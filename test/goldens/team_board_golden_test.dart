// Golden renders of the AI Team's board (docs/design/team-board-2026-09-26.md)
// at 412x915, dark and light, the app's real fonts, the 16-task fixture of
// test/support/team_board_fixture.dart: each column, the move sheet, the
// cancel confirmation, a move on its way, a refused move, read-only, empty,
// loading and error.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/team_board_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/team_board.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;
import '../support/team_board_fixture.dart';

enum BoardShot {
  working(BoardScene.loaded, 'team_board_working'),
  backlog(BoardScene.loaded, 'team_board_backlog'),
  ready(BoardScene.loaded, 'team_board_ready'),
  review(BoardScene.loaded, 'team_board_review'),
  done(BoardScene.loaded, 'team_board_done'),
  moveSheet(BoardScene.loaded, 'team_board_move_sheet'),
  teamMoves(BoardScene.loaded, 'team_board_team_moves'),
  cancelConfirm(BoardScene.loaded, 'team_board_cancel_confirm'),
  moving(BoardScene.loaded, 'team_board_moving'),
  refused(BoardScene.loaded, 'team_board_refused'),
  readOnly(BoardScene.readOnly, 'team_board_read_only'),
  empty(BoardScene.empty, 'team_board_empty'),
  loading(BoardScene.connecting, 'team_board_loading'),
  error(BoardScene.failed, 'team_board_error');

  const BoardShot(this.scene, this.fileName);
  final BoardScene scene;
  final String fileName;
}

Future<void> _tab(WidgetTester tester, TeamBoardColumn column) async {
  final tab = find.byKey(ValueKey('team-board-tab-${column.name}'));
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

Future<void> _more(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ValueKey('team-board-card-more-$id')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final shot in BoardShot.values) {
      testWidgets('${shot.fileName} · $mode', (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
        final (controller, gateway) = await boardController(shot.scene);
        await tester.pumpWidget(
          boardApp(
            controller,
            theme: captureTheme(light: light),
            boundary: boundary,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        switch (shot) {
          case BoardShot.backlog:
            await _tab(tester, TeamBoardColumn.backlog);
          case BoardShot.ready:
            await _tab(tester, TeamBoardColumn.ready);
          case BoardShot.review:
            await _tab(tester, TeamBoardColumn.review);
          case BoardShot.done:
            await _tab(tester, TeamBoardColumn.done);
          case BoardShot.moveSheet:
            await _tab(tester, TeamBoardColumn.backlog);
            await _more(tester, 'bd-crash');
          case BoardShot.teamMoves:
            await tester.longPress(find.text('Sync engine for offline drafts'));
            await tester.pumpAndSettle();
          case BoardShot.cancelConfirm:
            await _tab(tester, TeamBoardColumn.ready);
            await _more(tester, 'bd-rename');
            await tester.tap(
              find.byKey(const ValueKey('team-board-move-cancel')),
            );
            await tester.pumpAndSettle();
          case BoardShot.moving:
            await _tab(tester, TeamBoardColumn.backlog);
            await _more(tester, 'bd-crash');
            await tester.tap(
              find.byKey(const ValueKey('team-board-move-startNow')),
            );
            await tester.pumpAndSettle();
            await _tab(tester, TeamBoardColumn.ready);
          case BoardShot.refused:
            (gateway as BoardGateway).refuse =
                'bead bd-rename was changed on the host; refresh and try '
                'again';
            await _tab(tester, TeamBoardColumn.ready);
            await _more(tester, 'bd-rename');
            await tester.tap(
              find.byKey(const ValueKey('team-board-move-backToBacklog')),
            );
            await tester.pumpAndSettle();
          case BoardShot.loading:
            await tester.pump(const Duration(seconds: 1));
          case BoardShot.working ||
              BoardShot.readOnly ||
              BoardShot.empty ||
              BoardShot.error:
            break;
        }
        await tester.pump(const Duration(milliseconds: 600));
        try {
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(boundary),
            matchesGoldenFile('${shot.fileName}_$mode.png'),
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          controller.dispose();
          await tester.pump();
        }
      });
    }
  }
}
