import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elibrary_sliit/library_state.dart';
import 'package:elibrary_sliit/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LibraryState state;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    state = LibraryState();
    await state.initialize();
  });
  tearDown(() => state.dispose());

  test('reservations require login and reject duplicate requests', () async {
    final book = state.books.first;
    await expectLater(
      state.reserveBook(book, 'A. K. Perera', '0771234567'),
      throwsA(isA<LibraryException>()),
    );
    await state.signIn('IT21234567', 'Demo@12345', rememberMe: true);
    final id = await state.reserveBook(book, 'A. K. Perera', '0771234567');
    expect(state.bookings.first.id, id);
    expect(state.bookings.first.status, 'Pending');
    await expectLater(
      state.reserveBook(book, 'A. K. Perera', '0771234567'),
      throwsA(isA<LibraryException>()),
    );
    final restored = LibraryState();
    await restored.initialize();
    expect(restored.bookings.first.id, id);
    expect(restored.signedIn, true);
    restored.dispose();
  });
  test('wrong demo credentials never authenticate', () async {
    await expectLater(
      state.signIn('IT21234567', 'wrong', rememberMe: false),
      throwsA(isA<LibraryException>()),
    );
    expect(state.signedIn, false);
  });
  test('demo role accounts authenticate with their assigned roles', () async {
    for (final account in demoAccounts.skip(1)) {
      final accountState = LibraryState();
      await accountState.initialize();
      await accountState.signIn(account.login, account.password, rememberMe: false);
      expect(accountState.signedIn, true);
      expect(accountState.role, account.role);
      expect(accountState.email, account.email);
      accountState.dispose();
    }
  });
  test('login validation accepts campus formats and rejects other alphabets', () {
    expect(validateLoginIdentifier('it23857162'), isNull);
    expect(validateLoginIdentifier('EN20000000'), isNull);
    expect(validateLoginIdentifier('hs20000000'), isNull);
    expect(validateLoginIdentifier('BM20000000'), isNull);
    expect(validateLoginIdentifier('lecturer@my.sliit.lk'), isNull);
    expect(validateLoginIdentifier('IT2385716'), isNotNull);
    expect(validateLoginIdentifier('IT23857162x'), isNotNull);
    expect(validateLoginIdentifier('ІТ23857162'), isNotNull);
    expect(validateLoginIdentifier('student@example.com'), isNotNull);
    expect(validateLoginPassword(''), isNotNull);
    expect(validateLoginPassword('short'), isNotNull);
    expect(validateLoginPassword('Campus@123'), isNull);
  });
  test(
    'member validation rejects duplicates, owner ID and insufficient groups',
    () {
      expect(
        () => validateMembers('learning', [
          'IT2100001',
          'IT2100001',
          'IT2100002',
        ], 'IT21234567'),
        throwsA(isA<LibraryException>()),
      );
      expect(
        () => validateMembers('learning', [
          'IT21234567',
          'IT2100001',
          'IT2100002',
        ], 'IT21234567'),
        throwsA(isA<LibraryException>()),
      );
      expect(
        () => validateMembers('discussion', [
          'IT2100001',
          'IT2100002',
          'IT2100003',
        ], 'IT21234567'),
        throwsA(isA<LibraryException>()),
      );
      expect(
        () => validateMembers('learning', [
          'IT2100001',
          'IT2100002',
          'IT2100003',
        ], 'IT21234567'),
        returnsNormally,
      );
    },
  );
  test('room booking requires attendee photos and a future slot', () async {
    await state.signIn('IT21234567', 'Demo@12345', rememberMe: false);
    final room = state.rooms.first,
        day = campusNow.add(const Duration(days: 2));
    final members = ['IT2100001', 'IT2100002', 'IT2100003'];
    await expectLater(
      state.reserveRoom(
        room,
        'A. K. Perera',
        '0771234567',
        members,
        [],
        day,
        9,
      ),
      throwsA(isA<LibraryException>()),
    );
    await state.reserveRoom(
      room,
      'A. K. Perera',
      '0771234567',
      members,
      ['a', 'b', 'c', 'd'],
      day,
      9,
    );
    expect(state.bookings.first.kind, 'learning');
    expect(state.bookings.first.status, 'Pending');
    await expectLater(
      state.reserveRoom(
        room,
        'A. K. Perera',
        '0771234567',
        members,
        ['a', 'b', 'c', 'd'],
        day.subtract(const Duration(days: 4)),
        9,
      ),
      throwsA(isA<LibraryException>()),
    );
  });
  test('approved room intervals prevent conflicting reservations', () async {
    await state.signIn('IT21234567', 'Demo@12345', rememberMe: false);
    final room = state.rooms.first,
        day = campusNow.add(const Duration(days: 2));
    state.bookings.add(
      Booking(
        id: 'conflict',
        kind: 'learning',
        title: room.title,
        subtitle: '',
        status: 'Approved',
        date: day,
        itemId: room.id,
        start: campusUtc(day, 9),
        end: campusUtc(day, 11),
      ),
    );
    expect(await state.occupiedSlots(room, day), contains(9));
    await expectLater(
      state.reserveRoom(
        room,
        'A. K. Perera',
        '0771234567',
        ['IT2100001', 'IT2100002', 'IT2100003'],
        ['a', 'b', 'c', 'd'],
        day,
        9,
      ),
      throwsA(isA<LibraryException>()),
    );
  });
  test('extension stays pending without silently changing due date', () async {
    await state.signIn('IT21234567', 'Demo@12345', rememberMe: false);
    final booking = state.bookings.firstWhere(
      (b) => b.kind == 'book' && b.status == 'Active',
    );
    final due = booking.date;
    await state.extend(
      booking,
      campusUtc(due.add(const Duration(days: 3)), 0),
      'Need time to finish reading.',
    );
    expect(booking.extensionPending, true);
    expect(booking.date, due);
    await expectLater(
      state.extend(
        booking,
        campusUtc(due.add(const Duration(days: 4)), 0),
        'Another extension',
      ),
      throwsA(isA<LibraryException>()),
    );
  });
  test('unrecognised image bytes are rejected', () async {
    await state.signIn('IT21234567', 'Demo@12345', rememberMe: false);
    await expectLater(
      state.uploadId('bad.png', Uint8List.fromList([1, 2, 3])),
      throwsA(isA<LibraryException>()),
    );
  });
  test('bookmarks, read state and downloads survive a restart', () async {
    final book = state.books.firstWhere((b) => b.ebook);
    await state.toggleBookmark(book);
    await state.downloaded(book);
    await state.markRead(state.notices.first);
    final restored = LibraryState();
    await restored.initialize();
    expect(restored.bookmarks, contains(book.id));
    expect(restored.downloads, contains(book.id));
    expect(restored.notices.first.read, true);
    restored.dispose();
  });
}
