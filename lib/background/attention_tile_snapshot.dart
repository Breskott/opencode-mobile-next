import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../platform/platform_capabilities.dart';

/// Caches the needs-attention count for the Android Quick Settings tile.
///
/// The tile is a native `TileService` that may be shown while the app is not
/// running, so it reads this snapshot (`flutter.oc.attentionTile` in the
/// Flutter preferences file) instead of asking a controller. The count is
/// the same one the Activity tab shows — pending permissions, questions and
/// forms of the connected server — and nothing else is written: no titles,
/// no request text, no server address. Without a snapshot the tile shows a
/// plain "OpenCode" and no count.
class AttentionTileSnapshot {
  AttentionTileSnapshot({
    required this.prefs,
    bool? isAndroid,
    DateTime Function()? now,
  }) : _isAndroid = isAndroid ?? platformCapabilities.supportsQuickSettingsTile,
       _now = now ?? DateTime.now;

  /// Read by the native tile as `flutter.oc.attentionTile`.
  static const prefsKey = 'oc.attentionTile';

  final SharedPreferences prefs;
  final bool _isAndroid;
  final DateTime Function() _now;
  int? _lastCount;
  String? _lastProfileID;

  /// Writes [pendingCount] for [profileID] when either changed. The stamped
  /// time lets the tile refuse to show a count from a long-gone session.
  Future<void> update({
    required int pendingCount,
    required String profileID,
  }) async {
    if (!_isAndroid) return;
    final count = pendingCount < 0 ? 0 : pendingCount;
    if (count == _lastCount && profileID == _lastProfileID) return;
    _lastCount = count;
    _lastProfileID = profileID;
    await prefs.setString(
      prefsKey,
      jsonEncode({
        'pendingCount': count,
        'profileID': profileID,
        'updatedAt': _now().millisecondsSinceEpoch,
      }),
    );
  }

  /// Drops the cache so the tile falls back to "OpenCode" with no count.
  /// Used on an explicit disconnect, when the count stops being true.
  Future<void> clear() async {
    if (!_isAndroid) return;
    _lastCount = null;
    _lastProfileID = null;
    await prefs.remove(prefsKey);
  }

  /// Drops the cache when it belongs to [profileID]. A payload written
  /// without an owner is dropped too. Runs on every platform: the stored
  /// value is the artifact, and only the tile is Android-specific.
  Future<AttentionTileClear> clearForProfile(String profileID) async {
    final raw = prefs.getString(prefsKey);
    if (raw == null) return AttentionTileClear.nothingToClear;
    String? owner;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) owner = decoded['profileID']?.toString() ?? '';
    } catch (_) {
      owner = '';
    }
    if (owner == null || (owner.isNotEmpty && owner != profileID)) {
      return AttentionTileClear.nothingToClear;
    }
    try {
      if (!await prefs.remove(prefsKey)) return AttentionTileClear.failed;
    } catch (_) {
      return AttentionTileClear.failed;
    }
    _lastCount = null;
    _lastProfileID = null;
    return AttentionTileClear.cleared;
  }
}

/// What [AttentionTileSnapshot.clearForProfile] actually did.
enum AttentionTileClear { nothingToClear, cleared, failed }
