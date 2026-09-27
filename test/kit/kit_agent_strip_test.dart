// Behaviour tests for KitAgentStrip and KitAgentTint,
// docs/ux-system/kit-api/KitAgentStrip.md "Tests required".
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/chat/kit_agent_strip.dart';
import 'package:opencode_mobile/ui/kit/kit_bidi.dart';
import 'package:opencode_mobile/ui/kit/kit_task_mark.dart';
import 'package:opencode_mobile/ui/kit/kit_tappable.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';
import 'package:opencode_mobile/ui/widgets/agent_color.dart';

import 'kit_motion_still.dart';

Future<void> _pump(
  WidgetTester tester,
  List<KitAgent> agents, {
  Size size = const Size(412, 915),
  double textScale = 1,
  bool reduced = false,
  Locale locale = const Locale('en'),
  Key? stripKey,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: _theme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduced,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Column(
          children: [KitAgentStrip(agents: agents, stripKey: stripKey)],
        ),
      ),
    ),
  );
}

// One theme object for every pump, so re-pumping never starts the host's
// AnimatedTheme lerp (a host animation, not the strip's).
final _theme = AppTheme.dark();

String _n(String name) => KitBidi.auto(name);

List<KitAgent> _team({VoidCallback? open}) => [
  const KitAgent(
    id: 'lead',
    name: 'mayor',
    role: 'Lead',
    state: KitTaskState.working,
  ),
  KitAgent(
    id: 'w1',
    name: 'furiosa',
    role: 'Worker',
    state: KitTaskState.waiting,
    onOpen: open ?? () {},
  ),
  KitAgent(
    id: 'r1',
    name: 'nux',
    role: 'Reviewer',
    state: KitTaskState.done,
    onOpen: open ?? () {},
  ),
];

