// KitTappable (docs/ux-system/kit-api/KitTappable.md): the frozen "Tests
// required" contract (12 items), the debug asserts (STATE-8, onLongPress vs
// menu), the reduced-motion sample (G8x, MOT-7) via kitMotionStillTests, and
// no HapticFeedback (MOT-11).
import 'dart:ui' as ui;
import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_menu.dart';
import 'package:opencode_mobile/ui/kit/kit_tappable.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import 'kit_harness.dart';
import 'kit_motion_still.dart';

const _shotKey = ValueKey('shot');

/// Pumps [child] as a screen's body at [size] (DPR 1, so logical and
/// physical pixels line up for [WidgetTester.tapAt] and the pixel probe),
/// wrapped in a [RepaintBoundary] so [_Shot.take] can read back what was
/// actually painted (the same technique as `kit_chip_test.dart`).
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool light = false,
  Size size = const Size(412, 915),
  // The pixel probe (test 7) needs a real surface behind the tappable: it
  // paints no fill itself when idle (the host is assumed to already paint
  // the surface it sits on), so idle pixels are otherwise the Scaffold's
  // plain ground colour, not `surface`.
  Color? background,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // The background must sit INSIDE the RepaintBoundary: `toImage()` only
  // captures what paints within its own bounds, so a background painted by
  // an ancestor of the boundary would never show up in the probe.
  final content = background == null
      ? child
      : ColoredBox(color: background, child: child);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: light ? AppTheme.light() : AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(key: _shotKey, child: content),
        ),
      ),
    ),
  );
}

/// The role colour [surface] resolves to in [light]'s theme, for the pixel
/// probe's background (see [_pump]'s `background`).
Color _surfaceColor(bool light, KitSurfaceLevel surface) => KitTokens.fallback(
  light ? AppTheme.light() : AppTheme.dark(),
).fillOf(surface);

/// What the window actually shows, read back as pixels (kit_chip_test.dart's
/// `_Shot`, copied here since tests only reuse shared, not sibling, files).
class _Shot {
  _Shot(this.origin, this.width, this.bytes);

  final Offset origin;
  final int width;
  final ByteData bytes;

  static Future<_Shot> take(WidgetTester tester) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_shotKey),
    );
    final origin = tester.getTopLeft(find.byKey(_shotKey));
    final data = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final width = image.width;
      image.dispose();
      return (bytes!, width);
    });
    return _Shot(origin, data!.$2, data.$1);
  }

  Color at(Offset global) {
    final p = global - origin;
    final i = (p.dy.floor() * width + p.dx.floor()) * 4;
    return Color.fromARGB(
      bytes.getUint8(i + 3),
      bytes.getUint8(i),
      bytes.getUint8(i + 1),
      bytes.getUint8(i + 2),
    );
  }
}

bool _near(Color a, Color b) =>
    ((a.r - b.r) * 255).abs() <= 2 &&
    ((a.g - b.g) * 255).abs() <= 2 &&
    ((a.b - b.b) * 255).abs() <= 2;

/// The custom semantics actions KitTappable's outer [Semantics] node
/// declares, by label.
Map<String, VoidCallback> _customActions(WidgetTester tester) {
  final semantics = tester
      .widgetList<Semantics>(
        find.descendant(
          of: find.byType(KitTappable),
          matching: find.byType(Semantics),
        ),
      )
      .first;
  final actions = semantics.properties.customSemanticsActions;
  if (actions == null) return const {};
  return {for (final e in actions.entries) e.key.label ?? '': e.value};
}

