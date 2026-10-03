// The phone-hosted AI Team for the census scenes of `i2-team-sheets`: a
// connection to this phone's managed OpenCode 2 server (a fake v2 gateway,
// no network), a scripted TermuxTeamRuntime, and the Termux bridge as the
// setup screen sees a phone whose server is ready. Copied from the shapes
// test/team_phone_onboarding_test.dart uses.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:opencode_mobile/termux/team_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

const phoneProfileId = 'phone';

const phoneVersions = {'gc': '1.4.1', 'bd': '1.2.2', 'dolt': '2.3.3'};

TeamRuntimeStatus phoneStatus(
  TeamRuntimePhase phase, {
  String rawPhase = '',
  String? reason,
  String verb = '',
  bool installed = false,
  bool busy = false,
  String city = '',
  String project = '',
  int? agents,
  String? health,
  bool killed = false,
  String? lastError,
  Map<String, String> versions = const {},
}) => TeamRuntimeStatus(
  phase: phase,
  rawPhase: rawPhase.isEmpty ? phase.name : rawPhase,
  reason: reason,
  verb: verb,
  installed: installed,
  busy: busy,
  city: city,
  project: project,
  agents: agents,
  health: health,
  killedByAndroid: killed,
  lastError: lastError,
  versions: versions,
);

TeamRuntimeStatus phoneReady({int agents = 3, bool killed = false}) =>
    phoneStatus(
      TeamRuntimePhase.ready,
      installed: true,
      city: 'phone',
      project: '/root/projects/shopfront',
      agents: killed ? null : agents,
      health: killed ? null : 'ok',
      killed: killed,
      versions: phoneVersions,
    );

/// A scripted runtime: [current] is what `status` answers; a verb answers
/// its scripted result (or waits forever when [hang] names it).
class CensusTeamRuntime extends TermuxTeamRuntime {
  CensusTeamRuntime({this.supported = true})
    : super(
        runner: (_, {timeout = Duration.zero}) async => '',
        manifestLoader: () async =>
            '{"schema":1,"arch":"arm64","files":{"gc":{"bytes":93716776},'
            '"bd":{"bytes":72941864},"dolt":{"bytes":126391984},'
            '"wrapper":{"bytes":1200}}}',
        archProbe: () async => 'aarch64',
      );

  final bool supported;
  TeamRuntimeStatus current = phoneStatus(TeamRuntimePhase.idle);
  String log = '';
  List<String> projects = const ['/root/projects/shopfront'];
  final results = <String, TeamRuntimeStatus>{};
  final hang = <String>{};

  @override
  Future<bool> get supportsAiTeam async => supported;

  @override
  Future<TeamRuntimeStatus> status() async => current;

  @override
  Future<String> logTail({int lines = 200}) async => log;

  @override
  Future<List<String>> managedProjects() async => projects;

  @override
  Future<String> createManagedProject(String name) async =>
      '/root/projects/$name';

  Future<TeamRuntimeStatus> _verb(String verb) async {
    if (hang.contains(verb)) await Completer<void>().future;
    final result = results[verb] ?? current;
    current = result;
    return result;
  }

  @override
  Future<TeamRuntimeStatus> install({String? manifestUrl}) => _verb('install');

  @override
  Future<TeamRuntimeStatus> init(
    String projectPath, {
    String? city,
    String? rig,
  }) => _verb('init');

  @override
  Future<TeamRuntimeStatus> start() => _verb('start');

  @override
  Future<TeamRuntimeStatus> stop() => _verb('stop');

  @override
  Future<TeamRuntimeStatus> remove() => _verb('remove');
}

class _FakeChannel implements LiveEventChannel {
  _FakeChannel(this.onStatus);
  final void Function(StreamStatus status) onStatus;

  @override
  void start() => onStatus(StreamStatus.connected);

  @override
  Future<void> dispose() async {}
}

class _Gateway implements ServerGateway {
  String? _directory;
  String? _workspace;
  bool _closed = false;

  @override
  ServerCapabilities get capabilities =>
      const ServerCapabilities(projectManagement: false);

  @override
  Future<Health> health() async => Health(healthy: true, version: '1.0.0');

