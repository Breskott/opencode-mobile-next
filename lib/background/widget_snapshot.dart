import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/models.dart';
import '../platform/platform_capabilities.dart';
import '../l10n/app_localizations.dart';
import '../ui/kit/kit_redact.dart';
import '../ui/widgets/session_title.dart';
import 'widget_v2_contract.dart';

/// Persists a compact recent-sessions snapshot for the Android home-screen
/// widget and asks native to redraw it.
///
/// Privacy: the widget deliberately shows session titles. The recorded
/// notification rules (fixed copy only, no titles) protect the lock screen,
/// where content appears without the user's choice; a home-screen widget is
/// a surface the user explicitly placed, sized, and can remove, and it shows
/// exactly the titles the launcher-visible app UI shows. Prompt text, tool
/// input, file names, and server errors are never written.
class WidgetSessionSnapshot {
  WidgetSessionSnapshot({
    required this.prefs,
    Future<void> Function()? refreshNative,
    bool? isAndroid,
  }) : _refreshNative = refreshNative ?? _refreshViaChannel,
       _isAndroid = isAndroid ?? platformCapabilities.supportsHomeWidget;

  /// Read by the native widget as `flutter.oc.widgetSessions`.
  static const prefsKey = 'oc.widgetSessions';

  /// App-private connection routing, never part of the launcher snapshot.
  static String targetKey(String profileID) => 'oc.widgetTarget.$profileID';

  static Map<String, Object?>? _opaqueTarget(Map? target) =>
      target?['fingerprint'] is String
      ? {'fingerprint': target!['fingerprint']}
      : null;

  Future<bool> _saveTarget(
    String profileID,
    String scopeToken,
    Map? target,
  ) async {
    if (profileID.isEmpty) return target == null;
    final key = targetKey(profileID);
    if (_opaqueTarget(target) == null || scopeToken.isEmpty) {
      return !prefs.containsKey(key) || await prefs.remove(key);
    }
    final encoded = jsonEncode({
      'profileID': profileID,
      'scopeToken': scopeToken,
      'fingerprint': target!['fingerprint'],
      'directory': target['directory'],
      'workspace': target['workspace'],
    });
    return prefs.getString(key) == encoded ||
        await prefs.setString(key, encoded);
  }

  /// At most this many sessions are ever written.
  static const maxSessions = 4;

  static const _channel = MethodChannel('oc/background');

  final SharedPreferences prefs;
  final Future<void> Function() _refreshNative;
  final bool _isAndroid;
  String? _lastWritten;
  Future<void> _writeTail = Future.value();

