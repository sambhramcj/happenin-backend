-- 32_final_revenue_system.sql
-- Final Revenue Architecture
-- 1) Ticket commission 95/5 via Razorpay Route
-- 2) Digital visibility packs 20/80 via Razorpay Route
-- 3) Featured event boost 100% platform

-- =========================================================
-- REGISTRATIONS: pending->confirmed flow compatibility
-- =========================================================
ALTER TABLE registrations
  ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS organizer_share NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS platform_share NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS gateway_fee NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS payment_captured_at TIMESTAMP WITH TIME ZONE;

DO $$
DECLARE
  status_constraint TEXT;
BEGIN
  SELECT conname INTO status_constraint
  FROM pg_constraint
  WHERE conrelid = 'registrations'::regclass
    AND contype = 'c'
    AND pg_get_constraintdef(oid) ILIKE '%status%';

  IF status_constraint IS NOT NULL THEN
    EXECUTE format('ALTER TABLE registrations DROP CONSTRAINT %I', status_constraint);
  END IF;

  ALTER TABLE registrations
    ADD CONSTRAINT registrations_status_check
    CHECK (status IN ('pending', 'registered', 'confirmed', 'checked_in', 'cancelled'));
END $$;

-- =========================================================
-- DIGITAL VISIBILITY PACKS
-- =========================================================
CREATE TABLE IF NOT EXISTS digital_visibility_packs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sponsor_id TEXT NOT NULL REFERENCES users(email) ON DELETE CASCADE,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  fest_id UUID REFERENCES fests(id) ON DELETE CASCADE,
  pack_type TEXT NOT NULL CHECK (pack_type IN ('silver', 'gold', 'platinum')),
  amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  organizer_share NUMERIC(12,2) NOT NULL CHECK (organizer_share >= 0),
  platform_share NUMERIC(12,2) NOT NULL CHECK (platform_share >= 0),
  payment_status TEXT NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'failed', 'cancelled', 'refunded')),
  admin_approved BOOLEAN NOT NULL DEFAULT FALSE,
  visibility_active BOOLEAN NOT NULL DEFAULT FALSE,
  organizer_email TEXT,
  razorpay_order_id TEXT UNIQUE,
  razorpay_payment_id TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT digital_pack_scope_check CHECK (
    (pack_type = 'platinum' AND fest_id IS NOT NULL)
    OR (pack_type IN ('silver', 'gold') AND event_id IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_dvp_sponsor_id ON digital_visibility_packs(sponsor_id);
CREATE INDEX IF NOT EXISTS idx_dvp_event_id ON digital_visibility_packs(event_id);
CREATE INDEX IF NOT EXISTS idx_dvp_fest_id ON digital_visibility_packs(fest_id);
CREATE INDEX IF NOT EXISTS idx_dvp_status ON digital_visibility_packs(payment_status);
CREATE INDEX IF NOT EXISTS idx_dvp_visibility ON digital_visibility_packs(visibility_active);

-- one platinum per fest (paid + active intent)
CREATE UNIQUE INDEX IF NOT EXISTS uniq_dvp_platinum_per_fest
  ON digital_visibility_packs(fest_id)
  WHERE pack_type = 'platinum' AND payment_status = 'paid';

-- one silver OR gold per event (paid)
CREATE UNIQUE INDEX IF NOT EXISTS uniq_dvp_event_silver_gold
  ON digital_visibility_packs(event_id)
  WHERE pack_type IN ('silver', 'gold') AND payment_status = 'paid';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'digital_visibility_packs_sponsor_profile_fkey'
  ) THEN
    ALTER TABLE digital_visibility_packs
      ADD CONSTRAINT digital_visibility_packs_sponsor_profile_fkey
      FOREIGN KEY (sponsor_id) REFERENCES sponsors_profile(email) ON DELETE CASCADE;
  END IF;
END $$;

-- =========================================================
-- FEATURED EVENTS BOOST
-- =========================================================
CREATE TABLE IF NOT EXISTS featured_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  college_id UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
  start_date TIMESTAMP WITH TIME ZONE NOT NULL,
  end_date TIMESTAMP WITH TIME ZONE NOT NULL,
  payment_status TEXT NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'failed', 'cancelled', 'refunded')),
  active BOOLEAN NOT NULL DEFAULT FALSE,
  organizer_email TEXT NOT NULL,
  razorpay_order_id TEXT UNIQUE,
  razorpay_payment_id TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_featured_events_event ON featured_events(event_id);
CREATE INDEX IF NOT EXISTS idx_featured_events_college ON featured_events(college_id);
CREATE INDEX IF NOT EXISTS idx_featured_events_active ON featured_events(active);
CREATE INDEX IF NOT EXISTS idx_featured_events_status ON featured_events(payment_status);

