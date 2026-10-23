import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../books/models/book.dart';
import '../books/services/offline_book_library.dart';
import '../discovers/widgets/reading_card.dart';
import 'bookshelf_service.dart';
import 'models/book_note.dart';
import 'models/saved_book.dart';

class BackendBookshelfService extends BookshelfService {
  BackendBookshelfService({required super.userId, required this.api});

  final ApiClient api;
  final _saved = <String, SavedBook>{};
  final _notes = <String, BookNote>{};
  final _reading = ValueNotifier<List<ReadingBook>>([]);
  Future<void> _pending = Future.value();
  bool _disposed = false;

  @override
  ValueListenable<List<ReadingBook>> get readingBooks => _reading;
  @override
  List<SavedBook> get books => List.unmodifiable(
    _saved.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );
  @override
  List<BookNote> get notes => List.unmodifiable(
    _notes.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );
  @override
  SavedBook? bookById(String id) => _saved[id];
  @override
  BookNote? noteFor(String id) => _notes[id];

  Future<T> _run<T>(Future<T> Function() action) {
    if (_disposed) return Future.error(StateError('Tủ sách đã đóng.'));
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _publish() {
    if (_disposed) return;
    _reading.value = List.unmodifiable(
      books
          .where((saved) => saved.status == ReadingStatus.reading)
          .map(
            (saved) => ReadingBook(
              book: saved.book,
              pagesRead: saved.pagesRead,
              totalPages: saved.totalPages,
              totalPagesEstimated: saved.totalPagesEstimated,
            ),
          ),
    );
    notifyListeners();
  }

  Future<SavedBook> _withLocalTotal(SavedBook saved) async {
    if (saved.totalPages != null) return saved;
    final bundled = OfflineBookLibrary.forBook(saved.book);
    if (bundled == null) return saved;
    try {
      final content = await OfflineBookLibrary.load(bundled);
      final total = content.pageCount(saved.book);
      if (total < saved.pagesRead) return saved;
      return SavedBook(
        userId: saved.userId,
        book: saved.book,
        status: saved.status,
        pagesRead: saved.pagesRead,
        estimatedTotalPages: total,
        version: saved.version,
        addedAt: saved.addedAt,
        updatedAt: saved.updatedAt,
      );
    } catch (_) {
      return saved;
    }
  }

  Future<void> _reload() async {
    final nextBooks = <String, SavedBook>{};
    final nextNotes = <String, BookNote>{};
    var page = 1;
    while (true) {
      final data = await api.request(
        'GET',
        '/me/books',
        query: {'page': '$page', 'pageSize': '50'},
      );
      for (final raw in data['items'] as List) {
        final item = Map<String, dynamic>.from(raw as Map);
        final saved = await _withLocalTotal(
          SavedBook.fromApiJson(item, userId),
        );
        nextBooks[saved.id] = saved;
        final noteData = item['note'];
        if (noteData is Map) {
          final note = Map<String, dynamic>.from(noteData);
          nextNotes[saved.id] = BookNote(
            id: saved.id,
            userId: userId,
            bookId: saved.id,
            body: note['content'] as String,
            version: note['version'] as int,
            createdAt: DateTime.parse(note['createdAt'] as String),
            updatedAt: DateTime.parse(note['updatedAt'] as String),
          );
        }
      }
      if (data['hasMore'] != true) break;
      page++;
    }
    _saved
      ..clear()
      ..addAll(nextBooks);
    _notes
      ..clear()
      ..addAll(nextNotes);
    error = null;
    _publish();
  }

  Future<void> _applySaved(Map<String, dynamic> data) async {
    final saved = await _withLocalTotal(SavedBook.fromApiJson(data, userId));
    _saved[saved.id] = saved;
    error = null;
    _publish();
  }

  @override
  Future<void> loadBooks() => _run(() async {
    loading = true;
    _publish();
    try {
      await _reload();
    } catch (_) {
      error = 'Không thể tải tủ sách từ máy chủ. Hãy thử lại.';
    } finally {
      loading = false;
      _publish();
    }
  });

  String _id(String workId) => libraryKey(workId, 'works', 'W').split('/').last;
  SavedBook _require(String id) =>
      _saved[id] ?? (throw StateError('Sách không còn trong tủ.'));

  @override
  Future<bool> addBook(Book book) => _run(() async {
    if (_saved.containsKey(book.id)) return false;
    final data = await api.request(
      'PUT',
      '/me/books/${_id(book.id)}',
      body: {
        if (book.selectedEdition != null)
          'editionId': book.selectedEdition!.id.split('/').last,
      },
    );
    await _applySaved(data);
    return true;
  });

  @override
  Future<void> removeBook(String id) => _run(() async {
    _require(id);
    await api.request('DELETE', '/me/books/${_id(id)}');
    _saved.remove(id);
    _notes.remove(id);
    _publish();
  });

  Future<void> _patch(String id, Map<String, dynamic> changes) async {
    final saved = _require(id);
    final data = await api.request(
      'PATCH',
      '/me/books/${_id(id)}',
      body: {'expectedVersion': saved.version, ...changes},
    );
    await _applySaved(data);
  }

  @override
  Future<void> updateStatus(String id, ReadingStatus status) => _run(() async {
    final saved = _require(id);
    await _patch(id, {
      'status': switch (status) {
        ReadingStatus.wantToRead => 'want_to_read',
        ReadingStatus.reading => 'reading',
        ReadingStatus.read => 'finished',
      },
      if (status == ReadingStatus.wantToRead) 'pagesRead': 0,
      if (status == ReadingStatus.reading &&
          saved.totalPages != null &&
          saved.pagesRead == saved.totalPages)
        'pagesRead': (saved.totalPages! - 1).clamp(0, saved.totalPages!),
    });
  });

  @override
  Future<void> updateProgress(
    String id,
    int pagesRead, {
    bool completed = false,
  }) => _run(() async {
    final saved = _require(id);
    if (completed &&
        saved.totalPages != null &&
        pagesRead != saved.totalPages) {
      throw ArgumentError('Hãy nhập đủ số trang trước khi hoàn thành.');
    }
    await _patch(id, {
      'pagesRead': pagesRead,
      'status':
          completed ||
              (saved.totalPages != null && pagesRead == saved.totalPages)
          ? 'finished'
          : 'reading',
    });
  });

  @override
  Future<void> updateEdition(String id, BookEdition edition) => _run(() async {
    _require(id);
    await _patch(id, {
      'editionId': edition.id.split('/').last,
      'resetProgress': true,
    });
  });

  @override
  Future<void> saveNote(String id, String body) => _run(() async {
    _require(id);
    if (body.trim().isEmpty) {
      throw ArgumentError('Ghi chú không được để trống.');
    }
    final old = _notes[id];
    final data = await api.request(
      'PUT',
      '/me/books/${_id(id)}/note',
      body: {'content': body.trim(), 'expectedVersion': old?.version ?? 0},
    );
    final now = DateTime.now().toUtc();
    _notes[id] = BookNote(
      id: id,
      userId: userId,
      bookId: id,
      body: data['content'] as String,
      version: data['version'] as int,
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
    );
    _publish();
  });

  @override
  Future<void> deleteNote(String id) => _run(() async {
    final old = _notes[id];
    if (old == null) return;
    await api.request(
      'DELETE',
      '/me/books/${_id(id)}/note',
      query: {'expectedVersion': '${old.version}'},
    );
    _notes.remove(id);
    _publish();
  });

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _reading.dispose();
    super.dispose();
  }
}
