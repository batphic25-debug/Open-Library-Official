import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart' show newDatabaseFactoryMemory;
import 'package:open_library_client/features/auth/auth_service.dart';
import 'package:open_library_client/features/books/book_detail_page.dart';
import 'package:open_library_client/features/books/book_reading_page.dart';
import 'package:open_library_client/features/books/models/book.dart';
import 'package:open_library_client/features/books/models/reading_option.dart';
import 'package:open_library_client/features/books/services/book_discussion_service.dart';
import 'package:open_library_client/features/books/services/book_ranking_service.dart';
import 'package:open_library_client/features/books/services/offline_book_library.dart';
import 'package:open_library_client/features/books/services/open_library_service.dart';
import 'package:open_library_client/features/books/services/sample_books.dart';
import 'package:open_library_client/features/bookshelf/bookshelf_service.dart';
import 'package:open_library_client/features/bookshelf/models/saved_book.dart';
import 'package:open_library_client/features/discovers/widgets/reading_card.dart';
import 'package:open_library_client/features/navigation/main_shell.dart';
import 'package:open_library_client/features/profile/settings_service.dart';

const pride = Book(
  id: '/works/OL66554W',
  title: 'Pride and Prejudice',
  authors: ['Jane Austen'],
);

class NoNetworkService extends OpenLibraryService {
  int detailCalls = 0;
  int readingCalls = 0;

  @override
  Future<Book> getBookDetails(Book book) async {
    detailCalls++;
    throw StateError('Network must not be used');
  }

  @override
  Future<List<ReadingOption>> getReadingOptions(Book book) async {
    readingCalls++;
    throw StateError('Network must not be used');
  }
}

class ReaderSettings extends SettingsService {
  ReaderSettings(this.position) : super(userId: 'reader');

  ReaderPosition? position;
  bool failLoad = false;

  @override
  Future<ReaderPosition?> loadReaderPosition(String bookId) async {
    if (failLoad) throw StateError('Damaged position');
    return position;
  }

  @override
  Future<void> saveReaderPosition(String bookId, ReaderPosition value) async {
    position = value;
  }
}

class ReaderShelf extends BookshelfService {
  ReaderShelf()
    : super(
        userId: 'demo-user',
        openDatabase: () =>
            newDatabaseFactoryMemory().openDatabase('reader-shelf'),
      );

  SavedBook? saved;
  final ValueNotifier<List<ReadingBook>> visibleBooks = ValueNotifier([]);

  @override
  ValueListenable<List<ReadingBook>> get readingBooks => visibleBooks;

  void publish() {
    visibleBooks.value = saved?.status == ReadingStatus.reading
        ? [
            ReadingBook(
              book: saved!.book,
              pagesRead: saved!.pagesRead,
              totalPages: saved!.totalPages,
            ),
          ]
        : [];
    notifyListeners();
  }

  @override
  List<SavedBook> get books => [?saved];

  @override
  SavedBook? bookById(String id) => saved?.id == id ? saved : null;

  @override
  Future<void> loadBooks() async {}

  @override
  Future<bool> addBook(Book book) async {
    if (saved != null) return false;
    final now = DateTime.now().toUtc();
    saved = SavedBook(
      userId: userId,
      book: book,
      status: ReadingStatus.wantToRead,
      pagesRead: 0,
      addedAt: now,
      updatedAt: now,
    );
    publish();
    return true;
  }

  @override
  Future<void> updateStatus(String id, ReadingStatus status) async {
    saved = saved!.copyWith(status: status);
    publish();
  }

  @override
  Future<void> updateProgress(
    String id,
    int pagesRead, {
    bool completed = false,
  }) async {
    saved = saved!.copyWith(pagesRead: pagesRead);
    publish();
  }

  @override
  void dispose() {
    visibleBooks.dispose();
    super.dispose();
  }
}

