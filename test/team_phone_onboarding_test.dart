// TEAM-302: the optional on-device AI Team step of the Termux setup and the
// Settings › Plugins › AI Team "On this phone" section, over a fake
// TermuxTeamRuntime whose phase sequence the test scripts.
//
// Covers: block absent without `supportsAiTeam`; present after step 3;
// Skip is primary and records the dismissal; the five steps follow the
// runtime's phases with the live output panel; the checksum refusal's own
// sentence; success writes the phone config onto the Termux profile and
// Workspace then carries the Team card; killed_by_android copy with Start
// again; Remove is two-step, drops the config and calls remove; the
// re-offer shows once from Settings; the unsupported copy; and the layout
// at 320 dp / 2.5x in LTR English and RTL Arabic.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:opencode_mobile/termux/team_runtime.dart';
import 'package:opencode_mobile/ui/screens/settings/plugins_screen.dart';
import 'package:opencode_mobile/ui/screens/termux_setup_screen.dart';
import 'package:opencode_mobile/ui/screens/workspace_screen.dart';
import 'package:opencode_mobile/ui/widgets/team_card.dart';
import 'package:opencode_mobile/ui/widgets/team_phone_onboarding.dart';
import 'package:opencode_mobile/ui/widgets/team_phone_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profileId = 'phone';

TeamRuntimeStatus _status(
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

const _versions = {'gc': '1.4.1', 'bd': '1.2.2', 'dolt': '2.3.3'};

TeamRuntimeStatus _ready({int agents = 1, bool killed = false}) => _status(
  TeamRuntimePhase.ready,
  installed: true,
  city: 'phone',
  project: '/root/projects/calc',
  agents: killed ? null : agents,
  health: killed ? null : 'ok',
  killed: killed,
  versions: _versions,
);

/// A scripted runtime: [current] is what `status` answers; each verb waits
/// on its gate (when set), then answers its scripted result and makes it
/// the current status.
class _FakeRuntime extends TermuxTeamRuntime {
  _FakeRuntime({this.supported = true, this.manifestJson})
    : super(
        runner: (_, {timeout = Duration.zero}) async => '',
        manifestLoader: () async => null,
        archProbe: () async => 'aarch64',
      );

  final bool supported;
  final String? manifestJson;
  TeamRuntimeStatus current = _status(TeamRuntimePhase.idle);
  String log = '';
  List<String> projects = const ['/root/projects/calc'];
  final calls = <String>[];
  final results = <String, TeamRuntimeStatus>{};
  final gates = <String, Completer<void>>{};
  Object? thrown;

  @override
  Future<bool> get supportsAiTeam async => supported;

  @override
  Future<TeamRuntimeManifest?> manifest() async =>
      manifestJson == null ? null : TeamRuntimeManifest.parse(manifestJson!);

  @override
  Future<TeamRuntimeStatus> status() async => current;

  @override
  Future<String> logTail({int lines = 200}) async => log;

  @override
  Future<List<String>> managedProjects() async => projects;

  @override
  Future<String> createManagedProject(String name) async {
    calls.add('create $name');
    return '/root/projects/$name';
  }

  Future<TeamRuntimeStatus> _verb(String verb) async {
    calls.add(verb);
    final error = thrown;
    if (error != null) {
      thrown = null;
      throw error;
    }
    final gate = gates[verb];
    if (gate != null) await gate.future;
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
  }) {
    calls.add('init:$projectPath');
    return _verb('init');
  }

  @override
  Future<TeamRuntimeStatus> start() => _verb('start');

  @override
  Future<TeamRuntimeStatus> stop() => _verb('stop');

  @override
  Future<TeamRuntimeStatus> remove() => _verb('remove');
}

/// A live v2 gateway that answers health, the event channels and an empty
/// session list, so the Workspace renders without a server.
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

