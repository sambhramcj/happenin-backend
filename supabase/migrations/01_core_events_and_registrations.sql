-- 01_core_events_and_registrations.sql
-- Core Events System Tables
-- Migration 0: Create events table
CREATE TABLE IF NOT EXISTS events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  date TIMESTAMP NOT NULL,
  venue TEXT NOT NULL,
  price DECIMAL(10, 2) DEFAULT 0,
  organizer_email TEXT NOT NULL,
  needs_volunteers BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Migration 0.5: Create registrations table
CREATE TABLE IF NOT EXISTS registrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_email TEXT NOT NULL,
  registration_date TIMESTAMP DEFAULT NOW(),
  status TEXT DEFAULT 'registered' CHECK (status IN ('registered', 'checked_in', 'cancelled')),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for events and registrations
CREATE INDEX IF NOT EXISTS idx_events_organizer ON events(organizer_email);
CREATE INDEX IF NOT EXISTS idx_events_date ON events(date);
CREATE INDEX IF NOT EXISTS idx_registrations_event ON registrations(event_id);
CREATE INDEX IF NOT EXISTS idx_registrations_user ON registrations(user_email);

-- Migration 1: Create users table if it doesn't exist
CREATE TABLE IF NOT EXISTS users (
  email TEXT PRIMARY KEY,
  password TEXT,
  role TEXT NOT NULL CHECK (role IN ('student', 'organizer', 'admin')),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Migration 1: Add colleges table
CREATE TABLE IF NOT EXISTS colleges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  domain TEXT NOT NULL UNIQUE,
  verified BOOLEAN DEFAULT FALSE,
  logo_url TEXT,
  admin_email TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for colleges table
CREATE INDEX IF NOT EXISTS idx_colleges_domain ON colleges(domain);
CREATE INDEX IF NOT EXISTS idx_colleges_verified ON colleges(verified);

-- Migration 2: Add college_id and password_hash to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS college_id UUID REFERENCES colleges(id) ON DELETE SET NULL;

ALTER TABLE users
ADD COLUMN IF NOT EXISTS password_hash TEXT;

-- Create index on college_id
CREATE INDEX IF NOT EXISTS idx_users_college ON users(college_id);

-- Migration 3: Add RLS policies to colleges table
ALTER TABLE colleges ENABLE ROW LEVEL SECURITY;

-- Public can read colleges
DROP POLICY IF EXISTS "Public read colleges" ON colleges;
CREATE POLICY "Public read colleges" ON colleges
  FOR SELECT
  TO public
  USING (true);

-- Only admins can insert/update/delete colleges
DROP POLICY IF EXISTS "Admin manage colleges" ON colleges;
CREATE POLICY "Admin manage colleges" ON colleges
  FOR ALL
  TO authenticated
  USING (
    (SELECT role FROM users WHERE email = auth.jwt() ->> 'email') = 'admin'
  )
  WITH CHECK (
    (SELECT role FROM users WHERE email = auth.jwt() ->> 'email') = 'admin'
  );

-- Migration 4: Insert default colleges
INSERT INTO colleges (name, domain, verified) VALUES
  ('National Institute of Technology Karnataka', 'nitk.edu.in', true),
  ('Indian Institute of Technology Bombay', 'iitb.ac.in', true),
  ('BMS College of Engineering', 'bmsce.ac.in', true)
ON CONFLICT (domain) DO NOTHING;

-- Migration 5: Update password_hash for existing test users (dev only)
-- NOTE: Use bcrypt hash in production
UPDATE users SET password_hash = '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36P4/tvVe' 
WHERE email IN ('student@test.com', 'organizer@test.com', 'admin@test.com') AND password_hash IS NULL;
