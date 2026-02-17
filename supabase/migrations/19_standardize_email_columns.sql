-- 19_standardize_email_columns.sql
-- STANDARDIZE EMAIL COLUMN NAMING FOR BUSINESS CLARITY
-- Change generic "user_email" and "buyer_email" to role-specific names
-- This makes the business logic crystal clear and prevents confusion
-- Created: February 17, 2026

-- ============================================
-- REGISTRATIONS TABLE: user_email -> student_email
-- Business logic: Only students register for events
-- ============================================

-- Check if column exists before renaming
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'registrations' AND column_name = 'user_email'
  ) THEN
    ALTER TABLE registrations RENAME COLUMN user_email TO student_email;
  END IF;
END $$;

-- Update index name for clarity
DROP INDEX IF EXISTS idx_registrations_user;
CREATE INDEX IF NOT EXISTS idx_registrations_student ON registrations(student_email);

-- ============================================
-- PAYMENTS TABLE: Ensure student_email exists
-- Business logic: Only students make payments for events
-- ============================================

-- If payments has user_email instead of student_email, rename it
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'payments' AND column_name = 'user_email'
  ) THEN
    ALTER TABLE payments RENAME COLUMN user_email TO student_email;
  END IF;
END $$;

-- Ensure foreign key constraint is correct
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'payments_student_email_fkey' 
    AND table_name = 'payments'
  ) THEN
    -- Drop old constraint if exists with different name
    ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_user_email_fkey;
    -- Add new constraint
    ALTER TABLE payments ADD CONSTRAINT payments_student_email_fkey 
      FOREIGN KEY (student_email) REFERENCES users(email);
  END IF;
END $$;

-- ============================================
-- BULK TICKET PURCHASES: buyer_email -> student_email
-- Business logic: Students buy bulk tickets
-- ============================================

DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'bulk_ticket_purchases' AND column_name = 'buyer_email'
  ) THEN
    ALTER TABLE bulk_ticket_purchases RENAME COLUMN buyer_email TO student_email;
  END IF;
END $$;

-- Add foreign key if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'bulk_ticket_purchases_student_email_fkey'
    AND table_name = 'bulk_ticket_purchases'
  ) THEN
    ALTER TABLE bulk_ticket_purchases ADD CONSTRAINT bulk_ticket_purchases_student_email_fkey 
      FOREIGN KEY (student_email) REFERENCES users(email);
  END IF;
END $$;

-- ============================================
-- DOCUMENTATION COMMENT
-- ============================================

COMMENT ON COLUMN registrations.student_email IS 'Email of the student registering for the event (from users table with role=student)';
COMMENT ON COLUMN payments.student_email IS 'Email of the student making the payment (from users table with role=student)';
COMMENT ON COLUMN bulk_ticket_purchases.student_email IS 'Email of the student purchasing bulk tickets (from users table)';
COMMENT ON COLUMN events.organizer_email IS 'Email of the organizer creating the event (from users table with role=organizer)';

-- ============================================
-- VERIFICATION QUERY (uncomment to test)
-- ============================================

-- SELECT 
--   table_name,
--   column_name,
--   data_type
-- FROM information_schema.columns
-- WHERE table_schema = 'public'
--   AND column_name LIKE '%email'
--   AND table_name IN ('registrations', 'payments', 'bulk_ticket_purchases', 'events', 'fest_members')
-- ORDER BY table_name, column_name;
