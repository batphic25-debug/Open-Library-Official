import 'package:flutter/material.dart';

import '../models/book.dart';

class EditionMetadata extends StatelessWidget {
  const EditionMetadata({super.key, required this.edition});
  final BookEdition? edition;

  @override
  Widget build(BuildContext context) {
    final values = {
      'Phiên bản': edition?.title,
      'Ngôn ngữ ấn bản': edition?.languageLabel,
      'Số trang': edition?.pages?.toString(),
      'Nhà xuất bản': edition?.publishers.join(', '),
      'Ngày xuất bản': edition?.publishDate,
      'ISBN': edition?.isbn.join(' · '),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in values.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${entry.key}: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: entry.value == null || entry.value!.isEmpty
                        ? 'Chưa có dữ liệu'
                        : entry.value,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
