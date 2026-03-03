-- 31_enable_rls_for_all_public_tables.sql
-- Purpose: Enforce RLS across ALL public tables (dynamic, idempotent) and report policy coverage.
-- Run manually after other schema migrations.

DO $$
DECLARE
  record_table RECORD;
  enabled_count INTEGER := 0;
BEGIN
  FOR record_table IN
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
      AND tablename <> 'spatial_ref_sys'
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', record_table.tablename);
    enabled_count := enabled_count + 1;
  END LOOP;

  RAISE NOTICE 'RLS enabled on % public tables.', enabled_count;
END $$;

-- Optional hardening toggle (commented):
-- FORCE RLS applies even to table owners. Keep disabled unless you are fully ready.
-- DO $$
-- DECLARE t RECORD;
-- BEGIN
--   FOR t IN
--     SELECT tablename
--     FROM pg_tables
--     WHERE schemaname = 'public'
--       AND tablename <> 'spatial_ref_sys'
--   LOOP
--     EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', t.tablename);
--   END LOOP;
-- END $$;

-- Report tables that currently have RLS enabled but no policies.
DO $$
DECLARE
  missing_policy_tables TEXT;
BEGIN
  SELECT string_agg(quote_ident(pc.relname), ', ' ORDER BY pc.relname)
  INTO missing_policy_tables
  FROM pg_class pc
  JOIN pg_namespace pn ON pn.oid = pc.relnamespace
  WHERE pn.nspname = 'public'
    AND pc.relkind = 'r'
    AND pc.relrowsecurity = true
    AND pc.relname <> 'spatial_ref_sys'
    AND NOT EXISTS (
      SELECT 1
      FROM pg_policies pp
      WHERE pp.schemaname = 'public'
        AND pp.tablename = pc.relname
    );

  IF missing_policy_tables IS NULL THEN
    RAISE NOTICE 'All RLS-enabled public tables have at least one policy.';
  ELSE
    RAISE NOTICE 'RLS enabled but NO policies on: %', missing_policy_tables;
  END IF;
END $$;

-- Quick verification query to run after migration:
-- SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;
-- SELECT tablename, policyname, cmd FROM pg_policies WHERE schemaname = 'public' ORDER BY tablename, policyname;