  @override
  LiveEventChannel openEventChannel({
    required void Function(EventEnvelope event) onEvent,
    required void Function(StreamStatus status) onStatus,
    void Function(Object error)? onError,
  }) => _FakeChannel(onStatus);

  @override
  LiveEventChannel openGlobalEventChannel({
    required void Function(EventEnvelope event) onEvent,
    required void Function(StreamStatus status) onStatus,
    void Function(Object error)? onError,
  }) => _FakeChannel(onStatus);

  @override
  Future<ServerPage<Session>> sessionPage({String? cursor, int limit = 100}) =>
      Future.value(const ServerPage(items: []));

  @override
  Future<List<Session>> sessions() async => const [];

  @override
  Future<Map<String, String>> sessionStatuses() async => const {};

  @override
  String? get directory => _directory;

  @override
  String? get workspace => _workspace;

  @override
  bool get isClosed => _closed;

  @override
  void setLocation({String? directory, String? workspace}) {
    _directory = directory;
    _workspace = workspace;
  }

  @override
  void close() => _closed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _Operations implements ServerOperationsGateway {
  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Profiles in memory: no secure-storage channel.
class PhoneMemoryStore extends ProfileStore {
  PhoneMemoryStore({
    required super.prefs,
    List<ServerProfile> seeded = const [],
  }) : saved = List.of(seeded);

  final List<ServerProfile> saved;
  String? _activeId;

  @override
  List<ServerProfile> get profiles => List.unmodifiable(saved);

  @override
  String? get activeId => _activeId;

  @override
  Future<void> setActiveId(String? id) async => _activeId = id;

  @override
  Future<void> upsert(ServerProfile profile) async {
    final i = saved.indexWhere((p) => p.id == profile.id);
    if (i < 0) {
      saved.add(profile);
    } else {
      saved[i] = profile;
    }
  }
}

ServerProfile phoneProfile({OrchestrationConfig? config}) => ServerProfile(
  id: phoneProfileId,
  name: 'This phone',
  baseUrl: TermuxBridge.managedServerUrl,
  password: 'phone-demo-password',
  flavor: ServerFlavor.v2,
  orchestration: config,
);

OrchestrationConfig phoneConfig() => OrchestrationConfig(
  provider: OrchestrationProvider.gascity,
  url: TermuxBridge.aiteamSupervisorUrl,
  city: 'phone',
  hostMode: OrchestrationHostMode.phone,
  enabledAt: DateTime.utc(2026, 9, 11),
);

/// A connection to this phone's server, connected to [profile].
Future<(ConnectionController, PhoneMemoryStore)> phoneConnection(
  SharedPreferences prefs,
  ServerProfile profile,
) async {
  final store = PhoneMemoryStore(prefs: prefs, seeded: [profile]);
  final controller = ConnectionController(
    store,
    v2GatewayFactory: (_) => (gateway: _Gateway(), operations: _Operations()),
  );
  await controller.connect(profile);
  return (controller, store);
}

/// The Termux bridge as the setup screen sees a phone whose managed
/// OpenCode 2 server is ready: every command answers at once.
Future<Object?> readyTermux(MethodCall call) async {
  switch (call.method) {
    case 'getCapabilities':
      return <String, Object>{
        'installed': true,
        'version': '0.118',
        'serviceAvailable': true,
        'protocolSupported': true,
        'permissionGranted': true,
      };
    case 'runInTermux':
      final script = (call.arguments as Map)['script'] as String;
      var stdout = '';
      if (script.contains("printf 'opencode-bridge-ok'")) {
        stdout = 'opencode-bridge-ok';
      } else if (script.contains('ubuntu=absent')) {
        stdout = 'ubuntu=installed\nversion=1.0.0\nruntime=opencode2\n';
      } else if (script.contains('__OC_SETUP_OUTPUT__')) {
        stdout =
            'phase=ready\nmessage=OpenCode is ready\nport=4096\nrunner=proot\n'
            'version=1.0.0\nruntime=opencode2\npid=123\n'
            '__OC_SETUP_OUTPUT__\n[oc] authenticated server ready\n';
      }
      return <String, Object>{
        'stdout': stdout,
        'stderr': '',
        'exitCode': 0,
        'err': -1,
        'errorMessage': '',
      };
    default:
      return true;
  }
}
