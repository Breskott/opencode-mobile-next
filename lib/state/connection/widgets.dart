part of '../connection.dart';

extension _ConnectionControllerWidgets on ConnectionController {
  String get _currentWidgetScope {
    if (_lifecycleSuspended && _widgetScope.isNotEmpty) return _widgetScope;
    final identity = (_generation, api, profile?.id, directory, workspace);
    if (_widgetScopeIdentity != identity) {
      _widgetScopeIdentity = identity;
      _widgetScope = base64Url.encode(
        List<int>.generate(24, (_) => Random.secure().nextInt(256)),
      );
      _widgetActionResult = null;
      _widgetActionResults.clear();
    }
    return _widgetScope;
  }

  Map<String, int> get _widgetAppTheme {
    final palette = effectiveThemePack(themePack.value).palette(
      switch (appearance.value) {
        AppAppearance.dark => Brightness.dark,
        AppAppearance.light => Brightness.light,
        AppAppearance.system => PlatformDispatcher.instance.platformBrightness,
      },
    );
    return {
      'background': palette.background.toARGB32(),
      'text': palette.scheme.onSurface.toARGB32(),
      'muted': palette.scheme.onSurfaceVariant.toARGB32(),
      'accent': palette.scheme.primary.toARGB32(),
    };
  }

  String get _widgetProjectID => directory == null && workspace == null
      ? ''
      : receipt_crypto.sha256
            .convert(utf8.encode('$_currentWidgetScope|project'))
            .toString();

  int _widgetStartedAt(String id) {
    if (!busySessions.contains(id)) return 0;
    return _busySince
        .putIfAbsent(id, () => _openTurns[id] ?? DateTime.now())
        .millisecondsSinceEpoch;
  }

  String _widgetSteerMode(String id) {
    final gateway = api;
    if (gateway == null) return 'unknown';
    if (gateway.capabilities.promptSteering) return 'steer';
    if (gateway is MidTurnPromptGateway) {
      return switch ((gateway as MidTurnPromptGateway).midTurnPrompt(id)) {
        MidTurnPrompt.joinsTurn => 'steer',
        MidTurnPrompt.restartsTurn => 'restart',
        null => 'unknown',
      };
    }
    // A gateway without native steering uses its ordinary after-reply path.
    return 'afterReply';
  }

  Map<String, Object?>? get _widgetOnDemand {
    final owner = _connectedProfile;
    if (owner == null ||
        owner.transientTransport ||
        !isProfileReadable(owner.id)) {
      return null;
    }
    return {
      'fingerprint': widgetProfileFingerprint(owner),
      'directory': directory,
      'workspace': workspace,
    };
  }

  List<String> _widgetOnDemandActions(String sessionID) {
    final owner = _connectedProfile;
    if (owner == null ||
        owner.transientTransport ||
        owner.backend != ServerBackend.openCode ||
        !isProfileReadable(owner.id)) {
      return const [];
    }
    return [
      if (permissionForSession(sessionID) != null) ...['allowOnce', 'reject'],
      if (busySessions.contains(sessionID) &&
          _widgetRunMarkers.containsKey(sessionID))
        'stop',
    ];
  }

  Map<String, Map<String, Object?>> _widgetSessionDetails() => {
    for (final session in sessionsById.values)
      session.id: {
        'startedAt': busySessions.contains(session.id)
            ? _widgetStartedAt(session.id)
            : 0,
        'step': busySessions.contains(session.id)
            ? (_runningToolDetail[session.id] ?? '')
            : '',
        'steerMode': _widgetSteerMode(session.id),
        'onDemandActions': _widgetOnDemandActions(session.id),
        'runMarker': ?_widgetRunMarkers[session.id],
        if (permissionForSession(session.id) case final request?)
          'requestID': request.id,
        'todos': [
          for (final (index, task)
              in (_widgetTasks[session.id] ?? const <MobileTaskItem>[])
                  .take(5)
                  .indexed)
            {
              'title': _shellStrings().kitProgressStep(
                index + 1,
                _widgetTasks[session.id]!.length,
              ),
              'done': task.status == MobileTaskStatus.completed,
            },
        ],
        if (_sessionTasks[session.id] case final tasks?) ...{
          'tasksDone': tasks.done,
          'tasksTotal': tasks.total,
        },
      },
  };

