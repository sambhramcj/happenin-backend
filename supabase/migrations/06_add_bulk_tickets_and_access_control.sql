-- 11_add_bulk_tickets_and_access_control.sql
-- Migration: Add Bulk Ticket Sales and Event Access Control
-- Purpose: Enable bulk ticket sales with offers and granular event access restrictions
-- Date: February 2026

-- ============================================
-- 1. BULK TICKET SYSTEM
-- ============================================

-- Bulk Ticket Packs (organizers can create bulk ticket packages)
CREATE TABLE IF NOT EXISTS bulk_ticket_packs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  organizer_email TEXT NOT NULL,
  
  -- Package details
  name VARCHAR(255) NOT NULL, -- e.g., "Group of 10", "Corporate Pack"
  description TEXT,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  
  -- Pricing
  base_price DECIMAL(10, 2) NOT NULL, -- price per ticket
  bulk_price DECIMAL(10, 2) NOT NULL, -- discounted price per ticket
  discount_percentage INTEGER, -- calculated as (base_price - bulk_price) / base_price * 100
  total_cost DECIMAL(10, 2) NOT NULL, -- bulk_price * quantity
  
  -- Offer details (optional)
  offer_title VARCHAR(255),
  offer_description TEXT,
  offer_expiry_date TIMESTAMP WITH TIME ZONE,
  
  -- Status tracking
  status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'sold_out', 'expired', 'inactive')),
  sold_count INTEGER DEFAULT 0,
  available_count INTEGER GENERATED ALWAYS AS (quantity - sold_count) STORED,
  
  -- Metadata
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Individual bulk ticket purchases (when someone buys from a bulk pack)
CREATE TABLE IF NOT EXISTS bulk_ticket_purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bulk_pack_id UUID NOT NULL REFERENCES bulk_ticket_packs(id) ON DELETE CASCADE,
  buyer_email TEXT NOT NULL,
  
  -- Purchase details
  quantity_purchased INTEGER NOT NULL CHECK (quantity_purchased > 0),
  price_per_ticket DECIMAL(10, 2) NOT NULL,
  total_amount DECIMAL(10, 2) NOT NULL,
  
  -- Status
  payment_status VARCHAR(50) DEFAULT 'pending' CHECK (payment_status IN ('pending', 'completed', 'failed', 'refunded')),
  purchase_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Reference to payment if applicable
  payment_id UUID,
  
  UNIQUE(bulk_pack_id, buyer_email)
);

-- Bulk ticket distribution (tickets generated from bulk purchases)
CREATE TABLE IF NOT EXISTS bulk_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bulk_purchase_id UUID NOT NULL REFERENCES bulk_ticket_purchases(id) ON DELETE CASCADE,
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  
  -- Ticket info
  ticket_number VARCHAR(50) UNIQUE NOT NULL, -- e.g., BULK-EVENT-001
  qr_code_data TEXT,
  
  -- Usage tracking
  assigned_to_email TEXT, -- when the bulk buyer assigns to specific person
  checked_in BOOLEAN DEFAULT FALSE,
  checked_in_at TIMESTAMP WITH TIME ZONE,
  check_in_by_email TEXT,
  
  status VARCHAR(50) DEFAULT 'available' CHECK (status IN ('available', 'assigned', 'used', 'cancelled')),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 2. EVENT ACCESS CONTROL
-- ============================================

