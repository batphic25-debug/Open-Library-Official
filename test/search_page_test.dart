import 'dart:async';

import 'package:sembast/sembast_memory.dart' show newDatabaseFactoryMemory;
import 'package:open_library_client/features/bookshelf/bookshelf_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_library_client/core/theme/app_theme.dart';
import 'package:open_library_client/core/widgets/book_card.dart';
import 'package:open_library_client/features/books/models/book.dart';
import 'package:open_library_client/features/books/services/open_library_service.dart';
import 'package:open_library_client/features/books/services/sample_books.dart';
import 'package:open_library_client/features/search/search_page.dart';

class PendingSearch {
  PendingSearch(this.query, this.language, this.sort, this.page);
  final String query;
  final String? language;
  final BookSort sort;
  final int page;
  final result = Completer<BookSearchResult>();
}

class ControlledSearch extends OpenLibraryService {
  final calls = <PendingSearch>[];
  @override
  Future<BookSearchResult> searchBooks({
    required String query,
    String? language,
    BookSort sort = BookSort.relevance,
    int page = 1,
    int limit = 20,
  }) {
    final call = PendingSearch(query, language, sort, page);
    calls.add(call);
    return call.result.future;
  }
}

const first = Book(
  id: '1',
  title: 'First Book',
  authors: ['First Author'],
  firstPublishYear: 2000,
);
const second = Book(id: '2', title: 'Second Book', authors: ['Second Author']);

