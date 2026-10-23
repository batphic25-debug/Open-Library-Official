import 'package:open_library_client/core/l10n/app_strings.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/book_cover.dart';
import 'models/book.dart';
import 'services/offline_book_library.dart';
import '../profile/settings_service.dart';

class BookReadingPage extends StatefulWidget {
  const BookReadingPage({
    super.key,
    required this.book,
    this.settings,
    this.onPageChanged,
  });

  final Book book;
  final SettingsService? settings;
  final Future<void> Function(Book book, int page)? onPageChanged;

  @override
  State<BookReadingPage> createState() => _BookReadingPageState();
}

class _BookReadingPageState extends State<BookReadingPage> {
  static final RegExp _chapterHeading = RegExp(
    r'^CHAPTER\b',
    caseSensitive: false,
  );
  static final RegExp _gatsbyChapter = RegExp(
    r'^(?:I|II|III|IV|V|VI|VII|VIII|IX)$',
  );
  static final RegExp _sherlockStory = RegExp(r'^[IVX]+\.\s+\S');

  ScrollController? _scroll;
  Future<OfflineBookText>? _text;
  Timer? _saveTimer;
  double _fontSize = 18;
  double _lastOffset = 0;
  int? _totalPages;
  int? _lastReportedPage;
  final ValueNotifier<double> _progress = ValueNotifier(0);
  bool _progressReady = false;
  final Set<int> _chapters = {};

  @override
  void initState() {
    super.initState();
    final bundled = OfflineBookLibrary.forBook(widget.book);
    if (bundled != null) _text = _open(bundled);
  }

  Future<OfflineBookText> _open(OfflineBook bundled) async {
    ReaderPosition? saved;
    try {
      saved = await widget.settings?.loadReaderPosition(widget.book.id);
    } catch (_) {
      // A damaged reading position must not prevent access to the bundled book.
    }
    _fontSize = saved?.fontSize ?? 18;
    _lastOffset = saved?.offset ?? 0;
    _scroll = ScrollController(initialScrollOffset: saved?.offset ?? 0)
      ..addListener(_onScroll);
    final content = await OfflineBookLibrary.load(bundled);
    _totalPages = content.pageCount(widget.book);
    for (var index = 0; index < content.paragraphs.length; index++) {
      if (_isChapter(content.paragraphs[index])) {
        _chapters.add(index);
      }
    }
    return content;
  }

  bool _isChapter(String paragraph) {
    if (paragraph.length >= 100) return false;
    if (_chapterHeading.hasMatch(paragraph)) return true;
    if (widget.book.id == '/works/OL468431W') {
      return _gatsbyChapter.hasMatch(paragraph);
    }
    if (widget.book.id == '/works/OL262421W') {
      return _sherlockStory.hasMatch(paragraph);
    }
    return false;
  }

  void _onScroll() {
    final scroll = _scroll;
    if (scroll == null || !scroll.hasClients) return;
    _lastOffset = scroll.offset.clamp(0.0, scroll.position.maxScrollExtent);
    _updateProgress();
    _scheduleSave();
  }

