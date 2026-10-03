// The last step of a Termux setup job (P1.2): start OpenCode through the
// Termux manager and connect, returning null only once connected. Termux is
// stood in for by a fake server control; the profiles live in memory.
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/setup/setup_engine.dart';
import 'package:opencode_mobile/builtin/setup/termux_setup_finish.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/termux_channel_fixture.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

TermuxSetupStatus _status(
  String phase, {
  TermuxRuntime runtime = TermuxRuntime.openCode1,
  String version = '',
  String message = 'OpenCode is ready',
}) => TermuxSetupStatus(
  phase: phase,
  message: message,
  port: 4096,
  runner: 'proot',
  version: version,
  pid: 1,
  runtime: runtime,
  runtimeSelected: true,
);

class _FakeServer implements TermuxServerControl {
  TermuxSetupStatus now = _status('idle', message: 'No setup has been started');
  TermuxSetupStatus restarted = _status('ready', version: '1.18.32');
  TermuxBridgeException? stageFailure;
  final staged = <({TermuxRuntime runtime, String password})>[];
  var restarts = 0;

  @override
  Future<TermuxSetupStatus> status() async => now;

  @override
  Future<void> stage({
    required TermuxRuntime runtime,
    required String password,
  }) async {
    final failure = stageFailure;
    if (failure != null) throw failure;
    staged.add((runtime: runtime, password: password));
  }

  @override
  Future<TermuxSetupStatus> restart() async {
    restarts++;
    return now = restarted;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryProfileStore store;
  late _FakeServer server;
  late List<ServerProfile> connects;
  String? connectFailure;
  ServerProfile? connected;

  TermuxSetupFinisher finisher() => TermuxSetupFinisher(
    store: store,
    server: server,
    strings: () => _l10n,
    isConnectedTo: (profile) => connected?.id == profile.id,
    connect: (profile) async {
      connects.add(profile);
      if (connectFailure != null) return connectFailure;
      connected = profile;
      return null;
    },
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = MemoryProfileStore(prefs: await SharedPreferences.getInstance());
    server = _FakeServer();
    connects = [];
    connectFailure = null;
    connected = null;
    // No password in Termux unless a test puts one there.
    TermuxBridge.managedServerPasswordOverride = () async => null;
    addTearDown(() => TermuxBridge.managedServerPasswordOverride = null);
  });

  const fresh = SetupFinishRequest(
    host: SetupHostKind.termux,
    runtime: TermuxRuntime.openCode1,
    openCodeChanged: true,
    version: '1.18.32',
  );

  test(
    'a fresh install gets a profile with a new password, which the '
    'manager is given before the restart; done only once connected',
    () async {
      expect(await finisher().call(fresh), isNull);

      final profile = store.saved.single;
      expect(profile.baseUrl, TermuxBridge.managedServerUrl);
      expect(profile.password, isNotEmpty);
      expect(profile.serverVersion, '1.18.32');
      expect(server.staged.single.password, profile.password);
      expect(server.staged.single.runtime, TermuxRuntime.openCode1);
      expect(server.restarts, 1);
      expect(connects.single.id, profile.id);
    },
  );

  test('an existing install keeps the password Termux already holds', () async {
    TermuxBridge.managedServerPasswordOverride = () async =>
        'synthetic-termux-secret';
    expect(
      await finisher().call(
        const SetupFinishRequest(
          host: SetupHostKind.termux,
          runtime: TermuxRuntime.openCode2,
          openCodeChanged: false,
        ),
      ),
      isNull,
    );
    final profile = store.saved.single;
    expect(profile.password, 'synthetic-termux-secret');
    expect(profile.flavor, ServerFlavor.v2);
    expect(server.staged.single.password, 'synthetic-termux-secret');
    expect(server.staged.single.runtime, TermuxRuntime.openCode2);
  });

  test('a server already running the right OpenCode, with the app connected '
      'to it, is left alone (Add tools must not cut a session)', () async {
    final profile = ServerProfile(
      id: 'phone',
      name: 'This phone',
      baseUrl: TermuxBridge.managedServerUrl,
      password: 'synthetic-test-secret',
    );
    store.saved.add(profile);
    connected = profile;
    server.now = _status('ready', version: '1.18.32');

    expect(
      await finisher().call(
        const SetupFinishRequest(
          host: SetupHostKind.termux,
          runtime: TermuxRuntime.openCode1,
          openCodeChanged: false,
        ),
      ),
      isNull,
    );
    expect(server.staged, isEmpty);
    expect(server.restarts, 0);
    expect(connects, isEmpty);
  });

  test('a new OpenCode restarts even a connected server', () async {
    final profile = ServerProfile(
      id: 'phone',
      name: 'This phone',
      baseUrl: TermuxBridge.managedServerUrl,
      password: 'synthetic-test-secret',
    );
    store.saved.add(profile);
    connected = profile;
    server.now = _status('ready', version: '1.18.29');

    expect(await finisher().call(fresh), isNull);
    expect(server.restarts, 1);
    expect(store.saved.single.serverVersion, '1.18.32');
  });

  test(
    'Termux serving the other OpenCode is a switch, not a setup step',
    () async {
      server.stageFailure = const TermuxBridgeException(
        'other',
        code: 'runtime_mismatch',
      );
      expect(await finisher().call(fresh), _l10n.phoneSetupTermuxOtherRuntime);
      expect(server.restarts, 0);
      expect(connects, isEmpty);
    },
  );

  test('a restart that fails, or a connection that fails, is the reason on '
      'the start row', () async {
    server.restarted = _status('failed', message: 'Port 4096 is in use');
    expect(
      await finisher().call(fresh),
      _l10n.e7SetupRestartFailed('Port 4096 is in use'),
    );
    expect(connects, isEmpty);

    server.restarted = _status('ready', version: '1.18.32');
    connectFailure = 'Wrong password';
    expect(await finisher().call(fresh), 'Wrong password');
  });

  test('an in-app job never touches Termux', () async {
    expect(
      await finisher().call(
        const SetupFinishRequest(
          runtime: TermuxRuntime.openCode1,
          openCodeChanged: true,
        ),
      ),
      _l10n.phoneSetupErrorCannotStart,
    );
    expect(store.saved, isEmpty);
    expect(server.staged, isEmpty);
  });

  test('the staging script refuses the other runtime and a pending switch, '
      'and writes the password only to a private file', () {
    final script = TermuxBridgeServerControl.stageScript(
      runtime: TermuxRuntime.openCode2,
      password: "it's-synthetic",
    );
    expect(script, contains('managed-runtime-migration-required'));
    expect(script, contains('managed-runtime-switch-pending'));
    expect(script, contains("!= 'opencode2'"));
    expect(script, contains(r"printf '%s' 'it'\''s-synthetic'"));
    expect(script, contains('chmod 600'));
    expect(script, isNot(contains('echo "\$password')));
    expect(
      () => TermuxBridgeServerControl.stageScript(
        runtime: TermuxRuntime.openCode1,
        password: '',
      ),
      throwsArgumentError,
    );
  });
}