-- =========================================================
-- PAYMENT TRANSACTION LOG
-- =========================================================
CREATE TABLE IF NOT EXISTS payment_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stream_type TEXT NOT NULL CHECK (stream_type IN ('ticket', 'digital_pack', 'featured_boost')),
  source_id UUID,
  event_id UUID REFERENCES events(id) ON DELETE SET NULL,
  fest_id UUID REFERENCES fests(id) ON DELETE SET NULL,
  payer_email TEXT NOT NULL,
  organizer_email TEXT,
  gross_amount NUMERIC(12,2) NOT NULL,
  organizer_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  platform_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  gateway_fee_amount NUMERIC(12,2) DEFAULT 0,
  razorpay_order_id TEXT NOT NULL,
  razorpay_payment_id TEXT,
  status TEXT NOT NULL DEFAULT 'captured' CHECK (status IN ('pending', 'captured', 'failed', 'refunded')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_tx_stream ON payment_transactions(stream_type);
CREATE INDEX IF NOT EXISTS idx_payment_tx_payer ON payment_transactions(payer_email);
CREATE INDEX IF NOT EXISTS idx_payment_tx_order ON payment_transactions(razorpay_order_id);
CREATE UNIQUE INDEX IF NOT EXISTS uniq_payment_tx_order_payment
  ON payment_transactions(razorpay_order_id, COALESCE(razorpay_payment_id, ''));

-- =========================================================
-- WEBHOOK IDEMPOTENCY
-- =========================================================
CREATE TABLE IF NOT EXISTS webhook_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id TEXT NOT NULL UNIQUE,
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL,
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_webhook_events_type ON webhook_events(event_type);

-- =========================================================
-- UPDATED_AT triggers
-- =========================================================
CREATE OR REPLACE FUNCTION set_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_dvp_updated_at ON digital_visibility_packs;
CREATE TRIGGER trg_dvp_updated_at
  BEFORE UPDATE ON digital_visibility_packs
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at_column();

DROP TRIGGER IF EXISTS trg_featured_events_updated_at ON featured_events;
CREATE TRIGGER trg_featured_events_updated_at
  BEFORE UPDATE ON featured_events
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at_column();

-- =========================================================
-- RLS
-- =========================================================
ALTER TABLE digital_visibility_packs ENABLE ROW LEVEL SECURITY;
ALTER TABLE featured_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE webhook_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Sponsor read own digital packs" ON digital_visibility_packs;
CREATE POLICY "Sponsor read own digital packs" ON digital_visibility_packs
  FOR SELECT USING (sponsor_id = auth.jwt()->>'email');

DROP POLICY IF EXISTS "Sponsor insert own digital packs" ON digital_visibility_packs;
CREATE POLICY "Sponsor insert own digital packs" ON digital_visibility_packs
  FOR INSERT WITH CHECK (sponsor_id = auth.jwt()->>'email');

DROP POLICY IF EXISTS "Organizer read scoped digital packs" ON digital_visibility_packs;
CREATE POLICY "Organizer read scoped digital packs" ON digital_visibility_packs
  FOR SELECT USING (
    organizer_email = auth.jwt()->>'email'
    OR EXISTS (
      SELECT 1 FROM events e
      WHERE e.id = digital_visibility_packs.event_id
        AND e.organizer_email = auth.jwt()->>'email'
    )
  );

DROP POLICY IF EXISTS "Admin manage digital packs" ON digital_visibility_packs;
CREATE POLICY "Admin manage digital packs" ON digital_visibility_packs
  FOR ALL USING (auth.jwt()->>'role' = 'admin')
  WITH CHECK (auth.jwt()->>'role' = 'admin');

DROP POLICY IF EXISTS "Public read active digital packs" ON digital_visibility_packs;
CREATE POLICY "Public read active digital packs" ON digital_visibility_packs
  FOR SELECT USING (payment_status = 'paid' AND admin_approved = true AND visibility_active = true);

DROP POLICY IF EXISTS "Organizer read own featured events" ON featured_events;
CREATE POLICY "Organizer read own featured events" ON featured_events
  FOR SELECT USING (organizer_email = auth.jwt()->>'email');

DROP POLICY IF EXISTS "Organizer insert own featured events" ON featured_events;
CREATE POLICY "Organizer insert own featured events" ON featured_events
  FOR INSERT WITH CHECK (organizer_email = auth.jwt()->>'email');

DROP POLICY IF EXISTS "Admin manage featured events" ON featured_events;
CREATE POLICY "Admin manage featured events" ON featured_events
  FOR ALL USING (auth.jwt()->>'role' = 'admin')
  WITH CHECK (auth.jwt()->>'role' = 'admin');

DROP POLICY IF EXISTS "Public read active featured events" ON featured_events;
CREATE POLICY "Public read active featured events" ON featured_events
  FOR SELECT USING (active = true AND payment_status = 'paid');

DROP POLICY IF EXISTS "Admin read payment transactions" ON payment_transactions;
CREATE POLICY "Admin read payment transactions" ON payment_transactions
  FOR SELECT USING (auth.jwt()->>'role' = 'admin');

DROP POLICY IF EXISTS "Service role insert payment transactions" ON payment_transactions;
CREATE POLICY "Service role insert payment transactions" ON payment_transactions
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Admin read webhook events" ON webhook_events;
CREATE POLICY "Admin read webhook events" ON webhook_events
  FOR SELECT USING (auth.jwt()->>'role' = 'admin');

DROP POLICY IF EXISTS "Service role manage webhook events" ON webhook_events;
CREATE POLICY "Service role manage webhook events" ON webhook_events
  FOR ALL USING (true)
  WITH CHECK (true);
