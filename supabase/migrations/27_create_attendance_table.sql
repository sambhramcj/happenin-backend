-- 27_create_attendance_table.sql
-- Add attendance tracking table used by organizer QR scanning flow

CREATE TABLE IF NOT EXISTS attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  registration_id UUID REFERENCES registrations(id) ON DELETE SET NULL,
  ticket_id UUID REFERENCES bulk_tickets(id) ON DELETE SET NULL,
  student_email TEXT NOT NULL REFERENCES users(email) ON DELETE CASCADE,
  organizer_email TEXT NOT NULL REFERENCES users(email) ON DELETE CASCADE,
  scanned_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  CONSTRAINT attendance_unique_registration_per_event UNIQUE (event_id, registration_id)
);

CREATE INDEX IF NOT EXISTS idx_attendance_event_id ON attendance(event_id);
CREATE INDEX IF NOT EXISTS idx_attendance_student_email ON attendance(student_email);
CREATE INDEX IF NOT EXISTS idx_attendance_organizer_email ON attendance(organizer_email);
CREATE INDEX IF NOT EXISTS idx_attendance_scanned_at ON attendance(scanned_at DESC);

ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Organizers manage own event attendance" ON attendance;
CREATE POLICY "Organizers manage own event attendance"
ON attendance
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM events
    WHERE events.id = attendance.event_id
      AND events.organizer_email = auth.jwt() ->> 'email'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM events
    WHERE events.id = attendance.event_id
      AND events.organizer_email = auth.jwt() ->> 'email'
  )
);

DROP POLICY IF EXISTS "Students view own attendance" ON attendance;
CREATE POLICY "Students view own attendance"
ON attendance
FOR SELECT
TO authenticated
USING (student_email = auth.jwt() ->> 'email');

DROP POLICY IF EXISTS "Admins manage all attendance" ON attendance;
CREATE POLICY "Admins manage all attendance"
ON attendance
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM users
    WHERE users.email = auth.jwt() ->> 'email'
      AND users.role = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM users
    WHERE users.email = auth.jwt() ->> 'email'
      AND users.role = 'admin'
  )
);