/// Profiles in memory: no secure-storage channel in widget tests.
class _MemoryStore extends ProfileStore {
  _MemoryStore({required super.prefs, List<ServerProfile> seeded = const []})
    : saved = List.of(seeded);

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

ServerProfile _phoneProfile({OrchestrationConfig? config}) => ServerProfile(
  id: _profileId,
  name: 'My phone',
  baseUrl: TermuxBridge.managedServerUrl,
  password: 'phone-secret',
  flavor: ServerFlavor.v2,
  orchestration: config,
);

OrchestrationConfig _phoneConfig() => OrchestrationConfig(
  provider: OrchestrationProvider.gascity,
  url: TermuxBridge.aiteamSupervisorUrl,
  city: 'phone',
  hostMode: OrchestrationHostMode.phone,
  enabledAt: DateTime.utc(2026, 9, 11),
);

/// The Termux bridge as the setup screen sees a phone whose managed
/// OpenCode 2 server is ready: every command answers at once.
Future<Object?> _termux(MethodCall call) async {
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
      String stdout = '';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late _FakeRuntime runtime;
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    runtime = _FakeRuntime();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // The secure-storage channel answers (a real call to it never returns
    // in a widget test); the plugin's sweep deletes the reserved grant key.
    for (final channel in [
      'oc/background',
      'oc/shortcut',
      'plugins.it_nomads.com/flutter_secure_storage',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (call) async => call.method == 'readAll' ? <String, String>{} : null,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(MethodChannel(channel), null),
      );
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel('oc/termux'),
      _termux,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        const MethodChannel('oc/termux'),
        null,
      ),
    );
    debugTeamPhoneRuntime = runtime;
    addTearDown(() => debugTeamPhoneRuntime = null);
  });

  /// A connection over the fake v2 gateway, connected to [profile].
  Future<(ConnectionController, _MemoryStore)> connect(
    ServerProfile profile,
  ) async {
    final store = _MemoryStore(prefs: prefs, seeded: [profile]);
    final controller = ConnectionController(
      store,
      v2GatewayFactory: (_) => (gateway: _Gateway(), operations: _Operations()),
    );
    addTearDown(controller.dispose);
    await controller.connect(profile);
    return (controller, store);
  }

  Widget app(
    Widget home, {
    required ConnectionController controller,
    required ProfileStore store,
    Locale locale = const Locale('en'),
    double textScale = 1,
    bool rtl = false,
  }) => ProviderScope(
    overrides: [
      bootstrapProvider.overrideWithValue(AppBootstrap(store)),
      connProvider.overrideWithValue(controller),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        ),
      ),
      routes: {
        '/home': (_) => const Scaffold(body: Text('home')),
        '/termux-setup': (_) => const Scaffold(body: Text('setup')),
      },
      home: home,
    ),
  );

  /// Frames without waiting on timers: the fakes answer at once and the
  /// steps view's 2 s poll must not stall the test.
  Future<void> settle(WidgetTester tester, {int frames = 12}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> poll(WidgetTester tester) async {
    await tester.pump(teamPhonePollInterval);
    await settle(tester, frames: 3);
  }

  /// Scrolls the outer list until [finder] is built and on screen: the
  /// setup screen's list builds its children lazily, so a block below the
  /// fold has no element until the list reaches it.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty || finder.hitTestable().evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        120,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 120,
      );
      await tester.pump();
    }
    await tester.ensureVisible(finder);
    await settle(tester, frames: 2);
    expect(finder.hitTestable(), findsOneWidget);
  }

  Future<void> tapRevealed(WidgetTester tester, Finder finder) async {
    await reveal(tester, finder);
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> teardown(
    WidgetTester tester,
    ConnectionController controller,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await tester.pump();
  }

  Future<(ConnectionController, _MemoryStore)> pumpSetup(
    WidgetTester tester, {
    ServerProfile? profile,
    double textScale = 1,
    bool rtl = false,
    Locale locale = const Locale('en'),
  }) async {
    final (controller, store) = await connect(profile ?? _phoneProfile());
    await tester.pumpWidget(
      app(
        const TermuxSetupScreen(),
        controller: controller,
        store: store,
        textScale: textScale,
        rtl: rtl,
        locale: locale,
      ),
    );
    await settle(tester);
    return (controller, store);
  }

  group('onboarding block', () {
    testWidgets('absent when the runtime does not advertise support', (
      tester,
    ) async {
      runtime = _FakeRuntime(supported: false);
      debugTeamPhoneRuntime = runtime;
      final (controller, _) = await pumpSetup(tester);
      // Step 3 succeeded: the managed server is running and connected.
      expect(find.text(l10n.e7SetupRunningOnPhone), findsOneWidget);
      expect(find.byKey(const ValueKey('team-phone-offer')), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('team-phone-'),
        ),
        findsNothing,
      );
      await teardown(tester, controller);
    });

    testWidgets(
      'present after step 3 when supported, Skip primary, size from the manifest',
      (tester) async {
        runtime = _FakeRuntime(
          manifestJson:
              '{"schema":1,"arch":"arm64","files":{"gc":{"bytes":93716776},'
              '"bd":{"bytes":72941864},"dolt":{"bytes":126391984},'
              '"wrapper":{"bytes":1200}}}',
        );
        debugTeamPhoneRuntime = runtime;
        final (controller, _) = await pumpSetup(tester);
        final offer = find.byKey(const ValueKey('team-phone-offer'));
        await reveal(tester, offer);
        expect(find.text(l10n.teamUiPhoneOfferTitle), findsOneWidget);
        expect(find.text(l10n.teamUiPhoneOfferWarning), findsOneWidget);
        expect(find.text(l10n.teamUiPhoneOfferSize(294)), findsOneWidget);
        // Skip is the filled (primary) button; Set up is outlined.
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('team-phone-skip')),
            matching: find.text(l10n.teamUiPhoneSkip),
          ),
          findsOneWidget,
        );
        expect(
          tester.widget(find.byKey(const ValueKey('team-phone-skip'))),
          isA<FilledButton>(),
        );
        expect(
          tester.widget(find.byKey(const ValueKey('team-phone-set-up'))),
          isA<OutlinedButton>(),
        );
        await teardown(tester, controller);
      },
    );

    testWidgets('Skip records the dismissal and hides the block', (
      tester,
    ) async {
      final (controller, _) = await pumpSetup(tester);
      await tapRevealed(tester, find.byKey(const ValueKey('team-phone-skip')));
      expect(find.byKey(const ValueKey('team-phone-offer')), findsNothing);
      expect(
        prefs.getString(OrchestrationStore.phoneOfferKey(_profileId)),
        'skipped',
      );
      expect(
        controller.orchestrationStore.phoneOffer(_profileId),
        PhoneOffer.skipped,
      );
      // Re-entering the screen: the block stays away (Settings re-offers).
      await tester.pumpWidget(const SizedBox.shrink());
      final store = _MemoryStore(prefs: prefs, seeded: [_phoneProfile()]);
      await tester.pumpWidget(
        app(const TermuxSetupScreen(), controller: controller, store: store),
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('team-phone-offer')), findsNothing);
      await teardown(tester, controller);
    });

    testWidgets('the five steps follow the phases, with the live output panel', (
      tester,
    ) async {
      runtime.gates['install'] = Completer<void>();
      runtime.gates['init'] = Completer<void>();
      runtime.gates['start'] = Completer<void>();
      runtime.results['install'] = _status(
        TeamRuntimePhase.installed,
        installed: true,
        versions: _versions,
      );
      runtime.results['init'] = _status(
        TeamRuntimePhase.cityReady,
        installed: true,
        city: 'phone',
        project: '/root/projects/calc',
      );
      runtime.results['start'] = _ready(agents: 2);
      final (controller, store) = await pumpSetup(tester);
      await tapRevealed(
        tester,
        find.byKey(const ValueKey('team-phone-set-up')),
      );
      // One managed project: used without asking.
      expect(runtime.calls, ['install']);
      final steps = find.byKey(const ValueKey('team-phone-steps'));
      await reveal(tester, steps);
      expect(find.byKey(const ValueKey('setup-live-output')), findsOneWidget);
      expect(find.text(l10n.teamUiPhoneLeaveNote), findsOneWidget);
      expect(
        find.text(l10n.teamUiPhoneProjectLine('/root/projects/calc')),
        findsOneWidget,
      );
      for (final step in TeamPhoneStep.values) {
        expect(
          find.byKey(ValueKey('team-phone-step-${step.name}')),
          findsOneWidget,
        );
      }
      Map<TeamPhoneStep, TeamPhoneStepState> states() =>
          teamPhoneStepStates(runtime.current, connected: false);

      // Downloading: step 1 runs, the panel shows the script's lines.
      runtime.current = _status(
        TeamRuntimePhase.downloading,
        verb: 'install',
        busy: true,
      );
      runtime.log = '[aiteam] downloading gc-1.4.1-android-arm64\n';
      await poll(tester);
      expect(states()[TeamPhoneStep.download], TeamPhoneStepState.running);
      expect(
        find.textContaining('downloading gc-1.4.1-android-arm64'),
        findsOneWidget,
      );
      runtime.current = _status(
        TeamRuntimePhase.installingPackages,
        verb: 'install',
        busy: true,
      );
      await poll(tester);
      expect(states()[TeamPhoneStep.download], TeamPhoneStepState.done);
      expect(states()[TeamPhoneStep.packages], TeamPhoneStepState.running);

      runtime.gates['install']!.complete();
      await settle(tester);
      expect(runtime.calls, ['install', 'init:/root/projects/calc', 'init']);
      runtime.current = _status(
        TeamRuntimePhase.creatingCity,
        verb: 'init',
        busy: true,
        installed: true,
      );
      await poll(tester);
      expect(states()[TeamPhoneStep.packages], TeamPhoneStepState.done);
      expect(states()[TeamPhoneStep.city], TeamPhoneStepState.running);
      runtime.gates['init']!.complete();
      await settle(tester);
      expect(runtime.calls.last, 'start');
      runtime.current = _status(
        TeamRuntimePhase.starting,
        verb: 'start',
        busy: true,
        installed: true,
        city: 'phone',
      );
      await poll(tester);
      expect(states()[TeamPhoneStep.start], TeamPhoneStepState.running);
      runtime.gates['start']!.complete();
      await settle(tester);

      // Success: config written, card with the agent count.
      final success = find.byKey(const ValueKey('team-phone-success'));
      await reveal(tester, success);
      expect(
        find.text(
          '${l10n.teamUiPhoneSuccessTitle} · ${l10n.teamUiPhoneAgentsReady(2)}',
        ),
        findsOneWidget,
      );
      final saved = store.saved.single.orchestration;
      expect(saved, isNotNull);
      expect(saved!.hostMode, OrchestrationHostMode.phone);
      expect(saved.hostKind, OrchestrationHostKind.phone);
      expect(saved.url, TermuxBridge.aiteamSupervisorUrl);
      expect(saved.city, 'phone');
      expect(saved.front, isFalse);
      expect(controller.orchestration?.profileId, _profileId);
      await teardown(tester, controller);
    });

    testWidgets('a checksum mismatch gets its own sentence and Retry', (
      tester,
    ) async {
      runtime.results['install'] = _status(
        TeamRuntimePhase.failed,
        rawPhase: 'failed:checksum-mismatch gc',
        reason: 'checksum-mismatch gc',
        verb: 'install',
        lastError: 'gc: checksum mismatch',
      );
      runtime.log = '[aiteam] ERROR: gc: checksum mismatch\n';
      final (controller, store) = await pumpSetup(tester);
      await tapRevealed(
        tester,
        find.byKey(const ValueKey('team-phone-set-up')),
      );
      final failed = find.byKey(const ValueKey('team-phone-failed'));
      await reveal(tester, failed);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('team-phone-failed-reason')),
            )
            .data,
        l10n.teamUiPhoneFailedChecksum('gc'),
      );
      expect(
        teamPhoneStepStates(
          runtime.current,
          connected: false,
        )[TeamPhoneStep.download],
        TeamPhoneStepState.error,
      );
      expect(find.byKey(const ValueKey('setup-live-output')), findsOneWidget);
      expect(store.saved.single.orchestration, isNull);
      // Retry runs the install again.
      runtime.results['install'] = _status(
        TeamRuntimePhase.failed,
        rawPhase: 'failed:download',
        reason: 'download',
        verb: 'install',
      );
      await tapRevealed(tester, find.byKey(const ValueKey('team-phone-retry')));
      expect(runtime.calls, ['install', 'install']);
      expect(find.text(l10n.teamUiPhoneFailedDownload), findsOneWidget);
      await teardown(tester, controller);
    });

    testWidgets('failure copy per reason', (tester) async {
      String text(String reason, {String? error, String verb = 'start'}) =>
          teamPhoneFailureText(
            l10n,
            _status(
              TeamRuntimePhase.failed,
              rawPhase: 'failed:$reason',
              reason: reason,
              verb: verb,
              lastError: error,
            ),
          );
      expect(text('unsupported-arch'), l10n.teamUiPhoneFailedUnsupportedArch);
      expect(text('packages'), l10n.teamUiPhoneFailedPackages);
      expect(text('project-not-git'), l10n.teamUiPhoneFailedProject);
      expect(text('gc-init'), l10n.teamUiPhoneFailedCity);
      expect(text('supervisor-exited'), l10n.teamUiPhoneFailedSupervisorExited);
      expect(
        text('health-timeout'),
        l10n.teamUiPhoneFailedHealth(TermuxBridge.aiteamSupervisorUrl),
      );
      expect(text('interrupted'), l10n.teamUiPhoneFailedInterrupted);
      expect(
        text('', error: 'start stopped unexpectedly'),
        l10n.teamUiPhoneFailedInterrupted,
      );
      expect(
        text('something-new', error: 'odd'),
        l10n.teamUiPhoneFailedReason('odd'),
      );
    });

    testWidgets(
      'success writes the phone config and Workspace shows the Team card',
      (tester) async {
        runtime.results['install'] = _status(
          TeamRuntimePhase.installed,
          installed: true,
        );
        runtime.results['init'] = _status(
          TeamRuntimePhase.cityReady,
          installed: true,
          city: 'phone',
        );
        runtime.results['start'] = _ready(agents: 1);
        final (controller, store) = await pumpSetup(tester);
        await tapRevealed(
          tester,
          find.byKey(const ValueKey('team-phone-set-up')),
        );
        expect(
          find.text(
            '${l10n.teamUiPhoneSuccessTitle} · ${l10n.teamUiPhoneAgentsReady(1)}',
          ),
          findsOneWidget,
        );
        final profile = controller.profile!;
        expect(profile.orchestration?.hostMode, OrchestrationHostMode.phone);
        expect(controller.orchestration, isNotNull);
        // Open Workspace lands on the Workspace, where the card is present
        // for the Termux profile.
        await tapRevealed(
          tester,
          find.byKey(const ValueKey('team-phone-open-workspace')),
        );
        expect(find.text('home'), findsOneWidget);
        // A fresh tree: the navigator above still holds the /home route.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          app(
            WorkspaceScreen(controller: controller),
            controller: controller,
            store: store,
          ),
        );
        await settle(tester);
        expect(find.byType(TeamCard), findsOneWidget);
        expect(tester.takeException(), isNull);
        await teardown(tester, controller);
      },
    );

    testWidgets('re-entering resumes the view from the status file', (
      tester,
    ) async {
      runtime.current = _status(
        TeamRuntimePhase.installingPackages,
        verb: 'install',
        busy: true,
      );
      runtime.log = '[aiteam] Installing libicu git jq tmux\n';
      final (controller, _) = await pumpSetup(tester);
      final steps = find.byKey(const ValueKey('team-phone-steps'));
      await reveal(tester, steps);
      expect(find.byKey(const ValueKey('team-phone-offer')), findsNothing);
      expect(find.textContaining('Installing libicu'), findsOneWidget);
      // The verb finishes while the screen watches: Continue takes over.
      runtime.current = _status(
        TeamRuntimePhase.installed,
        installed: true,
        verb: 'install',
      );
      await poll(tester);
      final resume = find.byKey(const ValueKey('team-phone-continue'));
      await reveal(tester, resume);
      runtime.results['init'] = _status(
        TeamRuntimePhase.cityReady,
        installed: true,
        city: 'phone',
      );
      runtime.results['start'] = _ready();
      await tapRevealed(tester, resume);
      expect(runtime.calls, ['init:/root/projects/calc', 'init', 'start']);
      expect(find.byKey(const ValueKey('team-phone-success')), findsOneWidget);
      await teardown(tester, controller);
    });

    testWidgets('re-entering a failure shows its last output', (tester) async {
      runtime.current = _status(
        TeamRuntimePhase.failed,
        rawPhase: 'failed:init',
        reason: 'init',
        verb: 'init',
        installed: true,
      );
      runtime.log =
          '[aiteam] init started\n'
          'gc init: bead store: exec beads start: context deadline exceeded\n'
          '[aiteam] ERROR: gc init failed\n';
      final (controller, _) = await pumpSetup(tester);
      final steps = find.byKey(const ValueKey('team-phone-steps'));
      await reveal(tester, steps);
      expect(find.textContaining('context deadline exceeded'), findsOneWidget);
      await teardown(tester, controller);
    });

    testWidgets('a team that came up while away gets its config on entry', (
      tester,
    ) async {
      runtime.current = _ready(agents: 1);
      final (controller, store) = await pumpSetup(tester);
      await reveal(tester, find.byKey(const ValueKey('team-phone-success')));
      expect(
        store.saved.single.orchestration?.hostMode,
        OrchestrationHostMode.phone,
      );
      expect(controller.orchestration?.profileId, _profileId);
      expect(find.byKey(const ValueKey('team-phone-offer')), findsNothing);
      await teardown(tester, controller);
    });

    testWidgets('up but not answering reads as a failure, not a success', (
      tester,
    ) async {
      runtime.current = TeamRuntimeStatus(
        phase: TeamRuntimePhase.ready,
        rawPhase: 'ready',
        installed: true,
        city: 'phone',
        health: 'unreachable',
        supervisorPid: 4242,
        versions: _versions,
      );
      final (controller, store) = await pumpSetup(tester);
      await reveal(tester, find.byKey(const ValueKey('team-phone-failed')));
      expect(
        find.text(
          l10n.teamUiPhoneFailedHealth(TermuxBridge.aiteamSupervisorUrl),
        ),
        findsOneWidget,
      );
      expect(store.saved.single.orchestration, isNull);
      expect(
        teamPhoneStepStates(
          runtime.current,
          connected: false,
        )[TeamPhoneStep.start],
        TeamPhoneStepState.error,
      );
      expect(
        teamPhoneStatusLine(l10n, runtime.current),
        l10n.teamUiPhoneStatusUnreachable(TermuxBridge.aiteamSupervisorUrl),
      );
      await teardown(tester, controller);
    });

    testWidgets('killed by Android: the honest line and Start again', (
      tester,
    ) async {
      runtime.current = _ready(killed: true);
      final (controller, _) = await pumpSetup(
        tester,
        profile: _phoneProfile(config: _phoneConfig()),
      );
      final killed = find.byKey(const ValueKey('team-phone-killed'));
      await reveal(tester, killed);
      expect(find.text(l10n.teamUiPhoneKilled), findsOneWidget);
      runtime.results['start'] = _ready(agents: 1);
      await tapRevealed(
        tester,
        find.byKey(const ValueKey('team-phone-start-again')),
      );
      expect(runtime.calls, ['start']);
      expect(find.byKey(const ValueKey('team-phone-success')), findsOneWidget);
      await teardown(tester, controller);
    });

    testWidgets('no managed project: the sheet creates one', (tester) async {
      runtime.projects = const [];
      runtime.results['install'] = _status(
        TeamRuntimePhase.installed,
        installed: true,
      );
      runtime.results['init'] = _status(
        TeamRuntimePhase.cityReady,
        installed: true,
        city: 'phone',
      );
      runtime.results['start'] = _ready();
      final (controller, _) = await pumpSetup(tester);
      await tapRevealed(
        tester,
        find.byKey(const ValueKey('team-phone-set-up')),
      );
      expect(
        find.byKey(const ValueKey('team-phone-project-sheet')),
        findsOneWidget,
      );
      expect(runtime.calls, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('team-phone-new-folder')),
        'calc',
      );
      await tapRevealed(
        tester,
        find.byKey(const ValueKey('team-phone-create-folder')),
      );
      expect(runtime.calls, [
        'create calc',
        'install',
        'init:/root/projects/calc',
        'init',
        'start',
      ]);
      await teardown(tester, controller);
    });
  });

  group('Settings › Plugins › AI Team › On this phone', () {
    Future<(ConnectionController, _MemoryStore)> pumpPlugins(
      WidgetTester tester, {
      ServerProfile? profile,
      double textScale = 1,
      bool rtl = false,
      Locale locale = const Locale('en'),
    }) async {
      final (controller, store) = await connect(profile ?? _phoneProfile());
      await tester.pumpWidget(
        app(
          PluginsSettingsScreen(controller: controller, teamRuntime: runtime),
          controller: controller,
          store: store,
          textScale: textScale,
          rtl: rtl,
          locale: locale,
        ),
      );
      await settle(tester);
      return (controller, store);
    }

    Future<void> openSheet(WidgetTester tester) async {
      await tapRevealed(
        tester,
        find.byKey(const ValueKey('plugins-ai-team-row')),
      );
      expect(find.byKey(const ValueKey('team-phone-section')), findsOneWidget);
    }

    String statusLine(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const ValueKey('team-phone-status')))
        .data!;

    testWidgets('running: versions, agents, Stop is two-step', (tester) async {
      runtime.current = _ready(agents: 2);
      final (controller, _) = await pumpPlugins(
        tester,
        profile: _phoneProfile(config: _phoneConfig()),
      );
      await openSheet(tester);
      expect(statusLine(tester), l10n.teamUiPhoneStatusRunning(2));
      expect(
        find.text(l10n.teamUiPhoneVersions('1.4.1', '1.2.2', '2.3.3')),
        findsOneWidget,
      );
      runtime.results['stop'] = _status(
        TeamRuntimePhase.stopped,
        installed: true,
        city: 'phone',
        versions: _versions,
      );
      await tapRevealed(tester, find.byKey(const ValueKey('team-phone-stop')));
      expect(runtime.calls, isEmpty, reason: 'first tap only asks');
      expect(
        find.byKey(const ValueKey('team-phone-stop-sheet')),
        findsOneWidget,
      );
      await tapRevealed(
        tester,
        find.byKey(const ValueKey('team-phone-stop-confirm')),
      );
      expect(runtime.calls, ['stop']);
      expect(statusLine(tester), l10n.teamUiPhoneStatusStopped);
      // Stopped: Start is one tap and writes the config when it was gone.
      await tapRevealed(tester, find.byKey(const ValueKey('team-phone-start')));
      expect(runtime.calls, ['stop', 'start']);
      await teardown(tester, controller);
    });

    testWidgets('killed by Android: copy and Start again calls start', (
      tester,
    ) async {
      runtime.current = _ready(killed: true);
      final (controller, store) = await pumpPlugins(
        tester,
        profile: _phoneProfile(config: _phoneConfig()),
      );
      await openSheet(tester);
      expect(statusLine(tester), l10n.teamUiPhoneStatusStopped);
      expect(find.text(l10n.teamUiPhoneKilled), findsOneWidget);
      runtime.results['start'] = _ready(agents: 1);
      await tapRevealed(
        tester,
        find.byKey(const ValueKey('team-phone-start-again')),
      );
      expect(runtime.calls, ['start']);
      expect(statusLine(tester), l10n.teamUiPhoneStatusRunning(1));
      expect(
        store.saved.single.orchestration?.hostMode,
        OrchestrationHostMode.phone,
      );
      await teardown(tester, controller);
    });

    testWidgets('Keep it running opens the tips with the ADB steps', (
      tester,
    ) async {
      runtime.current = _ready();
      final (controller, _) = await pumpPlugins(
        tester,
        profile: _phoneProfile(config: _phoneConfig()),
      );
      await openSheet(tester);
      await tapRevealed(
        tester,
        find.byKey(const ValueKey('team-phone-keep-running')),
      );
      expect(
        find.byKey(const ValueKey('team-phone-tips-sheet')),
        findsOneWidget,
      );
      expect(find.text(l10n.teamUiPhoneTipWakeLock), findsOneWidget);
      expect(find.text(l10n.teamUiPhoneTipBattery), findsOneWidget);
      expect(find.text(l10n.teamUiPhoneTipPhantom), findsOneWidget);
      final commands = tester.widget<SelectableText>(
        find.byKey(const ValueKey('team-phone-tips-commands')),
      );
      expect(commands.textDirection, TextDirection.ltr);
      expect(
        commands.data,
        contains(
          'adb shell settings put global settings_enable_monitor_phantom_procs false',
        ),
      );
      expect(
        commands.data,
        contains(
          'adb shell device_config put activity_manager max_phantom_processes 2147483647',
        ),
      );
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tapRevealed(
        tester,
        find.byKey(const ValueKey('team-phone-tips-copy')),
      );
      expect(copied, teamPhoneAdbCommands);
      await teardown(tester, controller);
    });

    testWidgets(
      'Remove is two-step, calls remove, drops the config and the offer',
      (tester) async {
        runtime.current = _ready();
        final (controller, store) = await pumpPlugins(
          tester,
          profile: _phoneProfile(config: _phoneConfig()),
        );
        await openSheet(tester);
        final remove = find.byKey(const ValueKey('team-phone-remove'));
        await tapRevealed(tester, remove);
        expect(runtime.calls, isEmpty, reason: 'first tap only asks');
        expect(
          find.byKey(const ValueKey('team-phone-remove-sheet')),
          findsOneWidget,
        );
        expect(find.text(l10n.teamUiPhoneRemoveBody), findsOneWidget);
        runtime.results['remove'] = _status(TeamRuntimePhase.idle);
        await tapRevealed(
          tester,
          find.byKey(const ValueKey('team-phone-remove-confirm')),
        );
        expect(runtime.calls, ['remove']);
        expect(store.saved.single.orchestration, isNull);
        expect(controller.orchestration, isNull);
        expect(
          controller.orchestrationStore.phoneOffer(_profileId),
          PhoneOffer.dismissed,
        );
        // The sheet closed with the removal.
        expect(find.byKey(const ValueKey('team-plugin-sheet')), findsNothing);
        await teardown(tester, controller);
      },
    );

    testWidgets('not available copy when the runtime is unsupported', (
      tester,
    ) async {
      runtime = _FakeRuntime(supported: false);
      debugTeamPhoneRuntime = runtime;
      final (controller, _) = await pumpPlugins(tester);
      expect(find.byKey(const ValueKey('plugins-phone-offer')), findsNothing);
      await openSheet(tester);
      expect(find.text(l10n.teamUiPhoneNotAvailable), findsOneWidget);
      expect(find.byKey(const ValueKey('team-phone-status')), findsNothing);
      await teardown(tester, controller);
    });

    testWidgets('re-offer shows once after Skip and Not now ends it', (
      tester,
    ) async {
      await prefs.setString(
        OrchestrationStore.phoneOfferKey(_profileId),
        'skipped',
      );
      final (controller, _) = await pumpPlugins(tester);
      final offer = find.byKey(const ValueKey('plugins-phone-offer'));
      expect(offer, findsOneWidget);
      expect(find.text(l10n.teamUiPhoneReofferTitle), findsOneWidget);
      await tapRevealed(
        tester,
        find.byKey(const ValueKey('plugins-phone-offer-dismiss')),
      );
      expect(offer, findsNothing);
      expect(
        prefs.getString(OrchestrationStore.phoneOfferKey(_profileId)),
        'dismissed',
      );
      await teardown(tester, controller);
    });

    testWidgets('re-offer absent when never skipped or already on', (
      tester,
    ) async {
      final (controller, _) = await pumpPlugins(tester);
      expect(find.byKey(const ValueKey('plugins-phone-offer')), findsNothing);
      await teardown(tester, controller);
      await prefs.setString(
        OrchestrationStore.phoneOfferKey(_profileId),
        'skipped',
      );
      final (second, _) = await pumpPlugins(
        tester,
        profile: _phoneProfile(config: _phoneConfig()),
      );
      expect(find.byKey(const ValueKey('plugins-phone-offer')), findsNothing);
      await teardown(tester, second);
    });

    testWidgets('re-offer Set up opens the phone setup', (tester) async {
      await prefs.setString(
        OrchestrationStore.phoneOfferKey(_profileId),
        'skipped',
      );
      final (controller, _) = await pumpPlugins(tester);
      await tapRevealed(
        tester,
        find.byKey(const ValueKey('plugins-phone-offer-set-up')),
      );
      expect(find.text('setup'), findsOneWidget);
      await teardown(tester, controller);
    });

    testWidgets('not installed: the sheet points at the phone setup', (
      tester,
    ) async {
      final (controller, _) = await pumpPlugins(tester);
      await openSheet(tester);
      expect(statusLine(tester), l10n.teamUiPhoneStatusNotInstalled);
      expect(find.byKey(const ValueKey('team-phone-remove')), findsNothing);
      await tapRevealed(
        tester,
        find.byKey(const ValueKey('team-phone-open-setup')),
      );
      expect(find.text('setup'), findsOneWidget);
      await teardown(tester, controller);
    });
  });

  group('layout at 320dp and 2.5x', () {
    for (final rtl in [false, true]) {
      final locale = Locale(rtl ? 'ar' : 'en');
      final label = rtl ? 'RTL ar' : 'LTR en';

      testWidgets('offer, steps and success in the setup screen · $label', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        runtime.gates['install'] = Completer<void>();
        runtime.results['install'] = _status(
          TeamRuntimePhase.installed,
          installed: true,
        );
        runtime.results['init'] = _status(
          TeamRuntimePhase.cityReady,
          installed: true,
          city: 'phone',
        );
        runtime.results['start'] = _ready(agents: 3);
        final (controller, _) = await pumpSetup(
          tester,
          textScale: 2.5,
          rtl: rtl,
          locale: locale,
        );
        expect(tester.takeException(), isNull);
        // The card is taller than the screen at 2.5x: its controls are what
        // must be reachable.
        await reveal(tester, find.byKey(const ValueKey('team-phone-skip')));
        await tapRevealed(
          tester,
          find.byKey(const ValueKey('team-phone-set-up')),
        );
        runtime.current = _status(
          TeamRuntimePhase.downloading,
          verb: 'install',
          busy: true,
        );
        runtime.log = '[aiteam] downloading gc-1.4.1-android-arm64\n';
        await poll(tester);
        expect(tester.takeException(), isNull);
        await reveal(
          tester,
          find.byKey(const ValueKey('team-phone-step-download')),
        );
        await reveal(
          tester,
          find.byKey(const ValueKey('team-phone-step-connect')),
        );
        // The live output stays LTR in RTL.
        final output = tester.widget<SelectableText>(
          find.descendant(
            of: find.byKey(const ValueKey('setup-live-output')),
            matching: find.byType(SelectableText),
          ),
        );
        expect(output.textDirection, TextDirection.ltr);
        runtime.gates['install']!.complete();
        await settle(tester);
        expect(tester.takeException(), isNull);
        await reveal(
          tester,
          find.byKey(const ValueKey('team-phone-open-workspace')),
        );
        await teardown(tester, controller);
      });

      testWidgets('On this phone section and tips · $label', (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        runtime.current = _ready(killed: true);
        final (controller, store) = await connect(
          _phoneProfile(config: _phoneConfig()),
        );
        await tester.pumpWidget(
          app(
            PluginsSettingsScreen(controller: controller, teamRuntime: runtime),
            controller: controller,
            store: store,
            textScale: 2.5,
            rtl: rtl,
            locale: locale,
          ),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
        await tapRevealed(
          tester,
          find.byKey(const ValueKey('plugins-ai-team-row')),
        );
        expect(tester.takeException(), isNull);
        await reveal(tester, find.byKey(const ValueKey('team-phone-status')));
        await reveal(
          tester,
          find.byKey(const ValueKey('team-phone-start-again')),
        );
        await reveal(tester, find.byKey(const ValueKey('team-phone-remove')));
        await tapRevealed(
          tester,
          find.byKey(const ValueKey('team-phone-keep-running')),
        );
        expect(tester.takeException(), isNull);
        final commands = tester.widget<SelectableText>(
          find.byKey(const ValueKey('team-phone-tips-commands')),
        );
        expect(commands.textDirection, TextDirection.ltr);
        await reveal(
          tester,
          find.byKey(const ValueKey('team-phone-tips-copy')),
        );
        await teardown(tester, controller);
      });
    }
  });
}
