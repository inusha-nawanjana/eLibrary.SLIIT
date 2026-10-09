# Connect the app to Supabase

The project is configured locally for the Supabase project supplied for this checkout. The public API connection has been verified for catalogue books, rooms, and book availability. The publishable key is kept in ignored `config.local.json`; it is not committed. Demo mode remains available when that file is absent.

## 1. Create the project and tables

The supplied project already has the tables, row-level security policies, reservation functions, storage buckets, fourteen rooms, and five sample catalogue books. Do not rerun `supabase/setup.sql` or migrations 001 through 003 in this project.

For a separate fresh project, run **supabase/setup.sql** once in its SQL Editor. Do not run both the setup bundle and its individual migrations. For an existing database with migrations 001 through 003 already applied, run `supabase/migrations/202610080004_staff_roles.sql` to enable librarian and library-staff profiles.

## 2. Create the sample accounts and profiles

In Authentication > Users, create the sample accounts from the README with confirmed email addresses. For student-ID login, use the faculty email addresses; lecturers and library staff sign in with their full campus email addresses.

After creating the users, run `supabase/sample_profiles.sql` in the SQL Editor. It links each profile to `auth.users` by email, so no Auth UUID copying is needed. Run migration `202610080004_staff_roles.sql` first when using librarian or library-staff roles. The script never stores passwords in `public.profiles`.

For a manual profile insert, valid roles are `student`, `lecturer`, `librarian`, `library_staff`, and `admin`:

```sql
insert into public.profiles (id, campus_id, full_name, phone, role)
values ('REPLACE-WITH-STUDENT-AUTH-UUID', 'IT21234567', 'Student Name', '+94771234567', 'student');

insert into public.profiles (id, campus_id, full_name, phone, role)
values ('REPLACE-WITH-ADMIN-AUTH-UUID', 'LIB00001', 'Library Administrator', '+94771234567', 'admin');
```

Use the passwords chosen when creating those accounts. The demo passwords do not create or authenticate Supabase accounts. The client cannot assign itself a staff role.

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
