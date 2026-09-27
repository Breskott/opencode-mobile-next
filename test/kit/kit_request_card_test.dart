// KitRequestCard v2 (docs/ux-system/kit-api/KitRequestCard.md, kit-v2
// §2.1; P4.1a): the one answer card for everything an agent asks. Time runs
// on the fake clock testWidgets drives, through KitSince and KitReceipt.
//
// Announcements are counted on the semantics updates the framework sends to
// the engine (the pattern of kit_receipt_test.dart): a label a live-region
// node is sent that differs from the one it was last sent is what Android's
// live region announces.
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_choice_list.dart';
import 'package:opencode_mobile/ui/kit/kit_field.dart';
import 'package:opencode_mobile/ui/kit/kit_needs_you.dart';
import 'package:opencode_mobile/ui/kit/kit_receipt.dart';
import 'package:opencode_mobile/ui/kit/kit_request_card.dart';
import 'package:opencode_mobile/ui/kit/kit_sheet.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';
import 'package:opencode_mobile/ui/kit/motion/kit_haptics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kit_harness.dart';

/// Every `updateNode` the framework sent: the node id and its label.
final List<(int, String)> _sent = [];

class _SpyBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() => _SpyBuilder();
}

class _SpyBuilder implements ui.SemanticsUpdateBuilder {
  final ui.SemanticsUpdateBuilder _real = ui.SemanticsUpdateBuilder();

