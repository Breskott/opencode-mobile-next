// TEAM-116: the dispatch cycle. Derivation over the recorded normal-run
// event log and over hand-built evidence (each stall reason with its
// window), the provider-limit regex over a transcript, the strip's
// done / current / future rendering, reduced motion, 320dp at 2.5x in
// both directions and both languages, and the placement on the card,
// the run Overview and the Work sheet.

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
import 'package:opencode_mobile/ui/screens/team/agent_output_screen.dart';
import 'package:opencode_mobile/ui/screens/team/run_screen.dart';
import 'package:opencode_mobile/ui/screens/team/work_sheet.dart';
import 'package:opencode_mobile/ui/widgets/team_card.dart';
import 'package:opencode_mobile/ui/widgets/team_cycle_strip.dart';
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

  /// Lets a sent control's receipt timer run out so no timer outlives
  /// the test.
  Future<void> drain(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
  }

  /// Pushes [events] through the stream and lets the debounce refetch.
  Future<void> feed(
    WidgetTester tester,
    _Gateway gateway,
    List<OrchestrationEvent> events,
  ) async {
    for (final event in events) {
      gateway.stream.add(event);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
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

  String clockLabel(WidgetTester tester, DateTime at) =>
      MaterialLocalizations.of(
        tester.element(find.byType(TeamCycleStrip)),
      ).formatTimeOfDay(
        TimeOfDay.fromDateTime(at.toLocal()),
        alwaysUse24HourFormat: true,
      );

  Future<String> semanticsOf(WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    await tester.pump();
    final strip = key('team-cycle-strip');
    final node = tester.getSemantics(
      find
          .descendant(
            of: strip,
            matching: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.label != null,
            ),
          )
          .first,
    );
    final label = node.label;
    handle.dispose();
    return label;
  }

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
      expect(teamCycleCurrentStep(cycle), DispatchStep.handedToMerge);
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

    testWidgets('the tick runs only while a strip watches a moving cycle', (
      tester,
    ) async {
      final (controller, _) = await boot(
        configure: (g) => g.workOverride = [
          _item(updatedAt: clock.subtract(const Duration(minutes: 1))),
        ],
      );
      expect(controller.debugCycleTicking, isFalse);
      controller.cycleFor('oc-loy');
      expect(controller.debugCycleTicking, isFalse);
      await tester.pumpWidget(
        app(TeamCycleStrip(controller: controller, workId: 'oc-loy')),
      );
      await tester.pump();
      expect(controller.debugCycleTicking, isTrue);
      expect(
        find.text('Waiting for an agent · usually 1–5 min'),
        findsOneWidget,
      );

      // Three minutes pass with no event: the tick re-derives and the
      // strip now says why it waits.
      clock = clock.add(const Duration(minutes: 3));
      await tester.pump(const Duration(seconds: 31));
      expect(
        find.text('The host has not started an agent yet'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      expect(controller.debugCycleTicking, isFalse);
    });
  });

  // ---------------------------------------------------------------------
  // Strip
  // ---------------------------------------------------------------------

  group('strip', () {
    testWidgets('done steps carry a check and time, the current step '
        'pulses, the rest sit dim', (tester) async {
      final t0 = clock.subtract(const Duration(minutes: 4));
      final t1 = t0.add(const Duration(minutes: 1, seconds: 7));
      final t2 = t0.add(const Duration(minutes: 2, seconds: 40));
      final (controller, gateway) = await boot(
        configure: (g) => g
          ..workOverride = [
            _item(
              status: 'in_progress',
              assignee: 'gastown__polecat-bl-48k',
              sessionId: 'bl-48k',
              updatedAt: t2,
            ),
          ]
          // The agent has said nothing yet: no output, so not working.
          ..outputs['bl-48k'] = const [],
      );
      await tester.pumpWidget(
        app(
          TeamCycleStrip(controller: controller, workId: 'oc-loy'),
          reduceMotion: false,
        ),
      );
      await feed(tester, gateway, [
        _bead(t0),
        _session(t1, SessionChange.woke),
        _bead(
          t2,
          status: 'in_progress',
          assignee: 'gastown__polecat-bl-48k',
          metadata: const {
            'gc.routed_to': 'ocproof/gastown.polecat',
            'gc.session_id': 'bl-48k',
          },
        ),
      ]);
      final cycle = controller.cycleFor('oc-loy');
      expect(cycle.step, DispatchStep.working);
      expect(cycle.reachedAt[DispatchStep.routed], t0);
      expect(cycle.reachedAt[DispatchStep.agentStarting], t1);
      expect(cycle.reachedAt[DispatchStep.claimed], t2);

      for (final step in DispatchStep.dots) {
        expect(key('team-cycle-step-${step.name}'), findsOneWidget);
      }
      expect(key('team-cycle-end'), findsOneWidget);
      // Done steps show their time.
      expect(find.text(clockLabel(tester, t0)), findsOneWidget);
      expect(find.text(clockLabel(tester, t1)), findsOneWidget);
      expect(find.text(clockLabel(tester, t2)), findsOneWidget);
      // The current step is the only one that breathes.
      final state = tester.state<TeamCycleStripState>(
        find.byType(TeamCycleStrip),
      );
      expect(state.debugHasAnimation, isTrue);
      expect(
        find.descendant(
          of: key('team-cycle-strip'),
          matching: find.byType(ScaleTransition),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: key('team-cycle-step-working'),
          matching: find.byType(ScaleTransition),
        ),
        findsOneWidget,
      );
      expect(
        await semanticsOf(tester),
        'Step 4 of 6, Working, since ${clockLabel(tester, t2)}',
      );
      expect(key('team-cycle-hint'), findsNothing);
      expect(key('team-cycle-stall'), findsNothing);
      expect(key('team-cycle-actions'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion: static, no ticker; merged: none either', (
      tester,
    ) async {
      final t0 = clock.subtract(const Duration(minutes: 1));
      final (controller, gateway) = await boot(
        configure: (g) => g.workOverride = [_item(updatedAt: t0)],
      );
      await tester.pumpWidget(
        app(TeamCycleStrip(controller: controller, workId: 'oc-loy')),
      );
      await tester.pump();
      final state = tester.state<TeamCycleStripState>(
        find.byType(TeamCycleStrip),
      );
      expect(state.debugHasAnimation, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
      expect(
        find.descendant(
          of: key('team-cycle-strip'),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
      expect(
        await semanticsOf(tester),
        'Step 2 of 6, Agent starting, since ${clockLabel(tester, t0)}',
      );
      expect(
        find.text('Waiting for an agent · usually 1–5 min'),
        findsOneWidget,
      );

      // Merged with motion allowed: still no controller.
      gateway.workOverride = [
        _item(status: 'closed', branch: 'polecat/oc-loy', updatedAt: clock),
      ];
      await tester.pumpWidget(
        app(
          TeamCycleStrip(controller: controller, workId: 'oc-loy'),
          reduceMotion: false,
        ),
      );
      await feed(tester, gateway, [
        _bead(clock, change: BeadChange.closed, status: 'closed'),
      ]);
      expect(controller.cycleFor('oc-loy').isTerminal, isTrue);
      final merged = tester.state<TeamCycleStripState>(
        find.byType(TeamCycleStrip),
      );
      expect(merged.debugHasAnimation, isFalse);
      expect(
        find.descendant(
          of: key('team-cycle-strip'),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
      expect(
        await semanticsOf(tester),
        'All 6 steps done, merged at ${clockLabel(tester, clock)}',
      );
      expect(controller.debugCycleTicking, isFalse);
    });

    testWidgets('hostNotStarted: sentence, Refresh and the How sheet', (
      tester,
    ) async {
      final t0 = clock.subtract(const Duration(minutes: 4));
      final (controller, _) = await boot(
        configure: (g) => g.workOverride = [_item(updatedAt: t0)],
      );
      await tester.pumpWidget(
        app(TeamCycleStrip(controller: controller, workId: 'oc-loy')),
      );
      await tester.pump();
      expect(
        find.text('The host has not started an agent yet'),
        findsOneWidget,
      );
      expect(key('team-cycle-hint'), findsNothing);
      expect(key('team-cycle-action-refresh'), findsOneWidget);
      expect(key('team-cycle-action-how'), findsOneWidget);

      await tester.tap(key('team-cycle-action-how'));
      await tester.pumpAndSettle();
      expect(key('team-cycle-how-sheet'), findsOneWidget);
      expect(
        find.text(
          'The first model turn takes 10–60 seconds before the agent claims '
          'the work, so 2–6 minutes from routed to claimed is normal.',
        ),
        findsOneWidget,
      );
      await tester.tap(key('team-cycle-how-close'));
      await tester.pumpAndSettle();
      expect(key('team-cycle-how-sheet'), findsNothing);

      final before = controller.lastRefreshedAt;
      clock = clock.add(const Duration(seconds: 5));
      await tester.tap(key('team-cycle-action-refresh'));
      await tester.pumpAndSettle();
      expect(controller.lastRefreshedAt, isNot(before));
    });

    testWidgets('agentCannotStart: sentence and the How sheet first', (
      tester,
    ) async {
      final t0 = clock.subtract(const Duration(minutes: 2));
      final (controller, gateway) = await boot(
        configure: (g) => g.workOverride = [_item(updatedAt: t0)],
      );
      await tester.pumpWidget(
        app(TeamCycleStrip(controller: controller, workId: 'oc-loy')),
      );
      await feed(tester, gateway, [
        _bead(t0),
        for (var i = 0; i < 2; i++) ...[
          _session(
            t0.add(Duration(seconds: 10 + i * 40)),
            SessionChange.woke,
            template: 'ocproof/gastown.polecat',
          ),
          _session(
            t0.add(Duration(seconds: 30 + i * 40)),
            SessionChange.stopped,
            template: 'ocproof/gastown.polecat',
          ),
        ],
      ]);
      expect(
        find.text('The agent could not start on the host'),
        findsOneWidget,
      );
      final buttons = tester
          .widgetList(
            find.descendant(
              of: key('team-cycle-actions'),
              matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
            ),
          )
          .toList();
      expect(buttons.length, 2);
      expect(buttons.first.key, const ValueKey('team-cycle-action-how'));
      expect(buttons.last.key, const ValueKey('team-cycle-action-refresh'));
    });

    testWidgets('providerLimit from the probed transcript: Open agent '
        'output, and Stop in two steps', (tester) async {
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
            OrchestrationAgent(
              id: 'gastown.refinery',
              name: 'ocproof/gastown.refinery',
              state: AgentState.idle,
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

      await tester.pumpWidget(
        app(TeamCycleStrip(controller: controller, workId: 'oc-loy')),
      );
      await tester.pumpAndSettle();
      expect(gateway.outputOpened, ['bl-48k']);
      expect(controller.debugCycleProbes, {'bl-48k'});
      expect(
        controller.cycleTranscriptFor('oc-loy'),
        contains('usage limit has been reached'),
      );
      final cycle = controller.cycleFor('oc-loy');
      expect(cycle.stallReason, DispatchStall.providerLimit);
      expect(
        find.text('The model provider reached its usage limit'),
        findsOneWidget,
      );
      expect(key('team-cycle-action-output'), findsOneWidget);
      expect(key('team-cycle-action-stop'), findsOneWidget);
      expect(controller.cycleAgentFor('oc-loy'), 'gastown.furiosa');

      // Open agent output → the AgentOutputScreen for that agent.
      await tester.tap(key('team-cycle-action-output'));
      await tester.pumpAndSettle();
      expect(find.byType(AgentOutputScreen), findsOneWidget);
      expect(
        tester
            .widget<AgentOutputScreen>(find.byType(AgentOutputScreen))
            .agentId,
        'gastown.furiosa',
      );
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      // Stop: the first tap asks, backing out sends nothing.
      await tester.tap(key('team-cycle-action-stop'));
      await tester.pumpAndSettle();
      expect(key('team-cycle-stop-confirm'), findsOneWidget);
      expect(find.text('Stop ocproof/gastown.furiosa?'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(gateway.inner.controlCalls, isEmpty);

      await tester.tap(key('team-cycle-action-stop'));
      await tester.pumpAndSettle();
      await tester.tap(key('team-cycle-stop-confirm-action'));
      await tester.pumpAndSettle();
      expect(gateway.inner.controlCalls.length, 1);
      expect(gateway.inner.controlCalls.single.verb, 'controlAgent');
      expect(gateway.inner.controlCalls.single.target, 'gastown.furiosa');
      expect(gateway.inner.controlCalls.single.arg, AgentControlAction.stop);
      expect(key('team-cycle-receipt'), findsOneWidget);
      await drain(tester);

      // Leaving the strip releases the probe; the text stays.
      await tester.pumpWidget(const SizedBox());
      expect(controller.debugCycleProbes, isEmpty);
      expect(controller.cycleTranscriptFor('oc-loy'), isNotNull);
    });

    testWidgets('providerLimit without controls: no Stop', (tester) async {
      final t0 = clock.subtract(const Duration(minutes: 2));
      final (controller, _) = await boot(
        configure: (g) => g
          ..capabilitiesOverride = const OrchestrationCapabilities(
            runs: true,
            agents: true,
            agentOutput: true,
            eventStream: true,
          )
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
            ),
          ]
          ..outputs['bl-48k'] = const [
            AgentOutputText('Error: quota exceeded for this account'),
          ],
      );
      await tester.pumpWidget(
        app(TeamCycleStrip(controller: controller, workId: 'oc-loy')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('The model provider reached its usage limit'),
        findsOneWidget,
      );
      expect(key('team-cycle-action-output'), findsOneWidget);
      expect(key('team-cycle-action-stop'), findsNothing);
    });

    testWidgets('workingLong: sentence and Open agent output', (tester) async {
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
      await tester.pumpWidget(
        app(TeamCycleStrip(controller: controller, workId: 'oc-loy')),
      );
      await tester.pump();
      expect(
        find.text("Still working — check the agent's output"),
        findsOneWidget,
      );
      expect(key('team-cycle-action-output'), findsOneWidget);
      expect(key('team-cycle-action-stop'), findsNothing);
      expect(key('team-cycle-action-refresh'), findsNothing);
    });

    testWidgets('TEAM-117: the refinery bead the day before, no update time: '
        'checks without times, the merge sentence, never the clock', (
      tester,
    ) async {
      final item = _item(
        assignee: 'ocproof/gastown.refinery',
        sessionId: 'bl-48k',
        branch: 'polecat/oc-loy',
        createdAt: clock.subtract(const Duration(hours: 20)),
      );
      final (controller, _) = await boot(
        configure: (g) => g..workOverride = [item],
      );
      await tester.pumpWidget(
        app(TeamCycleStrip(controller: controller, workId: 'oc-loy')),
      );
      await tester.pump();
      for (final step in DispatchStep.dots) {
        expect(key('team-cycle-step-${step.name}'), findsOneWidget);
      }
      expect(
        find.descendant(
          of: key('team-cycle-strip'),
          matching: find.textContaining(clockLabel(tester, clock)),
        ),
        findsNothing,
      );
      expect(find.text('Handed to merge'), findsOneWidget);
      expect(find.text('Waiting for the merge agent'), findsOneWidget);
      expect(await semanticsOf(tester), 'Step 6 of 6, Handed to merge');
    });

    testWidgets('mergeWaiting: Nudge refinery with controls, Refresh '
        'without', (tester) async {
      final t0 = clock.subtract(const Duration(minutes: 20));
      final item = _item(
        assignee: 'ocproof/gastown.refinery',
        sessionId: 'bl-48k',
        branch: 'polecat/oc-loy',
        updatedAt: t0,
      );
      final (controller, gateway) = await boot(
        configure: (g) => g
          ..workOverride = [item]
          ..agentsOverride = const [
            OrchestrationAgent(
              id: 'gastown.refinery',
              name: 'ocproof/gastown.refinery',
              state: AgentState.idle,
            ),
          ],
      );
      await tester.pumpWidget(
        app(TeamCycleStrip(controller: controller, workId: 'oc-loy')),
      );
      await tester.pump();
      expect(find.text('Waiting for the merge agent'), findsOneWidget);
      expect(key('team-cycle-action-nudge'), findsOneWidget);
      expect(controller.cycleRefineryFor('oc-loy'), 'gastown.refinery');
      await tester.tap(key('team-cycle-action-nudge'));
      await tester.pumpAndSettle();
      expect(gateway.inner.controlCalls.single.target, 'gastown.refinery');
      expect(gateway.inner.controlCalls.single.arg, AgentControlAction.nudge);
      await drain(tester);

      final (readOnly, _) = await boot(
        configure: (g) => g
          ..capabilitiesOverride = const OrchestrationCapabilities(
            runs: true,
            agents: true,
            eventStream: true,
          )
          ..workOverride = [item],
      );
      await tester.pumpWidget(
        app(TeamCycleStrip(controller: readOnly, workId: 'oc-loy')),
      );
      await tester.pump();
      expect(key('team-cycle-action-nudge'), findsNothing);
      expect(key('team-cycle-action-refresh'), findsOneWidget);
    });

    for (final direction in TextDirection.values) {
      for (final locale in const [Locale('en'), Locale('ar')]) {
        final tag = '${direction.name} ${locale.languageCode}';
        testWidgets('320dp 2.5x $tag: the strip wraps to rows and fits', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final t0 = clock.subtract(const Duration(minutes: 4));
          final (controller, _) = await boot(
            configure: (g) => g.workOverride = [_item(updatedAt: t0)],
          );
          await tester.pumpWidget(
            app(
              TeamCycleStrip(controller: controller, workId: 'oc-loy'),
              locale: locale,
              direction: direction,
              textScale: 2.5,
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(tester.getSize(key('team-cycle-strip')).width, 320);
          final tops = {
            for (final step in DispatchStep.dots)
              tester.getTopLeft(key('team-cycle-step-${step.name}')).dy,
          };
          expect(tops.length, greaterThanOrEqualTo(2));
          for (final step in DispatchStep.dots) {
            final rect = tester.getRect(key('team-cycle-step-${step.name}'));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(320));
          }
          expect(key('team-cycle-stall'), findsOneWidget);
          expect(key('team-cycle-action-refresh'), findsOneWidget);
          if (locale.languageCode == 'ar') {
            expect(find.text('لم يبدأ المضيف وكيلًا بعد'), findsOneWidget);
            expect(find.text('الوكيل يبدأ'), findsOneWidget);
          } else {
            expect(
              find.text('The host has not started an agent yet'),
              findsOneWidget,
            );
          }
          final refresh = key('team-cycle-action-refresh');
          await tester.ensureVisible(refresh);
          await tester.pump();
          expect(refresh.hitTestable(), findsOneWidget);
        });
      }
    }
  });

  // ---------------------------------------------------------------------
  // Placement
  // ---------------------------------------------------------------------

  group('placement', () {
    testWidgets('the card shows the compact strip under its headline '
        'batch row', (tester) async {
      // The fixture convoy tracks oc-loy, routed and waiting for an agent.
      // The recorded bead carries no `updated_at` (TEAM-117): the routing
      // is reached at an unknown time, so the line names no time — never
      // the moment the app looked — and, created the day before with no
      // agent, the wait is a stall rather than the usual one.
      final (controller, gateway) = await boot();
      await tester.pumpWidget(
        app(TeamCard(controller: controller, onOpen: () {})),
      );
      await tester.pump();
      expect(key('team-card-cycle'), findsOneWidget);
      expect(
        tester.getTopLeft(key('team-card-cycle')).dy,
        greaterThan(tester.getTopLeft(key('team-card-run-oc-xru')).dy),
      );
      expect(key('team-cycle-current'), findsOneWidget);
      expect(
        tester.widget<Text>(key('team-cycle-current')).data,
        'Agent starting',
      );
      expect(
        find.descendant(
          of: key('team-card-cycle'),
          matching: find.textContaining(clockLabel(tester, clock)),
        ),
        findsNothing,
      );
      expect(
        find.text('The host has not started an agent yet'),
        findsOneWidget,
      );
      // Compact: dots, no chips, no buttons.
      expect(key('team-cycle-dot-routed'), findsOneWidget);
      expect(key('team-cycle-step-routed'), findsNothing);
      expect(key('team-cycle-actions'), findsNothing);
      expect(await semanticsOf(tester), 'Step 2 of 6, Agent starting');

      // A completed batch shows no strip.
      gateway.runsOverride = [
        OrchestrationRun(
          id: 'oc-xru',
          title: 'Add subtract function to calc.py',
          state: RunState.completed,
          kind: RunKind.batch,
          stepCount: 1,
          completedSteps: 1,
          updatedAt: clock,
        ),
      ];
      await controller.refresh();
      await tester.pump();
      expect(key('team-card-cycle'), findsNothing);
    });

    testWidgets('the run Overview shows the full strip over the batch '
        'line, and nothing for a formula run', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (controller, _) = await boot();
      await tester.pumpWidget(
        app(
          RunScreen(controller: controller, runId: 'oc-xru', now: () => clock),
          scroll: false,
        ),
      );
      await tester.pump();
      expect(key('team-run-cycle'), findsOneWidget);
      expect(key('team-run-batch'), findsOneWidget);
      expect(
        tester.getTopLeft(key('team-run-cycle')).dy,
        lessThan(tester.getTopLeft(key('team-run-batch')).dy),
      );
      expect(key('team-cycle-step-agentStarting'), findsOneWidget);
      // TEAM-117: the routed step's check carries no time (the bead has
      // no `updated_at`), and a day without an agent is a stall.
      expect(key('team-cycle-step-routed'), findsOneWidget);
      expect(
        find.descendant(
          of: key('team-run-cycle'),
          matching: find.textContaining(clockLabel(tester, clock)),
        ),
        findsNothing,
      );
      expect(
        find.text('The host has not started an agent yet'),
        findsOneWidget,
      );

      final formula = (await controller.gateway!.runs())
          .where((r) => r.kind == RunKind.formula)
          .firstOrNull;
      if (formula != null) {
        await tester.pumpWidget(
          app(
            RunScreen(
              controller: controller,
              runId: formula.id,
              now: () => clock,
            ),
            scroll: false,
          ),
        );
        await tester.pump();
        expect(key('team-run-cycle'), findsNothing);
      }
    });

    testWidgets('the Work sheet shows the full strip at the top', (
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
      await tester.pumpWidget(
        app(
          WorkSheet(controller: controller, workId: 'oc-loy', onJump: (_) {}),
        ),
      );
      await tester.pump();
      expect(key('team-work-sheet-cycle'), findsOneWidget);
      expect(
        tester.getTopLeft(key('team-work-sheet-cycle')).dy,
        lessThan(tester.getTopLeft(key('team-work-sheet-state')).dy),
      );
      expect(
        tester.getTopLeft(key('team-work-sheet-cycle')).dy,
        greaterThan(tester.getTopLeft(key('team-work-sheet-title')).dy),
      );
      expect(key('team-cycle-step-claimed'), findsOneWidget);
      expect(
        await semanticsOf(tester),
        'Step 4 of 6, Working, since ${clockLabel(tester, t0)}',
      );
    });
  });
}
