-- 03a_sponsorship_system_consolidated.sql
-- Consolidated Sponsorship System (formerly migrations 03, 04, 10, 24, 26)
-- Comprehensive sponsorship, payouts, and payment system

-- ============================================================================
-- SPONSORSHIP PACKAGES & DELIVERABLES
-- ============================================================================
CREATE TABLE IF NOT EXISTS sponsorship_packages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  tier TEXT NOT NULL CHECK (tier IN ('bronze', 'silver', 'gold', 'platinum')),
  min_amount NUMERIC NOT NULL,
  max_amount NUMERIC NOT NULL,
  facilitator_fee NUMERIC DEFAULT 0,
  organizer_notes TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sponsorship_deliverables (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id UUID NOT NULL REFERENCES sponsorship_packages(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('platform_default', 'organizer_defined')),
  category TEXT NOT NULL CHECK (category IN ('certificate', 'ticket', 'app_banner', 'social', 'on_ground', 'stall', 'digital')),
  title TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- SPONSORSHIP DEALS & DEALS TABLE (from 03, 10, 24, 26)
-- ============================================================================
CREATE TABLE IF NOT EXISTS sponsorship_deals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sponsor_id TEXT NOT NULL REFERENCES users(email) ON DELETE CASCADE,
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  package_id UUID NOT NULL REFERENCES sponsorship_packages(id) ON DELETE CASCADE,
  amount_paid NUMERIC NOT NULL,
  platform_fee NUMERIC NOT NULL,
  organizer_amount NUMERIC NOT NULL,
  facilitation_fee NUMERIC DEFAULT 0,
  visibility_manual_verified BOOLEAN DEFAULT FALSE,
  verification_admin_email TEXT REFERENCES users(email) ON DELETE SET NULL,
  razorpay_order_id TEXT,
  razorpay_payment_id TEXT,
  status TEXT NOT NULL CHECK (status IN ('pending', 'confirmed', 'active', 'completed')) DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- SPONSORS PROFILE
-- ============================================================================
CREATE TABLE IF NOT EXISTS sponsors_profile (
  email TEXT PRIMARY KEY REFERENCES users(email) ON DELETE CASCADE,
  company_name TEXT NOT NULL,
  logo_url TEXT,
  website_url TEXT,
  contact_name TEXT,
  contact_phone TEXT,
  banner_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- PLATFORM DEFAULT DELIVERABLES (Admin)
-- ============================================================================
CREATE TABLE IF NOT EXISTS platform_default_deliverables (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category TEXT NOT NULL CHECK (category IN ('certificate', 'ticket', 'app_banner', 'social', 'on_ground', 'stall', 'digital')),
  title TEXT NOT NULL,
  description TEXT,
  min_tier TEXT NOT NULL CHECK (min_tier IN ('bronze', 'silver', 'gold', 'platinum')),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- BANK ACCOUNTS & PAYOUTS (from 04)
-- ============================================================================
CREATE TABLE IF NOT EXISTS organizer_bank_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organizer_email TEXT NOT NULL REFERENCES users(email) ON DELETE CASCADE,
  account_holder_name TEXT,
  bank_name TEXT,
  account_number TEXT,
  ifsc_code TEXT,
  upi_id TEXT,
  is_verified BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uniq_organizer_bank_accounts_email ON organizer_bank_accounts(organizer_email);

CREATE TABLE IF NOT EXISTS sponsorship_payouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sponsorship_deal_id UUID NOT NULL REFERENCES sponsorship_deals(id) ON DELETE CASCADE,
  organizer_email TEXT NOT NULL REFERENCES users(email) ON DELETE CASCADE,
  gross_amount NUMERIC NOT NULL,
  platform_fee NUMERIC NOT NULL,
  payout_amount NUMERIC NOT NULL,
  payout_method TEXT CHECK (payout_method IN ('UPI', 'IMPS')),
  payout_status TEXT NOT NULL CHECK (payout_status IN ('pending', 'paid')) DEFAULT 'pending',
  paid_at TIMESTAMP WITH TIME ZONE,
  admin_email TEXT REFERENCES users(email),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uniq_sponsorship_payouts_deal ON sponsorship_payouts(sponsorship_deal_id);
CREATE INDEX IF NOT EXISTS idx_sponsorship_payouts_organizer ON sponsorship_payouts(organizer_email);
CREATE INDEX IF NOT EXISTS idx_sponsorship_payouts_status ON sponsorship_payouts(payout_status);

-- ============================================================================
-- RAZORPAY SPONSORSHIP ORDERS (from 26)
-- ============================================================================
CREATE TABLE IF NOT EXISTS sponsorship_razorpay_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sponsorship_deal_id UUID NOT NULL REFERENCES sponsorship_deals(id) ON DELETE CASCADE,
  razorpay_order_id TEXT UNIQUE NOT NULL,
  amount_paise INTEGER NOT NULL,
  status TEXT CHECK (status IN ('created', 'attempted', 'paid', 'failed')) DEFAULT 'created',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- EVENT SPONSORSHIP TOGGLE
-- ============================================================================
ALTER TABLE events ADD COLUMN IF NOT EXISTS sponsorship_enabled BOOLEAN DEFAULT false;

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_sponsorship_packages_event ON sponsorship_packages(event_id);
CREATE INDEX IF NOT EXISTS idx_sponsorship_deliverables_package ON sponsorship_deliverables(package_id);
CREATE INDEX IF NOT EXISTS idx_sponsorship_deals_sponsor ON sponsorship_deals(sponsor_id);
CREATE INDEX IF NOT EXISTS idx_sponsorship_deals_event ON sponsorship_deals(event_id);
CREATE INDEX IF NOT EXISTS idx_sponsorship_deals_status ON sponsorship_deals(status);
CREATE INDEX IF NOT EXISTS idx_sponsorship_deals_visibility_verified ON sponsorship_deals(visibility_manual_verified);
CREATE INDEX IF NOT EXISTS idx_platform_default_deliverables_active ON platform_default_deliverables(is_active);
CREATE INDEX IF NOT EXISTS idx_sponsorship_razorpay_orders_deal ON sponsorship_razorpay_orders(sponsorship_deal_id);

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================
ALTER TABLE organizer_bank_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE sponsorship_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE sponsorship_deals ENABLE ROW LEVEL SECURITY;
ALTER TABLE sponsors_profile ENABLE ROW LEVEL SECURITY;

-- Bank Accounts Policies
DROP POLICY IF EXISTS "Organizer read own bank account" ON organizer_bank_accounts;
CREATE POLICY "Organizer read own bank account" ON organizer_bank_accounts
  FOR SELECT USING (organizer_email = auth.jwt()->>'email');

DROP POLICY IF EXISTS "Organizer insert own bank account" ON organizer_bank_accounts;
CREATE POLICY "Organizer insert own bank account" ON organizer_bank_accounts
  FOR INSERT WITH CHECK (organizer_email = auth.jwt()->>'email');

DROP POLICY IF EXISTS "Organizer update own unverified bank account" ON organizer_bank_accounts;
CREATE POLICY "Organizer update own unverified bank account" ON organizer_bank_accounts
  FOR UPDATE USING (organizer_email = auth.jwt()->>'email' AND is_verified = false)
  WITH CHECK (organizer_email = auth.jwt()->>'email' AND is_verified = false);

DROP POLICY IF EXISTS "Admin manage bank accounts" ON organizer_bank_accounts;
CREATE POLICY "Admin manage bank accounts" ON organizer_bank_accounts
  FOR ALL USING (auth.jwt()->>'role' = 'admin')
  WITH CHECK (auth.jwt()->>'role' = 'admin');

-- Sponsorship Payouts Policies
DROP POLICY IF EXISTS "Organizer read own payouts" ON sponsorship_payouts;
CREATE POLICY "Organizer read own payouts" ON sponsorship_payouts
  FOR SELECT USING (organizer_email = auth.jwt()->>'email');

DROP POLICY IF EXISTS "Admin manage payouts" ON sponsorship_payouts;
CREATE POLICY "Admin manage payouts" ON sponsorship_payouts
  FOR ALL USING (auth.jwt()->>'role' = 'admin')
  WITH CHECK (auth.jwt()->>'role' = 'admin');

-- Sponsorship Deals Policies
DROP POLICY IF EXISTS "Sponsor read own sponsorships" ON sponsorship_deals;
CREATE POLICY "Sponsor read own sponsorships" ON sponsorship_deals
  FOR SELECT USING (sponsor_id = auth.jwt()->>'email');

DROP POLICY IF EXISTS "Admin manage sponsorships" ON sponsorship_deals;
CREATE POLICY "Admin manage sponsorships" ON sponsorship_deals
  FOR ALL USING (auth.jwt()->>'role' = 'admin')
  WITH CHECK (auth.jwt()->>'role' = 'admin');

-- Sponsors Profile Policies
DROP POLICY IF EXISTS "Sponsor read own profile" ON sponsors_profile;
CREATE POLICY "Sponsor read own profile" ON sponsors_profile
  FOR SELECT USING (email = auth.jwt()->>'email');

DROP POLICY IF EXISTS "Sponsor update own profile" ON sponsors_profile;
CREATE POLICY "Sponsor update own profile" ON sponsors_profile
  FOR UPDATE USING (email = auth.jwt()->>'email')
  WITH CHECK (email = auth.jwt()->>'email');

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================
CREATE OR REPLACE FUNCTION sponsorship_tier_rank(tier TEXT)
RETURNS INT AS $$
BEGIN
  RETURN CASE tier
    WHEN 'bronze' THEN 1
    WHEN 'silver' THEN 2
    WHEN 'gold' THEN 3
    WHEN 'platinum' THEN 4
    ELSE 0
  END;
END;
$$ LANGUAGE plpgsql;

-- Auto-add platform default deliverables when package is created
CREATE OR REPLACE FUNCTION add_platform_default_deliverables()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO sponsorship_deliverables (package_id, type, category, title, description)
  SELECT NEW.id, 'platform_default', d.category, d.title, d.description
  FROM platform_default_deliverables d
  WHERE d.is_active = true
    AND sponsorship_tier_rank(NEW.tier) >= sponsorship_tier_rank(d.min_tier);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_add_platform_default_deliverables ON sponsorship_packages;
CREATE TRIGGER trigger_add_platform_default_deliverables
  AFTER INSERT ON sponsorship_packages
  FOR EACH ROW
  EXECUTE FUNCTION add_platform_default_deliverables();

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================
COMMENT ON TABLE sponsorship_deals IS 'Sponsorship agreement between sponsor and event organizer';
COMMENT ON COLUMN sponsorship_deals.facilitation_fee IS 'Platform sharing fee for facilitation';
COMMENT ON COLUMN sponsorship_deals.visibility_manual_verified IS 'Manual approval for sponsorship visibility on event page';
COMMENT ON COLUMN sponsorship_deals.verification_admin_email IS 'Admin who verified visibility';
COMMENT ON TABLE sponsorship_razorpay_orders IS 'Razorpay payment orders for sponsorship deals via flat fee';
COMMENT ON COLUMN sponsors_profile.banner_url IS 'Sponsor profile banner image';
