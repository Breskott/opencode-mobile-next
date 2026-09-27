// KitSheet live pinned actions (coordinator ruling on kit-KitRequestSheet
// and screen-shell-1): a primary that changes while the sheet is open, and
// the frame that never overflows at 200 % text with the keyboard open
// (KIT-17).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_sheet.dart';

import 'kit_harness.dart';

void main() {
  testWidgets('the pinned primary enables, changes and stays pinned when its '
      'listenable changes', (tester) async {
    final context = await pumpKitHost(tester);
    final primary = ValueNotifier<KitAction?>(
      const KitAction(
        label: 'Send',
        onPressed: null,
        disabledReason: 'Type a message first',
      ),
    );
    addTearDown(primary.dispose);
    String? result = 'unset';
    unawaited(
      showKitSheet<String>(
        context,
        title: 'Message',
        body: (_) => const Text('Write to the agent'),
        primaryListenable: primary,
      ).then((v) => result = v),
    );
    await tester.pumpAndSettle();
    final actions = find.byKey(const ValueKey('kit-sheet-actions'));
    expect(
      find.descendant(of: actions, matching: find.text('Send')),
      findsOneWidget,
    );
    expect(find.text('Type a message first'), findsOneWidget);

    // Disabled: a tap does nothing and the sheet stays open.
    await tester.tap(find.text('Send'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Message'), findsOneWidget);
    expect(result, 'unset');

    // Something was typed: the same pinned place now sends.
    primary.value = KitAction(
      label: 'Send',
      onPressed: () => Navigator.of(context).pop('sent'),
    );
    await tester.pump();
    expect(find.text('Type a message first'), findsNothing);
    expect(
      find.descendant(of: actions, matching: find.text('Send')),
      findsOneWidget,
    );
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Message'), findsNothing);
    expect(result, 'sent');
  });

  testWidgets('a null listenable value falls back to primary', (tester) async {
    final context = await pumpKitHost(tester);
    final live = ValueNotifier<KitAction?>(null);
    addTearDown(live.dispose);
    unawaited(
      showKitSheet<void>(
        context,
        title: 'Message',
        body: (_) => const Text('Write to the agent'),
        primary: KitAction(label: 'Close it', onPressed: () {}),
        primaryListenable: live,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Close it'), findsOneWidget);
    live.value = KitAction(label: 'Submit', onPressed: () {});
    await tester.pump();
    expect(find.text('Close it'), findsNothing);
    expect(find.text('Submit'), findsOneWidget);
  });

  testWidgets(
    'at 2.0 text with a 300 dp keyboard at 412x915 the frame does not '
    'overflow: the header scrolls with the body and the actions stay pinned',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final context = await pumpKitHost(tester, size: const Size(412, 915));
      const title = 'Choose which folder the agent may read and change now';
      unawaited(
        showKitSheet<void>(
          context,
          title: title,
          subtitle:
              'The agent works only inside this folder. You can change it '
              'later from the project settings.',
          icon: AppIconography.folderOpen,
          body: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TextField(),
              for (var i = 0; i < 20; i++) Text('Row $i'),
            ],
          ),
          primary: KitAction(label: 'Use this folder', onPressed: () {}),
          secondary: KitAction(label: 'Pick another', onPressed: () {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      const keyboard = 300.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      // No RenderFlex overflow (or any other layout error) was reported.
      expect(tester.takeException(), isNull);

      const visibleBottom = 915.0 - keyboard;
      final primary = find.text('Use this folder');
      final before = tester.getRect(primary);
      expect(before.top, greaterThanOrEqualTo(0));
      expect(before.bottom, lessThanOrEqualTo(visibleBottom));

      // The body scrolls, taking the header with it; the last row comes
      // into view above the pinned block, which does not move.
      final titleTop = tester.getRect(find.text(title)).top;
      // At this size the header alone is taller than the room above the
      // pinned block, so it is drawn only inside the scroll view: the
      // pinned block is never covered.
      final actions = tester.getRect(
        find.byKey(const ValueKey('kit-sheet-actions')),
      );
      expect(find.text('Use this folder').hitTestable(), findsOneWidget);
      // A drag on the header (which may fill the scroll view) scrolls.
      final onHeader = Offset(200, actions.top / 2);
      await tester.dragFrom(onHeader, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.text(title)).top, lessThan(titleTop));
      final last = tester.getRect(find.text('Row 19'));
      expect(last.top, greaterThanOrEqualTo(0));
      expect(last.bottom, lessThanOrEqualTo(before.top));
      expect(tester.getRect(primary), before);

      // Back at the top the header, with Close, is reachable again.
      await tester.drag(find.text('Row 19'), const Offset(0, 3000));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text(title)).top, titleTop);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text(title), findsNothing);
    },
  );

  testWidgets('a header that fits stays fixed while the body scrolls', (
    tester,
  ) async {
    final context = await pumpKitHost(tester, size: const Size(412, 915));
    unawaited(
      showKitSheet<void>(
        context,
        title: 'Language',
        body: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (var i = 0; i < 80; i++) Text('Row $i')],
        ),
        primary: KitAction(label: 'Use English', onPressed: () {}),
      ),
    );
    await tester.pumpAndSettle();
    final titleRect = tester.getRect(find.text('Language'));
    await tester.drag(find.text('Row 5'), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Language')), titleRect);
    expect(find.text('Row 0').hitTestable(), findsNothing);
  });
}
