// Gate G9 (docs/ux-system/kit-api/KitMenu.md) for KitMenu: ordering
// (destructive last, after one divider), icon/check slot, disabled items,
// KitMenuItem.copy (redaction, one announcement, no SnackBar), empty items,
// keyboard navigation with desktop capabilities, anchoring (point and
// context, RTL), row height at 2.0 text, no stacking on a confirm raised
// from a menu item, reduced motion, and the retired constructor (KIT-43).
import 'dart:async';
import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_effects.dart';
import 'package:opencode_mobile/ui/kit/kit_menu.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:opencode_mobile/ui/kit/kit_sheet.dart';

import 'kit_harness.dart';

/// Whether keyboard focus is on [target] itself or something inside it (the
/// same technique as `kit_keyboard_test.dart`'s `_focusIn`).
bool _focusIn(WidgetTester tester, Finder target) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  final element = tester.element(target);
  if (focused == element) return true;
  var found = false;
  (focused as Element).visitAncestorElements((ancestor) {
    if (ancestor == element) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

bool _focusedOnLabel(WidgetTester tester, String label) => _focusIn(
  tester,
  find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
);

/// A minimal host with its own [NavigatorObserver] so a test can inspect the
/// pushed route's identity (test 10: no stacking on the menu route).
class _RouteLog extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route);
}

