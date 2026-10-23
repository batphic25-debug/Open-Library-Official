import 'package:open_library_client/core/l10n/app_strings.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'backend_settings_service.dart';
import 'settings_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.settings});
  final SettingsService settings;

  Future<void> _update(BuildContext context, Future<void> operation) async {
    try {
      await operation;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr("Không lưu được cài đặt. Hãy thử lại.")),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) {
      final english = settings.language == 'en';
      final dark = Theme.of(context).brightness == Brightness.dark;
      final ink = dark ? Colors.white : AppTheme.ink;
      final muted = dark ? const Color(0xFF9DADC8) : AppTheme.muted;
      final accent = dark ? const Color(0xFFFFC454) : AppTheme.accent;
      final card = dark ? const Color(0xFF19263A) : Colors.white;
      final edge = dark ? const Color(0xFF2A3951) : AppTheme.border;
      final segmentStyle = ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (dark ? const Color(0xFF101B2D) : Colors.white)
              : ink,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : card,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: edge)),
      );
      return Scaffold(
        backgroundColor: dark ? const Color(0xFF101B2D) : Colors.white,
        appBar: AppBar(
          title: Text(english ? 'Settings' : context.tr("Cài đặt")),
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
                    if (settings.error != null) ...[
                      Card(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: ListTile(
                          title: Text(context.trError(settings.error!)),
                          trailing: TextButton(
                            onPressed: settings.load,
                            child: Text(context.tr("Thử lại")),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _section(
                      dark: dark,
                      card: card,
                      edge: edge,
                      ink: ink,
                      muted: muted,
                      icon: Icons.notifications_none_rounded,
                      iconColor: const Color(0xFFFF5964),
                      title: english
                          ? 'Notifications'
                          : context.tr('Thông báo'),
                      subtitle: english
                          ? (settings is BackendSettingsService
                                ? 'Your notification preference is saved to your account.'
                                : 'Your notification preference is saved on this device.')
                          : (settings is BackendSettingsService
                                ? 'Lựa chọn thông báo được lưu vào tài khoản.'
                                : 'Lựa chọn thông báo được lưu trên thiết bị này.'),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              settings.notifications
                                  ? (english ? 'Enabled' : 'Đang bật')
                                  : (english ? 'Disabled' : 'Đang tắt'),
                              style: TextStyle(color: muted),
                            ),
                          ),
                          Switch(
                            value: settings.notifications,
                            activeTrackColor: accent,
                            activeThumbColor: Colors.white,
                            onChanged: (value) => _update(
                              context,
                              settings.update(notifications: value),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _section(
                      dark: dark,
                      card: card,
                      edge: edge,
                      ink: ink,
                      muted: muted,
                      icon: Icons.language_rounded,
                      iconColor: const Color(0xFF1CC979),
                      title: english ? 'Language' : context.tr('Ngôn ngữ'),
                      subtitle: english
                          ? 'Choose the language used in the app.'
                          : 'Chọn ngôn ngữ hiển thị trong ứng dụng.',
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          style: segmentStyle,
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: 'vi',
                              label: Text(context.tr('Tiếng Việt')),
                            ),
                            const ButtonSegment(
                              value: 'en',
                              label: Text('English'),
                            ),
                          ],
                          selected: {settings.language},
                          onSelectionChanged: (values) => _update(
                            context,
                            settings.update(language: values.single),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _section(
                      dark: dark,
                      card: card,
                      edge: edge,
                      ink: ink,
                      muted: muted,
                      icon: settings.darkMode
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      iconColor: const Color(0xFFFFB42E),
                      title: english ? 'Appearance' : context.tr('Giao diện'),
                      subtitle: english
                          ? 'Your choice is kept for your next sign-in.'
                          : 'Ghi nhớ giao diện cho những lần đăng nhập sau.',
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<bool>(
                          style: segmentStyle,
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: false,
                              icon: const Icon(Icons.light_mode_outlined),
                              label: Text(
                                english ? 'Light' : context.tr('Sáng'),
                              ),
                            ),
                            ButtonSegment(
                              value: true,
                              icon: const Icon(Icons.dark_mode_outlined),
                              label: Text(english ? 'Dark' : context.tr('Tối')),
                            ),
                          ],
                          selected: {settings.darkMode},
                          onSelectionChanged: (values) => _update(
                            context,
                            settings.update(darkMode: values.single),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _section({
    required bool dark,
    required Color card,
    required Color edge,
    required Color ink,
    required Color muted,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: card,
      border: Border.all(color: edge),
      borderRadius: BorderRadius.circular(20),
      boxShadow: dark
          ? null
          : const [
              BoxShadow(
                color: Color(0x100D193C),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: dark ? .2 : .11),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: muted, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}
