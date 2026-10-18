import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_page.dart';
import 'features/navigation/main_shell.dart';
import 'features/bookshelf/bookshelf_service.dart';
import 'features/profile/settings_service.dart';

class OpenLibraryApp extends StatefulWidget {
  const OpenLibraryApp({
    super.key,
    this.authService,
    this.bookshelfFactory,
    this.settingsFactory,
  });
  final AuthService? authService;
  final BookshelfService Function(String userId)? bookshelfFactory;
  final SettingsService Function(String userId)? settingsFactory;

  @override
  State<OpenLibraryApp> createState() => _OpenLibraryAppState();
}

class _OpenLibraryAppState extends State<OpenLibraryApp> {
  late final AuthService _authService = widget.authService ?? AuthService();
  SettingsService? _settings;
  String? _settingsUserId;

  @override
  void initState() {
    super.initState();
    _authService.addListener(_syncSettings);
    _syncSettings();
  }

  void _syncSettings() {
    final userId = _authService.currentUser?.id;
    if (userId == _settingsUserId) return;
    _settings?.dispose();
    _settingsUserId = userId;
    _settings = userId == null
        ? null
        : (widget.settingsFactory?.call(userId) ??
              SettingsService(userId: userId));
    _settings?.load();
  }

  @override
  void dispose() {
    _authService.removeListener(_syncSettings);
    _settings?.dispose();
    if (widget.authService == null) _authService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _authService,
    builder: (context, _) => ListenableBuilder(
      listenable: _settings ?? _authService,
      builder: (context, _) => MaterialApp(
        // Replacing the navigator drops protected routes when the session ends.
        key: ValueKey(_authService.currentUser?.id),
        debugShowCheckedModeBanner: false,
        title: 'Open Library',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _settings?.darkMode == true
            ? ThemeMode.dark
            : ThemeMode.light,
        home: _authService.currentUser == null
            ? LoginPage(authService: _authService)
            : MainShell(
                authService: _authService,
                bookshelfFactory: widget.bookshelfFactory,
                settings: _settings!,
              ),
      ),
    ),
  );
}
