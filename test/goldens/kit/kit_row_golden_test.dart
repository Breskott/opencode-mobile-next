// Gallery (gate G4) for kit-KitRow-v2 (docs/ux-system/kit-api/KitRow.md and
// KitSwipeAction.md "Galleries required"): KitRow inside a labelled
// KitRowGroup with KitRowValue, each declared state, and KitSwipeAction's
// revealing and acted states.
//
// Reduced from the frozen specs' size matrix by the owner decision of
// 2026-09-27 (R15: later owner decisions win): Arabic/RTL and 2.0-text
// galleries are dropped, and the gallery is phone (412x915) and one wide
// size (1280x800), light and dark, only. See
// docs/qa/revamp-kit-KitRow-v2-2026-09-27/README.md.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_row_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/ui/app_iconography.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_menu.dart';
import 'package:opencode_mobile/ui/kit/kit_row.dart';
import 'package:opencode_mobile/ui/kit/kit_row_parts.dart' show KitChevron;
import 'package:opencode_mobile/ui/kit/kit_swipe_action.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';
import 'package:opencode_mobile/ui/kit/kit_undo.dart';

import '../../../tool/capture/fixtures.dart' show captureTheme;
import 'kit_gallery.dart';

enum _State { defaults, disabled, unavailable, server, selected, destructive }

String _stateName(_State state) =>
    state == _State.defaults ? 'default' : state.name;

List<KitMenuItem> _menu() => [
  KitMenuItem(label: 'Rename', icon: AppIconography.edit, onSelected: () {}),
  KitMenuItem(
    label: 'Delete conversation',
    icon: AppIconography.delete,
    destructive: true,
    onSelected: () {},
  ),
];

KitSwipeAction _swipe() => KitSwipeAction(
  id: const ValueKey('session-dismiss-fix-login'),
  label: 'Archive',
  icon: AppIconography.archive,
  onAct: () async => true,
  undoMessage: "Archived 'Fix the login bug'",
  onUndo: () {},
);

/// The shared rows of the default scene: one-line with a value and
/// chevron, two-line with a supporting line, and a plain chevron row.
List<Widget> _defaultRows(
  BuildContext context, {
  List<KitMenuItem> menu = const [],
  KitSwipeAction? swipe,
}) => [
  KitRow(
    title: 'Fix the login bug',
    leading: KitRow.icon(context, AppIconography.chat),
    supporting: const TextSpan(text: 'Finished 5h ago'),
    onTap: () {},
    menu: menu,
    swipe: swipe,
  ),
  KitRow(
    title: 'Model',
    leading: KitRow.icon(context, AppIconography.model),
    trailing: const KitRowValue('Claude Sonnet 4'),
    onTap: () {},
  ),
  KitRow(
    title: 'Project settings',
    leading: KitRow.icon(context, AppIconography.settings),
    trailing: const KitChevron(),
    onTap: () {},
  ),
];

Widget _scene(_State state) => Builder(
  builder: (context) {
    final icon = KitRow.icon;
    final List<Widget> rows = switch (state) {
      _State.defaults => _defaultRows(context),
      _State.disabled => [
        KitRow(
          title: 'Run tests',
          leading: icon(context, AppIconography.terminal),
          onTap: () {},
          enabled: false,
          disabledReason: 'Needs a connection to the server',
        ),
        KitRow(
          title: 'Open terminal',
          leading: icon(context, AppIconography.terminal),
          onTap: () {},
        ),
      ],
      _State.unavailable => [
        KitRow.unavailable(
          title: 'Voice input',
          leading: icon(context, AppIconography.mic),
          reason: 'Voice needs a model on this phone.',
          capability: 'voice.model',
          enable: KitAction(label: 'Download', onPressed: () {}),
        ),
        KitRow.unavailable(
          title: 'Sub-agents',
          leading: icon(context, AppIconography.agent),
          reason: 'Available on OpenCode 2 servers.',
        ),
      ],
      _State.server => [
        KitRow(
          title: 'Fix the login bug',
          leading: icon(context, AppIconography.chat),
          server: 'laptop',
          supporting: const TextSpan(text: 'Needs you'),
          onTap: () {},
        ),
        KitRow(
          title: 'Write release notes',
          leading: icon(context, AppIconography.chat),
          server: 'phone',
          supporting: const TextSpan(text: 'Finished 2m ago'),
          onTap: () {},
        ),
      ],
      _State.selected => [
        KitRow(
          title: 'Fix the login bug',
          leading: icon(context, AppIconography.chat),
          supporting: const TextSpan(text: 'Open · Finished 5h ago'),
          selected: true,
          onTap: () {},
        ),
        KitRow(
          title: 'Write release notes',
          leading: icon(context, AppIconography.chat),
          supporting: const TextSpan(text: 'Finished 2m ago'),
          onTap: () {},
        ),
      ],
      _State.destructive => [
        // Passed first; KitRowGroup renders it last, behind the divider.
        KitRow(
          title: 'Delete conversation',
          leading: icon(
            context,
            AppIconography.delete,
            color: KitTokens.of(context).roles.danger,
          ),
          destructive: true,
          onTap: () {},
        ),
        KitRow(
          title: 'Rename',
          leading: icon(context, AppIconography.edit),
          onTap: () {},
        ),
        KitRow(
          title: 'Share',
          leading: icon(context, AppIconography.link),
          onTap: () {},
        ),
      ],
    };
    return KitRowGroup(label: 'Conversations', children: rows);
  },
);

