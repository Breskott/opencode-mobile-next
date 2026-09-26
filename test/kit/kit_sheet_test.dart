// KitSheet (docs/ux-system/kit-v2.md §1.1, §4.7, §8.2): the frame, its
// unsaved-input guard (the discard question asked in place), and the shape
// it takes per window class.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_harness.dart';

void main() {
  testWidgets('the frame: title, subtitle, close, body and pinned actions', (
    tester,
  ) async {
    final context = await pumpKitHost(tester);
    String? result;
    unawaited(
      showKitSheet<String>(
        context,
        title: 'Language',
        subtitle: 'Words across the app',
        body: (_) => const Text('English'),
        primary: KitAction(
          label: 'Use English',
          onPressed: () => Navigator.of(context).pop('en'),
        ),
      ).then((v) => result = v),
    );
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Words across the app'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.byKey(const ValueKey('kit-sheet-handle')), findsOneWidget);
    await tester.tap(find.text('Use English'));
    await tester.pumpAndSettle();
    expect(result, 'en');
  });

  testWidgets('close and back dismiss a sheet with nothing to lose', (
    tester,
  ) async {
    final context = await pumpKitHost(tester);
    unawaited(
      showKitSheet<void>(
        context,
        title: 'Language',
        body: (_) => const Text('English'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsNothing);
    unawaited(
      showKitSheet<void>(
        context,
        title: 'Language',
        body: (_) => const Text('English'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsNothing);
  });

  group('unsaved input without a draft', () {
    Future<ValueNotifier<bool>> open(
      WidgetTester tester,
      BuildContext context,
    ) async {
      final dirty = ValueNotifier(false);
      addTearDown(dirty.dispose);
      unawaited(
        showKitSheet<void>(
          context,
          title: 'Edit server',
          body: (_) => TextField(onChanged: (_) => dirty.value = true),
          dirty: dirty,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'changed');
      await tester.pump();
      return dirty;
    }

    testWidgets('back asks in place; Keep editing keeps the text', (
      tester,
    ) async {
      final routes = RouteCounter();
      final context = await pumpKitHost(tester, routes: routes);
      await open(tester, context);
      final before = routes.pushes;
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(routes.pushes, before);
      expect(find.text('Discard your changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Edit server'), findsOneWidget);
      expect(find.text('changed'), findsOneWidget);
    });

    testWidgets('the close button asks; Discard changes closes', (
      tester,
    ) async {
      final context = await pumpKitHost(tester);
      await open(tester, context);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(find.text('Edit server'), findsNothing);
    });

    testWidgets('a swipe down on the header asks instead of closing', (
      tester,
    ) async {
      final context = await pumpKitHost(tester);
      await open(tester, context);
      await tester.fling(find.text('Edit server'), const Offset(0, 400), 1500);
      await tester.pumpAndSettle();
      expect(find.text('Discard your changes?'), findsOneWidget);
    });

    testWidgets('a tap outside asks instead of closing', (tester) async {
      final context = await pumpKitHost(tester);
      await open(tester, context);
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      expect(find.text('Discard your changes?'), findsOneWidget);
    });

    testWidgets('clean input closes without asking', (tester) async {
      final context = await pumpKitHost(tester);
      final dirty = await open(tester, context);
      dirty.value = false;
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Edit server'), findsNothing);
    });
  });

  testWidgets('not dismissible while an irreversible step runs', (
    tester,
  ) async {
    final context = await pumpKitHost(tester);
    unawaited(
      showKitSheet<void>(
        context,
        title: 'Installing',
        body: (_) => const Text('This cannot be stopped halfway.'),
        dismissible: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(find.text('Installing'), findsOneWidget);
  });

  testWidgets('loading shows the one bar under the header', (tester) async {
    final context = await pumpKitHost(tester);
    final loading = ValueNotifier(true);
    addTearDown(loading.dispose);
    unawaited(
      showKitSheet<void>(
        context,
        title: 'Models',
        body: (_) => const SizedBox(height: 40),
        loading: loading,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('kit-loading-bar')), findsOneWidget);
    loading.value = false;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kit-loading-bar')), findsNothing);
  });

  group('adapts to the window (§8.2)', () {
    for (final (size, height, expected) in [
      (const Size(360, 800), KitSheetHeight.content, 'bottom'),
      (const Size(800, 1280), KitSheetHeight.content, 'bottom'),
      (const Size(1280, 800), KitSheetHeight.content, 'panel'),
      (const Size(1600, 1000), KitSheetHeight.full, 'side'),
      (const Size(915, 412), KitSheetHeight.content, 'bottom'),
    ]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()} '
          '${height.name}: $expected', (tester) async {
        final context = await pumpKitHost(tester, size: size);
        unawaited(
          showKitSheet<void>(
            context,
            title: 'Language',
            height: height,
            body: (_) => const Text('English'),
          ),
        );
        await tester.pumpAndSettle();
        final sheet = tester.getRect(find.byType(KitSheet));
        switch (expected) {
          case 'bottom':
            expect(find.byType(BottomSheet), findsOneWidget);
            expect(
              sheet.width,
              lessThanOrEqualTo(KitLayout.sheetMaxWidth + .5),
            );
            expect(sheet.bottom, moreOrLessEquals(size.height, epsilon: 1));
            expect(
              find.byKey(const ValueKey('kit-sheet-handle')),
              findsOneWidget,
            );
          case 'panel':
            expect(find.byType(Dialog), findsOneWidget);
            expect(
              sheet.width,
              lessThanOrEqualTo(KitLayout.dialogPanelWidth + .5),
            );
            expect(
              sheet.center.dx,
              moreOrLessEquals(size.width / 2, epsilon: 1),
            );
            expect(
              find.byKey(const ValueKey('kit-sheet-handle')),
              findsNothing,
            );
          case 'side':
            expect(sheet.right, moreOrLessEquals(size.width, epsilon: 1));
            expect(sheet.width, inInclusiveRange(400, 480));
            expect(
              find.byKey(const ValueKey('kit-sheet-handle')),
              findsNothing,
            );
        }
      });
    }

    testWidgets('the side sheet opens from the start edge in Arabic', (
      tester,
    ) async {
      final context = await pumpKitHost(
        tester,
        size: const Size(1600, 1000),
        locale: const Locale('ar'),
      );
      unawaited(
        showKitSheet<void>(
          context,
          title: 'Language',
          height: KitSheetHeight.full,
          body: (_) => const Text('English'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(KitSheet)).left, moreOrLessEquals(0));
    });
  });

  test('window classes (§8.1)', () {
    expect(KitLayout.windowFor(360), KitWindow.compact);
    expect(KitLayout.windowFor(599.9), KitWindow.compact);
    expect(KitLayout.windowFor(600), KitWindow.medium);
    expect(KitLayout.windowFor(839), KitWindow.medium);
    expect(KitLayout.windowFor(840), KitWindow.expanded);
    expect(KitLayout.windowFor(1199), KitWindow.expanded);
    expect(KitLayout.windowFor(1200), KitWindow.large);
    expect(KitWindow.expanded.isWide, isTrue);
    expect(KitWindow.medium.isWide, isFalse);
  });

  testWidgets('the close button is a 48 dp target with its label', (
    tester,
  ) async {
    final context = await pumpKitHost(tester, light: true);
    unawaited(
      showKitSheet<void>(
        context,
        title: 'Language',
        body: (_) => const Text('English'),
      ),
    );
    await tester.pumpAndSettle();
    final close = tester.getSize(find.byTooltip('Close'));
    expect(close.width, greaterThanOrEqualTo(48));
    expect(close.height, greaterThanOrEqualTo(48));
    expect(find.byIcon(AppIconography.close), findsOneWidget);
  });
}
