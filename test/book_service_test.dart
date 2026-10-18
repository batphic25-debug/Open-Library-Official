import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_library_client/features/books/models/book.dart';
import 'package:open_library_client/features/books/services/open_library_service.dart';
import 'package:open_library_client/features/books/services/sample_books.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'sample catalog has 30 unique books and loadable cover assets',
    () async {
      final books = await SampleBooks.load();
      expect(books, hasLength(30));
      expect(books.map((b) => b.id).toSet(), hasLength(30));
      expect(
        books.every(
          (book) =>
              book.description != null &&
              book.descriptionSource == 'Nhóm biên soạn',
        ),
        isTrue,
      );
      expect(
        books.every((book) => book.selectedEdition!.workIds.contains(book.id)),
        isTrue,
      );
      expect(
        books.every(
          (book) =>
              book.sourceUrl.host == 'openlibrary.org' &&
              book.coverIsIllustration,
        ),
        isTrue,
      );
      expect(
        books.every((b) => b.categories.isNotEmpty && b.authors.isNotEmpty),
        isTrue,
      );
      for (final book in books) {
        expect(
          (await rootBundle.load(book.coverAsset!)).lengthInBytes,
          greaterThan(0),
        );
      }
    },
  );

  test('catalog rejects missing, malformed and duplicated works', () async {
    expect(() => SampleBooks.parse('[]'), throwsFormatException);
    expect(() => SampleBooks.parse('{broken'), throwsFormatException);
    final entries = jsonDecode(
      await rootBundle.loadString('assets/data/catalog_30.json'),
    ) as List;
    entries[1] = entries.first;
    expect(() => SampleBooks.parse(jsonEncode(entries)), throwsFormatException);
  });

  test('model accepts missing metadata and normalizes work keys', () {
    final book = Book.fromSearchJson({
      'key': 'OL1W',
      'title': 'Một cuốn sách',
      'cover_i': -1,
    });
    expect(book.id, '/works/OL1W');
    expect(book.authorLabel, 'Chưa rõ tác giả');
    expect(book.coverUrl, isNull);
    expect(book.firstPublishYear, isNull);
  });

  test('cover URLs prefer image IDs then validated edition IDs', () {
    final book = Book.fromSearchJson({
      'key': 'OL1W',
      'title': 'Book',
      'cover_i': -1,
      'cover_edition_key': 'OL123M',
      'subject': ['Fantasy', null, '', 'Magic'],
    });
    expect(
      book.coverUrl,
      'https://covers.openlibrary.org/b/olid/OL123M-M.jpg?default=false',
    );
    expect(book.categories, ['Fantasy', 'Magic']);
    expect(
      const Book(
        id: '1',
        title: 'Book',
        coverId: 42,
        coverEditionKey: 'OL123M',
      ).coverUrl,
      'https://covers.openlibrary.org/b/id/42-M.jpg?default=false',
    );
    expect(
      const Book(
        id: '1',
        title: 'Book',
        coverEditionKey: '../invalid',
      ).coverUrl,
      isNull,
    );
  });

  test(
    'service sends real language constraint, sort, page and parses metadata',
    () async {
      final service = OpenLibraryService(
        client: MockClient((request) async {
          expect(request.url.host, 'openlibrary.org');
          expect(
            request.url.queryParameters['q'],
            '(Harry Potter) AND language:eng',
          );
          expect(request.url.queryParameters['sort'], 'new');
          expect(request.url.queryParameters['page'], '2');
          expect(request.url.queryParameters['limit'], '20');
          expect(
            request.url.queryParameters['fields'],
            contains('cover_edition_key'),
          );
          expect(request.url.queryParameters['fields'], contains('subject'));
          return http.Response(
            jsonEncode({
              'numFound': 41,
              'docs': [
                {
                  'key': '/works/OL1W',
                  'title': 'Harry Potter',
                  'author_name': ['J. K. Rowling'],
                  'first_publish_year': 1997,
                  'cover_i': 123,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(service.dispose);
      final result = await service.searchBooks(
        query: ' Harry Potter ',
        language: 'eng',
        sort: BookSort.newest,
        page: 2,
      );
      expect(result.hasMore, isTrue);
      expect(result.books.single.firstPublishYear, 1997);
      expect(result.books.single.coverUrl, contains('/123-M.jpg'));
    },
  );

  test('author query, oldest order and legacy total field work', () async {
    final service = OpenLibraryService(
      client: MockClient((request) async {
        expect(request.url.queryParameters['q'], 'Jane Austen');
        expect(request.url.queryParameters['sort'], 'old');
        return http.Response(
          '{"num_found":1,"docs":[{"key":"OL2W","title":"Pride and Prejudice"}]}',
          200,
        );
      }),
    );
    addTearDown(service.dispose);
    final result = await service.searchBooks(
      query: 'Jane Austen',
      sort: BookSort.oldest,
    );
    expect(result.hasMore, isFalse);
    expect(result.total, 1);
  });

  test('empty query does not call the network', () async {
    final service = OpenLibraryService(
      client: MockClient((_) async => throw StateError('Unexpected request')),
    );
    addTearDown(service.dispose);
    expect((await service.searchBooks(query: '  ')).books, isEmpty);
  });

  test(
    'network, rate limit, malformed and server responses give usable errors',
    () async {
      for (final handler in <Future<http.Response> Function(http.Request)>[
        (_) async => throw http.ClientException('offline'),
        (_) async => throw TimeoutException('timeout'),
        (_) async => http.Response('', 429),
        (_) async => http.Response('', 503),
        (_) async => http.Response('not json', 200),
        (_) async => http.Response('{"docs":null}', 200),
      ]) {
        final service = OpenLibraryService(client: MockClient(handler));
        await expectLater(
          service.searchBooks(query: 'book'),
          throwsA(isA<BookSearchException>()),
        );
        service.dispose();
      }
    },
  );
}
