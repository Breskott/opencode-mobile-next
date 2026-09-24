// Before/after captures for the design standard's Work tab leftovers
// (docs/design/design-standard.md §9 step 2 leftovers, 2026-09-24):
// conversation rows on KitRow, the AI Team section, the pin tip, the other
// servers and the shell's connection line, inside the real shell at
// 412x915 dp, dark theme, real fonts.
//
// It drives only the public shell with controller state (the Work tab
// fixture in test/support), so the same file renders the old code and the
// new:
//
//   flutter test --concurrency=1 --dart-define=DS_WORK_CAPTURE=before \
//     tool/capture/design_standard_work_test.dart    # on dca366f1
//   flutter test --concurrency=1 tool/capture/design_standard_work_test.dart
//
// Output: docs/qa/design-standard-setup-2026-09-24/<before|after>-work-*.png
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
import 'package:opencode_mobile/ui/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/support/work_tab_fixture.dart';
import 'fixtures.dart';

const _prefix = String.fromEnvironment(
  'DS_WORK_CAPTURE',
  defaultValue: 'after',
);
const _out = 'docs/qa/design-standard-setup-2026-09-24';

void _setUp(WidgetTester tester) {
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
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _shot(
  WidgetTester tester,
  String state,
  WorkController controller, {
  Widget home = const HomeScreen(initialTab: 0),
  double textScale = 1,
  VoidCallback? dispose,
}) async {
  final boundary = GlobalKey();
  try {
    await tester.pumpWidget(
      captureApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: home,
          ),
        ),
        boundaryKey: boundary,
        controller: controller,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await writePng(
      '$_out/$_prefix-work-$state.png',
      await capturePng(tester, boundary, pixelRatio: 1),
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

Future<WorkController> _loaded() async {
  final controller = await workController(
    sessions: workLoadedSessions(),
    busy: {'busy'},
    otherProjects: true,
  );
  controller.permissions['perm'] = workPermission();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  testWidgets('1 conversation rows', (tester) async {
    _setUp(tester);
    await _shot(tester, '1-rows', await _loaded());
  });

  testWidgets('2 conversation rows at 2x text', (tester) async {
    _setUp(tester);
    await _shot(tester, '2-rows-large-text', await _loaded(), textScale: 2);
  });

  testWidgets('3 AI Team section', (tester) async {
    _setUp(tester);
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
    await _shot(tester, '3-team', controller, dispose: team.dispose);
  });

  testWidgets('4 pin tip', (tester) async {
    _setUp(tester);
    final controller = await workController(
      sessions: workLoadedSessions(),
      otherProjects: true,
    );
    await controller.nudges.markFirstReplySeen();
    for (final directory in [workOther, workThird]) {
      await controller.nudges.noteProjectUsed(
        profileID: 'phone',
        directory: directory,
      );
    }
    await _shot(tester, '4-pin-tip', controller);
  });

  testWidgets('5 other servers', (tester) async {
    _setUp(tester);
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
    await _shot(
      tester,
      '5-other-servers',
      controller,
      dispose: monitor.dispose,
    );
  });

  testWidgets('6 connection lost on Inbox', (tester) async {
    _setUp(tester);
    final controller = await workController(status: StreamStatus.disconnected)
      ..lastError = 'Cannot reach http://127.0.0.1:4096: timed out';
    await _shot(
      tester,
      '6-shell-connection-lost',
      controller,
      home: const HomeScreen(initialTab: 1),
    );
  });
}
