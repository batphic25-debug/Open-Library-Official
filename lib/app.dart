import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/l10n/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/appearance_store.dart';
import 'core/network/api_client.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_page.dart';
import 'features/navigation/main_shell.dart';
import 'features/bookshelf/bookshelf_service.dart';
import 'features/profile/settings_service.dart';
import 'features/profile/backend_settings_service.dart';

class OpenLibraryApp extends StatefulWidget {
  const OpenLibraryApp({
    super.key,
    this.authService,
    this.bookshelfFactory,
    this.settingsFactory,
    this.appearanceStore,
    this.initialDarkMode = false,
  });
  final AuthService? authService;
  final BookshelfService Function(String userId)? bookshelfFactory;
  final SettingsService Function(String userId)? settingsFactory;
  final AppearanceStore? appearanceStore;
  final bool initialDarkMode;

  @override
  State<OpenLibraryApp> createState() => _OpenLibraryAppState();
}

class _OpenLibraryAppState extends State<OpenLibraryApp> {
  late final AuthService _authService =
      widget.authService ?? AuthService(apiClient: ApiClient());
  bool _restoring = false;
  SettingsService? _settings;
  String? _settingsUserId;
  String _lastLanguage = 'vi';
  late bool _lastDarkMode = widget.initialDarkMode;
  late final AppearanceStore _appearanceStore =
      widget.appearanceStore ?? AppearanceStore();
  Future<void> _appearanceWrite = Future.value();

  @override
  void initState() {
    super.initState();
    _authService.addListener(_syncSettings);
    _syncSettings();
    if (_authService.apiClient != null) {
      _restoring = true;
      _authService.restoreSession().catchError((Object _) {}).whenComplete(() {
        if (mounted) setState(() => _restoring = false);
      });
    }
  }

  void _onSettingsChanged() {
    final settings = _settings;
    if (settings == null || !settings.isLoaded) return;
    if (_lastDarkMode == settings.darkMode) return;
    _lastDarkMode = settings.darkMode;
    final darkMode = settings.darkMode;
    _appearanceWrite = _appearanceWrite
        .then((_) => _appearanceStore.save(darkMode))
        .catchError((Object _) {});
  }

  void _syncSettings() {
    final userId = _authService.currentUser?.id;
    if (userId == _settingsUserId) return;
    _lastLanguage = _settings?.language ?? _lastLanguage;
    _lastDarkMode = _settings?.darkMode ?? _lastDarkMode;
    _settings?.removeListener(_onSettingsChanged);
    _settings?.dispose();
    _settingsUserId = userId;
    _settings = userId == null
        ? null
        : (widget.settingsFactory?.call(userId) ??
              (_authService.apiClient == null
                  ? SettingsService(userId: userId)
                  : BackendSettingsService(
                      userId: userId,
                      api: _authService.apiClient!,
                    )));
    _settings?.addListener(_onSettingsChanged);
    _settings?.load();
  }

  @override
  void dispose() {
    _authService.removeListener(_syncSettings);
    _settings?.removeListener(_onSettingsChanged);
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
        locale: Locale(_settings?.language ?? _lastLanguage),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode:
            (_settings?.isLoaded == true ? _settings!.darkMode : _lastDarkMode)
            ? ThemeMode.dark
            : ThemeMode.light,
        home: _restoring
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : _authService.currentUser == null
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
