/// The AI Team plugin's controller: one per profile whose
/// [ServerProfile.orchestration] is set, constructed and disposed by
/// `ConnectionController` and never embedded in it (04-plugin-architecture
/// §1, §9).
///
/// Lifecycle: [start] probes the host, builds the adapter for the
/// configured provider, subscribes to its event stream and refreshes every
/// scope. Events do not carry data into the snapshot; they mark scopes
/// dirty and a short debounce refetches only those (§5). The timeline is
/// append-only from events and bounded. [stop] closes the gateway;
/// [remove] also sweeps the profile's store so turning the plugin off
/// leaves no trace.
///
/// Writes (TEAM-202, §6) go through [mutate] and its typed helpers
/// ([answerGate], [messageAgent], [controlAgent], [cancelRun],
/// [assignWork], [createWork] and the two-step [giveTask]): a [MutationRecord] with a fresh idempotency key is
/// persisted BEFORE the gateway is called, the receipt updates it, and the
/// host's matching `request.result` event (or the effect's own event)
/// marks it confirmed. A record still sent after [mutationTimeout] becomes
/// unconfirmed; so does every sent record found on restart. Nothing is
/// ever re-sent by the controller: [retryMutation] makes a new record
/// under a new key and only when a person asks.
///
/// Merge (TEAM-205): [mergeReadiness] reads the host front's readiness
/// document per run and caches it until [refresh]; [approveMergeRequest]
/// and [mergeRun] are ordinary mutations through the same path, allowed
/// only when the adapter implements [OrchestrationMergeGateway].
///
/// Policy (TEAM-207): [policy] is the host's read-only supervision level
/// and boundaries, read with the projects scope on every refresh when the
/// adapter implements [OrchestrationPolicyGateway] (a host front) and
/// null otherwise, so the run overview and the Start-a-run sheet show the
/// host's rules or nothing.
///
/// Dispatch cycle (TEAM-116): [cycleFor] derives where a work item is in
/// the host's dispatch chain (routed → agent starting → claimed → working
/// → pushed → handed to merge → merged) and why it waits, from the
/// snapshot, the timeline and the agent's transcript. Cycles are derived
/// on demand and cached until the next event, refresh or tick; the tick
/// ([cycleTick], 30 s) runs only while a strip watches ([watchCycles]) and
/// some cycle is still moving, and while watched the controller reads the
/// transcript of an agent that claimed but has not pushed, so a provider
/// usage limit surfaces as the stall reason without anyone opening the
/// output.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../domain/orchestration_gateway.dart';
import '../orchestration/adapters/fixture/fixture_gateway.dart';
import '../orchestration/adapters/gascity/gascity_gateway.dart';
import '../orchestration/adapters/gascity/gascity_mappers.dart'
    show mapStreamFrame;
import '../orchestration/adapters/gascity/gascity_probe.dart';
import '../orchestration/client/sse.dart';
import '../orchestration/dispatch.dart';
import 'orchestration_store.dart';
import 'profiles.dart';

export '../orchestration/adapters/gascity/gascity_probe.dart'
    show
        ProbeCityNotRunning,
        ProbeFound,
        ProbeNotGasCity,
        ProbePlainHttpRefused,
        ProbeUnreachable,
        ProbeVerdict;
export '../orchestration/client/sse.dart' show OrchestrationStreamStatus;
export '../orchestration/dispatch.dart'
    show deriveDispatchCycle, isRefineryName, workHandedToMerge;
export 'mutation_store.dart'
    show MutationKind, MutationRecord, MutationRequest, MutationStatus;

/// Mints one idempotency key per mutation.
typedef MutationKeyMinter = String Function();

/// Default: a version-4 UUID.
String mintMutationKey() => const Uuid().v4();

/// Probes the host described by a config. Never throws.
typedef OrchestrationProbe =
    Future<ProbeVerdict> Function(OrchestrationConfig config);

/// Builds the adapter for a config once the probe [found] the host.
typedef OrchestrationGatewayFactory =
    FutureOr<OrchestrationGateway> Function(
      OrchestrationConfig config,
      ProbeFound found,
    );

/// Why the plugin has no usable host, in a form the UI can map to copy.
enum OrchestrationErrorKind {
  /// The URL answered, but not like a Gas City supervisor.
  notGasCity,

  /// A Gas City answered, but the configured city is not running.
  cityNotRunning,

  /// `http://` to a host that is neither loopback nor tailnet.
  plainHttpRefused,

  /// No answer at all (DNS, refused, timeout, TLS, bad URL).
  unreachable,

  /// The host was reached but a read failed; cached data stays on show.
  readFailed,
}

/// The last thing that went wrong, with the probe verdict when there was
/// one so Technical details can show what the host said.
class OrchestrationError {
  const OrchestrationError(this.kind, this.message, {this.verdict});

  final OrchestrationErrorKind kind;
  final String message;
  final ProbeVerdict? verdict;

  /// Null for [ProbeFound]; otherwise the matching kind.
  static OrchestrationError? fromVerdict(ProbeVerdict verdict) =>
      switch (verdict) {
        ProbeFound() => null,
        ProbeNotGasCity() => OrchestrationError(
          OrchestrationErrorKind.notGasCity,
          verdict.describe(),
          verdict: verdict,
        ),
        ProbeCityNotRunning() => OrchestrationError(
          OrchestrationErrorKind.cityNotRunning,
          verdict.describe(),
          verdict: verdict,
        ),
        ProbePlainHttpRefused() => OrchestrationError(
          OrchestrationErrorKind.plainHttpRefused,
          verdict.describe(),
          verdict: verdict,
        ),
        ProbeUnreachable() => OrchestrationError(
          OrchestrationErrorKind.unreachable,
          verdict.describe(),
          verdict: verdict,
        ),
      };

  @override
  String toString() => 'OrchestrationError(${kind.name}: $message)';
}

/// Where the controller is in its lifecycle.
enum OrchestrationPhase {
  /// Constructed; [OrchestrationController.start] not called yet.
  idle,
  probing,
  connecting,

  /// Gateway built and subscribed; data flows.
  ready,

  /// The probe or the adapter refused; see
  /// [OrchestrationController.lastError].
  failed,

  /// [OrchestrationController.stop] ran; nothing more will arrive.
  stopped,
}

/// Names of the refetchable scopes an event can mark dirty (§5).
abstract final class OrchestrationScope {
  static const projects = 'projects';
  static const runs = 'runs';
  static const work = 'work';
  static const agents = 'agents';
  static const gates = 'gates';
  static const usage = 'usage';
  static const activity = 'activity';

  /// One run by id; subsumed by [runs] when both are dirty.
  static String run(String id) => 'run:$id';

  /// One agent by id; subsumed by [agents] when both are dirty.
  static String agent(String id) => 'agent:$id';

  /// Every list scope: what a full refresh or a head-only replay fetches.
  static const all = {projects, runs, work, agents, gates, usage, activity};
}

/// One scope's result folded into a snapshot.
typedef _Fold = OrchestrationSnapshot Function(OrchestrationSnapshot s);

/// An agent's live output as the controller holds it: the merged text so
/// far, whether the host still serves the session, and whether a stream
/// is open. The text survives the screen that watched it, so a session
/// that ended still shows what was cached (02-ux §5.2).
class AgentOutputTail extends ChangeNotifier {
  AgentOutputTail(this.agentId, {required this.sessionId});

  final String agentId;

  /// The session the output belongs to; null when the agent has none, in
  /// which case [available] is false.
  final String? sessionId;

  String _text = '';
  bool _available = true;
  bool _ended = false;
  bool _watching = false;
  bool _received = false;
  String? _endReason;
  Object? _error;

  /// Merged transcript, at most [agentOutputLimit] characters.
  String get text => _text;

  /// False when the adapter cannot serve output for this agent.
  bool get available => _available;

  /// The host stopped serving the session (404); nothing more arrives.
  bool get ended => _ended;

  /// Host-provided detail for [ended], when any.
  String? get endReason => _endReason;

  /// A stream is open and may still deliver text.
  bool get watching => _watching;

