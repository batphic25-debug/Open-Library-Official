import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_library_client/core/network/api_client.dart';
import 'package:open_library_client/features/books/services/backend_book_service.dart';
import 'package:open_library_client/features/bookshelf/backend_bookshelf_service.dart';
import 'package:open_library_client/features/bookshelf/models/saved_book.dart';

class MemoryTokens implements TokenStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async => value = token;
  @override
  Future<void> delete() async => value = null;
}

http.Response jsonResponse(int status, Object data) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test(
    'API client rotates one refresh token and retries an expired access token',
    () async {
      final tokens = MemoryTokens();
      var refreshes = 0;
      final api = ApiClient(
        baseUrl: 'http://localhost:8000/api/v1',
        tokenStore: tokens,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/login')) {
            return jsonResponse(200, {
              'user': {
                'id': 'user-1',
                'displayName': 'Reader',
                'email': 'a@example.com',
                'avatarUrl': null,
              },
              'accessToken': 'old-access',
              'refreshToken': 'old-refresh',
            });
          }
          if (request.url.path.endsWith('/auth/refresh')) {
            refreshes++;
            expect(jsonDecode(request.body)['refreshToken'], 'old-refresh');
            return jsonResponse(200, {
              'user': {
                'id': 'user-1',
                'displayName': 'Reader',
                'email': 'a@example.com',
                'avatarUrl': null,
              },
              'accessToken': 'new-access',
              'refreshToken': 'new-refresh',
            });
          }
          if (request.url.path.endsWith('/me')) {
            if (request.headers['authorization'] == 'Bearer old-access') {
              return jsonResponse(401, {
                'error': {'code': 'UNAUTHORIZED', 'message': 'Expired'},
              });
            }
            expect(request.headers['authorization'], 'Bearer new-access');
            return jsonResponse(200, {'id': 'user-1'});
          }
          fail('Unexpected request: ${request.url}');
        }),
      );
      await api.login('a@example.com', 'password-123');
      expect((await api.request('GET', '/me'))['id'], 'user-1');
      expect(refreshes, 1);
      expect(tokens.value, 'new-refresh');
      api.dispose();
    },
  );

  test(
    'catalog maps backend work, local cover, category and edition',
    () async {
      final api = ApiClient(
        baseUrl: 'http://localhost:8000/api/v1',
        tokenStore: MemoryTokens(),
        client: MockClient(
          (request) async => jsonResponse(200, {
            'items': [
              {
                'workId': 'OL10263W',
                'title': 'The Little Prince',
                'authors': ['Antoine de Saint-Exupéry'],
                'categories': ['children'],
                'summaryVi': 'Hoàng tử bé',
                'localCoverKey': 'assets/images/prince.png',
                'selectedEdition': {
                  'editionId': 'OL123M',
                  'workId': 'OL10263W',
                  'title': 'The Little Prince',
                  'pageCount': 96,
                  'isbn10': [],
                  'isbn13': [],
                  'publishers': [],
                  'languages': [],
                },
              },
            ],
          }),
        ),
      );
      final book = (await BackendCatalogService(api).loadBooks()).single;
      expect(book.id, '/works/OL10263W');
      expect(book.coverAsset, 'assets/images/prince.png');
      expect(book.categories, ['Thiếu nhi']);
      expect(book.selectedEdition?.pages, 96);
      api.dispose();
    },
  );

  test(
    'bookshelf sends server version and refreshes progress and notes',
    () async {
      var version = 1;
      var pages = 0;
      String? note;
      Map<String, dynamic> savedPayload() => {
        'workId': 'OL999W',
        'editionId': null,
        'status': pages == 0 ? 'want_to_read' : 'reading',
        'pagesRead': pages,
        'totalPages': null,
        'version': version,
        'createdAt': '2026-01-01T00:00:00Z',
        'updatedAt': '2026-01-01T00:00:00Z',
        'book': {
          'workId': 'OL999W',
          'title': 'Book',
          'authors': ['Author'],
          'categories': [],
        },
        'note': note == null
            ? null
            : {
                'content': note,
                'version': 1,
                'createdAt': '2026-01-01T00:00:00Z',
                'updatedAt': '2026-01-01T00:00:00Z',
              },
      };
      final api = ApiClient(
        baseUrl: 'http://localhost:8000/api/v1',
        tokenStore: MemoryTokens(),
        client: MockClient((request) async {
          if (request.method == 'PATCH') {
            final body = jsonDecode(request.body) as Map;
            expect(body['expectedVersion'], version);
            pages = body['pagesRead'] as int;
            version++;
            return jsonResponse(200, savedPayload());
          }
          if (request.method == 'PUT') {
            final body = jsonDecode(request.body) as Map;
            expect(body['expectedVersion'], 0);
            note = body['content'] as String;
            return jsonResponse(201, {'content': note, 'version': 1});
          }
          return jsonResponse(200, {
            'items': [savedPayload()],
            'hasMore': false,
          });
        }),
      );
      final shelf = BackendBookshelfService(userId: 'user-1', api: api);
      await shelf.loadBooks();
      expect(shelf.bookById('/works/OL999W')?.progress, isNull);
      await shelf.updateProgress('/works/OL999W', 7);
      expect(shelf.bookById('/works/OL999W')?.pagesRead, 7);
      expect(shelf.bookById('/works/OL999W')?.version, 2);
      expect(shelf.bookById('/works/OL999W')?.status, ReadingStatus.reading);
      await shelf.saveNote('/works/OL999W', 'A note');
      expect(shelf.noteFor('/works/OL999W')?.body, 'A note');
      await shelf.close();
      api.dispose();
    },
  );
}
