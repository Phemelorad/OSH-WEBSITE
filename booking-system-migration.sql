-- =============================================================================
-- Inspection Booking System Migration
--   1. Unique booking number  OHS/BK/YY/XXXXX (auto-generated on insert)
--   2. Status flow: pending -> assigned -> scheduled -> completed (+cancelled)
--   3. DB-enforced transition guards (cannot skip steps, cannot complete
--      an unassigned booking, cannot schedule without a date)
--   4. status_changed_by / status_changed_at audit columns
-- Run this ENTIRE file in the Supabase SQL Editor
-- =============================================================================

BEGIN;

-- ── 1. Booking number: sequence + generator + column + trigger ──────────────
CREATE SEQUENCE IF NOT EXISTS public.inspection_booking_number_seq
  START WITH 1 INCREMENT BY 1 MINVALUE 1 NO MAXVALUE CACHE 1;

CREATE OR REPLACE FUNCTION public.generate_booking_number()
RETURNS TEXT LANGUAGE plpgsql VOLATILE SET search_path = public AS $$
DECLARE
  v_year TEXT := to_char(CURRENT_DATE, 'YY');
  v_seq  TEXT;
BEGIN
  v_seq := LPAD(nextval('public.inspection_booking_number_seq')::TEXT, 5, '0');
  RETURN 'OHS/BK/' || v_year || '/' || v_seq;
END;
$$;

COMMENT ON FUNCTION public.generate_booking_number() IS 'Generates OHS/BK/{YY}/{XXXXX}';

ALTER TABLE public.inspection_bookings
  ADD COLUMN IF NOT EXISTS booking_number TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_inspection_bookings_booking_number
  ON public.inspection_bookings(booking_number)
  WHERE booking_number IS NOT NULL;

COMMENT ON COLUMN public.inspection_bookings.booking_number IS 'Auto-generated: OHS/BK/{YY}/{XXXXX}';

CREATE OR REPLACE FUNCTION public.trg_assign_booking_number()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.booking_number IS NULL THEN
    NEW.booking_number := public.generate_booking_number();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assign_booking_number ON public.inspection_bookings;
CREATE TRIGGER trg_assign_booking_number
  BEFORE INSERT ON public.inspection_bookings
  FOR EACH ROW EXECUTE FUNCTION public.trg_assign_booking_number();

-- Backfill existing rows
DO $$
DECLARE
  r RECORD;
  v_year TEXT := to_char(CURRENT_DATE, 'YY');
  v_seq BIGINT;
BEGIN
  v_seq := nextval('public.inspection_booking_number_seq') - 1;
  FOR r IN
    SELECT id FROM public.inspection_bookings
    WHERE booking_number IS NULL
    ORDER BY created_at, id
  LOOP
    v_seq := v_seq + 1;
    UPDATE public.inspection_bookings
    SET booking_number = 'OHS/BK/' || v_year || '/' || LPAD(v_seq::TEXT, 5, '0')
    WHERE id = r.id;
  END LOOP;
END;
$$;

-- ── 2. Status: add 'assigned', map legacy 'approved' -> 'assigned' ──────────
-- ORDER MATTERS (first run failed with 23514 doing this backwards):
--   a) drop the guard trigger so the backfill UPDATEs aren't rejected by it
--   b) DROP the old constraint
--   c) migrate legacy rows ('approved' -> 'assigned', anything unknown -> 'pending')
--   d) only then ADD the new constraint
DROP TRIGGER IF EXISTS trg_guard_booking_transition ON public.inspection_bookings;

ALTER TABLE public.inspection_bookings DROP CONSTRAINT IF EXISTS inspection_bookings_status_check;

UPDATE public.inspection_bookings SET status = 'assigned' WHERE status = 'approved';

-- Safety net: no status outside the new state machine may remain
UPDATE public.inspection_bookings
SET status = 'pending'
WHERE status IS NULL OR status NOT IN ('pending','assigned','scheduled','completed','cancelled');

