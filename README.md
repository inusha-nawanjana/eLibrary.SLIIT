# eLibrary.SLIIT

Flutter mobile app implementing the supplied Student View Figma design and PDF. Uses the original artwork, Inter font, navy `#112850`, orange `#E9781E`, and white.

## Run in VS Code

1. Open this folder in VS Code and install the recommended **Flutter** extension (it also installs Dart).
2. Select an Android emulator or connect an Android phone with USB debugging enabled.
3. Open `lib/main.dart`, choose **eLibrary Demo** in Run and Debug, and press **F5**.

The Flutter SDK installed for this workspace is `.tools/flutter`. VS Code is configured to find it. You can also use the terminal:

```powershell
.\flutter.ps1 pub get
.\flutter.ps1 run
```

For a browser preview of the same Flutter app:

```powershell
.\flutter.ps1 run -d chrome
```

Android is the initial mobile target. The `web/` target is for convenient preview; this is a Flutter application, with Android project files in `android/`.

## Demo sign-in

| Field | Value |
| --- | --- |
| Student ID | `IT21234567` |
| Password | `Demo@12345` |

The login screen includes a **Fill demo credentials** shortcut. These credentials work only in local demo mode. Real university credentials are not used.

Demo data is stored locally. Book and room requests appear as pending in **Activity** and create in-app notices. Extensions also remain pending; they do not silently change the original reservation. Sample dates are relative to today so future reservations remain testable. Uploads in demo mode are validated but are not sent anywhere. The reader and downloads include clearly labelled original sample PDFs, not full published books.

## Included flows

- Home catalogue, six categories, title/author/category search, related suggestions, book details and availability.
- Login before reservations, book collection agreement, confirmation and activity updates.
- E-books, chapter previews, full-screen reading, PDF viewing, real file download, download history and bookmarks.
- Eight learning rooms and six discussion rooms, member IDs, JPG/PNG uploads, booking dates and four two-hour slots.
- Activity categories and status filters, book-date extensions and room-time extensions.
- Notifications with read state, profile photo selection, logout, splash screen.
- Supabase-only administrator area: book/eBook and room CRUD, dashboard, reservation review, attendee ID inspection, book collection/return status, and extension decisions.

## Supabase connection and CRUD

The Supabase project has not been created yet, so the app still runs in demo mode. Follow [the Supabase setup guide](docs/SUPABASE_SETUP.md) to apply `supabase/setup.sql`, create student/admin profiles, and provide the public project URL and key in `config.local.json`.

Administrator CRUD is available under **Profile > Admin Dashboard > Books / Rooms** when connected to Supabase. It supports adding, listing, editing, and deleting catalogue records, cover/PDF replacement, and room enabling/disabling. Database policies restrict changes to administrators. Items with reservation history cannot be deleted; active loans protect the copy count.

The app supports `SUPABASE_PUBLISHABLE_KEY` and the legacy `SUPABASE_ANON_KEY`. Select **eLibrary Supabase (Chrome)** for a browser or **eLibrary Supabase** for Android. Demo login credentials are separate from real Supabase accounts.

Campus SSO, SMS, email approval messages, and push delivery require authorised external integrations. This version provides in-app notifications. Password reset uses Supabase's configured email flow; configure the project's recovery redirect URL and mobile deep links before enabling recovery in a deployed app. Automatic cancellation after the 48-hour collection window requires a scheduled backend task; the app's agreement text reflects the supplied design.

## Checks and builds

```powershell
.\flutter.ps1 analyze
.\flutter.ps1 test --dart-define=DESIGN_PREVIEW=true
.\flutter.ps1 build apk --debug
```

Validation: Flutter analyzer reported no issues; all 13 tests passed; the final screen-render check passed; Android debug APK packaging succeeded. No Android device was attached for a hardware smoke test.

The tests exercise login/reservation navigation, validation, duplicate requests, room conflicts, extensions, persistence, filters, and narrow layouts. `test/design_preview_test.dart` renders student screens into the ignored `.design/rendered/` folder for comparison with Figma/PDF. `DESIGN_PREVIEW` is test-only; Android normally uses the real device status/navigation areas.

The verified debug APK is `build/app/outputs/flutter-apk/app-debug.apk`. It is for testing, not store publication; configure release signing before publishing.

## Local toolchain notes

The current checkout is `E:/Website/eLibrary.SLIIT`. VS Code and `flutter.ps1` use workspace-relative paths, so moving the checkout does not leave old drive references in launch settings. Flutter, Pub packages, Gradle downloads, and temporary files live under the ignored `.tools/` directory. Build outputs live in `build/` in this checkout; no junction to another drive is required.

On a new clone, install the matching Flutter SDK before running the app:

```powershell
git -c core.longpaths=true clone --depth 1 --branch 3.47.6 https://github.com/flutter/flutter.git .tools/flutter
.\flutter.ps1 pub get
```

The existing system Android SDK is detected separately. The ignored `android/local.properties` is generated by Flutter for this machine. `android/ndk.local.properties` can point to a local NDK installation; remove or regenerate it when moving the checkout. Do not commit generated SDK paths or caches.

Open a new VS Code terminal after changing environment settings. If PowerShell blocks scripts, use `powershell -ExecutionPolicy Bypass -File .\flutter.ps1 run -d chrome`.

## Design references

- Figma: https://www.figma.com/design/U8NmgCcHVUF8tcgQ6zcZCo/eLibrary.SLIIT?node-id=0-1
- Supplied `eLibrary.SLIIT - Student View.pdf` was used, with permission, for remaining screens after the Figma connector reached its plan limit.
- Original asset mapping and verification notes: `docs/design-reference.md`.
