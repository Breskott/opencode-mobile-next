import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/app_exit_recovery.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/builtin/builtin_server.dart';
import 'package:opencode_mobile/builtin/thermal_guard.dart';
import 'package:opencode_mobile/diagnostics/app_diagnostics.dart';
import 'package:opencode_mobile/diagnostics/perf_trace.dart';
import 'package:opencode_mobile/diagnostics/report_problem.dart';
import 'package:opencode_mobile/diagnostics/report_problem_startup.dart';
import 'package:opencode_mobile/platform/app_exit.dart';
import 'package:opencode_mobile/platform/thermal.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake credentials: a registered provider key and pattern-shaped values.
const _providerKey = 'fake-provider-key-7Q2xLp9Vd';
const _bearer = 'Bearer fakeTokenAbc123def456ghi789';
const _password = 'hunter2-fake-password';

final _exitAt = DateTime(2026, 9, 27, 9, 30, 12);

AppExitRecord _crash() => AppExitRecord.fromMap({
  'reason': AndroidExitReason.crash,
  'subReason': -1,
  'status': 0,
  'importance': 100,
  'timestamp': _exitAt.millisecondsSinceEpoch,
  'description': 'crash while sending key $_providerKey',
})!;

class _Store extends ProfileStore {
  _Store({required super.prefs});

  @override
  List<ServerProfile> get profiles => const [];
}

class _Lifecycle extends AppLifecycleBridge {
  _Lifecycle(this.exit);

  final AppExitRecord exit;

  @override
  Future<AppLaunchReport> launchReport() async =>
      AppLaunchReport(exit: exit, previousServices: const []);
}

class _Thermal extends ThermalBridge {
  final controller = StreamController<ThermalReading>.broadcast();

  @override
  Future<ThermalReading> current() async =>
      const ThermalReading(status: ThermalStatus.none);

  @override
  Stream<ThermalReading> readings() => controller.stream;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late AppDiagnosticsController diagnostics;

  File snapshot() => File('${directory.path}/report_problem.json');

