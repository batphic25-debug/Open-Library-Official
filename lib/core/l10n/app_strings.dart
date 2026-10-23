import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'translations.dart';

class AppStrings {
  const AppStrings(this.languageCode);

  final String languageCode;
  static const delegate = _AppStringsDelegate();
  static const supportedLocales = [Locale('vi'), Locale('en')];

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ??
      const AppStrings('vi');

  String text(String key, [List<Object?> arguments = const []]) {
    var template = languageCode == 'en' ? englishTranslations[key] ?? key : key;
    if (languageCode == 'en') {
      template = template.replaceAllMapped(RegExp(r'\{(\d+)\} (\w+)\(s\)'), (
        match,
      ) {
        final index = int.parse(match[1]!);
        final singular =
            index < arguments.length && '${arguments[index]}' == '1';
        return '{${match[1]}} ${match[2]}${singular ? '' : 's'}';
      });
    }
    return template.replaceAllMapped(RegExp(r'\{(\d+)\}'), (match) {
      final index = int.parse(match[1]!);
      return index < arguments.length ? '${arguments[index]}' : match[0]!;
    });
  }

  /// Service errors retain stable source messages; translate only when displayed.
  String error(String message) {
    if (languageCode != 'en') return message;
    if (englishTranslations.containsKey(message)) return text(message);
    for (final key in englishTranslations.keys) {
      final placeholders = RegExp(r'\{\d+\}').allMatches(key).toList();
      if (placeholders.isEmpty) continue;
      var pattern = '^';
      var offset = 0;
      for (final placeholder in placeholders) {
        pattern +=
            '${RegExp.escape(key.substring(offset, placeholder.start))}(.+?)';
        offset = placeholder.end;
      }
      pattern += '${RegExp.escape(key.substring(offset))}\$';
      final match = RegExp(pattern, dotAll: true).firstMatch(message);
      if (match != null) {
        return text(key, [
          for (var i = 1; i <= match.groupCount; i++) match[i],
        ]);
      }
    }
    return message;
  }
}

extension AppTranslation on BuildContext {
  String tr(String key, [List<Object?> arguments = const []]) =>
      AppStrings.of(this).text(key, arguments);

  String trError(String message) => AppStrings.of(this).error(message);

  String? trValidation(String? message) =>
      message == null ? null : trError(message);
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'vi' || locale.languageCode == 'en';

  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture(AppStrings(locale.languageCode));

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
