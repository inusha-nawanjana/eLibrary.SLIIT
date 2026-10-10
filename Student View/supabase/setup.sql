-- Fresh project only. Run this file once, not alongside its individual migrations.
begin;

-- Run in a new Supabase project's SQL editor. No university SSO is assumed.
create extension if not exists btree_gist;

create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  campus_id text unique not null,
  full_name text not null,
  phone text not null default '',
  role text not null default 'student' check (role in ('student','lecturer','librarian','library_staff','admin')),
  avatar_path text
);

create function public.is_admin() returns boolean
language sql stable security definer set search_path = public
as $$ select exists(select 1 from profiles where id = auth.uid() and role in ('librarian','library_staff','admin')) $$;

create table public.books (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  author text not null,
  category text not null,
  published_year integer,
  edition text,
  shelf text,
  synopsis text not null default '',
  cover_path text,
  ebook_path text,
  copies integer not null default 1 check (copies >= 0),
  created_at timestamptz not null default now()
);

create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('learning','discussion')),
  number integer not null,
  capacity integer not null,
  enabled boolean not null default true,
  unique(kind, number)
);

create table public.reservations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  kind text not null check (kind in ('book','learning','discussion')),
  book_id uuid references public.books(id),
  room_id uuid references public.rooms(id),
  status text not null default 'pending'
    check (status in ('pending','approved','active','completed','rejected','cancelled')),
  full_name text not null,
  phone text not null,
  member_ids text[] not null default '{}',
  id_paths text[] not null default '{}',
  starts_at timestamptz,
  ends_at timestamptz,
  due_date date,
  admin_note text,
  created_at timestamptz not null default now(),
  check ((kind = 'book' and book_id is not null and room_id is null)
    or (kind <> 'book' and book_id is null and room_id is not null
      and starts_at is not null and ends_at > starts_at)),
  exclude using gist (room_id with =, tstzrange(starts_at, ends_at, '[)') with &&)
    where (room_id is not null and status in ('approved','active'))
);

create unique index one_open_book_request on public.reservations(user_id,book_id)
  where kind = 'book' and status in ('pending','approved','active');
create index reservations_user on public.reservations(user_id, created_at desc);

create table public.extension_requests (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null references public.reservations(id),
  user_id uuid not null references public.profiles(id),
  requested_end timestamptz not null,
  note text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now()
);
create unique index one_pending_extension on public.extension_requests(reservation_id)
  where status = 'pending';

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  title text not null,
  body text not null,
  category text not null default 'reservations',
  read_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.books enable row level security;
alter table public.rooms enable row level security;
alter table public.reservations enable row level security;
alter table public.extension_requests enable row level security;
alter table public.notifications enable row level security;

create policy profile_read on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());
create policy profile_edit on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
revoke update on public.profiles from authenticated;
grant update (full_name,phone,avatar_path) on public.profiles to authenticated;
create policy books_read on public.books for select using (true);
create policy books_admin on public.books for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy rooms_read on public.rooms for select using (true);
create policy rooms_admin on public.rooms for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy reservations_read on public.reservations for select to authenticated
  using (user_id = auth.uid() or public.is_admin());
create policy extensions_read on public.extension_requests for select to authenticated
  using (user_id = auth.uid() or public.is_admin());
create policy notifications_read on public.notifications for select to authenticated
  using (user_id = auth.uid());
create policy notifications_edit on public.notifications for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
revoke update on public.notifications from authenticated;
grant update (read_at) on public.notifications to authenticated;

-- All reservation mutations use checked functions, never unrestricted client writes.
create function public.reserve_book(p_book uuid, p_name text, p_phone text)
returns uuid language plpgsql security definer set search_path = public as $$
declare request_id uuid; item books;
begin
  if auth.uid() is null then raise exception 'Please sign in.'; end if;
  if length(trim(p_name)) < 2 or length(trim(p_phone)) < 9 then
    raise exception 'Please enter your name and phone number.';
  end if;
  select * into item from books where id = p_book for update;
  if not found or item.ebook_path is not null then raise exception 'Physical book not found.'; end if;
  if item.copies <= (select count(*) from reservations where book_id = p_book and status in ('approved','active'))
    then raise exception 'This book is currently unavailable.'; end if;
  insert into reservations(user_id,kind,book_id,full_name,phone)
    values(auth.uid(),'book',p_book,trim(p_name),trim(p_phone)) returning id into request_id;
  return request_id;
end $$;

create function public.reserve_room(p_room uuid, p_name text, p_phone text,
  p_members text[], p_id_paths text[], p_start timestamptz)
