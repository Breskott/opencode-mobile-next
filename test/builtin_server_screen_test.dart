import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/server_probe.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:opencode_mobile/ui/screens/builtin_server_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryProfileStore extends ProfileStore {
  _MemoryProfileStore({required super.prefs});

  final saved = <ServerProfile>[];
  String? selected;

  @override
  List<ServerProfile> get profiles => List.unmodifiable(saved);

  @override
  String? get activeId => selected;

  @override
  Future<void> upsert(ServerProfile profile) async {
    final index = saved.indexWhere((item) => item.id == profile.id);
    if (index == -1) {
      saved.add(profile);
    } else {
      saved[index] = profile;
    }
  }

  @override
  Future<void> setActiveId(String? id) async => selected = id;
}

class _Connection extends ConnectionController {
  _Connection(super.store);

  final connected = <ServerProfile>[];

  @override
  bool get hasConnectedServer =>
      api != null && status == StreamStatus.connected;

  @override
  Future<void> connect(
    ServerProfile profile, {
    bool redetectOnFailure = true,
  }) async {
    connected.add(profile);
    api = OpenCodeApi(baseUrl: profile.baseUrl);
    status = StreamStatus.connected;
    await store.setActiveId(profile.id);
    notifyListeners();
  }
}

/// Plays the Android side: Ubuntu takes one poll to unpack, OpenCode is
/// missing until the install script runs, the server runs once started.
class _FakeLinux extends BuiltinLinux {
  _FakeLinux() : super();

  bool installed = false;
  BuiltinLinuxPhase phase = BuiltinLinuxPhase.idle;
  bool serverRunning = false;
  bool openCodeInstalled = false;
  int statusReadsWhileInstalling = 0;
  final scripts = <String>[];
  String? serverScript;
  int? serverPortArg;
  String? writtenPassword;
  int uninstallCalls = 0;

  @override
  Future<BuiltinLinuxStatus> status() async {
    if (phase == BuiltinLinuxPhase.installing &&
        ++statusReadsWhileInstalling >= 2) {
      installed = true;
      phase = BuiltinLinuxPhase.ready;
    }
    return BuiltinLinuxStatus(
      installed: installed,
      phase: phase,
      serverRunning: serverRunning,
      serverPort: serverRunning ? BuiltinLinux.serverPort : null,
      abi: 'arm64-v8a',
      bytesUsed: installed ? 734003200 : null,
    );
  }

  @override
  Future<void> installUbuntu() async => phase = BuiltinLinuxPhase.installing;

  @override
  Future<BuiltinLinuxRunResult> run(
    String script, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    scripts.add(script);
    if (script == BuiltinLinux.versionScript(TermuxRuntime.openCode1)) {
      return openCodeInstalled
          ? const BuiltinLinuxRunResult(exitCode: 0, output: '1.18.29\n')
          : const BuiltinLinuxRunResult(exitCode: 1, output: '');
    }
    if (script.contains("<<'OC_PROOT_SETUP'")) {
      openCodeInstalled = true;
      return const BuiltinLinuxRunResult(exitCode: 0, output: '1.18.29\n');
    }
    if (script.contains(BuiltinLinux.passwordFile)) {
      writtenPassword = RegExp(r"printf '%s' '([^']*)'").firstMatch(script)![1];
      return const BuiltinLinuxRunResult(exitCode: 0, output: '');
    }
    return const BuiltinLinuxRunResult(exitCode: 127, output: 'unexpected');
  }

  @override
  Future<void> startServer(String script, {int port = 4097}) async {
    serverScript = script;
    serverPortArg = port;
    serverRunning = true;
  }

  @override
  Future<void> stopServer() async => serverRunning = false;

  @override
  Future<String> serverLog({int tailBytes = 32768}) async => 'listening\n';

  @override
  Future<void> uninstall() async {
    uninstallCalls++;
    serverRunning = false;
    installed = false;
    openCodeInstalled = false;
    phase = BuiltinLinuxPhase.idle;
  }
}

