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
