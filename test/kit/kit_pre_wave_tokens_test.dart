// The pre-wave named tokens (docs/ux-system/kit-api/_new-tokens.md) exist
// with the values the frozen wave-1 specs state, so no wave-1 unit edits
// kit_tokens.dart, kit_layout.dart or kit_motion.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_iconography.dart';
import 'package:opencode_mobile/ui/kit/kit_layout.dart';
import 'package:opencode_mobile/ui/kit/kit_motion.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';
import 'package:opencode_mobile/ui/theme_roles.dart';

Future<(double, double)> _strokes(WidgetTester tester, double dpr) async {
  late double hairline;
  late double ring;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(devicePixelRatio: dpr),
      child: Builder(
        builder: (context) {
          hairline = KitTokens.hairlineWidth(context);
          ring = KitTokens.focusRingWidth(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return (hairline, ring);
}

void main() {
  testWidgets('hairline is one physical pixel, focus ring two', (tester) async {
    final (h3, r3) = await _strokes(tester, 3);
    expect(h3, 1 / 3);
    expect(r3, 2 / 3);
    final (h1, r1) = await _strokes(tester, 1);
    expect(h1, 1);
    expect(r1, 2);
    final (_, rLow) = await _strokes(tester, .75);
    expect(rLow, greaterThanOrEqualTo(1));
  });

  test('KitTokens pre-wave constants', () {
    final expected = <String, num>{
      'chipHeight': KitTokens.chipHeight,
      'choiceRowMinHeight': KitTokens.choiceRowMinHeight,
      'composerActionSize': KitTokens.composerActionSize,
      'composerStopSquare': KitTokens.composerStopSquare,
      'crumbMaxWidth': KitTokens.crumbMaxWidth,
      'detailsLabelColumn': KitTokens.detailsLabelColumn,
      'disabledAlpha': KitTokens.disabledAlpha,
      'staleAlpha': KitTokens.staleAlpha,
      'duotoneWash': KitTokens.duotoneWash,
      'fieldRadius': KitTokens.fieldRadius,
      'monogramMaxTextScale': KitTokens.monogramMaxTextScale,
      'popoverRadius': KitTokens.popoverRadius,
      'bubbleRadius': KitTokens.bubbleRadius,
      'bubbleTailRadius': KitTokens.bubbleTailRadius,
      'logFoldedLines': KitTokens.logFoldedLines,
      'termBubbleMaxHeight': KitTokens.termBubbleMaxHeight,
      'statusLineMinHeight': KitTokens.statusLineMinHeight,
      'loadingBarHeight': KitTokens.loadingBarHeight,
      'progressBarHeight': KitTokens.progressBarHeight,
      'progressBarRadius': KitTokens.progressBarRadius,
      'navLabelMaxScale': KitTokens.navLabelMaxScale,
      'meterBars': KitTokens.meterBars,
      'meterBarWidth': KitTokens.meterBarWidth,
      'meterBarMin': KitTokens.meterBarMin,
      'meterBarMax': KitTokens.meterBarMax,
      'badgeHeight': KitTokens.badgeHeight,
      'badgeMinWidth': KitTokens.badgeMinWidth,
      'badgeTextScaleMax': KitTokens.badgeTextScaleMax,
      'qrMaxSize': KitTokens.qrMaxSize,
      'qrQuietModules': KitTokens.qrQuietModules,
      'needsYouRingWidth': KitTokens.needsYouRingWidth,
      'needsYouRingAlpha': KitTokens.needsYouRingAlpha,
      'requestTileSize': KitTokens.requestTileSize,
      'requestTileRadius': KitTokens.requestTileRadius,
      'requestMaxHeightShare': KitTokens.requestMaxHeightShare,
      'scannerWindow': KitTokens.scannerWindow,
      'scannerBracket': KitTokens.scannerBracket,
      'sceneWashAlpha': KitTokens.sceneWashAlpha,
      'illustrationPage': KitTokens.illustrationPage,
      'illustrationInline': KitTokens.illustrationInline,
      'stateVerticalPadding': KitTokens.stateVerticalPadding,
      'markSlotSize': KitTokens.markSlotSize,
      'markRingSize': KitTokens.markRingSize,
      'markDotSize': KitTokens.markDotSize,
      'swatchMinWidth': KitTokens.swatchMinWidth,
      'swatchPreviewHeight': KitTokens.swatchPreviewHeight,
      'swatchDot': KitTokens.swatchDot,
      'terminalMaxTextScale': KitTokens.terminalMaxTextScale,
      'terminalKeyMaxTextScale': KitTokens.terminalKeyMaxTextScale,
      'graphNodeWidth': KitTokens.graphNodeWidth,
      'graphColumnGap': KitTokens.graphColumnGap,
      'graphRowGap': KitTokens.graphRowGap,
      'graphMaxLanes': KitTokens.graphMaxLanes,
      'graphDash': KitTokens.graphDash,
    };
    expect(expected, {
      'chipHeight': 32,
      'choiceRowMinHeight': 56,
      'composerActionSize': 40,
      'composerStopSquare': 14,
      'crumbMaxWidth': 160,
      'detailsLabelColumn': 160,
      'disabledAlpha': .38,
      'staleAlpha': .6,
      'duotoneWash': .2,
      'fieldRadius': 14,
      'monogramMaxTextScale': 1.3,
      'popoverRadius': 14,
      'bubbleRadius': 20,
      'bubbleTailRadius': 6,
      'logFoldedLines': 12,
      'termBubbleMaxHeight': .4,
      'statusLineMinHeight': 52,
      'loadingBarHeight': 2,
      'progressBarHeight': 4,
      'progressBarRadius': 2,
      'navLabelMaxScale': 2,
      'meterBars': 9,
      'meterBarWidth': 6,
      'meterBarMin': 12,
      'meterBarMax': 20,
      'badgeHeight': 18,
      'badgeMinWidth': 18,
      'badgeTextScaleMax': 1.3,
      'qrMaxSize': 240,
      'qrQuietModules': 4,
      'needsYouRingWidth': 4,
      'needsYouRingAlpha': .06,
      'requestTileSize': 36,
      'requestTileRadius': 10,
      'requestMaxHeightShare': .45,
      'scannerWindow': 240,
      'scannerBracket': 28,
      'sceneWashAlpha': .12,
      'illustrationPage': 160,
      'illustrationInline': 88,
      'stateVerticalPadding': 32,
      'markSlotSize': 32,
      'markRingSize': 10,
      'markDotSize': 12,
      'swatchMinWidth': 112,
      'swatchPreviewHeight': 56,
      'swatchDot': 12,
      'terminalMaxTextScale': 2,
      'terminalKeyMaxTextScale': 1.3,
      'graphNodeWidth': 156,
      'graphColumnGap': 24,
      'graphRowGap': 48,
      'graphMaxLanes': 6,
      'graphDash': 4,
    });
    expect(KitTokens.qrInk, graphiteLight.text1);
    expect(KitTokens.qrPaper, graphiteLight.surface1);
  });

  test('KitLayout pre-wave widths and shares', () {
    expect(KitLayout.paneListWidth, 296);
    expect(KitLayout.paneDetailMaxWidth, 700);
    expect(KitLayout.paneSideWidth, 340);
    expect(
      [KitLayout.pcListPane, KitLayout.pcDetailPane, KitLayout.pcSidePane],
      [296, 700, 340],
    );
    expect(KitLayout.railWidth, 80);
    expect(KitLayout.undoMaxWidth, 480);
    expect(KitLayout.popoverMinWidth, 200);
    expect(KitLayout.popoverMaxWidth, 320);
    expect(KitLayout.bubbleMaxShare, .85);
    expect(KitLayout.composerMaxShare, .4);
    expect(KitLayout.laneMaxWidth, 400);
    expect(KitLayout.lanePeek, 20);
    expect(KitLayout.laneMinWidth, 296);
    expect(KitLayout.stateMaxWidth, 440);
  });

  test('KitMotion pre-wave waits', () {
    expect(KitMotion.escalateAfter, const Duration(seconds: 8));
    expect(KitMotion.undoWindow, const Duration(seconds: 8));
    expect(KitMotion.copiedHold, const Duration(seconds: 2));
    expect(KitMotion.logPoll, const Duration(seconds: 2));
    expect(KitMotion.typingSettle, const Duration(milliseconds: 300));
  });

  test('KitShape and KitSurfaceLevel resolve to the kit radii and roles', () {
    final tokens = KitTokens.fallback(ThemeData());
    RoundedRectangleBorder r(KitShape s) =>
        tokens.shapeOf(s) as RoundedRectangleBorder;
    expect(r(KitShape.square).borderRadius, BorderRadius.zero);
    expect(
      r(KitShape.tile).borderRadius,
      BorderRadius.circular(tokens.iconTileRadius),
    );
    expect(
      r(KitShape.button).borderRadius,
      BorderRadius.circular(tokens.buttonRadius),
    );
    expect(
      r(KitShape.panel).borderRadius,
      BorderRadius.circular(tokens.panelCornerRadius),
    );
    expect(tokens.shapeOf(KitShape.pill), isA<StadiumBorder>());
    expect(tokens.shapeOf(KitShape.circle), isA<CircleBorder>());
    expect(tokens.fillOf(KitSurfaceLevel.surface2), tokens.roles.surface2);
    expect(tokens.segmentFills, [
      tokens.roles.accent,
      tokens.roles.text2,
      tokens.roles.text3,
      tokens.roles.surface3,
    ]);
  });

  test('wrap glyph is the Phosphor text-align-justify codepoint', () {
    expect(AppIconography.wrapText.codePoint, 0xe482);
    expect(AppIconography.wrapText.fontFamily, 'AppPhosphorRegular');
  });
}
