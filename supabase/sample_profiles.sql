-- Run this in the Supabase SQL Editor after creating and confirming the
-- sample users in Authentication > Users. Run migration 202610080004 first
-- when using librarian or library_staff roles.
-- Passwords are managed by Supabase Auth and are intentionally not stored here.

insert into public.profiles (id, campus_id, full_name, phone, role)
select id, 'IT21234567', 'A. K. Perera', '+94771234567', 'student'
from auth.users where lower(email) = 'it21234567@my.sliit.lk'
on conflict (id) do update set campus_id = excluded.campus_id,
  full_name = excluded.full_name, role = excluded.role;

insert into public.profiles (id, campus_id, full_name, phone, role)
select id, 'IT23857162', 'I. T. Student', '', 'student'
from auth.users where lower(email) = 'it23857162@my.sliit.lk'
on conflict (id) do update set campus_id = excluded.campus_id,
  full_name = excluded.full_name, role = excluded.role;

insert into public.profiles (id, campus_id, full_name, phone, role)
select id, 'EN23824681', 'E. N. Student', '', 'student'
from auth.users where lower(email) = 'en23824681@my.sliit.lk'
on conflict (id) do update set campus_id = excluded.campus_id,
  full_name = excluded.full_name, role = excluded.role;

insert into public.profiles (id, campus_id, full_name, phone, role)
select id, 'HS23190754', 'H. S. Student', '', 'student'
from auth.users where lower(email) = 'hs23190754@my.sliit.lk'
on conflict (id) do update set campus_id = excluded.campus_id,
  full_name = excluded.full_name, role = excluded.role;

insert into public.profiles (id, campus_id, full_name, phone, role)
select id, 'BM22168432', 'B. M. Student', '', 'student'
from auth.users where lower(email) = 'bm22168432@my.sliit.lk'
on conflict (id) do update set campus_id = excluded.campus_id,
  full_name = excluded.full_name, role = excluded.role;

insert into public.profiles (id, campus_id, full_name, phone, role)
select id, 'LEC00001', 'Dr. N. Fernando', '', 'lecturer'
from auth.users where lower(email) = 'lecturer@my.sliit.lk'
on conflict (id) do update set campus_id = excluded.campus_id,
  full_name = excluded.full_name, role = excluded.role;

insert into public.profiles (id, campus_id, full_name, phone, role)
select id, 'LIBR0001', 'Library Librarian', '', 'librarian'
from auth.users where lower(email) = 'librarian@my.sliit.lk'
on conflict (id) do update set campus_id = excluded.campus_id,
  full_name = excluded.full_name, role = excluded.role;

insert into public.profiles (id, campus_id, full_name, phone, role)
select id, 'STAFF0001', 'Library Staff', '', 'library_staff'
from auth.users where lower(email) = 'library.staff@my.sliit.lk'
on conflict (id) do update set campus_id = excluded.campus_id,
  full_name = excluded.full_name, role = excluded.role;

insert into public.profiles (id, campus_id, full_name, phone, role)
select id, 'LIB00001', 'Library Administrator', '', 'admin'
from auth.users where lower(email) = 'admin@my.sliit.lk'
on conflict (id) do update set campus_id = excluded.campus_id,
  full_name = excluded.full_name, role = excluded.role;
