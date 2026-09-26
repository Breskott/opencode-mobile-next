// KitIcon (docs/ux-system/kit-api/KitIcon.md, wave 1, tier 1a): the one
// way to draw a glyph. See lib/ui/kit/kit_icon.dart's header for the PROC-20
// contract problem this unit recorded (KitTokens.toneFor missing) and
// docs/qa/revamp-kit-KitIcon/README.md for the evidence.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_icon.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import 'kit_motion_still.dart';

Widget _host(
  Widget child, {
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
  bool highContrast = false,
}) => MaterialApp(
  theme: AppTheme.dark(),
  builder: (context, widget) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      highContrast: highContrast,
    ),
    child: widget!,
  ),
  home: Directionality(
    textDirection: direction,
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  kitMotionStillTests(
    'KitIcon',
    builds: {
      'small': () => const KitIcon(AppIconography.check),
      'status': () =>
          const KitIcon.status(AppIconography.info, AppStatusTone.attention),
      'duotone': () => const KitIcon(AppIconography.workspaceSelected),
      'growsWithText': () =>
          const KitIcon(AppIconography.check, growsWithText: true),
    },
  );

  group('sizes (VL §7, C02: s/m/l = 20/22/24)', () {
    testWidgets(
      'fixed sizes render at exactly 20, 22 and 24 logical px at text scale '
      '1.0 and 2.0',
      (tester) async {
        for (final scale in [1.0, 2.0]) {
          await tester.pumpWidget(
            _host(
              const Column(
                children: [
                  KitIcon(AppIconography.check, size: KitIconSize.small),
                  KitIcon(AppIconography.check, size: KitIconSize.medium),
                  KitIcon(AppIconography.check, size: KitIconSize.large),
                ],
              ),
              textScale: scale,
            ),
          );
          final sizes = tester
              .widgetList<Icon>(find.byType(Icon))
              .map((i) => i.size)
              .toList();
          expect(sizes, [20, 22, 24], reason: 'at text scale $scale');
        }
      },
    );

    testWidgets(
      'growsWithText scales up to 1.5x and rounds to a whole physical pixel',
      (tester) async {
        for (final dpr in [2.625, 3.0]) {
          tester.view.devicePixelRatio = dpr;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            _host(
              const KitIcon(
                AppIconography.check,
                size: KitIconSize.large,
                growsWithText: true,
              ),
              textScale: 2.0,
            ),
          );
          final size = tester.widget<Icon>(find.byType(Icon)).size!;
          // min(24 * 2, 24 * 1.5) = 36, then rounded to a whole physical
          // pixel at this DPR.
          final expected = (36 * dpr).roundToDouble() / dpr;
          expect(size, closeTo(expected, 1e-9), reason: 'at dpr $dpr');
          final physical = size * dpr;
          expect(
            physical,
            closeTo(physical.roundToDouble(), 1e-6),
            reason: 'size * dpr must be a whole physical pixel at dpr $dpr',
          );
        }
      },
    );
  });

  group('the app icon set (KitIcon.md "Replaces")', () {
    testWidgets(
      'the debug assert rejects Icons.add and passes AppIconography.add '
      'and AppIcons.copy',
      (tester) async {
        await tester.pumpWidget(_host(const KitIcon(Icons.add)));
        expect(tester.takeException(), isAssertionError);

        await tester.pumpWidget(_host(const KitIcon(AppIconography.add)));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(_host(const KitIcon(AppIcons.copy)));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('accessibility (A11Y-1)', () {
    testWidgets('decorative by default; semanticsLabel gives one image node', (
      tester,
    ) async {
      // Explicit dispose, not addTearDown: package:test runs tearDowns after
      // the flutter_test binding's own end-of-test invariant check, which
      // would still see the handle as active.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const KitIcon(AppIconography.check)));
      expect(find.bySemanticsLabel('Offline'), findsNothing);

      await tester.pumpWidget(
        _host(
          const KitIcon(AppIconography.cloudOff, semanticsLabel: 'Offline'),
        ),
      );
      expect(find.bySemanticsLabel('Offline'), findsOneWidget);
      handle.dispose();
    });
  });

  group('KitIcon.status (README.md decision D12)', () {
    testWidgets(
      'maps each AppStatusTone to the tone the spec names; failure is not '
      'danger and attention is not the attention role',
      (tester) async {
        final theme = AppTheme.dark();
        final roles = ThemeRoles.resolve(theme);
        final expected = <AppStatusTone, Color>{
          AppStatusTone.neutral: roles.text2,
          AppStatusTone.progress: roles.accent,
          AppStatusTone.ok: roles.success,
          AppStatusTone.attention: roles.text1,
          AppStatusTone.failure: roles.text1,
        };
        for (final status in AppStatusTone.values) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Center(child: KitIcon.status(AppIconography.info, status)),
            ),
          );
          final color = tester.widget<Icon>(find.byType(Icon)).color;
          expect(color, expected[status], reason: '$status');
        }
        expect(expected[AppStatusTone.failure], isNot(roles.danger));
        expect(expected[AppStatusTone.attention], isNot(roles.attention));
      },
    );

    testWidgets('defaults to small and grows with text', (tester) async {
      await tester.pumpWidget(
        _host(
          const KitIcon.status(AppIconography.info, AppStatusTone.ok),
          textScale: 2.0,
        ),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.size, greaterThan(20));
      expect(icon.size, lessThanOrEqualTo(20 * 1.5));
    });
  });

  group('RTL (LAY-8)', () {
    testWidgets(
      'AppIconography.back mirrors under RTL; AppIconography.check does not',
      (tester) async {
        await tester.pumpWidget(
          _host(
            const Column(
              children: [
                KitIcon(AppIconography.back),
                KitIcon(AppIconography.check),
              ],
            ),
            direction: TextDirection.rtl,
          ),
        );
        Finder iconFinder(IconData data) =>
            find.byWidgetPredicate((w) => w is Icon && w.icon == data);
        // The mirroring Transform (a horizontal flip) is inside Icon's own
        // build output, so it is a descendant of the Icon widget, not an
        // ancestor; Icon emits no Transform at all when it does not mirror.
        bool flipped(Finder of) => find
            .descendant(of: of, matching: find.byType(Transform))
            .evaluate()
            .map((e) => e.widget as Transform)
            .any((t) => t.transform.getColumn(0).x < 0);
        expect(flipped(iconFinder(AppIconography.back)), isTrue);
        expect(flipped(iconFinder(AppIconography.check)), isFalse);
      },
    );
  });

  group('duotone (LOOK-33: the dock/rail selected glyph only)', () {
    testWidgets('draws two layers, one under high contrast', (tester) async {
      await tester.pumpWidget(
        _host(const KitIcon(AppIconography.workspaceSelected)),
      );
      expect(find.byType(Icon), findsNWidgets(2));
      // The tree also carries unrelated Opacity widgets (Material's own
      // scaffolding), so the wash is found by its value, not by count.
      Finder wash() => find.byWidgetPredicate(
        (w) => w is Opacity && w.opacity == KitTokens.duotoneWash,
      );
      expect(wash(), findsOneWidget);

      await tester.pumpWidget(
        _host(
          const KitIcon(AppIconography.workspaceSelected),
          highContrast: true,
        ),
      );
      expect(find.byType(Icon), findsOneWidget);
      expect(wash(), findsNothing);
    });

    testWidgets('a non-duotone glyph draws one layer', (tester) async {
      await tester.pumpWidget(_host(const KitIcon(AppIconography.check)));
      expect(find.byType(Icon), findsOneWidget);
    });
  });

  group('tone colours (§7: no text or icon at partial opacity)', () {
    testWidgets('every KitTextTone colour is fully opaque', (tester) async {
      final roles = ThemeRoles.resolve(AppTheme.dark());
      for (final tone in KitTextTone.values) {
        expect(KitText.toneColor(roles, tone).a, 1.0, reason: '$tone');
      }
    });

    testWidgets('an explicit tone overrides the ambient icon colour', (
      tester,
    ) async {
      final theme = AppTheme.dark();
      final roles = ThemeRoles.resolve(theme);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Center(
            child: IconTheme(
              data: IconThemeData(color: roles.danger),
              child: const KitIcon(
                AppIconography.check,
                tone: KitTextTone.accent,
              ),
            ),
          ),
        ),
      );
      expect(tester.widget<Icon>(find.byType(Icon)).color, roles.accent);
    });

    testWidgets('a null tone takes the ambient icon colour, else text1', (
      tester,
    ) async {
      final theme = AppTheme.dark();
      final roles = ThemeRoles.resolve(theme);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Center(
            child: IconTheme(
              data: IconThemeData(color: roles.danger),
              child: const KitIcon(AppIconography.check),
            ),
          ),
        ),
      );
      expect(tester.widget<Icon>(find.byType(Icon)).color, roles.danger);

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Center(child: const KitIcon(AppIconography.check)),
        ),
      );
      expect(tester.widget<Icon>(find.byType(Icon)).color, roles.text1);
    });
  });

  group(
    'AppGlyph and AppBrandMark (KIT-43: moved, re-exported, unchanged)',
    () {
      testWidgets(
        'AppGlyph still builds from app_iconography.dart with its old '
        'parameters',
        (tester) async {
          await tester.pumpWidget(
            _host(
              const AppGlyph(
                AppIconography.check,
                size: 18,
                color: Color(0xFF00FF00),
                semanticLabel: 'Done',
              ),
            ),
          );
          final icon = tester.widget<Icon>(find.byType(Icon));
          expect(icon.size, 18);
          expect(icon.color, const Color(0xFF00FF00));
          expect(find.bySemanticsLabel('Done'), findsOneWidget);
        },
      );

      testWidgets('AppBrandMark still builds from app_iconography.dart', (
        tester,
      ) async {
        await tester.pumpWidget(_host(const AppBrandMark(size: 40)));
        expect(find.byType(AppBrandMark), findsOneWidget);
      });
    },
  );

  group('KitBrandMark', () {
    testWidgets('renders at the tile size (KitTokens.iconTileSize, 30)', (
      tester,
    ) async {
      final theme = AppTheme.dark();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Center(child: KitBrandMark()),
        ),
      );
      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      final tokens = KitTokens.fallback(theme);
      expect(tokens.iconTileSize, 30);
      expect(tokens.markSize, 44);
      expect(picture.width, tokens.iconTileSize);
    });

    testWidgets('renders at the mark size (KitTokens.markSize, 44)', (
      tester,
    ) async {
      final theme = AppTheme.dark();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Center(child: KitBrandMark(size: KitBrandMarkSize.mark)),
        ),
      );
      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(picture.width, KitTokens.fallback(theme).markSize);
    });

    testWidgets('is decorative by default; a label gives one image node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const KitBrandMark(semanticsLabel: 'Open Portal')),
      );
      expect(find.bySemanticsLabel('Open Portal'), findsOneWidget);
      handle.dispose();
    });
  });
}
