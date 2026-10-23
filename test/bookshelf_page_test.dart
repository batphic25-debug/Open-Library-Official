import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart' show newDatabaseFactoryMemory;
import 'package:open_library_client/core/theme/app_theme.dart';
import 'package:open_library_client/features/auth/auth_service.dart';
import 'package:open_library_client/features/books/models/book.dart';
import 'package:open_library_client/features/books/services/open_library_service.dart';
import 'package:open_library_client/features/books/services/sample_books.dart';
import 'package:open_library_client/features/bookshelf/bookshelf_service.dart';
import 'package:open_library_client/features/bookshelf/bookshelf_page.dart';
import 'package:open_library_client/features/bookshelf/reading_progress_sheet.dart';
import 'package:open_library_client/features/bookshelf/note_editor_page.dart';
import 'package:open_library_client/features/bookshelf/models/saved_book.dart';
import 'package:open_library_client/features/navigation/main_shell.dart';
import 'package:open_library_client/features/books/book_detail_page.dart';

import 'bookshelf_service_test.dart' show book, unknown;

class FailingShelf extends BookshelfService {
  FailingShelf()
    : super(
        userId: 'demo-user',
        openDatabase: () => newDatabaseFactoryMemory().openDatabase('failures'),
      );
  bool fail = false;
  @override
  Future<void> saveNote(String id, String body) async {
    if (fail) throw StateError('Disk full');
    await super.saveNote(id, body);
  }

  @override
  Future<void> updateProgress(
    String id,
    int pagesRead, {
    bool completed = false,
  }) async {
    if (fail) throw StateError('Disk full');
    await super.updateProgress(id, pagesRead, completed: completed);
  }
}

class OfflineLibrary extends OpenLibraryService {
  @override
  Future<Book> getBookDetails(Book value) async => value;
}

Future<void> pumpWrite(WidgetTester tester, Future<void> operation) async {
  await tester.pumpAndSettle();
  await operation;
}

