-- 11_geolocation_and_spatial_indexing.sql
-- =============================================
-- GEOLOCATION & POSTGIS SPATIAL FEATURES
-- =============================================

-- Pre-check: Ensure payments table exists
CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_email TEXT NOT NULL REFERENCES users(email),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL,
  status TEXT CHECK (status IN ('pending', 'success', 'failed', 'refunded')) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Geolocation tables
CREATE TABLE IF NOT EXISTS colleges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE,
  city TEXT NOT NULL,
  state TEXT NOT NULL,
  country TEXT DEFAULT 'India',
  latitude NUMERIC(10, 8),
  longitude NUMERIC(11, 8),
  college_type TEXT CHECK (college_type IN ('public', 'private', 'autonomous', 'deemed')),
  contact_email TEXT,
  contact_phone TEXT,
  website_url TEXT,
  logo_url TEXT,
  is_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS favorite_colleges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_email TEXT NOT NULL REFERENCES users(email) ON DELETE CASCADE,
  college_id UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(student_email, college_id)
);

CREATE TABLE IF NOT EXISTS event_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL UNIQUE REFERENCES events(id) ON DELETE CASCADE,
  college_id UUID REFERENCES colleges(id),
  is_virtual BOOLEAN DEFAULT FALSE,
  venue_name TEXT,
  latitude NUMERIC(10, 8),
  longitude NUMERIC(11, 8),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Enable PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- Add missing columns if tables already existed
ALTER TABLE IF EXISTS colleges
  ADD COLUMN IF NOT EXISTS city TEXT,
  ADD COLUMN IF NOT EXISTS state TEXT,
  ADD COLUMN IF NOT EXISTS country TEXT DEFAULT 'India',
  ADD COLUMN IF NOT EXISTS latitude NUMERIC(10, 8),
  ADD COLUMN IF NOT EXISTS longitude NUMERIC(11, 8),
  ADD COLUMN IF NOT EXISTS location GEOMETRY(Point, 4326);

ALTER TABLE IF EXISTS event_locations
  ADD COLUMN IF NOT EXISTS latitude NUMERIC(10, 8),
  ADD COLUMN IF NOT EXISTS longitude NUMERIC(11, 8),
  ADD COLUMN IF NOT EXISTS location GEOMETRY(Point, 4326);

-- Update location column from latitude/longitude
UPDATE colleges 
SET location = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
WHERE location IS NULL AND latitude IS NOT NULL AND longitude IS NOT NULL;

UPDATE event_locations
SET location = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
WHERE location IS NULL AND latitude IS NOT NULL AND longitude IS NOT NULL;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_colleges_location ON colleges (latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_colleges_state_city ON colleges(state, city);
CREATE INDEX IF NOT EXISTS idx_colleges_spatial ON colleges USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_event_locations_college ON event_locations(college_id);
CREATE INDEX IF NOT EXISTS idx_event_locations_spatial ON event_locations USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_favorite_colleges_email ON favorite_colleges(student_email);

-- Drop existing policies to avoid duplicates
DROP POLICY IF EXISTS "Colleges are public" ON colleges;
DROP POLICY IF EXISTS "Colleges are viewable by everyone" ON colleges;
DROP POLICY IF EXISTS "Students can read own favorites" ON favorite_colleges;
DROP POLICY IF EXISTS "Students can add favorites" ON favorite_colleges;
DROP POLICY IF EXISTS "Students can remove favorites" ON favorite_colleges;
DROP POLICY IF EXISTS "Event locations are public" ON event_locations;
DROP POLICY IF EXISTS "Organizers can update event locations" ON event_locations;

-- Create RLS policies
CREATE POLICY "Colleges are public" ON colleges
  FOR SELECT TO anon, authenticated
  USING (true);

CREATE POLICY "Students can read own favorites" ON favorite_colleges
  FOR SELECT TO authenticated
  USING (student_email = auth.jwt()->>'email');

CREATE POLICY "Students can add favorites" ON favorite_colleges
  FOR INSERT TO authenticated
  WITH CHECK (student_email = auth.jwt()->>'email');

CREATE POLICY "Students can remove favorites" ON favorite_colleges
  FOR DELETE TO authenticated
  USING (student_email = auth.jwt()->>'email');

CREATE POLICY "Event locations are public" ON event_locations
  FOR SELECT TO anon, authenticated
  USING (true);

CREATE POLICY "Organizers can update event locations" ON event_locations
  FOR UPDATE TO authenticated
  USING (
    event_id IN (
      SELECT id FROM events WHERE organizer_email = auth.jwt()->>'email'
    )
  );

-- Function to find nearby colleges using PostGIS (much faster)
CREATE OR REPLACE FUNCTION get_nearby_colleges(
  user_lat DECIMAL,
  user_lng DECIMAL,
  radius_km INTEGER DEFAULT 10
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  city TEXT,
  state TEXT,
  latitude DECIMAL,
  longitude DECIMAL,
  distance_km DECIMAL
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id,
    c.name,
    c.city,
    c.state,
    c.latitude,
    c.longitude,
    ST_Distance(
      c.location::geography,
      ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography
    ) / 1000 AS distance_km
  FROM colleges c
  WHERE ST_DWithin(
    c.location::geography,
    ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography,
    radius_km * 1000
  )
  ORDER BY distance_km;
END;
$$ LANGUAGE plpgsql;

