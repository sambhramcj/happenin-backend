-- 02a_event_fields_consolidation.sql
-- Consolidated: Adds all event enhancements (formerly migrations 05, 06, 25, 28, 29, 33, 34)
-- Purpose: Single, clean migration for events table extensions

-- ============================================================================
-- EVENT SCHEDULING FIELDS (from 05)
-- ============================================================================
ALTER TABLE events
ADD COLUMN IF NOT EXISTS start_datetime TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS end_datetime TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS schedule_sessions JSONB DEFAULT NULL,
ADD COLUMN IF NOT EXISTS registration_close_datetime TIMESTAMP WITH TIME ZONE DEFAULT NULL,
ADD COLUMN IF NOT EXISTS registrations_closed BOOLEAN DEFAULT FALSE;

-- Migrate existing data from 'date' to 'start_datetime' and 'end_datetime'
UPDATE events 
SET 
  start_datetime = date AT TIME ZONE 'UTC',
  end_datetime = (date AT TIME ZONE 'UTC') + INTERVAL '1 day'
WHERE start_datetime IS NULL AND date IS NOT NULL;

-- ============================================================================
-- PRIZE POOL & ORGANIZER CONTACT (from 06)
-- ============================================================================
ALTER TABLE events 
ADD COLUMN IF NOT EXISTS prize_pool_amount NUMERIC(12, 2),
ADD COLUMN IF NOT EXISTS prize_pool_description TEXT,
ADD COLUMN IF NOT EXISTS organizer_contact_phone VARCHAR(20),
ADD COLUMN IF NOT EXISTS organizer_contact_email VARCHAR(255),
ADD COLUMN IF NOT EXISTS brochure_url TEXT;

-- ============================================================================
-- WHATSAPP GROUP & PROMOTIONAL FIELDS (from 25)
-- ============================================================================
ALTER TABLE events
ADD COLUMN IF NOT EXISTS whatsapp_group_enabled BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS whatsapp_group_link TEXT;

-- ============================================================================
-- BOOST & VISIBILITY FIELDS (from 28)
-- ============================================================================
ALTER TABLE events
ADD COLUMN IF NOT EXISTS boost_visibility BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS boost_payment_status TEXT DEFAULT 'unpaid' CHECK (boost_payment_status IN ('unpaid', 'pending', 'completed')),
ADD COLUMN IF NOT EXISTS boost_priority INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS boost_end_date TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS banner_url TEXT,
ADD COLUMN IF NOT EXISTS ticket_price NUMERIC(10, 2);

-- ============================================================================
-- CATEGORY & CAPACITY (from 33, 34)
-- ============================================================================
ALTER TABLE events
ADD COLUMN IF NOT EXISTS category TEXT,
ADD COLUMN IF NOT EXISTS max_attendees INTEGER;

-- Add constraint for max_attendees if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'events_max_attendees_positive'
  ) THEN
    ALTER TABLE events ADD CONSTRAINT events_max_attendees_positive CHECK (max_attendees IS NULL OR max_attendees > 0);
  END IF;
END $$;

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_events_start_datetime ON events(start_datetime);
CREATE INDEX IF NOT EXISTS idx_events_end_datetime ON events(end_datetime);
CREATE INDEX IF NOT EXISTS idx_events_registrations_closed ON events(registrations_closed);
CREATE INDEX IF NOT EXISTS idx_events_prize_pool_amount ON events(prize_pool_amount) WHERE prize_pool_amount IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_events_boost_visibility ON events(boost_visibility) WHERE boost_visibility = TRUE;
CREATE INDEX IF NOT EXISTS idx_events_category ON events(category);

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================
CREATE OR REPLACE FUNCTION is_event_live(event_id UUID)
RETURNS BOOLEAN AS $$
SELECT NOW() AT TIME ZONE 'UTC' >= e.start_datetime AND NOW() AT TIME ZONE 'UTC' <= e.end_datetime
FROM events e WHERE e.id = event_id;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION are_registrations_open(event_id UUID)
RETURNS BOOLEAN AS $$
SELECT NOT e.registrations_closed 
  AND (e.registration_close_datetime IS NULL OR NOW() AT TIME ZONE 'UTC' < e.registration_close_datetime)
  AND NOW() AT TIME ZONE 'UTC' < e.start_datetime
FROM events e WHERE e.id = event_id;
$$ LANGUAGE SQL STABLE;

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================
COMMENT ON COLUMN events.start_datetime IS 'Event start date and time (ISO 8601)';
COMMENT ON COLUMN events.end_datetime IS 'Event end date and time (ISO 8601)';
COMMENT ON COLUMN events.schedule_sessions IS 'JSON array of schedule sessions: [{date, start_time, end_time, description}]';
COMMENT ON COLUMN events.registration_close_datetime IS 'Datetime when registrations automatically close';
COMMENT ON COLUMN events.registrations_closed IS 'Manual flag to close registrations';
COMMENT ON COLUMN events.prize_pool_amount IS 'Total prize pool for the event';
COMMENT ON COLUMN events.prize_pool_description IS 'Description of prize distribution';
COMMENT ON COLUMN events.organizer_contact_phone IS 'Organizer phone number';
COMMENT ON COLUMN events.organizer_contact_email IS 'Organizer email address';
COMMENT ON COLUMN events.brochure_url IS 'URL to event brochure/PDF';
COMMENT ON COLUMN events.whatsapp_group_enabled IS 'Whether event has WhatsApp group';
COMMENT ON COLUMN events.whatsapp_group_link IS 'WhatsApp group invitation link';
COMMENT ON COLUMN events.boost_visibility IS 'Whether event visibility is boosted';
COMMENT ON COLUMN events.boost_payment_status IS 'Payment status for visibility boost';
COMMENT ON COLUMN events.boost_priority IS 'Priority rank for boosted visibility';
COMMENT ON COLUMN events.boost_end_date IS 'When the visibility boost expires';
COMMENT ON COLUMN events.banner_url IS 'URL to event banner image';
COMMENT ON COLUMN events.ticket_price IS 'Individual ticket price';
COMMENT ON COLUMN events.category IS 'Event category/type';
COMMENT ON COLUMN events.max_attendees IS 'Maximum number of attendees (NULL = unlimited)';
