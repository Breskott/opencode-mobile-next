// Gate G9 (docs/ux-system/kit-v2.md §7) for KitConfirmSheet: false on back,
// swipe, a tap outside and cancel; the typed name enables the confirm only
// on an exact match; the commit haptic only for stop, destructive and
// discard, never with Vibration off; a confirm raised from a KitSheet adds
// no route. Also the §8.2 shapes per window, and the showConfirmSheet
// wrapper's mapping.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/widgets/confirm_sheet.dart';

import 'kit_harness.dart';

Future<bool?> _open(
  WidgetTester tester,
  BuildContext context, {
  KitConfirmKind kind = KitConfirmKind.destructive,
  String? typedName,
  Future<void> Function()? action,
  KitAction? alternative,
}) async {
  bool? result;
  unawaited(
    showKitConfirm(
      context,
      title: 'Delete fox?',
      body: 'The conversation is removed from the server.',
      confirmLabel: 'Delete conversation',
      kind: kind,
      typedName: typedName,
      action: action,
      alternative: alternative,
    ).then((value) => result = value),
  );
  await tester.pumpAndSettle();
  expect(find.text('Delete fox?'), findsOneWidget);
  return result;
}

void main() {
  group('answers false unless confirmed', () {
    testWidgets('cancel', (tester) async {
      final context = await pumpKitHost(tester);
      bool? result;
      unawaited(
        showKitConfirm(
          context,
          title: 'Delete fox?',
          body: 'Removed from the server.',
          confirmLabel: 'Delete conversation',
          kind: KitConfirmKind.destructive,
        ).then((v) => result = v),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(find.text('Delete fox?'), findsNothing);
    });

    testWidgets('back', (tester) async {
      final context = await pumpKitHost(tester);
      bool? result;
      unawaited(
        showKitConfirm(
          context,
          title: 'Delete fox?',
          body: 'Removed from the server.',
          confirmLabel: 'Delete conversation',
        ).then((v) => result = v),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('swipe down', (tester) async {
      final context = await pumpKitHost(tester);
      bool? result;
      unawaited(
        showKitConfirm(
          context,
          title: 'Delete fox?',
          body: 'Removed from the server.',
          confirmLabel: 'Delete conversation',
        ).then((v) => result = v),
      );
      await tester.pumpAndSettle();
      await tester.fling(find.text('Delete fox?'), const Offset(0, 600), 2000);
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(find.text('Delete fox?'), findsNothing);
    });

    testWidgets('a tap outside', (tester) async {
      final context = await pumpKitHost(tester);
      bool? result;
      unawaited(
        showKitConfirm(
          context,
          title: 'Delete fox?',
          body: 'Removed from the server.',
          confirmLabel: 'Delete conversation',
        ).then((v) => result = v),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('confirm answers true', (tester) async {
      final context = await pumpKitHost(tester);
      bool? result;
      unawaited(
        showKitConfirm(
          context,
          title: 'Delete fox?',
          body: 'Removed from the server.',
          confirmLabel: 'Delete conversation',
        ).then((v) => result = v),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete conversation'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  testWidgets('the cancel word follows the kind', (tester) async {
    final context = await pumpKitHost(tester);
    for (final (kind, word) in [
      (KitConfirmKind.neutral, 'Cancel'),
      (KitConfirmKind.destructive, 'Cancel'),
      (KitConfirmKind.stop, 'Keep running'),
      (KitConfirmKind.discard, 'Keep editing'),
    ]) {
      await _open(tester, context, kind: kind);
      expect(find.text(word), findsOneWidget, reason: '$kind');
      await tester.tap(find.text(word));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('error tone only for stop, destructive and discard; never ?', (
    tester,
  ) async {
    final context = await pumpKitHost(tester);
    final theme = AppTheme.dark();
    for (final kind in KitConfirmKind.values) {
      await _open(tester, context, kind: kind);
      final button = filledButton(tester, 'Delete conversation');
      final background = button.style?.backgroundColor?.resolve({});
      if (kind == KitConfirmKind.neutral) {
        expect(background, isNot(theme.colorScheme.error), reason: '$kind');
      } else {
        expect(background, theme.colorScheme.error, reason: '$kind');
      }
      expect(find.byIcon(AppIconography.question), findsNothing);
      expect(find.byIcon(KitConfirmSheet.iconFor(kind)), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('kit-confirm-cancel')));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the typed name enables the confirm only on an exact match', (
    tester,
  ) async {
    final context = await pumpKitHost(tester);
    bool? result;
    unawaited(
      showKitConfirm(
        context,
        title: 'Delete Ubuntu?',
        body: 'Everything installed on this phone goes.',
        confirmLabel: 'Delete Ubuntu',
        kind: KitConfirmKind.destructive,
        typedName: 'ubuntu',
      ).then((v) => result = v),
    );
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('kit-confirm-typed-name'));
    expect(find.textContaining('to confirm'), findsOneWidget);
    for (final attempt in ['', 'ubunt', 'Ubuntu', 'ubuntu ']) {
      await tester.enterText(field, attempt);
      await tester.pump();
      expect(
        filledButton(tester, 'Delete Ubuntu').onPressed,
        isNull,
        reason: attempt,
      );
      expect(find.byKey(const ValueKey('kit-confirm-reason')), findsOneWidget);
    }
    await tester.enterText(field, 'ubuntu');
    await tester.pump();
    expect(filledButton(tester, 'Delete Ubuntu').onPressed, isNotNull);
    expect(find.byKey(const ValueKey('kit-confirm-reason')), findsNothing);
    await tester.tap(find.text('Delete Ubuntu'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  group('commit haptic', () {
    for (final kind in KitConfirmKind.values) {
      testWidgets('${kind.name}: ${kind.isDanger ? 'one tick' : 'none'}', (
        tester,
      ) async {
        final haptics = recordHaptics(tester);
        final context = await pumpKitHost(tester);
        await _open(tester, context, kind: kind);
        await tester.tap(find.text('Delete conversation'));
        await tester.pumpAndSettle();
        expect(
          haptics,
          kind.isDanger ? ['HapticFeedbackType.mediumImpact'] : isEmpty,
        );
      });
    }

    testWidgets('never with Vibration off', (tester) async {
      final haptics = recordHaptics(tester);
      final context = await pumpKitHost(
        tester,
        effects: const KitEffects(haptics: false),
      );
      await _open(tester, context, kind: KitConfirmKind.destructive);
      await tester.tap(find.text('Delete conversation'));
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);
    });

    testWidgets('showConfirmSheet obeys Vibration off too', (tester) async {
      final haptics = recordHaptics(tester);
      final context = await pumpKitHost(
        tester,
        effects: const KitEffects(haptics: false),
      );
      unawaited(
        showConfirmSheet(
          context,
          title: 'Remove server?',
          message: 'Its saved sign-in is removed.',
          confirmLabel: 'Remove server',
          destructive: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove server'));
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);
    });
  });

  testWidgets('a confirm raised from a KitSheet adds no route', (tester) async {
    final routes = RouteCounter();
    final context = await pumpKitHost(tester, routes: routes);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    late BuildContext bodyContext;
    unawaited(
      showKitSheet<void>(
        context,
        title: 'Saved prompts',
        body: (inner) {
          bodyContext = inner;
          return TextField(controller: controller);
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'kept text');
    final before = routes.pushes;
    bool? result;
    unawaited(
      showKitConfirm(
        bodyContext,
        title: 'Delete prompt?',
        body: 'It is removed from this phone.',
        confirmLabel: 'Delete prompt',
        kind: KitConfirmKind.destructive,
      ).then((v) => result = v),
    );
    await tester.pumpAndSettle();
    expect(routes.pushes, before, reason: 'no second modal (§4.7)');
    expect(find.text('Delete prompt?'), findsOneWidget);
    expect(find.text('Saved prompts'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(find.text('Saved prompts'), findsOneWidget);
    expect(controller.text, 'kept text');
    expect(find.text('kept text'), findsOneWidget);
  });

  testWidgets('a pinned action\'s confirm also swaps in place', (tester) async {
    final routes = RouteCounter();
    final context = await pumpKitHost(tester, routes: routes);
    bool? result;
    unawaited(
      showKitSheet<void>(
        context,
        title: 'Saved prompts',
        body: (_) => const Text('Three prompts'),
        tertiary: [
          KitAction(
            label: 'Delete all',
            destructive: true,
            onPressed: () => unawaited(
              showKitConfirm(
                context, // the caller's context, outside the sheet
                title: 'Delete all prompts?',
                body: 'They are removed from this phone.',
                confirmLabel: 'Delete prompts',
                kind: KitConfirmKind.destructive,
              ).then((v) => result = v),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final before = routes.pushes;
    await tester.tap(find.text('Delete all'));
    await tester.pumpAndSettle();
    expect(routes.pushes, before);
    await tester.tap(find.text('Delete prompts'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.text('Three prompts'), findsOneWidget);
  });

  testWidgets('a failed act keeps the question open with Try again', (
    tester,
  ) async {
    final context = await pumpKitHost(tester);
    var attempts = 0;
    final gate = Completer<void>();
    bool? result;
    unawaited(
      showKitConfirm(
        context,
        title: 'Stop fox?',
        body: 'Its work so far is kept.',
        confirmLabel: 'Stop fox',
        kind: KitConfirmKind.stop,
        action: () async {
          attempts++;
          if (attempts == 1) throw StateError('secret-token-123');
          await gate.future;
        },
      ).then((v) => result = v),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop fox'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.byKey(const ValueKey('kit-confirm-failed')), findsOneWidget);
    expect(find.textContaining('secret-token-123'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    // Working: the cancel is off while the act runs.
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('Keep running'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
    gate.complete();
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(attempts, 2);
  });

  testWidgets('the alternative closes the question and runs', (tester) async {
    final context = await pumpKitHost(tester);
    var exported = false;
    bool? result;
    unawaited(
      showKitConfirm(
        context,
        title: 'Delete fox?',
        body: 'Removed from the server.',
        confirmLabel: 'Delete conversation',
        kind: KitConfirmKind.destructive,
        alternative: KitAction(
          label: 'Export first',
          onPressed: () => exported = true,
        ),
      ).then((v) => result = v),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export first'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(exported, isTrue);
  });

  testWidgets('details fold open, left to right', (tester) async {
    final context = await pumpKitHost(tester, locale: const Locale('ar'));
    unawaited(
      showKitConfirm(
        context,
        title: 'Remove worktree?',
        body: 'Its files are deleted.',
        confirmLabel: 'Remove worktree',
        kind: KitConfirmKind.destructive,
        details: const [
          KitTechnicalValue('Path', '/home/dev/code/.worktrees/fox'),
          KitTechnicalValue('Again', '/home/dev/code/.worktrees/fox'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('/home/dev/code/.worktrees/fox'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('kit-details-toggle')));
    await tester.pumpAndSettle();
    // Deduplicated by value, and never reordered inside Arabic.
    final value = find.text('/home/dev/code/.worktrees/fox');
    expect(value, findsOneWidget);
    final direction = tester
        .element(value)
        .dependOnInheritedWidgetOfExactType<Directionality>()!
        .textDirection;
    expect(direction, TextDirection.ltr);
  });

  group('adapts to the window (§8.2)', () {
    for (final (size, shape, width) in [
      (const Size(412, 915), BottomSheet, 412.0),
      (const Size(700, 1000), BottomSheet, 560.0),
      (const Size(1280, 800), Dialog, 480.0),
      (const Size(915, 412), BottomSheet, 560.0), // a phone in landscape
    ]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}', (
        tester,
      ) async {
        final context = await pumpKitHost(tester, size: size);
        await _open(tester, context);
        expect(find.byType(shape), findsOneWidget);
        expect(
          tester.getSize(find.byType(KitConfirmSheet)).width,
          moreOrLessEquals(width, epsilon: 1),
        );
      });
    }
  });

  testWidgets('showConfirmSheet maps onto the kit confirmation', (
    tester,
  ) async {
    final context = await pumpKitHost(tester);
    bool? result;
    unawaited(
      showConfirmSheet(
        context,
        title: 'Remove server?',
        message: 'Its saved sign-in is removed.',
        confirmLabel: 'Remove server',
        destructive: true,
        sheetKey: const ValueKey('legacy-sheet'),
        confirmKey: const ValueKey('legacy-confirm'),
      ).then((v) => result = v),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('legacy-sheet')), findsOneWidget);
    expect(find.byType(KitConfirmSheet), findsOneWidget);
    expect(find.byIcon(AppIconography.question), findsNothing);
    expect(find.byIcon(AppIconography.delete), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('legacy-confirm')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
