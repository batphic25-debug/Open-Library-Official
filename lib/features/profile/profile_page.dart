import 'package:open_library_client/core/l10n/app_strings.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../auth/auth_service.dart';
import 'about_page.dart';
import 'avatar_image.dart';
import 'change_password_page.dart';
import 'edit_profile_page.dart';
import 'settings_page.dart';
import 'settings_service.dart';

/// Minimal authenticated landing page for the person 5 integration.
/// Resolved: this page now contains the account and settings destinations.
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.authService,
    required this.settings,
    required this.onShelfTap,
  });

  final AuthService authService;
  final SettingsService settings;
  final VoidCallback onShelfTap;

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([authService, settings]),
    builder: (context, _) {
      final user = authService.currentUser;
      if (user == null) return const SizedBox.shrink();
      final english = settings.language == 'en';
      final dark = Theme.of(context).brightness == Brightness.dark;
      final ink = dark ? Colors.white : const Color(0xFF0D193C);
      final muted = dark ? const Color(0xFF9DADC8) : const Color(0xFF7886A4);
      final accent = dark ? const Color(0xFFFFC454) : AppTheme.accent;
      final card = dark ? const Color(0xFF19263A) : Colors.white;
      final edge = dark ? const Color(0xFF2A3951) : const Color(0xFFE8EAF0);
      final editPage = EditProfilePage(
        authService: authService,
        settings: settings,
      );

      Future<void> updateNotifications(bool value) async {
        try {
          await settings.update(notifications: value);
        } catch (_) {
          if (context.mounted) _error(context);
        }
      }

      final editButton = OutlinedButton.icon(
        onPressed: () => _open(context, editPage),
        icon: const Icon(Icons.settings_outlined, size: 18),
        label: Text(english ? 'Edit' : context.tr('Sửa hồ sơ')),
        style: OutlinedButton.styleFrom(
          foregroundColor: dark ? const Color(0xFF101B2D) : accent,
          backgroundColor: dark
              ? accent
              : AppTheme.accent.withValues(alpha: .06),
          side: BorderSide(
            color: dark ? accent : AppTheme.accent.withValues(alpha: .18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 11),
          minimumSize: const Size(0, 42),
          shape: const StadiumBorder(),
        ),
      );
      final helpTile = _tile(
        dark,
        ink,
        muted,
        Icons.help_outline_rounded,
        const Color(0xFF328BFA),
        english ? 'Help' : context.tr('Trợ giúp'),
        english
            ? 'Frequently asked questions and support'
            : context.tr('Câu hỏi thường gặp và hỗ trợ'),
        () => _open(context, AboutPage(help: true, english: english)),
      );
      final aboutTile = _tile(
        dark,
        ink,
        muted,
        Icons.info_outline_rounded,
        const Color(0xFF9657F4),
        english ? 'About the app' : context.tr('Giới thiệu ứng dụng'),
        english
            ? 'Version and developer information'
            : context.tr('Thông tin phiên bản và nhà phát triển'),
        () => _open(
          context,
          AboutPage(
            english: english,
            syncedAccount: authService.apiClient != null,
          ),
        ),
      );

      return Scaffold(
        backgroundColor: dark ? const Color(0xFF101B2D) : Colors.white,
        appBar: AppBar(
          backgroundColor: dark ? const Color(0xFF101B2D) : Colors.white,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          title: Text(
            english ? 'Profile' : context.tr('Cá nhân'),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: ink,
              letterSpacing: -0.8,
            ),
          ),
          actions: [
            IconButton(
              tooltip: english ? 'Settings' : context.tr('Cài đặt'),
              icon: const Icon(Icons.settings_outlined, size: 27),
              color: muted,
              onPressed: () => _open(context, SettingsPage(settings: settings)),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? [const Color(0xFF0E1828), const Color(0xFF142136)]
                  : [const Color(0xFFFFF8F5), Colors.white],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 112),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact =
                              constraints.maxWidth < 360 ||
                              MediaQuery.textScalerOf(context).scale(1) > 1.2;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  InkWell(
                                    borderRadius: BorderRadius.circular(42),
                                    onTap: () => _open(context, editPage),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        AvatarImage(
                                          radius: 37,
                                          bytes: settings.avatarBytes,
                                        ),
                                        Positioned(
                                          right: -2,
                                          bottom: -2,
                                          child: CircleAvatar(
                                            radius: 14,
                                            backgroundColor: dark
                                                ? const Color(0xFF243249)
                                                : Colors.white,
                                            child: Icon(
                                              Icons.edit_outlined,
                                              color: dark ? muted : ink,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w800,
                                            color: ink,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          user.email,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: muted,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!compact) ...[
                                    const SizedBox(width: 8),
                                    editButton,
                                  ],
                                ],
                              ),
                              if (compact) ...[
                                const SizedBox(height: 8),
                                editButton,
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 26),
                      Material(
                        color: dark
                            ? const Color(0xFF252A31)
                            : const Color(0xFFFFF0EC),
                        elevation: dark ? 0 : 2,
                        shadowColor: const Color(0x260D193C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(color: edge),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          leading: _icon(Icons.menu_book_rounded, accent, dark),
                          title: Text(
                            english
                                ? 'My bookshelf'
                                : context.tr('Tủ sách của tôi'),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                          subtitle: Text(
                            english
                                ? 'Saved books and reading progress'
                                : context.tr('Sách đã lưu và tiến độ đọc'),
                            style: TextStyle(color: muted, fontSize: 13),
                          ),
                          trailing: CircleAvatar(
                            radius: 18,
                            backgroundColor: accent,
                            child: Icon(
                              Icons.chevron_right,
                              color: dark
                                  ? const Color(0xFF101B2D)
                                  : Colors.white,
                            ),
                          ),
                          onTap: onShelfTap,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _heading(
                        english ? 'Account' : context.tr('Tài khoản'),
                        ink,
                      ),
                      const SizedBox(height: 10),
                      _group(dark, card, edge, [
                        _tile(
                          dark,
                          ink,
                          muted,
                          Icons.person_outline,
                          const Color(0xFF328BFA),
                          english
                              ? 'Personal information'
                              : context.tr('Thông tin cá nhân'),
                          english
                              ? 'View and edit your personal information'
                              : context.tr(
                                  'Xem và chỉnh sửa thông tin cá nhân',
                                ),
                          () => _open(context, editPage),
                        ),
                        _tile(
                          dark,
                          ink,
                          muted,
                          Icons.lock_outline,
                          const Color(0xFF9657F4),
                          english
                              ? 'Change password'
                              : context.tr('Đổi mật khẩu'),
                          english
                              ? 'Update your password to protect your account'
                              : context.tr(
                                  'Cập nhật mật khẩu để bảo mật tài khoản',
                                ),
                          () => _open(
                            context,
                            ChangePasswordPage(authService: authService),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      _heading(
                        english ? 'Settings' : context.tr('Cài đặt'),
                        ink,
                      ),
                      const SizedBox(height: 10),
                      _group(dark, card, edge, [
                        _tile(
                          dark,
                          ink,
                          muted,
                          Icons.notifications_none_rounded,
                          const Color(0xFFFF5964),
                          english ? 'Notifications' : context.tr('Thông báo'),
                          english
                              ? 'Save your notification preference'
                              : 'Lưu lựa chọn thông báo',
                          () => updateNotifications(!settings.notifications),
                          action: Switch(
                            value: settings.notifications,
                            onChanged: updateNotifications,
                            activeTrackColor: accent,
                            activeThumbColor: Colors.white,
                          ),
                        ),
                        _tile(
                          dark,
                          ink,
                          muted,
                          Icons.language,
                          const Color(0xFF1CC979),
                          english ? 'Language' : context.tr('Ngôn ngữ'),
                          english
                              ? 'Choose the display language'
                              : context.tr('Chọn ngôn ngữ hiển thị'),
                          () =>
                              _open(context, SettingsPage(settings: settings)),
                          trailing: english
                              ? 'English'
                              : context.tr('Tiếng Việt'),
                        ),
                        _tile(
                          dark,
                          ink,
                          muted,
                          Icons.light_mode_outlined,
                          const Color(0xFFFFB42E),
                          english ? 'Appearance' : context.tr('Giao diện'),
                          english
                              ? 'Choose the app appearance'
                              : context.tr('Chọn chế độ hiển thị ứng dụng'),
                          () =>
                              _open(context, SettingsPage(settings: settings)),
                          trailing: settings.darkMode
                              ? (english ? 'Dark' : context.tr('Tối'))
                              : (english ? 'Light' : context.tr('Sáng')),
                        ),
                        if (dark) ...[helpTile, aboutTile],
                      ]),
                      if (!dark) ...[
                        const SizedBox(height: 12),
                        _group(dark, card, edge, [helpTile, aboutTile]),
                      ],
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: authService.signOut,
                        icon: const Icon(Icons.logout),
                        label: Text(
                          english ? 'Sign out' : context.tr('Đăng xuất'),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accent,
                          backgroundColor: dark
                              ? const Color(0xFF252A31)
                              : AppTheme.accent.withValues(alpha: .04),
                          side: BorderSide(color: accent, width: 1.4),
                          minimumSize: const Size.fromHeight(52),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  static void _error(BuildContext context) => ScaffoldMessenger.of(context)
      .showSnackBar(
        SnackBar(
          content: Text(context.tr('Không lưu được cài đặt. Hãy thử lại.')),
        ),
      );

  Widget _heading(String label, Color color) => Text(
    label,
    style: TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      color: color,
    ),
  );

  Widget _group(bool dark, Color card, Color edge, List<Widget> children) =>
      Material(
        color: card,
        elevation: dark ? 0 : 2,
        shadowColor: const Color(0x260D193C),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: edge),
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(height: 1, indent: 74, endIndent: 16, color: edge),
              children[i],
            ],
          ],
        ),
      );

  Widget _icon(IconData icon, Color accent, bool dark) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: accent.withValues(alpha: dark ? .18 : .12),
      borderRadius: BorderRadius.circular(13),
    ),
    alignment: Alignment.center,
    child: Icon(icon, color: accent, size: 27),
  );

  Widget _tile(
    bool dark,
    Color ink,
    Color muted,
    IconData icon,
    Color accent,
    String title,
    String subtitle,
    VoidCallback onTap, {
    String? trailing,
    Widget? action,
  }) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    leading: _icon(icon, accent, dark),
    title: Text(
      title,
      style: TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 15),
    ),
    subtitle: Text(subtitle, style: TextStyle(color: muted, fontSize: 12.5)),
    trailing:
        action ??
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailing != null)
              Text(trailing, style: TextStyle(color: muted, fontSize: 12)),
            Icon(Icons.chevron_right, color: muted),
          ],
        ),
    onTap: onTap,
  );
}
