import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/book.dart';
import '../models/reading_option.dart';

enum BookSort { relevance, newest, oldest }

class BookSearchResult {
  const BookSearchResult({
    required this.books,
    required this.total,
    required this.hasMore,
  });
  final List<Book> books;
  final int total;
  final bool hasMore;
}

class BookSearchException implements Exception {
  const BookSearchException(this.message);
  final String message;
}

class OpenLibraryService {
  OpenLibraryService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  DateTime _nextRequest = DateTime.fromMillisecondsSinceEpoch(0);

  Future<BookSearchResult> searchBooks({
    required String query,
    String? language,
    BookSort sort = BookSort.relevance,
    int page = 1,
    int limit = 20,
  }) async {
    if (limit < 1 || limit > 100) throw ArgumentError.value(limit, 'limit');
    if (page < 1) throw ArgumentError.value(page, 'page');
    if (language != null &&
        !const ['vie', 'eng', 'fre', 'ger', 'spa'].contains(language)) {
      throw ArgumentError.value(language, 'language');
    }
    if (query.trim().isEmpty) {
      return const BookSearchResult(books: [], total: 0, hasMore: false);
    }
    final escaped = query.trim().replaceAllMapped(
      RegExp(r'[+\-!(){}\[\]^"~*?:\\/|&]'),
      (match) => '\\${match[0]}',
    );
    final uri = Uri.https('openlibrary.org', '/search.json', {
      'q': language == null ? escaped : '($escaped) AND language:$language',
      'fields': 'key,title,author_name,author_key,first_publish_year,cover_i,cover_edition_key,subject',
      'limit': '$limit',
      'page': '$page',
      if (sort != BookSort.relevance)
        'sort': sort == BookSort.newest ? 'new' : 'old',
    });
    try {
      final data = await _getJson(uri);
      final docs = data['docs'] as List;
      final total = (data['numFound'] ?? data['num_found']) as int;
      final books = docs
          .map((doc) => Book.fromSearchJson(doc as Map<String, dynamic>))
          .toList();
      return BookSearchResult(
        books: books,
        total: total,
        hasMore: docs.isNotEmpty && page * limit < total,
      );
    } on FormatException {
      _cache.clear();
      throw const BookSearchException(
        'Dữ liệu sách không hợp lệ. Vui lòng thử lại.',
      );
    } on TypeError {
      _cache.clear();
      throw const BookSearchException(
        'Dữ liệu sách không hợp lệ. Vui lòng thử lại.',
      );
    }
  }

  Future<List<ReadingOption>> getReadingOptions(Book book) async {
    final edition = book.selectedEdition;
    if (edition == null) return const [];
    final key = libraryKey(edition.id, 'books', 'M').split('/').last;
    try {
      final data = await _getJson(
        Uri.https('openlibrary.org', '/api/volumes/brief/olid/$key.json'),
      );
      return ReadingOption.parse(data, book);
    } on FormatException {
      throw const BookSearchException(
        'Dữ liệu bản đọc không hợp lệ. Vui lòng thử lại.',
      );
    }
  }

  final Map<Uri, Map<String, dynamic>> _cache = {};

