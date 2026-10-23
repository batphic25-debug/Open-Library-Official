import 'package:sembast/sembast.dart';

import '../../bookshelf/bookshelf_database.dart';

class BookRating {
  const BookRating({
    required this.userId,
    required this.displayName,
    required this.stars,
  });

  final String userId;
  final String displayName;
  final int stars;

  Map<String, Object?> toJson() => {
    'userId': userId,
    'displayName': displayName,
    'stars': stars,
  };

  factory BookRating.fromJson(Map<String, dynamic> json) => BookRating(
    userId: json['userId'] as String,
    displayName: json['displayName'] as String,
    stars: json['stars'] as int,
  );
}

class BookComment {
  const BookComment({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.body,
    required this.createdAt,
    this.replyToId,
  });

  final String id;
  final String userId;
  final String displayName;
  final String body;
  final DateTime createdAt;
  final String? replyToId;

  Map<String, Object?> toJson() => {
    'id': id,
    'userId': userId,
    'displayName': displayName,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'replyToId': replyToId,
  };

  factory BookComment.fromJson(Map<String, dynamic> json) => BookComment(
    id: json['id'] as String,
    userId: json['userId'] as String,
    displayName: json['displayName'] as String,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    replyToId: json['replyToId'] as String?,
  );
}

class BookDiscussion {
  const BookDiscussion({this.ratings = const [], this.comments = const []});

  final List<BookRating> ratings;
  final List<BookComment> comments;

  double get averageRating => ratings.isEmpty
      ? 0
      : ratings.fold<int>(0, (sum, rating) => sum + rating.stars) /
            ratings.length;

  int? ratingBy(String userId) {
    for (final rating in ratings) {
      if (rating.userId == userId) return rating.stars;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'ratings': ratings.map((rating) => rating.toJson()).toList(),
    'comments': comments.map((comment) => comment.toJson()).toList(),
  };

  factory BookDiscussion.fromJson(Map<String, Object?>? json) {
    if (json == null) return const BookDiscussion();
    return BookDiscussion(
      ratings: (json['ratings'] as List? ?? const [])
          .map(
            (value) =>
                BookRating.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList(),
      comments: (json['comments'] as List? ?? const [])
          .map(
            (value) =>
                BookComment.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList(),
    );
  }
}

/// Shared by demo accounts on one device. No server or cross-device sync.
class BookDiscussionService {
  BookDiscussionService({Future<Database> Function()? openDatabase})
    : _openDatabase =
          openDatabase ?? (() => openShelfDatabase('community-discussions'));

  final Future<Database> Function() _openDatabase;
  Future<Database>? _opening;
  Future<Database> get _database => _opening ??= _openDatabase();
  final _store = stringMapStoreFactory.store('book_discussions');

  Future<BookDiscussion> load(String bookId) async {
    if (bookId.isEmpty) throw ArgumentError.value(bookId, 'bookId');
    return BookDiscussion.fromJson(
      await _store.record(bookId).get(await _database),
    );
  }

  Future<BookDiscussion> setRating({
    required String bookId,
    required String userId,
    required String displayName,
    required int stars,
  }) async {
    if (bookId.isEmpty ||
        userId.isEmpty ||
        displayName.trim().isEmpty ||
        stars < 1 ||
        stars > 5) {
      throw ArgumentError('Đánh giá không hợp lệ.');
    }
    final database = await _database;
    return database.transaction((txn) async {
      final record = _store.record(bookId);
      final discussion = BookDiscussion.fromJson(await record.get(txn));
      final ratings = [...discussion.ratings]
        ..removeWhere((rating) => rating.userId == userId)
        ..add(
          BookRating(
            userId: userId,
            displayName: displayName.trim(),
            stars: stars,
          ),
        );
      final updated = BookDiscussion(
        ratings: ratings,
        comments: discussion.comments,
      );
      await record.put(txn, updated.toJson());
      return updated;
    });
  }

  Future<BookDiscussion> addComment({
    required String bookId,
    required String userId,
    required String displayName,
    required String body,
    String? replyToId,
  }) async {
    final text = body.trim();
    if (bookId.isEmpty ||
        userId.isEmpty ||
        displayName.trim().isEmpty ||
        text.isEmpty ||
        text.length > 500) {
      throw ArgumentError('Bình luận cần từ 1 đến 500 ký tự.');
    }
    final database = await _database;
    return database.transaction((txn) async {
      final record = _store.record(bookId);
      final discussion = BookDiscussion.fromJson(await record.get(txn));
      String? parentId;
      if (replyToId != null) {
        final parent = discussion.comments.where(
          (item) => item.id == replyToId,
        );
        if (parent.isEmpty) {
          throw ArgumentError('Bình luận gốc không còn tồn tại.');
        }
        parentId = parent.first.replyToId ?? parent.first.id;
      }
      var id = DateTime.now().toUtc().microsecondsSinceEpoch;
      while (discussion.comments.any((item) => item.id == '$id')) {
        id++;
      }
      final updated = BookDiscussion(
        ratings: discussion.ratings,
        comments: [
          ...discussion.comments,
          BookComment(
            id: '$id',
            userId: userId,
            displayName: displayName.trim(),
            body: text,
            createdAt: DateTime.now().toUtc(),
            replyToId: parentId,
          ),
        ],
      );
      await record.put(txn, updated.toJson());
      return updated;
    });
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening != null) await (await opening).close();
  }
}
