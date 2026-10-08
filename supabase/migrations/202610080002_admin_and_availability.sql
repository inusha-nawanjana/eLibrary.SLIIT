create function public.book_availability()
returns table(book_id uuid, available integer)
language sql stable security definer set search_path = public as $$
  select b.id, greatest(0,b.copies - (select count(*)::integer from reservations r
    where r.book_id=b.id and r.status in ('approved','active')))
  from books b
$$;

create unique index one_open_room_request on public.reservations(user_id,room_id,starts_at)
  where kind <> 'book' and status in ('pending','approved','active');

create function public.review_reservation(p_id uuid,p_status text,p_note text default '')
returns void language plpgsql security definer set search_path = public as $$
declare booking reservations; item books;
begin
  if not public.is_admin() then raise exception 'Administrator access required.'; end if;
  select * into booking from reservations where id=p_id for update;
  if not found then raise exception 'Reservation not found.'; end if;
  if not ((booking.status='pending' and p_status in ('approved','rejected'))
    or (booking.status='approved' and p_status in ('active','cancelled'))
    or (booking.status='active' and p_status='completed'))
    then raise exception 'Invalid reservation status change.'; end if;
  if booking.kind='book' and p_status in ('approved','active') then
    select * into item from books where id=booking.book_id for update;
    if item.copies <= (select count(*) from reservations where book_id=item.id
      and id<>booking.id and status in ('approved','active'))
      then raise exception 'No copies are available.'; end if;
  end if;
  if booking.kind<>'book' and p_status in ('approved','active') then
    perform 1 from rooms where id=booking.room_id for update;
    if booking.ends_at<=now() then raise exception 'The requested slot has already ended.'; end if;
  end if;
  update reservations set status=p_status,admin_note=p_note,
    due_date=case when kind='book' and p_status='active' then (now() at time zone 'Asia/Colombo')::date+14 else due_date end
    where id=p_id;
end $$;

create function public.review_extension(p_id uuid,p_approve boolean)
returns void language plpgsql security definer set search_path = public as $$
declare request extension_requests; booking reservations; local_end timestamp;
begin
  if not public.is_admin() then raise exception 'Administrator access required.'; end if;
  select * into request from extension_requests where id=p_id for update;
  if not found or request.status<>'pending' then raise exception 'No pending extension found.'; end if;
  select * into booking from reservations where id=request.reservation_id for update;
  if p_approve then
    if booking.status<>'active' or request.requested_end<=now()
      or request.requested_end<=coalesce(booking.ends_at,booking.due_date::timestamp at time zone 'Asia/Colombo')
      then raise exception 'This extension is no longer valid.'; end if;
    if booking.kind='book' then
      update reservations set due_date=(request.requested_end at time zone 'Asia/Colombo')::date where id=booking.id;
    else
      perform 1 from rooms where id=booking.room_id for update;
      local_end := request.requested_end at time zone 'Asia/Colombo';
      if request.requested_end<>booking.ends_at+interval '2 hours' or extract(hour from local_end)>17
        or local_end::date<>(booking.ends_at at time zone 'Asia/Colombo')::date
        then raise exception 'Select the next two-hour slot ending by 17:00.'; end if;
      -- The exclusion constraint rejects any conflict with another approved/active booking.
      update reservations set ends_at=request.requested_end where id=booking.id;
    end if;
  end if;
  update extension_requests set status=case when p_approve then 'approved' else 'rejected' end where id=p_id;
  insert into notifications(user_id,title,body) values(request.user_id,
    case when p_approve then 'Extension approved' else 'Extension rejected' end,
    'Check Your Activity for the latest reservation details.');
end $$;

create function public.notify_reservation_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op='INSERT' or old.status is distinct from new.status then
    insert into notifications(user_id,title,body) values(new.user_id,
      case when new.status='pending' then 'Reservation received' else 'Reservation '||new.status end,
      case when new.status='pending' then 'Your request is waiting for library administrator approval.'
        else 'Your reservation status is now '||new.status||'. '||coalesce(new.admin_note,'') end);
  end if;
  return new;
end $$;
create trigger reservation_notifications after insert or update on public.reservations
  for each row execute function public.notify_reservation_change();

revoke all on function public.review_reservation(uuid,text,text) from public;
revoke all on function public.review_extension(uuid,boolean) from public;
grant execute on function public.review_reservation(uuid,text,text) to authenticated;
grant execute on function public.review_extension(uuid,boolean) to authenticated;

-- The scenario permits guest e-book reading. Keep the bucket private while allowing
-- read access through the Storage API; only administrators can upload/change files.
drop policy ebooks_read on storage.objects;
create policy ebooks_read on storage.objects for select using (bucket_id='ebooks');