void main() {
  kitMotionStillTests(
    'KitAgentStrip',
    builds: {
      'mixed': () => KitAgentStrip(agents: _team()),
      'working': () => const KitAgentStrip(
        agents: [
          KitAgent(id: 'lead', name: 'mayor', state: KitTaskState.working),
        ],
      ),
    },
    changes: {
      'agent finishes': KitMotionChange(
        build: () => const KitAgentStrip(
          agents: [
            KitAgent(id: 'lead', name: 'mayor', state: KitTaskState.working),
          ],
        ),
        act: (tester, stage) => stage.rebuild(
          const KitAgentStrip(
            agents: [
              KitAgent(
                id: 'lead',
                name: 'Finished review',
                state: KitTaskState.done,
              ),
            ],
          ),
        ),
        shows: KitBidi.auto('Finished review'),
      ),
    },
  );

  testWidgets('agents render in order; empty renders nothing', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _team());
    final xs = [
      for (final n in ['mayor', 'furiosa', 'nux'])
        tester.getTopLeft(find.text(_n(n))).dx,
    ];
    expect(xs, orderedEquals([...xs]..sort()));

    await _pump(tester, const []);
    expect(find.byType(KitTaskMark), findsNothing);
    expect(find.bySemanticsLabel('Agents on this task'), findsNothing);
    semantics.dispose();
  });

  testWidgets('each state shows its mark; needsYou is KitNeedsYou.mark; '
      'no Transform scales a mark', (tester) async {
    await _pump(tester, [
      for (final s in KitTaskState.values)
        KitAgent(id: s, name: s.name, state: s),
    ]);
    for (final s in KitTaskState.values) {
      expect(
        find.byWidgetPredicate((w) => w is KitTaskMark && w.state == s),
        findsOneWidget,
      );
    }
    final needs = tester.widget<KitTaskMark>(
      find.byWidgetPredicate(
        (w) => w is KitTaskMark && w.state == KitTaskState.needsYou,
      ),
    );
    expect(needs.paused, isFalse);
    expect(needs.label, isNull);
    expect(needs.showLabel, isFalse);
    expect(
      find.ancestor(
        of: find.byType(KitTaskMark),
        matching: find.descendant(
          of: find.byType(KitAgentStrip),
          matching: find.byWidgetPredicate(
            (w) => w is Transform && w.transform.getMaxScaleOnAxis() != 1.0,
          ),
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('onOpen fires on tap, Enter and Space; the lead is not a '
      'button nor a Tab stop', (tester) async {
    var opened = 0;
    await _pump(tester, _team(open: () => opened++));
    await tester.tap(find.text(_n('furiosa')));
    await tester.pump();
    expect(opened, 1);

    // Tab order: the lead is skipped, so the first stop is furiosa.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(opened, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(opened, 3);

    expect(
      find.ancestor(
        of: find.text(_n('mayor')),
        matching: find.byType(KitTappable),
      ),
      findsNothing,
    );
    expect(find.byType(KitTappable), findsNWidgets(2));
  });

  testWidgets('semantics: group, chip words, hint, not live, 48 dp', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, [
      ..._team(),
      KitAgent(
        id: 'x',
        name: 'slit',
        state: KitTaskState.working,
        onOpen: () {},
      ),
    ]);
    expect(find.bySemanticsLabel('Agents on this task'), findsOneWidget);
    final lead = tester.getSemantics(
      find.bySemanticsLabel('${_n('mayor')}, Lead, Working'),
    );
    expect(lead.flagsCollection.isButton, isFalse);
    final worker = tester.getSemantics(
      find.bySemanticsLabel('${_n('furiosa')}, Worker, Waiting'),
    );
    expect(worker.flagsCollection.isButton, isTrue);
    expect(worker.hint, "Open ${_n('furiosa')}'s conversation");
    expect(worker.flagsCollection.isLiveRegion, isFalse);
    // Role omitted when null.
    expect(find.bySemanticsLabel('${_n('slit')}, Working'), findsOneWidget);
    for (final n in ['mayor', 'furiosa', 'nux', 'slit']) {
      final chip = find
          .ancestor(of: find.text(_n(n)), matching: find.byType(DecoratedBox))
          .first;
      expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
    }
    semantics.dispose();
  });

  testWidgets('paused with done asserts; paused working reads Paused', (
    tester,
  ) async {
    expect(
      () =>
          KitAgent(id: 1, name: 'a', state: KitTaskState.done, paused: _true()),
      throwsAssertionError,
    );
    final semantics = tester.ensureSemantics();
    await _pump(tester, const [
      KitAgent(
        id: 1,
        name: 'furiosa',
        role: 'Worker',
        state: KitTaskState.working,
        paused: true,
      ),
    ]);
    expect(
      find.bySemanticsLabel('${_n('furiosa')}, Worker, Paused'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('Working')), findsNothing);
    semantics.dispose();
  });

  List<KitAgent> eight() => [
    for (var i = 0; i < 8; i++)
      KitAgent(
        id: i,
        name: 'agent-number-$i',
        role: i == 0 ? 'Lead' : 'Worker',
        state: KitTaskState.working,
        onOpen: i == 0 ? null : () {},
      ),
  ];

  testWidgets('compact scrolls sideways inside the strip; expanded wraps', (
    tester,
  ) async {
    await _pump(tester, eight());
    expect(tester.takeException(), isNull);
    final scroll = find.descendant(
      of: find.byType(KitAgentStrip),
      matching: find.byType(Scrollable),
    );
    expect(scroll, findsOneWidget);
    expect(
      tester.widget<Scrollable>(scroll).axisDirection,
      AxisDirection.right,
    );
    // Every agent is in the tree (no "+3").
    for (var i = 0; i < 8; i++) {
      expect(find.text(_n('agent-number-$i')), findsOneWidget);
    }

    await _pump(tester, eight(), size: const Size(1280, 800));
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(KitAgentStrip),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
    );
    expect(find.byType(Wrap), findsOneWidget);
    final first = tester.getTopLeft(find.text(_n('agent-number-0'))).dy;
    final last = tester.getTopLeft(find.text(_n('agent-number-7'))).dy;
    expect(last, greaterThan(first)); // wrapped onto a second run
    for (var i = 0; i < 8; i++) {
      expect(find.text(_n('agent-number-$i')), findsOneWidget);
    }
  });

  testWidgets('KitAgentTint is text2; the wrappers return the same neutral', (
    tester,
  ) async {
    await _pump(tester, const []);
    final context = tester.element(find.byType(KitAgentStrip));
    final text2 = KitTokens.of(context).roles.text2;
    final scheme = Theme.of(context).colorScheme;
    for (final raw in [null, '#ff0000', 'red', 'primary', 'nonsense']) {
      expect(KitAgentTint.of(context, name: 'a', serverColor: raw), text2);
      expect(
        KitAgentTint.ofScheme(scheme, name: 'a', serverColor: raw),
        scheme.onSurfaceVariant,
      );
      expect(agentColor(raw, scheme), scheme.onSurfaceVariant);
    }
    expect(scheme.onSurfaceVariant, text2);
    expect(agentColorFor(context, 'build'), text2);
    expect(agentFallbackColor('build', scheme), scheme.onSurfaceVariant);
    final source = File('lib/ui/widgets/agent_color.dart').readAsStringSync();
    expect(source.contains('Colors.'), isFalse);
    expect(source.contains('Color(0x'), isFalse);
  });

  testWidgets('desktop: Tab walks tappable chips into view; tooltip words', (
    tester,
  ) async {
    await _pump(tester, eight());
    for (var i = 1; i < 8; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      // The working marks spin, so settle by time, not pumpAndSettle.
      await tester.pump(const Duration(seconds: 1));
    }
    final last = tester.getRect(find.text(_n('agent-number-7')));
    expect(last.right, lessThanOrEqualTo(412));
    expect(last.left, greaterThanOrEqualTo(0));
    final tips = tester
        .widgetList<Tooltip>(find.byType(Tooltip))
        .map((t) => t.message)
        .toList();
    expect(tips, contains('${_n('agent-number-7')}, Worker, Working'));
    expect(tips, contains('${_n('agent-number-0')}, Lead, Working'));
  });

  testWidgets('reduced motion: a state change settles after one pump', (
    tester,
  ) async {
    await _pump(tester, const [
      KitAgent(id: 1, name: 'furiosa', state: KitTaskState.working),
    ], reduced: true);
    await _pump(tester, const [
      KitAgent(id: 1, name: 'furiosa', state: KitTaskState.done),
      KitAgent(id: 2, name: 'nux', state: KitTaskState.waiting),
    ], reduced: true);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(
      find.byWidgetPredicate(
        (w) => w is KitTaskMark && w.state == KitTaskState.working,
      ),
      findsNothing,
    );
  });

  testWidgets('200% text at 320 dp: no overflow, LTR and RTL', (tester) async {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      await _pump(
        tester,
        [
          ..._team(),
          KitAgent(
            id: 'long',
            name: 'a-very-long-agent-name-that-cannot-possibly-fit-here',
            role: 'Worker',
            state: KitTaskState.needsYou,
            onOpen: () {},
          ),
        ],
        size: const Size(320, 800),
        textScale: 2,
        locale: locale,
      );
      expect(tester.takeException(), isNull);
    }
  });
}

// Keeps the analyzer from folding the assert into a const error.
bool _true() => true;
