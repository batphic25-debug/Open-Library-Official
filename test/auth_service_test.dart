import 'package:flutter_test/flutter_test.dart';
import 'package:open_library_client/features/auth/auth_service.dart';

void main() {
  late AuthService auth;
  setUp(() => auth = AuthService());
  tearDown(() => auth.dispose());

  test(
    'demo login normalizes email and notifies on login and logout',
    () async {
      var notifications = 0;
      auth.addListener(() => notifications++);
      expect(auth.currentUser, isNull);
      final user = await auth.signIn(
        email: ' DEMO@EXAMPLE.COM ',
        password: AuthService.demoPassword,
      );
      expect(user.email, AuthService.demoEmail);
      expect(user.displayName, 'Nghĩa');
      expect(auth.currentUser, same(user));
      await auth.signOut();
      expect(auth.currentUser, isNull);
      expect(notifications, 2);
    },
  );

  test('wrong password and unknown account do not create a session', () async {
    for (final email in [AuthService.demoEmail, 'unknown@example.com']) {
      await expectLater(
        auth.signIn(email: email, password: 'wrong-password'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Email hoặc mật khẩu không đúng',
          ),
        ),
      );
      expect(auth.currentUser, isNull);
    }
  });

  test(
    'registration allows later login but does not sign in automatically',
    () async {
      await auth.signUp(
        displayName: ' Bạn đọc ',
        email: ' READER@example.com ',
        password: 'Reader123',
      );
      expect(auth.currentUser, isNull);
      final user = await auth.signIn(
        email: 'reader@example.com',
        password: 'Reader123',
      );
      expect(user.displayName, 'Bạn đọc');
      expect(user.id, isNotEmpty);
      await auth.signOut();
      await auth.signIn(email: user.email, password: 'Reader123');
      expect(auth.currentUser?.id, user.id);
    },
  );

  test(
    'duplicate registration cannot overwrite existing credentials',
    () async {
      await expectLater(
        auth.signUp(
          displayName: 'Other',
          email: ' DEMO@EXAMPLE.COM ',
          password: 'Other1234',
        ),
        throwsA(isA<AuthException>()),
      );
      final user = await auth.signIn(
        email: AuthService.demoEmail,
        password: AuthService.demoPassword,
      );
      expect(user.displayName, 'Nghĩa');
    },
  );

  test('service validates inputs even without a form', () async {
    for (final email in ['', 'invalid', 'a b@example.com']) {
      await expectLater(
        auth.signIn(email: email, password: '12345678'),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        auth.sendPasswordReset(email: email),
        throwsA(isA<AuthException>()),
      );
    }
    await expectLater(
      auth.signUp(
        displayName: ' ',
        email: 'reader@example.com',
        password: '12345678',
      ),
      throwsA(isA<AuthException>()),
    );
    await expectLater(
      auth.signUp(
        displayName: 'Reader',
        email: 'reader@example.com',
        password: '1234567',
      ),
      throwsA(isA<AuthException>()),
    );
    await expectLater(
      auth.signIn(email: AuthService.demoEmail, password: ''),
      throwsA(isA<AuthException>()),
    );
    expect(auth.currentUser, isNull);
  });

  test(
    'reset is a simulation and does not change credentials or session',
    () async {
      await auth.sendPasswordReset(email: AuthService.demoEmail);
      await auth.sendPasswordReset(email: 'unknown@example.com');
      expect(auth.currentUser, isNull);
      await auth.signIn(
        email: AuthService.demoEmail,
        password: AuthService.demoPassword,
      );
      expect(auth.currentUser?.email, AuthService.demoEmail);
    },
  );

  test(
    'new service has no previously registered accounts or session',
    () async {
      await auth.signUp(
        displayName: 'Reader',
        email: 'reader@example.com',
        password: '12345678',
      );
      final restarted = AuthService();
      addTearDown(restarted.dispose);
      expect(restarted.currentUser, isNull);
      await expectLater(
        restarted.signIn(email: 'reader@example.com', password: '12345678'),
        throwsA(isA<AuthException>()),
      );
    },
  );

  test(
    'profile edits preserve account identity and reject duplicate email',
    () async {
      await auth.signUp(
        displayName: 'Reader',
        email: 'reader@example.com',
        password: 'Reader123',
      );
      await auth.signIn(
        email: AuthService.demoEmail,
        password: AuthService.demoPassword,
      );
      final id = auth.currentUser!.id;
      await expectLater(
        auth.updateProfile(
          displayName: 'Nghĩa mới',
          email: 'reader@example.com',
        ),
        throwsA(isA<AuthException>()),
      );
      expect(auth.currentUser!.email, AuthService.demoEmail);
      await auth.updateProfile(
        displayName: 'Nghĩa mới',
        email: 'NEW@example.com',
      );
      expect(auth.currentUser!.id, id);
      expect(auth.currentUser!.email, 'new@example.com');
      await auth.signOut();
      await expectLater(
        auth.signIn(
          email: AuthService.demoEmail,
          password: AuthService.demoPassword,
        ),
        throwsA(isA<AuthException>()),
      );
      await auth.signIn(
        email: 'new@example.com',
        password: AuthService.demoPassword,
      );
      expect(auth.currentUser!.displayName, 'Nghĩa mới');
    },
  );

  test('change password checks current credential and updates login', () async {
    await auth.signIn(
      email: AuthService.demoEmail,
      password: AuthService.demoPassword,
    );
    await expectLater(
      auth.changePassword(currentPassword: 'wrong', newPassword: 'NewPass123'),
      throwsA(isA<AuthException>()),
    );
    await auth.changePassword(
      currentPassword: AuthService.demoPassword,
      newPassword: 'NewPass123',
    );
    await auth.signOut();
    await expectLater(
      auth.signIn(
        email: AuthService.demoEmail,
        password: AuthService.demoPassword,
      ),
      throwsA(isA<AuthException>()),
    );
    await auth.signIn(email: AuthService.demoEmail, password: 'NewPass123');
    expect(auth.currentUser, isNotNull);
  });
}