  @override
  ui.SemanticsUpdate build() => _real.build();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final named = invocation.namedArguments;
    switch (invocation.memberName) {
      case #updateNode:
        _sent.add((named[#id]! as int, named[#label]! as String));
        return Function.apply(_real.updateNode, const [], named);
      case #updateCustomAction:
        return Function.apply(_real.updateCustomAction, const [], named);
    }
    return super.noSuchMethod(invocation);
  }
}

Set<int> _liveIds(WidgetTester tester) {
  final ids = <int>{};
  void visit(SemanticsNode node) {
    if (node.getSemanticsData().flagsCollection.isLiveRegion) ids.add(node.id);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  var root = tester.getSemantics(find.byType(Scaffold));
  while (root.parent != null) {
    root = root.parent!;
  }
  visit(root);
  return ids;
}

/// Tracks what the platform announces across pumps.
class _Announcer {
  _Announcer() {
    _sent.clear();
  }

  final Map<int, String> _last = {};

  List<String> take(WidgetTester tester) {
    final live = _liveIds(tester);
    final announced = <String>[];
    for (final (id, label) in _sent) {
      if (!live.contains(id)) continue;
      if (_last[id] != label) announced.add(label);
      _last[id] = label;
    }
    _sent.clear();
    return announced;
  }
}

final _isolates = RegExp('[\\u2066-\\u2069]');
final _iconGlyph = RegExp('^[\\ue000-\\uf8ff]\$');

/// Every visible run of text, without KitBidi's isolates.
String _visible(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((t) => t.text.toPlainText().replaceAll(_isolates, ''))
    .where((text) => text.trim().isNotEmpty && !_iconGlyph.hasMatch(text))
    .join(' | ');

// One theme instance, so a rebuild of the app never animates a theme change.
final _dark = AppTheme.dark();
final _light = AppTheme.light();

const _cardKey = ValueKey('kit-request-card');
const _allowKey = Key('allow');
const _rejectKey = Key('reject');

Future<void> _pump(
  WidgetTester tester,
  Widget card, {
  Size size = const Size(412, 915),
  double textScale = 1,
  bool reduced = true,
  bool light = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: light ? _light : _dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduced,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(body: ListView(children: [card])),
    ),
  );
}

KitRequestCard _permission({
  KitRequestPhase phase = KitRequestPhase.waiting,
  VoidCallback? onAllow,
  VoidCallback? onReject,
  String? disabledReason,
  KitReceipt? receipt,
  String? answer,
  VoidCallback? onDetails,
  DateTime? since,
  String? server = 'laptop',
  String? allowLabel,
  String? rejectLabel,
}) => KitRequestCard.ask(
  kind: KitRequestKind.permission,
  title: 'Run a shell command',
  who: 'fox',
  server: server,
  reason: KitNeedsYouReason.decision,
  ifIgnored: 'The agent waits; nothing is lost.',
  announcement: 'Permission needed: Run a shell command',
  detail: 'To check the fix',
  summary: 'flutter test --concurrency=1 test/offline_queue_test.dart',
  phase: phase,
  since: since,
  receipt: receipt,
  answer: answer,
  onDetails: onDetails,
  answers: KitRequestDecide(
    onAllow: disabledReason == null ? (onAllow ?? () {}) : onAllow,
    onReject: disabledReason == null ? (onReject ?? () {}) : onReject,
    disabledReason: disabledReason,
    allowLabel: allowLabel,
    rejectLabel: rejectLabel,
    allowKey: _allowKey,
    rejectKey: _rejectKey,
  ),
);

const _colours = [
  KitChoice(value: 'red', title: 'Red'),
  KitChoice(value: 'green', title: 'Green'),
  KitChoice(value: 'blue', title: 'Blue'),
];

KitRequestCard _choice({
  KitRequestPhase phase = KitRequestPhase.waiting,
  ValueChanged<String>? onChosen,
  String? chosen,
  KitReceipt? receipt,
  String? answer,
  KitChoiceOther? other,
  List<KitChoice<String>> choices = _colours,
  VoidCallback? onDetails,
}) => KitRequestCard.ask(
  kind: KitRequestKind.choice,
  title: 'Which colour?',
  who: 'fox',
  reason: KitNeedsYouReason.decision,
  ifIgnored: 'The agent waits; nothing is lost.',
  announcement: 'Question: Which colour?',
  phase: phase,
  receipt: receipt,
  answer: answer,
  onDetails: onDetails,
  answers: KitRequestChoose<String>(
    choices: choices,
    onChosen: onChosen ?? (_) {},
    chosen: chosen,
    other: other,
  ),
);

/// Every colour a DecoratedBox paints: fills and border sides.
List<Color> _paints(WidgetTester tester) {
  final colours = <Color>[];
  for (final box in tester.widgetList<DecoratedBox>(
    find.byType(DecoratedBox),
  )) {
    final decoration = box.decoration;
    if (decoration is ShapeDecoration) {
      if (decoration.color case final color?) colours.add(color);
      final shape = decoration.shape;
      if (shape is OutlinedBorder) colours.add(shape.side.color);
    } else if (decoration is BoxDecoration) {
      if (decoration.color case final color?) colours.add(color);
      if (decoration.border case final Border border) {
        colours.add(border.top.color);
      }
    }
  }
  return colours;
}

KitTokens _tokens(WidgetTester tester) =>
    KitTokens.of(tester.element(find.byType(ListView)));

void main() {
  _SpyBinding();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => debugPlatformCapabilities = null);

  group('every kind waiting', () {
    for (final kind in KitRequestKind.values) {
      testWidgets('$kind: glyph, caption, words and fitting answers', (
        tester,
      ) async {
        final KitRequestAnswers answers = switch (kind) {
          KitRequestKind.permission || KitRequestKind.gate => KitRequestDecide(
            onAllow: () {},
            onReject: () {},
          ),
          KitRequestKind.question || KitRequestKind.choice =>
            KitRequestChoose<String>(choices: _colours, onChosen: (_) {}),
          KitRequestKind.reply => KitRequestReply(
            fieldLabel: 'Your reply',
            draft: KitDraft(
              target: 'request.r1',
              profileId: 'p1',
              controller: TextEditingController(),
            ),
            onSend: (_) {},
          ),
          KitRequestKind.form => const KitRequestInSheet(),
        };
        await _pump(
          tester,
          KitRequestCard.ask(
            kind: kind,
            title: 'The ask',
            who: 'fox',
            server: 'laptop',
            reason: KitNeedsYouReason.decision,
            ifIgnored: 'The agent waits; nothing is lost.',
            announcement: 'Needs you: The ask',
            detail: 'Why it asks',
            summary: 'git push origin main',
            since: clock.now().subtract(const Duration(minutes: 4)),
            answers: answers,
            onDetails: () {},
          ),
        );
        expect(find.byIcon(KitRequestCard.iconFor(kind)), findsOneWidget);
        final text = _visible(tester);
        expect(
          text,
          contains('Needs your decision · fox on laptop · waiting 4 min'),
        );
        expect(text, contains('The ask'));
        expect(text, contains('Why it asks'));
        expect(text, contains('The agent waits; nothing is lost.'));
        final summary = tester.widget<Text>(find.text('git push origin main'));
        expect(summary.textDirection, TextDirection.ltr);
        switch (kind) {
          case KitRequestKind.permission:
            expect(find.text('Allow once'), findsOneWidget);
            expect(find.text('Reject'), findsOneWidget);
          case KitRequestKind.gate:
            expect(find.text('Approve'), findsOneWidget);
            expect(find.text('Send back'), findsOneWidget);
          case KitRequestKind.question || KitRequestKind.choice:
            expect(find.text('Blue'), findsOneWidget);
          case KitRequestKind.reply:
            expect(find.byType(KitField), findsOneWidget);
            expect(find.text('Send'), findsOneWidget);
          case KitRequestKind.form:
            expect(find.text('Answer'), findsOneWidget);
        }
      });
    }
  });

  group('permission (P4.1a)', () {
    testWidgets('Allow once / Reject in place; one tap, once; one haptic', (
      tester,
    ) async {
      final haptics = recordHaptics(tester);
      var allowed = 0;
      await _pump(tester, _permission(onAllow: () => allowed++));
      expect(find.text('Allow once'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      await tester.tap(find.byKey(_allowKey));
      await tester.pump();
      await tester.tap(find.byKey(_allowKey));
      await tester.tap(find.byKey(_rejectKey));
      await tester.pump();
      expect(allowed, 1);
      expect(haptics, hasLength(1));
    });

    testWidgets('no haptic with Vibration off', (tester) async {
      final haptics = recordHaptics(tester);
      KitHaptics.enabled = false;
      addTearDown(() => KitHaptics.enabled = true);
      var allowed = 0;
      await _pump(tester, _permission(onAllow: () => allowed++));
      await tester.tap(find.byKey(_allowKey));
      await tester.pump();
      expect(allowed, 1);
      expect(haptics, isEmpty);
    });

    testWidgets('disabled: the reason shows under the answers', (tester) async {
      await _pump(tester, _permission(disabledReason: 'Reconnect to answer.'));
      expect(find.text('Reconnect to answer.'), findsOneWidget);
    });
  });

  group('choice (P4.1a: an option sends with Undo)', () {
    testWidgets('a tap sends once; sending shows the receipt on the chosen '
        'row; answered keeps Undo inside the window', (tester) async {
      final chosen = <String>[];
      await _pump(tester, _choice(onChosen: chosen.add));
      await tester.tap(find.text('Blue'));
      await tester.pump();
      await tester.tap(find.text('Red'));
      await tester.pump();
      expect(chosen, ['blue']);

      await _pump(
        tester,
        _choice(
          phase: KitRequestPhase.sending,
          chosen: 'blue',
          answer: 'Blue',
          receipt: KitReceipt(
            state: KitReceiptState.sending,
            since: clock.now(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Blue'), findsOneWidget);
      expect(find.text('Red'), findsNothing);
      expect(_visible(tester), contains('Sending…'));

      await _pump(
        tester,
        _choice(
          phase: KitRequestPhase.answered,
          answer: 'Blue',
          receipt: KitReceipt(
            state: KitReceiptState.confirmed,
            label: 'Chose Blue',
            at: clock.now(),
            onUndo: () {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 7));
      expect(find.text('Undo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('Undo'), findsNothing);
    });
  });

  testWidgets('Something else opens a KitField whose draft survives and is '
      'sent by Send', (tester) async {
    const fieldKey = Key('other-field');
    final sent = <String>[];
    KitRequestCard card() => _choice(
      other: KitChoiceOther(
        label: 'Something else',
        fieldLabel: 'Your answer',
        onSubmitted: sent.add,
        fieldKey: fieldKey,
        draft: KitDraft(
          target: 'request.r1',
          profileId: 'p1',
          controller: TextEditingController(),
        ),
      ),
    );
    await _pump(tester, card());
    expect(find.byType(KitField), findsNothing);
    await tester.tap(find.text('Something else'));
    await tester.pumpAndSettle();
    expect(find.byType(KitField), findsOneWidget);
    await tester.enterText(find.byKey(fieldKey), 'Purple');
    await tester.pump();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('oc.draft.request.r1.p1'), 'Purple');

    // Disposed, then shown again with a fresh controller: restored.
    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(tester, card());
    await tester.pumpAndSettle();
    expect(find.text('Purple'), findsOneWidget);

    await tester.tap(find.byTooltip('Send answer'));
    await tester.pump();
    expect(sent, ['Purple']);
  });

  testWidgets('reply: Send is disabled with its reason while empty', (
    tester,
  ) async {
    const fieldKey = Key('reply-field');
    const sendKey = Key('reply-send');
    final sent = <String>[];
    await _pump(
      tester,
      KitRequestCard.ask(
        kind: KitRequestKind.reply,
        title: 'The task asks for words',
        who: 'Reviewer',
        reason: KitNeedsYouReason.decision,
        ifIgnored: 'The task waits.',
        announcement: 'Reply needed',
        answers: KitRequestReply(
          fieldLabel: 'Your reply',
          fieldKey: fieldKey,
          sendKey: sendKey,
          onSend: sent.add,
          draft: KitDraft(
            target: 'request.r2',
            profileId: 'p1',
            controller: TextEditingController(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Type a reply first.'), findsOneWidget);
    await tester.tap(find.byKey(sendKey));
    await tester.pump();
    expect(sent, isEmpty);
    await tester.enterText(find.byKey(fieldKey), 'Ship it');
    await tester.pump();
    expect(find.text('Type a reply first.'), findsNothing);
    await tester.tap(find.byKey(sendKey));
    await tester.pump();
    expect(sent, ['Ship it']);
  });

  group('phases', () {
    testWidgets('sending: "{answer} · Sending…", then Not confirmed yet with '
        'Try again at 8 s', (tester) async {
      await _pump(
        tester,
        _permission(
          phase: KitRequestPhase.sending,
          answer: 'Run once',
          receipt: KitReceipt(
            state: KitReceiptState.sending,
            since: clock.now(),
            onRetry: () {},
          ),
        ),
      );
      expect(_visible(tester), contains('Run once ·'));
      expect(_visible(tester), contains('Sending…'));
      expect(find.byKey(_allowKey), findsNothing);
      await tester.pump(const Duration(seconds: 8));
      await tester.pump();
      expect(_visible(tester), contains('Not confirmed yet'));
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('answered collapses to a row with no attention colour', (
      tester,
    ) async {
      await _pump(
        tester,
        _permission(
          phase: KitRequestPhase.answered,
          receipt: KitReceipt(
            state: KitReceiptState.confirmed,
            label: 'Allowed once',
            at: clock.now(),
          ),
        ),
      );
      final roles = _tokens(tester).roles;
      expect(find.byKey(_cardKey), findsNothing);
      expect(find.byKey(const ValueKey('kit-request-row')), findsOneWidget);
      final paints = _paints(tester);
      expect(paints, isNot(contains(roles.attentionLine)));
      expect(
        paints,
        isNot(
          contains(Color.alphaBlend(roles.attentionSurface, roles.surface1)),
        ),
      );
      expect(_visible(tester), contains('Allowed once'));
    });

    testWidgets('answered elsewhere says where', (tester) async {
      await _pump(
        tester,
        _permission(
          phase: KitRequestPhase.answeredElsewhere,
          receipt: const KitReceipt(
            state: KitReceiptState.answeredElsewhere,
            where: 'the laptop',
          ),
        ),
      );
      expect(_visible(tester), contains('Answered on the laptop'));
    });

    testWidgets('expired: the words and nothing to press', (tester) async {
      await _pump(tester, _permission(phase: KitRequestPhase.expired));
      expect(_visible(tester), contains('Expired · the agent stopped waiting'));
      expect(find.byType(KitButton), findsNothing);
    });

    testWidgets('waiting-refused: the receipt sits above the answers', (
      tester,
    ) async {
      await _pump(
        tester,
        _permission(
          receipt: const KitReceipt(
            state: KitReceiptState.refused,
            reason: 'the session ended',
          ),
        ),
      );
      final refused = tester.getTopLeft(find.byType(KitReceipt));
      expect(refused.dy, lessThan(tester.getTopLeft(find.byKey(_allowKey)).dy));
    });
  });

  testWidgets('announcements: appear, sending, answered — three; the same '
      'state again — none', (tester) async {
    final semantics = tester.ensureSemantics();
    final announcer = _Announcer();
    await _pump(tester, _permission());
    expect(announcer.take(tester), ['Permission needed: Run a shell command']);
    await _pump(tester, _permission());
    expect(announcer.take(tester), isEmpty);
    await _pump(
      tester,
      _permission(
        phase: KitRequestPhase.sending,
        answer: 'Run once',
        receipt: KitReceipt(state: KitReceiptState.sending, since: clock.now()),
      ),
    );
    await tester.pump();
    expect(announcer.take(tester), hasLength(1));
    await _pump(
      tester,
      _permission(
        phase: KitRequestPhase.answered,
        receipt: const KitReceipt(
          state: KitReceiptState.confirmed,
          label: 'Allowed once',
        ),
      ),
    );
    await tester.pump();
    expect(announcer.take(tester), hasLength(1));
    semantics.dispose();
  });

  group('shortcuts (§8.2)', () {
    void desktop() => debugPlatformCapabilities = const PlatformCapabilities(
      platform: TargetPlatform.linux,
      isWeb: false,
    );

    void focusCard(WidgetTester tester) =>
        Focus.of(tester.element(find.byKey(_cardKey))).requestFocus();

    testWidgets('focused: A allows, D rejects', (tester) async {
      desktop();
      var allowed = 0;
      var rejected = 0;
      await _pump(
        tester,
        _permission(onAllow: () => allowed++, onReject: () => rejected++),
        size: const Size(1280, 800),
      );
      focusCard(tester);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();
      expect(allowed, 1);
      // A new request (a fresh card) answers D.
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(
        tester,
        _permission(onAllow: () => allowed++, onReject: () => rejected++),
        size: const Size(1280, 800),
      );
      focusCard(tester);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.pump();
      expect((allowed, rejected), (1, 1));
    });

    testWidgets('without focus nothing happens', (tester) async {
      desktop();
      var allowed = 0;
      await _pump(
        tester,
        _permission(onAllow: () => allowed++),
        size: const Size(1280, 800),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();
      expect(allowed, 0);
    });

    testWidgets('2 sends the second choice', (tester) async {
      desktop();
      final chosen = <String>[];
      await _pump(
        tester,
        _choice(onChosen: chosen.add),
        size: const Size(1280, 800),
      );
      focusCard(tester);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pump();
      expect(chosen, ['green']);
    });

    testWidgets('typing in Something else answers nothing', (tester) async {
      desktop();
      const fieldKey = Key('other-field');
      final chosen = <String>[];
      await _pump(
        tester,
        _choice(
          onChosen: chosen.add,
          other: KitChoiceOther(
            label: 'Something else',
            fieldLabel: 'Your answer',
            fieldKey: fieldKey,
            onSubmitted: (_) {},
          ),
        ),
        size: const Size(1280, 800),
      );
      await tester.tap(find.text('Something else'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(fieldKey));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();
      expect(chosen, isEmpty);
    });

    testWidgets('in sending, A does nothing', (tester) async {
      desktop();
      var allowed = 0;
      await _pump(
        tester,
        _permission(
          onAllow: () => allowed++,
          phase: KitRequestPhase.sending,
          answer: 'Run once',
          receipt: KitReceipt(
            state: KitReceiptState.sending,
            since: clock.now(),
          ),
        ),
        size: const Size(1280, 800),
      );
      focusCard(tester);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();
      expect(allowed, 0);
    });

    testWidgets('under an Arabic layout, physical A still allows', (
      tester,
    ) async {
      desktop();
      var allowed = 0;
      await _pump(
        tester,
        _permission(onAllow: () => allowed++),
        size: const Size(1280, 800),
      );
      focusCard(tester);
      await tester.pump();
      // The A key types another letter under another layout; the test
      // key map has no Arabic logical keys, so an AZERTY-style Q stands in:
      // what matters is that the physical key decides.
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyQ,
        physicalKey: PhysicalKeyboardKey.keyA,
      );
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.keyQ,
        physicalKey: PhysicalKeyboardKey.keyA,
      );
      await tester.pump();
      expect(allowed, 1);
    });
  });

  group('targets and large text', () {
    testWidgets('48 dp targets; the decide buttons are 8 dp apart', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        _permission(onDetails: () {}, allowLabel: 'Run', rejectLabel: 'Skip'),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      final reject = tester.getRect(find.byKey(_rejectKey));
      final allow = tester.getRect(find.byKey(_allowKey));
      expect(allow.left - reject.right, greaterThanOrEqualTo(8));
      semantics.dispose();
    });

    testWidgets('360 dp: side by side at 1.0, stacked at 2.0', (tester) async {
      // The test font draws every glyph 1 em wide: short verbs, as in
      // Chat.png ("Run once" / "Don't run" fit with the real face).
      final card = _permission(allowLabel: 'Run', rejectLabel: 'Skip');
      await _pump(tester, card, size: const Size(360, 800));
      expect(
        tester.getTopLeft(find.byKey(_allowKey)).dy,
        tester.getTopLeft(find.byKey(_rejectKey)).dy,
      );
      await _pump(tester, card, size: const Size(360, 800), textScale: 2);
      expect(
        tester.getTopLeft(find.byKey(_allowKey)).dy,
        lessThan(tester.getTopLeft(find.byKey(_rejectKey)).dy),
      );
    });

    testWidgets('2.0 text on 360x740: at most 45 % of the window, the primary '
        'in sight', (tester) async {
      await _pump(
        tester,
        _permission(onDetails: () {}),
        size: const Size(360, 740),
        textScale: 2,
      );
      final card = tester.getRect(find.byKey(_cardKey));
      expect(card.height, lessThanOrEqualTo(740 * .45 + .5));
      final allow = tester.getRect(find.byKey(_allowKey));
      expect(allow.bottom, lessThanOrEqualTo(card.bottom));
      expect(allow.top, greaterThanOrEqualTo(card.top));
    });

    for (final width in const [320.0, 360.0, 412.0, 600.0, 840.0, 1280.0]) {
      testWidgets('no overflow at ${width.toInt()} dp, 2.0 text', (
        tester,
      ) async {
        await _pump(
          tester,
          _permission(onDetails: () {}),
          size: Size(width, 740),
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('asserts (G37)', () {
    Future<void> expectAssert(WidgetTester tester, Widget card) async {
      await _pump(tester, card);
      expect(tester.takeException(), isA<AssertionError>());
    }

    testWidgets('ifIgnored is not empty', (tester) async {
      await expectAssert(
        tester,
        KitRequestCard.ask(
          kind: KitRequestKind.permission,
          title: 't',
          who: 'fox',
          reason: KitNeedsYouReason.decision,
          ifIgnored: ' ',
          announcement: 'a',
        ),
      );
    });

    testWidgets('sending needs a receipt with since and an answer', (
      tester,
    ) async {
      await expectAssert(
        tester,
        _permission(phase: KitRequestPhase.sending, answer: 'Run once'),
      );
      await expectAssert(
        tester,
        _permission(
          phase: KitRequestPhase.sending,
          answer: 'Run once',
          receipt: const KitReceipt(state: KitReceiptState.sending),
        ),
      );
      await expectAssert(
        tester,
        _permission(
          phase: KitRequestPhase.sending,
          receipt: KitReceipt(
            state: KitReceiptState.sending,
            since: clock.now(),
          ),
        ),
      );
    });

    testWidgets('answered needs a confirmed receipt', (tester) async {
      await expectAssert(
        tester,
        _permission(
          phase: KitRequestPhase.answered,
          receipt: const KitReceipt(state: KitReceiptState.sent),
        ),
      );
    });

    testWidgets('answeredElsewhere needs its receipt', (tester) async {
      await expectAssert(
        tester,
        _permission(
          phase: KitRequestPhase.answeredElsewhere,
          receipt: const KitReceipt(state: KitReceiptState.confirmed),
        ),
      );
    });

    testWidgets('expired has no receipt', (tester) async {
      await expectAssert(
        tester,
        _permission(
          phase: KitRequestPhase.expired,
          receipt: const KitReceipt(state: KitReceiptState.confirmed),
        ),
      );
    });

    testWidgets('an answer in the sheet needs onDetails', (tester) async {
      await expectAssert(
        tester,
        const KitRequestCard.ask(
          kind: KitRequestKind.form,
          title: 't',
          who: 'fox',
          reason: KitNeedsYouReason.decision,
          ifIgnored: 'waits',
          announcement: 'a',
          answers: KitRequestInSheet(),
        ),
      );
      await expectAssert(
        tester,
        KitRequestCard.ask(
          kind: KitRequestKind.question,
          title: 't',
          who: 'fox',
          reason: KitNeedsYouReason.decision,
          ifIgnored: 'waits',
          announcement: 'a',
          answers: KitRequestChooseMany<String>(
            choices: _colours,
            onSend: (_) {},
          ),
        ),
      );
    });

    testWidgets('more choices than fit need onDetails', (tester) async {
      await expectAssert(
        tester,
        _choice(
          choices: [
            for (var i = 0; i < 6; i++) KitChoice(value: '$i', title: '$i'),
          ],
        ),
      );
    });

    testWidgets('at most one tertiary', (tester) async {
      await expectAssert(
        tester,
        KitRequestCard.ask(
          kind: KitRequestKind.form,
          title: 't',
          who: 'fox',
          reason: KitNeedsYouReason.decision,
          ifIgnored: 'waits',
          announcement: 'a',
          tertiary: [
            KitAction(label: 'One', onPressed: () {}),
            KitAction(label: 'Two', onPressed: () {}),
          ],
        ),
      );
    });

    testWidgets('the answers fit the kind', (tester) async {
      await expectAssert(
        tester,
        KitRequestCard.ask(
          kind: KitRequestKind.question,
          title: 't',
          who: 'fox',
          reason: KitNeedsYouReason.decision,
          ifIgnored: 'waits',
          announcement: 'a',
          answers: KitRequestDecide(onAllow: () {}, onReject: () {}),
        ),
      );
      await expectAssert(
        tester,
        KitRequestCard.ask(
          kind: KitRequestKind.permission,
          title: 't',
          who: 'fox',
          reason: KitNeedsYouReason.decision,
          ifIgnored: 'waits',
          announcement: 'a',
          answers: KitRequestChoose<String>(
            choices: _colours,
            onChosen: (_) {},
          ),
        ),
      );
    });
  });

  group('legacy constructor (KIT-43)', () {
    testWidgets('the pre-v2 shape compiles and keeps kit-request-card', (
      tester,
    ) async {
      await _pump(
        tester,
        KitRequestCard(
          icon: AppIconography.question,
          title: 'Question',
          announcement: 'Question: pick one',
          summary: 'rm -rf build',
          detail: 'Why',
          body: const SizedBox(height: 8),
          primary: KitAction(label: 'Review', onPressed: () {}),
          secondary: KitAction(label: 'Later', onPressed: () {}),
          tertiary: [KitAction(label: 'More', onPressed: () {})],
          titleKey: const Key('title'),
        ),
      );
      expect(find.byKey(_cardKey), findsOneWidget);
      expect(find.byKey(const Key('title')), findsOneWidget);
    });

    testWidgets('tone attention paints the needs-you look', (tester) async {
      await _pump(
        tester,
        const KitRequestCard(
          icon: AppIconography.question,
          title: 'Question',
          announcement: 'a',
          tone: AppStatusTone.attention,
        ),
      );
      final roles = _tokens(tester).roles;
      final paints = _paints(tester);
      expect(paints, contains(roles.attentionLine));
      expect(
        paints,
        contains(Color.alphaBlend(roles.attentionSurface, roles.surface1)),
      );
    });

    testWidgets('no tone: a plain surface1 card, no accent tint (LOOK-6)', (
      tester,
    ) async {
      await _pump(
        tester,
        const KitRequestCard(
          icon: AppIconography.question,
          title: 'Question',
          announcement: 'a',
        ),
      );
      final roles = _tokens(tester).roles;
      final box = tester.widget<DecoratedBox>(find.byKey(_cardKey));
      final decoration = box.decoration as ShapeDecoration;
      expect(decoration.color, roles.surface1);
      for (final colour in _paints(tester)) {
        expect(
          colour.toARGB32() & 0xFFFFFF,
          isNot(roles.accent.toARGB32() & 0xFFFFFF),
        );
      }
    });
  });

  group('details', () {
    testWidgets('Details calls onDetails once', (tester) async {
      var opened = 0;
      await _pump(tester, _permission(onDetails: () => opened++));
      await tester.tap(find.text('Details'));
      await tester.pump();
      expect(opened, 1);
      expect(find.textContaining('more answer'), findsNothing);
    });

    testWidgets('"{n} more answers" only past maxChoicesInPlace', (
      tester,
    ) async {
      var opened = 0;
      await _pump(
        tester,
        _choice(
          onDetails: () => opened++,
          choices: [
            for (var i = 0; i < 7; i++) KitChoice(value: '$i', title: 'C$i'),
          ],
        ),
      );
      expect(find.text('C3'), findsOneWidget);
      expect(find.text('C4'), findsNothing);
      await tester.tap(find.text('3 more answers'));
      await tester.pump();
      expect(opened, 1);
    });
  });

  testWidgets('reduced motion: every phase settles after one pump (G8)', (
    tester,
  ) async {
    await _pump(tester, _permission());
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    await _pump(
      tester,
      _permission(
        phase: KitRequestPhase.sending,
        answer: 'Run once',
        receipt: KitReceipt(state: KitReceiptState.sending, since: clock.now()),
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    await _pump(
      tester,
      _permission(
        phase: KitRequestPhase.answered,
        receipt: const KitReceipt(
          state: KitReceiptState.confirmed,
          label: 'Allowed once',
        ),
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
