-- Published library notes are shared with users as Updates notifications.
begin;

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(trim(title)) between 1 and 120),
  body text not null check (length(trim(body)) between 1 and 4000),
  image_paths text[] not null default '{}',
  author_id uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

alter table public.notifications
  add column if not exists announcement_id uuid references public.announcements(id) on delete set null;

alter table public.announcements enable row level security;
drop policy if exists announcements_read on public.announcements;
create policy announcements_read on public.announcements for select to authenticated
  using (true);
drop policy if exists announcements_publish on public.announcements;
create policy announcements_publish on public.announcements for insert to authenticated
  with check (author_id = auth.uid() and public.is_admin());
grant select, insert on public.announcements to authenticated;
revoke update, delete on public.announcements from anon, authenticated;

create or replace function public.notify_announcement()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications(user_id, title, body, category, announcement_id)
  select p.id, 'Library Update: ' || new.title, new.body, 'updates', new.id
  from public.profiles p;
  return new;
end;
$$;

drop trigger if exists announcement_notifications on public.announcements;
create trigger announcement_notifications after insert on public.announcements
  for each row execute function public.notify_announcement();

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('announcement-images', 'announcement-images', true, 5242880,
  array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists announcement_images_read on storage.objects;
create policy announcement_images_read on storage.objects for select
  using (bucket_id = 'announcement-images');
drop policy if exists announcement_images_admin_write on storage.objects;
create policy announcement_images_admin_write on storage.objects for all to authenticated
  using (bucket_id = 'announcement-images' and public.is_admin())
  with check (bucket_id = 'announcement-images' and public.is_admin());

commit;
