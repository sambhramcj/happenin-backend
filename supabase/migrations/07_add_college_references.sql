-- 07_add_college_references.sql
-- Add college_id to events table
-- Migration: add_college_references
-- Created: 2026-02-01
-- Note: users table already has college_id from migration 01

-- Add college_id to events (if not exists)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'events' AND column_name = 'college_id'
  ) THEN
    ALTER TABLE events 
      ADD COLUMN college_id UUID REFERENCES colleges(id) ON DELETE SET NULL;
    
    CREATE INDEX IF NOT EXISTS idx_events_college_id 
      ON events(college_id);
    
    COMMENT ON COLUMN events.college_id IS 'College where event is hosted - inherited from organizer';
  END IF;
END $$;
