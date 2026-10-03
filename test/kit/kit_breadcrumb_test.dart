// Behaviour tests for KitBreadcrumb (docs/ux-system/kit-api/KitBreadcrumb.md
// "Tests required"). The RTL test (7) is reduced to the isolation marks: the
// owner decision of 2026-09-27 drops Arabic and RTL review.
//
// These tests use the test font, where every glyph is as wide as the font
// size (14 dp for KitText.secondary), so the collapse widths are exact.
import 'kit_motion_still.dart';

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_bidi.dart';
import 'package:opencode_mobile/ui/kit/kit_breadcrumb.dart';
import 'package:opencode_mobile/ui/kit/kit_tappable.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

const _root = 'oc';
// 3 characters each: a 58 dp crumb. At 412 dp only root › … › api › cfg
// fits; at 1280 dp all eight do.
const _eight = ['lib', 'kit', 'src', 'app', 'dev', 'net', 'api', 'cfg'];

// One instance: a fresh ThemeData on every pump would make MaterialApp's
// AnimatedTheme animate between two equal-looking themes.
final _theme = AppTheme.dark();

Key _crumb(int index) => ValueKey('crumb$index');
const _trailKey = ValueKey('trail');

Future<List<int>> _pump(
  WidgetTester tester, {
  String root = _root,
  List<String> segments = _eight,
  Size size = const Size(412, 915),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final selected = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: KitBreadcrumb(
              rootLabel: root,
              segments: segments,
              onSelected: selected.add,
              breadcrumbKey: _trailKey,
              crumbKey: _crumb,
            ),
          ),
        ),
      ),
    ),
  );
  return selected;
}

/// The labels of the trail's semantics nodes, in tree (trail) order.
List<SemanticsNode> _crumbNodes(WidgetTester tester) {
  final nodes = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    if (node.label.isNotEmpty) nodes.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  tester.getSemantics(find.byKey(_trailKey)).visitChildren((child) {
    visit(child);
    return true;
  });
  return nodes;
}

String? _focusedLabel() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context?.findAncestorWidgetOfExactType<KitTappable>()?.label;
}

