import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';
import '../../termux/bridge.dart' show TermuxRuntime;
import '../builtin_linux.dart';
import 'components.dart';
import 'setup_contract.dart';
import 'setup_scripts.dart';

/// What the engine asks of the app once OpenCode is installed: start the
/// in-app server for [runtime] and connect to it.
@immutable
class SetupFinishRequest {
  const SetupFinishRequest({
    required this.runtime,
    required this.openCodeChanged,
    this.version,
  });

  final TermuxRuntime runtime;

  /// OpenCode was installed or updated by this job, so a server already
  /// running is the old one and must be restarted.
  final bool openCodeChanged;
  final String? version;
}

/// Starts and connects; returns null when OpenCode answers, else the reason
/// in plain words. The app shell provides it (setup_finish.dart).
typedef SetupFinisher = Future<String?> Function(SetupFinishRequest request);

/// The phone setup engine (docs/design/phone-setup-v2-2026-09-24.md, "The
/// engine and its resume rule").
///
/// [run] checks every component first and skips what is installed, so each
/// run is also a resume; the rest goes to the native job runner
/// (SetupRunner.kt), which keeps going while the app is in the background and
/// writes setup.json. This class polls that and turns it into
/// [SetupProgress].
///
/// Starting OpenCode is the job's last step (`start`, a
/// [SetupComponent.jobStep]): the native job waits on it while [finisher]
/// starts the server and connects, and only then is the job done. A job
/// interrupted there continues like any other: every check passes and only
/// the start is left.
class ChannelSetupEngine implements SetupEngine {
  ChannelSetupEngine({
    BuiltinLinux? linux,
    this.finisher,
    AppLocalizations Function()? strings,
    List<SetupComponent> Function(
      AppLocalizations l10n,
      Map<String, Map<String, String>> params,
    )?
    components,
    this.pollInterval = const Duration(milliseconds: 500),
    DateTime Function()? clock,
  }) : _linux = linux ?? BuiltinLinux(),
       strings = strings ?? deviceStrings,
       _components =
           components ??
           ((l10n, params) => setupComponents(l10n, params: params)),
       _clock = clock ?? DateTime.now {
    _progress = _WatchedProgress(_watchersChanged);
  }

  final BuiltinLinux _linux;

  /// The words the engine writes (titles, stages, errors, the notification).
  AppLocalizations Function() strings;
  final List<SetupComponent> Function(
    AppLocalizations l10n,
    Map<String, Map<String, String>> params,
  )
  _components;
  final DateTime Function() _clock;
  final Duration pollInterval;

  /// Set by the app shell once it can start and connect (main.dart).
  SetupFinisher? finisher;

  /// Follows the device language, English for one the app does not ship.
  /// The app shell replaces it with its own language choice.
  static AppLocalizations deviceStrings() {
    final locale = PlatformDispatcher.instance.locale;
    final supported = AppLocalizations.supportedLocales.any(
      (candidate) => candidate.languageCode == locale.languageCode,
    );
    return lookupAppLocalizations(
      supported ? Locale(locale.languageCode) : const Locale('en'),
    );
  }

  late final _WatchedProgress _progress;

  /// The job the engine last saw, as setup.json has it.
  SetupJobRecord? _record;

  /// The components of the job being shown, in its order.
  List<SetupComponent> _jobComponents = const [];

  /// Per job: the highest fraction each component reached, so a new stage
  /// that starts measuring from zero never moves the bar backwards.
  final _floors = <String, double>{};
  String? _floorsJob;

  bool _starting = false;
  bool _cancelRequested = false;

  /// The last job given to the native runner by this engine.
  String? _handedOver;
  String? _finishing;
  Timer? _poll;
  bool _polling = false;
  bool _disposed = false;

  @override
  List<SetupComponent> get registry => _components(strings(), const {});

  @override
  ValueListenable<SetupProgress> get progress => _progress;

  @override
  Future<void> run(
    Set<String> ids, {
    Map<String, Map<String, String>> params = const {},
  }) async {
    if (_starting) return;
    _starting = true;
    _cancelRequested = false;
    try {
      final last = await _read();
      if (last != null && last.state == 'running') {
        // Already running (the app came back to it): watch, do not restart.
        _show(last);
        _ensurePolling();
        return;
      }
      // Continue keeps what the stopped job was for (OpenCode 2, a version)
      // unless the caller says otherwise.
      final effective = params.isEmpty && last != null && last.canContinue
          ? last.params
          : params;
      await _start(ids, effective);
    } finally {
      _starting = false;
    }
  }