  String? _widgetTeamAction(TeamProject project) {
    final team = orchestration;
    if (project.simulated ||
        team == null ||
        team.isStale ||
        team.phase != OrchestrationPhase.ready) {
      return null;
    }
    if (team.capabilities.projectLanes &&
        !project.planApproved &&
        const {'plan', 'planned'}.contains(project.status) &&
        project.tasks.isNotEmpty &&
        project.specVersions.isNotEmpty) {
      return 'approvePlan';
    }
    if (team.capabilities.projectResume &&
        project.planApproved &&
        const {'paused', 'interrupted'}.contains(project.status)) {
      return 'resume';
    }
    return null;
  }

  List<Map<String, Object?>> _widgetTeamRows() {
    final projects = orchestration?.projectController?.snapshot;
    if (projects == null || projects.simulated) return const [];
    final ranked = projects.projects.where((p) => !p.simulated).toList()
      ..sort((a, b) {
        int rank(TeamProject project) => _widgetTeamAction(project) != null
            ? 0
            : project.status == 'running'
            ? 1
            : 2;
        return rank(a).compareTo(rank(b));
      });
    return [
      for (final project in ranked.take(1))
        {
          'id': 'team:${project.id}',
          'title': safeWidgetTitle(project.name),
          'busy': project.status == 'running',
          'updatedAt':
              DateTime.tryParse(project.updatedAt)?.millisecondsSinceEpoch ?? 0,
          'startedAt': 0,
          'step': '',
          'steerMode': 'unknown',
          'todos': const [],
          'onDemandActions': [
            if (_connectedProfile?.transientTransport == false &&
                _connectedProfile?.orchestration?.provider ==
                    OrchestrationProvider.phoneEngine)
              ?_widgetTeamAction(project),
          ],
          'team': {
            'revision': project.revision,
            'runID': project.id,
            'gateID': receipt_crypto.sha256
                .convert(
                  utf8.encode(
                    '$_currentWidgetScope|${project.id}|${project.revision}',
                  ),
                )
                .toString(),
            'action': ?_widgetTeamAction(project),
            'done': project.tasks
                .where(
                  (t) =>
                      const {'done', 'merged', 'accepted'}.contains(t.status),
                )
                .length,
            'total': project.tasks.length,
          },
        },
    ];
  }