/// The interactive states kitGalleryPart has no hook for (hover, focus, an
/// open menu, a held swipe, the undo line), shot the way
/// kit_tappable_golden_test.dart does: pump, act, settle, the same G5
/// scan, compare.
Future<void> _interactiveShot(
  WidgetTester tester, {
  required String name,
  required bool light,
  required Widget scene,
  required Future<void> Function(WidgetTester tester) act,
  Size size = const Size(412, 915),
  bool desktop = false,
}) async {
  tester.view.physicalSize = size * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  final semantics = tester.ensureSemantics();
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  if (desktop) {
    debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
  }
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
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: scene,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await act(tester);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectKitGalleryAccessible(
      tester,
      shot: name,
      direction: TextDirection.ltr,
    );
  } finally {
    debugDefaultTargetPlatformOverride = null;
    debugPlatformCapabilities = null;
    semantics.dispose();
  }
  await expectLater(find.byKey(boundary), matchesGoldenFile('$name.png'));
}

Widget _defaultWith({
  List<KitMenuItem> menu = const [],
  KitSwipeAction? swipe,
}) => Builder(
  builder: (context) => KitRowGroup(
    label: 'Conversations',
    children: _defaultRows(context, menu: menu, swipe: swipe),
  ),
);

/// Holds the first row mid-swipe at about 60 % of its width.
Future<void> _holdSwipe(WidgetTester tester) async {
  final row = find.text('Fix the login bug');
  final width = tester.getSize(find.byType(KitRow).first).width;
  final gesture = await tester.startGesture(tester.getCenter(row));
  addTearDown(gesture.up);
  await gesture.moveBy(const Offset(-20, 0));
  await tester.pump();
  await gesture.moveBy(Offset(-width * 0.6 + 20, 0));
  await tester.pump();
}

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final state in _State.values) {
      testWidgets('kit_row ${_stateName(state)} · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_row_${_stateName(state)}',
            const Size(412, 915),
            light: light,
          ),
          size: const Size(412, 915),
          light: light,
          child: _scene(state),
        );
      });
    }

    testWidgets('kit_row default · 1280x800 · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_row_default',
          const Size(1280, 800),
          light: light,
        ),
        size: const Size(1280, 800),
        light: light,
        child: _scene(_State.defaults),
      );
    });

    testWidgets('kit_row hover · $mode', (tester) async {
      await _interactiveShot(
        tester,
        name: kitGalleryName(
          'kit_row_hover',
          const Size(412, 915),
          light: light,
        ),
        light: light,
        desktop: true,
        scene: _defaultWith(),
        act: (tester) async {
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          addTearDown(mouse.removePointer);
          await mouse.moveTo(tester.getCenter(find.text('Model')));
        },
      );
    });

    testWidgets('kit_row focused · $mode', (tester) async {
      await _interactiveShot(
        tester,
        name: kitGalleryName(
          'kit_row_focused',
          const Size(412, 915),
          light: light,
        ),
        light: light,
        scene: _defaultWith(),
        act: (tester) async {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        },
      );
    });

    testWidgets('kit_row context_menu · $mode', (tester) async {
      await _interactiveShot(
        tester,
        name: kitGalleryName(
          'kit_row_context_menu',
          const Size(412, 915),
          light: light,
        ),
        light: light,
        scene: _defaultWith(menu: _menu(), swipe: _swipe()),
        act: (tester) async {
          await tester.longPress(find.text('Fix the login bug'));
        },
      );
    });

    for (final size in const [Size(412, 915), Size(1280, 800)]) {
      testWidgets(
        'kit_swipe_action revealing · ${kitGallerySize(size)} · $mode',
        (tester) async {
          await _interactiveShot(
            tester,
            name: kitGalleryName(
              'kit_swipe_action_revealing',
              size,
              light: light,
            ),
            light: light,
            size: size,
            scene: _defaultWith(swipe: _swipe()),
            act: _holdSwipe,
          );
        },
      );
    }

    testWidgets('kit_swipe_action acted · $mode', (tester) async {
      await _interactiveShot(
        tester,
        name: kitGalleryName(
          'kit_swipe_action_acted',
          const Size(412, 915),
          light: light,
        ),
        light: light,
        scene: _defaultWith(swipe: _swipe()),
        act: (tester) async {
          await tester.drag(
            find.text('Fix the login bug'),
            const Offset(-400, 0),
          );
        },
      );
      // Closes the undo window so no timer outlives the test.
      KitUndo.commitPending();
      await tester.pumpAndSettle();
    });
  }
}
