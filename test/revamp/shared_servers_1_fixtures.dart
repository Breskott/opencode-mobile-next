// Shared fixtures for shared-servers-1's behaviour tests and goldens: a
// store with one current server and three saved ones, a controller whose
// attention source answers with fixed snapshots, and a Claude Code runtime
// that never touches Termux.
import 'dart:async';

import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profile_monitor.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:opencode_mobile/termux/local_agent_runtime.dart';

/// Work (current), Laptop, Lab box and a server whose password is needed
/// again. Nothing is read from secure storage.
class SwitcherStore extends ProfileStore {
  SwitcherStore({required super.prefs});

  final _profiles = [
    ServerProfile(
      id: 'work',
      name: 'Work server',
      baseUrl: 'https://work.example.test',
    ),
    ServerProfile(
      id: 'laptop',
      name: 'Laptop',
      baseUrl: 'https://laptop.example.test:4096',
    ),
    ServerProfile(
      id: 'lab',
      name: 'Lab box',
      baseUrl: 'https://lab.example.test',
    ),
    ServerProfile(
      id: 'locked',
      name: 'Home desk',
      baseUrl: 'https://home.example.test',
      requiresPasswordReentry: true,
    ),
  ];

  @override
  List<ServerProfile> get profiles => _profiles;

  @override
  String? get activeId => 'work';
}

class SwitcherController extends ConnectionController {
  SwitcherController(
    super.store, {
    Map<String, ProfileAttentionSnapshot> snapshots = const {},
  }) : _snapshots = snapshots;

  // The base constructor already reads the monitor, so it is made lazily.
  final Map<String, ProfileAttentionSnapshot> _snapshots;
  FixedMonitor? _monitor;
  int disconnects = 0;

  @override
  ProfileMonitor get profileMonitor =>
      _monitor ??= FixedMonitor(store, _snapshots);

  @override
  bool isProfileReadable(String id) => true;

  @override
  Future<void> disconnect({bool keepActive = false, bool silent = false}) {
    disconnects++;
    return super.disconnect(keepActive: keepActive, silent: silent);
  }
}

/// The other servers' watcher, answering with [fixed].
class FixedMonitor extends ProfileMonitor {
  FixedMonitor(ProfileStore store, this.fixed)
    : super(
        store: store,
        createGateway: (_) => throw UnimplementedError(),
        isReadable: (_) => true,
        networkWifi: () async => null,
        alert: (_, _, _, _) async => false,
        dismiss: (_) async => false,
      );

  final Map<String, ProfileAttentionSnapshot> fixed;

  @override
  ProfileAttentionSnapshot snapshotFor(String id) =>
      fixed[id] ??
      ProfileAttentionSnapshot(
        profileID: id,
        status: ProfileMonitorStatus.disabled,
      );
}

ProfileAttentionSnapshot snapshot(
  String id, {
  int waiting = 0,
  int running = 0,
  bool current = true,
}) => ProfileAttentionSnapshot(
  profileID: id,
  status: current
      ? ProfileMonitorStatus.current
      : ProfileMonitorStatus.disabled,
  complete: true,
  runningCount: running,
  requests: [
    for (var i = 0; i < waiting; i++)
      MonitoredRequest(
        id: 'perm-$i',
        sessionID: 's-$i',
        kind: MonitoredRequestKind.permission,
      ),
  ],
);

/// Installed Claude Code in [phase], signed in unless [signedIn] says so.
LocalAgentStatus agentStatus(
  LocalAgentPhase phase, {
  LocalAgentSignIn signedIn = LocalAgentSignIn.yes,
  String? paseo,
}) => LocalAgentStatus(
  phase: phase,
  installed: true,
  signedIn: signedIn,
  nodeVersion: 'v24.21.0',
  paseoVersion: paseo ?? TermuxBridge.localAgentsPins['paseo_version'] ?? '',
  claudeVersion: '2.1.278',
);

ServerProfile savedAgentProfile() => ServerProfile(
  id: 'claude',
  name: 'Claude Code',
  baseUrl: TermuxBridge.localAgentsUrl,
  backend: ServerBackend.paseo,
  codexDirectory: '/root/projects/app',
);

class FakeAgentRuntime extends LocalAgentRuntime {
  FakeAgentRuntime(this.current)
    : super(
        runner: (_, {Duration timeout = Duration.zero}) async => '',
        terminalOpener: (_) async => true,
      );

  LocalAgentStatus current;
  final calls = <String>[];
  LocalAgentFailure? startFailure;
  LocalAgentFailure? statusFailure;
  Completer<LocalAgentStatus>? _held;

  void holdStart() => _held = Completer<LocalAgentStatus>();

  void releaseStart(LocalAgentStatus status) => _held?.complete(status);

  @override
  Future<LocalAgentStatus> status() async {
    final failure = statusFailure;
    if (failure != null) throw failure;
    return current;
  }

  @override
  Future<LocalAgentStatus> start() async {
    calls.add('start');
    final failure = startFailure;
    if (failure != null) throw failure;
    final held = _held;
    if (held != null) return current = await held.future;
    return current = agentStatus(LocalAgentPhase.ready);
  }

  @override
  Future<LocalAgentStatus> restart() => start();

  @override
  Future<LocalAgentStatus> stop() async {
    calls.add('stop');
    return current = agentStatus(LocalAgentPhase.installed);
  }

  @override
  Future<LocalAgentStatus> remove({bool forgetSignIn = false}) async {
    calls.add('remove');
    return current = const LocalAgentStatus(phase: LocalAgentPhase.absent);
  }

  @override
  Future<bool> openSignIn() async {
    calls.add('signin');
    return true;
  }
}