  /// Native service pause invalidates its disk copy outside the Dart cache.
  /// Force the next event publication to restore the complete current truth.
  void invalidateNativeCopy() {
    _lastWritten = null;
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final next = _writeTail.then((_) => action());
    _writeTail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  /// Redraws the home-screen widget. The attention tile snapshot reuses it so
  /// only this file and live_background.dart talk to `oc/background`.
  static Future<void> refreshHomeWidget() => _refreshViaChannel();

  static Future<void> _refreshViaChannel() async {
    try {
      await _channel.invokeMethod<Object?>('refreshHomeWidget');
    } catch (_) {
      // No engine-side handler (tests, desktop, activity gone): the widget
      // simply keeps its last drawn state.
    }
  }

  /// Serializes the current root sessions and writes them only when the
  /// payload actually changed, so frequent controller notifications stay
  /// cheap and the widget redraws only on real changes.
  ///
  /// [profileID] names the server profile the sessions belong to. The widget
  /// stamps it onto every row's tap intent so a tap after a profile switch
  /// opens the app normally instead of another profile's chat.
  Future<void> update({
    required List<Session> sessions,
    required Set<String> busySessions,
    required bool connected,
    String profileID = '',
    String? untitledLabel,
    AppLocalizations? l10n,
    String scopeToken = '',
    String lastProjectID = '',
    int pendingCount = 0,
    Map<String, Map<String, Object?>> details = const {},
    List<Map<String, Object?>> teamRows = const [],
    WidgetActionResult? actionResult,
    Map<String, int> appTheme = const {},
    Map<String, Object?>? onDemand,
    bool preserveForOnDemand = false,
  }) async {
    if (!_isAndroid) return;
    // The widget has no widget tree: its caller supplies the app language.
    // Share the app's presentation so dated server placeholders never leak
    // into launcher titles, then apply the launcher privacy/length limits.
    final strings = l10n ?? lookupAppLocalizations(const Locale('en'));
    final ranked = sessions.indexed.toList()
      ..sort((a, b) {
        int rank(Session session) => details[session.id]?['requestID'] != null
            ? 0
            : busySessions.contains(session.id)
            ? 1
            : 2;
        final priority = rank(a.$2).compareTo(rank(b.$2));
        return priority == 0 ? a.$1.compareTo(b.$1) : priority;
      });
    final entries = [
      for (final (_, session) in ranked.take(maxSessions))
        {
          'id': session.id,
          'title': safeWidgetTitle(
            presentedSessionTitleText(
              session.title,
              fallback: untitledLabel ?? strings.workspaceNewSession,
              l10n: strings,
            ),
          ),
          'busy': busySessions.contains(session.id),
          'updatedAt': session.time?.updated ?? session.time?.created ?? 0,
          ..._safeWidgetDetails(details[session.id]),
        },
    ];
    final payload = jsonEncode({
      'version': 2,
      'onDemand': ?_opaqueTarget(onDemand),
      'appTheme': appTheme,
      'scopeToken': scopeToken,
      'lastProjectID': lastProjectID,
      'runningCount': busySessions.length,
      'pendingCount': pendingCount,
      'connected': connected,
      'profileID': profileID,
      'sessions': [
        ...entries.take(maxSessions - teamRows.length.clamp(0, 1)),
        ...teamRows.take(1),
      ].toList(),
      if (actionResult != null) 'actionResult': actionResult.toJson(),
    });
    await _serialize(() async {
      // Lifecycle suspension retires only the transport. Keep the explicit tap
      // target and its proofs until fresh foreground events replace it; never
      // resurrect a removed snapshot or one belonging to another profile.
      if (preserveForOnDemand) {
        await prefs.reload();
        final raw = prefs.getString(prefsKey);
        if (raw == null) return;
        try {
          final old = jsonDecode(raw);
          if (old is! Map || old['profileID'] != profileID) return;
          final oldTarget = old['onDemand'];
          // Migrate the previous build's routing fields on the first app event,
          // including suspension, before publishing the opaque snapshot.
          if (oldTarget is Map &&
              (oldTarget.containsKey('directory') ||
                  oldTarget.containsKey('workspace')) &&
              !await _saveTarget(
                profileID,
                old['scopeToken'] as String,
                oldTarget,
              )) {
            return;
          }
          final paused = jsonEncode({
            ...old,
            'onDemand': oldTarget is Map ? _opaqueTarget(oldTarget) : null,
            'connected': false,
          });
          if (paused != raw && await prefs.setString(prefsKey, paused)) {
            _lastWritten = paused;
            await _refreshNative();
          }
        } catch (_) {}
        return;
      }
      // Publish routing first; mismatched scope/fingerprint makes a partially
      // failed write unusable rather than dispatching to a default directory.
      if (!await _saveTarget(profileID, scopeToken, onDemand)) return;
      if (payload == _lastWritten && prefs.getString(prefsKey) == payload) {
        return;
      }
      if (!await prefs.setString(prefsKey, payload)) return;
      _lastWritten = payload;
      await _refreshNative();
    });
  }

  /// Drops the snapshot when it belongs to [profileID], so removing a server
  /// also removes the session titles its widget was still showing on the home
  /// screen. A snapshot written before rows carried a profile has no
  /// identifiable owner and is dropped too.
  ///
  /// The three outcomes are kept apart deliberately: "there was nothing of
  /// yours to clear" and "the write refused" look identical to a caller that
  /// only gets a bool, and a deletion flow has to tell the user the
  /// difference.
  ///
  /// Runs on every platform: the stored payload is the privacy-relevant
  /// artifact, and only the native redraw is Android-specific.
  Future<WidgetSnapshotClear> clearForProfile(String profileID) =>
      _serialize(() => _clearForProfile(profileID));

  Future<WidgetSnapshotClear> _clearForProfile(String profileID) async {
    if (_isAndroid) {
      try {
        final result = await _channel.invokeMapMethod<String, dynamic>(
          'clearWidgetProfile',
          {'profileID': profileID},
        );
        // A host that answers with nothing has no native copy to clear; only
        // an explicit refusal from the native side counts as a failure.
        if (result != null && result['cleared'] != true) {
          return WidgetSnapshotClear.failed;
        }
      } on MissingPluginException {
        // Injected test writer, or unsupported host with no native state.
      } catch (_) {
        return WidgetSnapshotClear.failed;
      }
    }
    final hadTarget = prefs.containsKey(targetKey(profileID));
    try {
      if (hadTarget && !await prefs.remove(targetKey(profileID))) {
        return WidgetSnapshotClear.failed;
      }
    } catch (_) {
      return WidgetSnapshotClear.failed;
    }
    final raw = prefs.getString(prefsKey);
    if (raw == null) {
      return hadTarget
          ? WidgetSnapshotClear.cleared
          : WidgetSnapshotClear.nothingToClear;
    }
    String? owner;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) owner = decoded['profileID']?.toString() ?? '';
    } catch (_) {
      // Unreadable payload: it cannot be shown to be another profile's, so
      // treat it as removable rather than leaving it behind.
      owner = '';
    }
    if (owner == null || (owner.isNotEmpty && owner != profileID)) {
      return hadTarget
          ? WidgetSnapshotClear.cleared
          : WidgetSnapshotClear.nothingToClear;
    }
    try {
      if (!await prefs.remove(prefsKey)) return WidgetSnapshotClear.failed;
    } catch (_) {
      return WidgetSnapshotClear.failed;
    }
    _lastWritten = null;
    if (_isAndroid) await _refreshNative();
    return WidgetSnapshotClear.cleared;
  }
}

