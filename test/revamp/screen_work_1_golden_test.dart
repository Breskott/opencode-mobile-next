// Golden renders of screen-work-1's pages (wave 2b): the Work tab rebuilt
// from kit parts, its project sheet, the delete confirmation, the one
// archive path's Undo line and the folder chooser. Phone 412x915 and one
// wide window (1280x800, two panes), dark and light (owner decision
// 2026-09-27: no Arabic), with the app's real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/screen_work_1_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/ui/kit/kit_motion.dart';
import 'package:opencode_mobile/ui/kit/kit_undo.dart';
import 'package:opencode_mobile/ui/screens/home_screen.dart';
import 'package:opencode_mobile/ui/screens/workspace_screen.dart';

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

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

String _name(String state, Size size, bool light) {
  final sized = size == _phone
      ? ''
      : '_${size.width.toInt()}x${size.height.toInt()}';
  return 'work_workspace_$state${sized}_${light ? 'light' : 'dark'}';
}

Future<void> _golden(
  WidgetTester tester,
  String state, {
  required bool light,
  required WorkController controller,
  Size size = _phone,
  Future<void> Function()? before,
}) async {
  _mockSecureStorage(tester);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  try {
    await tester.pumpWidget(
      captureApp(
        home: const HomeScreen(initialTab: 0),
        boundaryKey: boundary,
        controller: controller,
        light: light,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(KitMotion.entrance);
    if (before != null) {
      await before();
      await tester.pump(KitMotion.entrance);
    }
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/${_name(state, size, light)}.png'),
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(KitUndo.window);
    controller.dispose();
    await tester.pump();
  }
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
  tearDown(() => WorkspaceScreen.debugRunawayWatcher = null);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final size in [_phone, _wide]) {
      testWidgets('work · loaded · ${size.width.toInt()} · $mode', (
        tester,
      ) async {
        await _golden(
          tester,
          'loaded',
          light: light,
          size: size,
          controller: await _loaded(),
        );
      });
    }

    testWidgets('work · empty · $mode', (tester) async {
      await _golden(
        tester,
        'empty',
        light: light,
        controller: await workController(),
      );
    });

    testWidgets('work · project sheet · $mode', (tester) async {
      await _golden(
        tester,
        'context_sheet',
        light: light,
        controller: await _loaded(),
        before: () async {
          await tester.tap(find.byKey(const ValueKey('current-project-entry')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
        },
      );
    });

    testWidgets('work · archived with Undo · $mode', (tester) async {
      await _golden(
        tester,
        'archive_undo',
        light: light,
        controller: await _loaded(),
        before: () async {
          await tester.longPress(find.text('Explain the budget rules engine'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(find.text('Archive'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
        },
      );
    });

    testWidgets('work · delete confirmation · $mode', (tester) async {
      final controller = await _loaded();
      final older = controller.sessionsById['older']!;
      controller.sessionsById['older'] = Session(
        id: older.id,
        title: older.title,
        directory: older.directory,
        time: older.time,
        shareUrl: 'https://opncd.ai/s/abc',
      );
      await _golden(
        tester,
        'delete_confirm',
        light: light,
        controller: controller,
        before: () async {
          await tester.longPress(find.text('Explain the budget rules engine'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          // The row menu holds the conversation menu too (slice-P10.2).
          await tester.ensureVisible(find.text('Delete'));
          await tester.pump();
          await tester.tap(find.text('Delete'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
        },
      );
    });

    testWidgets('work · folder chooser · $mode', (tester) async {
      await _golden(
        tester,
        'folder_chooser',
        light: light,
        controller: await workController(
          directory: null,
          savedLocation: false,
          repository: WorkRepository()..projects = const [],
        ),
      );
    });

    testWidgets('work · folder chooser, list failed · $mode', (tester) async {
      await _golden(
        tester,
        'folder_chooser_error',
        light: light,
        controller: await workController(
          directory: null,
          savedLocation: false,
          status: StreamStatus.connected,
          repository: _FailingProjects(),
        ),
      );
    });
  }
}

class _FailingProjects extends WorkRepository {
  @override
  Future<List<WorkspaceProject>> listProjects() async =>
      throw Exception('connection reset by peer');
}
