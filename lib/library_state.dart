import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'catalogue_repository.dart';

class DemoAccount {
  const DemoAccount({
    required this.login,
    required this.password,
    required this.role,
    required this.campusId,
    required this.fullName,
    required this.email,
    this.aliases = const [],
  });

  final String login;
  final String password;
  final String role;
  final String campusId;
  final String fullName;
  final String email;
  final List<String> aliases;

  String get label => switch (role) {
    'library_staff' => 'Library staff',
    'admin' => 'Administrator',
    'librarian' => 'Librarian',
    'lecturer' => 'Lecturer',
    _ => 'Student',
  };

  bool matches(String value) {
    final normalized = value.trim().toLowerCase();
    return [login, ...aliases].any(
      (candidate) => candidate.toLowerCase() == normalized,
    );
  }
}

const demoAccounts = <DemoAccount>[
  DemoAccount(
    login: 'it23857162@my.sliit.lk',
    aliases: ['IT23857162'],
    password: 'ITStudent@123',
    role: 'student',
    campusId: 'IT23857162',
    fullName: 'I. T. Student',
    email: 'it23857162@my.sliit.lk',
  ),
  DemoAccount(
    login: 'en23824681@my.sliit.lk',
    aliases: ['EN23824681'],
    password: 'ENStudent@123',
    role: 'student',
    campusId: 'EN23824681',
    fullName: 'E. N. Student',
    email: 'en23824681@my.sliit.lk',
  ),
  DemoAccount(
    login: 'hs23190754@my.sliit.lk',
    aliases: ['HS23190754'],
    password: 'HSStudent@123',
    role: 'student',
    campusId: 'HS23190754',
    fullName: 'H. S. Student',
    email: 'hs23190754@my.sliit.lk',
  ),
  DemoAccount(
    login: 'bm22168432@my.sliit.lk',
    aliases: ['BM22168432'],
    password: 'BMStudent@123',
    role: 'student',
    campusId: 'BM22168432',
    fullName: 'B. M. Student',
    email: 'bm22168432@my.sliit.lk',
  ),
  DemoAccount(
    login: 'lecturer@my.sliit.lk',
    password: 'Lecturer@12345',
    role: 'lecturer',
    campusId: 'LEC00001',
    fullName: 'Dr. N. Fernando',
    email: 'lecturer@my.sliit.lk',
  ),
  DemoAccount(
    login: 'librarian@my.sliit.lk',
    password: 'Librarian@12345',
    role: 'librarian',
    campusId: 'LIBR0001',
    fullName: 'Library Librarian',
    email: 'librarian@my.sliit.lk',
  ),
  DemoAccount(
    login: 'library.staff@my.sliit.lk',
    password: 'Staff@12345',
    role: 'library_staff',
    campusId: 'STAFF0001',
    fullName: 'Library Staff',
    email: 'library.staff@my.sliit.lk',
  ),
  DemoAccount(
    login: 'admin@my.sliit.lk',
    password: 'Admin@12345',
    role: 'admin',
    campusId: 'LIB00001',
    fullName: 'Library Administrator',
    email: 'admin@my.sliit.lk',
  ),
];

const _studentIdPattern = r'^(IT|EN|HS|BM)2[0-9]{7}$';
final _campusEmailPattern = RegExp(
  r"^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9-]+(?:\.[a-z0-9-]+)+$",
);

String campusEmailDomain() => String.fromEnvironment(
      'CAMPUS_EMAIL_DOMAIN',
      defaultValue: 'my.sliit.lk',
    ).toLowerCase();

String? validateLoginIdentifier(String? value) {
  final input = value?.trim() ?? '';
  if (input.isEmpty) return 'Enter your student ID or campus email.';
  if (input.codeUnits.any((unit) => unit > 0x7f)) {
    return 'Use English letters and numbers only.';
  }
  final upper = input.toUpperCase();
  if (RegExp(_studentIdPattern).hasMatch(upper)) return null;
  if (input.contains('@')) {
    if (!_campusEmailPattern.hasMatch(input.toLowerCase())) {
      return 'Enter a valid campus email address.';
    }
    final domain = input.substring(input.indexOf('@') + 1).toLowerCase();
    if (domain != campusEmailDomain()) {
      return 'Use your @${campusEmailDomain()} campus email address.';
    }
    return null;
  }
  return 'Use IT, EN, HS, or BM followed by 8 digits (for example IT23857162).';
}

