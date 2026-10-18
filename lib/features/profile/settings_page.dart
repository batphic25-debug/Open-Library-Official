import 'package:flutter/material.dart';

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
          const SnackBar(content: Text('Không lưu được cài đặt. Hãy thử lại.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) {
      final english = settings.language == 'en';
      return Scaffold(
        appBar: AppBar(title: Text(english ? 'Settings' : 'Cài đặt')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (settings.error != null) ...[
                    Text(settings.error!),
                    TextButton(
                      onPressed: settings.load,
                      child: const Text('Thử lại'),
                    ),
                  ],
                  SwitchListTile(
                    title: Text(english ? 'Notifications' : 'Thông báo'),
                    subtitle: Text(
                      english
                          ? 'Save notification preference; push alerts are not available in this demo.'
                          : 'Lưu lựa chọn; bản mô phỏng chưa gửi thông báo đẩy.',
                    ),
                    value: settings.notifications,
                    onChanged: (value) =>
                        _update(context, settings.update(notifications: value)),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    english ? 'Language' : 'Ngôn ngữ',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'vi', label: Text('Tiếng Việt')),
                      ButtonSegment(value: 'en', label: Text('English')),
                    ],
                    selected: {settings.language},
                    onSelectionChanged: (values) => _update(
                      context,
                      settings.update(language: values.single),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    english
                        ? 'English currently covers Profile, Settings and the bottom navigation.'
                        : 'Tiếng Anh hiện áp dụng cho trang Cá nhân, Cài đặt và thanh điều hướng.',
                  ),
                  const SizedBox(height: 26),
                  Text(
                    english ? 'Appearance' : 'Giao diện',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        label: Text(english ? 'Light' : 'Sáng'),
                        icon: const Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text(english ? 'Dark' : 'Tối'),
                        icon: const Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: {settings.darkMode},
                    onSelectionChanged: (values) => _update(
                      context,
                      settings.update(darkMode: values.single),
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
}
