// A provider the server holds a sign-in for but has not loaded must not read
// "Connected" (P1-4, journeys 2064): it says so, offers the working fix (an
// API key), and shows no model count. Manage accounts is enabled or absent.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/screens/library_screen.dart';
import 'package:opencode_mobile/ui/widgets/provider_logo.dart';

import 'screen_library_3_fixtures.dart';

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: home,
);

Future<void> _open(WidgetTester tester, Library3Controller c) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _app(IntegrationsScreen(controller: c, mode: IntegrationsMode.providers)),
  );
  await tester.pumpAndSettle();
}

void main() {
  mockLibrary3SecureStorage();
  setUpAll(() => ProviderLogo.imageProviderOverride = (_) => null);
  tearDownAll(() => ProviderLogo.imageProviderOverride = null);

  testWidgets('a loaded provider reads Connected', (tester) async {
    final c = await library3Server();
    addTearDown(c.dispose);
    await _open(tester, c);
    expect(find.textContaining('Connected'), findsWidgets);
    expect(find.textContaining("can't use it"), findsNothing);
  });

  testWidgets('a signed-in provider the server did not load is not Connected '
      'and offers an API key', (tester) async {
    final c = await library3Server();
    addTearDown(c.dispose);
    c.unloadedProviderIDs = {'anthropic'};
    c.unloadedProvidersUnusable = true;
    await _open(tester, c);
    final row = find.byKey(const ValueKey('provider-anthropic'));
    expect(
      find.descendant(
        of: row,
        matching: find.textContaining(
          "Signed in, but this server can't use it",
        ),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.textContaining('Connected')),
      findsNothing,
    );
    expect(
      find.descendant(of: row, matching: find.textContaining('models')),
      findsNothing,
    );
    await tester.tap(row);
    await tester.pumpAndSettle();
    // The row's tap opens the key dialog: the working fix, not a dead end.
    expect(find.textContaining('API key'), findsWidgets);
  });

  testWidgets('never a disabled Manage accounts entry', (tester) async {
    final c = await library3Server();
    addTearDown(c.dispose);
    await _open(tester, c);
    expect(
      find.text("This server can't list saved accounts from the app."),
      findsNothing,
    );
  });
}