String? validateLoginPassword(String? value) {
  final input = value ?? '';
  if (input.isEmpty) return 'Password is required.';
  if (input.length < 8) return 'Password must be at least 8 characters.';
  return null;
}

DemoAccount? demoAccountFor(String login, String password) {
  for (final account in demoAccounts) {
    if (account.matches(login) && account.password == password) return account;
  }
  return null;
}

class LibraryState extends ChangeNotifier {
  LibraryState({this.client});
  final SupabaseClient? client;
  bool get demo => client == null;
  late SharedPreferences preferences;
  bool signedIn = false;
  bool remember = false;
  int tab = 0;
  String campusId = 'IT23857162',
      fullName = 'I. T. Student',
      phone = '+94 77 123 4567';
  String email = 'it23857162@my.sliit.lk', role = 'student';
  bool get isLibraryStaff =>
      role == 'admin' || role == 'librarian' || role == 'library_staff';
  String? avatar;
  List<Book> books = [];
  List<LibraryRoom> rooms = [];
  List<Booking> bookings = [];
  List<LibraryNotice> notices = [];
  Set<String> bookmarks = {}, downloads = {};
  String get storageKey =>
      demo ? 'demo' : client!.auth.currentUser?.id ?? 'guest';
  StreamSubscription<AuthState>? _auth;

  Future<void> initialize() async {
    preferences = await SharedPreferences.getInstance();
    if (demo) {
      books = demoBooks();
      rooms = [
        for (final kind in ['learning', 'discussion'])
          for (var n = 1; n <= (kind == 'learning' ? 8 : 6); n++)
            LibraryRoom(
              '$kind-$n',
              kind,
              n,
              occupied: kind == 'learning'
                  ? [2, 5].contains(n)
                  : [3, 5].contains(n),
            ),
      ];
      bookings = preferences.containsKey('demo.bookings')
          ? decodeRows(preferences.getString('demo.bookings'))
                .map(Booking.fromJson)
                .toList()
          : demoBookings();
      notices = preferences.containsKey('demo.notices')
          ? decodeRows(preferences.getString('demo.notices'))
                .map(LibraryNotice.fromJson)
                .toList()
          : demoNotices();
      final storedDemoEmail = preferences.getString('demo.email')?.toLowerCase();
      final hasKnownDemoAccount = demoAccounts.any(
        (account) => account.email.toLowerCase() == storedDemoEmail,
      );
      if (preferences.getBool('demo.signedIn') == true &&
          !hasKnownDemoAccount) {
        await preferences.remove('demo.signedIn');
        await preferences.remove('demo.email');
        await preferences.remove('demo.campusId');
        await preferences.remove('demo.name');
        await preferences.remove('demo.role');
      }
      signedIn = preferences.getBool('demo.signedIn') ?? false;
      fullName = preferences.getString('demo.name') ?? fullName;
      phone = preferences.getString('demo.phone') ?? phone;
      campusId = preferences.getString('demo.campusId') ?? campusId;
      email = preferences.getString('demo.email') ?? email;
      role = preferences.getString('demo.role') ?? role;
      avatar = preferences.getString('demo.avatar');
    } else {
      signedIn = client!.auth.currentUser != null;
      if (signedIn && preferences.getBool('live.remember') != true) {
        await client!.auth.signOut();
        signedIn = false;
      }
      await refresh();
      _auth = client!.auth.onAuthStateChange.listen((event) {
        if (event.event == AuthChangeEvent.signedOut) {
          signedIn = false;
          bookings = [];
          notices = [];
          tab = 0;
          notifyListeners();
        }
      });
    }
    _loadPersonal();
    notifyListeners();
  }

  void _loadPersonal() {
    bookmarks = (preferences.getStringList('$storageKey.bookmarks') ?? [])
        .toSet();
    downloads = (preferences.getStringList('$storageKey.downloads') ?? [])
        .toSet();
  }

