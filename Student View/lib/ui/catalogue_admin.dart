import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../catalogue_repository.dart';
import '../library_state.dart';
import '../models.dart';
import 'common.dart';

class CatalogueManager extends StatefulWidget {
  const CatalogueManager({super.key, this.rooms = false});
  final bool rooms;
  @override
  State<CatalogueManager> createState() => _CatalogueManagerState();
}

class _CatalogueManagerState extends State<CatalogueManager> {
  Future<List<Map<String, dynamic>>>? records;
  bool busy = false;
  CatalogueRepository get repository =>
      CatalogueRepository(LibraryScope.of(context).client!);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    records ??= fetch();
  }

  Future<List<Map<String, dynamic>>> fetch() =>
      widget.rooms ? repository.readRooms() : repository.readBooks();
  void reload() => setState(() => records = fetch());
  Future<void> edit([Map<String, dynamic>? row]) async {
    final saved = await push<bool>(
      context,
      widget.rooms
          ? RoomEditorScreen(record: row)
          : BookEditorScreen(record: row),
    );
    if (saved == true && mounted) reload();
  }

  Future<void> remove(Map<String, dynamic> row) async {
    final title = widget.rooms
        ? '${row['kind']} room ${row['number']}'
        : row['title'];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text(
          'Delete $title?\n\nItems with reservation history must be retained and cannot be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      if (widget.rooms) {
        await repository.deleteRoom(row['id']);
      } else {
        await repository.deleteBook(row['id']);
      }
      if (!mounted) return;
      try {
        await LibraryScope.of(context).refresh();
      } catch (_) {
        /* The delete already committed. The list reload reports connection errors. */
      }
      if (mounted) reload();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PrimaryButton(
        widget.rooms ? 'Add Room' : 'Add Book / eBook',
        onTap: busy ? null : () => edit(),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: busy ? null : reload,
          child: const Text('Refresh'),
        ),
      ),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: records,
        builder: (c, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Column(
              children: [
                Text(friendlyError(snapshot.error!)),
                TextButton(onPressed: reload, child: const Text('Retry')),
              ],
            );
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return Text(
              widget.rooms
                  ? 'No rooms yet. Add your first room.'
                  : 'No books yet. Add your first book.',
              style: txt(14, color: muted),
            );
          }
          return Column(
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.rooms
                              ? '${row['kind'] == 'learning' ? 'Learning' : 'Discussion'} Room ${row['number']}'
                              : row['title'],
                          style: txt(16, weight: bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.rooms
                              ? '${row['capacity']} people ? ${row['enabled'] == true ? 'Enabled' : 'Disabled'}'
                              : '${row['author']}\n${row['category']} ? ${row['copies']} copies${row['ebook_path'] == null ? '' : ' ? eBook'}',
                          style: txt(12, color: muted),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: busy ? null : () => edit(row),
                              child: const Text('Edit'),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: busy ? null : () => remove(row),
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class BookEditorScreen extends StatefulWidget {
  const BookEditorScreen({super.key, this.record});
  final Map<String, dynamic>? record;
  @override
  State<BookEditorScreen> createState() => _BookEditorState();
}

class _BookEditorState extends State<BookEditorScreen> {
  final creationId = newCatalogueId();
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      author = TextEditingController(),
      year = TextEditingController(),
      edition = TextEditingController(),
      shelf = TextEditingController(),
      synopsis = TextEditingController(),
      copies = TextEditingController();
  late String category;
  Map<String, dynamic>? record;
  CatalogueFile? cover, pdf;
  bool busy = false, removePdf = false;
  @override
  void initState() {
    super.initState();
    record = widget.record;
    title.text = record?['title'] ?? '';
    author.text = record?['author'] ?? '';
    year.text = '${record?['published_year'] ?? campusNow.year}';
    edition.text = record?['edition'] ?? '';
    shelf.text = record?['shelf'] ?? '';
    synopsis.text = record?['synopsis'] ?? '';
    copies.text = '${record?['copies'] ?? 1}';
    category = record?['category'] ?? categoryNames.first;
  }

  @override
  void dispose() {
    for (final controller in [
      title,
      author,
      year,
      edition,
      shelf,
      synopsis,
      copies,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> choose(bool ebook) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ebook ? ['pdf'] : ['jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result == null || !mounted) return;
      final selected = result.files.single;
      if (selected.bytes == null) {
        throw const CatalogueException('The selected file could not be read.');
      }
      final file = CatalogueFile(selected.name, selected.bytes!);
      file.validate(pdf: ebook);
      setState(() {
        if (ebook) {
          pdf = file;
          removePdf = false;
        } else {
          cover = file;
        }
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final state = LibraryScope.of(context);
      record = await CatalogueRepository(state.client!).saveBook(
        BookDraft(
          title: title.text,
          author: author.text,
          category: category,
          year: int.parse(year.text),
          copies: int.parse(copies.text),
          edition: edition.text,
          shelf: shelf.text,
          synopsis: synopsis.text,
          coverPath: record?['cover_path'],
          ebookPath: record?['ebook_path'],
        ),
        id: record?['id'],
        creationId: creationId,
        cover: cover,
        pdf: pdf,
        removePdf: removePdf,
      );
      // Once the server confirms a write, do not present a subsequent refresh failure as a failed save.
      try {
        await state.refresh();
      } catch (_) {
        /* The manager reloads independently. */
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final state = LibraryScope.of(c);
    if (!state.signedIn || !state.isLibraryStaff || state.client == null) {
      return const Screen(
        title: 'Library staff access required',
        back: true,
        child: SizedBox.shrink(),
      );
    }
    return Screen(
      title: record == null ? 'Add Book / eBook' : 'Edit Book',
      back: true,
      child: Form(
        key: form,
        child: Column(
          children: [
            const SizedBox(height: 16),
            Field('Book name', controller: title, validator: requiredValue),
            const SizedBox(height: 16),
            Field('Author', controller: author, validator: requiredValue),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: category,
              items: categoryNames
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: busy ? null : (s) => setState(() => category = s!),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 16),
            Field(
              'Published year',
              controller: year,
              keyboard: TextInputType.number,
              validator: (s) {
                final value = int.tryParse(s ?? '');
                return value != null && value > 0 && value <= campusNow.year
                    ? null
                    : 'Enter a valid year.';
              },
            ),
            const SizedBox(height: 16),
            Field('Edition', controller: edition),
            const SizedBox(height: 16),
            Field('Shelf location', controller: shelf),
            const SizedBox(height: 16),
            Field(
              'Number of copies',
              controller: copies,
              keyboard: TextInputType.number,
              validator: (s) => (int.tryParse(s ?? '') ?? -1) >= 0
                  ? null
                  : 'Enter zero or more copies.',
            ),
            const SizedBox(height: 16),
            Field('Synopsis', controller: synopsis, lines: 4),
            const SizedBox(height: 16),
            PrimaryButton(
              cover?.name ??
                  (record?['cover_path'] == null
                      ? 'Choose cover image'
                      : 'Replace cover image'),
              outline: true,
              onTap: busy ? null : () => choose(false),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              pdf?.name ?? 'Attach / replace eBook PDF',
              outline: true,
              onTap: busy ? null : () => choose(true),
            ),
            if (pdf != null)
              TextButton(
                onPressed: busy ? null : () => setState(() => pdf = null),
                child: const Text('Remove selected PDF'),
              ),
            if (record?['ebook_path'] != null && pdf == null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Keep existing eBook PDF'),
                value: !removePdf,
                onChanged: busy ? null : (v) => setState(() => removePdf = !v),
              ),
            const SizedBox(height: 24),
            PrimaryButton(
              record == null ? 'Add Book' : 'Save Changes',
              busy: busy,
              onTap: save,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class RoomEditorScreen extends StatefulWidget {
  const RoomEditorScreen({super.key, this.record});
  final Map<String, dynamic>? record;
  @override
  State<RoomEditorScreen> createState() => _RoomEditorState();
}

class _RoomEditorState extends State<RoomEditorScreen> {
  final form = GlobalKey<FormState>(), number = TextEditingController();
  late String kind;
  late bool enabled;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    kind = widget.record?['kind'] ?? 'learning';
    enabled = widget.record?['enabled'] ?? true;
    number.text = '${widget.record?['number'] ?? ''}';
  }

  @override
  void dispose() {
    number.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final state = LibraryScope.of(context);
      await CatalogueRepository(state.client!).saveRoom(
        id: widget.record?['id'],
        kind: kind,
        number: int.parse(number.text),
        enabled: enabled,
      );
      try {
        await state.refresh();
      } catch (_) {
        /* The confirmed mutation is preserved. */
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final state = LibraryScope.of(c);
    if (!state.signedIn || !state.isLibraryStaff || state.client == null) {
      return const Screen(
        title: 'Library staff access required',
        back: true,
        child: SizedBox.shrink(),
      );
    }
    return Screen(
      title: widget.record == null ? 'Add Room' : 'Edit Room',
      back: true,
      child: Form(
        key: form,
        child: Column(
          children: [
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: kind,
              items: const [
                DropdownMenuItem(
                  value: 'learning',
                  child: Text('Learning space'),
                ),
                DropdownMenuItem(
                  value: 'discussion',
                  child: Text('Discussion space'),
                ),
              ],
              onChanged: busy ? null : (v) => setState(() => kind = v!),
              decoration: const InputDecoration(labelText: 'Room type'),
            ),
            const SizedBox(height: 20),
            Field(
              'Room number',
              controller: number,
              keyboard: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n != null && n > 0 && n <= 999
                    ? null
                    : 'Enter a number between 1 and 999.';
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Capacity: ${kind == 'learning' ? 6 : 9} people, including the requester.',
              style: txt(14, color: muted),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Available for new reservations'),
              value: enabled,
              onChanged: busy ? null : (v) => setState(() => enabled = v),
            ),
            const SizedBox(height: 24),
            PrimaryButton('Save Room', busy: busy, onTap: save),
          ],
        ),
      ),
    );
  }
}
