import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_library_client/core/l10n/app_strings.dart';
import 'package:open_library_client/features/auth/auth_service.dart';
import 'package:open_library_client/features/books/book_detail_page.dart';
import 'package:open_library_client/features/books/data/sample_books.dart';
import 'package:open_library_client/features/books/models/book.dart';
import 'package:open_library_client/features/books/services/book_discussion_service.dart';
import 'package:open_library_client/features/discovers/widgets/category_selector.dart';
import 'package:open_library_client/features/profile/settings_service.dart';

import 'widget_test.dart' show start, tapVisible;

Widget localized(Widget child, {String language = 'en'}) => MaterialApp(
  locale: Locale(language),
  supportedLocales: AppStrings.supportedLocales,
  localizationsDelegates: const [
    AppStrings.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: child,
);

class _Discussion extends BookDiscussionService {
  @override
  Future<BookDiscussion> load(String bookId) async => BookDiscussion(
    comments: [
      BookComment(
        id: 'comment',
        userId: 'reader',
        displayName: 'Nguyễn An',
        body: 'Sách này hay quá!',
        createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
    ],
  );
}

void main() {
  testWidgets(
    'catalog introductions and credits follow the selected language',
    (tester) async {
      final books = (await tester.runAsync(SampleBooks.load))!;
      const en = AppStrings('en');
      const vi = AppStrings('vi');
      for (final book in books) {
        expect(
          en.text(book.description!),
          isNot(book.description),
          reason: '${book.title} needs an English introduction',
        );
        expect(vi.text(book.description!), book.description);
      }
      final book = books.first;
      await tester.pumpWidget(localized(BookDetailPage(book: book)));
      await tester.pumpAndSettle();
      expect(find.text(en.text(book.description!)), findsOneWidget);
      expect(find.text(book.description!), findsNothing);
      expect(find.text('Description source: Editorial team'), findsOneWidget);
      await tester.pumpWidget(
        localized(BookDetailPage(book: book), language: 'vi'),
      );
      await tester.pumpAndSettle();
      expect(find.text(book.description!), findsOneWidget);
      expect(find.text('Nguồn giới thiệu: Nhóm biên soạn'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('translations preserve arguments and translate service validation', () {
    const en = AppStrings('en');
    const vi = AppStrings('vi');
    expect(
      en.error(AuthService.validatePassword('short')!),
      'Your password must contain at least 8 characters',
    );
    expect(en.text('{0} sách', [1]), '1 book');
    expect(en.text('{0} sách', [2]), '2 books');
    expect(en.text('{0} sao: {1} lượt đánh giá', [1, 2]), '1 star: 2 ratings');
    expect(
      en.text('Đang trả lời {0}', ['Nguyễn {1}']),
      'Replying to Nguyễn {1}',
    );
    expect(vi.text('{0} sách', [2]), '2 sách');
    expect(en.error('An unknown server error'), 'An unknown server error');
  });

  testWidgets('profile language changes every tab, routes and auth screens', (
    tester,
  ) async {
    final auth = AuthService();
    addTearDown(auth.dispose);
    await tester.runAsync(
      () => auth.signIn(
        email: AuthService.demoEmail,
        password: AuthService.demoPassword,
      ),
    );
    late SettingsService settings;
    await start(tester, auth, onSettings: (value) => settings = value);
    await tapVisible(tester, find.text('Cá nhân').last);
    await tapVisible(tester, find.byTooltip('Cài đặt'));
    await tapVisible(tester, find.text('English'));
    expect(find.text('Settings'), findsOneWidget);
    expect(settings.language, 'en');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Bookshelf'));
    expect(find.text('Want to read'), findsOneWidget);
    expect(find.text('No books in want to read yet.'), findsOneWidget);
    await tapVisible(tester, find.text('Search').last);
    expect(find.text('Book title or author'), findsOneWidget);
    await tapVisible(tester, find.byTooltip('Filter by language'));
    expect(find.text('Vietnamese'), findsOneWidget);
    await tapVisible(
      tester,
      find.byWidgetPredicate(
        (widget) =>
            widget is CheckedPopupMenuItem<String> && widget.value == 'fre',
      ),
    );
    expect(find.text('French'), findsOneWidget);
    await tapVisible(tester, find.text('Explore'));
    expect(find.text('Top books'), findsOneWidget);
    expect(find.text('Books in the library'), findsOneWidget);
    expect(find.byTooltip("Open Nghĩa's profile"), findsOneWidget);
    await tapVisible(tester, find.text('Profile').last);
    await tapVisible(tester, find.byTooltip('Settings'));
    await tapVisible(tester, find.text('Vietnamese'));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Tủ sách').last);
    expect(find.text('Muốn đọc'), findsOneWidget);
    await tapVisible(tester, find.text('Cá nhân').last);
    await tapVisible(tester, find.byTooltip('Cài đặt'));
    await tapVisible(tester, find.text('English'));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Sign out'));
    expect(find.text('Welcome back to your bookshelf.'), findsOneWidget);
    await tapVisible(tester, find.byType(FilledButton));
    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
    await tapVisible(tester, find.text('Sign up'));
    expect(find.text('Create account'), findsOneWidget);
    await tapVisible(tester, find.byType(FilledButton));
    expect(find.text('Please enter a display name'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Forgot password?'));
    expect(find.text('Send request'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'detail, edition and discussion translate without changing content',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      const book = Book(
        id: '/works/OL17930368W',
        title: 'Tên sách giữ nguyên',
        authors: ['Tác giả giữ nguyên'],
        categories: ['Văn học'],
        description: 'Nội dung giới thiệu giữ nguyên.',
        selectedEdition: BookEdition(
          id: '/books/OL1M',
          workIds: ['/works/OL17930368W'],
          pages: 120,
          languages: ['vie', 'eng'],
        ),
      );
      final service = _Discussion();
      addTearDown(service.close);
      Widget detail() => BookDetailPage(
        book: book,
        userId: 'reader',
        displayName: 'Nguyễn An',
        discussionService: service,
      );
      await tester.pumpWidget(localized(detail()));
      await tester.pumpAndSettle();
      expect(find.text('Book details'), findsOneWidget);
      expect(find.text('Literature'), findsOneWidget);
      expect(find.text('120 pages'), findsOneWidget);
      expect(find.text('Vietnamese, English'), findsOneWidget);
      expect(find.text('Read book'), findsOneWidget);
      expect(find.text('Tên sách giữ nguyên'), findsWidgets);
      expect(find.text('Nội dung giới thiệu giữ nguyên.'), findsOneWidget);
      expect(find.text('Sách này hay quá!'), findsOneWidget);
      expect(find.text('2 minutes ago'), findsOneWidget);
      expect(find.text('Comments (1)'), findsOneWidget);
      expect(find.text('Reply'), findsOneWidget);
      await tester.pumpWidget(localized(detail(), language: 'vi'));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết sách'), findsOneWidget);
      expect(find.text('120 trang'), findsOneWidget);
      expect(find.text('Sách này hay quá!'), findsOneWidget);
      expect(find.text('Bình luận (1)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'translated category keeps its original filter value on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? selected;
      await tester.pumpWidget(
        localized(
          Scaffold(
            body: CategorySelector(
              categories: const ['Văn học', 'Khoa học viễn tưởng'],
              selected: null,
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Literature'));
      expect(selected, 'Văn học');
      expect(tester.takeException(), isNull);
    },
  );
}
