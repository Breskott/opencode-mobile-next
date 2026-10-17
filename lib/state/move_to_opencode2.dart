import 'package:shared_preferences/shared_preferences.dart';

import 'profiles.dart';

/// The servers whose "Move to OpenCode 2" line the person dismissed with
/// "Not now", per saved server. The line is the only place the move is
/// offered, so a dismissal ends it for that server for good. Kept under
/// `oc.moveToOpenCode2Dismissed.<profileId>`, so deleting the server sweeps
/// it (ProfileStore's scoped-key sweep).
abstract final class MoveToOpenCode2Dismissal {
  static String keyFor(String profileId) =>
      'oc.moveToOpenCode2Dismissed.$profileId';

  static bool dismissed(SharedPreferences prefs, String profileId) {
    try {
      return prefs.getBool(keyFor(profileId)) ?? false;
    } catch (_) {
      // A value of another type: nothing was dismissed that can be read.
      return false;
    }
  }

  /// Saves the dismissal. False when storage refused it; the line is then
  /// hidden only until the page is opened again.
  static Future<bool> dismiss(SharedPreferences prefs, String profileId) async {
    try {
      return await prefs.setBool(keyFor(profileId), true);
    } catch (_) {
      return false;
    }
  }
}

/// When a switch gives this phone a different saved server (one per
/// runtime), the AI Team that was on for the old one follows to the new
/// one: its config and engine credential move, so the team stays on and the
/// start that follows brings it back. A target that already has its own
/// team config keeps it; a remote server's team is never touched
/// ([sameHost] picks only this phone's own servers).
Future<void> teamFollowsRuntime(
  ProfileStore store,
  ServerProfile target, {
  required bool Function(ServerProfile profile) sameHost,
}) async {
  if (target.orchestration != null) return;
  for (final from in [...store.profiles]) {
    if (from.id == target.id || !sameHost(from)) continue;
    final config = from.orchestration;
    if (config == null) continue;
    target
      ..orchestration = config
      ..teamEngineAuth = from.teamEngineAuth;
    from
      ..orchestration = null
      ..teamEngineAuth = '';
    await store.upsert(target);
    await store.upsert(from);
    return;
  }
}