  Future<void> _start(
    Set<String> ids,
    Map<String, Map<String, String>> params,
  ) async {
    final l10n = strings();
    final all = _components(l10n, params);
    final job = expandSelection(all, ids);
    final jobId = 'setup-${_clock().microsecondsSinceEpoch}';
    _jobComponents = job;
    _resetFloors(jobId);
    final startedAt = _clock().millisecondsSinceEpoch;
    final checking = <String, ComponentProgress>{
      for (final component in job)
        component.id: ComponentProgress(
          id: component.id,
          state: component.jobStep
              ? ComponentState.pending
              : ComponentState.checking,
        ),
    };
    _emitLocal(jobId, checking, startedAt);

    // The resume rule: whatever its check finds installed is not redone.
    final Map<String, SetupCheckResult> checks;
    try {
      checks = await _check(job);
    } on BuiltinLinuxException catch (error) {
      _emitLocal(
        jobId,
        {
          for (final c in job)
            c.id: ComponentProgress(id: c.id, state: ComponentState.pending),
        },
        startedAt,
        state: SetupState.failed,
        error: error.message,
      );
      return;
    }
    if (_cancelRequested) {
      _emitLocal(
        jobId,
        _afterChecks(job, checks),
        startedAt,
        state: SetupState.cancelled,
      );
      return;
    }
    _emitLocal(jobId, _afterChecks(job, checks), startedAt);

    final openCode = params[SetupComponentIds.openCode] ?? const {};
    final runtime = TermuxRuntime.parse(openCode['runtime']);
    final openCodeChanged =
        job.any((c) => c.id == SetupComponentIds.openCode) &&
        checks[SetupComponentIds.openCode]?.ok != true;
    final specs = [
      for (final component in job)
        _spec(
          component,
          checks[component.id],
          l10n,
          runtime: runtime,
          openCodeChanged: openCodeChanged,
        ),
    ];
    try {
      await _linux.startSetup(
        jobId: jobId,
        components: specs,
        params: params,
        texts: {
          'channel': l10n.phoneSetupNotificationChannel,
          'title': l10n.phoneSetupNotificationTitle,
          'progress': l10n.phoneSetupNotificationProgress('{percent}'),
          'done': l10n.phoneSetupNotificationDone,
          'stopped': l10n.phoneSetupNotificationStopped,
        },
      );
    } on BuiltinLinuxException catch (error) {
      _emitLocal(
        jobId,
        _afterChecks(job, checks),
        startedAt,
        state: SetupState.failed,
        error: error.message,
      );
      return;
    }
    _handedOver = jobId;
    // A cancel that came while the job was being handed over.
    if (_cancelRequested) {
      try {
        await _linux.cancelSetup();
      } on BuiltinLinuxException {
        // The next read shows how the job ended.
      }
    }
    await _refresh();
    _ensurePolling();
  }

  Map<String, Object?> _spec(
    SetupComponent component,
    SetupCheckResult? check,
    AppLocalizations l10n, {
    required TermuxRuntime runtime,
    required bool openCodeChanged,
  }) {
    final base = <String, Object?>{
      'id': component.id,
      'weight': component.estimatedSeconds,
    };
    if (check?.ok == true) {
      return {...base, 'skipped': true, 'version': check!.version};
    }
    if (component.jobStep) {
      return {
        ...base,
        'step': true,
        'stage': l10n.phoneSetupStageStarting,
        'data': {
          'runtime': runtime.wireName,
          'openCodeChanged': '$openCodeChanged',
        },
      };
    }
    if (component.native) {
      return {
        ...base,
        'native': true,
        'labels': {
          'download': l10n.phoneSetupStageDownloadingLinux,
          'unpack': l10n.phoneSetupStageUnpackingLinux,
        },
      };
    }
    return {...base, 'script': withSetupPrelude(component.installScript)};
  }

  /// Checks [job]'s components: the Linux base by asking Android whether
  /// it is installed, the rest in one proot run. Nothing inside Ubuntu can
  /// pass before Ubuntu is there.
  Future<Map<String, SetupCheckResult>> _check(List<SetupComponent> job) async {
    final status = await _linux.status();
    if (!status.installed) return const {};
    final scripts = <String, String>{
      for (final component in job)
        if (!component.jobStep && component.checkScript.trim().isNotEmpty)
          component.id: component.checkScript,
    };
    final results = scripts.isEmpty
        ? <String, SetupCheckResult>{}
        : parseCombinedChecks(
            (await _linux.run(
              combinedCheckScript(scripts),
              timeout: const Duration(minutes: 2),
            )).output,
          );
    // Android's own marker is the truth for the base; its script only
    // supplies the version.
    for (final component in job.where((c) => c.native)) {
      results[component.id] = (
        ok: true,
        version: results[component.id]?.version,
      );
    }
    return results;
  }

