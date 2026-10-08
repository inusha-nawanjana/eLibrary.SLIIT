# eLibrary.SLIIT

Flutter mobile app implementing the supplied Student View Figma design and PDF. Uses the original artwork, Inter font, navy `#112850`, orange `#E9781E`, and white.

## Run in VS Code

1. Open this folder in VS Code and install the recommended **Flutter** extension (it also installs Dart).
2. Select an Android emulator or connect an Android phone with USB debugging enabled.
3. Open `lib/main.dart`, choose **eLibrary Demo** in Run and Debug, and press **F5**.

The Flutter SDK installed for this workspace is `.tools/flutter`. VS Code is configured to find it. You can also use the terminal:

```powershell
$env:GRADLE_USER_HOME = 'D:\eLibraryBuildTools\gradle'
.\.tools\flutter\bin\flutter.bat pub get
.\.tools\flutter\bin\flutter.bat run
```

For a browser preview of the same Flutter app:

```powershell
.\.tools\flutter\bin\flutter.bat run -d chrome
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
- Supabase-only administrator area: dashboard, reservation review, attendee ID inspection, book collection/return status, extension decisions, and book/PDF uploads.

## Supabase, when you are ready

Demo mode is the default, as requested. No live database has been created or modified.

1. Create a Supabase project.
2. Run the SQL files in `supabase/migrations/` in filename order using its SQL editor. Optionally run `supabase/seed.sql` once.
3. Create accounts through Supabase Authentication. For ID-based login, use the account email `<student-id>@my.sliit.lk`; the domain can be configured. Lecturer accounts can sign in using their full registered email.
4. Add a corresponding `public.profiles` row with the user's Auth UUID, campus ID, full name, phone and role. Use the dashboard/SQL editor as the trusted administrator; the app cannot grant itself an admin role.
5. Copy `config.example.json` to `config.local.json`, fill in the project URL and **public publishable/anon key**, and choose **eLibrary Supabase** in VS Code. Never put a service-role key in the mobile app.

Example profile setup, replacing the placeholder UUID with a real Auth user ID:

```sql
insert into public.profiles(id,campus_id,full_name,phone,role)
values ('YOUR-AUTH-USER-UUID','IT21234567','A. K. Perera','+94771234567','student');
```

An admin account uses `role = 'admin'`; its Profile screen opens **Admin Dashboard**. Database policies isolate users' reservations and ID images. Server functions enforce approved room conflicts, copy availability, role checks, and extension decisions. The demo does not simulate administrative decisions.

E-books are readable by guests, as in the scenario. Only administrators can upload them. Ensure uploaded PDFs are appropriate for that audience. Private attendee images are available only to their owner and library administrators.

Campus SSO, SMS, email approval messages, and push delivery require authorised external integrations. This version provides in-app notifications. Password reset uses Supabase's configured email flow; configure the project's recovery redirect URL and mobile deep links before enabling recovery in a deployed app. Automatic cancellation after the 48-hour collection window requires a scheduled backend task; the app's agreement text reflects the supplied design.

## Checks and builds

```powershell
.\.tools\flutter\bin\flutter.bat analyze
.\.tools\flutter\bin\flutter.bat test --dart-define=DESIGN_PREVIEW=true
.\.tools\flutter\bin\flutter.bat build apk --debug
```

Validation: Flutter analyzer reported no issues; all 13 tests passed; the final screen-render check passed; Android debug APK packaging succeeded. No Android device was attached for a hardware smoke test.

The tests exercise login/reservation navigation, validation, duplicate requests, room conflicts, extensions, persistence, filters, and narrow layouts. `test/design_preview_test.dart` renders student screens into the ignored `.design/rendered/` folder for comparison with Figma/PDF. `DESIGN_PREVIEW` is test-only; Android normally uses the real device status/navigation areas.

The verified debug APK is `build/app/outputs/flutter-apk/app-debug.apk`. It is for testing, not store publication; configure release signing before publishing.

## Local toolchain notes

The VS Code launch configurations use `D:/eLibraryBuildTools/gradle` for the Gradle cache. When using the terminal, set `$env:GRADLE_USER_HOME` to that directory before Android builds. On another machine, update or remove this environment setting.

The initial Android build exhausted the C: drive while installing the NDK. That build's temporary NDK files were moved, with approval, to `D:/eLibraryBuildTools/ndk-install`. The ignored `android/ndk.local.properties` tells Gradle where to find the extracted NDK. On another machine, omit that file to use the normal Android SDK installation, or set it to your own NDK directory. The generated `build/` directory is a Windows junction to `D:/eLibraryBuildTools/app-build`, so build artifacts also stay off C:. This junction is local and is not committed. Keep several GB free for Gradle and Android build artifacts.

The `.tools/`, `.design/`, machine-local configuration, and build outputs are excluded from Git. On a new checkout, install Flutter and change the VS Code Flutter SDK path if needed.

## Design references

- Figma: https://www.figma.com/design/U8NmgCcHVUF8tcgQ6zcZCo/eLibrary.SLIIT?node-id=0-1
- Supplied `eLibrary.SLIIT - Student View.pdf` was used, with permission, for remaining screens after the Figma connector reached its plan limit.
- Original asset mapping and verification notes: `docs/design-reference.md`.
