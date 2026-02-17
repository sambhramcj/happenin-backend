-- 09_add_notifications_system.sql
-- ====================================
-- Notifications System Schema
-- ====================================
-- Supports: Push (urgent) + In-app (reference)
-- Role-specific notification rules

-- ============================================
-- 1. NOTIFICATION TABLES
-- ============================================

-- Push Notifications (smartphone/PWA alerts)
CREATE TABLE IF NOT EXISTS push_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_email VARCHAR(255) NOT NULL,
  recipient_role VARCHAR(50) NOT NULL, -- student, organizer, sponsor, admin
  title VARCHAR(200) NOT NULL,
  body TEXT NOT NULL,
  action_url VARCHAR(500),
  notification_type VARCHAR(50) NOT NULL, -- registration, payment, reminder, update, etc.
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  data JSONB, -- extra context (amount, sponsor_name, etc.)
  is_delivered BOOLEAN DEFAULT FALSE,
  delivered_at TIMESTAMP,
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMP,
  push_type VARCHAR(50) NOT NULL DEFAULT 'default', -- urgent, normal, low_priority
  scheduled_for TIMESTAMP, -- for T-24h, T-2h reminders
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- In-app Notifications (history, reference)
CREATE TABLE IF NOT EXISTS in_app_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_email VARCHAR(255) NOT NULL,
  recipient_role VARCHAR(50) NOT NULL,
  title VARCHAR(200) NOT NULL,
  body TEXT NOT NULL,
  action_url VARCHAR(500),
  notification_type VARCHAR(50) NOT NULL,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  icon_type VARCHAR(50), -- payment, certificate, volunteer, etc.
  data JSONB,
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMP,
  expires_at TIMESTAMP, -- auto-delete old notifications
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User Notification Preferences
CREATE TABLE IF NOT EXISTS notification_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_email VARCHAR(255) NOT NULL UNIQUE,
  user_role VARCHAR(50) NOT NULL,
  
  -- Push settings (role-specific)
  push_enabled BOOLEAN DEFAULT TRUE,
  push_payment BOOLEAN DEFAULT TRUE,
  push_reminders BOOLEAN DEFAULT TRUE,
  push_updates BOOLEAN DEFAULT TRUE,
  push_milestone_registrations BOOLEAN DEFAULT TRUE, -- organizers
  push_sponsorships BOOLEAN DEFAULT TRUE,
  push_admin_alerts BOOLEAN DEFAULT FALSE,
  
  -- In-app settings
  in_app_enabled BOOLEAN DEFAULT TRUE,
  in_app_history BOOLEAN DEFAULT TRUE,
  
  -- Quiet hours (no push, but in-app ok)
  quiet_hours_enabled BOOLEAN DEFAULT FALSE,
  quiet_start TIME,
  quiet_end TIME,
  
  -- Fest mode (batch notifications during fest week)
  fest_mode_enabled BOOLEAN DEFAULT TRUE,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Notification Logs (audit trail)
CREATE TABLE IF NOT EXISTS notification_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  push_notification_id UUID REFERENCES push_notifications(id) ON DELETE CASCADE,
  in_app_notification_id UUID REFERENCES in_app_notifications(id) ON DELETE CASCADE,
  recipient_email VARCHAR(255) NOT NULL,
  recipient_role VARCHAR(50),
  notification_type VARCHAR(50),
  status VARCHAR(50), -- sent, failed, pending
  error_message TEXT,
  delivery_provider VARCHAR(50), -- firebase, supabase_realtime, etc.
  attempt_count INT DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 2. INDEXES
-- ============================================

CREATE INDEX idx_push_notifications_recipient ON push_notifications(recipient_email);
CREATE INDEX idx_push_notifications_role ON push_notifications(recipient_role);
CREATE INDEX idx_push_notifications_created ON push_notifications(created_at DESC);
CREATE INDEX idx_push_notifications_scheduled ON push_notifications(scheduled_for) WHERE scheduled_for IS NOT NULL;
CREATE INDEX idx_in_app_notifications_recipient ON in_app_notifications(recipient_email);
CREATE INDEX idx_in_app_notifications_read ON in_app_notifications(is_read);
CREATE INDEX idx_notification_preferences_email ON notification_preferences(user_email);
CREATE INDEX idx_notification_logs_recipient ON notification_logs(recipient_email);

