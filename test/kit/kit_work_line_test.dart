// KitWorkLine (docs/ux-system/kit-api/KitWorkLine.md): the frozen "Tests
// required" contract, the reduced-motion sample (G8x) and the keyboard
// behaviour (G14). Arabic plural checks are not run: owner decision
// 2026-09-27 dropped Arabic (no Arabic copy for new keys).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/chat/kit_work_line.dart';
import 'package:opencode_mobile/ui/kit/kit_status_mark.dart';

const _lineKey = ValueKey('work-group-header');
const _stepsKey = ValueKey('work-group-steps');

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
  bool reduceMotion = true,
  Size size = const Size(412, 915),
  TextDirection? direction,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, widget) {
        Widget body = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: widget!,
        );
        if (direction != null) {
          body = Directionality(textDirection: direction, child: body);
        }
        return body;
      },
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Align(alignment: AlignmentDirectional.topStart, child: child),
        ),
      ),
    ),
  );
}

List<Widget> _steps(int n) => [
  for (var i = 0; i < n; i++)
    SizedBox(
      key: ValueKey('step-$i'),
      height: 24,
      child: Text('Step number $i'),
    ),
];

Widget _line({
  KitWorkState state = KitWorkState.done,
  KitWorkCounts counts = const KitWorkCounts(read: 3, edited: 1),
  List<Widget>? steps,
  String? now,
  bool? expanded,
  ValueChanged<bool>? onExpansionChanged,
}) => KitWorkLine(
  counts: counts,
  state: state,
  steps: steps ?? _steps(3),
  now: now,
  expanded: expanded,
  onExpansionChanged: onExpansionChanged,
  lineKey: _lineKey,
  stepsKey: _stepsKey,
);

/// The summary for [counts] as the part says it, in English.
Future<String> _summary(WidgetTester tester, KitWorkCounts counts) async {
  late String out;
  await _pump(
    tester,
    Builder(
      builder: (context) {
        out = KitWorkLine.summaryOf(context, counts);
        return const SizedBox();
      },
    ),
  );
  return out;
}

/// The chip's one button node: the Semantics KitWorkLine wraps its chip in.
final _chipNode = find
    .ancestor(of: find.byKey(_lineKey), matching: find.byType(Semantics))
    .first;