void main() {
  kitMotionStillTests(
    'KitBreadcrumb',
    builds: {
      'path': () => KitBreadcrumb(
        rootLabel: 'Project',
        segments: const ['lib', 'state'],
        onSelected: (_) {},
      ),
    },
    changes: {
      'directory changes': KitMotionChange(
        build: () => KitBreadcrumb(
          rootLabel: 'Project',
          segments: const ['lib'],
          onSelected: (_) {},
        ),
        act: (tester, stage) => stage.rebuild(
          KitBreadcrumb(
            rootLabel: 'Project',
            segments: const ['test'],
            onSelected: (_) {},
          ),
        ),
        shows: KitBidi.auto('test'),
      ),
    },
  );

  testWidgets('1. select: root is -1, an ancestor its index, current nothing', (
    tester,
  ) async {
    final selected = await _pump(
      tester,
      segments: const ['lib', 'ui', 'screens'],
    );
    await tester.tap(find.byKey(_crumb(-1)));
    await tester.tap(find.byKey(_crumb(1)));
    await tester.tap(find.byKey(_crumb(2)), warnIfMissed: false);
    await tester.pump();
    expect(selected, [-1, 1]);
  });

  testWidgets('2. collapse: root › … › parent › current at 412, all at 1280', (
    tester,
  ) async {
    final selected = await _pump(tester);
    expect(find.byKey(_crumb(-1)), findsOneWidget);
    expect(find.byKey(_crumb(6)), findsOneWidget);
    expect(find.byKey(_crumb(7)), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      expect(find.byKey(_crumb(i)), findsNothing, reason: 'segment $i');
    }
    expect(find.text('…'), findsOneWidget);

    await tester.tap(find.text('…'));
    await tester.pumpAndSettle();
    final hidden = _eight.take(6).toList();
    final tops = [
      for (final name in hidden) tester.getTopLeft(find.text(name)),
    ];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i].dy, greaterThan(tops[i - 1].dy), reason: hidden[i]);
    }
    await tester.tap(find.text('src'));
    await tester.pumpAndSettle();
    expect(selected, [2]);

    await _pump(tester, size: const Size(1280, 800));
    for (var i = -1; i < 8; i++) {
      expect(find.byKey(_crumb(i)), findsOneWidget, reason: 'crumb $i');
    }
    expect(find.text('…'), findsNothing);
  });

  testWidgets('3. always kept at 320: root, parent, current; current wraps', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    const current = 'a-very-long-current-folder-name';
    await _pump(
      tester,
      root: 'my-long-project-root',
      segments: const [
        'alpha-long-folder',
        'beta-long-folder',
        'parent-folder-name',
        current,
      ],
      size: const Size(320, 800),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(_crumb(-1)), findsOneWidget);
    expect(find.byKey(_crumb(2)), findsOneWidget);
    expect(find.byKey(_crumb(3)), findsOneWidget);
    expect(find.bySemanticsLabel('Current folder: $current'), findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byKey(_crumb(3)),
        matching: find.byType(RichText),
      ),
    );
    // 14 dp lines: two lines, never a horizontal overflow.
    expect(paragraph.size.height, greaterThan(20));
    expect(
      paragraph.size.width,
      lessThanOrEqualTo(tester.getSize(find.byKey(_trailKey)).width),
    );
    handle.dispose();
  });

  testWidgets('4. truncation: a long ancestor cuts in the middle', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final long = 'start-${'x' * 48}-ended'; // 60 characters.
    expect(long.length, 60);
    await _pump(tester, segments: [long, 'cur'], size: const Size(1280, 800));
    final text = find.descendant(
      of: find.byKey(_crumb(0)),
      matching: find.byType(RichText),
    );
    final shown = tester.widget<RichText>(text).text.toPlainText();
    expect(shown, startsWith('${KitBidi.fsi}start'));
    expect(shown, endsWith('ended${KitBidi.pdi}'));
    expect(shown, contains('…'));
    expect(
      tester.getSize(text).width,
      lessThanOrEqualTo(KitTokens.crumbMaxWidth),
    );
    expect(find.bySemanticsLabel('Open folder $long'), findsOneWidget);
    final tooltip = tester.widget<Tooltip>(
      find.ancestor(of: find.byKey(_crumb(0)), matching: find.byType(Tooltip)),
    );
    expect(tooltip.message, long);
    handle.dispose();
  });

  testWidgets('5. semantics: container, trail order, current selected', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, segments: const ['lib', 'ui', 'screens']);
    expect(tester.getSemantics(find.byKey(_trailKey)).label, 'Folder path');
    final nodes = _crumbNodes(tester);
    expect(
      [for (final node in nodes) node.label],
      [
        'Open oc',
        'Open folder lib',
        'Open folder ui',
        'Current folder: screens',
      ],
    );
    for (final node in nodes.take(3)) {
      expect(node.flagsCollection.isButton, isTrue, reason: node.label);
    }
    expect(nodes.last.flagsCollection.isButton, isFalse);
    expect(nodes.last.flagsCollection.isSelected, Tristate.isTrue);

    // Collapsed: "…" is a button named by its count, after the root.
    await _pump(tester);
    expect(
      [for (final node in _crumbNodes(tester)) node.label],
      ['Open oc', '6 more folders', 'Open folder api', 'Current folder: cfg'],
    );
    handle.dispose();
  });

  testWidgets('6. keyboard: root, …, ancestors; current is not a stop', (
    tester,
  ) async {
    final selected = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focusedLabel(), 'Open oc');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focusedLabel(), '6 more folders');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focusedLabel(), 'Open folder api');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selected, [6]);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focusedLabel(), isNot(contains('cfg')));
    expect(_focusedLabel(), isNotNull);
  });

  testWidgets('7. every folder name is isolated (FSI…PDI)', (tester) async {
    await _pump(tester, segments: const ['lib', 'ملفات', 'src']);
    for (final (index, name) in [(0, 'lib'), (1, 'ملفات'), (2, 'src')]) {
      final shown = tester
          .widget<RichText>(
            find.descendant(
              of: find.byKey(_crumb(index)),
              matching: find.byType(RichText),
            ),
          )
          .text
          .toPlainText();
      expect(shown, KitBidi.auto(name));
    }
  });

  testWidgets('8. targets: 48 x 48, no overlapping hit areas', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    final rects = [
      for (final finder in [
        find.byKey(_crumb(-1)),
        find.ancestor(of: find.text('…'), matching: find.byType(KitTappable)),
        find.byKey(_crumb(6)),
      ])
        tester.getRect(finder),
    ];
    for (final rect in rects) {
      expect(rect.width, greaterThanOrEqualTo(48));
      expect(rect.height, greaterThanOrEqualTo(48));
    }
    for (var i = 1; i < rects.length; i++) {
      expect(rects[i].overlaps(rects[i - 1]), isFalse);
    }
    handle.dispose();
  });

  testWidgets('9. no overflow across widths and text sizes; one pump', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    const long = [
      'a-fairly-long-folder',
      'another-long-folder-name',
      'settings',
      'advanced-networking-overrides',
      'the-current-folder-with-a-long-name',
    ];
    for (final width in [320.0, 412.0, 600.0, 840.0, 1280.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        await _pump(
          tester,
          root: 'oc_app',
          segments: long,
          size: Size(width, 800),
          textScale: scale,
        );
        expect(tester.takeException(), isNull, reason: '$width @ $scale');
        expect(tester.hasRunningAnimations, isFalse);
      }
    }
    // A new trail replaces the old one at once (G8).
    await _pump(tester, segments: const ['lib']);
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.bySemanticsLabel('Current folder: lib'), findsOneWidget);
    handle.dispose();
  });
}
