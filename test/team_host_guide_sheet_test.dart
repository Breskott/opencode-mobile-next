// team-host-guide-sheet (slice-close-security, slice-team-g17): each step is
// a sentence and a copyable command in the kit code block; the front is
// downloaded from the pinned commit and checked before it runs; the published
// guide opens through openExternalLink, never by naming a repo file; and the
// sheet's primary is its next step, "Enter the address", where the host
// offers the address form. The form's hint names the port the guide starts
// the front on.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/kit/kit_code_block.dart';
import 'package:opencode_mobile/ui/setup_commands.dart';
import 'package:opencode_mobile/ui/widgets/team_host_form.dart';

Future<void> _open(
  WidgetTester tester, {
  Future<void> Function()? enterAddress,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => unawaited(
              showTeamHostGuideSheet(context, enterAddress: enterAddress),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every step carries its command in a kit code block', (
    tester,
  ) async {
    await _open(tester);
    final blocks = tester
        .widgetList<KitCodeBlock>(find.byType(KitCodeBlock))
        .map((b) => b.text)
        .toList();
    expect(blocks, [
      HostScripts.teamCheckTools,
      HostScripts.teamCreateCity,
      HostScripts.teamStart,
      HostScripts.teamFront,
    ]);
    // No repository file to go and find, no piped download.
    expect(find.textContaining('docs/ai-team-host.md'), findsNothing);
    expect(find.textContaining('python3 tool/'), findsNothing);
    expect(find.textContaining(RegExp(r'\|\s*(ba)?sh\b')), findsNothing);
  });

  testWidgets('copy puts the checked front command on the clipboard', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
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
    await _open(tester);
    final copy = find.byKey(const ValueKey('team-host-guide-copy-4'));
    await tester.ensureVisible(copy);
    await tester.pumpAndSettle();
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(copied, HostScripts.teamFront);
    expect(
      copied,
      contains(
        '${HostScripts.front.sha256}  opencode-mobile-front.py.part'
        "' | sha256sum -c - &&",
      ),
    );
  });

  testWidgets('the full guide opens through the external link gate', (
    tester,
  ) async {
    await _open(tester);
    final open = find.byKey(const ValueKey('team-host-guide-open'));
    await tester.ensureVisible(open);
    await tester.pumpAndSettle();
    expect(find.text('Open the full guide'), findsOneWidget);
    await tester.tap(open);
    await tester.pumpAndSettle();
    // openExternalLink asks first and names the destination host.
    expect(find.byKey(const ValueKey('external-link-confirm')), findsOneWidget);
    expect(find.textContaining('github.com'), findsWidgets);
  });

  testWidgets('Enter the address closes the guide, then runs the next step', (
    tester,
  ) async {
    var entered = 0;
    await _open(tester, enterAddress: () async => entered++);
    final next = find.byKey(const ValueKey('team-host-guide-enter-address'));
    expect(
      find.descendant(of: next, matching: find.text('Enter the address')),
      findsOneWidget,
    );
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('team-host-guide')), findsNothing);
    expect(entered, 1);
  });

  testWidgets('where the team is already added the guide has no primary', (
    tester,
  ) async {
    await _open(tester);
    expect(
      find.byKey(const ValueKey('team-host-guide-enter-address')),
      findsNothing,
    );
    // Dismissing it runs nothing and leaves the page as it was.
    await tester.tapAt(const Offset(200, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('team-host-guide')), findsNothing);
  });

  test('the address hint names the port the guide starts the front on', () {
    final front = File('tool/host/cp_front/front.py').readAsStringSync();
    final port = RegExp(
      r'^DEFAULT_PORT = (\d+)$',
      multiLine: true,
    ).firstMatch(front)!.group(1);
    expect(port, '$teamHostFrontPort');
    expect(HostScripts.teamFront, contains('--port $teamHostFrontPort'));
    final hint = lookupAppLocalizations(
      const Locale('en'),
    ).teamUiAddAddressHint;
    expect(hint, endsWith(':$teamHostFrontPort'));
  });
}
