import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/settings_scope.dart';
import 'app_locale.dart';
import 'effects.dart';
import 'profiles.dart' show AppAppearance, ThemePackId;
import 'read_state_consent.dart';

@immutable
class AppPreferencesSnapshot {
  const AppPreferencesSnapshot({
    required this.appearance,
    required this.themePack,
    required this.locale,
    required this.effects,
    this.textSize = KitTextSize.normal,
    required this.reasoningExpanded,
    required this.timestampsVisible,
  });

  final AppAppearance appearance;
  final ThemePackId themePack;
  final Locale? locale;
  final KitEffects effects;
  final KitTextSize textSize;
  final bool reasoningExpanded;
  final bool timestampsVisible;

  @override
  bool operator ==(Object other) =>
      other is AppPreferencesSnapshot &&
      appearance == other.appearance &&
      themePack == other.themePack &&
      locale == other.locale &&
      effects == other.effects &&
      textSize == other.textSize &&
      reasoningExpanded == other.reasoningExpanded &&
      timestampsVisible == other.timestampsVisible;

  @override
  int get hashCode => Object.hash(
    appearance,
    themePack,
    locale,
    effects,
    textSize,
    reasoningExpanded,
    timestampsVisible,
  );
}

/// One acknowledged device preference snapshot for all connection controllers.
/// Controllers borrow this owner and remove their listeners when disposed;
/// they must not dispose it with an individual connection.
class AppPreferencesStore extends ChangeNotifier {
  factory AppPreferencesStore.forPreferences(SharedPreferences preferences) =>
      _owners[preferences] ??= AppPreferencesStore._(preferences);

  AppPreferencesStore._(this._preferences)
    : readStateConsent = ReadStateConsentStore.forPreferences(_preferences) {
    _value = _read();
    _storedKeys = _preferences.getKeys();
    readStateConsent.addListener(_consentChanged);
  }

  static final _owners = Expando<AppPreferencesStore>();
  static const _appearance = 'oc.appearance';
  static const _themePack = 'oc.themePack';
  static const _reasoning = 'oc.transcript.reasoningExpanded';
  static const _timestamps = 'oc.transcript.timestampsVisible';
  static const _textSize = 'oc.textSize';
  static const _motion = 'oc.effectsMotion';
  static const _celebrations = 'oc.effectsCelebrations';
  static const _glow = 'oc.effectsActivityGlow';
  static const _liveBackground = 'oc.effectsLiveBackground';
  static const _liveStyle = 'oc.effectsLiveStyle';
  static const _liveIntensity = 'oc.effectsLiveIntensity';
  static const _glowStyle = 'oc.effectsGlowStyle';
  static const _glowColours = 'oc.effectsGlowColours';
  static const _glowSpeed = 'oc.effectsGlowSpeed';

  final SharedPreferences _preferences;
  final ReadStateConsentStore readStateConsent;
  late AppPreferencesSnapshot _value;
  late Set<String> _storedKeys;

  /// Provenance for the same acknowledged snapshot as [value].
  bool hasStoredPreference(String key) => _storedKeys.contains(key);
  Future<void> _writes = Future<void>.value();
  int _revision = 0;
  bool _needsReload = false;

  AppPreferencesSnapshot get value => _value;
  int get revision => _revision;
  int get privacyEpoch => readStateConsent.epoch;

  void _consentChanged() {
    _revision++;
    notifyListeners();
  }

  Object? _stored(String key) => _preferences.get(key);

  T _enum<T extends Enum>(String key, List<T> options, T fallback) {
    final raw = _stored(key);
    return options.where((option) => option.name == raw).firstOrNull ??
        fallback;
  }

  bool _bool(String key, bool fallback) {
    final raw = _stored(key);
    return raw is bool ? raw : fallback;
  }

  AppPreferencesSnapshot _read() {
    var motion = _enum(_motion, KitMotionLevel.values, KitMotionLevel.full);
    if (motion == KitMotionLevel.full && _stored(_celebrations) == false) {
      motion = KitMotionLevel.calm;
    }
    final language = _stored(AppLocaleStore.preferenceKey);
    return AppPreferencesSnapshot(
      appearance: _enum(_appearance, AppAppearance.values, AppAppearance.dark),
      themePack: _enum(_themePack, ThemePackId.values, ThemePackId.opencode),
      locale:
          language is String &&
              AppLocaleStore.supportedLanguages.contains(language)
          ? Locale(language)
          : null,
      effects: KitEffects(
        motion: motion,
        celebrations: motion == KitMotionLevel.full,
        activityGlow: _bool(_glow, true),
        liveBackground: _bool(_liveBackground, true),
        liveStyle: _stored(_liveStyle) is String
            ? _stored(_liveStyle)! as String
            : 'aurora',
        liveIntensity: _enum(
          _liveIntensity,
          KitLiveIntensity.values,
          KitLiveIntensity.normal,
        ),
        glowStyle: _enum(_glowStyle, KitGlowStyle.values, KitGlowStyle.classic),
        glowColours: _enum(
          _glowColours,
          KitGlowColours.values,
          KitGlowColours.one,
        ),
        glowSpeed: _enum(_glowSpeed, KitGlowSpeed.values, KitGlowSpeed.normal),
      ),
      textSize: _enum(_textSize, KitTextSize.values, KitTextSize.normal),
      reasoningExpanded: _bool(_reasoning, false),
      timestampsVisible: _bool(_timestamps, false),
    );
  }

