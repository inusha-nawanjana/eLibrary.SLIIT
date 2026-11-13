import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import 'common.dart';
import 'reservations.dart';
import 'ebooks.dart';
import 'personal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.ebooks = false});
  final bool ebooks;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void find(String value) {
    if (value.trim().isNotEmpty) {
      push(
        context,
        CatalogueScreen(query: value.trim(), ebooks: widget.ebooks),
      );
    }
  }

  @override
  Widget build(BuildContext c) {
    final state = LibraryScope.of(c);
    final digital = widget.ebooks;
    return Screen(
      tab: digital ? 1 : 0,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      header: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(child: Brand()),
            digital
                ? IconButton(
                    tooltip: 'Downloads',
                    onPressed: () => push(c, const DownloadsScreen()),
                    icon: const Glyph('2e967.svg', size: 24),
                  )
                : Material(
                    color: surface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        if (await ensureLogin(c) && c.mounted) {
                          push(c, const NotificationsScreen());
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Glyph('5c306.svg'),
                      ),
                    ),
                  ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!digital) const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: TextField(
              controller: search,
              onSubmitted: find,
              textInputAction: TextInputAction.search,
              style: txt(14),
              decoration: InputDecoration(
                hintText: digital ? 'Search e-books...' : 'Search for books...',
                hintStyle: txt(14, color: muted),
                filled: true,
                fillColor: surface,
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(15),
                  child: Glyph('c21af.svg', size: 18),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: line),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (digital) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [navy, orange]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WEEKLY HIGHLIGHT',
                    style: txt(
                      12,
                      weight: bold,
                      color: Colors.white.withValues(alpha: .8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Explore 50+ New CS journals\npublished this semester.',
                    style: txt(16, weight: heavy, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Digital Grid Categories', style: txt(16, weight: heavy)),
            const SizedBox(height: 20),
            for (final book in state.books.where((b) => b.ebook))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Panel(
                  radius: 14,
                  padding: const EdgeInsets.all(12),
                  onTap: () => push(c, EbookScreen(book: book)),
                  child: Row(
                    children: [
                      Art(book.cover, width: 48, height: 64, radius: 6),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(book.title, style: txt(13, weight: bold)),
                            const SizedBox(height: 2),
                            Text(
                              book.course.isEmpty
                                  ? book.category
                                  : 'Course Ref: ${book.course}',
                              style: txt(11, color: muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: peach,
                        ),
                        alignment: Alignment.center,
                        child: const Glyph('2ebe2.svg', size: 14),
                      ),
                    ],
                  ),
                ),
              ),
            if (state.books.where((b) => b.ebook).isEmpty)
              const EmptyState(
                'No e-books yet',
                'The library administrator can add digital titles.',
              ),
          ] else ...[
            Text('Browse Categories', style: txt(16, weight: heavy)),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (c, constraints) {
                final width = (constraints.maxWidth - 14) / 2;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (var i = 0; i < categoryNames.length; i++)
                      SizedBox(
                        width: width,
                        height: 160,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x40000000),
                                blurRadius: 6,
                                offset: Offset(3, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => push(
                                c,
                                CatalogueScreen(category: categoryNames[i]),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Art(
                                    asset(categoryAssets[i]),
                                    width: width,
                                    height: 110,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Text(
                                      categoryNames[i],
                                      style: txt(13, weight: bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class CatalogueScreen extends StatefulWidget {
  const CatalogueScreen({
    super.key,
    this.category,
    this.query,
    this.ebooks = false,
  });
  final String? category, query;
  final bool ebooks;
  @override
  State<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends State<CatalogueScreen> {
  bool all = false;
  @override
  Widget build(BuildContext c) {
    final books = LibraryScope.of(c).books
        .where((b) => b.ebook == widget.ebooks)
        .toList();
    final results = books
        .where(
          (b) => widget.query != null
              ? '${b.title} ${b.author} ${b.category}'.toLowerCase().contains(
                  widget.query!.toLowerCase(),
                )
              : b.category == widget.category,
        )
        .toList();
    final category =
        results.firstOrNull?.category ?? widget.category ?? 'Computer Science';
    final recommendations = books
        .where((b) => b.category == category && !results.take(3).contains(b))
        .take(4)
        .toList();
    if (recommendations.isEmpty) {
      recommendations.addAll(books.where((b) => !results.contains(b)).take(4));
    }
    final visible = all || widget.query != null
        ? results
        : results.take(3).toList();
    return Screen(
      title: widget.category ?? 'Search Results',
      back: true,
      tab: widget.ebooks ? 1 : 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.query != null) ...[
            Text('Results for “${widget.query}”', style: txt(14, color: muted)),
            const SizedBox(height: 8),
          ],
          Text(
            'Found ${results.length} publications',
            style: txt(14, weight: semi, color: muted),
          ),
          const SizedBox(height: 20),
          if (results.isEmpty)
            const EmptyState(
              'No books found',
              'Try another title or author. You can also explore the suggestions below.',
            ),
          for (final book in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BookRow(book: book),
            ),
          if (recommendations.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('You might also like', style: txt(16, weight: heavy)),
            const SizedBox(height: 20),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recommendations.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (c, i) {
                  final book = recommendations[i];
                  return SizedBox(
                    width: 200,
                    child: Material(
                      color: surface,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => openBook(c, book),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Art(book.cover, width: 40, height: 56, radius: 6),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  book.title,
                                  style: txt(12, weight: bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (!all && widget.query == null && results.length > 3) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => all = true),
              child: Text(
                'View all ${results.length} publications',
                style: txt(12, color: orange, weight: semi),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

void openBook(BuildContext c, Book book) => push(
  c,
  book.ebook ? EbookScreen(book: book) : BookDetailsScreen(book: book),
);

class BookRow extends StatelessWidget {
  const BookRow({super.key, required this.book});
  final Book book;
  @override
  Widget build(BuildContext c) => Panel(
    padding: const EdgeInsets.all(12),
    shadow: true,
    onTap: () => openBook(c, book),
    child: Row(
      children: [
        Art(book.cover, width: 64, height: 84, radius: 8),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.title,
                style: txt(14, weight: bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'By ${book.author}',
                style: txt(12, color: muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              if (!book.ebook)
                StatusBadge(book.status)
              else
                Text(
                  'Read online',
                  style: txt(11, color: orange, weight: semi),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class BookDetailsScreen extends StatelessWidget {
  const BookDetailsScreen({super.key, required this.book});
  final Book book;
  @override
  Widget build(BuildContext c) => Screen(
    title: 'Book Details',
    back: true,
    centerTitle: true,
    tab: 0,
    trailing: InkResponse(
      onTap: () async {
        await Clipboard.setData(
          ClipboardData(
            text:
                '${book.title}\nBy ${book.author}\n${book.shelf}\neLibrary.SLIIT',
          ),
        );
        if (c.mounted) {
          ScaffoldMessenger.of(
            c,
          ).showSnackBar(const SnackBar(content: Text('Book details copied.')));
        }
      },
      child: const Tooltip(
        message: 'Copy book details',
        child: Glyph('be420.svg', size: 24),
      ),
    ),
    child: Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: navy.withValues(alpha: .11),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Art(
            book.detailCover ?? book.cover,
            width: 180,
            height: 240,
            radius: 16,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          book.title,
          style: txt(20, weight: heavy),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'By ${book.id == 'algorithms' ? 'Thomas H. Cormen, Charles E. Leiserson' : book.author}',
          style: txt(14, color: muted),
          textAlign: TextAlign.center,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(color: line, height: 1),
        ),
        _detail(
          'Published',
          Text('${book.year} (${book.edition})', style: txt(13, weight: semi)),
        ),
        const SizedBox(height: 12),
        _detail(
          'Location',
          Text(
            book.shelf,
            style: txt(13, weight: semi, color: orange),
          ),
        ),
        const SizedBox(height: 12),
        _detail('Status', StatusBadge(book.status)),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(color: line, height: 1),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Synopsis', style: txt(14, weight: bold)),
        ),
        const SizedBox(height: 8),
        Text(book.synopsis, style: txt(13, color: muted, height: 1.5)),
        const SizedBox(height: 20),
        PrimaryButton(
          book.status == 'Available' ? 'Reserve Book' : 'Currently Unavailable',
          color: book.status == 'Available' ? navy : muted,
          onTap: book.status != 'Available'
              ? null
              : () async {
                  if (await ensureLogin(c) && c.mounted) {
                    push(c, BookReservationScreen(book: book));
                  }
                },
        ),
      ],
    ),
  );
  Widget _detail(String label, Widget value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: txt(13, color: muted)),
      const SizedBox(width: 12),
      Flexible(child: value),
    ],
  );
}