  Map<String, ComponentProgress> _afterChecks(
    List<SetupComponent> job,
    Map<String, SetupCheckResult> checks,
  ) => {
    for (final component in job)
      component.id: checks[component.id]?.ok == true
          ? ComponentProgress(
              id: component.id,
              state: ComponentState.skipped,
              version: checks[component.id]!.version,
            )
          : ComponentProgress(id: component.id, state: ComponentState.pending),
  };

  void _emitLocal(
    String jobId,
    Map<String, ComponentProgress> components,
    int startedAt, {
    SetupState state = SetupState.running,
    String? error,
  }) {
    final list = [
      for (final component in _jobComponents) components[component.id]!,
    ];
    _progress.value = SetupProgress(
      jobId: jobId,
      state: state,
      components: list,
      overall: overallFraction(_jobComponents, list, floors: _floors),
      error: error,
    );
  }

  @override
  Future<void> cancel() async {
    _cancelRequested = true;
    // Still checking: nothing native runs yet, and _start stops on the flag.
    if (_starting && _handedOver != _progress.value.jobId) return;
    final current = _progress.value;
    if (current.state != SetupState.running) return;
    try {
      await _linux.cancelSetup();
    } on BuiltinLinuxException {
      // Nothing native is running (still checking): the flag stops it.
    }
    await _refresh();
  }

  @override
  Future<void> restore() async {
    final record = await _read();
    if (record == null) return;
    _show(record);
    if (record.state == 'running') _ensurePolling();
  }

  @override
  Future<Set<String>> installedOptional() async {
    final optional = [
      for (final component in registry)
        if (!component.required && !component.jobStep) component,
    ];
    if (optional.isEmpty) return {};
    try {
      final checks = await _check(optional);
      return {
        for (final component in optional)
          if (checks[component.id]?.ok == true) component.id,
      };
    } on BuiltinLinuxException {
      return {};
    }
  }

  // ---- polling -------------------------------------------------------------

  void _watchersChanged() {
    if (_progress.watched) _ensurePolling();
  }

  bool get _jobRunning => _record?.state == 'running';

  void _ensurePolling() {
    if (_polling || _disposed) return;
    _polling = true;
    _poll = Timer(pollInterval, _tick);
  }

  Future<void> _tick() async {
    await _refresh();
    if (!_disposed && (_progress.watched || _jobRunning)) {
      _poll = Timer(pollInterval, _tick);
    } else {
      _polling = false;
      _poll = null;
    }
  }

  Future<void> _refresh() async {
    final record = await _read();
    if (record == null) return;
    _show(record);
    if (record.state == 'running' &&
        record.current == SetupComponentIds.start &&
        _finishing != record.jobId) {
      final step = record.component(SetupComponentIds.start);
      if (step != null && step.state == 'running') {
        _finishing = record.jobId;
        unawaited(_finish(record, step));
      }
    }
  }

  Future<void> _finish(SetupJobRecord record, SetupJobComponent step) async {
    final version = record.component(SetupComponentIds.openCode)?.version;
    String? error;
    final finish = finisher;
    if (finish == null) {
      error = strings().phoneSetupErrorCannotStart;
    } else {
      try {
        error = await finish(
          SetupFinishRequest(
            runtime: TermuxRuntime.parse(step.data['runtime']),
            openCodeChanged: step.data['openCodeChanged'] == 'true',
            version: version,
          ),
        );
      } catch (e) {
        error = '$e';
      }
    }
    try {
      await _linux.completeSetupStep(
        jobId: record.jobId,
        id: SetupComponentIds.start,
        ok: error == null,
        error: error,
        version: version,
      );
    } on BuiltinLinuxException {
      // The next poll shows whatever the job did.
    }
    await _refresh();
  }

  Future<SetupJobRecord?> _read() async {
    final String? text;
    try {
      text = await _linux.setupStatus();
    } on BuiltinLinuxException {
      return null;
    }
    final record = SetupJobRecord.parse(text);
    if (record != null) _record = record;
    return record;
  }

