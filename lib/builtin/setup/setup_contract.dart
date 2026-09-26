import 'package:flutter/foundation.dart';

/// The shared contract of the phone setup engine
/// (docs/design/phone-setup-v2-2026-09-24.md). Screens depend on these types
/// only; the engine implements [SetupEngine]. Nothing here knows about any
/// particular component, so adding one (AI Team, Python, anything) never
/// changes this file.

/// One installable piece: a check that says whether it is there, and an
/// install that puts it there and reports progress with `::oc` lines.
@immutable
class SetupComponent {
  const SetupComponent({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.checkScript,
    required this.installScript,
    this.dependsOn = const [],
    this.required = false,
    this.defaultOn = false,
    this.estimatedSeconds = 60,
    this.downloadBytes,
    this.removeScript,
    this.presenceScript,
    this.why,
    this.native = false,
    this.jobStep = false,
  });

  final String id;
  final String title;
  final String shortTitle;

  /// One plain sentence shown when a required component cannot be switched
  /// off ("OpenCode needs it to run").
  final String? why;
  final List<String> dependsOn;
  final bool required;
  final bool defaultOn;

  /// Measured on a mid-range phone; weights the overall bar and the ETA.
  final int estimatedSeconds;
  final int? downloadBytes;

  /// Exit 0 = installed and healthy; the last line of output is its version.
  final String checkScript;

  /// Idempotent. Reports with `::oc stage|bytes|percent|version` lines.
  final String installScript;
  final String? removeScript;

  /// Removal inventory, independent of pinned-version/health checks: exit 0
  /// means present (including a partial install), 1 absent, anything else
  /// unknown. Output is discarded. Null means presence cannot be verified.
  /// Native components use the native installed status instead.
  final String? presenceScript;

  /// Installed by native code rather than a script (the Linux base itself).
  final bool native;

  /// Not something installed but a step the engine itself runs at the end of
  /// every job: starting OpenCode and connecting to it. It is in the registry
  /// so the progress checklist can name it; lists of things to install
  /// (Customize, sizes) leave it out.
  final bool jobStep;
}

enum SetupState { idle, running, done, failed, interrupted, cancelled }

enum ComponentState { pending, checking, running, done, failed, skipped }

@immutable
class ComponentProgress {
  const ComponentProgress({
    required this.id,
    required this.state,
    this.stage,
    this.bytesDone,
    this.bytesTotal,
    this.percent,
    this.version,
    this.error,
  });

  final String id;
  final ComponentState state;

  /// What is happening now, in plain words, from `::oc stage`.
  final String? stage;
  final int? bytesDone;

  /// Null or 0 when the total is unknown.
  final int? bytesTotal;
  final double? percent;
  final String? version;
  final String? error;

  /// This component's own fraction from its real signal, or null when it
  /// only reports stages (the view shows it as indeterminate).
  double? get fraction {
    if (state == ComponentState.done || state == ComponentState.skipped) {
      return 1;
    }
    final total = bytesTotal;
    if (total != null && total > 0 && bytesDone != null) {
      return (bytesDone! / total).clamp(0, 1).toDouble();
    }
    if (percent != null) return (percent! / 100).clamp(0, 1).toDouble();
    return null;
  }
}

@immutable
class SetupProgress {
  const SetupProgress({
    required this.state,
    required this.components,
    required this.overall,
    this.current,
    this.etaSeconds,
    this.error,
    this.logTail = '',
    this.jobId,
    this.firstSetup = false,
    this.adding = const [],
  });

  static const idle = SetupProgress(
    state: SetupState.idle,
    components: [],
    overall: 0,
  );

  final SetupState state;

  /// In install order; only the components of this job.
  final List<ComponentProgress> components;

  /// 0..1, weighted by each component's estimate.
  final double overall;
  final String? current;

  /// Null until there is enough real progress to estimate honestly.
  final int? etaSeconds;
  final String? error;
  final String logTail;

  /// Which job this is; a new `run` makes a new one, so a view can reset
  /// its bar exactly when the job changes. Null while idle.
  final String? jobId;

  /// The job was started as the phone's first setup (screen A or the
  /// first-run welcome), so it ends on "name your first project". Kept in
  /// the job's own params ([SetupJobParams]) so it survives the app being
  /// killed: a notification tap after a cold start still knows where the
  /// job should end.
  final bool firstSetup;

  /// The tools an "Add tools" job adds, by component id; empty for a first
  /// setup or an update. The screen and the notification then say "Adding
  /// AI Team" instead of "Setting up OpenCode on this phone". Kept in the
  /// job's params like [firstSetup].
  final List<String> adding;

  bool get canContinue =>
      state == SetupState.failed ||
      state == SetupState.interrupted ||
      state == SetupState.cancelled;
}

/// Facts about a job rather than a component, kept in the job's params
/// under [key] so setup.json carries them without a schema change: the
/// native runner stores params opaquely, and components read only their own
/// id's entry.
abstract final class SetupJobParams {
  static const key = '_job';

  /// Marks a job as the phone's first setup ([SetupProgress.firstSetup]).
  static const firstSetup = <String, Map<String, String>>{
    key: {'first': '1'},
  };

  static bool isFirstSetup(Map<String, Map<String, String>> params) =>
      params[key]?['first'] == '1';

  /// Marks a job as adding [ids] to a phone that is set up
  /// ([SetupProgress.adding]).
  static Map<String, Map<String, String>> adding(Iterable<String> ids) => {
    key: {'adding': ids.join(',')},
  };

  static List<String> addingIds(Map<String, Map<String, String>> params) => [
    for (final id in (params[key]?['adding'] ?? '').split(','))
      if (id.trim().isNotEmpty) id.trim(),
  ];
}

/// Runs any set of components; first setup, "Add tools" and updates are all
/// just different selections. Running again after an interruption skips what
/// the check scripts find installed, so every run is also a resume.
abstract class SetupEngine {
  /// Every component the app knows, in dependency order.
  List<SetupComponent> get registry;

  /// The live progress of the current or last job.
  ValueListenable<SetupProgress> get progress;

  /// Starts (or continues) a job for [ids] plus what they depend on. Required
  /// components are always included. [params] are passed to scripts by
  /// component id (for example opencode: {runtime: opencode2}).
  Future<void> run(
    Set<String> ids, {
    Map<String, Map<String, String>> params = const {},
  });

  /// Stops the running job; finished components stay installed.
  Future<void> cancel();

  /// Reads the persisted job (after an app restart) into [progress].
  Future<void> restore();

  /// Ids of optional components that are installed now.
  Future<Set<String>> installedOptional();
}
