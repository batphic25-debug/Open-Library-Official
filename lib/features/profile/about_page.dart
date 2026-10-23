import 'package:open_library_client/core/l10n/app_strings.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({
    super.key,
    this.help = false,
    this.english = false,
    this.syncedAccount = false,
  });
  final bool help;
  final bool english;
  final bool syncedAccount;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : AppTheme.ink;
    final muted = dark ? const Color(0xFF9DADC8) : AppTheme.muted;
    final accent = dark ? const Color(0xFFFFC454) : AppTheme.accent;
    final card = dark ? const Color(0xFF19263A) : Colors.white;
    final edge = dark ? const Color(0xFF2A3951) : AppTheme.border;
    final title = help
        ? (english ? 'Help' : context.tr('Trợ giúp'))
        : (english ? 'About the app' : context.tr('Giới thiệu ứng dụng'));

    Widget item(IconData icon, String heading, String body) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: dark ? .18 : .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 23),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: TextStyle(
                    color: ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(body, style: TextStyle(color: muted, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF101B2D) : Colors.white,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: dark ? const Color(0xFF101B2D) : Colors.white,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const [Color(0xFF0E1828), Color(0xFF142136)]
                : const [Color(0xFFFFF8F5), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: card,
                      border: Border.all(color: edge),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          help
                              ? Icons.help_outline_rounded
                              : Icons.auto_stories_rounded,
                          size: 42,
                          color: accent,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          help ? title : 'Open Library Client',
                          style: TextStyle(
                            color: ink,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          help
                              ? (english
                                    ? 'Everything you need to start reading.'
                                    : 'Những điều cần biết để bắt đầu đọc sách.')
                              : (english
                                    ? 'Discover books, build a bookshelf and keep track of your reading.'
                                    : 'Khám phá sách, xây dựng tủ sách và theo dõi hành trình đọc.'),
                          style: TextStyle(color: muted, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: card,
                      border: Border.all(color: edge),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: help
                          ? [
                              item(
                                Icons.search_rounded,
                                english ? 'Find a book' : 'Tìm sách',
                                english
                                    ? 'Search by title or author. Open a result to see editions and reading options.'
                                    : 'Tìm theo tên sách hoặc tác giả. Mở sách để xem các phiên bản và cách đọc.',
                              ),
                              Divider(height: 1, color: edge),
                              item(
                                Icons.bookmark_outline_rounded,
                                english
                                    ? 'Keep a bookshelf'
                                    : 'Lưu vào tủ sách',
                                english
                                    ? 'Save books, update reading progress and add your own notes.'
                                    : 'Lưu sách, cập nhật tiến độ đọc và ghi chú của riêng bạn.',
                              ),
                              Divider(height: 1, color: edge),
                              item(
                                Icons.forum_outlined,
                                english ? 'Discuss a book' : 'Trao đổi về sách',
                                english
                                    ? 'Open a book detail page to rate it and join its discussion.'
                                    : 'Mở trang chi tiết để đánh giá và tham gia bình luận.',
                              ),
                            ]
                          : [
                              item(
                                Icons.library_books_outlined,
                                english ? 'Book catalog' : 'Kho sách',
                                english
                                    ? 'Explore the built-in catalog and search Open Library for more books.'
                                    : 'Khám phá danh mục có sẵn và tìm thêm sách từ Open Library.',
                              ),
                              Divider(height: 1, color: edge),
                              item(
                                Icons.storage_outlined,
                                syncedAccount
                                    ? (english
                                          ? 'Account data'
                                          : 'Dữ liệu tài khoản')
                                    : (english
                                          ? 'Data on this device'
                                          : 'Dữ liệu trên thiết bị'),
                                syncedAccount
                                    ? (english
                                          ? 'Your bookshelf, reading progress and notes are saved to your account. Discussions stay on this device.'
                                          : 'Tủ sách, tiến độ đọc và ghi chú được lưu vào tài khoản. Bình luận vẫn chỉ lưu trên thiết bị này.')
                                    : (english
                                          ? 'Your bookshelf, reading progress, notes and discussions are stored on this device.'
                                          : 'Tủ sách, tiến độ đọc, ghi chú và bình luận được lưu trên thiết bị này.'),
                              ),
                              Divider(height: 1, color: edge),
                              item(
                                Icons.info_outline_rounded,
                                english
                                    ? 'Account limits'
                                    : 'Giới hạn tài khoản',
                                syncedAccount
                                    ? (english
                                          ? 'Your account persists. Password reset email needs server mail setup; push notifications are not available.'
                                          : 'Tài khoản được lưu lâu dài. Email đặt lại mật khẩu cần cấu hình máy chủ; chưa hỗ trợ thông báo đẩy.')
                                    : (english
                                          ? 'Accounts currently last only until the app restarts. Password reset emails and push notifications are unavailable.'
                                          : 'Tài khoản hiện chỉ tồn tại đến khi khởi động lại ứng dụng. Chưa hỗ trợ email đặt lại mật khẩu hoặc thông báo đẩy.'),
                              ),
                            ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
