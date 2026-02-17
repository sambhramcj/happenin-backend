-- 14_festival_enhancements.sql
-- Festival Submissions System
-- Table for tracking event submissions to festivals

CREATE TABLE IF NOT EXISTS festival_submissions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  fest_id UUID NOT NULL REFERENCES fests(id) ON DELETE CASCADE,
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  submitted_by_email TEXT NOT NULL,
  submission_status TEXT DEFAULT 'pending' CHECK (submission_status IN ('pending', 'approved', 'rejected')),
  rejection_reason TEXT,
  reviewed_by_email TEXT,
  submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  reviewed_at TIMESTAMP WITH TIME ZONE,
  UNIQUE(fest_id, event_id)
);

-- Festival Analytics Table
CREATE TABLE IF NOT EXISTS festival_analytics (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  fest_id UUID NOT NULL REFERENCES fests(id) ON DELETE CASCADE,
  total_events INTEGER DEFAULT 0,
  total_registrations INTEGER DEFAULT 0,
  total_revenue DECIMAL(10, 2) DEFAULT 0,
  total_attendance INTEGER DEFAULT 0,
  unique_participants INTEGER DEFAULT 0,
  calculated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Festival Sponsorship Tiers
CREATE TABLE IF NOT EXISTS festival_sponsorships (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  fest_id UUID NOT NULL REFERENCES fests(id) ON DELETE CASCADE,
  sponsor_name TEXT NOT NULL,
  sponsor_logo_url TEXT,
  sponsor_website TEXT,
  tier TEXT NOT NULL CHECK (tier IN ('title', 'platinum', 'gold', 'silver', 'bronze', 'partner')),
  amount DECIMAL(10, 2),
  benefits JSONB,
  visibility_level INTEGER DEFAULT 1,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_festival_submissions_fest ON festival_submissions(fest_id);
CREATE INDEX IF NOT EXISTS idx_festival_submissions_event ON festival_submissions(event_id);
CREATE INDEX IF NOT EXISTS idx_festival_submissions_status ON festival_submissions(submission_status);
CREATE INDEX IF NOT EXISTS idx_festival_analytics_fest ON festival_analytics(fest_id);
CREATE INDEX IF NOT EXISTS idx_festival_sponsorships_fest ON festival_sponsorships(fest_id);
CREATE INDEX IF NOT EXISTS idx_festival_sponsorships_tier ON festival_sponsorships(tier);

-- Row Level Security
ALTER TABLE festival_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE festival_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE festival_sponsorships ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Anyone can view approved submissions" ON festival_submissions;
DROP POLICY IF EXISTS "Users can submit events" ON festival_submissions;
DROP POLICY IF EXISTS "Festival leaders can review submissions" ON festival_submissions;
DROP POLICY IF EXISTS "Anyone can view festival analytics" ON festival_analytics;
DROP POLICY IF EXISTS "Anyone can view festival sponsorships" ON festival_sponsorships;
DROP POLICY IF EXISTS "Festival leaders can manage sponsorships" ON festival_sponsorships;

-- Submissions policies
CREATE POLICY "Anyone can view approved submissions"
  ON festival_submissions FOR SELECT
  USING (submission_status = 'approved');

CREATE POLICY "Users can submit events"
  ON festival_submissions FOR INSERT
  WITH CHECK (submitted_by_email = auth.jwt() ->> 'email');

CREATE POLICY "Festival leaders can review submissions"
  ON festival_submissions FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM fest_members 
      WHERE fest_id = festival_submissions.fest_id 
      AND member_email = auth.jwt() ->> 'email'
    )
  );

-- Analytics policies
CREATE POLICY "Anyone can view festival analytics"
  ON festival_analytics FOR SELECT
  USING (true);

-- Sponsorships policies
CREATE POLICY "Anyone can view festival sponsorships"
  ON festival_sponsorships FOR SELECT
  USING (true);

CREATE POLICY "Festival leaders can manage sponsorships"
  ON festival_sponsorships FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM fest_members 
      WHERE fest_id = festival_sponsorships.fest_id 
      AND member_email = auth.jwt() ->> 'email'
    )
  );