void main() {
  group('summaryOf (1)', () {
    testWidgets('read 3 + edited 1', (tester) async {
      expect(
        await _summary(tester, const KitWorkCounts(read: 3, edited: 1)),
        'Read 3 files · edited 1 file',
      );
    });
    testWidgets('one segment only', (tester) async {
      expect(
        await _summary(tester, const KitWorkCounts(ran: 2)),
        'Ran 2 commands',
      );
    });
    testWidgets('no counted call falls back to steps', (tester) async {
      expect(await _summary(tester, const KitWorkCounts(steps: 4)), '4 steps');
    });
    testWidgets('every segment, singular, in order', (tester) async {
      expect(
        await _summary(
          tester,
          const KitWorkCounts(
            read: 1,
            searched: 1,
            listed: 1,
            edited: 1,
            ran: 1,
            fetched: 1,
            delegated: 1,
            other: 1,
            notRun: 1,
            steps: 9,
          ),
        ),
        'Read 1 file · searched once · listed 1 folder · edited 1 file · '
        'ran 1 command · fetched 1 page · delegated 1 task · 1 other step · '
        '1 not run',
      );
    });
    test('isEmpty', () {
      expect(const KitWorkCounts().isEmpty, isTrue);
      expect(const KitWorkCounts(steps: 1).isEmpty, isFalse);
      expect(const KitWorkCounts(notRun: 1).isEmpty, isFalse);
    });
  });

  group('states (2, 3)', () {
    testWidgets('running shows the live words and a working mark', (
      tester,
    ) async {
      await _pump(
        tester,
        _line(state: KitWorkState.running, now: 'Editing main.dart'),
      );
      expect(find.text('Editing main.dart'), findsOneWidget);
      final marks = tester.widgetList<KitStatusMark>(
        find.byType(KitStatusMark),
      );
      expect(marks.map((m) => m.state), [KitMarkState.working]);
    });

    testWidgets('running without now falls back to the summary', (
      tester,
    ) async {
      await _pump(tester, _line(state: KitWorkState.running));
      expect(find.text('Read 3 files · edited 1 file'), findsOneWidget);
    });

    testWidgets('waitingForYou: the words, no mark, no progress anywhere '
        '(AUTO-15)', (tester) async {
      await _pump(
        tester,
        _line(
          state: KitWorkState.waitingForYou,
          now: 'Running tools',
          expanded: true,
        ),
        reduceMotion: false,
      );
      expect(find.text('Waiting for you'), findsOneWidget);
      expect(find.text('Running tools'), findsNothing);
      expect(find.byType(KitStatusMark), findsNothing);
      expect(find.byType(ProgressIndicator), findsNothing);
    });

    testWidgets('done: the summary and no mark', (tester) async {
      await _pump(tester, _line());
      expect(find.text('Read 3 files · edited 1 file'), findsOneWidget);
      expect(find.byType(KitStatusMark), findsNothing);
      expect(find.byKey(_stepsKey), findsNothing);
    });

    testWidgets('stopped says so', (tester) async {
      await _pump(tester, _line(state: KitWorkState.stopped));
      expect(
        find.text('Read 3 files · edited 1 file · Stopped'),
        findsOneWidget,
      );
      expect(find.byType(KitStatusMark), findsNothing);
    });

    testWidgets('endedFailed: failed mark with its word, open on first '
        'build, no danger colour (LOOK-5 interim)', (tester) async {
      await _pump(tester, _line(state: KitWorkState.endedFailed));
      final marks = tester.widgetList<KitStatusMark>(
        find.byType(KitStatusMark),
      );
      expect(marks.map((m) => m.state), [KitMarkState.failed]);
      expect(find.text("Didn't finish"), findsOneWidget);
      expect(find.byKey(_stepsKey), findsOneWidget);

      final theme = AppTheme.dark();
      final roles = ThemeRoles.resolve(theme);
      final forbidden = {
        roles.danger,
        roles.dangerFill,
        theme.colorScheme.error,
      };
      final line = find.byType(KitWorkLine);
      final colours = <Color?>[
        for (final t in tester.widgetList<RichText>(
          find.descendant(of: line, matching: find.byType(RichText)),
        ))
          t.text.style?.color,
        for (final i in tester.widgetList<Icon>(
          find.descendant(of: line, matching: find.byType(Icon)),
        ))
          i.color,
      ];
      expect(colours.where(forbidden.contains), isEmpty);
      expect(
        tester
            .widget<RichText>(
              find
                  .descendant(
                    of: find.text("Didn't finish"),
                    matching: find.byType(RichText),
                  )
                  .first,
            )
            .text
            .style
            ?.color,
        roles.text1,
      );
    });
  });

  group('toggling (4)', () {
    testWidgets('tap toggles an uncontrolled line', (tester) async {
      final changes = <bool>[];
      await _pump(tester, _line(onExpansionChanged: changes.add));
      expect(find.byKey(_stepsKey), findsNothing);
      await tester.tap(find.byKey(_lineKey));
      await tester.pump();
      expect(find.byKey(_stepsKey), findsOneWidget);
      await tester.tap(find.byKey(_lineKey));
      await tester.pump();
      expect(find.byKey(_stepsKey), findsNothing);
      expect(changes, [true, false]);
    });

    testWidgets('controlled never toggles on its own', (tester) async {
      final changes = <bool>[];
      await _pump(
        tester,
        _line(expanded: false, onExpansionChanged: changes.add),
      );
      await tester.tap(find.byKey(_lineKey));
      await tester.pump();
      expect(changes, [true]);
      expect(find.byKey(_stepsKey), findsNothing);

      await _pump(
        tester,
        _line(expanded: true, onExpansionChanged: changes.add),
      );
      await tester.tap(find.byKey(_lineKey));
      await tester.pump();
      expect(changes, [true, false]);
      expect(find.byKey(_stepsKey), findsOneWidget);
    });

    testWidgets('uncontrolled starts from opensByDefault', (tester) async {
      for (final state in KitWorkState.values) {
        await _pump(tester, _line(state: state));
        expect(
          find.byKey(_stepsKey).evaluate().isNotEmpty,
          KitWorkLine.opensByDefault(state),
          reason: '$state',
        );
      }
      expect(KitWorkLine.opensByDefault(KitWorkState.endedFailed), isTrue);
      expect(KitWorkLine.opensByDefault(KitWorkState.done), isFalse);
    });
  });

  testWidgets('opened: steps in order under stepsKey, summary not repeated '
      '(5)', (tester) async {
    await _pump(tester, _line(expanded: true));
    final steps = find.descendant(
      of: find.byKey(_stepsKey),
      matching: find.textContaining('Step number'),
    );
    expect(tester.widgetList<Text>(steps).map((t) => t.data), [
      'Step number 0',
      'Step number 1',
      'Step number 2',
    ]);
    expect(
      find.descendant(
        of: find.byKey(_stepsKey),
        matching: find.textContaining('Read 3 files'),
      ),
      findsNothing,
    );
    expect(find.textContaining('Read 3 files'), findsOneWidget);
  });

  testWidgets('30 steps: 25 built, "Show 5 earlier steps" reveals the rest '
      'in place and focus moves to the first (6)', (tester) async {
    await _pump(tester, _line(expanded: true, steps: _steps(30)));
    expect(find.byKey(const ValueKey('step-4')), findsNothing);
    expect(find.byKey(const ValueKey('step-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('step-29')), findsOneWidget);
    final earlier = find.text('Show 5 earlier steps');
    expect(earlier, findsOneWidget);
    // The earlier-steps row sits above the newest steps.
    expect(
      tester.getTopLeft(earlier).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('step-5'))).dy),
    );

    await tester.tap(earlier);
    await tester.pump();
    await tester.pump();
    expect(find.text('Show 5 earlier steps'), findsNothing);
    for (var i = 0; i < 30; i++) {
      expect(find.byKey(ValueKey('step-$i')), findsOneWidget);
    }
    final first = tester.getTopLeft(find.byKey(const ValueKey('step-0'))).dy;
    expect(
      first,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('step-5'))).dy),
    );
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(focused, isNotNull);
    var holdsStep = false;
    (focused! as Element).visitChildElements((child) {
      void visit(Element e) {
        if (e.widget.key == const ValueKey('step-0')) holdsStep = true;
        e.visitChildElements(visit);
      }

      visit(child);
    });
    expect(holdsStep, isTrue);
  });

  group('motion (7, G8x)', () {
    testWidgets('no size or layout animation in the subtree', (tester) async {
      await _pump(
        tester,
        _line(expanded: true, state: KitWorkState.running),
        reduceMotion: false,
      );
      final line = find.byType(KitWorkLine);
      for (final type in [AnimatedSize, AnimatedContainer, SizeTransition]) {
        expect(
          find.descendant(of: line, matching: find.byType(type)),
          findsNothing,
          reason: '$type',
        );
      }
    });

    testWidgets('reduced motion: one pump settles the opening', (tester) async {
      await _pump(tester, _line());
      await tester.tap(find.byKey(_lineKey));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.byKey(_stepsKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(KitWorkLine),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
    });

    testWidgets('full motion: steps fade in over quick (paint only)', (
      tester,
    ) async {
      await _pump(tester, _line(), reduceMotion: false);
      await tester.tap(find.byKey(_lineKey));
      await tester.pump();
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('step-0')),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, lessThan(1));
      await tester.pumpAndSettle();
      expect(fade.opacity.value, 1);
    });
  });

  group('semantics (8)', () {
    Future<void> expectLabel(
      WidgetTester tester,
      KitWorkState state,
      String label, {
      String? now,
    }) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _line(state: state, now: now));
      final node = tester.getSemantics(_chipNode);
      expect(
        node,
        isSemantics(
          label: label,
          isButton: true,
          hasTapAction: true,
          hasExpandedState: true,
          isExpanded: KitWorkLine.opensByDefault(state),
          isLiveRegion: false,
        ),
        reason: '$state',
      );
      final size = tester.getSize(_chipNode);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      handle.dispose();
    }

    testWidgets('labels per state', (tester) async {
      const summary = 'Read 3 files · edited 1 file';
      await expectLabel(
        tester,
        KitWorkState.running,
        'Working, Editing main.dart',
        now: 'Editing main.dart',
      );
      await expectLabel(
        tester,
        KitWorkState.waitingForYou,
        'Waiting for you, $summary',
      );
      await expectLabel(tester, KitWorkState.done, summary);
      await expectLabel(
        tester,
        KitWorkState.endedFailed,
        "Didn't finish, $summary",
      );
      await expectLabel(tester, KitWorkState.stopped, 'Stopped, $summary');
    });

    testWidgets('the leading mark says nothing of its own', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _line(state: KitWorkState.endedFailed, steps: []));
      expect(find.bySemanticsLabel("Didn't finish"), findsNothing);
      expect(find.bySemanticsLabel(RegExp('^Failed')), findsNothing);
      handle.dispose();
    });
  });

  testWidgets('desktop: Tab reaches the chip, Enter toggles, the focus ring '
      'shows (9)', (tester) async {
    await _pump(
      tester,
      _line(
        steps: [TextButton(onPressed: () {}, child: const Text('Step button'))],
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final ring = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.position == DecorationPosition.foreground &&
          w.decoration is ShapeDecoration,
    );
    expect(
      find.descendant(of: find.byKey(_lineKey), matching: ring),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.byKey(_stepsKey), findsOneWidget);
    // Focus stays on the chip; Tab continues into the steps.
    expect(
      find.descendant(of: find.byKey(_lineKey), matching: ring),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(
      find.ancestor(
        of: find.byWidget(focused!.widget),
        matching: find.byKey(_stepsKey),
      ),
      findsOneWidget,
    );
  });

  group('200 % text at 320 dp (10, G6)', () {
    for (final direction in TextDirection.values) {
      for (final state in KitWorkState.values) {
        testWidgets('$state · ${direction.name}', (tester) async {
          await _pump(
            tester,
            _line(
              state: state,
              expanded: true,
              now: 'Editing lib/ui/screens/chat/message_view.dart',
              counts: const KitWorkCounts(
                read: 12,
                searched: 3,
                edited: 4,
                ran: 2,
                notRun: 1,
              ),
              steps: _steps(30),
            ),
            textScale: 2,
            size: const Size(320, 800),
            direction: direction,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  testWidgets('a running line that ends on a failure opens by itself', (
    tester,
  ) async {
    await _pump(tester, _line(state: KitWorkState.running));
    expect(find.byKey(_stepsKey), findsNothing);
    await _pump(tester, _line(state: KitWorkState.endedFailed));
    expect(find.byKey(_stepsKey), findsOneWidget);
  });

  testWidgets('the steps stroke is one physical pixel at '
      'the start edge', (tester) async {
    await _pump(tester, _line(expanded: true));
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(_stepsKey),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final border =
        (box.decoration as BoxDecoration).border! as BorderDirectional;
    expect(border.start.width, 1.0);
    expect(border.end, BorderSide.none);
    expect(border.top, BorderSide.none);
  });
}
