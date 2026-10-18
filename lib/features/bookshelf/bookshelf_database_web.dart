import 'dart:convert';

import 'package:sembast_web/sembast_web.dart';

Future<Database> openShelfDatabase(String userId) => databaseFactoryWeb
    .openDatabase('shelf_${base64Url.encode(utf8.encode(userId))}');
