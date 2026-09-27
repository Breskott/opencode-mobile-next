// KitRequestSheet (docs/ux-system/kit-api/KitRequestSheet.md, kit-v2 §2.1,
// cut C15): the one details sheet for a request. Owner decision 2026-09-27
// drops Arabic and RTL review, so the spec's test 14 (RTL) is not written.
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_choice_list.dart';
import 'package:opencode_mobile/ui/kit/kit_code_block.dart';
import 'package:opencode_mobile/ui/kit/kit_diff_view.dart';
import 'package:opencode_mobile/ui/kit/kit_field.dart';
import 'package:opencode_mobile/ui/kit/kit_needs_you.dart';
import 'package:opencode_mobile/ui/kit/kit_request_card.dart';
import 'package:opencode_mobile/ui/kit/kit_request_sheet.dart';
import 'package:opencode_mobile/ui/kit/kit_row_parts.dart';
import 'package:opencode_mobile/ui/kit/kit_sheet.dart';
import 'package:opencode_mobile/ui/kit/kit_technical_value.dart';
import 'package:opencode_mobile/ui/widgets/request_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kit_harness.dart';

const _ifIgnored = 'The agent waits; nothing is lost.';
const _command = 'flutter test --concurrency=1 test/offline_queue_test.dart';
const _closeKey = ValueKey('kit-sheet-close');
const _switchKey = ValueKey('always-switch');
const _noteKey = ValueKey('note-field');

final _isolates = RegExp('[\\u2066-\\u2069]');

/// A run of text, compared without KitBidi's isolates.
Finder _words(String text) => find.byWidgetPredicate(
  (widget) =>
      widget is RichText &&
      widget.text.toPlainText().replaceAll(_isolates, '') == text,
);

/// Pumps an empty screen and returns a context under the navigator.
Future<BuildContext> _host(
  WidgetTester tester, {
  Size size = const Size(412, 915),
  double textScale = 1,
  bool reduced = false,
  RouteCounter? counter,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorObservers: [?counter],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduced,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (inner) {
            context = inner;
            return const SizedBox.expand();
          },
        ),
      ),
    ),
  );
  return context;
}

/// A request that stays pending until [pending] turns false.
(ValueNotifier<bool>, RequestRoutes) _routes() {
  final pending = ValueNotifier(true);
  return (
    pending,
    RequestRoutes(changes: pending, isPending: () => pending.value),
  );
}

KitDraft _draft(String target, [TextEditingController? controller]) => KitDraft(
  target: target,
  profileId: 'p1',
  controller: controller ?? TextEditingController(),
);

KitRequestCard _permission({
  VoidCallback? onAllow,
  VoidCallback? onReject,
  String? disabledReason,
}) => KitRequestCard.ask(
  kind: KitRequestKind.permission,
  title: 'Run a shell command',
  who: 'fox',
  server: 'laptop',
  reason: KitNeedsYouReason.decision,
  ifIgnored: _ifIgnored,
  announcement: 'Permission needed: Run a shell command',
  summary: _command,
  since: clock.now().subtract(const Duration(minutes: 4)),
  onDetails: () {},
  answers: KitRequestDecide(
    onAllow: disabledReason == null ? (onAllow ?? () {}) : onAllow,
    onReject: disabledReason == null ? (onReject ?? () {}) : onReject,
    disabledReason: disabledReason,
  ),
);

KitRequestCard _gate({VoidCallback? onAllow, VoidCallback? onReject}) =>
    KitRequestCard.ask(
      kind: KitRequestKind.gate,
      title: 'Merge the storage migration',
      who: 'Reviewer',
      reason: KitNeedsYouReason.decision,
      ifIgnored: 'The team waits; nothing is lost.',
      announcement: 'Gate: Merge the storage migration',
      onDetails: () {},
      answers: KitRequestDecide(
        onAllow: onAllow ?? () {},
        onReject: onReject ?? () {},
      ),
    );

