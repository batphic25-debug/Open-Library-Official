import 'package:sembast/sembast.dart';

import '../../features/bookshelf/bookshelf_database.dart';

/// Remembers the last selected appearance for screens shown before sign-in.
class AppearanceStore {
  AppearanceStore({Future<Database> Function()? openDatabase})
    : _openDatabase =
          openDatabase ?? (() => openShelfDatabase('app-appearance'));

  final Future<Database> Function() _openDatabase;
  final _record = stringMapStoreFactory.store('appearance').record('last');
  Future<Database>? _database;

  Future<Database> get _db => _database ??= _openDatabase();

  Future<bool> load() async {
    return (await _record.get(await _db))?['darkMode'] == true;
  }

  Future<void> save(bool darkMode) async {
    await _record.put(await _db, {'darkMode': darkMode});
  }
}
