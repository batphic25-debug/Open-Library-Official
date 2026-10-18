import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';

import '../bookshelf/bookshelf_database.dart';

class ReaderPosition {
  const ReaderPosition({required this.offset, required this.fontSize});

  final double offset;
  final double fontSize;

  Map<String, num> toJson() => {'offset': offset, 'fontSize': fontSize};
}

/// Settings are stored per demo account on this device.
class SettingsService extends ChangeNotifier {
  SettingsService({
    required this.userId,
    Future<Database> Function()? openDatabase,
  }) : _openDatabase =
           openDatabase ?? (() => openShelfDatabase('settings:$userId'));

  final String userId;
  final Future<Database> Function() _openDatabase;
  final _record = stringMapStoreFactory.store('settings').record('preferences');
  Database? _database;
  Future<void> _pending = Future.value();
  bool _loaded = false;
  bool _disposed = false;
  Future<void>? _closing;
  bool notifications = false;
  String language = 'vi';
  bool darkMode = false;
  Uint8List? _avatarBytes;
  String? _avatarBase64;
  Map<String, ReaderPosition> _readerPositions = {};
  Uint8List? get avatarBytes => _avatarBytes;
  String? error;

  Future<void> _load() async {
    if (_loaded) return;
    _database ??= await _openDatabase();
    final data = await _record.get(_database!);
    if (data != null) {
      if (data['userId'] != userId) {
        throw const FormatException('Cài đặt không thuộc tài khoản này.');
      }
      notifications = data['notifications'] == true;
      language = data['language'] == 'en' ? 'en' : 'vi';
      darkMode = data['darkMode'] == true;
      final avatar = data['avatar'];
      if (avatar is String) {
        try {
          final bytes = base64Decode(avatar);
          if (bytes.lengthInBytes <= 2 * 1024 * 1024) {
            _avatarBytes = bytes;
            _avatarBase64 = avatar;
          }
        } on FormatException {
          // Keep the remaining settings if an older avatar is damaged.
        }
      }
      final positions = data['readerPositions'];
      if (positions is Map) {
        for (final entry in positions.entries) {
          final value = entry.value;
          if (entry.key is! String || value is! Map) continue;
          final offset = value['offset'];
          final fontSize = value['fontSize'];
          if (offset is num &&
              offset.isFinite &&
              offset >= 0 &&
              fontSize is num &&
              fontSize.isFinite &&
              fontSize >= 14 &&
              fontSize <= 28) {
            _readerPositions[entry.key as String] = ReaderPosition(
              offset: offset.toDouble(),
              fontSize: fontSize.toDouble(),
            );
          }
        }
      }
    }
    _loaded = true;
  }

  Future<void> load() => _enqueue(() async {
    try {
      await _load();
      error = null;
    } catch (_) {
      error = 'Không thể tải cài đặt. Hãy thử lại.';
    }
    if (!_disposed) notifyListeners();
  });

  Future<void> update({bool? notifications, String? language, bool? darkMode}) {
    if (language != null && language != 'vi' && language != 'en') {
      throw ArgumentError.value(language, 'language');
    }
    return _enqueue(() async {
      await _load();
      final nextNotifications = notifications ?? this.notifications;
      final nextLanguage = language ?? this.language;
      final nextDarkMode = darkMode ?? this.darkMode;
      await _record.put(
        _database!,
        _data(
          notifications: nextNotifications,
          language: nextLanguage,
          darkMode: nextDarkMode,
        ),
      );
      this.notifications = nextNotifications;
      this.language = nextLanguage;
      this.darkMode = nextDarkMode;
      error = null;
      if (!_disposed) notifyListeners();
    });
  }

  Future<void> updateAvatar(Uint8List? bytes) {
    if (bytes != null && bytes.lengthInBytes > 2 * 1024 * 1024) {
      return Future.error(
        ArgumentError('Ảnh vượt quá 2 MB. Hãy chọn ảnh nhỏ hơn.'),
      );
    }
    return _enqueue(() async {
      await _load();
      final encoded = bytes == null ? null : base64Encode(bytes);
      await _record.put(_database!, {..._data(), 'avatar': encoded});
      _avatarBase64 = encoded;
      _avatarBytes = bytes == null ? null : Uint8List.fromList(bytes);
      if (!_disposed) notifyListeners();
    });
  }

  Map<String, Object?> _data({
    bool? notifications,
    String? language,
    bool? darkMode,
  }) => {
    'userId': userId,
    'notifications': notifications ?? this.notifications,
    'language': language ?? this.language,
    'darkMode': darkMode ?? this.darkMode,
    'avatar': _avatarBase64,
    'readerPositions': _readerPositions.map(
      (id, position) => MapEntry(id, position.toJson()),
    ),
  };

  Future<ReaderPosition?> loadReaderPosition(String bookId) =>
      _enqueue(() async {
        await _load();
        return _readerPositions[bookId];
      });

  Future<void> saveReaderPosition(String bookId, ReaderPosition position) {
    if (bookId.isEmpty ||
        !position.offset.isFinite ||
        position.offset < 0 ||
        !position.fontSize.isFinite ||
        position.fontSize < 14 ||
        position.fontSize > 28) {
      return Future.error(ArgumentError('Vị trí đọc không hợp lệ.'));
    }
    return _enqueue(() async {
      await _load();
      final next = Map<String, ReaderPosition>.from(_readerPositions)
        ..[bookId] = position;
      await _record.put(_database!, {
        ..._data(),
        'readerPositions': next.map(
          (id, value) => MapEntry(id, value.toJson()),
        ),
      });
      _readerPositions = next;
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    if (_disposed) return Future.error(StateError('Cài đặt đã đóng.'));
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _closing = _pending.then((_) async {
      await _database?.close();
    });
    super.dispose();
  }

  Future<void> close() async {
    if (!_disposed) dispose();
    await _closing;
  }
}
