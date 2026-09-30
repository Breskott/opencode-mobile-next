// The one-tap "Turn on AI Team on this phone" flow, as a controller.
//
// Finish line: a person taps once and the phone goes from "team off" to
// "team ready": the running reply finishes, the unprotected OpenCode server
// and terminals are stopped only after the person says yes, the engine
// proves this phone safe, and OpenCode comes back protected.
// Non-goal: anything about the engine's own internals (the native daemon,
// its proof, its adapter). This file only drives the calls the coordinator's
// handoff froze: phoneProjectEngine.start / attach / probe.
//
// Every step is a real signal (a started and an ended time), never a timer
// guess, and every failure keeps only a safe code for Details.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../builtin/builtin_linux.dart';
import '../builtin/builtin_server.dart';
import '../builtin/deliberate_stop.dart';
import '../builtin/local_terminal.dart';
import '../domain/phone_project_engine.dart';
import '../l10n/app_localizations.dart';
import '../ui/kit/kit_redact.dart';
import 'connection.dart';
import 'profiles.dart';

/// The steps the person sees, in order.
enum PhoneTeamSetupStep { reply, stop, check, server }

enum PhoneTeamSetupPhase {
  /// Nothing started (or the last run was dismissed).
  idle,
  running,

  /// Waiting for the person's yes to stop the server and terminals.
  confirming,
  failed,
  done,
}

/// Why a run stopped, in the plain kinds the page has words for.
enum PhoneTeamSetupProblem {
  /// This phone did not prove the team's copy of the code separate.
  unsafe,

  /// The engine did not start or did not answer.
  engine,

  /// The server or a terminal did not stop.
  stopFailed,

  /// The server did not come back.
  serverStart,

  /// Everything started but the engine still says it cannot run work.
  notReady,

  /// The person said no to stopping the server.
  declined,

  /// There is no OpenCode on this phone to protect.
  noServer,
}

/// What the phone is running right now.
class PhoneTeamHostState {
  const PhoneTeamHostState({
    this.serverRunning = false,
    this.terminals = 0,
    this.engineRunning = false,
    this.restartRequired = false,
  });
  final bool serverRunning;
  final int terminals;
  final bool engineRunning;
  final bool restartRequired;

  bool get needsStop => serverRunning || terminals > 0 || restartRequired;
}

/// Everything the flow asks of the phone, so tests can stand in.
abstract interface class PhoneTeamSetupPorts {
  /// Whether this phone has an in-app OpenCode 1 server to set up.
  bool get hasServer;

  /// Whether the team was turned on here before (a saved engine config).
  bool get wasOn;

  /// A chat reply is on the wire.
  bool get replyRunning;
  Listenable get replyChanges;
  Future<PhoneTeamHostState> inspect();
  Future<void> stopServer();
  Future<void> closeTerminals();
  Future<PhoneEngineHealth> startEngine();
  Future<PhoneEngineHealth> probeEngine();

  /// Starts OpenCode and waits until it answers; null when it does, else
  /// the technical reason (kept under Details).
  Future<String?> startServer();

  /// Reads the engine again into the app's team (capabilities refresh).
  Future<void> attach();
}

/// The real phone: the same controls This phone uses, nothing reimplemented.
class BuiltinPhoneTeamSetupPorts implements PhoneTeamSetupPorts {
  BuiltinPhoneTeamSetupPorts({
    required this.connection,
    required this.linux,
    required this.starter,
    required this.notice,
    LocalTerminalSessions? terminals,
  }) : _terminals = terminals ?? LocalTerminalSessions();

  final ConnectionController connection;
  final BuiltinLinux linux;
  final BuiltinServerStarter starter;

  /// What the engine's ongoing notification says while it runs.
  final String notice;
  final LocalTerminalSessions _terminals;

  ServerProfile? get _profile {
    ServerProfile? chosen;
    for (final p in connection.store.profiles) {
      if (!looksLikeInAppServer(p) || p.flavor != ServerFlavor.v1) continue;
      if (p.id == connection.store.activeId) return p;
      chosen ??= p;
    }
    return chosen;
  }

  String get _id => _profile!.id;

