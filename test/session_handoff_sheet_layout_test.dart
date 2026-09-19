import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/session_handoff.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/widgets/session_handoff_sheets.dart';

/// The two handoff sheets (F4-S1 command, F4-S2 QR) at 320 dp, in both
/// directions and at 2.5x text: everything stays inside the viewport, the
/// copy buttons keep their 48 dp target, copying writes exactly the command
/// or link and nothing else happens.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final clipboard = <String>[];
  setUp(() {
    clipboard.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  final command = SessionResumeCommand.build(
    cli: SessionResumeCli.openCode2,
    sessionID: 'ses_0123456789abcdef',
    directory: '/home/dev/My Projects/acme',
  );
  final link = SessionLink.tryCreate(
    profileID: '1757500000000000',
    sessionID: 'ses_0123456789abcdef',
  )!;

  Future<void> pumpSheet(
    WidgetTester tester,
    Widget sheet, {
    required bool rtl,
    required bool large,
    void Function(String?)? onPopped,
  }) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: rtl ? const Locale('ar') : const Locale('en'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(large ? 2.5 : 1)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('open'),
                onPressed: () async {
                  final popped = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => LayoutBuilder(
                      builder: (context, constraints) => ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * .85,
                        ),
                        child: sheet,
                      ),
                    ),
                  );
                  onPopped?.call(popped);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  void expectInside(WidgetTester tester, Finder finder) {
    final rect = tester.getRect(finder);
    expect(rect.left, greaterThanOrEqualTo(0), reason: '$finder');
    expect(rect.right, lessThanOrEqualTo(320), reason: '$finder');
  }

  for (final variant in [
    (name: 'ltr', rtl: false, large: false),
    (name: 'rtl', rtl: true, large: false),
    (name: 'ltr-2.5x', rtl: false, large: true),
    (name: 'rtl-2.5x', rtl: true, large: true),
  ]) {
    testWidgets('continue on computer stays reachable ${variant.name}', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        ContinueOnComputerSheet(command: command, exportAvailable: true),
        rtl: variant.rtl,
        large: variant.large,
      );
      expect(
        find.byKey(const Key('continue-on-computer-sheet')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('agent-command-block')), findsOneWidget);
      expect(
        find.text(
          "cd '/home/dev/My Projects/acme' && opencode2 --session 'ses_0123456789abcdef'",
        ),
        findsOneWidget,
      );
      final copy = find.byKey(const Key('agent-command-copy-0'));
      await tester.ensureVisible(copy);
      await tester.pumpAndSettle();
      expectInside(tester, copy);
      expect(tester.getSize(copy).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(copy).height, greaterThanOrEqualTo(48));
      expectInside(tester, find.byKey(const Key('agent-command-block')));

      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(clipboard, [
        "cd '/home/dev/My Projects/acme' && opencode2 --session 'ses_0123456789abcdef'",
      ]);
      // The sheet stays open after a copy; nothing navigates or sends.
      expect(
        find.byKey(const Key('continue-on-computer-sheet')),
        findsOneWidget,
      );

      // The export route is reachable by scrolling and pops its value.
      final export = find.byKey(const Key('continue-on-computer-export'));
      await tester.ensureVisible(export);
      await tester.pumpAndSettle();
      expectInside(tester, export);
    });

    testWidgets('continue on phone stays reachable ${variant.name}', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        ContinueOnPhoneSheet(link: link),
        rtl: variant.rtl,
        large: variant.large,
      );
      expect(find.byKey(const Key('continue-on-phone-sheet')), findsOneWidget);
      final qr = find.byKey(const Key('session-link-qr'));
      // The QR may sit below the fold at 2.5x; it must still lay out inside
      // the width and be reachable.
      await tester.ensureVisible(qr);
      await tester.pumpAndSettle();
      expectInside(tester, qr);
      expect(tester.getSize(qr).width, lessThanOrEqualTo(240));
      expect(tester.getSize(qr).width, greaterThan(100));

      final copy = find.byKey(const Key('continue-on-phone-copy'));
      await tester.ensureVisible(copy);
      await tester.pumpAndSettle();
      expectInside(tester, copy);
      expect(tester.getSize(copy).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(copy).height, greaterThanOrEqualTo(48));
      expect(
        find.text(
          'opencode-mobile://session?profile=1757500000000000&session=ses_0123456789abcdef',
        ),
        findsOneWidget,
      );
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(clipboard, [
        'opencode-mobile://session?profile=1757500000000000&session=ses_0123456789abcdef',
      ]);
      expect(find.byKey(const Key('continue-on-phone-sheet')), findsOneWidget);
    });
  }

  testWidgets('export pops the sheet with its action', (tester) async {
    final popped = <String?>[];
    await pumpSheet(
      tester,
      ContinueOnComputerSheet(command: command, exportAvailable: true),
      rtl: false,
      large: false,
      onPopped: popped.add,
    );
    final export = find.byKey(const Key('continue-on-computer-export'));
    await tester.ensureVisible(export);
    await tester.pumpAndSettle();
    await tester.tap(export);
    await tester.pumpAndSettle();
    expect(popped, ['export']);
    expect(find.byKey(const Key('continue-on-computer-sheet')), findsNothing);
    expect(clipboard, isEmpty);
  });

  testWidgets('without export support the hint stays but the button goes', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      ContinueOnComputerSheet(command: command, exportAvailable: false),
      rtl: false,
      large: false,
    );
    expect(find.byKey(const Key('continue-on-computer-export')), findsNothing);
    expect(
      find.textContaining('Export this conversation as a file'),
      findsOneWidget,
    );
  });

  testWidgets('a managed-workspace session shows the honest state', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      ContinueOnComputerSheet(
        command: SessionResumeCommand.build(
          cli: SessionResumeCli.openCode2,
          sessionID: 'ses_ws',
          directory: '/workspace/acme',
          workspaceID: 'wrk_1',
        ),
        exportAvailable: true,
      ),
      rtl: false,
      large: false,
    );
    expect(find.byKey(const Key('agent-command-block')), findsNothing);
    expect(
      find.byKey(const Key('continue-on-computer-unavailable')),
      findsOneWidget,
    );
    expect(find.textContaining('cloud environment'), findsOneWidget);
    // The command name still names the right product in the intro.
    expect(find.textContaining('opencode2 interface'), findsOneWidget);
  });

  testWidgets('a missing directory shows the honest state, v1 naming', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      ContinueOnComputerSheet(
        command: SessionResumeCommand.build(
          cli: SessionResumeCli.openCode1,
          sessionID: 'ses_1',
          directory: null,
        ),
        exportAvailable: true,
      ),
      rtl: false,
      large: false,
    );
    expect(find.byKey(const Key('agent-command-block')), findsNothing);
    expect(
      find.textContaining('did not report a project folder'),
      findsOneWidget,
    );
    expect(find.textContaining('the opencode interface'), findsOneWidget);
  });

  testWidgets('an unbuildable link shows the honest state and no QR', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      const ContinueOnPhoneSheet(link: null),
      rtl: false,
      large: false,
    );
    expect(find.byKey(const Key('session-link-qr')), findsNothing);
    expect(find.byKey(const Key('continue-on-phone-copy')), findsNothing);
    expect(
      find.byKey(const Key('continue-on-phone-unavailable')),
      findsOneWidget,
    );
  });
}
