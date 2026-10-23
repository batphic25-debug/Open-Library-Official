import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_library_client/features/books/services/book_discussion_service.dart';
import 'package:sembast/sembast_io.dart';

void main() {
  late Directory directory;
  late BookDiscussionService service;

  BookDiscussionService open() => BookDiscussionService(
    openDatabase: () =>
        databaseFactoryIo.openDatabase('${directory.path}/discussions.db'),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('discussion_test_');
    service = open();
  });

  tearDown(() async {
    await service.close();
    await directory.delete(recursive: true);
  });

  test(
    'ratings are one per reader and comments stay with their book',
    () async {
      await service.setRating(
        bookId: 'book-1',
        userId: 'alice',
        displayName: 'Alice',
        stars: 4,
      );
      await service.setRating(
        bookId: 'book-1',
        userId: 'bob',
        displayName: 'Bob',
        stars: 5,
      );
      final updated = await service.setRating(
        bookId: 'book-1',
        userId: 'alice',
        displayName: 'Alice',
        stars: 3,
      );
      expect(updated.ratings, hasLength(2));
      expect(updated.averageRating, 4);
      expect(updated.ratingBy('alice'), 3);

      final first = await service.addComment(
        bookId: 'book-1',
        userId: 'alice',
        displayName: 'Alice',
        body: '  Cuốn sách rất hay.  ',
      );
      final parent = first.comments.single;
      final replied = await service.addComment(
        bookId: 'book-1',
        userId: 'bob',
        displayName: 'Bob',
        body: 'Mình cũng thích cuốn này.',
        replyToId: parent.id,
      );
      expect(replied.comments.last.replyToId, parent.id);
      expect(replied.comments.first.body, 'Cuốn sách rất hay.');
      expect((await service.load('book-2')).comments, isEmpty);

      await service.close();
      service = open();
      final reopened = await service.load('book-1');
      expect(reopened.ratingBy('bob'), 5);
      expect(reopened.comments.map((comment) => comment.body), [
        'Cuốn sách rất hay.',
        'Mình cũng thích cuốn này.',
      ]);
    },
  );

  test(
    'rejects invalid ratings, empty comments and missing reply targets',
    () async {
      await expectLater(
        service.setRating(
          bookId: 'book-1',
          userId: 'alice',
          displayName: 'Alice',
          stars: 0,
        ),
        throwsArgumentError,
      );
      await expectLater(
        service.addComment(
          bookId: 'book-1',
          userId: 'alice',
          displayName: 'Alice',
          body: '   ',
        ),
        throwsArgumentError,
      );
      await expectLater(
        service.addComment(
          bookId: 'book-1',
          userId: 'alice',
          displayName: 'Alice',
          body: 'Reply',
          replyToId: 'missing',
        ),
        throwsArgumentError,
      );
      expect((await service.load('book-1')).comments, isEmpty);
    },
  );
}