  @override
  bool get hasServer => _profile != null;

  @override
  bool get wasOn =>
      _profile?.orchestration?.provider == OrchestrationProvider.phoneEngine &&
      (_profile?.teamEngineAuth.isNotEmpty ?? false);

  @override
  bool get replyRunning => connection.busySessions.isNotEmpty;

  @override
  Listenable get replyChanges => connection;

  @override
  Future<PhoneTeamHostState> inspect() async {
    final status = await linux.status();
    var engine = const BuiltinPhoneEngineStatus(profileId: '');
    try {
      engine = await linux.phoneEngineStatus(_id);
    } on BuiltinLinuxException {
      // Unknown: treated as not running; the start reports for itself.
    }
    var shells = 0;
    try {
      await _terminals.load();
      shells = _terminals.shells.where((s) => s.running).length;
    } catch (_) {
      // No terminals to count.
    }
    return PhoneTeamHostState(
      serverRunning: status.serverRunning,
      terminals: shells,
      engineRunning: engine.running,
      restartRequired: engine.restartRequired,
    );
  }

  @override
  Future<void> stopServer() async {
    await linux.stopServer();
    await DeliberateServerStop.mark(connection.store.prefs, _id);
  }

  @override
  Future<void> closeTerminals() async {
    await _terminals.load();
    for (final shell in List.of(_terminals.shells)) {
      await _terminals.remove(shell);
    }
  }

  @override
  Future<PhoneEngineHealth> startEngine() =>
      connection.phoneProjectEngine.start(_id, notice: notice);

  @override
  Future<PhoneEngineHealth> probeEngine() =>
      connection.phoneProjectEngine.probe(_id);

  @override
  Future<String?> startServer() async {
    final profile = _profile;
    if (profile == null) return 'noServerProfile';
    final failure = await starter.start(profile);
    if (failure == null) return null;
    return failure.problem.name;
  }

  @override
  Future<void> attach() async {
    await connection.phoneProjectEngine.attach(_id);
    connection.syncOrchestration();
  }
}

/// One run of the flow. Listen to it; it never touches the widgets.
class PhoneTeamSetupController extends ChangeNotifier {
  PhoneTeamSetupController(
    this.ports, {
    DateTime Function()? now,
    Future<void> Function(Duration)? delay,
    this.readyAttempts = 15,
    this.readyGap = const Duration(seconds: 2),
  }) : _now = now ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed;

  final PhoneTeamSetupPorts ports;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _delay;
  final int readyAttempts;
  final Duration readyGap;

  PhoneTeamSetupPhase _phase = PhoneTeamSetupPhase.idle;
  PhoneTeamSetupProblem? _problem;
  PhoneTeamSetupStep? _step;
  PhoneTeamSetupStep? _failedStep;
  PhoneEngineHealth? _health;
  String? _details;
  bool _automatic = false;
  bool _stopped = false;
  bool _disposed = false;
  final Map<PhoneTeamSetupStep, DateTime> _began = {};
  final Map<PhoneTeamSetupStep, Duration> _took = {};
  final Set<PhoneTeamSetupStep> _skipped = {};
  Completer<bool>? _confirm;
  Future<void>? _running;

  PhoneTeamSetupPhase get phase => _phase;
  PhoneTeamSetupProblem? get problem => _problem;
  PhoneTeamSetupStep? get step => _step;
  PhoneTeamSetupStep? get failedStep => _failedStep;
  PhoneEngineHealth? get health => _health;

  /// Safe technical text for Details; never a raw exception.
  String? get details => _details;

  /// Started by the app itself (after an update), not by a tap.
  bool get automatic => _automatic;
  bool get isRunning =>
      _phase == PhoneTeamSetupPhase.running ||
      _phase == PhoneTeamSetupPhase.confirming;
  bool get isDone => _phase == PhoneTeamSetupPhase.done;
  bool get skipped => _skipped.isNotEmpty;
  bool wasSkipped(PhoneTeamSetupStep step) => _skipped.contains(step);

  /// How long [step] took, once it ended.
  Duration? took(PhoneTeamSetupStep step) => _took[step];

