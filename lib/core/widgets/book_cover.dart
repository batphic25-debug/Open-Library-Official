import 'package:flutter/material.dart';

import '../../features/books/models/book.dart';
import '../../features/books/data/sample_books.dart';

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.book,
    this.width = 84,
    this.height = 124,
  });
  final Book book;
  final double width;
  final double height;

  static final _catalog = SampleBooks.load();

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Book>>(
    future: _catalog,
    builder: (context, snapshot) {
      final catalogBook = snapshot.data
          ?.where((entry) => entry.id == book.id)
          .firstOrNull;
      return _cover(
        coverAsset: catalogBook?.coverAsset ?? book.coverAsset,
        isIllustration:
            catalogBook?.coverIsIllustration ?? book.coverIsIllustration,
        loadingCatalog: snapshot.connectionState != ConnectionState.done,
      );
    },
  );

  Widget _cover({
    String? coverAsset,
    required bool isIllustration,
    required bool loadingCatalog,
  }) {
    final fallback = _DesignedCover(book: book);
    final cover = Semantics(
      label: isIllustration
          ? 'Bìa minh họa ${book.title}'
          : 'Bìa sách ${book.title}',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: width,
          height: height,
          child: coverAsset != null
              ? Image.asset(
                  coverAsset,
                  fit: BoxFit.cover,
                  cacheWidth: 400,
                  excludeFromSemantics: true,
                  errorBuilder: (_, error, stack) => fallback,
                )
              : !loadingCatalog && book.coverUrl != null
              ? Image.network(
                  book.coverUrl!,
                  fit: BoxFit.cover,
                  cacheWidth: 400,
                  excludeFromSemantics: true,
                  errorBuilder: (_, error, stack) => fallback,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : fallback,
                )
              : fallback,
        ),
      ),
    );
    return isIllustration && coverAsset != null
        ? Tooltip(message: 'Ảnh minh họa có sẵn trong dự án', child: cover)
        : cover;
  }
}

class _DesignedCover extends StatelessWidget {
  const _DesignedCover({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFF244F64),
      Color(0xFF643E58),
      Color(0xFF345D50),
      Color(0xFF744B32),
      Color(0xFF3E4774),
    ];
    final color =
        colors[book.id.codeUnits.fold<int>(0, (sum, unit) => sum + unit) %
            colors.length];
    return Tooltip(
      message: 'Bìa thay thế · Chưa có ảnh bìa',
      child: Semantics(
        label: 'Bìa thay thế',
        child: ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, Color.lerp(color, Colors.black, .35)!],
              ),
              border: const Border(
                left: BorderSide(color: Color(0x40FFFFFF), width: 5),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 116,
                height: 172,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.auto_stories_outlined,
                        size: 22,
                        color: Color(0xFFF2D5A0),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Center(
                          child: RichText(
                            textAlign: TextAlign.center,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              text: book.title,
                              style: DefaultTextStyle.of(context).style
                                  .copyWith(
                                    fontSize: 15,
                                    height: 1.15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          text: book.authorLabel,
                          style: DefaultTextStyle.of(context).style.copyWith(
                            fontSize: 9,
                            color: const Color(0xFFF2D5A0),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'BÌA THAY THẾ',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: 7,
                          letterSpacing: 1,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
