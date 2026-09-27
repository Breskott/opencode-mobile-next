// TEAM-116: the dispatch cycle. Derivation over the recorded normal-run
// event log and over hand-built evidence (each stall reason with its
// window), the provider-limit regex over a transcript, and the step's Now
// line that replaced the strip (slice-P5.1): each stall as a reason in the
// person's words, the Why in place, 320dp at 2.5x in both directions, and
// the placement in Task details, the conversation and the Work sheet.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/fixture_gateway.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/dto/dto.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/gascity_mappers.dart';
import 'package:opencode_mobile/orchestration/dispatch.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/team/task_details_sheet.dart';
import 'package:opencode_mobile/ui/screens/team_conversation/team_conversation.dart'
    show TeamConversationScreen;
import 'package:opencode_mobile/ui/screens/team/work_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Directory _findFixtureRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 5; i++) {
    final candidate = Directory('${dir.path}/tool/qa/gascity_fixture');
    if (candidate.existsSync()) return candidate;
    dir = dir.parent;
  }
  throw StateError(
    'tool/qa/gascity_fixture not found from ${Directory.current}',
  );
}

/// The fixture with per-scope overrides, an owned event stream a test
/// pushes timeline events into, and scripted agent output per session.
class _Gateway
    implements OrchestrationGateway, OrchestrationAgentOutputGateway {
  _Gateway(this.inner);

  final FixtureOrchestrationGateway inner;
  final stream = StreamController<OrchestrationEvent>.broadcast();
  List<OrchestrationRun>? runsOverride;
  List<WorkItem>? workOverride;
  List<OrchestrationAgent>? agentsOverride;
  OrchestrationCapabilities? capabilitiesOverride;
  final outputs = <String, List<AgentOutputEvent>>{};
  final outputOpened = <String>[];

  @override
  OrchestrationCapabilities get capabilities =>
      capabilitiesOverride ?? inner.capabilities;
  @override
  OrchestrationHostIdentity? get host => inner.host;
  @override
  bool get isClosed => inner.isClosed;
  @override
  Future<void> close() async {
    await stream.close();
    await inner.close();
  }

  @override
  Future<List<OrchestrationProject>> projects() => inner.projects();
  @override
  Future<List<OrchestrationRun>> runs({String? projectId}) async =>
      runsOverride ?? await inner.runs(projectId: projectId);
  @override
  Future<OrchestrationRun?> run(String id) async {
    for (final run in await runs()) {
      if (run.id == id) return run;
    }
    return null;
  }

  @override
  Future<List<WorkItem>> work({String? projectId}) async =>
      workOverride ?? await inner.work(projectId: projectId);
  @override
  Future<List<WorkItem>> readyWork({String? projectId}) =>
      inner.readyWork(projectId: projectId);
  @override
  Future<WorkItem?> workItem(String id) async {
    for (final item in await work()) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<List<OrchestrationAgent>> agents() async =>
      agentsOverride ?? await inner.agents();
  @override
  Future<OrchestrationAgent?> agent(String id) => inner.agent(id);
  @override
  Future<List<OrchestrationGate>> gates() => inner.gates();
  @override
  Future<OrchestrationUsage?> usage() => inner.usage();
  @override
  Future<List<ActivityEvent>> activity({int? afterSeq, int limit = 100}) =>
      inner.activity(afterSeq: afterSeq, limit: limit);
  @override
  Stream<OrchestrationEvent> events({
    EventCursor resumeFrom = EventCursor.none,
  }) => stream.stream;

  /// Scripted output arrives on listen; the stream then stays open like
  /// a live session's would.
  @override
  Stream<AgentOutputEvent> agentOutput(String sessionId) {
    outputOpened.add(sessionId);
    final scripted = outputs[sessionId];
    if (scripted == null) return inner.agentOutput(sessionId);
    late StreamController<AgentOutputEvent> controller;
    controller = StreamController<AgentOutputEvent>(
      onListen: () => scripted.forEach(controller.add),
    );
    return controller.stream;
  }

  @override
  Future<MutationReceipt> respond(
    String gateId,
    GateResponse response, {
    required String requestId,
  }) => inner.respond(gateId, response, requestId: requestId);
  @override
  Future<MutationReceipt> message(
    String agentId,
    String text, {
    required String requestId,
  }) => inner.message(agentId, text, requestId: requestId);
  @override
  Future<MutationReceipt> controlAgent(
    String agentId,
    AgentControlAction action, {
    required String requestId,
  }) => inner.controlAgent(agentId, action, requestId: requestId);
  @override
  Future<MutationReceipt> cancelRun(
    String runId, {
    required String requestId,
  }) => inner.cancelRun(runId, requestId: requestId);
  @override
  Future<MutationReceipt> assign(
    String workId, {
    required String agentId,
    required String requestId,
  }) => inner.assign(workId, agentId: agentId, requestId: requestId);

  @override
  Future<MutationReceipt> createWork({
    required String title,
    String? description,
    String? projectId,
    required String requestId,
  }) => inner.createWork(
    title: title,
    description: description,
    projectId: projectId,
    requestId: requestId,
  );
}

/// One work item with Gas City-shaped raw metadata.
WorkItem _item({
  String id = 'oc-loy',
  String status = 'open',
  String? routedTo = 'ocproof/gastown.polecat',
  String? assignee,
  String? sessionId,
  String? workDir,
  String? branch,
  String? runId = 'oc-xru',
  DateTime? updatedAt,
  DateTime? createdAt,
}) {
  final metadata = <String, Object?>{
    'gc.routed_to': ?routedTo,
    'gc.session_id': ?sessionId,
    if (sessionId != null) 'gc.session_name': 'gastown__polecat-$sessionId',
    'gc.work_dir': ?workDir,
    'branch': ?branch,
  };
  return WorkItem(
    id: id,
    title: 'Add subtract function to calc.py',
    state: WorkState.fromProvider(status),
    rawState: status,
    projectId: 'ocproof',
    runId: runId,
    assignee: assignee ?? routedTo,
    sessionId: sessionId,
    updatedAt: updatedAt,
    createdAt: createdAt,
    raw: {
      'id': id,
      'status': status,
      'assignee': ?assignee,
      'metadata': metadata,
    },
  );
}

int _seq = 5000;

/// A `bead.*` event as the Gas City stream carries it.
BeadChanged _bead(
  DateTime at, {
  String id = 'oc-loy',
  BeadChange change = BeadChange.updated,
  String status = 'open',
  String? assignee,
  Map<String, Object?> metadata = const {
    'gc.routed_to': 'ocproof/gastown.polecat',
  },
  String? closeReason,
}) => BeadChanged(
  beadId: id,
  change: change,
  seq: ++_seq,
  raw: {
    'seq': _seq,
    'type': 'bead.${change.name}',
    'ts': at.toIso8601String(),
    'subject': id,
    'payload': {
      'bead': {
        'id': id,
        'status': status,
        'assignee': ?assignee,
        'close_reason': ?closeReason,
        'metadata': metadata,
      },
    },
  },
);

/// A `session.woke` / `session.stopped` event.
SessionChanged _session(
  DateTime at,
  SessionChange change, {
  String id = 'bl-48k',
  String subject = 'ocproof/gastown.furiosa',
  String? template,
}) => SessionChanged(
  sessionId: id,
  change: change,
  agentId: subject,
  seq: ++_seq,
  raw: {
    'seq': _seq,
    'type': 'session.${change.name}',
    'ts': at.toIso8601String(),
    'subject': subject,
    'session_id': id,
    'payload': {'session_id': id, 'template': ?template},
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String fixturePath;
  late SharedPreferences prefs;
  late OrchestrationStore store;
  late DateTime clock;

  setUp(() async {
    fixturePath = _findFixtureRoot().path;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = OrchestrationStore(prefs);
    clock = DateTime.utc(2026, 9, 11, 12, 30);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => call.method == 'readAll' ? <String, String>{} : null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  /// The recorded normal run as the controller would see it: every frame
  /// of `events/normal-run.ndjson` through the Gas City mapper.
  List<OrchestrationEvent> recordedRun() => [
    for (final line in File(
      '$fixturePath/events/normal-run.ndjson',
    ).readAsLinesSync())
      if (line.trim().isNotEmpty)
        mapStreamFrame(GcStreamFrame.fromJson(readMap(jsonDecode(line)))),
  ];

  /// The bead as the log last showed it (seq 1186, branch set).
  WorkItem recordedItem(List<OrchestrationEvent> log) {
    Map<String, Object?>? last;
    for (final event in log) {
      if (event is BeadChanged && event.beadId == 'oc-loy') {
        last = readMap(readMap(event.raw['payload'])['bead']);
      }
    }
    return mapBead(
      GcBead.fromJson(last!),
      context: const GcWorkContext(convoyByBead: {'oc-loy': 'oc-xru'}),
    );
  }

  DateTime host(String iso) => DateTime.parse(iso);

  OrchestrationConfig config() => OrchestrationConfig(
    provider: OrchestrationProvider.fixture,
    url: fixturePath,
    city: 'bright-lights',
    hostMode: OrchestrationHostMode.computer,
    enabledAt: DateTime.utc(2026, 9, 10),
  );

  Future<(OrchestrationController, _Gateway)> boot({
    void Function(_Gateway gateway)? configure,
  }) async {
    final gateway = _Gateway(
      FixtureOrchestrationGateway(fixturePath: fixturePath),
    );
    configure?.call(gateway);
    final cfg = config();
    final controller = OrchestrationController(
      profile: ServerProfile(
        id: 'srv-1',
        name: 'Workstation',
        baseUrl: 'https://server.example:4096',
        orchestration: cfg,
      ),
      config: cfg,
      store: store,
      gatewayFactory: (_, _) => gateway,
      now: () => clock,
      mutationTimeout: const Duration(seconds: 5),
    );
    addTearDown(controller.dispose);
    await controller.start();
    return (controller, gateway);
  }

  Widget app(
    Widget home, {
    bool reduceMotion = true,
    Locale locale = const Locale('en'),
    TextDirection? direction,
    double textScale = 1,
    bool scroll = true,
  }) => MaterialApp(
    theme: AppTheme.dark(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) {
      final wrapped = MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      );
      return direction == null
          ? wrapped
          : Directionality(textDirection: direction, child: wrapped);
    },
    home: scroll ? Scaffold(body: SingleChildScrollView(child: home)) : home,
  );

  Finder key(String name) => find.byKey(ValueKey(name));

  /// The step's Now line on the Work sheet (slice-P5.1: it replaced the
  /// strip), over the fixture's run.
  Future<void> pumpSheet(
    WidgetTester tester,
    OrchestrationController controller,
  ) async {
    await tester.pumpWidget(
      app(
        WorkSheet(
          controller: controller,
          workId: 'oc-loy',
          onJump: (_) {},
          now: () => clock,
        ),
      ),
    );
    await tester.pump();
  }

  String words(WidgetTester tester, String name) => tester
      .widgetList<RichText>(
        find.descendant(
          of: key(name),
          matching: find.byType(RichText),
          matchRoot: true,
        ),
      )
      .map((text) => text.text.toPlainText())
      .join(' ');

  // ---------------------------------------------------------------------
  // Derivation
  // ---------------------------------------------------------------------

  group('derivation', () {
    test('the recorded normal run yields the five timestamps in order', () {
      final log = recordedRun();
      final cycle = deriveDispatchCycle(
        item: recordedItem(log),
        timeline: log,
        now: host('2026-09-10T22:55:00+04:00'),
      );
      expect(
        cycle.reachedAt[DispatchStep.routed],
        host('2026-09-10T22:44:52.588680163+04:00'),
      );
      expect(
        cycle.reachedAt[DispatchStep.agentStarting],
        host('2026-09-10T22:44:59.362939687+04:00'),
      );
      expect(
        cycle.reachedAt[DispatchStep.claimed],
        host('2026-09-10T22:46:34.459669963+04:00'),
      );
      // The branch appeared at 22:51:04 (the agent records it when it
      // creates it; on the emulator that came at the claim, minutes before
      // any push), so the push is dated by the drain: the polecat's session
      // bead closed and its session stopped at 22:53:47, within a second.
      for (final step in [DispatchStep.pushed, DispatchStep.handedToMerge]) {
        expect(
          cycle.reachedAt[step]!
              .difference(host('2026-09-10T22:53:47.695156538+04:00'))
              .abs(),
          lessThan(const Duration(seconds: 1)),
          reason: step.name,
        );
      }
      // Working came with the worktree three seconds after the claim.
      final working = cycle.reachedAt[DispatchStep.working]!;
      expect(working.isAfter(cycle.reachedAt[DispatchStep.claimed]!), isTrue);
      expect(
        working.difference(cycle.reachedAt[DispatchStep.claimed]!),
        lessThan(const Duration(seconds: 5)),
      );
      final order = [
        for (final step in DispatchStep.values)
          if (cycle.reachedAt.containsKey(step)) cycle.reachedAt[step]!,
      ];
      for (var i = 1; i < order.length; i++) {
        expect(order[i].isBefore(order[i - 1]), isFalse, reason: 'step $i');
      }
      // The merge is what is awaited; a minute in, nothing stalls.
      expect(cycle.step, DispatchStep.merged);
      expect(cycle.isTerminal, isFalse);
      expect(cycle.stalled, isFalse);
      expect(cycle.since, cycle.reachedAt[DispatchStep.handedToMerge]);
      expect(cycle.position, 6);
    });

    test('the recorded run, cut after routing, waits for an agent', () {
      final log = recordedRun();
      final cut = [
        for (final event in log)
          if ((event.seq ?? 0) <= 1049) event,
      ];
      final item = _item(updatedAt: null);
      final early = deriveDispatchCycle(
        item: item,
        timeline: cut,
        now: host('2026-09-10T22:45:30+04:00'),
      );
      expect(early.step, DispatchStep.agentStarting);
      expect(early.hint, DispatchHint.usualWait);
      expect(early.stalled, isFalse);
      expect(early.position, 2);
      expect(early.since, early.reachedAt[DispatchStep.routed]);

      // The same evidence three minutes later: the host never started one.
      final late = deriveDispatchCycle(
        item: item,
        timeline: cut,
        now: host('2026-09-10T22:48:00+04:00'),
      );
      expect(late.stalled, isTrue);
      expect(late.stallReason, DispatchStall.hostNotStarted);
      expect(late.hint, isNull);

      // One frame further the polecat woke: agent starting reached.
      final woke = [
        for (final event in log)
          if ((event.seq ?? 0) <= 1050) event,
      ];
      final started = deriveDispatchCycle(
        item: item,
        timeline: woke,
        now: host('2026-09-10T22:48:00+04:00'),
      );
      expect(started.step, DispatchStep.claimed);
      expect(started.stalled, isFalse);
      expect(
        started.reachedAt[DispatchStep.agentStarting],
        host('2026-09-10T22:44:59.362939687+04:00'),
      );
    });

    test('a routed-only item with no events is agent starting', () {
      final cycle = deriveDispatchCycle(
        item: _item(updatedAt: clock.subtract(const Duration(minutes: 1))),
        now: clock,
      );
      expect(cycle.step, DispatchStep.agentStarting);
      expect(cycle.isDone(DispatchStep.routed), isTrue);
      expect(cycle.hint, DispatchHint.usualWait);
      expect(cycle.stalled, isFalse);
      expect(cycle.reachedAt.length, 1);
    });

    test('nothing known: routed pending, nothing reached', () {
      final cycle = deriveDispatchCycle(
        item: _item(routedTo: null, assignee: null),
        now: clock,
      );
      expect(cycle.step, DispatchStep.routed);
      expect(cycle.reachedAt, isEmpty);
      expect(cycle.since, isNull);
      expect(cycle.stalled, isFalse);
    });

    test('hostNotStarted: routed over three minutes, no agent', () {
      final at = clock.subtract(const Duration(minutes: 3, seconds: 1));
      final cycle = deriveDispatchCycle(
        item: _item(updatedAt: at),
        timeline: [_bead(at)],
        now: clock,
      );
      expect(cycle.stalled, isTrue);
      expect(cycle.stallReason, DispatchStall.hostNotStarted);
      expect(cycle.step, DispatchStep.agentStarting);

      final within = deriveDispatchCycle(
        item: _item(updatedAt: at),
        timeline: [_bead(at)],
        now: at.add(const Duration(minutes: 2, seconds: 59)),
      );
      expect(within.stalled, isFalse);
    });

    test('agentCannotStart: woke and stopped twice within a minute', () {
      final t0 = clock.subtract(const Duration(minutes: 2));
      final events = [
        _bead(t0),
        _session(
          t0.add(const Duration(seconds: 10)),
          SessionChange.woke,
          template: 'ocproof/gastown.polecat',
        ),
        _session(
          t0.add(const Duration(seconds: 30)),
          SessionChange.stopped,
          template: 'ocproof/gastown.polecat',
        ),
        _session(
          t0.add(const Duration(seconds: 45)),
          SessionChange.woke,
          template: 'ocproof/gastown.polecat',
        ),
        _session(
          t0.add(const Duration(seconds: 80)),
          SessionChange.stopped,
          template: 'ocproof/gastown.polecat',
        ),
      ];
      final cycle = deriveDispatchCycle(
        item: _item(updatedAt: t0),
        timeline: events,
        now: clock,
      );
      expect(cycle.stalled, isTrue);
      expect(cycle.stallReason, DispatchStall.agentCannotStart);
      expect(cycle.isDone(DispatchStep.agentStarting), isTrue);
      expect(cycle.step, DispatchStep.claimed);

      // One flap is not a pattern.
      final once = deriveDispatchCycle(
        item: _item(updatedAt: t0),
        timeline: events.take(3).toList(),
        now: clock,
      );
      expect(once.stalled, isFalse);

      // A session of another pool in the rig is not this item's.
      final other = deriveDispatchCycle(
        item: _item(updatedAt: t0),
        timeline: [
          _bead(t0),
          for (final event in events.skip(1))
            _session(
              DateTime.parse(event.raw['ts']! as String),
              (event as SessionChanged).change,
              id: 'bl-2e9',
              subject: 'gastown.boot',
              template: 'gastown.boot',
            ),
        ],
        now: clock,
      );
      expect(other.isDone(DispatchStep.agentStarting), isFalse);
      expect(other.stalled, isFalse);
    });

    test('providerLimit: the transcript names a usage limit', () {
      final t0 = clock.subtract(const Duration(minutes: 5));
      final item = _item(
        status: 'in_progress',
        assignee: 'gastown__polecat-bl-48k',
        sessionId: 'bl-48k',
        updatedAt: t0,
      );
      final cycle = deriveDispatchCycle(
        item: item,
        transcript:
            'Starting ACP…\nThe usage limit has been reached. Try again later.',
        now: clock,
      );
      expect(cycle.stalled, isTrue);
      expect(cycle.stallReason, DispatchStall.providerLimit);
      // Text in the transcript counts as working; the push is awaited.
      expect(cycle.isDone(DispatchStep.working), isTrue);
      expect(cycle.step, DispatchStep.pushed);

      final fine = deriveDispatchCycle(
        item: item,
        transcript: 'Reading calc.py…',
        now: clock,
      );
      expect(fine.stalled, isFalse);

      // A branch alone is still working (the agent names it early): the
      // words still count. Once the polecat drained after the branch, the
      // push happened and the same words are history.
      final branched = deriveDispatchCycle(
        item: _item(
          status: 'in_progress',
          assignee: 'gastown__polecat-bl-48k',
          sessionId: 'bl-48k',
          branch: 'polecat/oc-loy',
          updatedAt: t0,
        ),
        transcript: 'The usage limit has been reached',
        now: clock,
      );
      expect(branched.step, DispatchStep.pushed);
      expect(branched.stalled, isTrue);
      final pushed = deriveDispatchCycle(
        item: _item(
          status: 'in_progress',
          assignee: 'gastown__polecat-bl-48k',
          sessionId: 'bl-48k',
          branch: 'polecat/oc-loy',
          updatedAt: t0,
        ),
        timeline: [
          _session(t0.add(const Duration(minutes: 1)), SessionChange.stopped),
        ],
        transcript: 'The usage limit has been reached',
        now: clock,
      );
      expect(pushed.isDone(DispatchStep.pushed), isTrue);
      expect(pushed.stalled, isFalse);
    });

    test('the provider-limit words: usage limit, quota, rate limit', () {
      for (final text in const [
        'The usage limit has been reached',
        'USAGE LIMIT exceeded',
        'insufficient_quota: you have run out of quota',
        'Rate limit reached for gpt-5',
      ]) {
        expect(
          dispatchProviderLimitPattern.hasMatch(text),
          isTrue,
          reason: text,
        );
      }
      expect(dispatchProviderLimitPattern.hasMatch('all good'), isFalse);
    });

    test('workingLong: over thirty minutes with nothing pushed', () {
      final t0 = clock.subtract(const Duration(minutes: 31));
      final item = _item(
        status: 'in_progress',
        assignee: 'gastown__polecat-bl-48k',
        sessionId: 'bl-48k',
        workDir: '/city/.gc/worktrees/ocproof/polecats/gastown.furiosa',
        updatedAt: t0,
      );
      final cycle = deriveDispatchCycle(item: item, now: clock);
      expect(cycle.stalled, isTrue);
      expect(cycle.stallReason, DispatchStall.workingLong);
      expect(cycle.step, DispatchStep.pushed);

      final recent = deriveDispatchCycle(
        item: item,
        now: t0.add(const Duration(minutes: 29)),
      );
      expect(recent.stalled, isFalse);

      // Claimed with no worktree yet counts the same way.
      final claimed = deriveDispatchCycle(
        item: _item(
          status: 'in_progress',
          assignee: 'gastown__polecat-bl-48k',
          sessionId: 'bl-48k',
          updatedAt: t0,
        ),
        now: clock,
      );
      expect(claimed.step, DispatchStep.working);
      expect(claimed.stallReason, DispatchStall.workingLong);
    });

    test('mergeWaiting: handed to the refinery over fifteen minutes ago', () {
      final t0 = clock.subtract(const Duration(minutes: 16));
      final item = _item(
        status: 'open',
        assignee: 'ocproof/gastown.refinery',
        sessionId: 'bl-48k',
        branch: 'polecat/oc-loy',
        updatedAt: t0,
      );
      final cycle = deriveDispatchCycle(item: item, now: clock);
      expect(cycle.isDone(DispatchStep.handedToMerge), isTrue);
      expect(cycle.step, DispatchStep.merged);
      expect(cycle.stalled, isTrue);
      expect(cycle.stallReason, DispatchStall.mergeWaiting);

      final recent = deriveDispatchCycle(
        item: item,
        now: t0.add(const Duration(minutes: 14)),
      );
      expect(recent.stalled, isFalse);
    });

    // TEAM-117: the phone showed every step stamped with the minute the
    // app first looked, and no stall, for a bead handed to the refinery
    // the day before. Steps inferred from the item's fields take the
    // bead's `updated_at`, or no time at all; stalls count from the
    // bead's `updated_at`, else its `created_at`.
    test('handed to the refinery 20 h ago, no events: times are the '
        'bead\'s update, and the merge wait is a stall', () {
      final handedAt = clock.subtract(const Duration(hours: 20));
      final cycle = deriveDispatchCycle(
        item: _item(
          status: 'open',
          assignee: 'ocproof/gastown.refinery',
          sessionId: 'bl-48k',
          branch: 'polecat/oc-loy',
          workDir: '/city/.gc/worktrees/ocproof/polecats/gastown.furiosa',
          updatedAt: handedAt,
        ),
        now: clock,
      );
      expect(cycle.isDone(DispatchStep.handedToMerge), isTrue);
      expect(cycle.reachedAt[DispatchStep.handedToMerge], handedAt);
      expect(cycle.step, DispatchStep.merged);
      expect(cycle.isTerminal, isFalse);
      expect(cycle.since, handedAt);
      for (final step in DispatchStep.dots) {
        expect(cycle.reachedAt[step], handedAt, reason: step.name);
      }
      expect(cycle.stalled, isTrue);
      expect(cycle.stallReason, DispatchStall.mergeWaiting);
    });

    test('no timestamps at all: reached steps carry no time, and nothing '
        'counts as a stall', () {
      final item = _item(
        status: 'open',
        assignee: 'ocproof/gastown.refinery',
        sessionId: 'bl-48k',
        branch: 'polecat/oc-loy',
      );
      expect(item.updatedAt, isNull);
      expect(item.createdAt, isNull);
      final cycle = deriveDispatchCycle(item: item, now: clock);
      expect(cycle.isDone(DispatchStep.handedToMerge), isTrue);
      expect(cycle.reachedAt.containsKey(DispatchStep.handedToMerge), isTrue);
      expect(cycle.reachedAt[DispatchStep.handedToMerge], isNull);
      for (final step in DispatchStep.dots) {
        expect(cycle.isDone(step), isTrue, reason: step.name);
        expect(cycle.reachedAt[step], isNull, reason: step.name);
      }
      expect(cycle.since, isNull);
      expect(cycle.step, DispatchStep.merged);
      expect(cycle.stalled, isFalse);
      expect(cycle.stallReason, isNull);

      // The bead's `created_at` is the floor of the wait: created the
      // day before and still not merged is the merge stall, the steps
      // still untimed.
      final aged = deriveDispatchCycle(
        item: _item(
          status: 'open',
          assignee: 'ocproof/gastown.refinery',
          sessionId: 'bl-48k',
          branch: 'polecat/oc-loy',
          createdAt: clock.subtract(const Duration(hours: 20)),
        ),
        now: clock,
      );
      expect(aged.reachedAt[DispatchStep.handedToMerge], isNull);
      expect(aged.stalled, isTrue);
      expect(aged.stallReason, DispatchStall.mergeWaiting);

      // A routed-only bead with no time is agent starting, untimed.
      final routed = deriveDispatchCycle(item: _item(), now: clock);
      expect(routed.step, DispatchStep.agentStarting);
      expect(routed.reachedAt.containsKey(DispatchStep.routed), isTrue);
      expect(routed.reachedAt[DispatchStep.routed], isNull);
      expect(routed.stalled, isFalse);
      expect(routed.hint, DispatchHint.usualWait);
    });

    test('an event times a step the item left untimed; later untimed '
        'steps stay untimed', () {
      final t0 = clock.subtract(const Duration(hours: 1));
      final cycle = deriveDispatchCycle(
        item: _item(
          status: 'open',
          assignee: 'ocproof/gastown.refinery',
          branch: 'polecat/oc-loy',
        ),
        timeline: [_bead(t0)],
        now: clock,
      );
      expect(cycle.reachedAt[DispatchStep.routed], t0);
      expect(cycle.isDone(DispatchStep.handedToMerge), isTrue);
      expect(cycle.reachedAt[DispatchStep.handedToMerge], isNull);
      expect(cycle.since, isNull);
    });

    test('merged: closed bead, completed item or completed run end it', () {
      final t0 = clock.subtract(const Duration(hours: 2));
      final closed = deriveDispatchCycle(
        item: _item(status: 'closed', branch: 'polecat/oc-loy', updatedAt: t0),
        timeline: [_bead(t0, change: BeadChange.closed, status: 'closed')],
        now: clock,
      );
      expect(closed.isTerminal, isTrue);
      expect(closed.stalled, isFalse);
      expect(closed.hint, isNull);
      expect(closed.reachedAt.length, DispatchStep.values.length);

      final cancelled = deriveDispatchCycle(
        item: _item(status: 'open', updatedAt: t0),
        timeline: [
          _bead(
            t0,
            change: BeadChange.closed,
            status: 'closed',
            closeReason: 'cancelled by the person',
          ),
        ],
        now: clock,
      );
      expect(cancelled.isTerminal, isFalse);

      final run = deriveDispatchCycle(
        item: _item(updatedAt: t0),
        runCompleted: true,
        runCompletedAt: clock.subtract(const Duration(hours: 1)),
        now: clock,
      );
      expect(run.isTerminal, isTrue);
      expect(
        run.reachedAt[DispatchStep.merged],
        clock.subtract(const Duration(hours: 1)),
      );
    });
  });

  // ---------------------------------------------------------------------
  // Controller
  // ---------------------------------------------------------------------

  group('controller', () {
    testWidgets('cycleForRun is the least-advanced tracked item', (
      tester,
    ) async {
      final t0 = clock.subtract(const Duration(minutes: 1));
      final (controller, _) = await boot(
        configure: (g) => g.workOverride = [
          _item(id: 'w-pushed', branch: 'polecat/w', updatedAt: t0),
          _item(id: 'w-routed', updatedAt: t0),
          _item(id: 'w-done', status: 'closed', updatedAt: t0),
        ],
      );
      expect(controller.cycleWorkForRun('oc-xru'), 'w-routed');
      expect(
        controller.cycleForRun('oc-xru')!.step,
        DispatchStep.agentStarting,
      );
      expect(controller.cycleForRun('nope'), isNull);
      expect(controller.cycleFor('nope'), same(DispatchCycle.none));
    });

    testWidgets('the tick runs only while a Now line watches a moving '
        'cycle', (tester) async {
      final (controller, _) = await boot(
        configure: (g) => g.workOverride = [
          _item(updatedAt: clock.subtract(const Duration(minutes: 1))),
        ],
      );
      expect(controller.debugCycleTicking, isFalse);
      controller.cycleFor('oc-loy');
      expect(controller.debugCycleTicking, isFalse);
      await pumpSheet(tester, controller);
      expect(controller.debugCycleTicking, isTrue);
      expect(
        words(tester, 'team-work-sheet-now-text'),
        'Waiting for a worker · 1 min',
      );

      // Three minutes pass with no event: the tick re-derives and the
      // line now says why it waits, in the person's words.
      clock = clock.add(const Duration(minutes: 3));
      await tester.pump(const Duration(seconds: 31));
      expect(
        words(tester, 'team-work-sheet-now-text'),
        'Taking longer than expected · 4 min',
      );
      expect(
        words(tester, 'team-work-sheet-now-reason'),
        'No worker has been reported yet.',
      );

      await tester.pumpWidget(const SizedBox());
      expect(controller.debugCycleTicking, isFalse);
    });
  });

  // ---------------------------------------------------------------------
  // The step's Now line (slice-P5.1: it replaced the strip)
  // ---------------------------------------------------------------------

  group('now line', () {
    testWidgets('hostNotStarted: the reason in words and the Why in place, '
        'with Refresh; no engine step names', (tester) async {
      final t0 = clock.subtract(const Duration(minutes: 4));
      final (controller, _) = await boot(
        configure: (g) => g.workOverride = [_item(updatedAt: t0)],
      );
      await pumpSheet(tester, controller);
      expect(
        words(tester, 'team-work-sheet-now-reason'),
        'No worker has been reported yet.',
      );
      for (final engine in ['Routed', 'Claimed', 'Pushed', 'Handed to merge']) {
        expect(find.text(engine), findsNothing, reason: engine);
      }
      expect(key('team-work-sheet-now-why-fold'), findsNothing);
      await tester.tap(key('team-work-sheet-now-why'));
      await tester.pumpAndSettle();
      // What the retired "How the host dispatches" sheet said, in place.
      expect(
        find.text(
          'The team looks for new work regularly and starts a worker for '
          'it when one is free.',
        ),
        findsOneWidget,
      );
      final before = controller.lastRefreshedAt;
      clock = clock.add(const Duration(seconds: 5));
      await tester.tap(key('team-work-sheet-now-refresh'));
      await tester.pumpAndSettle();
      expect(controller.lastRefreshedAt, isNot(before));
    });

    testWidgets('providerLimit from the probed transcript: said as the AI '
        "service's limit", (tester) async {
      final t0 = clock.subtract(const Duration(minutes: 2));
      final (controller, gateway) = await boot(
        configure: (g) => g
          ..workOverride = [
            _item(
              status: 'in_progress',
              assignee: 'gastown__polecat-bl-48k',
              sessionId: 'bl-48k',
              updatedAt: t0,
            ),
          ]
          ..agentsOverride = const [
            OrchestrationAgent(
              id: 'gastown.furiosa',
              name: 'ocproof/gastown.furiosa',
              state: AgentState.working,
              sessionId: 'bl-48k',
              pool: 'ocproof/gastown.polecat',
            ),
          ]
          ..outputs['bl-48k'] = const [
            AgentOutputText('Starting ACP…\n'),
            AgentOutputText('The usage limit has been reached.\n'),
          ],
      );
      // Nobody watches the output yet: no probe, no stall.
      expect(controller.cycleFor('oc-loy').stalled, isFalse);
      expect(gateway.outputOpened, isEmpty);
      await pumpSheet(tester, controller);
      await tester.pumpAndSettle();
      expect(gateway.outputOpened, ['bl-48k']);
      expect(
        controller.cycleFor('oc-loy').stallReason,
        DispatchStall.providerLimit,
      );
      expect(
        words(tester, 'team-work-sheet-now-reason'),
        'The AI service reported a usage limit.',
      );
      expect(find.textContaining('model provider'), findsNothing);
    });

    testWidgets('workingLong: longer than expected, never "nothing is '
        'happening"', (tester) async {
      final t0 = clock.subtract(const Duration(minutes: 40));
      final (controller, _) = await boot(
        configure: (g) => g.workOverride = [
          _item(
            status: 'in_progress',
            assignee: 'gastown__polecat-bl-48k',
            sessionId: 'bl-48k',
            workDir: '/city/.gc/worktrees/ocproof/polecats/gastown.furiosa',
            updatedAt: t0,
          ),
        ],
      );
      await pumpSheet(tester, controller);
      expect(
        words(tester, 'team-work-sheet-now-reason'),
        'The work is taking longer than expected.',
      );
    });

    for (final (tag, locale, direction) in [
      ('ltr en', const Locale('en'), null),
      ('rtl ar', const Locale('ar'), TextDirection.rtl),
    ]) {
      testWidgets('320dp 2.5x $tag: the Now line and its Why fit', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final t0 = clock.subtract(const Duration(minutes: 4));
        final (controller, _) = await boot(
          configure: (g) => g.workOverride = [_item(updatedAt: t0)],
        );
        await tester.pumpWidget(
          app(
            WorkSheet(
              controller: controller,
              workId: 'oc-loy',
              onJump: (_) {},
              now: () => clock,
            ),
            locale: locale,
            direction: direction,
            textScale: 2.5,
          ),
        );
        await tester.pump();
        await tester.tap(key('team-work-sheet-now-why'));
        await tester.pumpAndSettle();
        expect(key('team-work-sheet-now-why-fold'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('placement', () {
    testWidgets('Task details shows the four stages (P3.5: the run page '
        'is retired)', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (controller, _) = await boot();
      await tester.pumpWidget(
        app(
          Scaffold(
            body: SingleChildScrollView(
              child: TeamTaskDetails(
                controller: controller,
                runId: 'oc-xru',
                now: () => clock,
              ),
            ),
          ),
          scroll: false,
        ),
      );
      await tester.pump();
      // The eight-step strip became four plain stages.
      expect(key('team-run-cycle'), findsNothing);
      expect(key('team-task-details-stage'), findsOneWidget);
      for (final stage in ['Waiting', 'Working', 'Reviewing', 'Done']) {
        expect(
          find.descendant(
            of: key('team-task-details-stage'),
            matching: find.text(stage),
          ),
          findsOneWidget,
          reason: stage,
        );
      }
    });

    testWidgets('the conversation says why it waits, with no time it cannot '
        'know (TEAM-117)', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (controller, _) = await boot();
      await tester.pumpWidget(
        app(
          TeamConversationScreen(
            team: controller,
            runId: 'oc-xru',
            now: () => clock,
          ),
          scroll: false,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // TEAM-117: routed a day ago with no agent is a stall, said in
      // words (slice-P5.1: the person's, not the host's); the routing time
      // is unknown, so no time is invented.
      final now = key('team-conversation-now-text');
      expect(now, findsOneWidget);
      expect(
        words(tester, 'team-conversation-now-text'),
        'Taking longer than expected',
      );
      expect(
        words(tester, 'team-conversation-now-reason'),
        'No worker has been reported yet.',
      );
      expect(
        find.descendant(
          of: now,
          matching: find.textContaining(
            MaterialLocalizations.of(
              tester.element(find.byType(TeamConversationScreen)),
            ).formatTimeOfDay(
              TimeOfDay.fromDateTime(clock.toLocal()),
              alwaysUse24HourFormat: true,
            ),
            findRichText: true,
          ),
        ),
        findsNothing,
      );
    });

    testWidgets("the Work sheet's first part is the step's Now line", (
      tester,
    ) async {
      final t0 = clock.subtract(const Duration(minutes: 1));
      final (controller, _) = await boot(
        configure: (g) => g
          ..workOverride = [
            _item(
              status: 'in_progress',
              assignee: 'gastown__polecat-bl-48k',
              sessionId: 'bl-48k',
              updatedAt: t0,
            ),
          ]
          ..outputs['bl-48k'] = const [],
      );
      await pumpSheet(tester, controller);
      expect(key('team-work-sheet-now'), findsOneWidget);
      expect(
        tester.getTopLeft(key('team-work-sheet-now')).dy,
        lessThan(tester.getTopLeft(key('team-work-sheet-owner')).dy),
      );
      // The title is the kit sheet's own header (screen-team-3).
      expect(key('team-work-sheet-title'), findsNothing);
      expect(
        words(tester, 'team-work-sheet-now-text'),
        startsWith('Working on your task'),
      );
      expect(
        words(tester, 'team-work-sheet-now-next'),
        'Next: the changes are reviewed',
      );
    });
  });
}
