// TEAM-305: Running now. The embedded tools script's procs-scan groups a
// fixture `ps` listing (stub on PATH) the way the owner's phone looked, and
// procs-stop is exercised against real `sleep` processes on the PC; the
// screen runs over a mocked `oc/termux` channel.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:opencode_mobile/termux/processes.dart';
import 'package:opencode_mobile/ui/screens/termux_processes_screen.dart';

/// The owner's phone this week: the manager, `opencode serve` with an MCP
/// child, an orphaned `minimax-coding-plan-mcp` at 100% CPU for an hour, a
/// Gradle daemon, a Gas City (gc, dolt, `opencode acp` + helper), a stray
/// script with a live shell parent and ten minutes of CPU, sshd and shells.
const _phonePs = '''
  100     1  0.0 00:00:00 2000  5000 bash /data/data/com.termux/files/usr/bin/bash /data/data/com.termux/files/home/.oc/manager.sh setup 4096
  101   100  0.2 00:01:00 90000 4000 opencode opencode serve --hostname 127.0.0.1 --port 4096
  102   101  0.0 00:00:03 30000 3900 node node /root/.npm/_npx/abc/node_modules/.bin/some-mcp
  200     1 99.0 01:02:03 45000 3700 node node /root/.npm/_npx/xyz/node_modules/minimax-coding-plan-mcp/dist/index.js
  300     1  1.0 02:00:00 300000 7200 java java -Xmx2g org.gradle.launcher.daemon.bootstrap.GradleDaemon 8.5
  400     1  0.0 00:00:10 20000 1000 gc /data/data/com.termux/files/usr/bin/gc start
  401   400  0.0 00:00:05 40000 900 dolt dolt sql-server
  402   400  0.5 00:00:07 50000 800 opencode opencode acp
  403   402  0.0 00:00:01 10000 700 node node /x/mcp-helper
  500   700  0.0 00:10:00 1000 5000 python3 python3 /root/stray.py
  600     1  0.0 00:00:00 3000 100 sshd sshd: /usr/sbin/sshd
  700     1  0.0 00:00:00 3000 100 bash bash
  800   700  3.0 00:00:30 5000 40 node node build/watch.js
''';

class _Phone {
  _Phone() {
    root = Directory.systemTemp.createTempSync('oc-tools-procs-');
    home = Directory('${root.path}/home')..createSync();
    bin = Directory('${root.path}/bin')..createSync();
    tools = File('${root.path}/tools.sh')
      ..writeAsStringSync(TermuxBridge.toolsScriptForTesting());
    final ps = File('${bin.path}/ps')
      ..writeAsStringSync('#!/bin/bash\ncat "\$OC_PS_FIXTURE"\n');
    Process.runSync('chmod', ['+x', ps.path]);
    psFixture = File('${root.path}/ps.txt')..writeAsStringSync(_phonePs);
  }

  late final Directory root;
  late final Directory home;
  late final Directory bin;
  late final File tools;
  late final File psFixture;

  void processes(String lines) => psFixture.writeAsStringSync(lines);

  ProcessResult run(List<String> args) => Process.runSync(
    'bash',
    [tools.path, ...args],
    environment: {
      ...Platform.environment,
      'HOME': home.path,
      'PREFIX': '${root.path}/prefix',
      'PATH': '${bin.path}:${Platform.environment['PATH']}',
      'OC_PS_FIXTURE': psFixture.path,
    },
  );

