// Gate G9/G14 behaviour tests for KitDialog
// (docs/ux-system/kit-api/KitDialog.md, "Tests required"): the input
// dialog's focus, validation, async submit, dismissal and discard rules,
// drafts, the secret kind, the destructive alternative, the alert's one
// action, the keyboard, reduced motion and overflow.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/effects.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_dialog.dart';
import 'package:opencode_mobile/ui/kit/kit_field.dart';
import 'package:opencode_mobile/ui/kit/kit_sheet.dart';
import 'package:opencode_mobile/ui/kit/kit_technical_value.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kit_harness.dart';

const _title = 'Rename conversation';
const _fieldKey = ValueKey('dialog-field');
const _confirmKey = ValueKey('dialog-confirm');

/// Opens the input dialog and returns a holder for its result.
Future<({String? value, bool done})> Function() _openInput(
  WidgetTester tester,
  BuildContext context, {
  String? initial = 'fox',
  String? Function(String)? validate,
  Future<String?> Function(String)? onSubmit,
  KitAction? alternative,
  KitDraft? draft,
  KitFieldKind kind = KitFieldKind.text,
  String? helper,
}) {
  String? value;
  var done = false;
  unawaited(
    showKitInputDialog(
      context,
      title: _title,
      label: 'Name',
      confirmLabel: 'Rename',
      initial: initial,
      helper: helper,
      validate: validate,
      onSubmit: onSubmit,
      alternative: alternative,
      draft: draft,
      kind: kind,
      dialogKey: const ValueKey('dialog'),
      fieldKey: _fieldKey,
      confirmKey: _confirmKey,
    ).then((v) {
      value = v;
      done = true;
    }),
  );
  return () async => (value: value, done: done);
}

EditableText _editable(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText));

