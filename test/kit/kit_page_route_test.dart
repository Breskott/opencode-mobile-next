// KitPageRoute contract tests (docs/ux-system/kit-api/KitPageRoute.md "Tests
// required").
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/kit/kit_motion.dart';
import 'package:opencode_mobile/ui/kit/kit_page_route.dart';

/// Pumps an empty [MaterialApp] at [theme] and [locale] and returns a
/// context under its Navigator to push from. [disableAnimations] seeds
/// `MediaQuery.disableAnimationsOf` (the "remove animations" setting);
/// [toggleAnimations], when given, lets a test flip it later without a new
/// pump tree (the element identity, and any state under it, is kept).
Future<BuildContext> _pumpApp(
  WidgetTester tester, {
  ThemeData? theme,
  Locale locale = const Locale('en'),
  bool disableAnimations = false,
  ValueNotifier<bool>? toggleAnimations,
}) async {
  late BuildContext context;
  Widget app(bool disable) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: disable),
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
  );
  if (toggleAnimations != null) {
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: toggleAnimations,
        builder: (context, disable, child) => app(disable),
      ),
    );
  } else {
    await tester.pumpWidget(app(disableAnimations));
  }
  return context;
}

/// Every [Transform] in the tree under [finder] whose matrix has moved (a
/// non-zero x translation): the signature of the kit's `_Axis` widget mid
/// transition (Zoom and Cupertino's builders use `ScaleTransition` /
/// `SlideTransition`, never a bare translating `Transform`).
Iterable<double> _translationsX(WidgetTester tester, Finder finder) => tester
    .widgetList<Transform>(finder)
    .map((t) => t.transform.getTranslation().x)
    .where((dx) => dx != 0);

