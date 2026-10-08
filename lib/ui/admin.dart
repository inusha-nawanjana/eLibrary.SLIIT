import 'package:flutter/material.dart';

import '../models.dart';
import 'common.dart';
import 'catalogue_admin.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminState();
}

class _AdminState extends State<AdminScreen> {
  String section = 'Dashboard', kind = 'book';
  bool busy = false;
  Future<void> review(Booking b, bool approve) async {
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(approve ? 'Approve reservation' : 'Reject reservation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(b.title),
            const SizedBox(height: 16),
            Field('Note to requester', controller: note, lines: 3),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    final message = note.text;
    note.dispose();
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      final state = LibraryScope.of(context);
      await state.client!.rpc(
        'review_reservation',
        params: {
          'p_id': b.id,
          'p_status': approve ? 'approved' : 'rejected',
          'p_note': message,
        },
      );
      await state.refresh();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> inspect(Booking b) async {
    try {
      final state = LibraryScope.of(context);
      final r = await state.client!
          .from('reservations')
          .select()
          .eq('id', b.id)
          .single();
      final images = <String>[];
      for (final path in (r['id_paths'] as List)) {
        images.add(
          await state.client!.storage
              .from('student-ids')
              .createSignedUrl(path, 120),
        );
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(b.title),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${r['full_name']}\n${r['phone']}'),
                  const SizedBox(height: 16),
                  Text('Attendees: ${(r['member_ids'] as List).join(', ')}'),
                  for (final image in images)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Art(
                        image,
                        width: 280,
                        height: 180,
                        fit: BoxFit.contain,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> extensions() async {
    try {
      final state = LibraryScope.of(context);
      final requests = await state.client!
          .from('extension_requests')
          .select('*, reservations(books(title), rooms(kind,number))')
          .eq('status', 'pending');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Pending extensions'),
          content: SizedBox(
            width: 330,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (requests.isEmpty) const Text('No extension requests.'),
                  for (final request in requests)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(request['note']),
                          Text('Until: ${request['requested_end']}'),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(d);
                                  await decideExtension(request['id'], false);
                                },
                                child: const Text('Reject'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(d);
                                  await decideExtension(request['id'], true);
                                },
                                child: const Text('Approve'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> decideExtension(String id, bool approve) async {
    try {
      final state = LibraryScope.of(context);
      await state.client!.rpc(
        'review_extension',
        params: {'p_id': id, 'p_approve': approve},
      );
      await state.refresh();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext c) {
    final state = LibraryScope.of(c);
    if (state.role != 'admin' || state.client == null) {
      return const Screen(
        title: 'Admin Dashboard',
        back: true,
        child: EmptyState(
          'Administrator access required',
          'Sign in with an administrator account.',
        ),
      );
    }
    return Screen(
      title: 'Admin Dashboard',
      back: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Filters(
            values: const ['Dashboard', 'Reservations', 'Books', 'Rooms'],
            selected: section,
            onSelected: (s) => setState(() => section = s),
          ),
          const SizedBox(height: 24),
          if (section == 'Dashboard') ...[
            for (final item in {
              'Pending book reservations': state.bookings
                  .where((b) => b.kind == 'book' && b.status == 'Pending')
                  .length,
              'Pending learning reservations': state.bookings
                  .where((b) => b.kind == 'learning' && b.status == 'Pending')
                  .length,
              'Pending discussion reservations': state.bookings
                  .where((b) => b.kind == 'discussion' && b.status == 'Pending')
                  .length,
              'Books reserved / borrowed': state.bookings
                  .where(
                    (b) =>
                        b.kind == 'book' &&
                        ['Approved', 'Active'].contains(b.status),
                  )
                  .length,
              'Learning rooms': state.rooms
                  .where((r) => r.kind == 'learning')
                  .length,
              'Discussion rooms': state.rooms
                  .where((r) => r.kind == 'discussion')
                  .length,
            }.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Panel(
                  child: Row(
                    children: [
                      Expanded(child: Text(item.key, style: txt(14))),
                      Text(
                        '${item.value}',
                        style: txt(24, weight: heavy, color: orange),
                      ),
                    ],
                  ),
                ),
              ),
            PrimaryButton('Review extension requests', onTap: extensions),
          ] else if (section == 'Reservations') ...[
            Filters(
              values: const ['book', 'learning', 'discussion'],
              selected: kind,
              onSelected: (v) => setState(() => kind = v),
            ),
            const SizedBox(height: 16),
            for (final b in state.bookings.where(
              (b) =>
                  b.kind == kind &&
                  ['Pending', 'Approved', 'Active'].contains(b.status),
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.title, style: txt(16, weight: bold)),
                      const SizedBox(height: 8),
                      StatusBadge(b.status),
                      TextButton(
                        onPressed: () => inspect(b),
                        child: const Text('View request and ID photos'),
                      ),
                      if (b.status == 'Pending')
                        Row(
                          children: [
                            Expanded(
                              child: PrimaryButton(
                                'Reject',
                                outline: true,
                                color: Colors.red,
                                onTap: busy ? null : () => review(b, false),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: PrimaryButton(
                                'Approve',
                                onTap: busy ? null : () => review(b, true),
                              ),
                            ),
                          ],
                        )
                      else
                        PrimaryButton(
                          b.status == 'Approved'
                              ? 'Mark collected / in use'
                              : 'Mark completed',
                          onTap: () async {
                            try {
                              await state.client!.rpc(
                                'review_reservation',
                                params: {
                                  'p_id': b.id,
                                  'p_status': b.status == 'Approved'
                                      ? 'active'
                                      : 'completed',
                                  'p_note': '',
                                },
                              );
                              await state.refresh();
                            } catch (e) {
                              if (c.mounted) showError(c, e);
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
          ] else if (section == 'Books')
            const CatalogueManager(key: ValueKey('books'))
          else
            const CatalogueManager(key: ValueKey('rooms'), rooms: true),
        ],
      ),
    );
  }
}
