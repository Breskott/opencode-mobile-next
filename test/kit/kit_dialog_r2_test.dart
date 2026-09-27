// Unit slice-R2 (docs/ux-system/revamp/leftover-units.json) for
// showKitInputDialog: the very first edit counts, validation waits for it
// and sits under the field (never under the button), and the dialog opens
// in the same frame as showKitConfirm.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_dialog.dart';
import 'package:opencode_mobile/ui/kit/kit_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kit_harness.dart';

const _fieldKey = ValueKey('r2-field');
const _confirmKey = ValueKey('r2-confirm');
final _handle = find.byKey(const ValueKey('kit-sheet-handle'));

String? _empty(String value) => value.trim().isEmpty ? 'Name is empty' : null;

Future<String?> Function() _open(
  BuildContext context, {
  String? initial = 'Laptop',
}) {
  String? value;
  unawaited(
    showKitInputDialog(
      context,
      title: 'Rename server',
      label: 'Name',
      confirmLabel: 'Rename server',
      initial: initial,
      validate: _empty,
      fieldKey: _fieldKey,
      confirmKey: _confirmKey,
    ).then((v) => value = v),
  );
  return () async => value;
}

FilledButton _primary(WidgetTester tester) => tester.widget<FilledButton>(
  find.descendant(
    of: find.byKey(_confirmKey),
    matching: find.byType(FilledButton),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the first edit already counts: clearing a prefilled name shows '
      'the reason under the field and disables the primary', (tester) async {
    final context = await pumpKitHost(tester);
    _open(context);
    await tester.pumpAndSettle();
    expect(find.text('Name is empty'), findsNothing);
    expect(_primary(tester).onPressed, isNotNull);

    // One edit, the first: before the fix it was missed, and the reason
    // went under the button instead.
    await tester.enterText(find.byType(EditableText), '');
    await tester.pumpAndSettle();
    expect(find.text('Name is empty'), findsOneWidget);
    final field = tester.getRect(find.byKey(_fieldKey));
    final reason = tester.getRect(find.text('Name is empty'));
    final button = tester.getRect(find.byKey(_confirmKey));
    expect(reason.top, greaterThanOrEqualTo(field.bottom - 1));
    expect(reason.bottom, lessThanOrEqualTo(button.top));
    expect(_primary(tester).onPressed, isNull);
    expect(find.byKey(const ValueKey('kit-action-reason')), findsNothing);

    await tester.enterText(find.byType(EditableText), 'Desk');
    await tester.pumpAndSettle();
    expect(find.text('Name is empty'), findsNothing);
    expect(_primary(tester).onPressed, isNotNull);
  });

  testWidgets('before any edit the reason shows nowhere; a tap on the primary '
      'shows it under the field instead of submitting', (tester) async {
    final context = await pumpKitHost(tester);
    final result = _open(context, initial: null);
    await tester.pumpAndSettle();
    expect(find.text('Name is empty'), findsNothing);
    await tester.tap(find.byKey(_confirmKey));
    await tester.pumpAndSettle();
    expect(await result(), isNull);
    expect(find.text('Rename server'), findsWidgets);
    expect(find.text('Name is empty'), findsOneWidget);
    expect(
      tester.getRect(find.text('Name is empty')).bottom,
      lessThanOrEqualTo(tester.getRect(find.byKey(_confirmKey)).top),
    );
  });

  testWidgets('on a phone it is a bottom sheet with a handle, like a confirm', (
    tester,
  ) async {
    final context = await pumpKitHost(tester);
    _open(context);
    await tester.pumpAndSettle();
    expect(_handle, findsOneWidget);
    final dialog = tester.getRect(find.byType(BottomSheet));
    expect(dialog.bottom, 915);
    expect(dialog.width, 412);

    // The same frame as showKitConfirm: its sheet sits in the same place.
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    unawaited(
      showKitConfirm(
        context,
        title: 'Forget Laptop?',
        body: 'The app stops connecting to it.',
        confirmLabel: 'Forget Laptop',
      ),
    );
    await tester.pumpAndSettle();
    final confirm = tester.getRect(find.byType(BottomSheet));
    expect(confirm.bottom, dialog.bottom);
    expect(confirm.width, dialog.width);
  });

  testWidgets('on a PC it is the confirm\'s centred panel, no handle', (
    tester,
  ) async {
    final context = await pumpKitHost(tester, size: const Size(1280, 800));
    _open(context);
    await tester.pumpAndSettle();
    expect(_handle, findsNothing);
    expect(find.byType(Dialog), findsOneWidget);
    final field = tester.getRect(find.byKey(_fieldKey));
    expect(field.center.dx, closeTo(640, 1));
    expect(field.width, lessThanOrEqualTo(480));
  });

  testWidgets('changed text: a tap outside asks the discard question, '
      'Keep editing keeps the text', (tester) async {
    final context = await pumpKitHost(tester);
    final result = _open(context);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Desk');
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kit-dialog-discard')), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Desk'), findsOneWidget);
    expect(await result(), isNull);
  });

  testWidgets('unchanged text: a tap outside closes it', (tester) async {
    final context = await pumpKitHost(tester);
    _open(context);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();
    expect(find.byKey(_fieldKey), findsNothing);
  });
}
