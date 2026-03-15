-- 35_mvp_qr_registration_and_feature_flags.sql
-- Lean MVP support for QR screenshot registration + feature flag management

-- =========================================================
-- EVENTS: MVP fields
-- =========================================================
ALTER TABLE events
  ADD COLUMN IF NOT EXISTS payment_qr TEXT,
  ADD COLUMN IF NOT EXISTS poster_url TEXT,
  ADD COLUMN IF NOT EXISTS registration_deadline TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS time TEXT;

-- Keep poster_url aligned with existing banner column when available
DO $$
DECLARE
  has_banner_image BOOLEAN;
  has_banner_url BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'events'
      AND column_name = 'banner_image'
  ) INTO has_banner_image;

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'events'
      AND column_name = 'banner_url'
  ) INTO has_banner_url;

  IF has_banner_image AND has_banner_url THEN
    EXECUTE 'UPDATE events SET poster_url = COALESCE(poster_url, banner_image, banner_url) WHERE poster_url IS NULL';
  ELSIF has_banner_image THEN
    EXECUTE 'UPDATE events SET poster_url = COALESCE(poster_url, banner_image) WHERE poster_url IS NULL';
  ELSIF has_banner_url THEN
    EXECUTE 'UPDATE events SET poster_url = COALESCE(poster_url, banner_url) WHERE poster_url IS NULL';
  END IF;
END $$;

-- =========================================================
-- REGISTRATIONS: screenshot + organizer review workflow
-- =========================================================
ALTER TABLE registrations
  ADD COLUMN IF NOT EXISTS screenshot_url TEXT,
  ADD COLUMN IF NOT EXISTS qr_ticket_id TEXT,
  ADD COLUMN IF NOT EXISTS review_notes TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS reviewed_by TEXT;

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
    CHECK (status IN ('pending', 'approved', 'rejected', 'registered', 'confirmed', 'checked_in', 'cancelled'));
END $$;

CREATE INDEX IF NOT EXISTS idx_registrations_status ON registrations(status);
CREATE INDEX IF NOT EXISTS idx_registrations_screenshot ON registrations(screenshot_url);

-- =========================================================
-- ATTENDANCE: avoid duplicate scan entries
-- =========================================================
CREATE UNIQUE INDEX IF NOT EXISTS uniq_attendance_event_registration
  ON attendance(event_id, registration_id)
  WHERE registration_id IS NOT NULL;

-- =========================================================
-- FEATURE FLAGS
-- =========================================================
CREATE TABLE IF NOT EXISTS platform_feature_flags (
  flag_key TEXT PRIMARY KEY,
  enabled BOOLEAN NOT NULL DEFAULT FALSE,
  updated_by TEXT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

INSERT INTO platform_feature_flags (flag_key, enabled)
VALUES
  ('PAYMENTS_RAZORPAY', false),
  ('SPONSORSHIPS', false),
  ('DIGITAL_VISIBILITY_PACKS', false),
  ('FEATURED_EVENT_BOOST', false),
  ('QR_PAYMENTS', true),
  ('EVENT_DISCOVERY', true),
  ('REGISTRATION', true),
  ('QR_ATTENDANCE', true),
  ('CERTIFICATES', true)
ON CONFLICT (flag_key) DO NOTHING;
