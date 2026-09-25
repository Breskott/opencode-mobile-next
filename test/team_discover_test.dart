// Finding the AI Team while it is off (docs/qa/team-discover-2026-09-25):
// the Work tab's entry and its folded row, the intro and where its one
// primary action leads for each kind of server, Settings' AI Team row, the
// empty home's drawing and the merged celebration's length; New
// conversation's Solo · Team and the team's tasks in the Work tab's lists
// (docs/design/team-conversation-2026-09-26.md).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/setup/components.dart';
import 'package:opencode_mobile/builtin/setup/phone_setup.dart';
import 'package:opencode_mobile/builtin/setup/setup_contract.dart';
import 'package:opencode_mobile/builtin/team/builtin_team.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/fixture_gateway.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/team_runtime.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/settings/plugins_screen.dart';
import 'package:opencode_mobile/ui/screens/settings_screen.dart';
import 'package:opencode_mobile/ui/screens/team/run_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_intro_screen.dart';
import 'package:opencode_mobile/ui/screens/workspace_screen.dart';
import 'package:opencode_mobile/ui/widgets/builtin_team_section.dart';
import 'package:opencode_mobile/ui/widgets/team_discover.dart';
import 'package:opencode_mobile/ui/widgets/team_host_form.dart';
import 'package:opencode_mobile/ui/widgets/team_moments.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_setup_engine.dart';
import 'support/team_golden_fixture.dart';
import 'support/work_tab_fixture.dart';

final _en = lookupAppLocalizations(const Locale('en'));

Finder _key(String key) => find.byKey(ValueKey(key));

/// A scripted Gas City probe: answers [found] for every address, or
/// unreachable.
class _Probe {
  ProbeFound? found;
  final calls = <String>[];

  Future<ProbeVerdict> call(String url, {String? city}) async {
    calls.add(url);
    return found ?? const ProbeUnreachable(error: 'no answer');
  }
}

ProbeFound _found() => const ProbeFound(
  host: OrchestrationHostIdentity(
    provider: 'gascity',
    url: 'http://100.100.1.2:8372',
    hostMode: OrchestrationHostMode.computer,
    version: '1.4.1',
    city: 'bright-lights',
  ),
  version: '1.4.1',
  city: 'bright-lights',
  readOnly: true,
);

/// A Termux team runtime that answers whether this phone can run a team.
class _Runtime extends TermuxTeamRuntime {
  _Runtime({required this.supported})
    : super(
        runner: (_, {timeout = Duration.zero}) async => '',
        manifestLoader: () async => null,
        archProbe: () async => 'aarch64',
      );

  final bool supported;

  @override
  Future<bool> get supportsAiTeam async => supported;

  @override
  Future<TeamRuntimeManifest?> manifest() async => null;

  @override
  Future<TeamRuntimeStatus> status() async =>
      const TeamRuntimeStatus(phase: TeamRuntimePhase.idle);
}

/// The in-app team, not installed; nothing reaches the phone's Linux.
class _BuiltinTeam extends BuiltinTeam {
  @override
  Future<BuiltinTeamState> status() async => const BuiltinTeamState();
}

void _mockChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in [
    'plugins.it_nomads.com/flutter_secure_storage',
    'oc/background',
    'oc/shortcut',
  ]) {
    messenger.setMockMethodCallHandler(
      MethodChannel(channel),
      (call) async => call.method == 'readAll' ? <String, String>{} : null,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(MethodChannel(channel), null),
    );
  }
}

/// A controller on one saved server, as the app has it after connecting.
Future<ConnectionController> _boot(ServerProfile profile) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = ProfileStore(prefs: prefs);
  await store.upsert(profile);
  await store.setActiveId(profile.id);
  final controller = ConnectionController(store);
  addTearDown(controller.dispose);
  controller.adoptConnectedProfileForTesting(profile);
  controller.syncOrchestration();
  return controller;
}

ServerProfile _computer() => ServerProfile(
  id: 'workstation',
  name: 'Workstation',
  baseUrl: 'http://100.100.1.2:4096',
);

