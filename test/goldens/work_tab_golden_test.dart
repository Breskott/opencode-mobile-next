// Golden renders of the screens migrated to the design kit
// (docs/design/design-standard.md §8): the connection states and the Work
// tab, at 412x915, dark and light, with the app's real fonts.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/work_tab_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/ui/kit/kit_motion.dart';
import 'package:opencode_mobile/ui/screens/home_screen.dart';
import 'package:opencode_mobile/ui/screens/workspace_screen.dart';
import 'package:opencode_mobile/ui/widgets/saved_server_connection_card.dart';
import 'package:opencode_mobile/ui/widgets/work_status_line.dart';

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
  Future<void> Function()? before,
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
    if (before != null) {
      await before();
      // A state that changed during `before` arrives with a short fade
      // (design standard §10); capture it once it has arrived.
      await tester.pump(KitMotion.standard);
    }
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('${name}_${light ? 'light' : 'dark'}.png'),
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await tester.pump();
  }
}

Widget _card({String? error, bool starting = false, VoidCallback? onStart}) =>
    Scaffold(
      body: SafeArea(
        child: SavedServerConnectionCard(
          profileName: 'This device (Termux)',
          baseUrl: 'http://127.0.0.1:4096',
          error: error,
          attempts: 1,
          supportsTermux: true,
          onChangeServer: () {},
          onRetry: () {},
          onOpenTermuxSetup: () {},
          onStartPhoneServer: onStart,
          startingPhoneServer: starting,
        ),
      ),
    );

/// Long enough for a state's drawing to finish drawing itself in
/// (KitMotion.entrance), so the golden shows the finished frame.
const _drawn = Duration(seconds: 1);

const _refused =
    'Cannot reach http://127.0.0.1:4096: Connection refused (errno = 111)';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  tearDown(() => WorkspaceScreen.debugRunawayWatcher = null);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    testWidgets('connection · connecting · $mode', (tester) async {
      await _golden(
        tester,
        'connection_connecting',
        light: light,
        controller: await workController(status: StreamStatus.connecting),
        home: _card(onStart: () {}),
        before: () => tester.pump(_drawn),
      );
    });

    testWidgets('connection · not answering · $mode', (tester) async {
      await _golden(
        tester,
        'connection_not_answering',
        light: light,
        controller: await workController(status: StreamStatus.connecting),
        home: _card(onStart: () {}),
        before: () async {
          await tester.pump(const Duration(seconds: 9));
          await tester.pump(_drawn);
        },
      );
    });

    testWidgets('connection · stopped · $mode', (tester) async {
      await _golden(
        tester,
        'connection_stopped',
        light: light,
        controller: await workController(status: StreamStatus.disconnected),
        home: _card(error: _refused, onStart: () {}),
        before: () => tester.pump(_drawn),
      );
    });

    testWidgets('connection · starting · $mode', (tester) async {
      await _golden(
        tester,
        'connection_starting',
        light: light,
        controller: await workController(status: StreamStatus.disconnected),
        // The last attempt's error is still there while it starts: the
        // screen must say "Starting", not "stopped".
        home: _card(error: _refused, starting: true, onStart: () {}),
        before: () => tester.pump(_drawn),
      );
    });

    testWidgets('connection · failed (remote) · $mode', (tester) async {
      await _golden(
        tester,
        'connection_failed',
        light: light,
        controller: await workController(status: StreamStatus.disconnected),
        home: Scaffold(
          body: SafeArea(
            child: SavedServerConnectionCard(
              profileName: 'Laptop',
              baseUrl: 'http://100.64.0.7:4096',
              error: 'Cannot reach http://100.64.0.7:4096: timed out',
              attempts: 2,
              supportsTermux: true,
              onChangeServer: () {},
              onRetry: () {},
            ),
          ),
        ),
      );
    });

    testWidgets('work · restoring · $mode', (tester) async {
      final controller =
          await workController(directory: null, otherProjects: true)
            ..holdSelection = true;
      await _golden(
        tester,
        'work_restoring',
        light: light,
        controller: controller,
      );
    });

    testWidgets('work · loading · $mode', (tester) async {
      final controller =
          await workController(
              otherProjects: true,
              repository: WorkRepository()..holdProjects = Completer<void>(),
            )
            ..sessionsLoading = true;
      await _golden(
        tester,
        'work_loading',
        light: light,
        controller: controller,
      );
    });

    testWidgets('work · empty · $mode', (tester) async {
      await _golden(
        tester,
        'work_empty',
        light: light,
        controller: await workController(),
        // The empty state's drawing finishes its entrance.
        before: () => tester.pump(KitMotion.entrance),
      );
    });

    testWidgets('work · loaded · $mode', (tester) async {
      final controller = await workController(
        sessions: workLoadedSessions(),
        busy: {'busy'},
        otherProjects: true,
      );
      controller.permissions['perm'] = workPermission();
      await _golden(
        tester,
        'work_loaded',
        light: light,
        controller: controller,
      );
    });

    testWidgets('work · not answering · $mode', (tester) async {
      final controller = await workController(
        status: StreamStatus.reconnecting,
        sessions: workLoadedSessions(),
        otherProjects: true,
      );
      await _golden(
        tester,
        'work_not_answering',
        light: light,
        controller: controller,
        before: () async {
          await tester.pump(const Duration(seconds: 9));
          await tester.pump(const Duration(milliseconds: 300));
        },
      );
    });

    testWidgets('work · runaway · $mode', (tester) async {
      WorkspaceScreen.debugRunawayWatcher = (context, builder) => builder(
        context,
        WorkRunawayNotice(
          identity: 1,
          helper: 'node',
          busyFor: '10 min',
          onStop: () {},
          onDismiss: () {},
        ),
      );
      final controller = await workController(
        sessions: workLoadedSessions(),
        otherProjects: true,
      );
      await _golden(
        tester,
        'work_runaway',
        light: light,
        controller: controller,
      );
    });

    testWidgets('work · no project yet · $mode', (tester) async {
      final controller = await workController(
        directory: null,
        savedLocation: false,
        repository: WorkRepository()..projects = const [],
      );
      await _golden(
        tester,
        'work_chooser',
        light: light,
        controller: controller,
        before: () => tester.pump(KitMotion.entrance),
      );
    });
  }
}