-- Access control policy for events
CREATE TABLE IF NOT EXISTS event_access_control (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL UNIQUE REFERENCES events(id) ON DELETE CASCADE,
  organizer_email TEXT NOT NULL,
  
  -- Access type: 'open' (everyone), 'restricted' (based on criteria below)
  access_type VARCHAR(50) DEFAULT 'open' CHECK (access_type IN ('open', 'restricted')),
  
  -- Restriction criteria (can be combined with AND logic)
  -- JSON format allows flexible combinations
  restrictions JSONB DEFAULT '{}',
  -- Example:
  -- {
  --   "college": ["MIT Chennai", "IITM"],
  --   "year_of_study": [3, 4],
  --   "branch": ["CSE", "ECE"],
  --   "club_membership": ["Tech Club", "Innovation Club"],
  --   "require_all_criteria": false  -- if true, user must match ALL criteria; if false, ANY criteria
  -- }
  
  -- Status
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Breakdown of restriction types (for easier querying)
CREATE TABLE IF NOT EXISTS access_control_restrictions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  access_control_id UUID NOT NULL REFERENCES event_access_control(id) ON DELETE CASCADE,
  
  restriction_type VARCHAR(50) NOT NULL CHECK (restriction_type IN ('college', 'year_of_study', 'branch', 'club_membership')),
  restriction_value VARCHAR(255) NOT NULL,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(access_control_id, restriction_type, restriction_value)
);

-- Track access eligibility checks
CREATE TABLE IF NOT EXISTS access_check_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_email TEXT NOT NULL,
  
  access_eligible BOOLEAN NOT NULL,
  check_reason TEXT, -- e.g., 'college_mismatch', 'year_not_eligible', 'passed'
  checked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 3. INDEXES FOR PERFORMANCE
-- ============================================

CREATE INDEX IF NOT EXISTS idx_bulk_packs_event ON bulk_ticket_packs(event_id);
CREATE INDEX IF NOT EXISTS idx_bulk_packs_organizer ON bulk_ticket_packs(organizer_email);
CREATE INDEX IF NOT EXISTS idx_bulk_packs_status ON bulk_ticket_packs(status);

CREATE INDEX IF NOT EXISTS idx_bulk_purchases_pack ON bulk_ticket_purchases(bulk_pack_id);
CREATE INDEX IF NOT EXISTS idx_bulk_purchases_buyer ON bulk_ticket_purchases(buyer_email);
CREATE INDEX IF NOT EXISTS idx_bulk_purchases_payment_status ON bulk_ticket_purchases(payment_status);

CREATE INDEX IF NOT EXISTS idx_bulk_tickets_purchase ON bulk_tickets(bulk_purchase_id);
CREATE INDEX IF NOT EXISTS idx_bulk_tickets_event ON bulk_tickets(event_id);
CREATE INDEX IF NOT EXISTS idx_bulk_tickets_assigned_to ON bulk_tickets(assigned_to_email);
CREATE INDEX IF NOT EXISTS idx_bulk_tickets_status ON bulk_tickets(status);

CREATE INDEX IF NOT EXISTS idx_access_control_event ON event_access_control(event_id);
CREATE INDEX IF NOT EXISTS idx_access_control_organizer ON event_access_control(organizer_email);

CREATE INDEX IF NOT EXISTS idx_access_restrictions_control ON access_control_restrictions(access_control_id);
CREATE INDEX IF NOT EXISTS idx_access_restrictions_type ON access_control_restrictions(restriction_type);

CREATE INDEX IF NOT EXISTS idx_access_logs_event ON access_check_logs(event_id);
CREATE INDEX IF NOT EXISTS idx_access_logs_user ON access_check_logs(user_email);

-- ============================================
-- 4. ADD COLUMNS TO EVENTS TABLE
-- ============================================

ALTER TABLE events ADD COLUMN IF NOT EXISTS allow_bulk_tickets BOOLEAN DEFAULT TRUE;
ALTER TABLE events ADD COLUMN IF NOT EXISTS bulk_ticket_info JSONB DEFAULT NULL;

-- ============================================
-- 5. HELPER FUNCTIONS
-- ============================================

