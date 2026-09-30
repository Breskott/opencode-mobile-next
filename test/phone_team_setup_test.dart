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
import 'package:opencode_mobile/ui/screens/team/team_phone_setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'team_project_fixture_test.dart' show MemoryPersistence;

final _en = lookupAppLocalizations(const Locale('en'));

PhoneEngineHealth _health({
  bool execution = true,
  bool boundary = true,
  bool oc1Verified = true,
  bool restartRequired = false,
  String reason = '',
}) => PhoneEngineHealth(
  profileId: 'p',
  engineVersion: '1',
  execution: execution,
  boundary: boundary,
  oc1Verified: oc1Verified,
  oc2: false,
  commandActions: const {},
  restartRequired: restartRequired,
  boundaryReason: reason,
);

/// A scripted phone: every call is recorded, nothing reaches Android.
class _Phone extends ChangeNotifier implements PhoneTeamSetupPorts {
  bool reply = false;
  PhoneTeamHostState host = const PhoneTeamHostState();
  PhoneEngineHealth started = _health();
  PhoneEngineHealth probed = _health();
  String? serverFailure;
  bool restoreResult = true;
  bool on = false;
  bool server = true;
  final calls = <String>[];
  int startCalls = 0;

  /// Holds the engine's proof open (a golden of the step while it works).
  Future<void>? holdStart;

  @override
  bool get hasServer => server;
  @override
  bool get wasOn => on;
  @override
  bool get replyRunning => reply;
  @override
  Listenable get replyChanges => this;
  void finishReply() {
    reply = false;
    notifyListeners();
  }

  @override
  Future<PhoneTeamHostState> inspect() async {
    calls.add('inspect');
    return host;
  }

  @override
  Future<void> stopServer() async => calls.add('stopServer');
  @override
  Future<void> closeTerminals() async => calls.add('closeTerminals');
  @override
  Future<PhoneEngineHealth> startEngine() async {
    calls.add('startEngine');
    startCalls++;
    await holdStart;
    return started;
  }

  @override
  Future<PhoneEngineHealth> probeEngine() async {
    calls.add('probe');
    return probed;
  }

  @override
  Future<String?> startServer() async {
    calls.add('startServer');
    return serverFailure;
  }

  @override
  Future<bool> restoreServer() async {
    calls.add('restoreServer');
    return restoreResult;
  }

  @override
  Future<void> attach() async => calls.add('attach');
}

PhoneTeamSetupController _flow(_Phone phone) =>
    PhoneTeamSetupController(phone, delay: (_) async {}, readyAttempts: 2);

Future<ConnectionController> _connection() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = ProfileStore(prefs: prefs);
  final connection = ConnectionController(store);
  addTearDown(connection.dispose);
  return connection;
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

