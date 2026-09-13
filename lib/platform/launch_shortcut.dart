import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'platform_capabilities.dart';

/// The whitelisted launcher actions. `connect` and `newTask` are the static
/// shortcuts in `res/xml/shortcuts.xml`; `activity` is what the Quick
/// Settings tile sends when tapped. Wire values are the action ids; anything
/// else the native side or a future build might send is dropped rather than
/// mapped.
enum LaunchAction {
  connect('connect'),
  newTask('new_task'),
  activity('activity');

  const LaunchAction(this.wireValue);

  /// The `oc.shortcut` extra / channel string for this action.
  final String wireValue;

  static LaunchAction? fromWire(Object? value) {
    if (value is! String) return null;
    final normalized = value.trim();
    for (final action in values) {
      if (action.wireValue == normalized) return action;
    }
    return null;
  }
}

/// A pinned-session launcher shortcut tapped on the home screen: the exact
/// session to open, addressed by IDs only. Nothing else travels with the
/// tap — no title, no prompt text — so the shortcut can never become an
/// automatic send.
@immutable
class SessionLaunch {
  const SessionLaunch({required this.profileID, required this.sessionID});

  /// The server profile the session belongs to. Routing drops a launch whose
  /// profile is not the active one instead of switching servers silently,
  /// mirroring the home-screen widget rows.
  final String profileID;
  final String sessionID;

  static SessionLaunch? fromWire(Object? value) {
    if (value is! Map) return null;
    final profileID = value['profileID']?.toString().trim() ?? '';
    final sessionID = value['sessionID']?.toString().trim() ?? '';
    if (profileID.isEmpty || sessionID.isEmpty) return null;
    return SessionLaunch(profileID: profileID, sessionID: sessionID);
  }

  @override
  bool operator ==(Object other) =>
      other is SessionLaunch &&
      other.profileID == profileID &&
      other.sessionID == sessionID;

  @override
  int get hashCode => Object.hash(profileID, sessionID);

  @override
  String toString() => 'SessionLaunch($profileID, $sessionID)';
}

/// A launcher shortcut tapped on the home screen. The Kotlin side captures
/// the `oc.shortcut` extra (or the `oc.shortcut.profile` /
/// `oc.shortcut.session` pair of a pinned-session shortcut) and hands it
/// over here; [pending] and [pendingSession] hold it until the app shell
/// routes it. Mirrors ShareIntent: one consume on start for the tap that
/// launched the app, a live `launched` / `launchedSession` push for taps
/// while the engine is already running. This class never connects, creates
/// a session or sends anything; routing owns that. Off Android the class is
/// inert.
class LaunchShortcut {
  LaunchShortcut({@visibleForTesting MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('oc/shortcut');

  final MethodChannel _channel;

  /// The most recent static shortcut action that nothing has consumed yet.
  final ValueNotifier<LaunchAction?> pending = ValueNotifier<LaunchAction?>(
    null,
  );

  /// The most recent pinned-session tap that nothing has consumed yet.
  final ValueNotifier<SessionLaunch?> pendingSession =
      ValueNotifier<SessionLaunch?>(null);

  bool _started = false;
  bool _disposed = false;
  int _acceptGeneration = 0;
  int _acceptSessionGeneration = 0;

  static bool get supported => platformCapabilities.supportsLaunchShortcuts;

  /// Registers for shortcut taps delivered while the app is running and
  /// drains the tap that may have launched it. Safe to call once; later
  /// calls no-op.
  Future<void> start() async {
    if (_started || _disposed || !supported) return;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (_disposed) return null;
      switch (call.method) {
        case 'launched':
          _accept(call.arguments);
        case 'launchedSession':
          _acceptSession(call.arguments);
      }
      return null;
    });
    final consumeGeneration = _acceptGeneration;
    final consumeSessionGeneration = _acceptSessionGeneration;
    try {
      final value = await _channel.invokeMethod<String>('consumeLaunchAction');
      // A live tap can arrive while the cold-start consume is in flight.
      // Keep that newer value instead of allowing the stale cold-start
      // value to replace it.
      if (!_disposed && consumeGeneration == _acceptGeneration) {
        _accept(value);
      }
      final session = await _channel.invokeMethod<Map<Object?, Object?>>(
        'consumeSessionLaunch',
      );
      if (!_disposed && consumeSessionGeneration == _acceptSessionGeneration) {
        _acceptSession(session);
      }
    } on MissingPluginException {
      // Tests and desktop hosts have no channel implementation.
    } on PlatformException {
      // A capture failure must never block startup.
    }
  }

  void _accept(Object? value) {
    if (_disposed) return;
    final action = LaunchAction.fromWire(value);
    if (action == null) return;
    _acceptGeneration++;
    pending.value = action;
  }

  void _acceptSession(Object? value) {
    if (_disposed) return;
    final launch = SessionLaunch.fromWire(value);
    if (launch == null) return;
    _acceptSessionGeneration++;
    pendingSession.value = launch;
  }

  /// Takes the pending action, leaving nothing behind.
  LaunchAction? take() {
    if (_disposed) return null;
    final action = pending.value;
    pending.value = null;
    return action;
  }

  /// Takes the pending pinned-session tap, leaving nothing behind.
  SessionLaunch? takeSession() {
    if (_disposed) return null;
    final launch = pendingSession.value;
    pendingSession.value = null;
    return launch;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_started) _channel.setMethodCallHandler(null);
    pending.dispose();
    pendingSession.dispose();
  }
}
