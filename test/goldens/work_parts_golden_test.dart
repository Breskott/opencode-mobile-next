// Golden renders of the Work tab's own parts moved onto the design kit
// (docs/design/design-standard.md §8, migration step 2 leftovers): the AI
// Team section, the one-time pin tip, and the shell's connection line on the
// other tabs. 412x915, dark and light, with the app's real fonts.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/work_parts_golden_test.dart
// and look at every changed image before committing it.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/fixture_gateway.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profile_monitor.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit_motion.dart';
import 'package:opencode_mobile/ui/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart' show captureApp, loadCaptureFonts;
import '../support/work_tab_fixture.dart';

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

Future<void> _golden(
  WidgetTester tester,
  String name, {
  required bool light,
  required WorkController controller,
  Widget home = const HomeScreen(initialTab: 0),
  VoidCallback? dispose,
  Duration settle = Duration.zero,
}) async {
  _mockSecureStorage(tester);
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  try {
    await tester.pumpWidget(
      captureApp(
        home: home,
        boundaryKey: boundary,
        controller: controller,
        light: light,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(settle);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('${name}_${light ? 'light' : 'dark'}.png'),
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    dispose?.call();
    controller.dispose();
    await tester.pump();
  }
}

String _fixtureRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 5; i++) {
    final candidate = Directory('${dir.path}/tool/qa/gascity_fixture');
    if (candidate.existsSync()) return candidate.path;
    dir = dir.parent;
  }
  throw StateError('tool/qa/gascity_fixture not found');
}

/// The AI Team over the recorded Gas City fixture: one convoy, agents at
/// work, on the computer.
Future<OrchestrationController> _team() async {
  final prefs = await SharedPreferences.getInstance();
  final fixturePath = _fixtureRoot();
  final config = OrchestrationConfig(
    provider: OrchestrationProvider.fixture,
    url: fixturePath,
    city: 'bright-lights',
    hostMode: OrchestrationHostMode.computer,
    enabledAt: DateTime.utc(2026, 9, 10),
  );
  final team = OrchestrationController(
    profile: ServerProfile(
      id: 'phone',
      name: 'This device (Termux)',
      baseUrl: 'http://127.0.0.1:4096',
      orchestration: config,
    ),
    config: config,
    store: OrchestrationStore(prefs),
    gatewayFactory: (_, _) => FixtureOrchestrationGateway(
      fixturePath: fixturePath,
      hostMode: OrchestrationHostMode.computer,
    ),
  );
  await team.start();
  return team;
}

/// The other servers' watcher, answering with fixed snapshots: Claude Code
/// on this phone waits on an approval, the laptop has two runs going.
class _Monitor extends ProfileMonitor {
  _Monitor(ProfileStore store)
    : super(
        store: store,
        createGateway: (_) => throw UnimplementedError(),
        isReadable: (_) => true,
        networkWifi: () async => null,
        alert: (_, _, _, _) async => false,
        dismiss: (_) async => false,
      );

  @override
  ProfileAttentionSnapshot snapshotFor(String id) => switch (id) {
    'claude' => ProfileAttentionSnapshot(
      profileID: id,
      status: ProfileMonitorStatus.current,
      complete: true,
      runningCount: 1,
      requests: const [
        MonitoredRequest(
          id: 'perm-1',
          sessionID: 's-1',
          kind: MonitoredRequestKind.permission,
        ),
      ],
    ),
    'laptop' => ProfileAttentionSnapshot(
      profileID: id,
      status: ProfileMonitorStatus.current,
      complete: true,
      runningCount: 2,
    ),
    _ => ProfileAttentionSnapshot(
      profileID: id,
      status: ProfileMonitorStatus.disabled,
    ),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    testWidgets('work · AI Team section · $mode', (tester) async {
      final controller = await workController(
        sessions: {
          'older': workSession(
            'older',
            'Explain the budget rules engine',
            ago: 5 * 60 * workMinute,
          ),
        },
      );
      final team = await _team();
      controller.team = team;
      await _golden(
        tester,
        'work_team',
        light: light,
        controller: controller,
        dispose: team.dispose,
      );
    });

    testWidgets('work · pin tip · $mode', (tester) async {
      final controller = await workController(
        sessions: workLoadedSessions(),
        otherProjects: true,
      );
      // Past the first reply, two projects used: Work offers the pin tip
      // once.
      await controller.nudges.markFirstReplySeen();
      for (final directory in [workOther, workThird]) {
        await controller.nudges.noteProjectUsed(
          profileID: 'phone',
          directory: directory,
        );
      }
      await _golden(tester, 'work_nudge', light: light, controller: controller);
    });

    testWidgets('work · other servers · $mode', (tester) async {
      final controller = await workController(
        sessions: workLoadedSessions(),
        otherServers: [
          ServerProfile(
            id: 'claude',
            name: 'Claude Code (this phone)',
            baseUrl: 'http://127.0.0.1:6767',
          ),
          ServerProfile(
            id: 'laptop',
            name: 'Laptop',
            baseUrl: 'http://100.64.0.7:4096',
          ),
        ],
      );
      final monitor = _Monitor(controller.store);
      controller.monitor = monitor;
      await _golden(
        tester,
        'work_other_servers',
        light: light,
        controller: controller,
        dispose: monitor.dispose,
      );
    });

    testWidgets('shell · connection lost on Inbox · $mode', (tester) async {
      final controller = await workController(status: StreamStatus.disconnected)
        ..lastError = 'Cannot reach http://127.0.0.1:4096: timed out';
      await _golden(
        tester,
        'shell_reconnecting',
        light: light,
        controller: controller,
        home: const HomeScreen(initialTab: 1),
        // Inbox's drawing finishes its entrance.
        settle: KitMotion.entrance,
      );
    });
  }
}
