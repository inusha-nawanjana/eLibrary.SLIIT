# Connect the app to Supabase

The project is currently unconnected: a Supabase project has not been created yet. Demo mode remains available. The CRUD client and database setup files are ready for a real project; they are not evidence of a live database deployment.

## 1. Create the project and tables

Create a project at https://supabase.com/dashboard. Open its SQL Editor and run **supabase/setup.sql** once in a fresh project. It creates the tables, row-level security policies, reservation functions, storage buckets, fourteen rooms, and five sample catalogue books.

Do not run both the setup bundle and its individual migrations. For an existing database with migrations 001 and 002 already applied, run only `supabase/migrations/202610080003_catalogue_crud.sql`.

## 2. Create a student and administrator

In Authentication > Users, create the accounts with confirmed email addresses. For student-ID login, use an address such as `it21234567@my.sliit.lk`. An administrator can sign in with their full email address.

Copy each account's Auth UUID and create its corresponding profile in the SQL Editor:

```sql
insert into public.profiles (id, campus_id, full_name, phone, role)
values ('REPLACE-WITH-STUDENT-AUTH-UUID', 'IT21234567', 'Student Name', '+94771234567', 'student');

insert into public.profiles (id, campus_id, full_name, phone, role)
values ('REPLACE-WITH-ADMIN-AUTH-UUID', 'LIB00001', 'Library Administrator', '+94771234567', 'admin');
```

Use the passwords chosen when creating those accounts. The demo password does not create or authenticate a Supabase account. The client cannot assign itself the admin role.

## 3. Supply the public connection details

Copy `config.example.json` to the ignored `config.local.json`. Set `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` using the project's Connect panel. A legacy anon key also works; the app still accepts the older `SUPABASE_ANON_KEY` name. Never use a secret or service-role key in this file or app.

Choose **eLibrary Supabase (Chrome)** in VS Code, or run:

```powershell
.\flutter.ps1 run -d chrome --web-port=5188 --no-web-resources-cdn --dart-define-from-file=config.local.json
```

For an Android device, choose **eLibrary Supabase** or omit `-d chrome` from the command. Fully restart the app after changing compile-time connection details.

## 4. Verify CRUD

Sign in as the administrator, open Profile > Admin Dashboard, then select **Books** or **Rooms**.

- Books: add, list, edit metadata/copy count/cover/PDF, explicitly remove a PDF, and delete a book with no reservation history.
- Rooms: add, list, edit, disable/enable, and delete a room with no reservation history. Room capacities follow the supplied learning/discussion requirements.
- Students: browse records and use the existing reservation, extension, notification, and profile-photo flows. They cannot mutate catalogue data.

Then sign in as a student and verify the changes are visible. Deleting a catalogue item referenced by any reservation is intentionally rejected so activity history stays valid. Copy counts cannot fall below approved/active loans. Rooms with history cannot change their type or number; disable them instead.

New uploads are rolled back after a definite rejected database write. Files are retained when a network failure leaves the commit outcome uncertain. Replaced or deleted records' older files are retained to avoid breaking shared references; storage cleanup is a separate administrative task.

Local mocked-HTTP tests cover the client CRUD requests and error handling. Run `supabase/tests/catalogue_crud.sql` in a test project's SQL Editor for transactional database/RLS checks. Live login, storage, and CRUD still require verification against your configured project.

References: https://supabase.com/docs/guides/getting-started/quickstarts/flutter and https://supabase.com/docs/guides/database/postgres/row-level-security
