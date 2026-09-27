// Golden renders for slice-R12: a board card while its move is in flight
// ("Moving to Review…" as a sending receipt). The host sheet, the turn-off
// question and the setup output are in shared_team_1_golden_test.dart and
// shared_phone_1_golden_test.dart. Phone 412x915 and one wide window
// (1280x800), dark and light, with the app's real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/slice_r12_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/team_board.dart';
import 'package:opencode_mobile/ui/widgets/team_board_card.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

String _name(String shot, Size size, bool light) => [
  shot,
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

TeamBoardCard _card({required bool moving}) => TeamBoardCard(
  item: WorkItem(
    id: moving ? 'oc-12' : 'oc-13',
    title: moving ? 'Fix flaky checkout test' : 'Add retry to the uploader',
    state: WorkState.review,
    updatedAt: DateTime.utc(2026, 9, 27, 11, 40),
  ),
  column: TeamBoardColumn.review,
  priority: WorkPriority.high,
  agentName: 'fox',
  moving: moving,
);

void main() {
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    for (final size in [_phone, _wide]) {
      testWidgets('board card moving (${light ? 'light' : 'dark'}, $size)', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
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
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: true),
                  child: child!,
                ),
                home: Scaffold(
                  body: SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final moving in [true, false])
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: TeamBoardCardView(
                                    card: _card(moving: moving),
                                    now: DateTime.utc(2026, 9, 27, 12),
                                    onOpen: () {},
                                    onMoves: () {},
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(boundary),
            matchesGoldenFile(
              'goldens/${_name('r12_board_card_moving', size, light)}.png',
            ),
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }
}
