// Gallery of slice-team-g17 (visual language 2026-09-26: amber means "needs
// you" and nothing else). The team home with two questions, an agent that
// waits on the person and one that is held up; the heat line; the page when
// the team does not answer; the Plugins page when a team was found on the
// server; and the host guide sheet. At 412x915 dark and 1280x800 light, with
// the app's real fonts.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/slice_team_g17_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/thermal_guard.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/thermal.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';
import 'package:opencode_mobile/ui/widgets/team_agent_row.dart';
import 'package:opencode_mobile/ui/widgets/team_host_form.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;

final _clock = DateTime.utc(2026, 9, 28, 12, 30);

/// A front host over fixed lists, every control on.
class _Gateway implements OrchestrationGateway {
  final runList = <OrchestrationRun>[];
  final workList = <WorkItem>[];
  final agentList = <OrchestrationAgent>[];
  final gateList = <OrchestrationGate>[];
  final _stream = StreamController<OrchestrationEvent>.broadcast();
  bool _closed = false;

  @override
  OrchestrationCapabilities get capabilities =>
      OrchestrationCapabilities.gascityFront;

  @override
  OrchestrationHostIdentity? get host => const OrchestrationHostIdentity(
    provider: 'gascity',
    url: 'http://127.0.0.1:8373',
    hostMode: OrchestrationHostMode.phone,
    city: 'bright-lights',
  );

  @override
  bool get isClosed => _closed;

  @override
  Future<void> close() async {
    _closed = true;
    await _stream.close();
  }

  @override
  Future<List<OrchestrationProject>> projects() async => const [];
  @override
  Future<List<OrchestrationRun>> runs({String? projectId}) async => runList;
  @override
  Future<OrchestrationRun?> run(String id) async => null;
  @override
  Future<List<WorkItem>> work({String? projectId}) async => workList;
  @override
  Future<List<WorkItem>> readyWork({String? projectId}) async => const [];
  @override
  Future<WorkItem?> workItem(String id) async => null;
  @override
  Future<List<OrchestrationAgent>> agents() async => agentList;
  @override
  Future<OrchestrationAgent?> agent(String id) async => null;
  @override
  Future<List<OrchestrationGate>> gates() async => gateList;
  @override
  Future<OrchestrationUsage?> usage() async => null;
  @override
  Future<List<ActivityEvent>> activity({
    int? afterSeq,
    int limit = 100,
  }) async => const [];
  @override
  Stream<OrchestrationEvent> events({
    EventCursor resumeFrom = EventCursor.none,
  }) => _stream.stream;

  MutationReceipt _ok(String requestId) => MutationReceipt(
    id: requestId,
    status: MutationReceiptStatus.accepted,
    upstreamStatus: 200,
  );

  @override
  Future<MutationReceipt> respond(
    String gateId,
    GateResponse response, {
    required String requestId,
  }) async => _ok(requestId);
  @override
  Future<MutationReceipt> message(
    String agentId,
    String text, {
    required String requestId,
  }) async => _ok(requestId);
  @override
  Future<MutationReceipt> controlAgent(
    String agentId,
    AgentControlAction action, {
    required String requestId,
  }) async => _ok(requestId);
  @override
  Future<MutationReceipt> cancelRun(
    String runId, {
    required String requestId,
  }) async => _ok(requestId);
  @override
  Future<MutationReceipt> assign(
    String workId, {
    required String agentId,
    required String requestId,
  }) async => _ok(requestId);
  @override
  Future<MutationReceipt> createWork({
    required String title,
    String? description,
    String? projectId,
    required String requestId,
  }) async => _ok(requestId);
}

/// A heat guard that holds what the scene says; nothing reaches Android.
class _Guard extends ThermalGuard {
  _Guard(SharedPreferences prefs, this.held)
    : super(bridge: ThermalBridge(), port: _NoTeams(), prefs: prefs);

  final Map<String, ThermalTeamHold> held;

  @override
  Map<String, ThermalTeamHold> get holds => held;
}

class _NoTeams implements ThermalTeamPort {
  @override
  Future<List<ThermalTeam>> runningHere() async => const [];
  @override
  Future<ThermalTeamHold?> pause(ThermalTeam team, {required DateTime now}) =>
      throw UnimplementedError();
  @override
  Future<ThermalTeamHold> stop(ThermalTeamHold hold) =>
      throw UnimplementedError();
  @override
  Future<bool> resume(ThermalTeamHold hold) => throw UnimplementedError();
}

final _asking = OrchestrationRun(
  id: 'oc-ask',
  title: 'Add a dark mode toggle',
  state: RunState.blocked,
  rawState: 'open',
  kind: RunKind.batch,
  stepCount: 1,
  startedAt: _clock.subtract(const Duration(hours: 1)),
  updatedAt: _clock.subtract(const Duration(minutes: 3)),
  raw: const {'id': 'oc-ask', 'issue_type': 'convoy'},
);

final _work = [
  WorkItem(
    id: 'oc-a1',
    title: 'Add a dark mode toggle',
    state: WorkState.needsInput,
    runId: 'oc-ask',
    assignee: 'a-fox',
    createdAt: _clock.subtract(const Duration(hours: 1)),
    updatedAt: _clock.subtract(const Duration(minutes: 3)),
  ),
  WorkItem(
    id: 'oc-a2',
    title: 'Theme the settings screen',
    state: WorkState.blocked,
    runId: 'oc-ask',
    assignee: 'a-owl',
    createdAt: _clock.subtract(const Duration(hours: 1)),
    updatedAt: _clock.subtract(const Duration(minutes: 8)),
  ),
];

const _fox = OrchestrationAgent(
  id: 'a-fox',
  name: 'ocproof/polecat-1',
  state: AgentState.waiting,
  sessionId: 'bl-7',
  currentWorkId: 'oc-a1',
);

