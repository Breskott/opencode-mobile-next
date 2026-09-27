// Golden renders of slice-P3.7b, the one "Undo from here" flow: the
// one-step sheet a server without staged undo gets (it replaced the old
// "Revert from this prompt?" confirm), and the review page and its delete
// question saying exactly how many messages the undo hides (SV1 count).
// Phone 412x915 and one wide window (1280x800), dark and light, with the
// app's real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/undo_from_here_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/ui/screens/staged_revert_screen.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;
import '../staged_revert_workflow_test.dart' show setup;

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

String _name(String shot, Size size, bool light) => [
  'undo_$shot',
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

MessageWithParts _message(String id, String role) => MessageWithParts(
  info: MessageInfo(id: id, sessionID: 'a', role: role),
  parts: [Part(id: '$id-p', type: 'text', text: id)],
);

/// A staged undo from msg_1 with three messages after it on the server.
Future<ConnectionController> _counted() async {
  final f = await setup(
    staged: SessionRevert(
      messageID: 'msg_1',
      snapshot: 'snap',
      files: [
        FileDiff(
          file: 'lib/settings/settings_screen.dart',
          status: 'modified',
          additions: 12,
          deletions: 4,
        ),
      ],
    ),
  );
  f.api.history = [
    _message('msg_1', 'user'),
    _message('msg_2', 'assistant'),
    _message('msg_3', 'user'),
    _message('msg_4', 'assistant'),
  ];
  return f.controller;
}

Future<void> _shot(
  WidgetTester tester,
  String shot, {
  required bool light,
  required Widget Function(ConnectionController controller) home,
  required Future<ConnectionController> Function() controller,
  Size size = _phone,
  Future<void> Function()? then,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  final boundary = GlobalKey();
  final ready = await controller();
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
          home: home(ready),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (then != null) {
      await then();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/${_name(shot, size, light)}.png'),
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  }
}

Widget _oneStep(ConnectionController c) => Builder(
  builder: (context) => Center(
    child: TextButton(
      onPressed: () => showStageRevertSheet(
        context,
        controller: c,
        review: c.reviewSessionRevert('a'),
        prompt:
            'Move the theme picker into Settings and keep the current '
            'accent when switching packs.',
        messagesAfter: 3,
        editedFiles: const [
          'lib/settings/settings_screen.dart',
          'lib/settings/theme_picker.dart',
        ],
        undo: () async {},
      ),
      child: const Text('open'),
    ),
  ),
);

Widget _review(ConnectionController c) =>
    StagedRevertScreen(controller: c, sessionID: 'a');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in [_phone, _wide]) {
      final wide = size == _wide ? ' wide' : '';
      testWidgets('one-step undo sheet$wide · $mode', (tester) async {
        await _shot(
          tester,
          'one_step_sheet',
          light: light,
          size: size,
          home: _oneStep,
          controller: () async => (await setup()).controller,
          then: () => tester.tap(find.text('open')),
        );
      });
      testWidgets('review with count$wide · $mode', (tester) async {
        await _shot(
          tester,
          'review_counted',
          light: light,
          size: size,
          home: _review,
          controller: _counted,
        );
      });
    }
    testWidgets('delete question with count · $mode', (tester) async {
      await _shot(
        tester,
        'delete_question_counted',
        light: light,
        home: _review,
        controller: _counted,
        then: () =>
            tester.tap(find.byKey(const ValueKey('commit-staged-revert'))),
      );
    });
  }
}
