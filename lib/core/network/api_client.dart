import 'dart:async';
import 'dart:convert';


import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.status, this.code, this.message);

  final int status;
  final String code;
  final String message;

  @override
  String toString() => message;
}

abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class SecureTokenStore implements TokenStore {
  const SecureTokenStore();

  static const _storage = FlutterSecureStorage();
  static const _key = 'open_library_refresh_token';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}

class ApiClient {
  ApiClient({http.Client? client, TokenStore? tokenStore, String? baseUrl})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _tokenStore = tokenStore ?? const SecureTokenStore(),
      baseUrl = baseUrl ?? defaultBaseUrl;

    static String get defaultBaseUrl {
    return 'https://open-library-client-oe9a.onrender.com/api/v1';
  }

  final http.Client _client;
  final bool _ownsClient;
  final TokenStore _tokenStore;
  final String baseUrl;
  String? _accessToken;
  String? _refreshToken;
  Future<Map<String, dynamic>>? _refreshing;
  void Function()? onSessionExpired;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await request(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
      authenticated: false,
    );
    await _acceptTokens(data);
    return Map<String, dynamic>.from(data['user'] as Map);
  }

  Future<Map<String, dynamic>?> restoreSession() async {
    _refreshToken = await _tokenStore.read();
    if (_refreshToken == null) return null;
    try {
      final data = await _refresh();
      return Map<String, dynamic>.from(data['user'] as Map);
    } on ApiException catch (error) {
      if (error.status == 401) return null;
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      if (_accessToken != null) {
        await request('POST', '/auth/logout');
      }
    } finally {
      await clearSession();
    }
  }

  Future<void> clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    await _tokenStore.delete();
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final uri = Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}$path')
        .replace(queryParameters: query);
    print('===> FLUTTER DANG GOI URL: $uri');
    var response = await _send(method, uri, body, authenticated);
    if (authenticated && response.statusCode == 401 && _refreshToken != null) {
      await _refresh();
      response = await _send(method, uri, body, authenticated);
    }
    if (response.statusCode >= 400) {
      throw _error(response);
    }
    if (response.bodyBytes.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map,
      );
    } on FormatException {
      throw const ApiException(
        502,
        'BAD_RESPONSE',
        'Dữ liệu từ máy chủ không hợp lệ.',
      );
    } on TypeError {
      throw const ApiException(
        502,
        'BAD_RESPONSE',
        'Dữ liệu từ máy chủ không hợp lệ.',
      );
    }
  }

  Future<http.Response> _send(
    String method,
    Uri uri,
    Map<String, dynamic>? body,
    bool authenticated,
  ) async {
    final call = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    if (authenticated && _accessToken != null) {
      call.headers['Authorization'] = 'Bearer $_accessToken';
    }
    if (body != null) {
      call.headers['Content-Type'] = 'application/json';
      call.body = jsonEncode(body);
    }
    try {
      final streamed = await _client
          .send(call)
          .timeout(const Duration(seconds: 20));
      return await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const ApiException(
        0,
        'TIMEOUT',
        'Kết nối quá lâu. Vui lòng thử lại.',
      );
    } on http.ClientException {
      throw const ApiException(
        0,
        'NETWORK_ERROR',
        'Không kết nối được máy chủ.',
      );
    }
  }

  Future<Map<String, dynamic>> _refresh() =>
      _refreshing ??= _performRefresh().whenComplete(() => _refreshing = null);

  Future<Map<String, dynamic>> _performRefresh() async {
    try {
      final data = await request(
        'POST',
        '/auth/refresh',
        body: {'refreshToken': _refreshToken},
        authenticated: false,
      );
      await _acceptTokens(data);
      return data;
    } on ApiException catch (error) {
      if (error.status == 401) {
        await clearSession();
        onSessionExpired?.call();
      }
      rethrow;
    }
  }

  Future<void> _acceptTokens(Map<String, dynamic> data) async {
    final access = data['accessToken'];
    final refresh = data['refreshToken'];
    if (access is! String || refresh is! String) {
      throw const ApiException(
        502,
        'BAD_RESPONSE',
        'Phiên đăng nhập không hợp lệ.',
      );
    }
    await _tokenStore.write(refresh);
    _accessToken = access;
    _refreshToken = refresh;
  }

  ApiException _error(http.Response response) {
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
      final error = data['error'] as Map;
      return ApiException(
        response.statusCode,
        error['code'] as String,
        error['message'] as String,
      );
    } catch (_) {
      return ApiException(
        response.statusCode,
        'HTTP_ERROR',
        'Máy chủ trả lỗi ${response.statusCode}. Vui lòng thử lại.',
      );
    }
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
