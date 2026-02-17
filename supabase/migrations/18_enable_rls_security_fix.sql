-- 18_enable_rls_security_fix.sql
-- STEP 1: Enable RLS on all tables (policies created in migration 20 after column standardization)
-- Created: February 17, 2026

-- ============================================
-- ENABLE RLS ON ALL CRITICAL TABLES
-- Note: Policies will be created in migration 20 after columns are standardized
-- ============================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE fests ENABLE ROW LEVEL SECURITY;
ALTER TABLE fest_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE fest_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_access_control ENABLE ROW LEVEL SECURITY;
ALTER TABLE bulk_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE bulk_ticket_packs ENABLE ROW LEVEL SECURITY;
ALTER TABLE bulk_ticket_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE sponsorship_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE sponsorship_razorpay_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE sponsorship_deliverables ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_default_deliverables ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_cancellations ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_reschedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_category_mapping ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_changelog ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_control_restrictions ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_check_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE banner_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_locations ENABLE ROW LEVEL SECURITY;

-- ============================================
-- RLS ENABLED - POLICIES CREATED IN MIGRATION 20
-- ============================================
-- Migration 19 will standardize column names (user_email -> student_email, etc.)
-- Migration 20 will create all RLS policies with correct standardized names
-- This ensures policies don't break during column renaming

