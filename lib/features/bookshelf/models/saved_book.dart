import '../../books/models/book.dart';

enum ReadingStatus {
  wantToRead('Muốn đọc'),
  reading('Đang đọc'),
  read('Đã đọc');

  const ReadingStatus(this.label);
  final String label;
}

class SavedBook {
  SavedBook({
    required this.userId,
    required this.book,
    required this.status,
    required this.pagesRead,
    required this.addedAt,
    required this.updatedAt,
    this.estimatedTotalPages,
    this.version = 1,
  }) {
    libraryKey(book.id, 'works', 'W');
    if (userId.isEmpty ||
        book.title.trim().isEmpty ||
        pagesRead < 0 ||
        (estimatedTotalPages != null && estimatedTotalPages! <= 0) ||
        (totalPages != null && pagesRead > totalPages!) ||
        (book.selectedEdition != null &&
            !book.selectedEdition!.workIds.contains(book.id))) {
      throw const FormatException('Dữ liệu sách đã lưu không hợp lệ.');
    }
  }

  final String userId;
  final Book book;
  final ReadingStatus status;
  final int pagesRead;
  // Reading units for bundled text without an edition page count.
  final int? estimatedTotalPages;
  final int version;
  final DateTime addedAt;
  final DateTime updatedAt;
  String get id => book.id;
  String? get editionId => book.selectedEdition?.id;
  int? get totalPages {
    final pages = book.selectedEdition?.pages;
    return pages != null && pages > 0 ? pages : estimatedTotalPages;
  }

  bool get totalPagesEstimated =>
      (book.selectedEdition?.pages ?? 0) <= 0 && estimatedTotalPages != null;

  double? get progress => totalPages == null ? null : pagesRead / totalPages!;

  SavedBook copyWith({Book? book, ReadingStatus? status, int? pagesRead}) =>
      SavedBook(
        userId: userId,
        book: book ?? this.book,
        status: status ?? this.status,
        pagesRead: pagesRead ?? this.pagesRead,
        estimatedTotalPages: book == null ? estimatedTotalPages : null,
        version: version,
        addedAt: addedAt,
        updatedAt: DateTime.now().toUtc(),
      );

  Map<String, Object?> toJson() {
    final edition = book.selectedEdition;
    return {
      'userId': userId,
      'status': status.name,
      'pagesRead': pagesRead,
      'estimatedTotalPages': estimatedTotalPages,
      'version': version,
      'addedAt': addedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'book': {
        'id': book.id,
        'title': book.title,
        'authors': book.authors,
        'authorIds': book.authorIds,
        'categories': book.categories,
        'description': book.description,
        'descriptionSource': book.descriptionSource,
        'firstPublishYear': book.firstPublishYear,
        'coverId': book.coverId,
        'coverAsset': book.coverAsset,
        'coverEditionKey': book.coverEditionKey,
        'coverIsIllustration': book.coverIsIllustration,
        'selectedEdition': edition == null
            ? null
            : {
                'key': edition.id,
                'works': edition.workIds.map((id) => {'key': id}).toList(),
                'title': edition.title,
                'isbn_13': edition.isbn,
                'publishers': edition.publishers,
                'publish_date': edition.publishDate,
                'number_of_pages': edition.pages,
                'languages': edition.languages
                    .map((code) => {'key': '/languages/$code'})
                    .toList(),
                'covers': [if (edition.coverId != null) edition.coverId],
              },
      },
    };
  }

  factory SavedBook.fromJson(Map<String, dynamic> json) {
    final data = Map<String, dynamic>.from(json['book'] as Map);
    return SavedBook(
      userId: json['userId'] as String,
      status: ReadingStatus.values.byName(json['status'] as String),
      pagesRead: json['pagesRead'] as int,
      estimatedTotalPages: json['estimatedTotalPages'] as int?,
      version: json['version'] as int? ?? 1,
      addedAt: DateTime.parse(json['addedAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      book: Book(
        id: data['id'] as String,
        title: data['title'] as String,
        authors: sourceStrings(data['authors']),
        authorIds: sourceStrings(data['authorIds']),
        categories: sourceStrings(data['categories']),
        description: data['description'] as String?,
        descriptionSource: data['descriptionSource'] as String?,
        firstPublishYear: data['firstPublishYear'] as int?,
        coverId: data['coverId'] as int?,
        coverAsset: data['coverAsset'] as String?,
        coverEditionKey: data['coverEditionKey'] as String?,
        coverIsIllustration: data['coverIsIllustration'] == true,
        selectedEdition: data['selectedEdition'] == null
            ? null
            : BookEdition.fromJson(
                Map<String, dynamic>.from(data['selectedEdition'] as Map),
              ),
      ),
    );
  }

  factory SavedBook.fromApiJson(Map<String, dynamic> json, String userId) {
    final status = switch (json['status']) {
      'want_to_read' => ReadingStatus.wantToRead,
      'reading' => ReadingStatus.reading,
      'finished' => ReadingStatus.read,
      _ => throw const FormatException('Invalid reading status'),
    };
    final book = Book.fromApiJson(
      Map<String, dynamic>.from(json['book'] as Map),
    );
    return SavedBook(
      userId: userId,
      book: book,
      status: status,
      pagesRead: json['pagesRead'] as int,
      estimatedTotalPages: book.selectedEdition?.pages == null
          ? json['totalPages'] as int?
          : null,
      version: json['version'] as int,
      addedAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
