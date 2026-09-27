// Behaviour tests for KitTaskCard (docs/ux-system/kit-api/KitTaskCard.md,
// "Tests required"). Arabic and RTL review are dropped by the owner's
// decision of 2026-09-27; the RTL overflow pass stays because it is cheap.
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/orchestration/models/work.dart';
import 'package:opencode_mobile/state/team_board.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_icon.dart';
import 'package:opencode_mobile/ui/kit/kit_icon_button.dart';
import 'package:opencode_mobile/ui/kit/kit_menu.dart';
import 'package:opencode_mobile/ui/kit/kit_receipt.dart';
import 'package:opencode_mobile/ui/kit/kit_task_card.dart';
import 'package:opencode_mobile/ui/kit/kit_task_mark.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';
import 'package:opencode_mobile/ui/widgets/team_board_card.dart';

import '../goldens/kit/kit_gallery.dart' show loadKitGalleryFonts;

final _dark = AppTheme.dark();

/// A colour as 8-bit ARGB, so a Paint's colour compares with a role.
Color _n(Color c) => Color(c.toARGB32());

ThemeRoles _r(WidgetTester tester) =>
    KitTokens.of(tester.element(find.byType(Scaffold))).roles;

Future<void> _pump(
  WidgetTester tester,
  Widget card, {
  double width = 320,
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: _dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Directionality(textDirection: direction, child: child!),
      ),
      home: Scaffold(
        body: Align(
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(width: width, child: card),
        ),
      ),
    ),
  );
  await tester.pump();
}

KitTaskCard _card({
  String title = 'Fix the sync engine',
  KitTaskState mark = KitTaskState.working,
  VoidCallback? onOpen,
  KitTaskFlag? flag,
  KitReceipt? receipt,
  KitAction? action,
  List<KitMenuItem> menu = const [],
  List<KitTaskMeta> meta = const [
    KitTaskMeta('High', priority: KitPriority.high, strong: true),
    KitTaskMeta('Bug'),
    KitTaskMeta('fox'),
    KitTaskMeta('12 min ago'),
  ],
}) => KitTaskCard(
  cardKey: const ValueKey('card'),
  titleKey: const ValueKey('title'),
  metaKey: const ValueKey('meta'),
  flagKey: const ValueKey('flag'),
  actionKey: const ValueKey('action'),
  title: title,
  mark: mark,
  onOpen: onOpen ?? () {},
  meta: meta,
  flag: flag,
  receipt: receipt,
  action: action,
  menu: menu,
);

/// Every colour painted as text or glyph under [root], with the text or
/// glyph it belongs to.
List<(String, Color)> _paintedColours(WidgetTester tester, Finder root) {
  final out = <(String, Color)>[];
  for (final element in root.evaluate()) {
    void visit(Element e) {
      final ro = e.renderObject;
      if (e.widget is RichText && ro is RenderParagraph) {
        ro.text.visitChildren((span) {
          final colour = span.style?.color;
          if (span is TextSpan && colour != null) {
            out.add((span.text ?? '', _n(colour)));
          }
          return true;
        });
      }
      if (e.widget is CustomPaint) {
        final painter = (e.widget as CustomPaint).painter;
        if (painter != null) {
          final canvas = _RecordingCanvas();
          painter.paint(canvas, const Size.square(20));
          for (final colour in canvas.colours) {
            out.add(('<paint>', _n(colour)));
          }
        }
      }
      e.visitChildren(visit);
    }

    visit(element);
  }
  return out;
}

class _RecordingCanvas implements Canvas {
  final colours = <Color>[];
  final rrects = <(RRect, Color)>[];
  int lines = 0;

  @override
  void drawRRect(RRect rrect, Paint paint) {
    colours.add(paint.color);
    rrects.add((rrect, paint.color));
  }

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    colours.add(paint.color);
    lines++;
  }

  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      colours.add(paint.color);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

_RecordingCanvas _paintGlyph(WidgetTester tester, KitPriority priority) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is KitPriorityGlyph && w.priority == priority,
      ),
      matching: find.byType(CustomPaint),
    ),
  );
  final canvas = _RecordingCanvas();
  paint.painter!.paint(canvas, const Size.square(20));
  return canvas;
}

