import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/server_probe.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/builtin/builtin_server.dart';
import 'package:opencode_mobile/builtin/setup/phone_setup.dart';
import 'package:opencode_mobile/main.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_start_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_setup_engine.dart';

class _OneProfileStore extends ProfileStore {
  _OneProfileStore({required super.prefs, required this.profile});

  final ServerProfile profile;

  @override
  List<ServerProfile> get profiles => [profile];

  @override
  String? get activeId => profile.id;

  @override
  Future<void> upsert(ServerProfile value) async {}
}

/// Every connect fails as a stopped server would, so the app stays on its
/// opening card and each connect attempt can be counted.
class _RefusedConnection extends ConnectionController {
  _RefusedConnection(super.store);

  int connectCalls = 0;
  final log = <String>[];

  @override
  Future<void> connect(
    ServerProfile profile, {
    bool redetectOnFailure = true,
  }) async {
    connectCalls++;
    log.add('connect');
    lastError = 'Health check failed: connection refused';
    notifyListeners();
  }
}

class _FakeLinux extends BuiltinLinux {
  _FakeLinux(this.events);

  final List<String> events;
  bool serverRunning = false;
  bool serverDies = false;
  int starts = 0;
  int generation = 0;
  bool wanted = true;

  @override
  Future<BuiltinLinuxStatus> status() async => BuiltinLinuxStatus(
    installed: true,
    phase: BuiltinLinuxPhase.ready,
    serverRunning: serverRunning,
    serverRestartWanted: wanted,
    serverRecoveryGeneration: generation,
  );

  @override
  Future<void> cancelServerRecovery() async {
    generation++;
  }

  @override
  Future<void> confirmServerRecovery({required int expectedGeneration}) async {}

  @override
  Future<void> restartServer(
    String script, {
    int port = 4097,
    required int expectedGeneration,
  }) async {
    if (!wanted || expectedGeneration != generation) {
      throw const BuiltinLinuxException('The phone server could not restart.');
    }
    await startServer(script, port: port);
  }

  @override
  Future<BuiltinLinuxRunResult> run(
    String script, {
    Duration timeout = const Duration(minutes: 2),
  }) async => const BuiltinLinuxRunResult(exitCode: 0, output: '');

  @override
  Future<void> startServer(String script, {int port = 4097}) async {
    starts++;
    events.add('start');
    serverRunning = !serverDies;
  }
}

void main() {
  late _RefusedConnection connection;
  late _FakeLinux linux;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final profile = ServerProfile(
      id: 'builtin',
      name: 'This phone, built-in (OpenCode)',
      baseUrl: BuiltinLinux.serverUrl,
      username: BuiltinLinux.serverUsername,
    )..password = 'secret';
    final store = _OneProfileStore(
      prefs: await SharedPreferences.getInstance(),
      profile: profile,
    );
    connection = _RefusedConnection(store);
    linux = _FakeLinux(connection.log);
    serverProbe = ({required baseUrl, username, password}) async =>
        linux.serverRunning
        ? const ServerProbeResult.success('1.18.29')
        : const ServerProbeResult.failure('refused');
  });

  tearDown(() => serverProbe = probeServerConnection);

  Future<void> mount(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.view
      ..physicalSize = const Size(900, 1800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapProvider.overrideWithValue(AppBootstrap(connection.store)),
          connProvider.overrideWithValue(connection),
          builtinLinuxProvider.overrideWithValue(linux),
          builtinServerStarterProvider.overrideWith(
            (ref) => BuiltinServerStarter(
              linux: linux,
              pollInterval: const Duration(milliseconds: 10),
            ),
          ),
        ],
        child: const OcApp(),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    connection.dispose();
    await tester.pump();
  }

  testWidgets('opening after a confirmed in-app crash starts it once, then '
      'connects; Start and connect on the card starts it again', (
    tester,
  ) async {
    await mount(tester);
    await settle(tester);

    expect(connection.log, ['start', 'connect']);
    expect(find.text('OpenCode inside the app is stopped'), findsOneWidget);
    expect(find.textContaining('Termux'), findsNothing);

    // The failed connect does not start the server again on its own.
    await settle(tester);
    expect(linux.starts, 1);
    expect(connection.connectCalls, 1);

    await tester.tap(find.byKey(const ValueKey('saved-server-start-phone')));
    await settle(tester);
    expect(connection.log, ['start', 'connect', 'start', 'connect']);

    await unmount(tester);
  });

  testWidgets('explicit Stop intent stays stopped on launch and resume', (
    tester,
  ) async {
    linux.wanted = false;
    await mount(tester);
    await settle(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 20));
    await settle(tester);
    expect(linux.starts, 0);
    await unmount(tester);
  });

  testWidgets('a server that is already running is only connected to', (
    tester,
  ) async {
    linux.serverRunning = true;
    await mount(tester);
    await settle(tester);
    expect(connection.log, ['connect']);
    await unmount(tester);
  });

  testWidgets('a failed automatic start falls back to the card, once', (
    tester,
  ) async {
    linux.serverDies = true;
    await mount(tester);
    await settle(tester);

    expect(linux.starts, 1);
    expect(connection.connectCalls, 0);
    expect(find.text('OpenCode inside the app did not start'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('saved-server-open-in-app-setup')),
      findsOneWidget,
    );
    await settle(tester);
    expect(linux.starts, 1);

    await unmount(tester);
  });

  testWidgets('its Open setup lands on phone setup, not the old in-app page '
      '(builtin-server-setup merged into phone-setup-start, P1.3)', (
    tester,
  ) async {
    final previous = PhoneSetup.engine;
    final previousTermux = PhoneSetup.termux;
    PhoneSetup.engine = FakeSetupEngine();
    PhoneSetup.termux = FakeSetupEngine();
    addTearDown(() {
      PhoneSetup.engine = previous;
      PhoneSetup.termux = previousTermux;
    });
    linux.serverDies = true;
    await mount(tester);
    await settle(tester);
    await tester.tap(
      find.byKey(const ValueKey('saved-server-open-in-app-setup')),
    );
    await settle(tester);
    expect(find.byType(PhoneSetupStartScreen), findsOneWidget);
    expect(
      ModalRoute.of(
        tester.element(find.byType(PhoneSetupStartScreen)),
      )?.settings.name,
      'phone-setup-start',
    );
    // The native device-info probe has a bounded five-second timeout.
    await tester.pump(const Duration(seconds: 6));
    await unmount(tester);
  });

  testWidgets('resume preserves backoff before healing a later crash', (
    tester,
  ) async {
    await mount(tester);
    await settle(tester);
    expect(connection.log, ['start', 'connect']);

    // Android stopped the server while the app was away.
    linux.serverRunning = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(connection.log, ['start', 'connect']);

    await unmount(tester);
  });
}
