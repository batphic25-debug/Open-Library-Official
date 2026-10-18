import 'dart:io';

import 'package:sembast/sembast_memory.dart' show newDatabaseFactoryMemory;
import 'package:open_library_client/features/bookshelf/bookshelf_service.dart';
import 'package:open_library_client/features/bookshelf/note_editor_page.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_library_client/app.dart';
import 'package:open_library_client/core/theme/app_theme.dart';
import 'package:open_library_client/features/books/models/book.dart';
import 'package:open_library_client/features/books/book_detail_page.dart';
import 'package:open_library_client/features/books/editions_page.dart';
import 'package:open_library_client/features/books/services/open_library_service.dart';
import 'package:open_library_client/features/books/services/sample_books.dart';
import 'package:open_library_client/features/navigation/main_shell.dart';
import 'package:open_library_client/features/auth/auth_service.dart';
import 'package:open_library_client/features/discovers/widgets/reading_card.dart';

/// Opt-in captures rendered by Flutter, using the SDK fonts instead of Ahem.
void main() {
  testWidgets('capture auth, discover and search pages for handoff', (
    tester,
  ) async {
    const sdk = String.fromEnvironment('FLUTTER_SDK');
    final font = FontLoader('Roboto');
    for (final weight in ['Regular', 'Bold', 'Black']) {
      final bytes = File(
        '$sdk/bin/cache/artifacts/material_fonts/Roboto-$weight.ttf',
      ).readAsBytesSync();
      font.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytesSync(),
          ),
        ),
      );
    await icons.load();
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    // Keep auth-flow tests and still captures independent of looping decoration.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = AuthService();
    addTearDown(auth.dispose);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: OpenLibraryApp(authService: auth),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/images/logo.png'),
        tester.element(find.byType(Image)),
      );
    });
    await tester.pumpAndSettle();

    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('md/screenshots/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('login');
    await tester.ensureVisible(find.text('Đăng ký'));
    await tester.tap(find.text('Đăng ký'));
    await tester.pumpAndSettle();
    await capture('register');
    await tester.ensureVisible(find.text('Đăng nhập'));
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Quên mật khẩu?'));
    await tester.tap(find.text('Quên mật khẩu?'));
    await tester.pumpAndSettle();
    await capture('forgot-password');

    final catalog = (await tester.runAsync(SampleBooks.load))!;
    // Preview-only progress matches the design; production never seeds reading history.
    final reading = ValueNotifier<List<ReadingBook>>([
      ReadingBook(book: catalog.first, pagesRead: 208, totalPages: 320),
    ]);
    addTearDown(reading.dispose);
    final shelf = BookshelfService(
      userId: 'demo-user',
      openDatabase: () => newDatabaseFactoryMemory().openDatabase('preview'),
    );
    addTearDown(shelf.dispose);
    await tester.runAsync(() async {
      await shelf.addBook(catalog.first);
      await shelf.updateProgress(
        catalog.first.id,
        (catalog.first.selectedEdition!.pages! * .65).round(),
      );
      await shelf.addBook(catalog[1]);
      await shelf.updateProgress(
        catalog[1].id,
        (catalog[1].selectedEdition!.pages! * .3).round(),
      );
      await shelf.saveNote(
        catalog.first.id,
        'Bắt đầu từ những thay đổi nhỏ. Mỗi ngày dành một chút thời gian cho điều mình muốn làm tốt hơn.',
      );
    });
    final search = _PreviewSearch(catalog);
    addTearDown(search.dispose);
    await tester.runAsync(
      () => auth.signIn(
        email: AuthService.demoEmail,
        password: AuthService.demoPassword,
      ),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          home: MainShell(
            authService: auth,
            service: search,
            bookshelfService: shelf,
            readingBooks: reading,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(MainShell));
    await tester.runAsync(() async {
      for (final book in catalog) {
        await precacheImage(
          ResizeImage(AssetImage(book.coverAsset!), width: 400),
          context,
        );
      }
    });
    await tester.pumpAndSettle();
    await capture('discover');
    await tester.tap(find.text('Tìm kiếm'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'George Orwell');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await capture('search');
    await tester.tap(find.text('Tủ sách'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đang đọc'));
    await tester.pumpAndSettle();
    await capture('bookshelf');
    await tester.tap(find.text('Cá nhân').last);
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/images/default_avatar.png'),
        tester.element(find.byType(MainShell)),
      ),
    );
    await tester.pumpAndSettle();
    await capture('profile');
    await tester.tap(find.text('Tủ sách').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cập nhật').first);
    await tester.pumpAndSettle();
    await capture('reading-progress');
    Navigator.pop(tester.element(find.text('Lưu tiến độ')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          home: NoteEditorPage(
            service: shelf,
            saved: shelf.bookById(catalog.first.id)!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture('book-note');
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          home: BookDetailPage(
            book: catalog.first,
            service: search,
            onAddToShelf: shelf.addBook,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture('book-detail');
    await tester.ensureVisible(find.text('Mở trên Open Library'));
    await tester.pumpAndSettle();
    await capture('book-detail-metadata');
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          home: EditionsPage(workId: catalog.first.id, service: search),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture('editions');
    debugDisableShadows = true;
  }, skip: !const bool.fromEnvironment('CAPTURE_AUTH'));
}

// Screenshot fixtures use local covers; production SearchPage uses the public API.
class _PreviewSearch extends OpenLibraryService {
  _PreviewSearch(this.catalog);
  final List<Book> catalog;
  // Edition metadata comes from the verified catalog; offline captures show the fallback cover.
  @override
  Future<Book> getBookDetails(Book book) async =>
      book.withEdition(book.selectedEdition!);
  @override
  Future<EditionPageResult> getEditions(
    String workId, {
    int page = 1,
    int limit = 20,
  }) async => EditionPageResult(
    editions: [
      catalog.firstWhere((book) => book.id == workId).selectedEdition!,
    ],
    total: 1,
    hasMore: false,
  );
  @override
  Future<BookSearchResult> searchBooks({
    required String query,
    String? language,
    BookSort sort = BookSort.relevance,
    int page = 1,
    int limit = 20,
  }) async {
    final books = catalog
        .where(
          (book) => '${book.title} ${book.authorLabel}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    return BookSearchResult(books: books, total: books.length, hasMore: false);
  }
}
