import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/server_probe.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/termux_running_server.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:opencode_mobile/ui/screens/servers_screen.dart';
import 'package:opencode_mobile/ui/widgets/termux_running_server_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Connection extends ConnectionController {
  _Connection(super.store);
  final attempted = <ServerProfile>[];
  @override
  Future<void> connect(ServerProfile profile, {bool redetectOnFailure = true}) async {
    attempted.add(profile);
    api = OpenCodeApi(baseUrl: profile.baseUrl);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('oc/termux');
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  final probes = <String>[];
  final secrets = <String, String>{};
  final oldProbe = termuxRunningServerProbe;
  late Map<String, Object> capabilities;
  late String status;
  late ServerProbeResult health;
  final local = ServerProfile(id: 'local', name: 'Phone',
    baseUrl: TermuxBridge.managedServerUrl, password: 'synthetic-local');
  final remote = ServerProfile(id: 'remote', name: 'Work server',
    baseUrl: 'https://work.example.test', password: 'synthetic-remote');

  setUp(() {
    calls.clear(); probes.clear(); secrets.clear();
    debugPlatformCapabilities = const PlatformCapabilities.android();
    capabilities = {'installed': true, 'serviceAvailable': true,
      'protocolSupported': true, 'permissionGranted': true};
    status = 'phase=ready\nport=4096\nruntime=opencode1\nversion=1.18.29\npid=12\n';
    health = const ServerProbeResult.success('1.18.29');
    termuxRunningServerProbe = ({required baseUrl, username, password}) async {
      probes.add(baseUrl);
      expect(baseUrl, TermuxBridge.managedServerUrl);
      expect(password, isNot('synthetic-remote'));
      return health;
    };
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getCapabilities') return capabilities;
      expect(call.method, 'runInTermux');
      expect((call.arguments as Map)['script'], TermuxBridge.statusScript());
      return {'exitCode': 0, 'stdout': status, 'stderr': ''};
    });
    messenger.setMockMethodCallHandler(secure, (call) async {
      final args = call.arguments as Map;
      final key = args['key'] as String?;
      switch (call.method) {
        case 'write': secrets[key!] = args['value'] as String; return null;
        case 'read': return secrets[key];
        case 'delete': secrets.remove(key); return null;
        case 'readAll': return secrets;
        case 'containsKey': return secrets.containsKey(key);
        case 'deleteAll': secrets.clear(); return null;
      }
      return null;
    });
  });
  tearDown(() {
    debugPlatformCapabilities = null;
    termuxRunningServerProbe = oldProbe;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(secure, null);
  });

  test('ready status requires live loopback response, not just saved manager state', () async {
    final observed = await detectTermuxRunningServer(profiles: [remote, local]);
    expect(observed.isRunning, isTrue);
    expect(savedProfileForTermuxServer([remote, local], observed), same(local));
    expect(probes, [TermuxBridge.managedServerUrl]);
    health = const ServerProbeResult.failure('unreachable');
    expect((await detectTermuxRunningServer()).state, TermuxRunningServerState.unavailable);
  });

  test('permission denied never sends a command or health request', () async {
    capabilities['permissionGranted'] = false;
    expect((await detectTermuxRunningServer()).state, TermuxRunningServerState.denied);
    expect(calls.map((call) => call.method), ['getCapabilities']);
    expect(probes, isEmpty);
  });

  test('missing Termux and a stopped or switching runtime are not running', () async {
    capabilities['installed'] = false;
    expect((await detectTermuxRunningServer()).isRunning, isFalse);
    capabilities['installed'] = true;
    for (final phase in ['idle', 'stopped', 'failed', 'installing_opencode']) {
      status = 'phase=$phase\n';
      expect((await detectTermuxRunningServer()).isRunning, isFalse);
    }
    status = 'phase=ready\nswitch_previous=opencode1\nswitch_target=opencode2\n';
    expect((await detectTermuxRunningServer()).isRunning, isFalse);
    expect(probes, isEmpty);
  });

  test('unknown port is never scanned', () async {
    status = 'phase=ready\nport=9876\n';
    expect((await detectTermuxRunningServer()).isRunning, isFalse);
    expect(probes, isEmpty);
  });

  test('authentication challenge is observed without claiming authenticated health', () async {
    health = const ServerProbeResult.failure('password required', needsPassword: true);
    final observed = await detectTermuxRunningServer(profiles: [remote]);
    expect(observed.isRunning, isTrue);
    expect(observed.needsCredentials, isTrue);
    expect(savedProfileForTermuxServer([remote], observed), isNull);
  });

  test('web, iOS and desktop never touch the native bridge', () async {
    for (final platform in [
      const PlatformCapabilities(platform: TargetPlatform.android, isWeb: true),
      const PlatformCapabilities(platform: TargetPlatform.iOS),
      const PlatformCapabilities.linuxDesktop(),
    ]) {
      debugPlatformCapabilities = platform;
      expect((await detectTermuxRunningServer()).state, TermuxRunningServerState.unsupported);
    }
    expect(calls, isEmpty); expect(probes, isEmpty);
  });

  Future<void> entry(WidgetTester tester, {
    List<ServerProfile>? profiles,
    ValueChanged<ServerProfile>? onConnect,
    void Function(TermuxRunningServer, ServerProfile?)? onCredentials,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: RepaintBoundary(
        key: const ValueKey('capture'),
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: SingleChildScrollView(child: TermuxRunningServerEntry(
            profiles: profiles ?? [remote, local], busy: false, revision: 0,
            onConnect: onConnect ?? (_) {},
            onEnterCredentials: onCredentials ?? (_, _) {},
          )),
        ),
      )),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('visible connect is explicit, rechecks, and never starts or switches runtime', (tester) async {
    final connected = <ServerProfile>[];
    await entry(tester, onConnect: connected.add);
    expect(find.text('Connect to running server'), findsOneWidget);
    expect(connected, isEmpty);
    expect(find.textContaining('1.18.29'), findsNothing);
    await tester.tap(find.text('Connect to running server'));
    await tester.pumpAndSettle();
    expect(connected, [local]);
    expect(probes, hasLength(2));
  });

  testWidgets('missing or rejected credentials go straight to credential flow', (tester) async {
    health = const ServerProbeResult.failure('password required', needsPassword: true);
    ServerProfile? requested;
    var opened = 0;
    await entry(tester, onCredentials: (_, profile) { opened++; requested = profile; });
    await tester.tap(find.text('Connect to running server'));
    await tester.pumpAndSettle();
    expect(opened, 1); expect(requested, same(local));
    await tester.pumpWidget(const SizedBox());
    await entry(tester, profiles: [remote], onCredentials: (_, profile) { opened++; requested = profile; });
    await tester.tap(find.text('Connect to running server'));
    await tester.pumpAndSettle();
    expect(opened, 2); expect(requested, isNull);
  });

  testWidgets('stale observation cannot connect a server that stopped before tap', (tester) async {
    var connected = 0;
    await entry(tester, onConnect: (_) => connected++);
    status = 'phase=stopped\n';
    await tester.tap(find.text('Connect to running server'));
    await tester.pumpAndSettle();
    expect(connected, 0);
    expect(find.text('Connect to running server'), findsNothing);
  });

  testWidgets('resume removes stale running entry', (tester) async {
    await entry(tester);
    status = 'phase=stopped\n';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Connect to running server'), findsNothing);
  });

  testWidgets('denied and unavailable explain uncertainty without a connect claim', (tester) async {
    capabilities['permissionGranted'] = false;
    await entry(tester);
    expect(find.text('Allow Termux access in phone setup to check for a server.'), findsOneWidget);
    expect(find.text('Connect to running server'), findsNothing);
    capabilities['permissionGranted'] = true;
    health = const ServerProbeResult.failure('unreachable');
    await tester.tap(find.byTooltip('Check status'));
    await tester.pumpAndSettle();
    expect(find.text('Could not check the server on this phone.'), findsOneWidget);
  });

  testWidgets('server list retains remote profiles and connects local only on tap', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = ProfileStore(prefs: await SharedPreferences.getInstance());
    await store.upsert(remote); await store.upsert(local);
    final connection = _Connection(store);
    addTearDown(connection.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [bootstrapProvider.overrideWithValue(AppBootstrap(store)),
        connProvider.overrideWithValue(connection)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routes: {'/home': (_) => const Scaffold(body: Text('Connected home'))},
        home: const ServersScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Connect to running server'), findsOneWidget);
    expect(connection.attempted, isEmpty);
    final before = jsonEncode(remote.toJson());
    await tester.tap(find.text('Connect to running server'));
    await tester.pumpAndSettle();
    expect(connection.attempted, [local]);
    expect(store.profiles, hasLength(2));
    expect(jsonEncode(remote.toJson()), before);
    expect(find.text('Connected home'), findsOneWidget);
  });

  testWidgets('welcome running entry opens password editor with authored local URL', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = ProfileStore(prefs: await SharedPreferences.getInstance());
    final connection = _Connection(store);
    addTearDown(connection.dispose);
    health = const ServerProbeResult.failure('password required', needsPassword: true);
    await tester.pumpWidget(ProviderScope(
      overrides: [bootstrapProvider.overrideWithValue(AppBootstrap(store)),
        connProvider.overrideWithValue(connection)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ServersScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    final connect = find.text('Connect to running server');
    await tester.ensureVisible(connect);
    await tester.tap(connect);
    await tester.pumpAndSettle();
    final url = tester.widget<TextField>(find.byKey(const ValueKey('server-url-field')));
    expect(url.controller!.text, TermuxBridge.managedServerUrl);
    expect(find.byKey(const ValueKey('server-password-field')), findsOneWidget);
    expect(store.profiles, isEmpty);
    expect(connection.attempted, isEmpty);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('running entry fits a narrow phone at text scale $scale', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await entry(tester, textScale: scale);
      expect(tester.takeException(), isNull);
      final connect = find.text('Connect to running server');
      await tester.ensureVisible(connect);
      expect(tester.getSize(find.ancestor(of: connect, matching: find.byType(FilledButton))).height, greaterThanOrEqualTo(48));
      const captureDirectory = String.fromEnvironment('TERMUX_ENTRY_CAPTURE_DIR');
      if (captureDirectory.isNotEmpty) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('capture')));
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await tester.runAsync(() async {
          await Directory(captureDirectory).create(recursive: true);
          await File('$captureDirectory/running-${scale}x.png').writeAsBytes(data!.buffer.asUint8List());
        });
        image.dispose();
      }
    });
  }
}
