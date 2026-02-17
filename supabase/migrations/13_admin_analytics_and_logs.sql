-- 22_admin_analytics_and_logs.sql
-- =============================================
-- HAPPENIN v1.1 — ADMIN ANALYTICS MIGRATIONS
-- =============================================

-- Admin activity logs (immutable)
CREATE TABLE IF NOT EXISTS admin_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_email TEXT NOT NULL REFERENCES users(email) ON DELETE CASCADE,
  action TEXT NOT NULL,
  resource_type TEXT,
  resource_id UUID,
  details JSONB,
  ip_address TEXT,
  created_at TIMESTAMP DEFAULT NOW() NOT NULL
);

-- User reports
CREATE TABLE IF NOT EXISTS user_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reported_by_email TEXT NOT NULL REFERENCES users(email),
  reported_user_email TEXT NOT NULL REFERENCES users(email),
  reason TEXT NOT NULL,
  description TEXT,
  status TEXT CHECK (status IN ('pending', 'reviewed', 'dismissed', 'action_taken')),
  action_taken TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  resolved_at TIMESTAMP
);

-- Event reports
CREATE TABLE IF NOT EXISTS event_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reported_by_email TEXT NOT NULL REFERENCES users(email),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  description TEXT,
  status TEXT CHECK (status IN ('pending', 'reviewed', 'dismissed', 'action_taken')),
  action_taken TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  resolved_at TIMESTAMP
);

-- Payment disputes
CREATE TABLE IF NOT EXISTS payment_disputes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id UUID NOT NULL REFERENCES payments(id),
  student_email TEXT NOT NULL REFERENCES users(email),
  reason TEXT NOT NULL,
  amount NUMERIC NOT NULL,
  status TEXT CHECK (status IN ('open', 'investigating', 'resolved', 'refunded')),
  admin_notes TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  resolved_at TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_admin_logs_action ON admin_logs(action, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_logs_email ON admin_logs(admin_email, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_reports_status ON user_reports(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_event_reports_status ON event_reports(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payment_disputes_status ON payment_disputes(status, created_at DESC);

-- Drop existing admin policies to avoid duplicates
DROP POLICY IF EXISTS "Only admins can read logs" ON admin_logs;
DROP POLICY IF EXISTS "Only admins can create logs" ON admin_logs;
DROP POLICY IF EXISTS "Only admins can read user reports" ON user_reports;
DROP POLICY IF EXISTS "Only admins can read event reports" ON event_reports;
DROP POLICY IF EXISTS "Only admins can read payment disputes" ON payment_disputes;
DROP POLICY IF EXISTS "Only admins can update user reports" ON user_reports;
DROP POLICY IF EXISTS "Only admins can update event reports" ON event_reports;
DROP POLICY IF EXISTS "Only admins can update payment disputes" ON payment_disputes;

-- Admin logs policies
CREATE POLICY "Only admins can read logs" ON admin_logs
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE email = auth.jwt()->>'email' AND role = 'admin'
    )
  );

CREATE POLICY "Only admins can create logs" ON admin_logs
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users WHERE email = auth.jwt()->>'email' AND role = 'admin'
    )
  );

-- User reports policies
CREATE POLICY "Only admins can read user reports" ON user_reports
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE email = auth.jwt()->>'email' AND role = 'admin'
    )
  );

CREATE POLICY "Only admins can update user reports" ON user_reports
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE email = auth.jwt()->>'email' AND role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users WHERE email = auth.jwt()->>'email' AND role = 'admin'
    )
  );

-- Event reports policies
CREATE POLICY "Only admins can read event reports" ON event_reports
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE email = auth.jwt()->>'email' AND role = 'admin'
    )
  );

CREATE POLICY "Only admins can update event reports" ON event_reports
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE email = auth.jwt()->>'email' AND role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users WHERE email = auth.jwt()->>'email' AND role = 'admin'
    )
  );

-- Payment disputes policies
CREATE POLICY "Only admins can read payment disputes" ON payment_disputes
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE email = auth.jwt()->>'email' AND role = 'admin'
    )
  );

CREATE POLICY "Only admins can update payment disputes" ON payment_disputes
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE email = auth.jwt()->>'email' AND role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users WHERE email = auth.jwt()->>'email' AND role = 'admin'
    )
  );