  TermuxProcessReport scan() {
    final result = run(['procs-scan']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    return TermuxProcessReport.parse(result.stdout as String);
  }

  TermuxProcessStopResult stop(String target) {
    final result = run(['procs-stop', target]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    return TermuxProcessStopResult.parse(result.stdout as String);
  }

  void dispose() => root.deleteSync(recursive: true);
}

_Phone _phone() {
  final phone = _Phone();
  addTearDown(phone.dispose);
  return phone;
}

Map<int, TermuxProcess> _byPid(TermuxProcessReport report) => {
  for (final p in report.processes) p.pid: p,
};

void main() {
  group('tools.sh procs-scan', () {
    test('groups by ancestry and flags orphans with a reason', () {
      final report = _phone().scan();
      final p = _byPid(report);
      expect(
        p.keys,
        containsAll([
          100,
          101,
          102,
          200,
          300,
          400,
          401,
          402,
          403,
          500,
          600,
          700,
          800,
        ]),
      );
      expect(p.keys, isNot(contains(1)));
      // OpenCode server: manager, `opencode serve` (protected) and its MCP.
      expect(p[100]!.group, TermuxProcessGroup.opencodeServer);
      expect(p[100]!.protected, isTrue);
      expect(p[101]!.group, TermuxProcessGroup.opencodeServer);
      expect(p[101]!.protected, isTrue);
      expect(p[101]!.name, 'opencode serve');
      expect(p[101]!.cpuSeconds, 60);
      expect(p[102]!.group, TermuxProcessGroup.opencodeServer);
      expect(p[102]!.protected, isFalse);
      expect(p[102]!.name, 'some-mcp');
      // The minimax case: parent gone, an hour of CPU.
      expect(p[200]!.group, TermuxProcessGroup.orphans);
      expect(p[200]!.orphanReason, TermuxOrphanReason.parentGone);
      expect(p[200]!.name, 'minimax-coding-plan-mcp');
      expect(p[200]!.cpuSeconds, 3723);
      expect(p[200]!.cpuPct, 99.0);
      // Build daemons keep their group even when daemonised (ppid 1).
      expect(p[300]!.group, TermuxProcessGroup.buildDaemons);
      expect(p[300]!.name, 'Gradle daemon');
      expect(p[300]!.orphanReason, isNull);
      // AI Team: supervisor, dolt, per-agent acp and its helper.
      for (final pid in [400, 401, 402, 403]) {
        expect(p[pid]!.group, TermuxProcessGroup.aiTeam, reason: '$pid');
        expect(p[pid]!.protected, isFalse);
      }
      expect(p[402]!.name, 'opencode acp');
      // Ten minutes of CPU under a plain shell: no OpenCode or gc owner.
      expect(p[500]!.group, TermuxProcessGroup.orphans);
      expect(p[500]!.orphanReason, TermuxOrphanReason.cpuNoOwner);
      expect(p[500]!.name, 'stray.py');
      // sshd is protected; shells are plain "other".
      expect(p[600]!.group, TermuxProcessGroup.other);
      expect(p[600]!.protected, isTrue);
      expect(p[700]!.group, TermuxProcessGroup.other);
      expect(p[700]!.protected, isFalse);
      expect(p[700]!.orphanReason, isNull);
      // node not under OpenCode is a build daemon; little CPU, live parent.
      expect(p[800]!.group, TermuxProcessGroup.buildDaemons);
      expect(p[800]!.name, 'watch.js');
      expect(
        report.orphansOver(const Duration(minutes: 10)).map((o) => o.pid),
        [200],
      );
      expect(report.orphansOver(const Duration(minutes: 5)).map((o) => o.pid), [
        200,
        500,
      ]);
      expect(report.totalCpuPct, closeTo(103.7, 0.01));
    });

    test('an MCP whose live parent is opencode serve is never an orphan', () {
      final phone = _phone();
      phone.processes(
        '  101     1  0.2 00:01:00 90000 4000 opencode opencode serve --hostname 127.0.0.1 --port 4096\n'
        '  102   101 50.0 01:00:00 30000 3900 node node /root/.npm/_npx/abc/node_modules/.bin/busy-mcp\n',
      );
      final p = _byPid(phone.scan());
      expect(p[102]!.group, TermuxProcessGroup.opencodeServer);
      expect(p[102]!.orphanReason, isNull);
    });

    test('reads the listing without procps by walking /proc', () {
      final phone = _phone();
      File('${phone.bin.path}/ps').deleteSync();
      final result = phone.run(['procs-scan']);
      expect(result.exitCode, 0, reason: result.stderr as String);
      final report = TermuxProcessReport.parse(result.stdout as String);
      // This very test runner is one of the processes the walk sees.
      expect(report.processes.any((p) => p.pid == pid), isTrue);
    });
  });

  group('tools.sh procs-stop', () {
    test('refuses protected processes, the server group and unknown pids', () {
      final phone = _phone();
      expect(phone.stop('101').refused.single, (pid: 101, reason: 'protected'));
      expect(phone.stop('600').refused.single, (pid: 600, reason: 'protected'));
      expect(
        phone.stop('opencode_server').refused.single.reason,
        'protected_group',
      );
      expect(phone.stop('4242').refused.single.reason, 'not_found');
      expect(phone.run(['procs-stop', 'zygote']).exitCode, 64);
      expect(phone.run(['procs-stop']).exitCode, 64);
    });

    test('TERM ends a cooperative process; KILL follows after 5 s', () async {
      final phone = _phone();
      final polite = await Process.start('sleep', ['300']);
      final stubborn = await Process.start('bash', [
        '-c',
        'trap "" TERM; sleep 300',
      ]);
      addTearDown(() {
        polite.kill(ProcessSignal.sigkill);
        stubborn.kill(ProcessSignal.sigkill);
        Process.runSync('pkill', ['-KILL', '-P', '${stubborn.pid}']);
      });
      phone.processes(
        '  ${polite.pid}     1  0.0 00:00:00 3000 100 sleep sleep 300\n'
        '  ${stubborn.pid}     1  0.0 00:00:00 3000 100 bash bash -c trap\n',
      );
      final first = phone.stop('${polite.pid}');
      expect(first.stopped, [polite.pid]);
      expect(first.killed, isEmpty);
      expect(first.remaining, isEmpty);
      expect(await polite.exitCode, isNot(0));
      final clock = Stopwatch()..start();
      final second = phone.stop('${stubborn.pid}');
      clock.stop();
      expect(second.stopped, isEmpty);
      expect(second.killed, [stubborn.pid]);
      expect(second.remaining, isEmpty);
      expect(clock.elapsed, greaterThanOrEqualTo(const Duration(seconds: 5)));
      expect(clock.elapsed, lessThan(const Duration(seconds: 12)));
      expect(await stubborn.exitCode, isNot(0));
    });

    test('a group stop skips its protected members and reports them', () async {
      final phone = _phone();
      final helper = await Process.start('sleep', ['300']);
      addTearDown(() => helper.kill(ProcessSignal.sigkill));
      // A shell at ppid 1 is "other" and never an orphan; the sleep with a
      // dead parent and a non-shell name is.
      phone.processes(
        '  600     1  0.0 00:00:00 3000 100 sshd sshd: /usr/sbin/sshd\n'
        '  ${helper.pid}     1  0.0 00:00:00 3000 100 helper /x/helper\n',
      );
      final scan = _byPid(phone.scan());
      expect(scan[helper.pid]!.group, TermuxProcessGroup.orphans);
      expect(scan[600]!.group, TermuxProcessGroup.other);
      final result = phone.stop('orphans');
      expect(result.stopped, [helper.pid]);
      expect(result.refused, isEmpty);
      expect(await helper.exitCode, isNot(0));
      final other = phone.stop('other');
      expect(other.refused.single, (pid: 600, reason: 'protected'));
      expect(other.stopped, isEmpty);
    });
  });

  group('parsing', () {
    test('an empty listing is an empty report; results parse', () {
      expect(TermuxProcessReport.parse('').count, 0);
      expect(TermuxProcessReport.parse('[]\n').count, 0);
      final stop = TermuxProcessStopResult.parse(
        '{"stopped":[1,2],"killed":[3],"remaining":[{"pid":3,"name":"x"}],"refused":[{"pid":9,"reason":"protected"}]}',
      );
      expect(stop.endedCount, 3);
      expect(stop.remaining.single.name, 'x');
      expect(stop.refused.single.pid, 9);
      expect(
        TermuxBridge.toolsCommandScript('procs-stop', argument: 'ai_team'),
        endsWith("exec \"\$TOOLS\" procs-stop 'ai_team'\n"),
      );
    });
  });

  group('TermuxProcessesScreen', () {
    late _ChannelFixture fixture;

    setUp(() => fixture = _ChannelFixture());

    testWidgets('lists groups, flags orphans and refreshes every interval', (
      tester,
    ) async {
      await fixture.mount(tester);
      await tester.pump();
      expect(find.byKey(const Key('termux-procs-summary')), findsOneWidget);
      expect(find.text('6 processes · CPU 104%'), findsOneWidget);
      expect(
        find.byKey(const Key('termux-procs-group-orphans')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('termux-procs-group-opencode_server')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('termux-procs-group-ai_team')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('termux-procs-group-build_daemons')),
        findsOneWidget,
      );
      expect(find.text('Managed from On this phone'), findsOneWidget);
      expect(
        find.byKey(const Key('termux-procs-stop-group-opencode_server')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('termux-procs-stop-group-ai_team')),
        findsOneWidget,
      );
      expect(find.text('minimax-coding-plan-mcp'), findsOneWidget);
      expect(
        find.text('Its parent is gone · running for 1 h 1 min'),
        findsOneWidget,
      );
      expect(find.text('10 min of CPU with no owner'), findsOneWidget);
      expect(
        find.byKey(const Key('termux-proc-protected-101')),
        findsOneWidget,
      );
      expect(fixture.scans, 1);
      await tester.pump(const Duration(milliseconds: 120));
      expect(fixture.scans, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an orphan asks before stopping and reports what remained', (
      tester,
    ) async {
      await fixture.mount(tester);
      await tester.pump();
      fixture.stopResult = jsonEncode({
        'stopped': <int>[],
        'killed': [200],
        'remaining': <Object>[],
        'refused': <Object>[],
      });
      // "Orphan" is a heuristic, so even the one-tap row button confirms and
      // says what is lost.
      await tester.tap(find.byKey(const Key('termux-proc-stop-200')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('termux-procs-confirm')), findsOneWidget);
      expect(
        find.textContaining('whatever it was still doing is lost'),
        findsOneWidget,
      );
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(fixture.stops, isEmpty);

      await tester.tap(find.byKey(const Key('termux-proc-stop-200')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('termux-procs-confirm')), findsNothing);
      expect(fixture.stops, isEmpty);

      await tester.tap(find.byKey(const Key('termux-proc-stop-200')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('termux-procs-confirm-stop')));
      await tester.pumpAndSettle();
      expect(fixture.stops, ['200']);
      expect(find.text('Stopped 1 (1 needed a forced stop)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'a group stop is two-step and a plain row confirms in its sheet',
      (tester) async {
        await fixture.mount(tester);
        await tester.pump();
        await tester.tap(
          find.byKey(const Key('termux-procs-stop-group-ai_team')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('termux-procs-confirm')), findsOneWidget);
        expect(find.text('Stop every process in AI Team?'), findsOneWidget);
        expect(fixture.stops, isEmpty);
        await tester.tap(find.text('Keep'));
        await tester.pumpAndSettle();
        expect(fixture.stops, isEmpty);
        await tester.tap(
          find.byKey(const Key('termux-procs-stop-group-ai_team')),
        );
        await tester.pumpAndSettle();
        fixture.stopResult = jsonEncode({
          'stopped': [400, 401],
          'killed': <int>[],
          'remaining': [
            {'pid': 402, 'name': 'opencode acp'},
          ],
          'refused': <Object>[],
        });
        await tester.tap(find.byKey(const Key('termux-procs-confirm-stop')));
        await tester.pumpAndSettle();
        expect(fixture.stops, ['ai_team']);
        expect(find.text('Stopped 2 · 1 would not stop'), findsOneWidget);
        // A non-orphan row opens its details; Stop there confirms first.
        await tester.tap(find.byKey(const Key('termux-proc-300')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('termux-procs-details')), findsOneWidget);
        expect(find.text('PID 300 · parent 1'), findsOneWidget);
        await tester.tap(find.byKey(const Key('termux-procs-details-stop')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('termux-procs-confirm')), findsOneWidget);
        expect(find.text('Stop Gradle daemon?'), findsOneWidget);
        await tester.tap(find.byKey(const Key('termux-procs-confirm-stop')));
        await tester.pumpAndSettle();
        expect(fixture.stops, ['ai_team', '300']);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('protected rows send the user to the server controls', (
      tester,
    ) async {
      await fixture.mount(tester);
      await tester.pump();
      await tester.tap(find.byKey(const Key('termux-proc-101')));
      await tester.pumpAndSettle();
      expect(fixture.serverControlsOpened, 1);
      expect(find.byKey(const Key('termux-procs-details')), findsNothing);
      expect(fixture.stops, isEmpty);
    });

    for (final rtl in [false, true]) {
      testWidgets('fits 320dp at 2.5x text ${rtl ? 'RTL' : 'LTR'}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await fixture.mount(tester, textScale: 2.5, rtl: rtl, tall: false);
        await tester.pump();
        expect(find.byKey(const Key('termux-procs-summary')), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const Key('termux-proc-stop-200')),
          100,
        );
        await tester.pumpAndSettle();
        await tester.pump();
        await tester.scrollUntilVisible(
          find.byKey(const Key('termux-proc-500')),
          100,
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('termux-proc-101')),
          100,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}

String _fixtureProcesses() => jsonEncode([
  {
    'pid': 101,
    'ppid': 100,
    'group': 'opencode_server',
    'name': 'opencode serve',
    'cmd': 'opencode serve --hostname 127.0.0.1 --port 4096',
    'cpu_pct': 0.2,
    'cpu_seconds': 60,
    'rss_kb': 90000,
    'elapsed_s': 4000,
    'cwd': '/root/projects',
    'orphan_reason': null,
    'protected': true,
  },
  {
    'pid': 200,
    'ppid': 1,
    'group': 'orphans',
    'name': 'minimax-coding-plan-mcp',
    'cmd':
        'node /root/.npm/_npx/xyz/node_modules/minimax-coding-plan-mcp/dist/index.js',
    'cpu_pct': 99.0,
    'cpu_seconds': 3723,
    'rss_kb': 45000,
    'elapsed_s': 3700,
    'cwd': '/tmp/opencode/abc',
    'orphan_reason': 'parent_gone',
    'protected': false,
  },
  {
    'pid': 300,
    'ppid': 1,
    'group': 'build_daemons',
    'name': 'Gradle daemon',
    'cmd': 'java -Xmx2g org.gradle.launcher.daemon.bootstrap.GradleDaemon 8.5',
    'cpu_pct': 1.0,
    'cpu_seconds': 7200,
    'rss_kb': 300000,
    'elapsed_s': 7200,
    'cwd': '/root/projects/IPTV_King',
    'orphan_reason': null,
    'protected': false,
  },
  {
    'pid': 400,
    'ppid': 1,
    'group': 'ai_team',
    'name': 'gc',
    'cmd': '/data/data/com.termux/files/usr/bin/gc start',
    'cpu_pct': 0.0,
    'cpu_seconds': 10,
    'rss_kb': 20000,
    'elapsed_s': 1000,
    'cwd': '',
    'orphan_reason': null,
    'protected': false,
  },
  {
    'pid': 402,
    'ppid': 400,
    'group': 'ai_team',
    'name': 'opencode acp',
    'cmd': 'opencode acp',
    'cpu_pct': 3.5,
    'cpu_seconds': 7,
    'rss_kb': 50000,
    'elapsed_s': 800,
    'cwd': '',
    'orphan_reason': null,
    'protected': false,
  },
  {
    'pid': 500,
    'ppid': 700,
    'group': 'orphans',
    'name': 'stray.py',
    'cmd': 'python3 /root/stray.py',
    'cpu_pct': 0.0,
    'cpu_seconds': 600,
    'rss_kb': 1000,
    'elapsed_s': 5000,
    'cwd': '/root',
    'orphan_reason': 'cpu_no_owner',
    'protected': false,
  },
]);

class _ChannelFixture {
  String listing = _fixtureProcesses();
  String stopResult = '{"stopped":[],"killed":[],"remaining":[],"refused":[]}';
  int scans = 0;
  int serverControlsOpened = 0;
  final stops = <String>[];

  Map<String, Object> _result(String stdout) => {
    'stdout': stdout,
    'stderr': '',
    'exitCode': 0,
    'err': -1,
    'errorMessage': '',
  };

  Future<Object?> handle(MethodCall call) async {
    if (call.method != 'runInTermux') return true;
    final script = (call.arguments as Map)['script'] as String;
    final verb = RegExp(
      r'''exec "\$TOOLS" ([a-z-]+)(?: '([^']*)')?\n$''',
    ).firstMatch(script);
    switch (verb?.group(1)) {
      case 'procs-scan':
        scans++;
        return _result('$listing\n');
      case 'procs-stop':
        stops.add(verb!.group(2)!);
        return _result('$stopResult\n');
    }
    return _result('');
  }

  Future<void> mount(
    WidgetTester tester, {
    double textScale = 1,
    bool rtl = false,
    bool tall = true,
  }) async {
    if (tall) {
      // A phone-tall viewport so the lazily built rows under test exist.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    const channel = MethodChannel('oc/termux');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handle);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(rtl ? 'ar' : 'en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: TermuxProcessesScreen(
          refreshInterval: const Duration(milliseconds: 100),
          onOpenServerControls: () => serverControlsOpened++,
        ),
      ),
    );
    await tester.pump();
  }
}
