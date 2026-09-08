-- Read-only check of migration 0136 against a live database.
--
--   psql "$DATABASE_URL" -f doc/check-0136.sql
--
-- 0136 repairs a schema that grew the Fact tables outside the migration
-- tracker. Every operation is IF NOT EXISTS, so re-running it cannot corrupt
-- anything — but that same IF NOT EXISTS means a table created earlier with
-- the WRONG columns is skipped silently. This reports that case.

\pset pager off
\echo '=============================================='
\echo ' 1. Is 0136 recorded in the migration tracker?'
\echo '=============================================='
SELECT name, applied
FROM   django_migrations
WHERE  app = 'core' AND name LIKE '013%'
ORDER  BY name;

\echo ''
\echo '=============================================='
\echo ' 2. Do the objects exist?'
\echo '=============================================='
SELECT 'core_fact'                      AS object,
       to_regclass('public.core_fact') IS NOT NULL AS present
UNION ALL
SELECT 'core_factcategory',
       to_regclass('public.core_factcategory') IS NOT NULL
UNION ALL
SELECT 'core_appsettings.facts_enabled',
       EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_name = 'core_appsettings'
                 AND column_name = 'facts_enabled');

\echo ''
\echo '========================================================'
\echo ' 3. Columns the model needs but the database is missing'
\echo '    (any row here = repair needed before you deploy)'
\echo '========================================================'
WITH expected(tbl, col) AS (
    VALUES
      ('core_factcategory','id'), ('core_factcategory','name'),
      ('core_factcategory','name_fr'), ('core_factcategory','icon_name'),
      ('core_factcategory','color'), ('core_factcategory','order'),
      ('core_factcategory','is_active'), ('core_factcategory','created_at'),
      ('core_fact','id'), ('core_fact','title'), ('core_fact','title_fr'),
      ('core_fact','content'), ('core_fact','content_fr'),
      ('core_fact','fact_type'), ('core_fact','source'),
      ('core_fact','source_fr'), ('core_fact','author_name'),
      ('core_fact','author_title'), ('core_fact','author_title_fr'),
      ('core_fact','image'), ('core_fact','is_active'),
      ('core_fact','is_featured'), ('core_fact','status'),
      ('core_fact','order'), ('core_fact','view_count'),
      ('core_fact','created_at'), ('core_fact','updated_at'),
      ('core_fact','category_id')
)
SELECT e.tbl AS missing_from_table, e.col AS missing_column
FROM   expected e
WHERE  to_regclass('public.' || e.tbl) IS NOT NULL
  AND  NOT EXISTS (
         SELECT 1 FROM information_schema.columns c
         WHERE c.table_name = e.tbl AND c.column_name = e.col)
ORDER  BY 1, 2;

\echo ''
\echo '=============================================='
\echo ' 4. Verdict'
\echo '=============================================='
SELECT CASE
  WHEN to_regclass('public.core_fact') IS NULL
    THEN 'SAFE - tables do not exist yet; 0136 will create them normally.'
  WHEN EXISTS (
        WITH expected(tbl, col) AS (
            VALUES
              ('core_fact','id'), ('core_fact','title'), ('core_fact','title_fr'),
              ('core_fact','content'), ('core_fact','content_fr'),
              ('core_fact','fact_type'), ('core_fact','source'),
              ('core_fact','source_fr'), ('core_fact','author_name'),
              ('core_fact','author_title'), ('core_fact','author_title_fr'),
              ('core_fact','image'), ('core_fact','is_active'),
              ('core_fact','is_featured'), ('core_fact','status'),
              ('core_fact','order'), ('core_fact','view_count'),
              ('core_fact','created_at'), ('core_fact','updated_at'),
              ('core_fact','category_id'),
              ('core_factcategory','id'), ('core_factcategory','name'),
              ('core_factcategory','name_fr'), ('core_factcategory','icon_name'),
              ('core_factcategory','color'), ('core_factcategory','order'),
              ('core_factcategory','is_active'), ('core_factcategory','created_at')
        )
        SELECT 1 FROM expected e
        WHERE to_regclass('public.' || e.tbl) IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM information_schema.columns c
                          WHERE c.table_name = e.tbl AND c.column_name = e.col))
    THEN 'REPAIR NEEDED - see section 3; IF NOT EXISTS will skip these silently.'
  ELSE 'SAFE - tables exist with the columns the model expects.'
END AS verdict;
