import 'dart:io';

import 'package:open_library_client/features/books/models/book.dart';
import 'package:open_library_client/features/books/services/open_library_service.dart';

// Run manually against the public API; access status can change at the source.
Future<void> main() async {
  final service = OpenLibraryService();
  try {
    const book = Book(
      id: '/works/OL15058799W',
      title: 'The Art of Community',
      selectedEdition: BookEdition(
        id: '/books/OL24194264M',
        workIds: ['/works/OL15058799W'],
      ),
    );
    final options = await service.getReadingOptions(book);
    if (options.isEmpty) {
      throw StateError('No readable editions returned by source');
    }
    for (final option in options) {
      stdout.writeln(
        '${option.editionId}: ${option.status}; exact edition: ${option.exactEdition}; ${option.url}',
      );
    }
  } finally {
    service.dispose();
  }
}
