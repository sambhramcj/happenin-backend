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

ALTER TABLE student_profiles
ADD COLUMN IF NOT EXISTS branch TEXT,
ADD COLUMN IF NOT EXISTS year_of_study INTEGER;