void main() {
  testWidgets('19 reflowed texts and nine Gutenberg books cover 28 titles', (
    tester,
  ) async {
    final books = await tester.runAsync(SampleBooks.load);
    final assets = (await AssetManifest.loadFromAssetBundle(rootBundle))
        .listAssets()
        .toSet();
    expect(books, hasLength(30));
    var extracted = 0;
    for (final book in books!) {
      final bundled = OfflineBookLibrary.forBook(book);
      if (bundled == null) continue;
      expect(assets, contains(bundled.path), reason: book.title);
      if (bundled.gutenbergId == null) {
        extracted++;
        final text = await tester.runAsync(
          () => OfflineBookLibrary.load(bundled),
        );
        expect(text!.paragraphs.length, greaterThan(100), reason: book.title);
      }
    }
    expect(extracted, 19);
    expect(books.where(OfflineBookLibrary.hasBook), hasLength(28));
    expect(
      books
          .where((book) => !OfflineBookLibrary.hasBook(book))
          .map((book) => book.title),
      containsAll(['And Then There Were None', 'Matilda']),
    );
  });

  testWidgets('The Little Prince opens with readable text', (tester) async {
    final bundled = OfflineBookLibrary.forBook(
      const Book(id: '/works/OL10263W', title: 'The Little Prince'),
    )!;
    final text = await tester.runAsync(() => OfflineBookLibrary.load(bundled));
    expect(text!.paragraphs.first, 'TO LEON WERTH');
    expect(text.paragraphs[1], startsWith('I ask the indulgence'));
    expect(text.paragraphs.take(5).join(' '), isNot(contains('%')));
  });

  testWidgets('nine complete books are bundled with their license', (
    tester,
  ) async {
    const ids = [
      '/works/OL66554W',
      '/works/OL468431W',
      '/works/OL1095427W',
      '/works/OL29983W',
      '/works/OL450063W',
      '/works/OL85892W',
      '/works/OL262421W',
      '/works/OL262454W',
      '/works/OL138052W',
    ];
    for (final id in ids) {
      final bundled = OfflineBookLibrary.forBook(Book(id: id, title: id));
      expect(bundled, isNotNull);
      final text = await tester.runAsync(
        () => OfflineBookLibrary.load(bundled!),
      );
      expect(text!.paragraphs.length, greaterThan(100), reason: id);
      expect(text.license, contains('PROJECT GUTENBERG'), reason: id);
    }
    expect(
      OfflineBookLibrary.forBook(
        const Book(id: '/works/OL45846W', title: 'Matilda'),
      ),
      isNull,
    );
  });

  testWidgets('detail opens bundled text without a reading API request', (
    tester,
  ) async {
    final service = NoNetworkService();
    addTearDown(service.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: BookDetailPage(book: pride, service: service),
      ),
    );
    await tester.ensureVisible(find.text('Đọc sách'));
    await tester.tap(find.text('Đọc sách'));
    await tester.pump();
    await tester.runAsync(
      () => OfflineBookLibrary.load(OfflineBookLibrary.forBook(pride)!),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BookReadingPage), findsOneWidget);
    expect(find.textContaining('Bản văn tiếng Anh lưu sẵn'), findsOneWidget);
    expect(find.byTooltip('Tăng cỡ chữ'), findsOneWidget);
    expect(service.detailCalls, 0);
    expect(service.readingCalls, 0);
  });

  testWidgets('detail opens reflowed book text without an API request', (
    tester,
  ) async {
    final service = NoNetworkService();
    addTearDown(service.dispose);
    const atomic = Book(id: '/works/OL17930368W', title: 'Atomic Habits');
    await tester.pumpWidget(
      MaterialApp(
        home: BookDetailPage(book: atomic, service: service),
      ),
    );
    await tester.ensureVisible(find.text('Đọc sách'));
    await tester.tap(find.text('Đọc sách'));
    await tester.pump();
    await tester.runAsync(
      () => OfflineBookLibrary.load(OfflineBookLibrary.forBook(atomic)!),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BookReadingPage), findsOneWidget);
    expect(find.textContaining('Văn bản trình bày lại'), findsOneWidget);
    expect(find.byTooltip('Tăng cỡ chữ'), findsOneWidget);
    expect(service.detailCalls, 0);
    expect(service.readingCalls, 0);
  });

  testWidgets('reader recognizes chapters without added number badges', (
    tester,
  ) async {
    const cases = <(String, String, int)>[
      ('/works/OL66554W', 'Pride and Prejudice', 61),
      ('/works/OL468431W', 'The Great Gatsby', 9),
      ('/works/OL262421W', 'The Adventures of Sherlock Holmes', 12),
    ];
    for (final (id, title, count) in cases) {
      final book = Book(id: id, title: title);
      await tester.pumpWidget(
        MaterialApp(
          home: BookReadingPage(key: ValueKey(id), book: book),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => OfflineBookLibrary.load(OfflineBookLibrary.forBook(book)!),
      );
      await tester.pumpAndSettle();
      expect(find.text('NỘI DUNG · $count CHƯƠNG'), findsOneWidget);
      expect(find.text('01'), findsNothing);
    }
  });

  testWidgets('unbundled book gives a clear offline state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BookReadingPage(
          book: Book(id: '/works/OL45846W', title: 'Matilda'),
        ),
      ),
    );
    expect(find.textContaining('Chưa có bản văn'), findsOneWidget);
    expect(find.byTooltip('Tăng cỡ chữ'), findsNothing);
  });

  testWidgets('reader and text controls fit a small screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      const MaterialApp(home: BookReadingPage(book: pride)),
    );
    await tester.pump();
    await tester.runAsync(
      () => OfflineBookLibrary.load(OfflineBookLibrary.forBook(pride)!),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tăng cỡ chữ'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('reader restores and saves its position for the account', (
    tester,
  ) async {
    final settings = ReaderSettings(
      const ReaderPosition(offset: 420, fontSize: 22),
    );
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: BookReadingPage(book: pride, settings: settings),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.byType(ListView), findsOneWidget);
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.controller!.offset, closeTo(420, 1));
    await tester.tap(find.byTooltip('Tăng cỡ chữ'));
    await tester.pump();
    list.controller!.jumpTo(920);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    final saved = settings.position;
    expect(saved!.offset, greaterThan(420));
    expect(saved.fontSize, 24);
  });

  testWidgets('reader reports final page only at the end of the text', (
    tester,
  ) async {
    const book = Book(
      id: '/works/OL66554W',
      title: 'Pride and Prejudice',
      selectedEdition: BookEdition(
        id: '/books/OL1M',
        workIds: ['/works/OL66554W'],
        pages: 100,
      ),
    );
    int? page;
    await tester.pumpWidget(
      MaterialApp(
        home: BookReadingPage(
          book: book,
          onPageChanged: (_, value) async => page = value,
        ),
      ),
    );
    await tester.runAsync(
      () => OfflineBookLibrary.load(OfflineBookLibrary.forBook(book)!),
    );
    await tester.pumpAndSettle();
    final scroll = tester.widget<ListView>(find.byType(ListView)).controller!;
    for (var i = 0; i < 5; i++) {
      scroll.jumpTo(scroll.position.maxScrollExtent - 1);
      await tester.pumpAndSettle();
    }
    await tester.pump(const Duration(milliseconds: 650));
    expect(page, lessThan(100));
    for (var i = 0; i < 5; i++) {
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
    }
    await tester.pump(const Duration(milliseconds: 650));
    expect(page, 100);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline reading appears in shelf and resumes at saved place', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final auth = AuthService();
    final shelf = ReaderShelf();
    final settings = ReaderSettings(null);
    final service = NoNetworkService();
    final discussion = BookDiscussionService(
      openDatabase: () =>
          newDatabaseFactoryMemory().openDatabase('reader-discussion'),
    );
    final rankings = BookRankingService(
      openDatabase: () =>
          newDatabaseFactoryMemory().openDatabase('reader-rankings'),
    );
    addTearDown(auth.dispose);
    addTearDown(shelf.dispose);
    addTearDown(settings.dispose);
    addTearDown(service.dispose);
    await tester.runAsync(
      () => auth.signIn(
        email: AuthService.demoEmail,
        password: AuthService.demoPassword,
      ),
    );
    await tester.runAsync(SampleBooks.load);
    await tester.pumpWidget(
      MaterialApp(
        home: MainShell(
          authService: auth,
          bookshelfService: shelf,
          settings: settings,
          service: service,
          discussionService: discussion,
          rankingService: rankings,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tìm kiếm').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sách đọc offline').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Pride');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pride and Prejudice').first);
    await tester.pumpAndSettle();
    expect(rankings.viewsFor(pride.id, days: 1), 1);
    await tester.ensureVisible(find.text('Đọc sách'));
    await tester.tap(find.text('Đọc sách'));
    await tester.pump();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(shelf.bookById(pride.id)?.status, ReadingStatus.reading);
    final firstList = tester.widget<ListView>(
      find.descendant(
        of: find.byType(BookReadingPage),
        matching: find.byType(ListView),
      ),
    );
    firstList.controller!.jumpTo(920);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    expect(shelf.bookById(pride.id)!.pagesRead, greaterThan(1));
    Navigator.of(tester.element(find.byType(BookReadingPage))).pop();
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(BookDetailPage))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khám phá').last);
    await tester.pumpAndSettle();
    final current = shelf.bookById(pride.id)!;
    expect(
      find.text('Trang ${current.pagesRead}/${current.totalPages}'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tủ sách').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đang đọc').last);
    await tester.pumpAndSettle();
    expect(find.text('Vị trí đọc được lưu tự động'), findsOneWidget);
    expect(find.text('Đọc tiếp'), findsOneWidget);
    await tester.tap(find.text('Đọc tiếp'));
    await tester.pump();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.byType(BookReadingPage), findsOneWidget);
    final resumed = tester.widget<ListView>(
      find.descendant(
        of: find.byType(BookReadingPage),
        matching: find.byType(ListView),
      ),
    );
    expect(resumed.controller!.offset, closeTo(920, 1));
  });

  testWidgets('damaged saved position does not block the offline text', (
    tester,
  ) async {
    final settings = ReaderSettings(null)..failLoad = true;
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: BookReadingPage(book: pride, settings: settings),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.textContaining('Bản văn tiếng Anh lưu sẵn'), findsOneWidget);
  });
}