  Future<void> persist() async {
    if (demo) {
      await preferences.setString(
        'demo.bookings',
        jsonEncode(bookings.map((b) => b.toJson()).toList()),
      );
      await preferences.setString(
        'demo.notices',
        jsonEncode(notices.map((n) => n.toJson()).toList()),
      );
      await preferences.setString('demo.name', fullName);
      await preferences.setString('demo.phone', phone);
      await preferences.setString('demo.campusId', campusId);
      await preferences.setString('demo.email', email);
      await preferences.setString('demo.role', role);
    }
    await preferences.setStringList(
      '$storageKey.bookmarks',
      bookmarks.toList(),
    );
    await preferences.setStringList(
      '$storageKey.downloads',
      downloads.toList(),
    );
    notifyListeners();
  }

  Future<void> signIn(
    String id,
    String password, {
    required bool rememberMe,
  }) async {
    final loginError = validateLoginIdentifier(id);
    if (loginError != null) throw LibraryException(loginError);
    final passwordError = validateLoginPassword(password);
    if (passwordError != null) throw LibraryException(passwordError);
    if (demo) {
      final account = demoAccountFor(id, password);
      if (account == null) {
        throw const LibraryException(
          'The demo login details are not recognised. Use one of the sample accounts shown below.',
        );
      }
      signedIn = true;
      remember = rememberMe;
      campusId = account.campusId;
      fullName = account.fullName;
      email = account.email;
      role = account.role;
      await preferences.setBool('demo.signedIn', rememberMe);
      await preferences.setString('demo.campusId', campusId);
      await preferences.setString('demo.name', fullName);
      await preferences.setString('demo.email', email);
      await preferences.setString('demo.role', role);
    } else {
      const domain = String.fromEnvironment(
        'CAMPUS_EMAIL_DOMAIN',
        defaultValue: 'my.sliit.lk',
      );
      final login = id.contains('@')
          ? id.trim()
          : '${id.trim().toLowerCase()}@$domain';
      await client!.auth.signInWithPassword(email: login, password: password);
      signedIn = true;
      await preferences.setBool('live.remember', rememberMe);
      try {
        await refresh();
      } catch (_) {
        await client!.auth.signOut();
        signedIn = false;
        rethrow;
      }
    }
    _loadPersonal();
    notifyListeners();
  }

