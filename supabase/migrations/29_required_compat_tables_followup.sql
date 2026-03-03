-- 29_required_compat_tables_followup.sql
-- Purpose: Ensure missing-but-required schema for current frontend codepaths exists.
-- Safe to run manually (idempotent).

-- =========================================================
-- 1) Shared updated_at trigger helper
-- =========================================================
CREATE OR REPLACE FUNCTION set_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- 2) TICKETS table (required by payments + student tickets APIs)
-- =========================================================
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

ALTER TABLE tickets ADD COLUMN IF NOT EXISTS ticket_id TEXT;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS event_id UUID;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS registration_id UUID;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS student_email TEXT;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS event_title TEXT;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS event_date TEXT;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS event_location TEXT;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS qr_code_data TEXT;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS design_template TEXT DEFAULT 'modern';
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

CREATE UNIQUE INDEX IF NOT EXISTS idx_tickets_ticket_id_unique ON tickets(ticket_id);
CREATE INDEX IF NOT EXISTS idx_tickets_student_email ON tickets(student_email);
CREATE INDEX IF NOT EXISTS idx_tickets_event_id ON tickets(event_id);
CREATE INDEX IF NOT EXISTS idx_tickets_registration_id ON tickets(registration_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'tickets_event_id_fkey'
  ) THEN
    ALTER TABLE tickets
      ADD CONSTRAINT tickets_event_id_fkey
      FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'tickets_registration_id_fkey'
  ) THEN
    ALTER TABLE tickets
      ADD CONSTRAINT tickets_registration_id_fkey
      FOREIGN KEY (registration_id) REFERENCES registrations(id) ON DELETE SET NULL;
  END IF;
END $$;

DROP TRIGGER IF EXISTS trigger_tickets_updated_at ON tickets;
CREATE TRIGGER trigger_tickets_updated_at
  BEFORE UPDATE ON tickets
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at_column();

-- =========================================================
-- 3) SPONSORSHIP_ORDERS table (required by sponsorship APIs)
-- =========================================================
CREATE TABLE IF NOT EXISTS sponsorship_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sponsor_email TEXT NOT NULL,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  fest_id UUID REFERENCES fests(id) ON DELETE CASCADE,
  pack_type TEXT NOT NULL CHECK (pack_type IN ('digital', 'app', 'fest')),
  amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
  razorpay_order_id TEXT UNIQUE,
  razorpay_payment_id TEXT,
  status TEXT NOT NULL DEFAULT 'created' CHECK (status IN ('created', 'paid', 'failed', 'cancelled', 'refunded')),
  visibility_active BOOLEAN DEFAULT FALSE,
  organizer_payout_settled BOOLEAN DEFAULT FALSE,
  organizer_payout_settled_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT sponsorship_orders_event_or_fest_required CHECK (
    (pack_type = 'fest' AND fest_id IS NOT NULL) OR
    (pack_type IN ('digital', 'app') AND event_id IS NOT NULL)
  )
);

ALTER TABLE sponsorship_orders ADD COLUMN IF NOT EXISTS sponsor_email TEXT;
ALTER TABLE sponsorship_orders ADD COLUMN IF NOT EXISTS event_id UUID;
ALTER TABLE sponsorship_orders ADD COLUMN IF NOT EXISTS fest_id UUID;
ALTER TABLE sponsorship_orders ADD COLUMN IF NOT EXISTS pack_type TEXT;
ALTER TABLE sponsorship_orders ADD COLUMN IF NOT EXISTS amount NUMERIC(12,2);
ALTER TABLE sponsorship_orders ADD COLUMN IF NOT EXISTS razorpay_order_id TEXT;
ALTER TABLE sponsorship_orders ADD COLUMN IF NOT EXISTS razorpay_payment_id TEXT;
ALTER TABLE sponsorship_orders ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'created';
ALTER TABLE sponsorship_orders ADD COLUMN IF NOT EXISTS visibility_active BOOLEAN DEFAULT FALSE;
ALTER TABLE sponsorship_orders ADD COLUMN IF NOT EXISTS organizer_payout_settled BOOLEAN DEFAULT FALSE;
ALTER TABLE sponsorship_orders ADD COLUMN IF NOT EXISTS organizer_payout_settled_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE sponsorship_orders ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE sponsorship_orders ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

CREATE UNIQUE INDEX IF NOT EXISTS idx_sponsorship_orders_razorpay_order_id_unique ON sponsorship_orders(razorpay_order_id);
CREATE INDEX IF NOT EXISTS idx_sponsorship_orders_sponsor_email ON sponsorship_orders(sponsor_email);
CREATE INDEX IF NOT EXISTS idx_sponsorship_orders_event_id ON sponsorship_orders(event_id);
CREATE INDEX IF NOT EXISTS idx_sponsorship_orders_fest_id ON sponsorship_orders(fest_id);
CREATE INDEX IF NOT EXISTS idx_sponsorship_orders_status ON sponsorship_orders(status);
CREATE INDEX IF NOT EXISTS idx_sponsorship_orders_visibility_active ON sponsorship_orders(visibility_active);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'sponsorship_orders_sponsor_users_fkey'
  ) THEN
    ALTER TABLE sponsorship_orders
      ADD CONSTRAINT sponsorship_orders_sponsor_users_fkey
      FOREIGN KEY (sponsor_email) REFERENCES users(email) ON DELETE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'sponsorship_orders_sponsor_profile_fkey'
  ) THEN
    ALTER TABLE sponsorship_orders
      ADD CONSTRAINT sponsorship_orders_sponsor_profile_fkey
      FOREIGN KEY (sponsor_email) REFERENCES sponsors_profile(email) ON DELETE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'sponsorship_orders_event_id_fkey'
  ) THEN
    ALTER TABLE sponsorship_orders
      ADD CONSTRAINT sponsorship_orders_event_id_fkey
      FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'sponsorship_orders_fest_id_fkey'
  ) THEN
    ALTER TABLE sponsorship_orders
      ADD CONSTRAINT sponsorship_orders_fest_id_fkey
      FOREIGN KEY (fest_id) REFERENCES fests(id) ON DELETE CASCADE;
  END IF;
END $$;

DROP TRIGGER IF EXISTS trigger_sponsorship_orders_updated_at ON sponsorship_orders;
CREATE TRIGGER trigger_sponsorship_orders_updated_at
  BEFORE UPDATE ON sponsorship_orders
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at_column();
