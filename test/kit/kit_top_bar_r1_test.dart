// Unit slice-R1 (docs/ux-system/revamp/leftover-units.json): KitTopBar sits
// flat on the gutter, and KitShellControls never cuts the server name in
// the PC sidebar. Behaviour first, then the unit's own gallery shots
// (owner 2026-09-27: phone 412x915 and 1280x800, light and dark).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/glass/kit_glass.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_divider.dart';
import 'package:opencode_mobile/ui/kit/kit_row.dart';
import 'package:opencode_mobile/ui/kit/kit_top_bar.dart';

import '../goldens/kit/kit_gallery.dart';

void _noop() {}

const _longServer = 'Build server in the basement closet';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(412, 915),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
  // The reconnecting mark turns forever, so no pumpAndSettle.
  await tester.pump(const Duration(milliseconds: 500));
}

/// The bar over the page's first content row.
Widget _screen(Widget bar) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    bar,
    const KitRow(
      title: 'Fix the login redirect',
      supporting: TextSpan(text: 'Working · 2 min'),
    ),
    const Expanded(child: SizedBox()),
  ],
);

Widget _sidebar({
  String status = 'Connected',
  AppStatusTone tone = AppStatusTone.ok,
  int needsYou = 0,
}) => Align(
  alignment: AlignmentDirectional.topStart,
  child: SizedBox(
    width: 296,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: KitShellControls(
        server: _longServer,
        serverStatus: status,
        serverTone: tone,
        onServer: _noop,
        needsYou: needsYou,
        project: 'shopfront',
        onProject: _noop,
        onSearch: _noop,
        layout: KitShellControlsLayout.sidebar,
      ),
    ),
  ),
);

double _x(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dx;

void main() {
  group('KitTopBar on the gutter', () {
    testWidgets('no exit: the title starts at the gutter, like the first '
        'content row', (tester) async {
      await _pump(
        tester,
        _screen(const KitTopBar(title: 'Fix login', exit: KitTopBarExit.none)),
      );
      expect(_x(tester, 'Fix login'), 16);
      expect(_x(tester, 'Fix login'), _x(tester, 'Fix the login redirect'));
    });

    testWidgets('a switcher title starts at the gutter too', (tester) async {
      await _pump(
        tester,
        _screen(
          const KitTopBar(
            title: 'shopfront',
            onTitleTap: _noop,
            titleTapLabel: 'Switch project',
            exit: KitTopBarExit.none,
          ),
        ),
      );
      expect(_x(tester, 'shopfront'), 16);
    });

    testWidgets('1280x800: the toolbar is flat on the ground with a hairline '
        'below, no glass', (tester) async {
      await _pump(
        tester,
        _screen(
          KitTopBar(
            title: 'Fix login',
            exit: KitTopBarExit.none,
            actions: [
              KitAction(
                label: 'Stop task',
                icon: AppIcons.stop,
                onPressed: () {},
              ),
            ],
          ),
        ),
        size: const Size(1280, 800),
      );
      final bar = find.byType(KitTopBar);
      expect(
        find.descendant(of: bar, matching: find.byType(KitGlass)),
        findsNothing,
      );
      final divider = find.descendant(
        of: bar,
        matching: find.byType(KitDivider),
      );
      expect(divider, findsOneWidget);
      expect(
        tester.getTopLeft(divider).dy,
        greaterThan(tester.getBottomLeft(find.text('Fix login')).dy),
      );
      expect(tester.getSize(divider).width, 1280);
      expect(_x(tester, 'Fix login'), 16);
      // The labelled action still shows on a PC.
      expect(find.text('Stop task'), findsOneWidget);
    });
  });

  group('KitShellControls sidebar (296 dp)', () {
    testWidgets('connected: the whole name shows, the word is left to the '
        'dot but stays in the label', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _sidebar(), size: const Size(1280, 800));
      final name = find.textContaining(_longServer);
      expect(name, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(name);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(find.textContaining('Connected'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('Connected, Switch server')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    for (final (word, tone) in [
      ('Offline', AppStatusTone.failure),
      ('Reconnecting', AppStatusTone.progress),
    ]) {
      testWidgets('$word: the word is on its own line under the name', (
        tester,
      ) async {
        await _pump(
          tester,
          _sidebar(status: word, tone: tone),
          size: const Size(1280, 800),
        );
        final name = find.textContaining(_longServer);
        expect(
          tester.renderObject<RenderParagraph>(name).didExceedMaxLines,
          isFalse,
        );
        expect(find.text(word), findsOneWidget);
        expect(
          tester.getTopLeft(find.text(word)).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(name).dy - 1),
        );
        expect(
          tester.getTopLeft(find.text(word)).dx,
          tester.getTopLeft(name).dx,
        );
      });
    }

    testWidgets('the bar layout keeps the word beside the name', (
      tester,
    ) async {
      await _pump(
        tester,
        KitTopBar.shell(
          controls: KitShellControls(
            server: 'Laptop',
            serverStatus: 'Connected',
            serverTone: AppStatusTone.ok,
            onServer: _noop,
          ),
        ),
      );
      expect(find.textContaining('Connected'), findsOneWidget);
    });
  });

  setUpAll(loadKitGalleryFonts);
  for (final light in [false, true]) {
    final theme = light ? 'light' : 'dark';
    testWidgets('kit_top_bar_r1_gutter 412x915 $theme', (tester) async {
      await kitGalleryPart(
        tester,
        name:
            'goldens/${kitGalleryName('kit_top_bar_r1_gutter', const Size(412, 915), light: light)}',
        size: const Size(412, 915),
        light: light,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KitTopBar(
              title: 'Work',
              exit: KitTopBarExit.none,
              actions: [
                KitAction(
                  label: 'New task',
                  icon: AppIconography.add,
                  onPressed: _noop,
                ),
              ],
            ),
            const KitRow(
              title: 'Fix the login redirect',
              supporting: TextSpan(text: 'Working · 2 min'),
            ),
            const KitRow(
              title: 'Update the docs',
              supporting: TextSpan(text: 'Done · yesterday'),
            ),
          ],
        ),
      );
    });

    testWidgets('kit_top_bar_r1_sidebar_296 1280x800 $theme', (tester) async {
      await kitGalleryPart(
        tester,
        name:
            'goldens/${kitGalleryName('kit_top_bar_r1_sidebar_296', const Size(1280, 800), light: light)}',
        size: const Size(1280, 800),
        light: light,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (status, tone) in [
              ('Connected', AppStatusTone.ok),
              ('Offline', AppStatusTone.failure),
            ])
              SizedBox(
                width: 296,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: KitShellControls(
                    server: _longServer,
                    serverStatus: status,
                    serverTone: tone,
                    onServer: _noop,
                    needsYou: tone == AppStatusTone.ok ? 1 : 0,
                    project: 'shopfront',
                    onProject: _noop,
                    onSearch: _noop,
                    layout: KitShellControlsLayout.sidebar,
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}
