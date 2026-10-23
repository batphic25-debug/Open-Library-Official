import 'package:open_library_client/core/l10n/app_strings.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../books/services/open_library_service.dart';

class SearchFilters extends StatelessWidget {
  const SearchFilters({
    super.key,
    required this.language,
    required this.sort,
    required this.onLanguageChanged,
    required this.onSortChanged,
  });
  final String? language;
  final BookSort sort;
  final ValueChanged<String?> onLanguageChanged;
  final ValueChanged<BookSort> onSortChanged;

  static const languages = {
    'all': 'Mọi ngôn ngữ',
    'vie': 'Tiếng Việt',
    'eng': 'Tiếng Anh',
    'fre': 'Tiếng Pháp',
    'ger': 'Tiếng Đức',
    'spa': 'Tiếng Tây Ban Nha',
  };
  static const sorts = {
    BookSort.relevance: 'Liên quan nhất',
    BookSort.newest: 'Mới nhất',
    BookSort.oldest: 'Cũ nhất',
  };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
      final width = largeText
          ? constraints.maxWidth
          : (constraints.maxWidth - 10) / 2;
      return PopupMenuTheme(
        data: PopupMenuThemeData(
          color: Theme.of(context).colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          shadowColor: const Color(0x24000000),
          elevation: 8,
          position: PopupMenuPosition.under,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          textStyle: TextStyle(
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            SizedBox(
              width: width,
              child: PopupMenuButton<String>(
                tooltip: context.tr("Lọc ngôn ngữ"),
                offset: const Offset(0, 8),
                constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
                initialValue: language ?? 'all',
                onSelected: (value) =>
                    onLanguageChanged(value == 'all' ? null : value),
                itemBuilder: (_) => languages.entries
                    .map(
                      (entry) => CheckedPopupMenuItem(
                        value: entry.key,
                        checked: entry.key == (language ?? 'all'),
                        child: Text(
                          context.tr(entry.value),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: entry.key == (language ?? 'all')
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: entry.key == (language ?? 'all')
                                ? AppTheme.accent
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                child: _FilterLabel(
                  icon: Icons.language,
                  text: language == null
                      ? context.tr("Ngôn ngữ")
                      : context.tr(languages[language]!),
                ),
              ),
            ),
            SizedBox(
              width: width,
              child: PopupMenuButton<BookSort>(
                tooltip: context.tr("Sắp xếp sách"),
                offset: const Offset(0, 8),
                constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
                initialValue: sort,
                onSelected: onSortChanged,
                itemBuilder: (_) => sorts.entries
                    .map(
                      (entry) => CheckedPopupMenuItem(
                        value: entry.key,
                        checked: entry.key == sort,
                        child: Text(
                          context.tr(entry.value),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: entry.key == sort
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: entry.key == sort
                                ? AppTheme.accent
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                child: _FilterLabel(
                  icon: Icons.sort,
                  text: sort == BookSort.relevance
                      ? context.tr("Sắp xếp")
                      : context.tr(sorts[sort]!),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 48),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF343544)
          : AppTheme.softSurface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        const SizedBox(width: 4),
        const Icon(Icons.expand_more, size: 18),
      ],
    ),
  );
}
