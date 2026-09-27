// Golden renders of screen-phone-2's pages (wave 2b), rebuilt from kit
// parts: phone setup progress (wide window; the phone renders are
// test/goldens/setup_progress_*.png) and its "Stop setup?" sheet, and
// Running now (loaded, empty, could not read) with its details sheet and the
// AI Team group stop. Phone 412x915 and one wide window (1280x800), dark and
// light (owner decision 2026-09-27: no Arabic), with the app's real fonts at
// DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/screen_phone_2_golden_test.dart
// and look at every changed image before committing it.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/screens/termux_processes_screen.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;
import '../support/phone_setup_scenes.dart';

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

String _name(String shot, Size size, bool light) => [
  shot,
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

void _mockSecureStorage(WidgetTester tester) {
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    secure,
    (call) async => call.method == 'readAll' ? <String, String>{} : null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      secure,
      null,
    ),
  );
}

Future<void> _progress(
  WidgetTester tester,
  String shot, {
  required bool light,
  Size size = _phone,
  Future<void> Function()? then,
}) async {
  _mockSecureStorage(tester);
  final boundary = GlobalKey();
  final scene = setupScenes.firstWhere(
    (s) => s.name == 'setup_progress_running',
  );
  try {
    await pumpSetupScene(tester, scene, boundary: boundary, light: light);
    if (size != _phone) {
      tester.view.physicalSize = size;
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    if (then != null) await then();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/${_name(shot, size, light)}.png'),
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }
}

String _listing() => jsonEncode([
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
    'cmd': 'node /root/.npm/_npx/xyz/minimax-coding-plan-mcp/dist/index.js',
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
    'cwd': '/root/projects/shopfront',
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
]);

Future<void> _processes(
  WidgetTester tester,
  String shot, {
  required bool light,
  String? listing,
  Size size = _phone,
  Future<void> Function()? then,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  const channel = MethodChannel('oc/termux');
  final body = listing ?? _listing();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
    call,
  ) async {
    if (call.method != 'runInTermux') return true;
    return {
      'stdout': '$body\n',
      'stderr': '',
      'exitCode': 0,
      'err': -1,
      'errorMessage': '',
    };
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    ),
  );
  final boundary = GlobalKey();
  try {
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: captureTheme(light: light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const TermuxProcessesScreen(
            refreshInterval: Duration(hours: 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (then != null) await then();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/${_name(shot, size, light)}.png'),
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    testWidgets('setup progress wide · $mode', (tester) async {
      await _progress(
        tester,
        'phone_setup_progress_running',
        light: light,
        size: _wide,
      );
    });
    testWidgets('setup progress stop sheet · $mode', (tester) async {
      await _progress(
        tester,
        'phone_setup_progress_stop_sheet',
        light: light,
        then: () async {
          final cancel = find.byKey(const Key('setup-progress-cancel'));
          await tester.ensureVisible(cancel);
          await tester.pump();
          await tester.tap(cancel);
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        },
      );
    });

    testWidgets('running now · $mode', (tester) async {
      await _processes(tester, 'phone_termux_processes_loaded', light: light);
    });
    testWidgets('running now wide · $mode', (tester) async {
      await _processes(
        tester,
        'phone_termux_processes_loaded',
        light: light,
        size: _wide,
      );
    });
    testWidgets('running now empty · $mode', (tester) async {
      await _processes(
        tester,
        'phone_termux_processes_empty',
        light: light,
        listing: '[]',
      );
    });
    testWidgets('running now could not read · $mode', (tester) async {
      await _processes(
        tester,
        'phone_termux_processes_error',
        light: light,
        listing: 'not json',
      );
    });
    testWidgets('running now details · $mode', (tester) async {
      await _processes(
        tester,
        'phone_termux_processes_details_sheet',
        light: light,
        then: () async {
          await tester.tap(find.byKey(const Key('termux-proc-300')));
          await tester.pumpAndSettle();
        },
      );
    });
    testWidgets('running now stop the orphans · $mode', (tester) async {
      await _processes(
        tester,
        'phone_termux_processes_stop_orphans_sheet',
        light: light,
        then: () async {
          final stop = find.byKey(const Key('termux-procs-stop-orphans'));
          await tester.ensureVisible(stop);
          await tester.pumpAndSettle();
          await tester.tap(stop);
          await tester.pumpAndSettle();
        },
      );
    });
  }
}
