# eLibrary.SLIIT Admin Dashboard

React, TypeScript, and Vite dashboard connected to the same Supabase project as the Student View.

## Run locally

The dashboard reads VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY from .env.local. The checked-out Student View has its own ignored config.local.json; copy those values into this folder's .env.local file. A publishable/anon key is safe for browser use because database access is protected by Supabase Auth and row-level security. Never use a service-role key in a browser app.

```powershell
Copy-Item .env.example .env.local
# Set the Supabase URL and publishable key in .env.local
npm install
npm run dev
```

Restart Vite after changing environment values. The dashboard prompts for a Supabase email and password, then checks that the matching profile has the admin, librarian, or library_staff role.

## Connected workflows

- Dashboard counts are read from live reservations, books, and enabled rooms.
- Pending book, learning-room, and discussion-room requests load from public.reservations.
- Approvals set reservations directly to active, while rejections set them to rejected. Both call the review_reservation RPC; the note is stored in admin_note and database triggers notify the requester in the Student View.
- Physical books and eBooks upload cover/PDF files to the existing book-covers and ebooks Storage buckets and create a public.books record.
- Library notes create persistent public.announcements records, upload optional photos to announcement-images, and broadcast an Updates notification to each profile. Student View notifications show the note and attached photos.
- Profile name, campus ID, role, phone, and email are read from the signed-in Supabase user and public.profiles.
- Logging out clears the Supabase session.

The dashboard uses the existing Supabase project and row-level security; it does not require a separate backend server or service-role key. For an existing database, run Student View/supabase/migrations/202610130002_library_announcements.sql in the Supabase SQL Editor before publishing notes. Fresh databases created with Student View/supabase/setup.sql already include announcements.

## Build

```powershell
npm run build
```