  Future<void> signOut() async {
    if (!demo) await client!.auth.signOut();
    await preferences.setBool('demo.signedIn', false);
    signedIn = false;
    tab = 0;
    if (!demo) {
      bookings = [];
      notices = [];
      avatar = null;
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    if (demo) {
      notifyListeners();
      return;
    }
    final rawBooks = await client!.from('books').select().order('created_at');
    final availability = await client!.rpc('book_availability') as List;
    final available = {
      for (final row in availability) row['book_id']: row['available'] as int,
    };
    books = rawBooks.map((j) {
      final row = Map<String, dynamic>.from(j);
      row['status'] = (available[row['id']] ?? 0) > 0
          ? 'Available'
          : 'Checked Out';
      final cover = row['cover_path'] as String?;
      if (cover != null && !cover.startsWith('assets/')) {
        row['cover_display'] = client!.storage
            .from('book-covers')
            .getPublicUrl(cover);
      }
      return Book.fromJson(row);
    }).toList();
    final rawRooms = await client!
        .from('rooms')
        .select()
        .eq('enabled', true)
        .order('number');
    rooms = rawRooms
        .map((r) => LibraryRoom(r['id'], r['kind'], r['number']))
        .toList();
    if (signedIn) {
      final p = await client!
          .from('profiles')
          .select()
          .eq('id', client!.auth.currentUser!.id)
          .maybeSingle();
      if (p == null) {
        throw const LibraryException(
          'Your account needs a library profile. Ask your library administrator to complete setup.',
        );
      }
      campusId = p['campus_id'];
      fullName = p['full_name'];
      phone = p['phone'];
      role = p['role'];
      email = client!.auth.currentUser!.email ?? '';
      avatar = p['avatar_path'] == null
          ? null
          : await client!.storage
                .from('avatars')
                .createSignedUrl(p['avatar_path'], 3600);
      final data = await client!
          .from('reservations')
          .select('*, books(title,author), rooms(kind,number,capacity)')
          .order('created_at', ascending: false);
      final extensions = await client!
          .from('extension_requests')
          .select('reservation_id')
          .eq('status', 'pending');
      final pending = extensions.map((e) => e['reservation_id']).toSet();
      bookings = data.map((r) {
        final book = r['books'];
        final room = r['rooms'];
        final status = r['status'] as String;
        return Booking(
          id: r['id'],
          kind: r['kind'],
          title:
              book?['title'] ??
              '${room?['kind'] == 'learning' ? 'Learning' : 'Discussion'} Room ${room?['number']}',
          subtitle: book != null
              ? 'Author: ${book['author']}'
              : 'Capacity: ${room?['capacity']} People',
          status: status[0].toUpperCase() + status.substring(1),
          date: DateTime.parse(r['due_date'] ?? r['created_at']),
          itemId: r['book_id'] ?? r['room_id'],
          start: r['starts_at'] == null ? null : DateTime.parse(r['starts_at']),
          end: r['ends_at'] == null ? null : DateTime.parse(r['ends_at']),
          note: r['admin_note'] ?? '',
          extensionPending: pending.contains(r['id']),
        );
      }).toList();
      final ns = await client!
          .from('notifications')
          .select()
          .order('created_at', ascending: false);
      notices = ns
          .map(
            (n) => LibraryNotice(
              n['id'],
              n['title'],
              n['body'],
              n['category'],
              read: n['read_at'] != null,
            ),
          )
          .toList();
    }
    notifyListeners();
  }

  void selectTab(int index) {
    tab = index;
    notifyListeners();
  }

  void _requireLogin() {
    if (!signedIn) throw const LibraryException('Please sign in to continue.');
  }

  Future<String> reserveBook(Book book, String name, String contact) async {
    _requireLogin();
    if (book.status != 'Available') {
      throw const LibraryException('This book is currently unavailable.');
    }
    if (demo) {
      if (bookings.any(
        (b) =>
            b.itemId == book.id &&
            ['Pending', 'Approved', 'Active'].contains(b.status),
      )) {
        throw const LibraryException(
          'You already have an open reservation for this book.',
        );
      }
      final id = 'SLIIT-RES-${DateTime.now().microsecondsSinceEpoch}';
      bookings.insert(
        0,
        Booking(
          id: id,
          kind: 'book',
          title: book.title,
          subtitle: 'Author: ${book.author}',
          status: 'Pending',
          date: campusNow,
          itemId: book.id,
        ),
      );
      _newNotice(
        'Reservation received',
        'Your request for ${book.title} is waiting for approval.',
      );
      await persist();
      return id;
    }
    final id = await client!.rpc(
      'reserve_book',
      params: {'p_book': book.id, 'p_name': name, 'p_phone': contact},
    ) as String;
    await refresh();
    return id;
  }

  Future<List<int>> occupiedSlots(LibraryRoom room, DateTime date) async {
    final intervals = demo
        ? bookings
              .where(
                (b) =>
                    b.itemId == room.id &&
                    ['Approved', 'Active'].contains(b.status),
              )
              .map(
                (b) => {
                  'starts_at': b.start?.toIso8601String(),
                  'ends_at': b.end?.toIso8601String(),
                },
              )
              .toList()
        : (await client!.rpc(
            'room_bookings',
            params: {
              'p_date':
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
            },
          ) as List).where((r) => r['room_id'] == room.id).toList();
    return slots.where((s) {
      final start = campusUtc(date, s);
      final end = start.add(const Duration(hours: 2));
      return intervals.any(
        (r) =>
            r['starts_at'] != null &&
            DateTime.parse(r['starts_at']).isBefore(end) &&
            DateTime.parse(r['ends_at']).isAfter(start),
      );
    }).toList();
  }

  Future<String> uploadId(String filename, Uint8List bytes) async {
    _requireLogin();
    if (bytes.length > 5 * 1024 * 1024) {
      throw const LibraryException('Each ID image must be smaller than 5 MB.');
    }
    final png =
        bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71;
    final jpg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    if (!png && !jpg) {
      throw const LibraryException('Select a JPG or PNG image.');
    }
    if (demo) return 'demo/${DateTime.now().microsecondsSinceEpoch}/$filename';
    final path =
        '${client!.auth.currentUser!.id}/${DateTime.now().microsecondsSinceEpoch}.${png ? 'png' : 'jpg'}';
    await client!.storage
        .from('student-ids')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: png ? 'image/png' : 'image/jpeg',
          ),
        );
    return path;
  }

  Future<String> reserveRoom(
    LibraryRoom room,
    String name,
    String contact,
    List<String> members,
    List<String> ids,
    DateTime day,
    int hour,
  ) async {
    _requireLogin();
    validateMembers(room.kind, members, campusId);
    if (ids.length < members.length + 1) {
      throw const LibraryException(
        'Upload one ID image for every attendee, including yourself.',
      );
    }
    final start = campusUtc(day, hour);
    if (start.isBefore(
      DateTime.now().toUtc().add(const Duration(minutes: 15)),
    )) {
      throw const LibraryException(
        'Choose a slot at least 15 minutes in the future.',
      );
    }
    if ((await occupiedSlots(room, day)).contains(hour)) {
      throw const LibraryException(
        'That slot is already booked. Please select another.',
      );
    }
    if (demo) {
      final id = 'SLIIT-ROOM-${DateTime.now().microsecondsSinceEpoch}';
      bookings.insert(
        0,
        Booking(
          id: id,
          kind: room.kind,
          title: room.title,
          subtitle: 'Capacity: ${members.length + 1} People',
          status: 'Pending',
          date: day,
          start: start,
          end: start.add(const Duration(hours: 2)),
          itemId: room.id,
        ),
      );
      _newNotice(
        'Room reservation received',
        'Your request for ${room.title} is waiting for approval.',
      );
      await persist();
      return id;
    }
    final id = await client!.rpc(
      'reserve_room',
      params: {
        'p_room': room.id,
        'p_name': name,
        'p_phone': contact,
        'p_members': members,
        'p_id_paths': ids,
        'p_start': start.toIso8601String(),
      },
    ) as String;
    await refresh();
    return id;
  }

  Future<void> extend(Booking booking, DateTime end, String note) async {
    _requireLogin();
    if (booking.status != 'Active' || booking.extensionPending) {
      throw const LibraryException(
        'An extension is already pending or this reservation is not active.',
      );
    }
    if (note.trim().length < 3) {
      throw const LibraryException('Please enter a reason for the extension.');
    }
    final currentEnd = booking.kind == 'book'
        ? campusUtc(booking.date, 0)
        : booking.end!;
    if (!end.isAfter(currentEnd) || !end.isAfter(DateTime.now().toUtc())) {
      throw const LibraryException('Please choose a later date or time.');
    }
    if (booking.kind != 'book') {
      if (end != currentEnd.add(const Duration(hours: 2)) ||
          campusDate(end).hour > 17 ||
          campusDate(end).day != campusDate(currentEnd).day) {
        throw const LibraryException(
          'Only the next two-hour slot, ending by 17:00, can be requested.',
        );
      }
      final room = rooms.where((r) => r.id == booking.itemId).firstOrNull;
      if (room != null &&
          (await occupiedSlots(
            room,
            campusDate(currentEnd),
          )).contains(campusDate(currentEnd).hour)) {
        throw const LibraryException('The next slot is already occupied.');
      }
    }
    if (demo) {
      booking.extensionPending = true;
      _newNotice(
        'Extension requested',
        'Your extension for ${booking.title} is waiting for approval.',
      );
      await persist();
    } else {
      await client!.rpc(
        'request_extension',
        params: {
          'p_reservation': booking.id,
          'p_end': end.toIso8601String(),
          'p_note': note.trim(),
        },
      );
      await refresh();
    }
  }

  void _newNotice(String title, String body) {
    notices.insert(
      0,
      LibraryNotice(
        DateTime.now().microsecondsSinceEpoch.toString(),
        title,
        body,
        'reservations',
      ),
    );
  }

  Future<void> markRead(LibraryNotice notice) async {
    if (!demo) {
      await client!
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', notice.id);
    }
    notice.read = true;
    await persist();
  }

  Future<void> toggleBookmark(Book book) async {
    if (!bookmarks.add(book.id)) bookmarks.remove(book.id);
    await persist();
  }

  Future<Uint8List> ebookBytes(Book book) async {
    if (book.ebookPath == null) {
      throw const LibraryException('This e-book has no file attached.');
    }
    if (book.ebookPath!.startsWith('assets/')) {
      return (await rootBundle.load(book.ebookPath!)).buffer.asUint8List();
    }
    return client!.storage.from('ebooks').download(book.ebookPath!);
  }

  Future<void> downloaded(Book book) async {
    downloads.add(book.id);
    await persist();
  }

  Future<void> removeDownload(String id) async {
    downloads.remove(id);
    await persist();
  }

  Future<void> updateAvatar(Uint8List bytes) async {
    _requireLogin();
    if (bytes.length > 5 * 1024 * 1024) {
      throw const LibraryException('Choose an image smaller than 5 MB.');
    }
    if (demo) {
      avatar = 'data:image/png;base64,${base64Encode(bytes)}';
      await preferences.setString('demo.avatar', avatar!);
    } else {
      final png = bytes.length > 4 && bytes[0] == 137 && bytes[1] == 80;
      final path =
          '${client!.auth.currentUser!.id}/${DateTime.now().microsecondsSinceEpoch}.${png ? 'png' : 'jpg'}';
      await client!.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: png ? 'image/png' : 'image/jpeg',
            ),
          );
      await client!
          .from('profiles')
          .update({'avatar_path': path})
          .eq('id', client!.auth.currentUser!.id);
      avatar = await client!.storage
          .from('avatars')
          .createSignedUrl(path, 3600);
    }
    notifyListeners();
  }

  Future<void> resetPassword(String login) async {
    if (demo) {
      throw const LibraryException(
        'Demo password: ITStudent@123. No reset email is sent in demo mode.',
      );
    }
    const domain = String.fromEnvironment(
      'CAMPUS_EMAIL_DOMAIN',
      defaultValue: 'my.sliit.lk',
    );
    await client!.auth.resetPasswordForEmail(
      login.contains('@')
          ? login.trim()
          : '${login.trim().toLowerCase()}@$domain',
    );
  }

  @override
  void dispose() {
    _auth?.cancel();
    super.dispose();
  }
}

