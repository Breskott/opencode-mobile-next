// shared-settings-1 (wave 2a): the Language sheet's honest Arabic offer, the
// theme preview sheet's "In use now" line and Undo after Apply, and the AI
// team discovery offer's stacked actions and failed turn-on.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_undo.dart';
import 'package:opencode_mobile/ui/widgets/appearance_picker.dart';
import 'package:opencode_mobile/ui/widgets/language_picker.dart';
import 'package:opencode_mobile/ui/screens/settings/plugins_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n_coverage_test.dart' show scan;
import 'shared_settings_harness.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  // Reduced motion: the preview's working mark holds still, so the tree
  // settles (G8).
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: Scaffold(body: home),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Map<String, Object?> _arb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in ['oc/background', 'oc/shortcut']) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(MethodChannel(channel), null),
      );
    }
  });

  group('language sheet', () {
    test('the Arabic share is the real coverage, within 3 points', () {
      bool message(String key) => !key.startsWith('@');
      final en = _arb('lib/l10n/app_en.arb').keys.where(message).toSet();
      final ar = _arb(
        'lib/l10n/app_ar.arb',
      ).keys.where(message).where(en.contains).length;
      final hardcoded = scan().values.fold<int>(0, (a, b) => a + b);
      final percent = ar * 100 ~/ (en.length + hardcoded);
      expect(
        (percent - arabicTranslatedPercent).abs(),
        lessThanOrEqualTo(3),
        reason:
            'Arabic covers $percent % ($ar of ${en.length} catalogue '
            'strings + $hardcoded in code); set arabicTranslatedPercent in '
            'lib/ui/widgets/language_picker.dart to $percent.',
      );
    });

    testWidgets('Arabic says it is partly translated, with the share', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final controller = ConnectionController(
        ProfileStore(prefs: await SharedPreferences.getInstance()),
        isIsolated: true,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(LanguageSettingsTile(controller: controller)),
      );
      await tester.tap(find.text(_l10n.e7LocaleUiLanguage));
      await tester.pumpAndSettle();
      final share = _l10n.languagePickerPartlyTranslated(
        arabicTranslatedPercent,
      );
      expect(share, 'Partly translated ($arabicTranslatedPercent %)');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('language-choice-ar')),
          matching: find.text(share),
        ),
        findsOneWidget,
      );
      // Only Arabic carries the note.
      expect(find.text(share), findsOneWidget);
      // Choosing the language in use just closes the sheet.
      await tester.tap(find.text(_l10n.e7LocaleUiSystem).last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('language-sheet')), findsNothing);
      expect(controller.appLocale.value, isNull);
    });
  });

  group('theme preview sheet', () {
    Future<ConnectionController> open(
      WidgetTester tester,
      ThemePackId pack,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final controller = ConnectionController(
        ProfileStore(prefs: await SharedPreferences.getInstance()),
        isIsolated: true,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Center(
              child: GestureDetector(
                onTap: () => showThemePackPreview(
                  context,
                  controller: controller,
                  pack: pack,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('the pack in use says so in words, not a disabled button', (
      tester,
    ) async {
      await open(tester, ThemePackId.opencode);
      expect(find.text(_l10n.appearancePickerInUse), findsOneWidget);
      expect(find.text(_l10n.e7AppearanceApply), findsNothing);
      expect(find.text(_l10n.e7AppearanceCurrent), findsNothing);
    });

    testWidgets('Apply saves the pack and Undo puts the old one back', (
      tester,
    ) async {
      final controller = await open(tester, ThemePackId.gruvbox);
      expect(find.text(_l10n.appearancePickerInUse), findsNothing);
      // Previewing in light only changes the picture.
      final appearance = controller.appearance.value;
      await tester.tap(find.byKey(const ValueKey('appearance-preview-light')));
      await tester.pumpAndSettle();
      expect(controller.appearance.value, appearance);
      await tester.tap(find.text(_l10n.e7AppearanceApply));
      await tester.pumpAndSettle();
      expect(controller.themePack.value, ThemePackId.gruvbox);
      expect(find.byKey(const Key('appearance-picker')), findsNothing);
      expect(
        find.text(_l10n.appearancePickerThemeApplied('Gruvbox')),
        findsOneWidget,
      );
      await tester.tap(find.text(_l10n.kitUndoAction));
      await tester.pumpAndSettle();
      expect(controller.themePack.value, ThemePackId.opencode);
      expect(controller.store.themePack, ThemePackId.opencode);
      KitUndo.commitPending();
    });
  });

  // Review board, embedded-team-discovery-card: the offer is folded into
  // the Plugins AI Team row ("Found on Workstation" + Turn on), so the team
  // has one presence on the page.
  group('team found on the server', () {
    Future<(ConnectionController, FlakyProfileStore)> pump(
      WidgetTester tester, {
      Size size = const Size(412, 915),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final booted = await bootWorkstation();
      addTearDown(booted.$1.dispose);
      await tester.pumpWidget(
        _app(PluginsSettingsScreen(controller: booted.$1, probe: teamProbe)),
      );
      await _settle(tester);
      return booted;
    }

    String rowLine(WidgetTester tester) {
      final text = tester.widget<Text>(
        find.byKey(const ValueKey('plugins-ai-team-subtitle')),
      );
      return text.data ?? text.textSpan!.toPlainText();
    }

    testWidgets('one row says where it was found and carries Turn on, with '
        'no separate card', (tester) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('team-discovery-card')), findsNothing);
      expect(rowLine(tester), _l10n.pluginsTeamRowFound('Workstation'));
      final row = find.byKey(const ValueKey('plugins-ai-team-row'));
      final turnOn = find.byKey(const ValueKey('plugins-ai-team-turn-on'));
      expect(find.descendant(of: row, matching: turnOn), findsOneWidget);
      expect(
        find.descendant(of: turnOn, matching: find.text('Turn on')),
        findsOneWidget,
      );
      // Engine words (Gas City, its version, the city) stay on the page.
      expect(find.textContaining('Gas City'), findsNothing);
      expect(find.textContaining('bright-lights'), findsNothing);
    });

    testWidgets('a failed turn-on says so on the row, keeps Turn on and can '
        'retry', (tester) async {
      final (controller, store) = await pump(tester);
      store.fail = true;
      await tester.tap(find.byKey(const ValueKey('plugins-ai-team-turn-on')));
      await _settle(tester);
      expect(rowLine(tester), _l10n.teamDiscoveryCardTurnOnFailed);
      expect(controller.profile!.orchestration, isNull);
      store.fail = false;
      await tester.tap(find.byKey(const ValueKey('plugins-ai-team-turn-on')));
      await _settle(tester);
      expect(controller.profile!.orchestration?.city, 'bright-lights');
      expect(
        find.byKey(const ValueKey('plugins-ai-team-turn-on')),
        findsNothing,
      );
    });
  });
}