/// Only reviewed compact fields cross into launcher storage.
Map<String, Object?> _safeWidgetDetails(Map<String, Object?>? details) {
  if (details == null) return const {};
  final todos = details['todos'];
  return {
    'onDemandActions': [
      if (details['onDemandActions'] is List)
        for (final action in details['onDemandActions'] as List)
          if (const {'allowOnce', 'reject', 'stop'}.contains(action)) action,
    ],
    if (details['runMarker'] case final String marker
        when marker.isNotEmpty && marker.length <= 512)
      'runMarker': marker,
    if (details['startedAt'] case final int value)
      'startedAt': value < 0 ? 0 : value,
    if (details['step'] case final String value) 'step': safeWidgetTitle(value),
    if (details['requestID'] case final String value
        when value.isNotEmpty && value.length <= 512)
      'requestID': value,
    'steerMode':
        const {
          'steer',
          'afterReply',
          'restart',
          'unknown',
        }.contains(details['steerMode'])
        ? details['steerMode']
        : 'unknown',
    'todos': todos is List
        ? [
            for (final task in todos.whereType<Map>().take(5))
              if (task['title'] is String && task['done'] is bool)
                {
                  'title': safeWidgetTitle(task['title'] as String),
                  'done': task['done'],
                },
          ]
        : const [],
    if (details['tasksDone'] case final int value)
      'tasksDone': value.clamp(0, 100000),
    if (details['tasksTotal'] case final int value)
      'tasksTotal': value.clamp(0, 100000),
  };
}

/// Control characters and the bidirectional overrides and isolates (which
/// can reorder a title on the launcher).
bool _unsafeInTitle(int c) =>
    c < 0x20 ||
    c == 0x7f ||
    (c >= 0x202a && c <= 0x202e) ||
    (c >= 0x2066 && c <= 0x2069);

String safeWidgetTitle(String value) {
  final safe = String.fromCharCodes(
    KitRedact.text(value).runes.map((c) => _unsafeInTitle(c) ? 0x20 : c),
  ).replaceAll(RegExp(r'\s+'), ' ').trim();
  return String.fromCharCodes(safe.runes.take(80));
}

/// What [WidgetSessionSnapshot.clearForProfile] actually did.
enum WidgetSnapshotClear {
  /// No snapshot, or one belonging to another profile: nothing was at risk.
  nothingToClear,

  /// The profile's snapshot is gone from disk.
  cleared,

  /// A snapshot belonging to the profile is still on disk — the store
  /// refused the write. The caller must not report the data as deleted.
  failed,
}