const _owl = OrchestrationAgent(
  id: 'a-owl',
  name: 'ocproof/polecat-2',
  state: AgentState.blocked,
  sessionId: 'bl-8',
  currentWorkId: 'oc-a2',
);

const _wolf = OrchestrationAgent(
  id: 'a-wolf',
  name: 'ocproof/polecat-3',
  state: AgentState.working,
  sessionId: 'bl-9',
);

final _gates = [
  OrchestrationGate(
    id: 'req-safe',
    kind: GateKind.confirmation,
    rawKind: 'confirmation',
    title: 'Keep the old toggle?',
    prompt: 'The settings screen already has a theme switch.',
    agentId: 'a-fox',
    workId: 'oc-a1',
    runId: 'oc-ask',
    createdAt: _clock.subtract(const Duration(minutes: 3)),
    raw: const {'request_id': 'req-safe', 'session_id': 'bl-7'},
  ),
  OrchestrationGate(
    id: 'req-name',
    kind: GateKind.freeText,
    rawKind: 'text',
    title: 'What should the toggle say?',
    prompt: 'One or two words.',
    agentId: 'a-fox',
    workId: 'oc-a1',
    runId: 'oc-ask',
    createdAt: _clock.subtract(const Duration(minutes: 9)),
    raw: const {'request_id': 'req-name', 'session_id': 'bl-7'},
  ),
];

Future<OrchestrationController> _team(
  OrchestrationStore store, {
  bool answers = true,
}) async {
  final gateway = _Gateway()
    ..runList.add(_asking)
    ..workList.addAll(_work)
    ..agentList.addAll([_fox, _owl, _wolf])
    ..gateList.addAll(_gates);
  final config = OrchestrationConfig(
    provider: OrchestrationProvider.gascity,
    url: 'http://127.0.0.1:8373',
    city: 'bright-lights',
    front: true,
    hostMode: OrchestrationHostMode.phone,
    enabledAt: DateTime.utc(2026, 9, 10),
  );
  final controller = OrchestrationController(
    profile: ServerProfile(
      id: 'phone',
      name: 'This phone',
      baseUrl: 'http://127.0.0.1:4097',
      orchestration: config,
    ),
    config: config,
    store: store,
    gatewayFactory: (_, _) => gateway,
    probe: (_) async => answers
        ? ProbeFound(
            host: gateway.host!,
            front: true,
            identityAllowed: true,
            capabilities: OrchestrationCapabilities.gascityFront,
          )
        : const ProbeUnreachable(error: 'no answer'),
    now: () => _clock,
  );
  await controller.start();
  return controller;
}

Future<void> _golden(
  WidgetTester tester,
  String name, {
  required Size size,
  required bool light,
  Widget? body,
  Future<void> Function(BuildContext context)? open,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  final host = GlobalKey();
  debugDefaultTargetPlatformOverride = TargetPlatform.android; // ARCH-11
  try {
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: captureTheme(light: light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: body ?? Scaffold(key: host, body: const SizedBox.expand()),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (open != null) {
      unawaited(open(host.currentContext!));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/$name.png'),
    );
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

enum _Scene { home, heat, notAnswering, agents, guide }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  late SharedPreferences prefs;
  late OrchestrationStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = OrchestrationStore(prefs);
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
  });

  for (final (size, light) in const [
    (Size(412, 915), false),
    (Size(1280, 800), true),
  ]) {
    final sized = size.width == 412
        ? ''
        : '_${size.width.toInt()}x${size.height.toInt()}';
    final mode = light ? 'light' : 'dark';
    for (final scene in _Scene.values) {
      // TEST-20: golden names are lower-case snake_case (plannerOff ->
      // planner_off).
      final state = scene.name.replaceAllMapped(
        RegExp('[A-Z]'),
        (m) => '_${m[0]!.toLowerCase()}',
      );
      final name = 'team_g17_$state${sized}_$mode';
      testWidgets(name, (tester) async {
        switch (scene) {
          case _Scene.home:
          case _Scene.heat:
          case _Scene.notAnswering:
            final team = await _team(
              store,
              answers: scene != _Scene.notAnswering,
            );
            final guard = _Guard(prefs, {
              if (scene == _Scene.heat)
                team.profileId: ThermalTeamHold(
                  team: ThermalTeam(
                    id: team.profileId,
                    url: team.host!.url,
                    city: team.host!.city!,
                    builtin: true,
                  ),
                  since: _clock.subtract(const Duration(minutes: 3)),
                  status: ThermalStatus.severe,
                ),
            });
            try {
              await _golden(
                tester,
                name,
                size: size,
                light: light,
                body: TeamHomeScreen(
                  controller: team,
                  now: () => _clock,
                  thermalGuard: ValueNotifier<ThermalGuard?>(guard),
                ),
              );
            } finally {
              await team.stop();
              team.dispose();
              guard.dispose();
            }
          case _Scene.agents:
            await _golden(
              tester,
              name,
              size: size,
              light: light,
              body: KitScreen(
                topBar: const KitTopBar(title: 'Agents'),
                body: ListView(
                  children: [
                    KitRowGroup(
                      children: [
                        for (final (agent, work) in [
                          (_fox, _work[0]),
                          (_owl, _work[1]),
                          (_wolf, null),
                        ])
                          TeamAgentRow(
                            agent: agent,
                            work: work,
                            now: _clock,
                            onTap: () {},
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          case _Scene.guide:
            await _golden(
              tester,
              name,
              size: size,
              light: light,
              open: (context) =>
                  showTeamHostGuideSheet(context, enterAddress: () async {}),
            );
        }
      });
    }
  }
}
