import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/app_exit_recovery.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/builtin/team/builtin_team.dart';
import 'package:opencode_mobile/builtin/thermal_guard.dart';
import 'package:opencode_mobile/builtin/thermal_guard_teams.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/app_exit.dart';
import 'package:opencode_mobile/platform/thermal.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/keep_running_screen.dart';
import 'package:opencode_mobile/ui/widgets/thermal_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _none = ThermalReading(status: ThermalStatus.none);
const _moderate = ThermalReading(status: ThermalStatus.moderate);
const _severe = ThermalReading(status: ThermalStatus.severe);
const _critical = ThermalReading(status: ThermalStatus.critical);

final _t0 = DateTime(2026, 9, 26, 14);

class _FakeBridge extends ThermalBridge {
  final controller = StreamController<ThermalReading>.broadcast();
  ThermalReading now = _none;
  final notified = <String>[];

  @override
  Future<ThermalReading> current() async => now;

  @override
  Stream<ThermalReading> readings() => controller.stream;

  @override
  Future<bool> notify({required String title, String text = ''}) async {
    notified.add(title);
    return true;
  }
}

const _phoneTeam = ThermalTeam(
  id: 'phone',
  url: 'http://127.0.0.1:8472',
  city: 'phone',
  builtin: true,
);

class _FakePort implements ThermalTeamPort {
  List<ThermalTeam> running = [_phoneTeam];
  final calls = <String>[];
  bool reachable = true;

  @override
  Future<List<ThermalTeam>> runningHere() async => running;

  @override
  Future<ThermalTeamHold?> pause(
    ThermalTeam team, {
    required DateTime now,
  }) async {
    calls.add('pause ${team.id}');
    return ThermalTeamHold(team: team, since: now, sessions: const ['gc-7']);
  }

  @override
  Future<ThermalTeamHold> stop(ThermalTeamHold hold) async {
    calls.add('stop ${hold.team.id}');
    return hold.copyWith(serviceStopped: true);
  }

