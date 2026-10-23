import '../../../core/network/api_client.dart';
import '../models/book.dart';
import 'open_library_service.dart';

class BackendBookService extends OpenLibraryService {
  BackendBookService(this.api);

  final ApiClient api;

  @override
  Future<BookSearchResult> searchBooks({
    required String query,
    String? language,
    BookSort sort = BookSort.relevance,
    int page = 1,
    int limit = 20,
  }) async {
    if (query.trim().length < 2) {
      return const BookSearchResult(books: [], total: 0, hasMore: false);
    }
    try {
      final data = await api.request(
        'GET',
        '/books/search',
        authenticated: false,
        query: {
          'q': query.trim(),
          'page': '$page',
          'pageSize': '$limit',
          'sort': sort.name,
          if (language != null)
            'language': language == 'ger' ? 'deu' : language,
        },
      );
      final items = (data['items'] as List)
          .map(
            (item) =>
                Book.fromApiSearchJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
      return BookSearchResult(
        books: items,
        total: data['total'] is int
            ? data['total'] as int
            : (page - 1) * limit + items.length,
        hasMore: data['hasMore'] == true,
      );
    } on ApiException catch (error) {
      throw BookSearchException(error.message);
    } on FormatException {
      throw const BookSearchException('Dữ liệu sách không hợp lệ.');
    }
  }

  @override
  Future<Book> getBookDetails(Book book) async {
    try {
      final workId = libraryKey(book.id, 'works', 'W').split('/').last;
      final data = await api.request(
        'GET',
        '/books/$workId',
        authenticated: false,
      );
      var result = Book.fromApiJson(data);
      if (result.selectedEdition == null) {
        final editions = await getEditions(book.id, limit: 1);
        if (editions.editions.isNotEmpty) {
          result = result.withEdition(editions.editions.first);
        }
      }
      return result;
    } on ApiException catch (error) {
      throw BookSearchException(error.message);
    } on FormatException {
      throw const BookSearchException('Dữ liệu chi tiết sách không hợp lệ.');
    }
  }

  @override
  Future<EditionPageResult> getEditions(
    String workId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final id = libraryKey(workId, 'works', 'W').split('/').last;
      final data = await api.request(
        'GET',
        '/books/$id/editions',
        authenticated: false,
        query: {'offset': '${(page - 1) * limit}', 'limit': '$limit'},
      );
      final editions = (data['items'] as List)
          .map(
            (item) =>
                BookEdition.fromApiJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
      return EditionPageResult(
        editions: editions,
        total: data['total'] is int
            ? data['total'] as int
            : (page - 1) * limit + editions.length,
        hasMore: data['hasMore'] == true,
      );
    } on ApiException catch (error) {
      throw BookSearchException(error.message);
    } on FormatException {
      throw const BookSearchException('Dữ liệu phiên bản không hợp lệ.');
    }
  }
}

class BackendCatalogService {
  BackendCatalogService(this.api);

  final ApiClient api;

  Future<List<Book>> loadBooks() async {
    final data = await api.request(
      'GET',
      '/books',
      authenticated: false,
      query: {'pageSize': '50'},
    );
    return (data['items'] as List)
        .map((item) => Book.fromApiJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