  Future<WidgetActionResult> _handleWidgetAction(WidgetAction action) async {
    WidgetActionResult refuse(String error) =>
        WidgetActionResult(action.id, action.action, 'rejected', error);
    final scope = _currentWidgetScope;
    bool current() =>
        !_disposed &&
        !_widgetSnapshotSuspended &&
        !_lifecycleSuspended &&
        isConnected &&
        (!_lifecycleWasBackgrounded ||
            keepLiveInBackground && backgroundLive.active) &&
        action.profileID == profile?.id &&
        action.scopeToken == _currentWidgetScope;
    if (!current()) return refuse('staleRequest');
    final previous = _widgetActionResults[action.id];
    if (previous != null) return previous;
    final gateway = api;
    if (gateway == null || !_ownsProfileServices) return refuse('unavailable');
    final target = action.action == 'voice'
        ? 'voice'
        : action.runID.isNotEmpty
        ? action.runID
        : action.sessionID;
    if (!_widgetActionsInFlight.add(target)) return refuse('busy');
    WidgetActionResult result = WidgetActionResult(
      action.id,
      action.action,
      'uncertain',
      'uncertainDelivery',
    );
    _widgetActionResults[action.id] = result;
    try {
      switch (action.action) {
        case 'allowOnce':
        case 'reject':
          final permission = permissions[action.requestID];
          if (permission == null ||
              permission.sessionID != action.sessionID ||
              !awaitingPermissions.contains(permission)) {
            result = refuse('staleRequest');
            break;
          }
          final identity = permissionIdentity(permission);
          var confirmed = false;
          await _sendPermissionReply(
            gateway,
            action.requestID,
            action.action == 'allowOnce' ? 'once' : 'reject',
            expectedRequest: identity,
            onConfirmed: () {
              confirmed = true;
            },
          );
          if (confirmed) {
            result = WidgetActionResult(action.id, action.action, 'accepted');
          } else if (current()) {
            result = refuse('staleRequest');
          }
        case 'stop':
        case 'steer':
          if (!busySessions.contains(action.sessionID) ||
              action.expectedStartedAt <= 0 ||
              action.expectedStartedAt != _widgetStartedAt(action.sessionID)) {
            result = refuse('staleRequest');
            break;
          }
          if (action.action == 'stop') {
            await gateway.abort(action.sessionID);
          } else {
            final mode = _widgetSteerMode(action.sessionID);
            if (mode == 'unknown' || mode == 'restart') {
              result = refuse('unsupported');
              break;
            }
            if (action.text.isEmpty) {
              result = refuse('invalidRequest');
              break;
            }
            await gateway.promptAsync(
              action.sessionID,
              text: action.text,
              delivery: gateway.capabilities.promptSteering
                  ? PromptDelivery.steer
                  : null,
            );
          }
          result = WidgetActionResult(action.id, action.action, 'accepted');
        case 'voice':
          if (action.text.isEmpty ||
              action.lastProjectID.isEmpty ||
              action.lastProjectID != _widgetProjectID) {
            result = refuse('staleRequest');
            break;
          }
          final session = gateway is SessionSelectionGateway
              ? await (gateway as SessionSelectionGateway)
                    .createSelectedSession(
                      SessionSelection(
                        model: selectedModel,
                        variant: selectedVariant,
                        agent: selectedAgent,
                      ),
                    )
              : await gateway.createSession();
          if (!current()) break; // Creation may have committed: never replay.
          sessionsById[session.id] = session;
          _sessionInventoryIDs.add(session.id);
          await gateway.promptAsync(
            session.id,
            text: action.text,
            model: selectedModel,
            agent: selectedAgent,
            variant: selectedVariant,
          );
          result = WidgetActionResult(action.id, action.action, 'accepted');
        case 'approvePlan':
        case 'resume':
          final controller = orchestration?.projectController;
          final project = controller?.snapshot?.projects
              .where((p) => p.id == action.runID)
              .firstOrNull;
          final expectedGate = project == null
              ? ''
              : receipt_crypto.sha256
                    .convert(
                      utf8.encode('$scope|${project.id}|${project.revision}'),
                    )
                    .toString();
          if (controller == null ||
              project == null ||
              controller.snapshot?.simulated != false ||
              action.gateID != expectedGate ||
              _widgetTeamAction(project) != action.action) {
            result = refuse('staleRequest');
            break;
          }
          final response = await controller.execute(
            TeamProjectCommand(
              requestId: action.id,
              action: action.action == 'approvePlan'
                  ? TeamProjectAction.approvePlan
                  : TeamProjectAction.resumeProject,
              projectId: project.id,
              expectedRevision: project.revision,
            ),
          );
          result = response.accepted
              ? WidgetActionResult(action.id, action.action, 'accepted')
              : response.code == 'busy'
              ? refuse('busy')
              : response.code == 'saveFailed'
              ? WidgetActionResult(
                  action.id,
                  action.action,
                  'uncertain',
                  'uncertainDelivery',
                )
              : refuse('unavailable');
      }
    } catch (_) {
      // A failed await cannot prove a mutation was not delivered. Never expose
      // a server error, auto retry, or turn an uncertain steer into a new turn.
    } finally {
      _widgetActionsInFlight.remove(target);
    }
    if (current() && scope == _currentWidgetScope) {
      _widgetActionResults[action.id] = result;
      while (_widgetActionResults.length > 32) {
        _widgetActionResults.remove(_widgetActionResults.keys.first);
      }
      _widgetActionResult = result;
      _notifyListeners();
    }
    return result;
  }
}
