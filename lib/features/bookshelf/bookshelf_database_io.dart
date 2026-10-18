import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openShelfDatabase(String userId) async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  final name = base64Url.encode(utf8.encode(userId));
  return databaseFactoryIo.openDatabase(
    path.join(directory.path, 'shelf_$name.db'),
  );
}
