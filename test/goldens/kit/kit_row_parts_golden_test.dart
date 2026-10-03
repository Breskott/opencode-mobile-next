// Gallery (gate G4) for KitRowParts v2: KitRowMenu, KitSwitchRow and
// KitExpandRow, docs/ux-system/kit-api/KitRowParts.md.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_row_parts_golden_test.dart
// and look at every changed image before committing it.
//
// Owner decision 2026-09-27 (dated later than KitRowParts.md, R15): Arabic
// is dropped and galleries are phone 412x915 plus one wide size 1280x800,
// light and dark. Every state renders at 412x915; each widget's default
// renders at 1280x800. This replaces the spec's 74-PNG list (and its
// Open question 2 on the 60-PNG cap): 26 PNGs.
//
// The risky switch's "on" condition is contributed through
// KitStatusContribution; the status line itself is not drawn here because
// no host can yet place a KitStatusLineSlot above its body (see the unit's
// QA record), so `risk_on` shows the row's own supporting line.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_row.dart';
import 'package:opencode_mobile/ui/kit/kit_row_parts.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import 'kit_gallery.dart';

Future<void> _shot(
  WidgetTester tester, {
  required String name,
  required Size size,
  required bool light,
  required List<Widget> Function(BuildContext context) rows,
  Future<void> Function(WidgetTester tester)? then,
}) async {
  final own = light ? 'light' : 'dark';
  final stem = name.substring(0, name.length - own.length - 1);
  tester.view.physicalSize = size * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  final semantics = tester.ensureSemantics();
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  try {
    for (final pass in [!light, light]) {
      late BuildContext outer;
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
                builder: (context) {
                  outer = context;
                  final tokens = KitTokens.of(context);
                  return ListView(
                    padding: EdgeInsetsDirectional.all(tokens.gutter),
                    children: [KitRowGroup(children: rows(context))],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (then != null) {
        await then(tester);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await expectKitGalleryAccessible(
        tester,
        shot: '${stem}_${pass ? 'light' : 'dark'}',
        direction: Directionality.of(outer),
      );
    }
  } finally {
    debugDefaultTargetPlatformOverride = null;
    semantics.dispose();
  }
  await expectLater(find.byKey(boundary), matchesGoldenFile('$name.png'));
}

List<Widget> _menuRows(BuildContext context) => [
  KitRow(
    title: 'Conversation',
    leading: KitRow.icon(context, AppIconography.chat),
    trailing: KitRowMenu(
      menuLabel: 'Conversation actions',
      items: [
        KitMenuItem(label: 'Rename', onSelected: () {}),
        KitMenuItem(label: 'Share', onSelected: () {}),
        KitMenuItem(label: 'Delete', destructive: true, onSelected: () {}),
      ],
    ),
  ),
];

KitRisk _risk({KitUntil? current}) => KitRisk(
  scope: 'Every conversation on this server',
  onLabel: 'Auto-approve is on',
  icon: AppIconography.check,
  until: const [KitUntil.off, KitUntil.conversation, KitUntil.hour],
  current: current,
  onUntil: (_) {},
);

Map<String, List<Widget> Function(BuildContext)> _switchScenes() => {
  'off': (_) => [
    KitSwitchRow(
      title: 'Sounds',
      supporting: 'Play a sound when a reply arrives',
      value: false,
      onChanged: (_) {},
    ),
  ],
  'on': (_) => [
    KitSwitchRow(
      title: 'Sounds',
      supporting: 'Play a sound when a reply arrives',
      value: true,
      onChanged: (_) {},
    ),
  ],
  'disabled': (_) => [
    const KitSwitchRow(
      title: 'Sounds',
      value: false,
      onChanged: null,
      disabledReason: 'Turn on notifications first',
    ),
  ],
  'risk_step': (_) => [
    KitSwitchRow(
      title: 'Approve everything',
      supporting: 'Tools run without asking',
      value: false,
      onChanged: (_) {},
      risk: _risk(),
    ),
  ],
  'risk_on': (_) => [
    KitSwitchRow(
      title: 'Approve everything',
      value: true,
      onChanged: (_) {},
      risk: _risk(current: KitUntil.hour),
    ),
  ],
  'locked': (_) => [
    KitSwitchRow(
      title: 'Core tools',
      supporting: 'Read, edit and run commands',
      value: true,
      onChanged: null,
      locked: 'Always included',
    ),
  ],
  'default': (_) => [
    KitSwitchRow(title: 'Sounds', value: false, onChanged: (_) {}),
    KitSwitchRow(title: 'Vibrate', value: true, onChanged: (_) {}),
  ],
};

List<Widget> _expandRows(BuildContext context, {required bool open}) => [
  KitExpandRow(
    title: 'Built-in plugins',
    supporting: const TextSpan(text: '3 plugins, all on'),
    leading: KitRow.icon(context, AppIconography.more),
    expanded: open,
    onExpansionChanged: (_) {},
    children: const [
      KitRow(title: 'Formatter'),
      KitRow(title: 'Linter'),
      KitRow(title: 'Git'),
    ],
  ),
];

Future<void> _tapFind(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);
  const phone = Size(412, 915);
  const wide = Size(1280, 800);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    group('KitRowMenu', () {
      for (final size in [phone, wide]) {
        testWidgets('kit_row_menu default · ${kitGallerySize(size)} · $mode', (
          tester,
        ) async {
          await _shot(
            tester,
            name: kitGalleryName('kit_row_menu_default', size, light: light),
            size: size,
            light: light,
            rows: _menuRows,
          );
        });
      }
      testWidgets('kit_row_menu open · $mode', (tester) async {
        await _shot(
          tester,
          name: kitGalleryName('kit_row_menu_open', phone, light: light),
          size: phone,
          light: light,
          rows: _menuRows,
          then: (tester) => _tapFind(
            tester,
            find.byKey(const ValueKey('kit-row-menu-button')),
          ),
        );
      });
    });

    group('KitSwitchRow', () {
      for (final entry in _switchScenes().entries) {
        final sizes = entry.key == 'default' ? [wide] : [phone];
        for (final size in sizes) {
          testWidgets(
            'kit_switch_row ${entry.key} · ${kitGallerySize(size)} · $mode',
            (tester) async {
              await _shot(
                tester,
                name: kitGalleryName(
                  'kit_switch_row_${entry.key}',
                  size,
                  light: light,
                ),
                size: size,
                light: light,
                rows: entry.value,
                then: entry.key == 'risk_step'
                    ? (tester) =>
                          _tapFind(tester, find.text('Approve everything'))
                    : null,
              );
            },
          );
        }
      }
    });

    group('KitExpandRow', () {
      testWidgets('kit_expand_row folded · $mode', (tester) async {
        await _shot(
          tester,
          name: kitGalleryName('kit_expand_row_folded', phone, light: light),
          size: phone,
          light: light,
          rows: (context) => _expandRows(context, open: false),
        );
      });
      for (final size in [phone, wide]) {
        testWidgets('kit_expand_row open · ${kitGallerySize(size)} · $mode', (
          tester,
        ) async {
          await _shot(
            tester,
            name: kitGalleryName('kit_expand_row_open', size, light: light),
            size: size,
            light: light,
            rows: (context) => _expandRows(context, open: true),
          );
        });
      }
    });
  }
}