returns uuid language plpgsql security definer set search_path = public as $$
declare room rooms; request_id uuid; min_members integer; local_start timestamp;
begin
  if auth.uid() is null then raise exception 'Please sign in.'; end if;
  select * into room from rooms where id = p_room and enabled for update;
  if not found then raise exception 'Room is unavailable.'; end if;
  if room.kind = 'learning' and not exists(select 1 from profiles where id = auth.uid() and role = 'student')
    then raise exception 'Learning rooms are for students.'; end if;
  min_members := case when room.kind = 'learning' then 3 else 4 end;
  if cardinality(p_members) < min_members or cardinality(p_members) > room.capacity - 1
    or exists(select 1 from unnest(p_members) m where length(trim(m)) < 3)
    or (select count(distinct lower(trim(m))) from unnest(p_members) m) <> cardinality(p_members)
    or exists(select 1 from profiles where id = auth.uid() and lower(campus_id) = any(select lower(trim(m)) from unnest(p_members) m))
    then raise exception 'Check the group member IDs.'; end if;
  if cardinality(p_id_paths) < cardinality(p_members) + 1
    or exists(select 1 from unnest(p_id_paths) path where split_part(path,'/',1) <> auth.uid()::text
      or not exists(select 1 from storage.objects o where o.bucket_id = 'student-ids' and o.name = path))
    then raise exception 'Upload an ID image for every attendee, including yourself.'; end if;
  local_start := p_start at time zone 'Asia/Colombo';
  if p_start < now() + interval '15 minutes' or extract(hour from local_start) not in (9,11,13,15)
    or extract(minute from local_start) <> 0 or extract(second from local_start) <> 0
    then raise exception 'Select a valid future two-hour slot, at least 15 minutes ahead.'; end if;
  if length(trim(p_name)) < 2 or length(trim(p_phone)) < 9 then raise exception 'Enter your name and phone number.'; end if;
  if exists(select 1 from reservations where room_id = p_room and status in ('approved','active')
    and tstzrange(starts_at,ends_at,'[)') && tstzrange(p_start,p_start + interval '2 hours','[)'))
    then raise exception 'This room is already booked for that time.'; end if;
  insert into reservations(user_id,kind,room_id,full_name,phone,member_ids,id_paths,starts_at,ends_at)
    values(auth.uid(),room.kind,p_room,trim(p_name),trim(p_phone),p_members,p_id_paths,p_start,p_start + interval '2 hours')
    returning id into request_id;
  return request_id;
end $$;

create function public.request_extension(p_reservation uuid, p_end timestamptz, p_note text)
returns uuid language plpgsql security definer set search_path = public as $$
declare booking reservations; request_id uuid;
begin
  select * into booking from reservations where id = p_reservation and user_id = auth.uid() for update;
  if not found or booking.status <> 'active' then raise exception 'Only active reservations can be extended.'; end if;
  if length(trim(p_note)) < 3 then raise exception 'Please give a reason for the extension.'; end if;
  if p_end <= coalesce(booking.ends_at, booking.due_date::timestamp at time zone 'Asia/Colombo') or p_end <= now()
    then raise exception 'Choose a later end time.'; end if;
  if booking.kind <> 'book' then
    if p_end <> booking.ends_at + interval '2 hours'
      or (p_end at time zone 'Asia/Colombo')::date <> (booking.ends_at at time zone 'Asia/Colombo')::date
      or extract(hour from p_end at time zone 'Asia/Colombo') > 17
      then raise exception 'Select the next available two-hour slot before 17:00.'; end if;
    if exists(select 1 from reservations where room_id = booking.room_id and id <> booking.id
      and status in ('approved','active') and tstzrange(starts_at,ends_at,'[)') && tstzrange(booking.ends_at,p_end,'[)'))
      then raise exception 'The next slot is already booked.'; end if;
  end if;
  insert into extension_requests(reservation_id,user_id,requested_end,note)
    values(booking.id,auth.uid(),p_end,trim(p_note)) returning id into request_id;
  return request_id;
end $$;

-- A public view exposes availability without exposing attendee data.
create function public.room_bookings(p_date date)
returns table(room_id uuid, starts_at timestamptz, ends_at timestamptz)
language sql stable security definer set search_path = public as $$
  select r.room_id,r.starts_at,r.ends_at from reservations r
  where r.kind <> 'book' and r.status in ('approved','active')
    and (r.starts_at at time zone 'Asia/Colombo')::date = p_date
$$;

insert into public.rooms(kind,number,capacity)
select 'learning',generate_series(1,8),6;
insert into public.rooms(kind,number,capacity)
select 'discussion',generate_series(1,6),9;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
  ('book-covers','book-covers',true,5242880,array['image/jpeg','image/png','image/webp']),
  ('ebooks','ebooks',false,52428800,array['application/pdf']),
  ('student-ids','student-ids',false,5242880,array['image/jpeg','image/png']),
  ('avatars','avatars',false,5242880,array['image/jpeg','image/png']);

