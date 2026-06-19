-- ============================================================
-- DATABASE SCHEMA DISCOVERY
-- Run this in Supabase Dashboard → SQL Editor to get a
-- complete understanding of your database structure.
-- ============================================================

-- ============================================================
-- 1. ALL TABLES (excluding Supabase system schemas)
-- ============================================================
SELECT
  table_name,
  table_schema,
  table_type
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog', 'information_schema', 'auth', 'storage', 'extensions')
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- ============================================================
-- 2. ALL COLUMNS for every table (with types, defaults, nullability)
-- ============================================================
SELECT
  c.table_name,
  c.column_name,
  c.data_type,
  c.character_maximum_length AS max_length,
  c.column_default AS default_value,
  c.is_nullable,
  c.ordinal_position
FROM information_schema.columns c
WHERE c.table_schema NOT IN ('pg_catalog', 'information_schema', 'auth', 'storage', 'extensions')
ORDER BY c.table_name, c.ordinal_position;

-- ============================================================
-- 3. PRIMARY KEYS
-- ============================================================
SELECT
  tc.table_name,
  kcu.column_name,
  tc.constraint_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
WHERE tc.constraint_type = 'PRIMARY KEY'
  AND tc.table_schema NOT IN ('pg_catalog', 'information_schema', 'auth', 'storage', 'extensions')
ORDER BY tc.table_name, kcu.ordinal_position;

-- ============================================================
-- 4. FOREIGN KEY RELATIONSHIPS (table connections)
-- ============================================================
SELECT
  tc.table_name AS source_table,
  kcu.column_name AS source_column,
  ccu.table_name AS target_table,
  ccu.column_name AS target_column,
  tc.constraint_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
  ON tc.constraint_name = ccu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema NOT IN ('pg_catalog', 'information_schema', 'auth', 'storage', 'extensions')
ORDER BY tc.table_name, kcu.ordinal_position;

-- ============================================================
-- 5. RLS POLICIES on each table
-- ============================================================
SELECT
  n.nspname AS schema_name,
  c.relname AS table_name,
  p.policyname AS policy_name,
  p.permissive,
  p.cmd AS command_type,
  pg_get_expr(p.qual, p.relid) AS using_expression,
  pg_get_expr(p.with_check, p.relid) AS with_check_expression
FROM pg_policy p
JOIN pg_class c ON c.oid = p.relid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'auth', 'storage', 'extensions')
ORDER BY c.relname, p.policyname;

-- ============================================================
-- 6. ROW COUNTS for every table
-- ============================================================
SELECT
  schemaname AS schema_name,
  tablename AS table_name,
  n_live_tup AS estimated_row_count,
  'SELECT COUNT(*) FROM "' || tablename || '";' AS count_query
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;

-- ============================================================
-- 7. SEQUENCES (auto-increment counters)
-- ============================================================
SELECT
  sequence_schema,
  sequence_name,
  data_type,
  start_value,
  minimum_value,
  maximum_value,
  increment
FROM information_schema.sequences
WHERE sequence_schema NOT IN ('pg_catalog', 'information_schema', 'auth', 'storage', 'extensions')
ORDER BY sequence_name;

-- ============================================================
-- 8. INDEXES on each table
-- ============================================================
SELECT
  tablename AS table_name,
  indexname AS index_name,
  indexdef AS index_definition
FROM pg_indexes
WHERE schemaname NOT IN ('pg_catalog', 'information_schema', 'auth', 'storage', 'extensions')
ORDER BY tablename, indexname;

-- ============================================================
-- 9. ENUM TYPES
-- ============================================================
SELECT
  t.typname AS enum_name,
  e.enumlabel AS enum_value
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'auth', 'storage', 'extensions')
ORDER BY t.typname, e.enumsortorder;

-- ============================================================
-- 10. TRIGGERS
-- ============================================================
SELECT
  event_object_table AS table_name,
  trigger_name,
  action_timing AS timing,
  event_manipulation AS event,
  action_statement AS statement
FROM information_schema.triggers
WHERE trigger_schema NOT IN ('pg_catalog', 'information_schema', 'auth', 'storage', 'extensions')
ORDER BY event_object_table, trigger_name;

-- ============================================================
-- 11. SUMMARY: TABLE RELATIONSHIP MAP (text format)
-- Run each COUNT query from section 6 to get exact counts.
-- Below is a human-readable summary generated from the above queries.
-- ============================================================
SELECT 'DATABASE SCHEMA SUMMARY' AS report;
SELECT '========================' AS separator;
