import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models.dart';
import 'common.dart';

class EbookScreen extends StatefulWidget {
  const EbookScreen({super.key, required this.book});
  final Book book;
  @override
  State<EbookScreen> createState() => _EbookState();
}

class _EbookState extends State<EbookScreen> {
  bool downloading = false;
  Future<void> download() async {
    setState(() => downloading = true);
    try {
      final state = LibraryScope.of(context);
      final bytes = await state.ebookBytes(widget.book);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save e-book',
        fileName:
            '${widget.book.title.replaceAll(RegExp(r'[^a-zA-Z0-9 -]'), '')}${state.demo ? ' - demo sample' : ''}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );
      if (path == null && !kIsWeb) return;
      await state.downloaded(widget.book);
      if (mounted) {
        setState(() => downloading = false);
        await approval(context, download: true);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final state = LibraryScope.of(c);
    final book = widget.book;
    return Screen(
      title: 'E-book Reader',
      back: true,
      centerTitle: true,
      tab: 1,
      trailing: IconButton(
        tooltip: state.bookmarks.contains(book.id)
            ? 'Remove bookmark'
            : 'Bookmark',
        onPressed: () => state.toggleBookmark(book),
        icon: state.bookmarks.contains(book.id)
            ? const Icon(Icons.bookmark, color: orange)
            : const Glyph('6e6fb.svg', size: 24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Art(book.cover, width: 80, height: 110, radius: 10),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title, style: txt(16, weight: heavy)),
                    const SizedBox(height: 4),
                    Text('By ${book.author}', style: txt(12, color: muted)),
                    const SizedBox(height: 4),
                    Text(
                      'PDF${state.demo ? ' (sample)' : ''} · ${book.year} Edition',
                      style: txt(11, color: orange),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  'Download E-Book',
                  height: 44,
                  color: orange,
                  foreground: Colors.black,
                  busy: downloading,
                  onTap: download,
                  icon: const Glyph('3a9b8.svg', size: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  'Full Screen',
                  height: 44,
                  outline: true,
                  onTap: () => push(c, FullReaderScreen(book: book)),
                  icon: const Glyph('58743.svg', size: 16),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(color: line, height: 1),
          ),
          Text('Live Chapter Preview', style: txt(14, weight: bold)),
          const SizedBox(height: 8),
          if (state.demo)
            ChapterPanel(book: book)
          else
            SizedBox(height: 400, child: PdfContent(book: book)),
        ],
      ),
    );
  }
}

class ChapterPanel extends StatelessWidget {
  const ChapterPanel({super.key, required this.book, this.full = false});
  final Book book;
  final bool full;
  @override
  Widget build(BuildContext c) => Panel(
    color: surface,
    radius: 12,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'CHAPTER 1 — BASIC INTRODUCTION',
                style: txt(11, weight: bold, color: orange),
              ),
            ),
            const SizedBox(width: 8),
            Text('Sample', style: txt(10, color: muted)),
          ],
        ),
        const SizedBox(height: 10),
        SelectableText(
          book.id == 'ebook-hadoop'
              ? (full ? hadoopFull : hadoopPreview)
              : book.category == 'Management'
              ? 'Financial statements describe the position and performance of an organisation. A balance sheet records assets, liabilities and equity. An income statement records revenues and expenses.\n\nThis demonstration chapter introduces the financial concepts used in this collection. Download the sample PDF to continue reading.'
              : book.category == 'Law'
              ? 'Legal research begins by defining a question and identifying its jurisdiction. Researchers distinguish primary authority, such as legislation and judgments, from secondary commentary.\n\nDownload this original demonstration sample to explore a short legal research exercise.'
              : 'A pastry dough balances flour, fat and liquid. Temperature and handling influence its final texture. Chilling dough helps keep the fat firm, while resting allows the flour to hydrate.\n\nDownload this original demonstration sample to explore a short practical exercise.',
          style: txt(12, height: 1.6),
        ),
      ],
    ),
  );
}

class FullReaderScreen extends StatelessWidget {
  const FullReaderScreen({super.key, required this.book, this.pdf = false});
  final Book book;
  final bool pdf;
  @override
  Widget build(BuildContext c) {
    final demo = LibraryScope.of(c).demo;
    return Screen(
      title: 'Full Screen',
      back: true,
      scroll: demo && !pdf,
      child: demo && !pdf
          ? Column(
              children: [
                const SizedBox(height: 11),
                ChapterPanel(book: book, full: true),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () =>
                      push(c, FullReaderScreen(book: book, pdf: true)),
                  child: Text(
                    'Open sample PDF',
                    style: txt(13, color: orange, weight: semi),
                  ),
                ),
              ],
            )
          : PdfContent(book: book),
    );
  }
}

class PdfContent extends StatefulWidget {
  const PdfContent({super.key, required this.book});
  final Book book;
  @override
  State<PdfContent> createState() => _PdfContentState();
}

class _PdfContentState extends State<PdfContent> {
  Future<Uint8List>? data;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    data ??= LibraryScope.of(context).ebookBytes(widget.book);
  }

  @override
  Widget build(BuildContext c) => FutureBuilder<Uint8List>(
    future: data,
    builder: (c, s) {
      if (s.hasError) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const EmptyState(
              'Unable to open this PDF',
              'Check your connection and try again.',
            ),
            TextButton(
              onPressed: () => setState(
                () => data = LibraryScope.of(c).ebookBytes(widget.book),
              ),
              child: const Text('Retry'),
            ),
          ],
        );
      }
      if (!s.hasData) {
        return const Center(child: CircularProgressIndicator(color: orange));
      }
      return PdfViewer.data(
        s.data!,
        sourceName: widget.book.title,
        params: const PdfViewerParams(backgroundColor: surface),
      );
    },
  );
}

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});
  @override
  Widget build(BuildContext c) {
    final state = LibraryScope.of(c);
    final books = state.books.where((b) => state.downloads.contains(b.id));
    return Screen(
      title: 'Downloads',
      back: true,
      child: Column(
        children: [
          const SizedBox(height: 20),
          for (final book in books)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Panel(
                padding: const EdgeInsets.all(16),
                onTap: () => push(c, EbookScreen(book: book)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(book.title, style: txt(14, weight: bold)),
                          const SizedBox(height: 6),
                          Text(
                            'By ${book.author}',
                            style: txt(12, color: muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove from download history',
                      onPressed: () async {
                        final remove = await showDialog<bool>(
                          context: c,
                          builder: (d) => AlertDialog(
                            title: const Text('Remove from download history?'),
                            content: Text(book.title),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(d, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(d, true),
                                child: const Text('Remove'),
                              ),
                            ],
                          ),
                        );
                        if (remove == true) await state.removeDownload(book.id);
                      },
                      icon: const Icon(Icons.close, size: 18, color: orange),
                    ),
                  ],
                ),
              ),
            ),
          if (books.isEmpty)
            const EmptyState(
              'No downloads yet',
              'Open an e-book and tap Download E-Book to save a PDF.',
            ),
        ],
      ),
    );
  }
}
