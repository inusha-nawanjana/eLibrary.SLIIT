-- Approving a reservation makes it active immediately for the requester.
-- Run this migration after 202610080002_admin_and_availability.sql.
create or replace function public.review_reservation(
  p_id uuid,
  p_status text,
  p_note text default ''
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  booking reservations;
  item books;
begin
  if not public.is_admin() then
    raise exception 'Library staff access required.';
  end if;

  select * into booking from reservations where id = p_id for update;
  if not found then
    raise exception 'Reservation not found.';
  end if;

  if not (
    (booking.status = 'pending' and p_status in ('active', 'rejected'))
    or (booking.status = 'approved' and p_status in ('active', 'cancelled'))
    or (booking.status = 'active' and p_status = 'completed')
  ) then
    raise exception 'Invalid reservation status change.';
  end if;

  if booking.kind = 'book' and p_status = 'active' then
    select * into item from books where id = booking.book_id for update;
    if item.copies <= (
      select count(*) from reservations
      where book_id = item.id and id <> booking.id
        and status in ('approved', 'active')
    ) then
      raise exception 'No copies are available.';
    end if;
  end if;

  if booking.kind <> 'book' and p_status = 'active' then
    perform 1 from rooms where id = booking.room_id for update;
    if booking.ends_at <= now() then
      raise exception 'The requested slot has already ended.';
    end if;
  end if;

  update reservations
  set status = p_status,
      admin_note = p_note,
      due_date = case
        when kind = 'book' and p_status = 'active'
          then (now() at time zone 'Asia/Colombo')::date + 14
        else due_date
      end
  where id = p_id;
end;
$$;

revoke all on function public.review_reservation(uuid, text, text) from public;
grant execute on function public.review_reservation(uuid, text, text) to authenticated;
