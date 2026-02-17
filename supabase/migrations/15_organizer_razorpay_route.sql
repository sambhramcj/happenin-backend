-- 27_organizer_razorpay_route.sql
-- Organizer Razorpay Route Sub-Merchant Integration
-- Supports both CLUB and FEST organizers with KYC-verified payouts
-- Created: February 2026

-- ============================================
-- CREATE organizers TABLE
-- ============================================
-- Tracks organizers with Razorpay Route integration
-- Links to users (for clubs) OR fests (for fest committees)
CREATE TABLE IF NOT EXISTS organizers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Type determination
  organizer_type TEXT NOT NULL CHECK (organizer_type IN ('CLUB', 'FEST')),
  
  -- Identity references (mutually exclusive)
  -- CLUB: linked to a user (student club organizer)
  -- FEST: linked to a fest (fest committee organizer)
  user_email TEXT REFERENCES users(email) ON DELETE CASCADE,
  fest_id UUID REFERENCES fests(id) ON DELETE CASCADE,
  
  -- Display name (club name or fest name)
  display_name TEXT NOT NULL,
  
  -- Legal/PAN holder name (MUST match PAN holder name)
  legal_name TEXT NOT NULL,
  
  -- PAN details (required for Razorpay Route)
  pan_number TEXT NOT NULL UNIQUE,
  
  -- Bank account details (MUST match PAN holder)
  bank_account_number TEXT NOT NULL,
  ifsc_code TEXT NOT NULL,
  
  -- Razorpay Route integration
  razorpay_account_id TEXT UNIQUE,
  
  -- KYC status from Razorpay
  kyc_status TEXT NOT NULL DEFAULT 'pending' CHECK (kyc_status IN ('pending', 'verified', 'rejected')),
  kyc_rejection_reason TEXT,
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  kyc_verified_at TIMESTAMP WITH TIME ZONE,
  
  -- Constraints
  CONSTRAINT organizer_single_type CHECK (
    (organizer_type = 'CLUB' AND user_email IS NOT NULL AND fest_id IS NULL) OR
    (organizer_type = 'FEST' AND fest_id IS NOT NULL AND user_email IS NULL)
  )
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_organizers_user_email ON organizers(user_email);
CREATE INDEX IF NOT EXISTS idx_organizers_fest_id ON organizers(fest_id);
CREATE INDEX IF NOT EXISTS idx_organizers_type ON organizers(organizer_type);
CREATE INDEX IF NOT EXISTS idx_organizers_kyc_status ON organizers(kyc_status);
CREATE INDEX IF NOT EXISTS idx_organizers_razorpay_account_id ON organizers(razorpay_account_id);
CREATE INDEX IF NOT EXISTS idx_organizers_pan ON organizers(pan_number);

-- ============================================
-- UPDATE events TABLE
-- ============================================
-- Add organizer_id to link events to specific organizers
ALTER TABLE events
  ADD COLUMN IF NOT EXISTS organizer_id UUID REFERENCES organizers(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_events_organizer_id ON events(organizer_id);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================
ALTER TABLE organizers ENABLE ROW LEVEL SECURITY;

-- Organizers can read their own profile
DROP POLICY IF EXISTS "Organizer read own profile" ON organizers;
CREATE POLICY "Organizer read own profile" ON organizers
  FOR SELECT
  USING (
    (organizer_type = 'CLUB' AND user_email = auth.jwt()->>'email') OR
    (organizer_type = 'FEST' AND fest_id IN (
      SELECT fest_id FROM fest_members 
      WHERE member_email = auth.jwt()->>'email'
    ))
  );

-- Organizers can update their own profile (only if KYC not verified)
DROP POLICY IF EXISTS "Organizer update own unverified profile" ON organizers;
CREATE POLICY "Organizer update own unverified profile" ON organizers
  FOR UPDATE
  USING (
    kyc_status != 'verified' AND (
      (organizer_type = 'CLUB' AND user_email = auth.jwt()->>'email') OR
      (organizer_type = 'FEST' AND fest_id IN (
        SELECT fest_id FROM fest_members 
        WHERE member_email = auth.jwt()->>'email'
      ))
    )
  )
  WITH CHECK (
    kyc_status != 'verified' AND (
      (organizer_type = 'CLUB' AND user_email = auth.jwt()->>'email') OR
      (organizer_type = 'FEST' AND fest_id IN (
        SELECT fest_id FROM fest_members 
        WHERE member_email = auth.jwt()->>'email'
      ))
    )
  );

-- Admins can read all organizer profiles and update KYC status
DROP POLICY IF EXISTS "Admin read all organizers" ON organizers;
CREATE POLICY "Admin read all organizers" ON organizers
  FOR SELECT
  USING (auth.jwt()->>'role' = 'admin');

DROP POLICY IF EXISTS "Admin update organizer kyc_status" ON organizers;
CREATE POLICY "Admin update organizer kyc_status" ON organizers
  FOR UPDATE
  USING (auth.jwt()->>'role' = 'admin')
  WITH CHECK (auth.jwt()->>'role' = 'admin');

-- ============================================
-- TRIGGER: Update updated_at timestamp
-- ============================================
CREATE OR REPLACE FUNCTION update_organizers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_organizers_updated_at ON organizers;
CREATE TRIGGER trg_organizers_updated_at
  BEFORE UPDATE ON organizers
  FOR EACH ROW
  EXECUTE FUNCTION update_organizers_updated_at();
