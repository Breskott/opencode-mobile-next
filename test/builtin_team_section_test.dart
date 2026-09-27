// Settings › Plugins › "AI Team on this phone" while the team is turned on
// (owner's phone, build 2054: "Is it normal to take long?"): the turn-on is
// the app's one job, so it goes on when the screen is left and shows again;
// no disabled "Turn on" beside it; the stages as a list with the current
// one marked and each one's time; the store made in the background once AI
// Team is installed, which Turn on waits for instead of racing.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/builtin/team/builtin_team.dart';
import 'package:opencode_mobile/builtin/team/builtin_team_job.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit_status_mark.dart';
import 'package:opencode_mobile/ui/widgets/builtin_team_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Store extends ProfileStore {
  _Store({required super.prefs, required this.saved});

  final List<ServerProfile> saved;

  @override
  List<ServerProfile> get profiles => List.unmodifiable(saved);

  @override
  String? get activeId => saved.first.id;
}

/// A team whose turn-on waits at each stage for the test.
class _FakeTeam extends BuiltinTeam {
  _FakeTeam() : super(linux: BuiltinLinux());

  BuiltinTeamState state = const BuiltinTeamState(installed: true);
  final gates = {
    for (final stage in BuiltinTeamStage.values) stage: Completer<void>(),
  };
  BuiltinTeamStage? failAt;
  int prepares = 0;
  int turnOns = 0;
  int turnOffs = 0;

  @override
  Future<void> turnOff() async {
    turnOffs++;
    state = BuiltinTeamState(installed: true, hasCity: true, rigs: state.rigs);
  }

  @override
  Future<BuiltinTeamState> status() async => state;

  @override
  Future<void> prepare() async => prepares++;

  @override
  Future<void> turnOn(
    String path, {
    required String notice,
    void Function(BuiltinTeamStage stage)? onStage,
    Duration healthTimeout = const Duration(minutes: 6),
  }) async {
    turnOns++;
    for (final stage in BuiltinTeamStage.values) {
      onStage?.call(stage);
      await gates[stage]!.future;
      if (failAt == stage) {
        throw BuiltinTeamException(stage, 'bd init: schema\ndirty tables');
      }
    }
    state = const BuiltinTeamState(
      installed: true,
      hasCity: true,
      rigs: ['my-app'],
      running: true,
    );
  }
}

final _en = lookupAppLocalizations(const Locale('en'));

