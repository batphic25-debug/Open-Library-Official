import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/book_cover.dart';
import '../books/editions_page.dart';
import '../books/models/book.dart';
import '../books/services/offline_book_library.dart';
import '../books/services/open_library_service.dart';
import 'bookshelf_service.dart';
import 'models/saved_book.dart';
import 'note_editor_page.dart';
import 'reading_progress_sheet.dart';

// shortcut: only supplied reading entries are shown; add saved lists with person 4's storage service.
// Resolved: the account-scoped service now supplies all three persisted lists.
class BookshelfPage extends StatefulWidget {
  const BookshelfPage({
    super.key,
    required this.service,
    required this.libraryService,
    required this.onBookTap,
    this.onReadTap,
    required this.onExplore,
  });
  final BookshelfService service;
  final OpenLibraryService libraryService;
  final ValueChanged<Book> onBookTap;
  final ValueChanged<Book>? onReadTap;
  final VoidCallback onExplore;
  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  ReadingStatus _status = ReadingStatus.wantToRead;
  bool _busy = false;
  bool _showAllNotes = false;
  static const _coral = AppTheme.accent;
  bool _canContinue(SavedBook saved) =>
      _isOfflineReading(saved) && widget.onReadTap != null;

  bool _isOfflineReading(SavedBook saved) =>
      saved.status == ReadingStatus.reading &&
      OfflineBookLibrary.hasBook(saved.book);

  void _openSaved(SavedBook saved) {
    if (_canContinue(saved)) {
      widget.onReadTap!(saved.book);
    } else {
      widget.onBookTap(saved.book);
    }
  }