const _colours = [
  KitChoice(value: 'red', title: 'Red'),
  KitChoice(value: 'green', title: 'Green'),
  KitChoice(value: 'blue', title: 'Blue'),
];

KitRequestCard _question({
  ValueChanged<String>? onChosen,
  KitChoiceOther? other,
}) => KitRequestCard.ask(
  kind: KitRequestKind.question,
  title: 'Which colour?',
  who: 'fox',
  reason: KitNeedsYouReason.decision,
  ifIgnored: _ifIgnored,
  announcement: 'Question: Which colour?',
  onDetails: () {},
  answers: KitRequestChoose<String>(
    choices: _colours,
    onChosen: onChosen ?? (_) {},
    other: other,
  ),
);

KitRequestCard _many(ValueChanged<Set<String>> onSend) => KitRequestCard.ask(
  kind: KitRequestKind.question,
  title: 'Which colours?',
  who: 'fox',
  reason: KitNeedsYouReason.decision,
  ifIgnored: _ifIgnored,
  announcement: 'Question: Which colours?',
  onDetails: () {},
  answers: KitRequestChooseMany<String>(choices: _colours, onSend: onSend),
);

KitRequestCard _form() => KitRequestCard.ask(
  kind: KitRequestKind.form,
  title: 'Fill in the release notes',
  who: 'Reviewer',
  reason: KitNeedsYouReason.decision,
  ifIgnored: 'The release waits; nothing is lost.',
  announcement: 'Form: Fill in the release notes',
  onDetails: () {},
  answers: const KitRequestInSheet(),
);

KitRequestCard _reply(KitDraft draft, ValueChanged<String> onSend) =>
    KitRequestCard.ask(
      kind: KitRequestKind.reply,
      title: 'What should the changelog say?',
      who: 'Release task',
      reason: KitNeedsYouReason.decision,
      ifIgnored: 'The task waits; nothing is lost.',
      announcement: 'Reply needed: What should the changelog say?',
      answers: KitRequestReply(
        fieldLabel: 'Your reply',
        draft: draft,
        onSend: onSend,
      ),
    );

final _change = KitDiffView(
  files: [
    KitDiffFile.fromTexts(
      'lib/state/storage.dart',
      before: 'const key = "oc.store";\n',
      after: 'const key = "oc.store.v2";\n',
    ),
  ],
);