void main() {
  late _MemoryProfileStore store;
  late _Connection connection;
  late _FakeLinux linux;
  final probes = <({String baseUrl, String? username, String? password})>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = _MemoryProfileStore(prefs: await SharedPreferences.getInstance());
    connection = _Connection(store);
    linux = _FakeLinux();
    probes.clear();
    serverProbe = ({required baseUrl, username, password}) async {
      probes.add((baseUrl: baseUrl, username: username, password: password));
      return const ServerProbeResult.success('1.18.29');
    };
  });

  tearDown(() {
    serverProbe = probeServerConnection;
    connection.dispose();
  });

  Future<void> mount(WidgetTester tester) async {
    // Tall enough that all four steps and the footer are built at once.
    tester.view
      ..physicalSize = const Size(900, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapProvider.overrideWithValue(AppBootstrap(store)),
          connProvider.overrideWithValue(connection),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routes: {'/home': (_) => const Scaffold(body: Text('App home'))},
          home: BuiltinServerScreen(
            linux: linux,
            pollInterval: const Duration(milliseconds: 50),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.scrollUntilVisible(finder, 100);
    await tester.tap(finder);
    await tester.pump();
  }

  testWidgets('install Ubuntu, install OpenCode, start, connect', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('Download Ubuntu (about 30 MB)'), findsOneWidget);
    expect(find.text('Experimental'), findsOneWidget);
    expect(find.byKey(const Key('builtin-install-opencode')), findsNothing);

    await tap(tester, 'builtin-install-ubuntu');
    expect(find.text('Downloading and unpacking Ubuntu…'), findsOneWidget);
    // Two polls later Android reports Ubuntu ready.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.text('Ubuntu is ready.'), findsOneWidget);
    expect(find.text('Using 700.0 MB of storage'), findsOneWidget);

    await tap(tester, 'builtin-install-opencode');
    await tester.pumpAndSettle();
    expect(
      linux.scripts.where((s) => s.contains("<<'OC_PROOT_SETUP'")).single,
      BuiltinLinux.installOpenCodeScript(),
    );
    expect(find.text('OpenCode 1.18.29 is installed.'), findsOneWidget);

    await tap(tester, 'builtin-start');
    await tester.pumpAndSettle();

    expect(linux.serverScript, BuiltinLinux.serverScript());
    expect(linux.serverPortArg, 4097);
    final profile = store.saved.single;
    expect(profile.baseUrl, 'http://127.0.0.1:4097');
    expect(profile.username, 'opencode');
    expect(profile.password.length, greaterThanOrEqualTo(40));
    expect(linux.writtenPassword, profile.password);
    expect(probes.last, (
      baseUrl: 'http://127.0.0.1:4097',
      username: 'opencode',
      password: profile.password,
    ));
    expect(connection.connected.single.id, profile.id);
    expect(store.selected, profile.id);
    expect(find.text('App home'), findsOneWidget);
  });

  testWidgets('a second start reuses the saved profile and password', (
    tester,
  ) async {
    linux
      ..installed = true
      ..phase = BuiltinLinuxPhase.ready
      ..openCodeInstalled = true;
    final existing = ServerProfile(
      id: 'builtin',
      name: 'Mine',
      baseUrl: BuiltinLinux.serverUrl,
      username: 'opencode',
      password: 'kept-password',
    );
    await store.upsert(existing);
    await mount(tester);

    await tap(tester, 'builtin-start');
    await tester.pumpAndSettle();
    expect(store.saved, hasLength(1));
    expect(linux.writtenPassword, 'kept-password');
    expect(connection.connected.single.id, 'builtin');
  });

  testWidgets('a server that exits while starting shows the failure', (
    tester,
  ) async {
    linux
      ..installed = true
      ..phase = BuiltinLinuxPhase.ready
      ..openCodeInstalled = true;
    serverProbe = ({required baseUrl, username, password}) async {
      linux.serverRunning = false;
      return const ServerProbeResult.failure('refused');
    };
    await mount(tester);

    await tap(tester, 'builtin-start');
    await tester.pumpAndSettle();
    expect(
      find.text(
        'OpenCode did not answer: the server stopped. Open the log to see why.',
      ),
      findsOneWidget,
    );
    expect(connection.connected, isEmpty);

    await tap(tester, 'builtin-show-log');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('builtin-server-log')), findsOneWidget);
  });

  testWidgets('Stop stops a running server', (tester) async {
    linux
      ..installed = true
      ..phase = BuiltinLinuxPhase.ready
      ..openCodeInstalled = true
      ..serverRunning = true;
    await mount(tester);
    expect(
      find.text('Running on this phone at 127.0.0.1:4097.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('builtin-connect')), findsOneWidget);

    await tap(tester, 'builtin-stop');
    await tester.pumpAndSettle();
    expect(linux.serverRunning, isFalse);
    expect(find.text('Not running.'), findsOneWidget);
  });

  testWidgets('Remove asks first, then deletes Ubuntu', (tester) async {
    linux
      ..installed = true
      ..phase = BuiltinLinuxPhase.ready
      ..openCodeInstalled = true;
    await mount(tester);

    await tap(tester, 'builtin-remove');
    await tester.pumpAndSettle();
    expect(find.text('Remove the built-in Ubuntu?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('builtin-server-remove-confirm')));
    await tester.pumpAndSettle();
    expect(linux.uninstallCalls, 1);
    expect(find.byKey(const Key('builtin-install-ubuntu')), findsOneWidget);
  });
}
