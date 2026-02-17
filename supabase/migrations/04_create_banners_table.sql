-- 07_create_banners_table.sql
-- Create banners table
CREATE TABLE IF NOT EXISTS banners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  type text NOT NULL CHECK (type IN ('fest', 'event', 'sponsor')),
  event_id uuid REFERENCES events(id) ON DELETE CASCADE,
  sponsor_email text REFERENCES sponsors_profile(email) ON DELETE CASCADE,
  image_url text NOT NULL,
  placement text NOT NULL CHECK (placement IN ('home_top', 'home_mid', 'event_page')),
  link_type text NOT NULL CHECK (link_type IN ('internal_event', 'internal_sponsor')),
  link_target_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  priority integer DEFAULT 0,
  start_date timestamp with time zone,
  end_date timestamp with time zone,
  created_by text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  views_count integer DEFAULT 0,
  clicks_count integer DEFAULT 0
);

-- Create indexes for common queries
CREATE INDEX idx_banners_status ON banners(status);
CREATE INDEX idx_banners_type ON banners(type);
CREATE INDEX idx_banners_placement ON banners(placement);
CREATE INDEX idx_banners_created_by ON banners(created_by);
CREATE INDEX idx_banners_event_id ON banners(event_id);
CREATE INDEX idx_banners_sponsor_email ON banners(sponsor_email);
CREATE INDEX idx_banners_start_date ON banners(start_date);
CREATE INDEX idx_banners_active ON banners(status, start_date, end_date);

-- Enable RLS
ALTER TABLE banners ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Organizers can insert banners for their own events
CREATE POLICY "Organizers can insert event banners" ON banners
  FOR INSERT
  WITH CHECK (
    auth.uid()::text = created_by AND
    type = 'event' AND
    event_id IN (
      SELECT id FROM events WHERE organizer_email = auth.jwt()->>'email'
    )
  );

-- RLS Policy: Sponsors can insert banners for their own sponsorships
CREATE POLICY "Sponsors can insert sponsor banners" ON banners
  FOR INSERT
  WITH CHECK (
    auth.uid()::text = created_by AND
    type = 'sponsor' AND
    sponsor_email = auth.jwt()->>'email'
  );

-- RLS Policy: Organizers can view their own event banners
CREATE POLICY "Organizers can view their event banners" ON banners
  FOR SELECT
  USING (
    type = 'event' AND
    event_id IN (
      SELECT id FROM events WHERE organizer_email = auth.jwt()->>'email'
    )
  );

-- RLS Policy: Sponsors can view their own banners
CREATE POLICY "Sponsors can view their banners" ON banners
  FOR SELECT
  USING (
    type = 'sponsor' AND
    sponsor_email = auth.jwt()->>'email'
  );

-- RLS Policy: Admin can view all unapproved banners
CREATE POLICY "Admin can view all banners" ON banners
  FOR SELECT
  USING (
    auth.jwt()->>'role' = 'admin'
  );

-- RLS Policy: Admin can update banners (approve/reject)
CREATE POLICY "Admin can update banners" ON banners
  FOR UPDATE
  USING (
    auth.jwt()->>'role' = 'admin'
  );

-- RLS Policy: Admin can delete banners
CREATE POLICY "Admin can delete banners" ON banners
  FOR DELETE
  USING (
    auth.jwt()->>'role' = 'admin'
  );

-- RLS Policy: Anyone can view approved, active banners
CREATE POLICY "Approved banners are viewable by all" ON banners
  FOR SELECT
  USING (
    status = 'approved' AND
    (start_date IS NULL OR start_date <= now()) AND
    (end_date IS NULL OR end_date > now())
  );

-- RLS Policy: Organizers/Sponsors can update their own pending banners
CREATE POLICY "Creators can update pending banners" ON banners
  FOR UPDATE
  USING (
    auth.uid()::text = created_by AND
    status = 'pending'
  );

-- RLS Policy: Creators can delete pending banners
CREATE POLICY "Creators can delete pending banners" ON banners
  FOR DELETE
  USING (
    auth.uid()::text = created_by AND
    status = 'pending'
  );

-- Create banner analytics table
CREATE TABLE IF NOT EXISTS banner_analytics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  banner_id uuid NOT NULL REFERENCES banners(id) ON DELETE CASCADE,
  event_type text CHECK (event_type IN ('view', 'click')),
  user_email text,
  created_at timestamp with time zone DEFAULT now()
);

-- Create index for analytics queries
CREATE INDEX idx_banner_analytics_banner_id ON banner_analytics(banner_id);
CREATE INDEX idx_banner_analytics_event_type ON banner_analytics(event_type);
CREATE INDEX idx_banner_analytics_created_at ON banner_analytics(created_at);

-- Function to increment view count
CREATE OR REPLACE FUNCTION increment_banner_views(banner_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE banners SET views_count = views_count + 1 WHERE id = banner_id;
  INSERT INTO banner_analytics (banner_id, event_type) VALUES (banner_id, 'view');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to increment click count
CREATE OR REPLACE FUNCTION increment_banner_clicks(banner_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE banners SET clicks_count = clicks_count + 1 WHERE id = banner_id;
  INSERT INTO banner_analytics (banner_id, event_type) VALUES (banner_id, 'click');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
