-- Run in a new Supabase project's SQL editor. No university SSO is assumed.
create extension if not exists btree_gist;

create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  campus_id text unique not null,
  full_name text not null,
  phone text not null default '',
  role text not null default 'student' check (role in ('student','lecturer','admin')),
  avatar_path text
);

create function public.is_admin() returns boolean
language sql stable security definer set search_path = public
as $$ select exists(select 1 from profiles where id = auth.uid() and role = 'admin') $$;

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
