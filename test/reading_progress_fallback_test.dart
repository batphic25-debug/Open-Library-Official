import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:open_library_client/features/books/data/sample_books.dart';
import 'package:open_library_client/features/books/models/book.dart';
import 'package:open_library_client/features/books/services/offline_book_library.dart';
import 'package:open_library_client/features/bookshelf/bookshelf_service.dart';
import 'package:open_library_client/features/bookshelf/models/saved_book.dart';
import 'package:open_library_client/features/discovers/widgets/reading_card.dart';

void main() {
  testWidgets(
    'legacy Harry Potter keeps seven pages and shows estimated percent',
    (tester) async {
      final catalog = (await tester.runAsync(SampleBooks.load))!;
      final book = catalog.singleWhere((book) => book.id == '/works/OL82563W');
      expect(book.selectedEdition!.pages, isNull);
      final factory = newDatabaseFactoryMemory();
      final date = DateTime.utc(2026, 10, 20);
      final legacy = SavedBook(
        userId: 'reader',
        book: book,
        status: ReadingStatus.reading,
        pagesRead: 7,
        addedAt: date,
        updatedAt: date,
      ).toJson()..remove('estimatedTotalPages');
      await tester.runAsync(() async {
        final db = await factory.openDatabase('legacy');
        await stringMapStoreFactory.store('bookshelf').record('snapshot').put(
          db,
          {
            'version': 1,
            'userId': 'reader',
            'books': [legacy],
            'notes': [],
          },
        );
        await db.close();
      });
      BookshelfService open() => BookshelfService(
        userId: 'reader',
        openDatabase: () => factory.openDatabase('legacy'),
      );
      var shelf = open();
      addTearDown(() => shelf.close());
      await tester.runAsync(shelf.loadBooks);
      final saved = shelf.bookById(book.id)!;
      final content = (await tester.runAsync(
        () => OfflineBookLibrary.load(OfflineBookLibrary.forBook(book)!),
      ))!;
      expect(saved.pagesRead, 7);
      expect(saved.updatedAt, date);
      expect(saved.totalPages, content.pageCount(book));
      expect(saved.progress, 7 / content.pageCount(book));
      expect(saved.totalPagesEstimated, isTrue);
      expect(saved.book.selectedEdition!.pages, isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadingCard(
              reading: shelf.readingBooks.value.single,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('~${700 ~/ saved.totalPages!}%'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        saved.progress,
      );
      await tester.runAsync(() async {
        await shelf.saveNote(book.id, 'Giữ nguyên ghi chú');
        await shelf.close();
        shelf = open();
        await shelf.loadBooks();
      });
      expect(shelf.books.single.pagesRead, 7);
      expect(shelf.books.single.estimatedTotalPages, saved.estimatedTotalPages);
      expect(shelf.noteFor(book.id)!.body, 'Giữ nguyên ghi chú');
      await tester.runAsync(
        () => shelf.updateProgress(book.id, saved.totalPages!),
      );
      expect(shelf.books.single.status, ReadingStatus.read);
      expect(shelf.readingBooks.value, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new bundled books share reader totals and discard them on edition change',
    (tester) async {
      final catalog = (await tester.runAsync(SampleBooks.load))!;
      final factory = newDatabaseFactoryMemory();
      final shelf = BookshelfService(
        userId: 'reader',
        openDatabase: () => factory.openDatabase('new-books'),
      );
      addTearDown(shelf.close);
      final missing = catalog.where(
        (book) => book.selectedEdition!.pages == null,
      );
      expect(missing, hasLength(3));
      await tester.runAsync(() async {
        for (final book in missing) {
          await shelf.addBook(book);
          final content = await OfflineBookLibrary.load(
            OfflineBookLibrary.forBook(book)!,
          );
          expect(shelf.bookById(book.id)!.totalPages, content.pageCount(book));
        }
        final book = missing.first;
        await shelf.updateEdition(
          book.id,
          BookEdition(id: '/books/OL1M', workIds: [book.id], pages: 100),
        );
        expect(shelf.bookById(book.id)!.totalPages, 100);
        expect(shelf.bookById(book.id)!.estimatedTotalPages, isNull);
        expect(shelf.bookById(book.id)!.pagesRead, 0);
      });
    },
  );
}
