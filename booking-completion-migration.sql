-- =============================================================================
-- Booking completion when an inspection is attached
--
-- The transition guard added by booking-system-migration.sql only allowed
--   scheduled -> completed
-- so an inspection submitted against a booking that was still 'pending' or
-- 'assigned' could not complete it. inspection.html attempted the update, the
-- guard raised, and the failure was swallowed: the booking stayed open and kept
-- appearing in the "link a booking" dropdown for every later inspection, so the
-- same booking could be linked to inspection after inspection.
--
-- This migration allows completion from ANY open state. The inspection record
-- is the evidence that the visit happened, so requiring an officer to first
-- assign and then schedule a booking they have already inspected is not a real
-- safeguard — it is the thing that was breaking.
--
-- Terminal states stay terminal: completed -> cancelled is still rejected, and
-- new bookings must still start as 'pending'.
--
-- Run in Supabase Dashboard -> SQL Editor. Idempotent (CREATE OR REPLACE).
-- =============================================================================

BEGIN;

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
    -- Widened: an inspection carried out for this booking completes it, whether
    -- or not it had been through assigned/scheduled first.
    IF OLD.status NOT IN ('pending', 'assigned', 'scheduled') THEN
      RAISE EXCEPTION 'Invalid transition: % -> % (booking is already closed)', OLD.status, NEW.status;
    END IF;

  ELSIF NEW.status = 'cancelled' THEN
    IF OLD.status IN ('completed', 'cancelled') THEN
      RAISE EXCEPTION 'Cannot cancel a % booking', OLD.status;
    END IF;

  ELSE
    RAISE EXCEPTION 'Unknown booking status: %', NEW.status;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.guard_inspection_booking_transition()
  IS 'Enforces the inspection_bookings state machine. pending/assigned/scheduled -> completed is allowed because a linked inspection is the record of the visit; completed and cancelled are terminal.';

COMMIT;

-- =============================================================================
-- Verification — run after applying.
-- =============================================================================

-- 1. The function now allows completion from an open state. Should return
--    'ALLOWED' for each of the three open statuses and 'REJECTED' for a
--    completed booking (this runs the guard for real, then rolls back):
--
--   BEGIN;
--   SELECT id, status FROM public.inspection_bookings
--    WHERE status IN ('pending','assigned','scheduled') LIMIT 1;
--   UPDATE public.inspection_bookings SET status = 'completed' WHERE id = '<that id>';
--   -- no error  => attaching an inspection can now complete the booking
--   ROLLBACK;
--
-- 2. Every completed booking should have an inspection pointing at it (0 rows
--    returned once the officers' linked inspections have been re-saved):
--
--   SELECT b.booking_number, b.status, count(wi.id) AS linked_inspections
--     FROM public.inspection_bookings b
--     LEFT JOIN public.workplace_inspections wi ON wi.booking_id = b.id
--    WHERE b.status = 'completed'
--    GROUP BY b.booking_number, b.status
--   HAVING count(wi.id) = 0;
--
-- 3. No booking may carry more than one inspection (0 rows is the healthy
--    answer; anything else means the same booking was linked twice before this
--    fix — the extra inspections keep their record, the link is the duplicate):
--
--   SELECT booking_id, count(*) AS inspections
--     FROM public.workplace_inspections
--    WHERE booking_id IS NOT NULL
--    GROUP BY booking_id
--   HAVING count(*) > 1;
