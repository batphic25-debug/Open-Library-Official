import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/book_cover.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/theme/app_theme.dart';
import 'editions_page.dart';
import 'book_reading_page.dart';
import 'models/book.dart';
import 'services/open_library_service.dart';
import 'services/offline_book_library.dart';
import '../profile/settings_service.dart';
import 'widgets/edition_metadata.dart';

/// Basic handoff destination; editions and full work data belong to person 3.
class BookDetailPage extends StatefulWidget {
  const BookDetailPage({
    super.key,
    required this.book,
    this.service,
    this.onAddToShelf,
    this.openLink,
    this.settings,
    this.onStartReading,
    this.onPageChanged,
  });
  final Book book;
  final OpenLibraryService? service;

  /// The bookshelf service returns true when added, false when the work exists.
  final Future<bool> Function(Book)? onAddToShelf;
  final Future<bool> Function(Uri)? openLink;
  final SettingsService? settings;
  final Future<void> Function(Book)? onStartReading;
  final Future<void> Function(Book book, int page)? onPageChanged;
  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  late final _service = widget.service ?? OpenLibraryService();
  Book? _book;
  String? _error;
  bool _loading = false;
  bool _saving = false;
  bool _saved = false;
  Future<List<BookAuthor>>? _authors;

  @override
  void initState() {
    super.initState();
    if (OfflineBookLibrary.hasBook(widget.book)) {
      _book = widget.book;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final book = await _service.getBookDetails(widget.book);
      if (mounted) setState(() => _book = book);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is BookSearchException
              ? error.message
              : 'Không thể tải chi tiết sách. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _save() async {
    if (_saving || _book == null || widget.onAddToShelf == null) return;
    setState(() => _saving = true);
    try {
      final added = await widget.onAddToShelf!(_book!);
      if (mounted) setState(() => _saved = true);
      _message(added ? 'Đã thêm sách vào tủ.' : 'Sách đã có trong tủ.');
    } catch (_) {
      _message('Không thể thêm sách. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openSource() async {
    try {
      final url = _book!.selectedEdition?.sourceUrl ?? _book!.sourceUrl;
      final opened = widget.openLink != null
          ? await widget.openLink!(url)
          : await launchUrl(url);
      if (!opened) _message('Không thể mở Open Library. Vui lòng thử lại.');
    } catch (_) {
      _message('Không thể mở Open Library. Vui lòng thử lại.');
    }
  }

  Future<void> _read(Book book) async {
    if (OfflineBookLibrary.hasBook(book) && widget.onStartReading != null) {
      try {
        await widget.onStartReading!(book);
      } catch (_) {
        _message('Chưa lưu được sách vào tủ. Bạn vẫn có thể đọc tiếp.');
      }
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BookReadingPage(
          book: book,
          settings: widget.settings,
          onPageChanged: widget.onPageChanged,
        ),
      ),
    );
  }

  Future<void> _chooseEdition() async {
    final edition = await Navigator.push<BookEdition>(
      context,
      MaterialPageRoute(
        builder: (_) => EditionsPage(
          workId: _book!.id,
          service: _service,
          selectedEditionId: _book!.selectedEdition?.id,
        ),
      ),
    );
    if (!mounted || edition == null) return;
    setState(() => _book = _book!.withEdition(edition));
  }

  void _loadAuthors() => setState(
    () => _authors = Future.wait(_book!.authorIds.map(_service.getAuthor)),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    appBar: AppBar(
      title: const Text(
        'Chi tiết sách',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
      ),
      centerTitle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      actions: [
        IconButton(
          tooltip: _saved ? 'Đã có trong tủ sách' : 'Lưu vào tủ sách',
          onPressed:
              _book == null ||
                  _loading ||
                  _saving ||
                  widget.onAddToShelf == null
              ? null
              : _save,
          icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border),
        ),
      ],
    ),
    body: _loading
        ? const LoadingView()
        : _error != null
        ? ListView(
            children: [ErrorView(message: _error!, onRetry: _load)],
          )
        : _book == null
        ? const SizedBox.shrink()
        : _content(_book!),
  );

  Widget _content(Book book) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(
            gradient: const RadialGradient(
              colors: [Color(0xFFFFDCCF), Colors.white],
              radius: .75,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(child: BookCover(book: book, width: 164, height: 238)),
        ),
        if (book.coverIsIllustration)
          const Text('Bìa minh họa của nhóm', textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Text(
          book.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          book.authors.isEmpty ? 'Chưa có dữ liệu' : book.authorLabel,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, color: AppTheme.muted),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 18,
              color: AppTheme.muted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                book.selectedEdition?.pages == null
                    ? 'Chưa có số trang'
                    : '${book.selectedEdition!.pages} trang',
                style: const TextStyle(color: AppTheme.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (book.categories.isEmpty)
          const Text('Thể loại: Chưa có dữ liệu')
        else
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final category in book.categories.take(3))
                Chip(
                  label: Text(
                    category,
                    style: const TextStyle(
                      color: Color(0xFFFF554C),
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: const Color(0xFFFFEEE7),
                  side: BorderSide.none,
                ),
            ],
          ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF343544)
                : AppTheme.softSurface,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.language, size: 21),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Ngôn ngữ ấn bản',
                        style: TextStyle(color: Color(0xFF65728A)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        book.selectedEdition?.languageLabel.isNotEmpty == true
                            ? book.selectedEdition!.languageLabel
                            : 'Chưa có dữ liệu',
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE5E6EC)),
              InkWell(
                onTap: _saving ? null : _chooseEdition,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.menu_book_outlined, size: 21),
                      SizedBox(width: 12),
                      Text(
                        'Ấn bản',
                        style: TextStyle(color: Color(0xFF65728A)),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Xem các phiên bản',
                          textAlign: TextAlign.end,
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Giới thiệu',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        SelectableText(
          book.description ?? 'Chưa có dữ liệu',
          style: const TextStyle(fontSize: 15, height: 1.55),
        ),
        if (book.description != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Nguồn giới thiệu: ${book.descriptionSource ?? 'Chưa có dữ liệu'}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF65728A)),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.accent,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () => _read(book),
          icon: const Icon(Icons.auto_stories_outlined),
          label: const Text('Đọc sách'),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Color(0xFFFF713D), Color(0xFFF03562)],
            ),
          ),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: widget.onAddToShelf == null || _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bookmark_add_outlined),
            label: Text(_saving ? 'Đang thêm…' : 'Thêm vào tủ sách'),
          ),
        ),
        // shortcut: saving is injected by person 4; enable when its persistent bookshelf service is available.
        if (widget.onAddToShelf == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Tính năng lưu sách chưa khả dụng.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF65728A)),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFF554C),
            side: const BorderSide(color: Color(0xFFFF554C)),
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _openSource,
          icon: const Icon(Icons.open_in_new),
          label: const Text('Mở trên Open Library'),
        ),
        const SizedBox(height: 20),
        const Text(
          'Thông tin xuất bản',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text('Xuất bản lần đầu: ${book.firstPublishYear ?? 'Chưa có dữ liệu'}'),
        EditionMetadata(edition: book.selectedEdition),
        if (book.authorIds.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Thông tin tác giả'),
            onExpansionChanged: (open) {
              if (open && _authors == null) _loadAuthors();
            },
            children: [
              if (_authors != null)
                FutureBuilder<List<BookAuthor>>(
                  future: _authors,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const LoadingView();
                    }
                    if (snapshot.hasError) {
                      return ErrorView(
                        message: 'Không thể tải thông tin tác giả.',
                        onRetry: _loadAuthors,
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final author in snapshot.data!)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  author.name ?? 'Chưa có dữ liệu',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (author.birthDate != null)
                                  Text('Ngày sinh: ${author.birthDate}'),
                                if (author.deathDate != null)
                                  Text('Ngày mất: ${author.deathDate}'),
                                const SizedBox(height: 6),
                                Text(author.biography ?? 'Chưa có dữ liệu'),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
      ],
    ),
  );
}