void validateMembers(String kind, List<String> members, String owner) {
  final min = kind == 'learning' ? 3 : 4, max = kind == 'learning' ? 5 : 8;
  if (members.length < min || members.length > max) {
    throw LibraryException('Enter $min to $max group member IDs.');
  }
  final normalized = members.map((s) => s.trim().toUpperCase()).toList();
  if (normalized.any((s) => !RegExp(r'^[A-Z]{2,5}[0-9]{4,10}$').hasMatch(s))) {
    throw const LibraryException('Check the format of every group member ID.');
  }
  if (normalized.toSet().length != normalized.length ||
      normalized.contains(owner.trim().toUpperCase())) {
    throw const LibraryException(
      'Each attendee must have a different ID. Do not repeat your own ID.',
    );
  }
}

class LibraryException implements Exception {
  const LibraryException(this.message);
  final String message;
  @override
  String toString() => message;
}

String friendlyError(Object error) {
  if (error is LibraryException) return error.message;
  if (error is CatalogueException) return error.message;
  if (error is AuthException) return error.message;
  if (error is PostgrestException) {
    if (error.code == '23505') {
      return 'A matching record or open reservation already exists.';
    }
    if (error.code == '23503') {
      return 'This item has reservation history and cannot be deleted. Keep the record; disable the room or set the book copy count to zero when appropriate.';
    }
    if (error.code == '42501') {
      return 'You do not have permission to make this change. Sign in with an administrator account.';
    }
    if (error.code == '23P01') {
      return 'This room is already booked for that time.';
    }
    return error.message;
  }
  if (error is StorageException) return error.message;
  return 'Unable to complete this action. Check your connection and try again.';
}