void main() {
  late BookshelfService shelf;
  late OfflineLibrary library;
  void shelfTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      shelf = BookshelfService(
        userId: 'demo-user',
        openDatabase: () => newDatabaseFactoryMemory().openDatabase('test'),
      );
      library = OfflineLibrary();
      addTearDown(() {
        shelf.dispose();
        library.dispose();
      });
      await body(tester);
    });
  }

  Future<void> seed(WidgetTester tester, [Book value = book]) async {
    final operation = shelf.addBook(value);
    await tester.pumpAndSettle();
    await operation;
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label).last);
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );
  Widget progressHost(SavedBook saved) => MaterialApp(
    key: UniqueKey(),
    theme: AppTheme.light,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => ReadingProgressSheet(service: shelf, saved: saved),
          ),
          child: const Text('Open progress'),
        ),
      ),
    ),
  );
  Widget page({VoidCallback? explore, ValueChanged<Book>? onBook}) =>
      BookshelfPage(
        service: shelf,
        libraryService: library,
        onBookTap: onBook ?? (_) {},
        onExplore: explore ?? () {},
      );

  shelfTest(
    'loading, failed load and retry show empty shelf with explore action',
    (tester) async {
      shelf.dispose();
      final gate = Completer<void>();
      var fail = true;
      var explored = false;
      shelf = BookshelfService(
        userId: 'demo-user',
        openDatabase: () async {
          await gate.future;
          if (fail) throw StateError('Offline');
          return newDatabaseFactoryMemory().openDatabase('retry');
        },
      );
      unawaited(shelf.loadBooks());
      await tester.pumpWidget(host(page(explore: () => explored = true)));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);
      fail = false;
      await tap(tester, 'Thử lại');
      expect(find.text('Chưa có sách trong nhóm muốn đọc.'), findsOneWidget);
      await tap(tester, 'Khám phá sách');
      expect(explored, isTrue);
    },
  );
  shelfTest(
    'progress validates integers and bounds, completes known and unknown books',
    (tester) async {
      await seed(tester);
      await tester.pumpWidget(progressHost(shelf.books.single));
      await tap(tester, 'Open progress');
      for (final value in ['-1', '101', '1.5']) {
        await tester.enterText(find.byType(TextFormField), value);
        await tap(tester, 'Lưu tiến độ');
        expect(shelf.books.single.pagesRead, 0);
        expect(
          find.textContaining(
            value == '101' ? 'Không được vượt' : 'Nhập số nguyên',
          ),
          findsOneWidget,
        );
      }
      await tester.enterText(find.byType(TextFormField), '100');
      await tester.pump();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      await tap(tester, 'Lưu tiến độ');
      expect(shelf.books.single.status, ReadingStatus.read);
      await seed(tester, unknown);
      await tester.pumpWidget(progressHost(shelf.bookById(unknown.id)!));
      await tap(tester, 'Open progress');
      await tester.enterText(find.byType(TextFormField), '500');
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tap(tester, 'Đánh dấu Đã đọc');
      await tap(tester, 'Lưu tiến độ');
      expect(shelf.bookById(unknown.id)!.pagesRead, 500);
      expect(shelf.bookById(unknown.id)!.status, ReadingStatus.read);
    },
  );
  shelfTest(
    'notes save, reopen, guard unsaved navigation, discard and delete',
    (tester) async {
      await seed(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => NoteEditorPage(
                      service: shelf,
                      saved: shelf.books.single,
                    ),
                  ),
                ),
                child: const Text('Open note'),
              ),
            ),
          ),
        ),
      );
      await tap(tester, 'Open note');
      await tester.enterText(find.byType(TextField), 'First note');
      await tap(tester, 'Lưu ghi chú');
      expect(shelf.notes.single.body, 'First note');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, 'Open note');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'First note',
      );
      await tester.enterText(find.byType(TextField), 'Unsaved');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Giữ thay đổi ghi chú?'), findsOneWidget);
      await tap(tester, 'Viết tiếp');
      expect(find.byType(NoteEditorPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, 'Bỏ thay đổi');
      expect(find.byType(NoteEditorPage), findsNothing);
      expect(shelf.notes.single.body, 'First note');
      await tap(tester, 'Open note');
      await tester.enterText(find.byType(TextField), 'Saved on leave');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, 'Lưu và rời trang');
      expect(shelf.notes.single.body, 'Saved on leave');
      expect(find.byType(NoteEditorPage), findsNothing);
      await tap(tester, 'Open note');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tap(tester, 'Xóa ghi chú');
      await tap(tester, 'Xóa');
      expect(shelf.notes, isEmpty);
    },
  );
  shelfTest('failed note and progress writes keep input and allow retry', (
    tester,
  ) async {
    shelf.dispose();
    final failing = FailingShelf();
    shelf = failing;
    await seed(tester);
    failing.fail = true;
    await tester.pumpWidget(
      host(NoteEditorPage(service: shelf, saved: shelf.books.single)),
    );
    await tester.enterText(find.byType(TextField), 'Keep my draft');
    await tap(tester, 'Lưu ghi chú');
    expect(find.textContaining('Chưa lưu được ghi chú'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Keep my draft',
    );
    expect(shelf.notes, isEmpty);
    failing.fail = false;
    await tap(tester, 'Lưu ghi chú');
    expect(shelf.notes.single.body, 'Keep my draft');
    failing.fail = true;
    await tester.pumpWidget(progressHost(shelf.books.single));
    await tap(tester, 'Open progress');
    await tester.enterText(find.byType(TextFormField), '65');
    await tap(tester, 'Lưu tiến độ');
    expect(find.textContaining('Chưa lưu được tiến độ'), findsOneWidget);
    expect(shelf.books.single.pagesRead, 0);
    failing.fail = false;
    await tap(tester, 'Lưu tiến độ');
    expect(shelf.books.single.pagesRead, 65);
  });
  shelfTest(
    'long book and note remain usable on narrow screens with keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await seed(
        tester,
        Book(
          id: book.id,
          title: List.filled(15, 'Một cuốn sách rất dài').join(' '),
          authors: ['Tên tác giả dài'],
        ),
      );
      await pumpWrite(
        tester,
        shelf.saveNote(
          book.id,
          List.filled(30, 'Một điều muốn nhớ.').join('\n'),
        ),
      );
      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        host(NoteEditorPage(service: shelf, saved: shelf.books.single)),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Lưu ghi chú'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        host(ReadingProgressSheet(service: shelf, saved: shelf.books.single)),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Lưu tiến độ'));
      expect(tester.takeException(), isNull);
    },
  );
  shelfTest('bottom navigation hides down and returns up', (tester) async {
    await tester.runAsync(SampleBooks.load);
    final auth = AuthService();
    addTearDown(auth.dispose);
    await tester.runAsync(
      () => auth.signIn(
        email: AuthService.demoEmail,
        password: AuthService.demoPassword,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MainShell(
          authService: auth,
          service: library,
          bookshelfService: shelf,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final destination = find.text('Cá nhân').hitTestable();
    expect(destination, findsOneWidget);
    final list = find.byType(Scrollable).first;
    await tester.drag(list, const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(destination, findsNothing);
    await tester.drag(list, const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(destination, findsOneWidget);
    await tester.tap(find.text('Tủ sách'));
    await tester.pumpAndSettle();
    expect(destination, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  shelfTest('all selected navigation tabs share the discover dark colors', (
    tester,
  ) async {
    await tester.runAsync(SampleBooks.load);
    final auth = AuthService();
    addTearDown(auth.dispose);
    await tester.runAsync(
      () => auth.signIn(
        email: AuthService.demoEmail,
        password: AuthService.demoPassword,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MainShell(
          authService: auth,
          service: library,
          bookshelfService: shelf,
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final label in ['Khám phá', 'Tìm kiếm', 'Tủ sách', 'Cá nhân']) {
      final destination = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      );
      await tester.tap(destination);
      await tester.pumpAndSettle();
      final theme = NavigationBarTheme.of(
        tester.element(find.byType(NavigationBar)),
      );
      expect(theme.backgroundColor, const Color(0xFF18263B));
      expect(theme.indicatorColor, const Color(0xFF244571));
      expect(
        theme.iconTheme!.resolve({WidgetState.selected})!.color,
        const Color(0xFFFFC45A),
      );
      expect(
        theme.labelTextStyle!.resolve({WidgetState.selected})!.color,
        const Color(0xFFFFC45A),
      );
      expect(tester.takeException(), isNull);
    }
  });

  shelfTest(
    'detail adds once; shelf progress updates Discover; delete removes note',
    (tester) async {
      await tester.runAsync(SampleBooks.load);
      final auth = AuthService();
      addTearDown(auth.dispose);
      await tester.runAsync(
        () => auth.signIn(
          email: AuthService.demoEmail,
          password: AuthService.demoPassword,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MainShell(
            authService: auth,
            service: library,
            bookshelfService: shelf,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(MainShell));
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => BookDetailPage(
            book: book,
            service: library,
            onAddToShelf: shelf.addBook,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'Thêm vào tủ sách');
      expect(shelf.books, hasLength(1));
      await tap(tester, 'Thêm vào tủ sách');
      expect(shelf.books, hasLength(1));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, 'Tủ sách');
      await tap(tester, 'Cập nhật');
      await tester.enterText(find.byType(TextFormField), '65');
      await tap(tester, 'Lưu tiến độ');
      await tap(tester, 'Đang đọc');
      expect(find.text('65%'), findsOneWidget);
      await tap(tester, 'Khám phá');
      expect(find.text('65%'), findsOneWidget);
      await tap(tester, 'Cập nhật');
      await tester.enterText(find.byType(TextFormField), '70');
      await tap(tester, 'Lưu tiến độ');
      expect(find.text('70%'), findsOneWidget);
      expect(shelf.books.single.pagesRead, 70);
      await tap(tester, 'Tủ sách');
      await pumpWrite(tester, shelf.saveNote(book.id, 'Delete with book'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tùy chọn Book one'));
      await tester.pumpAndSettle();
      await tap(tester, 'Xóa khỏi tủ sách');
      await tap(tester, 'Xóa');
      expect(shelf.books, isEmpty);
      expect(shelf.notes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
