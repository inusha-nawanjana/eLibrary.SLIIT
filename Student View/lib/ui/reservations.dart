import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../library_state.dart';
import '../models.dart';
import 'common.dart';

class StudyScreen extends StatelessWidget {
  const StudyScreen({super.key});
  @override
  Widget build(BuildContext c) {
    final state = LibraryScope.of(c);
    return Screen(
      title: 'Study Space',
      tab: 2,
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: peach,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Glyph('ba1bc.svg', size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reservations must be made at least 15 min in advance.',
                    style: txt(13, weight: semi, color: orange),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 41),
          for (final kind in ['learning', 'discussion']) ...[
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: line),
                boxShadow: [
                  BoxShadow(
                    color: navy.withValues(alpha: .05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () async {
                    if (!await ensureLogin(c) || !c.mounted) return;
                    if (kind == 'learning' && state.role != 'student') {
                      showError(
                        c,
                        const LibraryException(
                          'Learning spaces are reserved for students.',
                        ),
                      );
                      return;
                    }
                    push(c, RoomListScreen(kind: kind));
                  },
                  child: Column(
                    children: [
                      SizedBox(
                        height: 140,
                        width: double.infinity,
                        child: LayoutBuilder(
                          builder: (c, constraints) => ClipRect(
                            child: OverflowBox(
                              maxHeight: kind == 'learning' ? 225.23 : 278.78,
                              minHeight: kind == 'learning' ? 225.23 : 278.78,
                              alignment: kind == 'learning'
                                  ? const Alignment(0, -.44)
                                  : const Alignment(0, .46),
                              child: Art(
                                asset(
                                  kind == 'learning'
                                      ? 'bb015.png'
                                      : '27c37.png',
                                ),
                                width: constraints.maxWidth,
                                height: kind == 'learning' ? 225.23 : 278.78,
                                fit: BoxFit.fill,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${kind == 'learning' ? 'Learning' : 'Discussion'} Space Reservation',
                                    style: txt(16, weight: heavy),
                                  ),
                                ),
                                const Glyph('30b6d.svg', size: 14),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${state.rooms.where((r) => r.kind == kind).length} rooms available',
                              style: txt(13, weight: semi, color: green),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 41),
          ],
        ],
      ),
    );
  }
}

class RoomListScreen extends StatelessWidget {
  const RoomListScreen({super.key, required this.kind});
  final String kind;
  @override
  Widget build(BuildContext c) {
    final rooms = LibraryScope.of(c).rooms.where((r) => r.kind == kind);
    return Screen(
      title: '${kind == 'learning' ? 'Learning' : 'Discussion'} Space',
      back: true,
      tab: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            kind == 'learning'
                ? 'Select a room to begin reservation'
                : 'Select a discussion room to book',
            style: txt(14, weight: semi, color: muted),
          ),
          const SizedBox(height: 16),
          for (final room in rooms)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                padding: const EdgeInsets.all(12),
                shadow: true,
                onTap: () => push(c, RoomReservationScreen(room: room)),
                child: Row(
                  children: [
                    Art(room.cover, width: 64, height: 64, radius: 8),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(room.title, style: txt(14, weight: bold)),
                          const SizedBox(height: 6),
                          StatusBadge(room.occupied ? 'Occupied' : 'Available'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (rooms.isEmpty)
            const EmptyState('No rooms available', 'Please check again later.'),
        ],
      ),
    );
  }
}

class BookReservationScreen extends StatefulWidget {
  const BookReservationScreen({super.key, required this.book});
  final Book book;
  @override
  State<BookReservationScreen> createState() => _BookReservationState();
}

class _BookReservationState extends State<BookReservationScreen> {
  final id = TextEditingController(),
      name = TextEditingController(),
      phone = TextEditingController();
  final form = GlobalKey<FormState>();
  bool initialized = false, agreed = false, busy = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      final s = LibraryScope.of(context);
      id.text = s.campusId;
      name.text = s.fullName;
      phone.text = s.phone;
      initialized = true;
    }
  }

  @override
  void dispose() {
    id.dispose();
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    if (!agreed) {
      showError(
        context,
        const LibraryException(
          'Please agree to collect the book within 48 hours.',
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      final reservation = await LibraryScope.of(context)
          .reserveBook(widget.book, name.text, phone.text);
      if (!mounted) return;
      setState(() => busy = false);
      await approval(context, id: reservation);
      if (mounted) {
        LibraryScope.of(context).selectTab(3);
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Screen(
    title: 'Reserve Book',
    back: true,
    tab: 0,
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Art(widget.book.cover, width: 40, height: 56, radius: 6),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.book.title, style: txt(13, weight: bold)),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.book.author} · ${widget.book.shelf.split(',').first}',
                        style: txt(11, color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Field('Student / Lecturer ID', controller: id, readOnly: true),
          const SizedBox(height: 16),
          Field(
            'Full Name',
            controller: name,
            hint: 'A. K. Perera',
            validator: requiredValue,
          ),
          const SizedBox(height: 16),
          Field(
            'Phone Number',
            controller: phone,
            hint: 'e.g. +94 77 123 4567',
            validator: validPhone,
            keyboard: TextInputType.phone,
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () => setState(() => agreed = !agreed),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: agreed,
                    onChanged: (v) => setState(() => agreed = v!),
                    activeColor: orange,
                    side: const BorderSide(color: orange),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'I agree to collect this book within 48 hours of approval. Failure to collect will automatically cancel this reservation.',
                    style: txt(12, color: muted, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton('Confirm Reservation', onTap: submit, busy: busy),
        ],
      ),
    ),
  );
}

class RoomReservationScreen extends StatefulWidget {
  const RoomReservationScreen({super.key, required this.room});
  final LibraryRoom room;
  @override
  State<RoomReservationScreen> createState() => _RoomReservationState();
}

class _RoomReservationState extends State<RoomReservationScreen> {
  final id = TextEditingController(),
      name = TextEditingController(),
      phone = TextEditingController();
  late final List<TextEditingController> members = List.generate(
    widget.room.kind == 'learning' ? 5 : 8,
    (_) => TextEditingController(),
  );
  final form = GlobalKey<FormState>();
  DateTime day = campusNow;
  int? selected;
  bool initialized = false,
      busy = false,
      uploading = false,
      loadingSlots = true;
  List<int> occupied = [];
  String? slotError;
  final Map<String, String> uploads = {};
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      final s = LibraryScope.of(context);
      id.text = s.campusId;
      name.text = s.fullName;
      phone.text = s.phone;
      initialized = true;
      loadSlots();
    }
  }

  @override
  void dispose() {
    id.dispose();
    name.dispose();
    phone.dispose();
    for (final c in members) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> loadSlots() async {
    setState(() {
      loadingSlots = true;
      slotError = null;
      selected = null;
    });
    try {
      final result = await LibraryScope.of(context)
          .occupiedSlots(widget.room, day);
      if (mounted) setState(() => occupied = result);
    } catch (e) {
      if (mounted) setState(() => slotError = friendlyError(e));
    } finally {
      if (mounted) setState(() => loadingSlots = false);
    }
  }

  bool available(int hour) =>
      !occupied.contains(hour) &&
      campusUtc(
        day,
        hour,
      ).isAfter(DateTime.now().toUtc().add(const Duration(minutes: 15)));
  Future<void> chooseDate() async {
    final now = campusNow;
    final chosen = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
    );
    if (chosen != null && mounted) {
      setState(() => day = chosen);
      await loadSlots();
    }
  }

  Future<void> upload() async {
    setState(() => uploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        allowMultiple: true,
        withData: true,
      );
      if (result == null || !mounted) return;
      if (uploads.length + result.files.length > widget.room.capacity) {
        throw LibraryException(
          'Upload no more than ${widget.room.capacity} ID photos.',
        );
      }
      for (final file in result.files) {
        if (!mounted) return;
        if (file.bytes == null) {
          throw const LibraryException(
            'The image could not be read. Please select it again.',
          );
        }
        final path = await LibraryScope.of(context)
            .uploadId(file.name, file.bytes!);
        if (mounted) setState(() => uploads[path] = file.name);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    if (selected == null || slotError != null) {
      showError(
        context,
        const LibraryException('Select an available time slot.'),
      );
      return;
    }
    setState(() => busy = true);
    try {
      final reservation = await LibraryScope.of(context).reserveRoom(
        widget.room,
        name.text,
        phone.text,
        members.map((m) => m.text.trim()).where((m) => m.isNotEmpty).toList(),
        uploads.keys.toList(),
        day,
        selected!,
      );
      if (!mounted) return;
      setState(() => busy = false);
      await approval(context, id: reservation, room: true);
      if (mounted) {
        LibraryScope.of(context).selectTab(3);
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final learning = widget.room.kind == 'learning',
        min = widget.room.kind == 'learning' ? 3 : 4;
    return Screen(
      title: learning
          ? 'Reserve Room ${widget.room.number}'
          : 'Reserve Discussion Room ${widget.room.number}',
      back: true,
      tab: 2,
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Field(
              learning ? 'Student ID' : 'Student / Lecturer ID',
              controller: id,
              compact: true,
              readOnly: true,
            ),
            const SizedBox(height: 20),
            Field(
              learning ? 'Student Name' : 'Full Name',
              controller: name,
              compact: true,
              hint: learning ? 'e.g. A. K. Perera' : 'e.g. Prof. Anderson',
              validator: requiredValue,
            ),
            const SizedBox(height: 20),
            Field(
              'Phone Number',
              controller: phone,
              compact: true,
              hint: 'e.g. +94 77 123 4567',
              keyboard: TextInputType.phone,
              validator: validPhone,
            ),
            const SizedBox(height: 20),
            Text(
              '${learning ? 'Group Members' : 'Group Attendees'} (Min $min required)',
              style: txt(14, weight: bold),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < members.length; i++) ...[
              Field(
                'Group Member ${i + 1} ID',
                controller: members[i],
                compact: true,
                hint: i < min ? 'ITXXXXXXX' : 'ITXXXXXXX (Optional)',
                validator: i < min ? requiredValue : null,
              ),
              const SizedBox(height: 16),
            ],
            Text(
              learning
                  ? 'Upload Student ID Photos'
                  : 'Upload Attendees ID Photos',
              style: txt(13, weight: semi),
            ),
            const SizedBox(height: 10),
            Panel(
              color: peach,
              onTap: uploading ? null : upload,
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    if (uploading)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: orange,
                        ),
                      )
                    else
                      const Glyph('ffa05.svg', size: 20),
                    const SizedBox(height: 8),
                    Text(
                      'Upload ID images (.jpg, .png)',
                      style: txt(13, weight: semi, color: orange),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'One photo per attendee, including yourself · max 5 MB',
                      style: txt(10, color: muted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            for (final entry in uploads.entries)
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: txt(12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove ${entry.value}',
                    onPressed: () => setState(() => uploads.remove(entry.key)),
                    icon: const Icon(Icons.close, size: 16, color: muted),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            Text('Select Reservation Date', style: txt(13, weight: semi)),
            const SizedBox(height: 10),
            Panel(
              color: surface,
              onTap: chooseDate,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dateLabel(day), style: txt(14)),
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 18,
                    color: muted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Select Time Slot', style: txt(13, weight: semi)),
            const SizedBox(height: 10),
            if (loadingSlots)
              const LinearProgressIndicator(color: orange)
            else if (slotError != null)
              Column(
                children: [
                  Text(slotError!, style: txt(12, color: Colors.red)),
                  TextButton(onPressed: loadSlots, child: const Text('Retry')),
                ],
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final hour in slots)
                    Semantics(
                      selected: selected == hour,
                      button: true,
                      child: InkWell(
                        onTap: available(hour)
                            ? () => setState(() => selected = hour)
                            : null,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selected == hour ? peach : surface,
                            border: Border.all(
                              color: selected == hour ? orange : line,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            slotLabel(hour),
                            style: txt(
                              12,
                              weight: selected == hour ? bold : FontWeight.w500,
                              color: !available(hour)
                                  ? muted.withValues(alpha: .4)
                                  : selected == hour
                                  ? orange
                                  : muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 24),
            PrimaryButton(
              'Confirm Reservation',
              onTap: loadingSlots || uploading ? null : submit,
              busy: busy,
            ),
          ],
        ),
      ),
    );
  }
}