-- Check if user is eligible for an event
CREATE OR REPLACE FUNCTION is_user_eligible_for_event(
  p_event_id UUID,
  p_user_email TEXT,
  p_user_college TEXT DEFAULT NULL,
  p_user_year_of_study INTEGER DEFAULT NULL,
  p_user_branch TEXT DEFAULT NULL,
  p_user_club_memberships TEXT[] DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  v_access_control RECORD;
  v_require_all BOOLEAN;
  v_matches INTEGER := 0;
  v_restriction_count INTEGER := 0;
  v_restriction RECORD;
BEGIN
  -- Get access control for event
  SELECT * INTO v_access_control 
  FROM event_access_control 
  WHERE event_id = p_event_id AND is_active = TRUE;
  
  -- If no access control or it's open, user is eligible
  IF v_access_control IS NULL OR v_access_control.access_type = 'open' THEN
    RETURN TRUE;
  END IF;
  
  -- Check restricted access
  v_require_all := COALESCE((v_access_control.restrictions->>'require_all_criteria')::BOOLEAN, FALSE);
  
  FOR v_restriction IN
    SELECT * FROM access_control_restrictions 
    WHERE access_control_id = v_access_control.id
  LOOP
    v_restriction_count := v_restriction_count + 1;
    
    CASE v_restriction.restriction_type
      WHEN 'college' THEN
        IF p_user_college = v_restriction.restriction_value THEN
          v_matches := v_matches + 1;
        END IF;
      WHEN 'year_of_study' THEN
        IF p_user_year_of_study = v_restriction.restriction_value::INTEGER THEN
          v_matches := v_matches + 1;
        END IF;
      WHEN 'branch' THEN
        IF p_user_branch = v_restriction.restriction_value THEN
          v_matches := v_matches + 1;
        END IF;
      WHEN 'club_membership' THEN
        IF p_user_club_memberships IS NOT NULL AND 
           v_restriction.restriction_value = ANY(p_user_club_memberships) THEN
          v_matches := v_matches + 1;
        END IF;
    END CASE;
  END LOOP;
  
  -- Check eligibility based on require_all flag
  IF v_require_all THEN
    RETURN v_matches = v_restriction_count;
  ELSE
    RETURN v_matches > 0;
  END IF;
END;
$$ LANGUAGE plpgsql STABLE;

-- Get discount percentage for a bulk pack
CREATE OR REPLACE FUNCTION get_bulk_discount_percentage(p_base_price DECIMAL, p_bulk_price DECIMAL)
RETURNS INTEGER AS $$
BEGIN
  IF p_base_price = 0 OR p_base_price IS NULL THEN
    RETURN 0;
  END IF;
  RETURN ROUND(((p_base_price - p_bulk_price) / p_base_price * 100)::NUMERIC)::INTEGER;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Update bulk pack status based on sold count
CREATE OR REPLACE FUNCTION update_bulk_pack_status()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.sold_count >= NEW.quantity THEN
    NEW.status := 'sold_out';
  ELSIF NEW.offer_expiry_date IS NOT NULL AND NOW() > NEW.offer_expiry_date THEN
    NEW.status := 'expired';
  ELSE
    NEW.status := 'active';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update bulk pack status
CREATE TRIGGER trigger_update_bulk_pack_status
BEFORE INSERT OR UPDATE ON bulk_ticket_packs
FOR EACH ROW
EXECUTE FUNCTION update_bulk_pack_status();

-- ============================================
-- 6. COMMENTS FOR DOCUMENTATION
-- ============================================

COMMENT ON TABLE bulk_ticket_packs IS 'Bulk ticket packages that organizers can create and sell at discounted rates';
COMMENT ON TABLE bulk_ticket_purchases IS 'Records of bulk ticket package purchases';
COMMENT ON TABLE bulk_tickets IS 'Individual tickets generated from bulk purchases';
COMMENT ON TABLE event_access_control IS 'Access control policies for events (open or restricted)';
COMMENT ON TABLE access_control_restrictions IS 'Individual restriction criteria for event access control';

COMMENT ON COLUMN bulk_ticket_packs.discount_percentage IS 'Calculated discount % for marketing purposes';
COMMENT ON COLUMN event_access_control.restrictions IS 'JSONB with flexibility for future restriction types';
COMMENT ON COLUMN access_control_restrictions.restriction_type IS 'Type of restriction: college, year_of_study, branch, or club_membership';
