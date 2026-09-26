// Gallery (gate G4) for KitJumpPill, docs/ux-system/kit-api/KitJumpPill.md;
// K2 §1.19, §8.2.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_jump_pill_golden_test.dart
// and look at every changed image before committing it.
//
// Owner decision 2026-09-27 (dated later than KitJumpPill.md, R15): Arabic
// is dropped — no Arabic/RTL galleries, no text-2.0-at-every-size sweep;
// galleries are phone 412x915 and one wide size 1280x800 only, light and
// dark. This replaces KitJumpPill.md's own "Galleries required" list
// (360x800/800x1280/915x412/1600x1000, text 2.0 and Arabic RTL at 412x915
// and 1280x800), a PROC-20 note recorded in the unit's QA record.
//
// kit-KitComposer has not merged (no unit dependency; the pill is a leaf
// over any scroll area), so the composer-height inset a real chat composer
// would publish is stood in for by a plain bottom bar publishing the same
// clearance through KitBottomInset, as KitUndo's own gallery does for its
// dock scene. Recorded as NOT proven in the QA record until kit-KitComposer
// lands and this gallery is updated to the real thing.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_bottom_inset.dart';
import 'package:opencode_mobile/ui/kit/kit_jump_pill.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import 'kit_gallery.dart';

/// A composer-height bottom bar, published through [KitBottomInset] exactly
/// as the real composer will (file header note).
Widget _composerScene(BuildContext context) {
  final tokens = KitTokens.of(context);
  return PositionedDirectional(
    start: 0,
    end: 0,
    bottom: 0,
    child: Container(height: tokens.navHeight, color: tokens.roles.surface2),
  );
}

/// A transcript-like list: rows of body text standing in for the chat
/// transcript a real jump pill floats over. Top and bottom padding clear
/// both the composer and either pill's own floating band (top for
/// [KitJumpPill.older], bottom for the default), so no row sits underneath
/// the solid pill: the pill is meant to hover clear of read messages, and a
/// row a screen reader would announce out of visual top-to-bottom order
/// (behind an opaque pill it never scrolls with) is a scene defect, not a
/// KitJumpPill one (G5, STANDARDS §18, is absolute).
Widget _transcriptScene(BuildContext context) {
  final tokens = KitTokens.of(context);
  final reserve = tokens.navHeight + tokens.minTarget + tokens.space3 * 3;
  return ListView.builder(
    padding: EdgeInsets.fromLTRB(
      tokens.space4,
      reserve,
      tokens.space4,
      reserve,
    ),
    itemCount: 6,
    itemBuilder: (context, i) => Padding(
      padding: EdgeInsets.only(bottom: tokens.space3),
      child: KitText(
        'Message ${i + 1}: the quick brown fox jumps over the lazy dog.',
      ),
    ),
  );
}

/// Pumps a transcript-like scroll area with a composer-height bottom inset
/// (via [KitBottomInset]) and [pill] laid over it through
/// [KitJumpPillLayer], settles, runs the G5 accessibility checks and
/// compares the whole window with `goldens/kit/<name>.png`.
Future<void> _pillGalleryShot(
  WidgetTester tester, {
  required String name,
  required Size size,
  required bool light,
  required KitJumpPill Function(BuildContext context) pill,
  Future<void> Function(WidgetTester tester)? then,
}) async {
  final own = light ? 'light' : 'dark';
  if (!name.endsWith('_$own')) {
    throw ArgumentError.value(name, 'name', 'must end in "_$own"');
  }
  final stem = name.substring(0, name.length - own.length - 1);
  // TEST-9: DPR 3.0, [size] in logical pixels.
  tester.view.physicalSize = size * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  final semantics = tester.ensureSemantics();
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  try {
    // The other theme first (checks only), then the shot's own theme —
    // G5 (kit_gallery.dart) checks every shot in both themes.
    for (final pass in [!light, light]) {
      late BuildContext outerContext;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: pass ? AppTheme.light() : AppTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (outer) {
                  outerContext = outer;
                  final tokens = KitTokens.of(outer);
                  return KitBottomInset.add(
                    extraBottom: tokens.navHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: KitJumpPillLayer(
                            pill: pill(outer),
                            child: _transcriptScene(outer),
                          ),
                        ),
                        _composerScene(outer),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (then != null) await then(tester);
      expect(tester.takeException(), isNull);
      await expectKitGalleryAccessible(
        tester,
        shot: '${stem}_${pass ? 'light' : 'dark'}',
        direction: Directionality.of(outerContext),
      );
    }
  } finally {
    debugDefaultTargetPlatformOverride = null;
    semantics.dispose();
  }
  await expectLater(find.byKey(boundary), matchesGoldenFile('$name.png'));
}

const _sizes = <Size>[Size(412, 915), Size(1280, 800)];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in _sizes) {
      testWidgets('kit_jump_pill default · ${kitGallerySize(size)} · $mode', (
        tester,
      ) async {
        await _pillGalleryShot(
          tester,
          name: kitGalleryName('kit_jump_pill_default', size, light: light),
          size: size,
          light: light,
          pill: (context) => KitJumpPill(
            label: KitJumpPill.latestLabel(context, newCount: 3),
            onPressed: () {},
            visible: true,
          ),
        );
      });

      testWidgets('kit_jump_pill older · ${kitGallerySize(size)} · $mode', (
        tester,
      ) async {
        await _pillGalleryShot(
          tester,
          name: kitGalleryName('kit_jump_pill_older', size, light: light),
          size: size,
          light: light,
          // A plain literal, not an ARB key: no host names one yet (R14 —
          // no screen migrates onto this part in this unit), and a
          // gallery's own scene text is test code, outside the l10n
          // ratchet's scanned roots (lib/ui, lib/voice, lib/main.dart).
          pill: (context) => KitJumpPill.older(
            label: 'Earlier messages',
            onPressed: () {},
            visible: true,
          ),
        );
      });

      testWidgets('kit_jump_pill focused · ${kitGallerySize(size)} · $mode', (
        tester,
      ) async {
        await _pillGalleryShot(
          tester,
          name: kitGalleryName('kit_jump_pill_focused', size, light: light),
          size: size,
          light: light,
          pill: (context) => KitJumpPill(
            label: KitJumpPill.latestLabel(context, newCount: 3),
            onPressed: () {},
            visible: true,
          ),
          then: (tester) async {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pump();
          },
        );
      });
    }
  }
}
