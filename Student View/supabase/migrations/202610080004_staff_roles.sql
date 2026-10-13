-- Allow the demo's librarian and library-staff roles to use the staff policies.
-- The function name is retained for compatibility with existing policies.
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role in ('student','lecturer','librarian','library_staff','admin'));

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public
as $$
  select exists(
    select 1
    from profiles
    where id = auth.uid()
      and role in ('librarian','library_staff','admin')
  )
$$;