ALTER TABLE public.inspection_bookings ADD CONSTRAINT inspection_bookings_status_check
  CHECK (status IN ('pending','assigned','scheduled','completed','cancelled'));

-- ── 3. Audit columns ────────────────────────────────────────────────────────
ALTER TABLE public.inspection_bookings
  ADD COLUMN IF NOT EXISTS status_changed_by UUID,
  ADD COLUMN IF NOT EXISTS status_changed_at TIMESTAMPTZ;

-- ── 4. Transition guard trigger ─────────────────────────────────────────────
-- Allowed transitions:
--   INSERT               -> must be 'pending' (booking number assigned here)
--   pending   -> assigned | cancelled
--   assigned  -> scheduled | cancelled      (scheduled_date required)
--   scheduled -> completed | cancelled
--   completed -> (terminal)
--   cancelled -> (terminal)
CREATE OR REPLACE FUNCTION public.guard_inspection_booking_transition()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  -- Allow status to be set on insert (defaults to pending)
  IF TG_OP = 'INSERT' THEN
    IF NEW.status IS NULL THEN NEW.status := 'pending'; END IF;
    IF NEW.status NOT IN ('pending') THEN
      RAISE EXCEPTION 'New bookings must start as pending (got %)', NEW.status;
    END IF;
    RETURN NEW;
  END IF;

  -- No status change: allow field edits (notes etc.)
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  -- Every status change must be attributable
  NEW.status_changed_by := auth.uid();
  NEW.status_changed_at := NOW();

  IF NEW.status = 'assigned' THEN
    IF OLD.status <> 'pending' THEN
      RAISE EXCEPTION 'Invalid transition: % -> %', OLD.status, NEW.status;
    END IF;
    IF COALESCE(TRIM(NEW.assigned_inspector), '') = '' THEN
      RAISE EXCEPTION 'Cannot assign: assigned_inspector is required';
    END IF;

  ELSIF NEW.status = 'scheduled' THEN
    IF OLD.status <> 'assigned' THEN
      RAISE EXCEPTION 'Invalid transition: % -> % (must be assigned first)', OLD.status, NEW.status;
    END IF;
    IF NEW.scheduled_date IS NULL THEN
      RAISE EXCEPTION 'Cannot schedule: scheduled_date is required';
    END IF;

  ELSIF NEW.status = 'completed' THEN
    IF OLD.status <> 'scheduled' THEN
      RAISE EXCEPTION 'Invalid transition: % -> % (must be scheduled first)', OLD.status, NEW.status;
    END IF;

  ELSIF NEW.status = 'cancelled' THEN
    IF OLD.status IN ('completed','cancelled') THEN
      RAISE EXCEPTION 'Cannot cancel a % booking', OLD.status;
    END IF;

  ELSE
    RAISE EXCEPTION 'Unknown booking status: %', NEW.status;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.guard_inspection_booking_transition()
  IS 'Enforces pending -> assigned -> scheduled -> completed state machine on inspection_bookings';

DROP TRIGGER IF EXISTS trg_guard_booking_transition ON public.inspection_bookings;
CREATE TRIGGER trg_guard_booking_transition
  BEFORE INSERT OR UPDATE OF status ON public.inspection_bookings
  FOR EACH ROW EXECUTE FUNCTION public.guard_inspection_booking_transition();

-- ── 5. Indexes for the officer queue ────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_ib_status            ON inspection_bookings(status);
CREATE INDEX IF NOT EXISTS idx_ib_assigned_inspector ON inspection_bookings(assigned_inspector);

COMMIT;

-- =============================================================================
-- NOTES
-- * Clients must now INSERT with status='pending' only, then use UPDATE to
--   advance. The insert response returns booking_number (add .select()).
-- * assignInspector should update { assigned_inspector, status:'assigned' }
--   in ONE update so the guard sees the inspector present.
-- * scheduling must send scheduled_date together with status:'scheduled'.
-- =============================================================================
