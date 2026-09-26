// shared-team-2 (wave 2a): the AI Team's shared pieces rebuilt from kit
// parts. The host's Technical details sheet (team-host-details-sheet) is
// the kit's one sheet with every raw value once, in one open fold; a raw
// value row (embedded-team-technical-value) copies through the kit's one
// copy service from a 48 dp target, never a snackbar.
//
// Goldens: the host sheet at 412x915 and 1280x800, dark and light (owner
// decision 2026-09-27: phone and one wide size, no Arabic).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/shared_team_2_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/ui/kit/kit_details_fold.dart';
import 'package:opencode_mobile/ui/widgets/team_technical_details.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;
import '../support/team_golden_fixture.dart';

Finder _key(String name) => find.byKey(ValueKey(name));

/// Records what reaches the clipboard.
List<String> _mockClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

Widget _app(Widget home, {bool light = false, GlobalKey? boundary}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: captureTheme(light: light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: RepaintBoundary(key: boundary, child: child),
      ),
      home: home,
    );

Future<OrchestrationController> _openHostSheet(
  WidgetTester tester, {
  Size size = const Size(412, 915),
  bool light = false,
  GlobalKey? boundary,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  resetTeamMoments();
  final controller = await teamSceneController(TeamScene.loaded);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    _app(
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: GestureDetector(
              key: const ValueKey('open'),
              behavior: HitTestBehavior.opaque,
              onTap: () => showTeamHostDetailsSheet(context, controller),
              child: const SizedBox.square(dimension: 48),
            ),
          ),
        ),
      ),
      light: light,
      boundary: boundary,
    ),
  );
  // The first page settles in before the sheet opens over it.
  await tester.pumpAndSettle();
  await tester.tap(_key('open'));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final en = lookupAppLocalizations(const Locale('en'));

  group('team-host-details-sheet', () {
    testWidgets('the kit sheet names itself; each raw value shows once, in '
        'one open fold', (tester) async {
      final controller = await _openHostSheet(tester);
      final sheet = _key('team-home-host-sheet');
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(
          of: sheet,
          matching: find.text(en.teamUiTechnicalDetails),
        ),
        findsOneWidget,
      );
      // One fold, open: the person came here for these values.
      expect(find.byType(KitDetailsFold), findsOneWidget);
      expect(
        find.descendant(
          of: sheet,
          matching: find.text(en.teamUiHomeHostRawHeading),
        ),
        findsOneWidget,
      );
      final address = controller.host?.url ?? controller.config.url;
      final city = controller.config.city;
      final version = controller.host?.version;
      for (final value in [address, city, ?version]) {
        expect(
          find.descendant(of: sheet, matching: find.text(value)),
          findsOneWidget,
          reason: '$value shows once (map: dedupe values)',
        );
      }
      // The host kind's line and the glossary stay readable above it.
      expect(_key('team-host-disclaimer'), findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.textContaining('polecat')),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('copying a value puts it on the clipboard and shows no '
        'snackbar', (tester) async {
      final copied = _mockClipboard(tester);
      final controller = await _openHostSheet(tester);
      final address = controller.host?.url ?? controller.config.url;
      final copy = find.byTooltip(en.kitCopyValue('address'));
      expect(copy, findsOneWidget);
      await tester.ensureVisible(copy);
      await tester.tap(copy);
      await tester.pump();
      expect(copied, [address]);
      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpAndSettle();
    });

    for (final (size, suffix) in [
      (const Size(412, 915), ''),
      (const Size(1280, 800), '_1280x800'),
    ]) {
      for (final light in [false, true]) {
        final mode = light ? 'light' : 'dark';
        testWidgets('golden: open$suffix · $mode', (tester) async {
          await tester.runAsync(loadCaptureFonts);
          final boundary = GlobalKey();
          await _openHostSheet(
            tester,
            size: size,
            light: light,
            boundary: boundary,
          );
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(boundary),
            matchesGoldenFile(
              'goldens/team_host_details_sheet_open${suffix}_$mode.png',
            ),
          );
        });
      }
    }
  });

  group('embedded-team-technical-value', () {
    Future<void> pumpValue(WidgetTester tester, String value) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: TeamTechnicalValue(label: 'Branch', value: value),
          ),
        ),
      );
    }

    testWidgets('label over the mono value; a 48 dp copy target on the rail '
        'copies it, with no snackbar', (tester) async {
      final copied = _mockClipboard(tester);
      await pumpValue(tester, 'revamp/shared-team-2');
      expect(find.text('Branch'), findsOneWidget);
      expect(find.text('revamp/shared-team-2'), findsOneWidget);
      final copy = find.byTooltip(en.kitCopyValue('branch'));
      expect(copy, findsOneWidget);
      final box = tester.getSize(copy);
      expect(box.width, greaterThanOrEqualTo(48));
      expect(box.height, greaterThanOrEqualTo(48));
      // On the rail: the copy target ends the row.
      expect(tester.getTopRight(copy).dx, closeTo(412, 1));
      await tester.tap(copy);
      await tester.pump();
      expect(copied, ['revamp/shared-team-2']);
      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('an empty value shows a dash and offers nothing to copy', (
      tester,
    ) async {
      await pumpValue(tester, '');
      expect(find.text('—'), findsOneWidget);
      expect(find.byTooltip(en.kitCopyValue('branch')), findsNothing);
    });

    test('asKit hands the same value to a KitDetailsFold', () {
      const row = TeamTechnicalValue(label: 'Branch', value: 'main');
      expect(row.asKit.label, 'Branch');
      expect(row.asKit.value, 'main');
      expect(row.asKit.copyable, isTrue);
      expect(
        const TeamTechnicalValue(label: 'City', value: '').asKit.copyable,
        isFalse,
      );
    });
  });
}
