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
- Approvals and rejections call the existing review_reservation RPC. The note is stored in admin_note; existing database triggers notify the requester in the Student View.
- Physical books and eBooks upload cover/PDF files to the existing book-covers and ebooks Storage buckets and create a public.books record.
- Profile name, campus ID, role, phone, and email are read from the signed-in Supabase user and public.profiles.
- Logging out clears the Supabase session.

The dashboard uses the existing schema and policies from Student View/supabase/; it does not require a separate backend server or service-role key. Library announcements are not supported by the current database schema; the optional note form reports this and does not claim to publish.

## Build

```powershell
npm run build
```
