-- 30_enable_rls_for_compat_tables.sql
-- Purpose: Apply RLS + policies for newly required compatibility tables.
-- Safe to run manually after 29_required_compat_tables_followup.sql.

-- =========================================================
-- TICKETS: Enable RLS and policies
-- =========================================================
DO $$
BEGIN
  IF to_regclass('public.tickets') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY';

    EXECUTE 'DROP POLICY IF EXISTS "Student read own tickets" ON public.tickets';
    EXECUTE 'CREATE POLICY "Student read own tickets" ON public.tickets
      FOR SELECT USING (student_email = auth.jwt()->>''email'')';

    EXECUTE 'DROP POLICY IF EXISTS "Student insert own tickets" ON public.tickets';
    EXECUTE 'CREATE POLICY "Student insert own tickets" ON public.tickets
      FOR INSERT WITH CHECK (student_email = auth.jwt()->>''email'')';

    EXECUTE 'DROP POLICY IF EXISTS "Organizer read tickets for own events" ON public.tickets';
    EXECUTE 'CREATE POLICY "Organizer read tickets for own events" ON public.tickets
      FOR SELECT USING (
        EXISTS (
          SELECT 1 FROM public.events e
          WHERE e.id = tickets.event_id
            AND e.organizer_email = auth.jwt()->>''email''
        )
      )';

    EXECUTE 'DROP POLICY IF EXISTS "Organizer update tickets for own events" ON public.tickets';
    EXECUTE 'CREATE POLICY "Organizer update tickets for own events" ON public.tickets
      FOR UPDATE USING (
        EXISTS (
          SELECT 1 FROM public.events e
          WHERE e.id = tickets.event_id
            AND e.organizer_email = auth.jwt()->>''email''
        )
      )
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM public.events e
          WHERE e.id = tickets.event_id
            AND e.organizer_email = auth.jwt()->>''email''
        )
      )';

    EXECUTE 'DROP POLICY IF EXISTS "Admin manage all tickets" ON public.tickets';
    EXECUTE 'CREATE POLICY "Admin manage all tickets" ON public.tickets
      FOR ALL USING (auth.jwt()->>''role'' = ''admin'')
      WITH CHECK (auth.jwt()->>''role'' = ''admin'')';
  END IF;
END $$;

-- =========================================================
-- SPONSORSHIP_ORDERS: Enable RLS and policies
-- =========================================================
DO $$
BEGIN
  IF to_regclass('public.sponsorship_orders') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.sponsorship_orders ENABLE ROW LEVEL SECURITY';

    EXECUTE 'DROP POLICY IF EXISTS "Public read active paid sponsorship orders" ON public.sponsorship_orders';
    EXECUTE 'CREATE POLICY "Public read active paid sponsorship orders" ON public.sponsorship_orders
      FOR SELECT USING (status = ''paid'' AND visibility_active = true)';

    EXECUTE 'DROP POLICY IF EXISTS "Sponsor read own sponsorship orders" ON public.sponsorship_orders';
    EXECUTE 'CREATE POLICY "Sponsor read own sponsorship orders" ON public.sponsorship_orders
      FOR SELECT USING (sponsor_email = auth.jwt()->>''email'')';

    EXECUTE 'DROP POLICY IF EXISTS "Sponsor insert own sponsorship orders" ON public.sponsorship_orders';
    EXECUTE 'CREATE POLICY "Sponsor insert own sponsorship orders" ON public.sponsorship_orders
      FOR INSERT WITH CHECK (sponsor_email = auth.jwt()->>''email'')';

    EXECUTE 'DROP POLICY IF EXISTS "Sponsor update own sponsorship orders" ON public.sponsorship_orders';
    EXECUTE 'CREATE POLICY "Sponsor update own sponsorship orders" ON public.sponsorship_orders
      FOR UPDATE USING (sponsor_email = auth.jwt()->>''email'')
      WITH CHECK (sponsor_email = auth.jwt()->>''email'')';

    EXECUTE 'DROP POLICY IF EXISTS "Organizer read sponsorship orders for own scope" ON public.sponsorship_orders';
    EXECUTE 'CREATE POLICY "Organizer read sponsorship orders for own scope" ON public.sponsorship_orders
      FOR SELECT USING (
        EXISTS (
          SELECT 1
          FROM public.events e
          WHERE (
            (sponsorship_orders.event_id IS NOT NULL AND e.id = sponsorship_orders.event_id)
            OR
            (sponsorship_orders.fest_id IS NOT NULL AND e.fest_id = sponsorship_orders.fest_id)
          )
          AND e.organizer_email = auth.jwt()->>''email''
        )
      )';

    EXECUTE 'DROP POLICY IF EXISTS "Admin manage all sponsorship orders" ON public.sponsorship_orders';
    EXECUTE 'CREATE POLICY "Admin manage all sponsorship orders" ON public.sponsorship_orders
      FOR ALL USING (auth.jwt()->>''role'' = ''admin'')
      WITH CHECK (auth.jwt()->>''role'' = ''admin'')';
  END IF;
END $$;

-- =========================================================
-- SPONSORS_PROFILE: Public read active profile rows (for public sponsorship display)
-- =========================================================
DO $$
BEGIN
  IF to_regclass('public.sponsors_profile') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.sponsors_profile ENABLE ROW LEVEL SECURITY';

    EXECUTE 'DROP POLICY IF EXISTS "Public read active sponsor profiles" ON public.sponsors_profile';
    EXECUTE 'CREATE POLICY "Public read active sponsor profiles" ON public.sponsors_profile
      FOR SELECT USING (is_active = true)';
  END IF;
END $$;

DO $$
BEGIN
  RAISE NOTICE 'RLS policies for tickets, sponsorship_orders, and sponsor public profile access applied.';
END $$;
