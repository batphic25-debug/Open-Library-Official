import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_library_client/core/theme/app_theme.dart';
import 'package:open_library_client/features/profile/about_page.dart';
import 'package:open_library_client/features/profile/settings_page.dart';
import 'package:open_library_client/features/profile/settings_service.dart';

void main() {
  testWidgets('support pages fit a narrow screen with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final settings = SettingsService(userId: 'support-layout');
    addTearDown(settings.dispose);
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: SettingsPage(settings: settings),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(theme: theme, home: const AboutPage(help: true)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