ServerProfile _termux() => ServerProfile(
  id: 'termux',
  name: 'This device (Termux)',
  baseUrl: 'http://127.0.0.1:4096',
);

ServerProfile _inApp() => ServerProfile(
  id: 'in-app',
  name: 'This phone',
  baseUrl: 'http://127.0.0.1:4097',
);

Widget _app(Widget home, {Map<String, WidgetBuilder> routes = const {}}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routes: routes,
      home: home,
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

String _fixturePath() {
  var dir = Directory.current;
  for (var i = 0; i < 5; i++) {
    final candidate = Directory('${dir.path}/tool/qa/gascity_fixture');
    if (candidate.existsSync()) return candidate.path;
    dir = dir.parent;
  }
  throw StateError('tool/qa/gascity_fixture not found');
}

/// The recorded Gas City fixture as the Work tab's team.
Future<OrchestrationController> _fixtureTeam() async {
  final prefs = await SharedPreferences.getInstance();
  final config = OrchestrationConfig(
    provider: OrchestrationProvider.fixture,
    url: _fixturePath(),
    city: 'bright-lights',
    hostMode: OrchestrationHostMode.computer,
    enabledAt: DateTime.utc(2026, 9, 10),
  );
  final team = OrchestrationController(
    profile: ServerProfile(
      id: 'phone',
      name: 'pop-os',
      baseUrl: 'http://100.100.1.2:4096',
      orchestration: config,
    ),
    config: config,
    store: OrchestrationStore(prefs),
    gatewayFactory: (_, _) => FixtureOrchestrationGateway(
      fixturePath: _fixturePath(),
      hostMode: OrchestrationHostMode.computer,
    ),
  );
  await team.start();
  return team;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Probe probe;

  setUp(() {
    probe = _Probe();
    teamHostProbe = probe.call;
  });
  tearDown(() {
    teamHostProbe = defaultTeamHostProbe;
    debugPlatformCapabilities = null;
    debugBuiltinTeam = null;
  });

  group('the Work tab', () {
    Future<WorkController> pumpWork(WidgetTester tester) async {
      _tallScreen(tester);
      _mockChannels();
      // A computer: the tests' platform is Android, where the fixture's
      // 127.0.0.1:4096 would be the Termux server.
      final controller = await workController(
        name: 'pop-os',
        baseUrl: 'http://100.100.1.2:4096',
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(Scaffold(body: WorkspaceScreen(controller: controller))),
      );
      await _settle(tester);
      return controller;
    }

    testWidgets('shows the AI Team while it is off, below the work', (
      tester,
    ) async {
      await pumpWork(tester);
      final entry = _key('team-discover-open');
      expect(entry, findsOneWidget);
      expect(find.text(_en.teamDiscoverEntryTitle), findsOneWidget);
      expect(find.text(_en.teamDiscoverEntryBody), findsOneWidget);
      expect(_key('team-discover-drawing'), findsOneWidget);
      // After the person's own list, never above it.
      final recent = find.text(_en.e7WorkspaceRecentSessions);
      expect(
        tester.getTopLeft(entry).dy,
        greaterThan(tester.getTopLeft(recent).dy),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('hiding it folds it to one quiet row that stays folded', (
      tester,
    ) async {
      final controller = await pumpWork(tester);
      await tester.tap(_key('team-discover-hide'));
      await _settle(tester);
      expect(_key('team-discover-open'), findsNothing);
      expect(_key('team-discover-row'), findsOneWidget);
      expect(find.text(_en.teamDiscoverRowLine), findsOneWidget);

      // Remembered: a fresh Work tab (a restart) opens folded.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _app(Scaffold(body: WorkspaceScreen(controller: controller))),
      );
      await _settle(tester);
      expect(_key('team-discover-open'), findsNothing);
      expect(_key('team-discover-row'), findsOneWidget);

      // A global memory, not a server's: deleting a server keeps it.
      final prefs = controller.store.prefs;
      expect(prefs.getBool(TeamDiscoverMemory.foldedKey), isTrue);
      expect(
        controller.store.profileScopedPreferenceKeys('phone'),
        isNot(contains(TeamDiscoverMemory.foldedKey)),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('opening it shows the intro; back, it is folded', (
      tester,
    ) async {
      await pumpWork(tester);
      await tester.tap(_key('team-discover-open'));
      await _settle(tester);
      expect(find.byType(TeamIntroScreen), findsOneWidget);
      expect(find.text(_en.teamDiscoverHowHeading), findsOneWidget);
      await tester.pageBack();
      await _settle(tester);
      expect(_key('team-discover-open'), findsNothing);
      expect(_key('team-discover-row'), findsOneWidget);
      // The folded row is still a way in.
      await tester.tap(_key('team-discover-row'));
      await _settle(tester);
      expect(find.byType(TeamIntroScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('New conversation: Solo · Team', () {
    Future<WorkController> pumpWork(
      WidgetTester tester, {
      OrchestrationController? team,
    }) async {
      _tallScreen(tester);
      _mockChannels();
      final controller = await workController(
        name: 'pop-os',
        baseUrl: 'http://100.100.1.2:4096',
      );
      controller.team = team;
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(Scaffold(body: WorkspaceScreen(controller: controller))),
      );
      await _settle(tester);
      return controller;
    }

    testWidgets('Team is offered, remembered per server, and with the team '
        'off it opens the intro', (tester) async {
      final controller = await pumpWork(tester);
      expect(_key('workspace-new-mode'), findsOneWidget);
      expect(find.text(_en.workspaceNewSession), findsOneWidget);
      await tester.tap(_key('workspace-new-mode-team'));
      await _settle(tester);
      expect(find.text(_en.teamNewTask), findsOneWidget);
      expect(
        controller.store.prefs.getString(TeamNewMode.key('phone')),
        'team',
      );
      // Remembered: a fresh Work tab opens on Team.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _app(Scaffold(body: WorkspaceScreen(controller: controller))),
      );
      await _settle(tester);
      expect(find.text(_en.teamNewTask), findsOneWidget);
      // Swept with the server.
      expect(
        controller.store.profileScopedPreferenceKeys('phone'),
        contains(TeamNewMode.key('phone')),
      );
      await tester.tap(_key('workspace-new'));
      await _settle(tester);
      expect(find.byType(TeamIntroScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('with the team on: its tasks are in the lists with the '
        'team mark, and Team starts a team task', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final team = await _fixtureTeam();
      addTearDown(team.dispose);
      await pumpWork(tester, team: team);
      // The recorded convoy waits for a worker: under Running, marked.
      expect(_key('workspace-running'), findsOneWidget);
      expect(_key('team-work-task-oc-xru'), findsOneWidget);
      expect(_key('team-work-task-mark-oc-xru'), findsOneWidget);
      expect(
        tester
            .widget<Text>(_key('team-work-task-line-oc-xru'))
            .textSpan!
            .toPlainText(),
        startsWith('${_en.teamTaskMark} · ${_en.teamUiCardRunStateWaiting}'),
      );
      // No separate card; one quiet door to the team's page.
      expect(_key('team-card'), findsNothing);
      expect(_key('team-work-door'), findsOneWidget);
      await tester.tap(_key('team-work-task-oc-xru'));
      await _settle(tester);
      expect(find.byType(RunScreen), findsOneWidget);
      await tester.pageBack();
      await _settle(tester);
      await tester.tap(_key('workspace-new-mode-team'));
      await _settle(tester);
      await tester.tap(_key('workspace-new'));
      await _settle(tester);
      expect(_key('team-start-run-sheet'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('the entry per kind of server', () {
    Future<void> pumpEntry(
      WidgetTester tester,
      ConnectionController controller, {
      TermuxTeamRuntime? runtime,
    }) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: TeamDiscoverEntry(controller: controller, runtime: runtime),
          ),
        ),
      );
      await _settle(tester);
    }

    testWidgets('absent once the team is on', (tester) async {
      _mockChannels();
      final profile = _computer()
        ..orchestration = OrchestrationConfig(
          provider: OrchestrationProvider.gascity,
          url: 'https://team.example',
          city: 'city',
          hostMode: OrchestrationHostMode.computer,
          enabledAt: DateTime.utc(2026, 9, 25),
        );
      final controller = await _boot(profile);
      await pumpEntry(tester, controller);
      expect(_key('team-discover-open'), findsNothing);
      expect(_key('team-discover-row'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a Termux phone that can run a team shows it', (tester) async {
      debugPlatformCapabilities = const PlatformCapabilities.android();
      _mockChannels();
      final controller = await _boot(_termux());
      expect(teamServerKindOf(controller.profile!), TeamServerKind.termux);
      await pumpEntry(tester, controller, runtime: _Runtime(supported: true));
      expect(_key('team-discover-open'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a Termux phone that cannot run a team shows nothing', (
      tester,
    ) async {
      debugPlatformCapabilities = const PlatformCapabilities.android();
      _mockChannels();
      final controller = await _boot(_termux());
      await pumpEntry(tester, controller, runtime: _Runtime(supported: false));
      expect(_key('team-discover-open'), findsNothing);
      expect(_key('team-discover-row'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('the intro', () {
    /// Brings [finder] into the intro's list (built lazily).
    Future<void> reveal(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.descendant(
          of: _key('team-intro'),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(finder);
      await _settle(tester);
    }

    Future<void> pumpIntro(
      WidgetTester tester,
      ConnectionController controller, {
      TermuxTeamRuntime? runtime,
    }) async {
      _tallScreen(tester);
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () =>
                      openTeamIntro(context, controller, runtime: runtime),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          routes: {
            '/termux-setup': (_) =>
                const Scaffold(body: Text('termux setup screen')),
          },
        ),
      );
      await tester.tap(find.text('open'));
      await _settle(tester);
    }

    testWidgets('says what the team does, in four steps', (tester) async {
      _mockChannels();
      final controller = await _boot(_computer());
      await pumpIntro(tester, controller);
      for (final title in [
        _en.teamDiscoverStepPlanTitle,
        _en.teamDiscoverStepWorkTitle,
        _en.teamDiscoverStepCheckTitle,
        _en.teamDiscoverStepMergeTitle,
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(_key('team-intro-drawing'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a computer where Gas City answers: Turn on turns it on', (
      tester,
    ) async {
      _mockChannels();
      probe.found = _found();
      final controller = await _boot(_computer());
      await pumpIntro(tester, controller);
      expect(probe.calls, isNotEmpty);
      await reveal(tester, _key('team-intro-found'));
      expect(find.text(_en.pluginsTeamRowFound('Workstation')), findsOneWidget);
      await tester.tap(_key('team-intro-turn-on'));
      await _settle(tester);
      expect(controller.profile!.orchestration, isNotNull);
      // Back where the person came from, where the team now shows.
      expect(find.byType(TeamIntroScreen), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a computer without it: Set it up shows how, then looks '
        'again; the address is the other way', (tester) async {
      _mockChannels();
      final controller = await _boot(_computer());
      await pumpIntro(tester, controller);
      await reveal(tester, _key('team-intro-needs'));
      expect(
        find.text(_en.teamDiscoverNeedsServer('Workstation')),
        findsOneWidget,
      );
      expect(_key('team-intro-found'), findsNothing);
      final before = probe.calls.length;
      await tester.tap(_key('team-intro-set-up'));
      await _settle(tester);
      expect(_key('team-host-guide'), findsOneWidget);
      await tester.tapAt(const Offset(200, 40));
      await _settle(tester);
      expect(probe.calls.length, greaterThan(before));

      await tester.tap(_key('team-intro-address'));
      await _settle(tester);
      expect(find.byType(TeamHostForm), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('OpenCode inside the app: Set it up opens its set-up', (
      tester,
    ) async {
      debugPlatformCapabilities = const PlatformCapabilities.android();
      debugBuiltinTeam = _BuiltinTeam();
      _mockChannels();
      final controller = await _boot(_inApp());
      expect(teamServerKindOf(controller.profile!), TeamServerKind.inApp);
      await pumpIntro(tester, controller);
      await reveal(tester, find.text(_en.teamDiscoverBatteryTitle));
      expect(find.text(_en.teamDiscoverNeedsPhone), findsOneWidget);
      await tester.tap(_key('team-intro-set-up'));
      await _settle(tester);
      expect(find.byType(PluginsSettingsScreen), findsOneWidget);
      expect(find.byType(BuiltinTeamSection), findsOneWidget);
      expect(_key('builtin-team-add'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Termux: Set it up reopens the offer and opens its setup', (
      tester,
    ) async {
      debugPlatformCapabilities = const PlatformCapabilities.android();
      _mockChannels();
      final controller = await _boot(_termux());
      // Skipped during the first setup: the setup screen would hide it.
      await controller.orchestrationStore.setPhoneOffer(
        'termux',
        PhoneOffer.skipped,
      );
      await pumpIntro(tester, controller, runtime: _Runtime(supported: true));
      await reveal(tester, find.text(_en.teamDiscoverTermuxBatteryBody));
      await tester.tap(_key('team-intro-set-up'));
      await _settle(tester);
      expect(find.text('termux setup screen'), findsOneWidget);
      expect(
        controller.orchestrationStore.phoneOffer('termux'),
        PhoneOffer.open,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a Termux phone that cannot run it says so and offers a '
        'computer', (tester) async {
      debugPlatformCapabilities = const PlatformCapabilities.android();
      _mockChannels();
      final controller = await _boot(_termux());
      await pumpIntro(tester, controller, runtime: _Runtime(supported: false));
      await reveal(tester, _key('team-intro-on-computer'));
      expect(_key('team-intro-unsupported'), findsOneWidget);
      expect(_key('team-intro-set-up'), findsNothing);
      await tester.tap(_key('team-intro-on-computer'));
      await _settle(tester);
      expect(_key('team-host-guide'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('Settings', () {
    Future<void> pumpSettings(
      WidgetTester tester,
      ConnectionController controller,
    ) async {
      _tallScreen(tester);
      await tester.pumpWidget(_app(SettingsScreen(controller: controller)));
      await _settle(tester);
    }

    String line(WidgetTester tester) {
      final row = tester.widget<KitRow>(_key('settings-ai-team'));
      return row.supporting!.toPlainText();
    }

    testWidgets('has an AI Team row that reads Off and what it is for, and '
        'opens the intro', (tester) async {
      _mockChannels();
      final controller = await _boot(_computer());
      await pumpSettings(tester, controller);
      await tester.ensureVisible(_key('settings-ai-team'));
      await _settle(tester);
      expect(line(tester), _en.teamDiscoverRowLine);
      await tester.tap(_key('settings-ai-team'));
      await _settle(tester);
      expect(find.byType(TeamIntroScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('reads On · the server once it is on', (tester) async {
      _mockChannels();
      final profile = _computer()
        ..orchestration = OrchestrationConfig(
          provider: OrchestrationProvider.gascity,
          url: 'https://team.example',
          city: 'city',
          hostMode: OrchestrationHostMode.computer,
          enabledAt: DateTime.utc(2026, 9, 25),
        );
      final controller = await _boot(profile);
      await pumpSettings(tester, controller);
      await tester.ensureVisible(_key('settings-ai-team'));
      await _settle(tester);
      // The Plugins row's words, whatever the team's state is now.
      expect(line(tester), teamStateLine(_en, controller));
      expect(line(tester), isNot(startsWith(_en.teamUiRowOff)));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('one AI Team per page (OpenCode inside the app)', () {
    testWidgets('no contradicting AI Team rows while turning on', (
      tester,
    ) async {
      debugPlatformCapabilities = const PlatformCapabilities.android();
      debugBuiltinTeam = _BuiltinTeam();
      final engine = FakeSetupEngine();
      PhoneSetup.engine = engine;
      _mockChannels();
      _tallScreen(tester);
      final controller = await _boot(_inApp());
      // Add tools with AI Team is installing it.
      engine.emit(
        const SetupProgress(
          state: SetupState.running,
          components: [
            ComponentProgress(
              id: SetupComponentIds.aiTeam,
              state: ComponentState.running,
            ),
          ],
          overall: .4,
        ),
      );

      await tester.pumpWidget(
        _app(PluginsSettingsScreen(controller: controller)),
      );
      await _settle(tester);
      // The phone's card is the AI Team; no second "AI Team · Off" row.
      expect(find.byType(BuiltinTeamSection), findsOneWidget);
      expect(_key('plugins-ai-team-row'), findsNothing);
      expect(find.text(_en.teamUiRowOff), findsNothing);
      // A computer's team is a secondary choice under it.
      expect(_key('plugins-team-other'), findsOneWidget);
      expect(find.text(_en.teamDiscoverComputerChoiceTitle), findsOneWidget);

      // Settings says the same: turning on, never Off.
      await tester.pumpWidget(_app(SettingsScreen(controller: controller)));
      await _settle(tester);
      await tester.ensureVisible(_key('settings-ai-team'));
      await _settle(tester);
      String line() => tester
          .widget<KitRow>(_key('settings-ai-team'))
          .supporting!
          .toPlainText();
      expect(line(), _en.teamDiscoverTurningOn);

      // Done installing: the card offers to turn it on; Settings reads Off.
      engine.emit(SetupProgress.idle);
      await _settle(tester);
      expect(line(), startsWith(_en.teamUiRowOff));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('once the phone team is on, one state: On · This phone', (
      tester,
    ) async {
      debugPlatformCapabilities = const PlatformCapabilities.android();
      debugBuiltinTeam = _BuiltinTeam();
      PhoneSetup.engine = FakeSetupEngine();
      _mockChannels();
      _tallScreen(tester);
      final controller = await _boot(
        _inApp()..orchestration = BuiltinTeam.config(),
      );
      await tester.pumpWidget(
        _app(PluginsSettingsScreen(controller: controller)),
      );
      await _settle(tester);
      expect(_key('plugins-ai-team-row'), findsNothing);
      // Its technical details (and Turn off) are in the sheet, one row.
      expect(find.text(_en.teamUiTechnicalDetails), findsOneWidget);
      await tester.pumpWidget(_app(SettingsScreen(controller: controller)));
      await _settle(tester);
      await tester.ensureVisible(_key('settings-ai-team'));
      await _settle(tester);
      final line = tester
          .widget<KitRow>(_key('settings-ai-team'))
          .supporting!
          .toPlainText();
      expect(line, teamStateLine(_en, controller));
      expect(line, isNot(startsWith(_en.teamUiRowOff)));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('the team screens', () {
    testWidgets('the empty home gives its drawing room', (tester) async {
      _tallScreen(tester);
      final team = await teamSceneController(TeamScene.empty);
      addTearDown(team.dispose);
      await tester.pumpWidget(
        _app(TeamHomeScreen(controller: team, now: () => teamSceneClock)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(KitMotion.entrance);
      final drawing = find.descendant(
        of: _key('team-home-runs-empty'),
        matching: find.byType(KitIllustration),
      );
      // The board and its three agents read at this size; 88 dp cramped
      // them.
      expect(tester.getSize(drawing).width, greaterThanOrEqualTo(160));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the merged celebration plays for a celebration', (
      tester,
    ) async {
      TeamCelebrations.forgetSession();
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        _app(
          const Scaffold(
            body: TeamMergedCelebration(
              profileId: 'p',
              runId: 'merged-run',
              merged: true,
            ),
          ),
        ),
      );
      await _settle(tester);
      final drawing = tester.widget<KitIllustration>(
        _key('team-run-celebration'),
      );
      expect(drawing.entranceDuration, KitMotion.celebration);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