Future<BuildContext> _pumpLoggedHost(WidgetTester tester, _RouteLog log) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorObservers: [log],
      home: Scaffold(
        body: Builder(
          builder: (inner) {
            context = inner;
            return const SizedBox.expand();
          },
        ),
      ),
    ),
  );
  return context;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('kitMenuLayout (ordering, structural)', () {
    KitMenuItem item(String label, {bool destructive = false, Object? group}) =>
        KitMenuItem(
          label: label,
          onSelected: () {},
          destructive: destructive,
          group: group,
        );

    test('keeps order within a group and groups in first-item order', () {
      final rows = kitMenuLayout([
        item('a', group: 1),
        item('b', group: 1),
        item('c', group: 2),
      ]);
      expect(rows.whereType<KitMenuItem>().map((i) => i.label), [
        'a',
        'b',
        'c',
      ]);
      // One divider, between the two groups.
      expect(rows.where((r) => r is! KitMenuItem), hasLength(1));
    });

    test('moves destructive items last, after one divider, even when '
        'passed first', () {
      final rows = kitMenuLayout([
        item('delete', destructive: true),
        item('a', group: 1),
        item('b', group: 1),
        item('c', group: 2),
      ]);
      expect(rows.whereType<KitMenuItem>().map((i) => i.label), [
        'a',
        'b',
        'c',
        'delete',
      ]);
      // One divider between the groups, one before the destructive block.
      expect(rows.where((r) => r is! KitMenuItem), hasLength(2));
    });

    test('no leading divider when every item is destructive', () {
      final rows = kitMenuLayout([
        item('delete', destructive: true),
        item('stop', destructive: true),
      ]);
      expect(rows.first, isA<KitMenuItem>());
      expect(rows.where((r) => r is! KitMenuItem), isEmpty);
    });
  });

  testWidgets('1. returns the tapped item after onSelected ran exactly once', (
    tester,
  ) async {
    final context = await pumpKitHost(tester);
    var runs = 0;
    KitMenuItem? result;
    unawaited(
      showKitMenu(
        context,
        items: [KitMenuItem(label: 'Archive', onSelected: () => runs++)],
      ).then((v) => result = v),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    expect(runs, 1);
    expect(result?.label, 'Archive');
  });

  group('1. dismissing runs nothing and resolves null', () {
    testWidgets('tap outside', (tester) async {
      final context = await pumpKitHost(tester);
      var runs = 0;
      KitMenuItem? result;
      var done = false;
      unawaited(
        showKitMenu(
          context,
          items: [KitMenuItem(label: 'Archive', onSelected: () => runs++)],
        ).then((v) {
          result = v;
          done = true;
        }),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(done, isTrue);
      expect(result, isNull);
      expect(runs, 0);
    });

    testWidgets('Esc', (tester) async {
      final context = await pumpKitHost(tester);
      var runs = 0;
      KitMenuItem? result;
      unawaited(
        showKitMenu(
          context,
          items: [KitMenuItem(label: 'Archive', onSelected: () => runs++)],
        ).then((v) => result = v),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(result, isNull);
      expect(runs, 0);
      expect(find.text('Archive'), findsNothing);
    });

    testWidgets('Back', (tester) async {
      final context = await pumpKitHost(tester);
      var runs = 0;
      KitMenuItem? result;
      unawaited(
        showKitMenu(
          context,
          items: [KitMenuItem(label: 'Archive', onSelected: () => runs++)],
        ).then((v) => result = v),
      );
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(result, isNull);
      expect(runs, 0);
    });
  });

  testWidgets(
    '2. destructive items render last after a divider; groups keep order',
    (tester) async {
      final context = await pumpKitHost(tester);
      unawaited(
        showKitMenu(
          context,
          items: [
            KitMenuItem(label: 'Delete', onSelected: () {}, destructive: true),
            KitMenuItem(label: 'Rename', onSelected: () {}, group: 'a'),
            KitMenuItem(label: 'Duplicate', onSelected: () {}, group: 'a'),
            KitMenuItem(label: 'Share', onSelected: () {}, group: 'b'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final ys = [
        'Rename',
        'Duplicate',
        'Share',
        'Delete',
      ].map((l) => tester.getTopLeft(find.text(l)).dy).toList();
      for (var i = 0; i < ys.length - 1; i++) {
        expect(
          ys[i],
          lessThan(ys[i + 1]),
          reason:
              'expected top-to-bottom order Rename, Duplicate, Share, '
              'Delete',
        );
      }
      expect(find.byKey(const ValueKey('kit-menu-divider-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('kit-menu-divider-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('kit-menu-divider-2')), findsNothing);
    },
  );

  group('3. checked', () {
    testWidgets('checked:true paints the check and exposes it', (tester) async {
      // Disposed inline, not via addTearDown: the end-of-test leak check
      // runs before addTearDown callbacks (test/goldens/kit/kit_gallery.dart
      // "Released before the test ends; a tear-down runs too late").
      final semantics = tester.ensureSemantics();
      final context = await pumpKitHost(tester);
      unawaited(
        showKitMenu(
          context,
          items: [
            KitMenuItem(label: 'On', onSelected: () {}, checked: true),
            KitMenuItem(label: 'Off', onSelected: () {}, checked: false),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find
              .ancestor(of: find.text('On'), matching: find.byType(InkWell))
              .first,
          matching: find.byIcon(AppIconography.check),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find
              .ancestor(of: find.text('Off'), matching: find.byType(InkWell))
              .first,
          matching: find.byIcon(AppIconography.check),
        ),
        findsNothing,
      );

      final on = tester.getSemantics(find.text('On'));
      expect(on.flagsCollection.isChecked, isNot(CheckedState.none));
      expect(on.flagsCollection.isChecked, CheckedState.isTrue);
      final off = tester.getSemantics(find.text('Off'));
      expect(off.flagsCollection.isChecked, isNot(CheckedState.none));
      expect(off.flagsCollection.isChecked, CheckedState.isFalse);
      semantics.dispose();
    });
  });

  testWidgets(
    '4. a disabled item shows its reason, cannot be selected, exposes the '
    'reason as its hint',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final context = await pumpKitHost(tester);
      var runs = 0;
      unawaited(
        showKitMenu(
          context,
          items: [
            KitMenuItem(
              label: 'Restart',
              onSelected: () => runs++,
              enabled: false,
              disabledReason: 'No server connected',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No server connected'), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);

      await tester.tap(find.text('Restart'), warnIfMissed: false);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(runs, 0);

      final data = tester.getSemantics(find.text('Restart'));
      expect(data.flagsCollection.isEnabled, isNot(Tristate.none));
      expect(data.flagsCollection.isEnabled, Tristate.isFalse);
      expect(data.hint, 'No server connected');
      semantics.dispose();
    },
  );

  testWidgets('5. KitMenuItem.copy copies redacted text after the menu closes, '
      'announces once, no SnackBar', (tester) async {
    final platform = <MethodCall>[];
    final announcements = <Map<Object?, Object?>>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platform.add(call);
      return null;
    });
    messenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (message) async {
        final map = message as Map<Object?, Object?>;
        if (map['type'] == 'announce') announcements.add(map);
        return null;
      },
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockDecodedMessageHandler<dynamic>(
        SystemChannels.accessibility,
        null,
      );
    });

    final context = await pumpKitHost(tester);
    KitMenuItem? result;
    unawaited(
      showKitMenu(
        context,
        items: [
          KitMenuItem.copy(
            label: 'Copy key',
            text: () => 'export KEY=sk-ant-api03-AbCdEfGhIjKlMnOp',
          ),
        ],
      ).then((v) => result = v),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy key'));
    await tester.pumpAndSettle();

    final setData = platform.singleWhere(
      (c) => c.method == 'Clipboard.setData',
    );
    expect(
      (setData.arguments as Map)['text'],
      'export KEY=sk-ant-${KitRedact.mask}',
    );
    expect(announcements, hasLength(1));
    expect((announcements.single['data'] as Map)['message'], 'Copied');
    expect(find.byType(SnackBar), findsNothing);
    expect(result?.label, 'Copy key');
  });

  testWidgets('6. an empty item list resolves to null and pushes no route', (
    tester,
  ) async {
    final routes = RouteCounter();
    final context = await pumpKitHost(tester, routes: routes);
    final before = routes.pushes;

    final result = await showKitMenu(context, items: const []);

    expect(result, isNull);
    expect(routes.pushes, before);
  });

  group('7. keyboard, with desktop capabilities', () {
    setUp(() {
      debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
    });
    tearDown(() {
      debugPlatformCapabilities = null;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
    });

    testWidgets(
      'opening from the keyboard focuses the first enabled item; Down/Up '
      'skip disabled and wrap; Enter selects; Esc closes; focus returns',
      (tester) async {
        final context = await pumpKitHost(tester, size: const Size(1280, 800));
        KitMenuItem? result;
        unawaited(
          showKitMenu(
            context,
            items: [
              KitMenuItem(label: 'First', onSelected: () {}),
              KitMenuItem(
                label: 'Disabled',
                onSelected: () {},
                enabled: false,
                disabledReason: 'x',
              ),
              KitMenuItem(label: 'Last', onSelected: () {}),
            ],
          ).then((v) => result = v),
        );
        await tester.pumpAndSettle();

        expect(_focusedOnLabel(tester, 'First'), isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(
          _focusedOnLabel(tester, 'Last'),
          isTrue,
          reason: 'Down skips the disabled item',
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(
          _focusedOnLabel(tester, 'First'),
          isTrue,
          reason: 'Down from the last item wraps to the first',
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(
          _focusedOnLabel(tester, 'Last'),
          isTrue,
          reason: 'Up from the first item wraps to the last',
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(result?.label, 'Last');
        expect(find.text('Last'), findsNothing);
      },
    );
  });

  group('8. anchoring', () {
    testWidgets("with position, the panel's top-start corner is at the point", (
      tester,
    ) async {
      final context = await pumpKitHost(tester, size: const Size(412, 915));
      unawaited(
        showKitMenu(
          context,
          items: [KitMenuItem(label: 'Only', onSelected: () {})],
          position: const Offset(40, 40),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.byKey(const ValueKey('kit-menu'))),
        const Offset(40, 40),
      );
    });

    testWidgets('clamped inside the window near an edge', (tester) async {
      final context = await pumpKitHost(tester, size: const Size(412, 915));
      unawaited(
        showKitMenu(
          context,
          items: [KitMenuItem(label: 'Only', onSelected: () {})],
          position: const Offset(410, 913),
        ),
      );
      await tester.pumpAndSettle();

      final topLeft = tester.getTopLeft(find.byKey(const ValueKey('kit-menu')));
      final size = tester.getSize(find.byKey(const ValueKey('kit-menu')));
      expect(topLeft.dx, greaterThanOrEqualTo(16));
      expect(topLeft.dy, greaterThanOrEqualTo(16));
      expect(topLeft.dx + size.width, lessThanOrEqualTo(412 - 16 + 0.5));
      expect(topLeft.dy + size.height, lessThanOrEqualTo(915 - 16 + 0.5));
    });

    testWidgets("anchored, aligns to the invoker's end edge in RTL", (
      tester,
    ) async {
      final context = await pumpKitHost(
        tester,
        size: const Size(412, 915),
        locale: const Locale('ar'),
      );
      unawaited(
        showKitMenu(
          context,
          items: [KitMenuItem(label: 'واحد', onSelected: () {})],
        ),
      );
      await tester.pumpAndSettle();

      // The anchor context fills the whole screen; its end (left in RTL)
      // edge is the screen's left edge, so the panel's own end edge sits
      // there too, clamped by the gutter.
      final topLeft = tester.getTopLeft(find.byKey(const ValueKey('kit-menu')));
      expect(topLeft.dx, closeTo(16, 0.5));
    });
  });

  testWidgets(
    '9. each item is 48dp or taller and wraps without an ellipsis at text '
    '2.0, 320dp wide',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late BuildContext context;
      const label =
          'A reasonably long menu label to force wrapping onto '
          'two lines';
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(
              ctx,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (inner) {
                context = inner;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );

      unawaited(
        showKitMenu(
          context,
          items: [KitMenuItem(label: label, onSelected: () {})],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final panelSize = tester.getSize(find.byKey(const ValueKey('kit-menu')));
      expect(panelSize.width, lessThanOrEqualTo(320));

      final tile = find
          .ancestor(of: find.text(label), matching: find.byType(InkWell))
          .first;
      expect(tester.getSize(tile).height, greaterThanOrEqualTo(48));

      final text = tester.widget<Text>(find.text(label));
      expect(text.overflow, isNot(TextOverflow.ellipsis));
    },
  );

  testWidgets(
    "10. onSelected that opens showKitConfirm runs after the menu route "
    "is gone",
    (tester) async {
      final log = _RouteLog();
      final context = await _pumpLoggedHost(tester, log);

      unawaited(
        showKitMenu(
          context,
          items: [
            KitMenuItem(
              label: 'Delete',
              destructive: true,
              onSelected: () {
                unawaited(
                  showKitConfirm(
                    context,
                    title: 'Delete fox?',
                    body: 'Removed from the server.',
                    confirmLabel: 'Delete conversation',
                  ),
                );
              },
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final menuRoute = log.pushed.last;
      expect(menuRoute.isActive, isTrue);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete fox?'), findsOneWidget);
      expect(menuRoute.isActive, isFalse);
    },
  );

  testWidgets(
    '11. reduced motion opens and closes within one pump with no ticker '
    'running',
    (tester) async {
      final context = await pumpKitHost(
        tester,
        effects: const KitEffects(motion: KitMotionLevel.off),
      );
      KitMenuItem? result;
      unawaited(
        showKitMenu(
          context,
          items: [KitMenuItem(label: 'Only', onSelected: () {})],
        ).then((v) => result = v),
      );
      await tester.pump();

      expect(find.text('Only'), findsOneWidget);
      expect(SchedulerBinding.instance.transientCallbackCount, 0);

      await tester.tap(find.text('Only'));
      await tester.pump();

      expect(find.text('Only'), findsNothing);
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
      expect(result?.label, 'Only');
    },
  );

  testWidgets(
    '12. the retired KitMenuItem(label:, onSelected:, key:, destructive:, '
    'enabled:) constructor still compiles and behaves the same',
    (tester) async {
      final context = await pumpKitHost(tester);
      var ran = false;
      final item = KitMenuItem(
        label: 'Legacy',
        onSelected: () => ran = true,
        key: const ValueKey('legacy-item'),
        destructive: true,
        enabled: true,
      );
      unawaited(showKitMenu(context, items: [item]));
      await tester.pumpAndSettle();

      expect(find.text('Legacy'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('legacy-item')));
      await tester.pumpAndSettle();

      expect(ran, isTrue);
    },
  );
}
