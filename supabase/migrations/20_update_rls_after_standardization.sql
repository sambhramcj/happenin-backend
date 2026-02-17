-- 20_update_rls_after_standardization.sql
-- CREATE ALL RLS POLICIES WITH STANDARDIZED EMAIL COLUMN NAMES
-- Run after migration 18 (enabled RLS) and 19 (standardized columns)
-- Created: February 17, 2026

-- ============================================
-- USERS TABLE POLICIES
-- ============================================

-- Users can read own data
DROP POLICY IF EXISTS "Users read own data" ON users;
CREATE POLICY "Users read own data" ON users
  FOR SELECT TO authenticated
  USING (email = auth.jwt() ->> 'email');

-- Admins can read all users
DROP POLICY IF EXISTS "Admins read all users" ON users;
CREATE POLICY "Admins read all users" ON users
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.email = auth.jwt() ->> 'email' 
      AND u.role = 'admin'
    )
  );

-- Users can update own data
DROP POLICY IF EXISTS "Users update own data" ON users;
CREATE POLICY "Users update own data" ON users
  FOR UPDATE TO authenticated
  USING (email = auth.jwt() ->> 'email');

-- ============================================
-- EVENTS TABLE POLICIES
-- ============================================

-- Everyone can read published events
DROP POLICY IF EXISTS "Public read events" ON events;
CREATE POLICY "Public read events" ON events
  FOR SELECT TO public
  USING (true);

-- Organizers can create events
DROP POLICY IF EXISTS "Organizers create events" ON events;
CREATE POLICY "Organizers create events" ON events
  FOR INSERT TO authenticated
  WITH CHECK (
    organizer_email = auth.jwt() ->> 'email' AND
    EXISTS (SELECT 1 FROM users WHERE email = auth.jwt() ->> 'email' AND role IN ('organizer', 'admin'))
  );

-- Organizers can update own events
DROP POLICY IF EXISTS "Organizers update own events" ON events;
CREATE POLICY "Organizers update own events" ON events
  FOR UPDATE TO authenticated
  USING (organizer_email = auth.jwt() ->> 'email');

-- Organizers can delete own events
DROP POLICY IF EXISTS "Organizers delete own events" ON events;
CREATE POLICY "Organizers delete own events" ON events
  FOR DELETE TO authenticated
  USING (organizer_email = auth.jwt() ->> 'email');

-- ============================================
-- REGISTRATIONS TABLE POLICIES
-- ============================================

-- Students can read own registrations (now using student_email)
DROP POLICY IF EXISTS "Students read own registrations" ON registrations;
CREATE POLICY "Students read own registrations" ON registrations
  FOR SELECT TO authenticated
  USING (student_email = auth.jwt() ->> 'email');

-- Students can create registrations
DROP POLICY IF EXISTS "Students create registrations" ON registrations;
CREATE POLICY "Students create registrations" ON registrations
  FOR INSERT TO authenticated
  WITH CHECK (student_email = auth.jwt() ->> 'email');

-- Organizers can read registrations for their events
DROP POLICY IF EXISTS "Organizers read event registrations" ON registrations;
CREATE POLICY "Organizers read event registrations" ON registrations
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM events e 
      WHERE e.id = registrations.event_id 
      AND e.organizer_email = auth.jwt() ->> 'email'
    )
  );

-- ============================================
-- PAYMENTS TABLE POLICIES  
-- ============================================

-- Students can read own payments (now using student_email)
DROP POLICY IF EXISTS "Students read own payments" ON payments;
CREATE POLICY "Students read own payments" ON payments
  FOR SELECT TO authenticated
  USING (student_email = auth.jwt() ->> 'email');

-- Service role can insert payments (for Razorpay webhooks)
DROP POLICY IF EXISTS "Service role insert payments" ON payments;
CREATE POLICY "Service role insert payments" ON payments
  FOR INSERT TO service_role
  WITH CHECK (true);

-- Admins can read all payments
DROP POLICY IF EXISTS "Admins read all payments" ON payments;
CREATE POLICY "Admins read all payments" ON payments
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM users WHERE email = auth.jwt() ->> 'email' AND role = 'admin')
  );

-- ============================================
-- FESTS TABLE POLICIES
-- ============================================

