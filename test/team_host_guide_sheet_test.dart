// team-host-guide-sheet (slice-close-security): each step is a sentence and
// a copyable command in the kit code block; the front is downloaded from the
// pinned commit and checked before it runs; the sheet ends by opening the
// published guide through openExternalLink, never by naming a repo file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_code_block.dart';
import 'package:opencode_mobile/ui/setup_commands.dart';
import 'package:opencode_mobile/ui/widgets/team_host_form.dart';

Future<void> _open(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(420, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => unawaited(showTeamHostGuideSheet(context)),
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
}