/// [matching] among the ancestors of the arriving page's own content, not
/// the whole tree — `MaterialApp`'s own initial (implicit) route keeps its
/// platform `ZoomPageTransitionsBuilder` wrapper (a settled `ScaleTransition`
/// at scale 1.0) for as long as it is mounted, which is not what these tests
/// are about.
Finder _underB(Finder matching) =>
    find.ancestor(of: find.text('B'), matching: matching);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'transitionDuration and reverseTransitionDuration are KitMotion.standard',
    () {
      final route = KitPageRoute<void>(builder: (_) => const SizedBox.shrink());
      expect(route.transitionDuration, KitMotion.standard);
      expect(route.reverseTransitionDuration, KitMotion.standard);
    },
  );

  testWidgets(
    'under a bare ThemeData the kit\'s own transition still plays, not the '
    'platform default',
    (tester) async {
      final context = await _pumpApp(tester, theme: ThemeData());
      unawaited(pushKitPage<void>(context, (_) => const Text('B')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 125));

      expect(_underB(find.byType(ScaleTransition)), findsNothing);
      expect(
        _translationsX(tester, _underB(find.byType(Transform))),
        isNotEmpty,
        reason: 'the kit\'s axis widget should be sliding the arriving page',
      );
    },
  );

  testWidgets('mid-transition there is no scale or blur (MOT-2)', (
    tester,
  ) async {
    final context = await _pumpApp(tester);
    unawaited(pushKitPage<void>(context, (_) => const Text('B')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 125));

    expect(_underB(find.byType(ScaleTransition)), findsNothing);
    expect(_underB(find.byType(ImageFiltered)), findsNothing);
    expect(_underB(find.byType(BackdropFilter)), findsNothing);
    final scaled = tester
        .widgetList<Transform>(_underB(find.byType(Transform)))
        .where((t) => t.transform.getMaxScaleOnAxis() != 1.0);
    expect(scaled, isEmpty);
  });

  testWidgets(
    'under disableAnimations the new page is opaque and in place with no '
    'elapsed animation time',
    (tester) async {
      final context = await _pumpApp(tester, disableAnimations: true);
      unawaited(pushKitPage<void>(context, (_) => const Text('B')));
      // Two zero-duration pumps: one for Navigator.push's own state change,
      // one to build the new route's overlay entry — no animation time
      // elapses (G8x: reduced motion never waits out the real duration).
      await tester.pump();
      await tester.pump();

      expect(find.text('B'), findsOneWidget);
      for (final o in tester.widgetList<Opacity>(
        find.ancestor(of: find.text('B'), matching: find.byType(Opacity)),
      )) {
        expect(o.opacity, 1.0);
      }
      for (final t in tester.widgetList<Transform>(
        find.ancestor(of: find.text('B'), matching: find.byType(Transform)),
      )) {
        expect(t.transform.getTranslation().x, 0);
      }
    },
  );

  testWidgets('RTL: the arriving page slides in from the left (negative x)', (
    tester,
  ) async {
    final context = await _pumpApp(tester, locale: const Locale('ar'));
    unawaited(pushKitPage<void>(context, (_) => const Text('B')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 125));

    final dxs = _translationsX(
      tester,
      find.ancestor(of: find.text('B'), matching: find.byType(Transform)),
    ).toList();
    expect(dxs, isNotEmpty);
    for (final dx in dxs) {
      expect(dx, lessThan(0));
    }
  });

  testWidgets(
    'pushKitPage resolves with the popped value and keeps settings.name',
    (tester) async {
      final context = await _pumpApp(tester);
      String? nameInsidePage;
      final result = pushKitPage<String>(context, (inner) {
        nameInsidePage = ModalRoute.of(inner)?.settings.name;
        return const SizedBox.shrink();
      }, settings: const RouteSettings(name: '/b'));
      await tester.pumpAndSettle();
      expect(nameInsidePage, '/b');

      Navigator.of(context).pop('done');
      await tester.pumpAndSettle();
      expect(await result, 'done');
    },
  );

  testWidgets('fullscreenDialog is visible on ModalRoute.of inside the page', (
    tester,
  ) async {
    final context = await _pumpApp(tester);
    bool? fullscreen;
    unawaited(
      pushKitPage<void>(context, (inner) {
        fullscreen = ModalRoute.of(inner)!.fullscreenDialog;
        return const SizedBox.shrink();
      }, fullscreenDialog: true),
    );
    await tester.pumpAndSettle();
    expect(fullscreen, isTrue);
  });

  testWidgets(
    'a draft in the page underneath survives push, pop and a reduced-motion '
    'toggle while the page above is open',
    (tester) async {
      final toggle = ValueNotifier<bool>(false);
      addTearDown(toggle.dispose);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      late BuildContext context;
      await tester.pumpWidget(
        ValueListenableBuilder<bool>(
          valueListenable: toggle,
          builder: (outerContext, disable, child) => MaterialApp(
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: disable),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (inner) {
                  context = inner;
                  return TextField(controller: controller);
                },
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'draft text');
      expect(controller.text, 'draft text');

      unawaited(pushKitPage<void>(context, (_) => const SizedBox.shrink()));
      await tester.pumpAndSettle();

      // Toggle reduced motion while the pushed page is still open.
      toggle.value = true;
      await tester.pump();
      toggle.value = false;
      await tester.pump();

      Navigator.of(context).pop();
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(controller.text, 'draft text');
    },
  );

  testWidgets('replaceWithKitPage removes the route it replaces', (
    tester,
  ) async {
    final context = await _pumpApp(tester);
    late BuildContext pageAContext;
    unawaited(
      pushKitPage<void>(context, (inner) {
        pageAContext = inner;
        return const Text('A');
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);

    final result = replaceWithKitPage<String, void>(
      pageAContext,
      (_) => const Text('B'),
    );
    await tester.pumpAndSettle();

    expect(find.text('B'), findsOneWidget);
    expect(
      find.text('A'),
      findsNothing,
      reason: 'the replaced route must be gone, not merely covered',
    );

    Navigator.of(context).pop('bye');
    await tester.pumpAndSettle();
    expect(find.text('B'), findsNothing);
    expect(await result, 'bye');
  });
}