  void _show(SetupJobRecord record) {
    final l10n = strings();
    if (_jobComponents.isEmpty ||
        _progress.value.jobId != record.jobId ||
        _jobComponents.length != record.components.length) {
      final all = _components(l10n, record.params);
      _jobComponents = [
        for (final component in record.components)
          all.firstWhere(
            (candidate) => candidate.id == component.id,
            orElse: () => SetupComponent(
              id: component.id,
              title: component.id,
              shortTitle: component.id,
              checkScript: '',
              installScript: '',
            ),
          ),
      ];
    }
    _resetFloors(record.jobId);
    _progress.value = progressFromRecord(
      record,
      _jobComponents,
      l10n,
      now: _clock(),
      floors: _floors,
    );
  }

  void _resetFloors(String jobId) {
    if (_floorsJob == jobId) return;
    _floorsJob = jobId;
    _floors.clear();
  }

  /// Stops polling for good (tests; the app keeps its one engine).
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _polling = false;
  }
}

/// A [ValueNotifier] that tells its engine when the first listener comes and
/// the last goes, so polling runs only while someone watches (or a job
/// runs).
class _WatchedProgress extends ValueNotifier<SetupProgress> {
  _WatchedProgress(this._changed) : super(SetupProgress.idle);

  final VoidCallback _changed;
  var _count = 0;

  bool get watched => _count > 0;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _count++;
    if (_count == 1) _changed();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (_count > 0) _count--;
    if (_count == 0) _changed();
  }
}

// ---- pure parts, tested directly --------------------------------------------

/// [ids] plus every required component, expanded by `dependsOn` and put in
/// dependency order (registry order among equals).
List<SetupComponent> expandSelection(
  List<SetupComponent> registry,
  Set<String> ids,
) {
  final byId = {for (final component in registry) component.id: component};
  final wanted = <String>{};
  void want(String id) {
    final component = byId[id];
    if (component == null || !wanted.add(id)) return;
    component.dependsOn.forEach(want);
  }

  for (final component in registry) {
    if (component.required || ids.contains(component.id)) want(component.id);
  }
  final ordered = <SetupComponent>[];
  final placed = <String>{};
  final visiting = <String>{};
  void place(SetupComponent component) {
    if (placed.contains(component.id)) return;
    if (!visiting.add(component.id)) {
      throw StateError(
        'Setup components depend on each other: ${component.id}',
      );
    }
    for (final dependency in component.dependsOn) {
      final other = byId[dependency];
      if (other != null && wanted.contains(dependency)) place(other);
    }
    visiting.remove(component.id);
    placed.add(component.id);
    ordered.add(component);
  }

  for (final component in registry) {
    if (wanted.contains(component.id)) place(component);
  }
  return ordered;
}

/// 0..1 over [components], each weighted by its estimate. A running one
/// counts its real fraction, or half when it only reports stages, and never
/// less than it already reached ([floors], updated here).
double overallFraction(
  List<SetupComponent> components,
  List<ComponentProgress> progress, {
  Map<String, double>? floors,
}) {
  var total = 0.0;
  var done = 0.0;
  for (var i = 0; i < components.length && i < progress.length; i++) {
    final weight = components[i].estimatedSeconds.toDouble();
    total += weight;
    done += weight * _fraction(progress[i], floors);
  }
  if (total <= 0) return 0;
  return (done / total).clamp(0, 1).toDouble();
}

double _fraction(ComponentProgress progress, Map<String, double>? floors) {
  final double raw = switch (progress.state) {
    ComponentState.done || ComponentState.skipped => 1,
    ComponentState.running => progress.fraction ?? .5,
    _ => 0,
  };
  if (floors == null) return raw;
  if (progress.state == ComponentState.running ||
      progress.state == ComponentState.done ||
      progress.state == ComponentState.skipped) {
    // A running component never shows as finished before it is.
    final capped = progress.state == ComponentState.running
        ? raw.clamp(0, .98).toDouble()
        : raw;
    final best = capped > (floors[progress.id] ?? 0)
        ? capped
        : floors[progress.id]!;
    floors[progress.id] = best;
    return best;
  }
  // Pending or failed after an interruption: keep what it had reached.
  return floors[progress.id] ?? raw;
}

