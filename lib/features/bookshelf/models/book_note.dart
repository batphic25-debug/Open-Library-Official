class BookNote {
  const BookNote({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String userId;
  final String bookId;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'userId': userId,
    'bookId': bookId,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
  factory BookNote.fromJson(Map<String, dynamic> json) => BookNote(
    id: json['id'] as String,
    userId: json['userId'] as String,
    bookId: json['bookId'] as String,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}
