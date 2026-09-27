// Golden renders of screen-library-3's pages (wave 2b): Tools and its
// detail sheet, manage accounts and its remove question, server sign-in,
// the unfinished sign-in cards on Providers, the Plugins page and the AI
// Team sheet. Phone 412x915 and one wide window (1280x800) for the pages,
// dark and light (owner decision 2026-09-27: no Arabic), with the app's
// real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/screen_library_3_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/pending_auth.dart';
import 'package:opencode_mobile/ui/screens/library_screen.dart';
import 'package:opencode_mobile/ui/screens/tools_screen.dart';
import 'package:opencode_mobile/ui/widgets/provider_logo.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;
import 'screen_library_3_fixtures.dart';

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

String _name(String shot, Size size, bool light) => [
  shot,
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

Future<void> _shot(
  WidgetTester tester,
  String shot, {
  required bool light,
  required Widget home,
  Size size = _phone,
  Future<void> Function()? act,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  final boundary = GlobalKey();
  try {
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: captureTheme(light: light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (act != null) {
      await act();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/${_name(shot, size, light)}.png'),
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  setUpAll(() => ProviderLogo.imageProviderOverride = (_) => null);
  tearDownAll(() => ProviderLogo.imageProviderOverride = null);
  mockLibrary3SecureStorage();

  for (final light in [false, true]) {
    final tone = light ? 'light' : 'dark';

    group('tools ($tone)', () {
      for (final size in [_phone, _wide]) {
        testWidgets('loaded ${size.width.toInt()}', (tester) async {
          final c = await library3Server();
          addTearDown(c.dispose);
          await _shot(
            tester,
            'library_tools_loaded',
            light: light,
            size: size,
            home: ToolsScreen(controller: c),
          );
        });
      }

      testWidgets('detail sheet', (tester) async {
        final c = await library3Server();
        addTearDown(c.dispose);
        await _shot(
          tester,
          'library_tools_detail_sheet',
          light: light,
          home: ToolsScreen(controller: c),
          act: () => tester.tap(find.byKey(const ValueKey('coding-tool-bash'))),
        );
      });
    });

    group('providers ($tone)', () {
      Widget providers(Library3Controller c) =>
          IntegrationsScreen(controller: c, mode: IntegrationsMode.providers);

      testWidgets('manage accounts', (tester) async {
        final c = await library3Server();
        addTearDown(c.dispose);
        await _shot(
          tester,
          'library_credential_management_sheet',
          light: light,
          home: providers(c),
          act: () async {
            await tester.tap(find.byKey(const ValueKey('provider-anthropic')));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Manage Anthropic accounts'));
          },
        );
      });

      testWidgets('remove account question', (tester) async {
        final c = await library3Server();
        addTearDown(c.dispose);
        await _shot(
          tester,
          'library_credential_management_remove_sheet',
          light: light,
          home: providers(c),
          act: () async {
            await tester.tap(find.byKey(const ValueKey('provider-anthropic')));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Manage Anthropic accounts'));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('credential-cred-1')));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Remove Work').last);
          },
        );
      });

      testWidgets('server sign-in', (tester) async {
        final c = await library3Server();
        addTearDown(c.dispose);
        await _shot(
          tester,
          'library_command_auth_sheet',
          light: light,
          home: providers(c),
          act: () =>
              tester.tap(find.byKey(const ValueKey('connect-provider-cloud'))),
        );
      });

      testWidgets('unfinished sign-ins', (tester) async {
        final c = await library3Server()
          ..pending = [library3Pending()]
          ..uncertain = const [
            (integrationID: 'openai', kind: PendingAuthKind.command),
          ];
        addTearDown(c.dispose);
        await _shot(
          tester,
          'library_integrations_pending_auth',
          light: light,
          home: providers(c),
        );
      });
    });

    group('plugins ($tone)', () {
      for (final size in [_phone, _wide]) {
        testWidgets('loaded ${size.width.toInt()}', (tester) async {
          final c = await library3Server();
          addTearDown(c.dispose);
          await _shot(
            tester,
            'settings_plugins_loaded',
            light: light,
            size: size,
            home: library3Plugins(c),
          );
        });
      }

      testWidgets('AI Team sheet, off', (tester) async {
        final c = await library3Server();
        addTearDown(c.dispose);
        await _shot(
          tester,
          'settings_team_plugin_sheet_off',
          light: light,
          home: library3Plugins(c),
          act: () =>
              tester.tap(find.byKey(const ValueKey('plugins-ai-team-row'))),
        );
      });
    });
  }
}