  @override
  Future<bool> resume(ThermalTeamHold hold) async {
    calls.add(
      'resume ${hold.team.id} ${hold.sessions.join(',')}'
      '${hold.serviceStopped ? ' +service' : ''}',
    );
    return reachable;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThermalPolicy', () {
    test('pauses at SEVERE, stops at CRITICAL and above', () {
      final policy = ThermalPolicy();
      for (final status in [
        ThermalStatus.unknown,
        ThermalStatus.none,
        ThermalStatus.light,
        ThermalStatus.moderate,
      ]) {
        expect(
          policy.decide(ThermalReading(status: status), _t0, enabled: true),
          ThermalAction.none,
          reason: status.name,
        );
      }
      expect(policy.decide(_severe, _t0, enabled: true), ThermalAction.pause);
      for (final status in [
        ThermalStatus.critical,
        ThermalStatus.emergency,
        ThermalStatus.shutdown,
      ]) {
        expect(
          policy.decide(ThermalReading(status: status), _t0, enabled: true),
          ThermalAction.stop,
          reason: status.name,
        );
      }
    });

    test('an early forecast (headroom >= 0.95) pauses before SEVERE', () {
      final policy = ThermalPolicy();
      expect(
        policy.decide(
          const ThermalReading(status: ThermalStatus.light, headroom: 0.94),
          _t0,
          enabled: true,
        ),
        ThermalAction.none,
      );
      expect(
        policy.decide(
          const ThermalReading(status: ThermalStatus.light, headroom: 0.95),
          _t0,
          enabled: true,
        ),
        ThermalAction.pause,
      );
    });

    test('a paused team escalates to a stop at CRITICAL', () {
      final policy = ThermalPolicy()..applied(ThermalAction.pause);
      expect(policy.decide(_severe, _t0, enabled: true), ThermalAction.none);
      expect(policy.decide(_critical, _t0, enabled: true), ThermalAction.stop);
      policy.applied(ThermalAction.stop);
      expect(policy.decide(_critical, _t0, enabled: true), ThermalAction.none);
    });

    test('resumes only after two cool minutes; heat restarts the wait', () {
      final policy = ThermalPolicy()..applied(ThermalAction.pause);
      final at = _t0.add;
      expect(
        policy.decide(_moderate, at(Duration.zero), enabled: true),
        ThermalAction.none,
      );
      expect(
        policy.decide(
          _moderate,
          at(const Duration(seconds: 119)),
          enabled: true,
        ),
        ThermalAction.none,
      );
      // Hot again for a moment: the two minutes start over.
      expect(
        policy.decide(_severe, at(const Duration(seconds: 120)), enabled: true),
        ThermalAction.none,
      );
      expect(
        policy.decide(_none, at(const Duration(seconds: 150)), enabled: true),
        ThermalAction.none,
      );
      expect(
        policy.decide(_none, at(const Duration(seconds: 269)), enabled: true),
        ThermalAction.none,
      );
      expect(
        policy.decide(_none, at(const Duration(seconds: 270)), enabled: true),
        ThermalAction.resume,
      );
      expect(policy.resumeAt, _t0.add(const Duration(seconds: 270)));
    });

    test('turned off: starts nothing, but still gives back what it holds', () {
      final off = ThermalPolicy();
      expect(off.decide(_critical, _t0, enabled: false), ThermalAction.none);
      final holding = ThermalPolicy()..applied(ThermalAction.pause);
      expect(
        holding.decide(_critical, _t0, enabled: false),
        ThermalAction.none,
      );
      holding.decide(_none, _t0, enabled: false);
      expect(
        holding.decide(
          _none,
          _t0.add(const Duration(minutes: 2)),
          enabled: false,
        ),
        ThermalAction.resume,
      );
    });
  });

  group('ThermalGuard', () {
    late SharedPreferences prefs;
    late _FakeBridge bridge;
    late _FakePort port;
    late DateTime now;
    late bool background;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      bridge = _FakeBridge();
      port = _FakePort();
      now = _t0;
      background = true;
    });

    ThermalGuard guard0() => ThermalGuard(
      bridge: bridge,
      port: port,
      prefs: prefs,
      clock: () => now,
      inBackground: () => background,
      strings: () => lookupAppLocalizations(const Locale('en')),
    );

    final en = lookupAppLocalizations(const Locale('en'));

    test(
      'SEVERE pauses the phone\'s team once, keeps it, tells once',
      () async {
        final guard = guard0();
        await guard.observe(_severe);
        expect(port.calls, ['pause phone']);
        expect(guard.hold, ThermalHold.paused);
        expect(guard.notice?.kind, ThermalNoticeKind.paused);
        expect(bridge.notified, [en.thermalPausedNotice]);
        final saved = jsonDecode(prefs.getString('oc.thermalPause.phone')!);
        expect(saved['sessions'], ['gc-7']);
        expect(saved['status'], 'severe');

        // Still hot, more readings: nothing again, no second line.
        guard.dismiss();
        await guard.observe(_severe);
        await guard.observe(
          const ThermalReading(status: ThermalStatus.severe, headroom: 1.1),
        );
        expect(port.calls, ['pause phone']);
        expect(guard.notice, isNull);
        expect(bridge.notified, hasLength(1));
        guard.dispose();
      },
    );

    test(
      'CRITICAL stops it (paused first); one notification per episode',
      () async {
        final guard = guard0();
        await guard.observe(_severe);
        await guard.observe(_critical);
        expect(port.calls, ['pause phone', 'stop phone']);
        expect(guard.hold, ThermalHold.stopped);
        expect(guard.notice?.kind, ThermalNoticeKind.stopped);
        expect(bridge.notified, [en.thermalPausedNotice]);

        // Cool for two minutes: the team comes back, service and sessions.
        now = _t0.add(const Duration(minutes: 1));
        await guard.observe(_moderate);
        expect(port.calls.last, 'stop phone');
        now = _t0.add(const Duration(minutes: 3));
        await guard.observe(_moderate);
        expect(port.calls.last, 'resume phone gc-7 +service');
        expect(guard.hold, ThermalHold.none);
        expect(guard.notice?.kind, ThermalNoticeKind.resumed);
        expect(bridge.notified, [
          en.thermalPausedNotice,
          en.thermalResumedNotice,
        ]);
        expect(prefs.getString('oc.thermalPause.phone'), isNull);
        guard.dispose();
      },
    );

    test('every confirmed pause, stop and resume is reported once per team '
        '(P6.2 While you were away)', () async {
      final acts = <(ThermalNoticeKind, String, DateTime)>[];
      final guard = ThermalGuard(
        bridge: bridge,
        port: port,
        prefs: prefs,
        clock: () => now,
        inBackground: () => background,
        strings: () => lookupAppLocalizations(const Locale('en')),
        onAct: (kind, team, since, at) => acts.add((kind, team.id, at)),
      );
      await guard.observe(_severe);
      await guard.observe(_severe);
      await guard.observe(_critical);
      now = _t0.add(const Duration(minutes: 1));
      await guard.observe(_moderate);
      now = _t0.add(const Duration(minutes: 3));
      await guard.observe(_moderate);
      expect(acts, [
        (ThermalNoticeKind.paused, 'phone', _t0),
        (ThermalNoticeKind.stopped, 'phone', _t0),
        (
          ThermalNoticeKind.resumed,
          'phone',
          _t0.add(const Duration(minutes: 3)),
        ),
      ]);
      guard.dispose();
    });

    test('an unreachable team is not reported as resumed', () async {
      final acts = <ThermalNoticeKind>[];
      final guard = ThermalGuard(
        bridge: bridge,
        port: port,
        prefs: prefs,
        clock: () => now,
        inBackground: () => background,
        strings: () => lookupAppLocalizations(const Locale('en')),
        onAct: (kind, team, since, at) => acts.add(kind),
      );
      await guard.observe(_severe);
      port.reachable = false;
      now = _t0.add(const Duration(minutes: 1));
      await guard.observe(_moderate);
      now = _t0.add(const Duration(minutes: 3));
      await guard.observe(_moderate);
      expect(acts, [ThermalNoticeKind.paused]);
      guard.dispose();
    });

    test('no notification while the app is on screen', () async {
      background = false;
      final guard = guard0();
      await guard.observe(_severe);
      expect(guard.notice?.kind, ThermalNoticeKind.paused);
      expect(bridge.notified, isEmpty);
      guard.dispose();
    });

    test('acts only when a team works on this phone', () async {
      port.running = [];
      final guard = guard0();
      await guard.observe(_critical);
      expect(port.calls, isEmpty);
      expect(guard.hold, ThermalHold.none);
      expect(guard.notice, isNull);
      expect(bridge.notified, isEmpty);
      guard.dispose();
    });

    test('switched off: no action at all', () async {
      final guard = guard0();
      await guard.setEnabled(false);
      await guard.observe(_critical);
      expect(port.calls, isEmpty);
      expect(guard.notice, isNull);
      expect(prefs.getBool(ThermalGuard.enabledKey), isFalse);
      guard.dispose();
    });

    test(
      'an unreachable team is tried again after another cool wait',
      () async {
        final guard = guard0();
        await guard.observe(_severe);
        port.reachable = false;
        now = _t0.add(const Duration(minutes: 1));
        await guard.observe(_none);
        now = _t0.add(const Duration(minutes: 3));
        await guard.observe(_none);
        expect(port.calls.last, startsWith('resume'));
        expect(guard.hold, ThermalHold.paused);
        port.reachable = true;
        now = _t0.add(const Duration(minutes: 5, seconds: 1));
        await guard.observe(_none);
        expect(guard.hold, ThermalHold.none);
        guard.dispose();
      },
    );

    test(
      'a pause survives the app dying: the next process resumes it',
      () async {
        final first = guard0();
        await first.observe(_severe);
        first.dispose();

        final second = guard0();
        bridge.now = _moderate;
        await second.start();
        expect(second.hold, ThermalHold.paused);
        expect(port.calls, ['pause phone']);
        now = _t0.add(const Duration(minutes: 2));
        await second.observe(_moderate);
        expect(port.calls.last, 'resume phone gc-7');
        expect(second.hold, ThermalHold.none);
        second.dispose();
      },
    );
  });

  group('GasCityThermalTeams (the supervisor API)', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    ProfileStore storeWith(List<ServerProfile> profiles) =>
        _Store(prefs: prefs, all: profiles);

    final phone = ServerProfile(
      id: 'phone',
      name: 'This phone',
      baseUrl: BuiltinLinux.serverUrl,
      orchestration: BuiltinTeam.config(),
    );
    final laptop = ServerProfile(
      id: 'laptop',
      name: 'Laptop',
      baseUrl: 'http://192.168.1.20:4096',
      orchestration: const OrchestrationConfig(
        provider: OrchestrationProvider.gascity,
        url: 'http://100.64.0.2:8372',
        city: 'desk',
      ),
    );

    test('only loopback teams count as on this phone', () {
      final teams = GasCityThermalTeams(
        store: storeWith([phone, laptop]),
        http: (_, _, [_]) async => null,
      ).teamsHere();
      expect(teams.map((t) => t.id), ['phone']);
      expect(teams.single.builtin, isTrue);
    });

    test('pause suspends the city and the running sessions only; resume '
        'gives back exactly those', () async {
      final requests = <String>[];
      var citySuspended = false;
      Future<ThermalHttpAnswer?> http(
        String method,
        Uri uri, [
        Map<String, Object?>? body,
      ]) async {
        requests.add('$method ${uri.path}${body == null ? '' : ' $body'}');
        if (uri.path == '/v0/city/phone') {
          if (method == 'PATCH') citySuspended = body!['suspended'] == true;
          return ThermalHttpAnswer(200, {'suspended': citySuspended});
        }
        if (uri.path == '/v0/city/phone/sessions') {
          return const ThermalHttpAnswer(200, {
            'items': [
              {'id': 'gc-1', 'state': 'active', 'running': true},
              // Asleep or suspended by the person: never touched.
              {'id': 'gc-2', 'state': 'suspended', 'running': false},
              {'id': 'gc-3', 'state': 'asleep', 'running': false},
            ],
          });
        }
        return const ThermalHttpAnswer(200, {});
      }

      final teams = GasCityThermalTeams(store: storeWith([phone]), http: http);
      expect(await teams.runningHere(), hasLength(1));
      final hold = await teams.pause(_phoneTeam, now: _t0);
      expect(hold!.sessions, ['gc-1']);
      expect(requests, [
        'GET /v0/city/phone',
        'GET /v0/city/phone',
        'PATCH /v0/city/phone {suspended: true}',
        'GET /v0/city/phone/sessions',
        'POST /v0/city/phone/session/gc-1/suspend',
      ]);

      requests.clear();
      expect(await teams.resume(hold), isTrue);
      expect(requests, [
        'GET /v0/city/phone',
        'PATCH /v0/city/phone {suspended: false}',
        'POST /v0/city/phone/session/gc-1/wake',
      ]);
    });

    test('a city the person suspended is left alone', () async {
      final requests = <String>[];
      final teams = GasCityThermalTeams(
        store: storeWith([phone]),
        http: (method, uri, [body]) async {
          requests.add('$method ${uri.path}');
          return const ThermalHttpAnswer(200, {'suspended': true});
        },
      );
      expect(await teams.runningHere(), isEmpty);
      expect(await teams.pause(_phoneTeam, now: _t0), isNull);
      expect(requests.where((r) => !r.startsWith('GET')), isEmpty);
    });

    test(
      'a team the person turned off meanwhile is not started again',
      () async {
        final requests = <String>[];
        final teams = GasCityThermalTeams(
          store: storeWith([]),
          http: (method, uri, [body]) async {
            requests.add('$method ${uri.path}');
            return const ThermalHttpAnswer(200, {'suspended': true});
          },
        );
        final done = await teams.resume(
          ThermalTeamHold(
            team: _phoneTeam,
            since: _t0,
            sessions: const ['gc-1'],
            serviceStopped: true,
          ),
        );
        expect(done, isTrue);
        expect(requests, isEmpty);
      },
    );
  });

  group('oc/thermal (the Kotlin half, faked)', () {
    const channel = MethodChannel(ThermalBridge.channelName);
    const events = EventChannel(ThermalBridge.eventsName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockStreamHandler(events, null);
    });

    test('ThermalMonitor.kt words map onto the statuses', () async {
      final answers = <Object?>[
        {'status': 'severe', 'headroom': 0.97, 'sdk': 35},
        {'status': 'critical', 'headroom': -1.0, 'sdk': 29},
        {'status': 'shutdown', 'headroom': double.nan},
        {'status': 'unknown', 'headroom': -1.0, 'sdk': 28},
        {'status': 'lukewarm'},
        null,
      ];
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'current');
        return answers.removeAt(0);
      });
      final bridge = ThermalBridge();
      expect(
        await bridge.current(),
        const ThermalReading(status: ThermalStatus.severe, headroom: 0.97),
      );
      expect(await bridge.current(), _critical);
      expect(
        await bridge.current(),
        const ThermalReading(status: ThermalStatus.shutdown),
      );
      expect((await bridge.current()).status, ThermalStatus.unknown);
      expect((await bridge.current()).status, ThermalStatus.unknown);
      expect(await bridge.current(), ThermalReading.unknown);
      expect(ThermalStatus.values.map((s) => s.name).skip(1), [
        'none',
        'light',
        'moderate',
        'severe',
        'critical',
        'emergency',
        'shutdown',
      ], reason: 'ThermalMonitor.statusName answers these words');
    });

    test('events arrive as readings; a missing channel is safe', () async {
      messenger.setMockStreamHandler(
        events,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            sink.success({'status': 'moderate', 'headroom': 0.6});
            sink.success({'status': 'severe', 'headroom': 0.99});
            sink.endOfStream();
          },
        ),
      );
      final readings = await ThermalBridge().readings().toList();
      expect(readings.map((r) => r.status), [
        ThermalStatus.moderate,
        ThermalStatus.severe,
      ]);
      expect(await ThermalBridge().current(), ThermalReading.unknown);
      expect(await ThermalBridge().notify(title: 'x'), isFalse);
    });

    test('notify passes the words only', () async {
      Object? args;
      messenger.setMockMethodCallHandler(channel, (call) async {
        args = call.arguments;
        return call.method == 'notify';
      });
      expect(await ThermalBridge().notify(title: 'Hot'), isTrue);
      expect(args, {'title': 'Hot', 'text': ''});
    });
  });

  group('the shell line and the setting', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Widget app(ThermalGuard guard, Widget home) => ProviderScope(
      overrides: [
        thermalGuardSlotProvider.overrideWithValue(
          ValueNotifier<ThermalGuard?>(guard),
        ),
        appLifecycleBridgeProvider.overrideWithValue(_Lifecycle()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

    testWidgets('paused once, then resumed; dismissed stays away', (
      tester,
    ) async {
      final en = lookupAppLocalizations(const Locale('en'));
      var now = _t0;
      final port = _FakePort();
      final guard = ThermalGuard(
        bridge: _FakeBridge(),
        port: port,
        prefs: prefs,
        clock: () => now,
        inBackground: () => false,
      );
      addTearDown(guard.dispose);
      await tester.pumpWidget(
        app(
          guard,
          const Scaffold(body: Column(children: [ThermalNoticeLine()])),
        ),
      );
      expect(find.text(en.thermalPausedNotice), findsNothing);

      await tester.runAsync(() => guard.observe(_severe));
      await tester.pumpAndSettle();
      expect(find.text(en.thermalPausedNotice), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('kit-notice-dismiss')));
      await tester.pumpAndSettle();
      expect(find.text(en.thermalPausedNotice), findsNothing);
      await tester.runAsync(() => guard.observe(_severe));
      await tester.pumpAndSettle();
      expect(find.text(en.thermalPausedNotice), findsNothing);

      now = _t0.add(const Duration(minutes: 1));
      await tester.runAsync(() => guard.observe(_none));
      now = _t0.add(const Duration(minutes: 3));
      await tester.runAsync(() => guard.observe(_none));
      await tester.pumpAndSettle();
      expect(find.text(en.thermalResumedNotice), findsOneWidget);
    });

    testWidgets('the Keep running screen has the switch, on by default', (
      tester,
    ) async {
      final en = lookupAppLocalizations(const Locale('en'));
      final guard = ThermalGuard(
        bridge: _FakeBridge(),
        port: _FakePort(),
        prefs: prefs,
      );
      addTearDown(guard.dispose);
      tester.view
        ..physicalSize = const Size(412, 915)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(guard, const KeepRunningScreen()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(en.thermalGuardSetting),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(en.thermalGuardSettingDetail), findsOneWidget);
      final toggle = find.byKey(const ValueKey('keep-running-thermal-switch'));
      expect(tester.widget<Switch>(toggle).value, isTrue);
      await tester.tap(find.text(en.thermalGuardSetting));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(toggle).value, isFalse);
      expect(prefs.getBool(ThermalGuard.enabledKey), isFalse);
    });
  });
}

class _Store extends ProfileStore {
  _Store({required super.prefs, required this.all});

  final List<ServerProfile> all;

  @override
  List<ServerProfile> get profiles => all;
}

class _Lifecycle extends AppLifecycleBridge {
  @override
  Future<KeepAliveInfo> keepAliveInfo() async =>
      const KeepAliveInfo(manufacturer: 'Google', brand: 'google');
}
