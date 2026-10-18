import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';

import '../books/models/book.dart';
import '../discovers/widgets/reading_card.dart';
import 'bookshelf_database.dart';
import 'models/book_note.dart';
import 'models/saved_book.dart';

/// One durable snapshot per account. Mutations publish only after the write succeeds.
class BookshelfService extends ChangeNotifier {
  BookshelfService({
    required this.userId,
    Future<Database> Function()? openDatabase,
  }) : _openDatabase = openDatabase ?? (() => openShelfDatabase(userId)) {
    if (userId.isEmpty) throw ArgumentError.value(userId, 'userId');
  }
  final String userId;
  final Future<Database> Function() _openDatabase;
  final _record = stringMapStoreFactory.store('bookshelf').record('snapshot');
  Database? _database;
  Future<void> _pending = Future.value();
  bool _disposed = false;
  Future<void>? _closing;
  bool _loaded = false;
  bool loading = false;
  String? error;
  Map<String, SavedBook> _books = {};
  Map<String, BookNote> _notes = {};
  final ValueNotifier<List<ReadingBook>> _readingBooks = ValueNotifier([]);
  ValueListenable<List<ReadingBook>> get readingBooks => _readingBooks;
  List<SavedBook> get books => List.unmodifiable(
    _books.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );
  List<BookNote> get notes => List.unmodifiable(
    _notes.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );
  SavedBook? bookById(String id) => _books[id];
  BookNote? noteFor(String id) => _notes[id];

  Future<T> _enqueue<T>(Future<T> Function() action) {
    if (_disposed) return Future.error(StateError('Tủ sách đã đóng.'));
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _publish() {
    if (_disposed) return;
    _readingBooks.value = List.unmodifiable(
      books
          .where((saved) => saved.status == ReadingStatus.reading)
          .map(
            (saved) => ReadingBook(
              book: saved.book,
              pagesRead: saved.pagesRead,
              totalPages: saved.totalPages,
            ),
          ),
    );
    notifyListeners();
  }

  Future<void> _load() async {
    if (_loaded) return;
    _database ??= await _openDatabase();
    final snapshot = await _record.get(_database!);
    final books = <String, SavedBook>{};
    final notes = <String, BookNote>{};
    if (snapshot != null) {
      if (snapshot['version'] != 1 || snapshot['userId'] != userId) {
        throw const FormatException(
          'Dữ liệu tủ sách không thuộc tài khoản này.',
        );
      }
      for (final value in snapshot['books'] as List) {
        final saved = SavedBook.fromJson(
          Map<String, dynamic>.from(value as Map),
        );
        if (saved.userId != userId || books.containsKey(saved.id)) {
          throw const FormatException('Dữ liệu sách không hợp lệ.');
        }
        books[saved.id] = saved;
      }
      for (final value in snapshot['notes'] as List) {
        final note = BookNote.fromJson(Map<String, dynamic>.from(value as Map));
        if (note.userId != userId ||
            !books.containsKey(note.bookId) ||
            notes.containsKey(note.bookId)) {
          throw const FormatException('Dữ liệu ghi chú không hợp lệ.');
        }
        notes[note.bookId] = note;
      }
    }
    _books = books;
    _notes = notes;
    _loaded = true;
  }

  /// Errors are exposed for the page's retry state. Mutations still throw on failure.
  Future<void> loadBooks() => _enqueue(() async {
    loading = true;
    error = null;
    if (!_disposed) notifyListeners();
    try {
      await _load();
    } catch (_) {
      error = 'Không thể đọc tủ sách trên thiết bị. Hãy thử lại.';
    } finally {
      loading = false;
      _publish();
    }
  });

  Future<T> _change<T>(
    T Function(Map<String, SavedBook>, Map<String, BookNote>) edit,
  ) => _enqueue(() async {
    await _load();
    final books = Map<String, SavedBook>.from(_books);
    final notes = Map<String, BookNote>.from(_notes);
    final result = edit(books, notes);
    await _record.put(_database!, {
      'version': 1,
      'userId': userId,
      'books': books.values.map((book) => book.toJson()).toList(),
      'notes': notes.values.map((note) => note.toJson()).toList(),
    });
    _books = books;
    _notes = notes;
    error = null;
    _publish();
    return result;
  });

  SavedBook _require(Map<String, SavedBook> books, String id) =>
      books[id] ?? (throw StateError('Sách không còn trong tủ.'));

  Future<bool> addBook(Book book) => _change((books, notes) {
    if (books.containsKey(book.id)) return false;
    final now = DateTime.now().toUtc();
    books[book.id] = SavedBook(
      userId: userId,
      book: book,
      status: ReadingStatus.wantToRead,
      pagesRead: 0,
      addedAt: now,
      updatedAt: now,
    );
    return true;
  });
  Future<void> removeBook(String id) => _change((books, notes) {
    books.remove(id);
    notes.remove(id);
  });
  Future<void> updateStatus(String id, ReadingStatus status) =>
      _change((books, notes) {
        final saved = _require(books, id);
        books[id] = saved.copyWith(
          status: status,
          pagesRead: status == ReadingStatus.wantToRead
              ? 0
              : status == ReadingStatus.read
              ? saved.totalPages ?? saved.pagesRead
              : saved.pagesRead,
        );
      });
  Future<void> updateProgress(
    String id,
    int pagesRead, {
    bool completed = false,
  }) => _change((books, notes) {
    final saved = _require(books, id);
    if (completed &&
        saved.totalPages != null &&
        pagesRead != saved.totalPages) {
      throw ArgumentError('Hãy nhập đủ số trang trước khi hoàn thành.');
    }
    books[id] = saved.copyWith(
      pagesRead: pagesRead,
      status: completed ? ReadingStatus.read : ReadingStatus.reading,
    );
  });
  Future<void> updateEdition(String id, BookEdition edition) =>
      _change((books, notes) {
        final saved = _require(books, id);
        books[id] = saved.copyWith(
          book: saved.book.withEdition(edition),
          pagesRead: 0,
          status: ReadingStatus.wantToRead,
        );
      });
  Future<void> saveNote(String id, String body) => _change((books, notes) {
    _require(books, id);
    if (body.trim().isEmpty) {
      throw ArgumentError('Ghi chú không được để trống.');
    }
    final now = DateTime.now().toUtc();
    notes[id] = BookNote(
      id: id,
      userId: userId,
      bookId: id,
      body: body.trim(),
      createdAt: notes[id]?.createdAt ?? now,
      updatedAt: now,
    );
  });
  Future<void> deleteNote(String id) => _change((books, notes) {
    notes.remove(id);
  });

  /// Tests may await this to reopen the database after all pending writes finish.
  Future<void> close() async {
    if (!_disposed) dispose();
    await _closing;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _readingBooks.dispose();
    _closing = _pending.then((_) async {
      await _database?.close();
    });
    super.dispose();
  }
}
