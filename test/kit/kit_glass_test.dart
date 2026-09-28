// Behaviour tests for fluid glass (docs/ux-system/kit-api/KitGlass.md; the
// owner's approved "Fluid glass" sample): the glass gives under a finger,
// follows its content's new size, the shell's pill and search join while
// the page is scrolled, and the dock's lens stretches, lifts under a drag
// and settles. Reduced motion makes every state instant, glass off keeps
// the solid fallback still, and the motion costs no rebuilds per frame.
//
// The looks themselves (liquid, frosted, solid, rim, shadow) are covered by
// test/kit_glass_test.dart; this file runs the frosted look (flutter_tester
// is Skia), whose drawn shape is the same one the liquid shader reads.
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/glass/glass_geometry.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

const _off = KitEffects(glass: false);

// One theme for every pump: a new ThemeData would animate the theme.
final _theme = AppTheme.dark();
const _still = KitEffects(motion: KitMotionLevel.off);

Widget _app(Widget child, {KitEffects effects = KitEffects.defaults}) =>
    KitEffectsScope(
      effects: effects,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

/// The drawn shape of the glass [of] (its clip), in its box's coordinates.
RRect _drawn(WidgetTester tester, Finder of) {
  final clip = tester.widget<ClipRRect>(
    find
        .descendant(
          of: of,
          matching: find.byWidgetPredicate((w) => w is ClipRRect),
        )
        .first,
  );
  final box = tester.getSize(of);
  return clip.clipper!.getClip(box);
}

Rect _box(WidgetTester tester, Finder of) => Offset.zero & tester.getSize(of);

void main() {
  setUp(() => KitGlassShader.debugSupportedOverride = false);
  tearDown(KitGlassShader.debugReset);

  group('press', () {
    const glass = Center(
      child: SizedBox(
        width: 200,
        height: 48,
        child: KitGlass(respond: true, child: Text('Laptop')),
      ),
    );
    final finder = find.byType(KitGlass);

    testWidgets('the glass swells under a finger and springs back', (
      tester,
    ) async {
      await tester.pumpWidget(_app(glass));
      expect(_drawn(tester, finder).outerRect, _box(tester, finder));
      final label = tester.getRect(find.text('Laptop'));
      final gesture = await tester.startGesture(tester.getCenter(finder));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final pressed = _drawn(tester, finder).outerRect;
      final box = _box(tester, finder);
      expect(pressed.left, lessThan(box.left));
      expect(pressed.right, greaterThan(box.right));
      expect(pressed.top, lessThan(box.top));
      // A few dp, never more than GlassGeometry.swellMax a side.
      expect(box.left - pressed.left, lessThanOrEqualTo(4.5));
      // The label is never scaled or moved: only the drawn glass swells.
      expect(tester.getRect(find.text('Laptop')), label);
      await gesture.up();
      await tester.pumpAndSettle();
      // Exactly the box again: crisp at rest.
      expect(_drawn(tester, finder).outerRect, box);
    });

    testWidgets('a finger lifted after the glass left the screen is ignored', (
      tester,
    ) async {
      await tester.pumpWidget(_app(glass));
      final gesture = await tester.startGesture(tester.getCenter(finder));
      await tester.pump(const Duration(milliseconds: 40));
      // The screen changes under the finger (a new page, a closed sheet).
      await tester.pumpWidget(_app(const SizedBox.shrink()));
      await gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a pair: a finger lifted after it left is ignored', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const Center(
            child: SizedBox(
              width: 300,
              child: KitGlass.pair(
                leading: SizedBox(width: 120, height: 48),
                trailing: SizedBox(width: 48, height: 48),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getTopLeft(find.byType(KitGlass)) + const Offset(60, 24),
      );
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpWidget(_app(const SizedBox.shrink()));
      await gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion: no swell, nothing ticks', (tester) async {
      await tester.pumpWidget(_app(glass, effects: _still));
      final gesture = await tester.startGesture(tester.getCenter(finder));
      await tester.pump(const Duration(milliseconds: 80));
      expect(_drawn(tester, finder).outerRect, _box(tester, finder));
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
      await gesture.up();
    });

    testWidgets('glass off stays a still solid surface with its hairline', (
      tester,
    ) async {
      await tester.pumpWidget(_app(glass, effects: _off));
      expect(
        KitGlass.lookOf(tester.element(find.text('Laptop'))),
        KitGlassLook.solid,
      );
      final gesture = await tester.startGesture(tester.getCenter(finder));
      await tester.pump(const Duration(milliseconds: 80));
      expect(_drawn(tester, finder).outerRect, _box(tester, finder));
      final solid = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: finder, matching: find.byType(DecoratedBox)),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((box) => box.border != null);
      expect(solid, hasLength(1));
      expect(solid.single.boxShadow ?? const [], isEmpty);
      await gesture.up();
    });
  });

  group('flow', () {
    Widget host(double height, {KitEffects effects = KitEffects.defaults}) =>
        _app(
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 320,
              child: KitGlass(
                flow: true,
                child: SizedBox(height: height, child: const Text('Draft')),
              ),
            ),
          ),
          effects: effects,
        );
    final finder = find.byType(KitGlass);

    testWidgets('growing content: the glass flows up from the old size', (
      tester,
    ) async {
      await tester.pumpWidget(host(48));
      await tester.pumpWidget(host(88));
      // The content took its size at once; the glass starts where it was,
      // on the bottom edge, and flows up.
      final start = _drawn(tester, finder).outerRect;
      final box = _box(tester, finder);
      expect(box.height, 88);
      expect(start.height, closeTo(48, .5));
      expect(start.bottom, closeTo(box.bottom, .5));
      await tester.pump(const Duration(milliseconds: 60));
      final mid = _drawn(tester, finder).outerRect;
      expect(mid.height, greaterThan(start.height));
      expect(mid.height, lessThan(box.height + 2));
      await tester.pumpAndSettle();
      expect(_drawn(tester, finder).outerRect, box);
    });

    // The composer grows a row (a delivery choice, a confirm) at its top
    // edge: the row is laid out at once while the glass is still drawn at
    // the old size. The row must answer the very first tap.
    Widget growing({
      required bool grown,
      required VoidCallback onTap,
      KitEffects effects = KitEffects.defaults,
    }) => _app(
      Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: 320,
          child: KitGlass(
            flow: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (grown)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    child: const SizedBox(
                      height: 40,
                      width: double.infinity,
                      child: Text('Send now'),
                    ),
                  ),
                const SizedBox(height: 48, child: Text('Draft')),
              ],
            ),
          ),
        ),
      ),
      effects: effects,
    );

    testWidgets('a control that just appeared at the edge takes the first '
        'tap while the glass is still flowing', (tester) async {
      var taps = 0;
      void tap() => taps++;
      await tester.pumpWidget(growing(grown: false, onTap: tap));
      await tester.pumpWidget(growing(grown: true, onTap: tap));
      // First frame of the flow: the drawn glass is still the old 48 dp on
      // the bottom edge, so the new row is outside it...
      final drawn = _drawn(tester, finder).outerRect;
      final row = tester.getRect(find.text('Send now'));
      final glass = tester.getTopLeft(finder);
      expect(drawn.height, closeTo(48, .5));
      expect(drawn.shift(glass).contains(row.center), isFalse);
      expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0));
      // ...and still takes the tap.
      await tester.tap(find.text('Send now'));
      expect(taps, 1);
      // The visual keeps flowing to the box and settles exactly on it.
      await tester.pumpAndSettle();
      expect(_drawn(tester, finder).outerRect, _box(tester, finder));
      await tester.tap(find.text('Send now'));
      expect(taps, 2);
    });

    testWidgets('reduced motion: the new control and the glass are there '
        'in one pump', (tester) async {
      var taps = 0;
      void tap() => taps++;
      await tester.pumpWidget(
        growing(grown: false, onTap: tap, effects: _still),
      );
      await tester.pumpWidget(
        growing(grown: true, onTap: tap, effects: _still),
      );
      expect(_drawn(tester, finder).outerRect, _box(tester, finder));
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
      await tester.tap(find.text('Send now'));
      expect(taps, 1);
    });

    testWidgets('reduced motion: the glass takes the new size at once', (
      tester,
    ) async {
      await tester.pumpWidget(host(48, effects: _still));
      await tester.pumpWidget(host(88, effects: _still));
      expect(_drawn(tester, finder).outerRect, _box(tester, finder));
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
    });
  });

  group('pair', () {
    var taps = 0;
    Widget pair({
      required bool joined,
      KitEffects effects = KitEffects.defaults,
    }) => _app(
      Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 360,
          child: KitGlass.pair(
            joined: joined,
            leading: const SizedBox(
              key: ValueKey('leading'),
              width: 140,
              height: 48,
              child: Center(child: Text('Laptop')),
            ),
            trailing: GestureDetector(
              onTap: () => taps++,
              child: const SizedBox(
                key: ValueKey('trailing'),
                width: 48,
                height: 48,
                child: Center(child: Text('Find')),
              ),
            ),
          ),
        ),
      ),
      effects: effects,
    );
    Rect trailing(WidgetTester tester) =>
        tester.getRect(find.byKey(const ValueKey('trailing')));
    Rect leading(WidgetTester tester) =>
        tester.getRect(find.byKey(const ValueKey('leading')));

    testWidgets('joined, the trailing piece slides next to the leading one', (
      tester,
    ) async {
      taps = 0;
      await tester.pumpWidget(pair(joined: false));
      final pairRect = tester.getRect(find.byType(KitGlass));
      final rest = trailing(tester);
      expect(rest.right, pairRect.right);
      await tester.pumpWidget(pair(joined: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final moving = trailing(tester);
      expect(moving.left, lessThan(rest.left));
      expect(moving.left, greaterThan(leading(tester).right));
      await tester.pumpAndSettle();
      final joined = trailing(tester);
      // Touching: the smaller drop's edge meets the leading piece.
      expect(joined.left, closeTo(leading(tester).right - 2, .01));
      // Still the same piece, and it still answers where it now is.
      expect(joined.size, rest.size);
      await tester.tap(find.text('Find'));
      expect(taps, 1);
      await tester.pumpWidget(pair(joined: false));
      await tester.pumpAndSettle();
      expect(trailing(tester), rest);
    });

    testWidgets('reduced motion: the pieces join and part at once', (
      tester,
    ) async {
      await tester.pumpWidget(pair(joined: false, effects: _still));
      await tester.pumpWidget(pair(joined: true, effects: _still));
      expect(trailing(tester).left, closeTo(leading(tester).right - 2, .01));
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
    });

    testWidgets('glass off: one solid outline, pieces still join', (
      tester,
    ) async {
      await tester.pumpWidget(pair(joined: false, effects: _off));
      await tester.pumpWidget(pair(joined: true, effects: _off));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);
      expect(trailing(tester).left, closeTo(leading(tester).right - 2, .01));
      expect(tester.takeException(), isNull);
    });
  });

  group('the shell', () {
    List<KitNavDestination> destinations() => const [
      KitNavDestination(
        label: 'Work',
        icon: AppIconography.workspace,
        key: ValueKey('nav-work'),
      ),
      KitNavDestination(
        label: 'Inbox',
        icon: AppIconography.activity,
        key: ValueKey('nav-inbox'),
      ),
      KitNavDestination(
        label: 'Project',
        icon: AppIconography.files,
        key: ValueKey('nav-project'),
      ),
      KitNavDestination(
        label: 'Settings',
        icon: AppIconography.settings,
        key: ValueKey('nav-settings'),
      ),
    ];

    Future<List<int>> shell(
      WidgetTester tester, {
      KitEffects effects = KitEffects.defaults,
      Size size = const Size(412, 915),
    }) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final selections = <int>[];
      var selected = 0;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => KitNav(
              destinations: destinations(),
              selected: selected,
              onSelected: (i) {
                selections.add(i);
                setState(() => selected = i);
              },
              child: Column(
                children: [
                  KitTopBar.shell(
                    controls: KitShellControls(
                      server: 'Laptop',
                      serverStatus: 'Connected',
                      onServer: () {},
                      onSearch: () {},
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      key: const ValueKey('list'),
                      itemCount: 60,
                      itemExtent: 56,
                      itemBuilder: (context, i) => Text('Row $i'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          effects: effects,
        ),
      );
      await tester.pumpAndSettle();
      return selections;
    }

    Finder search() => find.byTooltip('Search');
    Finder pill() => find.textContaining('Laptop', findRichText: true);

    testWidgets('scrolling joins search to the server pill; the top parts '
        'them', (tester) async {
      await shell(tester);
      final apart = tester.getRect(search());
      await tester.drag(
        find.byKey(const ValueKey('list')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      final joined = tester.getRect(search());
      expect(joined.left, lessThan(apart.left));
      // Next to the pill, not across it.
      expect(joined.left, greaterThan(tester.getRect(pill()).left));
      await tester.drag(
        find.byKey(const ValueKey('list')),
        const Offset(0, 600),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(search()), apart);
    });

    testWidgets('another tab starts apart again', (tester) async {
      await shell(tester);
      final apart = tester.getRect(search());
      await tester.drag(
        find.byKey(const ValueKey('list')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(search()), isNot(apart));
      await tester.tap(find.byKey(const ValueKey('nav-inbox')));
      await tester.pumpAndSettle();
      expect(tester.getRect(search()), apart);
    });

    Finder lens() => find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_KitNavLens',
    );

    testWidgets('a tap stretches the lens towards the tab, then it settles', (
      tester,
    ) async {
      await shell(tester);
      final rest = tester.getRect(lens());
      await tester.tap(find.byKey(const ValueKey('nav-settings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final moving = tester.getRect(lens());
      // The front edge leads: the lens is longer than at rest on the way.
      expect(moving.width, greaterThan(rest.width + 4));
      expect(moving.right - rest.right, greaterThan(moving.left - rest.left));
      await tester.pumpAndSettle();
      final settled = tester.getRect(lens());
      expect(settled.width, closeTo(rest.width, .001));
      expect(settled.height, closeTo(rest.height, .001));
      expect(
        settled.center.dx,
        greaterThan(
          tester.getCenter(find.byKey(const ValueKey('nav-project'))).dx,
        ),
      );
    });

    testWidgets('dragging along the dock lifts the lens and opens the tab it '
        'is let go on', (tester) async {
      final selections = await shell(tester);
      final rest = tester.getRect(lens());
      final from = tester.getCenter(find.byKey(const ValueKey('nav-work')));
      final to = tester.getCenter(find.byKey(const ValueKey('nav-project')));
      final gesture = await tester.startGesture(from);
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(Offset((to.dx - from.dx - 20) / 10, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final lifted = tester.getRect(lens());
      expect(lifted.height, greaterThan(rest.height));
      expect(lifted.center.dx, closeTo(to.dx, 12));
      expect(selections, isEmpty);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(selections, [2]);
      final settled = tester.getRect(lens());
      expect(settled.width, closeTo(rest.width, .001));
      expect(settled.height, closeTo(rest.height, .001));
      expect(settled.center.dx, closeTo(to.dx, 1));
    });

    testWidgets('reduced motion: the lens follows the finger without lifting '
        'and every state is instant', (tester) async {
      final selections = await shell(tester, effects: _still);
      final rest = tester.getRect(lens());
      final from = tester.getCenter(find.byKey(const ValueKey('nav-work')));
      final to = tester.getCenter(find.byKey(const ValueKey('nav-inbox')));
      final gesture = await tester.startGesture(from);
      await gesture.moveBy(const Offset(20, 0));
      await gesture.moveBy(Offset(to.dx - from.dx - 20, 0));
      await tester.pump();
      final dragged = tester.getRect(lens());
      expect(dragged.height, rest.height);
      expect(dragged.center.dx, closeTo(to.dx, 1));
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
      await gesture.up();
      await tester.pump();
      expect(selections, [1]);
      await tester.tap(find.byKey(const ValueKey('nav-settings')));
      await tester.pump();
      final settled = tester.getRect(lens());
      await tester.pumpAndSettle();
      expect(tester.getRect(lens()), settled);
    });

    testWidgets('the rail: a vertical drag opens the destination let go on', (
      tester,
    ) async {
      final selections = await shell(tester, size: const Size(700, 1000));
      final from = tester.getCenter(find.byKey(const ValueKey('nav-work')));
      final to = tester.getCenter(find.byKey(const ValueKey('nav-settings')));
      final gesture = await tester.startGesture(from);
      await gesture.moveBy(const Offset(0, 20));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(Offset(0, (to.dy - from.dy - 20) / 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(selections, [3]);
      expect(tester.getRect(lens()).center.dy, closeTo(to.dy, 14));
    });

    testWidgets('60 fps budget: the lens and a press rebuild no widget per '
        'frame and each frame stays well under 16 ms', (tester) async {
      await shell(tester);
      await tester.tap(find.byKey(const ValueKey('nav-settings')));
      // The tap's own frames (selection, pressed fill) rebuild; the spring
      // frames after them must not.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final gesture = await tester.startGesture(
        tester.getCenter(find.textContaining('Laptop', findRichText: true)),
      );
      await tester.pump();
      // KitTappable's own pressed fill (an AnimatedContainer) may rebuild
      // while it fades; no glass or navigation widget may.
      final rebuilt = <String>[];
      final previous = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) =>
          rebuilt.add(element.widget.runtimeType.toString());
      addTearDown(() => debugOnRebuildDirtyWidget = previous);
      final watch = Stopwatch();
      final frames = <int>[];
      for (var i = 0; i < 20; i++) {
        watch
          ..reset()
          ..start();
        await tester.pump(const Duration(milliseconds: 16));
        watch.stop();
        frames.add(watch.elapsedMicroseconds);
      }
      debugOnRebuildDirtyWidget = previous;
      const glassAndNav = {
        'KitGlass',
        '_KitGlassPair',
        '_GlassPairLayout',
        'KitNav',
        'KitNavBar',
        'KitNavRail',
        '_KitNavItems',
        '_KitNavItem',
        '_KitNavLens',
        'KitShellControls',
        'KitTopBar',
        'CustomSingleChildLayout',
        'LiquidGlassFilter',
        'BackdropFilter',
        'ClipRRect',
      };
      expect(
        rebuilt.where(glassAndNav.contains),
        isEmpty,
        reason: 'springs repaint or relayout the lens and glass only',
      );
      final mean = frames.reduce((a, b) => a + b) / frames.length;
      // Debug-mode build, layout and paint of the whole shell on the test
      // host (Skia, no GPU); a coarse guard that no frame does a rebuild's
      // or a shader compile's work. Printed for the QA record.
      debugPrint(
        'fluid glass frames: mean ${(mean / 1000).toStringAsFixed(2)} ms, '
        'max ${(frames.reduce((a, b) => a > b ? a : b) / 1000).toStringAsFixed(2)} ms',
      );
      expect(mean, lessThan(16000));
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  test('the press swell is a few dp and scales with small glass', () {
    const box = Rect.fromLTWH(0, 0, 48, 48);
    final swollen = GlassGeometry.swell(box, 1);
    expect(
      box.left - swollen.left,
      closeTo(48 * GlassGeometry.swellShare, .001),
    );
    final wide = GlassGeometry.swell(const Rect.fromLTWH(0, 0, 380, 60), 1);
    expect(-wide.left, GlassGeometry.swellMax);
    expect(-wide.top, lessThanOrEqualTo(GlassGeometry.swellMax / 2));
  });
}
