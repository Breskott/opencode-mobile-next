// Golden renders of slice-P1.7, AI Team on the phone through phone setup
// v2: the intro's "Set up AI Team on this phone" on a Termux phone, the
// pre-flight that tells a 32-bit phone why (never hidden), the ready page
// turning the team on, ready with "Give the team a first task" and failed,
// the team page's "Android stopped the team" line, This phone's Installed
// list for Termux, the start screen leading with a stopped Termux job, and
// a failed setup row with "Report this failure" (P8.4). Light, the app's
// real fonts, DPR 1; phone (412x915) and a wide window (1280x800).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/team_phone_v2_golden_test.dart
// and look at every changed image before committing it.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/setup/phone_setup.dart';
import 'package:opencode_mobile/builtin/setup/setup_contract.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/orchestration.dart' show TeamLastKnown;
import 'package:opencode_mobile/state/orchestration_store.dart'
    show OrchestrationStore;
import 'package:opencode_mobile/state/phone_host.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:opencode_mobile/termux/team_runtime.dart';
import 'package:opencode_mobile/ui/kit/kit.dart' show KitRow;
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_intro_screen.dart';
import 'package:opencode_mobile/ui/screens/this_phone_screen.dart';
import 'package:opencode_mobile/ui/widgets/setup_progress_view.dart';
import 'package:opencode_mobile/ui/widgets/team_phone_onboarding.dart';
import 'package:opencode_mobile/voice/device.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;
import '../support/fake_setup_engine.dart';
import '../support/termux_channel_fixture.dart';
import 'screen_phone_1_fixtures.dart';

/// The in-app registry plus AI Team and voice typing, as a host lists it.
const _registry = [
  ...FakeSetupEngine.fakeRegistry,
  SetupComponent(
    id: 'aiteam',
    title: 'AI Team',
    shortTitle: 'AI Team',
    checkScript: 'true',
    installScript: 'true',
    dependsOn: ['essentials', 'opencode'],
    estimatedSeconds: 150,
    downloadBytes: 112000000,
  ),
  SetupComponent(
    id: 'voice',
    title: 'Voice typing',
    shortTitle: 'Voice typing',
    checkScript: '',
    installScript: '',
    estimatedSeconds: 45,
    downloadBytes: 150000000,
  ),
];

ServerProfile _termuxProfile({OrchestrationConfig? config}) => ServerProfile(
  id: 'termux',
  name: 'This phone',
  baseUrl: TermuxBridge.managedServerUrl,
  password: 'synthetic-test-secret',
  serverVersion: '1.18.32',
  orchestration: config,
);

TeamRuntimeStatus _status(
  TeamRuntimePhase phase, {
  String reason = '',
  bool killed = false,
}) => TeamRuntimeStatus(
  phase: phase,
  rawPhase: phase.name,
  reason: reason.isEmpty ? null : reason,
  installed: true,
  city: 'phone',
  project: '/root/projects/calc',
  agents: phase == TeamRuntimePhase.ready && !killed ? 2 : null,
  health: phase == TeamRuntimePhase.ready && !killed ? 'ok' : null,
  killedByAndroid: killed,
);

/// A Termux team whose verbs answer as scripted; `start` may wait.
class _Runtime extends TermuxTeamRuntime {
  _Runtime()
    : super(
        runner: (_, {timeout = Duration.zero}) async => '',
        manifestLoader: () async => null,
        archProbe: () async => 'aarch64',
      );

  TeamRuntimeStatus current = _status(TeamRuntimePhase.idle);
  TeamRuntimeStatus? initResult;
  Completer<void>? startGate;

  @override
  Future<bool> get supportsAiTeam async => true;

  @override
  Future<TeamRuntimeStatus> status() async => current;

  @override
  Future<TeamRuntimeStatus> install({String? manifestUrl}) async =>
      _status(TeamRuntimePhase.installed);

  @override
  Future<TeamRuntimeStatus> init(
    String projectPath, {
    String? city,
    String? rig,
  }) async => initResult ?? _status(TeamRuntimePhase.cityReady);

  @override
  Future<TeamRuntimeStatus> start() async {
    await startGate?.future;
    return _status(TeamRuntimePhase.ready);
  }
}

class _Store extends ProfileStore {
  _Store({required super.prefs, required this.saved});

  final List<ServerProfile> saved;
  String? _active;

  @override
  List<ServerProfile> get profiles => List.unmodifiable(saved);

  @override
  String? get activeId => _active;

  @override
  Future<void> setActiveId(String? id) async => _active = id;

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

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A connection that has [profile] as its connected server.
Future<ConnectionController> _connection(
  ServerProfile profile, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = _Store(
    prefs: await SharedPreferences.getInstance(),
    saved: [profile],
  );
  await store.setActiveId(profile.id);
  final controller = ConnectionController(store)
    ..directory = '/root/projects/calc';
  controller.adoptConnectedProfileForTesting(profile);
  controller.syncOrchestration();
  return controller;
}

Future<void> _shot(
  WidgetTester tester,
  String name, {
  required ConnectionController controller,
  required Widget Function(BuildContext context) home,
  Size size = phoneSize,
  Future<void> Function()? act,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  debugDefaultTargetPlatformOverride = TargetPlatform.android; // ARCH-11
  try {
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ProviderScope(
          overrides: [
            bootstrapProvider.overrideWithValue(AppBootstrap(controller.store)),
            connProvider.overrideWithValue(controller),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: captureTheme(light: true),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Builder(builder: home),
          ),
        ),
      ),
    );
    await _settle(tester);
    if (act != null) await act();
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/$name.png'),
    );
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
  await tester.pumpWidget(const SizedBox.shrink());
}

