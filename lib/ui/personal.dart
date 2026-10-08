import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../library_state.dart';
import '../models.dart';
import 'common.dart';
import 'admin.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityState();
}

class _ActivityState extends State<ActivityScreen> {
  int section = 0;
  String filter = 'All';
  bool refreshing = false;
  Future<void> refresh() async {
    setState(() => refreshing = true);
    try {
      await LibraryScope.of(context).refresh();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final state = LibraryScope.of(c),
        kind = ['book', 'learning', 'discussion'][section];
    final bookings = state.bookings.where(
      (b) => b.kind == kind && (filter == 'All' || b.status == filter),
    );
    return Screen(
      title: 'Your Activity',
      tab: 3,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: line)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          section = i;
                          filter = 'All';
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: section == i
                                    ? orange
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Text(
                            ['Books', 'Learning Space', 'Discussion Space'][i],
                            textAlign: TextAlign.center,
                            style: txt(
                              12,
                              weight: section == i ? bold : FontWeight.w500,
                              color: section == i ? orange : muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Filters(
                  values: const ['All', 'Pending', 'Active', 'Completed'],
                  selected: filter,
                  onSelected: (v) => setState(() => filter = v),
                ),
                const SizedBox(height: 16),
                for (final booking in bookings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: BookingCard(booking: booking),
                  ),
                if (bookings.isEmpty)
                  const EmptyState(
                    'No reservations here',
                    'Your requests will appear here after you make a reservation.',
                  ),
                if (!state.demo)
                  TextButton(
                    onPressed: refreshing ? null : refresh,
                    child: Text(
                      refreshing ? 'Refreshing…' : 'Refresh status',
                      style: txt(12, color: orange, weight: semi),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking});
  final Booking booking;
  @override
  Widget build(BuildContext c) {
    final b = booking;
    final room = b.kind != 'book';
    final stamp = room && b.start != null
        ? '${dateLabel(campusDate(b.start!))}, ${slotLabel(campusDate(b.start!).hour)}'
        : dateLabel(b.date);
    return Panel(
      shadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            b.title,
            style: txt(14, weight: bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  b.subtitle,
                  style: txt(12, color: muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(b.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${b.status == 'Active' && !room
                ? 'Return Due'
                : b.status == 'Completed'
                ? 'Completed'
                : 'Reservation'}: $stamp',
            style: txt(11, color: muted),
          ),
          if (b.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Admin note: ${b.note}', style: txt(12, color: muted)),
          ],
          if (b.status == 'Active') ...[
            const SizedBox(height: 12),
            PrimaryButton(
              b.extensionPending
                  ? 'Extension Pending'
                  : room
                  ? 'Extend Time'
                  : 'Extend Date',
              height: 32,
              onTap: b.extensionPending
                  ? null
                  : () => push(c, ExtensionScreen(booking: b)),
              color: b.extensionPending ? muted : navy,
            ),
          ],
        ],
      ),
    );
  }
}

class ExtensionScreen extends StatefulWidget {
  const ExtensionScreen({super.key, required this.booking});
  final Booking booking;
  @override
  State<ExtensionScreen> createState() => _ExtensionState();
}

class _ExtensionState extends State<ExtensionScreen> {
  final note = TextEditingController();
  bool busy = false;
  DateTime? selected;
  late DateTime month;
  bool get book => widget.booking.kind == 'book';
  DateTime get firstDate {
    final current = widget.booking.date;
    final now = campusNow;
    final later = current.isAfter(now) ? current : now;
    return DateTime(later.year, later.month, later.day + 1);
  }

  @override
  void initState() {
    super.initState();
    month = book ? firstDate : campusDate(widget.booking.end!);
    if (book) {
      selected = firstDate;
    } else {
      selected = widget.booking.end!.add(const Duration(hours: 2));
    }
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (selected == null) {
      showError(
        context,
        const LibraryException('Select an extension date or time.'),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await LibraryScope.of(context).extend(
        widget.booking,
        book ? campusUtc(selected!, 0) : selected!,
        note.text,
      );
      if (!mounted) return;
      await approval(context, extension: true);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final b = widget.booking;
    return Screen(
      tab: 3,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              Material(
                color: surface,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(c),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Glyph('c317c.svg', size: 24),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                book ? 'Extend Date' : 'Extend Time',
                style: txt(18, weight: heavy),
              ),
            ],
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT RESERVATION',
                  style: txt(12, weight: bold, color: orange),
                ),
                const SizedBox(height: 8),
                Text(
                  book
                      ? '${b.title} - ${b.subtitle.replaceFirst('Author: ', '')}'
                      : b.title,
                  style: txt(16, weight: bold),
                ),
                const SizedBox(height: 8),
                Text(
                  book
                      ? 'Return Due: ${dateLabel(b.date)}'
                      : 'Scheduled: ${dateLabel(campusDate(b.start!))}, ${slotLabel(campusDate(b.start!).hour)}',
                  style: txt(13, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            book ? 'Select Extension Date' : 'Select Extension Time Slot',
            style: txt(14, weight: semi),
          ),
          const SizedBox(height: 16),
          if (book)
            Center(
              child: CompactCalendar(
                month: month,
                selected: selected,
                firstDate: firstDate,
                onMonth: (m) => setState(() => month = m),
                onDate: (d) => setState(() => selected = d),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 16,
              children: [
                for (final hour in [11, 13, 15])
                  InkWell(
                    onTap: campusDate(b.end!).hour == hour
                        ? () => setState(
                            () =>
                                selected = b.end!.add(const Duration(hours: 2)),
                          )
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: campusDate(b.end!).hour == hour
                            ? orange
                            : surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        slotLabel(hour),
                        style: txt(
                          12,
                          weight: semi,
                          color: campusDate(b.end!).hour == hour
                              ? Colors.white
                              : muted.withValues(alpha: .5),
                        ),
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    'Not Available',
                    style: txt(12, color: muted.withValues(alpha: .5)),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 28),
          Field(
            'Reason for Extension',
            controller: note,
            lines: 4,
            hint: book
                ? 'Need extra time to read this book...'
                : 'Need extra time to complete group presentation slides...',
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            'Confirm Extension',
            height: 46,
            onTap: submit,
            busy: busy,
          ),
        ],
      ),
    );
  }
}

class CompactCalendar extends StatelessWidget {
  const CompactCalendar({
    super.key,
    required this.month,
    required this.selected,
    required this.firstDate,
    required this.onMonth,
    required this.onDate,
  });
  final DateTime month, firstDate;
  final DateTime? selected;
  final ValueChanged<DateTime> onMonth, onDate;
  @override
  Widget build(BuildContext c) {
    final first = DateTime(month.year, month.month, 1),
        offset = DateTime(month.year, month.month, 1).weekday % 7;
    final count = DateTime(month.year, month.month + 1, 0).day;
    return Container(
      width: 244,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 4,
            offset: Offset(2, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  onPressed: () =>
                      onMonth(DateTime(month.year, month.month - 1)),
                  icon: const Icon(Icons.chevron_left),
                ),
              ),
              Expanded(
                child: Text(
                  '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month.month - 1]}   ${month.year}',
                  textAlign: TextAlign.center,
                  style: txt(13),
                ),
              ),
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  onPressed: () =>
                      onMonth(DateTime(month.year, month.month + 1)),
                  icon: const Icon(Icons.chevron_right),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final d in ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'])
                Expanded(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: txt(10, color: muted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ((offset + count) / 7).ceil() * 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 2,
              childAspectRatio: 1.2,
            ),
            itemBuilder: (c, i) {
              final date = first.add(Duration(days: i - offset));
              final valid =
                  date.month == month.month &&
                  !date.isBefore(
                    DateTime(firstDate.year, firstDate.month, firstDate.day),
                  );
              final chosen =
                  selected != null &&
                  date.year == selected!.year &&
                  date.month == selected!.month &&
                  date.day == selected!.day;
              return InkWell(
                onTap: valid ? () => onDate(date) : null,
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: chosen ? orange : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '${date.day}',
                    style: txt(
                      11,
                      color: chosen
                          ? Colors.white
                          : valid
                          ? navy
                          : muted.withValues(alpha: .35),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends State<ProfileScreen> {
  bool updating = false;
  Future<void> changePhoto() async {
    setState(() => updating = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result != null && mounted && result.files.single.bytes != null) {
        await LibraryScope.of(context).updateAvatar(result.files.single.bytes!);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => updating = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final state = LibraryScope.of(c);
    return Screen(
      title: 'Profile',
      tab: 4,
      child: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x40000000),
                        offset: Offset(0, 3),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: Art(
                    state.avatar ?? asset('9fe95.png'),
                    width: 110,
                    height: 110,
                    radius: 55,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Semantics(
                    label: 'Change profile photo',
                    button: true,
                    child: InkWell(
                      onTap: updating ? null : changePhoto,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: orange,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: updating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Glyph('91636.svg', size: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          for (final entry in {
            'Full Name': state.fullName,
            state.role == 'lecturer' ? 'Lecturer ID' : 'Student ID':
                state.campusId,
            'Email Address': state.email,
            'Phone Number': state.phone,
          }.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                color: surface,
                radius: 12,
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: txt(11, weight: semi, color: muted),
                      ),
                      const SizedBox(height: 4),
                      Text(entry.value, style: txt(14, weight: bold)),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          PrimaryButton(
            'Log Out',
            outline: true,
            color: const Color(0xFFEF4444),
            onTap: () async {
              try {
                await state.signOut();
                if (c.mounted) Navigator.of(c).popUntil((r) => r.isFirst);
              } catch (e) {
                if (c.mounted) showError(c, e);
              }
            },
          ),
          if (state.role == 'admin') ...[
            const SizedBox(height: 20),
            PrimaryButton(
              'Admin Dashboard',
              onTap: () => push(c, const AdminScreen()),
            ),
          ],
        ],
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsState();
}

class _NotificationsState extends State<NotificationsScreen> {
  String filter = 'All';
  @override
  Widget build(BuildContext c) {
    final state = LibraryScope.of(c);
    final notices = state.notices.where(
      (n) =>
          filter == 'All' ||
          filter == 'Unread' && !n.read ||
          n.category == filter.toLowerCase(),
    );
    return Screen(
      title: 'Notifications',
      back: true,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Filters(
            values: const ['All', 'Unread', 'Reservations', 'Updates'],
            selected: filter,
            onSelected: (v) => setState(() => filter = v),
          ),
          const SizedBox(height: 32),
          for (final notice in notices)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Panel(
                shadow: true,
                onTap: () async {
                  try {
                    await state.markRead(notice);
                    if (!c.mounted) return;
                    await showDialog<void>(
                      context: c,
                      builder: (d) => AlertDialog(
                        title: Text(notice.title, style: txt(18, weight: bold)),
                        content: Text(
                          notice.body,
                          style: txt(14, color: muted, height: 1.5),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(d),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    );
                  } catch (e) {
                    if (c.mounted) showError(c, e);
                  }
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notice.title,
                            style: txt(14, weight: bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            notice.body,
                            style: txt(12, color: muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 14,
                      height: 20,
                      decoration: BoxDecoration(
                        color: notice.read ? surface : peach,
                        border: Border.all(color: notice.read ? line : orange),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (notices.isEmpty)
            const EmptyState(
              'You’re all caught up',
              'New library updates and reservation notices will appear here.',
            ),
        ],
      ),
    );
  }
}
