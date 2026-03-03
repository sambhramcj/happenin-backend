-- 28_add_tickets_and_sponsorship_orders_compat.sql
-- Purpose: Add compatibility tables required by current frontend APIs and demo seeding

-- ============================================
-- TICKETS TABLE (used by /api/student/tickets and /api/payments/verify)
-- ============================================
CREATE TABLE IF NOT EXISTS tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id TEXT UNIQUE NOT NULL,
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  registration_id UUID REFERENCES registrations(id) ON DELETE SET NULL,
  student_email TEXT NOT NULL,
  event_title TEXT,
  event_date TEXT,
  event_location TEXT,
  qr_code_data TEXT,
  design_template TEXT DEFAULT 'modern',
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'used', 'cancelled')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tickets_student_email ON tickets(student_email);
CREATE INDEX IF NOT EXISTS idx_tickets_event_id ON tickets(event_id);
CREATE INDEX IF NOT EXISTS idx_tickets_registration_id ON tickets(registration_id);

-- ============================================
-- SPONSORSHIP ORDERS TABLE (used by /api/sponsorships/* routes)
-- ============================================
CREATE TABLE IF NOT EXISTS sponsorship_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sponsor_email TEXT NOT NULL REFERENCES users(email) ON DELETE CASCADE,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  fest_id UUID REFERENCES fests(id) ON DELETE CASCADE,
  pack_type TEXT NOT NULL CHECK (pack_type IN ('digital', 'app', 'fest')),
  amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
  razorpay_order_id TEXT UNIQUE,
  razorpay_payment_id TEXT,
  status TEXT NOT NULL DEFAULT 'created' CHECK (status IN ('created', 'paid', 'failed', 'cancelled', 'refunded')),
  visibility_active BOOLEAN DEFAULT FALSE,
  organizer_payout_settled BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT sponsorship_orders_event_or_fest_required CHECK (
    (pack_type = 'fest' AND fest_id IS NOT NULL) OR
    (pack_type IN ('digital', 'app') AND event_id IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_sponsorship_orders_sponsor ON sponsorship_orders(sponsor_email);
CREATE INDEX IF NOT EXISTS idx_sponsorship_orders_event ON sponsorship_orders(event_id);
CREATE INDEX IF NOT EXISTS idx_sponsorship_orders_fest ON sponsorship_orders(fest_id);
CREATE INDEX IF NOT EXISTS idx_sponsorship_orders_status ON sponsorship_orders(status);

-- ============================================
-- Updated-at trigger helper
-- ============================================
CREATE OR REPLACE FUNCTION set_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_tickets_updated_at ON tickets;
CREATE TRIGGER trigger_tickets_updated_at
  BEFORE UPDATE ON tickets
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at_column();

DROP TRIGGER IF EXISTS trigger_sponsorship_orders_updated_at ON sponsorship_orders;
CREATE TRIGGER trigger_sponsorship_orders_updated_at
  BEFORE UPDATE ON sponsorship_orders
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at_column();
