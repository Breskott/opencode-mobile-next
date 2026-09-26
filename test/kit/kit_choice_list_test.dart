// KitChoiceList, KitChoiceRow, KitPickerRow (docs/ux-system/kit-api/
// KitChoiceList.md): the frozen "Tests required" contract (G9, G14, G37,
// TEST-15). Arabic/RTL is dropped by the owner decision of 2026-09-27.
// ignore_for_file: deprecated_member_use_from_same_package
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/server_gateway.dart' show QuestionChoice;
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_choice_list.dart';
import 'package:opencode_mobile/ui/kit/kit_field.dart';
import 'package:opencode_mobile/ui/kit/kit_receipt.dart';
import 'package:opencode_mobile/ui/kit/kit_sheet.dart';
import 'package:opencode_mobile/ui/kit/kit_state_view.dart';
import 'package:opencode_mobile/ui/kit/motion/kit_haptics.dart';
import 'package:opencode_mobile/ui/widgets/question_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
  Size size = const Size(412, 915),
  bool reduced = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduced,
        ),
        child: widget!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

const _choices = [
  KitChoice(value: 'a', title: 'Staging'),
  KitChoice(value: 'b', title: 'Production', supporting: 'The live site'),
  KitChoice(value: 'c', title: 'Canary', recommended: true),
];

/// A host that owns the single selection.
class _Single extends StatefulWidget {
  const _Single({
    required this.onSelected,
    this.sends = false,
    this.actsOnTap = true,
    this.receipt,
    this.other,
  });

  final ValueChanged<String> onSelected;
  final bool sends;
  final bool actsOnTap;
  final KitReceipt? receipt;
  final KitChoiceOther? other;

  @override
  State<_Single> createState() => _SingleState();
}

class _SingleState extends State<_Single> {
  String? selected;

  @override
  Widget build(BuildContext context) => KitChoiceList<String>.single(
    choices: _choices,
    selected: selected,
    sends: widget.sends,
    actsOnTap: widget.actsOnTap,
    receipt: widget.receipt,
    other: widget.other,
    semanticsLabel: 'Where to deploy',
    onSelected: (value) {
      widget.onSelected(value);
      if (!widget.sends) setState(() => selected = value);
    },
  );
}

List<MethodCall> _mockPlatform() {
  final calls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    calls.add(call);
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return calls;
}

