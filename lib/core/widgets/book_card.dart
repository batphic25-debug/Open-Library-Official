import 'package:open_library_client/core/l10n/app_strings.dart';
import 'package:flutter/material.dart';

import '../../features/books/models/book.dart';
import '../theme/app_theme.dart';
import 'book_cover.dart';

class BookCard extends StatelessWidget {
  const BookCard({
    super.key,
    required this.book,
    required this.onTap,
    this.compact = false,
    this.onSave,
    this.saved = false,
    this.saving = false,
  });
  final Book book;
  final VoidCallback onTap;
  final bool compact;
  final VoidCallback? onSave;
  final bool saved;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    if (compact) return _libraryCard(context);
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                book.title,
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 15 : 17,
                  height: 1.25,
                ),
              ),
            ),
            if (!compact && onSave != null)
              SizedBox(
                width: 32,
                height: 36,
                child: saving
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: saved
                            ? context.tr("Đã có trong tủ sách")
                            : context.tr("Lưu vào tủ sách"),
                        onPressed: onSave,
                        icon: Icon(
                          saved ? Icons.bookmark : Icons.bookmark_border,
                          color: saved
                              ? AppTheme.accent
                              : Theme.of(context).colorScheme.onSurface,
                          size: 25,
                        ),
                      ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          context.tr(book.authorLabel),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: compact ? 13 : 16,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF343544)
                  : AppTheme.softSurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              book.categories.isNotEmpty
                  ? context.tr(book.categories.first)
                  : book.firstPublishYear != null
                  ? context.tr("Xuất bản {0}", [book.firstPublishYear])
                  : context.tr("Sách"),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
    return Semantics(
      button: true,
      child: Material(
        color: compact
            ? Colors.transparent
            : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: compact
                ? Colors.transparent
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: EdgeInsets.all(compact ? 0 : 12),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 2 / 3,
                        child: BookCover(
                          book: book,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      const SizedBox(height: 10),
                      details,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BookCover(book: book, width: 98, height: 138),
                      const SizedBox(width: 14),
                      Expanded(child: details),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _libraryCard(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < 170 ? 10.0 : 14.0;
        final titleSize = constraints.maxWidth < 170 ? 16.0 : 19.0;
        final titleHeight =
            MediaQuery.textScalerOf(context).scale(titleSize) * 1.13 * 2 + 2;
        return Semantics(
          button: true,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: dark ? 0 : 4,
            shadowColor: const Color(0x1A24304A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: dark ? Colors.white12 : const Color(0xFFF0DFD8),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 2 / 3,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          BookCover(
                            book: book,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Material(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(13),
                              child: saving
                                  ? const SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: Padding(
                                        padding: EdgeInsets.all(10),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : IconButton(
                                      tooltip: saved
                                          ? context.tr("Đã có trong tủ sách")
                                          : context.tr("Lưu vào tủ sách"),
                                      onPressed: onSave,
                                      icon: Icon(
                                        saved
                                            ? Icons.bookmark_rounded
                                            : Icons.bookmark_border_rounded,
                                        color: AppTheme.accent,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: titleHeight,
                      child: Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          height: 1.13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      context.tr(book.authorLabel),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 14),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: dark
                                  ? const Color(0xFF493138)
                                  : const Color(0xFFFFEEE9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              context.tr(book.categories.firstOrNull ?? "Sách"),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppTheme.accent,
                          size: 22,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
