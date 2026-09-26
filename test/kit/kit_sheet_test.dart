// KitSheet (docs/ux-system/kit-v2.md §1.1, §4.7, §8.2): the frame, its
// unsaved-input guard (the discard question asked in place), and the shape
// it takes per window class.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/widgets/request_routes.dart';

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

  group('the header icon tile (§5 Sheets)', () {
    testWidgets(
      'with icon, the tile sits above the title, at the start, and is '
      'excluded from semantics',
      (tester) async {
        final context = await pumpKitHost(tester);
        unawaited(
          showKitSheet<void>(
            context,
            title: 'Language',
            icon: AppIconography.globe,
            body: (_) => const Text('English'),
          ),
        );
        await tester.pumpAndSettle();
        final tile = find.byKey(const ValueKey('kit-sheet-icon'));
        expect(tile, findsOneWidget);
        final glyph = find.descendant(
          of: tile,
          matching: find.byIcon(AppIconography.globe),
        );
        expect(glyph, findsOneWidget);
        expect(
          find.ancestor(of: glyph, matching: find.byType(ExcludeSemantics)),
          findsOneWidget,
        );
        final tileRect = tester.getRect(tile);
        final titleRect = tester.getRect(find.text('Language'));
        expect(tileRect.bottom, lessThanOrEqualTo(titleRect.top));
        expect(tileRect.left, moreOrLessEquals(titleRect.left, epsilon: 1));
      },
    );

    testWidgets('without icon, no tile is drawn', (tester) async {
      final context = await pumpKitHost(tester);
      unawaited(
        showKitSheet<void>(
          context,
          title: 'Language',
          body: (_) => const Text('English'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kit-sheet-icon')), findsNothing);
    });

    testWidgets(
      'tone: attention paints the glyph in attention, neutral in text1',
      (tester) async {
        final context = await pumpKitHost(tester, light: true);
        final roles = ThemeRoles.resolve(AppTheme.light());
        Icon glyphOf(Finder tile) => tester.widget<Icon>(
          find.descendant(of: tile, matching: find.byType(Icon)),
        );

        unawaited(
          showKitSheet<void>(
            context,
            title: 'Language',
            icon: AppIconography.globe,
            body: (_) => const Text('English'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          glyphOf(find.byKey(const ValueKey('kit-sheet-icon'))).color,
          roles.text1,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        unawaited(
          showKitSheet<void>(
            context,
            title: 'Approve run',
            icon: AppIconography.globe,
            tone: KitSheetTone.attention,
            body: (_) => const Text('Run it?'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          glyphOf(find.byKey(const ValueKey('kit-sheet-icon'))).color,
          roles.attention,
        );
      },
    );
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
    expect(find.byType(KitIconButton), findsNothing);
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
      (const Size(1600, 1000), KitSheetHeight.content, 'panel'),
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
    expect(find.byType(KitIconButton), findsOneWidget);
    final close = tester.getSize(find.byTooltip('Close'));
    expect(close.width, greaterThanOrEqualTo(48));
    expect(close.height, greaterThanOrEqualTo(48));
    expect(find.byIcon(AppIconography.close), findsOneWidget);
  });

  testWidgets('the grabber exposes the "Dismiss" action when dismissible', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final context = await pumpKitHost(tester);
    unawaited(
      showKitSheet<void>(
        context,
        title: 'Language',
        body: (_) => const Text('English'),
      ),
    );
    await tester.pumpAndSettle();
    // Sibling declarative Semantics with no boundary of their own merge
    // into one node here (the grabber and the header), so only the action
    // itself (not the whole flag/label set) is checked.
    final node = tester.getSemantics(
      find.byKey(const ValueKey('kit-sheet-handle')),
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.dismiss), isTrue);
    handle.dispose();
  });

  testWidgets('pinned actions stay visible with the keyboard open (KIT-17)', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final context = await pumpKitHost(tester);
    unawaited(
      showKitSheet<void>(
        context,
        title: 'Language',
        // The body scrolls inside the frame's own scroll view; it is
        // never its own ListView (KitSheet's contract).
        body: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(20, (i) => Text('Row $i')),
        ),
        primary: KitAction(label: 'Use English', onPressed: () {}),
      ),
    );
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final windowHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final primaryRect = tester.getRect(find.text('Use English'));
    expect(primaryRect.bottom, lessThanOrEqualTo(windowHeight));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  group('stacked actions (§5 Sheets)', () {
    testWidgets('actions stack full width on a phone (§8.2)', (tester) async {
      final context = await pumpKitHost(tester, size: const Size(412, 915));
      unawaited(
        showKitSheet<void>(
          context,
          title: 'Language',
          body: (_) => const Text('English'),
          primary: KitAction(label: 'Use English', onPressed: () {}),
          secondary: KitAction(label: 'Keep current', onPressed: () {}),
        ),
      );
      await tester.pumpAndSettle();
      Rect buttonRect(String label) => tester.getRect(
        find.ancestor(of: find.text(label), matching: find.byType(KitButton)),
      );
      final primary = buttonRect('Use English');
      final secondary = buttonRect('Keep current');
      // Stacked: the secondary sits under the primary, both full width.
      expect(secondary.top, greaterThanOrEqualTo(primary.bottom));
      expect(primary.left, moreOrLessEquals(secondary.left, epsilon: 1));
      expect(primary.width, moreOrLessEquals(secondary.width, epsilon: 1));
      // The row-on-PC half of this acceptance needs kit-KitAction-v2's
      // window-class rule (today's KitActionBlock rows only at
      // maxWidth >= 600, which the 560 dp panel never reaches). NOT proven
      // until it merges (README.md decision D4).
    });
  });

  group('routes: closes itself when its request is answered elsewhere', () {
    testWidgets(
      'flipping isPending to false while open removes the route after '
      'one frame, and the future completes with null',
      (tester) async {
        final context = await pumpKitHost(tester);
        var pending = true;
        final changes = ChangeNotifier();
        addTearDown(changes.dispose);
        final routes = RequestRoutes(
          changes: changes,
          isPending: () => pending,
        );
        String? result = 'unset';
        unawaited(
          showKitSheet<String>(
            context,
            title: 'Approve',
            body: (_) => const Text('Run the build?'),
            routes: routes,
          ).then((v) => result = v),
        );
        await tester.pumpAndSettle();
        expect(find.text('Approve'), findsOneWidget);
        pending = false;
        changes.notifyListeners();
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.text('Approve'), findsNothing);
        expect(result, isNull);
      },
    );

    testWidgets('a non-pending routes at call time pushes no route', (
      tester,
    ) async {
      final routes = RouteCounter();
      final context = await pumpKitHost(tester, routes: routes);
      final before = routes.pushes;
      final requestRoutes = RequestRoutes(isPending: () => false);
      final result = await showKitSheet<String>(
        context,
        title: 'Approve',
        body: (_) => const Text('Run the build?'),
        routes: requestRoutes,
      );
      expect(result, isNull);
      expect(find.text('Approve'), findsNothing);
      expect(routes.pushes, before);
    });
  });
}