  Future<void> _enqueue(Future<void> Function() write) {
    final result = _writes.then((_) async {
      if (_needsReload) {
        try {
          await _preferences.reload();
          _needsReload = false;
          _publish(_read());
        } catch (_) {
          throw const SettingsFailure(SettingsFailureReason.storageFailed);
        }
      }
      await write();
    });
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _put(String key, Object? value) async {
    final bool saved;
    if (value == null) {
      saved = await _preferences.remove(key);
    } else if (value is bool) {
      saved = await _preferences.setBool(key, value);
    } else if (value is String) {
      saved = await _preferences.setString(key, value);
    } else if (value is int) {
      saved = await _preferences.setInt(key, value);
    } else if (value is double) {
      saved = await _preferences.setDouble(key, value);
    } else if (value is List<String>) {
      saved = await _preferences.setStringList(key, value);
    } else {
      throw const SettingsFailure(SettingsFailureReason.storageFailed);
    }
    if (!saved) {
      throw const SettingsFailure(SettingsFailureReason.storageFailed);
    }
  }

  void _publish(AppPreferencesSnapshot next, {bool acknowledged = false}) {
    final keys = _preferences.getKeys();
    final keysChanged = !setEquals(keys, _storedKeys);
    _storedKeys = keys;
    if (!acknowledged && !keysChanged && next == _value) return;
    _value = next;
    _revision++;
    notifyListeners();
  }

  /// SharedPreferences has no multi-key transaction. Restore attempted keys
  /// on refusal; if restoration is also refused, expose reloaded disk truth
  /// while still reporting failure. A failed reload retains confirmed memory.
  Future<void> _commit(Map<String, Object?> changes) async {
    if (changes.isEmpty) return;
    final before = {for (final key in changes.keys) key: _stored(key)};
    final attempted = <String>[];
    try {
      for (final entry in changes.entries) {
        attempted.add(entry.key);
        await _put(entry.key, entry.value);
      }
    } catch (_) {
      for (final key in attempted.reversed) {
        try {
          await _put(key, before[key]);
        } catch (_) {
          // The original failure remains the result; inspect durable state.
        }
      }
      try {
        await _preferences.reload();
        _publish(_read());
      } catch (_) {
        // Never promote SharedPreferences' optimistic cache to saved truth.
        _needsReload = true;
      }
      throw const SettingsFailure(SettingsFailureReason.storageFailed);
    }
    _publish(_read(), acknowledged: true);
  }

  Future<void> setAppearance(AppAppearance value) =>
      _enqueue(() => _commit({_appearance: value.name}));

  Future<void> setThemePack(ThemePackId value) =>
      _enqueue(() => _commit({_themePack: value.name}));

  Future<void> setLocale(Locale? value) {
    if (value != null &&
        !AppLocaleStore.supportedLanguages.contains(value.languageCode)) {
      return Future<void>.error(
        const SettingsFailure(SettingsFailureReason.invalidValue),
      );
    }
    return _enqueue(
      () => _commit({AppLocaleStore.preferenceKey: value?.languageCode}),
    );
  }

  Future<void> setReasoningExpanded(bool value) =>
      _enqueue(() => _commit({_reasoning: value}));

  Future<void> setTimestampsVisible(bool value) =>
      _enqueue(() => _commit({_timestamps: value}));

  Future<void> setTextSize(KitTextSize value) =>
      _enqueue(() => _commit({_textSize: value.name}));

  Future<void> setEffects(KitEffects value) => _enqueue(() {
    final before = _value.effects;
    return _commit({
      if (before.motion != value.motion) _motion: value.motion.name,
      if (before.activityGlow != value.activityGlow) _glow: value.activityGlow,
      if (before.liveBackground != value.liveBackground)
        _liveBackground: value.liveBackground,
      if (before.liveStyle != value.liveStyle) _liveStyle: value.liveStyle,
      if (before.liveIntensity != value.liveIntensity)
        _liveIntensity: value.liveIntensity.name,
      if (before.glowStyle != value.glowStyle) _glowStyle: value.glowStyle.name,
      if (before.glowColours != value.glowColours)
        _glowColours: value.glowColours.name,
      if (before.glowSpeed != value.glowSpeed) _glowSpeed: value.glowSpeed.name,
      if (value.motion == KitMotionLevel.full &&
          _preferences.containsKey(_celebrations))
        _celebrations: null,
    });
  });
}
