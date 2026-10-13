-- Run this in the Supabase SQL Editor after creating and confirming the
-- sample users in Authentication > Users. Run migration 202610080004 first
-- when using librarian or library_staff roles.
-- Passwords are managed by Supabase Auth and are intentionally not stored here.
-- If a campus_id already belongs to a different profile, that row is skipped
-- so this script can be safely rerun without overwriting another account.

insert into public.profiles (id, campus_id, full_name, phone, role)
select id, 'IT23857162', 'I. T. Student', '', 'student'
from auth.users u
where lower(u.email) = 'it23857162@my.sliit.lk'
  and not exists (select 1 from public.profiles p where p.campus_id = 'IT23857162' and p.id <> u.id)
on conflict (id) do update set campus_id = excluded.campus_id,
  full_name = excluded.full_name, role = excluded.role;

insert into public.profiles (id, campus_id, full_name, phone, role)
select id, 'EN23824681', 'E. N. Student', '', 'student'
from auth.users u
where lower(u.email) = 'en23824681@my.sliit.lk'
  and not exists (select 1 from public.profiles p where p.campus_id = 'EN23824681' and p.id <> u.id)
on conflict (id) do update set campus_id = excluded.campus_id,
  full_name = excluded.full_name, role = excluded.role;

insert into public.profiles (id, campus_id, full_name, phone, role)
select id, 'HS23190754', 'H. S. Student', '', 'student'
from auth.users u
where lower(u.email) = 'hs23190754@my.sliit.lk'
  and not exists (select 1 from public.profiles p where p.campus_id = 'HS23190754' and p.id <> u.id)
on conflict (id) do update set campus_id = excluded.campus_id,
  full_name = excluded.full_name, role = excluded.role;

insert into public.profiles (id, campus_id, full_name, phone, role)
select id, 'BM22168432', 'B. M. Student', '', 'student'
from auth.users u
where lower(u.email) = 'bm22168432@my.sliit.lk'
  and not exists (select 1 from public.profiles p where p.campus_id = 'BM22168432' and p.id <> u.id)
on conflict (id) do update set campus_id = excluded.campus_id,
  full_name = excluded.full_name, role = excluded.role;

insert into public.profiles (id, campus_id, full_name, phone, role)
select id, 'LEC00001', 'Dr. N. Fernando', '', 'lecturer'
from auth.users u
where lower(u.email) = 'lecturer@my.sliit.lk'
  and not exists (select 1 from public.profiles p where p.campus_id = 'LEC00001' and p.id <> u.id)
on conflict (id) do update set campus_id = excluded.campus_id,
  full_name = excluded.full_name, role = excluded.role;

insert into public.profiles (id, campus_id, full_name, phone, role)
select id, 'LIBR0001', 'Library Librarian', '', 'librarian'
from auth.users u
where lower(u.email) = 'librarian@my.sliit.lk'
  and not exists (select 1 from public.profiles p where p.campus_id = 'LIBR0001' and p.id <> u.id)
on conflict (id) do update set campus_id = excluded.campus_id,
  full_name = excluded.full_name, role = excluded.role;

insert into public.profiles (id, campus_id, full_name, phone, role)
select id, 'STAFF0001', 'Library Staff', '', 'library_staff'
from auth.users u
where lower(u.email) = 'library.staff@my.sliit.lk'
  and not exists (select 1 from public.profiles p where p.campus_id = 'STAFF0001' and p.id <> u.id)
on conflict (id) do update set campus_id = excluded.campus_id,
  full_name = excluded.full_name, role = excluded.role;

insert into public.profiles (id, campus_id, full_name, phone, role)
select id, 'LIB00001', 'Library Administrator', '', 'admin'
from auth.users u
where lower(u.email) = 'admin@my.sliit.lk'
  and not exists (select 1 from public.profiles p where p.campus_id = 'LIB00001' and p.id <> u.id)
on conflict (id) do update set campus_id = excluded.campus_id,
  full_name = excluded.full_name, role = excluded.role;
