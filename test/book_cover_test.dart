import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_library_client/core/widgets/book_cover.dart';
import 'package:open_library_client/features/books/data/sample_books.dart';
import 'package:open_library_client/features/books/models/book.dart';

void main() {
  testWidgets(
    'search, editions and previously saved books reuse the Discover cover by work ID',
    (tester) async {
      final catalog = (await tester.runAsync(SampleBooks.load))!;
      final original = catalog.first;
      final fromSearch = Book(
        id: original.id,
        title: 'Different API title',
        coverId: 999,
      );
      final anotherEdition = fromSearch.withEdition(
        BookEdition(
          id: '/books/OL999M',
          workIds: [original.id],
          pages: 200,
          coverId: 999,
        ),
      );
      for (final book in [original, fromSearch, anotherEdition]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(child: BookCover(book: book)),
          ),
        );
        await tester.pumpAndSettle();
        final provider =
            tester.widget<Image>(find.byType(Image)).image as ResizeImage;
        expect(
          (provider.imageProvider as AssetImage).assetName,
          original.coverAsset,
        );
        expect(
          find.byTooltip('Ảnh minh họa có sẵn trong dự án'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
      expect(anotherEdition.selectedEdition!.pages, 200);
      expect(anotherEdition.coverUrl, contains('/999-M.jpg'));
    },
  );

  testWidgets('unknown work never borrows a cover based on its title', (
    tester,
  ) async {
    final catalog = (await tester.runAsync(SampleBooks.load))!;
    final book = Book(id: '/works/OL999999999W', title: catalog.first.title);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: BookCover(book: book)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.text('BÌA THAY THẾ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
