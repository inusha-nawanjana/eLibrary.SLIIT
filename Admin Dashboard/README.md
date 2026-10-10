# eLibrary.SLIIT Admin Dashboard

Mobile-first React and TypeScript implementation of the supplied Admin View PDF. The app is set up with Vite and sized around the 390 × 844 mobile artboards.

## Run locally

```powershell
npm install
npm run dev
```

## Current screens

- Admin dashboard overview with reservation and space counts.
- Pending book, learning space, and discussion space requests. Approving or rejecting a request removes it from the local demo list; rejection and approval notes are captured in the confirmation flow.
- Physical book, eBook, and library note forms with local file pickers.
- Admin profile and log out confirmation.

Reservation rows and profile details are sample UI data. This standalone dashboard is not connected to the mobile app's Supabase backend yet.
