import 'package:flutter/services.dart';

import '../models/book.dart';

class OfflineBook {
  const OfflineBook({required this.path, this.gutenbergId});

  final String path;
  final int? gutenbergId;
}

class OfflineBookText {
  const OfflineBookText({required this.paragraphs, required this.license});

  final List<String> paragraphs;
  final String license;

  int pageCount(Book book) {
    final pages = book.selectedEdition?.pages;
    if (pages != null && pages > 0) return pages;
    final length = paragraphs.fold<int>(0, (sum, text) => sum + text.length);
    return (length / 1800).ceil().clamp(1, 10000);
  }
}

class OfflineBookLibrary {
  static const _books = <String, OfflineBook>{
    '/works/OL66554W': OfflineBook(
      path: 'assets/books/open_library_pride.txt',
      gutenbergId: 1342,
    ),
    '/works/OL468431W': OfflineBook(
      path: 'assets/books/open_library_gatsby.txt',
      gutenbergId: 64317,
    ),
    '/works/OL1095427W': OfflineBook(
      path: 'assets/books/open_library_jane_eyre.txt',
      gutenbergId: 1260,
    ),
    '/works/OL29983W': OfflineBook(
      path: 'assets/books/open_library_little_women.txt',
      gutenbergId: 514,
    ),
    '/works/OL450063W': OfflineBook(
      path: 'assets/books/open_library_frankenstein.txt',
      gutenbergId: 84,
    ),
    '/works/OL85892W': OfflineBook(
      path: 'assets/books/open_library_dracula.txt',
      gutenbergId: 345,
    ),
    '/works/OL262421W': OfflineBook(
      path: 'assets/books/open_library_sherlock.txt',
      gutenbergId: 1661,
    ),
    '/works/OL262454W': OfflineBook(
      path: 'assets/books/open_library_hound.txt',
      gutenbergId: 2852,
    ),
    '/works/OL138052W': OfflineBook(
      path: 'assets/books/open_library_alice.txt',
      gutenbergId: 11,
    ),
    '/works/OL17930368W': OfflineBook(
      path: 'assets/books/local_OL17930368W.txt',
    ),
    '/works/OL10263W': OfflineBook(path: 'assets/books/local_OL10263W.txt'),
    '/works/OL82563W': OfflineBook(path: 'assets/books/local_OL82563W.txt'),
    '/works/OL1168083W': OfflineBook(path: 'assets/books/local_OL1168083W.txt'),
    '/works/OL3140822W': OfflineBook(path: 'assets/books/local_OL3140822W.txt'),
    '/works/OL1168007W': OfflineBook(path: 'assets/books/local_OL1168007W.txt'),
    '/works/OL796465W': OfflineBook(path: 'assets/books/local_OL796465W.txt'),
    '/works/OL27482W': OfflineBook(path: 'assets/books/local_OL27482W.txt'),
    '/works/OL27513W': OfflineBook(path: 'assets/books/local_OL27513W.txt'),
    '/works/OL71037W': OfflineBook(path: 'assets/books/local_OL71037W.txt'),
    '/works/OL893414W': OfflineBook(path: 'assets/books/local_OL893414W.txt'),
    '/works/OL64365W': OfflineBook(path: 'assets/books/local_OL64365W.txt'),
    '/works/OL103123W': OfflineBook(path: 'assets/books/local_OL103123W.txt'),
    '/works/OL471576W': OfflineBook(path: 'assets/books/local_OL471576W.txt'),
    '/works/OL483391W': OfflineBook(path: 'assets/books/local_OL483391W.txt'),
    '/works/OL1063267W': OfflineBook(path: 'assets/books/local_OL1063267W.txt'),
    '/works/OL2629977W': OfflineBook(path: 'assets/books/local_OL2629977W.txt'),
    '/works/OL17713267W': OfflineBook(
      path: 'assets/books/local_OL17713267W.txt',
    ),
    '/works/OL21640039W': OfflineBook(
      path: 'assets/books/local_OL21640039W.txt',
    ),
  };

  static OfflineBook? forBook(Book book) => _books[book.id];

  static bool hasBook(Book book) => forBook(book) != null;

  static Future<OfflineBookText> load(OfflineBook book) async {
    final raw = await rootBundle.loadString(book.path);
    if (book.gutenbergId == null) {
      final paragraphs = raw
          .replaceAll('\r\n', '\n')
          .split(RegExp(r'\n\s*\n'))
          .map((part) => part.trim().replaceAll(RegExp(r'\n+'), ' '))
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
      if (paragraphs.isEmpty) throw const FormatException('Empty bundled book');
      return OfflineBookText(
        paragraphs: paragraphs,
        license: 'Văn bản được trích xuất và trình bày lại từ tệp PDF bạn đã thêm vào ứng dụng. Nội dung giữ nguyên theo tệp gốc.',
      );
    }
    final start = RegExp(
      r'\*\*\* START OF (?:THE|THIS) PROJECT GUTENBERG EBOOK .*?\*\*\*',
      caseSensitive: false,
    ).firstMatch(raw);
    final end = RegExp(
      r'\*\*\* END OF (?:THE|THIS) PROJECT GUTENBERG EBOOK .*?\*\*\*',
      caseSensitive: false,
    ).firstMatch(raw);
    if (start == null || end == null || end.start <= start.end) {
      throw const FormatException('Invalid bundled book');
    }
    final body = raw.substring(start.end, end.start).trim();
    final paragraphs = body
        .replaceAll('\r\n', '\n')
        .split(RegExp(r'\n\s*\n'))
        .map((part) => part.trim().replaceAll(RegExp(r'\n+'), ' '))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (paragraphs.isEmpty) throw const FormatException('Empty bundled book');
    return OfflineBookText(
      paragraphs: paragraphs,
      license: raw.substring(end.start).trim(),
    );
  }
}
