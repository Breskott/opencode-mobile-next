// Usage › Add a subscription: pick where it should be signed in, skip the
// pick when there is only one place, and send each choice to that
// connection's own sign-in.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/usage_signin_destination.dart';
import 'package:opencode_mobile/ui/screens/usage/usage_actions.dart';
import 'package:opencode_mobile/ui/screens/usage_hub_screen.dart';

import 'support/usage_ui_harness.dart';

final _en = lookupAppLocalizations(const Locale('en'));

/// A page with one button that starts the add flow for [provider].
Widget _starter(UsageHarness h, String provider) => Builder(
  builder: (context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () => startUsageAdd(
          context,
          controller: h.connection,
          usage: h.usage,
          launcher: h.launcher,
          providerId: provider,
        ),
        child: const Text('Start'),
      ),
    ),
  ),
);

Future<void> _start(
  WidgetTester tester,
  UsageHarness h,
  String provider,
) async {
  usagePhoneView(tester);
  await h.usage.refresh();
  await tester.pumpWidget(usageApp(_starter(h, provider)));
  await tester.tap(find.text('Start'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  usageTestWidgets('one connection: the choice is skipped and sign-in opens '
      'straight away', (tester) async {
    final h = await usageHarness(connections: const [usageInApp]);
    await _start(tester, h, 'codex');
    expect(usageKey('usage-add'), findsNothing);
    final (destination, profile) = h.launcher.opened.single;
    expect(destination.kind, UsageSignInKind.openCodeProvider);
    expect(destination.providerId, 'openai');
    expect(profile, 'inapp');
  });

  usageTestWidgets('GLM goes to the Providers page for its own id', (
    tester,
  ) async {
    final h = await usageHarness(connections: const [usageInApp]);
    await _start(tester, h, 'glm');
    expect(h.launcher.opened.single.$1.providerId, 'zai-coding-plan');
  });

  usageTestWidgets('several places: In-app Ubuntu is marked Best and each '
      'choice opens that connection\'s sign-in', (tester) async {
    final h = await usageHarness(
      connections: const [usagePc, usageInApp, usagePhone],
    );
    await _start(tester, h, 'codex');
    expect(find.text(_en.usageAddTitle('Codex')), findsOneWidget);
    expect(find.text(_en.usageAddWhere('Codex')), findsOneWidget);
    expect(h.launcher.opened, isEmpty);
    expect(find.text(_en.usageBest), findsOneWidget);
    // Best first, then the saved servers, then this phone.
    final inApp = tester.getTopLeft(usageKey('usage-add-choice-inapp')).dy;
    final pc = tester.getTopLeft(usageKey('usage-add-choice-pc')).dy;
    final phone = tester.getTopLeft(usageKey('usage-add-choice-phone')).dy;
    expect(inApp, lessThan(pc));
    expect(pc, lessThan(phone));

    await tester.tap(usageKey('usage-add-choice-pc'));
    await tester.pumpAndSettle();
    expect(h.launcher.opened.last.$1.kind, UsageSignInKind.openCodeProvider);
    expect(h.launcher.opened.last.$2, 'pc');

    await tester.tap(usageKey('usage-add-choice-phone'));
    await tester.pumpAndSettle();
    expect(h.launcher.opened.last.$1.kind, UsageSignInKind.agentSignIn);
    expect(h.launcher.opened.last.$1.agentId, 'codex');
  });

  usageTestWidgets('a sign-in that cannot open says so in words', (
    tester,
  ) async {
    final h = await usageHarness(connections: const [usagePc, usageInApp]);
    h.launcher.outcome = UsageSignInOutcome.connectFailed;
    await _start(tester, h, 'codex');
    await tester.tap(usageKey('usage-add-choice-pc'));
    await tester.pumpAndSettle();
    expect(usageKey('usage-add-notice'), findsOneWidget);
    expect(find.text(_en.launchUiUsageSignInConnectionFailed), findsOneWidget);
  });

  usageTestWidgets('nowhere to sign in to says why, not a blank page', (
    tester,
  ) async {
    // Claude cannot be signed in through OpenCode.
    final h = await usageHarness(connections: const [usageInApp, usagePc]);
    await _start(tester, h, 'claude');
    expect(usageKey('usage-add-none'), findsOneWidget);
    expect(find.text(_en.usageAddNoneTitle('Claude')), findsOneWidget);
  });

  usageTestWidgets('from the Plans list, one connection goes straight to '
      'sign-in', (tester) async {
    final h = await usageHarness(connections: const [usageInApp]);
    usagePhoneView(tester);
    await tester.pumpWidget(
      usageApp(
        UsageHubScreen(
          controller: h.connection,
          usage: h.usage,
          launcher: h.launcher,
          clock: () => usageNow,
          prepare: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(usageKey('usage-add-row'));
    await tester.pumpAndSettle();
    await tester.tap(usageKey('usage-add-minimax'));
    await tester.pumpAndSettle();
    expect(usageKey('usage-add'), findsNothing);
    expect(h.launcher.opened.single.$1.providerId, 'minimax-coding-plan');
  });
}
