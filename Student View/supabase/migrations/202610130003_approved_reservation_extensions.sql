-- Older reservations use `approved`; the app presents both approved and active
-- reservations as Active. Keep extension requests compatible with both values.
begin;

create or replace function public.request_extension(
  p_reservation uuid,
  p_end timestamptz,
  p_note text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  booking reservations;
  request_id uuid;
begin
  select * into booking
  from reservations
  where id = p_reservation and user_id = auth.uid()
  for update;

  if not found or booking.status not in ('active', 'approved') then
    raise exception 'Only active reservations can be extended.';
  end if;
  if length(trim(p_note)) < 3 then
    raise exception 'Please give a reason for the extension.';
  end if;
  if p_end <= coalesce(booking.ends_at, booking.due_date::timestamp at time zone 'Asia/Colombo')
    or p_end <= now() then
    raise exception 'Choose a later end time.';
  end if;

  if booking.kind <> 'book' then
    if p_end <> booking.ends_at + interval '2 hours'
      or (p_end at time zone 'Asia/Colombo')::date <> (booking.ends_at at time zone 'Asia/Colombo')::date
      or extract(hour from p_end at time zone 'Asia/Colombo') > 17 then
      raise exception 'Select the next available two-hour slot before 17:00.';
    end if;
    if exists (
      select 1 from reservations
      where room_id = booking.room_id and id <> booking.id
        and status in ('approved','active')
        and tstzrange(starts_at, ends_at, '[)') && tstzrange(booking.ends_at, p_end, '[)')
    ) then
      raise exception 'The next slot is already booked.';
    end if;
  end if;

  insert into extension_requests(reservation_id, user_id, requested_end, note)
  values (booking.id, auth.uid(), p_end, trim(p_note))
  returning id into request_id;
  return request_id;
end;
$$;

create or replace function public.review_extension(p_id uuid, p_approve boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  request extension_requests;
  booking reservations;
  local_end timestamp;
begin
  if not public.is_admin() then
    raise exception 'Library staff access required.';
  end if;

  select * into request from extension_requests where id = p_id for update;
  if not found or request.status <> 'pending' then
    raise exception 'No pending extension found.';
  end if;
  select * into booking from reservations where id = request.reservation_id for update;

  if p_approve then
    if booking.status not in ('active', 'approved')
      or request.requested_end <= now()
      or request.requested_end <= coalesce(booking.ends_at, booking.due_date::timestamp at time zone 'Asia/Colombo') then
      raise exception 'This extension is no longer valid.';
    end if;
    if booking.kind = 'book' then
      update reservations
      set due_date = (request.requested_end at time zone 'Asia/Colombo')::date
      where id = booking.id;
    else
      perform 1 from rooms where id = booking.room_id for update;
      local_end := request.requested_end at time zone 'Asia/Colombo';
      if request.requested_end <> booking.ends_at + interval '2 hours'
        or extract(hour from local_end) > 17
        or local_end::date <> (booking.ends_at at time zone 'Asia/Colombo')::date then
        raise exception 'Select the next two-hour slot ending by 17:00.';
      end if;
      update reservations set ends_at = request.requested_end where id = booking.id;
    end if;
  end if;

  update extension_requests
  set status = case when p_approve then 'approved' else 'rejected' end
  where id = p_id;
  insert into notifications(user_id, title, body)
  values (
    request.user_id,
    case when p_approve then 'Extension approved' else 'Extension rejected' end,
    'Check Your Activity for the latest reservation details.'
  );
end;
$$;

revoke all on function public.request_extension(uuid, timestamptz, text) from public;
revoke all on function public.review_extension(uuid, boolean) from public;
grant execute on function public.request_extension(uuid, timestamptz, text) to authenticated;
grant execute on function public.review_extension(uuid, boolean) to authenticated;

commit;
