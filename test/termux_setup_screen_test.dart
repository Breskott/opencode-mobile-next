import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:opencode_mobile/ui/screens/termux_setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:opencode_mobile/ui/app_iconography.dart';

class _MemoryProfileStore extends ProfileStore {
  _MemoryProfileStore({required super.prefs});

  final savedProfiles = <ServerProfile>[];
  String? selectedID;
  Completer<void>? pendingSave;
  Completer<void>? pendingSelection;

  @override
  List<ServerProfile> get profiles => List.unmodifiable(savedProfiles);

  @override
  String? get activeId => selectedID;

  @override
  Future<void> upsert(ServerProfile profile) async {
    await pendingSave?.future;
    final index = savedProfiles.indexWhere((item) => item.id == profile.id);
    if (index == -1) {
      savedProfiles.add(profile);
    } else {
      savedProfiles[index] = profile;
    }
  }

  @override
  Future<void> setActiveId(String? id) async {
    await pendingSelection?.future;
    selectedID = id;
  }
}

class _LocalConnectionController extends ConnectionController {
  _LocalConnectionController(super.store);

  int retryCalls = 0;
  int retriesToFail = 0;
  int connectCalls = 0;
  int attempt = 0;
  Completer<void>? pendingConnect;
  bool failConnect = false;
  bool restoreLocation = false;

  @override
  bool get hasConnectedServer =>
      api != null && status == StreamStatus.connected;

  @override
  Future<void> connect(
    ServerProfile profile, {
    bool redetectOnFailure = true,
  }) async {
    final currentAttempt = ++attempt;
    connectionRevision++;
    connectionAttemptRevision++;
    connectCalls++;
    api = OpenCodeApi(baseUrl: profile.baseUrl);
    status = StreamStatus.connecting;
    notifyListeners();
    await store.setActiveId(profile.id);
    if (restoreLocation) {
      // Restoring a saved folder replaces the gateway within this attempt.
      connectionRevision++;
      api = OpenCodeApi(baseUrl: profile.baseUrl);
    }
    await pendingConnect?.future;
    if (currentAttempt != attempt) return;
    if (failConnect) {
      api = null;
      status = StreamStatus.disconnected;
      lastError = 'Could not connect to the phone server.';
      notifyListeners();
      return;
    }
    version = '1.18.21';
    status = StreamStatus.connected;
    notifyListeners();
  }

  @override
  Future<void> disconnect({
    bool keepActive = false,
    bool silent = false,
  }) async {
    attempt++;
    connectionRevision++;
    connectionAttemptRevision++;
    api = null;
    version = null;
    status = StreamStatus.disconnected;
    if (!keepActive) await store.setActiveId(null);
    if (!silent) notifyListeners();
  }

  @override
  Future<void> retryConnection() async {
    connectionRevision++;
    connectionAttemptRevision++;
    retryCalls++;
    if (retryCalls <= retriesToFail) {
      api = null;
      status = StreamStatus.disconnected;
      lastError = 'Server unavailable during lifecycle resume.';
      notifyListeners();
      return;
    }
    api = OpenCodeApi(baseUrl: TermuxBridge.managedServerUrl);
    version = '1.18.21';
    status = StreamStatus.connected;
    notifyListeners();
  }
}

Map<String, Object> _commandResult({String stdout = ''}) => {
  'stdout': stdout,
  'stderr': '',
  'exitCode': 0,
  'err': -1,
  'errorMessage': '',
};

// Gates represent native command acknowledgements, independent of widget time.
class _SetupProgressFixture {
  _SetupProgressFixture(this.store)
    : connection = _LocalConnectionController(store);

  final _MemoryProfileStore store;
  final _LocalConnectionController connection;
  Completer<Map<String, Object>>? pendingBridge;
  Completer<Map<String, Object>>? pendingLaunch;
  Completer<Map<String, Object>>? pendingStatus;
  int launchCalls = 0;
  String? launchedScript;
  TermuxRuntime runtime = TermuxRuntime.openCode1;
  int restartCalls = 0;
  int switchCalls = 0;
  bool switchFails = false;
  String switchPhase = 'ready';
  String? restartOperation;
  String inventoryOutput = 'ubuntu=absent\nversion=\n';
  Completer<Map<String, Object>>? pendingInventory;
  int statusReads = 0;
  String? statusOutput;
  bool launched = false;
  bool termuxInstalled = true;
  bool permissionGranted = true;
  bool inventoryFails = false;
  int commandCalls = 0;
  final handoffCalls = <String>[];
  bool permissionResult = true;
  bool openResult = true;
  bool bridgeUnlocked = true;
  int bridgeChecks = 0;
  Completer<bool>? pendingPermission;
  Completer<bool>? pendingOpen;
  PlatformException? openFailure;
  PlatformException? clipboardFailure;
  String? copiedCommand;
  int? startedAtEpochSeconds;

  void watchClipboard() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            handoffCalls.add('copy');
            if (clipboardFailure != null) throw clipboardFailure!;
            copiedCommand = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
  }

  Future<Object?> handle(MethodCall call) async {
    if (call.method == 'requestRunCommandPermission') {
      handoffCalls.add('permission');
      permissionGranted =
          await (pendingPermission?.future ?? Future.value(permissionResult));
      return permissionGranted;
    }
    if (call.method == 'openTermux') {
      handoffCalls.add('open');
      if (openFailure != null) throw openFailure!;
      return pendingOpen?.future ?? Future.value(openResult);
    }
    if (call.method == 'openAppSettings') {
      handoffCalls.add('settings');
      return true;
    }
    if (call.method == 'getCapabilities') {
      return <String, Object>{
        'installed': termuxInstalled,
        'version': '0.118',
        'serviceAvailable': true,
        'protocolSupported': true,
        'permissionGranted': permissionGranted,
      };
    }
    if (call.method != 'runInTermux') return true;
    commandCalls++;
    final script = (call.arguments as Map)['script'] as String;
    if (script.contains('ubuntu=absent')) {
      if (inventoryFails) throw PlatformException(code: 'command_timeout');
      return pendingInventory?.future ??
          _commandResult(stdout: inventoryOutput);
    }
    if (script.contains("printf 'opencode-bridge-ok'")) {
      bridgeChecks++;
      if (!bridgeUnlocked) {
        throw PlatformException(
          code: 'command_timeout',
          message: 'Termux did not answer. Paste the command and try again.',
        );
      }
      return pendingBridge?.future ??
          Future.value(_commandResult(stdout: 'opencode-bridge-ok'));
    }
    final switchMatch = RegExp(
      r"restart '4096' '([^']+)' '' '' '(opencode[12])'",
    ).firstMatch(script);
    if (switchMatch != null) {
      switchCalls++;
      final result =
          await (pendingLaunch?.future ??
              Future.value(_commandResult(stdout: 'manager-started:123')));
      final previous = runtime;
      runtime = TermuxRuntime.parse(switchMatch.group(2));
      final operation = switchMatch.group(1);
      statusOutput =
          'phase=${switchFails ? 'failed' : switchPhase}\n'
          'message=${switchFails ? 'Authentication failed' : 'OpenCode is ready'}\n'
          'port=4096\nrunner=proot\nversion=${runtime.pinnedVersion}\n'
          'runtime=${runtime.wireName}\noperation=$operation\npid=123\n'
          'switch_return=opencode1\n'
          '${startedAtEpochSeconds == null ? '' : 'started_at=$startedAtEpochSeconds\n'}'
          '${switchFails || switchPhase != 'ready' ? 'switch_previous=${previous.wireName}\nswitch_target=${runtime.wireName}\nswitch_phase=starting\n' : ''}'
          '__OC_SETUP_OUTPUT__\n';
      inventoryOutput =
          'ubuntu=installed\nversion=${runtime.pinnedVersion}\nruntime=${runtime.wireName}\n';
      return result;
    }
    if (script.contains('"\$MANAGER" restart')) {
      restartCalls++;
      restartOperation = RegExp(
        r"restart '4096' '([^']+)'",
      ).firstMatch(script)!.group(1);
      return _commandResult();
    }
    if (script.contains('manager_tmp=')) {
      launchCalls++;
      launchedScript = script;
      final result =
          await (pendingLaunch?.future ??
              Future.value(_commandResult(stdout: 'manager-started:123')));
      launched = true;
      return result;
    }
    if (script.contains('__OC_SETUP_OUTPUT__') ||
        (script.contains('exec "') && script.contains(' status'))) {
      statusReads++;
      if (launched && pendingStatus != null) return pendingStatus!.future;
      return statusResult();
    }
    return _commandResult();
  }

  Map<String, Object> statusResult() => _commandResult(
    stdout:
        statusOutput ??
        (restartOperation != null
            ? '''phase=ready
message=OpenCode is ready
port=4096
runner=proot
version=${runtime.pinnedVersion}
runtime=${runtime.wireName}
pid=123
operation=$restartOperation
operation_result=completed
__OC_SETUP_OUTPUT__
[oc] authenticated server ready
'''
            : launched
            ? '''phase=installing_dependencies
message=Installing Termux dependencies
port=4096
runner=proot
version=
pid=123
runtime=${runtime.wireName}
${startedAtEpochSeconds == null ? '' : 'started_at=$startedAtEpochSeconds'}
__OC_SETUP_OUTPUT__
[oc] Installing packages
'''
            : '''phase=idle
message=No setup has been started
port=4096
runner=
version=
pid=
__OC_SETUP_OUTPUT__
'''),
  );

  Future<void> mount(
    WidgetTester tester, {
    double textScale = 1,
    bool rtl = false,
    DateTime Function()? now,
    GlobalKey? captureKey,
    ThemeData? theme,
  }) async {
    const channel = MethodChannel('oc/termux');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handle);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      connection.dispose();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapProvider.overrideWithValue(AppBootstrap(store)),
          connProvider.overrideWithValue(connection),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          // RTL cases flip direction only and keep the English catalog, so
          // the literal expectations below stay readable; the Arabic copy
          // itself is exercised by the e7 layout suites.
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => RepaintBoundary(
            key: captureKey,
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: child!,
              ),
            ),
          ),
          routes: {
            '/home': (_) => const Scaffold(body: Text('App home')),
            '/servers': (_) =>
                const Scaffold(body: Text('Server address entry')),
          },
          home: TermuxSetupScreen(now: now),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    statusReads = 0;
  }
}

