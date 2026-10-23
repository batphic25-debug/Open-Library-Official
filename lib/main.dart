import 'package:flutter/material.dart';

import 'app.dart';
import 'core/theme/appearance_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appearance = AppearanceStore();
  var darkMode = false;
  try {
    darkMode = await appearance.load();
  } catch (_) {
    // New installations and unavailable local storage start in light mode.
  }
  runApp(
    OpenLibraryApp(appearanceStore: appearance, initialDarkMode: darkMode),
  );
}
