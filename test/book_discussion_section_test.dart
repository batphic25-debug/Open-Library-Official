import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_library_client/core/theme/app_theme.dart';
import 'package:open_library_client/features/books/services/book_discussion_service.dart';
import 'package:open_library_client/features/books/widgets/book_discussion_section.dart';
import 'package:sembast/sembast_memory.dart';

class PendingDiscussionService extends BookDiscussionService {
  PendingDiscussionService({this.discussion = const BookDiscussion()});

  final BookDiscussion discussion;
  final pending = Completer<BookDiscussion>();

  @override
  Future<BookDiscussion> load(String bookId) async => discussion;

  @override
  Future<BookDiscussion> addComment({
    required String bookId,
    required String userId,
    required String displayName,
    required String body,
    String? replyToId,
  }) => pending.future;
}

Widget host(BookDiscussionService service, {bool dark = false}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: BookDiscussionSection(
        bookId: 'book-1',
        bookTitle: 'Cuốn sách đang đọc',
        userId: 'alice',
        displayName: 'Alice',
        service: service,
      ),
    ),
  ),
);

void main() {
  for (final dark in [false, true]) {
    testWidgets('comment feed fits long names and keeps replies, dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final now = DateTime.now();
      final service = PendingDiscussionService(
        discussion: BookDiscussion(
          comments: [
            BookComment(
              id: 'older',
              userId: 'bob',
              displayName: 'Bob',
              body: 'Một góc nhìn khác.',
              createdAt: now.subtract(const Duration(hours: 3)),
            ),
            BookComment(
              id: 'parent',
              userId: 'alice',
              displayName: 'Nguyễn Thị Minh Anh với tên hiển thị rất dài',
              body: 'Bạn thích đoạn nào nhất?',
              createdAt: now.subtract(const Duration(minutes: 2)),
            ),
            BookComment(
              id: 'reply',
              userId: 'linh',
              displayName: 'Linh',
              body: 'Mình thích phần kết.',
              createdAt: now.subtract(const Duration(minutes: 1)),
              replyToId: 'parent',
            ),
          ],
        ),
      );
      await tester.pumpWidget(host(service, dark: dark));
      await tester.pumpAndSettle();
      expect(find.text('Cộng đồng đang nói gì'), findsOneWidget);
      expect(find.text('Cuốn sách đang đọc'), findsNWidgets(2));
      expect(find.text('2 phút trước'), findsOneWidget);
      expect(find.text('3 giờ trước'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Bạn thích đoạn nào nhất?')).dy,
        lessThan(tester.getTopLeft(find.text('Một góc nhìn khác.')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Mình thích phần kết.')).dy,
        lessThan(tester.getTopLeft(find.text('Một góc nhìn khác.')).dy),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Trả lời').first);
      await tester.tap(find.text('Trả lời').first);
      await tester.pumpAndSettle();
      expect(
        find.text('Đang trả lời Nguyễn Thị Minh Anh với tên hiển thị rất dài'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byTooltip('Hủy trả lời'));
      await tester.tap(find.byTooltip('Hủy trả lời'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đang trả lời'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('discussion fits small screens with large text, dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final service = BookDiscussionService(
        openDatabase: () => newDatabaseFactoryMemory().openDatabase('small'),
      );
      await tester.pumpWidget(host(service, dark: dark));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('Đánh giá 4 sao'));
      await tester.tap(find.byTooltip('Đánh giá 4 sao'));
      await tester.pumpAndSettle();
      expect(find.text('4.0'), findsOneWidget);
      expect(
        tester
            .widgetList<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .map((bar) => bar.value),
        [0, 1, 0, 0, 0],
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('failed send keeps draft and allows retry', (tester) async {
    final service = PendingDiscussionService();
    await tester.pumpWidget(host(service));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Cảm nhận của mình.');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Gửi bình luận'));
    await tester.tap(find.text('Gửi bình luận'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    service.pending.completeError(StateError('Offline'));
    await tester.pumpAndSettle();
    expect(find.text('Cảm nhận của mình.'), findsOneWidget);
    expect(
      find.text('Chưa gửi được bình luận. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}