void main() {
  testWidgets('1 open: a tap and Enter call onOpen once each', (tester) async {
    var opened = 0;
    var acted = 0;
    await _pump(
      tester,
      _card(
        onOpen: () => opened++,
        action: KitAction(label: 'Move or change', onPressed: () => acted++),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('title')));
    expect(opened, 1);
    await tester.tap(find.byKey(const ValueKey('action')));
    expect(opened, 1);
    expect(acted, 1);
    // Keyboard: the card is the first Tab stop.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened, 2);
  });

  testWidgets('2 action: 48 dp, absent when null, disabled while sending', (
    tester,
  ) async {
    await _pump(
      tester,
      _card(
        action: KitAction(
          label: 'Move or change',
          icon: AppIconography.swap,
          onPressed: () {},
        ),
      ),
    );
    final size = tester.getSize(find.byKey(const ValueKey('action')));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));

    await _pump(tester, _card());
    expect(find.byType(KitIconButton), findsNothing);

    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      _card(
        receipt: const KitReceipt(
          state: KitReceiptState.sending,
          label: 'Moving to Review…',
          automatic: true,
        ),
        action: KitAction(
          label: 'Move or change',
          icon: AppIconography.swap,
          onPressed: () {},
          disabledReason: 'Moving…',
        ),
      ),
    );
    expect(
      tester.widget<KitIconButton>(find.byType(KitIconButton)).onPressed,
      isNull,
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('action'))),
      matchesSemantics(hint: 'Moving…', isButton: true, hasEnabledState: true),
    );
    handle.dispose();
  });

  testWidgets('3 menu: long-press and right-click open it; custom actions', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final menu = [KitMenuItem(label: 'Archive task', onSelected: () {})];
    await _pump(tester, _card(menu: menu));
    await tester.longPress(find.byKey(const ValueKey('title')));
    await tester.pumpAndSettle();
    expect(find.text('Archive task'), findsOneWidget);
    await tester.tapAt(const Offset(400, 900));
    await tester.pumpAndSettle();
    expect(find.text('Archive task'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('title')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    expect(find.text('Archive task'), findsOneWidget);
    await tester.tapAt(const Offset(400, 900));
    await tester.pumpAndSettle();

    final node = tester.getSemantics(find.byKey(const ValueKey('title')));
    final labels = node.getSemanticsData().customSemanticsActionIds!.map(
      (id) => CustomSemanticsAction.getAction(id)!.label,
    );
    expect(labels, contains('Archive task'));
    handle.dispose();

    expect(
      () => KitTaskCard(
        title: 't',
        mark: KitTaskState.working,
        onOpen: () {},
        menu: menu,
        onLongPress: () {},
      ),
      throwsAssertionError,
    );
  });

  testWidgets('4 needs you: attention only in the mark and the word', (
    tester,
  ) async {
    await _pump(
      tester,
      _card(
        mark: KitTaskState.needsYou,
        flag: const KitTaskFlag(
          kind: KitTaskFlagKind.needsYou,
          label: 'Approve the merge',
        ),
      ),
    );
    expect(find.textContaining('Needs you'), findsOneWidget);
    final attention = _paintedColours(
      tester,
      find.byKey(const ValueKey('card')),
    ).where((c) => c.$2 == _n(_r(tester).attention)).map((c) => c.$1).toList();
    expect(attention, isNotEmpty);
    for (final text in attention) {
      expect(text, anyOf('Needs you · ', isNot(contains('Approve'))));
    }
    // No attention surface or border.
    for (final box in tester.widgetList<DecoratedBox>(
      find.descendant(
        of: find.byKey(const ValueKey('card')),
        matching: find.byType(DecoratedBox),
      ),
    )) {
      final d = box.decoration;
      if (d is ShapeDecoration) {
        expect(
          d.color == null ? null : _n(d.color!),
          isNot(_n(_r(tester).attentionSurface)),
        );
      }
      if (d is BoxDecoration) {
        expect(
          d.color == null ? null : _n(d.color!),
          isNot(_n(_r(tester).attentionSurface)),
        );
        expect(d.border, isNull);
      }
    }
  });

  testWidgets('5 no red, no amber on blocked, failed and urgent', (
    tester,
  ) async {
    for (final flag in const [
      KitTaskFlag(kind: KitTaskFlagKind.blocked, label: 'Blocked by Sync'),
      KitTaskFlag(kind: KitTaskFlagKind.failed, label: 'Stopped with an error'),
    ]) {
      await _pump(
        tester,
        _card(
          mark: KitTaskState.failed,
          flag: flag,
          meta: const [
            KitTaskMeta('Urgent', priority: KitPriority.urgent, strong: true),
          ],
        ),
      );
      final colours = _paintedColours(
        tester,
        find.byKey(const ValueKey('card')),
      ).map((c) => c.$2);
      expect(colours, isNot(contains(_n(_r(tester).danger))));
      expect(colours, isNot(contains(_n(_r(tester).attention))));
      expect(find.text(flag.label), findsOneWidget);
    }
  });

  testWidgets('6 receipt: replaces the flag, escalates after 8 s', (
    tester,
  ) async {
    await _pump(
      tester,
      _card(
        flag: const KitTaskFlag(kind: KitTaskFlagKind.info, label: 'In Epic'),
        receipt: KitReceipt(
          state: KitReceiptState.sending,
          since: clock.now(),
          onRetry: () {},
        ),
      ),
    );
    expect(find.text('In Epic'), findsNothing);
    expect(find.text('Sending…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
    await tester.pump();
    expect(find.text('Not confirmed yet'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('7 semantics: one node, word read once', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      _card(
        flag: const KitTaskFlag(kind: KitTaskFlagKind.info, label: 'In Epic'),
      ),
    );
    final node = tester.getSemantics(find.byKey(const ValueKey('title')));
    expect(
      node.label,
      'Fix the sync engine. Working. High, Bug, fox, 12 min ago. In Epic',
    );
    expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
    expect(find.bySemanticsLabel('Working'), findsNothing);
    handle.dispose();
  });

  testWidgets('8 truncation: 2 lines at 1.0, 3 at 1.3; meta never cut', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final title = List.filled(60, 'words').join(' ');
    for (final (scale, lines) in [(1.0, 2), (1.3, 3)]) {
      await _pump(tester, _card(title: title), textScale: scale);
      final text = tester.widget<RichText>(
        find.descendant(
          of: find.byKey(const ValueKey('title')),
          matching: find.byType(RichText),
        ),
      );
      expect(text.maxLines, lines);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('title'))).label,
        startsWith(title),
      );
      expect(tester.widget<Tooltip>(find.byType(Tooltip).first).message, title);
      final meta = tester.widget<RichText>(
        find
            .descendant(
              of: find.byKey(const ValueKey('meta')),
              matching: find.byType(RichText),
            )
            .first,
      );
      expect(meta.maxLines, isNull);
    }
    handle.dispose();
  });

  testWidgets('9 wrapper: TeamBoardCardView keeps its keys', (tester) async {
    var moves = 0;
    final now = DateTime(2026, 9, 27, 12);
    final card = TeamBoardCard(
      item: WorkItem(
        id: 'bd-1',
        title: 'Fix sync',
        state: WorkState.working,
        updatedAt: now.subtract(const Duration(minutes: 12)),
      ),
      column: TeamBoardColumn.working,
      priority: WorkPriority.high,
      type: 'bug',
      agentName: 'fox',
    );
    await _pump(
      tester,
      TeamBoardCardView(
        card: card,
        now: now,
        onOpen: () {},
        onMoves: () => moves++,
        onLongPress: () {},
      ),
    );
    expect(find.byType(KitTaskCard), findsOneWidget);
    for (final key in [
      'team-board-card-bd-1',
      'team-board-card-title-bd-1',
      'team-board-card-meta-bd-1',
      'team-board-card-more-bd-1',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
    await tester.tap(find.byKey(const ValueKey('team-board-card-more-bd-1')));
    expect(moves, 1);
  });

  testWidgets('10 priority glyph: bars, dashes, square; no semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const Column(
        children: [
          KitPriorityGlyph(priority: KitPriority.high),
          KitPriorityGlyph(priority: KitPriority.low),
          KitPriorityGlyph(priority: KitPriority.someday),
          KitPriorityGlyph(priority: KitPriority.urgent),
        ],
      ),
    );
    int lit(KitPriority p) => _paintGlyph(
      tester,
      p,
    ).rrects.where((r) => _n(r.$2) == _n(_r(tester).text1)).length;
    expect(lit(KitPriority.high), 3);
    expect(lit(KitPriority.low), 1);
    final someday = _paintGlyph(tester, KitPriority.someday);
    expect(someday.rrects, isEmpty);
    expect(someday.lines, greaterThan(1));
    final urgent = _paintGlyph(tester, KitPriority.urgent);
    expect(_n(urgent.rrects.single.$2), _n(_r(tester).text1));
    expect(
      find.descendant(
        of: find.byType(KitPriorityGlyph).first,
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
    handle.dispose();
  });

  testWidgets('11 no overflow at 320/412, text 1.0/1.3/2.0, LTR/RTL', (
    tester,
  ) async {
    for (final width in [320.0, 412.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final direction in TextDirection.values) {
          await _pump(
            tester,
            _card(
              title: 'A long task title that wraps over more than one line',
              flag: const KitTaskFlag(
                kind: KitTaskFlagKind.blocked,
                label: 'Blocked by Sync engine + 2 more',
              ),
              action: KitAction(
                label: 'Move or change',
                icon: AppIconography.swap,
                onPressed: () {},
              ),
            ),
            width: width,
            textScale: scale,
            direction: direction,
          );
          expect(tester.takeException(), isNull);
          expect(tester.binding.hasScheduledFrame, isFalse);
        }
      }
    }
  });

  // Real faces for the line-break case (the test font is one em per
  // glyph, which breaks "12 min ago" by width alone). Last, so the tests
  // above keep the test font.
  group('with the app fonts', () {
    setUpAll(loadKitGalleryFonts);

    testWidgets('12 meta pieces stay whole at text 2.0: "12 min ago" moves to '
        'the next line as one, and a glyph stays with its word', (
      tester,
    ) async {
      for (final width in [320.0, 412.0]) {
        await _pump(
          tester,
          _card(
            meta: const [
              KitTaskMeta('High', priority: KitPriority.high, strong: true),
              KitTaskMeta('Bug', icon: AppIconography.bug),
              KitTaskMeta('fox'),
              KitTaskMeta('12 min ago'),
            ],
            // The gallery's card: the action narrows the words' column.
            action: KitAction(
              label: 'Move or change',
              icon: AppIconography.swap,
              onPressed: () {},
            ),
          ),
          width: width,
          textScale: 2,
        );
        final meta = find.byKey(const ValueKey('meta'));
        Finder piece(String label) => find.descendant(
          of: meta,
          matching: find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText() == label,
          ),
        );
        // Each piece keeps its words on one line.
        for (final label in ['High', 'Bug', 'fox', '12 min ago']) {
          final paragraph = tester.renderObject<RenderParagraph>(piece(label));
          final tops = {
            for (final box in paragraph.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: label.length),
            ))
              box.top,
          };
          expect(tops, hasLength(1), reason: '"$label" breaks at $width dp');
        }
        // The type glyph shares the line of its word.
        final glyph = tester.getRect(
          find.descendant(of: meta, matching: find.byType(KitIcon)),
        );
        final bug = tester.getRect(piece('Bug'));
        expect(
          glyph.top < bug.bottom && bug.top < glyph.bottom,
          isTrue,
          reason: 'glyph split from "Bug" at $width dp',
        );
        expect(glyph.right, lessThanOrEqualTo(bug.left));
        expect(tester.takeException(), isNull);
      }
    });
  });
}
