import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../ui/kit/kit_redact.dart';

/// The profile's default-on “Alert me at 80 %” preference.
///
/// Holds no account, quota or credential data. Supply live guards: `isCurrent`
/// means this instance still belongs to the active UI, and `isProfilePresent`
/// means the profile has not been deleted. Navigation does not delete data.
/// Await [setAlert80Enabled] before notifying listeners; this is not a notifier
/// and does not schedule notifications. The ordinary profile deletion sweep
/// includes its `oc.quotaAnswers.<profileId>` key.
class QuotaAnswerPreferences {
  QuotaAnswerPreferences({
    required SharedPreferences preferences,
    required String profileId,
    required bool Function() isCurrent,
    required bool Function() isProfilePresent,
  }) : _preferences = preferences,
       _key = 'oc.quotaAnswers.$profileId',
       _isCurrent = isCurrent,
       _isProfilePresent = isProfilePresent {
    if (profileId.trim().isEmpty) {
      throw ArgumentError('A profile id is required.');
    }
    final records = _records[preferences] ??= <String, _ConfirmedPreference>{};
    _confirmed = records.putIfAbsent(_key, _ConfirmedPreference.new);
    // A second instance must not interpret the plugin's optimistic cache as
    // confirmed data while a write is pending or a reload has failed.
    if (_confirmed.pending == 0) _read();
  }

  final SharedPreferences _preferences;
  final String _key;
  final bool Function() _isCurrent;
  final bool Function() _isProfilePresent;
  static final _queues = Expando<Map<String, Future<void>>>();
  static final _records = Expando<Map<String, _ConfirmedPreference>>();
  late final _ConfirmedPreference _confirmed;

  /// The last confirmed preference, or true for absent/invalid records.
  bool get alert80Enabled => _confirmed.alert80Enabled;

  /// Storage or validation failed; expose a fixed localized error in the UI.
  /// No raw storage errors or stored values are exposed.
  bool get failed => _confirmed.failed;

  void _read({bool refreshed = false}) {
    try {
      final raw = _preferences.get(_key);
      if (!refreshed) {
        if (_confirmed.uncertain && raw != null) return;
        if (!_confirmed.uncertain && raw == _confirmed.raw) return;
      }
      _confirmed
        ..raw = raw
        ..uncertain = false
        ..alert80Enabled = true
        ..failed = false;
      if (raw == null) return;
      final decoded = raw is String ? jsonDecode(raw) : null;
      if (decoded is! Map ||
          decoded.length != 2 ||
          decoded['version'] is! int ||
          decoded['version'] != 1 ||
          decoded['alert80Enabled'] is! bool) {
        _confirmed.failed = true;
        return;
      }
      _confirmed.alert80Enabled = decoded['alert80Enabled'] as bool;
    } catch (_) {
      _confirmed
        ..failed = true
        ..uncertain = true;
    }
  }

  /// Returns true only after persistence succeeds while this profile is current.
  /// Serializes writes even across reconstructed instances using the same
  /// preferences object. A write finishing after deletion removes its late
  /// record; one finishing after navigation preserves the still-present profile.
  Future<bool> setAlert80Enabled(bool enabled) {
    if (!_isCurrent() || !_isProfilePresent()) {
      return Future<bool>.value(false);
    }
    final queue = _queues[_preferences] ??= <String, Future<void>>{};
    final previous = queue[_key] ?? Future<void>.value();
    _confirmed.pending += 1;
    final result = previous.then((_) => _write(enabled));
    final pending = result.then<void>((_) {
      _confirmed.pending -= 1;
    });
    queue[_key] = pending;
    pending.then((_) {
      if (identical(queue[_key], pending)) queue.remove(_key);
    });
    return result;
  }

  Future<bool> _write(bool enabled) async {
    if (!_isCurrent() || !_isProfilePresent()) return false;
    try {
      final raw = jsonEncode({'version': 1, 'alert80Enabled': enabled});
      final redacted = KitRedact.text(raw);
      if (redacted != raw) {
        _confirmed.failed = true;
        return false;
      }
      final saved = await _preferences.setString(_key, redacted);
      if (!saved) {
        _confirmed.uncertain = true;
        // SharedPreferences updates its cache even when the platform refuses
        // a write. Reload so reconstruction cannot treat that as a saved value.
        await _preferences.reload();
        _read(refreshed: true);
        _confirmed.failed = true;
        return false;
      }
      if (!_isProfilePresent()) return false;
      _confirmed
        ..raw = redacted
        ..alert80Enabled = enabled
        ..failed = false
        ..uncertain = false;
      return _isCurrent();
    } catch (_) {
      _confirmed.uncertain = true;
      try {
        await _preferences.reload();
        _read(refreshed: true);
      } catch (_) {
        // Only the fixed failed flag is exposed.
      }
      _confirmed.failed = true;
      return false;
    } finally {
      if (!_isProfilePresent()) {
        _confirmed
          ..alert80Enabled = true
          ..raw = null;
        try {
          final removed = await _preferences.remove(_key);
          _confirmed.uncertain = !removed;
          if (!removed) _confirmed.failed = true;
        } catch (_) {
          _confirmed
            ..failed = true
            ..uncertain = true;
        }
      }
    }
  }
}

class _ConfirmedPreference {
  Object? raw;
  bool alert80Enabled = true;
  bool failed = false;
  bool uncertain = false;
  int pending = 0;
}
