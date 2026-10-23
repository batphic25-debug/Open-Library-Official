import 'package:open_library_client/core/l10n/app_strings.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/book_card.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/theme/app_theme.dart';
import '../books/models/book.dart';
import '../books/services/offline_book_library.dart';
import '../books/services/sample_books.dart';
import '../bookshelf/bookshelf_service.dart';
import '../books/services/open_library_service.dart';
import 'widgets/search_filters.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.service,
    required this.onBookTap,
    this.initialQuery = '',
    this.bookshelfService,
  });
  final OpenLibraryService service;
  final BookshelfService? bookshelfService;
  final ValueChanged<Book> onBookTap;
  final String initialQuery;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final _query = TextEditingController(text: widget.initialQuery);
  Timer? _debounce;
  List<Book> _books = [];
  String? _language;
  BookSort _sort = BookSort.relevance;
  String? _error;
  int _generation = 0;
  int _page = 0;
  int _total = 0;
  bool _loading = false;
  bool _inFlight = false;
  bool _queued = false;
  bool _hasMore = false;
  bool _offlineOnly = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.trim().isNotEmpty) _restart();
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery) {
      _query.text = widget.initialQuery;
      _restart();
    }
  }

  void _restart({bool debounce = false}) {
    _debounce?.cancel();
    _generation++;
    _queued = false;
    setState(() {
      _books = [];
      _page = 0;
      _total = 0;
      _error = null;
      _hasMore = false;
      _loading = _offlineOnly || _query.text.trim().isNotEmpty;
    });
    if (!_loading) return;
    if (debounce) {
      _debounce = Timer(
        const Duration(milliseconds: 450),
        _offlineOnly ? _loadOffline : _load,
      );
    } else {
      if (_offlineOnly) {
        _loadOffline();
      } else {
        _load();
      }
    }
  }

  Future<void> _loadOffline() async {
    final generation = _generation;
    try {
      final catalog = await SampleBooks.load();
      final query = _query.text.trim().toLowerCase();
      final books = catalog
          .where(OfflineBookLibrary.hasBook)
          .where(
            (book) =>
                query.isEmpty ||
                book.title.toLowerCase().contains(query) ||
                book.authorLabel.toLowerCase().contains(query),
          )
          .toList();
      if (!mounted || generation != _generation || !_offlineOnly) return;
      setState(() {
        _books = books;
        _total = books.length;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation || !_offlineOnly) return;
      setState(() {
        _error = 'Không thể tải sách offline. Vui lòng thử lại.';
        _loading = false;
      });
    }
  }

  Future<void> _load() async {
    if (_query.text.trim().isEmpty) return;
    if (_inFlight) {
      if (_page == 0) _queued = true;
      return;
    }
    _inFlight = true;
    final generation = _generation;
    final page = _page + 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.service.searchBooks(
        query: _query.text.trim(),
        language: _language,
        sort: _sort,
        page: page,
      );
      if (!mounted || generation != _generation) return;
      final ids = _books.map((book) => book.id).toSet();
      setState(() {
        _books = [..._books, ...result.books.where((book) => ids.add(book.id))];
        _page = page;
        _total = result.total;
        _hasMore = result.hasMore;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(
        () => _error = error is BookSearchException
            ? error.message
            : 'Không thể tìm sách. Vui lòng thử lại.',
      );
    } finally {
      _inFlight = false;
      if (mounted) {
        if (generation == _generation) setState(() => _loading = false);
        if (_queued) {
          _queued = false;
          _load();
        }
      }
    }
  }

  final Set<String> _saving = {};

  Future<void> _saveBook(Book book) async {
    final shelf = widget.bookshelfService;
    if (shelf == null) {
      widget.onBookTap(book);
      return;
    }
    if (_saving.contains(book.id)) return;
    setState(() => _saving.add(book.id));
    try {
      final added = await shelf.addBook(book);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              added
                  ? context.tr("Đã thêm sách vào tủ.")
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
      if (mounted) setState(() => _saving.remove(book.id));
    }
  }

  Widget _bookCard(Book book) {
    Widget card() => BookCard(
      key: ValueKey(book.id),
      book: book,
      onTap: () => widget.onBookTap(book),
      onSave: () => _saveBook(book),
      saved: widget.bookshelfService?.bookById(book.id) != null,
      saving: _saving.contains(book.id),
    );
    final shelf = widget.bookshelfService;
    return shelf == null
        ? card()
        : ListenableBuilder(listenable: shelf, builder: (_, _) => card());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: Theme.of(context).brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark,
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        context.tr("Tìm kiếm"),
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.16,
                          letterSpacing: -.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _query,
                      textInputAction: TextInputAction.search,
                      onChanged: (_) => _restart(debounce: true),
                      onSubmitted: (_) {
                        FocusScope.of(context).unfocus();
                        _restart();
                      },
                      style: const TextStyle(fontSize: 18),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF343544)
                            : AppTheme.softSurface,
                        hintText: context.tr("Tên sách hoặc tác giả"),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 15,
                          horizontal: 16,
                        ),
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
                          borderSide: const BorderSide(
                            color: AppTheme.accent,
                            width: 1,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 30,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        suffixIcon: _query.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: context.tr("Xóa từ khóa"),
                                onPressed: () {
                                  _query.clear();
                                  _restart();
                                },
                                icon: const Icon(Icons.close, size: 27),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilterChip(
                      label: Text(context.tr("Sách đọc offline")),
                      avatar: const Icon(Icons.menu_book_outlined, size: 20),
                      selected: _offlineOnly,
                      selectedColor: const Color(0xFFFFE8E1),
                      onSelected: (selected) {
                        setState(() => _offlineOnly = selected);
                        _restart();
                      },
                    ),
                    if (!_offlineOnly) ...[
                      const SizedBox(height: 12),
                      SearchFilters(
                        language: _language,
                        sort: _sort,
                        onLanguageChanged: (value) {
                          _language = value;
                          _restart();
                        },
                        onSortChanged: (value) {
                          _sort = value;
                          _restart();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_query.text.trim().isEmpty && !_offlineOnly)
                  _SearchMessage(
                    icon: Icons.manage_search,
                    text: context.tr(
                      "Nhập tên sách hoặc tác giả để khám phá Open Library.",
                    ),
                  )
                else ...[
                  if (_books.isNotEmpty) ...[
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(
                          _offlineOnly
                              ? context.tr("Sách đọc offline")
                              : context.tr("Kết quả tìm kiếm"),
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          context.tr("{0} sách", [_total]),
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    for (final book in _books)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _bookCard(book),
                      ),
                  ],
                  if (_loading)
                    const LoadingView()
                  else if (_error != null)
                    ErrorView(
                      message: _error!,
                      onRetry: _offlineOnly ? _loadOffline : _load,
                    )
                  else if (_books.isEmpty)
                    _SearchMessage(
                      icon: Icons.search_off,
                      text: context.tr(
                        "Không tìm thấy sách. Thử từ khóa hoặc bộ lọc khác.",
                      ),
                    )
                  else if (_hasMore)
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.expand_more),
                      label: Text(context.tr("Tải thêm")),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        Icon(icon, size: 56, color: AppTheme.accent),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center),
      ],
    ),
  );
}
