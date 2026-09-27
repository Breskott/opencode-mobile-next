// Unit slice-R2 (docs/ux-system/revamp/leftover-units.json) for
// showKitConfirm and KitConsequences: the alternative sits between the
// confirm and Cancel, and facts can share one neutral mark.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_sheet.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import 'kit_harness.dart';

Future<void> _open(BuildContext context, {VoidCallback? onAlternative}) =>
    showKitConfirm(
      context,
      title: 'Delete fox?',
      body: 'The conversation is removed from the server.',
      confirmLabel: 'Delete conversation',
      kind: KitConfirmKind.destructive,
      alternative: KitAction(
        label: 'Export fox first',
        onPressed: onAlternative ?? () {},
      ),
    );

void main() {
  group('the alternative sits between the confirm and Cancel', () {
    testWidgets('phone: confirm, alternative, Cancel from top to bottom', (
      tester,
    ) async {
      final context = await pumpKitHost(tester);
      unawaited(_open(context));
      await tester.pumpAndSettle();
      final confirm = tester.getRect(find.text('Delete conversation'));
      final alternative = tester.getRect(find.text('Export fox first'));
      final cancel = tester.getRect(find.text('Cancel'));
      expect(alternative.top, greaterThan(confirm.bottom));
      expect(cancel.top, greaterThan(alternative.bottom));
    });

    testWidgets('PC: one row, Cancel, alternative, confirm', (tester) async {
      final context = await pumpKitHost(tester, size: const Size(1280, 800));
      // Short labels, so the three fit one 480 dp row in the test font
      // (longer ones wrap to a second row rather than squeeze a label).
      unawaited(
        showKitConfirm(
          context,
          title: 'Delete fox?',
          body: 'Removed from the server.',
          confirmLabel: 'Delete',
          kind: KitConfirmKind.destructive,
          alternative: KitAction(label: 'Save', onPressed: () {}),
        ),
      );
      await tester.pumpAndSettle();
      final confirm = tester.getRect(find.text('Delete'));
      final alternative = tester.getRect(find.text('Save'));
      final cancel = tester.getRect(find.text('Cancel'));
      expect(alternative.center.dy, closeTo(confirm.center.dy, 2));
      expect(cancel.center.dy, closeTo(confirm.center.dy, 2));
      expect(cancel.right, lessThanOrEqualTo(alternative.left));
      expect(alternative.right, lessThanOrEqualTo(confirm.left));
      expect(tester.takeException(), isNull);
    });

    testWidgets('choosing it answers false and runs it', (tester) async {
      final context = await pumpKitHost(tester);
      var ran = false;
      bool? answer;
      unawaited(
        showKitConfirm(
          context,
          title: 'Delete fox?',
          body: 'Removed from the server.',
          confirmLabel: 'Delete conversation',
          alternative: KitAction(
            label: 'Export fox first',
            onPressed: () => ran = true,
          ),
        ).then((v) => answer = v),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export fox first'));
      await tester.pumpAndSettle();
      expect(ran, isTrue);
      expect(answer, isFalse);
    });
  });

  group('the neutral mark', () {
    Future<void> pump(WidgetTester tester, List<KitConsequence> items) async {
      await pumpKitHost(tester);
      final context = tester.element(find.byType(Scaffold));
      unawaited(
        showKitConfirm(
          context,
          title: 'Move fox?',
          body: 'The conversation moves to the other project.',
          confirmLabel: 'Move fox',
          consequenceItems: items,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('every fact can carry the same neutral dot, no check or '
        'info glyph', (tester) async {
      await pump(tester, const [
        KitConsequence(
          'Its 3 files move with it',
          mark: KitConsequenceMark.neutral,
        ),
        KitConsequence(
          'Its agent keeps its model',
          mark: KitConsequenceMark.neutral,
        ),
      ]);
      final panel = find.byKey(const ValueKey('kit-consequences'));
      expect(
        find.descendant(
          of: panel,
          matching: find.byKey(const ValueKey('kit-consequence-dot')),
        ),
        findsNWidgets(2),
      );
      expect(
        find.descendant(of: panel, matching: find.byIcon(AppIconography.check)),
        findsNothing,
      );
      expect(
        find.descendant(of: panel, matching: find.byIcon(AppIconography.info)),
        findsNothing,
      );
    });

    testWidgets(
      'the dot is text2, out of semantics, and smaller than a glyph',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, const [
          KitConsequence(
            'Its 3 files move with it',
            mark: KitConsequenceMark.neutral,
          ),
        ]);
        final dot = find.byKey(const ValueKey('kit-consequence-dot'));
        final box = tester.widget<DecoratedBox>(
          find.descendant(of: dot, matching: find.byType(DecoratedBox)),
        );
        final roles = KitTokens.of(tester.element(dot)).roles;
        expect((box.decoration as BoxDecoration).color, roles.text2);
        final inner = tester.getSize(
          find.descendant(of: dot, matching: find.byType(DecoratedBox)),
        );
        expect(inner.width, lessThan(tester.getSize(dot).width));
        // The dot adds nothing to what is read out: only the fact is.
        expect(
          find.ancestor(of: dot, matching: find.byType(ExcludeSemantics)),
          findsWidgets,
        );
        expect(
          find.bySemanticsLabel(RegExp('Its 3 files move with it')),
          findsWidgets,
        );
        semantics.dispose();
      },
    );
  });
}
