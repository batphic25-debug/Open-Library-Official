// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sembast/sembast_memory.dart' show newDatabaseFactoryMemory;
import 'package:open_library_client/features/bookshelf/bookshelf_service.dart';
import 'package:open_library_client/features/books/services/sample_books.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_library_client/app.dart';
import 'package:open_library_client/features/auth/auth_service.dart';
import 'package:open_library_client/features/auth/forgot_password_page.dart';
import 'package:open_library_client/features/auth/login_page.dart';
import 'package:open_library_client/features/auth/register_page.dart';
import 'package:open_library_client/features/navigation/main_shell.dart';
import 'package:open_library_client/features/profile/models/user_profile.dart';
import 'package:open_library_client/features/profile/settings_service.dart';
import 'package:open_library_client/features/profile/edit_profile_page.dart';

class TrackingAuthService extends AuthService {
  int signInCalls = 0;
  bool fail = false;

  @override
  Future<Never> sendPasswordReset({required String email}) async {
    throw const AuthException('Không thể gửi yêu cầu thử');
  }

  @override
  Future<Never> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    throw const AuthException('Không thể tạo tài khoản thử');
  }

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    if (fail) throw StateError('Simulated connection error');
    return super.signIn(email: email, password: password);
  }
}

Future<void> start(
  WidgetTester tester,
  AuthService auth, {
  void Function(SettingsService)? onSettings,
}) async {
  await tester.runAsync(SampleBooks.load);
  // Keep auth-flow tests and still captures independent of looping decoration.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  tester.view.physicalSize = const Size(430, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    OpenLibraryApp(
      authService: auth,
      bookshelfFactory: (id) => BookshelfService(
        userId: id,
        openDatabase: () => newDatabaseFactoryMemory().openDatabase(id),
      ),
      settingsFactory: (id) {
        final settings = SettingsService(
          userId: id,
          openDatabase: () =>
              newDatabaseFactoryMemory().openDatabase('settings-$id'),
        );
        onSettings?.call(settings);
        return settings;
      },
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('discover avatar follows account photo and reset', (
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
    SettingsService? settings;
    await start(tester, auth, onSettings: (value) => settings = value);
    final profileButton = find.byTooltip('Mở trang Cá nhân của Nghĩa');
    expect(
      find.descendant(of: profileButton, matching: find.text('N')),
      findsOneWidget,
    );

    final image = (await rootBundle.load('assets/images/default_avatar.png'))
        .buffer
        .asUint8List();
    await tester.runAsync(() => settings!.updateAvatar(image));
    await tester.pumpAndSettle();
    final avatar = find.descendant(
      of: profileButton,
      matching: find.byType(CircleAvatar),
    );
    expect(
      tester.widget<CircleAvatar>(avatar).backgroundImage,
      isA<MemoryImage>(),
    );

    await tester.runAsync(() => settings!.updateAvatar(null));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: profileButton, matching: find.text('N')),
      findsOneWidget,
    );
  });

  testWidgets('chosen avatar appears immediately and can be reset', (
    tester,
  ) async {
    final auth = AuthService();
    addTearDown(auth.dispose);
    final settings = SettingsService(
      userId: 'demo-user',
      openDatabase: () =>
          newDatabaseFactoryMemory().openDatabase('avatar-test'),
    );
    addTearDown(settings.dispose);
    await tester.runAsync(
      () => auth.signIn(
        email: AuthService.demoEmail,
        password: AuthService.demoPassword,
      ),
    );
    final image = (await rootBundle.load('assets/images/default_avatar.png'))
        .buffer
        .asUint8List();
    await tester.pumpWidget(
      MaterialApp(
        home: EditProfilePage(
          authService: auth,
          settings: settings,
          pickImage: () async => image,
        ),
      ),
    );
    await tapVisible(tester, find.text('Thay ảnh đại diện'));
    expect(settings.avatarBytes, isNotNull);
    expect(
      tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundImage,
      isA<MemoryImage>(),
    );
    expect(find.text('Dùng ảnh mặc định'), findsOneWidget);
    await tapVisible(tester, find.text('Dùng ảnh mặc định'));
    expect(settings.avatarBytes, isNull);
    expect(
      tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundImage,
      isA<AssetImage>(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile and account form remain usable on a narrow screen', (
    tester,
  ) async {
    final auth = AuthService();
    addTearDown(auth.dispose);
    await start(tester, auth);
    await tester.enterText(
      find.byType(TextFormField).first,
      AuthService.demoEmail,
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      AuthService.demoPassword,
    );
    await tapVisible(tester, find.byType(FilledButton));
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byIcon(Icons.person_outline));
    await tester.scrollUntilVisible(find.text('Đăng xuất'), 200);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Sửa hồ sơ'), -200);
    await tapVisible(tester, find.text('Sửa hồ sơ'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Lưu thay đổi'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'profile form saves identity and password form rejects wrong old password',
    (tester) async {
      final auth = AuthService();
      addTearDown(auth.dispose);
      await start(tester, auth);
      await tester.enterText(
        find.byType(TextFormField).first,
        AuthService.demoEmail,
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        AuthService.demoPassword,
      );
      await tapVisible(tester, find.byType(FilledButton));
      await tapVisible(tester, find.byIcon(Icons.person_outline));
      await tapVisible(tester, find.text('Sửa hồ sơ'));
      await tester.enterText(find.byType(TextFormField).first, 'Tên mới');
      await tester.enterText(
        find.byType(TextFormField).last,
        'new@example.com',
      );
      await tapVisible(tester, find.text('Lưu thay đổi'));
      expect(find.text('Tên mới'), findsOneWidget);
      expect(find.text('new@example.com'), findsOneWidget);
      await tapVisible(tester, find.text('Đổi mật khẩu').first);
      await tester.enterText(find.byType(TextFormField).at(0), 'wrong');
      await tester.enterText(find.byType(TextFormField).at(1), 'NewPass123');
      await tester.enterText(find.byType(TextFormField).at(2), 'NewPass123');
      await tapVisible(tester, find.byType(FilledButton));
      expect(find.text('Mật khẩu hiện tại không đúng'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        AuthService.demoPassword,
      );
      await tapVisible(tester, find.byType(FilledButton));
      await tapVisible(tester, find.text('Đăng xuất'));
      expect(find.byType(LoginPage), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        'new@example.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'NewPass123');
      await tapVisible(tester, find.byType(FilledButton));
      expect(find.byType(MainShell), findsOneWidget);
    },
  );

  testWidgets('profile opens bookshelf and applies saved appearance', (
    tester,
  ) async {
    final auth = AuthService();
    addTearDown(auth.dispose);
    await start(tester, auth);
    await tester.enterText(
      find.byType(TextFormField).first,
      AuthService.demoEmail,
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      AuthService.demoPassword,
    );
    await tapVisible(tester, find.byType(FilledButton));
    await tapVisible(tester, find.byIcon(Icons.person_outline));
    expect(find.text('Tủ sách của tôi'), findsOneWidget);
    await tapVisible(tester, find.text('Tủ sách của tôi'));
    expect(find.text('Muốn đọc'), findsOneWidget);
    await tapVisible(tester, find.text('Cá nhân').last);
    await tapVisible(tester, find.byTooltip('Cài đặt'));
    await tapVisible(tester, find.text('English'));
    expect(find.text('Settings'), findsOneWidget);
    await tapVisible(tester, find.text('Dark'));
    expect(
      Theme.of(tester.element(find.text('Settings'))).brightness,
      Brightness.dark,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('My bookshelf'), findsOneWidget);
    expect(find.text('Bookshelf'), findsOneWidget);
  });

  testWidgets('login validates fields and toggles password visibility', (
    tester,
  ) async {
    final auth = AuthService();
    addTearDown(auth.dispose);
    await start(tester, auth);
    await tapVisible(tester, find.byType(FilledButton));
    expect(find.text('Vui lòng nhập email'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'invalid');
    await tapVisible(tester, find.byType(FilledButton));
    expect(find.text('Email chưa hợp lệ'), findsOneWidget);
    await tapVisible(tester, find.byTooltip('Hiện mật khẩu'));
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isFalse,
    );
    expect(auth.currentUser, isNull);
  });

  testWidgets(
    'wrong credentials stay on login; double submit only calls once',
    (tester) async {
      final auth = TrackingAuthService();
      addTearDown(auth.dispose);
      await start(tester, auth);
      await tester.enterText(
        find.byType(TextFormField).first,
        AuthService.demoEmail,
      );
      await tester.enterText(find.byType(TextFormField).last, 'wrong');
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(auth.signInCalls, 1);
      expect(find.text('Email hoặc mật khẩu không đúng'), findsOneWidget);
      expect(find.byType(MainShell), findsNothing);
    },
  );

  testWidgets('logout clears session and protected navigation history', (
    tester,
  ) async {
    final auth = AuthService();
    addTearDown(auth.dispose);
    await start(tester, auth);
    await tester.enterText(
      find.byType(TextFormField).first,
      AuthService.demoEmail,
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      AuthService.demoPassword,
    );
    await tapVisible(tester, find.byType(FilledButton));
    expect(find.byType(MainShell), findsOneWidget);
    await tapVisible(tester, find.text('Tủ sách'));
    expect(find.text('Tủ sách của tôi'), findsOneWidget);
    expect(find.text('Chưa có sách trong nhóm muốn đọc.'), findsOneWidget);
    await tapVisible(tester, find.text('Khám phá'));
    expect(find.text('Hôm nay bạn\nmuốn đọc gì?'), findsOneWidget);
    await tapVisible(tester, find.byIcon(Icons.person_outline));
    expect(find.text('Nghĩa'), findsOneWidget);
    final navigator = Navigator.of(tester.element(find.byType(MainShell)));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: TextButton(
            onPressed: auth.signOut,
            child: const Text('Đăng xuất từ trang con'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng xuất từ trang con'));
    await tester.pumpAndSettle();
    expect(auth.currentUser, isNull);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Đăng xuất từ trang con'), findsNothing);
    expect(
      await Navigator.of(tester.element(find.byType(LoginPage))).maybePop(),
      isFalse,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MainShell), findsNothing);
  });

  testWidgets(
    'register checks confirmation, returns to login, and account works',
    (tester) async {
      final auth = AuthService();
      addTearDown(auth.dispose);
      await start(tester, auth);
      await tapVisible(tester, find.text('Đăng ký'));
      expect(find.byType(RegisterPage), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(0), 'Bạn đọc');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'reader@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'Reader123');
      await tester.enterText(find.byType(TextFormField).at(3), 'Other1234');
      await tapVisible(tester, find.byType(FilledButton));
      expect(find.text('Hai mật khẩu không khớp'), findsOneWidget);
      expect(auth.currentUser, isNull);
      await tester.enterText(find.byType(TextFormField).at(3), 'Reader123');
      await tapVisible(tester, find.byType(FilledButton));
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.textContaining('Đăng ký thành công!'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'reader@example.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'Reader123');
      await tapVisible(tester, find.byType(FilledButton));
      await tapVisible(tester, find.byIcon(Icons.person_outline));
      expect(find.text('Bạn đọc'), findsOneWidget);
      await tapVisible(tester, find.text('Đăng xuất'));
      expect(find.byType(LoginPage), findsOneWidget);
    },
  );

  testWidgets('reset validates email and clearly reports a simulation', (
    tester,
  ) async {
    final auth = AuthService();
    addTearDown(auth.dispose);
    await start(tester, auth);
    await tapVisible(tester, find.text('Quên mật khẩu?'));
    expect(find.byType(ForgotPasswordPage), findsOneWidget);
    await tapVisible(tester, find.byType(FilledButton));
    expect(find.text('Vui lòng nhập email'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'reader@example.com');
    await tapVisible(tester, find.byType(FilledButton));
    expect(find.textContaining('Không có email nào được gửi'), findsOneWidget);
    await tapVisible(tester, find.text('Quay lại đăng nhập'));
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('service failures appear and leave forms retryable', (
    tester,
  ) async {
    final auth = TrackingAuthService()..fail = true;
    addTearDown(auth.dispose);
    await start(tester, auth);
    await tester.enterText(
      find.byType(TextFormField).first,
      AuthService.demoEmail,
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      AuthService.demoPassword,
    );
    await tapVisible(tester, find.byType(FilledButton));
    expect(find.text('Không thể đăng nhập. Vui lòng thử lại.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tapVisible(tester, find.text('Đăng ký'));
    await tester.enterText(find.byType(TextFormField).at(0), 'Reader');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'reader@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'Reader123');
    await tester.enterText(find.byType(TextFormField).at(3), 'Reader123');
    await tapVisible(tester, find.byType(FilledButton));
    expect(find.text('Không thể tạo tài khoản thử'), findsOneWidget);
    await tapVisible(tester, find.text('Đăng nhập'));
    await tapVisible(tester, find.text('Quên mật khẩu?'));
    await tester.enterText(find.byType(TextFormField), 'reader@example.com');
    await tapVisible(tester, find.byType(FilledButton));
    expect(find.text('Không thể gửi yêu cầu thử'), findsOneWidget);
  });

  testWidgets('small screen, keyboard, and large text still allow submission', (
    tester,
  ) async {
    final auth = AuthService();
    addTearDown(auth.dispose);
    await start(tester, auth);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    for (final route in ['login', 'register', 'reset']) {
      if (route == 'register') await tapVisible(tester, find.text('Đăng ký'));
      if (route == 'reset') {
        await tapVisible(tester, find.text('Quên mật khẩu?'));
      }
      await tapVisible(tester, find.byType(FilledButton));
      expect(find.text('Vui lòng nhập email'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (route != 'login') {
        Navigator.of(tester.element(find.byType(FilledButton))).pop();
        await tester.pumpAndSettle();
      }
    }
  });
}