/// Seconds left: the estimates not yet done, scaled by how fast this job has
/// really gone so far. Null until it has made real progress for at least
/// [minimum], so an early guess never shows.
int? estimateEta({
  required List<SetupComponent> components,
  required List<ComponentProgress> progress,
  required double overall,
  required Duration elapsed,
  Duration minimum = const Duration(seconds: 10),
}) {
  if (elapsed < minimum) return null;
  var total = 0.0;
  var before = 0.0;
  for (var i = 0; i < components.length && i < progress.length; i++) {
    final weight = components[i].estimatedSeconds.toDouble();
    total += weight;
    if (progress[i].state == ComponentState.skipped) before += weight;
  }
  final doneNow = overall * total - before;
  if (doneNow <= 0) return null;
  final remaining = total * (1 - overall);
  if (remaining <= 0) return 0;
  final pace = elapsed.inMilliseconds / 1000 / doneNow;
  return (remaining * pace).ceil();
}

/// setup.json, read.
@immutable
class SetupJobRecord {
  const SetupJobRecord({
    required this.jobId,
    required this.state,
    required this.components,
    this.current,
    this.startedAt = 0,
    this.updatedAt = 0,
    this.error,
    this.logTail = '',
    this.params = const {},
  });

  final String jobId;

  /// running | done | failed | cancelled | interrupted
  final String state;
  final String? current;
  final List<SetupJobComponent> components;
  final int startedAt;
  final int updatedAt;
  final String? error;
  final String logTail;
  final Map<String, Map<String, String>> params;

  bool get canContinue =>
      state == 'failed' || state == 'interrupted' || state == 'cancelled';

  SetupJobComponent? component(String id) {
    for (final component in components) {
      if (component.id == id) return component;
    }
    return null;
  }

  /// Null for no job or text that is not a job; unknown fields are ignored
  /// and missing ones take their empty value, so an older or newer runner
  /// never breaks the screen.
  static SetupJobRecord? parse(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final jobId = decoded['jobId'];
    if (jobId is! String || jobId.isEmpty) return null;
    final map = decoded['components'];
    final componentMap = map is Map ? map : const {};
    final order = decoded['order'];
    final ids = order is List
        ? [
            for (final id in order)
              if (id is String) id,
          ]
        : [
            for (final id in componentMap.keys)
              if (id is String) id,
          ];
    final params = <String, Map<String, String>>{};
    final rawParams = decoded['params'];
    if (rawParams is Map) {
      for (final entry in rawParams.entries) {
        if (entry.key is String && entry.value is Map) {
          params[entry.key as String] = _strings(entry.value);
        }
      }
    }
    return SetupJobRecord(
      jobId: jobId,
      state: _string(decoded['state']) ?? 'interrupted',
      current: _string(decoded['current']),
      components: [
        for (final id in ids)
          if (componentMap[id] is Map)
            SetupJobComponent.fromMap(id, componentMap[id] as Map),
      ],
      startedAt: _int(decoded['startedAt']) ?? 0,
      updatedAt: _int(decoded['updatedAt']) ?? 0,
      error: _string(decoded['error']),
      logTail: _string(decoded['logTail']) ?? '',
      params: params,
    );
  }
}

@immutable
class SetupJobComponent {
  const SetupJobComponent({
    required this.id,
    required this.state,
    this.weight = 1,
    this.stage,
    this.done,
    this.total,
    this.percent,
    this.version,
    this.error,
    this.startedAt,
    this.endedAt,
    this.data = const {},
  });

  factory SetupJobComponent.fromMap(String id, Map<Object?, Object?> map) =>
      SetupJobComponent(
        id: id,
        state: _string(map['state']) ?? 'pending',
        weight: (map['weight'] is num) ? (map['weight'] as num).toDouble() : 1,
        stage: _string(map['stage']),
        done: _int(map['done']),
        total: _int(map['total']),
        percent: map['percent'] is num
            ? (map['percent'] as num).toDouble()
            : null,
        version: _string(map['version']),
        error: _string(map['error']),
        startedAt: _int(map['startedAt']),
        endedAt: _int(map['endedAt']),
        data: map['data'] is Map ? _strings(map['data']) : const {},
      );

  final String id;

  /// pending | running | done | failed | skipped
  final String state;
  final double weight;
  final String? stage;
  final int? done;
  final int? total;
  final double? percent;
  final String? version;
  final String? error;
  final int? startedAt;
  final int? endedAt;
  final Map<String, String> data;

  ComponentState get componentState => switch (state) {
    'running' => ComponentState.running,
    'done' => ComponentState.done,
    'failed' => ComponentState.failed,
    'skipped' => ComponentState.skipped,
    _ => ComponentState.pending,
  };
}

String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

int? _int(Object? value) => value is num ? value.toInt() : null;

