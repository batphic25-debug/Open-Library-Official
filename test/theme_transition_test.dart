import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_library_client/app.dart';
import 'package:open_library_client/core/theme/app_theme.dart';
import 'package:open_library_client/core/theme/appearance_store.dart';
import 'package:open_library_client/features/auth/auth_service.dart';
import 'package:open_library_client/features/auth/login_page.dart';
import 'package:open_library_client/features/books/book_detail_page.dart';
import 'package:open_library_client/features/books/services/offline_book_library.dart';
import 'package:open_library_client/features/books/services/sample_books.dart';
import 'package:open_library_client/features/bookshelf/bookshelf_service.dart';
import 'package:open_library_client/features/bookshelf/bookshelf_page.dart';
import 'package:open_library_client/features/discovers/discover_page.dart';
import 'package:open_library_client/features/navigation/main_shell.dart';
import 'package:open_library_client/features/profile/profile_page.dart';
import 'package:open_library_client/features/profile/settings_service.dart';
import 'package:open_library_client/features/search/search_page.dart';
import 'package:sembast/sembast_memory.dart' show newDatabaseFactoryMemory;

void main() {
  test('light and dark themes interpolate without TextStyle errors', () {
    expect(
      () => ThemeData.lerp(AppTheme.light, AppTheme.dark, 0.5),
      returnsNormally,
    );
    expect(
      () => ThemeData.lerp(AppTheme.dark, AppTheme.light, 0.5),
      returnsNormally,
    );
  });

  testWidgets('changing appearance animates without TextStyle errors', (
    tester,
  ) async {
    final auth = AuthService();
    addTearDown(auth.dispose);
    await tester.runAsync(SampleBooks.load);
    await tester.runAsync(
      () => auth.signIn(
        email: AuthService.demoEmail,
        password: AuthService.demoPassword,
      ),
    );
    final databaseFactory = newDatabaseFactoryMemory();
    late SettingsService settings;
    await tester.pumpWidget(
      OpenLibraryApp(
        authService: auth,
        appearanceStore: AppearanceStore(
          openDatabase: () => databaseFactory.openDatabase('appearance'),
        ),
        bookshelfFactory: (id) => BookshelfService(
          userId: id,
          openDatabase: () => databaseFactory.openDatabase('shelf-$id'),
        ),
        settingsFactory: (id) => settings = SettingsService(
          userId: id,
          openDatabase: () => databaseFactory.openDatabase('settings-$id'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => settings.update(darkMode: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    for (final page in [
      find.byType(DiscoverPage, skipOffstage: false),
      find.byType(SearchPage, skipOffstage: false),
      find.byType(BookshelfPage, skipOffstage: false),
      find.byType(ProfilePage, skipOffstage: false),
    ]) {
      expect(Theme.of(tester.element(page)).brightness, Brightness.dark);
    }

    for (final label in ['Tìm kiếm', 'Tủ sách', 'Cá nhân', 'Khám phá']) {
      await tester.tap(find.text(label).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull, reason: 'After selecting $label');
      await tester.pumpAndSettle();
    }

    await tester.runAsync(() => settings.update(darkMode: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    for (final page in [
      find.byType(DiscoverPage, skipOffstage: false),
      find.byType(SearchPage, skipOffstage: false),
      find.byType(BookshelfPage, skipOffstage: false),
      find.byType(ProfilePage, skipOffstage: false),
    ]) {
      expect(Theme.of(tester.element(page)).brightness, Brightness.light);
    }
  });

  testWidgets('saved dark appearance reaches login, home, and nested routes', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final databaseFactory = newDatabaseFactoryMemory();
    final appearance = AppearanceStore(
      openDatabase: () => databaseFactory.openDatabase('appearance'),
    );
    await tester.runAsync(() => appearance.save(true));
    expect(await tester.runAsync(appearance.load), isTrue);
    final auth = AuthService();
    addTearDown(auth.dispose);
    final books = await tester.runAsync(SampleBooks.load);
    final seedSettings = SettingsService(
      userId: 'demo-user',
      openDatabase: () => databaseFactory.openDatabase('settings-demo-user'),
    );
    await tester.runAsync(() => seedSettings.update(darkMode: true));
    await tester.runAsync(seedSettings.close);

    await tester.pumpWidget(
      OpenLibraryApp(
        authService: auth,
        appearanceStore: appearance,
        initialDarkMode: await tester.runAsync(appearance.load) ?? false,
        bookshelfFactory: (id) => BookshelfService(
          userId: id,
          openDatabase: () => databaseFactory.openDatabase('shelf-$id'),
        ),
        settingsFactory: (id) => SettingsService(
          userId: id,
          openDatabase: () => databaseFactory.openDatabase('settings-$id'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(LoginPage))).brightness,
      Brightness.dark,
    );
    await tester.runAsync(
      () => auth.signIn(
        email: AuthService.demoEmail,
        password: AuthService.demoPassword,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(MainShell))).brightness,
      Brightness.dark,
    );

    final navigator = Navigator.of(tester.element(find.byType(MainShell)));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            BookDetailPage(book: books!.firstWhere(OfflineBookLibrary.hasBook)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(BookDetailPage))).brightness,
      Brightness.dark,
    );
  });
}
