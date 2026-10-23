import '../../core/network/api_client.dart';
import 'settings_service.dart';

class BackendSettingsService extends SettingsService {
  BackendSettingsService({required super.userId, required this.api});

  final ApiClient api;

  @override
  Future<void> load() async {
    await super.load();
    try {
      final data = await api.request('GET', '/me/settings');
      await super.update(
        notifications: data['notificationsEnabled'] == true,
        language: data['language'] == 'en' ? 'en' : 'vi',
        darkMode: data['theme'] == 'dark',
      );
      error = null;
    } on ApiException catch (failure) {
      error = failure.message;
      notifyListeners();
    }
  }

  @override
  Future<void> update({
    bool? notifications,
    String? language,
    bool? darkMode,
  }) async {
    if (notifications == null && language == null && darkMode == null) return;
    final changes = <String, dynamic>{};
    if (notifications != null) changes['notificationsEnabled'] = notifications;
    if (language != null) changes['language'] = language;
    if (darkMode != null) changes['theme'] = darkMode ? 'dark' : 'light';
    try {
      final data = await api.request('PATCH', '/me/settings', body: changes);
      await super.update(
        notifications: data['notificationsEnabled'] == true,
        language: data['language'] == 'en' ? 'en' : 'vi',
        darkMode: data['theme'] == 'dark',
      );
    } on ApiException catch (failure) {
      error = failure.message;
      notifyListeners();
      rethrow;
    }
  }
}
