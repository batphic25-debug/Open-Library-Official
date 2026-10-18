import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/book.dart';

class SampleBooks {
  static List<Book>? _cache;

  static Future<List<Book>> load() async {
    if (_cache != null) return _cache!;
    return _cache = parse(
      await rootBundle.loadString('assets/data/catalog_30.json'),
    );
  }

  static List<Book> parse(String source) {
    final data = jsonDecode(source);
    if (data is! List || data.length != 30) {
      throw const FormatException('Catalog must contain 30 works');
    }
    final books = <Book>[];
    for (final entry in data) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Invalid catalog entry');
      }
      final book = Book.fromCatalogJson(entry);
      if (book.authors.isEmpty ||
          book.categories.isEmpty ||
          book.selectedEdition == null ||
          book.coverAsset == null) {
        throw const FormatException('Incomplete catalog entry');
      }
      books.add(book);
    }
    if (books.map((book) => book.id).toSet().length != 30) {
      throw const FormatException('Duplicate work IDs');
    }
    return List.unmodifiable(books);
  }
}