  void _updateProgress() {
    final scroll = _scroll;
    if (scroll == null || !scroll.hasClients) return;
    final max = scroll.position.maxScrollExtent;
    _progress.value = max <= 0 ? 0 : (scroll.offset / max).clamp(0.0, 1.0);
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _savePosition);
  }

  void _savePosition() {
    final settings = widget.settings;
    if (_scroll == null) return;
    if (settings != null) {
      settings
          .saveReaderPosition(
            widget.book.id,
            ReaderPosition(offset: _lastOffset, fontSize: _fontSize),
          )
          .catchError((Object _) {});
    }
    final total = _totalPages;
    final onPageChanged = widget.onPageChanged;
    if (total == null || onPageChanged == null) return;
    final page = _progress.value >= 1
        ? total
        : (1 + (_progress.value * (total - 1)).round()).clamp(0, total - 1);
    if (page == _lastReportedPage) return;
    _lastReportedPage = page;
    onPageChanged(widget.book, page).catchError((Object _) {
      if (_lastReportedPage == page) _lastReportedPage = null;
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _savePosition();
    _scroll?.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _showLicense(String license, {bool local = false}) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        local ? context.tr("Thông tin nguồn") : context.tr("Giấy phép bản văn"),
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: SelectableText(local ? context.tr(license) : license),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr("Đóng")),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bundled = OfflineBookLibrary.forBook(widget.book);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final paper = dark ? const Color(0xFF252633) : const Color(0xFFFFFEFA);
    final canvas = dark ? const Color(0xFF191A26) : const Color(0xFFF6F2EA);
    final ink = dark ? const Color(0xFFF4EFE7) : AppTheme.ink;
    final muted = dark ? const Color(0xFFB9B3BC) : AppTheme.muted;
    return Scaffold(
      backgroundColor: canvas,
      appBar: AppBar(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        title: Text(
          context.tr("Đọc sách"),
          style: TextStyle(color: ink, fontWeight: FontWeight.w700),
        ),
        actions: bundled == null
            ? null
            : [
                IconButton(
                  tooltip: context.tr("Giảm cỡ chữ"),
                  color: ink,
                  onPressed: _fontSize <= 14
                      ? null
                      : () {
                          setState(() => _fontSize -= 2);
                          _scheduleSave();
                        },
                  icon: const Icon(Icons.text_decrease),
                ),
                IconButton(
                  tooltip: context.tr("Tăng cỡ chữ"),
                  color: ink,
                  onPressed: _fontSize >= 28
                      ? null
                      : () {
                          setState(() => _fontSize += 2);
                          _scheduleSave();
                        },
                  icon: const Icon(Icons.text_increase),
                ),
              ],
      ),
      body: bundled == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.menu_book_outlined, size: 56),
                    const SizedBox(height: 16),
                    Text(
                      widget.book.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr(
                        "Chưa có bản văn được phép lưu trong ứng dụng cho sách này.",
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : FutureBuilder<OfflineBookText>(
              future: _text,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(context.tr("Không thể mở bản văn đã lưu.")),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final content = snapshot.data!;
                if (!_progressReady) {
                  _progressReady = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _updateProgress();
                  });
                }
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: paper,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                          boxShadow: dark
                              ? null
                              : const [
                                  BoxShadow(
                                    color: Color(0x140B1024),
                                    blurRadius: 24,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                        ),
                        child: Scrollbar(
                          controller: _scroll,
                          child: ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(24, 26, 24, 48),
                            itemCount: content.paragraphs.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        BookCover(
                                          book: widget.book,
                                          width: 72,
                                          height: 106,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                context.tr("THƯ VIỆN OFFLINE"),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 1.2,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                widget.book.title,
                                                style: TextStyle(
                                                  fontSize: 24,
                                                  height: 1.15,
                                                  fontWeight: FontWeight.w800,
                                                  color: ink,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                context.tr(
                                                  widget.book.authorLabel,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    Divider(
                                      color: dark
                                          ? Colors.white24
                                          : const Color(0xFFEAE3D8),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      bundled.gutenbergId == null
                                          ? context.tr(
                                              "Văn bản trình bày lại từ PDF đã lưu",
                                            )
                                          : context.tr(
                                              "Bản văn tiếng Anh lưu sẵn · Project Gutenberg #{0}",
                                              [bundled.gutenbergId],
                                            ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: muted,
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _showLicense(
                                        content.license,
                                        local: bundled.gutenbergId == null,
                                      ),
                                      icon: const Icon(
                                        Icons.info_outline,
                                        size: 18,
                                      ),
                                      label: Text(
                                        bundled.gutenbergId == null
                                            ? context.tr("Thông tin nguồn")
                                            : context.tr(
                                                "Giấy phép và thông tin nguồn",
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    Text(
                                      _chapters.isEmpty
                                          ? context.tr("NỘI DUNG SÁCH")
                                          : context.tr(
                                              "NỘI DUNG · {0} CHƯƠNG",
                                              [_chapters.length],
                                            ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.1,
                                        color: muted,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                );
                              }
                              final paragraph = content.paragraphs[index - 1];
                              if (_chapters.contains(index - 1)) {
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    0,
                                    32,
                                    0,
                                    26,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SelectableText(
                                        paragraph,
                                        style: TextStyle(
                                          fontSize: _fontSize + 2,
                                          fontWeight: FontWeight.w800,
                                          height: 1.35,
                                          color: ink,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Divider(
                                        color: dark
                                            ? Colors.white24
                                            : const Color(0xFFEAE3D8),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              final heading =
                                  paragraph.length < 100 &&
                                  RegExp(
                                    r'^(CHAPTER|PART|BOOK|LETTER)\b',
                                    caseSensitive: false,
                                  ).hasMatch(paragraph);
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: heading ? 24 : 22,
                                  top: heading ? 16 : 0,
                                ),
                                child: SelectableText(
                                  paragraph,
                                  style: TextStyle(
                                    fontFamily: heading ? null : 'serif',
                                    fontSize: heading
                                        ? _fontSize + 2
                                        : _fontSize,
                                    fontWeight: heading
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    height: heading ? 1.4 : 1.75,
                                    color: ink,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: bundled == null
          ? null
          : ValueListenableBuilder<double>(
              valueListenable: _progress,
              builder: (context, progress, _) => SafeArea(
                top: false,
                child: ColoredBox(
                  color: paper,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: dark
                                ? Colors.white12
                                : const Color(0xFFECE6DE),
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.bookmark_outline,
                              size: 16,
                              color: muted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.settings == null
                                    ? context.tr("Đang đọc trên thiết bị")
                                    : context.tr("Tự lưu vị trí đọc"),
                                style: TextStyle(fontSize: 12, color: muted),
                              ),
                            ),
                            Text(
                              '~${(progress * 100).floor()}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: ink,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
