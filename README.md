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

If Chrome or Edge cannot start because Windows reports that the paging file is too small, run the **eLibrary Demo (Web server)** VS Code configuration instead, or use:

```powershell
.\flutter.ps1 run -d web-server --web-port=5188 --no-web-resources-cdn
```

Open the localhost URL printed by Flutter in an already-open browser. Increase Windows virtual memory before retrying Edge: **System Properties → Advanced → Performance Settings → Advanced → Virtual memory**, select **System managed size**, then restart Windows.

Android is the initial mobile target. The `web/` target is for convenient preview; this is a Flutter application, with Android project files in `android/`.

## Demo sign-in

| Field | Value |
| --- | --- |
| Student ID or email | `IT23857162` or `it23857162@my.sliit.lk` |
| Password | `ITStudent@123` |

Additional local demo accounts are available on the login screen:

| Role | Login | Password |
| --- | --- | --- |
| Faculty of Computing student | `it23857162@my.sliit.lk` | `ITStudent@123` |
| Engineering student | `en23824681@my.sliit.lk` | `ENStudent@123` |
| Humanities and Sciences student | `hs23190754@my.sliit.lk` | `HSStudent@123` |
| School of Management student | `bm22168432@my.sliit.lk` | `BMStudent@123` |
| Lecturer | `lecturer@my.sliit.lk` | `Lecturer@12345` |
| Librarian | `librarian@my.sliit.lk` | `Librarian@12345` |
| Library staff | `library.staff@my.sliit.lk` | `Staff@12345` |
| Administrator | `admin@my.sliit.lk` | `Admin@12345` |

Student IDs must use `IT`, `EN`, `HS`, or `BM` followed by eight numbers, such as `it23857162`; lowercase is accepted and converted internally. Campus emails must use the configured `@my.sliit.lk` domain. The login form rejects blank passwords, short passwords, non-ASCII characters, and invalid identifiers. These credentials work only in local demo mode. Real university credentials are not used.

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

The project is now configured for Supabase in the local ignored `config.local.json`. Follow [the Supabase setup guide](docs/SUPABASE_SETUP.md) to create Auth users and matching profiles for students, lecturers, librarians, library staff, or administrators. Demo mode remains available when the file is absent.

Library staff CRUD is available under **Profile > Admin Dashboard > Books / Rooms** when connected to Supabase. It supports adding, listing, editing, and deleting catalogue records, cover/PDF replacement, and room enabling/disabling. Database policies restrict changes to librarians, library staff, and administrators. Items with reservation history cannot be deleted; active loans protect the copy count.

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
