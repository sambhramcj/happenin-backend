-- 23_event_categories_cancellation_reschedule.sql
-- v1.2.1 Migration: Event Cancellation/Rescheduling and Categories

-- Event Categories Table
CREATE TABLE event_categories (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  category_name VARCHAR(255) NOT NULL UNIQUE,
  description TEXT,
  icon_url VARCHAR(500),
  color_code VARCHAR(7) DEFAULT '#6366F1',
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Event Category Mapping (many-to-many)
CREATE TABLE event_category_mapping (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES event_categories(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(event_id, category_id)
);

-- Event Status History/Changelog Table
CREATE TABLE event_changelog (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  status VARCHAR(50) NOT NULL DEFAULT 'active',
  previous_status VARCHAR(50),
  changed_by VARCHAR(255) NOT NULL,
  reason TEXT,
  details JSONB,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Store rescheduling information
CREATE TABLE event_reschedules (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  original_date TIMESTAMP NOT NULL,
  new_date TIMESTAMP NOT NULL,
  original_time VARCHAR(5),
  new_time VARCHAR(5),
  original_venue VARCHAR(500),
  new_venue VARCHAR(500),
  rescheduled_by VARCHAR(255) NOT NULL,
  reason TEXT,
  notification_sent BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Store cancellation information
CREATE TABLE event_cancellations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  cancelled_by VARCHAR(255) NOT NULL,
  cancellation_reason TEXT NOT NULL,
  refund_status VARCHAR(50) DEFAULT 'pending',
  notification_sent BOOLEAN DEFAULT FALSE,
  cancelled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add status column to events table (if not already present)
-- Uncomment if needed:
-- ALTER TABLE events ADD COLUMN status VARCHAR(50) DEFAULT 'active';

-- Create indexes for performance
CREATE INDEX idx_event_categories_name ON event_categories(category_name);
CREATE INDEX idx_event_category_mapping_event_id ON event_category_mapping(event_id);
CREATE INDEX idx_event_category_mapping_category_id ON event_category_mapping(category_id);
CREATE INDEX idx_event_changelog_event_id ON event_changelog(event_id);
CREATE INDEX idx_event_changelog_status ON event_changelog(status);
CREATE INDEX idx_event_reschedules_event_id ON event_reschedules(event_id);
CREATE INDEX idx_event_cancellations_event_id ON event_cancellations(event_id);

-- Insert default categories
INSERT INTO event_categories (category_name, description, color_code, display_order) VALUES
  ('Tech & Innovation', 'Hackathons, tech talks, coding competitions', '#3B82F6', 1),
  ('Cultural', 'Festivals, performances, cultural events', '#EC4899', 2),
  ('Sports', 'Athletic competitions, tournaments, sports events', '#10B981', 3),
  ('Business', 'Conferences, networking, entrepreneurship', '#F59E0B', 4),
  ('Education', 'Workshops, seminars, learning sessions', '#8B5CF6', 5),
  ('Arts & Design', 'Art exhibitions, design workshops, creative events', '#F97316', 6),
  ('Social Cause', 'Volunteering, charity, social awareness', '#06B6D4', 7),
  ('Entertainment', 'Concerts, comedy, movies, entertainment shows', '#EF4444', 8),
  ('Sports & Fitness', 'Fitness challenges, wellness workshops', '#14B8A6', 9),
  ('Career & Development', 'Job fairs, skill development, mentoring', '#6366F1', 10)
ON CONFLICT DO NOTHING;