String? _empty(String value) => value.trim().isEmpty ? 'Name is empty' : null;

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('1. opens with the field focused, the text selected, and the '
      'title naming the route', (tester) async {
    final semantics = tester.ensureSemantics();
    final context = await pumpKitHost(tester);
    _openInput(tester, context);
    await tester.pumpAndSettle();
    final editable = _editable(tester);
    expect(editable.focusNode.hasFocus, isTrue);
    expect(
      editable.controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 3),
    );
    expect(find.bySemanticsLabel(_title), findsOneWidget);
    final node = tester.getSemantics(find.bySemanticsLabel(_title));
    expect(node.flagsCollection.namesRoute, isTrue);
    semantics.dispose();
  });

  testWidgets('2. an invalid empty field: nothing judged before the first '
      'edit, then the reason once under the field (slice-R2)', (tester) async {
    final context = await pumpKitHost(tester);
    final result = _openInput(tester, context, initial: null, validate: _empty);
    await tester.pumpAndSettle();
    expect(find.text('Name is empty'), findsNothing);
    // A tap before any edit does not submit: it shows the reason.
    await tester.tap(find.byKey(_confirmKey));
    await tester.pumpAndSettle();
    expect((await result()).done, isFalse);
    expect(find.text('Name is empty'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'a');
    await tester.pumpAndSettle();
    expect(find.text('Name is empty'), findsNothing);
    await tester.enterText(find.byType(EditableText), '');
    await tester.pumpAndSettle();
    // Shown once: under the field, not under the button.
    expect(find.text('Name is empty'), findsOneWidget);
    final fieldBottom = tester.getBottomLeft(find.byKey(_fieldKey)).dy;
    final reasonTop = tester.getTopLeft(find.text('Name is empty')).dy;
    final buttonTop = tester.getTopLeft(find.byKey(_confirmKey)).dy;
    expect(reasonTop, lessThan(buttonTop));
    expect(reasonTop, greaterThanOrEqualTo(fieldBottom - 1));
  });

  testWidgets('3. Enter submits only when valid and returns the text', (
    tester,
  ) async {
    final context = await pumpKitHost(tester);
    final result = _openInput(tester, context, initial: null, validate: _empty);
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect((await result()).done, isFalse);
    await tester.enterText(find.byType(EditableText), 'wolf');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(await result(), (value: 'wolf', done: true));
  });

  testWidgets('4. async submit: working, Enter and Esc ignored, an error '
      'keeps the text, then null closes', (tester) async {
    final context = await pumpKitHost(tester, size: const Size(1280, 800));
    var calls = 0;
    var answer = Completer<String?>();
    final result = _openInput(
      tester,
      context,
      onSubmit: (_) {
        calls++;
        return answer.future;
      },
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'wolf');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(
      tester
          .widget<KitButton>(
            find.ancestor(
              of: find.text('Rename'),
              matching: find.byType(KitButton),
            ),
          )
          .working,
      isTrue,
    );
    await tester.tap(find.byKey(_confirmKey));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(calls, 1);
    expect(find.text(_title), findsOneWidget);
    answer.complete('That name is taken');
    await tester.pumpAndSettle();
    expect(find.text('That name is taken'), findsOneWidget);
    expect(find.text('wolf'), findsOneWidget);
    expect((await result()).done, isFalse);
    answer = Completer<String?>()..complete(null);
    await tester.tap(find.byKey(_confirmKey));
    await tester.pumpAndSettle();
    expect(await result(), (value: 'wolf', done: true));
  });

  group('5. unchanged text closes with null', () {
    for (final (name, close) in <(String, Future<void> Function(WidgetTester))>[
      ('Cancel', (t) => t.tap(find.text('Cancel'))),
      ('back', (t) => t.binding.handlePopRoute()),
      ('Esc', (t) => t.sendKeyEvent(LogicalKeyboardKey.escape)),
      ('a tap outside', (t) => t.tapAt(const Offset(4, 4))),
    ]) {
      testWidgets(name, (tester) async {
        final context = await pumpKitHost(tester);
        final result = _openInput(tester, context);
        await tester.pumpAndSettle();
        await close(tester);
        await tester.pumpAndSettle();
        expect(await result(), (value: null, done: true));
        expect(find.text(_title), findsNothing);
      });
    }
  });

  testWidgets('6. changed text without a draft: the discard question in '
      'place, no route; a tap outside asks too (slice-R2: the confirm '
      'frame)', (tester) async {
    final routes = RouteCounter();
    final context = await pumpKitHost(tester, routes: routes);
    final result = _openInput(tester, context);
    await tester.pumpAndSettle();
    final pushes = routes.pushes;
    await tester.enterText(find.byType(EditableText), 'wolf');
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.text('Discard your changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text(_title), findsOneWidget);
    expect(find.text('wolf'), findsOneWidget);

    await _key(tester, LogicalKeyboardKey.escape);
    expect(find.text('Discard your changes?'), findsOneWidget);
    expect(routes.pushes, pushes);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('wolf'), findsOneWidget);
    expect((await result()).done, isFalse);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard your changes?'), findsOneWidget);
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(await result(), (value: null, done: true));
    expect(routes.pushes, pushes);
  });

  testWidgets('6b. an explicit Cancel closes changed text without asking', (
    tester,
  ) async {
    final context = await pumpKitHost(tester);
    final result = _openInput(tester, context);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'wolf');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result(), (value: null, done: true));
  });

  testWidgets('7. with a draft Esc closes silently, the text is saved and '
      'reopening restores it', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final draft = KitDraft(
      target: 'rename.s1',
      profileId: 'p1',
      controller: controller,
      prefs: prefs,
    );
    expect(draft.key, 'oc.draft.rename.s1.p1');
    final context = await pumpKitHost(tester);
    var result = _openInput(tester, context, initial: null, draft: draft);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'wolf');
    await _key(tester, LogicalKeyboardKey.escape);
    expect(await result(), (value: null, done: true));
    expect(find.text('Discard your changes?'), findsNothing);
    expect(prefs.getString('oc.draft.rename.s1.p1'), 'wolf');

    controller.clear();
    result = _openInput(tester, context, initial: null, draft: draft);
    await tester.pumpAndSettle();
    expect(find.text('wolf'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect((await result()).done, isTrue);
  });

  testWidgets('8. the secret kind asserts on a prefill and is obscured with '
      'no suggestions', (tester) async {
    final context = await pumpKitHost(tester);
    await expectLater(
      showKitInputDialog(
        context,
        title: 'Paste code',
        label: 'Code',
        confirmLabel: 'Connect',
        initial: 'x',
        kind: KitFieldKind.secret,
      ),
      throwsAssertionError,
    );
    unawaited(
      showKitInputDialog(
        context,
        title: 'Paste code',
        label: 'Code',
        confirmLabel: 'Connect',
        kind: KitFieldKind.secret,
      ),
    );
    await tester.pumpAndSettle();
    final editable = _editable(tester);
    expect(editable.obscureText, isTrue);
    expect(editable.enableSuggestions, isFalse);
  });

  testWidgets('9. a destructive alternative stacks on its own line, never '
      'beside the primary', (tester) async {
    final context = await pumpKitHost(tester, size: const Size(1280, 800));
    var removed = false;
    final result = _openInput(
      tester,
      context,
      alternative: KitAction(
        label: 'Remove budget',
        destructive: true,
        onPressed: () => removed = true,
      ),
    );
    await tester.pumpAndSettle();
    final primary = tester.getRect(find.byKey(_confirmKey));
    final alternative = tester.getRect(
      find.ancestor(
        of: find.text('Remove budget'),
        matching: find.byType(KitButton),
      ),
    );
    final cancel = tester.getRect(
      find.ancestor(of: find.text('Cancel'), matching: find.byType(KitButton)),
    );
    expect(alternative.top, greaterThanOrEqualTo(primary.bottom + 8));
    expect(cancel.top, greaterThanOrEqualTo(alternative.bottom + 8));
    expect(alternative.height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('Remove budget'));
    await tester.pumpAndSettle();
    expect(removed, isTrue);
    expect(await result(), (value: null, done: true));
  });

  group('10. showKitAlert', () {
    Future<bool Function()> open(
      WidgetTester tester,
      BuildContext context, {
      KitAction? action,
      List<KitTechnicalValue> details = const [],
    }) async {
      var done = false;
      unawaited(
        showKitAlert(
          context,
          title: 'Could not open file',
          body: 'The file is too large to show here.',
          icon: AppIconography.info,
          action: action,
          details: details,
          alertKey: const ValueKey('alert'),
          closeKey: const ValueKey('close'),
        ).then((_) => done = true),
      );
      await tester.pumpAndSettle();
      return () => done;
    }

    for (final (name, close) in <(String, Future<void> Function(WidgetTester))>[
      ('Close', (t) => t.tap(find.byKey(const ValueKey('close')))),
      ('Esc', (t) => t.sendKeyEvent(LogicalKeyboardKey.escape)),
      ('back', (t) => t.binding.handlePopRoute()),
    ]) {
      testWidgets('$name completes it', (tester) async {
        final context = await pumpKitHost(tester);
        final done = await open(tester, context);
        await close(tester);
        await tester.pumpAndSettle();
        expect(done(), isTrue);
      });
    }

    testWidgets('a tap outside does not close it', (tester) async {
      final context = await pumpKitHost(tester);
      final done = await open(tester, context);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(done(), isFalse);
      expect(find.byKey(const ValueKey('alert')), findsOneWidget);
    });

    testWidgets('its one action closes it and runs', (tester) async {
      final context = await pumpKitHost(tester);
      var ran = false;
      final done = await open(
        tester,
        context,
        action: KitAction(label: 'Open Files', onPressed: () => ran = true),
      );
      expect(find.byType(KitButton), findsNWidgets(2));
      await tester.tap(find.text('Open Files'));
      await tester.pumpAndSettle();
      expect(ran, isTrue);
      expect(done(), isTrue);
    });

    testWidgets('details fold last and collapsed; title and body once', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final context = await pumpKitHost(tester);
      await open(
        tester,
        context,
        details: const [KitTechnicalValue('Size', '48 MB')],
      );
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('48 MB'), findsNothing);
      final body = tester.getRect(
        find.text('The file is too large to show here.'),
      );
      expect(tester.getRect(find.text('Details')).top, greaterThan(body.top));
      expect(find.bySemanticsLabel('Could not open file'), findsOneWidget);
      expect(
        find.bySemanticsLabel('The file is too large to show here.'),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });

  group('11. keyboard', () {
    testWidgets('Tab: field, primary, alternative, Cancel', (tester) async {
      final context = await pumpKitHost(tester);
      _openInput(
        tester,
        context,
        alternative: KitAction(label: 'Remove budget', onPressed: () {}),
      );
      await tester.pumpAndSettle();
      expect(_editable(tester).focusNode.hasFocus, isTrue);
      String? focused() {
        final node = FocusManager.instance.primaryFocus;
        final element = node?.context;
        if (element == null) return null;
        for (final label in ['Rename', 'Remove budget', 'Cancel']) {
          final match = find.ancestor(
            of: find.text(label),
            matching: find.byElementPredicate((e) => e == element),
          );
          if (match.evaluate().isNotEmpty) return label;
        }
        return null;
      }

      final order = <String?>[];
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        order.add(focused());
      }
      expect(order, ['Rename', 'Remove budget', 'Cancel']);
    });

    testWidgets('Enter on an alert closes it without running the action', (
      tester,
    ) async {
      final context = await pumpKitHost(tester, size: const Size(1280, 800));
      var ran = false;
      var done = false;
      unawaited(
        showKitAlert(
          context,
          title: 'Could not open file',
          body: 'The file is too large.',
          action: KitAction(label: 'Open Files', onPressed: () => ran = true),
        ).then((_) => done = true),
      );
      await tester.pumpAndSettle();
      await _key(tester, LogicalKeyboardKey.enter);
      expect(done, isTrue);
      expect(ran, isFalse);
    });
  });

  testWidgets('12. reduced motion: one pump settles; no scale', (tester) async {
    final context = await pumpKitHost(
      tester,
      effects: const KitEffects(motion: KitMotionLevel.off),
    );
    _openInput(tester, context);
    await tester.pump();
    await tester.pump();
    // The route's cross-fade is already at full opacity.
    final fades = tester.widgetList<FadeTransition>(
      find.ancestor(
        of: find.text(_title),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(fades, isNotEmpty);
    for (final fade in fades) {
      expect(fade.opacity.value, 1);
    }
    expect(find.text(_title), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text(_title),
        matching: find.byType(ScaleTransition),
      ),
      findsNothing,
    );
  });

  group('13. overflow', () {
    const sizes = [
      Size(320, 640),
      Size(412, 915),
      Size(915, 412),
      Size(1280, 800),
      Size(1600, 1000),
    ];
    for (final size in sizes) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('${size.width.toInt()}x${size.height.toInt()} at $scale', (
          tester,
        ) async {
          final context = await pumpKitHost(tester, size: size);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pump();
          _openInput(
            tester,
            context,
            helper:
                'Letters, digits and dashes. The name shows in the list and '
                'in the window title.',
            alternative: KitAction(
              label: 'Remove budget',
              destructive: true,
              onPressed: () {},
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.byKey(_confirmKey));
          await tester.ensureVisible(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  test('14. both functions return Futures and take keys', () {
    // Compile-time manifest (G4): the frozen signatures.
    const Future<String?> Function(
      BuildContext, {
      required String title,
      required String label,
      required String confirmLabel,
      Key? dialogKey,
      Key? fieldKey,
      Key? confirmKey,
    })
    input = showKitInputDialog;
    const Future<void> Function(
      BuildContext, {
      required String title,
      required String body,
      Key? alertKey,
      Key? closeKey,
    })
    alert = showKitAlert;
    expect(input, isNotNull);
    expect(alert, isNotNull);
  });
}