-- Everyone can read active fests
DROP POLICY IF EXISTS "Public read fests" ON fests;
CREATE POLICY "Public read fests" ON fests
  FOR SELECT TO public
  USING (status = 'active');

-- Fest leaders can create fests
DROP POLICY IF EXISTS "Leaders create fests" ON fests;
CREATE POLICY "Leaders create fests" ON fests
  FOR INSERT TO authenticated
  WITH CHECK (core_team_leader_email = auth.jwt() ->> 'email');

-- Fest leaders can update own fests
DROP POLICY IF EXISTS "Leaders update own fests" ON fests;
CREATE POLICY "Leaders update own fests" ON fests
  FOR UPDATE TO authenticated
  USING (core_team_leader_email = auth.jwt() ->> 'email');

-- Fest leaders can delete own fests
DROP POLICY IF EXISTS "Leaders delete own fests" ON fests;
CREATE POLICY "Leaders delete own fests" ON fests
  FOR DELETE TO authenticated
  USING (core_team_leader_email = auth.jwt() ->> 'email');

-- ============================================
-- FEST_EVENTS TABLE POLICIES
-- ============================================

-- Everyone can read approved fest events
DROP POLICY IF EXISTS "Public read approved fest events" ON fest_events;
CREATE POLICY "Public read approved fest events" ON fest_events
  FOR SELECT TO public
  USING (approval_status = 'approved');

-- Organizers can submit events to fests
DROP POLICY IF EXISTS "Organizers submit to fests" ON fest_events;
CREATE POLICY "Organizers submit to fests" ON fest_events
  FOR INSERT TO authenticated
  WITH CHECK (submitted_by_email = auth.jwt() ->> 'email');

-- Organizers can read own submissions
DROP POLICY IF EXISTS "Organizers read own submissions" ON fest_events;
CREATE POLICY "Organizers read own submissions" ON fest_events
  FOR SELECT TO authenticated
  USING (submitted_by_email = auth.jwt() ->> 'email');

-- Fest leaders can approve/reject submissions
DROP POLICY IF EXISTS "Leaders manage submissions" ON fest_events;
CREATE POLICY "Leaders manage submissions" ON fest_events
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM fests f 
      WHERE f.id = fest_events.fest_id 
      AND f.core_team_leader_email = auth.jwt() ->> 'email'
    )
  );

-- ============================================
-- FEST_MEMBERS TABLE POLICIES
-- ============================================

-- Fest members can read own membership
DROP POLICY IF EXISTS "Members read own membership" ON fest_members;
CREATE POLICY "Members read own membership" ON fest_members
  FOR SELECT TO authenticated
  USING (member_email = auth.jwt() ->> 'email');

-- Fest leaders can manage members
DROP POLICY IF EXISTS "Leaders manage members" ON fest_members;
CREATE POLICY "Leaders manage members" ON fest_members
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM fests f 
      WHERE f.id = fest_members.fest_id 
      AND f.core_team_leader_email = auth.jwt() ->> 'email'
    )
  );

-- ============================================
-- BULK TICKETS POLICIES
-- ============================================

-- Public can read ticket packs
DROP POLICY IF EXISTS "Public read bulk ticket packs" ON bulk_ticket_packs;
CREATE POLICY "Public read bulk ticket packs" ON bulk_ticket_packs
  FOR SELECT TO public
  USING (true);

-- Organizers can create bulk ticket packs
DROP POLICY IF EXISTS "Organizers create bulk packs" ON bulk_ticket_packs;
CREATE POLICY "Organizers create bulk packs" ON bulk_ticket_packs
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM events e 
      WHERE e.id = bulk_ticket_packs.event_id 
      AND e.organizer_email = auth.jwt() ->> 'email'
    )
  );

-- ============================================
-- BULK TICKET PURCHASES POLICIES
-- ============================================

-- Students can read own bulk purchases (now using student_email)
DROP POLICY IF EXISTS "Students read own bulk purchases" ON bulk_ticket_purchases;
CREATE POLICY "Students read own bulk purchases" ON bulk_ticket_purchases
  FOR SELECT TO authenticated
  USING (student_email = auth.jwt() ->> 'email');