/// The focus ring is the only [CustomPaint] KitTappable ever builds.
Finder get _ring => find.descendant(
  of: find.byType(KitTappable),
  matching: find.byType(CustomPaint),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('disabled requires disabledReason (STATE-8, debug assert)', () {
    expect(
      () => KitTappable(onTap: null, child: const Text('Archive')),
      throwsAssertionError,
    );
    expect(
      () => KitTappable(
        onTap: null,
        disabledReason: 'Needs a connection',
        child: const Text('Archive'),
      ),
      returnsNormally,
    );
  });

  test('onLongPress cannot combine with a non-empty menu', () {
    expect(
      () => KitTappable(
        onTap: () {},
        onLongPress: () {},
        menu: [KitMenuItem(label: 'Archive', onSelected: () {})],
        child: const Text('Row'),
      ),
      throwsAssertionError,
    );
    expect(
      () => KitTappable(
        onTap: () {},
        onLongPress: () {},
        child: const Text('Row'),
      ),
      returnsNormally,
    );
  });

  testWidgets('1. a 20×20 child gets a 48×48 hit area', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      KitTappable(
        onTap: () => taps++,
        child: const SizedBox(width: 20, height: 20),
      ),
    );
    final box = tester.getRect(find.byType(KitTappable));
    expect(box.width, 48);
    expect(box.height, 48);
    // Inside the 48 box (0–48), outside the centred 20×20 child (14–34).
    await tester.tapAt(box.topLeft + const Offset(2, 2));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('2. Enter and Space fire once; key repeat does not refire', (
    tester,
  ) async {
    var taps = 0;
    final focusNode = FocusNode(debugLabel: 'under test');
    addTearDown(focusNode.dispose);
    await _pump(
      tester,
      KitTappable(
        onTap: () => taps++,
        focusNode: focusNode,
        child: const Text('Go'),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    expect(taps, 1, reason: 'Enter fires once');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    expect(taps, 2, reason: 'a held Enter (key repeat) does not fire again');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    expect(taps, 3, reason: 'Space fires once');
  });

  testWidgets('3. disabled: no Tab stop, no hover fill, basic cursor', (
    tester,
  ) async {
    // Disposed inline, not via addTearDown: the end-of-test leak check runs
    // before addTearDown callbacks.
    final handle = tester.ensureSemantics();
    final focusNode = FocusNode(debugLabel: 'under test');
    addTearDown(focusNode.dispose);
    await _pump(
      tester,
      KitTappable(
        onTap: null,
        disabledReason: 'Needs a connection',
        focusNode: focusNode,
        child: const Text('Delete'),
      ),
    );

    final semantics = tester.getSemantics(find.byType(KitTappable));
    expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
    expect(semantics.hint, 'Needs a connection');

    expect(focusNode.canRequestFocus, isFalse);
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);

    final region = tester.widget<MouseRegion>(
      find
          .descendant(
            of: find.byType(KitTappable),
            matching: find.byType(MouseRegion),
          )
          .first,
    );
    expect(region.cursor, MouseCursor.defer);
    handle.dispose();
  });

  group('4. menu: right-click, long-press, Shift+F10, onLongPress hook', () {
    testWidgets('right-click opens the menu at the click point', (
      tester,
    ) async {
      debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
      addTearDown(() => debugPlatformCapabilities = null);
      var selected = 0;
      await _pump(
        tester,
        KitTappable(
          onTap: () {},
          menu: [KitMenuItem(label: 'Archive', onSelected: () => selected++)],
          child: const Text('Row'),
        ),
        size: const Size(1280, 800),
      );
      final point = tester.getCenter(find.byType(KitTappable));
      await tester.tap(
        find.byType(KitTappable),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(find.byType(KitMenuPanel), findsOneWidget);
      expect(tester.getTopLeft(find.byType(KitMenuPanel)), point);

      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(selected, 1);
    });

    testWidgets('long-press opens the same items at the press point', (
      tester,
    ) async {
      var selected = 0;
      await _pump(
        tester,
        KitTappable(
          onTap: () {},
          menu: [KitMenuItem(label: 'Archive', onSelected: () => selected++)],
          child: const Text('Row'),
        ),
        size: const Size(1280, 800),
      );
      final point = tester.getCenter(find.byType(KitTappable));
      await tester.longPressAt(point);
      await tester.pumpAndSettle();
      expect(find.byType(KitMenuPanel), findsOneWidget);
      expect(tester.getTopLeft(find.byType(KitMenuPanel)), point);
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(selected, 1);
    });

    testWidgets('Shift+F10 opens it anchored (position: null)', (tester) async {
      final focusNode = FocusNode(debugLabel: 'under test');
      addTearDown(focusNode.dispose);
      await _pump(
        tester,
        KitTappable(
          onTap: () {},
          focusNode: focusNode,
          menu: [KitMenuItem(label: 'Archive', onSelected: () {})],
          child: const Text('Row'),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(find.byType(KitMenuPanel), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    });

    testWidgets('the Menu key also opens it anchored', (tester) async {
      final focusNode = FocusNode(debugLabel: 'under test');
      addTearDown(focusNode.dispose);
      await _pump(
        tester,
        KitTappable(
          onTap: () {},
          focusNode: focusNode,
          menu: [KitMenuItem(label: 'Archive', onSelected: () {})],
          child: const Text('Row'),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pumpAndSettle();
      expect(find.byType(KitMenuPanel), findsOneWidget);
    });

    testWidgets('onLongPress: a long-press calls it and opens no menu', (
      tester,
    ) async {
      var hookCalls = 0;
      await _pump(
        tester,
        KitTappable(
          onTap: () {},
          onLongPress: () => hookCalls++,
          child: const Text('Row'),
        ),
      );
      await tester.longPress(find.byType(KitTappable));
      await tester.pumpAndSettle();
      expect(hookCalls, 1);
      expect(find.byType(KitMenuPanel), findsNothing);
    });
  });

  testWidgets('5. menu items are custom semantics actions', (tester) async {
    // Disposed inline, not via addTearDown: the end-of-test leak check runs
    // before addTearDown callbacks.
    final handle = tester.ensureSemantics();
    var archived = false;
    await _pump(
      tester,
      KitTappable(
        onTap: () {},
        menu: [
          KitMenuItem(label: 'Archive', onSelected: () => archived = true),
        ],
        child: const Text('Row'),
      ),
    );
    final actions = _customActions(tester);
    expect(actions.keys, containsAll(['Show actions', 'Archive']));
    actions['Archive']!();
    expect(archived, isTrue);
    handle.dispose();
  });

  testWidgets('6. empty menu: long-press shows the tooltip, opens nothing', (
    tester,
  ) async {
    await _pump(
      tester,
      KitTappable(onTap: () {}, tooltip: 'More info', child: const Text('Row')),
    );
    await tester.longPress(find.byType(KitTappable));
    await tester.pump();
    expect(find.byType(KitMenuPanel), findsNothing);
    expect(find.text('More info'), findsOneWidget);
  });

  group('7. hover and pressed fills come from surface steps', () {
    Future<void> probe(
      WidgetTester tester, {
      required bool light,
      required KitSurfaceLevel surface,
      required KitSurfaceLevel expectHover,
      required KitSurfaceLevel expectPressed,
    }) async {
      await _pump(
        tester,
        KitTappable(onTap: () {}, surface: surface, child: const Text('Row')),
        light: light,
        background: _surfaceColor(light, surface),
      );
      final tokens = KitTokens.of(tester.element(find.byType(KitTappable)));
      final rect = tester.getRect(find.byType(KitTappable));
      final probePoint = rect.topLeft + const Offset(4, 4);

      var shot = await _Shot.take(tester);
      expect(
        _near(shot.at(probePoint), tokens.fillOf(surface)),
        isTrue,
        reason: 'no hover: the fill matches the surface it sits on',
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(() => mouse.removePointer());
      await mouse.moveTo(rect.center);
      await tester.pumpAndSettle();
      shot = await _Shot.take(tester);
      expect(_near(shot.at(probePoint), tokens.fillOf(expectHover)), isTrue);

      await mouse.down(rect.center);
      await tester.pumpAndSettle();
      shot = await _Shot.take(tester);
      expect(_near(shot.at(probePoint), tokens.fillOf(expectPressed)), isTrue);
      await mouse.up();
    }

    testWidgets('surface1: hover surface2 in dark, pressed surface3', (
      tester,
    ) async {
      await probe(
        tester,
        light: false,
        surface: KitSurfaceLevel.surface1,
        expectHover: KitSurfaceLevel.surface2,
        expectPressed: KitSurfaceLevel.surface3,
      );
    });

    testWidgets('surface1: hover surface3 in light, pressed surface3', (
      tester,
    ) async {
      await probe(
        tester,
        light: true,
        surface: KitSurfaceLevel.surface1,
        expectHover: KitSurfaceLevel.surface3,
        expectPressed: KitSurfaceLevel.surface3,
      );
    });

    testWidgets('surface3: hover and pressed both step down to surface2', (
      tester,
    ) async {
      await probe(
        tester,
        light: false,
        surface: KitSurfaceLevel.surface3,
        expectHover: KitSurfaceLevel.surface2,
        expectPressed: KitSurfaceLevel.surface2,
      );
    });

    testWidgets('touch (no mouse connected): no hover paint', (tester) async {
      await _pump(
        tester,
        const KitTappable(onTap: _noop, child: Text('Row')),
        background: _surfaceColor(false, KitSurfaceLevel.surface1),
      );
      final tokens = KitTokens.of(tester.element(find.byType(KitTappable)));
      final rect = tester.getRect(find.byType(KitTappable));
      await tester.tapAt(rect.center);
      await tester.pumpAndSettle();
      final shot = await _Shot.take(tester);
      expect(
        _near(
          shot.at(rect.topLeft + const Offset(4, 4)),
          tokens.fillOf(KitSurfaceLevel.surface1),
        ),
        isTrue,
      );
    });
  });

  testWidgets('8. keyboard focus shows the ring; a tap does not', (
    tester,
  ) async {
    final focusNode = FocusNode(debugLabel: 'under test');
    addTearDown(focusNode.dispose);
    await _pump(
      tester,
      KitTappable(onTap: () {}, focusNode: focusNode, child: const Text('Row')),
    );
    expect(_ring, findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusNode.hasFocus, isTrue, reason: 'Tab moved focus onto it');
    expect(_ring, findsOneWidget);

    focusNode.unfocus();
    // FocusNode's own change notification can lag a frame behind unfocus()
    // (FocusNode.unfocus doc: "may take a frame to update").
    await tester.pump();
    await tester.pump();
    expect(_ring, findsNothing);

    await tester.tap(find.byType(KitTappable));
    await tester.pump();
    expect(focusNode.hasFocus, isFalse, reason: 'a tap never requests focus');
    expect(_ring, findsNothing);
  });

  testWidgets('9. the tooltip shows on hover and on keyboard focus', (
    tester,
  ) async {
    final focusNode = FocusNode(debugLabel: 'under test');
    addTearDown(focusNode.dispose);
    await _pump(
      tester,
      KitTappable(
        onTap: () {},
        tooltip: 'Retry',
        shortcut: 'Ctrl+R',
        focusNode: focusNode,
        child: const Text('Row'),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(() => mouse.removePointer());
    await mouse.moveTo(tester.getCenter(find.byType(KitTappable)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Retry  Ctrl+R'), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(seconds: 1));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    await tester.pump();
    expect(find.text('Retry  Ctrl+R'), findsOneWidget);
  });

  testWidgets('10. no HapticFeedback on tap or long-press', (tester) async {
    final calls = recordHaptics(tester);
    var taps = 0;
    await _pump(
      tester,
      KitTappable(
        onTap: () => taps++,
        onLongPress: () {},
        child: const Text('Row'),
      ),
    );
    await tester.tap(find.byType(KitTappable));
    await tester.pump();
    await tester.longPress(find.byType(KitTappable));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(calls, isEmpty);
  });

  testWidgets('12. selected exposes isSelected in semantics', (tester) async {
    // Disposed inline, not via addTearDown: the end-of-test leak check runs
    // before addTearDown callbacks.
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      KitTappable(onTap: () {}, selected: true, child: const Text('Row')),
    );
    final semantics = tester.getSemantics(find.byType(KitTappable));
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
    handle.dispose();
  });

  // 11 (reduced motion settles after one pump with no ticker) is the
  // kitMotionStillTests registration below (G8x, MOT-7).
  kitMotionStillTests(
    'KitTappable',
    builds: {
      'enabled': () => KitTappable(onTap: () {}, child: const Text('Row')),
      'disabled': () => KitTappable(
        onTap: null,
        disabledReason: 'Needs a connection',
        child: const Text('Row'),
      ),
    },
    changes: {
      'pressed then released': KitMotionChange(
        build: () => KitTappable(onTap: () {}, child: const Text('Row')),
        act: (tester, stage) async {
          await tester.tap(find.byType(KitTappable));
        },
        shows: 'Row',
      ),
    },
  );
}

void _noop() {}
