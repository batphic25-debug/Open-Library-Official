import 'package:open_library_client/core/l10n/app_strings.dart';
import 'package:flutter/material.dart';

class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.categories,
    required this.selected,
    required this.onChanged,
  });
  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = dark ? const Color(0xFFFFC45A) : const Color(0xFF8A5B00);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final category in <String?>[null, ...categories])
              Semantics(
                button: true,
                selected: selected == category,
                child: InkWell(
                  onTap: () => onChanged(category),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: constraints.maxWidth >= 600
                        ? constraints.maxWidth / 4
                        : null,
                    constraints: const BoxConstraints(minHeight: 52),
                    padding: EdgeInsets.symmetric(
                      horizontal: constraints.maxWidth >= 600 ? 20 : 8,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: selected == category
                                ? accent
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 4,
                        ),
                        child: Text(
                          context.tr(category ?? "Tất cả"),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: constraints.maxWidth >= 600 ? 22 : 16,
                            color: selected == category
                                ? accent
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: selected == category
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
