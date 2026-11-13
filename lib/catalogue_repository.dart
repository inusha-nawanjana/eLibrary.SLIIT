import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

String newCatalogueId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class CatalogueException implements Exception {
  const CatalogueException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CatalogueFile {
  const CatalogueFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
  bool get png =>
      bytes.length >= 8 &&
      bytes[0] == 137 &&
      bytes[1] == 80 &&
      bytes[2] == 78 &&
      bytes[3] == 71 &&
      bytes[4] == 13 &&
      bytes[5] == 10 &&
      bytes[6] == 26 &&
      bytes[7] == 10;
  void validate({required bool pdf}) {
    final limit = (pdf ? 50 : 5) * 1024 * 1024;
    final valid = pdf
        ? bytes.length >= 5 && String.fromCharCodes(bytes.take(5)) == '%PDF-'
        : png ||
              (bytes.length >= 3 &&
                  bytes[0] == 255 &&
                  bytes[1] == 216 &&
                  bytes[2] == 255);
    if (bytes.isEmpty || bytes.length > limit || !valid) {
      throw CatalogueException(
        pdf
            ? 'Choose a valid PDF of up to 50 MB.'
            : 'Choose a JPG or PNG of up to 5 MB.',
      );
    }
  }
}

class BookDraft {
  const BookDraft({
    required this.title,
    required this.author,
    required this.category,
    required this.year,
    required this.copies,
    this.edition = '',
    this.shelf = '',
    this.synopsis = '',
    this.coverPath,
    this.ebookPath,
  });
  final String title, author, category, edition, shelf, synopsis;
  final String? coverPath, ebookPath;
  final int year, copies;
  void validate({bool attachingPdf = false, bool removingPdf = false}) {
    if (title.trim().isEmpty || author.trim().isEmpty) {
      throw const CatalogueException('Enter the book title and author.');
    }
    if (!categoryNames.contains(category)) {
      throw const CatalogueException('Choose a valid category.');
    }
    if (year < 1 || year > campusNow.year) {
      throw const CatalogueException('Enter a valid published year.');
    }
    if (copies < 0) {
      throw const CatalogueException('The copy count cannot be negative.');
    }
    if (!attachingPdf &&
        (removingPdf || ebookPath == null) &&
        shelf.trim().isEmpty) {
      throw const CatalogueException(
        'Enter a shelf location for a physical book.',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'author': author.trim(),
    'category': category,
    'published_year': year,
    'copies': copies,
    'edition': edition.trim(),
    'shelf': shelf.trim(),
    'synopsis': synopsis.trim(),
    'cover_path': coverPath,
    'ebook_path': ebookPath,
  };
}

/// Uses the signed-in user's JWT. Database RLS, not the UI, authorizes writes.
class CatalogueRepository {
  CatalogueRepository(this.client);
  final SupabaseClient client;
  Future<List<Map<String, dynamic>>> readBooks() =>
      client.from('books').select().order('title');
  Future<List<Map<String, dynamic>>> readRooms() =>
      client.from('rooms').select().order('kind').order('number');

  Future<Map<String, dynamic>> saveBook(
    BookDraft draft, {
    String? id,
    String? creationId,
    CatalogueFile? cover,
    CatalogueFile? pdf,
    bool removePdf = false,
  }) async {
    draft.validate(attachingPdf: pdf != null, removingPdf: removePdf);
    cover?.validate(pdf: false);
    pdf?.validate(pdf: true);
    if (cover == null && (draft.coverPath?.isEmpty ?? true)) {
      throw const CatalogueException('Choose a book cover.');
    }
    final values = draft.toJson();
    if (removePdf) values['ebook_path'] = null;
    final uploads = <(String, String)>[];
    final token =
        '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}';
    var databaseWriteStarted = false;
    try {
      if (cover != null) {
        final path = 'catalogue/$token.${cover.png ? 'png' : 'jpg'}';
        await client.storage
            .from('book-covers')
            .uploadBinary(
              path,
              cover.bytes,
              fileOptions: FileOptions(
                contentType: cover.png ? 'image/png' : 'image/jpeg',
              ),
            );
        uploads.add(('book-covers', path));
        values['cover_path'] = path;
      }
      if (pdf != null) {
        final path = 'catalogue/$token.pdf';
        await client.storage
            .from('ebooks')
            .uploadBinary(
              path,
              pdf.bytes,
              fileOptions: const FileOptions(contentType: 'application/pdf'),
            );
        uploads.add(('ebooks', path));
        values['ebook_path'] = path;
      }
      databaseWriteStarted = true;
      if (id == null) {
        if (creationId != null) {
          values['id'] = creationId;
          return await client
              .from('books')
              .upsert(values, onConflict: 'id')
              .select()
              .single();
        }
        return await client.from('books').insert(values).select().single();
      }
      final row = await client
          .from('books')
          .update(values)
          .eq('id', id)
          .select()
          .maybeSingle();
      if (row == null) {
        throw const CatalogueException(
          'Book not found, or you do not have permission to edit it.',
        );
      }
      return row;
    } catch (error) {
      // A transport failure may occur after commit; keep uploaded files in that case.
      final rejected =
          !databaseWriteStarted ||
          (error is PostgrestException &&
              ((RegExp(r'^[0-9A-Z]{5}$').hasMatch(error.code ?? '') &&
                      !(error.code ?? '').startsWith('08') &&
                      error.code != '40003') ||
                  (error.code ?? '').startsWith('PGRST'))) ||
          error is CatalogueException;
      // Roll back newly uploaded objects if the database write failed.
      // Existing/shared artwork is never removed as part of an edit.
      for (final (bucket, path) in rejected ? uploads : <(String, String)>[]) {
        try {
          await client.storage.from(bucket).remove([path]);
        } catch (_) {
          /* Preserve the original error. */
        }
      }
      rethrow;
    }
  }

  Future<void> deleteBook(String id) async {
    final row = await client
        .from('books')
        .delete()
        .eq('id', id)
        .select('id')
        .maybeSingle();
    if (row == null) {
      throw const CatalogueException(
        'Book not found, or you do not have permission to delete it.',
      );
    }
  }

  Future<Map<String, dynamic>> saveRoom({
    String? id,
    required String kind,
    required int number,
    required bool enabled,
  }) async {
    if (!['learning', 'discussion'].contains(kind) ||
        number < 1 ||
        number > 999) {
      throw const CatalogueException(
        'Choose a room type and a number between 1 and 999.',
      );
    }
    final values = {
      'kind': kind,
      'number': number,
      'capacity': kind == 'learning' ? 6 : 9,
      'enabled': enabled,
    };
    if (id == null) {
      return await client.from('rooms').insert(values).select().single();
    }
    final row = await client
        .from('rooms')
        .update(values)
        .eq('id', id)
        .select()
        .maybeSingle();
    if (row == null) {
      throw const CatalogueException(
        'Room not found, or you do not have permission to edit it.',
      );
    }
    return row;
  }

  Future<void> deleteRoom(String id) async {
    final row = await client
        .from('rooms')
        .delete()
        .eq('id', id)
        .select('id')
        .maybeSingle();
    if (row == null) {
      throw const CatalogueException(
        'Room not found, or you do not have permission to delete it.',
      );
    }
  }
}
