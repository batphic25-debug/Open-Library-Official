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
      final scheme = Theme.of(context).colorScheme;
      final border = BorderSide(
        color: scheme.outlineVariant.withValues(alpha: .55),
      );
      return Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 125),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          english ? 'Profile' : 'Cá nhân',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: english ? 'Settings' : 'Cài đặt',
                        icon: const Icon(Icons.settings_outlined, size: 27),
                        onPressed: () =>
                            _open(context, SettingsPage(settings: settings)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(34),
                        onTap: () => _open(
                          context,
                          EditProfilePage(
                            authService: authService,
                            settings: settings,
                          ),
                        ),
                        child: AvatarImage(
                          radius: 34,
                          bytes: settings.avatarBytes,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              user.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.muted),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 88,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                          ),
                          onPressed: () => _open(
                            context,
                            EditProfilePage(
                              authService: authService,
                              settings: settings,
                            ),
                          ),
                          child: Text(
                            english ? 'Edit' : 'Sửa hồ sơ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Material(
                    color: const Color(0xFFFFF1E9),
                    borderRadius: BorderRadius.circular(18),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      leading: const Icon(
                        Icons.menu_book_outlined,
                        color: AppTheme.accent,
                      ),
                      title: Text(
                        english ? 'My bookshelf' : 'Tủ sách của tôi',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink,
                        ),
                      ),
                      subtitle: Text(
                        english
                            ? 'Saved books and reading progress'
                            : 'Sách đã lưu và tiến độ đọc',
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppTheme.ink,
                      ),
                      onTap: onShelfTap,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _heading(english ? 'Account' : 'Tài khoản'),
                  const SizedBox(height: 8),
                  _group(context, border, [
                    _tile(
                      Icons.person_outline,
                      english ? 'Personal information' : 'Thông tin cá nhân',
                      () => _open(
                        context,
                        EditProfilePage(
                          authService: authService,
                          settings: settings,
                        ),
                      ),
                    ),
                    _tile(
                      Icons.lock_outline,
                      english ? 'Change password' : 'Đổi mật khẩu',
                      () => _open(
                        context,
                        ChangePasswordPage(authService: authService),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _heading(english ? 'Settings' : 'Cài đặt'),
                  const SizedBox(height: 8),
                  _group(context, border, [
                    ListTile(
                      leading: const Icon(Icons.notifications_none),
                      title: Text(english ? 'Notifications' : 'Thông báo'),
                      trailing: Switch(
                        value: settings.notifications,
                        onChanged: (value) async {
                          try {
                            await settings.update(notifications: value);
                          } catch (_) {
                            if (context.mounted) _error(context);
                          }
                        },
                      ),
                    ),
                    _tile(
                      Icons.language,
                      english ? 'Language' : 'Ngôn ngữ',
                      () => _open(context, SettingsPage(settings: settings)),
                      trailing: english ? 'English' : 'Tiếng Việt',
                    ),
                    _tile(
                      Icons.light_mode_outlined,
                      english ? 'Appearance' : 'Giao diện',
                      () => _open(context, SettingsPage(settings: settings)),
                      trailing: settings.darkMode
                          ? (english ? 'Dark' : 'Tối')
                          : (english ? 'Light' : 'Sáng'),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _group(context, border, [
                    _tile(
                      Icons.help_outline,
                      english ? 'Help' : 'Trợ giúp',
                      () => _open(
                        context,
                        AboutPage(help: true, english: english),
                      ),
                    ),
                    _tile(
                      Icons.info_outline,
                      english ? 'About the app' : 'Giới thiệu ứng dụng',
                      () => _open(context, AboutPage(english: english)),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: authService.signOut,
                    icon: const Icon(Icons.logout),
                    label: Text(english ? 'Sign out' : 'Đăng xuất'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accent,
                      side: const BorderSide(color: AppTheme.accent),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  static void _error(BuildContext context) => ScaffoldMessenger.of(context)
      .showSnackBar(
        const SnackBar(content: Text('Không lưu được cài đặt. Hãy thử lại.')),
      );

  Widget _heading(String label) => Text(
    label,
    style: const TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
    ),
  );

  Widget _group(
    BuildContext context,
    BorderSide border,
    List<Widget> children,
  ) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      side: border,
      borderRadius: BorderRadius.circular(18),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 52),
          children[i],
        ],
      ],
    ),
  );

  Widget _tile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    String? trailing,
  }) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (trailing != null)
          Text(trailing, style: const TextStyle(color: AppTheme.muted)),
        const Icon(Icons.chevron_right),
      ],
    ),
    onTap: onTap,
  );
}