  /// How long the current [step] has been going.
  Duration? elapsed(PhoneTeamSetupStep step) {
    final began = _began[step];
    if (began == null || _took.containsKey(step)) return null;
    return _now().difference(began);
  }

  /// Whether the page should show Finishing your current reply.
  bool get waitingForReply =>
      _phase == PhoneTeamSetupPhase.running &&
      _step == PhoneTeamSetupStep.reply;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _begin(PhoneTeamSetupStep step) {
    _step = step;
    _began[step] = _now();
    _emit();
  }

  void _end(PhoneTeamSetupStep step) {
    _took[step] = _now().difference(_began[step] ?? _now());
    _emit();
  }

  void _skip(PhoneTeamSetupStep step) {
    _skipped.add(step);
    _began[step] = _now();
    _took[step] = Duration.zero;
    _emit();
  }

  void _fail(
    PhoneTeamSetupProblem problem,
    PhoneTeamSetupStep step,
    String details,
  ) {
    _problem = problem;
    _failedStep = step;
    _details = KitRedact.text(details);
    _phase = PhoneTeamSetupPhase.failed;
    _emit();
  }

  /// The person's answer to the stop question. True stops the server and
  /// closes the terminals; false ends the run, changing nothing.
  void answer(bool yes) {
    final confirm = _confirm;
    if (confirm != null && !confirm.isCompleted) confirm.complete(yes);
  }

  /// Runs the whole flow; a second call while it runs joins the first.
  Future<void> run({bool automatic = false}) {
    final existing = _running;
    if (existing != null && isRunning) return existing;
    _automatic = automatic;
    return _running = _run().whenComplete(() => _running = null);
  }

  void _reset() {
    _phase = PhoneTeamSetupPhase.running;
    _problem = null;
    _step = null;
    _failedStep = null;
    _details = null;
    _health = null;
    _began.clear();
    _took.clear();
    _skipped.clear();
    _stopped = false;
  }

  Future<void> _waitForReply() async {
    if (!ports.replyRunning) return;
    final done = Completer<void>();
    void check() {
      if (!ports.replyRunning && !done.isCompleted) done.complete();
    }

    ports.replyChanges.addListener(check);
    try {
      await done.future;
    } finally {
      ports.replyChanges.removeListener(check);
    }
  }

  Future<bool> _stopForProtection() async {
    _phase = PhoneTeamSetupPhase.confirming;
    _begin(PhoneTeamSetupStep.stop);
    final confirm = _confirm = Completer<bool>();
    final yes = await confirm.future;
    _confirm = null;
    if (!yes) {
      _fail(
        PhoneTeamSetupProblem.declined,
        PhoneTeamSetupStep.stop,
        'declined',
      );
      return false;
    }
    _phase = PhoneTeamSetupPhase.running;
    _emit();
    try {
      await ports.stopServer();
      await ports.closeTerminals();
    } catch (_) {
      _fail(
        PhoneTeamSetupProblem.stopFailed,
        PhoneTeamSetupStep.stop,
        'stopFailed',
      );
      return false;
    }
    _end(PhoneTeamSetupStep.stop);
    return true;
  }

