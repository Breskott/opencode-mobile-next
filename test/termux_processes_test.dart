// TEAM-305, P5.3: Running on this phone. The embedded tools script's
// procs-scan groups a
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
      // The grace before KILL is 5 s on the phone (asserted below); the
      // tests shorten it.
      'OC_STOP_WAIT_SECONDS': '1',
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

    test(
      'TERM ends a cooperative process; KILL follows after the grace',
      () async {
        // The phone's grace is 5 s; the tests run with 1 s.
        expect(
          TermuxBridge.toolsScriptForTesting(),
          contains('STOP_WAIT_SECONDS=\${OC_STOP_WAIT_SECONDS:-5}'),
        );
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
        expect(clock.elapsed, greaterThanOrEqualTo(const Duration(seconds: 1)));
        expect(clock.elapsed, lessThan(const Duration(seconds: 4)));
        expect(await stubborn.exitCode, isNot(0));
      },
    );

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

    test('a list of pids (one kind, confirmed together) stops exactly those, '
        'checking each again', () async {
      final phone = _phone();
      final a = await Process.start('sleep', ['300']);
      final b = await Process.start('sleep', ['300']);
      final bystander = await Process.start('sleep', ['300']);
      addTearDown(() {
        a.kill(ProcessSignal.sigkill);
        b.kill(ProcessSignal.sigkill);
        bystander.kill(ProcessSignal.sigkill);
      });
      phone.processes(
        '  600     1  0.0 00:00:00 3000 100 sshd sshd: /usr/sbin/sshd\n'
        '  ${a.pid}     1  0.0 00:00:00 3000 100 sleep sleep 300\n'
        '  ${b.pid}     1  0.0 00:00:00 3000 100 sleep sleep 300\n'
        '  ${bystander.pid}     1  0.0 00:00:00 3000 100 sleep sleep 300\n',
      );
      final result = phone.stop('${a.pid},600,4242,${b.pid}');
      expect(result.stopped, [a.pid, b.pid]);
      expect(result.refused, [
        (pid: 600, reason: 'protected'),
        (pid: 4242, reason: 'not_found'),
      ]);
      expect(await a.exitCode, isNot(0));
      expect(await b.exitCode, isNot(0));
      // Only the named ones: the third sleep keeps running.
      expect(bystander.kill(ProcessSignal.sigcont), isTrue);
      expect(
        TermuxBridge.toolsCommandScript('procs-stop', argument: '12,34'),
        endsWith("exec \"\$TOOLS\" procs-stop '12,34'\n"),
      );
      expect(
        () => TermuxBridge.toolsCommandScript('procs-stop', argument: '1;2'),
        throwsArgumentError,
      );
    });
  });

  group('what runs', () {
    test('each process has one of the six kinds; the Termux app itself is '
        'never stopped or counted', () {
      final phone = _phone();
      phone.processes(
        '$_phonePs'
        '  900   700  5.0 00:02:00 150000 600 node node /data/data/com.termux/files/usr/lib/node_modules/@anthropic-ai/claude-code/cli.js\n'
        '   50     1  0.5 00:05:00 200000 9000 com.termux com.termux\n',
      );
      final report = phone.scan();
      final p = _byPid(report);
      final kinds = {for (final e in p.entries) e.key: e.value.kind};
      expect(kinds, {
        50: PhoneProcessKind.helpers,
        100: PhoneProcessKind.openCodeServer,
        101: PhoneProcessKind.openCodeServer,
        102: PhoneProcessKind.openCodeServer,
        200: PhoneProcessKind.helpers,
        300: PhoneProcessKind.devServices,
        400: PhoneProcessKind.aiTeam,
        401: PhoneProcessKind.aiTeam,
        402: PhoneProcessKind.aiTeam,
        403: PhoneProcessKind.aiTeam,
        500: PhoneProcessKind.helpers,
        600: PhoneProcessKind.helpers,
        700: PhoneProcessKind.terminals,
        800: PhoneProcessKind.devServices,
        900: PhoneProcessKind.claudeCode,
      });
      expect(p[50]!.isHostApp, isTrue);
      expect(p[50]!.stoppable, isFalse);
      expect(p[101]!.stoppable, isFalse);
      expect(p[600]!.stoppable, isFalse);
      expect(p[900]!.stoppable, isTrue);
      // Everything Termux started counts against Android's 32; the app
      // itself does not.
      expect(report.count, 15);
      expect(report.backgroundCount, 14);
      expect(TermuxProcessReport.androidBackgroundLimit, 32);
      // Memory in MB, rounded; a missing reading stays unknown.
      expect(p[300]!.memoryMb, 293);
      expect(TermuxProcess.fromJson({'pid': 7, 'rss_kb': 0})!.memoryMb, isNull);
    });

    test('busy is measured between two readings, never from the lifetime '
        'average', () {
      TermuxProcess at(
        int cpu,
        int elapsed, {
        String name = 'x',
        int pid = 7,
      }) => TermuxProcess.fromJson({
        'pid': pid,
        'name': name,
        'cpu_pct': 99.0,
        'cpu_seconds': cpu,
        'elapsed_s': elapsed,
      })!;
      TermuxProcessReport report(TermuxProcess p) => TermuxProcessReport([p]);
      // No earlier reading: unknown, whatever ps's average says.
      expect(
        TermuxProcessReport.activityOf(at(100, 100), null),
        PhoneProcessActivity.unknown,
      );
      // 5 s of processor in 10 s: busy.
      expect(
        TermuxProcessReport.activityOf(at(105, 110), report(at(100, 100))),
        PhoneProcessActivity.busy,
      );
      // A second's rounding in 10 s: idle, despite "CPU 99%".
      expect(
        TermuxProcessReport.activityOf(at(101, 110), report(at(100, 100))),
        PhoneProcessActivity.idle,
      );
      // A new process under a reused pid (younger than before) or another
      // name: unknown.
      expect(
        TermuxProcessReport.activityOf(at(5, 20), report(at(100, 100))),
        PhoneProcessActivity.unknown,
      );
      expect(
        TermuxProcessReport.activityOf(
          at(105, 110, name: 'y'),
          report(at(100, 100)),
        ),
        PhoneProcessActivity.unknown,
      );
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

    testWidgets('one list by urgency: left behind first, then by what runs; '
        'each row names its kind; busy is measured; refreshes every interval', (
      tester,
    ) async {
      // The second reading: opencode acp used 5 s of processor in 10 s.
      fixture.later = _fixtureProcesses(
        tick: (pid) => (cpu: pid == 402 ? 5 : 0, elapsed: 10),
      );
      await fixture.mount(tester);
      await tester.pump();
      expect(find.text('Running on this phone'), findsOneWidget);
      expect(find.byKey(const Key('termux-procs-summary')), findsOneWidget);
      // The budget, with what the 32 is; no unexplained CPU total.
      expect(find.text('6 of 32 background processes'), findsOneWidget);
      expect(
        find.text(
          'Android 12 and later may stop the oldest ones when all apps '
          'together run more than 32.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('CPU'), findsNothing);
      // One panel, no sections by owner, no counts, no captions
      // (owner rule 2026-09-27).
      expect(find.byKey(const Key('termux-procs-list-group')), findsOneWidget);
      for (final group in [
        'orphans',
        'opencode_server',
        'ai_team',
        'build_daemons',
      ]) {
        expect(find.byKey(Key('termux-procs-group-$group')), findsNothing);
        expect(find.byKey(Key('termux-procs-stop-group-$group')), findsNothing);
      }
      expect(find.text('Managed from On this phone'), findsNothing);
      expect(find.textContaining('Helpers whose parent is gone'), findsNothing);
      expect(find.text('Stop all'), findsNothing);
      // No manual Refresh beside the automatic one.
      expect(find.byKey(const Key('termux-procs-refresh')), findsNothing);
      // Left behind first, then by kind in the page's order (the server,
      // the team, dev services), the most memory first within a kind.
      final order = [200, 500, 101, 402, 400, 300];
      double top(int pid) =>
          tester.getTopLeft(find.byKey(Key('termux-proc-$pid'))).dy;
      for (var i = 1; i < order.length; i++) {
        expect(
          top(order[i - 1]),
          lessThan(top(order[i])),
          reason: '${order[i - 1]} above ${order[i]}',
        );
      }
      String line(int pid) => tester
          .widget<RichText>(
            find.descendant(
              of: find.byKey(Key('termux-proc-line-$pid')),
              matching: find.byType(RichText),
            ),
          )
          .text
          .toPlainText();
      // First reading: no Busy or Idle yet (never ps's lifetime average).
      expect(line(200), 'Helper · Parent gone · 44 MB · running 1 h 1 min');
      expect(line(500), 'Helper · No owner · 1 MB · running 1 h 23 min');
      expect(line(402), 'AI Team · 49 MB · running 13 min');
      expect(line(300), 'Dev service · 293 MB · running 2 h 0 min');
      expect(
        find.byKey(const Key('termux-proc-protected-101')),
        findsOneWidget,
      );
      expect(
        find.text('Protected · control it from This phone'),
        findsOneWidget,
      );
      // The unlabeled stop square is gone: stopping lives in the menu and
      // the details sheet.
      expect(find.byKey(const Key('termux-proc-stop-200')), findsNothing);
      expect(find.text('minimax-coding-plan-mcp'), findsOneWidget);
      expect(fixture.scans, 1);
      // The second reading comes soon after opening: Busy and Idle.
      await tester.pump(const Duration(milliseconds: 60));
      expect(fixture.scans, 2);
      expect(line(402), 'AI Team · Busy · 49 MB · running 13 min');
      expect(line(300), 'Dev service · Idle · 293 MB · running 2 h 0 min');
      await tester.pump(const Duration(milliseconds: 60));
      expect(fixture.scans, 3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the one bulk stop names the orphans, asks first and reports '
        'what remained', (tester) async {
      await fixture.mount(tester);
      await tester.pump();
      final bulk = find.byKey(const Key('termux-procs-stop-orphans'));
      expect(bulk, findsOneWidget);
      expect(find.text('Stop 2 orphaned helpers'), findsOneWidget);
      await tester.tap(bulk);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('termux-procs-confirm')), findsOneWidget);
      expect(find.text('Stop 2 orphaned helpers?'), findsOneWidget);
      await tester.tap(find.text('Keep running'));
      await tester.pumpAndSettle();
      expect(fixture.stops, isEmpty);

      await tester.tap(bulk);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('termux-procs-confirm')), findsNothing);
      expect(fixture.stops, isEmpty);

      fixture.stopResult = jsonEncode({
        'stopped': [500],
        'killed': [200],
        'remaining': <Object>[],
        'refused': <Object>[],
      });
      await tester.tap(bulk);
      await tester.pumpAndSettle();
      // The confirm button names what it stops.
      expect(
        find.descendant(
          of: find.byKey(const Key('termux-procs-confirm-stop')),
          matching: find.text('Stop 2 orphaned helpers'),
        ),
        findsOneWidget,
      );
      // Every one it stops is named.
      expect(
        find.textContaining('minimax-coding-plan-mcp, stray.py'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('termux-procs-confirm-stop')));
      await tester.pumpAndSettle();
      // Exactly the ones the question named, not whatever is an orphan now.
      expect(fixture.stops, ['200,500']);
      expect(find.text('Stopped 2 (1 needed a forced stop)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('one process stops from its details sheet, after asking', (
      tester,
    ) async {
      await fixture.mount(tester);
      await tester.pump();
      await tester.tap(find.byKey(const Key('termux-proc-300')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('termux-procs-details')), findsOneWidget);
      // The kind names it; the IDs wait under Details.
      expect(find.text('Dev service'), findsOneWidget);
      expect(find.text('PID 300 · parent 1'), findsNothing);
      await tester.tap(find.byKey(const Key('termux-procs-details-stop')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('termux-procs-confirm')), findsOneWidget);
      expect(find.text('Stop Gradle daemon?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('termux-procs-confirm-stop')));
      await tester.pumpAndSettle();
      expect(fixture.stops, ['300']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a stop that did not take is said as a problem', (
      tester,
    ) async {
      await fixture.mount(tester);
      await tester.pump();
      fixture.stopResult = jsonEncode({
        'stopped': <int>[],
        'killed': <int>[],
        'remaining': [
          {'pid': 200, 'name': 'minimax-coding-plan-mcp'},
        ],
        'refused': <Object>[],
      });
      await tester.tap(find.byKey(const Key('termux-proc-200')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('termux-procs-details-stop')));
      await tester.pumpAndSettle();
      // An orphan's stop says what is lost.
      expect(
        find.textContaining('whatever it was still doing is lost'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('termux-procs-confirm-stop')));
      await tester.pumpAndSettle();
      expect(find.text('Not everything stopped'), findsOneWidget);
      expect(find.text('Stopped 0 · 1 would not stop'), findsOneWidget);
    });

    testWidgets('details say what the process is and copy its command', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await fixture.mount(tester);
      await tester.pump();
      await tester.tap(find.byKey(const Key('termux-proc-300')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'A build helper. The next build starts it again when it needs it.',
        ),
        findsOneWidget,
      );
      expect(find.text('Stop Gradle daemon'), findsOneWidget);
      await tester.tap(find.byKey(const Key('termux-procs-details-copy')));
      await tester.pump();
      expect(
        copied,
        'java -Xmx2g org.gradle.launcher.daemon.bootstrap.GradleDaemon 8.5',
      );
      // The command, folder and IDs sit under the one Details fold.
      await tester.tap(find.byKey(const ValueKey('kit-details-toggle')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('termux-procs-details-command')),
        findsOneWidget,
      );
      expect(find.text('/root/projects/IPTV_King'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('a list that cannot be read offers Try again', (tester) async {
      fixture.listing = 'not json';
      await fixture.mount(tester);
      await tester.pump();
      await tester.pump();
      expect(find.text("Couldn't read what's running"), findsOneWidget);
      // Plain words and a way forward; no parser or bridge text as copy.
      expect(
        find.text('Termux did not answer. Open Termux, then try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('FormatException'), findsNothing);
      fixture.listing = _fixtureProcesses();
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      expect(find.text('6 of 32 background processes'), findsOneWidget);
    });

    testWidgets('an empty list says what would show here', (tester) async {
      fixture.listing = '[]';
      await fixture.mount(tester);
      await tester.pump();
      expect(
        find.text('Nothing is running in the phone server'),
        findsOneWidget,
      );
      expect(
        find.text(
          'When OpenCode, the AI Team or a build runs here, it shows up in '
          'this list.',
        ),
        findsOneWidget,
      );
    });

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

    testWidgets('a kind with several processes stops them together, asked '
        'once with every name', (tester) async {
      await fixture.mount(tester);
      await tester.pump();
      await tester.longPress(find.byKey(const Key('termux-proc-402')));
      await tester.pumpAndSettle();
      // Its own stop and its kind's, each naming what it stops.
      expect(find.text('Stop opencode acp'), findsOneWidget);
      await tester.tap(find.text('Stop all 2 AI Team processes'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('termux-procs-confirm')), findsOneWidget);
      expect(find.text('Stop all 2 AI Team processes?'), findsOneWidget);
      expect(
        find.text(
          'gc, opencode acp: each gets a polite stop, then a forced one '
          'after 5 seconds.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Any task the team is working on stops too.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('termux-procs-confirm-stop')));
      await tester.pumpAndSettle();
      expect(fixture.stops, ['400,402']);
      // A kind of one offers no second stop for the same process.
      await tester.longPress(find.byKey(const Key('termux-proc-300')));
      await tester.pumpAndSettle();
      expect(find.text('Stop Gradle daemon'), findsOneWidget);
      expect(find.textContaining('Stop all'), findsNothing);
      expect(find.textContaining('Stop the dev service'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('past Android\'s 32 it says so in words', (tester) async {
      fixture.listing = jsonEncode([
        for (var pid = 1000; pid < 1034; pid++)
          {
            'pid': pid,
            'ppid': 1,
            'group': 'other',
            'name': 'helper-$pid',
            'cmd': '/x/helper',
            'rss_kb': 2048,
            'elapsed_s': 60,
          },
      ]);
      await fixture.mount(tester);
      await tester.pump();
      expect(find.text('34 of 32 background processes'), findsOneWidget);
      expect(
        find.text(
          'More than 32: Android may stop the oldest of these at any time.',
        ),
        findsOneWidget,
      );
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
          find.byKey(const Key('termux-proc-500')),
          100,
        );
        await tester.pumpAndSettle();
        await tester.pump();
        await tester.scrollUntilVisible(
          find.byKey(const Key('termux-proc-101')),
          100,
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('termux-procs-stop-orphans')),
          100,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}

/// The owner's list; [tick] moves each process's processor time and age on
/// for a later reading.
String _fixtureProcesses({({int cpu, int elapsed}) Function(int pid)? tick}) =>
    jsonEncode([
      for (final process in _fixtureList)
        if (tick == null)
          process
        else
          {
            ...process,
            'cpu_seconds':
                (process['cpu_seconds']! as int) +
                tick(process['pid']! as int).cpu,
            'elapsed_s':
                (process['elapsed_s']! as int) +
                tick(process['pid']! as int).elapsed,
          },
    ]);

const _fixtureList = <Map<String, Object?>>[
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
];

class _ChannelFixture {
  String listing = _fixtureProcesses();

  /// What every reading after the first answers, when set.
  String? later;
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
        return _result('${scans > 1 ? later ?? listing : listing}\n');
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
          sampleDelay: const Duration(milliseconds: 50),
          onOpenServerControls: () => serverControlsOpened++,
        ),
      ),
    );
    await tester.pump();
  }
}