-- ============================================
-- 3. RLS POLICIES
-- ============================================

ALTER TABLE push_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE in_app_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_logs ENABLE ROW LEVEL SECURITY;

-- Push Notifications: Users can only read their own
CREATE POLICY push_notifications_self ON push_notifications
  FOR SELECT
  USING (recipient_email = auth.jwt()->>'email');

CREATE POLICY push_notifications_insert_service ON push_notifications
  FOR INSERT
  WITH CHECK (TRUE); -- Service role can insert

-- In-app Notifications: Users can read their own
CREATE POLICY in_app_notifications_self ON in_app_notifications
  FOR SELECT
  USING (recipient_email = auth.jwt()->>'email');

Create POLICY in_app_notifications_insert ON in_app_notifications
  FOR INSERT
  WITH CHECK (TRUE);

-- Preferences: Users manage their own
CREATE POLICY notification_preferences_self ON notification_preferences
  FOR SELECT
  USING (user_email = auth.jwt()->>'email');

CREATE POLICY notification_preferences_update_self ON notification_preferences
  FOR UPDATE
  USING (user_email = auth.jwt()->>'email');

CREATE POLICY notification_preferences_insert_self ON notification_preferences
  FOR INSERT
  WITH CHECK (user_email = auth.jwt()->>'email');

-- Logs: Service role only
CREATE POLICY notification_logs_insert_service ON notification_logs
  FOR INSERT
  WITH CHECK (TRUE);

-- ============================================
-- 4. NOTIFICATION TRIGGER FUNCTIONS
-- ============================================