  void _note(SavedBook saved) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => NoteEditorPage(service: widget.service, saved: saved),
    ),
  );
  void _progress(SavedBook saved) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => ReadingProgressSheet(service: widget.service, saved: saved),
  );

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa lưu được thay đổi. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _menu(SavedBook saved, String action) async {
    if (action == 'note') {
      _note(saved);
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xóa khỏi tủ sách?'),
          content: Text(
            '“${saved.book.title}”, tiến độ và ghi chú của sách sẽ bị xóa khỏi tài khoản này.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa'),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        await _perform(() => widget.service.removeBook(saved.id));
      }
    } else if (action == 'edition') {
      final edition = await Navigator.of(context).push<BookEdition>(
        MaterialPageRoute(
          builder: (_) => EditionsPage(
            workId: saved.id,
            service: widget.libraryService,
            selectedEditionId: saved.editionId,
          ),
        ),
      );
      if (edition == null || edition.id == saved.editionId || !mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Đổi phiên bản đã lưu?'),
          content: const Text(
            'Tiến độ về 0 và trạng thái chuyển sang Muốn đọc. Ghi chú được giữ lại.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Đổi phiên bản'),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        await _perform(() => widget.service.updateEdition(saved.id, edition));
      }
    } else {
      final status = ReadingStatus.values.byName(action);
      await _perform(() => widget.service.updateStatus(saved.id, status));
      if (mounted && widget.service.bookById(saved.id)?.status == status) {
        setState(() => _status = status);
      }
    }
  }

  Widget _card(SavedBook saved) => Card(
    color: Theme.of(context).colorScheme.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppTheme.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: _canContinue(saved)
                ? 'Đọc tiếp ${saved.book.title}'
                : 'Chi tiết ${saved.book.title}',
            child: InkWell(
              onTap: () => _openSaved(saved),
              borderRadius: BorderRadius.circular(10),
              child: BookCover(book: saved.book, width: 92, height: 144),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _openSaved(saved),
                        child: Text(
                          saved.book.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: PopupMenuButton<String>(
                        tooltip: 'Tùy chọn ${saved.book.title}',
                        enabled: !_busy,
                        padding: EdgeInsets.zero,
                        color: Theme.of(context).colorScheme.surface,
                        surfaceTintColor: Colors.transparent,
                        icon: const Icon(Icons.more_vert, size: 22),
                        onSelected: (action) => _menu(saved, action),
                        itemBuilder: (_) => [
                          for (final status in ReadingStatus.values)
                            CheckedPopupMenuItem(
                              value: status.name,
                              checked: saved.status == status,
                              child: Text(status.label),
                            ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'note',
                            child: Text('Ghi chú'),
                          ),
                          const PopupMenuItem(
                            value: 'edition',
                            child: Text('Đổi phiên bản'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Xóa khỏi tủ sách',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  saved.book.authorLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (saved.status != ReadingStatus.wantToRead) ...[
                  const SizedBox(height: 18),
                  if (saved.progress != null && !_isOfflineReading(saved))
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: saved.progress!,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(8),
                            color: _coral,
                            backgroundColor: const Color(0xFFEDEEF2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${(saved.progress! * 100).round()}%'),
                      ],
                    ),
                  const SizedBox(height: 4),
                  if (_isOfflineReading(saved))
                    const Text(
                      'Vị trí đọc được lưu tự động',
                      style: TextStyle(fontSize: 12, color: Color(0xFF686B74)),
                    )
                  else if (saved.totalPages == null)
                    Text(
                      'Đã đọc ${saved.pagesRead} trang',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF686B74),
                      ),
                    ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (_canContinue(saved))
                      TextButton.icon(
                        onPressed: () => widget.onReadTap!(saved.book),
                        style: _editStyle(context),
                        icon: const Icon(Icons.menu_book_outlined, size: 20),
                        label: const Text('Đọc tiếp'),
                      ),
                    TextButton.icon(
                      onPressed: _busy ? null : () => _progress(saved),
                      style: _editStyle(context),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      label: const Text('Cập nhật'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  ButtonStyle _editStyle(BuildContext context) => TextButton.styleFrom(
    foregroundColor: Theme.of(context).colorScheme.onSurface,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF343544)
        : const Color(0xFFF4F4F6),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  Widget _noteCard(SavedBook saved, String body) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF45303A)
          : const Color(0xFFFFF2E9),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE6D4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.note_alt_outlined, color: _coral, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      saved.book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: PopupMenuButton<String>(
                      tooltip: 'Tùy chọn ghi chú ${saved.book.title}',
                      padding: EdgeInsets.zero,
                      color: Theme.of(context).colorScheme.surface,
                      surfaceTintColor: Colors.transparent,
                      onSelected: (_) => _note(saved),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _note(saved),
                style: _editStyle(context),
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: const Text('Chỉnh sửa'),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      child: ListenableBuilder(
        listenable: widget.service,
        builder: (context, _) {
          final books = widget.service.books
              .where((book) => book.status == _status)
              .toList();
          final notes = widget.service.notes;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Tủ sách của tôi',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onExplore,
                    tooltip: 'Khám phá sách',
                    iconSize: 32,
                    icon: const Icon(Icons.search),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF343544)
                      : const Color(0xFFF4F4F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    for (final status in ReadingStatus.values)
                      Expanded(
                        child: Semantics(
                          selected: _status == status,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: _status == status
                                  ? const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFFFF854D), _coral],
                                    )
                                  : null,
                            ),
                            child: TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: _status == status
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurface,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => setState(() => _status = status),
                              child: Text(
                                status.label,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (widget.service.loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (widget.service.error != null) ...[
                Text(widget.service.error!, textAlign: TextAlign.center),
                TextButton.icon(
                  onPressed: widget.service.loadBooks,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ] else ...[
                if (books.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF45303A)
                          : const Color(0xFFFFF3ED),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.auto_stories_outlined,
                          size: 48,
                          color: _coral,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Chưa có sách trong nhóm ${_status.label.toLowerCase()}.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: widget.onExplore,
                          child: const Text('Khám phá sách'),
                        ),
                      ],
                    ),
                  ),
                ...books.map(_card),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Ghi chú gần đây',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _showAllNotes = !_showAllNotes),
                        style: TextButton.styleFrom(foregroundColor: _coral),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_showAllNotes ? 'Thu gọn' : 'Xem tất cả'),
                            const Icon(Icons.chevron_right, size: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final note in (_showAllNotes ? notes : notes.take(1)))
                    _noteCard(widget.service.bookById(note.bookId)!, note.body),
                ],
              ],
            ],
          );
        },
      ),
    ),
  );
}
