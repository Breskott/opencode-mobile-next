// TEAM-304: Storage on this phone. The embedded tools script runs under
// bash on the PC against a fixture tree that mirrors the phone's paths
// (Termux $PREFIX, $HOME and the proot rootfs), with a stub `ps` on PATH;
// the screen runs over a mocked `oc/termux` channel.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:opencode_mobile/termux/storage.dart';
import 'package:opencode_mobile/ui/screens/termux_storage_screen.dart';

/// A phone-shaped tree under a temp directory.
class _Phone {
  _Phone() {
    root = Directory.systemTemp.createTempSync('oc-tools-storage-');
    home = Directory('${root.path}/home')..createSync();
    prefix = Directory('${root.path}/prefix')..createSync();
    bin = Directory('${root.path}/bin')..createSync();
    rootfs = Directory(
      '${prefix.path}/var/lib/proot-distro/containers/opencode-ubuntu/rootfs',
    )..createSync(recursive: true);
    tools = File('${root.path}/tools.sh')
      ..writeAsStringSync(TermuxBridge.toolsScriptForTesting());
    ps = File('${bin.path}/ps')
      ..writeAsStringSync('#!/bin/bash\ncat "\$OC_PS_FIXTURE"\n');
    Process.runSync('chmod', ['+x', ps.path]);
    psFixture = File('${root.path}/ps.txt')..writeAsStringSync('');
  }

  late final Directory root;
  late final Directory home;
  late final Directory prefix;
  late final Directory bin;
  late final Directory rootfs;
  late final File tools;
  late final File ps;
  late final File psFixture;

  Directory get ocDir => Directory('${home.path}/.oc');

  /// Writes [bytes] of data at [relative] (under [base]).
  void file(Directory base, String relative, {int bytes = 2048}) {
    final target = File('${base.path}/$relative');
    target.parent.createSync(recursive: true);
    target.writeAsBytesSync(List.filled(bytes, 0x41));
  }

  void processes(String lines) => psFixture.writeAsStringSync(lines);

  ProcessResult run(List<String> args) => Process.runSync(
    'bash',
    [tools.path, ...args],
    environment: {
      ...Platform.environment,
      'HOME': home.path,
      'PREFIX': prefix.path,
      'PATH': '${bin.path}:${Platform.environment['PATH']}',
      'OC_PS_FIXTURE': psFixture.path,
    },
  );

  void dispose() => root.deleteSync(recursive: true);
}

_Phone _phoneWithCaches() {
  final phone = _Phone();
  addTearDown(phone.dispose);
  final r = phone.rootfs;
  phone.file(r, 'root/.gradle/caches/a.jar');
  phone.file(r, 'root/.gradle/wrapper/b.zip');
  phone.file(r, 'root/.pub-cache/c');
  phone.file(r, 'root/.cache/d');
  phone.file(r, 'root/.dartServer/e');
  phone.file(phone.home, '.npm/f');
  phone.file(phone.home, '.cache/g');
  phone.file(r, 'tmp/opencode/scratch-1/h');
  phone.file(r, 'tmp/opencode/scratch-2/i');
  phone.file(r, 'tmp/opencode/flutter/bin/flutter');
  phone.file(r, 'tmp/opencode/flutter_linux_3.35.tar.xz');
  phone.file(phone.prefix, 'tmp/j');
  phone.file(r, 'usr/lib/android-sdk/k');
  phone.file(r, 'usr/lib/jvm/l');
  phone.file(r, 'root/projects/IPTV_King/lib/main.dart');
  phone.file(r, 'root/projects/IPTV_King/build/app.apk');
  phone.file(r, 'root/projects/IPTV_King/android/build/x');
  phone.file(r, 'root/projects/IPTV_King/.dart_tool/y');
  phone.file(r, 'root/projects/IPTV_King/node_modules/z');
  phone.file(r, 'root/projects/notes/README.md');
  phone.file(r, 'usr/local/lib/node_modules/opencode-ai/index.js');
  phone.file(r, 'root/.local/share/opencode/auth.json');
  phone.file(phone.home, '.oc/aiteam/city/rig');
  phone.file(phone.prefix, 'bin/gc');
  phone.file(r, 'root/aiteam-work/w');
  // Only an idle shell: nothing is using any category.
  phone.processes('  700     1  0.0 00:00:00 3000 100 bash bash\n');
  return phone;
}