Future<void> start(
  WidgetTester tester,
  ControlledSearch service, {
  String query = '',
  BookshelfService? shelf,
  ValueChanged<Book>? onBookTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SearchPage(
          service: service,
          bookshelfService: shelf,
          initialQuery: query,
          onBookTap: onBookTap ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> finish(
  WidgetTester tester,
  PendingSearch call,
  List<Book> books, {
  bool more = false,
}) async {
  call.result.complete(
    BookSearchResult(
      books: books,
      total: more ? 50 : books.length,
      hasMore: more,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late ControlledSearch service;
  setUp(() => service = ControlledSearch());
  tearDown(() => service.dispose());
  testWidgets('offline search uses bundled books without the API', (
    tester,
  ) async {
    await tester.runAsync(SampleBooks.load);
    await start(tester, service);
    await tester.tap(find.text('Sách đọc offline'));
    await tester.pumpAndSettle();
    expect(find.text('28 sách'), findsOneWidget);
    expect(service.calls, isEmpty);
    await tester.enterText(find.byType(TextField), 'Pride');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.text('1 sách'), findsOneWidget);
    expect(find.text('Pride and Prejudice'), findsOneWidget);
    expect(service.calls, isEmpty);
  });

  testWidgets('late online results do not replace offline books', (
    tester,
  ) async {
    await tester.runAsync(SampleBooks.load);
    await start(tester, service, query: 'Pride');
    expect(service.calls, hasLength(1));
    await tester.tap(find.text('Sách đọc offline'));
    await tester.pumpAndSettle();
    expect(find.text('Pride and Prejudice'), findsOneWidget);
    await finish(tester, service.calls.single, [first]);
    expect(find.text('Pride and Prejudice'), findsOneWidget);
    expect(find.text(first.title), findsNothing);
  });

  testWidgets('bookmark saves once and reflects changes from the bookshelf', (
    tester,
  ) async {
    final shelf = BookshelfService(
      userId: 'reader',
      openDatabase: () => newDatabaseFactoryMemory().openDatabase('search'),
    );
    addTearDown(shelf.dispose);
    const book = Book(id: '/works/OL1W', title: 'Saved from search');
    await start(tester, service, query: 'book', shelf: shelf);
    await finish(tester, service.calls.single, [book]);
    await tester.tap(find.byTooltip('Lưu vào tủ sách'));
    await tester.pumpAndSettle();
    expect(shelf.books.single.id, book.id);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    await tester.tap(find.byTooltip('Đã có trong tủ sách'));
    await tester.pumpAndSettle();
    expect(shelf.books, hasLength(1));
    final deletion = shelf.removeBook(book.id);
    await tester.pumpAndSettle();
    await deletion;
    await tester.pump();
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
  });

  testWidgets('debounce sends only the latest typed text', (tester) async {
    await start(tester, service);
    expect(find.textContaining('Nhập tên sách'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Har');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.enterText(find.byType(TextField), 'Harry Potter');
    await tester.pump(const Duration(milliseconds: 449));
    expect(service.calls, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(service.calls.single.query, 'Harry Potter');
    await finish(tester, service.calls.single, []);
    expect(find.textContaining('Không tìm thấy sách'), findsOneWidget);
  });

  testWidgets(
    'old responses never overwrite a new query; requests are serialized',
    (tester) async {
      await start(tester, service, query: 'old');
      await tester.enterText(find.byType(TextField), 'new');
      await tester.pump(const Duration(milliseconds: 500));
      expect(service.calls, hasLength(1));
      service.calls.first.result.complete(
        const BookSearchResult(books: [first], total: 1, hasMore: false),
      );
      await tester.pump();
      expect(find.text(first.title), findsNothing);
      expect(service.calls, hasLength(2));
      expect(service.calls.last.query, 'new');
      await finish(tester, service.calls.last, [second]);
      expect(find.text(second.title), findsOneWidget);
    },
  );

  testWidgets('pagination deduplicates books and cannot queue duplicate taps', (
    tester,
  ) async {
    Book? selected;
    await start(
      tester,
      service,
      query: 'book',
      onBookTap: (book) => selected = book,
    );
    await finish(tester, service.calls.first, [first], more: true);
    final button = find.widgetWithText(OutlinedButton, 'Tải thêm');
    await tester.ensureVisible(button);
    final callback = tester.widget<OutlinedButton>(button).onPressed!;
    callback();
    callback();
    await tester.pump();
    expect(service.calls, hasLength(2));
    expect(service.calls.last.page, 2);
    await finish(tester, service.calls.last, [first, second], more: true);
    expect(find.byType(BookCard), findsNWidgets(2));
    expect(service.calls, hasLength(2));
    await tester.ensureVisible(find.text(second.title));
    await tester.tap(find.text(second.title));
    expect(selected, same(second));
  });

  testWidgets(
    'language and sort reset pagination and change request parameters',
    (tester) async {
      await start(tester, service, query: 'book');
      await finish(tester, service.calls.first, [first]);
      await tester.tap(find.byTooltip('Lọc ngôn ngữ'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<String>, 'Tiếng Anh'),
      );
      await tester.pump();
      expect(service.calls.last.language, 'eng');
      expect(service.calls.last.page, 1);
      await finish(tester, service.calls.last, [second]);
      expect(find.text(first.title), findsNothing);
      await tester.tap(find.byTooltip('Sắp xếp sách'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<BookSort>, 'Cũ nhất'),
      );
      await tester.pump();
      expect(service.calls.last.sort, BookSort.oldest);
      expect(service.calls.last.language, 'eng');
      expect(service.calls.last.page, 1);
      await finish(tester, service.calls.last, [first]);
    },
  );

  testWidgets('load-more error preserves results and retries the failed page', (
    tester,
  ) async {
    await start(tester, service, query: 'book');
    await finish(tester, service.calls.first, [first], more: true);
    await tester.ensureVisible(find.text('Tải thêm'));
    await tester.tap(find.text('Tải thêm'));
    await tester.pump();
    service.calls.last.result.completeError(
      const BookSearchException('Mất mạng'),
    );
    await tester.pumpAndSettle();
    expect(find.text(first.title), findsOneWidget);
    expect(find.text('Mất mạng'), findsOneWidget);
    await tester.ensureVisible(find.text('Thử lại'));
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    expect(service.calls.last.page, 2);
    await finish(tester, service.calls.last, [second]);
  });

  testWidgets('clear and dispose ignore pending responses', (tester) async {
    await start(tester, service, query: 'old');
    await tester.tap(find.byTooltip('Xóa từ khóa'));
    await tester.pump();
    await finish(tester, service.calls.first, [first]);
    expect(find.text(first.title), findsNothing);
    expect(find.textContaining('Nhập tên sách'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'later');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpWidget(const SizedBox());
    service.calls.last.result.complete(
      const BookSearchResult(books: [second], total: 1, hasMore: false),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('small viewport with keyboard and large text does not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await start(tester, service, query: 'book');
    await finish(tester, service.calls.first, [first]);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text(first.title),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text(first.title).hitTestable(), findsOneWidget);
  });
}
