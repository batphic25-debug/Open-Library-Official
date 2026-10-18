import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key, this.help = false, this.english = false});
  final bool help;
  final bool english;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        help
            ? (english ? 'Help' : 'Trợ giúp')
            : (english ? 'About the app' : 'Giới thiệu ứng dụng'),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.auto_stories, size: 54),
              const SizedBox(height: 16),
              Text(
                help
                    ? (english
                          ? 'Find books in Search, save them to your bookshelf and update reading progress there.'
                          : 'Tìm sách ở tab Tìm kiếm, lưu vào Tủ sách rồi cập nhật tiến độ đọc trong Tủ sách.')
                    : (english
                          ? 'Open Library Client helps you discover books, organize a bookshelf and record reading notes.'
                          : 'Open Library Client giúp khám phá sách, quản lý tủ sách và ghi chú khi đọc.'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                english
                    ? 'Accounts are simulated. No reset email or push notification is sent.'
                    : 'Tài khoản là bản mô phỏng. Ứng dụng chưa gửi email đặt lại mật khẩu hoặc thông báo đẩy.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
