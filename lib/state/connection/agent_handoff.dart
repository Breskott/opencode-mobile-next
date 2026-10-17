part of '../connection.dart';

// Continue with… (docs/design/agent-handoff-contract.md): the few facts only
// the connection holds. The sheet's own logic is in continue_with.dart and
// continue_with_connection.dart; nothing here sends or writes.

extension ConnectionAgentHandoff on ConnectionController {
  /// The connection that owns the agents on this phone for this conversation:
  /// the main one, or the parent of an agent's own backend.
  ConnectionController get agentHandoffHub =>
      isAgentBackend ? (_genUiParent ?? this) : this;

  /// "Working", "Waiting for you", "Failed" or "Unknown" in plain words for
  /// the record (never inferred from an idle transport alone).
  String agentHandoffLastState(String sessionID) {
    if (busySessions.contains(sessionID)) return 'Working';
    if (permissionsForSession(sessionID).isNotEmpty ||
        questions.values.any((q) => q.sessionID == sessionID)) {
      return 'Waiting for you';
    }
    if (_failedAttentionSessions.containsKey(sessionID)) return 'Failed';
    return 'Unknown';
  }

  /// The connection to the agent host for [directory] (a project under
  /// `/root/projects`). Throws a ProductException in plain words when the
  /// host cannot be reached; starts the host when Android stopped it.
  Future<ServerGateway> agentHandoffTargetGateway(String directory) async =>
      (await agentHandoffHub._paReachSource(directory)).gateway;

  /// Makes a conversation the first prompt just created openable: the app
  /// finds its backend by id.
  Future<void> agentHandoffAdopt({
    required String directory,
    required String agentId,
    required String sessionId,
  }) async {
    final hub = agentHandoffHub;
    final descriptor = hub._paCatalog.byId(agentId);
    hub._paLive.add(
      jsonEncode([_paseoSourceId(directory), sessionId, directory]),
    );
    hub._paOwners[sessionId] = await hub._paBackendFor(
      directory,
      agentName: descriptor?.name,
      agentId: agentId,
    );
    hub.notifyListeners();
  }
}