  /// At least one capture arrived since the stream opened.
  bool get received => _received;

  /// The last stream error, cleared by the next capture.
  Object? get error => _error;

  void _apply(AgentOutputEvent event) {
    switch (event) {
      case AgentOutputText():
        _text = mergeAgentOutput(_text, event.text);
        _received = true;
        _error = null;
      case AgentOutputEnded():
        _ended = true;
        _endReason = event.reason;
        _watching = false;
    }
    notifyListeners();
  }

  void _notify() => notifyListeners();
}

/// What the host last answered, per scope, plus when.
class OrchestrationSnapshot {
  const OrchestrationSnapshot({
    this.projects = const [],
    this.runs = const [],
    this.work = const [],
    this.agents = const [],
    this.gates = const [],
    this.usage,
    this.refreshedAt,
  });

  final List<OrchestrationProject> projects;
  final List<OrchestrationRun> runs;
  final List<WorkItem> work;
  final List<OrchestrationAgent> agents;
  final List<OrchestrationGate> gates;
  final OrchestrationUsage? usage;

  /// When any scope was last refreshed from the host; null before the
  /// first answer.
  final DateTime? refreshedAt;

  bool get hasData => refreshedAt != null;

  OrchestrationSnapshot copyWith({
    List<OrchestrationProject>? projects,
    List<OrchestrationRun>? runs,
    List<WorkItem>? work,
    List<OrchestrationAgent>? agents,
    List<OrchestrationGate>? gates,
    OrchestrationUsage? usage,
    DateTime? refreshedAt,
  }) => OrchestrationSnapshot(
    projects: projects ?? this.projects,
    runs: runs ?? this.runs,
    work: work ?? this.work,
    agents: agents ?? this.agents,
    gates: gates ?? this.gates,
    usage: usage ?? this.usage,
    refreshedAt: refreshedAt ?? this.refreshedAt,
  );

  /// The provider JSON behind every item, for [OrchestrationStore].
  OrchestrationSnapshotCache toCache() => OrchestrationSnapshotCache(
    projects: [for (final p in projects) p.raw],
    runs: [for (final r in runs) r.raw],
    work: [for (final w in work) w.raw],
    agents: [for (final a in agents) a.raw],
    gates: [for (final g in gates) g.raw],
    usage: usage?.raw,
    refreshedAt: refreshedAt,
  );
}

/// Per-profile orchestration state: host identity, capabilities, the
/// snapshot, stream liveness, the dirty-scope refresh loop, the timeline
/// and the attention contribution.
class OrchestrationController extends ChangeNotifier {
  OrchestrationController({
    required this.profile,
    required this.config,
    required OrchestrationStore store,
    OrchestrationGatewayFactory? gatewayFactory,
    OrchestrationProbe? probe,
    DateTime Function()? now,
    MutationKeyMinter? mintKey,
    this.refreshDebounce = const Duration(milliseconds: 400),
    this.staleAfter = const Duration(seconds: 60),
    this.timelineLimit = 500,
    this.mutationTimeout = const Duration(seconds: 60),
    this.cycleTick = const Duration(seconds: 30),
  }) : _store = store,
       _gatewayFactory = gatewayFactory ?? defaultGatewayFactory,
       _probe = probe ?? defaultProbe,
       _now = now ?? DateTime.now,
       _mintKey = mintKey ?? mintMutationKey;

  final ServerProfile profile;
  final OrchestrationConfig config;
  final OrchestrationStore _store;
  final OrchestrationGatewayFactory _gatewayFactory;
  final OrchestrationProbe _probe;
  final DateTime Function() _now;

  /// How long dirty scopes accumulate before one refetch.
  final Duration refreshDebounce;

  /// Data older than this counts as stale (with a live stream or not).
  final Duration staleAfter;

  /// Timeline entries kept; older ones are dropped from the front.
  final int timelineLimit;

  /// How long a sent mutation waits for the host's result before it is
  /// shown as unconfirmed (02-ux §6). A late result still confirms it.
  final Duration mutationTimeout;

  /// How often a watched, still-moving dispatch cycle is re-derived so a
  /// stall window elapsing shows without an event (TEAM-116).
  final Duration cycleTick;
  final MutationKeyMinter _mintKey;

  OrchestrationGateway? _gateway;
  OrchestrationSseClient? _sse;
  StreamSubscription<OrchestrationEvent>? _events;
  StreamSubscription<OrchestrationStreamStatus>? _status;
  StreamSubscription<HeadOnlyReplay>? _replays;
  Timer? _debounce;
  Future<void>? _refresh;
  bool _refreshQueued = false;
  bool _started = false;
  bool _disposed = false;
  final _dirty = <String>{};
  final _timeline = <OrchestrationEvent>[];
  final _outputs = <String, AgentOutputTail>{};
  final _outputWatchers = <String, int>{};
  final _outputSubscriptions = <String, StreamSubscription<AgentOutputEvent>>{};
  final _mutations = <String, MutationRecord>{};
  final _mutationTimers = <String, Timer>{};
  final _mergeReadiness = <String, MergeReadiness>{};
  final _mergeReadinessErrors = <String, Object>{};
  final _mergeReadinessLoads = <String, Future<MergeReadiness?>>{};
  OrchestrationPolicy? _policy;
  final _cycles = <String, DispatchCycle>{};
  final _cycleProbes = <String, StreamSubscription<AgentOutputEvent>>{};
  final _cycleTranscripts = <String, String>{};

  /// Sessions whose probe stream ended (the host stopped serving them):
  /// never opened again; their text stays.
  final _cycleProbesEnded = <String>{};
  final _cycleLimitSeen = <String>{};
  int _cycleWatchers = 0;
  Timer? _cycleTimer;
  bool _cyclesMoving = false;

  /// Results that arrived before their receipt did (a fast host answers
  /// the stream before the HTTP response lands), by correlation id.
  final _earlyResults = <String, RequestResult>{};
  bool _mutationsLoaded = false;
  int? _timelineSeq;
  EventCursor _cursor = EventCursor.none;

  OrchestrationPhase _phase = OrchestrationPhase.idle;
  OrchestrationHostIdentity? _host;
  OrchestrationCapabilities _capabilities = OrchestrationCapabilities.none;
  OrchestrationSnapshot _snapshot = const OrchestrationSnapshot();
  OrchestrationStreamStatus _streamStatus = OrchestrationStreamStatus.closed;
  OrchestrationError? _lastError;
  DateTime? _lastEventAt;

  String get profileId => profile.id;
  OrchestrationPhase get phase => _phase;

  /// Identity of the host: from the probe, then the gateway once it
  /// connected. Null until the probe answered.
  OrchestrationHostIdentity? get host => _host;

  /// [OrchestrationCapabilities.none] until the gateway is built.
  OrchestrationCapabilities get capabilities => _capabilities;
  OrchestrationSnapshot get snapshot => _snapshot;
  OrchestrationStreamStatus get streamStatus => _streamStatus;
  OrchestrationError? get lastError => _lastError;

  /// Resume position, advanced by every numbered event.
  EventCursor get cursor => _cursor;

  /// When the last event (heartbeats included) arrived.
  DateTime? get lastEventAt => _lastEventAt;
  DateTime? get lastRefreshedAt => _snapshot.refreshedAt;

  /// The adapter, for screens that need a per-item read (agent output).
  OrchestrationGateway? get gateway => _gateway;

  /// The host's supervision policy (TEAM-207), cached with the snapshot:
  /// refreshed with the projects scope, null until a host front answered
  /// it and always null against a bare supervisor or the fixture.
  OrchestrationPolicy? get policy => _policy;

  /// Scopes marked dirty by events and not yet refetched.
  Set<String> get dirtyScopes => Set.unmodifiable(_dirty);

  /// Every non-heartbeat event received, oldest first, at most
  /// [timelineLimit].
  List<OrchestrationEvent> get timeline => List.unmodifiable(_timeline);

