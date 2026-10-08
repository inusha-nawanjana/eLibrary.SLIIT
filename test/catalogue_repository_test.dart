import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:elibrary_sliit/catalogue_repository.dart';
import 'package:elibrary_sliit/library_state.dart';
import 'package:elibrary_sliit/main.dart';
import 'package:elibrary_sliit/models.dart';
import 'package:elibrary_sliit/ui/catalogue_admin.dart';
import 'package:elibrary_sliit/ui/common.dart';

const itemId = '00000000-0000-4000-8000-000000000001';
BookDraft draft({String title = 'Algorithms', int copies = 2, String? pdf}) =>
    BookDraft(
      title: title,
      author: 'Author',
      category: 'Computer Science',
      year: 2021,
      copies: copies,
      shelf: 'A-1',
      coverPath: 'assets/figma/88bd2.png',
      ebookPath: pdf,
    );
http.Response response(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);
SupabaseClient clientFor(Future<http.Response> Function(http.Request) handler) {
  final client = SupabaseClient(
    'https://library-test.supabase.co',
    'public-test-key',
    httpClient: MockClient((request) async {
      final result = await handler(request);
      return http.Response.bytes(
        result.bodyBytes,
        result.statusCode,
        headers: result.headers,
        request: request,
      );
    }),
  );
  addTearDown(client.dispose);
  return client;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('book create/read/update/delete uses matching IDs and preserves attachment paths', () async {
    final rows = <Map<String, dynamic>>[];
    final methods = <String>[];
    final repo = CatalogueRepository(
      clientFor((request) async {
        expect(request.url.path, '/rest/v1/books');
        methods.add(request.method);
        switch (request.method) {
          case 'GET':
            return response(rows);
          case 'POST':
            rows.add({
              'id': itemId,
              ...jsonDecode(request.body) as Map<String, dynamic>,
            });
            return response(rows.single, 201);
          case 'PATCH':
            expect(request.url.queryParameters['id'], 'eq.$itemId');
            rows.single.addAll(
              jsonDecode(request.body) as Map<String, dynamic>,
            );
            return response(rows.single);
          case 'DELETE':
            expect(request.url.queryParameters['id'], 'eq.$itemId');
            rows.clear();
            return response({'id': itemId});
          default:
            throw StateError('Unexpected request');
        }
      }),
    );
    final created = await repo.saveBook(draft(pdf: 'existing.pdf'));
    expect(created['id'], itemId);
    expect((await repo.readBooks()).single['title'], 'Algorithms');
    final edited = await repo.saveBook(
      draft(title: 'Revised Algorithms', pdf: 'existing.pdf'),
      id: itemId,
    );
    expect(edited['title'], 'Revised Algorithms');
    expect(edited['cover_path'], 'assets/figma/88bd2.png');
    expect(edited['ebook_path'], 'existing.pdf');
    await repo.deleteBook(itemId);
    expect(await repo.readBooks(), isEmpty);
    expect(methods, ['POST', 'GET', 'PATCH', 'DELETE', 'GET']);
  });

  test('book update can explicitly remove a PDF', () async {
    final repo = CatalogueRepository(
      clientFor((request) async {
        final data = jsonDecode(request.body) as Map<String, dynamic>;
        expect(data.containsKey('ebook_path'), isTrue);
        expect(data['ebook_path'], isNull);
        return response({'id': itemId, ...data});
      }),
    );
    await repo.saveBook(draft(pdf: 'old.pdf'), id: itemId, removePdf: true);
  });

  test(
    'validation prevents invalid copies and invalid uploads before any request',
    () async {
      var calls = 0;
      final repo = CatalogueRepository(
        clientFor((_) async {
          calls++;
          return response({});
        }),
      );
      await expectLater(
        repo.saveBook(draft(copies: -1)),
        throwsA(isA<CatalogueException>()),
      );
      await expectLater(
        repo.saveBook(
          draft(),
          pdf: CatalogueFile('bad.pdf', Uint8List.fromList([1, 2, 3])),
        ),
        throwsA(isA<CatalogueException>()),
      );
      await expectLater(
        repo.saveBook(
          draft(),
          cover: CatalogueFile('bad.png', Uint8List.fromList([137, 80])),
        ),
        throwsA(isA<CatalogueException>()),
      );
      expect(calls, 0);
    },
  );

  test(
    'RLS rejection propagates and failed inserts remove newly uploaded objects',
    () async {
      final calls = <String>[];
      final repo = CatalogueRepository(
        clientFor((request) async {
          calls.add('${request.method} ${request.url.path}');
          if (request.url.path.startsWith('/storage/v1/object/')) {
            if (request.method == 'DELETE') {
              expect(
                (jsonDecode(request.body)['prefixes'] as List).single,
                startsWith('catalogue/'),
              );
              return response([]);
            }
            return response({'Key': 'book-covers/new.png'});
          }
          return response({
            'code': '42501',
            'message': 'new row violates row-level security policy',
          }, 403);
        }),
      );
      final cover = CatalogueFile(
        'cover.png',
        Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0]),
      );
      await expectLater(
        repo.saveBook(draft(), cover: cover),
        throwsA(isA<PostgrestException>()),
      );
      expect(
        calls.where((s) => s.startsWith('DELETE /storage/')),
        hasLength(1),
      );
    },
  );

  test(
    'uncertain network outcome never deletes assets which may have committed',
    () async {
      var deletes = 0;
      final repo = CatalogueRepository(
        clientFor((request) async {
          if (request.url.path.startsWith('/storage/')) {
            if (request.method == 'DELETE') {
              deletes++;
              return response([]);
            }
            return response({'Key': 'book-covers/new.png'});
          }
          throw http.ClientException('Connection closed before the response');
        }),
      );
      final cover = CatalogueFile(
        'cover.png',
        Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0]),
      );
      await expectLater(
        repo.saveBook(draft(), cover: cover),
        throwsA(isA<http.ClientException>()),
      );
      expect(deletes, 0);
    },
  );

  test(
    'delete preserves FK protection and empty updates cannot claim success',
    () async {
      final repo = CatalogueRepository(
        clientFor(
          (request) async => request.method == 'DELETE'
              ? response({
                  'code': '23503',
                  'message': 'foreign key violation',
                }, 409)
              : response([]),
        ),
      );
      await expectLater(
        repo.deleteBook(itemId),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        repo.saveBook(draft(), id: itemId),
        throwsA(isA<CatalogueException>()),
      );
      expect(
        friendlyError(
          const PostgrestException(
            message: 'foreign key violation',
            code: '23503',
          ),
        ),
        contains('reservation history'),
      );
    },
  );

  test('room CRUD sends expected capacities and supports disabling', () async {
    Map<String, dynamic>? room;
    final repo = CatalogueRepository(
      clientFor((request) async {
        expect(request.url.path, '/rest/v1/rooms');
        if (request.method == 'GET') {
          return response(room == null ? [] : [room]);
        }
        if (request.method == 'DELETE') {
          room = null;
          return response({'id': itemId});
        }
        if (request.method == 'PATCH') {
          expect(request.url.queryParameters['id'], 'eq.$itemId');
        }
        room = {
          'id': itemId,
          ...jsonDecode(request.body) as Map<String, dynamic>,
        };
        return response(room!);
      }),
    );
    await repo.saveRoom(kind: 'learning', number: 9, enabled: true);
    expect((await repo.readRooms()).single['capacity'], 6);
    await repo.saveRoom(
      id: itemId,
      kind: 'learning',
      number: 9,
      enabled: false,
    );
    expect((await repo.readRooms()).single['enabled'], false);
    await repo.deleteRoom(itemId);
    expect(await repo.readRooms(), isEmpty);
    await expectLater(
      repo.saveRoom(kind: 'other', number: 0, enabled: true),
      throwsA(isA<CatalogueException>()),
    );
  });

  test('display URLs do not replace editable storage keys', () {
    final book = Book.fromJson({
      'id': itemId,
      ...draft().toJson(),
      'cover_display': 'https://example.com/cover.png',
    });
    expect(book.cover, 'https://example.com/cover.png');
    expect(book.coverPath, 'assets/figma/88bd2.png');
    expect(book.copies, 2);
  });

  testWidgets('book editor pre-fills metadata and rejects negative copies', (
    tester,
  ) async {
    var requests = 0;
    final client = clientFor((_) async {
      requests++;
      return response([]);
    });
    final state = LibraryState(client: client)
      ..signedIn = true
      ..role = 'admin';
    addTearDown(state.dispose);
    await tester.pumpWidget(
      LibraryScope(
        state: state,
        child: MaterialApp(
          theme: appTheme(),
          home: BookEditorScreen(record: {'id': itemId, ...draft().toJson()}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Algorithms'), findsOneWidget);
    final copiesField = find.descendant(
      of: find.widgetWithText(Field, 'Number of copies'),
      matching: find.byType(TextFormField),
    );
    await tester.ensureVisible(copiesField);
    await tester.enterText(copiesField, '-1');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.text('Enter zero or more copies.'), findsOneWidget);
    expect(requests, 0);
  });
}
