import 'dart:convert';
import 'dart:io';

import 'package:open_library_client/features/books/models/book.dart';
import 'package:open_library_client/features/books/services/open_library_service.dart';

// Run manually with `dart run tool/verify_books.dart`; uses the live public API.
Future<void> main() async {
  final catalog =
      (jsonDecode(File('assets/data/catalog_30.json').readAsStringSync())
              as List)
          .map((entry) => Book.fromCatalogJson(entry as Map<String, dynamic>))
          .toList();
  final service = OpenLibraryService();
  try {
    final details = await service.getBookDetails(catalog.first);
    if (details.id != catalog.first.id ||
        details.selectedEdition?.id != catalog.first.selectedEdition?.id) {
      throw StateError('Detail or edition mismatch');
    }
    final editions = await service.getEditions(details.id, limit: 2);
    if (editions.editions.isEmpty ||
        editions.editions.any(
          (edition) => !edition.workIds.contains(details.id),
        )) {
      throw StateError('Invalid editions');
    }
    if (details.authorIds.isNotEmpty) {
      final author = await service.getAuthor(details.authorIds.first);
      stdout.writeln(
        'Author: ${author.name}; biography present: ${author.biography != null}',
      );
    }
    final search = await service.searchBooks(
      query: 'Harry Potter',
      language: 'eng',
      limit: 3,
    );
    if (search.books.isEmpty || search.books.length > 3) {
      throw StateError('Invalid search results');
    }
    stdout.writeln(
      'Verified details ${details.id}, edition ${details.selectedEdition?.id}, '
      '${editions.editions.length} editions and ${search.books.length} search results.',
    );
  } finally {
    service.dispose();
  }
}
