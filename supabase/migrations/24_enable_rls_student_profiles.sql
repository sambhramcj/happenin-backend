CREATE TABLE IF NOT EXISTS student_profiles (
  student_email TEXT PRIMARY KEY REFERENCES users(email) ON DELETE CASCADE,
  full_name TEXT,
  dob DATE,
  college_name TEXT,
  college_email TEXT,
  phone_number TEXT,
  personal_email TEXT,
  profile_photo_url TEXT,
  branch TEXT,
  year_of_study INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE student_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Students read own profile" ON student_profiles;
CREATE POLICY "Students read own profile" ON student_profiles
  FOR SELECT
  USING (student_email = auth.jwt() ->> 'email');

DROP POLICY IF EXISTS "Students create own profile" ON student_profiles;
CREATE POLICY "Students create own profile" ON student_profiles
  FOR INSERT
  WITH CHECK (
    student_email = auth.jwt() ->> 'email' AND
    EXISTS (
      SELECT 1 FROM users
      WHERE users.email = auth.jwt() ->> 'email'
      AND users.role = 'student'
    )
  );

DROP POLICY IF EXISTS "Students update own profile" ON student_profiles;
CREATE POLICY "Students update own profile" ON student_profiles
  FOR UPDATE
  USING (student_email = auth.jwt() ->> 'email')
  WITH CHECK (student_email = auth.jwt() ->> 'email');

DROP POLICY IF EXISTS "Admins manage all student profiles" ON student_profiles;
CREATE POLICY "Admins manage all student profiles" ON student_profiles
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.email = auth.jwt() ->> 'email'
      AND users.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.email = auth.jwt() ->> 'email'
      AND users.role = 'admin'
    )
  );