import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/book_card.dart';
import '../../core/widgets/book_cover.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/theme/app_theme.dart';
import '../books/models/book.dart';
import '../books/services/sample_books.dart';
import '../bookshelf/bookshelf_service.dart';
import 'widgets/category_selector.dart';
import 'widgets/reading_card.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({
    super.key,
    required this.displayName,
    required this.onSearch,
    required this.onBookTap,
    this.avatarBytes,
    this.onProfileTap,
    this.onUpdateProgress,
    this.readingBooks,
    this.bookshelfService,
    this.loadBooks = SampleBooks.load,
    this.searchQuery = '',
  });
  final String displayName;
  final Uint8List? avatarBytes;
  final String searchQuery;
  final ValueChanged<String> onSearch;
  final ValueChanged<Book> onBookTap;
  final VoidCallback? onProfileTap;
  final ValueChanged<Book>? onUpdateProgress;
  final ValueListenable<List<ReadingBook>>? readingBooks;
  final BookshelfService? bookshelfService;
  final Future<List<Book>> Function() loadBooks;

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  static const _coral = AppTheme.accent;
  static const _heading = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
  );
  late Future<List<Book>> _books = widget.loadBooks();
  final PageController _featuredController = PageController(
    viewportFraction: .92,
  );
  final GlobalKey _libraryKey = GlobalKey();
  final Set<String> _savingFeatured = {};
  String? _category;
  bool _showAll = false;
  int _featuredIndex = 0;

  @override
  void dispose() {
    _featuredController.dispose();
    super.dispose();
  }

  void _viewAll() {
    setState(() => _showAll = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _libraryKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _saveFeatured(Book book) async {
    final shelf = widget.bookshelfService;
    if (shelf == null || _savingFeatured.contains(book.id)) return;
    setState(() => _savingFeatured.add(book.id));
    try {
      final added = await shelf.addBook(book);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              added ? 'Đã lưu sách vào tủ.' : 'Sách đã có trong tủ.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa lưu được sách. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingFeatured.remove(book.id));
    }
  }

  Widget _reading(List<ReadingBook> books) => books.isEmpty
      ? Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Text(
            'Chưa có sách đang đọc. Thêm sách vào tủ để bắt đầu hành trình đọc của bạn.',
          ),
        )
      : Column(
          children: [
            for (final reading in books)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ReadingCard(
                  reading: reading,
                  onTap: () => widget.onBookTap(reading.book),
                  onUpdate: widget.onUpdateProgress == null
                      ? null
                      : () => widget.onUpdateProgress!(reading.book),
                ),
              ),
          ],
        );

  Widget _featuredBook(Book book) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final description = book.description?.trim();
    final ink = Theme.of(context).colorScheme.onSurface;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
        final wide = constraints.maxWidth >= 620 && !largeText;
        final compact = !wide;
        final coverHeight = wide
            ? constraints.maxHeight - 48
            : constraints.maxWidth < 300
            ? 166.0
            : 200.0;
        final coverWidth = wide
            ? coverHeight * 2 / 3
            : constraints.maxWidth < 300
            ? 108.0
            : 126.0;
        return Material(
          key: ValueKey('featured-${book.id}'),
          color: Colors.transparent,
          elevation: dark ? 0 : 3,
          shadowColor: const Color(0x1F765746),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: BorderSide(
              color: dark ? Colors.white12 : const Color(0xFFF5EEEA),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [const Color(0xFF38313A), const Color(0xFF242632)]
                    : [const Color(0xFFFFEEE6), const Color(0xFFFFFCF9)],
              ),
            ),
            child: InkWell(
              onTap: () => widget.onBookTap(book),
              child: Padding(
                padding: EdgeInsets.all(wide ? 24 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BookCover(
                          book: book,
                          width: coverWidth,
                          height: coverHeight,
                        ),
                        SizedBox(width: wide ? 26 : 12),
                        Expanded(
                          child: SizedBox(
                            height: wide
                                ? coverHeight
                                : compact
                                ? 176
                                : 220,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: wide ? 14 : 8,
                                      vertical: wide ? 8 : 5,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: wide
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFFFF8463),
                                                Color(0xFFFF4F59),
                                              ],
                                            )
                                          : null,
                                      color: wide
                                          ? null
                                          : dark
                                          ? const Color(0xFF493138)
                                          : const Color(0xFFFFEAE4),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          wide
                                              ? Icons.workspace_premium_rounded
                                              : Icons.star_rounded,
                                          size: wide ? 19 : 16,
                                          color: wide ? Colors.white : _coral,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'NỔI BẬT',
                                          style: TextStyle(
                                            color: wide ? Colors.white : _coral,
                                            fontSize: wide ? 13 : 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: wide ? 18 : 9),
                                Text(
                                  book.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: ink,
                                    fontSize: wide ? 32 : 20,
                                    fontWeight: FontWeight.w800,
                                    height: 1.12,
                                  ),
                                ),
                                SizedBox(height: wide ? 12 : 6),
                                Text(
                                  book.authorLabel,
                                  maxLines: compact || wide ? 2 : 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: wide ? 18 : 13,
                                  ),
                                ),
                                if (wide) ...[
                                  const SizedBox(height: 22),
                                  _featuredMetadata(book, muted),
                                ],
                                if (!compact &&
                                    description != null &&
                                    description.isNotEmpty) ...[
                                  SizedBox(height: wide ? 24 : 12),
                                  if (!wide) ...[
                                    Container(
                                      width: 32,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: _coral,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  Expanded(
                                    child: Text(
                                      description,
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: wide ? 16 : 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                                if (wide &&
                                    (description == null ||
                                        description.isEmpty))
                                  const Spacer(),
                                if (wide) ...[
                                  const SizedBox(height: 10),
                                  _featuredActions(book, wide),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (compact &&
                        (book.categories.isNotEmpty ||
                            book.selectedEdition?.pages != null)) ...[
                      const SizedBox(height: 12),
                      _featuredMetadata(book, muted),
                    ],
                    if (compact &&
                        description != null &&
                        description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        description,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: muted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (!wide) ...[
                      const Spacer(),
                      _featuredActions(book, wide),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _featuredActions(Book book, bool wide) => Row(
    children: [
      Expanded(child: _featuredDetailButton(book, wide)),
      SizedBox(width: wide ? 18 : 10),
      _featuredSaveButton(book, wide: wide),
    ],
  );

  Widget _featuredMetadata(Book book, Color color) => Wrap(
    spacing: 16,
    runSpacing: 8,
    children: [
      if (book.categories.isNotEmpty)
        _featuredFact(Icons.menu_book_outlined, book.categories.first, color),
      if (book.selectedEdition?.pages != null)
        _featuredFact(
          Icons.description_outlined,
          '${book.selectedEdition!.pages} trang',
          color,
        ),
    ],
  );

  Widget _featuredFact(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color, fontSize: 15),
        ),
      ),
    ],
  );

  Widget _featuredDetailButton(Book book, bool wide) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF4F55), Color(0xFFFF8760)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: () => widget.onBookTap(book),
        child: SizedBox(
          height: wide ? 62 : 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  'Xem chi tiết',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: wide ? 19 : 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _featuredSaveButton(Book book, {required bool wide}) {
    final shelf = widget.bookshelfService;
    Widget button() {
      final saved = shelf?.bookById(book.id) != null;
      return SizedBox(
        width: wide ? 62 : 52,
        height: wide ? 62 : 52,
        child: IconButton(
          tooltip: saved ? 'Đã lưu vào tủ sách' : 'Lưu vào tủ sách',
          onPressed: shelf == null || saved || _savingFeatured.contains(book.id)
              ? null
              : () => _saveFeatured(book),
          style: IconButton.styleFrom(
            backgroundColor: wide ? Colors.white : const Color(0xFFFFEEE9),
            disabledBackgroundColor: wide
                ? Colors.white
                : const Color(0xFFFFEEE9),
            shape: const CircleBorder(),
          ),
          icon: Icon(
            saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: _coral,
            size: 25,
          ),
        ),
      );
    }

    return shelf == null
        ? button()
        : ListenableBuilder(listenable: shelf, builder: (_, _) => button());
  }

  Widget _header() => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 48,
                height: 52,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: 192,
                    maxWidth: 192,
                    minHeight: 64,
                    maxHeight: 64,
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 192,
                      height: 64,
                      fit: BoxFit.contain,
                      color: _coral,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Open Library',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: widget.onProfileTap,
                tooltip: 'Mở trang Cá nhân của ${widget.displayName}',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF0E9),
                  foregroundColor: _coral,
                ),
                icon: widget.avatarBytes == null
                    ? Text(
                        widget.displayName.trim().isEmpty
                            ? '?'
                            : widget.displayName
                                  .trim()
                                  .characters
                                  .first
                                  .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 20,
                          color: _coral,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : CircleAvatar(
                        radius: 18,
                        backgroundImage: MemoryImage(widget.avatarBytes!),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text.rich(
            const TextSpan(
              children: [
                TextSpan(text: 'Hôm nay bạn\n'),
                TextSpan(
                  text: 'muốn đọc gì?',
                  style: TextStyle(color: _coral),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.12,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            readOnly: true,
            onTap: () => widget.onSearch(widget.searchQuery),
            decoration: InputDecoration(
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF343544)
                  : AppTheme.softSurface,
              hintText: widget.searchQuery.isEmpty
                  ? 'Tìm tên sách, tác giả...'
                  : widget.searchQuery,
              hintStyle: const TextStyle(color: Color(0xFF85858D)),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 12, right: 8),
                child: Icon(Icons.search, size: 27),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _coral, width: 1),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _catalog(AsyncSnapshot<List<Book>> snapshot) {
    final books = snapshot.data ?? [];
    final categories = {
      for (final name in ['Văn học', 'Kỳ ảo', 'Trinh thám'])
        if (books.any((book) => book.categories.contains(name))) name,
      ...books.expand((book) => book.categories),
    }.toList();
    final filtered = books
        .where(
          (book) => _category == null || book.categories.contains(_category),
        )
        .toList();
    // Editorial picks from the bundled catalog; other catalogs keep their order.
    final featured = [
      for (final id in ['/works/OL10263W', '/works/OL82563W'])
        ...filtered.where((book) => book.id == id),
      ...filtered.where(
        (book) => !['/works/OL10263W', '/works/OL82563W'].contains(book.id),
      ),
    ];
    final visible = _showAll ? featured : featured.take(4).toList();
    final recommendations = [
      ...filtered.where((book) => book.id == '/works/OL27482W'),
      ...filtered.where((book) => book.id != '/works/OL27482W'),
    ].where((book) => !visible.contains(book)).take(3).toList();

    final highlights = featured.take(4).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CategorySelector(
            categories: categories,
            selected: _category,
            onChanged: (category) {
              if (_featuredController.hasClients) {
                _featuredController.jumpToPage(0);
              }
              setState(() {
                _category = category;
                _showAll = false;
                _featuredIndex = 0;
              });
            },
          ),
          const SizedBox(height: 24),
          if (highlights.isNotEmpty) ...[
            Row(
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Sách nổi bật',
                          style: _heading,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 5),
                      Icon(Icons.auto_awesome_rounded, color: _coral, size: 20),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _viewAll,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                  label: const Text('Xem tất cả'),
                  icon: const Icon(Icons.chevron_right),
                  iconAlignment: IconAlignment.end,
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth * .92 - 12;
                final largeText =
                    MediaQuery.textScalerOf(context).scale(1) > 1.3;
                final height = cardWidth >= 620 && !largeText
                    ? (cardWidth * .62).clamp(400.0, 520.0)
                    : largeText
                    ? 470.0
                    : 440.0;
                return SizedBox(
                  height: height,
                  child: PageView.builder(
                    controller: _featuredController,
                    itemCount: highlights.length,
                    onPageChanged: (index) =>
                        setState(() => _featuredIndex = index),
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(right: 12, bottom: 4),
                      child: _featuredBook(highlights[index]),
                    ),
                  ),
                );
              },
            ),
            if (highlights.length > 1) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < highlights.length; index++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: AnimatedContainer(
                        key: ValueKey('featured-dot-$index'),
                        duration: const Duration(milliseconds: 180),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == _featuredIndex
                              ? _coral
                              : const Color(0xFFD9DADD),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 26),
          ],
          const Text('Đang đọc', style: _heading),
          const SizedBox(height: 12),
          if (widget.readingBooks == null)
            _reading(const [])
          else
            ValueListenableBuilder<List<ReadingBook>>(
              valueListenable: widget.readingBooks!,
              builder: (_, books, child) => _reading(books),
            ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text('Sách trong thư viện', key: _libraryKey, style: _heading),
              if (filtered.length > 4)
                TextButton.icon(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  style: TextButton.styleFrom(foregroundColor: _coral),
                  label: Text(_showAll ? 'Thu gọn' : 'Xem thêm'),
                  icon: Icon(
                    _showAll ? Icons.expand_less : Icons.chevron_right,
                    size: 20,
                  ),
                  iconAlignment: IconAlignment.end,
                ),
            ],
          ),
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: _coral,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Chọn một cuốn sách để khám phá',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          if (snapshot.connectionState != ConnectionState.done)
            const LoadingView()
          else if (snapshot.hasError)
            ErrorView(
              message: 'Không thể tải danh mục sách.',
              onRetry: () => setState(() {
                _books = widget.loadBooks();
              }),
            )
          else if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Chưa có sách trong danh mục này.'),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 300 ? 1 : 2;
                final width =
                    (constraints.maxWidth - (columns - 1) * 18) / columns;
                return Wrap(
                  spacing: 18,
                  runSpacing: 22,
                  children: [
                    for (final book in visible)
                      SizedBox(
                        width: width,
                        child: widget.bookshelfService == null
                            ? BookCard(
                                book: book,
                                compact: true,
                                onTap: () => widget.onBookTap(book),
                              )
                            : ListenableBuilder(
                                listenable: widget.bookshelfService!,
                                builder: (context, _) {
                                  final saved =
                                      widget.bookshelfService!.bookById(
                                        book.id,
                                      ) !=
                                      null;
                                  return BookCard(
                                    book: book,
                                    compact: true,
                                    saved: saved,
                                    saving: _savingFeatured.contains(book.id),
                                    onSave: saved
                                        ? null
                                        : () => _saveFeatured(book),
                                    onTap: () => widget.onBookTap(book),
                                  );
                                },
                              ),
                      ),
                  ],
                );
              },
            ),
          if (recommendations.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Gợi ý cho bạn', style: _heading),
            const SizedBox(height: 12),
            for (final book in recommendations)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: () => widget.onBookTap(book),
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          BookCover(book: book, width: 74, height: 108),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  book.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  book.authorLabel,
                                  style: const TextStyle(
                                    color: Color(0xFF686B74),
                                  ),
                                ),
                                if (book.categories.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    book.categories.first,
                                    style: const TextStyle(
                                      color: _coral,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF686B74),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: Theme.of(context).brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark,
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        child: Column(
          children: [
            _header(),
            FutureBuilder<List<Book>>(
              future: _books,
              builder: (_, snapshot) => _catalog(snapshot),
            ),
          ],
        ),
      ),
    ),
  );
}