create policy covers_read on storage.objects for select using (bucket_id = 'book-covers');
create policy library_upload on storage.objects for all to authenticated
  using (bucket_id in ('book-covers','ebooks') and public.is_admin())
  with check (bucket_id in ('book-covers','ebooks') and public.is_admin());
create policy ebooks_read on storage.objects for select to authenticated using (bucket_id = 'ebooks');
create policy personal_upload on storage.objects for insert to authenticated
  with check (bucket_id in ('student-ids','avatars') and (storage.foldername(name))[1] = auth.uid()::text);
create policy personal_read on storage.objects for select to authenticated
  using (bucket_id in ('student-ids','avatars') and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));

revoke all on function public.reserve_book(uuid,text,text) from public;
revoke all on function public.reserve_room(uuid,text,text,text[],text[],timestamptz) from public;
revoke all on function public.request_extension(uuid,timestamptz,text) from public;
grant execute on function public.reserve_book(uuid,text,text) to authenticated;
grant execute on function public.reserve_room(uuid,text,text,text[],text[],timestamptz) to authenticated;
grant execute on function public.request_extension(uuid,timestamptz,text) to authenticated;


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
  if not public.is_admin() then raise exception 'Library staff access required.'; end if;
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
  if not public.is_admin() then raise exception 'Library staff access required.'; end if;
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


-- Explicit grants complement the existing admin-only RLS policies.
grant select on public.books, public.rooms to anon, authenticated;
grant insert, update, delete on public.books, public.rooms to authenticated;
revoke insert, update, delete on public.books, public.rooms from anon;

alter table public.books add constraint books_title_nonempty check (length(trim(title)) > 0);
alter table public.books add constraint books_author_nonempty check (length(trim(author)) > 0);
alter table public.books add constraint books_category_valid check
  (category in ('Computer Science','Management','Law','Cookery','Data Science','Engineering'));
alter table public.books add constraint books_year_valid check (published_year between 1 and 9999);
alter table public.rooms add constraint rooms_number_positive check (number between 1 and 999);
alter table public.rooms add constraint rooms_capacity_valid check
  ((kind = 'learning' and capacity = 6) or (kind = 'discussion' and capacity = 9));

-- Reservation foreign keys intentionally prevent deleting catalogue history.
-- Book row locks also serialize this check with reservation approval.
create function public.validate_catalogue_change() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_table_name = 'books' then
    if new.copies < (select count(*) from public.reservations
      where book_id = old.id and status in ('approved','active')) then
      raise exception 'Copy count cannot be less than approved or borrowed copies.' using errcode = '23514';
    end if;
  elsif (new.kind <> old.kind or new.number <> old.number) and exists
    (select 1 from public.reservations where room_id = old.id) then
    raise exception 'A room with reservation history cannot be renumbered or change type. Disable it and create another room instead.' using errcode = '23514';
  end if;
  return new;
end $$;
revoke all on function public.validate_catalogue_change() from public, anon, authenticated;
create trigger protect_book_loans before update on public.books
  for each row execute function public.validate_catalogue_change();
create trigger protect_room_history before update on public.rooms
  for each row execute function public.validate_catalogue_change();


-- Optional catalogue seed. The asset paths refer to artwork bundled in the app.
-- Run only once in a fresh project, after the migrations.
insert into public.books(title,author,category,published_year,edition,shelf,synopsis,cover_path,copies) values
('Introduction to Algorithms','Thomas H. Cormen','Computer Science',2019,'4th Edition','Shelf B-12, Section 3','A comprehensive guide to the modern study of computer algorithms, presenting many algorithms in detail with mathematical rigor yet remaining widely accessible to all levels of readers.','assets/figma/88bd2.png',3),
('Digital Circuits & Data Pathways','Andrew S. Tanenbaum','Computer Science',2021,'2nd Edition','Shelf A-7, Section 1','An introduction to digital circuits and the organisation of computing systems.','assets/figma/6fea3.png',2),
('Architecting Computing Systems','Erich Gamma','Computer Science',2021,'1st Edition','Shelf A-8, Section 1','A practical overview of computing system architecture.','assets/figma/9df7b.png',2),
('Clean Code','Robert C. Martin','Computer Science',2008,'1st Edition','Shelf B-12, Section 4','A handbook of agile software craftsmanship.','assets/figma/fc70d.png',2),
('Artificial Intelligence','Stuart Russell','Computer Science',2021,'4th Edition','Shelf B-14, Section 2','An introduction to the foundations of artificial intelligence.','assets/figma/99570.png',2);

-- Upload your licensed PDFs through Admin > Add books for live e-books.
-- Demo sample PDFs are included in assets/ebooks; no published full books are bundled.

commit;
