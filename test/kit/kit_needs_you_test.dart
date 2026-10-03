// KitNeedsYou (docs/ux-system/kit-api/KitNeedsYou.md): the frozen "Tests
// required" contract, 1-4 and 7-8 verbatim. Item 5 ("row without reason or
// ifIgnored does not compile") is a compile-time guarantee of the required
// named parameters themselves; this file instead exercises the runtime half
// of that rule (an empty ifIgnored asserts). Item 6 (Arabic plural forms,
// bidi golden) is dropped by the owner decision of 2026-09-27 (Arabic and
// RTL review out of scope for this wave); this file keeps only the
// direction-neutral half of that rule — who/server are bidi-isolated in the
// composed text regardless of locale.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_bidi.dart';
import 'package:opencode_mobile/ui/kit/kit_menu.dart' show KitMenuPanel;
import 'package:opencode_mobile/ui/kit/kit_needs_you.dart';
import 'package:opencode_mobile/ui/kit/kit_row.dart';
import 'package:opencode_mobile/ui/kit/kit_row_parts.dart';
import 'package:opencode_mobile/ui/kit/kit_task_mark.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

/// One theme instance for every pump in a test: a fresh [AppTheme.dark] on
/// each rebuild would not compare equal and [MaterialApp]'s `AnimatedTheme`
/// would then animate between the two — the harness moving, not the part
/// (see test/kit/kit_motion_still.dart's own note).
final _theme = AppTheme.dark();

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  Size size = const Size(412, 915),
  bool disableAnimations = false,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _theme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
          textScaler: TextScaler.linear(textScale),
        ),
        child: widget!,
      ),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  // 1. mark() is exactly KitTaskMark(state: needsYou), semantics "Needs you".
  testWidgets('mark(): KitTaskMark(state: needsYou), semantics "Needs you"', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pump(tester, KitNeedsYou.mark());
      final mark = tester.widget<KitTaskMark>(find.byType(KitTaskMark));
      expect(mark.state, KitTaskState.needsYou);
      expect(find.bySemanticsLabel('Needs you'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  // 2. span(count: 1) is "Needs you · "; span(count: 3) is "3 need you · "
  // (English plural; Arabic dropped, see file header).
  testWidgets(
    'span(): "Needs you · " at 1, "3 need you · " at 3, attention tone',
    (tester) async {
      late TextSpan one;
      late TextSpan three;
      await _pump(
        tester,
        Builder(
          builder: (context) {
            one = KitNeedsYou.span(context, count: 1);
            three = KitNeedsYou.span(context, count: 3);
            final roles = ThemeRoles.resolve(Theme.of(context));
            expect(one.style?.color, roles.attention);
            expect(three.style?.color, roles.attention);
            return const SizedBox.shrink();
          },
        ),
      );
      expect(one.text, 'Needs you · ');
      expect(three.text, '3 need you · ');
    },
  );

  group('badge()', () {
    Widget host(int count, {Key? childKey}) => KitNeedsYou.badge(
      count: count,
      child: Semantics(
        label: 'Chat',
        child: Icon(Icons.chat, key: childKey ?? const ValueKey('host-icon')),
      ),
    );

    testWidgets('count 0: the child unchanged, no badge in the tree', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        const iconKey = ValueKey('host-icon');
        // The bare host first, for its semantics and layout.
        await _pump(
          tester,
          Center(
            child: Semantics(
              label: 'Chat',
              child: const Icon(Icons.chat, key: iconKey),
            ),
          ),
        );
        final bare = tester.getSemantics(find.byKey(iconKey));
        final bareLabel = bare.label;
        final bareRect = tester.getRect(find.byKey(iconKey));
        final bareFlags = bare.getSemanticsData().flagsCollection;
        final bareActions = bare.getSemanticsData().actions;

        await _pump(tester, Center(child: host(0)));
        expect(find.byIcon(Icons.chat), findsOneWidget);
        expect(find.text('0'), findsNothing);
        // No wrapper of the badge's around the host: no merge, no stack,
        // no positioned pill.
        final badge = find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_KitNeedsYouBadge',
        );
        for (final type in [MergeSemantics, Stack, PositionedDirectional]) {
          expect(
            find.descendant(of: badge, matching: find.byType(type)),
            findsNothing,
            reason: '$type',
          );
        }
        // The host's semantics and layout are exactly the bare host's.
        final data = tester.getSemantics(find.byKey(iconKey));
        expect(data.label, bareLabel);
        expect(data.getSemanticsData().flagsCollection, bareFlags);
        expect(data.getSemanticsData().actions, bareActions);
        expect(tester.getRect(find.byKey(iconKey)), bareRect);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('dropping to 0 fades out, then leaves the child alone and '
        'keeps its element', (tester) async {
      const iconKey = ValueKey('host-icon');
      await _pump(tester, host(3));
      await tester.pumpAndSettle();
      final before = tester.element(find.byKey(iconKey));
      await _pump(tester, host(0));
      await tester.pump(const Duration(milliseconds: 50));
      // Mid fade-out: the last count is still drawn, fading.
      expect(find.text('3'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('3'), findsNothing);
      final badge = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_KitNeedsYouBadge',
      );
      expect(
        find.descendant(of: badge, matching: find.byType(Stack)),
        findsNothing,
      );
      // Coming and going never rebuilds the host from scratch.
      expect(tester.element(find.byKey(iconKey)), same(before));
      await _pump(tester, host(4));
      await tester.pumpAndSettle();
      expect(find.text('4'), findsOneWidget);
      expect(tester.element(find.byKey(iconKey)), same(before));
    });

    testWidgets('at text scale 2.0 the pill grows to its clamped text', (
      tester,
    ) async {
      await _pump(tester, Center(child: host(5)), textScale: 2);
      await tester.pumpAndSettle();
      final text = find.text('5');
      final paragraph = tester.renderObject<RenderParagraph>(text);
      final textHeight = paragraph.getMaxIntrinsicHeight(double.infinity);
      // The clamp holds: caption at 1.3x, not 2.0x.
      expect(
        paragraph.textScaler.scale(10),
        closeTo(10 * KitTokens.badgeTextScaleMax, 0.001),
      );
      expect(textHeight, greaterThan(KitTokens.badgeHeight));
      final pill = find
          .ancestor(of: text, matching: find.byType(Container))
          .first;
      expect(tester.getSize(pill).height, greaterThanOrEqualTo(textHeight));
      expect(tester.getSize(text).height, greaterThanOrEqualTo(textHeight));
    });

    testWidgets('count 5: shows "5", host label ends ", 5 need you"', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pump(tester, host(5));
        await tester.pump();
        expect(find.text('5'), findsOneWidget);
        final data = tester.getSemantics(
          find.byKey(const ValueKey('host-icon')),
        );
        expect(data.label, endsWith(', 5 need you'));
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('count 120: shows "99+"', (tester) async {
      await _pump(tester, host(120));
      await tester.pump();
      expect(find.text('99+'), findsOneWidget);
      expect(find.text('120'), findsNothing);
    });

    testWidgets('a count change cross-fades on quick, never scales', (
      tester,
    ) async {
      await _pump(tester, host(3));
      await tester.pumpAndSettle();
      await _pump(tester, host(7));
      await tester.pump();
      // Mid cross-fade: both the old and the incoming digit may be
      // present (AnimatedSwitcher stacks outgoing and incoming), but
      // nothing scales the pill (MOT-2) — checked by the transform below.
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('7'), findsOneWidget);
      final transform = tester
          .renderObject<RenderObject>(find.text('7'))
          .getTransformTo(null);
      expect(transform.getMaxScaleOnAxis(), closeTo(1, 0.001));
    });

    testWidgets('under reduced motion a badge change settles after one pump', (
      tester,
    ) async {
      await _pump(tester, host(3), disableAnimations: true);
      await tester.pumpAndSettle();
      await _pump(tester, host(7), disableAnimations: true);
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('3'), findsNothing);
    });
  });

  group('row()', () {
    testWidgets('tapping calls onOpen once; no answer actions or menu', (
      tester,
    ) async {
      var opened = 0;
      await _pump(
        tester,
        KitNeedsYou.row(
          title: 'Run a shell command',
          reason: KitNeedsYouReason.decision,
          ifIgnored: 'The team waits; nothing is lost.',
          onOpen: () => opened++,
        ),
      );
      expect(find.byType(KitRowMenu), findsNothing);
      await tester.tap(find.byType(KitRow));
      expect(opened, 1);
      await tester.tap(find.byType(KitRow));
      expect(opened, 2);
    });

    testWidgets(
      'semantics: one button node with the reason word and ifIgnored',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await _pump(
            tester,
            KitNeedsYou.row(
              title: 'Run a shell command',
              reason: KitNeedsYouReason.blocked,
              ifIgnored: 'The team waits; nothing is lost.',
              onOpen: () {},
              who: 'fox',
              server: 'laptop',
            ),
          );
          final node = tester.getSemantics(find.byType(KitRow));
          expect(node.flagsCollection.isButton, isTrue);
          expect(node.label, contains('Run a shell command'));
          expect(
            node.label,
            contains(
              KitNeedsYou.reasonWord(
                tester.element(find.byType(KitRow)),
                KitNeedsYouReason.blocked,
              ),
            ),
          );
          expect(node.label, contains('The team waits; nothing is lost.'));
          final data = node.getSemanticsData();
          expect(data.actions & SemanticsAction.tap.index, isNot(0));
          expect(data.actions & SemanticsAction.customAction.index, 0);
          expect(data.customSemanticsActionIds, anyOf(isNull, isEmpty));
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets('who and server are bidi-isolated in the composed text', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pump(
          tester,
          KitNeedsYou.row(
            title: 'Merge the branch',
            reason: KitNeedsYouReason.decision,
            ifIgnored: 'The branch waits.',
            onOpen: () {},
            who: 'fox',
            server: 'laptop',
          ),
        );
        final node = tester.getSemantics(find.byType(KitRow));
        expect(node.label, contains(KitBidi.auto('fox')));
        expect(node.label, contains(KitBidi.auto('laptop')));
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('an empty ifIgnored asserts (G37)', (tester) async {
      expect(
        () => KitNeedsYou.row(
          title: 'Run a shell command',
          reason: KitNeedsYouReason.decision,
          ifIgnored: '',
          onOpen: () {},
        ),
        throwsAssertionError,
      );
    });

    testWidgets('right-click opens no menu and is not an open', (tester) async {
      var opened = 0;
      await _pump(
        tester,
        KitNeedsYou.row(
          title: 'Run a shell command',
          reason: KitNeedsYouReason.decision,
          ifIgnored: 'Nothing is lost.',
          onOpen: () => opened++,
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(KitRow)),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      // No kit menu, no framework menu, and no route pushed over the host.
      expect(find.byType(KitRowMenu), findsNothing);
      expect(find.byType(KitMenuPanel), findsNothing);
      expect(find.byType(PopupMenuButton<Object?>), findsNothing);
      expect(
        Navigator.of(tester.element(find.byType(KitRow))).canPop(),
        isFalse,
      );
      // And a secondary click is not an open.
      expect(opened, 0);
    });

    testWidgets('long-press opens no menu', (tester) async {
      await _pump(
        tester,
        KitNeedsYou.row(
          title: 'Run a shell command',
          reason: KitNeedsYouReason.decision,
          ifIgnored: 'Nothing is lost.',
          onOpen: () {},
        ),
      );
      await tester.longPress(find.byType(KitRow));
      await tester.pumpAndSettle();
      expect(find.byType(KitMenuPanel), findsNothing);
      expect(
        Navigator.of(tester.element(find.byType(KitRow))).canPop(),
        isFalse,
      );
    });

    testWidgets('the age: "waiting 4 minutes" spoken, "· " joined on screen', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pump(
          tester,
          KitNeedsYou.row(
            title: 'Allow microphone access',
            reason: KitNeedsYouReason.consent,
            ifIgnored: 'Voice input stays off.',
            onOpen: () {},
            // Half a minute of slack either way of the test's fake clock,
            // which starts a moment before this line reads the real one.
            since: DateTime.now().subtract(
              const Duration(minutes: 4, seconds: 30),
            ),
          ),
        );
        final node = tester.getSemantics(find.byType(KitRow));
        expect(node.label, contains('waiting 4 minutes'));
        expect(node.label, isNot(contains('min,')));
        final shown = find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('waiting 4 min · Voice input'),
        );
        expect(shown, findsOneWidget);
        expect(find.textContaining('min. '), findsNothing);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('keyboard: Tab reaches the row, Enter calls onOpen', (
      tester,
    ) async {
      var opened = 0;
      await _pump(
        tester,
        KitNeedsYou.row(
          title: 'Run a shell command',
          reason: KitNeedsYouReason.decision,
          ifIgnored: 'Nothing is lost.',
          onOpen: () => opened++,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus?.context;
      expect(focused, isNotNull);
      final rowElement = tester.element(find.byType(KitRow));
      var withinRow = false;
      (focused as Element).visitAncestorElements((ancestor) {
        if (ancestor == rowElement) {
          withinRow = true;
          return false;
        }
        return true;
      });
      expect(withinRow || focused == rowElement, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(opened, 1);
    });
  });

  group('reasonWord()', () {
    testWidgets('the three reason words', (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (context) {
            expect(
              KitNeedsYou.reasonWord(context, KitNeedsYouReason.decision),
              'Needs your decision',
            );
            expect(
              KitNeedsYou.reasonWord(context, KitNeedsYouReason.blocked),
              'Stuck: needs you',
            );
            expect(
              KitNeedsYou.reasonWord(context, KitNeedsYouReason.consent),
              'Needs your OK',
            );
            return const SizedBox.shrink();
          },
        ),
      );
    });
  });
}
