-- 13_create_fest_system.sql
-- Fest Hierarchical System Migrations
-- v1.3.0 (January 2026)

-- Create fests table
CREATE TABLE IF NOT EXISTS fests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  banner_image VARCHAR(500),
  start_date TIMESTAMP NOT NULL,
  end_date TIMESTAMP NOT NULL,
  location VARCHAR(255),
  college_id UUID REFERENCES colleges(id) ON DELETE SET NULL,
  core_team_leader_email VARCHAR(255) NOT NULL,
  status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'cancelled', 'archived')),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create fest_events junction table
CREATE TABLE IF NOT EXISTS fest_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fest_id UUID NOT NULL REFERENCES fests(id) ON DELETE CASCADE,
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  submitted_by_email VARCHAR(255) NOT NULL,
  approval_status VARCHAR(50) DEFAULT 'pending' CHECK (approval_status IN ('pending', 'approved', 'rejected')),
  rejection_reason TEXT,
  requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  approved_at TIMESTAMP,
  approved_by_email VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(fest_id, event_id)
);

-- Create fest_members table (for core team)
CREATE TABLE IF NOT EXISTS fest_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fest_id UUID NOT NULL REFERENCES fests(id) ON DELETE CASCADE,
  member_email VARCHAR(255) NOT NULL,
  role VARCHAR(50) DEFAULT 'member' CHECK (role IN ('leader', 'member')),
  joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(fest_id, member_email)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_fests_college_id ON fests(college_id);
CREATE INDEX IF NOT EXISTS idx_fests_leader_email ON fests(core_team_leader_email);
CREATE INDEX IF NOT EXISTS idx_fest_events_fest_id ON fest_events(fest_id);
CREATE INDEX IF NOT EXISTS idx_fest_events_event_id ON fest_events(event_id);
CREATE INDEX IF NOT EXISTS idx_fest_events_status ON fest_events(approval_status);
CREATE INDEX IF NOT EXISTS idx_fest_members_fest_id ON fest_members(fest_id);

-- Update events table to support fest_id (optional foreign key)
ALTER TABLE events ADD COLUMN IF NOT EXISTS fest_id UUID REFERENCES fests(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_events_fest_id ON events(fest_id);
