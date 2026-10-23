import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_library_client/features/books/services/book_ranking_service.dart';
import 'package:sembast/sembast_io.dart';

void main() {
  test(
    'counts calendar periods, serializes visits and persists on reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp('rankings_test_');
      var now = DateTime(2026, 10, 11, 23, 59);
      BookRankingService open() => BookRankingService(
        openDatabase: () =>
            databaseFactoryIo.openDatabase('${directory.path}/views.db'),
        now: () => now,
      );
      var service = open();
      try {
        await service.recordView('a');
        now = DateTime(2026, 10, 13);
        await service.recordView('a');
        now = DateTime(2026, 10, 19, 23, 59);
        await Future.wait(List.generate(3, (_) => service.recordView('a')));
        await service.recordView('b');
        expect(service.viewsFor('a', days: 1), 3);
        expect(service.viewsFor('a', days: 7), 4);
        expect(service.viewsFor('a'), 5);
        expect(service.viewsFor('b'), 1);
        expect(service.viewsFor('missing'), 0);
        await service.close();
        service = open();
        await service.load();
        expect(service.viewsFor('a'), 5);
        now = DateTime(2026, 10, 20);
        expect(service.viewsFor('a', days: 1), 0);
        expect(service.viewsFor('a', days: 7), 3);
        expect(service.error, isNull);
        await expectLater(service.recordView(' '), throwsArgumentError);
      } finally {
        await service.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('failed storage can retry without counting a failed visit', () async {
    final directory = await Directory.systemTemp.createTemp('rankings_retry_');
    var fail = true;
    final service = BookRankingService(
      openDatabase: () async {
        if (fail) throw StateError('Storage unavailable');
        return databaseFactoryIo.openDatabase('${directory.path}/views.db');
      },
    );
    try {
      await service.recordView('a');
      expect(service.error, isNotNull);
      expect(service.viewsFor('a'), 0);
      fail = false;
      await service.load();
      await service.recordView('a');
      expect(service.error, isNull);
      expect(service.viewsFor('a'), 1);
    } finally {
      await service.close();
      await directory.delete(recursive: true);
    }
  });
}
