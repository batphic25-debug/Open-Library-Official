import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_library_client/features/books/models/book.dart';
import 'package:open_library_client/features/books/services/open_library_service.dart';

const work = Book(
  id: '/works/OL1W',
  title: 'Work',
  authors: ['Author'],
  coverEditionKey: 'OL10M',
);
Map<String, dynamic> editionJson(String id, {String workId = '/works/OL1W'}) =>
    {
      'key': '/books/$id',
      'title': 'Edition $id',
      'works': [
        {'key': workId},
      ],
      'isbn_13': ['9780000000002'],
      'publishers': ['Publisher'],
      'publish_date': '2001',
      'number_of_pages': 321,
      'languages': [
        {'key': '/languages/vie'},
      ],
      'covers': [-1, 42],
    };
http.Response jsonResponse(Object data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test(
    'edition parses optional fields and replaces cover metadata atomically',
    () {
      final first = BookEdition.fromJson(editionJson('OL10M'));
      final second = BookEdition.fromJson({
        'key': 'OL11M',
        'works': [
          {'key': work.id},
        ],
      });
      expect(first.pages, 321);
      expect(first.languageLabel, 'Tiếng Việt');
      expect(first.coverId, 42);
      final selected = const Book(
        id: '/works/OL1W',
        title: 'Work',
        coverAsset: 'illustration.png',
        coverId: 999,
      ).withEdition(first).withEdition(second);
      expect(selected.coverAsset, isNull);
      expect(selected.selectedEdition!.pages, isNull);
      expect(selected.selectedEdition!.isbn, isEmpty);
      expect(selected.coverUrl, contains('/olid/OL11M-M.jpg'));
      expect(
        () => work.withEdition(
          BookEdition.fromJson(editionJson('OL12M', workId: '/works/OL2W')),
        ),
        throwsFormatException,
      );
    },
  );

  test('details parse object descriptions and keep the selected edition with cached requests', () async {
    final paths = <String>[];
    final service = OpenLibraryService(
      client: MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path == '/works/OL1W.json') {
          return jsonResponse({
            'key': work.id,
            'title': 'Source work',
            'description': {'value': 'Source introduction'},
            'authors': [
              {
                'author': {'key': '/authors/OL2A'},
              },
            ],
            'subjects': ['Fiction'],
          });
        }
        return jsonResponse(editionJson('OL10M'));
      }),
    );
    addTearDown(service.dispose);
    final result = await service.getBookDetails(work);
    expect(result.description, 'Source introduction');
    expect(result.descriptionSource, 'Open Library');
    expect(result.authorIds, ['/authors/OL2A']);
    expect(result.selectedEdition!.pages, 321);
    expect(result.coverUrl, contains('/42-M.jpg'));
    await service.getBookDetails(work);
    expect(paths, ['/works/OL1W.json', '/books/OL10M.json']);
  });

  test('editions paginate using offset and report remaining results', () async {
    final service = OpenLibraryService(
      client: MockClient((request) async {
        expect(request.url.queryParameters, {'limit': '2', 'offset': '2'});
        return jsonResponse({
          'size': 5,
          'entries': [editionJson('OL12M'), editionJson('OL13M')],
        });
      }),
    );
    addTearDown(service.dispose);
    final result = await service.getEditions(work.id, page: 2, limit: 2);
    expect(result.editions.length, 2);
    expect(result.hasMore, isTrue);
    expect(result.total, 5);
  });

  test(
    'malformed cached editions can be retried; foreign editions are rejected',
    () async {
      var calls = 0;
      final service = OpenLibraryService(
        client: MockClient(
          (request) async => jsonResponse({
            'size': 1,
            'entries': [
              editionJson(
                'OL10M',
                workId: calls++ == 0 ? '/works/OL9W' : work.id,
              ),
            ],
          }),
        ),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.getEditions(work.id),
        throwsA(isA<BookSearchException>()),
      );
      expect((await service.getEditions(work.id)).editions.single.workIds, [
        work.id,
      ]);
      expect(calls, 2);
    },
  );

  test(
    'author text can be a string or object, absent biography stays null',
    () async {
      final service = OpenLibraryService(
        client: MockClient(
          (request) async => jsonResponse({
            'key': '/authors/OL2A',
            'name': 'Author',
            'bio': {'value': 'Biography'},
            'birth_date': '1900',
          }),
        ),
      );
      addTearDown(service.dispose);
      final author = await service.getAuthor('OL2A');
      expect(author.biography, 'Biography');
      expect(author.birthDate, '1900');
      expect(BookAuthor.fromJson({'key': '/authors/OL3A'}).biography, isNull);
      expect(sourceText('Plain text'), 'Plain text');
    },
  );

  test('details, editions and authors preserve network errors', () async {
    final service = OpenLibraryService(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    addTearDown(service.dispose);
    for (final request in <Future<Object> Function()>[
      () => service.getBookDetails(work),
      () => service.getEditions(work.id),
      () => service.getAuthor('OL2A'),
    ]) {
      await expectLater(request(), throwsA(isA<BookSearchException>()));
    }
  });

  test(
    'search supports custom page size and validates invalid pagination',
    () async {
      final service = OpenLibraryService(
        client: MockClient((request) async {
          expect(request.url.queryParameters['limit'], '5');
          return jsonResponse({
            'numFound': 6,
            'docs': [
              {'key': work.id, 'title': 'Work'},
            ],
          });
        }),
      );
      addTearDown(service.dispose);
      expect(
        (await service.searchBooks(query: 'Work', limit: 5)).hasMore,
        isTrue,
      );
      await expectLater(
        service.searchBooks(query: 'Work', limit: 0),
        throwsArgumentError,
      );
      await expectLater(
        service.getEditions(work.id, page: 0),
        throwsArgumentError,
      );
    },
  );
}
