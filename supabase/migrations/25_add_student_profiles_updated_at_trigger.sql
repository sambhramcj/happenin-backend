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

CREATE OR REPLACE FUNCTION set_student_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_student_profiles_updated_at ON student_profiles;
CREATE TRIGGER trg_student_profiles_updated_at
  BEFORE UPDATE ON student_profiles
  FOR EACH ROW
  EXECUTE FUNCTION set_student_profiles_updated_at();