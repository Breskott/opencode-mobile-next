// Golden renders of shared-team-1's pages (wave 2a): the board's move,
// priority, add and cancel sheets, the manual host sheet (idle, testing,
// no answer), the host guide, the turn-off question and the dispatch How
// sheet, all on the kit sheet frame. Phone 412x915 and one wide window
// (1280x800), dark and light (owner decision 2026-09-27: no Arabic), with
// the app's real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/shared_team_1_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/team_board.dart';
import 'package:opencode_mobile/ui/widgets/team_board_move_sheet.dart';
import 'package:opencode_mobile/ui/widgets/team_host_form.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

String _name(String shot, Size size, bool light) => [
  shot,
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

TeamBoardCard _card() => TeamBoardCard(
  item: const WorkItem(
    id: 'oc-12',
    title: 'Fix flaky checkout test',
    state: WorkState.ready,
  ),
  column: TeamBoardColumn.ready,
  priority: WorkPriority.high,
);

Future<void> _shot(
  WidgetTester tester,
  String shot, {
  required bool light,
  Size size = _phone,
  required FutureOr<void> Function(BuildContext context) open,
  Future<void> Function(WidgetTester tester)? then,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  final boundary = GlobalKey();
  try {
    late BuildContext context;
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
          home: Scaffold(
            body: SafeArea(
              child: Builder(
                builder: (inner) {
                  context = inner;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      ),
    );
    unawaited(Future.sync(() => open(context)));
    await tester.pumpAndSettle();
    if (then != null) await then(tester);
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

Future<void> _testUrl(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('team-host-url')),
    'http://100.64.0.3:8372',
  );
  await tester.tap(find.byKey(const ValueKey('team-host-submit')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final theme = light ? 'light' : 'dark';

    for (final size in [_phone, _wide]) {
      testWidgets('board move sheet ($theme, $size)', (tester) async {
        await _shot(
          tester,
          'team_board_move_sheet',
          light: light,
          size: size,
          open: (context) => showTeamBoardMoveSheet(
            context,
            card: _card(),
            moves: const [
              TeamBoardMove.backToBacklog,
              TeamBoardMove.priority,
              TeamBoardMove.cancel,
            ],
            readOnly: false,
            hasConversation: true,
          ),
        );
      });

      testWidgets('host sheet, no answer ($theme, $size)', (tester) async {
        final previous = teamHostProbe;
        teamHostProbe = (url, {city}) async => const ProbeUnreachable(
          error: 'SocketException: Connection refused (OS Error: 111)',
        );
        addTearDown(() => teamHostProbe = previous);
        await _shot(
          tester,
          'team_host_sheet_unanswered',
          light: light,
          size: size,
          open: showTeamHostSheet,
          then: _testUrl,
        );
      });
    }

    testWidgets('board move sheet, read-only ($theme)', (tester) async {
      await _shot(
        tester,
        'team_board_move_sheet_read_only',
        light: light,
        open: (context) => showTeamBoardMoveSheet(
          context,
          card: _card(),
          moves: const [],
          readOnly: true,
          hasConversation: false,
        ),
      );
    });

    testWidgets('board priority sheet ($theme)', (tester) async {
      await _shot(
        tester,
        'team_board_priority_sheet',
        light: light,
        open: (context) =>
            showTeamBoardPrioritySheet(context, current: WorkPriority.high),
      );
    });

    testWidgets('board cancel question ($theme)', (tester) async {
      await _shot(
        tester,
        'team_board_cancel_confirm_sheet',
        light: light,
        open: (context) =>
            confirmTeamBoardCancel(context, 'Fix flaky checkout test'),
      );
    });

    testWidgets('host sheet, idle ($theme)', (tester) async {
      await _shot(
        tester,
        'team_host_sheet',
        light: light,
        open: showTeamHostSheet,
      );
    });

    testWidgets('host sheet, testing ($theme)', (tester) async {
      final previous = teamHostProbe;
      final never = Completer<ProbeVerdict>();
      teamHostProbe = (url, {city}) => never.future;
      addTearDown(() => teamHostProbe = previous);
      await _shot(
        tester,
        'team_host_sheet_testing',
        light: light,
        open: showTeamHostSheet,
        then: (tester) async {
          await tester.enterText(
            find.byKey(const ValueKey('team-host-url')),
            'http://100.64.0.3:8372',
          );
          await tester.tap(find.byKey(const ValueKey('team-host-submit')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        },
      );
    });

    testWidgets('host guide sheet ($theme)', (tester) async {
      await _shot(
        tester,
        'team_host_guide_sheet',
        light: light,
        open: showTeamHostGuideSheet,
      );
    });

    testWidgets('turn-off question ($theme)', (tester) async {
      await _shot(
        tester,
        'team_turn_off_sheet',
        light: light,
        open: (context) => showTeamTurnOffSheet(context, 'Laptop'),
      );
    });
  }
}