  Future<void> _run() async {
    _reset();
    _emit();
    try {
      if (!ports.hasServer) {
        _fail(
          PhoneTeamSetupProblem.noServer,
          PhoneTeamSetupStep.reply,
          'noServerProfile',
        );
        return;
      }
      // a) A running reply is never cut short.
      _begin(PhoneTeamSetupStep.reply);
      await _waitForReply();
      if (_stopped) return;
      _end(PhoneTeamSetupStep.reply);

      // b) The unprotected server and terminals: only with a yes.
      final host = await ports.inspect();
      var stopped = false;
      if (host.needsStop) {
        if (!await _stopForProtection()) return;
        stopped = true;
      } else {
        _skip(PhoneTeamSetupStep.stop);
      }

      // c) The engine proves this phone safe.
      _begin(PhoneTeamSetupStep.check);
      var health = await ports.startEngine();
      if (health.restartRequired && !stopped) {
        // The engine found an old server it cannot vouch for: ask now.
        _took.remove(PhoneTeamSetupStep.stop);
        _skipped.remove(PhoneTeamSetupStep.stop);
        if (!await _stopForProtection()) return;
        stopped = true;
        _begin(PhoneTeamSetupStep.check);
        health = await ports.startEngine();
      }
      _health = health;
      if (!health.canExecute) {
        _fail(
          PhoneTeamSetupProblem.unsafe,
          PhoneTeamSetupStep.check,
          health.boundaryReason.isEmpty
              ? 'boundary_unverified'
              : health.boundaryReason,
        );
        return;
      }
      _end(PhoneTeamSetupStep.check);

      // d) OpenCode back, protected; probe until the engine can run work.
      _begin(PhoneTeamSetupStep.server);
      final failure = await ports.startServer();
      if (failure != null) {
        _fail(
          PhoneTeamSetupProblem.serverStart,
          PhoneTeamSetupStep.server,
          failure,
        );
        return;
      }
      PhoneEngineHealth? last;
      for (var attempt = 0; attempt < readyAttempts; attempt++) {
        try {
          last = await ports.probeEngine();
        } on PhoneEngineException {
          last = null;
        }
        if (last != null && last.canExecute) break;
        if (attempt + 1 < readyAttempts) await _delay(readyGap);
      }
      _health = last ?? _health;
      if (last == null || !last.canExecute) {
        _fail(
          PhoneTeamSetupProblem.notReady,
          PhoneTeamSetupStep.server,
          last == null
              ? 'engineUnavailable'
              : (last.boundaryReason.isEmpty
                    ? 'notExecutable'
                    : last.boundaryReason),
        );
        return;
      }
      await ports.attach();
      _end(PhoneTeamSetupStep.server);
      _step = null;
      _phase = PhoneTeamSetupPhase.done;
      _emit();
    } on PhoneEngineException catch (e) {
      _fail(
        PhoneTeamSetupProblem.engine,
        _step ?? PhoneTeamSetupStep.check,
        e.code,
      );
    } catch (_) {
      _fail(
        PhoneTeamSetupProblem.engine,
        _step ?? PhoneTeamSetupStep.check,
        'unexpected',
      );
    }
  }

  /// After an app update: the proof is per packaged binary, so a team that
  /// was on is checked again in the background. Nothing is stopped without
  /// the person (the flow waits at its question).
  Future<void> autoProof() async {
    if (isRunning || _autoTried || !ports.wasOn || !ports.hasServer) return;
    _autoTried = true;
    try {
      final health = await ports.probeEngine();
      if (health.canExecute) return;
    } catch (_) {
      // The engine is not answering: check it again.
    }
    await run(automatic: true);
  }

  bool _autoTried = false;

  /// Forgets a finished or failed run so the page shows its start again.
  void dismiss() {
    if (isRunning) return;
    _phase = PhoneTeamSetupPhase.idle;
    _emit();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopped = true;
    final confirm = _confirm;
    if (confirm != null && !confirm.isCompleted) confirm.complete(false);
    super.dispose();
  }
}

/// The app's one setup flow for [connection], shared by the AI Team page,
/// Team settings and the Work strip (one run at a time).
class PhoneTeamSetup {
  PhoneTeamSetup._();

  static final Expando<PhoneTeamSetupController> _shared = Expando();

  /// Tests replace the phone with this.
  @visibleForTesting
  static PhoneTeamSetupPorts Function(ConnectionController)? debugPorts;

  static PhoneTeamSetupController of(
    ConnectionController connection, {
    AppLocalizations? copy,
    BuiltinLinux? linux,
    BuiltinServerStarter? starter,
  }) {
    final existing = _shared[connection];
    if (existing != null) return existing;
    final ports =
        debugPorts?.call(connection) ??
        BuiltinPhoneTeamSetupPorts(
          connection: connection,
          linux: linux ?? BuiltinLinux(),
          starter:
              starter ?? BuiltinServerStarter(linux: linux ?? BuiltinLinux()),
          notice: copy?.aiteamComponentNotice ?? 'AI Team is running',
        );
    return _shared[connection] = PhoneTeamSetupController(ports);
  }
}
