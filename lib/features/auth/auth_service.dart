/* quản lý tài khoản và xác thực người dùng */
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../profile/models/user_profile.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  AuthService({this.apiClient}) {
    apiClient?.onSessionExpired = () {
      _currentUser = null;
      notifyListeners();
    };
  }

  final ApiClient? apiClient;
  bool get canChangeEmail => apiClient == null;
  static const demoEmail = 'demo@example.com';
  static const demoPassword = 'Demo1234';
  static const minimumPasswordLength = 8;

  // Kept for injected preview/test services; the app uses apiClient by default.
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
    // kiem tra Email
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Vui lòng nhập email';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Email chưa hợp lệ';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    // Kiem tra mat khau
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (value.length < minimumPasswordLength) {
      return 'Mật khẩu cần ít nhất $minimumPasswordLength ký tự';
    }
    return null;
  }

  static String _normalizeEmail(String email) {
    // chuan hoa email
    final error = validateEmail(email);
    if (error != null) throw AuthException(error);
    return email.trim().toLowerCase();
  }

  Future<UserProfile> signIn({
    // Dang nhap
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    if (password.isEmpty) {
      throw const AuthException('Vui lòng nhập mật khẩu');
    }
    if (apiClient != null) {
      try {
        final user = UserProfile.fromJson(
          await apiClient!.login(normalizedEmail, password),
        );
        _currentUser = user;
        notifyListeners();
        return user;
      } on ApiException catch (error) {
        throw AuthException(error.message);
      }
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
    // Dang ki tai khoan
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
    if (apiClient != null) {
      try {
        await apiClient!.request(
          'POST',
          '/auth/register',
          authenticated: false,
          body: {
            'displayName': displayName.trim(),
            'email': normalizedEmail,
            'password': password,
          },
        );
        return;
      } on ApiException catch (error) {
        throw AuthException(error.message);
      }
    }
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

  // Ham quen mat khau
  Future<void> sendPasswordReset({required String email}) async {
    final normalizedEmail = _normalizeEmail(email);
    if (apiClient != null) {
      try {
        await apiClient!.request(
          'POST',
          '/auth/forgot-password',
          authenticated: false,
          body: {'email': normalizedEmail},
        );
        return;
      } on ApiException catch (error) {
        throw AuthException(error.message);
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    // No email is sent and no password changes in this demo.
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final error = validatePassword(newPassword);
    if (error != null) throw AuthException(error);
    if (token.trim().isEmpty) {
      throw const AuthException('Vui lòng nhập mã đặt lại.');
    }
    if (apiClient == null) {
      throw const AuthException('Bản xem trước không hỗ trợ đặt lại mật khẩu.');
    }
    try {
      await apiClient!.request(
        'POST',
        '/auth/reset-password',
        authenticated: false,
        body: {'token': token.trim(), 'newPassword': newPassword},
      );
    } on ApiException catch (failure) {
      throw AuthException(failure.message);
    }
  }

  Future<UserProfile> updateProfile({
    // Cap nhat thong tin ca nhan
    required String displayName,
    required String email,
  }) async {
    final current = _currentUser;
    if (current == null) throw const AuthException('Vui lòng đăng nhập lại');
    final name = displayName.trim();
    if (name.isEmpty) throw const AuthException('Vui lòng nhập tên hiển thị');
    final normalizedEmail = _normalizeEmail(email);
    if (apiClient != null) {
      if (normalizedEmail != current.email) {
        throw const AuthException('Chưa hỗ trợ đổi email.');
      }
      try {
        final updated = UserProfile.fromJson(
          await apiClient!.request('PATCH', '/me', body: {'displayName': name}),
        );
        _currentUser = updated;
        notifyListeners();
        return updated;
      } on ApiException catch (error) {
        throw AuthException(error.message);
      }
    }
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
    if (apiClient != null) {
      final error = validatePassword(newPassword);
      if (error != null) throw AuthException(error);
      try {
        await apiClient!.request(
          'POST',
          '/me/change-password',
          body: {
            'currentPassword': currentPassword,
            'newPassword': newPassword,
          },
        );
        await apiClient!.clearSession();
        _currentUser = null;
        notifyListeners();
        return;
      } on ApiException catch (error) {
        throw AuthException(error.message);
      }
    }
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
    if (apiClient != null) {
      try {
        await apiClient!.logout();
      } on ApiException {
        // Local sign-out still completes if the server is unreachable.
      } finally {
        _currentUser = null;
        notifyListeners();
      }
      return;
    }
    _currentUser = null;
    notifyListeners();
  }

  Future<void> restoreSession() async {
    if (apiClient == null) return;
    try {
      final data = await apiClient!.restoreSession();
      _currentUser = data == null ? null : UserProfile.fromJson(data);
    } on ApiException {
      _currentUser = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    apiClient?.dispose();
    super.dispose();
  }
}
