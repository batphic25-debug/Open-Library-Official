import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_library_client/core/theme/app_theme.dart';
import 'package:open_library_client/core/widgets/book_cover.dart';
import 'package:open_library_client/features/books/book_detail_page.dart';
import 'package:open_library_client/features/books/editions_page.dart';
import 'package:open_library_client/features/books/models/book.dart';
import 'package:open_library_client/features/books/services/book_discussion_service.dart';
import 'package:open_library_client/features/books/services/open_library_service.dart';
import 'package:sembast/sembast_memory.dart' show newDatabaseFactoryMemory;

const original = Book(
  id: '/works/OL1W',
  title: 'Test work',
  authors: ['Author'],
  description: 'Introduction',
  descriptionSource: 'Nhóm biên soạn',
  selectedEdition: firstEdition,
);
const firstEdition = BookEdition(
  id: '/books/OL10M',
  workIds: ['/works/OL1W'],
  title: 'First edition',
  isbn: ['111'],
  publishers: ['First publisher'],
  pages: 100,
  languages: ['eng'],
  coverId: 1,
);
const secondEdition = BookEdition(
  id: '/books/OL11M',
  workIds: ['/works/OL1W'],
  title: 'Second edition',
  isbn: ['222'],
  publishers: ['Second publisher'],
  pages: 200,
  languages: ['vie'],
  coverId: 2,
);

class DetailService extends OpenLibraryService {
  Book details = original;
  int detailCalls = 0;
  int editionCalls = 0;
  bool failDetail = false;
  bool failNextPage = false;
  bool empty = false;
  @override
  Future<Book> getBookDetails(Book book) async {
    detailCalls++;
    if (failDetail) throw const BookSearchException('Lỗi chi tiết');
    return details;
  }

  @override
  Future<EditionPageResult> getEditions(
    String workId, {
    int page = 1,
    int limit = 20,
  }) async {
    editionCalls++;
    if (page == 2 && failNextPage) {
      throw const BookSearchException('Lỗi tải thêm');
    }
    return EditionPageResult(
      editions: empty
          ? []
          : page == 1
          ? [firstEdition]
          : [firstEdition, secondEdition],
      total: empty ? 0 : 2,
      hasMore: !empty && page == 1,
    );
  }
}

