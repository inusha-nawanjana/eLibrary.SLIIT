-- Run after setup.sql in a test project. All fixture data is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(18);
create temporary table crud_fixture as select gen_random_uuid() as admin_id,
  gen_random_uuid() as student_id, gen_random_uuid() as book_id,
  gen_random_uuid() as room_id, gen_random_uuid() as spare_book_id,
  gen_random_uuid() as spare_room_id,
  (select n from generate_series(900,999) n where not exists
    (select 1 from public.rooms r where r.kind='learning' and r.number=n) order by n limit 1) as room_number,
  (select n from generate_series(900,999) n where not exists
    (select 1 from public.rooms r where r.kind='learning' and r.number=n) order by n limit 1 offset 1) as spare_room_number;
grant select on crud_fixture to anon, authenticated;
insert into auth.users(id,email)
  select admin_id,'crud-admin-'||admin_id||'@example.invalid' from crud_fixture
  union all select student_id,'crud-student-'||student_id||'@example.invalid' from crud_fixture;
insert into public.profiles(id,campus_id,full_name,role)
  select admin_id,'ADMIN-'||admin_id,'CRUD Admin','admin' from crud_fixture
  union all select student_id,'STUDENT-'||student_id,'CRUD Student','student' from crud_fixture;
insert into public.books(id,title,author,category,published_year,copies)
  select book_id,'CRUD fixture','Test','Computer Science',2021,2 from crud_fixture;
insert into public.rooms(id,kind,number,capacity)
  select room_id,'learning',room_number,6 from crud_fixture;
insert into public.reservations(user_id,kind,book_id,status,full_name,phone,due_date)
  select student_id,'book',book_id,'active','CRUD Student','0771234567',current_date+7 from crud_fixture;
insert into public.reservations(user_id,kind,room_id,status,full_name,phone,starts_at,ends_at)
  select student_id,'learning',room_id,'approved','CRUD Student','0771234567',now()+interval '1 day',now()+interval '1 day 2 hours' from crud_fixture;

set local role anon;
select is((select count(*)::int from public.books where id=(select book_id from crud_fixture)),1,'Guests can read catalogue books');
select throws_ok($$insert into public.books(title,author,category) values ('Forbidden','Guest','Law')$$,'42501',null,'Guests cannot create books');
select throws_ok($$delete from public.books where id=(select book_id from crud_fixture)$$,'42501',null,'Guests cannot delete books');

reset role;
select set_config('request.jwt.claim.sub',(select student_id::text from crud_fixture),true);
set local role authenticated;
select throws_ok($$insert into public.books(title,author,category) values ('Forbidden','Student','Law')$$,'42501',null,'Students cannot create books');
with changed as (update public.books set title='Forbidden' where id=(select book_id from crud_fixture) returning id)
select is((select count(*)::int from changed),0,'Students cannot update catalogue books');
with removed as (delete from public.books where id=(select book_id from crud_fixture) returning id)
select is((select count(*)::int from removed),0,'Students cannot delete catalogue books');
select throws_ok($$update public.profiles set role='admin' where id=auth.uid()$$,'42501',null,'Students cannot promote themselves');

reset role;
select set_config('request.jwt.claim.sub',(select admin_id::text from crud_fixture),true);
set local role authenticated;
select lives_ok($$insert into public.books(id,title,author,category,copies) select spare_book_id,'New book','Admin','Law',1 from crud_fixture$$,'Admins can create books');
update public.books set copies=3 where id=(select spare_book_id from crud_fixture);
select is((select copies from public.books where id=(select spare_book_id from crud_fixture)),3,'Admins can update books');
select lives_ok($$insert into public.rooms(id,kind,number,capacity) select spare_room_id,'learning',spare_room_number,6 from crud_fixture$$,'Admins can create rooms');
update public.rooms set enabled=false where id=(select spare_room_id from crud_fixture);
select is((select enabled from public.rooms where id=(select spare_room_id from crud_fixture)),false,'Admins can disable rooms');
select lives_ok($$delete from public.books where id=(select spare_book_id from crud_fixture)$$,'Admins can delete unused books');
select lives_ok($$delete from public.rooms where id=(select spare_room_id from crud_fixture)$$,'Admins can delete unused rooms');
select throws_ok($$delete from public.books where id=(select book_id from crud_fixture)$$,'23503',null,'Books with reservation history cannot be deleted');
select throws_ok($$update public.books set copies=0 where id=(select book_id from crud_fixture)$$,'23514',null,'Copy counts cannot fall below active loans');
select throws_ok($$delete from public.rooms where id=(select room_id from crud_fixture)$$,'23503',null,'Rooms with reservation history cannot be deleted');
select throws_ok($$update public.rooms set number=(select spare_room_number from crud_fixture) where id=(select room_id from crud_fixture)$$,'23514',null,'Room identities with history are protected');

reset role;
select set_config('request.jwt.claim.sub',(select student_id::text from crud_fixture),true);
set local role authenticated;
select is((select count(*)::int from public.profiles where id=(select admin_id from crud_fixture)),0,'Students cannot read another profile');
reset role;
select * from finish();
rollback;
