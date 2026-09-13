import 'dart:ui' show Locale;

import 'package:shared_preferences/shared_preferences.dart';

/// Device-wide preference, deliberately outside profile deletion. A null
/// override follows Flutter's platform locale resolution (English fallback).
class AppLocaleStore {
  AppLocaleStore(this._preferences);

  static const preferenceKey = 'oc.appLocale';
  static const supportedLanguages = {'en', 'ar'};
  final SharedPreferences _preferences;
  Future<void>? _pending;

  Locale? get value {
    final language = _preferences.getString(preferenceKey);
    return supportedLanguages.contains(language) ? Locale(language!) : null;
  }

  /// Serial writes avoid an older slow save replacing a newer choice. A
  /// refused platform write also refreshes SharedPreferences' optimistic cache.
  Future<void> save(Locale? locale) {
    if (locale != null && !supportedLanguages.contains(locale.languageCode)) {
      return Future<void>.error(ArgumentError.value(locale, 'locale'));
    }
    Future<void> write() async {
      try {
        final saved = locale == null
            ? await _preferences.remove(preferenceKey)
            : await _preferences.setString(preferenceKey, locale.languageCode);
        if (!saved) throw const AppLocaleSaveException();
      } catch (_) {
        try {
          await _preferences.reload();
        } catch (_) {
          // The controller retains the last acknowledged locale either way.
        }
        throw const AppLocaleSaveException();
      }
    }

    final result = _pending == null ? write() : _pending!.then((_) => write());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}

class AppLocaleSaveException implements Exception {
  const AppLocaleSaveException();
}
