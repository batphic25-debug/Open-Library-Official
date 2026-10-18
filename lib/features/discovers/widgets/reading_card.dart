import 'package:flutter/material.dart';

import '../../../core/widgets/book_cover.dart';
import '../../../core/theme/app_theme.dart';
import '../../books/models/book.dart';

/// Supplied by the bookshelf owner; this view never saves or invents progress.
class ReadingBook {
  const ReadingBook({
    required this.book,
    required this.pagesRead,
    this.totalPages,
  });
  final Book book;
  final int pagesRead;
  final int? totalPages;
}

class ReadingCard extends StatelessWidget {
  const ReadingCard({
    super.key,
    required this.reading,
    required this.onTap,
    this.onUpdate,
  });
  final ReadingBook reading;
  final VoidCallback onTap;
  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context) {
    final total = reading.totalPages;
    final pages = reading.pagesRead < 0 ? 0 : reading.pagesRead;
    final progress = total != null && total > 0
        ? (pages / total).clamp(0.0, 1.0)
        : null;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      shadowColor: const Color(0x12000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              BookCover(book: reading.book, width: 86, height: 128),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reading.book.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    Text(
                      reading.book.authorLabel,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (progress != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 7,
                              color: AppTheme.accent,
                              backgroundColor: const Color(0xFFECEDEF),
                              borderRadius: BorderRadius.circular(8),
                              semanticsLabel:
                                  'Tiến độ đọc: $pages/$total trang',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(progress * 100).round()}%',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Trang $pages/$total',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ] else
                      Text('Đã đọc $pages trang'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: onUpdate ?? onTap,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF343544)
                            : AppTheme.softSurface,
                        foregroundColor: Theme.of(context)
                            .colorScheme
                            .onSurface,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 2,
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          Text('Cập nhật'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
