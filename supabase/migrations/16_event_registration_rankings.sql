-- 30_event_registration_rankings.sql
-- Helper function to fetch top events by confirmed registrations

CREATE OR REPLACE FUNCTION get_top_events_by_registrations(
  p_college_id UUID,
  p_limit INT
)
RETURNS TABLE (
  id UUID,
  title TEXT,
  banner_url TEXT,
  start_date TIMESTAMP WITH TIME ZONE,
  ticket_price NUMERIC,
  category TEXT,
  college_id UUID,
  registration_count BIGINT
) AS $$
  SELECT
    e.id,
    e.title,
    e.banner_url,
    e.start_date,
    e.ticket_price,
    e.category,
    e.college_id,
    COUNT(r.id) FILTER (WHERE r.status = 'confirmed') AS registration_count
  FROM events e
  LEFT JOIN registrations r ON r.event_id = e.id
  WHERE e.is_published = true
    AND (p_college_id IS NULL OR e.college_id = p_college_id)
  GROUP BY e.id
  ORDER BY registration_count DESC
  LIMIT p_limit;
$$ LANGUAGE SQL STABLE;