Future<_SetupProgressFixture> _setupFixture() async {
  SharedPreferences.setMockInitialValues({});
  return _SetupProgressFixture(
    _MemoryProfileStore(prefs: await SharedPreferences.getInstance()),
  );
}

/// Shared synthetic journey for the opt-in, real-font screenshot runner.
Future<VoidCallback> showReadyHandoffCapture(
  WidgetTester tester, {
  required GlobalKey captureKey,
  required ThemeData theme,
  double textScale = 1,
  bool connected = false,
}) async {
  final fixture = await _setupFixture();
  await fixture.mount(
    tester,
    captureKey: captureKey,
    theme: theme,
    textScale: textScale,
  );
  await _revealGuideTarget(tester, find.text('Install & start'));
  await tester.tap(find.text('Install & start'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  final pending = Completer<void>();
  if (!connected) fixture.connection.pendingConnect = pending;
  fixture.statusOutput =
      'phase=ready\nport=4096\nrunner=proot\nversion=1.18.29\n'
      'runtime=opencode1\npid=123\n__OC_SETUP_OUTPUT__\n'
      '[oc] authenticated server ready on 127.0.0.1:4096\n';
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(milliseconds: 300));
  await _scrollToTop(tester);
  return () {
    if (!pending.isCompleted) pending.complete();
  };
}

Future<void> _revealGuideTarget(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, maxScrolls: 80);
  // ensureVisible changes the scroll offset; the new layout needs a frame
  // before a tap can use the target's on-screen position.
  await tester.pump();
  await tester.ensureVisible(finder);
  await tester.pump();
  expect(finder.hitTestable(), findsOneWidget);
}

