// KitJumpPill (docs/ux-system/kit-api/KitJumpPill.md): the frozen "Tests
// required" contract, items 1-9.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/kit/kit_jump_pill.dart';

/// Pumps [child] as a screen's body, with the real test window sized to
/// [size] (not just a MediaQuery override), so tap and hit-test geometry
/// line up with what a person would actually see.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
  bool light = false,
  bool disableAnimations = false,
  KitEffects effects = KitEffects.defaults,
  Size size = const Size(412, 915),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    KitEffectsScope(
      effects: effects,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: light ? AppTheme.light() : AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, widget) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: widget!,
        ),
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

/// Whether keyboard focus is on [target] itself or a descendant of it
/// (test/kit/kit_keyboard_test.dart's own helper, kept local so this
/// file's write set stays just its own tests).
bool _focusIn(WidgetTester tester, Finder target) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  final element = tester.element(target);
  if (focused == element) return true;
  var found = false;
  (focused as Element).visitAncestorElements((ancestor) {
    if (ancestor == element) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

/// The keyboard focus ring (a foreground stadium outline), if one is drawn.
final _ring = find.byWidgetPredicate(
  (w) =>
      w is DecoratedBox &&
      w.position == DecorationPosition.foreground &&
      w.decoration is ShapeDecoration,
);

/// The pill's own filled stadium (the background [DecoratedBox]).
final _fill = find.byWidgetPredicate(
  (w) =>
      w is DecoratedBox &&
      w.position == DecorationPosition.background &&
      w.decoration is ShapeDecoration &&
      (w.decoration as ShapeDecoration).color != null,
);

Color _fillColor(WidgetTester tester) =>
    (tester.widget<DecoratedBox>(_fill).decoration as ShapeDecoration).color!;

void main() {
  group('1. visible', () {
    testWidgets('shows the label and icon; tap calls onPressed once', (
      tester,
    ) async {
      var taps = 0;
      await _pump(
        tester,
        KitJumpPill(
          label: '3 new · Jump to latest',
          onPressed: () => taps++,
          visible: true,
        ),
      );
      expect(find.text('3 new · Jump to latest'), findsOneWidget);
      expect(find.byIcon(AppIconography.down), findsOneWidget);
      await tester.tap(find.text('3 new · Jump to latest'));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('2. hidden', () {
    /// True when [finder] sits under an offstage [RenderOffstage] (Flutter
    /// keeps the element mounted and laid out, but excludes it from
    /// painting, hit testing and semantics — proxy_box.dart `RenderOffstage`
    /// `hitTest`/`visitChildrenForSemantics`).
    bool underOffstage(WidgetTester tester, Finder finder) {
      for (
        RenderObject? r = tester.renderObject(finder);
        r != null;
        r = r.parent
      ) {
        if (r is RenderOffstage && r.offstage) return true;
      }
      return false;
    }

    /// The offstage subtree is still built (`Visibility(maintainState:
    /// true)`), so a finder must be told not to skip it (finders default to
    /// `skipOffstage: true`, which is exactly the opposite of what "kept
    /// mounted" needs to prove here).
    Finder onstageOrNot(String text) => find.text(text, skipOffstage: false);

    testWidgets('not hittable, not in semantics, not focusable; nothing paints '
        'once settled hidden', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await _pump(
        tester,
        KitJumpPill(
          label: 'Jump to latest',
          onPressed: () => taps++,
          visible: false,
        ),
      );
      // Kept mounted (found by the element tree)...
      expect(onstageOrNot('Jump to latest'), findsOneWidget);
      // ...but offstage: not painted, not hit-testable, not in semantics.
      expect(underOffstage(tester, onstageOrNot('Jump to latest')), isTrue);
      expect(find.bySemanticsLabel('Jump to latest'), findsNothing);

      await tester.tap(onstageOrNot('Jump to latest'), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        _focusIn(tester, find.byType(KitJumpPill, skipOffstage: false)),
        isFalse,
        reason: 'ExcludeFocus keeps a hidden pill out of Tab order',
      );

      expect(tester.hasRunningAnimations, isFalse);
      handle.dispose();
    });

    testWidgets(
      'toggling to hidden ends offstage, not hittable, after settling',
      (tester) async {
        var taps = 0;
        Widget host(bool visible) => KitEffectsScope(
          effects: KitEffects.defaults,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: KitJumpPill(
                  label: 'Jump to latest',
                  onPressed: () => taps++,
                  visible: visible,
                ),
              ),
            ),
          ),
        );
        await tester.pumpWidget(host(true));
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(host(false));
        // Settle the exit animation (KitMotion.standard, 250ms).
        await tester.pump(const Duration(milliseconds: 300));

        expect(underOffstage(tester, onstageOrNot('Jump to latest')), isTrue);
        await tester.tap(onstageOrNot('Jump to latest'), warnIfMissed: false);
        await tester.pump();
        expect(taps, 0);
        expect(tester.hasRunningAnimations, isFalse);
      },
    );
  });

  group('3. motion', () {
    testWidgets('toggling visible animates over KitMotion.standard, no scale', (
      tester,
    ) async {
      final key = GlobalKey();
      // One theme instance for every pump: a fresh AppTheme.dark() per call
      // would not compare equal and MaterialApp's AnimatedTheme would
      // animate between the two (the harness moving, not the part) — see
      // test/kit/kit_motion_still.dart's own `_theme`.
      final theme = AppTheme.dark();
      Widget host(bool visible) => KitEffectsScope(
        effects: KitEffects.defaults,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: KitJumpPill(
                key: key,
                label: 'Jump to latest',
                onPressed: () {},
                visible: visible,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(host(false));
      // Let the app's own initial-route transition settle before toggling,
      // so only KitJumpPill's own animation is under test below.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(host(true));
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      final pillScope = find.byType(KitJumpPill);
      expect(
        find.descendant(of: pillScope, matching: find.byType(ScaleTransition)),
        findsNothing,
      );
      expect(
        tester
            .widgetList(
              find.descendant(of: pillScope, matching: find.byType(Transform)),
            )
            .whereType<Transform>()
            .any((t) => t.transform.getMaxScaleOnAxis() != 1.0),
        isFalse,
        reason: 'MOT-2: KitJumpPill never scales',
      );
      // KitMotion.standard is 250ms; well short of it nothing has settled.
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('under reduced motion (system), one pump() settles', (
      tester,
    ) async {
      final key = GlobalKey();
      final theme = AppTheme.dark();
      Widget host(bool visible) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: KitJumpPill(
              key: key,
              label: 'Jump to latest',
              onPressed: () {},
              visible: visible,
            ),
          ),
        ),
      );
      await tester.pumpWidget(host(false));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(host(true));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('Jump to latest'), findsOneWidget);

      await tester.pumpWidget(host(false));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('under reduced motion (Animations: Off), one pump() settles', (
      tester,
    ) async {
      final key = GlobalKey();
      final theme = AppTheme.dark();
      Widget host(bool visible) => KitEffectsScope(
        effects: const KitEffects(motion: KitMotionLevel.off),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: KitJumpPill(
                key: key,
                label: 'Jump to latest',
                onPressed: () {},
                visible: visible,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(host(false));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(host(true));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('Jump to latest'), findsOneWidget);
    });
  });

  group('4. KitJumpPillLayer', () {
    testWidgets('clears the published bottom inset by default', (tester) async {
      const inset = 140.0;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: KitBottomInset(
              insets: const KitClearance(bottom: inset),
              child: KitJumpPillLayer(
                pill: KitJumpPill(
                  label: 'Jump to latest',
                  onPressed: () {},
                  visible: true,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final areaBottom = tester.getRect(find.byType(Scaffold)).bottom;
      final pillBottom = tester.getRect(find.byType(KitJumpPill)).bottom;
      // >= 152 dp above the area's bottom (140 inset + 12 space3).
      expect(areaBottom - pillBottom, greaterThanOrEqualTo(152));
    });

    testWidgets('clearBottomInset: false sits space3 from the area bottom', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: KitBottomInset(
              insets: const KitClearance(bottom: 140),
              child: KitJumpPillLayer(
                clearBottomInset: false,
                pill: KitJumpPill(
                  label: 'Jump to latest',
                  onPressed: () {},
                  visible: true,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final context = tester.element(find.byType(Scaffold));
      final tokens = KitTokens.of(context);
      final areaBottom = tester.getRect(find.byType(Scaffold)).bottom;
      final pillBottom = tester.getRect(find.byType(KitJumpPill)).bottom;
      expect(areaBottom - pillBottom, moreOrLessEquals(tokens.space3));
    });
  });

  group('5. KitJumpPill.older', () {
    testWidgets('sits at the top edge with the up glyph', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: KitJumpPillLayer(
              pill: KitJumpPill.older(
                label: 'Earlier messages',
                onPressed: () {},
                visible: true,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(AppIconography.chevronUp), findsOneWidget);
      final context = tester.element(find.byType(Scaffold));
      final tokens = KitTokens.of(context);
      final areaTop = tester.getRect(find.byType(Scaffold)).top;
      final pillTop = tester.getRect(find.byType(KitJumpPill)).top;
      expect(pillTop - areaTop, moreOrLessEquals(tokens.space3, epsilon: 2));
    });
  });

  group('6. latestLabel', () {
    testWidgets('newCount: 3 says "3 new · Jump to latest"; 0 says '
        '"Jump to latest"', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(
        KitJumpPill.latestLabel(ctx, newCount: 3),
        '3 new · Jump to latest',
      );
      expect(
        KitJumpPill.latestLabel(ctx, newCount: 1),
        '1 new · Jump to latest',
      );
      expect(KitJumpPill.latestLabel(ctx), 'Jump to latest');
      expect(KitJumpPill.latestLabel(ctx, newCount: 0), 'Jump to latest');
    });
  });

  group('7. semantics', () {
    testWidgets('a button whose label is the words, not a live region, '
        '>= 48x48', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        KitJumpPill(
          label: '3 new · Jump to latest',
          onPressed: () {},
          visible: true,
        ),
      );
      // Settle the entrance animation: at opacity 0 mid-fade, Opacity
      // excludes its subtree from semantics by design, which is not what
      // this test means to exercise.
      await tester.pump(const Duration(seconds: 1));
      final semantics = tester.getSemantics(
        find.text('3 new · Jump to latest'),
      );
      // Focusability itself is proven by real Tab traversal in "8. desktop
      // capabilities" below; `excludeSemantics` merges only this node's own
      // flags, not InkWell's contributed `isFocusable`.
      expect(
        semantics,
        isSemantics(
          label: '3 new · Jump to latest',
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(
        semantics.getSemanticsData().flagsCollection.isLiveRegion,
        isFalse,
        reason: 'K2 §1.19: not a live region',
      );
      final box = tester.getSize(find.byType(InkWell));
      expect(box.width, greaterThanOrEqualTo(48));
      expect(box.height, greaterThanOrEqualTo(48));
      handle.dispose();
    });
  });

  group('8. desktop capabilities', () {
    testWidgets('focus ring visible when focused; Enter activates', (
      tester,
    ) async {
      var taps = 0;
      await _pump(
        tester,
        KitJumpPill(
          label: 'Jump to latest',
          onPressed: () => taps++,
          visible: true,
        ),
      );
      expect(_ring, findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusIn(tester, find.byType(InkWell)), isTrue);
      expect(_ring, findsOneWidget);
      final roles = ThemeRoles.resolve(AppTheme.dark());
      final shape =
          (tester.widget<DecoratedBox>(_ring).decoration as ShapeDecoration)
                  .shape
              as OutlinedBorder;
      expect(shape.side.color, roles.accent);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('fine-pointer hover steps the fill to surface2', (
      tester,
    ) async {
      await _pump(
        tester,
        KitJumpPill(label: 'Jump to latest', onPressed: () {}, visible: true),
      );
      final roles = ThemeRoles.resolve(AppTheme.dark());
      expect(_fillColor(tester), roles.surface3);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(InkWell)));
      await tester.pump();
      expect(_fillColor(tester), roles.surface2);
    });
  });

  group('9. 200% text', () {
    testWidgets('at 320 dp: no overflow, label on <= 2 lines', (tester) async {
      await _pump(
        tester,
        KitJumpPill(
          label: '3 new · Jump to latest',
          onPressed: () {},
          visible: true,
        ),
        size: const Size(320, 700),
        textScale: 2.0,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      final textWidget = tester.widget<Text>(
        find.descendant(
          of: find.byType(KitJumpPill),
          matching: find.byType(Text),
        ),
      );
      expect(textWidget.maxLines, anyOf(isNull, lessThanOrEqualTo(2)));
      final renderBox = tester.renderObject<RenderBox>(
        find.descendant(
          of: find.byType(KitJumpPill),
          matching: find.byType(Text).first,
        ),
      );
      expect(renderBox.size.width, lessThanOrEqualTo(320));
    });
  });
}
