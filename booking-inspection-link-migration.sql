-- =============================================================================
-- Booking <-> Inspection link
-- Adds workplace_inspections.booking_id so an inspection produced from a
-- booking references that booking. Run in Supabase SQL Editor.
--
-- After this:
--   * inspection.html?booking=<id> prefills from the booking and stamps
--     booking_id on the inserted inspection.
--   * Submitting a linked inspection auto-completes the booking if it is
--     in 'scheduled' status (guarded update, so invalid states are ignored).
-- =============================================================================

BEGIN;

ALTER TABLE public.workplace_inspections
  ADD COLUMN IF NOT EXISTS booking_id uuid;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'workplace_inspections_booking_id_fkey'
  ) THEN
    ALTER TABLE public.workplace_inspections
      ADD CONSTRAINT workplace_inspections_booking_id_fkey
      FOREIGN KEY (booking_id) REFERENCES public.inspection_bookings(id)
      ON DELETE SET NULL;
  END IF;
END;
$$;

COMMENT ON COLUMN public.workplace_inspections.booking_id
  IS 'Inspection performed for this booking (inspection_bookings.id); set via inspection.html?booking=';

CREATE INDEX IF NOT EXISTS idx_wi_booking_id
  ON public.workplace_inspections(booking_id)
  WHERE booking_id IS NOT NULL;

-- Reverse lookup: bookings page shows the inspection produced by a booking
CREATE INDEX IF NOT EXISTS idx_ib_booking_number_lookup
  ON public.inspection_bookings(booking_number)
  WHERE booking_number IS NOT NULL;

COMMIT;

-- =============================================================================
-- NOTE: booking_id is ON DELETE SET NULL — deleting a booking never deletes
-- the inspection record that was already performed.
-- =============================================================================
