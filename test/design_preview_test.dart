import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elibrary_sliit/library_state.dart';
import 'package:elibrary_sliit/main.dart';
import 'package:elibrary_sliit/ui/common.dart';
import 'package:elibrary_sliit/ui/catalogue.dart';
import 'package:elibrary_sliit/ui/auth.dart';
import 'package:elibrary_sliit/ui/reservations.dart';
import 'package:elibrary_sliit/ui/personal.dart';
import 'package:elibrary_sliit/ui/ebooks.dart';

void main() {
  testWidgets('render student screens for visual review', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final state = LibraryState();
    await state.initialize();
    await state.signIn('IT23857162', 'ITStudent@123', rememberMe: false);
    debugDisableShadows = false;
    await tester.runAsync(() async {
      final loader = FontLoader('Inter')
        ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
      await loader.load();
    });
    final screens = <String, Widget>{
      'home': const HomeScreen(),
      'ebooks': const HomeScreen(ebooks: true),
      'study': const StudyScreen(),
      'profile': const ProfileScreen(),
      'login': const LoginScreen(),
      'catalogue': const CatalogueScreen(category: 'Computer Science'),
      'book': BookDetailsScreen(book: state.books.first),
      'reserve': BookReservationScreen(book: state.books.first),
      'learning': const RoomListScreen(kind: 'learning'),
      'learning_form': RoomReservationScreen(room: state.rooms.first),
      'activity': const ActivityScreen(),
      'notifications': const NotificationsScreen(),
      'extend_book': ExtensionScreen(
        booking: state.bookings.firstWhere(
          (b) => b.kind == 'book' && b.status == 'Active',
        ),
      ),
      'reader': EbookScreen(book: state.books.firstWhere((b) => b.ebook)),
      'splash': const SplashScreen(),
    };
    Directory('.design/rendered').createSync(recursive: true);
    for (final entry in screens.entries) {
      final key = GlobalKey();
      await tester.pumpWidget(
        LibraryScope(
          state: state,
          child: MaterialApp(
            theme: appTheme(),
            home: RepaintBoundary(key: key, child: entry.value),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final file in Directory(
          'assets/figma',
        ).listSync().whereType<File>().where((f) => f.path.endsWith('.png'))) {
          await precacheImage(
            AssetImage(file.path.replaceAll('\\', '/')),
            key.currentContext!,
          );
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: entry.key);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('.design/rendered/${entry.key}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
    state.dispose();
    debugDisableShadows = true;
  });
}
