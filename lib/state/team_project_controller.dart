import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/team_project_gateway.dart';
export '../domain/team_project_gateway.dart';

class TeamProjectController extends ChangeNotifier {
  TeamProjectController(
    this.gateway, {
    this.profileId = 'team-demo',
    this.ownsGateway = true,
  });
  final String profileId;
  final bool ownsGateway;
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

  Future<void> deleteLocalData() async {
    await gateway.deleteLocalData();
    snapshot = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    if (ownsGateway) unawaited(gateway.close());
    super.dispose();
  }
}