-- Students can create bulk purchases
DROP POLICY IF EXISTS "Students create bulk purchases" ON bulk_ticket_purchases;
CREATE POLICY "Students create bulk purchases" ON bulk_ticket_purchases
  FOR INSERT TO authenticated
  WITH CHECK (student_email = auth.jwt() ->> 'email');

-- ============================================
-- SPONSORSHIPS POLICIES
-- ============================================

-- Public can read sponsorship packages
DROP POLICY IF EXISTS "Public read sponsorship packages" ON sponsorship_packages;
CREATE POLICY "Public read sponsorship packages" ON sponsorship_packages
  FOR SELECT TO public
  USING (true);

-- Sponsors can read own Razorpay orders (via deal reference)
DROP POLICY IF EXISTS "Sponsors read own orders" ON sponsorship_razorpay_orders;
CREATE POLICY "Sponsors read own orders" ON sponsorship_razorpay_orders
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM sponsorship_deals sd
      WHERE sd.id = sponsorship_razorpay_orders.sponsorship_deal_id
      AND sd.sponsor_id = auth.jwt() ->> 'email'
    )
  );

-- Service role can insert/update orders (from Razorpay webhooks)
DROP POLICY IF EXISTS "Service role manage orders" ON sponsorship_razorpay_orders;
CREATE POLICY "Service role manage orders" ON sponsorship_razorpay_orders
  FOR ALL TO service_role
  USING (true);

-- ============================================
-- EVENT CATEGORIES POLICIES
-- ============================================

-- Public can read event categories
DROP POLICY IF EXISTS "Public read event categories" ON event_categories;
CREATE POLICY "Public read event categories" ON event_categories
  FOR SELECT TO public
  USING (true);

-- Public can read event category mappings
DROP POLICY IF EXISTS "Public read category mappings" ON event_category_mapping;
CREATE POLICY "Public read category mappings" ON event_category_mapping
  FOR SELECT TO public
  USING (true);

-- ============================================
-- EVENT LOCATIONS POLICIES
-- ============================================

-- Public can read event locations
DROP POLICY IF EXISTS "Public read event locations" ON event_locations;
CREATE POLICY "Public read event locations" ON event_locations
  FOR SELECT TO public
  USING (true);

-- ============================================
-- REPORTS POLICIES
-- ============================================

-- Admins can read event reports
DROP POLICY IF EXISTS "Admins read event reports" ON event_reports;
CREATE POLICY "Admins read event reports" ON event_reports
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM users WHERE email = auth.jwt() ->> 'email' AND role = 'admin')
  );

-- Admins can update event reports
DROP POLICY IF EXISTS "Admins update event reports" ON event_reports;
CREATE POLICY "Admins update event reports" ON event_reports
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM users WHERE email = auth.jwt() ->> 'email' AND role = 'admin')
  );

-- Admins can read user reports
DROP POLICY IF EXISTS "Admins read user reports" ON user_reports;
CREATE POLICY "Admins read user reports" ON user_reports
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM users WHERE email = auth.jwt() ->> 'email' AND role = 'admin')
  );

-- Admins can update user reports
DROP POLICY IF EXISTS "Admins update user reports" ON user_reports;
CREATE POLICY "Admins update user reports" ON user_reports
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM users WHERE email = auth.jwt() ->> 'email' AND role = 'admin')
  );

-- ============================================
-- DISPUTES POLICIES
-- ============================================

-- Admins can read payment disputes
DROP POLICY IF EXISTS "Admins read disputes" ON payment_disputes;
CREATE POLICY "Admins read disputes" ON payment_disputes
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM users WHERE email = auth.jwt() ->> 'email' AND role = 'admin')
  );

-- Admins can update payment disputes
DROP POLICY IF EXISTS "Admins update disputes" ON payment_disputes;
CREATE POLICY "Admins update disputes" ON payment_disputes
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM users WHERE email = auth.jwt() ->> 'email' AND role = 'admin')
  );

-- ============================================
-- VERIFICATION & DOCUMENTATION
-- ============================================

COMMENT ON DATABASE postgres IS 'Email columns standardized to role-specific names (student_email, organizer_email, sponsor_email) for business clarity. Migration 19 renamed columns, Migration 20 updated RLS policies to match.';
