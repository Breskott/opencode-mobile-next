// Unit slice-R2 (docs/ux-system/revamp/leftover-units.json): the sheet
// frame's one close control, a live secondary, the virtualised list body,
// the header that scrolls away at 250 % text, the in-place question at the
// sheet's full height, and pinned actions a tap reaches at 800x600.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_sheet.dart';

import 'kit_harness.dart';

final _close = find.byKey(const ValueKey('kit-sheet-close'));
final _actions = find.byKey(const ValueKey('kit-sheet-actions'));

Widget _rows(BuildContext _) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [for (var i = 0; i < 40; i++) Text('Row $i')],
);

void main() {
  group('one close control', () {
    testWidgets('a dismissing secondary replaces the header X', (tester) async {
      final context = await pumpKitHost(tester);
      unawaited(
        showKitSheet<void>(
          context,
          title: 'Rename server',
          body: (_) => const Text('Laptop'),
          primary: KitAction(label: 'Rename Laptop', onPressed: () {}),
          secondary: KitAction(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
          secondaryDismisses: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(_close, findsNothing);
      expect(find.byTooltip('Close'), findsNothing);
      expect(find.text('Cancel'), findsOneWidget);
      // Still closable without the X: back and the handle's Dismiss.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Rename server'), findsNothing);
    });

    testWidgets('without the flag, or with no secondary, the X stays', (
      tester,
    ) async {
      final context = await pumpKitHost(tester);
      unawaited(
        showKitSheet<void>(
          context,
          title: 'Rename server',
          body: (_) => const Text('Laptop'),
          secondary: KitAction(label: 'Cancel', onPressed: () {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(_close, findsOneWidget);
      await tester.tap(_close);
      await tester.pumpAndSettle();

      unawaited(
        showKitSheet<void>(
          context,
          title: 'About Laptop',
          body: (_) => const Text('Laptop'),
          secondaryDismisses: true,
        ),
      );
      await tester.pumpAndSettle();
      // Nothing else closes it on screen: the X is the one control.
      expect(_close, findsOneWidget);
    });

    testWidgets('back still closes a sheet without the X', (tester) async {
      final context = await pumpKitHost(tester);
      unawaited(
        showKitSheet<void>(
          context,
          title: 'Rename server',
          body: (_) => const Text('Laptop'),
          secondary: KitAction(label: 'Cancel', onPressed: () {}),
          secondaryDismisses: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Rename server'), findsNothing);
    });
  });

  testWidgets('a live secondary changes in place and stays pinned (KIT-17)', (
    tester,
  ) async {
    final context = await pumpKitHost(tester);
    final primary = ValueNotifier<KitAction?>(
      KitAction(label: 'Test and turn on', onPressed: () {}),
    );
    final secondary = ValueNotifier<KitAction?>(null);
    addTearDown(primary.dispose);
    addTearDown(secondary.dispose);
    unawaited(
      showKitSheet<void>(
        context,
        title: 'Voice server',
        body: _rows,
        primaryListenable: primary,
        secondaryListenable: secondary,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: _actions, matching: find.text('Test and turn on')),
      findsOneWidget,
    );

    // The test runs: the way out of it takes the secondary's place.
    var cancelled = false;
    primary.value = const KitAction(
      label: 'Test and turn on',
      onPressed: null,
      working: true,
    );
    secondary.value = KitAction(
      label: 'Cancel test',
      onPressed: () => cancelled = true,
    );
    await tester.pump();
    expect(
      find.descendant(of: _actions, matching: find.text('Cancel test')),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel test'));
    expect(cancelled, isTrue);

    // The test failed: save anyway replaces it, still pinned.
    primary.value = KitAction(label: 'Try again', onPressed: () {});
    secondary.value = KitAction(label: 'Save anyway', onPressed: () {});
    await tester.pump();
    expect(find.text('Cancel test'), findsNothing);
    final before = tester.getRect(find.text('Save anyway'));
    await tester.drag(find.text('Row 3'), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Save anyway')), before);
  });

  testWidgets('a list body builds only the rows in view', (tester) async {
    final context = await pumpKitHost(tester);
    final built = <int>{};
    String? picked;
    unawaited(
      showKitSheet<String>(
        context,
        title: 'Pick a model',
        height: KitSheetHeight.half,
        itemCount: 5000,
        itemBuilder: (context, index) {
          built.add(index);
          return SizedBox(
            height: 48,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop('Model $index'),
              child: Text('Model $index'),
            ),
          );
        },
      ).then((v) => picked = v),
    );
    await tester.pumpAndSettle();
    expect(find.text('Model 0'), findsOneWidget);
    expect(built.length, lessThan(60));
    await tester.drag(find.text('Model 2'), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('Model 0'), findsNothing);
    expect(built.length, lessThan(200));
    final shown = built.where(
      (i) => find.text('Model $i').evaluate().isNotEmpty,
    );
    final row = shown.reduce((a, b) => a > b ? a : b) - 2;
    await tester.tap(find.text('Model $row'));
    await tester.pumpAndSettle();
    expect(picked, 'Model $row');
  });

  group('250 % text on a 320x640 window', () {
    Future<(Rect sheet, Rect body, Rect title)> open(
      WidgetTester tester,
      double scale,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final context = await pumpKitHost(tester, size: const Size(320, 640));
      unawaited(
        showKitSheet<void>(
          context,
          title: 'Project folder',
          subtitle: 'Where the agent works',
          icon: AppIconography.folderOpen,
          body: _rows,
          primary: KitAction(label: 'Use folder', onPressed: () {}),
          secondary: KitAction(label: 'Cancel', onPressed: () {}),
          secondaryDismisses: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final sheet = tester.getRect(find.byType(KitSheet));
      final body = tester.getRect(
        find.descendant(
          of: find.byType(KitSheet),
          matching: find.byType(CustomScrollView),
        ),
      );
      final title = tester.getRect(find.text('Project folder'));
      return (sheet, body, title);
    }

    testWidgets('at 2.5 the header scrolls away and the body keeps half', (
      tester,
    ) async {
      final (sheet, body, title) = await open(tester, 2.5);
      expect(body.height, greaterThanOrEqualTo(sheet.height / 2));
      final primary = tester.getRect(find.text('Use folder'));
      // A drag inside the body (the header lies over it) scrolls both.
      await tester.dragFrom(body.center, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.text('Project folder')).top,
        lessThan(title.top),
      );
      // The pinned block did not move.
      expect(tester.getRect(find.text('Use folder')), primary);
    });

    testWidgets('at 1.0 the header stays pinned', (tester) async {
      final (_, body, title) = await open(tester, 1.0);
      await tester.dragFrom(body.center, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Project folder')), title);
    });
  });

  testWidgets('a question in place over a sheet gets the full sheet height', (
    tester,
  ) async {
    final context = await pumpKitHost(tester);
    late BuildContext bodyContext;
    unawaited(
      showKitSheet<void>(
        context,
        title: 'Server',
        body: (inner) {
          bodyContext = inner;
          return const Text('Laptop');
        },
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      showKitConfirm(
        bodyContext,
        title: 'Forget Laptop?',
        body: 'The app stops connecting to it.',
        confirmLabel: 'Forget Laptop',
        kind: KitConfirmKind.destructive,
        consequenceItems: [
          for (var i = 0; i < 24; i++)
            KitConsequence('Saved thing $i is removed'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final question = tester.getRect(
      find.byKey(const ValueKey('kit-sheet-question')),
    );
    // The cap is 90 % of the 915 dp window; before, the question shared it
    // with the hidden content and got at most half (a squeezed band).
    const cap = 915 * 0.9;
    expect(question.height, greaterThan(cap * 0.9));
    expect(question.height, lessThanOrEqualTo(cap));
    // The confirm is reachable by scrolling the question.
    await tester.scrollUntilVisible(
      find.text('Forget Laptop').last,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('kit-sheet-question')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Forget Laptop').last.hitTestable(), findsOneWidget);
  });

  for (final size in const [Size(800, 600), Size(1024, 600)]) {
    testWidgets('at ${size.width.toInt()}x${size.height.toInt()} a full '
        'sheet\'s pinned primary is reached by ensureVisible and a tap', (
      tester,
    ) async {
      final context = await pumpKitHost(tester, size: size);
      String? result;
      unawaited(
        showKitSheet<String>(
          context,
          title: 'Model',
          height: KitSheetHeight.full,
          body: _rows,
          primary: KitAction(
            label: 'Use Opus',
            onPressed: () => Navigator.of(context).pop('opus'),
          ),
        ).then((v) => result = v),
      );
      await tester.pumpAndSettle();
      final primary = find.text('Use Opus');
      await tester.ensureVisible(primary);
      await tester.pumpAndSettle();
      final rect = tester.getRect(primary);
      expect(rect.bottom, lessThanOrEqualTo(size.height));
      expect(rect.right, lessThanOrEqualTo(size.width));
      expect(primary.hitTestable(), findsOneWidget);
      await tester.tap(primary);
      await tester.pumpAndSettle();
      expect(result, 'opus');
    });
  }
}