TermuxStorageReport _scan(_Phone phone) {
  final scan = phone.run(['storage-scan']);
  expect(scan.exitCode, 0, reason: '${scan.stdout}\n${scan.stderr}');
  final status = phone.run(['storage-status']);
  expect(status.exitCode, 0, reason: status.stderr as String);
  final parsed = TermuxStorageScanStatus.parse(status.stdout as String);
  expect(parsed.state, TermuxStorageScanState.done, reason: parsed.log);
  return parsed.report!;
}

Map<String, TermuxStorageCategory> _byKey(TermuxStorageReport report) => {
  for (final c in report.categories) c.key: c,
};

Set<String> _relative(_Phone phone, Iterable<TermuxStoragePath> paths) => {
  for (final p in paths) p.path.replaceFirst(phone.root.path, ''),
};

void main() {
  group('tools.sh storage-scan', () {
    test('measures every category with the right paths and flags', () {
      final phone = _phoneWithCaches();
      final report = _scan(phone);
      final cats = _byKey(report);
      const rfs =
          '/prefix/var/lib/proot-distro/containers/opencode-ubuntu/rootfs';
      expect(cats.keys.toList(), [
        'build_caches',
        'agent_scratch',
        'project_build_outputs',
        'toolchains',
        'ai_team',
        'opencode',
        'projects',
      ]);
      expect(_relative(phone, cats['build_caches']!.paths), {
        '$rfs/root/.gradle/caches',
        '$rfs/root/.gradle/wrapper',
        '$rfs/root/.pub-cache',
        '$rfs/root/.cache',
        '$rfs/root/.dartServer',
        '/home/.npm',
        '/home/.cache',
      });
      expect(cats['build_caches']!.deletable, isTrue);
      expect(cats['build_caches']!.bytes, greaterThanOrEqualTo(7 * 2048));
      expect(_relative(phone, cats['agent_scratch']!.paths), {
        '$rfs/tmp/opencode/scratch-1',
        '$rfs/tmp/opencode/scratch-2',
        '/prefix/tmp',
      });
      expect(_relative(phone, cats['project_build_outputs']!.paths), {
        '$rfs/root/projects/IPTV_King/build',
        '$rfs/root/projects/IPTV_King/android/build',
        '$rfs/root/projects/IPTV_King/.dart_tool',
        '$rfs/root/projects/IPTV_King/node_modules',
      });
      expect(_relative(phone, cats['toolchains']!.paths), {
        '$rfs/usr/lib/android-sdk',
        '$rfs/usr/lib/jvm',
        '$rfs/tmp/opencode/flutter',
        '$rfs/tmp/opencode/flutter_linux_3.35.tar.xz',
      });
      expect(cats['toolchains']!.noteKey, 'termuxStorageNoteToolchains');
      expect(_relative(phone, cats['ai_team']!.paths), {
        '/home/.oc/aiteam',
        '/prefix/bin/gc',
        '$rfs/root/aiteam-work',
      });
      expect(cats['opencode']!.deletable, isFalse);
      expect(_relative(phone, cats['opencode']!.paths), {
        '$rfs/usr/local/lib/node_modules',
        '$rfs/root/.local/share/opencode',
      });
      expect(cats['projects']!.deletable, isFalse);
      expect(_relative(phone, cats['projects']!.paths), {
        '$rfs/root/projects/IPTV_King',
        '$rfs/root/projects/notes',
      });
      expect(report.projects.map((p) => p.name), ['IPTV_King', 'notes']);
      final iptv = report.projects.first;
      expect(iptv.buildBytes, greaterThanOrEqualTo(4 * 2048));
      expect(iptv.bytes, greaterThan(iptv.buildBytes));
      expect(report.totalBytes, greaterThan(report.deletableBytes));
      expect(report.scannedAt, isNotNull);
      // The log the UI tails names each measured path in short form.
      final log = File(
        '${phone.ocDir.path}/storage-scan.log',
      ).readAsStringSync();
      expect(log, contains('[oc] Build caches'));
      expect(log, contains('ubuntu:/root/.gradle/caches'));
      expect(log, contains('~/.npm'));
      expect(log, contains('[oc] Scan complete'));
    });

    test('accepts the older installed-rootfs layout', () {
      final phone = _Phone();
      addTearDown(phone.dispose);
      phone.rootfs.deleteSync(recursive: true);
      final old = Directory(
        '${phone.prefix.path}/var/lib/proot-distro/installed-rootfs/opencode-ubuntu',
      )..createSync(recursive: true);
      phone.file(old, 'root/.gradle/caches/a');
      phone.processes('');
      final report = _scan(phone);
      expect(_relative(phone, _byKey(report)['build_caches']!.paths), {
        '/prefix/var/lib/proot-distro/installed-rootfs/opencode-ubuntu/root/.gradle/caches',
      });
    });

    test('a cancel file stops the scan before it measures anything', () {
      final phone = _phoneWithCaches();
      phone.ocDir.createSync(recursive: true);
      File('${phone.ocDir.path}/storage-scan.cancel').createSync();
      final scan = phone.run(['storage-scan']);
      expect(scan.exitCode, 0);
      final status = TermuxStorageScanStatus.parse(
        phone.run(['storage-status']).stdout as String,
      );
      expect(status.state, TermuxStorageScanState.cancelled);
      expect(status.report, isNull);
      expect(status.log, contains('[oc] Scan cancelled'));
      expect(
        File('${phone.ocDir.path}/storage-scan.pid').existsSync(),
        isFalse,
      );
    });

    test('storage-summary answers with the last total', () {
      final phone = _phoneWithCaches();
      final before = TermuxStorageSummary.parse(
        phone.run(['storage-summary']).stdout as String,
      );
      expect(before.state, TermuxStorageScanState.idle);
      expect(before.totalBytes, isNull);
      final report = _scan(phone);
      final after = TermuxStorageSummary.parse(
        phone.run(['storage-summary']).stdout as String,
      );
      expect(after.state, TermuxStorageScanState.done);
      expect(after.totalBytes, report.totalBytes);
      expect(after.scannedAtEpochSeconds, report.scannedAtEpochSeconds);
    });
  });

  group('tools.sh storage-clean', () {
    test('removes only the listed paths of one category', () {
      final phone = _phoneWithCaches();
      final report = _scan(phone);
      final before = _byKey(report)['build_caches']!;
      final result = TermuxStorageCleanResult.parse(
        phone.run(['storage-clean', 'build_caches']).stdout as String,
      );
      expect(result.refused, isEmpty);
      expect(result.freedBytes, before.bytes);
      expect(_relative(phone, result.removed), _relative(phone, before.paths));
      for (final path in before.paths) {
        if (path.path == '${phone.home.path}/.cache') {
          // Termux's own ~/.cache is emptied, not removed.
          expect(Directory(path.path).existsSync(), isTrue);
          expect(Directory(path.path).listSync(), isEmpty);
        } else {
          expect(
            FileSystemEntity.typeSync(path.path),
            FileSystemEntityType.notFound,
          );
        }
      }
      // Everything else is untouched.
      final r = phone.rootfs.path;
      expect(
        File('$r/root/projects/IPTV_King/lib/main.dart').existsSync(),
        isTrue,
      );
      expect(
        File('$r/root/projects/IPTV_King/build/app.apk').existsSync(),
        isTrue,
      );
      expect(File('$r/tmp/opencode/scratch-1/h').existsSync(), isTrue);
      expect(
        File('$r/root/.local/share/opencode/auth.json').existsSync(),
        isTrue,
      );
      expect(File('$r/usr/lib/jvm/l').existsSync(), isTrue);
      // A second clean of the same category is a no-op.
      final again = TermuxStorageCleanResult.parse(
        phone.run(['storage-clean', 'build_caches']).stdout as String,
      );
      expect(again.freedBytes, 0);
      expect(again.removed, isEmpty);
    });

    test('project build outputs go, project sources stay', () {
      final phone = _phoneWithCaches();
      _scan(phone);
      final result = TermuxStorageCleanResult.parse(
        phone.run(['storage-clean', 'project_build_outputs']).stdout as String,
      );
      expect(result.refused, isEmpty);
      expect(result.removed, hasLength(4));
      final r = phone.rootfs.path;
      expect(
        Directory('$r/root/projects/IPTV_King/build').existsSync(),
        isFalse,
      );
      expect(
        Directory('$r/root/projects/IPTV_King/node_modules').existsSync(),
        isFalse,
      );
      expect(
        File('$r/root/projects/IPTV_King/lib/main.dart').existsSync(),
        isTrue,
      );
      expect(File('$r/root/projects/notes/README.md').existsSync(), isTrue);
    });

    test('agent scratch empties Termux tmp instead of removing it', () {
      final phone = _phoneWithCaches();
      _scan(phone);
      final result = TermuxStorageCleanResult.parse(
        phone.run(['storage-clean', 'agent_scratch']).stdout as String,
      );
      expect(result.removed, hasLength(3));
      expect(Directory('${phone.prefix.path}/tmp').existsSync(), isTrue);
      expect(Directory('${phone.prefix.path}/tmp').listSync(), isEmpty);
      expect(
        Directory('${phone.rootfs.path}/tmp/opencode/scratch-1').existsSync(),
        isFalse,
      );
      // The toolchain copies under /tmp/opencode belong to another category.
      expect(
        Directory('${phone.rootfs.path}/tmp/opencode/flutter').existsSync(),
        isTrue,
      );
    });

    test('refuses a category a live process is using, naming it', () {
      final phone = _phoneWithCaches();
      _scan(phone);
      phone.processes(
        '  300     1  1.0 02:00:00 300000 7200 java java -Xmx2g org.gradle.launcher.daemon.bootstrap.GradleDaemon 8.5\n'
        '  400     1  0.0 00:00:10 20000 1000 gc /prefix/bin/gc start\n'
        '  401   400  0.0 00:00:05 40000 900 dolt dolt sql-server\n'
        '  402   400  0.5 00:00:07 50000 800 opencode opencode acp\n',
      );
      for (final category in [
        'build_caches',
        'project_build_outputs',
        'toolchains',
      ]) {
        final result = TermuxStorageCleanResult.parse(
          phone.run(['storage-clean', category]).stdout as String,
        );
        expect(result.inUse, isNotNull, reason: category);
        expect(result.inUse!.processes, ['java'], reason: category);
        expect(result.removed, isEmpty);
      }
      final team = TermuxStorageCleanResult.parse(
        phone.run(['storage-clean', 'ai_team']).stdout as String,
      );
      expect(team.inUse!.processes, containsAll(['gc', 'dolt']));
      final scratch = TermuxStorageCleanResult.parse(
        phone.run(['storage-clean', 'agent_scratch']).stdout as String,
      );
      expect(scratch.inUse!.processes, ['opencode']);
      // Nothing was touched.
      expect(
        File('${phone.rootfs.path}/root/.gradle/caches/a.jar').existsSync(),
        isTrue,
      );
      expect(
        File('${phone.home.path}/.oc/aiteam/city/rig').existsSync(),
        isTrue,
      );
    });

    test('never offers OpenCode itself or project sources', () {
      final phone = _phoneWithCaches();
      _scan(phone);
      for (final category in ['opencode', 'projects']) {
        final result = TermuxStorageCleanResult.parse(
          phone.run(['storage-clean', category]).stdout as String,
        );
        expect(result.removed, isEmpty);
        expect(result.refused.single.reason, 'never_deletable');
      }
      expect(phone.run(['storage-clean', 'sessions']).exitCode, 64);
      expect(
        File(
          '${phone.rootfs.path}/root/.local/share/opencode/auth.json',
        ).existsSync(),
        isTrue,
      );
    });

    test('refuses when no scan has listed anything', () {
      final phone = _phoneWithCaches();
      final result = phone.run(['storage-clean', 'build_caches']);
      expect(result.exitCode, 65);
      expect(
        File('${phone.rootfs.path}/root/.gradle/caches/a.jar').existsSync(),
        isTrue,
      );
    });
  });

  group('bridge wrappers', () {
    test('tools script installs beside manager.sh and dispatches a scan', () {
      final scan = TermuxBridge.toolsCommandScript('storage-scan');
      expect(scan, contains('TOOLS="${TermuxBridge.termuxHome}/.oc/tools.sh"'));
      expect(scan, contains("<<'OC_TOOLS_EOF'"));
      expect(scan, contains('mv "\$tools_tmp" "\$TOOLS"'));
      expect(scan, contains('rm -f "\$OC_DIR/storage-scan.cancel"'));
      expect(scan, contains('nohup "\$TOOLS" storage-scan'));
      expect(scan, contains('echo "tools-started:\$!"'));
      final clean = TermuxBridge.toolsCommandScript(
        'storage-clean',
        argument: 'build_caches',
      );
      expect(
        clean,
        endsWith("exec \"\$TOOLS\" storage-clean 'build_caches'\n"),
      );
      expect(() => TermuxBridge.toolsCommandScript('rm'), throwsArgumentError);
      expect(
        () =>
            TermuxBridge.toolsCommandScript('storage-clean', argument: '../x'),
        throwsArgumentError,
      );
    });

    test('byte and path formatting', () {
      expect(splitBytes(0), (value: '0', unit: TermuxByteUnit.b));
      expect(splitBytes(2048), (value: '2', unit: TermuxByteUnit.kb));
      expect(splitBytes(812 * 1024 * 1024), (
        value: '812',
        unit: TermuxByteUnit.mb,
      ));
      expect(splitBytes((11.6 * 1024 * 1024 * 1024).round()), (
        value: '11.6',
        unit: TermuxByteUnit.gb,
      ));
      expect(splitBytes(3 * 1024 * 1024 * 1024), (
        value: '3',
        unit: TermuxByteUnit.gb,
      ));
      expect(
        displayTermuxPath(
          '/data/data/com.termux/files/usr/var/lib/proot-distro/containers/opencode-ubuntu/rootfs/root/.gradle/caches',
        ),
        'ubuntu:/root/.gradle/caches',
      );
      expect(
        displayTermuxPath('/data/data/com.termux/files/home/.npm'),
        '~/.npm',
      );
      expect(
        displayTermuxPath('/data/data/com.termux/files/usr/tmp'),
        'termux:/tmp',
      );
    });

    test('status parsing tolerates an idle phone and a bare log', () {
      final idle = TermuxStorageScanStatus.parse(
        'state=idle\n__OC_TOOLS_LOG__\n__OC_TOOLS_JSON__\n',
      );
      expect(idle.state, TermuxStorageScanState.idle);
      expect(idle.report, isNull);
      final running = TermuxStorageScanStatus.parse(
        'state=running\n__OC_TOOLS_LOG__\n[oc] Build caches\n__OC_TOOLS_JSON__\n',
      );
      expect(running.state, TermuxStorageScanState.running);
      expect(running.log, '[oc] Build caches');
      expect(
        TermuxStorageScanStatus.parse('').state,
        TermuxStorageScanState.idle,
      );
    });
  });

  group('TermuxStorageScreen', () {
    late _ChannelFixture fixture;

    setUp(() => fixture = _ChannelFixture());

    testWidgets('scans with the live panel, cancels, then shows the report', (
      tester,
    ) async {
      await fixture.mount(tester);
      expect(find.byKey(const Key('termux-storage-intro')), findsOneWidget);
      await tester.tap(find.byKey(const Key('termux-storage-scan')));
      await tester.pump();
      expect(fixture.scanStarts, 1);
      fixture.state = 'running';
      fixture.log = '[oc] Measuring storage on this phone\n[oc] Build caches';
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byKey(const Key('termux-storage-scanning')), findsOneWidget);
      expect(find.byKey(const Key('setup-live-output')), findsOneWidget);
      expect(find.textContaining('[oc] Build caches'), findsOneWidget);
      await tester.tap(find.byKey(const Key('termux-storage-cancel')));
      fixture.state = 'cancelled';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(fixture.cancels, 1);
      expect(find.text('Scan cancelled'), findsOneWidget);
      // Scan again to completion.
      await tester.tap(find.byKey(const Key('termux-storage-scan')));
      await tester.pump();
      fixture.state = 'done';
      fixture.report = _fixtureReport();
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byKey(const Key('termux-storage-total')), findsOneWidget);
      expect(find.text('46 GB used by the phone server'), findsOneWidget);
      expect(find.text('Build caches'), findsOneWidget);
      expect(find.text('Projects (your files)'), findsWidgets);
      expect(
        find.byKey(const Key('termux-storage-project-IPTV_King')),
        findsOneWidget,
      );
      // Non-deletable categories have no Clean button.
      await tester.tap(find.byKey(const Key('termux-storage-cat-opencode')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('termux-storage-clean-opencode')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('termux-storage-clean-projects')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('cleaning over a gigabyte is two-step and shows freed bytes', (
      tester,
    ) async {
      fixture.state = 'done';
      fixture.report = _fixtureReport();
      await fixture.mount(tester);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(
        find.byKey(const Key('termux-storage-cat-build_caches')),
      );
      await tester.pumpAndSettle();
      expect(find.text('What Clean removes'), findsOneWidget);
      expect(find.text('ubuntu:/root/.gradle/caches'), findsOneWidget);
      expect(
        find.textContaining('the next build will download these again'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const Key('termux-storage-clean-build_caches')),
      );
      await tester.tap(
        find.byKey(const Key('termux-storage-clean-build_caches')),
      );
      await tester.pumpAndSettle();
      // First step: the confirmation sheet; nothing ran yet.
      expect(find.byKey(const Key('termux-storage-confirm')), findsOneWidget);
      expect(find.text('Remove 8.1 GB of Build caches?'), findsOneWidget);
      expect(fixture.cleans, isEmpty);
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(fixture.cleans, isEmpty);
      await tester.tap(
        find.byKey(const Key('termux-storage-clean-build_caches')),
      );
      await tester.pumpAndSettle();
      fixture.cleanResult = jsonEncode({
        'freed_bytes': 8700000000,
        'removed': [
          {'path': _rootfs('/root/.gradle/caches'), 'bytes': 8000000000},
          {'path': _rootfs('/root/.gradle/wrapper'), 'bytes': 700000000},
        ],
        'refused': <Object>[],
      });
      await tester.tap(find.byKey(const Key('termux-storage-confirm-remove')));
      await tester.pumpAndSettle();
      expect(fixture.cleans, ['build_caches']);
      expect(find.text('Freed 8.1 GB'), findsOneWidget);
      // The category and the total shrink by what went.
      expect(find.text('37.9 GB used by the phone server'), findsOneWidget);
      expect(find.text('ubuntu:/root/.gradle/caches'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'a small category cleans in one tap; in-use refusals name the process',
      (tester) async {
        fixture.state = 'done';
        fixture.report = _fixtureReport();
        await fixture.mount(tester);
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tap(find.byKey(const Key('termux-storage-cat-ai_team')));
        await tester.pumpAndSettle();
        fixture.cleanResult = jsonEncode({
          'freed_bytes': 0,
          'removed': <Object>[],
          'refused': [
            {
              'path': '',
              'reason': 'in_use',
              'processes': ['dolt', 'gc'],
            },
          ],
        });
        await tester.ensureVisible(
          find.byKey(const Key('termux-storage-clean-ai_team')),
        );
        await tester.tap(find.byKey(const Key('termux-storage-clean-ai_team')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('termux-storage-confirm')), findsNothing);
        expect(fixture.cleans, ['ai_team']);
        expect(
          find.text('In use by dolt, gc. Stop it under Running now first.'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('termux-storage-open-running')),
          findsOneWidget,
        );
        // Still listed: nothing was removed.
        expect(find.text('~/.oc/aiteam'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    for (final rtl in [false, true]) {
      testWidgets('report fits 320dp at 2.5x text ${rtl ? 'RTL' : 'LTR'}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        fixture.state = 'done';
        fixture.report = _fixtureReport();
        await fixture.mount(tester, textScale: 2.5, rtl: rtl, tall: false);
        await tester.pump(const Duration(milliseconds: 60));
        expect(find.byKey(const Key('termux-storage-total')), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const Key('termux-storage-cat-build_caches')),
          100,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('termux-storage-cat-build_caches')),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('termux-storage-clean-build_caches')),
          100,
        );
        await tester.pumpAndSettle();
        await tester.pump();
        await tester.scrollUntilVisible(
          find.byKey(const Key('termux-storage-project-IPTV_King')),
          100,
        );
        await tester.pumpAndSettle();
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });
}

String _rootfs(String path) =>
    '/data/data/com.termux/files/usr/var/lib/proot-distro/containers/opencode-ubuntu/rootfs$path';

String _fixtureReport() => jsonEncode({
  'scanned_at': 1788800000,
  'total_bytes': 46 * 1024 * 1024 * 1024,
  'categories': [
    {
      'key': 'build_caches',
      'label_key': 'termuxStorageCat_build_caches',
      'bytes': 8700000000,
      'deletable': true,
      'note_key': 'termuxStorageNoteBuildCaches',
      'paths': [
        {'path': _rootfs('/root/.gradle/caches'), 'bytes': 8000000000},
        {'path': _rootfs('/root/.gradle/wrapper'), 'bytes': 700000000},
      ],
    },
    {
      'key': 'agent_scratch',
      'bytes': 11000000000,
      'deletable': true,
      'paths': [
        {'path': _rootfs('/tmp/opencode/abc'), 'bytes': 11000000000},
      ],
    },
    {
      'key': 'ai_team',
      'bytes': 600000000,
      'deletable': true,
      'paths': [
        {
          'path': '/data/data/com.termux/files/home/.oc/aiteam',
          'bytes': 600000000,
        },
      ],
    },
    {
      'key': 'opencode',
      'bytes': 400000000,
      'deletable': false,
      'paths': [
        {'path': _rootfs('/usr/local/lib/node_modules'), 'bytes': 400000000},
      ],
    },
    {
      'key': 'projects',
      'bytes': 3600000000,
      'deletable': false,
      'paths': [
        {'path': _rootfs('/root/projects/IPTV_King'), 'bytes': 3600000000},
      ],
    },
  ],
  'projects': [
    {
      'name': 'IPTV_King',
      'path': _rootfs('/root/projects/IPTV_King'),
      'bytes': 3600000000,
      'build_bytes': 3000000000,
    },
  ],
});

/// The `oc/termux` channel as a phone whose tools answer by verb.
class _ChannelFixture {
  String state = 'idle';
  String log = '';
  String? report;
  String cleanResult = '{"freed_bytes":0,"removed":[],"refused":[]}';
  int scanStarts = 0;
  int cancels = 0;
  final cleans = <String>[];

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
    if (script.contains('nohup "\$TOOLS" storage-scan')) {
      scanStarts++;
      return _result('tools-started:4242\n');
    }
    final verb = RegExp(
      r'''exec "\$TOOLS" ([a-z-]+)(?: '([^']*)')?\n$''',
    ).firstMatch(script);
    switch (verb?.group(1)) {
      case 'storage-status':
        return _result(
          'state=$state\n__OC_TOOLS_LOG__\n$log\n__OC_TOOLS_JSON__\n${report ?? ''}\n',
        );
      case 'storage-cancel':
        cancels++;
        return _result('{"cancelled":true}\n');
      case 'storage-clean':
        cleans.add(verb!.group(2)!);
        return _result('$cleanResult\n');
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
        home: TermuxStorageScreen(
          now: () =>
              DateTime.fromMillisecondsSinceEpoch(1788800000 * 1000 + 120000),
          pollInterval: const Duration(milliseconds: 50),
        ),
      ),
    );
    await tester.pump();
  }
}