int _vibrations(List<MethodCall> calls) =>
    calls.where((c) => c.method == 'HapticFeedback.vibrate').length;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('single: one tap, one callback (G9)', () {
    testWidgets('a tap calls onSelected exactly once', (tester) async {
      final got = <String>[];
      await _pump(tester, _Single(onSelected: got.add));
      await tester.tap(find.text('Production'));
      await tester.pump();
      expect(got, ['b']);
      // The selected row, tapped again, still answers (a picker closes).
      await tester.tap(find.text('Production'));
      await tester.pump();
      expect(got, ['b', 'b']);
    });

    testWidgets('sends: a double tap sends once until the receipt changes', (
      tester,
    ) async {
      final got = <String>[];
      await _pump(tester, _Single(onSelected: got.add, sends: true));
      await tester.tap(find.text('Staging'));
      await tester.tap(find.text('Staging'));
      await tester.tap(find.text('Production'));
      await tester.pump();
      expect(got, ['a']);

      await _pump(
        tester,
        _Single(
          onSelected: got.add,
          sends: true,
          receipt: const KitReceipt(
            state: KitReceiptState.refused,
            reason: 'closed',
          ),
        ),
      );
      await tester.tap(find.text('Production'));
      await tester.pump();
      expect(got, ['a', 'b']);
    });
  });

  testWidgets('actsOnTap false: the mark moves and no Current shows', (
    tester,
  ) async {
    await _pump(tester, _Single(onSelected: (_) {}, actsOnTap: false));
    await tester.tap(find.text('Canary'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('kit-choice-mark-radio-selected')),
      findsOneWidget,
    );
    expect(find.textContaining('Current'), findsNothing);
  });

  testWidgets('a picker shows Current on the selected row; sends never does', (
    tester,
  ) async {
    await _pump(tester, _Single(onSelected: (_) {}));
    await tester.tap(find.text('Staging'));
    await tester.pump();
    expect(find.textContaining('Current'), findsOneWidget);

    await _pump(
      tester,
      KitChoiceList<String>.single(
        choices: _choices,
        selected: 'a',
        sends: true,
        onSelected: (_) {},
      ),
    );
    expect(find.textContaining('Current'), findsNothing);
  });

  testWidgets('showKitChoiceSheet pops with the chosen value, Esc with null', (
    tester,
  ) async {
    await _pump(tester, const SizedBox());
    final context = tester.element(find.byType(SingleChildScrollView));
    final first = showKitChoiceSheet<String>(
      context,
      title: 'Deploy to',
      choices: _choices,
      selected: 'a',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Canary'));
    await tester.pumpAndSettle();
    expect(await first, 'c');

    final second = showKitChoiceSheet<String>(
      context,
      title: 'Deploy to',
      choices: _choices,
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(await second, isNull);
  });

  testWidgets('multi: a tap toggles membership; semantics say checked', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    Set<String>? got;
    await _pump(
      tester,
      KitChoiceList<String>.multi(
        choices: _choices,
        selected: const {'a'},
        onChanged: (next) => got = next,
      ),
    );
    await tester.tap(find.text('Canary'));
    expect(got, {'a', 'c'});
    await tester.tap(find.text('Staging'));
    expect(got, <String>{});
    expect(find.text('1 selected'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Staging')),
      matchesSemantics(
        label: 'Staging',
        isButton: true,
        hasCheckedState: true,
        isChecked: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });

  group('disabled choice', () {
    test('asserts without a reason', () {
      expect(
        () => KitChoice<int>(value: 1, title: 'x', enabled: false),
        throwsAssertionError,
      );
    });

    testWidgets('shows its reason and ignores taps', (tester) async {
      final got = <String>[];
      await _pump(
        tester,
        KitChoiceList<String>.single(
          choices: const [
            KitChoice(value: 'a', title: 'Staging'),
            KitChoice(
              value: 'b',
              title: 'Production',
              enabled: false,
              disabledReason: 'Needs a release tag',
            ),
          ],
          selected: null,
          onSelected: got.add,
        ),
      );
      expect(find.text('Needs a release tag'), findsOneWidget);
      await tester.tap(find.text('Production'));
      await tester.pump();
      expect(got, isEmpty);
    });
  });

  testWidgets('selection is a shape and semantics say selected', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      KitChoiceList<String>.single(
        choices: _choices,
        selected: 'b',
        onSelected: (_) {},
      ),
    );
    expect(
      find.byKey(const ValueKey('kit-choice-mark-radio-selected')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('kit-choice-mark-radio-empty')),
      findsNWidgets(2),
    );
    final node = tester.getSemantics(find.text('Production'));
    expect(node.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(node.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
    handle.dispose();
  });

  group('haptics', () {
    tearDown(() => KitHaptics.enabled = true);

    testWidgets('send fires once per sent answer, never for a local choice', (
      tester,
    ) async {
      final calls = _mockPlatform();
      await _pump(tester, _Single(onSelected: (_) {}, sends: true));
      await tester.tap(find.text('Staging'));
      await tester.tap(find.text('Staging'));
      await tester.pump();
      expect(_vibrations(calls), 1);

      calls.clear();
      await _pump(tester, _Single(onSelected: (_) {}));
      await tester.tap(find.text('Staging'));
      await tester.pump();
      expect(_vibrations(calls), 0);
    });

    testWidgets('never with Vibration off', (tester) async {
      final calls = _mockPlatform();
      KitHaptics.enabled = false;
      await _pump(tester, _Single(onSelected: (_) {}, sends: true));
      await tester.tap(find.text('Staging'));
      await tester.pump();
      expect(_vibrations(calls), 0);
    });
  });

  testWidgets('receipt: Sending, Sent, Answered, then Not confirmed yet', (
    tester,
  ) async {
    Future<void> show(KitReceipt receipt) => _pump(
      tester,
      KitChoiceList<String>.single(
        choices: _choices,
        selected: 'a',
        sends: true,
        receipt: receipt,
        onSelected: (_) {},
      ),
    );
    await show(const KitReceipt(state: KitReceiptState.sending));
    expect(find.textContaining('Sending'), findsOneWidget);
    await show(const KitReceipt(state: KitReceiptState.sent));
    expect(find.textContaining('Sent'), findsOneWidget);
    await show(
      const KitReceipt(
        state: KitReceiptState.answeredElsewhere,
        where: 'the laptop',
      ),
    );
    expect(find.textContaining('the laptop'), findsOneWidget);
    // Waiting from long ago: the receipt has escalated.
    await show(
      KitReceipt(
        state: KitReceiptState.sent,
        since: DateTime.now().subtract(const Duration(seconds: 9)),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Not confirmed yet'), findsOneWidget);
  });

  group('other', () {
    testWidgets('opens a KitField and sends the typed text', (tester) async {
      final sent = <String>[];
      await _pump(
        tester,
        _Single(
          onSelected: (_) {},
          other: KitChoiceOther(
            label: 'Something else',
            fieldLabel: 'Your answer',
            onSubmitted: sent.add,
          ),
        ),
      );
      expect(find.byType(KitField), findsNothing);
      await tester.tap(find.text('Something else'));
      await tester.pumpAndSettle();
      expect(find.byType(KitField), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  Blue-green  ');
      await tester.tap(find.byTooltip('Send answer'));
      await tester.pump();
      expect(sent, ['Blue-green']);
    });

    testWidgets('a draft survives dispose and remount', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      Widget host(TextEditingController controller) => _Single(
        onSelected: (_) {},
        other: KitChoiceOther(
          label: 'Something else',
          fieldLabel: 'Your answer',
          onSubmitted: (_) {},
          draft: KitDraft(
            target: 'question.q1',
            profileId: 'p1',
            controller: controller,
            prefs: prefs,
          ),
        ),
      );
      final first = TextEditingController();
      addTearDown(first.dispose);
      await _pump(tester, host(first));
      await tester.tap(find.text('Something else'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Half typed');
      await tester.pump();
      await _pump(tester, const SizedBox());
      await tester.pumpAndSettle();

      final second = TextEditingController();
      addTearDown(second.dispose);
      await _pump(tester, host(second));
      await tester.pumpAndSettle();
      expect(find.text('Half typed'), findsOneWidget);
    });
  });

  group('loading and empty', () {
    testWidgets('loading shows skeleton rows', (tester) async {
      await _pump(
        tester,
        KitChoiceList<String>.single(
          choices: const [],
          selected: null,
          loading: true,
          onSelected: (_) {},
        ),
      );
      expect(find.byKey(const ValueKey('kit-skeleton-rows')), findsOneWidget);
    });

    testWidgets('empty without a view asserts', (tester) async {
      await _pump(
        tester,
        KitChoiceList<String>.single(
          choices: const [],
          selected: null,
          onSelected: (_) {},
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('empty renders the given view', (tester) async {
      await _pump(
        tester,
        KitChoiceList<String>.single(
          choices: const [],
          selected: null,
          onSelected: (_) {},
          empty: const KitStateView(
            icon: Icons.mic_none,
            title: 'No voices downloaded yet',
          ),
        ),
      );
      expect(find.text('No voices downloaded yet'), findsOneWidget);
    });
  });

  group('KitPickerRow', () {
    testWidgets('shows its value; a tap opens the sheet and chooses', (
      tester,
    ) async {
      final got = <String>[];
      await _pump(
        tester,
        KitPickerRow<String>(
          title: 'Deploy to',
          choices: _choices,
          selected: 'a',
          onSelected: got.add,
        ),
      );
      expect(find.text('Deploy to'), findsOneWidget);
      expect(find.textContaining('Staging'), findsOneWidget);
      await tester.tap(find.text('Deploy to'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Production'));
      await tester.pumpAndSettle();
      expect(got, ['b']);
    });

    testWidgets('valueLabel overrides the shown value', (tester) async {
      await _pump(
        tester,
        KitPickerRow<String>(
          title: 'Theme',
          choices: _choices,
          selected: null,
          valueLabel: 'Follow the system',
          onSelected: (_) {},
        ),
      );
      expect(find.textContaining('Follow the system'), findsOneWidget);
    });

    testWidgets('one choice: no chevron and no sheet', (tester) async {
      await _pump(
        tester,
        KitPickerRow<String>(
          title: 'Deploy to',
          choices: const [KitChoice(value: 'a', title: 'Staging')],
          selected: 'a',
          onSelected: (_) {},
        ),
      );
      expect(find.byKey(const ValueKey('kit-picker-chevron')), findsNothing);
      await tester.tap(find.text('Deploy to'));
      await tester.pumpAndSettle();
      expect(find.text('Production'), findsNothing);
    });

    test('disabled without a reason asserts', () {
      expect(
        () => KitPickerRow<String>(
          title: 'x',
          choices: _choices,
          selected: null,
          onSelected: null,
        ),
        throwsAssertionError,
      );
    });
  });

  testWidgets('keyboard: Tab enters on the selected row, arrows move focus, '
      'Space and Enter select', (tester) async {
    final got = <String>[];
    await _pump(
      tester,
      Column(
        children: [
          const TextField(),
          KitChoiceList<String>.single(
            choices: _choices,
            selected: 'b',
            onSelected: got.add,
          ),
        ],
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(got, ['b']);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(got, ['b']);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(got, ['b', 'c']);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(got, ['b', 'c', 'a']);
  });

  testWidgets('rows are at least 56 dp tall', (tester) async {
    await _pump(
      tester,
      KitChoiceList<String>.single(
        choices: _choices,
        selected: null,
        onSelected: (_) {},
      ),
    );
    for (final row in find.byType(KitChoiceRow<String>).evaluate()) {
      expect(
        tester.getSize(find.byWidget(row.widget)).height,
        greaterThanOrEqualTo(56),
      );
    }
  });

  testWidgets('QuestionOptionRow forwards to KitChoiceRow', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      Column(
        children: [
          QuestionOptionRow(
            choice: const QuestionChoice(label: 'Staging', description: 'x'),
            selected: true,
            multiple: true,
            onTap: () => taps++,
          ),
          QuestionCustomAnswerField(
            controller: TextEditingController(),
            onChanged: (_) {},
          ),
        ],
      ),
    );
    final row = tester.widget<KitChoiceRow<String>>(
      find.byType(KitChoiceRow<String>),
    );
    expect(row.choice.title, 'Staging');
    expect(row.selected, isTrue);
    expect(row.mark, KitChoiceMark.check);
    await tester.tap(find.byKey(const ValueKey('question-option-Staging')));
    expect(taps, 1);
    final field = tester.widget<KitField>(find.byType(KitField));
    expect(field.kind, KitFieldKind.multiline);
  });

  testWidgets('reduced motion settles in one pump', (tester) async {
    await _pump(tester, _Single(onSelected: (_) {}), reduced: true);
    await tester.tap(find.text('Staging'));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('no overflow from 320 to 1600 dp at 1.0, 1.3 and 2.0 text', (
    tester,
  ) async {
    for (final size in const [
      Size(320, 640),
      Size(412, 915),
      Size(915, 412),
      Size(1600, 1000),
    ]) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        await _pump(
          tester,
          Column(
            children: [
              KitChoiceList<String>.single(
                choices: _choices,
                selected: 'a',
                onSelected: (_) {},
              ),
              KitPickerRow<String>(
                title: 'Deploy to',
                choices: _choices,
                selected: 'b',
                onSelected: (_) {},
              ),
            ],
          ),
          size: size,
          textScale: scale,
        );
        expect(tester.takeException(), isNull, reason: '$size x$scale');
      }
    }
  });
}