-- Mark notification as delivered
CREATE OR REPLACE FUNCTION mark_notification_delivered(notification_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE push_notifications
  SET is_delivered = TRUE, delivered_at = CURRENT_TIMESTAMP
  WHERE id = notification_id;
END;
$$ LANGUAGE plpgsql;

-- Mark push notification as delivered (for webhooks)
CREATE OR REPLACE FUNCTION mark_push_delivered(notification_id UUID, delivery_provider VARCHAR)
RETURNS void AS $$
BEGIN
  UPDATE push_notifications
  SET is_delivered = TRUE, delivered_at = CURRENT_TIMESTAMP
  WHERE id = notification_id;
  
  INSERT INTO notification_logs (push_notification_id, recipient_email, status, delivery_provider)
  SELECT id, recipient_email, 'sent', delivery_provider
  FROM push_notifications WHERE id = notification_id;
END;
$$ LANGUAGE plpgsql;

-- Get user notification preferences (with defaults)
CREATE OR REPLACE FUNCTION get_user_preferences(user_email VARCHAR, user_role VARCHAR)
RETURNS TABLE(
  push_enabled BOOLEAN,
  push_payment BOOLEAN,
  push_reminders BOOLEAN,
  push_updates BOOLEAN,
  in_app_enabled BOOLEAN,
  quiet_hours_active BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(np.push_enabled, TRUE),
    COALESCE(np.push_payment, TRUE),
    COALESCE(np.push_reminders, TRUE),
    COALESCE(np.push_updates, TRUE),
    COALESCE(np.in_app_enabled, TRUE),
    CASE 
      WHEN COALESCE(np.quiet_hours_enabled, FALSE) = TRUE
        AND CURRENT_TIME BETWEEN np.quiet_start AND np.quiet_end
      THEN TRUE
      ELSE FALSE
    END
  FROM notification_preferences np
  WHERE np.user_email = user_email
  LIMIT 1;
  
  -- If no preferences found, return defaults
  IF NOT FOUND THEN
    RETURN QUERY SELECT TRUE, TRUE, TRUE, TRUE, TRUE, FALSE;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Auto-create preferences on first login
CREATE OR REPLACE FUNCTION create_default_notification_preferences()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO notification_preferences (user_email, user_role)
  VALUES (NEW.email, 'student')
  ON CONFLICT (user_email) DO NOTHING;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 5. EVENT-DRIVEN NOTIFICATION TRIGGERS
-- ============================================

-- A. STUDENT: Payment Success
CREATE OR REPLACE FUNCTION notify_student_payment_success()
RETURNS TRIGGER AS $$
DECLARE
  v_event_title VARCHAR;
  v_student_email VARCHAR;
BEGIN
  -- Only on payment completion
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    SELECT student_email INTO v_student_email FROM registrations WHERE id = NEW.registration_id;
    SELECT title INTO v_event_title FROM events WHERE id = NEW.event_id;
    
    INSERT INTO push_notifications (
      recipient_email, recipient_role, title, body, action_url,
      notification_type, event_id, push_type, data
    ) VALUES (
      v_student_email, 'student',
      'Payment Successful',
      'You are registered for ' || v_event_title || '. Ticket ready.',
      '/dashboard/student?tab=my-events',
      'payment_success',
      NEW.event_id,
      'urgent',
      jsonb_build_object('amount', NEW.amount, 'event_title', v_event_title)
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_student_payment_success
AFTER INSERT OR UPDATE ON registrations
FOR EACH ROW EXECUTE FUNCTION notify_student_payment_success();

-- B. STUDENT: 24h Event Reminder
CREATE OR REPLACE FUNCTION schedule_event_reminders()
RETURNS void AS $$
DECLARE
  v_event RECORD;
  v_registration RECORD;
  v_remind_at TIMESTAMP;
BEGIN
  -- Find events happening in 24 hours
  FOR v_event IN
    SELECT id, title, date, organizer_email
    FROM events
    WHERE date > CURRENT_TIMESTAMP
      AND date <= CURRENT_TIMESTAMP + INTERVAL '24 hours'
      AND date >= CURRENT_TIMESTAMP + INTERVAL '24 hours' - INTERVAL '1 hour'
  LOOP
    -- Send to all registered students
    FOR v_registration IN
      SELECT student_email FROM registrations WHERE event_id = v_event.id
    LOOP
      INSERT INTO push_notifications (
        recipient_email, recipient_role, title, body, action_url,
        notification_type, event_id, push_type, scheduled_for
      ) VALUES (
        v_registration.student_email, 'student',
        v_event.title || ' is tomorrow',
        v_event.title || ' is tomorrow at ' || TO_CHAR(v_event.date, 'HH:MM AM') || '. Don''t miss it!',
        '/events/' || v_event.id,
        'event_reminder_24h',
        v_event.id,
        'normal',
        v_event.date - INTERVAL '24 hours'
      );
    END LOOP;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- C. STUDENT: 2h Event Reminder (urgent)
CREATE OR REPLACE FUNCTION schedule_event_reminders_2h()
RETURNS void AS $$
BEGIN
  INSERT INTO push_notifications (
    recipient_email, recipient_role, title, body, action_url,
    notification_type, event_id, push_type, scheduled_for
  )
  SELECT
    r.student_email, 'student',
    e.title || ' starts in 2 hours',
    e.title || ' starts in 2 hours. Open your ticket.',
    '/dashboard/student?tab=my-events',
    'event_reminder_2h',
    e.id,
    'urgent',
    e.date - INTERVAL '2 hours'
  FROM events e
  INNER JOIN registrations r ON r.event_id = e.id
  WHERE e.date > CURRENT_TIMESTAMP
    AND e.date <= CURRENT_TIMESTAMP + INTERVAL '2 hours'
    AND e.date >= CURRENT_TIMESTAMP + INTERVAL '2 hours' - INTERVAL '1 hour';
END;
$$ LANGUAGE plpgsql;

-- D. ORGANIZER: First Registration
CREATE OR REPLACE FUNCTION notify_organizer_first_registration()
RETURNS TRIGGER AS $$
DECLARE
  v_event_title VARCHAR;
  v_organizer_email VARCHAR;
  v_reg_count INT;
BEGIN
  SELECT title, organizer_email INTO v_event_title, v_organizer_email
  FROM events WHERE id = NEW.event_id;
  
  SELECT COUNT(*) INTO v_reg_count FROM registrations WHERE event_id = NEW.event_id;
  
  -- Only on first registration
  IF v_reg_count = 1 THEN
    INSERT INTO push_notifications (
      recipient_email, recipient_role, title, body, action_url,
      notification_type, event_id, push_type
    ) VALUES (
      v_organizer_email, 'organizer',
      'First registration!',
      '🎉 First registration for ' || v_event_title || '.',
      '/dashboard/organizer?tab=events&event=' || NEW.event_id,
      'first_registration',
      NEW.event_id,
      'normal'
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_organizer_first_registration
AFTER INSERT ON registrations
FOR EACH ROW EXECUTE FUNCTION notify_organizer_first_registration();

-- E. ORGANIZER: Registration Milestones (10, 50, 100)
CREATE OR REPLACE FUNCTION notify_organizer_registration_milestone()
RETURNS TRIGGER AS $$
DECLARE
  v_event_title VARCHAR;
  v_organizer_email VARCHAR;
  v_reg_count INT;
  v_milestone INT;
BEGIN
  SELECT title, organizer_email INTO v_event_title, v_organizer_email
  FROM events WHERE id = NEW.event_id;
  
  SELECT COUNT(*) INTO v_reg_count FROM registrations WHERE event_id = NEW.event_id;
  
  -- Check for milestones
  IF v_reg_count IN (10, 50, 100, 250, 500) THEN
    INSERT INTO push_notifications (
      recipient_email, recipient_role, title, body, action_url,
      notification_type, event_id, push_type, data
    ) VALUES (
      v_organizer_email, 'organizer',
      v_event_title || ' crossed ' || v_reg_count || ' registrations',
      '🔥 ' || v_event_title || ' just hit ' || v_reg_count || ' registrations!',
      '/dashboard/organizer?tab=events&event=' || NEW.event_id,
      'registration_milestone',
      NEW.event_id,
      'normal',
      jsonb_build_object('milestone', v_reg_count)
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_organizer_registration_milestone
AFTER INSERT ON registrations
FOR EACH ROW EXECUTE FUNCTION notify_organizer_registration_milestone();

-- F. ORGANIZER: Event Day Reminder
CREATE OR REPLACE FUNCTION notify_organizer_event_day()
RETURNS void AS $$
BEGIN
  INSERT INTO push_notifications (
    recipient_email, recipient_role, title, body, action_url,
    notification_type, event_id, push_type
  )
  SELECT
    e.organizer_email, 'organizer',
    e.title || ' is happening today',
    'Today is ' || e.title || '. ' || (SELECT COUNT(*) FROM registrations WHERE event_id = e.id) || ' students registered.',
    '/dashboard/organizer?tab=events&event=' || e.id,
    'event_day_reminder',
    e.id,
    'urgent'
  FROM events e
  WHERE DATE(e.date) = CURRENT_DATE
    AND NOT EXISTS (
      SELECT 1 FROM push_notifications 
      WHERE event_id = e.id 
        AND notification_type = 'event_day_reminder'
        AND DATE(created_at) = CURRENT_DATE
    );
END;
$$ LANGUAGE plpgsql;

-- G. ORGANIZER: New Volunteer Application
CREATE OR REPLACE FUNCTION notify_organizer_volunteer_application()
RETURNS TRIGGER AS $$
DECLARE
  v_event_title VARCHAR;
  v_organizer_email VARCHAR;
BEGIN
  SELECT e.title, e.organizer_email INTO v_event_title, v_organizer_email
  FROM events e WHERE e.id = NEW.event_id;
  
  INSERT INTO push_notifications (
    recipient_email, recipient_role, title, body, action_url,
    notification_type, event_id, push_type
  ) VALUES (
    v_organizer_email, 'organizer',
    'New volunteer application',
    'New volunteer applied for ' || NEW.role || ' in ' || v_event_title || '.',
    '/dashboard/organizer?tab=events&event=' || NEW.event_id || '&view=volunteers',
    'volunteer_application',
    NEW.event_id,
    'normal'
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- H. SPONSOR: Payment Received
CREATE OR REPLACE FUNCTION notify_admin_sponsor_payment()
RETURNS TRIGGER AS $$
DECLARE
  v_sponsor_name VARCHAR;
  v_amount NUMERIC;
  v_event_title VARCHAR;
BEGIN
  -- Only on new confirmed deal
  IF NEW.status = 'confirmed' AND (OLD.status IS NULL OR OLD.status != 'confirmed') THEN
    SELECT sp.company_name, sd.amount_paid, e.title
    INTO v_sponsor_name, v_amount, v_event_title
    FROM sponsorship_deals sd
    INNER JOIN sponsors_profile sp ON sp.email = sd.sponsor_id
    INNER JOIN events e ON e.id = sd.event_id
    WHERE sd.id = NEW.id;
    
    -- Notify admin (platform revenue alert)
    INSERT INTO push_notifications (
      recipient_email, recipient_role, title, body, action_url,
      notification_type, event_id, push_type, data
    ) VALUES (
      'admin@happenin.app', 'admin',
      '₹' || (v_amount * 0.20)::INT || ' sponsorship platform fee',
      v_sponsor_name || ' confirmed ' || v_event_title || ' sponsorship.',
      '/dashboard/admin?tab=sponsorships',
      'sponsor_payment_received',
      NEW.event_id,
      'normal',
      jsonb_build_object('amount', v_amount, 'sponsor', v_sponsor_name, 'platform_fee', v_amount * 0.20)
    );
    
    -- Notify organizer
    INSERT INTO push_notifications (
      recipient_email, recipient_role, title, body, action_url,
      notification_type, event_id, push_type, data
    ) SELECT
      e.organizer_email, 'organizer',
      '₹' || (v_amount * 0.80)::INT || ' sponsorship earned',
      v_sponsor_name || ' sponsored ' || v_event_title || ' with ' || v_amount || '.',
      '/dashboard/organizer?tab=sponsorships',
      'sponsor_payment_received',
      NEW.event_id,
      'normal',
      jsonb_build_object('amount', v_amount * 0.80, 'sponsor', v_sponsor_name)
    FROM events e WHERE e.id = NEW.event_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 6. CLEANUP & EXPIRY
-- ============================================

-- Archive old notifications (keep 90 days)
CREATE OR REPLACE FUNCTION archive_old_notifications()
RETURNS void AS $$
BEGIN
  DELETE FROM in_app_notifications
  WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '90 days';
  
  DELETE FROM push_notifications
  WHERE is_read = TRUE 
    AND created_at < CURRENT_TIMESTAMP - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 7. HELPER FUNCTIONS
-- ============================================

-- Send immediate notification (for API calls)
CREATE OR REPLACE FUNCTION send_notification(
  p_recipient_email VARCHAR,
  p_recipient_role VARCHAR,
  p_title VARCHAR,
  p_body VARCHAR,
  p_action_url VARCHAR DEFAULT NULL,
  p_notification_type VARCHAR DEFAULT 'general',
  p_event_id UUID DEFAULT NULL,
  p_push_type VARCHAR DEFAULT 'normal'
)
RETURNS UUID AS $$
DECLARE
  v_notification_id UUID;
BEGIN
  INSERT INTO push_notifications (
    recipient_email, recipient_role, title, body, action_url,
    notification_type, event_id, push_type
  ) VALUES (
    p_recipient_email, p_recipient_role, p_title, p_body, p_action_url,
    p_notification_type, p_event_id, p_push_type
  ) RETURNING id INTO v_notification_id;
  
  RETURN v_notification_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 8. GRANTS
-- ============================================

GRANT SELECT, INSERT ON push_notifications TO postgres;
GRANT SELECT, UPDATE ON in_app_notifications TO postgres;
GRANT SELECT, INSERT, UPDATE ON notification_preferences TO postgres;
GRANT SELECT, INSERT ON notification_logs TO postgres;

-- ============================================
-- END NOTIFICATIONS SCHEMA
-- ============================================
