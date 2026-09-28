// screen-phone-1 (wave 2b): the phone pages rebuilt from kit parts, and the
// map items they now handle. Each test asserts what the person sees or what
// the screen sends.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/setup/phone_setup.dart';
import 'package:opencode_mobile/state/termux_running_server.dart';
import 'package:opencode_mobile/termux/bridge.dart' show TermuxRuntime;
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_field.dart';
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_customize_sheet.dart';
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_ready_screen.dart';
import 'package:opencode_mobile/ui/screens/termux_storage_screen.dart';

import 'screen_phone_1_fixtures.dart';

Future<void> _openOtherWays(WidgetTester tester) async {
  final toggle = find.byKey(const ValueKey('phone-setup-start-other-ways'));
  await tester.ensureVisible(toggle);
  await tester.pumpAndSettle();
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

/// Opens the customize sheet the way the phone's card does ("Add tools").
Widget _customizeHost({required bool addMode}) => Scaffold(
  body: Builder(
    builder: (context) => Center(
      child: KitButton.primary(
        label: 'open',
        onPressed: () => showSetupCustomizeSheet(
          context,
          engine: PhoneSetup.engine,
          addMode: addMode,
        ),
      ),
    ),
  ),
);

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('oc/voice'), (
          call,
        ) async {
          if (call.method == 'getDeviceInfo') return <String, Object?>{};
          return null;
        });
    useNoTermuxJob();
  });

  group('phone-setup-start', () {
    testWidgets('Termux there but not allowed says so under Use Termux', (
      tester,
    ) async {
      await pumpPhone(
        tester,
        home: startScreen(termux: const TermuxRunningServer.denied()),
      );
      await tester.pumpAndSettle();
      await _openOtherWays(tester);
      expect(find.text('Use Termux instead'), findsOneWidget);
      expect(
        find.text(
          "Termux is installed but hasn't let this app in yet. Finish its "
          'setup.',
        ),
        findsOneWidget,
      );
      await unmountPhone(tester);
    });

    testWidgets('in-app and Termux both there: the Termux one is a row', (
      tester,
    ) async {
      await pumpPhone(
        tester,
        home: startScreen(
          inApp: true,
          termux: TermuxRunningServer.running(
            runtime: TermuxRuntime.openCode1,
            version: '1.18.29',
            observedAt: DateTime(2026, 9, 24),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('OpenCode is ready on this phone'), findsOneWidget);
      await _openOtherWays(tester);
      expect(
        find.byKey(const ValueKey('phone-setup-start-connect-termux')),
        findsOneWidget,
      );
      expect(find.text('Use the one in Termux'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('phone-setup-start-use-termux')),
        findsNothing,
      );
      await unmountPhone(tester);
    });

    testWidgets('a fresh phone keeps one primary and folds the other ways', (
      tester,
    ) async {
      await pumpPhone(tester, home: startScreen());
      await tester.pumpAndSettle();
      expect(find.text('Run a coding agent right here'), findsOneWidget);
      expect(find.text('Use Termux instead'), findsNothing);
      await _openOtherWays(tester);
      expect(find.text('Use Termux instead'), findsOneWidget);
      // What Termux costs is said before anything installs (P1.5).
      expect(
        find.text("About 10–15 minutes the first time, in Termux's storage"),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await unmountPhone(tester);
    });
  });

  group('phone-setup-customize-sheet', () {
    testWidgets('required tools are locked on with a word, not a dead switch', (
      tester,
    ) async {
      await pumpPhone(tester, home: _customizeHost(addMode: false));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Choose what to install'), findsOneWidget);
      // linux, essentials, node, opencode are required in the fake registry.
      expect(find.text('Required'), findsNWidgets(4));
      expect(find.text('About 4 minutes · ~165 MB'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('phone-setup-customize-python')),
      );
      await tester.pumpAndSettle();
      expect(find.text('About 3 minutes · ~135 MB'), findsOneWidget);
      await unmountPhone(tester);
    });

    testWidgets('every optional tool installed: nothing to add, and why', (
      tester,
    ) async {
      await pumpPhone(
        tester,
        home: _customizeHost(addMode: true),
        optionalInstalled: {'python'},
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Add tools'), findsOneWidget);
      expect(find.text('Installed'), findsOneWidget);
      // The reason is the line right above the disabled Add (STATE-8),
      // said once.
      expect(
        find.text('Every optional tool is already on this phone.'),
        findsOneWidget,
      );
      final add = tester.widget<KitButton>(
        find.byKey(const ValueKey('phone-setup-customize-done')),
      );
      expect(add.onPressed, isNull);
      await unmountPhone(tester);
    });
  });

  group('phone-setup-ready', () {
    testWidgets('the name is a labelled kit field that says what is wrong', (
      tester,
    ) async {
      await pumpPhone(
        tester,
        home: PhoneSetupReadyScreen(linux: PhoneLinux(running: true)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(KitField), findsOneWidget);
      expect(find.text('Project name'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('phone-setup-ready-name')),
        'a/b',
      );
      await tester.tap(find.byKey(const ValueKey('phone-setup-ready-create')));
      await tester.pumpAndSettle();
      expect(find.text('Use one name, without slashes.'), findsOneWidget);
      await unmountPhone(tester);
    });

    testWidgets('Close leaves for the app root', (tester) async {
      await pumpPhone(
        tester,
        home: const Scaffold(body: Text('root')),
        routes: {'/ready': (_) => PhoneSetupReadyScreen(linux: PhoneLinux())},
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/ready');
      await tester.pumpAndSettle();
      expect(find.text('OpenCode is ready'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('phone-setup-ready-close')));
      await tester.pumpAndSettle();
      expect(find.text('root'), findsOneWidget);
      expect(find.text('OpenCode is ready'), findsNothing);
      await unmountPhone(tester);
    });
  });

  group('termux-storage', () {
    testWidgets('a failed scan says so, and Scan starts it again', (
      tester,
    ) async {
      final channel = StorageChannel(state: 'failed')..install();
      await pumpPhone(
        tester,
        home: TermuxStorageScreen(
          now: () => DateTime.fromMillisecondsSinceEpoch(1788800120000),
          pollInterval: const Duration(milliseconds: 50),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('The scan did not finish. Try again.'), findsOneWidget);
      // Nothing was measured yet, so the intro's Scan is the one way on.
      expect(find.text('Scan again'), findsNothing);
      await tester.tap(find.byKey(const Key('termux-storage-scan')));
      await tester.pump();
      expect(channel.scanStarts, 1);
      channel.state = 'running';
      channel.log = '[oc] Build caches';
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byKey(const Key('termux-storage-scanning')), findsOneWidget);
      channel.state = 'done';
      channel.report = storageReport();
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byKey(const Key('termux-storage-total')), findsOneWidget);
      await unmountPhone(tester);
    });

    testWidgets('the clean question lists the exact paths under Details', (
      tester,
    ) async {
      StorageChannel(state: 'done', report: storageReport()).install();
      await pumpPhone(
        tester,
        home: TermuxStorageScreen(
          now: () => DateTime.fromMillisecondsSinceEpoch(1788800120000),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('termux-storage-cat-build_caches')),
      );
      await tester.pumpAndSettle();
      final clean = find.byKey(const Key('termux-storage-clean-build_caches'));
      await tester.ensureVisible(clean);
      await tester.pumpAndSettle();
      await tester.tap(clean);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('termux-storage-confirm')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('kit-details-toggle')).last);
      await tester.pumpAndSettle();
      expect(find.text('ubuntu:/root/.gradle/caches'), findsWidgets);
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      await unmountPhone(tester);
    });
  });
}