/// The installed-runtime view has the On this phone rows (TEAM-304/305)
/// under its controls, so it scrolls even on the test window and
/// [WidgetTester.ensureVisible] parks a control at the top. The heading
/// assertions below want the list back at its start.
Future<void> _scrollToTop(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable).first;
  if (scrollable.evaluate().isEmpty) return;
  final position = Scrollable.of(
    tester.element(
      find.descendant(of: scrollable, matching: find.byType(Padding)).first,
    ),
  ).position;
  position.jumpTo(0);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('oc/termux');

  testWidgets(
    'late version save cannot replace a newer same-profile connection',
    (tester) async {
      final fixture = await _setupFixture();
      final phone = ServerProfile(
        id: 'phone',
        name: 'This phone',
        baseUrl: TermuxBridge.managedServerUrl,
        password: 'synthetic-test-secret',
      );
      fixture.store.savedProfiles.add(phone);
      fixture.store.selectedID = phone.id;
      fixture.statusOutput =
          'phase=ready\nport=4096\nrunner=proot\nversion=1.18.29\n'
          'runtime=opencode1\npid=123\n__OC_SETUP_OUTPUT__\n';
      await fixture.mount(tester);
      final pending = Completer<void>();
      fixture.store.pendingSave = pending;
      await _revealGuideTarget(tester, find.text('Connect to OpenCode 1'));
      await tester.tap(find.text('Connect to OpenCode 1'));
      await tester.pump();
      expect(fixture.connection.connectCalls, 0);
      await fixture.connection.connect(phone);
      pending.complete();
      await tester.pumpAndSettle();
      expect(fixture.connection.connectCalls, 1);
      expect(fixture.connection.hasConnectedServer, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final selectionPending in [true, false]) {
    testWidgets(
      selectionPending
          ? 'cancel owns transport before active profile persistence completes'
          : 'cancel preserves a newer connection to the same phone profile',
      (tester) async {
        final fixture = await _setupFixture();
        final phone = ServerProfile(
          id: 'phone',
          name: 'This phone',
          baseUrl: TermuxBridge.managedServerUrl,
          password: 'synthetic-test-secret',
        );
        fixture.store.savedProfiles.add(phone);
        fixture.statusOutput =
            'phase=ready\nport=4096\nrunner=proot\nversion=1.18.29\n'
            'runtime=opencode1\npid=123\n__OC_SETUP_OUTPUT__\n';
        await fixture.mount(tester);
        final pending = Completer<void>();
        if (selectionPending) {
          fixture.store.pendingSelection = pending;
        } else {
          fixture.connection.pendingConnect = pending;
          fixture.connection.restoreLocation = true;
        }
        await _revealGuideTarget(tester, find.text('Connect to OpenCode 1'));
        await tester.tap(find.text('Connect to OpenCode 1'));
        await tester.pump();
        if (!selectionPending) {
          fixture.connection.pendingConnect = null;
          await fixture.connection.connect(phone);
          await tester.pump();
        } else {
          expect(fixture.store.selectedID, isNull);
          expect(fixture.connection.api, isNotNull);
        }
        await _revealGuideTarget(tester, find.text('Cancel connection'));
        await tester.tap(find.text('Cancel connection'));
        await tester.pumpAndSettle();
        expect(fixture.connection.hasConnectedServer, !selectionPending);
        pending.complete();
        await tester.pumpAndSettle();
        expect(fixture.connection.hasConnectedServer, !selectionPending);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('cancel releases monitoring before old storage work completes', (
    tester,
  ) async {
    final fixture = await _setupFixture();
    await fixture.mount(tester);
    await _revealGuideTarget(tester, find.text('Install & start'));
    await tester.tap(find.text('Install & start'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    fixture.store.selectedID = fixture.store.savedProfiles.single.id;
    final pending = Completer<void>();
    fixture.store.pendingSave = pending;
    fixture.statusOutput =
        'phase=ready\nport=4096\nrunner=proot\nversion=1.18.29\n'
        'runtime=opencode1\npid=123\n__OC_SETUP_OUTPUT__\n';
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await _revealGuideTarget(tester, find.text('Cancel connection'));
    await tester.tap(find.text('Cancel connection'));
    await tester.pumpAndSettle();
    fixture.store.pendingSave = null;
    fixture.statusOutput = null;
    final before = fixture.statusReads;
    await _revealGuideTarget(tester, find.text('Restart local server'));
    await tester.tap(find.text('Restart local server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();
    expect(fixture.restartCalls, 1);
    expect(fixture.statusReads, greaterThan(before));
    await _scrollToTop(tester);
    expect(find.text('Continue to app'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(fixture.connection.connectCalls, 0);
    expect(fixture.connection.hasConnectedServer, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final waitFor in ['storage', 'connection']) {
    testWidgets('ready server replaces setup log while waiting for $waitFor', (
      tester,
    ) async {
      final fixture = await _setupFixture();
      await fixture.mount(tester);
      await _revealGuideTarget(tester, find.text('Install & start'));
      await tester.tap(find.text('Install & start'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final pending = Completer<void>();
      if (waitFor == 'storage') {
        fixture.store.pendingSave = pending;
      } else {
        fixture.connection.pendingConnect = pending;
      }
      fixture.statusOutput =
          'phase=ready\nmessage=OpenCode is ready\nport=4096\n'
          'runner=proot\nversion=1.18.29\nruntime=opencode1\npid=123\n'
          '__OC_SETUP_OUTPUT__\n[oc] authenticated server ready on 127.0.0.1:4096\n';
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('OpenCode is running on this phone.'), findsOneWidget);
      expect(find.byKey(const Key('setup-live-output')), findsNothing);
      expect(find.text('Continue to app'), findsNothing);
      expect(find.textContaining('Connecting to'), findsOneWidget);
      await _revealGuideTarget(tester, find.text('Cancel connection'));
      expect(fixture.connection.connectCalls, waitFor == 'storage' ? 0 : 1);

      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Cancel connection'), findsNothing);
      await _scrollToTop(tester);
      await _revealGuideTarget(tester, find.text('Continue to app'));
      await tester.tap(find.text('Continue to app'));
      await tester.pumpAndSettle();
      expect(find.text('App home'), findsOneWidget);
    });

    testWidgets(
      'cancel during $waitFor retains ready server and ignores completion',
      (tester) async {
        final fixture = await _setupFixture();
        await fixture.mount(tester);
        await _revealGuideTarget(tester, find.text('Install & start'));
        await tester.tap(find.text('Install & start'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        final pending = Completer<void>();
        if (waitFor == 'storage') {
          fixture.store.pendingSave = pending;
        } else {
          fixture.connection.pendingConnect = pending;
        }
        fixture.statusOutput =
            'phase=ready\nport=4096\nrunner=proot\nversion=1.18.29\n'
            'runtime=opencode1\npid=123\n__OC_SETUP_OUTPUT__\n';
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        await _revealGuideTarget(tester, find.text('Cancel connection'));
        await tester.tap(find.text('Cancel connection'));
        await tester.pumpAndSettle();
        expect(find.text('Cancel connection'), findsNothing);
        await _scrollToTop(tester);
        expect(find.text('OpenCode is running on this phone.'), findsOneWidget);
        expect(fixture.restartCalls, 0);
        expect(fixture.launchCalls, 1);
        pending.complete();
        await tester.pumpAndSettle();
        expect(find.text('Continue to app'), findsNothing);
        expect(fixture.connection.hasConnectedServer, isFalse);
        expect(fixture.connection.connectCalls, waitFor == 'storage' ? 0 : 1);
        fixture.store.pendingSave = null;
        fixture.connection.pendingConnect = null;
        await _revealGuideTarget(tester, find.text('Connect to OpenCode 1'));
        await tester.tap(find.text('Connect to OpenCode 1'));
        await tester.pumpAndSettle();
        expect(find.text('Continue to app'), findsOneWidget);
        expect(fixture.launchCalls, 1);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'client failure keeps the ready server and offers connection retry',
    (tester) async {
      final fixture = await _setupFixture();
      fixture.connection.failConnect = true;
      await fixture.mount(tester);
      await _revealGuideTarget(tester, find.text('Install & start'));
      await tester.tap(find.text('Install & start'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      fixture.statusOutput =
          'phase=ready\nport=4096\nrunner=proot\nversion=1.18.29\n'
          'runtime=opencode1\npid=123\n__OC_SETUP_OUTPUT__\n';
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('OpenCode is running on this phone.'), findsOneWidget);
      expect(
        find.text('Could not connect to the phone server.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('setup-live-output')), findsNothing);
      fixture.connection.failConnect = false;
      await _revealGuideTarget(tester, find.text('Connect to OpenCode 1'));
      await tester.tap(find.text('Connect to OpenCode 1'));
      await tester.pumpAndSettle();
      expect(find.text('Continue to app'), findsOneWidget);
      expect(fixture.launchCalls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  // 2.5x is covered by the phone-space test below; at that scale nothing
  // fits "first" on a 320dp screen and the journey is about reachability.
  for (final textScale in [1.0, 2.0]) {
    testWidgets(
      'managed switch is visible first, preserves profiles and returns at scale $textScale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = await _setupFixture();
        final original = ServerProfile(
          id: 'original',
          name: 'My phone',
          baseUrl: TermuxBridge.managedServerUrl,
          password: 'one-fixture',
        );
        fixture.store.savedProfiles.add(original);
        fixture.store.selectedID = original.id;
        fixture.statusOutput =
            'phase=ready\nmessage=Ready\nport=4096\nrunner=proot\nversion=1.18.29\nruntime=opencode1\npid=123\n';
        await fixture.mount(
          tester,
          textScale: textScale,
          rtl: textScale == 2.5,
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(TermuxSetupScreen)),
        );
        expect(
          find.text(l10n.setupSwitchUse(l10n.setupRuntimeTwo)).hitTestable(),
          findsOneWidget,
        );
        expect(
          fixture.connection.api,
          isNull,
          reason: 'Inspecting setup does not connect',
        );
        await tester.tap(find.text(l10n.setupSwitchUse(l10n.setupRuntimeTwo)));
        await tester.pumpAndSettle();
        expect(find.text(l10n.setupSwitchConfirmDetail), findsOneWidget);
        await tester.ensureVisible(find.text(l10n.setupSwitchConfirm));
        await tester.tap(find.text(l10n.setupSwitchConfirm));
        await tester.pumpAndSettle();
        expect(fixture.switchCalls, 1);
        expect(original.flavor, ServerFlavor.v1);
        expect(original.password, 'one-fixture');
        expect(fixture.store.savedProfiles.length, 2);
        final beta = fixture.store.savedProfiles.singleWhere(
          (p) => p.flavor == ServerFlavor.v2,
        );
        expect(fixture.store.selectedID, beta.id);
        expect(beta.serverVersion, TermuxRuntime.openCode2.pinnedVersion);
        expect(find.text(l10n.setupRuntimeTwo), findsOneWidget);
        expect(
          find.text(l10n.setupSwitchReturn(l10n.setupRuntimeOne)).hitTestable(),
          findsOneWidget,
        );
        await tester.tap(
          find.text(l10n.setupSwitchReturn(l10n.setupRuntimeOne)),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(l10n.setupSwitchConfirm));
        await tester.tap(find.text(l10n.setupSwitchConfirm));
        await tester.pumpAndSettle();
        expect(fixture.switchCalls, 2);
        expect(fixture.store.selectedID, original.id);
        expect(original.serverVersion, TermuxRuntime.openCode1.pinnedVersion);
        expect(beta.flavor, ServerFlavor.v2);
        expect(fixture.store.savedProfiles.length, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'failed beta switch offers return without connecting unavailable beta',
    (tester) async {
      final fixture = await _setupFixture();
      final original = ServerProfile(
        id: 'original',
        name: 'Phone',
        baseUrl: TermuxBridge.managedServerUrl,
        password: 'one-fixture',
      );
      fixture.store.savedProfiles.add(original);
      fixture.store.selectedID = original.id;
      fixture.statusOutput =
          'phase=ready\nport=4096\nrunner=proot\nversion=1.18.29\nruntime=opencode1\n';
      fixture.switchFails = true;
      await fixture.mount(tester);
      await tester.tap(find.text('Try OpenCode 2 beta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Switch version'));
      await tester.pumpAndSettle();
      expect(fixture.connection.api, isNull);
      expect(find.text('Retry OpenCode 2 beta'), findsOneWidget);
      expect(find.text('Return to OpenCode 1'), findsOneWidget);
      fixture.switchFails = false;
      await tester.tap(find.text('Return to OpenCode 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Switch version'));
      await tester.pumpAndSettle();
      expect(fixture.store.selectedID, original.id);
    },
  );

  testWidgets('missing prior profile refuses switch without mutating setup', (
    tester,
  ) async {
    final fixture = await _setupFixture();
    fixture.statusOutput =
        'phase=ready\nport=4096\nrunner=proot\nversion=1.18.29\nruntime=opencode1\n';
    await fixture.mount(tester);
    await tester.tap(find.text('Try OpenCode 2 beta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Switch version'));
    await tester.pumpAndSettle();
    expect(fixture.switchCalls, 0);
    expect(fixture.store.savedProfiles, isEmpty);
    expect(
      find.textContaining('restore the saved profile before returning'),
      findsOneWidget,
    );
  });

  testWidgets('existing beta default data has no invented OC1 return', (
    tester,
  ) async {
    final fixture = await _setupFixture();
    fixture.runtime = TermuxRuntime.openCode2;
    fixture.statusOutput =
        'phase=stopped\nport=4096\nrunner=proot\nversion=0.0.0-beta-18600\nruntime=opencode2\n';
    fixture.inventoryOutput =
        'ubuntu=installed\nversion=0.0.0-beta-18600\nruntime=opencode2\n';
    await fixture.mount(tester);
    expect(find.text('Return to OpenCode 1'), findsNothing);
    expect(find.textContaining('keeps its existing data'), findsOneWidget);
    expect(fixture.switchCalls, 0);
  });

  testWidgets(
    'inspect and switch local runtime leave active remote connection selected',
    (tester) async {
      final fixture = await _setupFixture();
      final original = ServerProfile(
        id: 'original',
        name: 'Phone',
        baseUrl: TermuxBridge.managedServerUrl,
        password: 'one-fixture',
      );
      final remote = ServerProfile(
        id: 'remote',
        name: 'Laptop',
        baseUrl: 'https://example.invalid',
        password: 'remote-fixture',
      );
      fixture.store.savedProfiles.addAll([original, remote]);
      fixture.store.selectedID = remote.id;
      await fixture.connection.connect(remote);
      final remoteApi = fixture.connection.api;
      fixture.statusOutput =
          'phase=ready\nport=4096\nrunner=proot\nversion=1.18.29\nruntime=opencode1\n';
      await fixture.mount(tester);
      expect(fixture.connection.api, same(remoteApi));
      await tester.tap(find.text('Try OpenCode 2 beta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Switch version'));
      await tester.pumpAndSettle();
      expect(fixture.store.selectedID, remote.id);
      expect(fixture.connection.api, same(remoteApi));
      expect(find.text('Connect to OpenCode 2 beta'), findsOneWidget);
    },
  );

  for (final layout in [
    (width: 800.0, textScale: 1.0),
    (width: 390.0, textScale: 1.0),
    (width: 390.0, textScale: 2.0),
  ]) {
    testWidgets(
      'paste guide is inspectable at width ${layout.width}, text scale ${layout.textScale}',
      (tester) async {
        tester.view.physicalSize = Size(layout.width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = await _setupFixture();
        fixture.permissionGranted = false;
        await fixture.mount(tester, textScale: layout.textScale);
        if (layout.textScale == 1) {
          // The next action should not require scrolling through the guide.
          expect(
            find.byKey(const Key('termux-copy-open')).hitTestable(),
            findsOneWidget,
          );
        }
        for (final title in [
          '1. Copy & open',
          '2. Press and hold, then Paste',
          '3. Enter, then return',
        ]) {
          await _revealGuideTarget(tester, find.text(title));
        }
        expect(find.text(TermuxBridge.unlockCommand), findsNothing);
        await _revealGuideTarget(tester, find.text('Show command'));
        await tester.tap(find.text('Show command'));
        await tester.pumpAndSettle();
        expect(find.text(TermuxBridge.unlockCommand), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(fixture.handoffCalls, isEmpty);
        expect(fixture.commandCalls, 0);
        expect(fixture.store.savedProfiles, isEmpty);
      },
    );
  }

  testWidgets(
    'permission precedes copy and open, return verifies without installing',
    (tester) async {
      final fixture = await _setupFixture();
      fixture.permissionGranted = false;
      fixture.pendingPermission = Completer<bool>();
      fixture.watchClipboard();
      await fixture.mount(tester);
      final copyOpen = find.byKey(const Key('termux-copy-open'));
      await _revealGuideTarget(tester, copyOpen);
      await tester.tap(copyOpen);
      await tester.pump();
      expect(fixture.handoffCalls, ['permission']);
      expect(tester.widget<FilledButton>(copyOpen).onPressed, isNull);
      // Android permission dialogs can also pause/resume the activity.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(fixture.bridgeChecks, 0);
      fixture.pendingPermission!.complete(true);
      await tester.pumpAndSettle();
      expect(fixture.handoffCalls, ['permission', 'copy', 'open']);
      expect(fixture.copiedCommand, TermuxBridge.unlockCommand);
      expect(fixture.commandCalls, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(fixture.bridgeChecks, 1);
      expect(find.text('Install & start'), findsOneWidget);
      expect(fixture.handoffCalls, ['permission', 'copy', 'open']);
      expect(fixture.launchCalls, 0);
      expect(fixture.store.savedProfiles, isEmpty);
    },
  );

  testWidgets(
    'permission denial leaves clipboard alone and settings and retry usable',
    (tester) async {
      final fixture = await _setupFixture();
      fixture.permissionGranted = false;
      fixture.permissionResult = false;
      fixture.watchClipboard();
      await fixture.mount(tester);
      final copyOpen = find.byKey(const Key('termux-copy-open'));
      await _revealGuideTarget(tester, copyOpen);
      await tester.tap(copyOpen);
      await tester.pumpAndSettle();
      expect(fixture.handoffCalls, ['permission']);
      expect(fixture.copiedCommand, isNull);
      expect(find.textContaining('Android denied'), findsOneWidget);
      // Android can deliver the permission result before its resume callback.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.textContaining('Android denied'), findsOneWidget);
      expect(fixture.commandCalls, 0);
      await _revealGuideTarget(tester, find.text('App settings'));
      await tester.tap(find.text('App settings'));
      await tester.pumpAndSettle();
      expect(fixture.handoffCalls, ['permission', 'settings']);
      fixture.permissionResult = true;
      await _revealGuideTarget(tester, copyOpen);
      await tester.tap(copyOpen);
      await tester.pumpAndSettle();
      expect(fixture.handoffCalls, [
        'permission',
        'settings',
        'permission',
        'copy',
        'open',
      ]);
      expect(fixture.commandCalls, 0);
      expect(fixture.launchCalls, 0);
    },
  );

  for (final failure in [
    'open false',
    'open exception',
    'clipboard exception',
  ]) {
    testWidgets('copy/open failure is recoverable: $failure', (tester) async {
      final fixture = await _setupFixture();
      fixture.permissionGranted = false;
      fixture.openResult = failure != 'open false';
      if (failure == 'open exception') {
        fixture.openFailure = PlatformException(
          code: 'open_failed',
          message: 'Termux could not open. Try again.',
        );
      }
      if (failure == 'clipboard exception') {
        fixture.clipboardFailure = PlatformException(
          code: 'clipboard_failed',
          message: 'Could not copy the command. Try again.',
        );
      }
      fixture.watchClipboard();
      await fixture.mount(tester);
      final copyOpen = find.byKey(const Key('termux-copy-open'));
      await _revealGuideTarget(tester, copyOpen);
      await tester.tap(copyOpen);
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          failure == 'clipboard exception'
              ? 'Could not copy the command'
              : 'could not open',
        ),
        findsOneWidget,
      );
      expect(
        fixture.handoffCalls,
        failure == 'clipboard exception'
            ? ['permission', 'copy']
            : ['permission', 'copy', 'open'],
      );
      expect(tester.takeException(), isNull);
      fixture.openResult = true;
      fixture.openFailure = null;
      fixture.clipboardFailure = null;
      fixture.handoffCalls.clear();
      await _revealGuideTarget(tester, copyOpen);
      await tester.tap(copyOpen);
      await tester.pumpAndSettle();
      expect(fixture.handoffCalls, ['permission', 'copy', 'open']);
      expect(fixture.copiedCommand, TermuxBridge.unlockCommand);
      expect(fixture.commandCalls, 0);
      expect(fixture.launchCalls, 0);
    });
  }

  testWidgets(
    'late permission resume does not verify before Termux backgrounds and returns',
    (tester) async {
      final fixture = await _setupFixture();
      fixture.permissionGranted = false;
      fixture.pendingPermission = Completer<bool>();
      fixture.pendingOpen = Completer<bool>();
      fixture.watchClipboard();
      await fixture.mount(tester);
      final copyOpen = find.byKey(const Key('termux-copy-open'));
      await _revealGuideTarget(tester, copyOpen);
      await tester.tap(copyOpen);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      fixture.pendingPermission!.complete(true);
      await tester.pump();
      expect(fixture.handoffCalls, ['permission', 'copy', 'open']);
      // This belongs to the permission dialog, before Termux backgrounds us.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(fixture.bridgeChecks, 0);
      fixture.pendingOpen!.complete(true);
      await tester.pumpAndSettle();
      expect(fixture.bridgeChecks, 0);
      // Inactive alone can still be a dialog, not a Termux round trip.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(fixture.bridgeChecks, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(fixture.bridgeChecks, 1);
      expect(find.text('Install & start'), findsOneWidget);
      expect(fixture.launchCalls, 0);
      expect(fixture.store.savedProfiles, isEmpty);
    },
  );

  testWidgets(
    'early return verifies after open completes and failed verification can retry',
    (tester) async {
      final fixture = await _setupFixture();
      fixture.permissionGranted = false;
      fixture.bridgeUnlocked = false;
      fixture.pendingOpen = Completer<bool>();
      fixture.watchClipboard();
      await fixture.mount(tester);
      final copyOpen = find.byKey(const Key('termux-copy-open'));
      await _revealGuideTarget(tester, copyOpen);
      await tester.tap(copyOpen);
      await tester.pump();
      expect(fixture.handoffCalls, ['permission', 'copy', 'open']);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(fixture.bridgeChecks, 0);
      fixture.pendingOpen!.complete(true);
      await tester.pumpAndSettle();
      expect(fixture.bridgeChecks, 1);
      expect(find.textContaining('Termux did not answer'), findsOneWidget);
      final verify = find.byKey(const Key('termux-verify-unlock'));
      expect(tester.widget<FilledButton>(verify).onPressed, isNotNull);
      fixture.bridgeUnlocked = true;
      await _revealGuideTarget(tester, verify);
      await tester.tap(verify);
      await tester.pumpAndSettle();
      expect(fixture.bridgeChecks, 2);
      expect(find.text('Install & start'), findsOneWidget);
      expect(fixture.launchCalls, 0);
      expect(fixture.store.savedProfiles, isEmpty);
    },
  );

  testWidgets(
    'new switch hides prior elapsed clock until accepted and resumes durable timing',
    (tester) async {
      var now = DateTime.utc(2026, 9, 10, 1);
      final oldStart =
          now
              .subtract(const Duration(minutes: 99, seconds: 30))
              .millisecondsSinceEpoch ~/
          1000;
      final fixture = await _setupFixture();
      fixture.store.savedProfiles.add(
        ServerProfile(
          id: 'original',
          name: 'Phone',
          baseUrl: TermuxBridge.managedServerUrl,
          password: 'fixture-one',
        ),
      );
      fixture.store.selectedID = 'original';
      fixture.statusOutput =
          'phase=ready\nport=4096\nrunner=proot\nversion=1.18.29\nruntime=opencode1\nstarted_at=$oldStart\n';
      fixture.pendingLaunch = Completer<Map<String, Object>>();
      fixture.switchPhase = 'installing_opencode';
      await fixture.mount(tester, now: () => now);
      await tester.tap(find.text('Try OpenCode 2 beta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Switch version'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(fixture.switchCalls, 1);
      expect(find.text('Preparing the runtime switch…'), findsOneWidget);
      expect(find.textContaining('elapsed'), findsNothing);
      now = now.add(const Duration(seconds: 20));
      await tester.pump(const Duration(seconds: 20));
      expect(find.textContaining('elapsed'), findsNothing);
      fixture.startedAtEpochSeconds =
          now.subtract(const Duration(seconds: 2)).millisecondsSinceEpoch ~/
          1000;
      fixture.pendingLaunch!.complete(
        _commandResult(stdout: 'manager-started:123'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('2s elapsed'), findsOneWidget);
      expect(
        find.text('You can leave this screen and return to check progress.'),
        findsOneWidget,
      );
      expect(find.textContaining('First-time setup'), findsNothing);
      final persisted = fixture.statusOutput;
      await tester.pumpWidget(const SizedBox.shrink());
      now = now.add(const Duration(minutes: 1));
      final reopened = _SetupProgressFixture(fixture.store)
        ..statusOutput = persisted;
      await reopened.mount(tester, now: () => now);
      expect(find.text('1m 2s elapsed'), findsOneWidget);
      expect(find.textContaining('First-time setup'), findsNothing);
      expect(reopened.switchCalls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'elapsed uses persisted start across background and route recreation',
    (tester) async {
      var now = DateTime.utc(2026, 9, 7, 12);
      final startedAt =
          now.subtract(const Duration(seconds: 125)).millisecondsSinceEpoch ~/
          1000;
      final fixture = await _setupFixture();
      fixture.launched = true;
      fixture.startedAtEpochSeconds = startedAt;
      await fixture.mount(tester, now: () => now);
      expect(find.text('2m 5s elapsed'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      // Time passes with no foreground timer callbacks.
      now = now.add(const Duration(minutes: 3));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('5m 5s elapsed'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      now = now.add(const Duration(minutes: 1));
      final reopened = _SetupProgressFixture(fixture.store);
      reopened.launched = true;
      reopened.startedAtEpochSeconds = startedAt;
      await reopened.mount(tester, now: () => now);
      expect(find.text('6m 5s elapsed'), findsOneWidget);
      expect(fixture.launchCalls + reopened.launchCalls, 0);
      expect(fixture.store.savedProfiles, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'elapsed hides legacy total and follows authoritative operation timestamps',
    (tester) async {
      var now = DateTime.utc(2026, 9, 7, 12);
      final fixture = await _setupFixture();
      fixture.launched = true;
      await fixture.mount(tester, now: () => now);
      expect(find.textContaining('elapsed'), findsNothing);
      fixture.startedAtEpochSeconds =
          now.add(const Duration(seconds: 60)).millisecondsSinceEpoch ~/ 1000;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('0s elapsed'), findsOneWidget);
      now = now.add(const Duration(seconds: 90));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('30s elapsed'), findsOneWidget);
      // A new accepted operation has a new persisted start, not the old total.
      fixture.startedAtEpochSeconds = now.millisecondsSinceEpoch ~/ 1000;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('0s elapsed'), findsOneWidget);
      now = now.add(const Duration(minutes: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2m 0s elapsed'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'install shows immediate progress throughout slow native startup',
    (tester) async {
      final fixture = await _setupFixture();
      await fixture.mount(tester);
      fixture.pendingBridge = Completer<Map<String, Object>>();
      fixture.store.pendingSave = Completer<void>();
      fixture.pendingLaunch = Completer<Map<String, Object>>();
      fixture.pendingStatus = Completer<Map<String, Object>>();

      await tester.scrollUntilVisible(find.text('Install & start'), 250);
      await tester.pump();
      await tester.tap(find.text('Install & start'));
      await tester.pump();

      expect(find.text('Preparing setup'), findsOneWidget);
      expect(find.text('Checking Termux connection'), findsOneWidget);
      expect(find.textContaining('elapsed'), findsNothing);
      expect(find.text('LIVE OUTPUT'), findsOneWidget);
      expect(find.text('Install & start'), findsNothing);
      expect(fixture.launchCalls, 0);
      expect(fixture.statusReads, 0);

      await tester.pump(const Duration(seconds: 21));
      expect(find.textContaining('elapsed'), findsNothing);
      expect(find.text('Checking Termux connection'), findsOneWidget);
      expect(fixture.statusReads, 0);

      fixture.pendingBridge!.complete(
        _commandResult(stdout: 'opencode-bridge-ok'),
      );
      await tester.pump();
      expect(find.text('Saving local server settings'), findsOneWidget);
      expect(fixture.launchCalls, 0);

      fixture.store.pendingSave!.complete();
      await tester.pump();
      expect(find.text('Starting setup in Termux'), findsOneWidget);
      expect(fixture.launchCalls, 1);
      await tester.pump(const Duration(seconds: 3));
      expect(fixture.launchCalls, 1);
      expect(fixture.statusReads, 0);

      fixture.pendingLaunch!.complete(
        _commandResult(stdout: 'manager-started:123'),
      );
      await tester.pump();
      expect(find.text('Reading setup progress'), findsOneWidget);
      fixture.pendingStatus!.complete(fixture.statusResult());
      await tester.pump();
      expect(find.text('Installing Termux dependencies'), findsOneWidget);
      expect(fixture.launchCalls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'prelaunch bridge failure stops waiting and offers a working retry',
    (tester) async {
      final fixture = await _setupFixture();
      await fixture.mount(tester);
      fixture.pendingBridge = Completer<Map<String, Object>>();
      await tester.scrollUntilVisible(find.text('Install & start'), 250);
      await tester.pump();
      await tester.tap(find.text('Install & start'));
      await tester.pump();
      fixture.pendingBridge!.completeError(
        PlatformException(
          code: 'bridge_failed',
          message: 'Termux could not answer',
        ),
      );
      await tester.pump();
      expect(find.textContaining('Termux could not answer'), findsOneWidget);
      expect(fixture.launchCalls, 0);
      expect(fixture.store.savedProfiles, isEmpty);

      fixture.pendingBridge = null;
      await tester.ensureVisible(
        find.text('Retry — resumes where setup left off'),
      );
      await tester.pump();
      await tester.tap(find.text('Retry — resumes where setup left off'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(fixture.launchCalls, 1);
      expect(find.text('Installing Termux dependencies'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'resuming during launch preserves progress and avoids stale polling',
    (tester) async {
      final fixture = await _setupFixture();
      await fixture.mount(tester);
      fixture.pendingLaunch = Completer<Map<String, Object>>();
      await tester.scrollUntilVisible(find.text('Install & start'), 250);
      await tester.pump();
      await tester.tap(find.text('Install & start'));
      await tester.pump();
      expect(fixture.launchCalls, 1);
      expect(find.text('Starting setup in Termux'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Starting setup in Termux'), findsOneWidget);
      expect(find.text('Install & start'), findsNothing);
      expect(fixture.statusReads, 0);
      expect(fixture.launchCalls, 1);

      fixture.pendingLaunch!.complete(
        _commandResult(stdout: 'manager-started:123'),
      );
      await tester.pump();
      expect(find.text('Installing Termux dependencies'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final textScale in [1.0, 2.0, 2.5]) {
    testWidgets(
      'setup uses phone space without overflow at text scale $textScale',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = await _setupFixture();
        await fixture.mount(
          tester,
          textScale: textScale,
          rtl: textScale == 2.5,
        );
        await tester.scrollUntilVisible(find.text('Install & start'), 250);
        await Scrollable.ensureVisible(
          tester.element(find.text('Install & start')),
          alignment: 0.5,
        );
        await tester.pump();
        await tester.tap(find.text('Install & start'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.scrollUntilVisible(
          find.text('LIVE OUTPUT'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        expect(find.text('LIVE OUTPUT'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (textScale == 1) {
          final terminal = find.byKey(const Key('setup-live-output'));
          expect(tester.getSize(terminal).height, greaterThanOrEqualTo(300));
          expect(tester.getRect(terminal).bottom, lessThanOrEqualTo(844));
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final missing in ['Termux', 'permission']) {
    testWidgets('existing server stays reachable without $missing', (
      tester,
    ) async {
      final fixture = await _setupFixture();
      fixture.termuxInstalled = missing != 'Termux';
      fixture.permissionGranted = missing != 'permission';
      await fixture.mount(tester);
      await tester.tap(find.text('Connect existing server'));
      await tester.pumpAndSettle();
      expect(find.text('Server address entry'), findsOneWidget);
      expect(fixture.commandCalls, 0);
      expect(fixture.store.savedProfiles, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('desktop setup offers existing server with large text', (
    tester,
  ) async {
    debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
    addTearDown(() => debugPlatformCapabilities = null);
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = await _setupFixture();
    await fixture.mount(tester, textScale: 2);
    await tester.scrollUntilVisible(find.text('Connect existing server'), 200);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Connect existing server'));
    await tester.pumpAndSettle();
    expect(find.text('Server address entry'), findsOneWidget);
    expect(fixture.commandCalls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'failed inventory requires reviewed Ubuntu choice before launch',
    (tester) async {
      final fixture = await _setupFixture();
      fixture.inventoryFails = true;
      await fixture.mount(tester);
      await tester.scrollUntilVisible(find.text('Install & start'), 200);
      await tester.pump();
      await tester.tap(find.text('Install & start'));
      await tester.pumpAndSettle();
      expect(
        find.text('Continue without an installation check?'),
        findsOneWidget,
      );
      expect(fixture.launchCalls, 0);
      expect(fixture.store.savedProfiles, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(fixture.launchCalls, 0);
      await tester.tap(find.text('Install & start'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue with Ubuntu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(fixture.launchCalls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('checks the environment before enabling installation', (
    tester,
  ) async {
    final fixture = await _setupFixture();
    fixture.pendingInventory = Completer<Map<String, Object>>();
    await fixture.mount(tester);
    expect(find.text('Checking installed environment...'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Install & start'), 200);
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Install & start'),
    );
    expect(button.onPressed, isNull);
    expect(fixture.launchCalls, 0);
    fixture.pendingInventory!.complete(
      _commandResult(stdout: 'ubuntu=absent\nversion=\n'),
    );
    await tester.pump();
    expect(find.text('No managed Ubuntu installation found.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Install & start'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'first installation asks and saves the selected beta before launch',
    (tester) async {
      final fixture = await _setupFixture();
      fixture.runtime = TermuxRuntime.openCode2;
      fixture.store.pendingSave = Completer<void>();
      await fixture.mount(tester);
      await _revealGuideTarget(
        tester,
        find.byKey(const Key('setup-runtime-opencode2')),
      );
      expect(
        find.text('Which OpenCode would you like to use?'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<RadioGroup<TermuxRuntime>>(
              find.byType(RadioGroup<TermuxRuntime>),
            )
            .groupValue,
        TermuxRuntime.openCode1,
      );
      await tester.tap(
        find.byKey(const Key('setup-runtime-opencode2')).hitTestable(),
      );
      await tester.pump();
      expect(fixture.launchCalls, 0);
      expect(fixture.store.savedProfiles, isEmpty);
      expect(
        tester
            .widget<RadioGroup<TermuxRuntime>>(
              find.byType(RadioGroup<TermuxRuntime>),
            )
            .groupValue,
        TermuxRuntime.openCode2,
      );
      await _revealGuideTarget(tester, find.text('Install & start'));
      expect(find.textContaining('0.0.0-beta-18600'), findsOneWidget);
      await tester.tap(find.text('Install & start').hitTestable());
      await tester.pump();
      expect(fixture.launchCalls, 0);
      fixture.store.pendingSave!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(fixture.launchCalls, 1);
      expect(
        fixture.launchedScript,
        contains("setup '4096' '0.0.0-beta-18600'"),
      );
      final saved = fixture.store.savedProfiles.single;
      expect(saved.flavor, ServerFlavor.v2);
      expect(saved.username, 'opencode');
      expect(saved.password, isNotEmpty);
      expect(fixture.launchedScript, contains(saved.password));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'legacy stopped state does not override the visible beta choice',
    (tester) async {
      final fixture = await _setupFixture();
      fixture.runtime = TermuxRuntime.openCode2;
      fixture.statusOutput = 'phase=stopped\nmessage=Stopped\nversion=\n';
      await fixture.mount(tester);
      final beta = find.byKey(const Key('setup-runtime-opencode2'));
      await _revealGuideTarget(tester, beta);
      await tester.tap(beta.hitTestable());
      await tester.pump();
      await _revealGuideTarget(tester, find.text('Install & start'));
      expect(find.textContaining('0.0.0-beta-18600'), findsOneWidget);
      fixture.statusOutput = null;
      await tester.tap(find.text('Install & start').hitTestable());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(fixture.launchCalls, 1);
      expect(
        fixture.launchedScript,
        contains("setup '4096' '0.0.0-beta-18600'"),
      );
      expect(fixture.store.savedProfiles.single.flavor, ServerFlavor.v2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'fresh beta remains installed after ready and Stop on the same route',
    (tester) async {
      final fixture = await _setupFixture();
      fixture.runtime = TermuxRuntime.openCode2;
      await fixture.mount(tester);
      final beta = find.byKey(const Key('setup-runtime-opencode2'));
      await _revealGuideTarget(tester, beta);
      await tester.tap(beta.hitTestable());
      await tester.pump();
      await _revealGuideTarget(tester, find.text('Install & start'));
      await tester.tap(find.text('Install & start').hitTestable());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(fixture.launchCalls, 1);
      fixture.statusOutput =
          'phase=ready\nmessage=OpenCode is ready\nport=4096\n'
          'runner=proot\nversion=0.0.0-beta-18600\nruntime=opencode2\npid=123\n';
      fixture.inventoryOutput =
          'ubuntu=installed\nversion=0.0.0-beta-18600\nruntime=opencode2\n';
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await _revealGuideTarget(tester, find.text('Stop local server'));
      fixture.pendingInventory = Completer<Map<String, Object>>();
      await tester.tap(find.text('Stop local server').hitTestable());
      await tester.pump();
      expect(find.byType(RadioGroup<TermuxRuntime>), findsNothing);
      fixture.pendingInventory!.complete(
        _commandResult(stdout: fixture.inventoryOutput),
      );
      await tester.pumpAndSettle();
      await _revealGuideTarget(tester, find.text('Reinstall & start'));
      await _scrollToTop(tester);
      expect(find.byType(RadioGroup<TermuxRuntime>), findsNothing);
      expect(find.textContaining('0.0.0-beta-18600'), findsWidgets);
      await tester.tap(find.text('Reinstall & start').hitTestable());
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Replace OpenCode 0.0.0-beta-18600 with 0.0.0-beta-18600',
        ),
        findsOneWidget,
      );
      expect(fixture.launchCalls, 1);
      expect(fixture.store.savedProfiles, hasLength(1));
      await tester.tap(find.text('Cancel').hitTestable());
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final runtime in TermuxRuntime.values) {
    testWidgets('existing ${runtime.wireName} retains its runtime on repair', (
      tester,
    ) async {
      final fixture = await _setupFixture();
      fixture.runtime = runtime;
      // Legacy v1 installations have no runtime marker. Both forms are locked
      // to their installed generation, including on a newly created route.
      fixture.inventoryOutput =
          'ubuntu=installed\nversion=${runtime.pinnedVersion}\n'
          '${runtime == TermuxRuntime.openCode2 ? 'runtime=opencode2\n' : ''}';
      await fixture.mount(tester);
      await _revealGuideTarget(tester, find.text('Reinstall & start'));
      expect(find.byType(RadioGroup<TermuxRuntime>), findsNothing);
      await tester.tap(find.text('Reinstall & start').hitTestable());
      await tester.pumpAndSettle();
      expect(fixture.launchCalls, 0);
      expect(
        find.textContaining(
          'Replace OpenCode ${runtime.pinnedVersion} with ${runtime.pinnedVersion}',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Install & restart').hitTestable());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(fixture.launchCalls, 1);
      expect(
        fixture.launchedScript,
        contains("setup '4096' '${runtime.pinnedVersion}'"),
      );
      expect(
        fixture.store.savedProfiles.single.flavor,
        runtime == TermuxRuntime.openCode2 ? ServerFlavor.v2 : ServerFlavor.v1,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'beta start reuses its saved profile without installing or selecting a generation',
    (tester) async {
      final fixture = await _setupFixture();
      fixture.runtime = TermuxRuntime.openCode2;
      fixture.inventoryOutput =
          'ubuntu=installed\nversion=0.0.0-beta-18600\nruntime=opencode2\n';
      fixture.store.savedProfiles.add(
        ServerProfile(
          id: 'local-beta',
          name: 'This device',
          baseUrl: TermuxBridge.managedServerUrl,
          username: 'opencode',
          password: 'synthetic-test-secret',
          flavor: ServerFlavor.v2,
        ),
      );
      await fixture.mount(tester);
      await _revealGuideTarget(tester, find.text('Start installed OpenCode'));
      expect(find.byType(RadioGroup<TermuxRuntime>), findsNothing);
      await tester.tap(find.text('Start installed OpenCode').hitTestable());
      await tester.pumpAndSettle();
      expect(fixture.restartCalls, 0);
      await tester.tap(find.text('Start & connect').hitTestable());
      await tester.pumpAndSettle();
      expect(fixture.restartCalls, 1);
      expect(fixture.launchCalls, 0);
      expect(fixture.store.savedProfiles, hasLength(1));
      expect(fixture.store.selectedID, 'local-beta');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('runtime choice wraps at 320 pixels with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = await _setupFixture();
    await fixture.mount(tester, textScale: 2);
    await _revealGuideTarget(
      tester,
      find.byKey(const Key('setup-runtime-opencode2')),
    );
    await tester.tap(
      find.byKey(const Key('setup-runtime-opencode2')).hitTestable(),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await _revealGuideTarget(tester, find.text('Install & start'));
    expect(tester.takeException(), isNull);
    expect(fixture.launchCalls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('starts the detected installation without downloading packages', (
    tester,
  ) async {
    final fixture = await _setupFixture();
    fixture.inventoryOutput = 'ubuntu=installed\nversion=1.18.29\n';
    fixture.store.savedProfiles.add(
      ServerProfile(
        id: 'local',
        name: 'This device',
        baseUrl: TermuxBridge.managedServerUrl,
        username: 'opencode',
        password: 'synthetic-test-secret',
      ),
    );
    await fixture.mount(tester);
    expect(find.text('Version 1.18.29'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Start installed OpenCode'), 200);
    await tester.pump();
    await tester.tap(find.text('Start installed OpenCode'));
    await tester.pumpAndSettle();
    expect(fixture.restartCalls, 0);
    await tester.tap(find.text('Start & connect'));
    await tester.pumpAndSettle();
    expect(fixture.restartCalls, 1);
    expect(fixture.launchCalls, 0);
    expect(find.text('Continue to app'), findsOneWidget);
    expect(fixture.store.selectedID, 'local');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reinstalling a detected version requires replacement review', (
    tester,
  ) async {
    final fixture = await _setupFixture();
    fixture.startedAtEpochSeconds =
        DateTime.now().millisecondsSinceEpoch ~/ 1000;
    fixture.inventoryOutput = 'ubuntu=installed\nversion=1.18.29\n';
    await fixture.mount(tester);
    final reinstall = find.widgetWithText(OutlinedButton, 'Reinstall & start');
    await tester.scrollUntilVisible(reinstall.hitTestable(), 200);
    await tester.tap(reinstall.hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Replace installed OpenCode?'), findsOneWidget);
    expect(
      find.textContaining('Replace OpenCode 1.18.29 with 1.18.29'),
      findsOneWidget,
    );
    expect(fixture.launchCalls, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(fixture.launchCalls, 0);
    await tester.tap(reinstall.hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install & restart'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(fixture.launchCalls, 1);
    expect(find.textContaining('elapsed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('checking Termux does not mark the download step complete', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = _MemoryProfileStore(
      prefs: await SharedPreferences.getInstance(),
    );
    final connection = _LocalConnectionController(store);
    addTearDown(connection.dispose);
    final capabilities = Completer<Map<String, Object?>>();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getCapabilities') return capabilities.future;
          return _commandResult();
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

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
          home: TermuxSetupScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Checking Termux...'), findsOneWidget);
    expect(find.byIcon(AppIconography.check), findsNothing);

    capabilities.complete({
      'installed': false,
      'version': null,
      'serviceAvailable': false,
      'protocolSupported': false,
      'permissionGranted': false,
    });
    await tester.pump();
  });

  testWidgets(
    'successful setup exposes controls and stops despite recovery cleanup failure',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = _MemoryProfileStore(
        prefs: await SharedPreferences.getInstance(),
      );
      final connection = _LocalConnectionController(store);
      addTearDown(connection.dispose);
      var launched = false;
      var launchCalls = 0;
      var restartCalls = 0;
      var restartShouldFail = false;
      var restartOperation = '';
      var restartResult = '';
      var stopCalls = 0;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getCapabilities') {
              return <String, Object>{
                'installed': true,
                'version': '0.118',
                'serviceAvailable': true,
                'protocolSupported': true,
                'permissionGranted': true,
              };
            }
            if (call.method != 'runInTermux') return true;
            final arguments = call.arguments as Map<Object?, Object?>;
            final script = arguments['script']! as String;
            if (script.contains('exec "\$MANAGER" recovery-disarm')) {
              return {..._commandResult(), 'exitCode': 75};
            }
            if (script.contains('ubuntu=absent')) {
              return _commandResult(
                stdout: launchCalls > 0
                    ? 'ubuntu=installed\nversion=1.18.21\nruntime=opencode1\n'
                    : 'ubuntu=absent\nversion=\n',
              );
            }
            if (script.contains("printf 'opencode-bridge-ok'")) {
              return _commandResult(stdout: 'opencode-bridge-ok');
            }
            if (script.contains('__OC_SETUP_OUTPUT__')) {
              return _commandResult(
                stdout: launched
                    ? '''phase=ready
message=OpenCode is ready
port=4096
runner=proot
version=1.18.21
pid=321
operation=$restartOperation
operation_result=$restartResult
__OC_SETUP_OUTPUT__
[oc] authenticated server ready
'''
                    : '''phase=idle
message=No setup has been started
port=4096
runner=
version=
pid=
__OC_SETUP_OUTPUT__
''',
              );
            }
            if (script.contains("manager.sh\" stop '4096'")) {
              launched = false;
              stopCalls++;
              return _commandResult(stdout: '[oc] server stopped');
            }
            if (script.contains("\"\$MANAGER\" restart '4096' ")) {
              restartCalls++;
              restartOperation = RegExp(
                r"restart '4096' '([^']+)'",
              ).firstMatch(script)!.group(1)!;
              if (restartShouldFail) {
                restartResult = 'not_performed';
                return {
                  ..._commandResult(),
                  'stderr': 'The installed OpenCode command is unavailable',
                  'exitCode': 1,
                };
              }
              restartResult = 'completed';
              launched = true;
              return _commandResult(stdout: '[oc] authenticated server ready');
            }
            if (script.contains('manager_tmp=')) {
              restartOperation = '';
              restartResult = '';
              launched = true;
              launchCalls++;
              return _commandResult(stdout: 'manager-started:123');
            }
            if (script.contains('exec "') && script.contains(' status')) {
              return _commandResult(
                stdout: launched
                    ? '''phase=ready
message=OpenCode is ready
port=4096
runner=proot
version=1.18.21
pid=321
'''
                    : '''phase=idle
message=No setup has been started
port=4096
runner=
version=
pid=
''',
              );
            }
            return _commandResult();
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

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
            home: const TermuxSetupScreen(),
            routes: {'/home': (_) => const Scaffold(body: Text('Home'))},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Install & start'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Install & start'), 250);
      await tester.pump();
      await tester.tap(find.text('Install & start'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('OpenCode is running on this phone.'), findsOneWidget);
      expect(find.text('Continue to app'), findsOneWidget);
      expect(find.text('Stop local server'), findsOneWidget);
      expect(find.text('Restart local server'), findsOneWidget);
      expect(find.textContaining('Version 1.18.21'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('restart-managed-opencode')),
      );
      connection.busySessions.add('busy-session');
      await tester.tap(find.byKey(const Key('restart-managed-opencode')));
      await tester.pumpAndSettle();
      expect(find.text('Restart the local server?'), findsOneWidget);
      expect(
        find.textContaining(
          '1 session is generating. Restarting will interrupt it.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('update-managed-opencode')),
      );
      connection.busySessions.add('busy-session');
      await tester.tap(find.byKey(const Key('update-managed-opencode')));
      await tester.pump();
      expect(
        find.text('Stop active generation before updating OpenCode.'),
        findsOneWidget,
      );
      expect(launchCalls, 1);
      connection.busySessions.clear();

      await tester.ensureVisible(
        find.byKey(const Key('restart-managed-opencode')),
      );
      await _scrollToTop(tester);
      connection.retriesToFail = 1;
      await tester.tap(find.byKey(const Key('restart-managed-opencode')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Restart'));
      await tester.pumpAndSettle();
      expect(restartCalls, 1);
      expect(connection.retryCalls, 2);
      expect(launchCalls, 1);
      expect(find.text('OpenCode is running on this phone.'), findsOneWidget);

      restartShouldFail = true;
      await tester.tap(find.byKey(const Key('restart-managed-opencode')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Restart'));
      await tester.pumpAndSettle();
      expect(restartCalls, 2);
      expect(connection.retryCalls, 2);
      expect(find.text('OpenCode is running on this phone.'), findsOneWidget);
      restartShouldFail = false;

      await tester.tap(find.byKey(const Key('update-managed-opencode')));
      await tester.pumpAndSettle();
      expect(find.text('Update managed OpenCode?'), findsOneWidget);
      // The dialog names the exact pinned release, not "latest": the user is
      // agreeing to install a specific server version.
      expect(
        find.textContaining(
          'The app will install OpenCode 1 ${TermuxBridge.defaultOpenCodeVersion}, '
          'restart only the managed local server',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Update'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(launchCalls, 2);
      expect(find.text('OpenCode is running on this phone.'), findsOneWidget);

      await store.prefs.setString(
        'oc.managedServerRecovery.${store.profiles.first.id}',
        '{"enabled":true,"token":"synthetic-permit"}',
      );
      await tester.ensureVisible(find.text('Stop local server'));
      await tester.tap(find.text('Stop local server'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(stopCalls, 1);
      expect(connection.api, isNull);
      expect(find.textContaining('local server is stopped'), findsOneWidget);
      expect(
        find.textContaining('Recovery settings could not be fully cleared'),
        findsOneWidget,
      );
      expect(find.text('Start installed OpenCode'), findsOneWidget);
      expect(find.text('Install & start'), findsNothing);
      expect(find.byType(RadioGroup<TermuxRuntime>), findsNothing);
    },
  );

  for (final staleReady in [true, false]) {
    testWidgets(
      staleReady
          ? 'restart timeout does not accept a previous ready operation'
          : 'restart timeout follows matching preflight until completion',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final store = _MemoryProfileStore(
          prefs: await SharedPreferences.getInstance(),
        );
        final profile = ServerProfile(
          id: 'local',
          name: 'Local',
          baseUrl: TermuxBridge.managedServerUrl,
          username: 'opencode',
          password: 'test-password',
        );
        await store.upsert(profile);
        final connection = _LocalConnectionController(store);
        await connection.connect(profile);
        addTearDown(connection.dispose);
        String? operation;
        var completed = false;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'getCapabilities') {
                return <String, Object>{
                  'installed': true,
                  'version': '0.118',
                  'serviceAvailable': true,
                  'protocolSupported': true,
                  'permissionGranted': true,
                };
              }
              if (call.method != 'runInTermux') return true;
              final script = (call.arguments as Map)['script'] as String;
              if (script.contains('ubuntu=absent')) {
                return _commandResult(stdout: 'ubuntu=absent\nversion=\n');
              }
              if (script.contains("printf 'opencode-bridge-ok'")) {
                return _commandResult(stdout: 'opencode-bridge-ok');
              }
              if (script.contains("\"\$MANAGER\" restart '4096' ")) {
                operation = RegExp(
                  r"restart '4096' '([^']+)'",
                ).firstMatch(script)!.group(1)!;
                throw PlatformException(code: 'command_timeout');
              }
              if (script.contains('__OC_SETUP_OUTPUT__')) {
                final preflight =
                    operation != null && !staleReady && !completed;
                return _commandResult(
                  stdout:
                      '''phase=${preflight ? 'restarting' : 'ready'}
message=${preflight ? 'Checking the local server before restart' : 'OpenCode is ready'}
port=4096
runner=proot
version=1.18.21
pid=321
operation=${staleReady ? 'prior-restart' : operation ?? ''}
operation_result=${preflight ? '' : 'completed'}
__OC_SETUP_OUTPUT__
''',
                );
              }
              return _commandResult();
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              bootstrapProvider.overrideWithValue(AppBootstrap(store)),
              connProvider.overrideWithValue(connection),
            ],
            child: const MaterialApp(
              locale: Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: TermuxSetupScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final restartButton = find.byKey(const Key('restart-managed-opencode'));
        await tester.scrollUntilVisible(restartButton.hitTestable(), 200);
        await tester.pumpAndSettle();
        await tester.tap(restartButton.hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Restart'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(operation, isNotNull);
        expect(connection.retryCalls, 0);
        expect(
          find.text('Local server restarted and reconnected.'),
          findsNothing,
        );
        if (staleReady) {
          expect(
            find.textContaining('Could not restart the local server'),
            findsOneWidget,
          );
        } else {
          expect(
            find.textContaining('Checking the local server before restart'),
            findsOneWidget,
          );
          completed = true;
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          expect(connection.retryCalls, 1);
          expect(
            find.text('OpenCode is running on this phone.'),
            findsOneWidget,
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('launch timeout recovers the persisted phase and root cause', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = _MemoryProfileStore(
      prefs: await SharedPreferences.getInstance(),
    );
    final connection = _LocalConnectionController(store);
    addTearDown(connection.dispose);
    var launchTimedOut = false;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getCapabilities') {
            return <String, Object>{
              'installed': true,
              'version': '0.118',
              'serviceAvailable': true,
              'protocolSupported': true,
              'permissionGranted': true,
            };
          }
          if (call.method != 'runInTermux') return true;
          final arguments = call.arguments as Map<Object?, Object?>;
          final script = arguments['script']! as String;
          if (script.contains('ubuntu=absent')) {
            return _commandResult(stdout: 'ubuntu=absent\nversion=\n');
          }
          if (script.contains("printf 'opencode-bridge-ok'")) {
            return _commandResult(stdout: 'opencode-bridge-ok');
          }
          if (script.contains('manager_tmp=')) {
            launchTimedOut = true;
            throw PlatformException(
              code: 'command_timeout',
              message:
                  'Termux did not return a command result within 30 seconds.',
            );
          }
          if (script.contains('__OC_SETUP_OUTPUT__')) {
            return _commandResult(
              stdout: launchTimedOut
                  ? '''phase=failed
message=Repairing the Termux package set failed (exit 127; setup line 812)
port=4096
runner=proot
version=
pid=
__OC_SETUP_OUTPUT__
CANNOT LINK EXECUTABLE "curl": cannot locate symbol "SSL_set_quic_tls_transport_params"
'''
                  : '''phase=idle
message=No setup has been started
port=4096
runner=
version=
pid=
__OC_SETUP_OUTPUT__
''',
            );
          }
          return _commandResult();
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

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
          home: TermuxSetupScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.scrollUntilVisible(find.text('Install & start'), 250);
    await tester.pump();
    await tester.tap(find.text('Install & start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.textContaining('Repairing the Termux package set failed'),
      findsOneWidget,
    );
    expect(
      find.textContaining('SSL_set_quic_tls_transport_params'),
      findsWidgets,
    );
    expect(find.text('Retry — resumes where setup left off'), findsOneWidget);
  });
}