Widget host(Widget child) => MaterialApp(theme: AppTheme.light, home: child);
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  late DetailService service;
  setUp(() => service = DetailService());
  tearDown(() => service.dispose());

  testWidgets('detail retry works and save waits for the bookshelf service', (
    tester,
  ) async {
    service.failDetail = true;
    await tester.pumpWidget(
      host(BookDetailPage(book: original, service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lỗi chi tiết'), findsOneWidget);
    service.failDetail = false;
    await tapVisible(tester, find.text('Thử lại'));
    expect(find.text('Test work'), findsOneWidget);
    expect(service.detailCalls, 2);
    await tester.ensureVisible(find.text('Thêm vào tủ sách'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Thêm vào tủ sách'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('reader can rate, comment and reply on a book', (tester) async {
    final discussion = BookDiscussionService(
      openDatabase: () =>
          newDatabaseFactoryMemory().openDatabase('detail-discussion-test'),
    );
    await tester.pumpWidget(
      host(
        BookDetailPage(
          book: original,
          service: service,
          userId: 'alice',
          displayName: 'Alice',
          discussionService: discussion,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa có đánh giá'), findsOneWidget);
    await tapVisible(tester, find.byTooltip('Đánh giá 5 sao'));
    expect(find.text('5.0'), findsOneWidget);

    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Một câu chuyện đáng đọc.');
    await tapVisible(tester, find.text('Gửi bình luận'));
    expect(find.text('Một câu chuyện đáng đọc.'), findsOneWidget);
    expect(find.text('Bình luận (1)'), findsOneWidget);

    await tapVisible(tester, find.text('Trả lời'));
    await tester.enterText(find.byType(TextField), 'Mình đồng ý.');
    await tapVisible(tester, find.text('Gửi bình luận'));
    expect(find.text('Mình đồng ý.'), findsOneWidget);
    expect(find.text('Bình luận (2)'), findsOneWidget);
  });

  testWidgets(
    'changing edition updates cover, ISBN, publisher, language and pages together',
    (tester) async {
      Book? saved;
      Uri? opened;
      await tester.pumpWidget(
        host(
          BookDetailPage(
            book: original,
            service: service,
            onAddToShelf: (book) async {
              saved = book;
              return true;
            },
            openLink: (url) async {
              opened = url;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Xem các phiên bản'));
      await tapVisible(tester, find.text('Tải thêm phiên bản'));
      expect(find.text('Chọn phiên bản'), findsOneWidget);
      await tapVisible(tester, find.text('Chọn phiên bản'));
      final cover = tester.widget<BookCover>(find.byType(BookCover));
      expect(cover.book.selectedEdition, same(secondEdition));
      expect(cover.book.coverUrl, contains('/2-M.jpg'));
      expect(find.textContaining('ISBN: 222'), findsOneWidget);
      expect(find.textContaining('Số trang: 200'), findsOneWidget);
      expect(
        find.textContaining('Nhà xuất bản: Second publisher'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Ngôn ngữ ấn bản: Tiếng Việt'),
        findsOneWidget,
      );
      await tapVisible(tester, find.text('Thêm vào tủ sách'));
      expect(saved!.selectedEdition, same(secondEdition));
      expect(find.text('Đã thêm sách vào tủ.'), findsOneWidget);
      await tapVisible(tester, find.text('Mở trên Open Library'));
      expect(opened.toString(), 'https://openlibrary.org/books/OL11M');
    },
  );

  testWidgets('save blocks double submission and reports duplicates', (
    tester,
  ) async {
    final completer = Completer<bool>();
    var calls = 0;
    await tester.pumpWidget(
      host(
        BookDetailPage(
          book: original,
          service: service,
          onAddToShelf: (_) {
            calls++;
            return completer.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Thêm vào tủ sách'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm vào tủ sách'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
      isNull,
    );
    expect(calls, 1);
    completer.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Sách đã có trong tủ.'), findsOneWidget);
  });

  testWidgets(
    'edition load-more retries without losing or duplicating entries',
    (tester) async {
      service.failNextPage = true;
      await tester.pumpWidget(
        host(EditionsPage(workId: original.id, service: service)),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Tải thêm phiên bản'));
      expect(find.text('Lỗi tải thêm'), findsOneWidget);
      expect(find.byType(BookCover), findsOneWidget);
      service.failNextPage = false;
      await tapVisible(tester, find.text('Thử lại'));
      expect(find.byType(BookCover), findsNWidgets(2));
      expect(service.editionCalls, 3);
    },
  );

  testWidgets('empty editions and large text on small screens remain usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    service.empty = true;
    service.details = Book(
      id: original.id,
      title: List.filled(8, 'Tên sách rất dài').join(' '),
      description: List.filled(20, 'Giới thiệu dài vẫn cuộn được.').join('\n'),
      selectedEdition: secondEdition,
    );
    await tester.pumpWidget(
      host(BookDetailPage(book: original, service: service)),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Xem các phiên bản'));
    expect(find.text('Chưa có phiên bản xuất bản.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save and external-link failures are visible and retryable', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        BookDetailPage(
          book: original,
          service: service,
          onAddToShelf: (_) async => throw StateError('Offline'),
          openLink: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Thêm vào tủ sách'));
    expect(find.text('Không thể thêm sách. Vui lòng thử lại.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
      isNotNull,
    );
    await tester.pump(const Duration(seconds: 5));
    await tapVisible(tester, find.text('Mở trên Open Library'));
    expect(
      find.text('Không thể mở Open Library. Vui lòng thử lại.'),
      findsOneWidget,
    );
  });
}
