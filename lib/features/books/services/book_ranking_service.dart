import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';

import '../../bookshelf/bookshelf_database.dart';

/// Counts detail-page visits on this device, shared by its demo accounts.
class BookRankingService extends ChangeNotifier {
  BookRankingService({
    Future<Database> Function()? openDatabase,
    DateTime Function()? now,
  }) : _openDatabase =
           openDatabase ?? (() => openShelfDatabase('book-rankings')),
       _now = now ?? DateTime.now;

  final Future<Database> Function() _openDatabase;
  final DateTime Function() _now;
  final _store = stringMapStoreFactory.store('book_views');
  final _views = <String, Map<String, int>>{};
  Database? _database;
  Future<void> _pending = Future.value();
  Future<void>? _closing;
  bool _loaded = false;
  bool _disposed = false;
  String? error;

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  int viewsFor(String bookId, {int? days}) {
    assert(days == null || days > 0);
    final today = _now().toLocal();
    final end = _dateKey(today);
    final start = days == null
        ? null
        : _dateKey(DateTime(today.year, today.month, today.day - days + 1));
    return (_views[bookId] ?? {}).entries
        .where(
          (entry) =>
              entry.key.compareTo(end) <= 0 &&
              (start == null || entry.key.compareTo(start) >= 0),
        )
        .fold(0, (total, entry) => total + entry.value);
  }

  Future<void> _load() async {
    if (_loaded) return;
    _database ??= await _openDatabase();
    final records = await _store.find(_database!);
    for (final record in records) {
      _views[record.key] = {
        for (final entry in record.value.entries)
          if (entry.value is int && (entry.value as int) >= 0)
            entry.key: entry.value as int,
      };
    }
    _loaded = true;
  }

  Future<void> load() => _enqueue(() async {
    await _load();
  });

  Future<void> recordView(String bookId) {
    if (bookId.trim().isEmpty) {
      return Future.error(ArgumentError('Missing book ID'));
    }
    final day = _dateKey(_now().toLocal());
    return _enqueue(() async {
      await _load();
      final next = {...?_views[bookId]};
      next[day] = (next[day] ?? 0) + 1;
      await _store.record(bookId).put(_database!, next);
      _views[bookId] = next;
    });
  }

  Future<void> _enqueue(Future<void> Function() action) {
    if (_disposed) return Future.error(StateError('Rankings closed'));
    final result = _pending.then((_) async {
      try {
        await action();
        error = null;
      } catch (_) {
        error = 'Chưa cập nhật được bảng xếp hạng. Thử lại.';
      }
      if (!_disposed) notifyListeners();
    });
    _pending = result;
    return result;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _closing = _pending.then((_) async => _database?.close());
    super.dispose();
  }

  Future<void> close() async {
    dispose();
    await _closing;
  }
}
