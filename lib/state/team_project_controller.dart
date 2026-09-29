import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/kit/kit_redact.dart';
import 'package:flutter/foundation.dart';
import '../domain/team_project_gateway.dart';
export '../domain/team_project_gateway.dart';

class TeamProjectController extends ChangeNotifier {
  TeamProjectController(
    this.gateway, {
    this.profileId = 'team-demo',
    this.ownsGateway = true,
    this.preferences,
  });
  final String profileId;
  final bool ownsGateway;
  final SharedPreferences? preferences;
  Future<void> _draftTail = Future.value();
  bool _draftClosed = false;
  String get _draftKey => 'oc.teamEditorDrafts.$profileId';
  final OrchestrationProjectGateway gateway;
  TeamWorkspace? snapshot;
  bool loading = false;
  bool busy = false;
  String? errorCode;
  StreamSubscription<TeamWorkspace>? _subscription;
  bool _disposed = false;
  int _serial = 0;
  Future<void> load() async {
    loading = true;
    errorCode = null;
    _notify();
    _subscription ??= gateway.watchTeamWorkspace().listen(
      (value) {
        snapshot = value;
        _notify();
      },
      onError: (Object _) {
        errorCode = 'unavailable';
        _notify();
      },
    );
    try {
      snapshot = await gateway.teamWorkspace();
    } catch (_) {
      errorCode = 'unavailable';
    }
    loading = false;
    _notify();
  }

  String newRequestId() =>
      'team-${DateTime.now().microsecondsSinceEpoch}-${_serial++}';
  Future<TeamCommandResult> execute(TeamProjectCommand command) async {
    if (busy || _disposed) {
      return const TeamCommandResult(accepted: false, code: 'busy');
    }
    busy = true;
    errorCode = null;
    _notify();
    try {
      final result = await gateway.executeProject(command);
      if (!result.accepted) errorCode = result.code;
      snapshot = await gateway.teamWorkspace();
      return result;
    } catch (_) {
      errorCode = 'saveFailed';
      return const TeamCommandResult(accepted: false, code: 'saveFailed');
    } finally {
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<T> _draftAction<T>(
    Future<T> Function(SharedPreferences prefs) action,
  ) {
    final next = _draftTail.then((_) async {
      if (_disposed || _draftClosed) throw StateError('draftClosed');
      final prefs = preferences ?? await SharedPreferences.getInstance();
      if (_disposed || _draftClosed) throw StateError('draftClosed');
      try {
        return await action(prefs);
      } catch (_) {
        throw StateError('draftSaveFailed');
      }
    });
    _draftTail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Map<String, dynamic> _drafts(SharedPreferences prefs) {
    final raw = prefs.getString(_draftKey);
    return raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  String _safeDraft(String text) {
    Object? safe(Object? value) => switch (value) {
      String s => KitRedact.text(s),
      List v => v.map(safe).toList(),
      Map v => v.map((k, v) => MapEntry(k, safe(v))),
      _ => value,
    };
    try {
      return jsonEncode(safe(jsonDecode(text)));
    } catch (_) {
      return KitRedact.text(text);
    }
  }

  Future<String?> readEditorDraft(String target) => _draftAction((prefs) async {
    final value = _drafts(prefs)[target];
    return value is String ? _safeDraft(value) : null;
  });
  Future<void> saveEditorDraft(String target, String text) {
    final safe = _safeDraft(text);
    return _draftAction((prefs) async {
      final values = _drafts(prefs)..[target] = safe;
      if (!await prefs.setString(_draftKey, jsonEncode(values)))
        throw StateError('draftSaveFailed');
    });
  }

  Future<void> clearEditorDraft(String target) => _draftAction((prefs) async {
    final values = _drafts(prefs)..remove(target);
    if (!await prefs.setString(_draftKey, jsonEncode(values)))
      throw StateError('draftSaveFailed');
  });

  /// Called at profile stop before its deletion sweep; rejects future writes.
  Future<void> drainEditorDrafts() async {
    _draftClosed = true;
    await _draftTail;
  }

  Future<void> deleteLocalData() async {
    await drainEditorDrafts();
    final prefs = preferences ?? await SharedPreferences.getInstance();
    if (!await prefs.remove(_draftKey)) throw StateError('draftDeleteFailed');
    await gateway.deleteLocalData();
    snapshot = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _draftClosed = true;
    unawaited(_subscription?.cancel());
    if (ownsGateway) unawaited(gateway.close());
    super.dispose();
  }
}
