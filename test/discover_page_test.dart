import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_library_client/core/theme/app_theme.dart';
import 'package:open_library_client/core/widgets/book_card.dart';
import 'package:open_library_client/core/widgets/book_cover.dart';
import 'package:open_library_client/features/books/models/book.dart';
import 'package:open_library_client/features/bookshelf/bookshelf_service.dart';
import 'package:open_library_client/features/discovers/discover_page.dart';
import 'package:open_library_client/features/discovers/widgets/category_selector.dart';
import 'package:open_library_client/features/discovers/widgets/reading_card.dart';
import 'package:sembast/sembast_memory.dart' show newDatabaseFactoryMemory;

const first = Book(
  id: '1',
  title: 'Book One',
  authors: ['Author'],
  categories: ['Văn học'],
);
const second = Book(id: '2', title: 'Book Two', categories: ['Kỳ ảo']);
Widget host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  testWidgets(
    'view all expands catalog and recommendations open the exact book',
    (tester) async {
      final catalog = List.generate(
        8,
        (index) => Book(
          id: '$index',
          title: index == 0
              ? 'A long title that wraps onto a second line'
              : 'Title $index',
          categories: [index < 4 ? 'Văn học' : 'Kỳ ảo'],
        ),
      );
      Book? selected;
      await tester.pumpWidget(
        host(
          DiscoverPage(
            displayName: 'Reader',
            loadBooks: () async => catalog,
            onSearch: (_) {},
            onBookTap: (book) => selected = book,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BookCard), findsNWidgets(4));
      final firstCard = find.byType(BookCard).at(0);
      final secondCard = find.byType(BookCard).at(1);
      final firstCover = find.descendant(
        of: firstCard,
        matching: find.byType(BookCover),
      );
      final secondCover = find.descendant(
        of: secondCard,
        matching: find.byType(BookCover),
      );
      expect(tester.getSize(firstCover), tester.getSize(secondCover));
      expect(tester.getSize(firstCard), tester.getSize(secondCard));
      await tester.ensureVisible(find.text('Title 3'));
      await tester.tap(find.text('Title 3'));
      expect(selected, same(catalog[3]));
      await tester.ensureVisible(find.text('Xem thêm'));
      await tester.tap(find.text('Xem thêm'));
      await tester.pumpAndSettle();
      expect(find.byType(BookCard), findsNWidgets(8));
      expect(find.text('Gợi ý cho bạn'), findsNothing);
      await tester.tap(find.text('Thu gọn'));
      await tester.pumpAndSettle();
      expect(find.byType(BookCard), findsNWidgets(4));
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Kỳ ảo'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Kỳ ảo'));
      await tester.pumpAndSettle();
      expect(find.text('Title 0'), findsNothing);
      expect(find.text('Title 7'), findsOneWidget);
    },
  );

  testWidgets(
    'discover filters catalog and forwards exact book and search text',
    (tester) async {
      Book? selected;
      String? query;
      await tester.pumpWidget(
        host(
          DiscoverPage(
            displayName: 'Reader',
            searchQuery: 'Harry Potter',
            loadBooks: () async => [first, second],
            onSearch: (value) => query = value,
            onBookTap: (value) => selected = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      expect(query, 'Harry Potter');
      expect(find.textContaining('Chưa có sách đang đọc'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byType(CategorySelector),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Kỳ ảo'));
      await tester.pumpAndSettle();
      expect(find.byType(BookCard), findsOneWidget);
      final filteredBook = find.descendant(
        of: find.byType(BookCard),
        matching: find.text(second.title),
      );
      await tester.ensureVisible(filteredBook);
      await tester.pumpAndSettle();
      await tester.tap(filteredBook);
      expect(selected, same(second));
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Tất cả'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Tất cả'));
      await tester.pumpAndSettle();
      expect(find.byType(BookCard), findsNWidgets(2));
    },
  );

  testWidgets('featured carousel opens the selected book', (tester) async {
    const highlighted = Book(
      id: '1',
      title: 'Book One',
      authors: ['Author'],
      categories: ['Văn học'],
      description: 'A longer introduction to the featured story.',
      selectedEdition: BookEdition(
        id: '/books/OL1M',
        workIds: ['1'],
        pages: 96,
      ),
    );
    Book? selected;
    await tester.pumpWidget(
      host(
        DiscoverPage(
          displayName: 'Reader',
          loadBooks: () async => [highlighted, second],
          onSearch: (_) {},
          onBookTap: (book) => selected = book,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sách nổi bật'), findsOneWidget);
    expect(find.text('Sách trong thư viện'), findsOneWidget);
    expect(find.text(highlighted.description!), findsOneWidget);
    final featured = find.byKey(const ValueKey('featured-1'));
    expect(
      find.descendant(of: featured, matching: find.text('Văn học')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: featured, matching: find.text('96 trang')),
      findsOneWidget,
    );
    final featuredCover = tester.widget<BookCover>(
      find.descendant(of: featured, matching: find.byType(BookCover)),
    );
    expect(featuredCover.width, greaterThan(200));
    expect(featuredCover.height, greaterThan(300));
    await tester.ensureVisible(find.byKey(const ValueKey('featured-1')));
    await tester.tap(find.byKey(const ValueKey('featured-1')));
    expect(selected, same(highlighted));
  });

  testWidgets('featured pages, view all, and save button work', (tester) async {
    final shelf = BookshelfService(
      userId: 'featured-test',
      openDatabase: () =>
          newDatabaseFactoryMemory().openDatabase('featured-test'),
    );
    addTearDown(shelf.dispose);
    final catalog = [
      const Book(id: '/works/OL10263W', title: 'The Little Prince'),
      const Book(id: '/works/OL82563W', title: 'Harry Potter'),
      const Book(id: '/works/OL468431W', title: 'The Great Gatsby'),
      const Book(id: '/works/OL66554W', title: 'Pride and Prejudice'),
    ];
    await tester.pumpWidget(
      host(
        DiscoverPage(
          displayName: 'Reader',
          loadBooks: () async => catalog,
          bookshelfService: shelf,
          onSearch: (_) {},
          onBookTap: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('featured-dot-0')), findsOneWidget);
    final firstCard = find.byKey(const ValueKey('featured-/works/OL10263W'));
    final saveButton = find.descendant(
      of: firstCard,
      matching: find.byTooltip('Lưu vào tủ sách'),
    );
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(shelf.bookById(catalog.first.id), isNotNull);
    expect(find.byTooltip('Đã lưu vào tủ sách'), findsOneWidget);

    final libraryCard = find.ancestor(
      of: find.text('Harry Potter').last,
      matching: find.byType(BookCard),
    );
    final librarySave = find.descendant(
      of: libraryCard,
      matching: find.byTooltip('Lưu vào tủ sách'),
    );
    await tester.ensureVisible(librarySave);
    await tester.tap(librarySave);
    await tester.pumpAndSettle();
    expect(shelf.bookById(catalog[1].id), isNotNull);

    await tester.ensureVisible(find.byType(PageView));
    await tester.pumpAndSettle();
    tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(0);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    final activeDot = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('featured-dot-1')),
    );
    expect((activeDot.decoration! as BoxDecoration).color, AppTheme.accent);

    await tester.ensureVisible(find.text('Xem tất cả'));
    await tester.tap(find.text('Xem tất cả'));
    await tester.pumpAndSettle();
    expect(find.byType(BookCard), findsNWidgets(4));
  });

  testWidgets('loading, error, retry, and empty catalog states work', (
    tester,
  ) async {
    final firstLoad = Completer<List<Book>>();
    var calls = 0;
    await tester.pumpWidget(
      host(
        DiscoverPage(
          displayName: 'Reader',
          loadBooks: () => calls++ == 0 ? firstLoad.future : Future.value([]),
          onSearch: (_) {},
          onBookTap: (_) {},
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    firstLoad.completeError(StateError('missing catalog'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Thử lại'));
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có sách trong danh mục này.'), findsOneWidget);
  });

  testWidgets(
    'reading progress updates from the supplied notifier without fake percentages',
    (tester) async {
      final progress = ValueNotifier<List<ReadingBook>>([]);
      Book? selected;
      addTearDown(progress.dispose);
      await tester.pumpWidget(
        host(
          DiscoverPage(
            displayName: 'Reader',
            readingBooks: progress,
            loadBooks: () async => [],
            onSearch: (_) {},
            onBookTap: (book) => selected = book,
          ),
        ),
      );
      await tester.pumpAndSettle();
      progress.value = [const ReadingBook(book: first, pagesRead: 35)];
      await tester.pumpAndSettle();
      expect(find.text('Đã đọc 35 trang'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      progress.value = [
        const ReadingBook(book: first, pagesRead: 35, totalPages: 100),
      ];
      await tester.pumpAndSettle();
      expect(find.text('35%'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        .35,
      );
      await tester.ensureVisible(find.text('Cập nhật'));
      await tester.tap(find.text('Cập nhật'));
      expect(selected, same(first));
    },
  );

  testWidgets('cover falls back for missing metadata and failed images', (
    tester,
  ) async {
    await tester.pumpWidget(host(const BookCover(book: first)));
    expect(find.byIcon(Icons.auto_stories_outlined), findsOneWidget);
    expect(find.text('BÌA THAY THẾ'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText() == first.title,
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(
      host(
        const BookCover(
          book: Book(id: 'bad', title: 'Broken', coverId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.auto_stories_outlined), findsOneWidget);
    expect(find.text('BÌA THAY THẾ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('discover fits a small screen with large text', (tester) async {
    const longCategory = Book(
      id: 'long-category',
      title: 'Long category book',
      categories: ['Phát triển bản thân'],
    );
    final reading = ValueNotifier<List<ReadingBook>>([
      const ReadingBook(book: first, pagesRead: 65, totalPages: 100),
    ]);
    addTearDown(reading.dispose);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      host(
        DiscoverPage(
          displayName: 'Reader',
          readingBooks: reading,
          loadBooks: () async => [longCategory, second],
          onSearch: (_) {},
          onBookTap: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(CategorySelector),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
}
