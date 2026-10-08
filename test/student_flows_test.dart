import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elibrary_sliit/library_state.dart';
import 'package:elibrary_sliit/main.dart';
import 'package:elibrary_sliit/ui/common.dart';

void main() {
  late LibraryState state;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    state = LibraryState();
    await state.initialize();
  });
  tearDown(() => state.dispose());
  Future<void> start(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    await tester.runAsync(() async {
      final loader = FontLoader('Inter')
        ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
      await loader.load();
    });
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(LibraryApp(state: state));
    await tester.pumpAndSettle();
  }

  testWidgets('book reservation resumes after login and appears in Activity', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.text('Computer Science'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Introduction to Algorithms'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reserve Book'));
    await tester.tap(find.text('Reserve Book'));
    await tester.pumpAndSettle();
    expect(find.text('Student / Lecturer ID'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'IT21234567');
    await tester.enterText(find.byType(TextFormField).at(1), 'Demo@12345');
    await tester.ensureVisible(find.text('Login'));
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm Reservation'), findsOneWidget);
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.ensureVisible(find.text('Confirm Reservation'));
    await tester.tap(find.text('Confirm Reservation'));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for Approval'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Your Activity'), findsOneWidget);
    expect(state.bookings.first.title, 'Introduction to Algorithms');
    expect(tester.takeException(), isNull);
  });
  testWidgets('search with no results still suggests related books', (
    tester,
  ) async {
    await start(tester);
    await tester.enterText(find.byType(TextField), 'Unlisted Java title');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('No books found'), findsOneWidget);
    expect(find.text('You might also like'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('primary screens remain usable on a narrow phone', (
    tester,
  ) async {
    await state.signIn('IT21234567', 'Demo@12345', rememberMe: false);
    await start(tester, size: const Size(320, 568));
    for (final tab in [
      'E-books',
      'Study Space',
      'Activity',
      'Profile',
      'Home',
    ]) {
      await tester.tap(
        find.descendant(of: find.byType(BottomBar), matching: find.text(tab)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
  });
  testWidgets('activity filters and logout preserve public browsing', (
    tester,
  ) async {
    await state.signIn('IT21234567', 'Demo@12345', rememberMe: false);
    await start(tester);
    state.selectTab(3);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pending').first);
    await tester.pumpAndSettle();
    expect(find.text('Data Structures & Algorithms'), findsOneWidget);
    expect(find.text('Clean Code'), findsNothing);
    state.selectTab(4);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    expect(find.text('Browse Categories'), findsOneWidget);
    expect(state.signedIn, false);
  });
}
