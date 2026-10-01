import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/domain/phone_project_engine.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/project_fixture_gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/phone_team_setup.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/team/projects/team_execution_gate.dart';
import 'package:opencode_mobile/ui/screens/team/projects/team_projects_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'team_project_fixture_test.dart' show MemoryPersistence;

final _en = lookupAppLocalizations(const Locale('en'));

PhoneEngineHealth _health() => const PhoneEngineHealth(
  boundaryTier: 'proot',
  profileId: 'p',
  engineVersion: '1',
  execution: true,
  boundary: true,
  oc1Verified: true,
  oc2: false,
  commandActions: {},
  restartRequired: false,
  boundaryReason: '',
);

class _Phone extends ChangeNotifier implements PhoneTeamSetupPorts {
  bool reply = false;
  PhoneTeamHostState host = const PhoneTeamHostState();
  Future<PhoneEngineHealth>? hangStart;
  @override
  bool get hasServer => true;
  @override
  bool get wasOn => true;
  @override
  bool get replyRunning => reply;
  @override
  Listenable get replyChanges => this;
  @override
  Future<PhoneTeamHostState> inspect() async => host;
  @override
  Future<void> stopServer() async {}
  @override
  Future<void> closeTerminals() async {}
  @override
  Future<PhoneEngineHealth> startEngine() =>
      hangStart ?? Future.value(_health());
  @override
  Future<PhoneEngineHealth> probeEngine() async => _health();
  @override
  Future<String?> startServer() async => null;
  @override
  Future<bool> restoreServer() async => true;
  @override
  Future<void> attach() async {}
}

PhoneTeamSetupController _flow(_Phone p) => PhoneTeamSetupController(
  p,
  delay: (_) async {},
  readyAttempts: 1,
  replyWait: const Duration(milliseconds: 50),
  stepWait: const Duration(milliseconds: 50),
);

Widget _app(Widget home) => ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: home,
  ),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
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

class _Gateway extends ProjectFixtureGateway {
  _Gateway({required this.resume}) : super(persistence: MemoryPersistence());
  final bool resume;
  final commands = <TeamProjectAction>[];
  @override
  Future<TeamWorkspace> teamWorkspace() async =>
      _interrupt(await super.teamWorkspace());
  @override
  Stream<TeamWorkspace> watchTeamWorkspace() =>
      super.watchTeamWorkspace().map(_interrupt);
  TeamWorkspace _interrupt(TeamWorkspace w) => w.copyWith(
    simulated: false,
    projects: [
      for (final p in w.projects)
        p.copyWith(
          status: 'interrupted',
          tasks: [for (final t in p.tasks) t.copyWith(status: 'interrupted')],
        ),
    ],
  );
  @override
  Future<TeamCommandResult> executeProject(TeamProjectCommand command) {
    commands.add(command.action);
    return super.executeProject(command);
  }

  @override
  OrchestrationCapabilities get capabilities => OrchestrationCapabilities(
    projects: true,
    projectLifecycle: true,
    livingSpec: true,
    projectLanes: true,
    projectResume: resume,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a check that never answers ends in a failure with a reason', () {
    test('a hung engine start', () async {
      final phone = _Phone()..hangStart = Completer<PhoneEngineHealth>().future;
      final flow = _flow(phone);
      await flow.run().timeout(const Duration(seconds: 5));
      expect(flow.phase, PhoneTeamSetupPhase.failed);
      expect(flow.problem, PhoneTeamSetupProblem.engine);
      expect(flow.details, contains('timeout:startEngine'));
      expect(flow.isRunning, isFalse);
    });

    test('a reply that never ends does not hold the check forever', () async {
      final phone = _Phone()..reply = true;
      final flow = _flow(phone);
      await flow.run().timeout(const Duration(seconds: 5));
      expect(flow.phase, PhoneTeamSetupPhase.failed);
      expect(flow.details, contains('replyStillRunning'));
    });
  });

  group('the AI Team page while the check runs', () {
    testWidgets('waiting for the person says so instead of Checking', (
      tester,
    ) async {
      _mockChannels();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final connection = ConnectionController(ProfileStore(prefs: prefs));
      addTearDown(connection.dispose);
      final phone = _Phone()
        ..host = const PhoneTeamHostState(serverRunning: true);
      PhoneTeamSetup.debugPorts = (_) => phone;
      addTearDown(() => PhoneTeamSetup.debugPorts = null);
      final flow = PhoneTeamSetup.of(connection);
      unawaited(flow.run(automatic: true));
      await tester.pumpWidget(_app(PhoneTeamOffPage(connection: connection)));
      await _settle(tester);
      expect(flow.phase, PhoneTeamSetupPhase.confirming);
      expect(find.text(_en.phoneTeamStripChecking), findsNothing);
      expect(find.text(_en.phoneTeamStripWaiting), findsOneWidget);
      expect(find.text(_en.phoneTeamOffReview), findsOneWidget);
      flow.answer(false);
      await _settle(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('Resume on interrupted work', () {
    Future<_Gateway> pump(WidgetTester tester, {required bool resume}) async {
      _mockChannels();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final connection = ConnectionController(ProfileStore(prefs: prefs));
      addTearDown(connection.dispose);
      final gateway = _Gateway(resume: resume);
      final owner = OrchestrationController(
        profile: ServerProfile(
          id: 'p',
          name: 'This phone',
          baseUrl: 'http://127.0.0.1:4097',
        ),
        config: const OrchestrationConfig(
          provider: OrchestrationProvider.fixture,
          url: 'fixture://resume',
        ),
        store: OrchestrationStore(prefs),
        gatewayFactory: (_, _) => gateway,
        probe: (config) async => ProbeFound(
          host: OrchestrationHostIdentity(
            provider: 'fixture',
            url: config.url,
            hostMode: config.hostMode,
          ),
        ),
      );
      addTearDown(owner.dispose);
      await owner.start();
      TeamExecutionGate.bind(owner, connection);
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(TeamProjectsScreen(controller: owner.projectController!)),
      );
      await _settle(tester);
      return gateway;
    }

    testWidgets('an interrupted project row resumes it when offered', (
      tester,
    ) async {
      final gateway = await pump(tester, resume: true);
      final row = find.byKey(const ValueKey('team-resume-row-demo-project'));
      expect(row, findsOneWidget);
      expect(find.text(_en.teamProjectResumeUnavailable), findsNothing);
      await tester.tap(row);
      await _settle(tester);
      expect(gateway.commands, contains(TeamProjectAction.resumeProject));
    });

    testWidgets('without the engine action there is no button, only a '
        'plain reason', (tester) async {
      final gateway = await pump(tester, resume: false);
      expect(
        find.byKey(const ValueKey('team-resume-row-demo-project')),
        findsNothing,
      );
      expect(find.text(_en.teamProjectResumeUnavailable), findsOneWidget);
      expect(gateway.commands, isEmpty);
    });
  });
}