  /// True while ready and either the data is older than [staleAfter] or
  /// the event stream is not live: the card shows "Showing data from
  /// HH:MM" and disables everything but Refresh.
  bool get isStale {
    if (_phase != OrchestrationPhase.ready) return false;
    if (_streamStatus != OrchestrationStreamStatus.live) return true;
    final at = _snapshot.refreshedAt;
    return at == null || _now().difference(at) > staleAfter;
  }

  /// What needs the person: pending interactions (choice, confirmation,
  /// free text and unrecognised kinds), open gate beads and failed runs.
  /// Review-ready items are informational and not counted.
  int get attentionCount {
    var count = 0;
    for (final gate in _snapshot.gates) {
      switch (gate.kind) {
        case GateKind.choice:
        case GateKind.confirmation:
        case GateKind.freeText:
        case GateKind.unknown:
        case GateKind.gateBead:
        case GateKind.runFailed:
          count += 1;
        case GateKind.reviewReady:
          break;
      }
    }
    return count;
  }

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  /// Probes, builds the adapter, subscribes and refreshes every scope.
  /// Idempotent; a failed probe leaves [phase] failed and [lastError] set.
  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    _cursor = _store.readCursor(profile.id);
    await _loadMutations();
    _setPhase(OrchestrationPhase.probing);

    final ProbeVerdict verdict;
    try {
      verdict = await _probe(config);
    } catch (error) {
      _fail(OrchestrationErrorKind.unreachable, '$error');
      return;
    }
    if (_stoppedMeanwhile) return;
    final error = OrchestrationError.fromVerdict(verdict);
    if (error != null || verdict is! ProbeFound) {
      _lastError = error;
      _setPhase(OrchestrationPhase.failed);
      return;
    }
    _host = verdict.host;
    _setPhase(OrchestrationPhase.connecting);