String _suffix(Size size) => size == phoneSize ? '' : '_1280x800';

void main() {
  setUpAll(loadCaptureFonts);
  late _Runtime runtime;

  setUp(() {
    debugPlatformCapabilities = const PlatformCapabilities.android();
    runtime = _Runtime();
    debugTeamPhoneRuntime = runtime;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'plugins.it_nomads.com/flutter_secure_storage',
      'oc/background',
      'oc/shortcut',
      'oc/voice',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (call) async => call.method == 'readAll' ? <String, String>{} : null,
      );
    }
  });
  tearDown(() {
    debugPlatformCapabilities = null;
    debugTeamPhoneRuntime = null;
  });

  for (final size in [phoneSize, wideSize]) {
    testWidgets('intro on a Termux phone ($size)', (tester) async {
      final controller = await _connection(_termuxProfile());
      addTearDown(controller.dispose);
      await _shot(
        tester,
        'team_v2_intro_termux${_suffix(size)}_light',
        size: size,
        controller: controller,
        home: (_) => TeamIntroScreen(
          controller: controller,
          runtime: runtime,
          deviceProbe: () async => okDevice,
        ),
      );
    });
  }

  testWidgets('intro: a 32-bit phone is told why', (tester) async {
    final controller = await _connection(_termuxProfile());
    addTearDown(controller.dispose);
    await _shot(
      tester,
      'team_v2_intro_preflight_light',
      controller: controller,
      home: (_) => TeamIntroScreen(
        controller: controller,
        runtime: runtime,
        deviceProbe: () async => const VoiceDeviceInfo(
          availableStorageBytes: 20000000000,
          memoryClassMb: 256,
          totalMemoryMb: 3072,
          supportedAbis: ['armeabi-v7a', 'armeabi'],
          hasMicrophone: true,
        ),
      ),
      act: () async {
        final notice = find.byKey(const ValueKey('team-intro-on-computer'));
        await tester.scrollUntilVisible(
          notice,
          200,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('team-intro')),
            matching: find.byType(Scrollable),
          ),
        );
      },
    );
  });

  for (final size in [phoneSize, wideSize]) {
    testWidgets('ready page turning on ($size)', (tester) async {
      runtime.startGate = Completer<void>();
      final controller = await _connection(_termuxProfile());
      addTearDown(controller.dispose);
      await _shot(
        tester,
        'team_v2_ready_turning_on${_suffix(size)}_light',
        size: size,
        controller: controller,
        home: (_) => TeamPhoneReadyScreen(
          connection: controller,
          host: SetupHostKind.termux,
          runtime: runtime,
        ),
      );
      runtime.startGate!.complete();
      await _settle(tester);
    });

    testWidgets('ready page, ready ($size)', (tester) async {
      final controller = await _connection(_termuxProfile());
      addTearDown(controller.dispose);
      await _shot(
        tester,
        'team_v2_ready_done${_suffix(size)}_light',
        size: size,
        controller: controller,
        home: (_) => TeamPhoneReadyScreen(
          connection: controller,
          host: SetupHostKind.termux,
          runtime: runtime,
        ),
      );
    });
  }

  testWidgets('ready page, failed', (tester) async {
    runtime.initResult = _status(
      TeamRuntimePhase.failed,
      reason: 'project-not-git',
    );
    final controller = await _connection(_termuxProfile());
    addTearDown(controller.dispose);
    await _shot(
      tester,
      'team_v2_ready_failed_light',
      controller: controller,
      home: (_) => TeamPhoneReadyScreen(
        connection: controller,
        host: SetupHostKind.termux,
        runtime: runtime,
      ),
    );
  });

  testWidgets('team page: Android stopped the phone team', (tester) async {
    runtime.current = _status(TeamRuntimePhase.ready, killed: true);
    // What the app read before Android stopped the team (slice-polish
    // 2026-09-28): kept on the device, shown dimmed and "as of" under the
    // stopped line.
    final lastKnown = TeamLastKnown(
      asOf: DateTime(2026, 9, 27, 10, 42),
      runs: const [
        OrchestrationRun(
          id: 'r1',
          title: 'Fix the checkout total',
          state: RunState.working,
        ),
        OrchestrationRun(
          id: 'r2',
          title: 'Add a test for an expired coupon',
          state: RunState.waiting,
        ),
        OrchestrationRun(
          id: 'r3',
          title: 'Update the changelog',
          state: RunState.completed,
        ),
      ],
      agents: const [
        OrchestrationAgent(
          id: 'a1',
          name: 'calc/polecat-1',
          pool: 'polecat',
          state: AgentState.working,
        ),
        OrchestrationAgent(
          id: 'a2',
          name: 'calc/refinery',
          pool: 'refinery',
          state: AgentState.idle,
        ),
      ],
    );
    final controller = await _connection(
      prefs: {
        OrchestrationStore.lastKnownKey('termux'): jsonEncode(
          lastKnown.toJson(),
        ),
      },
      _termuxProfile(
        config: OrchestrationConfig(
          provider: OrchestrationProvider.gascity,
          url: TermuxBridge.aiteamSupervisorUrl,
          city: 'phone',
          hostMode: OrchestrationHostMode.phone,
          hostKind: OrchestrationHostKind.phone,
          enabledAt: DateTime.utc(2026, 9, 27),
        ),
      ),
    );
    addTearDown(controller.dispose);
    await _shot(
      tester,
      'team_v2_team_home_killed_light',
      controller: controller,
      home: (_) => TeamHomeScreen(
        controller: controller.orchestration!,
        now: () => DateTime.utc(2026, 9, 27, 12),
      ),
      act: () async {
        // The last-known team is under the stopped line, dimmed, with when
        // it was read; nothing on it acts, and Start a task says why.
        expect(find.byKey(const ValueKey('team-phone-killed')), findsWidgets);
        expect(find.text('Fix the checkout total'), findsOneWidget);
        expect(find.text('Update the changelog'), findsOneWidget);
        expect(find.textContaining('Tasks as of'), findsOneWidget);
        expect(find.textContaining('Agents as of'), findsOneWidget);
        final row = tester.widget<KitRow>(
          find.byKey(const ValueKey('team-home-last-known-run-r1')),
        );
        expect(row.enabled, isFalse);
        expect(row.onTap, isNull);
        expect(
          find.text('Start the team again to give it a task or open one.'),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('This phone in Termux lists what is installed', (tester) async {
    TermuxChannelFixture()
      ..inventoryOutput =
          'ubuntu=installed\nversion=1.18.32\nruntime=opencode1\n'
      ..statusOutput = termuxSnapshot(phase: 'ready', version: '1.18.32')
      ..install();
    final termux = FakeSetupEngine(registry: _registry)
      ..optionalInstalled = {'python', 'aiteam', 'voice'};
    PhoneSetup.termux = termux;
    final boundary = GlobalKey();
    debugDefaultTargetPlatformOverride = TargetPlatform.android; // ARCH-11
    try {
      await pumpPhone(
        tester,
        home: const ThisPhoneScreen(kind: PhoneHostKind.termux),
        light: true,
        boundary: boundary,
        profiles: [_termuxProfile()],
      );
      final header = find.byKey(const ValueKey('this-phone-installed-header'));
      await tester.ensureVisible(header);
      await _settle(tester);
      await tester.tap(header);
      await _settle(tester);
      await tester.ensureVisible(header);
      await _settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/team_v2_this_phone_installed_light.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      await unmountPhone(tester);
    }
  });

  for (final size in [phoneSize, wideSize]) {
    testWidgets('start screen leads with a stopped Termux job ($size)', (
      tester,
    ) async {
      final termux = FakeSetupEngine(registry: _registry)
        ..emit(
          const SetupProgress(
            state: SetupState.interrupted,
            jobId: 'termux-1',
            overall: .62,
            firstSetup: true,
            components: [
              ComponentProgress(id: 'linux', state: ComponentState.done),
              ComponentProgress(id: 'essentials', state: ComponentState.done),
              ComponentProgress(id: 'node', state: ComponentState.done),
              ComponentProgress(id: 'opencode', state: ComponentState.pending),
            ],
          ),
        );
      PhoneSetup.termux = termux;
      final boundary = GlobalKey();
      debugDefaultTargetPlatformOverride = TargetPlatform.android; // ARCH-11
      try {
        await pumpPhone(
          tester,
          home: startScreen(),
          size: size,
          light: true,
          boundary: boundary,
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(boundary),
          matchesGoldenFile(
            'goldens/team_v2_start_termux_job${_suffix(size)}_light.png',
          ),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
        await unmountPhone(tester);
      }
    });
  }

  testWidgets('a failed setup row offers Report this failure', (tester) async {
    final controller = await _connection(_termuxProfile());
    addTearDown(controller.dispose);
    await _shot(
      tester,
      'team_v2_setup_failed_report_light',
      controller: controller,
      home: (_) => Scaffold(
        body: SingleChildScrollView(
          child: SetupProgressView(
            progress: const SetupProgress(
              state: SetupState.failed,
              jobId: 'job-1',
              overall: .7,
              current: 'aiteam',
              adding: ['aiteam'],
              logTail:
                  'Downloading AI Team · 2 of 3\ncurl: (6) Could not '
                  'resolve host: github.com',
              components: [
                ComponentProgress(
                  id: 'aiteam',
                  state: ComponentState.failed,
                  error: 'curl: (6) Could not resolve host: github.com',
                ),
              ],
            ),
            components: _registry,
            title: 'Adding AI Team',
            onContinue: () {},
          ),
        ),
      ),
    );
  });
}