void main() {
  late _FakeTeam team;
  late DateTime now;
  late ConnectionController connection;
  late ServerProfile profile;

  setUp(() async {
    debugPlatformCapabilities = const PlatformCapabilities.android();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => call.method == 'readAll' ? <String, String>{} : null,
        );
    SharedPreferences.setMockInitialValues({});
    profile = ServerProfile(
      id: 'phone',
      name: 'This phone',
      baseUrl: BuiltinLinux.serverUrl,
      username: BuiltinLinux.serverUsername,
      password: 'secret',
    );
    connection = ConnectionController(
      _Store(prefs: await SharedPreferences.getInstance(), saved: [profile]),
    )..directory = '/root/projects/my-app';
    now = DateTime.utc(2026, 9, 25, 11, 30);
    BuiltinTeamJob.debugShared = BuiltinTeamJob(now: () => now);
  });

  tearDown(() {
    debugBuiltinTeam = null;
    BuiltinTeamJob.debugShared = null;
    debugPlatformCapabilities = null;
    connection.dispose();
  });

  Future<void> pumpSection(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BuiltinTeamSection(connection: connection, profile: profile),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Leaves the screen (the section and its ticker go).
  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  KitMarkState markOf(WidgetTester tester, BuiltinTeamStage stage) => tester
      .widget<KitStatusMark>(
        find.descendant(
          of: find.byKey(ValueKey('builtin-team-stage-${stage.name}')),
          matching: find.byType(KitStatusMark),
        ),
      )
      .state;

  /// The fake team, made inside the test's own zone: its gates' futures
  /// must complete on the fake clock's microtask queue.
  void useTeam() {
    team = _FakeTeam();
    debugBuiltinTeam = team;
  }

  Future<void> advance(WidgetTester tester, Duration by) async {
    now = now.add(by);
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('a turn-on shows its stages with times and no disabled button, '
      'and goes on when the screen is left', (tester) async {
    useTeam();
    await pumpSection(tester);
    // Installed without a store: it is made now, in the background.
    expect(team.prepares, 1);
    final turnOn = find.byKey(const ValueKey('builtin-team-turn-on'));
    expect(turnOn, findsOneWidget);
    await tester.tap(turnOn);
    await tester.pump();

    // While it runs: the job only. No Turn on, no other action.
    expect(turnOn, findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.text(_en.aiteamComponentTurnOnExpectation), findsOneWidget);
    expect(markOf(tester, BuiltinTeamStage.preparing), KitMarkState.working);
    expect(
      markOf(tester, BuiltinTeamStage.addingProject),
      KitMarkState.waiting,
    );
    expect(find.text(_en.aiteamComponentStageSoFar('0:00')), findsOneWidget);
    await advance(tester, const Duration(seconds: 65));
    expect(find.text(_en.aiteamComponentStageSoFar('1:05')), findsOneWidget);

    team.gates[BuiltinTeamStage.preparing]!.complete();
    await tester.pump();
    await tester.pump();
    expect(markOf(tester, BuiltinTeamStage.preparing), KitMarkState.done);
    expect(find.text(_en.aiteamComponentStageTook('1:05')), findsOneWidget);
    expect(
      markOf(tester, BuiltinTeamStage.addingProject),
      KitMarkState.working,
    );
    expect(
      find.text(_en.aiteamComponentStageProject('my-app')),
      findsOneWidget,
    );

    // Leave Plugins and come back: the same job, where it got to.
    await leave(tester);
    await pumpSection(tester);
    expect(
      markOf(tester, BuiltinTeamStage.addingProject),
      KitMarkState.working,
    );
    expect(find.byKey(const ValueKey('builtin-team-turn-on')), findsNothing);
    expect(team.turnOns, 1);
    // Not a second store beside the job's own.
    expect(team.prepares, 1);

    // It finishes while the screen is away: the profile still gets the team.
    await leave(tester);
    for (final stage in [
      BuiltinTeamStage.addingProject,
      BuiltinTeamStage.starting,
      BuiltinTeamStage.waiting,
    ]) {
      now = now.add(const Duration(seconds: 30));
      team.gates[stage]!.complete();
      await tester.pump();
    }
    await tester.pump();
    expect(BuiltinTeam.isBuiltinConfig(profile.orchestration), isTrue);
    expect(BuiltinTeamJob.shared.running, isFalse);
    expect(
      BuiltinTeamJob.shared.took(BuiltinTeamStage.waiting),
      const Duration(seconds: 30),
    );
    await pumpSection(tester);
    expect(find.text(_en.aiteamComponentRunning), findsOneWidget);
    expect(
      find.byKey(const ValueKey('builtin-team-stage-preparing')),
      findsNothing,
    );
    await leave(tester);
  });

  testWidgets('a failed stage is marked, said in words, and Turn on is back', (
    tester,
  ) async {
    useTeam();
    team.failAt = BuiltinTeamStage.addingProject;
    await pumpSection(tester);
    await tester.tap(find.byKey(const ValueKey('builtin-team-turn-on')));
    await tester.pump();
    team.gates[BuiltinTeamStage.preparing]!.complete();
    await advance(tester, const Duration(seconds: 12));
    team.gates[BuiltinTeamStage.addingProject]!.complete();
    await tester.pump();
    await tester.pump();
    expect(markOf(tester, BuiltinTeamStage.preparing), KitMarkState.done);
    expect(markOf(tester, BuiltinTeamStage.addingProject), KitMarkState.failed);
    expect(markOf(tester, BuiltinTeamStage.starting), KitMarkState.waiting);
    // The script's output is not the words: it is said plainly, and the
    // output itself stays under Details.
    expect(
      find.text(_en.aiteamComponentFailed(_en.productErrorDevice)),
      findsOneWidget,
    );
    expect(find.text('dirty tables'), findsNothing);
    expect(find.byKey(const ValueKey('builtin-team-turn-on')), findsOneWidget);
    expect(find.text(_en.aiteamComponentTurnOnExpectation), findsNothing);
    expect(profile.orchestration, isNull);
    await leave(tester);
  });

  test('the job records each stage and keeps the failed one', () async {
    var clock = DateTime.utc(2026);
    final job = BuiltinTeamJob(now: () => clock);
    final gate = Completer<void>();
    final run = job.run(
      stages: BuiltinTeamStage.values,
      work: (onStage) async {
        onStage(BuiltinTeamStage.preparing);
        clock = clock.add(const Duration(minutes: 2));
        onStage(BuiltinTeamStage.addingProject);
        clock = clock.add(const Duration(seconds: 7));
        await gate.future;
        throw StateError('no');
      },
    );
    expect(job.running, isTrue);
    expect(job.took(BuiltinTeamStage.preparing), const Duration(minutes: 2));
    expect(
      job.elapsed(BuiltinTeamStage.addingProject),
      const Duration(seconds: 7),
    );
    // A second job while one runs does nothing.
    var second = false;
    await job.run(stages: const [], work: (_) async => second = true);
    expect(second, isFalse);
    gate.complete();
    await run;
    expect(job.running, isFalse);
    expect(job.stage, BuiltinTeamStage.addingProject);
    expect(job.error, isA<StateError>());
    expect(job.took(BuiltinTeamStage.addingProject), isNull);
  });

  test('turn-on waits for the store prepare is making, never a second one '
      'beside it', () async {
    const channel = MethodChannel(BuiltinLinux.channelName);
    final release = Completer<void>();
    var running = 0;
    var most = 0;
    final scripts = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = (call.arguments as Map?) ?? const {};
          switch (call.method) {
            case 'status':
              return {
                'installed': true,
                'phase': 'ready',
                'services': ['aiteam'],
              };
            case 'run':
              final script = args['script'] as String;
              scripts.add(script);
              running++;
              most = running > most ? running : most;
              if (script == BuiltinTeam.cityScript && !release.isCompleted) {
                await release.future;
              }
              running--;
              return {'exitCode': 0, 'output': ''};
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final real = BuiltinTeam(
      linux: BuiltinLinux(),
      httpGet: (_) async => '{"status":"ok"}',
      pollInterval: Duration.zero,
    );
    final preparing = real.prepare();
    expect(identical(real.prepare(), preparing), isTrue);
    final turnOn = real.turnOn('/root/projects/my-app', notice: 'n');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // Only the background store is being made; turn-on waits for it.
    expect(scripts, [BuiltinTeam.cityScript]);
    release.complete();
    await preparing;
    await turnOn;
    expect(most, 1);
    expect(scripts.first, BuiltinTeam.cityScript);
    expect(scripts[1], BuiltinTeam.cityScript);
    expect(
      scripts[2],
      BuiltinTeam.rigScript('/root/projects/my-app', 'my-app'),
    );
  });

  testWidgets('Turn off asks first, says what stays, turns the team off for '
      'good and takes its config off the profile (P1.4)', (tester) async {
    useTeam();
    team.state = const BuiltinTeamState(
      installed: true,
      hasCity: true,
      rigs: ['my-app'],
      running: true,
    );
    profile.orchestration = BuiltinTeam.config();
    await pumpSection(tester);
    // One act ends the team's work, and it is the lasting one.
    expect(find.text(_en.aiteamComponentTurnOff), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('builtin-team-turn-off')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('builtin-team-turn-off-sheet')),
      findsOneWidget,
    );
    expect(find.text(_en.aiteamComponentTurnOffKept), findsOneWidget);
    expect(team.turnOffs, 0, reason: 'the question changes nothing');
    await tester.tap(
      find.byKey(const ValueKey('builtin-team-turn-off-confirm')),
    );
    await tester.pumpAndSettle();
    expect(team.turnOffs, 1);
    expect(profile.orchestration, isNull);
    // Off: turning it on again is the way back.
    expect(find.byKey(const ValueKey('builtin-team-turn-on')), findsOneWidget);
    await leave(tester);
  });
}