void _size(WidgetTester tester, [Size size = const Size(412, 915)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Fixture projects whose engine can (or cannot) run work yet.
class _Gateway extends ProjectFixtureGateway {
  _Gateway({required this.lanes}) : super(persistence: MemoryPersistence());
  final bool lanes;
  @override
  OrchestrationCapabilities get capabilities => OrchestrationCapabilities(
    projects: true,
    projectLifecycle: true,
    projectLanes: lanes,
    projectPromotion: lanes,
    projectMergeQueue: lanes,
    projectVerification: lanes,
    projectPlacement: lanes,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => PhoneTeamSetup.debugPorts = null);

  group('the flow', () {
    test('a running reply is waited for, never cut short', () async {
      final phone = _Phone()..reply = true;
      final flow = _flow(phone);
      final run = flow.run();
      await Future<void>.delayed(Duration.zero);
      expect(flow.waitingForReply, isTrue);
      expect(phone.calls, isEmpty);
      phone.finishReply();
      await run;
      expect(flow.phase, PhoneTeamSetupPhase.done);
      expect(phone.calls.first, 'inspect');
    });

    test('a reply whose grace ends without an event does not hold the '
        'flow', () async {
      // replyRunning turns false with no notification (a just-sent
      // prompt's grace window expiring); the flow must still move on.
      final phone = _Phone()..reply = true;
      final flow = _flow(phone);
      final run = flow.run();
      await Future<void>.delayed(Duration.zero);
      expect(flow.waitingForReply, isTrue);
      phone.reply = false; // no notifyListeners
      await run.timeout(const Duration(seconds: 5));
      expect(flow.phase, PhoneTeamSetupPhase.done);
    });

    test('a passed check before OpenCode restarts is not a failure '
        '(boundary_attested)', () async {
      // Right after the proof, OpenCode is not verified yet: the check
      // passes on the boundary and the server step waits for canExecute.
      final phone = _Phone()
        ..started = _health(oc1Verified: false, reason: 'boundary_attested');
      final flow = _flow(phone);
      await flow.run();
      expect(flow.isDone, isTrue);
    });

    test(
      'nothing running: no stop question, steps skipped, then ready',
      () async {
        final phone = _Phone();
        final flow = _flow(phone);
        await flow.run();
        expect(flow.isDone, isTrue);
        expect(flow.wasSkipped(PhoneTeamSetupStep.stop), isTrue);
        expect(phone.calls, [
          'inspect',
          'startEngine',
          'startServer',
          'probe',
          'attach',
        ]);
      },
    );

    test('a running server asks first; no stops before a yes', () async {
      final phone = _Phone()
        ..host = const PhoneTeamHostState(serverRunning: true, terminals: 2);
      final flow = _flow(phone);
      final run = flow.run();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(flow.phase, PhoneTeamSetupPhase.confirming);
      expect(phone.calls, ['inspect']);
      flow.answer(true);
      await run;
      expect(flow.isDone, isTrue);
      expect(
        phone.calls,
        containsAllInOrder([
          'stopServer',
          'closeTerminals',
          'startEngine',
          'startServer',
        ]),
      );
    });

    test('saying no changes nothing and ends in plain words', () async {
      final phone = _Phone()
        ..host = const PhoneTeamHostState(serverRunning: true);
      final flow = _flow(phone);
      final run = flow.run();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      flow.answer(false);
      await run;
      expect(flow.phase, PhoneTeamSetupPhase.failed);
      expect(flow.problem, PhoneTeamSetupProblem.declined);
      expect(phone.calls, ['inspect']);
    });

    test(
      'an engine that finds an old server asks, once, then retries',
      () async {
        final phone = _Phone()..started = _health(restartRequired: true);
        final flow = _flow(phone);
        final run = flow.run();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(flow.phase, PhoneTeamSetupPhase.confirming);
        // The second start answers clean.
        phone.started = _health();
        flow.answer(true);
        await run;
        expect(flow.isDone, isTrue);
        expect(phone.startCalls, 2);
      },
    );

    test('a failed proof stays off, keeps reasons for Details', () async {
      final phone = _Phone()
        ..started = _health(boundary: false, reason: 'boundary_proof_failed');
      final flow = _flow(phone);
      await flow.run();
      expect(flow.phase, PhoneTeamSetupPhase.failed);
      expect(flow.problem, PhoneTeamSetupProblem.unsafe);
      expect(flow.failedStep, PhoneTeamSetupStep.check);
      expect(flow.details, 'boundary_proof_failed');
      expect(phone.calls, isNot(contains('startServer')));
    });

    test(
      'B-3: a failure after the stop puts OpenCode back, once, and says so',
      () async {
        final phone = _Phone()
          ..host = const PhoneTeamHostState(serverRunning: true, terminals: 1)
          ..started = _health(boundary: false, reason: 'boundary_proof_failed');
        final flow = _flow(phone);
        final run = flow.run();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        flow.answer(true);
        await run;
        expect(flow.phase, PhoneTeamSetupPhase.failed);
        expect(flow.serverState, PhoneTeamServerState.backOn);
        expect(flow.terminalsClosed, isTrue);
        expect(phone.calls.where((c) => c == 'restoreServer'), hasLength(1));
        expect(phone.calls.indexOf('restoreServer'), greaterThan(2));

        phone.restoreResult = false;
        phone.started = _health(boundary: false, reason: 'x');
        final again = _flow(phone);
        final second = again.run();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        again.answer(true);
        await second;
        expect(again.serverState, PhoneTeamServerState.stillOff);
      },
    );

    test(
      'B-3: a failure that never stopped OpenCode restores nothing',
      () async {
        final phone = _Phone()
          ..started = _health(boundary: false, reason: 'boundary_proof_failed');
        final flow = _flow(phone);
        await flow.run();
        expect(flow.serverState, PhoneTeamServerState.untouched);
        expect(phone.calls, isNot(contains('restoreServer')));
      },
    );

    test('OpenCode that does not come back is its own failure', () async {
      final phone = _Phone()..serverFailure = 'timedOut';
      final flow = _flow(phone);
      await flow.run();
      expect(flow.problem, PhoneTeamSetupProblem.serverStart);
      expect(flow.failedStep, PhoneTeamSetupStep.server);
    });

    test(
      'an engine that still cannot run work after the probe is not ready',
      () async {
        final phone = _Phone()..probed = _health(execution: false);
        final flow = _flow(phone);
        await flow.run();
        expect(flow.problem, PhoneTeamSetupProblem.notReady);
        expect(phone.calls.where((c) => c == 'probe'), hasLength(2));
      },
    );

    test('no OpenCode on this phone says so, changes nothing', () async {
      final phone = _Phone()..server = false;
      final flow = _flow(phone);
      await flow.run();
      expect(flow.problem, PhoneTeamSetupProblem.noServer);
      expect(phone.calls, isEmpty);
    });

    test(
      'after an update, a team that was on is checked again alone',
      () async {
        final off = _Phone();
        await _flow(off).autoProof();
        expect(off.calls, isEmpty, reason: 'never turned on: nothing to redo');

        final healthy = _Phone()..on = true;
        await _flow(healthy).autoProof();
        expect(healthy.calls, ['probe'], reason: 'proof still holds');

        final stale = _Phone()
          ..on = true
          ..probed = _health(execution: false)
          ..host = const PhoneTeamHostState(serverRunning: true);
        final flow = _flow(stale);
        unawaited(flow.autoProof());
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(flow.automatic, isTrue);
        expect(flow.phase, PhoneTeamSetupPhase.confirming);
        expect(
          stale.calls,
          isNot(contains('stopServer')),
          reason: 'the person\'s chat is never killed silently',
        );
        flow.dispose();
      },
    );
  });

  group('the page', () {
    testWidgets('waiting for a reply, then the stop question, then ready', (
      tester,
    ) async {
      _size(tester);
      final connection = await _connection();
      final phone = _Phone()
        ..reply = true
        ..host = const PhoneTeamHostState(serverRunning: true, terminals: 1);
      final flow = _flow(phone);
      await tester.pumpWidget(
        _app(TeamPhoneSetupScreen(connection: connection, controller: flow)),
      );
      await _settle(tester);
      expect(find.text(_en.phoneTeamStepReply), findsOneWidget);
      expect(find.textContaining(_en.phoneTeamReplyWaiting), findsOneWidget);

      phone.finishReply();
      await _settle(tester);
      expect(find.text(_en.phoneTeamStopTitle), findsOneWidget);
      expect(find.text(_en.phoneTeamStopBody), findsOneWidget);
      expect(phone.calls, ['inspect'], reason: 'nothing stops before a yes');

      await tester.tap(find.byKey(const ValueKey('phone-team-stop-confirm')));
      await _settle(tester);
      expect(find.text(_en.phoneTeamDoneTitle), findsOneWidget);
      expect(find.text(_en.teamProjectNew), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a failed proof: plain words, Details, Start again', (
      tester,
    ) async {
      _size(tester);
      final connection = await _connection();
      final phone = _Phone()
        ..started = _health(boundary: false, reason: 'boundary_proof_failed');
      final flow = _flow(phone);
      await tester.pumpWidget(
        _app(TeamPhoneSetupScreen(connection: connection, controller: flow)),
      );
      await _settle(tester);
      expect(find.text(_en.phoneTeamFailUnsafeTitle), findsOneWidget);
      // B-4: the body says exactly what state OpenCode is in; nothing was
      // stopped here, and it never claims "nothing else was changed".
      expect(find.textContaining(_en.phoneTeamFailUnsafeBody), findsOneWidget);
      expect(find.textContaining(_en.phoneTeamStateNotStopped), findsOneWidget);
      expect(find.textContaining('Nothing else was changed'), findsNothing);
      // The code is not plain copy; it is behind Details.
      expect(find.text('boundary_proof_failed'), findsNothing);
      expect(find.text(_en.phoneTeamStepCheck), findsOneWidget);
      await tester.tap(find.text('Details'));
      await _settle(tester);
      // Details: one plain sentence, then the code.
      expect(find.textContaining(_en.phoneTeamWhyUnsafe), findsOneWidget);
      expect(find.textContaining('boundary_proof_failed'), findsOneWidget);

      // Start again runs it afresh and can succeed.
      phone.started = _health();
      await tester.tap(find.byKey(const ValueKey('phone-team-start-again')));
      await _settle(tester);
      expect(find.text(_en.phoneTeamDoneTitle), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('B-3/B-4: after a stop, the failure says OpenCode is back on', (
      tester,
    ) async {
      _size(tester);
      final connection = await _connection();
      final phone = _Phone()
        ..host = const PhoneTeamHostState(serverRunning: true, terminals: 1)
        ..started = _health(boundary: false, reason: 'engine_bundle_invalid');
      await tester.pumpWidget(
        _app(
          TeamPhoneSetupScreen(
            connection: connection,
            controller: _flow(phone),
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('phone-team-stop-confirm')));
      await _settle(tester);
      expect(find.textContaining(_en.phoneTeamStateBackOn), findsOneWidget);
      expect(
        find.textContaining(_en.phoneTeamStateTerminalsClosed),
        findsOneWidget,
      );
      expect(phone.calls, contains('restoreServer'));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('no from the question leaves a calm page, nothing stopped', (
      tester,
    ) async {
      _size(tester);
      final connection = await _connection();
      final phone = _Phone()
        ..host = const PhoneTeamHostState(serverRunning: true);
      await tester.pumpWidget(
        _app(
          TeamPhoneSetupScreen(
            connection: connection,
            controller: _flow(phone),
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.text(_en.phoneTeamStopCancel));
      await _settle(tester);
      expect(find.text(_en.phoneTeamFailDeclinedTitle), findsOneWidget);
      expect(phone.calls, ['inspect']);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('execution gating', () {
    Future<(OrchestrationController, ConnectionController)> team({
      required bool lanes,
    }) async {
      _mockChannels();
      final connection = await _connection();
      final prefs = await SharedPreferences.getInstance();
      final owner = OrchestrationController(
        profile: ServerProfile(
          id: 'p',
          name: 'This phone',
          baseUrl: 'http://127.0.0.1:4097',
        ),
        config: const OrchestrationConfig(
          provider: OrchestrationProvider.fixture,
          url: 'fixture://gate',
        ),
        store: OrchestrationStore(prefs),
        gatewayFactory: (_, _) => _Gateway(lanes: lanes),
      );
      addTearDown(owner.dispose);
      await owner.start();
      return (owner, connection);
    }

    testWidgets('blocked: one plain line and the fix, no New project', (
      tester,
    ) async {
      _size(tester);
      final (owner, connection) = await team(lanes: false);
      TeamExecutionGate.bind(owner, connection);
      final phone = _Phone()..reply = true;
      PhoneTeamSetup.debugPorts = (_) => phone;
      await tester.pumpWidget(
        _app(TeamProjectsScreen(controller: owner.projectController!)),
      );
      await _settle(tester);
      expect(find.text(_en.phoneTeamBlocked), findsOneWidget);
      expect(find.text(_en.teamProjectNew), findsNothing);
      expect(find.text(_en.teamProjectQuick), findsNothing);

      // The fix is the setup flow, waiting for the reply it found.
      await tester.tap(find.byKey(const ValueKey('team-execution-set-up')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('phone-team-steps')), findsOneWidget);
      expect(find.textContaining(_en.phoneTeamReplyWaiting), findsOneWidget);
      // Let the flow finish so its reply poll ends with the test.
      phone.finishReply();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('ready engine: no line, New project is there', (tester) async {
      _size(tester);
      final (owner, connection) = await team(lanes: true);
      TeamExecutionGate.bind(owner, connection);
      await tester.pumpWidget(
        _app(TeamProjectsScreen(controller: owner.projectController!)),
      );
      await _settle(tester);
      expect(find.text(_en.phoneTeamBlocked), findsNothing);
      expect(find.text(_en.teamProjectNew), findsOneWidget);
    });

    testWidgets('the demo is never gated', (tester) async {
      _size(tester);
      final (owner, _) = await team(lanes: false);
      await tester.pumpWidget(
        _app(TeamProjectsScreen(controller: owner.projectController!)),
      );
      await _settle(tester);
      expect(find.text(_en.phoneTeamBlocked), findsNothing);
      expect(find.text(_en.teamProjectNew), findsOneWidget);
    });
  });
}

// Shared with the golden scenes.
PhoneTeamSetupPortsForGolden phoneForGolden() => _Phone();
PhoneEngineHealth healthForGolden({bool boundary = true, String reason = ''}) =>
    _health(boundary: boundary, reason: reason);
typedef PhoneTeamSetupPortsForGolden = _Phone;
