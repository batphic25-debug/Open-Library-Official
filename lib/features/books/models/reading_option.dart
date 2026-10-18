import 'book.dart';

class ReadingOption {
  const ReadingOption({
    required this.url,
    required this.editionId,
    required this.status,
    required this.exactEdition,
  });
  final Uri url;
  final String editionId;
  final String status;
  final bool exactEdition;

  String get label => switch (status) {
    'full access' => 'Đọc miễn phí',
    'lendable' => 'Mượn để đọc',
    'checked out' => 'Đang được mượn',
    _ => 'Quyền truy cập hạn chế',
  };
  String get description => switch (status) {
    'full access' => 'Đọc bản số do thư viện cung cấp.',
    'lendable' =>
      'Cần đăng nhập tài khoản Open Library / Internet Archive và mượn sách.',
    'checked out' => 'Bản này hiện chưa sẵn sàng. Kiểm tra lại tại thư viện.',
    _ => 'Có thể chỉ xem trước hoặc không được đọc toàn bộ. Thư viện quyết định quyền truy cập.',
  };

  static List<ReadingOption> parse(Map<String, dynamic> data, Book book) {
    if (data['items'] is! List) {
      throw const FormatException('Invalid reading response');
    }
    final options = <ReadingOption>[];
    final seen = <String>{};
    for (final item in data['items'] as List) {
      if (item is! Map) continue;
      try {
        final workId = libraryKey(item['ol-work-id'], 'works', 'W');
        if (workId != book.id) continue;
        final editionId = libraryKey(item['ol-edition-id'], 'books', 'M');
        final uri = Uri.tryParse(
          item['itemURL'] is String ? item['itemURL'] as String : '',
        );
        if (uri == null ||
            !['http', 'https'].contains(uri.scheme) ||
            uri.userInfo.isNotEmpty ||
            ![
              'archive.org',
              'www.archive.org',
              'openlibrary.org',
              'www.openlibrary.org',
            ].contains(uri.host) ||
            (uri.hasPort && uri.port != 80 && uri.port != 443)) {
          continue;
        }
        final status = item['status'];
        if (![
          'full access',
          'lendable',
          'checked out',
          'restricted',
        ].contains(status)) {
          continue;
        }
        final url = uri.replace(scheme: 'https', port: 443);
        if (!seen.add(url.toString())) continue;
        options.add(
          ReadingOption(
            url: url,
            editionId: editionId,
            status: status as String,
            exactEdition: editionId == book.selectedEdition?.id,
          ),
        );
      } on FormatException {
        continue;
      }
    }
    return options;
  }
}