Map<String, String> _strings(Object? value) => {
  if (value is Map)
    for (final entry in value.entries)
      if (entry.key is String && entry.value != null)
        entry.key as String: '${entry.value}',
};

SetupState _jobState(String state) => switch (state) {
  'running' => SetupState.running,
  'done' => SetupState.done,
  'failed' => SetupState.failed,
  'cancelled' => SetupState.cancelled,
  _ => SetupState.interrupted,
};

/// [record] as the screens see it: states, plain-word errors, the weighted
/// bar and (once honest) the ETA. [components] are the job's, in its order.
SetupProgress progressFromRecord(
  SetupJobRecord record,
  List<SetupComponent> components,
  AppLocalizations l10n, {
  required DateTime now,
  Map<String, double>? floors,
}) {
  final titles = {for (final c in components) c.id: c.shortTitle};
  final list = <ComponentProgress>[];
  String? jobError;
  for (final component in record.components) {
    final state = component.componentState;
    String? error;
    if (state == ComponentState.failed) {
      final failure = describeSetupFailure(
        component,
        record.logTail,
        titles[component.id] ?? component.id,
        l10n,
        step: component.id == SetupComponentIds.start,
      );
      error = failure.component;
      jobError ??= failure.job;
    }
    list.add(
      ComponentProgress(
        id: component.id,
        state: state,
        stage: component.stage,
        bytesDone: component.done,
        bytesTotal: component.total,
        percent: component.percent,
        version: component.version,
        error: error,
      ),
    );
  }
  final state = _jobState(record.state);
  final overall = overallFraction(components, list, floors: floors);
  final elapsed = now.difference(
    DateTime.fromMillisecondsSinceEpoch(record.startedAt),
  );
  return SetupProgress(
    jobId: record.jobId,
    state: state,
    components: list,
    overall: state == SetupState.done ? 1 : overall,
    current: record.current,
    etaSeconds: state == SetupState.running
        ? estimateEta(
            components: components,
            progress: list,
            overall: overall,
            elapsed: elapsed,
          )
        : null,
    error: state == SetupState.failed
        ? jobError ??
              l10n.phoneSetupErrorInstall(
                titles[record.current] ?? record.current ?? 'OpenCode',
              )
        : null,
    logTail: record.logTail,
  );
}

final _offline = RegExp(
  r'Could not resolve|Temporary failure resolving|Unable to resolve host|'
  r'No address associated|Network is unreachable|Could not connect to|'
  r'Failed to connect|Connection timed out|timed out after|'
  r'curl: \((6|7|28|35|52|56)\)|curl exit (6|7|28|35|52|56)\)|'
  r'UnknownHostException|SocketTimeoutException|ConnectException|'
  r'ECONNRESET|ETIMEDOUT|EAI_AGAIN|ENOTFOUND|Failed to fetch',
  caseSensitive: false,
);
final _noSpace = RegExp(
  r'No space left on device|ENOSPC',
  caseSensitive: false,
);
final _checksum = RegExp(
  r'checksum|did not match its checksum',
  caseSensitive: false,
);

/// A failed component in plain words, for its row ([component]) and for the
/// whole job ([job]). The technical reason stays in the log tail, which the
/// details view shows.
({String component, String job}) describeSetupFailure(
  SetupJobComponent failed,
  String logTail,
  String title,
  AppLocalizations l10n, {
  bool step = false,
}) {
  final reason = failed.error ?? '';
  if (step) {
    final text = l10n.phoneSetupErrorStart(
      reason.isEmpty ? l10n.phoneSetupErrorCannotStart : reason,
    );
    return (component: text, job: text);
  }
  // Only the end of the log: an old warning further up is not the reason.
  final lines = logTail.trimRight().split('\n');
  final recent = [
    ...lines.skip(lines.length > 15 ? lines.length - 15 : 0),
    reason,
  ].join('\n');
  if (_noSpace.hasMatch(recent)) {
    final text = l10n.phoneSetupErrorNoSpace(title);
    return (component: text, job: text);
  }
  if (_offline.hasMatch(recent)) {
    return (
      component: l10n.phoneSetupErrorOffline(title),
      job: l10n.phoneSetupErrorNoInternet,
    );
  }
  if (_checksum.hasMatch(reason)) {
    final text = l10n.phoneSetupErrorChecksum(title);
    return (component: text, job: text);
  }
  final text = l10n.phoneSetupErrorInstall(title);
  return (component: text, job: text);
}
