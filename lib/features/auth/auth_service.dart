import 'package:flutter/foundation.dart';

import '../profile/models/user_profile.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Demo authentication only. Accounts and sessions disappear on app restart.
class AuthService extends ChangeNotifier {
  static const demoEmail = 'demo@example.com';
  static const demoPassword = 'Demo1234';
  static const minimumPasswordLength = 8;

  // shortcut: demo credentials live only in memory; replace with a backend before production.
  final _accounts = <String, ({UserProfile user, String password})>{
    demoEmail: (
      user: const UserProfile(
        id: 'demo-user',
        displayName: 'Nghĩa',
        email: demoEmail,
      ),
      password: demoPassword,
    ),
  };

  UserProfile? _currentUser;
  UserProfile? get currentUser => _currentUser;

  static String? validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Vui lòng nhập email';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Email chưa hợp lệ';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (value.length < minimumPasswordLength) {
      return 'Mật khẩu cần ít nhất $minimumPasswordLength ký tự';
    }
    return null;
  }

  static String _normalizeEmail(String email) {
    final error = validateEmail(email);
    if (error != null) throw AuthException(error);
    return email.trim().toLowerCase();
  }

  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    if (password.isEmpty) {
      throw const AuthException('Vui lòng nhập mật khẩu');
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final account = _accounts[normalizedEmail];
    if (account == null || account.password != password) {
      throw const AuthException('Email hoặc mật khẩu không đúng');
    }
    _currentUser = account.user;
    notifyListeners();
    return account.user;
  }

  Future<void> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    if (displayName.trim().isEmpty) {
      throw const AuthException('Vui lòng nhập tên hiển thị');
    }
    final normalizedEmail = _normalizeEmail(email);
    final passwordError = validatePassword(password);
    if (passwordError != null) throw AuthException(passwordError);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (_accounts.containsKey(normalizedEmail)) {
      throw const AuthException('Email này đã được đăng ký');
    }
    _accounts[normalizedEmail] = (
      user: UserProfile(
        id: 'demo-email:$normalizedEmail',
        displayName: displayName.trim(),
        email: normalizedEmail,
      ),
      password: password,
    );
  }

  Future<void> sendPasswordReset({required String email}) async {
    _normalizeEmail(email);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    // No email is sent and no password changes in this demo.
  }

  /// Demo account changes last only until this service is disposed.
  Future<UserProfile> updateProfile({
    required String displayName,
    required String email,
  }) async {
    final current = _currentUser;
    if (current == null) throw const AuthException('Vui lòng đăng nhập lại');
    final name = displayName.trim();
    if (name.isEmpty) throw const AuthException('Vui lòng nhập tên hiển thị');
    final normalizedEmail = _normalizeEmail(email);
    final existing = _accounts[normalizedEmail];
    if (existing != null && existing.user.id != current.id) {
      throw const AuthException('Email này đã được đăng ký');
    }
    final account = _accounts[current.email];
    if (account == null) {
      throw const AuthException('Tài khoản không còn tồn tại');
    }
    final updated = UserProfile(
      id: current.id,
      displayName: name,
      email: normalizedEmail,
      avatarPath: current.avatarPath,
    );
    _accounts.remove(current.email);
    _accounts[normalizedEmail] = (user: updated, password: account.password);
    _currentUser = updated;
    notifyListeners();
    return updated;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final current = _currentUser;
    if (current == null) throw const AuthException('Vui lòng đăng nhập lại');
    final account = _accounts[current.email];
    if (account == null || account.password != currentPassword) {
      throw const AuthException('Mật khẩu hiện tại không đúng');
    }
    final error = validatePassword(newPassword);
    if (error != null) throw AuthException(error);
    if (newPassword == currentPassword) {
      throw const AuthException('Mật khẩu mới phải khác mật khẩu hiện tại');
    }
    _accounts[current.email] = (user: account.user, password: newPassword);
  }

  Future<void> signOut() async {
    _currentUser = null;
    notifyListeners();
  }
}