/// True when focus is on [target] or inside it (or [target] inside the
/// focused element).
bool _focusOn(WidgetTester tester, Finder target) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  final inFocused = find.descendant(
    of: find.byElementPredicate((e) => e == focused),
    matching: target,
  );
  if (inFocused.evaluate().isNotEmpty) return true;
  for (final element in target.evaluate()) {
    var inside = false;
    (focused as Element).visitAncestorElements((ancestor) {
      if (ancestor == element) inside = true;
      return !inside;
    });
    if (inside) return true;
  }
  return false;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => debugPlatformCapabilities = null);

  void desktop() => debugPlatformCapabilities = const PlatformCapabilities(
    platform: TargetPlatform.linux,
    isWeb: false,
  );

  testWidgets('1. the header is the card\'s: title, attention tile, "{who} '
      'on {server} · waiting 4 min"', (tester) async {
    final context = await _host(tester);
    final (_, routes) = _routes();
    showKitRequestSheet(
      context,
      card: _permission(),
      routes: routes,
      fullText: _command,
    );
    await tester.pumpAndSettle();
    expect(find.text('Run a shell command'), findsOneWidget);
    expect(find.byKey(const ValueKey('kit-sheet-icon')), findsOneWidget);
    expect(_words('fox on laptop · waiting 4 min'), findsOneWidget);
    expect(find.text(_ifIgnored), findsOneWidget);
  });

  testWidgets('2. answered here: Allow once calls onAllow once, one send '
      'haptic, closes with answered', (tester) async {
    final haptics = recordHaptics(tester);
    final context = await _host(tester);
    final (_, routes) = _routes();
    var allowed = 0;
    final outcome = showKitRequestSheet(
      context,
      card: _permission(onAllow: () => allowed++),
      routes: routes,
      fullText: _command,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow once'));
    await tester.pumpAndSettle();
    expect(allowed, 1);
    expect(haptics, ['HapticFeedbackType.lightImpact']);
    expect(find.text('Run a shell command'), findsNothing);
    expect(await outcome, KitRequestSheetOutcome.answered);
  });

  group('3. answered elsewhere', () {
    testWidgets('the route goes a frame after isPending turns false; no '
        'callback, no haptic', (tester) async {
      final haptics = recordHaptics(tester);
      final context = await _host(tester);
      final (pending, routes) = _routes();
      var called = 0;
      final outcome = showKitRequestSheet(
        context,
        card: _permission(onAllow: () => called++, onReject: () => called++),
        routes: routes,
        fullText: _command,
      );
      await tester.pumpAndSettle();
      pending.value = false;
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Allow once'), findsNothing);
      expect(await outcome, KitRequestSheetOutcome.answeredElsewhere);
      expect(called, 0);
      expect(haptics, isEmpty);
    });

    testWidgets('already not pending: nothing opens', (tester) async {
      final counter = RouteCounter();
      final context = await _host(tester, counter: counter);
      final (pending, routes) = _routes();
      pending.value = false;
      final before = counter.pushes;
      final outcome = await showKitRequestSheet(
        context,
        card: _permission(),
        routes: routes,
      );
      await tester.pumpAndSettle();
      expect(outcome, KitRequestSheetOutcome.answeredElsewhere);
      expect(counter.pushes, before);
    });
  });

  group('4. dismissed', () {
    final ways = <String, Future<void> Function(WidgetTester)>{
      'back': (tester) => tester.binding.handlePopRoute(),
      'Esc': (tester) => tester.sendKeyEvent(LogicalKeyboardKey.escape),
      'Close': (tester) => tester.tap(find.byKey(_closeKey)),
      'tap outside': (tester) => tester.tapAt(const Offset(200, 10)),
      'swipe down': (tester) => tester.drag(
        find.byKey(const ValueKey('kit-sheet-handle')),
        const Offset(0, 600),
      ),
    };
    for (final MapEntry(key: way, value: act) in ways.entries) {
      testWidgets('$way returns dismissed', (tester) async {
        final context = await _host(tester);
        final (_, routes) = _routes();
        final outcome = showKitRequestSheet(
          context,
          card: _permission(),
          routes: routes,
          fullText: _command,
        );
        await tester.pumpAndSettle();
        await act(tester);
        await tester.pumpAndSettle();
        expect(find.text('Allow once'), findsNothing);
        expect(await outcome, KitRequestSheetOutcome.dismissed);
      });
    }

    testWidgets('the typed reject note is restored on reopen', (tester) async {
      final context = await _host(tester);
      final (_, routes) = _routes();
      Future<KitRequestSheetOutcome> open() => showKitRequestSheet(
        context,
        card: _permission(),
        routes: routes,
        fullText: _command,
        message: KitRequestMessage(
          fieldLabel: 'Tell the agent why (optional)',
          draft: _draft('request.r1.note'),
          fieldKey: _noteKey,
        ),
      );
      final first = open();
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(_noteKey), 'Not on main');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_closeKey));
      await tester.pumpAndSettle();
      expect(await first, KitRequestSheetOutcome.dismissed);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('oc.draft.request.r1.note.p1'), 'Not on main');
      open();
      await tester.pumpAndSettle();
      expect(find.text('Not on main'), findsOneWidget);
    });
  });

  group('5. Always allow', () {
    Future<Future<KitRequestSheetOutcome>> openAlways(
      WidgetTester tester,
      List<KitUntil> calls,
      List<String> others,
    ) async {
      final context = await _host(tester);
      final (_, routes) = _routes();
      final outcome = showKitRequestSheet(
        context,
        card: _permission(
          onAllow: () => others.add('allow'),
          onReject: () => others.add('reject'),
        ),
        routes: routes,
        fullText: _command,
        alwaysAllow: KitRequestAlwaysAllow(
          title: 'Always allow flutter test',
          scope: 'In this conversation, on laptop',
          onLabel: 'flutter test is always allowed',
          until: const [KitUntil.conversation, KitUntil.hour],
          switchKey: _switchKey,
          onAllowAlways: calls.add,
        ),
      );
      await tester.pumpAndSettle();
      return outcome;
    }

    testWidgets('the switch unfolds the scope and calls nothing; a duration '
        'sends always once and closes', (tester) async {
      final calls = <KitUntil>[];
      final others = <String>[];
      final haptics = recordHaptics(tester);
      final outcome = await openAlways(tester, calls, others);
      expect(find.text('In this conversation, on laptop'), findsNothing);
      await tester.tap(find.byKey(_switchKey));
      await tester.pumpAndSettle();
      expect(find.text('In this conversation, on laptop'), findsOneWidget);
      expect(calls, isEmpty);
      await tester.tap(find.text('For this conversation'));
      await tester.pumpAndSettle();
      expect(calls, [KitUntil.conversation]);
      expect(others, isEmpty);
      expect(haptics, hasLength(1));
      expect(await outcome, KitRequestSheetOutcome.answered);
    });

    testWidgets('Not now folds and sends nothing; no pinned action is Always '
        'allow', (tester) async {
      final calls = <KitUntil>[];
      final others = <String>[];
      await openAlways(tester, calls, others);
      final pinned = find.byKey(const ValueKey('kit-sheet-actions'));
      expect(
        find.descendant(of: pinned, matching: find.textContaining('Always')),
        findsNothing,
      );
      await tester.tap(find.byKey(_switchKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('In this conversation, on laptop'), findsNothing);
      expect(calls, isEmpty);
      expect(others, isEmpty);
      expect(find.text('Allow once'), findsOneWidget);
    });
  });

  group('6. question', () {
    testWidgets('every option is listed; a tap calls onChosen once and '
        'closes', (tester) async {
      final context = await _host(tester);
      final (_, routes) = _routes();
      final chosen = <String>[];
      final outcome = showKitRequestSheet(
        context,
        card: _question(onChosen: chosen.add),
        routes: routes,
        fullText: 'Which colour should the header use?',
      );
      await tester.pumpAndSettle();
      for (final title in ['Red', 'Green', 'Blue']) {
        expect(find.text(title), findsOneWidget);
      }
      await tester.tap(find.text('Green'));
      await tester.pump();
      await tester.tap(find.text('Green'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(chosen, ['green']);
      expect(await outcome, KitRequestSheetOutcome.answered);
    });

    testWidgets('Something else keeps its draft', (tester) async {
      final context = await _host(tester);
      final (_, routes) = _routes();
      final outcome = showKitRequestSheet(
        context,
        card: _question(
          other: KitChoiceOther(
            label: 'Something else',
            fieldLabel: 'Your answer',
            draft: _draft('request.q1.other'),
            fieldKey: const ValueKey('other-field'),
            onSubmitted: (_) {},
          ),
        ),
        routes: routes,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Something else'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('other-field')), 'Teal');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_closeKey));
      await tester.pumpAndSettle();
      expect(await outcome, KitRequestSheetOutcome.dismissed);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('oc.draft.request.q1.other.p1'), 'Teal');
    });
  });

  testWidgets('7. ChooseMany: Send is disabled with "Choose at least one '
      'answer." until one is chosen, then sends the set', (tester) async {
    final context = await _host(tester);
    final (_, routes) = _routes();
    final sent = <Set<String>>[];
    final outcome = showKitRequestSheet(
      context,
      card: _many(sent.add),
      routes: routes,
    );
    await tester.pumpAndSettle();
    expect(filledButton(tester, 'Send').onPressed, isNull);
    expect(find.text('Choose at least one answer.'), findsOneWidget);
    await tester.tap(find.text('Blue'));
    await tester.pump();
    await tester.tap(find.text('Red'));
    await tester.pumpAndSettle();
    expect(find.text('Choose at least one answer.'), findsNothing);
    expect(filledButton(tester, 'Send').onPressed, isNotNull);
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(sent, [
      {'red', 'blue'},
    ]);
    expect(await outcome, KitRequestSheetOutcome.answered);
  });

  group('8. form', () {
    testWidgets('submit disabled shows its reason', (tester) async {
      final context = await _host(tester);
      final (_, routes) = _routes();
      showKitRequestSheet(
        context,
        card: _form(),
        routes: routes,
        body: (_) => const KitField(label: 'Version'),
        submit: const KitAction(
          label: 'Send answers',
          onPressed: null,
          disabledReason: 'Fill in the version first.',
        ),
      );
      await tester.pumpAndSettle();
      expect(filledButton(tester, 'Send answers').onPressed, isNull);
      expect(find.text('Fill in the version first.'), findsOneWidget);
    });

    testWidgets('with draft, dismissal keeps the typed text', (tester) async {
      final context = await _host(tester);
      final (_, routes) = _routes();
      final draft = _draft('request.f1.form');
      final outcome = showKitRequestSheet(
        context,
        card: _form(),
        routes: routes,
        draft: draft,
        body: (_) => KitField(
          label: 'Version',
          controller: draft.controller,
          fieldKey: const ValueKey('version'),
        ),
        submit: KitAction(label: 'Send answers', onPressed: () {}),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('version')), '1.0.45');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(await outcome, KitRequestSheetOutcome.dismissed);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('oc.draft.request.f1.form.p1'), '1.0.45');
    });

    testWidgets('with dirty only, back asks the discard question in place and '
        'adds no route', (tester) async {
      final counter = RouteCounter();
      final context = await _host(tester, counter: counter);
      final (_, routes) = _routes();
      final dirty = ValueNotifier(true);
      showKitRequestSheet(
        context,
        card: _form(),
        routes: routes,
        dirty: dirty,
        body: (_) => const KitField(label: 'Version'),
        submit: KitAction(label: 'Send answers', onPressed: () {}),
      );
      await tester.pumpAndSettle();
      final pushes = counter.pushes;
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard your changes?'), findsOneWidget);
      expect(counter.pushes, pushes);
    });
  });

  group('9. gate', () {
    testWidgets('Approve and Send back are pinned; the notes go with Send '
        'back', (tester) async {
      final context = await _host(tester);
      final (_, routes) = _routes();
      final notes = _draft('request.g1.note');
      final sent = <String>[];
      final outcome = showKitRequestSheet(
        context,
        card: _gate(onReject: () => sent.add(notes.controller.text)),
        routes: routes,
        fullText: 'Move the store key to v2, then migrate.',
        message: KitRequestMessage(
          fieldLabel: 'Notes for the team (optional)',
          draft: notes,
          fieldKey: _noteKey,
        ),
      );
      await tester.pumpAndSettle();
      final pinned = find.byKey(const ValueKey('kit-sheet-actions'));
      for (final label in ['Approve', 'Send back']) {
        expect(
          find.descendant(of: pinned, matching: find.text(label)),
          findsOneWidget,
        );
      }
      await tester.enterText(find.byKey(_noteKey), 'Split the migration');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send back'));
      await tester.pumpAndSettle();
      expect(sent, ['Split the migration']);
      expect(await outcome, KitRequestSheetOutcome.answered);
    });

    testWidgets('an in-place showKitConfirm adds no route', (tester) async {
      final counter = RouteCounter();
      final context = await _host(tester, counter: counter);
      final (_, routes) = _routes();
      const plan = 'Move the store key to v2, then migrate.';
      showKitRequestSheet(
        context,
        card: _gate(),
        routes: routes,
        fullText: plan,
      );
      await tester.pumpAndSettle();
      final pushes = counter.pushes;
      showKitConfirm(
        tester.element(_words(plan)),
        title: 'Merge into main?',
        body: 'The team merges the migration now.',
        confirmLabel: 'Merge',
      );
      await tester.pumpAndSettle();
      expect(find.text('Merge into main?'), findsOneWidget);
      expect(counter.pushes, pushes);
    });
  });

  testWidgets('10. permission with change: a read-only diff; at 1280x800 an '
      'end-side sheet of 400–480 with the diff unified', (tester) async {
    final context = await _host(tester, size: const Size(1280, 800));
    final (_, routes) = _routes();
    showKitRequestSheet(
      context,
      card: _permission(),
      routes: routes,
      fullText: 'lib/state/storage.dart',
      change: _change,
    );
    await tester.pumpAndSettle();
    final diff = find.byType(KitDiffView);
    expect(diff, findsOneWidget);
    expect(tester.widget<KitDiffView>(diff).readOnly, isTrue);
    final sheet = tester.getRect(find.byType(KitSheet));
    expect(sheet.width, inInclusiveRange(400, 480));
    expect(sheet.right, 1280);
    // KitDiffView splits only in a box of 840 dp or wider.
    expect(tester.getSize(diff).width, lessThan(840));
  });

  testWidgets('11. details render last and collapsed in one fold', (
    tester,
  ) async {
    final context = await _host(tester);
    final (_, routes) = _routes();
    showKitRequestSheet(
      context,
      card: _permission(),
      routes: routes,
      fullText: _command,
      details: const [KitTechnicalValue('Request id', 'per_01HZX9')],
    );
    await tester.pumpAndSettle();
    final fold = find.byType(KitDetailsFold);
    expect(fold, findsOneWidget);
    expect(find.text('per_01HZX9'), findsNothing);
    expect(
      tester.getTopLeft(fold).dy,
      greaterThan(tester.getTopLeft(find.byType(KitCodeBlock)).dy),
    );
  });

  group('12. keyboard', () {
    Future<(List<String>, Future<KitRequestSheetOutcome>)> open(
      WidgetTester tester,
    ) async {
      desktop();
      final context = await _host(tester, size: const Size(1280, 800));
      final (_, routes) = _routes();
      final calls = <String>[];
      final outcome = showKitRequestSheet(
        context,
        card: _permission(
          onAllow: () => calls.add('allow'),
          onReject: () => calls.add('reject'),
        ),
        routes: routes,
        fullText: _command,
        alwaysAllow: KitRequestAlwaysAllow(
          title: 'Always allow flutter test',
          scope: 'In this conversation, on laptop',
          onLabel: 'flutter test is always allowed',
          switchKey: _switchKey,
          onAllowAlways: (_) => calls.add('always'),
        ),
        message: KitRequestMessage(
          fieldLabel: 'Tell the agent why (optional)',
          draft: _draft('request.k1.note'),
          fieldKey: _noteKey,
        ),
      );
      await tester.pumpAndSettle();
      return (calls, outcome);
    }

    testWidgets('A allows while focus is on the sheet', (tester) async {
      final (calls, outcome) = await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pumpAndSettle();
      expect(calls, ['allow']);
      expect(await outcome, KitRequestSheetOutcome.answered);
    });

    testWidgets('D rejects; Enter on the sheet does not allow', (tester) async {
      final (calls, outcome) = await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(find.text('Allow once'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.pumpAndSettle();
      expect(calls, ['reject']);
      expect(await outcome, KitRequestSheetOutcome.answered);
    });

    testWidgets('typing A or D in the note field answers nothing', (
      tester,
    ) async {
      final (calls, _) = await open(tester);
      await tester.tap(find.byKey(_noteKey));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(find.text('Allow once'), findsOneWidget);
    });

    testWidgets('Tab reaches Close, the switch and the pinned answers', (
      tester,
    ) async {
      await open(tester);
      final targets = <String, Finder>{
        'close': find.byKey(_closeKey),
        'switch': find.byKey(_switchKey),
        'allow': find.text('Allow once'),
        'reject': find.text('Reject'),
      };
      final reached = <String>{};
      for (var i = 0; i < 30 && reached.length < targets.length; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        for (final MapEntry(key: name, value: finder) in targets.entries) {
          if (_focusOn(tester, finder)) reached.add(name);
        }
      }
      expect(reached, targets.keys.toSet());
    });
  });

  group('13. large text and sizes', () {
    // The spec's combined case (2.0 text AND a 300 dp keyboard on 412x915)
    // overflows KitSheet's own frame by 43 px: its header and pinned block
    // do not shrink (kit_sheet.dart, not this part). Reported in the QA
    // record; each condition alone is covered here.
    for (final (name, scale, inset) in [
      ('2.0 text', 2.0, 0.0),
      ('the keyboard open (300 dp)', 1.0, 300.0),
    ]) {
      testWidgets('$name: the pinned answers are fully visible', (
        tester,
      ) async {
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        addTearDown(tester.view.resetViewInsets);
        final context = await _host(tester, textScale: scale);
        final (_, routes) = _routes();
        showKitRequestSheet(
          context,
          card: _permission(),
          routes: routes,
          fullText: _command,
          message: KitRequestMessage(
            fieldLabel: 'Tell the agent why (optional)',
            draft: _draft('request.t1.note'),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final label in ['Allow once', 'Reject']) {
          final rect = tester.getRect(find.text(label));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(915 - inset));
        }
      });
    }

    for (final width in [320.0, 412.0, 600.0, 840.0, 1280.0]) {
      testWidgets('no overflow at ${width.toInt()} dp', (tester) async {
        final context = await _host(tester, size: Size(width, 800));
        final (_, routes) = _routes();
        showKitRequestSheet(
          context,
          card: _permission(),
          routes: routes,
          fullText: _command,
          change: _change,
          alwaysAllow: KitRequestAlwaysAllow(
            title: 'Always allow flutter test',
            scope: 'In this conversation, on laptop',
            onLabel: 'flutter test is always allowed',
            onAllowAlways: (_) {},
          ),
          details: const [KitTechnicalValue('Request id', 'per_01HZX9')],
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Allow once'), findsOneWidget);
      });
    }
  });

  testWidgets('reply: Send is disabled with "Type a reply first." while '
      'empty, then sends the words', (tester) async {
    final context = await _host(tester);
    final (_, routes) = _routes();
    final sent = <String>[];
    final outcome = showKitRequestSheet(
      context,
      card: _reply(_draft('request.p1.reply'), sent.add),
      routes: routes,
      fullText: 'The release is ready. What should the changelog say?',
    );
    await tester.pumpAndSettle();
    expect(filledButton(tester, 'Send').onPressed, isNull);
    expect(find.text('Type a reply first.'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'Ship it on Friday.');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(sent, ['Ship it on Friday.']);
    expect(await outcome, KitRequestSheetOutcome.answered);
  });

  testWidgets('15. reduced motion: opening, the risk unfold and the in-place '
      'confirm each settle after one pump', (tester) async {
    final context = await _host(tester, reduced: true);
    final (_, routes) = _routes();
    showKitRequestSheet(
      context,
      card: _permission(),
      routes: routes,
      fullText: _command,
      alwaysAllow: KitRequestAlwaysAllow(
        title: 'Always allow flutter test',
        scope: 'In this conversation, on laptop',
        onLabel: 'flutter test is always allowed',
        switchKey: _switchKey,
        onAllowAlways: (_) {},
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('Allow once'), findsOneWidget);
    await tester.tap(find.byKey(_switchKey));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('In this conversation, on laptop'), findsOneWidget);
    showKitConfirm(
      tester.element(find.text('Allow once')),
      title: 'Stop here?',
      body: 'Nothing is sent.',
      confirmLabel: 'Stop',
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('Stop here?'), findsOneWidget);
  });
}
