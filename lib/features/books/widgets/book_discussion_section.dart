import 'package:open_library_client/core/l10n/app_strings.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/book_discussion_service.dart';

class BookDiscussionSection extends StatefulWidget {
  const BookDiscussionSection({
    super.key,
    required this.bookId,
    required this.userId,
    required this.displayName,
    this.bookTitle,
    this.service,
  });

  final String bookId;
  final String userId;
  final String displayName;
  final String? bookTitle;
  final BookDiscussionService? service;

  @override
  State<BookDiscussionSection> createState() => _BookDiscussionSectionState();
}

class _BookDiscussionSectionState extends State<BookDiscussionSection> {
  static const _blue = Color(0xFF3B82F6);
  static const _purple = Color(0xFFA855F7);
  late final BookDiscussionService _service =
      widget.service ?? BookDiscussionService();
  final _composer = TextEditingController();
  final _composerFocus = FocusNode();
  final _composerKey = GlobalKey();
  BookDiscussion? _discussion;
  BookComment? _replyTo;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Timer? _relativeTimeTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _relativeTimeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && (_discussion?.comments.isNotEmpty ?? false)) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _relativeTimeTimer?.cancel();
    _composer.dispose();
    _composerFocus.dispose();
    if (widget.service == null) unawaited(_service.close());
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final discussion = await _service.load(widget.bookId);
      if (mounted) setState(() => _discussion = discussion);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không tải được đánh giá và bình luận.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _rate(int stars) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final discussion = await _service.setRating(
        bookId: widget.bookId,
        userId: widget.userId,
        displayName: widget.displayName,
        stars: stars,
      );
      if (mounted) setState(() => _discussion = discussion);
    } catch (_) {
      if (mounted) {
        _message(context.tr("Chưa lưu được đánh giá. Vui lòng thử lại."));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_busy || _composer.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final discussion = await _service.addComment(
        bookId: widget.bookId,
        userId: widget.userId,
        displayName: widget.displayName,
        body: _composer.text,
        replyToId: _replyTo?.id,
      );
      if (!mounted) return;
      _composer.clear();
      _composerFocus.unfocus();
      setState(() {
        _discussion = discussion;
        _replyTo = null;
      });
    } catch (_) {
      if (mounted) {
        _message(context.tr("Chưa gửi được bình luận. Vui lòng thử lại."));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reply(BookComment comment) {
    setState(() => _replyTo = comment);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _composerKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      _composerFocus.requestFocus();
    });
  }

  Widget _comment(BookComment comment, {bool reply = false}) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final link = dark ? const Color(0xFFD8B4FE) : const Color(0xFF7E22CE);
    final date = comment.createdAt.toLocal();
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
    final elapsed = DateTime.now().difference(comment.createdAt);
    final timeLabel = elapsed.inMinutes < 1
        ? context.tr("Vừa xong")
        : elapsed.inMinutes < 60
        ? context.tr("{0} phút trước", [elapsed.inMinutes])
        : elapsed.inHours < 24
        ? context.tr("{0} giờ trước", [elapsed.inHours])
        : elapsed.inDays < 7
        ? context.tr("{0} ngày trước", [elapsed.inDays])
        : '${date.day}/${date.month}/${date.year}';
    return Container(
      margin: EdgeInsets.only(left: reply ? 18 : 0, top: reply ? 14 : 0),
      padding: EdgeInsets.only(left: reply ? 12 : 0),
      decoration: reply
          ? BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: _purple.withValues(alpha: .3),
                  width: 2,
                ),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!reply && widget.bookTitle != null) ...[
            Text(
              widget.bookTitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            comment.body,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.6),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: _purple.withValues(alpha: .25),
                      child: Text(
                        comment.displayName.characters.first.toUpperCase(),
                        style: TextStyle(
                          color: link,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        comment.displayName,
                        style: TextStyle(color: link),
                      ),
                    ),
                  ],
                ),
                Tooltip(
                  message: dateLabel,
                  child: Text(
                    timeLabel,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : () => _reply(comment),
              style: TextButton.styleFrom(foregroundColor: link),
              child: Text(context.tr("Trả lời")),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final discussion = _discussion;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xFF0E1726) : const Color(0xFFF4F7FC);
    final surface = dark ? const Color(0xFF172335) : Colors.white;
    final soft = dark ? const Color(0xFF1B2A40) : const Color(0xFFEEF4FF);
    final border = dark ? const Color(0xFF253750) : const Color(0xFFDCE5F3);
    final link = dark ? const Color(0xFFD8B4FE) : const Color(0xFF7E22CE);
    final myRating = discussion?.ratingBy(widget.userId);
    final ratingCounts = List<int>.filled(6, 0);
    for (final rating in discussion?.ratings ?? <BookRating>[]) {
      ratingCounts[rating.stars]++;
    }
    final parents =
        discussion?.comments
            .where((comment) => comment.replyToId == null)
            .toList() ??
        [];
    parents.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr("Đánh giá"),
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr("Chia sẻ cảm nhận của bạn về cuốn sách"),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: _blue))
          else if (_error != null)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: link),
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text(
                context.tr("{0} Thử lại", [context.trError(_error!)]),
              ),
            )
          else if (discussion != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: Colors.amber.shade700,
                        size: 30,
                      ),
                      Text(
                        discussion.ratings.isEmpty
                            ? context.tr("Chưa có đánh giá")
                            : discussion.averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        context.tr("({0} lượt)", [discussion.ratings.length]),
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (var stars = 5; stars >= 1; stars--)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Semantics(
                        label: context.tr("{0} sao: {1} lượt đánh giá", [
                          stars,
                          ratingCounts[stars],
                        ]),
                        excludeSemantics: true,
                        child: Row(
                          children: [
                            Text('$stars'),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Colors.amber.shade700,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: discussion.ratings.isEmpty
                                    ? 0
                                    : ratingCounts[stars] /
                                          discussion.ratings.length,
                                minHeight: 7,
                                borderRadius: BorderRadius.circular(8),
                                backgroundColor: border,
                                color: Colors.amber.shade700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text('${ratingCounts[stars]}'),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: border),
                  ),
                  Text(
                    context.tr("Đánh giá của bạn"),
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Wrap(
                    children: [
                      for (var stars = 1; stars <= 5; stars++)
                        Semantics(
                          selected: myRating == stars,
                          child: IconButton(
                            tooltip: context.tr("Đánh giá {0} sao", [stars]),
                            onPressed: _busy ? null : () => _rate(stars),
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              stars <= (myRating ?? 0)
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: Colors.amber.shade700,
                              size: 32,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    myRating == null
                        ? context.tr(
                            "Chạm vào sao để chia sẻ đánh giá của bạn.",
                          )
                        : context.tr(
                            "Bạn đã đánh giá {0}/5 sao. Chạm để thay đổi.",
                            [myRating],
                          ),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _purple,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr("Bình luận ({0})", [
                          discussion.comments.length,
                        ]),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr("Cộng đồng đang nói gì"),
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              key: _composerKey,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_replyTo != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.tr("Đang trả lời {0}", [
                              _replyTo!.displayName,
                            ]),
                            style: TextStyle(color: link),
                          ),
                        ),
                        IconButton(
                          tooltip: context.tr("Hủy trả lời"),
                          onPressed: _busy
                              ? null
                              : () => setState(() => _replyTo = null),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                  TextField(
                    enabled: !_busy,
                    controller: _composer,
                    focusNode: _composerFocus,
                    maxLength: 500,
                    maxLines: 3,
                    minLines: 2,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: soft,
                      alignLabelWithHint: true,
                      floatingLabelStyle: TextStyle(color: link),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: _purple,
                          width: 1.5,
                        ),
                      ),
                      labelText: _replyTo == null
                          ? context.tr("Bình luận của bạn")
                          : context.tr("Câu trả lời của bạn"),
                      hintText: _replyTo == null
                          ? context.tr("Chia sẻ cảm nhận của bạn...")
                          : context.tr("Viết câu trả lời..."),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7E22CE),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _busy || _composer.text.trim().isEmpty
                          ? null
                          : _send,
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _purple,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(context.tr("Gửi bình luận")),
                    ),
                  ),
                ],
              ),
            ),
            if (parents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  context.tr("Chưa có bình luận. Hãy bắt đầu cuộc trò chuyện."),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              )
            else
              Container(
                key: const ValueKey('book-comment-feed'),
                margin: const EdgeInsets.only(top: 18),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < parents.length; index++) ...[
                      if (index > 0)
                        Divider(
                          height: 32,
                          thickness: 2,
                          color: dark ? const Color(0xFF3C4758) : border,
                        ),
                      _comment(parents[index]),
                      for (final reply in discussion.comments.where(
                        (comment) => comment.replyToId == parents[index].id,
                      ))
                        _comment(reply, reply: true),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 14),
            Text(
              context.tr(
                "Bình luận chỉ lưu trên thiết bị này; chưa đồng bộ lên mạng.",
              ),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