  Future<Map<String, dynamic>> _getJson(Uri uri, {bool cache = false}) async {
    if (cache && _cache.containsKey(uri)) return _cache[uri]!;
    // Space requests to respect the public API's unauthenticated rate limit.
    final now = DateTime.now();
    final wait = _nextRequest.difference(now);
    _nextRequest = (wait.isNegative ? now : _nextRequest).add(
      const Duration(seconds: 1),
    );
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 429) {
        throw const BookSearchException(
          'Open Library đang nhận nhiều yêu cầu. Vui lòng đợi rồi thử lại.',
        );
      }
      if (response.statusCode != 200) {
        throw const BookSearchException(
          'Không thể tải sách từ Open Library. Vui lòng thử lại.',
        );
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (cache) _cache[uri] = data;
      return data;
    } on BookSearchException {
      rethrow;
    } on TimeoutException {
      throw const BookSearchException(
        'Kết nối quá lâu. Kiểm tra mạng và thử lại.',
      );
    } on http.ClientException {
      throw const BookSearchException(
        'Không có kết nối tới Open Library. Kiểm tra mạng và thử lại.',
      );
    } on FormatException {
      _cache.clear();
      throw const BookSearchException(
        'Dữ liệu sách không hợp lệ. Vui lòng thử lại.',
      );
    } on TypeError {
      _cache.clear();
      throw const BookSearchException(
        'Dữ liệu sách không hợp lệ. Vui lòng thử lại.',
      );
    }
  }

  Future<BookAuthor> getAuthor(String authorId) async {
    try {
      final key = libraryKey(authorId, 'authors', 'A');
      return BookAuthor.fromJson(
        await _getJson(Uri.https('openlibrary.org', '$key.json'), cache: true),
      );
    } on FormatException {
      _cache.clear();
      throw const BookSearchException('Dữ liệu tác giả không hợp lệ.');
    } on TypeError {
      _cache.clear();
      throw const BookSearchException('Dữ liệu tác giả không hợp lệ.');
    }
  }

  Future<EditionPageResult> getEditions(
    String workId, {
    int page = 1,
    int limit = 20,
  }) async {
    if (page < 1 || limit < 1 || limit > 100) {
      throw ArgumentError('Invalid pagination');
    }
    try {
      final key = libraryKey(workId, 'works', 'W');
      final data = await _getJson(
        Uri.https('openlibrary.org', '$key/editions.json', {
          'limit': '$limit',
          'offset': '${(page - 1) * limit}',
        }),
        cache: true,
      );
      final entries = data['entries'] as List;
      final total = data['size'] as int;
      final editions = entries
          .map((item) => BookEdition.fromJson(item as Map<String, dynamic>))
          .toList();
      if (editions.any((edition) => !edition.workIds.contains(key))) {
        throw const FormatException('Edition belongs to a different work');
      }
      return EditionPageResult(
        editions: editions,
        total: total,
        hasMore: entries.isNotEmpty && page * limit < total,
      );
    } on FormatException {
      _cache.clear();
      throw const BookSearchException('Dữ liệu phiên bản không hợp lệ.');
    } on TypeError {
      _cache.clear();
      throw const BookSearchException('Dữ liệu phiên bản không hợp lệ.');
    }
  }

  Future<Book> getBookDetails(Book book) async {
    try {
      final key = libraryKey(book.id, 'works', 'W');
      final data = await _getJson(
        Uri.https('openlibrary.org', '$key.json'),
        cache: true,
      );
      if (libraryKey(data['key'], 'works', 'W') != key) {
        throw const FormatException('Wrong work');
      }
      final authorIds = data['authors'] is List
          ? (data['authors'] as List)
                .whereType<Map>()
                .map((entry) => (entry['author'] as Map?)?['key'])
                .whereType<String>()
                .toList()
          : book.authorIds;
      final names = <String>[];
      // Search/catalog author names already come from source; fetch names only when missing.
      if (book.authors.isEmpty) {
        for (final id in authorIds) {
          final author = await getAuthor(id);
          if (author.name != null) names.add(author.name!);
        }
      }
      var edition = book.selectedEdition;
      if (edition == null &&
          book.coverEditionKey != null &&
          RegExp(r'^OL\d+M$').hasMatch(book.coverEditionKey!)) {
        edition = BookEdition.fromJson(
          await _getJson(
            Uri.https('openlibrary.org', '/books/${book.coverEditionKey}.json'),
            cache: true,
          ),
        );
      }
      if (edition == null) {
        final result = await getEditions(key, limit: 1);
        if (result.editions.isNotEmpty) edition = result.editions.first;
      }
      final description = sourceText(data['description']);
      final year = RegExp(r'\b[0-9]{4}\b')
          .firstMatch(sourceText(data['first_publish_date']) ?? '')
          ?.group(0);
      final details = Book(
        id: key,
        title: sourceText(data['title']) ?? book.title,
        authors: book.authors.isNotEmpty ? book.authors : names,
        authorIds: authorIds,
        categories: book.categories.isNotEmpty
            ? book.categories
            : sourceStrings(data['subjects']).take(12).toList(),
        description: description ?? book.description,
        descriptionSource: description != null
            ? 'Open Library'
            : book.descriptionSource,
        firstPublishYear:
            book.firstPublishYear ?? (year == null ? null : int.tryParse(year)),
      );
      return edition == null ? details : details.withEdition(edition);
    } on FormatException {
      _cache.clear();
      throw const BookSearchException('Dữ liệu chi tiết sách không hợp lệ.');
    } on TypeError {
      _cache.clear();
      throw const BookSearchException('Dữ liệu chi tiết sách không hợp lệ.');
    }
  }

  void dispose() => _client.close();
}

class EditionPageResult {
  const EditionPageResult({
    required this.editions,
    required this.total,
    required this.hasMore,
  });
  final List<BookEdition> editions;
  final int total;
  final bool hasMore;
}
