String? sourceText(dynamic value) {
  if (value is Map) value = value['value'];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

List<String> sourceStrings(dynamic value) => value is List
    ? value.whereType<String>().where((item) => item.trim().isNotEmpty).toList()
    : const [];

String libraryKey(dynamic value, String collection, String suffix) {
  final text = value is String ? value : '';
  final key = text.startsWith('OL') ? '/$collection/$text' : text;
  if (!RegExp('^/$collection/OL[0-9]+$suffix\$').hasMatch(key)) {
    throw const FormatException('Invalid Open Library key');
  }
  return key;
}

class Book {
  const Book({
    required this.id,
    required this.title,
    this.authors = const [],
    this.authorIds = const [],
    this.categories = const [],
    this.description,
    this.descriptionSource,
    this.firstPublishYear,
    this.coverId,
    this.coverAsset,
    this.coverEditionKey,
    this.coverIsIllustration = false,
    this.selectedEdition,
  });

  final String id;
  final String title;
  final List<String> authors;
  final List<String> authorIds;
  final List<String> categories;
  final String? description;
  final String? descriptionSource;
  final int? firstPublishYear;
  final int? coverId;
  final String? coverAsset;
  final String? coverEditionKey;
  final bool coverIsIllustration;
  final BookEdition? selectedEdition;

  String get authorLabel =>
      authors.isEmpty ? 'Chưa rõ tác giả' : authors.join(', ');
  Uri get sourceUrl =>
      Uri.https('openlibrary.org', libraryKey(id, 'works', 'W'));
  String? get coverUrl {
    if (selectedEdition != null) return selectedEdition!.coverUrl;
    if (coverId != null && coverId! > 0) {
      return 'https://covers.openlibrary.org/b/id/$coverId-M.jpg?default=false';
    }
    if (coverEditionKey != null &&
        RegExp(r'^OL\d+M$').hasMatch(coverEditionKey!)) {
      return 'https://covers.openlibrary.org/b/olid/$coverEditionKey-M.jpg?default=false';
    }
    return null;
  }

  Book withEdition(BookEdition edition) {
    if (!edition.workIds.contains(id)) {
      throw const FormatException('Edition does not belong to work');
    }
    return Book(
      id: id,
      title: title,
      authors: authors,
      authorIds: authorIds,
      categories: categories,
      description: description,
      descriptionSource: descriptionSource,
      firstPublishYear: firstPublishYear,
      selectedEdition: edition,
    );
  }

  static int? _coverId(dynamic url) {
    final match = RegExp(r'/b/id/(\d+)').firstMatch(url is String ? url : '');
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  factory Book.fromApiJson(
    Map<String, dynamic> json, {
    Map<String, String> categoryNames = const {},
  }) {
    final edition = json['selectedEdition'];
    return Book(
      id: libraryKey(json['workId'], 'works', 'W'),
      title:
          sourceText(json['title']) ??
          (throw const FormatException('Missing title')),
      authors: sourceStrings(json['authors']),
      categories: sourceStrings(json['categories'])
          .map(
            (slug) =>
                categoryNames[slug] ??
                const {
                  'science-fiction': 'Khoa học viễn tưởng',
                  'horror': 'Kinh dị',
                  'fantasy': 'Kỳ ảo',
                  'self-development': 'Phát triển bản thân',
                  'children': 'Thiếu nhi',
                  'mystery': 'Trinh thám',
                  'finance': 'Tài chính',
                  'literature': 'Văn học',
                }[slug] ??
                slug,
          )
          .toList(),
      description:
          sourceText(json['summaryVi']) ?? sourceText(json['description']),
      descriptionSource:
          sourceText(json['descriptionSource']) ??
          (sourceText(json['description']) == null ? null : 'Open Library'),
      firstPublishYear: json['firstPublishYear'] is int
          ? json['firstPublishYear'] as int
          : null,
      coverId: _coverId(json['coverUrl']),
      coverAsset: sourceText(json['localCoverKey']),
      coverIsIllustration: sourceText(json['localCoverKey']) != null,
      selectedEdition: edition is Map
          ? BookEdition.fromApiJson(Map<String, dynamic>.from(edition))
          : null,
    );
  }

  factory Book.fromApiSearchJson(Map<String, dynamic> json) => Book(
    id: libraryKey(json['workId'], 'works', 'W'),
    title:
        sourceText(json['title']) ??
        (throw const FormatException('Missing title')),
    authors: sourceStrings(json['authors']),
    firstPublishYear: json['firstPublishYear'] is int
        ? json['firstPublishYear'] as int
        : null,
    coverId: _coverId(json['coverUrl']),
  );

  factory Book.fromSearchJson(Map<String, dynamic> json) {
    final title = sourceText(json['title']);
    if (title == null) throw const FormatException('Missing book title');
    return Book(
      id: libraryKey(json['key'], 'works', 'W'),
      title: title,
      authors: sourceStrings(json['author_name']),
      authorIds: sourceStrings(json['author_key'])
          .map((key) => libraryKey(key, 'authors', 'A'))
          .toList(),
      categories: sourceStrings(json['subject']).take(3).toList(),
      firstPublishYear: json['first_publish_year'] is int
          ? json['first_publish_year'] as int
          : null,
      coverId: json['cover_i'] is int && (json['cover_i'] as int) > 0
          ? json['cover_i'] as int
          : null,
      coverEditionKey: sourceText(json['cover_edition_key']),
    );
  }

  factory Book.fromCatalogJson(Map<String, dynamic> json) {
    final title = sourceText(json['title']);
    final description = sourceText(json['description']);
    if (title == null ||
        description == null ||
        sourceText(json['descriptionSource']) == null) {
      throw const FormatException('Invalid catalog description or title');
    }
    final book = Book(
      id: libraryKey(json['id'], 'works', 'W'),
      title: title,
      authors: sourceStrings(json['authors']),
      categories: sourceStrings(json['categories']),
      description: description,
      descriptionSource: json['descriptionSource'] as String,
      firstPublishYear: json['firstPublishYear'] is int
          ? json['firstPublishYear'] as int
          : null,
      coverAsset: sourceText(json['coverAsset']),
      coverIsIllustration: json['coverIsIllustration'] == true,
      selectedEdition: json['selectedEdition'] is Map<String, dynamic>
          ? BookEdition.fromJson(
              json['selectedEdition'] as Map<String, dynamic>,
            )
          : null,
    );
    if (book.selectedEdition != null &&
        !book.selectedEdition!.workIds.contains(book.id)) {
      throw const FormatException('Catalog edition belongs to another work');
    }
    return book;
  }
}

class BookEdition {
  const BookEdition({
    required this.id,
    required this.workIds,
    this.title,
    this.isbn = const [],
    this.publishers = const [],
    this.publishDate,
    this.pages,
    this.languages = const [],
    this.coverId,
  });
  final String id;
  final List<String> workIds;
  final String? title;
  final List<String> isbn;
  final List<String> publishers;
  final String? publishDate;
  final int? pages;
  final List<String> languages;
  final int? coverId;

  String get coverUrl => coverId != null && coverId! > 0
      ? 'https://covers.openlibrary.org/b/id/$coverId-M.jpg?default=false'
      : 'https://covers.openlibrary.org/b/olid/${id.split('/').last}-M.jpg?default=false';
  Uri get sourceUrl =>
      Uri.https('openlibrary.org', libraryKey(id, 'books', 'M'));
  String get languageLabel => languageLabelFor((label) => label);

  String languageLabelFor(String Function(String) translate) => languages
      .map(
        (code) =>
            const {
              'eng': 'Tiếng Anh',
              'vie': 'Tiếng Việt',
              'fre': 'Tiếng Pháp',
              'ger': 'Tiếng Đức',
              'spa': 'Tiếng Tây Ban Nha',
              'ita': 'Tiếng Ý',
              'jpn': 'Tiếng Nhật',
              'chi': 'Tiếng Trung',
              'rus': 'Tiếng Nga',
            }[code] ??
            code,
      )
      .map(translate)
      .join(', ');

  factory BookEdition.fromJson(Map<String, dynamic> json) {
    final covers = json['covers'];
    final coverIds = covers is List
        ? covers.whereType<int>().where((id) => id > 0)
        : const <int>[];
    return BookEdition(
      id: libraryKey(json['key'], 'books', 'M'),
      workIds: json['works'] is List
          ? (json['works'] as List)
                .whereType<Map>()
                .map((work) => libraryKey(work['key'], 'works', 'W'))
                .toList()
          : const [],
      title: sourceText(json['title']),
      isbn: {
        ...sourceStrings(json['isbn_13']),
        ...sourceStrings(json['isbn_10']),
      }.toList(),
      publishers: sourceStrings(json['publishers']),
      publishDate: sourceText(json['publish_date']),
      pages:
          json['number_of_pages'] is int && (json['number_of_pages'] as int) > 0
          ? json['number_of_pages'] as int
          : null,
      languages: json['languages'] is List
          ? (json['languages'] as List)
                .whereType<Map>()
                .map((language) => sourceText(language['key'])?.split('/').last)
                .whereType<String>()
                .toList()
          : const [],
      coverId: coverIds.isEmpty ? null : coverIds.first,
    );
  }

  factory BookEdition.fromApiJson(Map<String, dynamic> json) => BookEdition(
    id: libraryKey(json['editionId'], 'books', 'M'),
    workIds: [libraryKey(json['workId'], 'works', 'W')],
    title: sourceText(json['title']),
    isbn: {
      ...sourceStrings(json['isbn13']),
      ...sourceStrings(json['isbn10']),
    }.toList(),
    publishers: sourceStrings(json['publishers']),
    publishDate: sourceText(json['publishDate']),
    pages: json['pageCount'] is int ? json['pageCount'] as int : null,
    languages: sourceStrings(json['languages']),
    coverId: Book._coverId(json['coverUrl']),
  );
}

class BookAuthor {
  const BookAuthor({
    required this.id,
    this.name,
    this.biography,
    this.birthDate,
    this.deathDate,
  });
  final String id;
  final String? name;
  final String? biography;
  final String? birthDate;
  final String? deathDate;
  factory BookAuthor.fromJson(Map<String, dynamic> json) => BookAuthor(
    id: libraryKey(json['key'], 'authors', 'A'),
    name: sourceText(json['name']),
    biography: sourceText(json['bio']),
    birthDate: sourceText(json['birth_date']),
    deathDate: sourceText(json['death_date']),
  );
}
