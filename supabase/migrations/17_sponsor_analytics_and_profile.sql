-- 19_sponsor_analytics_and_profile.sql
-- =============================================
-- SPONSOR ANALYTICS & PROFILE FEATURES
-- =============================================

-- Sponsor Analytics: Track banner impressions and clicks
CREATE TABLE IF NOT EXISTS sponsor_analytics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sponsor_email TEXT REFERENCES sponsors_profile(email) ON DELETE SET NULL,
  event_id UUID REFERENCES events(id) ON DELETE SET NULL,
  type TEXT NOT NULL CHECK (type IN ('impression', 'click')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add banner_url to sponsors_profile for Sponsor Spotlight section
ALTER TABLE sponsors_profile
  ADD COLUMN IF NOT EXISTS banner_url TEXT;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_sponsor_analytics_sponsor ON sponsor_analytics(sponsor_email);
CREATE INDEX IF NOT EXISTS idx_sponsor_analytics_event ON sponsor_analytics(event_id);
CREATE INDEX IF NOT EXISTS idx_sponsor_analytics_type ON sponsor_analytics(type);
CREATE INDEX IF NOT EXISTS idx_sponsors_profile_banner_url ON sponsors_profile(banner_url);

-- Enable Row Level Security
ALTER TABLE sponsor_analytics ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Admins can read sponsor analytics" ON sponsor_analytics;
DROP POLICY IF EXISTS "Service role can insert sponsor analytics" ON sponsor_analytics;

-- Read access for admins only
CREATE POLICY "Admins can read sponsor analytics" ON sponsor_analytics
  FOR SELECT
  USING (auth.role() = 'service_role');

-- Insert allowed via server only (service role)
CREATE POLICY "Service role can insert sponsor analytics" ON sponsor_analytics
  FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

