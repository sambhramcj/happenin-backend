-- 21_enable_rls_all_tables.sql
-- ENABLE RLS ON ALL REMAINING TABLES
-- Ensures every table has RLS protection
-- Created: February 17, 2026

-- ============================================
-- ENABLE RLS ON ALL TABLES
-- ============================================

-- Core tables (if not already enabled)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Fest system
ALTER TABLE fests ENABLE ROW LEVEL SECURITY;
ALTER TABLE fest_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE fest_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE festival_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE festival_sponsorships ENABLE ROW LEVEL SECURITY;
ALTER TABLE festival_submissions ENABLE ROW LEVEL SECURITY;

-- Bulk tickets
ALTER TABLE bulk_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE bulk_ticket_packs ENABLE ROW LEVEL SECURITY;
ALTER TABLE bulk_ticket_purchases ENABLE ROW LEVEL SECURITY;

-- Sponsorships
ALTER TABLE sponsorship_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE sponsorship_deals ENABLE ROW LEVEL SECURITY;
ALTER TABLE sponsorship_razorpay_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE sponsorship_deliverables ENABLE ROW LEVEL SECURITY;
ALTER TABLE sponsorship_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_default_deliverables ENABLE ROW LEVEL SECURITY;
ALTER TABLE sponsors_profile ENABLE ROW LEVEL SECURITY;
ALTER TABLE sponsor_analytics ENABLE ROW LEVEL SECURITY;

-- Event management
ALTER TABLE event_access_control ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_cancellations ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_reschedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_category_mapping ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_changelog ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_similarity_cache ENABLE ROW LEVEL SECURITY;

-- Reports and disputes
ALTER TABLE event_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_disputes ENABLE ROW LEVEL SECURITY;

-- Access control
ALTER TABLE access_control_restrictions ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_check_logs ENABLE ROW LEVEL SECURITY;

-- Analytics and logs
ALTER TABLE banner_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_logs ENABLE ROW LEVEL SECURITY;

-- Banners
ALTER TABLE banners ENABLE ROW LEVEL SECURITY;

-- Colleges
ALTER TABLE colleges ENABLE ROW LEVEL SECURITY;

-- Favorites
ALTER TABLE favorite_colleges ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorite_events ENABLE ROW LEVEL SECURITY;

-- Notifications
ALTER TABLE in_app_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE push_notifications ENABLE ROW LEVEL SECURITY;

-- Organizers
ALTER TABLE organizer_bank_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizers ENABLE ROW LEVEL SECURITY;

-- Certificates and badges
ALTER TABLE certificate_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE certificate_recipients ENABLE ROW LEVEL SECURITY;
ALTER TABLE certificate_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievement_badges ENABLE ROW LEVEL SECURITY;

-- Volunteers
ALTER TABLE volunteer_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE volunteer_assignments ENABLE ROW LEVEL SECURITY;

-- User interactions
ALTER TABLE user_event_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

-- Note: spatial_ref_sys is a PostGIS system table owned by postgres superuser
-- It cannot be modified and doesn't need RLS (read-only reference data)

-- ============================================
-- SUCCESS MESSAGE
-- ============================================

DO $$
BEGIN
  RAISE NOTICE 'RLS enabled on all tables. Verify with: SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = ''public'' ORDER BY tablename;';
END $$;
