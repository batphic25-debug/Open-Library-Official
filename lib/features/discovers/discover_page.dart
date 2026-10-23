import 'package:open_library_client/core/l10n/app_strings.dart';
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
import '../books/services/book_ranking_service.dart';
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
    this.rankingService,
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
  final BookRankingService? rankingService;

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  static const _coral = AppTheme.accent;
  static const _night = Color(0xFF0D1728);
  static const _panel = Color(0xFF18263B);
  static const _line = Color(0xFF2A3C57);
  static const _secondary = Color(0xFF9BAAC1);
  static const _gold = Color(0xFFFFC45A);
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _canvas => _dark ? _night : AppTheme.canvas;
  Color get _surface => _dark ? _panel : Colors.white;
  Color get _border => _dark ? _line : AppTheme.border;
  Color get _text => _dark ? Colors.white : AppTheme.ink;
  Color get _muted => _dark ? _secondary : AppTheme.muted;
  Color get _highlight => _dark ? _gold : _coral;
  TextStyle get _heading => TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: _text,
  );
  late Future<List<Book>> _books = widget.loadBooks();
  final PageController _featuredController = PageController(
    viewportFraction: 1,
  );
  final GlobalKey _libraryKey = GlobalKey();
  final Set<String> _savingFeatured = {};
  String? _category;
  bool _showAll = false;
  int _featuredIndex = 0;
  int? _rankingDays = 1;

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
              added
                  ? context.tr("Đã lưu sách vào tủ.")
                  : context.tr("Sách đã có trong tủ."),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr("Chưa lưu được sách. Vui lòng thử lại.")),
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
            color: _surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            context.tr(
              "Chưa có sách đang đọc. Thêm sách vào tủ để bắt đầu hành trình đọc của bạn.",
            ),
            style: TextStyle(color: _muted),
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

  Widget _featuredBook(Book book) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 620;
      final stacked =
          constraints.maxWidth < 340 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final padding = wide ? 28.0 : 16.0;
      final coverWidth = stacked
          ? 100.0
          : (constraints.maxWidth - padding * 2) * .35;
      final coverHeight = coverWidth * 1.52;
      final description = book.description?.trim();
      final title = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _text,
              fontSize: wide ? 28 : 18,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr(book.authorLabel),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _muted, fontSize: wide ? 21 : 13),
          ),
        ],
      );
      final details = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!stacked) title,
          SizedBox(height: wide ? 22 : 12),
          _featuredMetadata(book, _muted),
          if (description != null && description.isNotEmpty) ...[
            SizedBox(height: wide ? 16 : 10),
            Expanded(
              child: Text(
                context.tr(description),
                maxLines: wide ? 4 : 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _muted,
                  fontSize: wide ? 18 : 13,
                  height: 1.45,
                ),
              ),
            ),
          ] else
            const Spacer(),
          const SizedBox(height: 12),
          _featuredActions(book, wide),
        ],
      );
      return Material(
        key: ValueKey('featured-${book.id}'),
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: _dark ? const Color(0xFF263F58) : const Color(0xFFE8DCC4),
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _dark
                  ? const [Color(0xFF152A40), Color(0xFF17283D)]
                  : const [Color(0xFFFFF7E7), Color(0xFFFFFCF5)],
            ),
          ),
          child: InkWell(
            onTap: () => widget.onBookTap(book),
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: stacked
                  ? Column(
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
                            const SizedBox(width: 14),
                            Expanded(child: title),
                          ],
                        ),
                        Expanded(child: details),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        BookCover(
                          book: book,
                          width: coverWidth,
                          height: coverHeight,
                        ),
                        SizedBox(width: wide ? 26 : 16),
                        Expanded(child: details),
                      ],
                    ),
            ),
          ),
        ),
      );
    },
  );

  Widget _featuredActions(Book book, bool wide) => Row(
    children: [
      Expanded(child: _featuredDetailButton(book, wide)),
      SizedBox(width: wide ? 18 : 10),
      _featuredSaveButton(book, wide: wide),
    ],
  );

  Widget _featuredMetadata(Book book, Color color) {
    final labels = [
      if (book.categories.isNotEmpty) context.tr(book.categories.first),
      if ((book.selectedEdition?.pages ?? 0) > 0)
        context.tr("{0} trang", [book.selectedEdition!.pages]),
    ];
    if (labels.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(Icons.menu_book_outlined, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            labels.join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _featuredDetailButton(Book book, bool wide) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(_dark ? 18 : 999),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _dark
              ? const [Color(0xFFFFCA55), Color(0xFFFFC247)]
              : const [Color(0xFFFF6B55), Color(0xFFFF6550)],
        ),
        borderRadius: BorderRadius.circular(_dark ? 18 : 999),
      ),
      child: InkWell(
        onTap: () => widget.onBookTap(book),
        child: SizedBox(
          height: wide ? 62 : 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  context.tr("Xem chi tiết"),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _dark ? _night : Colors.white,
                    fontSize: wide ? 19 : 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.arrow_forward_rounded,
                color: _dark ? _night : Colors.white,
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
        width: wide ? 70 : 48,
        height: wide ? 62 : 48,
        child: IconButton(
          tooltip: saved
              ? context.tr("Đã lưu vào tủ sách")
              : context.tr("Lưu vào tủ sách"),
          onPressed: shelf == null || saved || _savingFeatured.contains(book.id)
              ? null
              : () => _saveFeatured(book),
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shape: const CircleBorder(),
            side: BorderSide(color: _dark ? _gold : AppTheme.accent, width: 2),
          ),
          icon: Icon(
            saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: _dark ? (saved ? _gold : _text) : AppTheme.accent,
            size: wide ? 30 : 24,
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
                      color: _highlight,
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
                    color: _text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: widget.onProfileTap,
                tooltip: context.tr("Mở trang Cá nhân của {0}", [
                  widget.displayName,
                ]),
                style: IconButton.styleFrom(
                  backgroundColor: _dark ? _panel : const Color(0xFFFFF0E9),
                  foregroundColor: _highlight,
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
                        style: TextStyle(
                          fontSize: 20,
                          color: _highlight,
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
            TextSpan(
              children: [
                TextSpan(text: context.tr("Hôm nay bạn\n")),
                TextSpan(
                  text: context.tr("muốn đọc gì?"),
                  style: TextStyle(color: _highlight),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: _text,
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
              fillColor: _dark ? _panel : AppTheme.softSurface,
              hintText: widget.searchQuery.isEmpty
                  ? context.tr("Tìm tên sách, tác giả...")
                  : widget.searchQuery,
              hintStyle: TextStyle(color: _muted),
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
                borderSide: BorderSide(color: _highlight, width: 1),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _sectionHeading(String title, String subtitle, Color accent) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _heading),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(color: _muted, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _bookStrip(List<Book> books) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionHeading(
        context.tr("Sách chọn lọc"),
        context.tr("Khám phá thêm từ thư viện"),
        _highlight,
      ),
      SizedBox(
        height: 252,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: books.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final book = books[index];
            return SizedBox(
              width: 136,
              child: Material(
                key: ValueKey('discover-strip-${book.id}'),
                color: _surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: _border),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => widget.onBookTap(book),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BookCover(book: book, width: 136, height: 185),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(9, 8, 9, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _text,
                              ),
                            ),
                            Text(
                              context.tr(book.authorLabel),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: _muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );

  Widget _rankedBooks(List<Book> books) {
    final service = widget.rankingService;
    final views = {
      for (final book in books)
        book.id: service?.viewsFor(book.id, days: _rankingDays) ?? 0,
    };
    final ordered = books.indexed.toList()
      ..sort((a, b) {
        final byViews = views[b.$2.id]!.compareTo(views[a.$2.id]!);
        return byViews == 0 ? a.$1.compareTo(b.$1) : byViews;
      });
    final ranked = ordered.map((entry) => entry.$2).take(5).toList();
    const medals = [Color(0xFFFF5C62), Color(0xFFF3C400), Color(0xFF2BCB70)];
    const blue = Color(0xFF468DFF);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeading(
          context.tr("Top sách"),
          context.tr("Theo lượt xem trên thiết bị này"),
          blue,
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  for (final period in [
                    (1, context.tr("Ngày")),
                    (7, context.tr("Tuần")),
                    (null, context.tr("Tất cả")),
                  ])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Semantics(
                          selected: _rankingDays == period.$1,
                          child: OutlinedButton(
                            onPressed: () =>
                                setState(() => _rankingDays = period.$1),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 10,
                              ),
                              backgroundColor: _rankingDays == period.$1
                                  ? blue.withValues(alpha: .18)
                                  : Colors.transparent,
                              foregroundColor: _rankingDays == period.$1
                                  ? (_dark
                                        ? const Color(0xFFB8D3FF)
                                        : const Color(0xFF245BB5))
                                  : _muted,
                              side: BorderSide(
                                color: _rankingDays == period.$1
                                    ? blue
                                    : _border,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(period.$2, textAlign: TextAlign.center),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (service?.error != null)
                TextButton.icon(
                  onPressed: service!.load,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.trError(service.error!)),
                )
              else if (views.values.every((count) => count == 0))
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    context.tr(
                      "Chưa có lượt xem trong khoảng này. Khám phá một cuốn sách bên dưới.",
                    ),
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
              for (var index = 0; index < ranked.length; index++) ...[
                const SizedBox(height: 12),
                Material(
                  key: ValueKey('discover-rank-${ranked[index].id}'),
                  color: index.isOdd
                      ? (_dark
                            ? const Color(0xFF1D2C42)
                            : const Color(0xFFF3F6FB))
                      : _surface,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => widget.onBookTap(ranked[index]),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            width: 3,
                            color: index < 3 && views[ranked[index].id]! > 0
                                ? medals[index]
                                : _border,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: index < 3 && views[ranked[index].id]! > 0
                                  ? medals[index]
                                  : _border,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                views[ranked[index].id]! > 0
                                    ? '${index + 1}'.padLeft(2, '0')
                                    : '—',
                                style: TextStyle(
                                  color:
                                      index < 3 && views[ranked[index].id]! > 0
                                      ? const Color(0xFF111A32)
                                      : _muted,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          BookCover(book: ranked[index], width: 50, height: 72),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ranked[index].title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _text,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.tr(ranked[index].authorLabel),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: _muted, fontSize: 12),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.visibility_outlined,
                                      size: 14,
                                      color: _muted,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        context.tr("{0} lượt xem", [
                                          views[ranked[index].id],
                                        ]),
                                        style: TextStyle(
                                          color: _muted,
                                          fontSize: 12,
                                        ),
                                      ),
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
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _catalog(AsyncSnapshot<List<Book>> snapshot) {
    final books = snapshot.data ?? [];
    final categories = {
      for (final name in ["Văn học", "Kỳ ảo", "Trinh thám"])
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
      decoration: BoxDecoration(color: _canvas),
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
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          context.tr("Sách nổi bật"),
                          style: _heading,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: _highlight,
                        size: 20,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _viewAll,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                    textStyle: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  label: Text(context.tr("Xem tất cả")),
                  icon: const Icon(Icons.chevron_right),
                  iconAlignment: IconAlignment.end,
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth;
                final largeText =
                    MediaQuery.textScalerOf(context).scale(1) > 1.3;
                final height = largeText || cardWidth < 340
                    ? 440.0 *
                          MediaQuery.textScalerOf(context)
                              .scale(1)
                              .clamp(1.0, 1.5)
                    : cardWidth >= 620
                    ? ((cardWidth - 56) * .35 * 1.52 + 56).clamp(400.0, 520.0)
                    : 250.0;
                return SizedBox(
                  height: height,
                  child: PageView.builder(
                    controller: _featuredController,
                    itemCount: highlights.length,
                    onPageChanged: (index) =>
                        setState(() => _featuredIndex = index),
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
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
                              ? _highlight
                              : (_dark ? _line : const Color(0xFFD9DADD)),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 26),
          ],
          if (featured.length > 1) ...[
            _bookStrip(featured.skip(1).take(8).toList()),
            const SizedBox(height: 28),
          ],
          Text(context.tr("Đang đọc"), style: _heading),
          const SizedBox(height: 12),
          if (widget.readingBooks == null)
            _reading(const [])
          else
            ValueListenableBuilder<List<ReadingBook>>(
              valueListenable: widget.readingBooks!,
              builder: (_, books, child) => _reading(books),
            ),
          if (filtered.isNotEmpty) ...[
            const SizedBox(height: 30),
            if (widget.rankingService == null)
              _rankedBooks(featured)
            else
              ListenableBuilder(
                listenable: widget.rankingService!,
                builder: (_, _) => _rankedBooks(featured),
              ),
          ],
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                context.tr("Sách trong thư viện"),
                key: _libraryKey,
                style: _heading,
              ),
              if (filtered.length > 4)
                TextButton.icon(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  style: TextButton.styleFrom(foregroundColor: _highlight),
                  label: Text(
                    _showAll ? context.tr("Thu gọn") : context.tr("Xem thêm"),
                  ),
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
                color: _highlight,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr("Chọn một cuốn sách để khám phá"),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          if (snapshot.connectionState != ConnectionState.done)
            const LoadingView()
          else if (snapshot.hasError)
            DefaultTextStyle.merge(
              style: TextStyle(color: _text),
              child: ErrorView(
                message: context.tr("Không thể tải danh mục sách."),
                onRetry: () => setState(() {
                  _books = widget.loadBooks();
                }),
              ),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.tr("Chưa có sách trong danh mục này."),
                style: TextStyle(color: _text),
              ),
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
            Text(context.tr("Gợi ý cho bạn"), style: _heading),
            const SizedBox(height: 12),
            for (final book in recommendations)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: _surface,
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
                                  context.tr(book.authorLabel),
                                  style: TextStyle(color: _muted),
                                ),
                                if (book.categories.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    context.tr(book.categories.first),
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
                          Icon(Icons.chevron_right, color: _muted),
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
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      key: ValueKey('discover-theme-$dark'),
      data: dark
          ? AppTheme.dark.copyWith(
              colorScheme: AppTheme.dark.colorScheme.copyWith(
                primary: _gold,
                surface: _panel,
                onSurface: Colors.white,
                onSurfaceVariant: _secondary,
                outlineVariant: _line,
              ),
            )
          : Theme.of(context),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: ColoredBox(
          key: const ValueKey('discover-background'),
          color: _canvas,
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
      ),
    );
  }
}
