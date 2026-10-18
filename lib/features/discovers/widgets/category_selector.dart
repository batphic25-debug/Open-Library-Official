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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final category in <String?>[null, ...categories])
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ChoiceChip(
                label: Text(category ?? 'Tất cả'),
                selected: selected == category,
                showCheckmark: false,
                selectedColor: dark
                    ? const Color(0xFF493138)
                    : const Color(0xFFFFF3F1),
                backgroundColor: dark
                    ? theme.colorScheme.surface
                    : Colors.white,
                shape: const StadiumBorder(),
                side: BorderSide(
                  color: selected == category
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                  width: selected == category ? 1.5 : 1,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                labelStyle: TextStyle(
                  fontSize: 16,
                  color: selected == category
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                  fontWeight: selected == category
                      ? FontWeight.w700
                      : FontWeight.w600,
                ),
                onSelected: (_) => onChanged(category),
              ),
            ),
        ],
      ),
    );
  }
}
