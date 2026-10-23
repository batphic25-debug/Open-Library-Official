import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:open_library_client/features/books/models/book.dart';
import 'package:open_library_client/features/bookshelf/bookshelf_service.dart';
import 'package:open_library_client/features/bookshelf/models/saved_book.dart';
import 'package:open_library_client/features/bookshelf/models/book_note.dart';
import 'package:open_library_client/features/auth/auth_service.dart';

const edition = BookEdition(
  id: '/books/OL1M',
  workIds: ['/works/OL1W'],
  pages: 100,
  title: 'First edition',
  isbn: ['123'],
  languages: ['eng'],
  publishers: ['Publisher'],
  publishDate: '2001',
  coverId: 42,
);
const book = Book(
  id: '/works/OL1W',
  title: 'Book one',
  authors: ['Author'],
  authorIds: ['/authors/OL1A'],
  categories: ['Fiction'],
  description: 'Description',
  descriptionSource: 'Source',
  coverAsset: 'assets/cover.png',
  firstPublishYear: 2000,
  coverId: 5,
  coverEditionKey: 'OL1M',
  coverIsIllustration: true,
  selectedEdition: edition,
);
const unknown = Book(id: '/works/OL2W', title: 'Unknown pages');

void main() {
  late Directory directory;
  late BookshelfService shelf;
  BookshelfService open(String user) => BookshelfService(
    userId: user,
    openDatabase: () =>
        databaseFactoryIo.openDatabase('${directory.path}/$user.db'),
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('shelf_test_');
    shelf = open('alice');
  });
  tearDown(() async {
    await shelf.close();
    await directory.delete(recursive: true);
  });

  test(
    'concurrent additions deduplicate by work and preserve selected edition',
    () async {
      final results = await Future.wait([
        shelf.addBook(book),
        shelf.addBook(
          book.withEdition(
            const BookEdition(
              id: '/books/OL2M',
              workIds: ['/works/OL1W'],
              pages: 200,
            ),
          ),
        ),
      ]);
      expect(results, [true, false]);
      expect(shelf.books, hasLength(1));
      expect(shelf.books.single.editionId, edition.id);
    },
  );
  test('JSON roundtrip preserves complete metadata and note dates', () async {
    await shelf.addBook(book);
    await shelf.saveNote(book.id, 'Nội dung');
    final saved = shelf.books.single;
    final restored = SavedBook.fromJson(
      jsonDecode(jsonEncode(saved.toJson())) as Map<String, dynamic>,
    );
    expect(restored.toJson(), saved.toJson());
    final note = shelf.notes.single;
    expect(
      BookNote.fromJson(
        jsonDecode(jsonEncode(note.toJson())) as Map<String, dynamic>,
      ).toJson(),
      note.toJson(),
    );
  });
  test(
    'disk reopen retains notes, progress; accounts remain isolated',
    () async {
      await shelf.addBook(book);
      await shelf.updateProgress(book.id, 65);
      await shelf.saveNote(book.id, 'First');
      final createdAt = shelf.notes.single.createdAt;
      await shelf.saveNote(book.id, 'Edited');
      expect(shelf.notes.single.createdAt, createdAt);
      await shelf.close();
      shelf = open('alice');
      await shelf.loadBooks();
      expect(shelf.books.single.pagesRead, 65);
      expect(shelf.notes.single.body, 'Edited');
      expect(shelf.readingBooks.value.single.pagesRead, 65);
      final bob = open('bob');
      await bob.loadBooks();
      expect(bob.books, isEmpty);
      expect(bob.notes, isEmpty);
      await bob.addBook(unknown);
      await bob.close();
      expect(shelf.books.single.id, book.id);
      await shelf.deleteNote(book.id);
      await shelf.close();
      shelf = open('alice');
      await shelf.loadBooks();
      expect(shelf.notes, isEmpty);
    },
  );
  test(
    'progress validates bounds; completion and all status transitions publish',
    () async {
      await shelf.addBook(book);
      for (final pages in [-1, 101]) {
        await expectLater(
          shelf.updateProgress(book.id, pages),
          throwsFormatException,
        );
      }
      expect(shelf.books.single.pagesRead, 0);
      await shelf.updateProgress(book.id, 65);
      expect(shelf.books.single.progress, .65);
      expect(shelf.readingBooks.value.single.pagesRead, 65);
      await expectLater(
        shelf.updateProgress(book.id, 65, completed: true),
        throwsArgumentError,
      );
      await shelf.updateProgress(book.id, 100, completed: true);
      expect(shelf.books.single.status, ReadingStatus.read);
      expect(shelf.readingBooks.value, isEmpty);
      await shelf.updateStatus(book.id, ReadingStatus.wantToRead);
      expect(shelf.books.single.pagesRead, 0);
      await shelf.updateStatus(book.id, ReadingStatus.reading);
      expect(shelf.readingBooks.value, hasLength(1));
      await shelf.updateStatus(book.id, ReadingStatus.read);
      expect(shelf.books.single.pagesRead, 100);
    },
  );
  test(
    'full progress automatically finishes and stays finished after reopen',
    () async {
      await shelf.addBook(book);
      await shelf.updateProgress(book.id, 99);
      expect(shelf.books.single.status, ReadingStatus.reading);
      expect(shelf.readingBooks.value, hasLength(1));
      await shelf.updateProgress(book.id, 100);
      expect(shelf.books.single.status, ReadingStatus.read);
      expect(shelf.readingBooks.value, isEmpty);
      await shelf.close();
      shelf = open('alice');
      await shelf.loadBooks();
      expect(shelf.books.single.status, ReadingStatus.read);
      expect(shelf.readingBooks.value, isEmpty);
    },
  );

  test('previously saved 100 percent reading books load as finished', () async {
    await shelf.addBook(book);
    await shelf.updateStatus(book.id, ReadingStatus.read);
    await shelf.updateStatus(book.id, ReadingStatus.reading);
    await shelf.close();
    shelf = open('alice');
    await shelf.loadBooks();
    expect(shelf.books.single.status, ReadingStatus.read);
    expect(shelf.readingBooks.value, isEmpty);
  });
  test(
    'unknown or zero total never manufactures percentage; can finish',
    () async {
      await shelf.addBook(unknown);
      await shelf.updateProgress(unknown.id, 800);
      expect(shelf.books.single.progress, isNull);
      expect(shelf.readingBooks.value.single.totalPages, isNull);
      await shelf.updateProgress(unknown.id, 800, completed: true);
      expect(shelf.books.single.status, ReadingStatus.read);
      await shelf.updateEdition(
        unknown.id,
        const BookEdition(
          id: '/books/OL3M',
          workIds: ['/works/OL2W'],
          pages: 0,
        ),
      );
      expect(shelf.books.single.totalPages, isNull);
    },
  );
  test('edition replacement resets progress, retains note, rejects foreign edition', () async {
    await shelf.addBook(book);
    await shelf.updateProgress(book.id, 90);
    await shelf.saveNote(book.id, 'Keep');
    await expectLater(
      shelf.updateEdition(
        book.id,
        const BookEdition(id: '/books/OL3M', workIds: ['/works/OL2W']),
      ),
      throwsFormatException,
    );
    await shelf.updateEdition(
      book.id,
      const BookEdition(id: '/books/OL2M', workIds: ['/works/OL1W'], pages: 50),
    );
    expect(shelf.books.single.pagesRead, 0);
    expect(shelf.books.single.totalPages, 50);
    expect(shelf.books.single.status, ReadingStatus.wantToRead);
    expect(shelf.notes.single.body, 'Keep');
  });
  test('deleting book atomically deletes note and persists deletion', () async {
    await shelf.addBook(book);
    await shelf.saveNote(book.id, 'Delete');
    await shelf.removeBook(book.id);
    await expectLater(shelf.saveNote(book.id, 'Orphan'), throwsStateError);
    await shelf.close();
    shelf = open('alice');
    await shelf.loadBooks();
    expect(shelf.books, isEmpty);
    expect(shelf.notes, isEmpty);
  });
  test('failed writes do not publish success or discard saved state', () async {
    await shelf.addBook(book);
    await shelf.saveNote(book.id, 'Keep');
    final db = await databaseFactoryIo.openDatabase(
      '${directory.path}/alice.db',
    );
    await db.close();
    await expectLater(shelf.updateProgress(book.id, 50), throwsA(anything));
    await expectLater(shelf.removeBook(book.id), throwsA(anything));
    expect(shelf.books.single.pagesRead, 0);
    expect(shelf.notes.single.body, 'Keep');
  });
  test(
    'load error can retry; foreign account snapshot is never exposed',
    () async {
      await shelf.close();
      var fail = true;
      shelf = BookshelfService(
        userId: 'alice',
        openDatabase: () async {
          if (fail) throw StateError('Unavailable');
          return databaseFactoryIo.openDatabase('${directory.path}/alice.db');
        },
      );
      await shelf.loadBooks();
      expect(shelf.error, isNotNull);
      fail = false;
      await shelf.loadBooks();
      expect(shelf.error, isNull);
      await shelf.addBook(book);
      await shelf.close();
      shelf = BookshelfService(
        userId: 'bob',
        openDatabase: () =>
            databaseFactoryIo.openDatabase('${directory.path}/alice.db'),
      );
      await shelf.loadBooks();
      expect(shelf.error, isNotNull);
      expect(shelf.books, isEmpty);
      await expectLater(shelf.addBook(unknown), throwsFormatException);
    },
  );
  test('mock account IDs survive signup order changes after restart', () async {
    final first = AuthService();
    final second = AuthService();
    Future<String> register(AuthService auth, String email) async {
      await auth.signUp(
        displayName: 'Reader',
        email: email,
        password: 'Reader123',
      );
      return (await auth.signIn(email: email, password: 'Reader123')).id;
    }

    final alice = await register(first, 'Alice@example.com');
    final bob = await register(second, 'bob@example.com');
    expect(bob, isNot(alice));
    expect(await register(second, 'alice@example.com'), alice);
    first.dispose();
    second.dispose();
  });
}