    final OrchestrationGateway gateway;
    try {
      gateway = await _gatewayFactory(config, verdict);
      if (gateway is GasCityGateway) {
        try {
          await gateway.connect();
        } catch (_) {
          // The probe already identified the host; reads decide from here.
        }
      }
    } catch (error) {
      _fail(OrchestrationErrorKind.unreachable, '$error');
      return;
    }
    if (_stoppedMeanwhile) {
      await gateway.close();
      return;
    }
    _gateway = gateway;
    _capabilities = gateway.capabilities;
    _host = gateway.host ?? _host;
    _subscribe(gateway);
    _setPhase(OrchestrationPhase.ready);
    await refresh();
  }

  /// After a failed probe or connect (the card's Retry): probes and
  /// connects again. A no-op in every other phase.
  Future<void> retry() {
    if (_phase != OrchestrationPhase.failed || _disposed) {
      return Future.value();
    }
    _started = false;
    _lastError = null;
    return start();
  }

  bool get _stoppedMeanwhile =>
      _disposed || _phase == OrchestrationPhase.stopped;

  void _fail(OrchestrationErrorKind kind, String message) {
    if (_stoppedMeanwhile) return;
    _lastError = OrchestrationError(kind, message);
    _setPhase(OrchestrationPhase.failed);
  }

  /// Closes the stream and the gateway and persists the cursor. Idempotent.
  Future<void> stop() async {
    if (_phase == OrchestrationPhase.stopped) return;
    _phase = OrchestrationPhase.stopped;
    _debounce?.cancel();
    _debounce = null;
    _dirty.clear();
    for (final timer in _mutationTimers.values) {
      timer.cancel();
    }
    _mutationTimers.clear();
    for (final subscription in _outputSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _outputSubscriptions.clear();
    _outputWatchers.clear();
    for (final tail in _outputs.values) {
      tail._watching = false;
    }
    _mergeReadiness.clear();
    _mergeReadinessErrors.clear();
    _policy = null;
    _cycleTimer?.cancel();
    _cycleTimer = null;
    for (final probe in _cycleProbes.values) {
      unawaited(probe.cancel());
    }
    _cycleProbes.clear();
    _cycles.clear();
    await _unsubscribe();
    final gateway = _gateway;
    _gateway = null;
    if (gateway != null) await gateway.close();
    _setStreamStatus(OrchestrationStreamStatus.closed);
    await _store.saveCursor(profile.id, _cursor);
    _notify();
  }

  /// The Work tab view (`list` / `graph`) last chosen for [runId] on this
  /// profile, or null when the screen should pick its default.
  String? workView(String runId) => _store.readWorkView(profile.id, runId);

  /// Remembers the Work tab view for [runId] under the profile's prefix
  /// (`workView.` + run id); swept with the rest when the plugin is off.
  Future<void> rememberWorkView(String runId, String? view) =>
      _store.saveWorkView(profile.id, runId, view);

  /// True when the person dismissed the Start-a-run request under the
  /// mutation [key] (TEAM-204); its "Planning…" card stays hidden.
  bool isPlanningDismissed(String key) =>
      _store.readPlanningDismissed(profile.id).contains(key);

  /// Hides the Start-a-run request [key]'s card for good; persisted under
  /// the profile's prefix (`planningDismissed`), swept with the rest.
  Future<void> dismissPlanning(String key) async {
    await _store.savePlanningDismissed(profile.id, key);
    _notify();
  }

  /// Turns the plugin off for this profile: stops, then deletes every
  /// `oc.orchestration.<profileId>.` key and secret. Returns the keys the
  /// store refused to drop.
  Future<Set<String>> remove() async {
    await stop();
    await _store.drain(profile.id);
    return _store.sweep(profile.id);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Agent output
  // -------------------------------------------------------------------------

  /// The cached output of [agentId], never null; empty and unavailable
  /// until [watchAgentOutput] opened a stream for it.
  AgentOutputTail agentOutput(String agentId) =>
      _outputs[agentId] ?? _tailFor(agentId);

  /// Opens (or keeps open) the output stream of [agentId] and returns its
  /// tail. Every call is paired with one [unwatchAgentOutput]; the stream
  /// closes when the last watcher leaves, the text stays.
  AgentOutputTail watchAgentOutput(String agentId) {
    final tail = _tailFor(agentId);
    _outputWatchers[agentId] = (_outputWatchers[agentId] ?? 0) + 1;
    _openOutput(tail);
    return tail;
  }

  /// Releases one watch taken by [watchAgentOutput].
  void unwatchAgentOutput(String agentId) {
    final count = (_outputWatchers[agentId] ?? 0) - 1;
    if (count > 0) {
      _outputWatchers[agentId] = count;
      return;
    }
    _outputWatchers.remove(agentId);
    final subscription = _outputSubscriptions.remove(agentId);
    if (subscription != null) unawaited(subscription.cancel());
    final tail = _outputs[agentId];
    if (tail != null && tail._watching) {
      tail._watching = false;
      tail._notify();
    }
  }

  AgentOutputTail _tailFor(String agentId) {
    final existing = _outputs[agentId];
    if (existing != null) return existing;
    String? sessionId;
    for (final agent in _snapshot.agents) {
      if (agent.id == agentId || agent.sessionId == agentId) {
        sessionId = agent.sessionId;
        break;
      }
    }
    final tail = AgentOutputTail(agentId, sessionId: sessionId);
    _outputs[agentId] = tail;
    return tail;
  }

  void _openOutput(AgentOutputTail tail) {
    if (_outputSubscriptions.containsKey(tail.agentId) || tail.ended) return;
    final gateway = _gateway;
    final sessionId = tail.sessionId;
    // The output interface sits beside the gateway rather than inside it,
    // so a checked value does not promote and needs the cast.
    final source = gateway is OrchestrationAgentOutputGateway
        ? gateway as OrchestrationAgentOutputGateway
        : null;
    if (_stoppedMeanwhile ||
        source == null ||
        !_capabilities.agentOutput ||
        sessionId == null) {
      tail._available = false;
      tail._notify();
      return;
    }
    tail._available = true;
    tail._watching = true;
    tail._error = null;
    _outputSubscriptions[tail.agentId] = source
        .agentOutput(sessionId)
        .listen(
          tail._apply,
          onError: (Object error) {
            tail._error = error;
            tail._notify();
          },
          onDone: () {
            _outputSubscriptions.remove(tail.agentId);
            if (tail._watching) {
              tail._watching = false;
              tail._notify();
            }
          },
        );
    tail._notify();
  }

  // -------------------------------------------------------------------------
  // Events
  // -------------------------------------------------------------------------

  void _subscribe(OrchestrationGateway gateway) {
    if (gateway is GasCityGateway) {
      // The raw client exposes the connection status and head-only replays
      // the plain event stream folds away.
      final sse = gateway.openStream(resumeFrom: _cursor);
      _sse = sse;
      _status = sse.status.listen(_setStreamStatus);
      _replays = sse.headOnlyReplay.listen(
        (replay) => _onEvent(
          StreamHeadOnlyReplay(
            requestedSeq: replay.requestedSeq,
            firstSeq: replay.firstSeq,
          ),
        ),
      );
      _events = sse.frames
          .map(mapStreamFrame)
          .listen(_onEvent, onError: (Object _) {});
      _setStreamStatus(sse.currentStatus);
      return;
    }
    _events = gateway
        .events(resumeFrom: _cursor)
        .listen(
          _onEvent,
          onError: (Object _) =>
              _setStreamStatus(OrchestrationStreamStatus.reconnecting),
          onDone: () => _setStreamStatus(OrchestrationStreamStatus.closed),
        );
    _setStreamStatus(OrchestrationStreamStatus.live);
  }

  /// Cancels are not awaited, as `ConnectionController._retireTransport`
  /// does: a cancelled subscription answers from the root zone, which
  /// never resumes a caller inside a fake-async test. Closing the SSE
  /// client is what actually ends the connection, and that is awaited.
  Future<void> _unsubscribe() async {
    final replays = _replays;
    final status = _status;
    final events = _events;
    final sse = _sse;
    _replays = null;
    _status = null;
    _events = null;
    _sse = null;
    if (replays != null) unawaited(replays.cancel());
    if (status != null) unawaited(status.cancel());
    if (events != null) unawaited(events.cancel());
    if (sse != null) await sse.close();
  }

  /// Marks scopes dirty per §5 and appends to the timeline; heartbeats only
  /// refresh liveness.
  void _onEvent(OrchestrationEvent event) {
    if (_stoppedMeanwhile) return;
    _lastEventAt = _now();
    switch (event) {
      case StreamHeartbeat():
        _setStreamStatus(OrchestrationStreamStatus.live);
        return;
      case StreamHeadOnlyReplay():
        _cursor = EventCursor(seq: event.firstSeq - 1);
        _dirty.addAll(OrchestrationScope.all);
      case BeadChanged():
        _dirty
          ..add(OrchestrationScope.work)
          ..add(OrchestrationScope.runs)
          ..add(OrchestrationScope.gates);
        // A session bead (its id is the session id) changing is the only
        // sign Gas City 1.4.1 gives of a stopped or swept pool session
        // (write proof, TEAM-207): refresh the agents too.
        if (_agentById(event.beadId) != null) {
          _dirty.add(OrchestrationScope.agents);
        }
      case RunChanged():
        _dirty
          ..add(OrchestrationScope.runs)
          ..add(OrchestrationScope.run(event.runId));
      case SessionChanged():
        _dirty
          ..add(OrchestrationScope.agents)
          ..add(OrchestrationScope.agent(event.agentId ?? event.sessionId));
      case GateChanged():
        _dirty.add(OrchestrationScope.gates);
      case RequestResult():
        _dirty.add(OrchestrationScope.activity);
      case ActivityAppended():
        _dirty.add(OrchestrationScope.activity);
      case UnknownOrchestrationEvent():
        break;
    }
    if (event is! StreamHeadOnlyReplay) {
      if (event.seq != null) _cursor = _cursor.advance(event.seq);
      _append(event);
      _settleMutations(event);
    }
    _setStreamStatus(OrchestrationStreamStatus.live);
    _scheduleRefetch();
    _notify();
  }

  void _append(OrchestrationEvent event) {
    final seq = event.seq;
    if (seq != null) {
      final known = _timelineSeq;
      if (known != null && seq <= known) return;
      _timelineSeq = seq;
    }
    _timeline.add(event);
    if (_timeline.length > timelineLimit) {
      _timeline.removeRange(0, _timeline.length - timelineLimit);
    }
  }

  void _scheduleRefetch() {
    if (_dirty.isEmpty) return;
    _debounce?.cancel();
    _debounce = Timer(refreshDebounce, () {
      _debounce = null;
      unawaited(_refetchDirty());
    });
  }

  // -------------------------------------------------------------------------
  // Refresh
  // -------------------------------------------------------------------------

  /// Refetches every scope now (the Refresh action). Cached merge
  /// readiness is fetched again for the runs that had it.
  Future<void> refresh() {
    _dirty.addAll(OrchestrationScope.all);
    _debounce?.cancel();
    _debounce = null;
    for (final runId in _mergeReadiness.keys.toList()) {
      unawaited(mergeReadiness(runId, force: true));
    }
    return _refetchDirty();
  }

  /// Refetches the dirty scopes; a call during a refetch runs once more
  /// after it so no dirty mark is lost.
  Future<void> _refetchDirty() {
    final running = _refresh;
    if (running != null) {
      _refreshQueued = true;
      return running;
    }
    final run = _refetchNow().whenComplete(() {
      _refresh = null;
      if (_refreshQueued) {
        _refreshQueued = false;
        if (_dirty.isNotEmpty) unawaited(_refetchDirty());
      }
    });
    _refresh = run;
    return run;
  }

  Future<void> _refetchNow() async {
    final gateway = _gateway;
    if (gateway == null || _stoppedMeanwhile || _dirty.isEmpty) return;
    final scopes = Set.of(_dirty);
    _dirty.clear();
    var next = _snapshot;
    var succeeded = false;
    OrchestrationError? failure;

    // Each fetch awaits its read first and only then folds the result into
    // [next], so concurrent scopes never overwrite each other's update.
    Future<void> fetch(String scope, Future<_Fold> Function() load) async {
      try {
        final fold = await load();
        if (_stoppedMeanwhile) return;
        next = fold(next);
        succeeded = true;
      } catch (error) {
        failure ??= OrchestrationError(
          OrchestrationErrorKind.readFailed,
          '$scope: $error',
        );
      }
    }

    final fetches = <Future<void>>[];
    if (scopes.contains(OrchestrationScope.projects)) {
      fetches.add(
        fetch(OrchestrationScope.projects, () async {
          final projects = await gateway.projects();
          return (OrchestrationSnapshot s) => s.copyWith(projects: projects);
        }),
      );
      // The policy rides with the projects scope: it describes a rig and
      // changes only when the host's owner edits the rig config.
      if (_policies case final policies?) {
        fetches.add(
          fetch('policy', () async {
            final policy = await policies.policy();
            return (OrchestrationSnapshot s) {
              _policy = policy;
              return s;
            };
          }),
        );
      }
    }
    if (scopes.contains(OrchestrationScope.runs)) {
      fetches.add(
        fetch(OrchestrationScope.runs, () async {
          final runs = await gateway.runs();
          return (OrchestrationSnapshot s) => s.copyWith(runs: runs);
        }),
      );
    } else {
      for (final id in _ids(scopes, 'run:')) {
        fetches.add(
          fetch(OrchestrationScope.run(id), () async {
            final run = await gateway.run(id);
            return (OrchestrationSnapshot s) =>
                s.copyWith(runs: _merge(s.runs, run, (r) => r.id == id));
          }),
        );
      }
    }
    if (scopes.contains(OrchestrationScope.work)) {
      fetches.add(
        fetch(OrchestrationScope.work, () async {
          final work = await gateway.work();
          return (OrchestrationSnapshot s) => s.copyWith(work: work);
        }),
      );
    }
    if (scopes.contains(OrchestrationScope.agents)) {
      fetches.add(
        fetch(OrchestrationScope.agents, () async {
          final agents = await gateway.agents();
          return (OrchestrationSnapshot s) => s.copyWith(agents: agents);
        }),
      );
    } else {
      for (final id in _ids(scopes, 'agent:')) {
        fetches.add(
          fetch(OrchestrationScope.agent(id), () async {
            final agent = await gateway.agent(id);
            return (OrchestrationSnapshot s) => s.copyWith(
              agents: _merge(
                s.agents,
                agent,
                (a) =>
                    a.id == id ||
                    a.sessionId == id ||
                    (agent != null && a.id == agent.id),
              ),
            );
          }),
        );
      }
    }
    if (scopes.contains(OrchestrationScope.gates)) {
      fetches.add(
        fetch(OrchestrationScope.gates, () async {
          final gates = await gateway.gates();
          return (OrchestrationSnapshot s) => s.copyWith(gates: gates);
        }),
      );
    }
    if (scopes.contains(OrchestrationScope.usage)) {
      fetches.add(
        fetch(OrchestrationScope.usage, () async {
          final usage = await gateway.usage();
          return (OrchestrationSnapshot s) => s.copyWith(usage: usage);
        }),
      );
    }
    if (scopes.contains(OrchestrationScope.activity)) {
      fetches.add(
        fetch(OrchestrationScope.activity, () async {
          final page = await gateway.activity(afterSeq: _timelineSeq);
          return (OrchestrationSnapshot s) {
            for (final event in page) {
              _append(ActivityAppended(event: event, seq: event.seq));
            }
            return s;
          };
        }),
      );
    }
    await Future.wait(fetches);
    if (_stoppedMeanwhile) return;

    if (succeeded) next = next.copyWith(refreshedAt: _now());
    _snapshot = next;
    _lastError = failure;
    if (succeeded) {
      unawaited(_store.saveSnapshot(profile.id, next.toCache()));
      unawaited(_store.saveCursor(profile.id, _cursor));
    }
    _notify();
  }

  static Iterable<String> _ids(Set<String> scopes, String prefix) => [
    for (final scope in scopes)
      if (scope.startsWith(prefix)) scope.substring(prefix.length),
  ];

  /// [items] with every entry [matches] replaced by [item] (appended when
  /// none matched, dropped when [item] is null).
  static List<T> _merge<T>(List<T> items, T? item, bool Function(T) matches) {
    final out = <T>[];
    var placed = false;
    for (final existing in items) {
      if (matches(existing)) {
        if (item != null && !placed) out.add(item);
        placed = true;
      } else {
        out.add(existing);
      }
    }
    if (!placed && item != null) out.add(item);
    return out;
  }

  // -------------------------------------------------------------------------
  // Mutations (TEAM-202)
  // -------------------------------------------------------------------------

  /// Every mutation of this profile the store knows, oldest first.
  List<MutationRecord> get mutations {
    final all = _mutations.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List.unmodifiable(all);
  }

  /// One record by idempotency key.
  MutationRecord? mutation(String key) => _mutations[key];

  /// The answer a gate row shows: the newest record answering [gateId]
  /// that no retry superseded, or null when the gate was never answered
  /// from this device. Its [MutationRecord.status] picks the copy (sent →
  /// "Sent · waiting for the host to confirm", confirmed → "Answered",
  /// unconfirmed → "Sent, unconfirmed — check on the host before
  /// re-sending"); the row leaves the list only on confirmed.
  MutationRecord? mutationFor(String gateId) =>
      latestMutation(kind: MutationKind.respond, targetId: gateId);

  /// The newest record of [kind] (any when null) for [targetId] (any when
  /// null) that no retry superseded.
  MutationRecord? latestMutation({MutationKind? kind, String? targetId}) {
    MutationRecord? best;
    for (final record in _mutations.values) {
      if (record.retriedBy != null) continue;
      if (kind != null && record.kind != kind) continue;
      if (targetId != null && record.targetId != targetId) continue;
      if (best == null || record.createdAt.isAfter(best.createdAt)) {
        best = record;
      }
    }
    return best;
  }

  /// Answers the gate [gateId]. A gate already sent and not yet settled
  /// is not sent again: the existing record comes back.
  Future<MutationRecord> answerGate(String gateId, GateResponse response) =>
      mutate(MutationRequest.respond(gateId, response));

  /// Sends [text] to the agent [agentId].
  Future<MutationRecord> messageAgent(String agentId, String text) =>
      mutate(MutationRequest.message(agentId, text));

  /// Nudge / pause / resume / stop / restart the agent [agentId].
  Future<MutationRecord> controlAgent(
    String agentId,
    AgentControlAction action,
  ) => mutate(MutationRequest.controlAgent(agentId, action));

  /// Cancels the run [runId].
  Future<MutationRecord> cancelRun(String runId) =>
      mutate(MutationRequest.cancelRun(runId));

  /// Assigns the work item [workId] to the agent [agentId].
  Future<MutationRecord> assignWork(String workId, {required String agentId}) =>
      mutate(MutationRequest.assign(workId, agentId: agentId));

  /// Creates one work item (TEAM-306) titled [title] in the project
  /// [projectId]; the created id is the record's
  /// [MutationReceipt.createdId].
  Future<MutationRecord> createWork({
    required String title,
    String? description,
    String? projectId,
  }) => mutate(
    MutationRequest.createWork(
      title: title,
      description: description,
      projectId: projectId,
    ),
  );

  /// Gives one task straight to an agent when the planner is off
  /// (TEAM-306): creates the work item, then — when the host accepted it
  /// and answered its id — assigns it to [agentId] (a pool id such as
  /// `<rig>/gastown.polecat`). Work and runs are fetched again afterwards
  /// so the new item shows without waiting for the stream. `assigned` is
  /// null when the create was refused or came back without an id.
  Future<({MutationRecord created, MutationRecord? assigned})> giveTask({
    required String title,
    String? description,
    required String projectId,
    required String agentId,
  }) async {
    final created = await createWork(
      title: title,
      description: description,
      projectId: projectId,
    );
    final receipt = created.receipt;
    final workId = receipt?.createdId;
    MutationRecord? assigned;
    if (receipt != null && receipt.isAccepted && workId != null) {
      assigned = await assignWork(workId, agentId: agentId);
    }
    if (!_disposed && !_stoppedMeanwhile) {
      _dirty
        ..add(OrchestrationScope.work)
        ..add(OrchestrationScope.runs);
      unawaited(_refetchDirty());
    }
    return (created: created, assigned: assigned);
  }

  /// Approves the merge request [mergeRequestId] (TEAM-205). The run's
  /// readiness is fetched again once the host answered.
  Future<MutationRecord> approveMergeRequest(
    String mergeRequestId, {
    String? runId,
  }) async {
    final record = await mutate(MutationRequest.approveMerge(mergeRequestId));
    if (runId != null) unawaited(mergeReadiness(runId, force: true));
    return record;
  }

  /// Merges the run [runId] into the rig's default branch (TEAM-205).
  /// Only a person's confirmed tap calls this; the host still checks its
  /// readiness and boundaries. The readiness is fetched again afterwards.
  Future<MutationRecord> mergeRun(String runId) async {
    final record = await mutate(MutationRequest.merge(runId));
    unawaited(mergeReadiness(runId, force: true));
    return record;
  }

  // -------------------------------------------------------------------------
  // Merge readiness (TEAM-205)
  // -------------------------------------------------------------------------

  /// The cached readiness of [runId], null until [mergeReadiness] answered.
  MergeReadiness? mergeReadinessFor(String runId) => _mergeReadiness[runId];

  /// Why the last readiness read of [runId] failed, null when it did not.
  Object? mergeReadinessError(String runId) => _mergeReadinessErrors[runId];

  /// A readiness read of [runId] is in flight.
  bool mergeReadinessLoading(String runId) =>
      _mergeReadinessLoads.containsKey(runId);

  /// Fetches the host's readiness for [runId] and caches it per run until
  /// [refresh] or a merge mutation; a read already in flight is shared.
  /// Returns null when the host has no merge roles or the read failed
  /// (see [mergeReadinessError]). Never throws.
  Future<MergeReadiness?> mergeReadiness(String runId, {bool force = false}) {
    final running = _mergeReadinessLoads[runId];
    if (running != null) return running;
    if (!force && _mergeReadiness.containsKey(runId)) {
      return Future.value(_mergeReadiness[runId]);
    }
    final load = _loadMergeReadiness(runId).whenComplete(() {
      _mergeReadinessLoads.remove(runId);
      _notify();
    });
    _mergeReadinessLoads[runId] = load;
    _notify();
    return load;
  }

  Future<MergeReadiness?> _loadMergeReadiness(String runId) async {
    final merges = _merges;
    if (merges == null || _stoppedMeanwhile || !_capabilities.mergeReadiness) {
      return null;
    }
    try {
      final readiness = await merges.mergeReadiness(runId);
      if (_stoppedMeanwhile) return null;
      _mergeReadinessErrors.remove(runId);
      if (readiness == null) {
        _mergeReadiness.remove(runId);
      } else {
        _mergeReadiness[runId] = readiness;
      }
      return readiness;
    } catch (error) {
      if (_stoppedMeanwhile) return null;
      _mergeReadinessErrors[runId] = error;
      return null;
    }
  }

  /// Sends one write: mints a key, persists the record as sent, calls the
  /// gateway, applies the receipt and waits for the host's result (§6).
  /// Returns the record as it stands once the receipt is in; listeners
  /// hear every later change. Never throws: a gateway failure lands in
  /// the record as unconfirmed with the error as its receipt message.
  Future<MutationRecord> mutate(
    MutationRequest request, {
    String? retryOf,
  }) async {
    if (request.kind == MutationKind.respond && retryOf == null) {
      final existing = mutationFor(request.targetId);
      if (existing != null && existing.isSent) return existing;
    }
    final gateway = _gateway;
    final key = _mintKey();
    var record = MutationRecord(
      key: key,
      request: request,
      createdAt: _now(),
      status: MutationStatus.sent,
      retryOf: retryOf,
    );
    // Persist first: a crash from here on shows the record as unconfirmed
    // and never sends it again.
    _mutations[key] = record;
    await _store.mutations.save(profile.id, record);
    _notify();

    if (gateway == null || _stoppedMeanwhile || !_allowed(request.kind)) {
      return _update(
        key,
        status: MutationStatus.rejected,
        receipt: MutationReceipt.rejected(
          key,
          gateway == null || _stoppedMeanwhile
              ? 'not connected to the host'
              : 'the host does not allow this control',
        ),
      );
    }

    MutationReceipt receipt;
    try {
      receipt = await _send(gateway, request, key);
    } catch (error) {
      receipt = MutationReceipt(
        id: key,
        status: MutationReceiptStatus.pending,
        message: '$error',
      );
    }
    if (_disposed) return _mutations[key] ?? record;
    record = _applyReceipt(key, receipt);
    unawaited(_store.mutations.prune(profile.id));
    return record;
  }

  /// Sends [key]'s request again under a new key, when the record may be
  /// retried ([MutationRecord.canRetry]); the old record is marked as
  /// superseded. Null when there is nothing to retry. Only a person's tap
  /// calls this.
  Future<MutationRecord?> retryMutation(String key) async {
    final old = _mutations[key];
    if (old == null || !old.canRetry) return null;
    final next = await mutate(old.request, retryOf: key);
    _update(key, retriedBy: next.key);
    return next;
  }

  bool _allowed(MutationKind kind) => switch (kind) {
    MutationKind.respond => _capabilities.controlRespond,
    MutationKind.message => _capabilities.controlMessage,
    MutationKind.controlAgent => _capabilities.controlAgent,
    MutationKind.cancelRun => _capabilities.controlCancelRun,
    MutationKind.assign => _capabilities.controlAssign,
    MutationKind.createWork => _capabilities.controlCreateWork,
    MutationKind.approveMerge ||
    MutationKind.merge => _capabilities.mergeReadiness && _merges != null,
  };

  /// The policy side of the gateway, when the adapter has one.
  OrchestrationPolicyGateway? get _policies {
    final gateway = _gateway;
    return gateway is OrchestrationPolicyGateway
        ? gateway as OrchestrationPolicyGateway
        : null;
  }

  /// The merge side of the gateway, when the adapter has one.
  OrchestrationMergeGateway? get _merges {
    final gateway = _gateway;
    // The merge interface sits beside the gateway rather than inside it,
    // so a checked value does not promote and needs the cast.
    return gateway is OrchestrationMergeGateway
        ? gateway as OrchestrationMergeGateway
        : null;
  }

  Future<MutationReceipt> _send(
    OrchestrationGateway gateway,
    MutationRequest request,
    String key,
  ) => switch (request.kind) {
    MutationKind.approveMerge => _merges!.approveMerge(
      request.targetId,
      requestId: key,
    ),
    MutationKind.merge => _merges!.merge(request.targetId, requestId: key),
    MutationKind.respond => gateway.respond(
      request.targetId,
      request.response!,
      requestId: key,
    ),
    MutationKind.message => gateway.message(
      request.targetId,
      request.text ?? '',
      requestId: key,
    ),
    MutationKind.controlAgent => gateway.controlAgent(
      request.targetId,
      request.action ?? AgentControlAction.nudge,
      requestId: key,
    ),
    MutationKind.cancelRun => gateway.cancelRun(
      request.targetId,
      requestId: key,
    ),
    MutationKind.assign => gateway.assign(
      request.targetId,
      agentId: request.agentId ?? '',
      requestId: key,
    ),
    MutationKind.createWork => gateway.createWork(
      title: request.targetId,
      description: request.text,
      projectId: request.projectId,
      requestId: key,
    ),
  };

  /// Folds the gateway's receipt into the record: rejected settles it;
  /// accepted with a synchronous answer (HTTP 200) is confirmed, accepted
  /// with an asynchronous one (202) waits for the result event under the
  /// timer; pending (transport failure, front without a stored receipt)
  /// and timed-out are unconfirmed at once.
  MutationRecord _applyReceipt(String key, MutationReceipt receipt) {
    switch (receipt.status) {
      case MutationReceiptStatus.rejected:
        return _update(key, status: MutationStatus.rejected, receipt: receipt);
      case MutationReceiptStatus.pending:
      case MutationReceiptStatus.timedOut:
        return _update(
          key,
          status: MutationStatus.unconfirmed,
          receipt: receipt,
        );
      case MutationReceiptStatus.accepted:
        final early = receipt.correlationId == null
            ? null
            : _earlyResults.remove(receipt.correlationId);
        if (early != null) {
          return _update(
            key,
            status: early.ok
                ? MutationStatus.confirmed
                : MutationStatus.rejected,
            receipt: early.ok
                ? receipt
                : MutationReceipt(
                    id: key,
                    status: MutationReceiptStatus.rejected,
                    message: early.errorMessage ?? early.errorCode,
                    raw: receipt.raw,
                    hostRequestId: receipt.hostRequestId,
                    correlationId: receipt.correlationId,
                    upstreamStatus: receipt.upstreamStatus,
                  ),
          );
        }
        // A synchronous answer: 200, or 201 carrying the created resource
        // (createWork's bead) — there is no later result event to wait for.
        if (receipt.upstreamStatus == 200 ||
            (receipt.upstreamStatus == 201 && receipt.createdId != null)) {
          return _update(
            key,
            status: MutationStatus.confirmed,
            receipt: receipt,
          );
        }
        final record = _update(key, receipt: receipt);
        _armTimer(key);
        return record;
    }
  }

  void _armTimer(String key) {
    _mutationTimers[key]?.cancel();
    _mutationTimers[key] = Timer(mutationTimeout, () {
      _mutationTimers.remove(key);
      final record = _mutations[key];
      if (record == null || !record.isSent) return;
      _update(
        key,
        status: MutationStatus.unconfirmed,
        receipt: record.receipt == null
            ? MutationReceipt(id: key, status: MutationReceiptStatus.timedOut)
            : null,
      );
    });
  }

  /// A host event that proves a write happened (or failed) settles the
  /// matching record, whether it is still sent or already unconfirmed:
  ///
  /// | Event | Confirms |
  /// |---|---|
  /// | [RequestResult] with the receipt's correlation id | any kind (failed → rejected) |
  /// | [GateChanged] resolved | respond on that gate |
  /// | [RunChanged] cancelled / completed | cancelRun on that run |
  /// | [SessionChanged] stopped / woke | controlAgent stop, pause / resume, start, restart on that agent or session |
  /// | [BeadChanged] updated | assign on that work item; approveMerge on that request bead |
  /// | [BeadChanged] created | createWork whose receipt carries that bead's id |
  void _settleMutations(OrchestrationEvent event) {
    if (event is RequestResult) {
      var matched = false;
      for (final record in _mutations.values.toList()) {
        if (record.isSettled || record.correlationId != event.requestId) {
          continue;
        }
        matched = true;
        _update(
          record.key,
          status: event.ok ? MutationStatus.confirmed : MutationStatus.rejected,
          receipt: event.ok
              ? null
              : MutationReceipt(
                  id: record.key,
                  status: MutationReceiptStatus.rejected,
                  message: event.errorMessage ?? event.errorCode,
                  raw: record.receipt?.raw ?? const {},
                  hostRequestId: record.receipt?.hostRequestId,
                  correlationId: event.requestId,
                  upstreamStatus: record.receipt?.upstreamStatus,
                ),
        );
      }
      if (!matched) {
        _earlyResults[event.requestId] = event;
        if (_earlyResults.length > 64) {
          _earlyResults.remove(_earlyResults.keys.first);
        }
      }
      return;
    }
    for (final record in _mutations.values.toList()) {
      if (record.isSettled || !_confirms(record, event)) continue;
      _update(record.key, status: MutationStatus.confirmed);
    }
  }

  bool _confirms(MutationRecord record, OrchestrationEvent event) {
    final target = record.targetId;
    switch (event) {
      case GateChanged():
        return record.kind == MutationKind.respond &&
            event.resolved &&
            event.gateId == target;
      case RunChanged():
        return record.kind == MutationKind.cancelRun &&
            event.runId == target &&
            (event.state == RunState.cancelled ||
                event.state == RunState.completed);
      case SessionChanged():
        if (record.kind != MutationKind.controlAgent) return false;
        if (event.agentId != target && event.sessionId != target) {
          final agent = _agentById(target);
          if (agent == null || agent.sessionId != event.sessionId) {
            return false;
          }
        }
        return switch (record.request.action) {
          AgentControlAction.stop ||
          AgentControlAction.pause => event.change == SessionChange.stopped,
          AgentControlAction.resume ||
          AgentControlAction.start ||
          AgentControlAction.restart => event.change == SessionChange.woke,
          AgentControlAction.nudge || null => false,
        };
      case BeadChanged():
        if (event.change == BeadChange.closed) {
          // Proven live (docs/qa/ai-team/write-proof-2026-09-11.md): Gas
          // City 1.4.1 signals an explicit session stop as `bead.closed`
          // on the session bead and a convoy close as `bead.closed` on the
          // convoy bead, with no `session.stopped` / run event.
          if (record.kind == MutationKind.cancelRun) {
            return event.beadId == target;
          }
          if (record.kind == MutationKind.controlAgent &&
              (record.request.action == AgentControlAction.stop ||
                  record.request.action == AgentControlAction.pause)) {
            return event.beadId == target ||
                event.beadId == _agentById(target)?.sessionId;
          }
          return false;
        }
        if (record.kind == MutationKind.createWork) {
          return event.change == BeadChange.created &&
              event.beadId == record.receipt?.createdId;
        }
        return (record.kind == MutationKind.assign ||
                record.kind == MutationKind.approveMerge) &&
            event.beadId == target &&
            event.change == BeadChange.updated;
      case RequestResult() ||
          ActivityAppended() ||
          StreamHeartbeat() ||
          StreamHeadOnlyReplay() ||
          UnknownOrchestrationEvent():
        return false;
    }
  }

  OrchestrationAgent? _agentById(String id) {
    for (final agent in _snapshot.agents) {
      if (agent.id == id || agent.sessionId == id) return agent;
    }
    return null;
  }

  /// Updates and persists one record; settled records drop their timer.
  MutationRecord _update(
    String key, {
    MutationStatus? status,
    MutationReceipt? receipt,
    String? retriedBy,
  }) {
    final current = _mutations[key];
    if (current == null) {
      throw StateError('unknown mutation $key');
    }
    final next = current.copyWith(
      status: status,
      receipt: receipt,
      retriedBy: retriedBy,
      updatedAt: _now(),
    );
    _mutations[key] = next;
    if (next.status != MutationStatus.sent) {
      _mutationTimers.remove(key)?.cancel();
    }
    unawaited(_store.mutations.save(profile.id, next));
    _notify();
    return next;
  }

  /// Loads the profile's records. A record still sent when the app went
  /// away is shown as unconfirmed and never sent again (§6).
  Future<void> _loadMutations() async {
    if (_mutationsLoaded) return;
    _mutationsLoaded = true;
    for (final record in _store.mutations.read(profile.id)) {
      if (record.isSent) {
        final stale = record.copyWith(
          status: MutationStatus.unconfirmed,
          updatedAt: _now(),
        );
        _mutations[record.key] = stale;
        await _store.mutations.save(profile.id, stale);
      } else {
        _mutations[record.key] = record;
      }
    }
  }

  // -------------------------------------------------------------------------
  // Dispatch cycle (TEAM-116)
  // -------------------------------------------------------------------------

  /// Where the work item [workId] is in the host's dispatch chain and why
  /// it waits, derived from the snapshot, the timeline and the agent's
  /// transcript at this moment ([DispatchCycle.none] for an unknown id).
  /// Cached until the next event, refresh, mutation or tick.
  DispatchCycle cycleFor(String workId) {
    final cached = _cycles[workId];
    if (cached != null) return cached;
    final item = _workById(workId);
    if (item == null) return DispatchCycle.none;
    final now = _now();
    OrchestrationRun? run;
    if (item.runId case final runId?) {
      for (final candidate in _snapshot.runs) {
        if (candidate.id == runId) {
          run = candidate;
          break;
        }
      }
    }
    final cycle = deriveDispatchCycle(
      item: item,
      now: now,
      timeline: _timeline,
      agents: _snapshot.agents,
      transcript: cycleTranscriptFor(workId),
      runCompleted: run?.state == RunState.completed,
      runCompletedAt: run?.updatedAt,
    );
    _cycles[workId] = cycle;
    if (!cycle.isTerminal) _cyclesMoving = true;
    _syncCycleProbe(item, cycle);
    _syncCycleTimer();
    return cycle;
  }

  /// The least-advanced tracked item of the run [runId]: the batch's
  /// cycle is its cycle. Cancelled and failed items are passed over
  /// unless every item is one. Null when the run tracks no work.
  String? cycleWorkForRun(String runId) {
    WorkItem? best;
    DispatchCycle? bestCycle;
    var bestSkipped = true;
    for (final item in _snapshot.work) {
      if (item.runId != runId) continue;
      final skipped =
          item.state == WorkState.cancelled || item.state == WorkState.failed;
      final cycle = cycleFor(item.id);
      if (best == null ||
          (bestSkipped && !skipped) ||
          (bestSkipped == skipped && _lessAdvanced(cycle, bestCycle!))) {
        best = item;
        bestCycle = cycle;
        bestSkipped = skipped;
      }
    }
    return best?.id;
  }

  /// [cycleFor] of [cycleWorkForRun]; null when the run tracks no work.
  DispatchCycle? cycleForRun(String runId) {
    final workId = cycleWorkForRun(runId);
    return workId == null ? null : cycleFor(workId);
  }

  static bool _lessAdvanced(DispatchCycle a, DispatchCycle b) {
    final byStep = a.step.index.compareTo(b.step.index);
    if (byStep != 0) return byStep < 0;
    final at = a.since, bt = b.since;
    if (at == null || bt == null) return false;
    return at.isBefore(bt);
  }

  /// The agent working [workId] (by the item's session), for the strip's
  /// Open agent output and Stop: the agent's id when the snapshot lists
  /// it, else the session id (which [agentOutput] resolves too). Null
  /// when the item names no session.
  String? cycleAgentFor(String workId) {
    final sessionId = _workById(workId)?.sessionId;
    if (sessionId == null || sessionId.isEmpty) return null;
    return _agentById(sessionId)?.id ?? sessionId;
  }

  /// The rig's refinery agent for [workId] (its name ends in `refinery`
  /// and its rig matches the item's), for Nudge refinery. Null when the
  /// snapshot lists none.
  String? cycleRefineryFor(String workId) {
    final item = _workById(workId);
    if (item == null) return null;
    final rig = item.projectId;
    OrchestrationAgent? found;
    for (final agent in _snapshot.agents) {
      final name = agent.name.toLowerCase();
      if (!name.contains('refinery')) continue;
      final agentRig = agent.name.contains('/')
          ? agent.name.substring(0, agent.name.indexOf('/'))
          : null;
      if (rig != null && agentRig != null && agentRig != rig) continue;
      found = agent;
      if (agentRig == rig) break;
    }
    return found?.id;
  }

  /// The transcript the app holds for the agent on [workId]: the output
  /// tail a screen watched, or what the cycle probe read. Null when none.
  String? cycleTranscriptFor(String workId) {
    final sessionId = _workById(workId)?.sessionId;
    if (sessionId == null || sessionId.isEmpty) return null;
    final agent = _agentById(sessionId);
    final tail =
        (agent == null ? null : _outputs[agent.id]) ?? _outputs[sessionId];
    final watched = tail?.text ?? '';
    final probed = _cycleTranscripts[sessionId] ?? '';
    final text = watched.length >= probed.length ? watched : probed;
    return text.isEmpty ? null : text;
  }

  /// A strip is on screen: keeps the tick running while some cycle moves
  /// and lets the controller read a claimed agent's transcript. Paired
  /// with one [unwatchCycles].
  void watchCycles() {
    _cycleWatchers += 1;
    // Cycles derived before anyone watched opened no probe: derive again.
    _cycles.clear();
    _syncCycleTimer();
  }

  /// Releases one [watchCycles]; the last one stops the tick and the
  /// transcript probes (their text stays).
  void unwatchCycles() {
    if (_cycleWatchers == 0) return;
    _cycleWatchers -= 1;
    if (_cycleWatchers > 0) return;
    _cycleTimer?.cancel();
    _cycleTimer = null;
    for (final probe in _cycleProbes.values) {
      unawaited(probe.cancel());
    }
    _cycleProbes.clear();
  }

  /// True while the 30 s tick runs (tests read it).
  bool get debugCycleTicking => _cycleTimer != null;

  /// Sessions the controller reads the transcript of for their cycle.
  Set<String> get debugCycleProbes => Set.unmodifiable(_cycleProbes.keys);

  WorkItem? _workById(String id) {
    for (final item in _snapshot.work) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _syncCycleTimer() {
    final wanted = _cycleWatchers > 0 && _cyclesMoving && !_stoppedMeanwhile;
    if (wanted == (_cycleTimer != null)) return;
    if (!wanted) {
      _cycleTimer?.cancel();
      _cycleTimer = null;
      return;
    }
    _cycleTimer = Timer.periodic(cycleTick, (_) {
      if (_stoppedMeanwhile) {
        _cycleTimer?.cancel();
        _cycleTimer = null;
        return;
      }
      // Nothing re-derived a moving cycle since the last tick: no strip
      // is asking, so stop until one does.
      if (!_cyclesMoving) {
        _cycleTimer?.cancel();
        _cycleTimer = null;
        return;
      }
      _notify();
    });
  }

  /// While a strip watches, reads the transcript of the agent on [item]
  /// once it claimed and until it pushed, so a provider limit is seen.
  /// The text lives beside the output tails and never opens or closes
  /// what a screen watches.
  void _syncCycleProbe(WorkItem item, DispatchCycle cycle) {
    final sessionId = item.sessionId;
    final wanted =
        _cycleWatchers > 0 &&
        sessionId != null &&
        sessionId.isNotEmpty &&
        !cycle.isTerminal &&
        (cycle.step == DispatchStep.claimed ||
            cycle.step == DispatchStep.working ||
            cycle.step == DispatchStep.pushed);
    if (!wanted) {
      if (sessionId != null) {
        final probe = _cycleProbes.remove(sessionId);
        if (probe != null) unawaited(probe.cancel());
      }
      return;
    }
    if (_cycleProbes.containsKey(sessionId) ||
        _cycleProbesEnded.contains(sessionId)) {
      return;
    }
    final gateway = _gateway;
    final source = gateway is OrchestrationAgentOutputGateway
        ? gateway as OrchestrationAgentOutputGateway
        : null;
    if (source == null || !_capabilities.agentOutput || _stoppedMeanwhile) {
      return;
    }
    _cycleProbes[sessionId] = source
        .agentOutput(sessionId)
        .listen(
          (event) {
            if (event is! AgentOutputText) return;
            final before = _cycleTranscripts[sessionId] ?? '';
            var text = mergeAgentOutput(before, event.text);
            if (text.length > agentOutputLimit) {
              text = text.substring(text.length - agentOutputLimit);
            }
            _cycleTranscripts[sessionId] = text;
            final limit = dispatchProviderLimitPattern.hasMatch(text);
            // Only what changes the cycle notifies: the first text
            // (working evidence) and a provider limit appearing.
            final limitWasSeen = _cycleLimitSeen.contains(sessionId);
            if (limit) _cycleLimitSeen.add(sessionId);
            if (before.isEmpty || limit != limitWasSeen) _notify();
          },
          onError: (Object _) {},
          onDone: () {
            _cycleProbes.remove(sessionId);
            _cycleProbesEnded.add(sessionId);
          },
        );
  }

  // -------------------------------------------------------------------------
  // Plumbing
  // -------------------------------------------------------------------------

  void _setPhase(OrchestrationPhase next) {
    if (_phase == next) return;
    _phase = next;
    _notify();
  }

  void _setStreamStatus(OrchestrationStreamStatus next) {
    if (_streamStatus == next) return;
    _streamStatus = next;
    _notify();
  }

  void _notify() {
    // Cycles are derived from what just changed: drop the cache and let
    // the next [cycleFor] say whether anything still moves.
    _cycles.clear();
    _cyclesMoving = false;
    if (!_disposed) notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Defaults
  // -------------------------------------------------------------------------

  /// Gas City: [GasCityProbe] on the config's URL and city. Fixture: found
  /// at once, the recordings answer for the host.
  static Future<ProbeVerdict> defaultProbe(OrchestrationConfig config) {
    switch (config.provider) {
      case OrchestrationProvider.gascity:
        return GasCityProbe(
          hostMode: config.hostMode,
        ).probe(config.url, city: config.city.isEmpty ? null : config.city);
      case OrchestrationProvider.fixture:
        return Future.value(
          ProbeFound(
            host: OrchestrationHostIdentity(
              provider: 'fixture',
              url: config.url,
              hostMode: config.hostMode,
            ),
            city: config.city.isEmpty ? null : config.city,
          ),
        );
    }
  }

  /// [GasCityGateway] for Gas City (the city from the config, else the one
  /// the probe reported; the front's `supervisorUrl` with controls on when
  /// the probe found a front that allows this device to write);
  /// [FixtureOrchestrationGateway] over the directory in `url` for the
  /// fixture.
  static OrchestrationGateway defaultGatewayFactory(
    OrchestrationConfig config,
    ProbeFound found,
  ) {
    switch (config.provider) {
      case OrchestrationProvider.gascity:
        final front = found.front && found.identityAllowed;
        return GasCityGateway(
          url: front ? found.host.url : config.url,
          city: config.city.isEmpty ? (found.city ?? '') : config.city,
          hostMode: config.hostMode,
          front: front,
        );
      case OrchestrationProvider.fixture:
        const scheme = 'fixture://';
        final path = config.url.startsWith(scheme)
            ? config.url.substring(scheme.length)
            : config.url;
        return FixtureOrchestrationGateway(
          fixturePath: path,
          hostMode: config.hostMode,
        );
    }
  }
}