  void expectNoSecret(String text) {
    expect(text, isNot(contains(_providerKey)));
    expect(text, isNot(contains('fakeTokenAbc123def456ghi789')));
    expect(text, isNot(contains(_password)));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ReportProblemStartup.resetForTesting();
    KitRedact.clearKnownSecrets();
    KitRedact.registerKnownSecret(_providerKey);
    KitRedact.registerKnownSecret(_password);
    PerfTrace.resetForTesting();
    PerfTrace.logSink = null;
    directory = Directory.systemTemp.createTempSync('report-startup-test-');
    diagnostics = AppDiagnosticsController();
  });

  tearDown(() async {
    await ReportProblemStartup.resetForTesting();
    diagnostics.dispose();
    if (directory.existsSync()) directory.deleteSync(recursive: true);
    PerfTrace.resetForTesting();
    KitRedact.clearKnownSecrets();
  });

  test('start opens once, imports what came before, and keeps every kind '
      'redacted on disk across a crash and reopen', () async {
    // Before the store opens: an error and a timing, both with fake keys.
    diagnostics.record(
      StateError('provider rejected $_providerKey ($_bearer)'),
      StackTrace.fromString('#0 send (password=$_password)'),
      source: 'provider',
    );
    PerfTrace.mark('provider.load', attrs: {'apiKey': _providerKey});

    final first = ReportProblemStartup.start(diagnostics, directory: directory);
    expect(
      identical(first, ReportProblemStartup.start(diagnostics)),
      isTrue,
      reason: 'one store per process',
    );
    final started = await first;
    expect(started, isNotNull);
    expect(ReportProblemStartup.current, same(started));
    expect(await ReportProblemStartup.ready, same(started));

    started!.recordAndroidExit(_crash());
    started.recordThermal(
      const ThermalReading(status: ThermalStatus.severe, headroom: 0.9),
    );
    diagnostics.record(
      'later failure token=$_providerKey',
      null,
      source: 'test',
    );

    // A crash here runs no dispose or flush: read what is already on disk.
    final raw = snapshot().readAsStringSync();
    expectNoSecret(raw);
    expect(raw, contains('androidExit'));
    expect(raw, contains('thermal'));

    final reopened = await ReportProblem.open(directory: directory);
    addTearDown(reopened.dispose);
    final kinds = reopened.entries.map((entry) => entry.kind).toSet();
    expect(kinds, {
      ProblemEventKind.error,
      ProblemEventKind.timing,
      ProblemEventKind.androidExit,
      ProblemEventKind.thermal,
    });
    expect(
      reopened.entries.where((e) => e.message.contains('later failure')),
      hasLength(1),
    );
    expectNoSecret(reopened.reportText());
    expectNoSecret(reopened.reportJson().toString());
  });

  test(
    'notification and log copy made from the report stays redacted',
    () async {
      final started = await ReportProblemStartup.start(
        diagnostics,
        directory: directory,
      );
      diagnostics.record(
        'auth failed with $_bearer and $_providerKey',
        null,
        source: 'test',
      );
      final message = started!.report.entries.last.message;
      expectNoSecret(ReportProblem.notificationText(message));
      expectNoSecret(ReportProblem.logText(message));
      expectNoSecret(ReportProblem.notificationText('key $_providerKey'));
      expectNoSecret(ReportProblem.logText('password=$_password $_bearer'));
      expect(
        ReportProblem.notificationText('x' * 1000).length,
        lessThanOrEqualTo(300),
      );
    },
  );

  test('the report stays within its entry and byte bounds', () async {
    final started = await ReportProblemStartup.start(
      diagnostics,
      directory: directory,
      maxEntries: 5,
      maxBytes: 4096,
    );
    for (var i = 0; i < 40; i++) {
      diagnostics.record('failure $i ${'x' * 400}', null, source: 'loop');
    }
    final report = started!.report;
    expect(report.entries.length, lessThanOrEqualTo(5));
    expect(report.entries.last.message, startsWith('failure 39'));
    expect(snapshot().lengthSync(), lessThanOrEqualTo(4096));
  });

  test("the diagnostics Clear action erases the saved report, also after "
      'a restart', () async {
    var started = await ReportProblemStartup.start(
      diagnostics,
      directory: directory,
    );
    diagnostics.record('before restart', null, source: 'test');
    started!.recordAndroidExit(_crash());
    expect(snapshot().existsSync(), isTrue);

    // Restart: a new process with an empty in-memory diagnostics buffer.
    await ReportProblemStartup.resetForTesting();
    diagnostics.dispose();
    diagnostics = AppDiagnosticsController();
    started = await ReportProblemStartup.start(
      diagnostics,
      directory: directory,
    );
    expect(started!.report.entries, isNotEmpty);

    diagnostics.record('after restart', null, source: 'test');
    diagnostics.clear();
    expect(started.report.entries, isEmpty);
    expect(snapshot().existsSync(), isFalse);

    final reopened = await ReportProblem.open(directory: directory);
    addTearDown(reopened.dispose);
    expect(reopened.entries, isEmpty);
  });

  test('exit recovery keeps the typed exit once, without an error copy, '
      'and not again after a restart', () async {
    final prefs = await SharedPreferences.getInstance();
    final starter = BuiltinServerStarter(linux: BuiltinLinux());
    addTearDown(starter.dispose);
    Future<void> launch() async {
      final recovery = AppExitRecovery(bridge: _Lifecycle(_crash()));
      addTearDown(recovery.dispose);
      await recovery.runOnce(
        store: _Store(prefs: prefs),
        active: null,
        starter: starter,
        diagnostics: diagnostics,
        problemReport: ReportProblemStartup.start(diagnostics, directory: directory),
      );
      await Future<void>.delayed(Duration.zero);
    }

    await launch();
    var report = ReportProblemStartup.current!.report;
    final exits = report.entries
        .where((e) => e.kind == ProblemEventKind.androidExit)
        .toList();
    expect(exits, hasLength(1));
    expect(exits.single.message, contains('reason=4'));
    expectNoSecret(exits.single.message);
    expect(diagnostics.entries.map((e) => e.source), contains('android.exit'));
    expect(
      report.entries.where((e) => e.source == 'android.exit'),
      hasLength(1),
      reason: 'the diagnostics copy of the exit is not stored twice',
    );

    await ReportProblemStartup.resetForTesting();
    await launch();
    report = ReportProblemStartup.current!.report;
    expect(
      report.entries.where((e) => e.kind == ProblemEventKind.androidExit),
      hasLength(1),
    );
  });

  test('the thermal guard hands its readings to the report: changes only, '
      'no unknowns', () async {
    final started = await ReportProblemStartup.start(
      diagnostics,
      directory: directory,
    );
    final prefs = await SharedPreferences.getInstance();
    final guard = ThermalGuard(
      bridge: _Thermal(),
      port: _NoTeams(),
      prefs: prefs,
      inBackground: () => false,
      onReading: started!.recordThermal,
    );
    addTearDown(guard.dispose);
    await guard.observe(ThermalReading.unknown);
    await guard.observe(const ThermalReading(status: ThermalStatus.none));
    await guard.observe(const ThermalReading(status: ThermalStatus.none));
    await guard.observe(const ThermalReading(status: ThermalStatus.severe));
    await guard.observe(const ThermalReading(status: ThermalStatus.severe));
    final thermal = started.report.entries
        .where((e) => e.kind == ProblemEventKind.thermal)
        .map((e) => e.message)
        .toList();
    expect(thermal, hasLength(2));
    expect(thermal.first, startsWith('status=none'));
    expect(thermal.last, startsWith('status=severe'));
  });

  test('a store that cannot open leaves one fixed diagnostics line', () async {
    final blocker = File('${directory.path}/not-a-directory')
      ..writeAsStringSync('x');
    final started = await ReportProblemStartup.start(
      diagnostics,
      directory: Directory(blocker.path),
    );
    expect(started, isNull);
    expect(ReportProblemStartup.current, isNull);
    expect(
      diagnostics.entries.single.message,
      ReportProblemStartup.openFailedMessage,
    );
    expect(diagnostics.entries.single.source, ReportProblemStartup.source);
  });
}
