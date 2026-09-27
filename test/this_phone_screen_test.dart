// This phone (programme P1.5): one host-neutral page for OpenCode inside the
// app and OpenCode in Termux. The same page opens for both, with the same
// status row, the same one act it needs now, and the same list; each host
// adds only what it alone has (the in-app terminal and Remove, Termux's
// Running now). Add tools opens phone setup's Customize sheet in add mode,
// priced with the kit's cost line, and installs only the new tools.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/setup/setup_contract.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/phone_host.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:opencode_mobile/termux/processes.dart';
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_termux_screen.dart';
import 'package:opencode_mobile/ui/screens/this_phone_screen.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/widgets/phone_server_card.dart';

import 'revamp/screen_phone_1_fixtures.dart';
import 'support/termux_channel_fixture.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

/// The parts both hosts show, by key.
const _shared = [
  'this-phone-title',
  'this-phone-state',
  'this-phone-detail',
  'this-phone-connect',
  'this-phone-stop',
  'this-phone-switch',
  'this-phone-add-tools',
  'this-phone-installed',
  'this-phone-keep-running',
];

final _termuxProfile = ServerProfile(
  id: 'termux',
  name: 'This phone',
  baseUrl: TermuxBridge.managedServerUrl,
  password: 'synthetic-test-secret',
  serverVersion: '1.18.29',
);

Future<void> _settle(WidgetTester tester, {int frames = 10}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Set<String> _present(WidgetTester tester) => {
  for (final key in _shared)
    if (find.byKey(ValueKey(key)).evaluate().isNotEmpty) key,
};

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  Future<void> inApp(WidgetTester tester, {PhoneLinux? linux}) async {
    await pumpPhone(
      tester,
      home: const ThisPhoneScreen(kind: PhoneHostKind.inApp),
      linux: linux ?? PhoneLinux(running: true),
      profiles: [inAppProfile],
    );
    await _settle(tester);
  }

  Future<TermuxChannelFixture> termux(
    WidgetTester tester, {
    String version = '1.18.29',
    Future<TermuxProcessReport> Function()? scan,
  }) async {
    final channel = TermuxChannelFixture()
      ..inventoryOutput =
          'ubuntu=installed\nversion=$version\nruntime=opencode1\n'
      ..statusOutput = termuxSnapshot(phase: 'ready', version: version);
    channel.install();
    await pumpPhone(
      tester,
      home: ThisPhoneScreen(kind: PhoneHostKind.termux, scanProcesses: scan),
      profiles: [_termuxProfile],
    );
    await _settle(tester);
    return channel;
  }

  String text(WidgetTester tester, String key) => tester
      .widget<RichText>(
        find
            .descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(RichText),
              matchRoot: true,
            )
            .first,
      )
      .text
      .toPlainText();

  testWidgets('in the app: the status, the one act it needs, then one list', (
    tester,
  ) async {
    await inApp(tester);
    expect(find.text(_l10n.phoneServerCardTitle), findsOneWidget);
    expect(text(tester, 'this-phone-state'), _l10n.phoneServerCardRunning);
    expect(
      text(tester, 'this-phone-detail'),
      contains(_l10n.thisPhoneHostInApp),
    );
    expect(_present(tester), _shared.toSet());
    // Every act names what it acts on.
    expect(find.text(_l10n.thisPhoneStop), findsOneWidget);
    expect(find.text(_l10n.thisPhoneConnect), findsOneWidget);
    // Only the in-app Linux has a terminal and Remove.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('this-phone-remove')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('this-phone-terminal')), findsOneWidget);
    expect(find.text(_l10n.thisPhoneRemove), findsOneWidget);
    // The technical fold is last, after Remove.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('this-phone-details')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('termux-procs-row')), findsNothing);
    await unmountPhone(tester);
  });

  testWidgets('in Termux: the same page, with Termux\'s own rows', (
    tester,
  ) async {
    await termux(tester, scan: () async => const TermuxProcessReport([]));
    expect(find.text(_l10n.phoneServerCardTitle), findsOneWidget);
    expect(text(tester, 'this-phone-state'), _l10n.phoneServerCardRunning);
    expect(
      text(tester, 'this-phone-detail'),
      contains(_l10n.thisPhoneHostTermux),
    );
    expect(_present(tester), _shared.toSet());
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('termux-procs-row')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('termux-storage-row')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('this-phone-details')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('this-phone-terminal')), findsNothing);
    expect(find.byKey(const ValueKey('this-phone-remove')), findsNothing);
    await unmountPhone(tester);
  });

  testWidgets('Running on this phone: its line is the budget; a list that '
      'cannot be read leaves no dead row and no stray line', (tester) async {
    final listing = TermuxProcessReport([
      for (var pid = 100; pid < 118; pid++)
        TermuxProcess.fromJson({'pid': pid, 'name': 'p$pid', 'rss_kb': 1024})!,
    ]);
    await termux(tester, scan: () async => listing);
    final row = find.byKey(const ValueKey('termux-procs-row'));
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Running on this phone'), findsOneWidget);
    expect(find.text('18 of 32 background processes'), findsOneWidget);
    expect(find.text('Not available right now'), findsNothing);
    await unmountPhone(tester);

    await termux(
      tester,
      scan: () async =>
          throw const TermuxBridgeException('no tools', code: 'tools_missing'),
    );
    final list = find.byKey(const ValueKey('this-phone-list'));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('termux-storage-row')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('termux-procs-row')), findsNothing);
    expect(find.text('Not available right now'), findsNothing);
    // One hairline between each pair of rows, none for the missing one.
    final group = tester.widget<KitRowGroup>(list);
    expect(
      find.descendant(of: list, matching: find.byType(KitDivider)),
      findsNWidgets(group.children.length - 1),
    );
    await unmountPhone(tester);
  });

  testWidgets('the server log waits folded under Details, last', (
    tester,
  ) async {
    await pumpPhone(
      tester,
      home: const ThisPhoneScreen(kind: PhoneHostKind.inApp),
      linux: PhoneLinux(running: true, log: 'INFO  session created\n'),
      profiles: [inAppProfile],
    );
    await _settle(tester);
    expect(find.byKey(const ValueKey('this-phone-log')), findsNothing);
    final details = find.byKey(const ValueKey('this-phone-details'));
    await tester.scrollUntilVisible(
      details,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(details);
    await _settle(tester);
    expect(find.byKey(const ValueKey('this-phone-log')), findsOneWidget);
    expect(find.textContaining('session created'), findsOneWidget);
    // The panel names the server; "Server log" is not said a second time.
    expect(find.text(_l10n.phoneServerCardVersion('1.18.29')), findsOneWidget);
    expect(find.text(_l10n.builtinServerLogTitle), findsNothing);
    await unmountPhone(tester);
  });

  testWidgets('stopping asks first, then the page offers Start', (
    tester,
  ) async {
    final linux = PhoneLinux(running: true);
    await inApp(tester, linux: linux);
    await tester.tap(find.byKey(const ValueKey('this-phone-stop')));
    await _settle(tester);
    expect(linux.running, isTrue, reason: 'the question changes nothing');
    await tester.tap(find.byKey(const ValueKey('confirm-stop-local-server')));
    await _settle(tester);
    expect(linux.running, isFalse);
    expect(text(tester, 'this-phone-state'), _l10n.phoneServerCardStopped);
    expect(find.text(_l10n.thisPhoneStart), findsOneWidget);
    await unmountPhone(tester);
  });

  testWidgets('Add tools opens Customize in add mode, priced before it '
      'installs, and installs only the new tools', (tester) async {
    var progressOpened = 0;
    PhoneServerCardRoutes.openProgressOverride = (_) async => progressOpened++;
    addTearDown(() => PhoneServerCardRoutes.openProgressOverride = null);
    final engine = await pumpPhone(
      tester,
      home: const ThisPhoneScreen(kind: PhoneHostKind.inApp),
      linux: PhoneLinux(running: true),
      profiles: [inAppProfile],
    );
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('this-phone-add-tools')));
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('phone-setup-customize-sheet')),
      findsOneWidget,
    );
    expect(find.text(_l10n.phoneSetupStartAddTitle), findsWidgets);
    await tester.tap(
      find.byKey(const ValueKey('phone-setup-customize-python')),
    );
    await _settle(tester);
    // The kit's cost line, before the button that installs.
    expect(
      find.byKey(const ValueKey('phone-setup-customize-cost')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('phone-setup-customize-done')));
    await _settle(tester);
    expect(engine.runs, [
      {'python'},
    ]);
    expect(engine.runParams.single, SetupJobParams.adding({'python'}));
    expect(progressOpened, 1);
    // The sheet's device look gives up after 5 s off a phone.
    await tester.pump(const Duration(seconds: 6));
    await unmountPhone(tester);
  });

  testWidgets('Termux: Update asks, then runs in phone setup\'s progress', (
    tester,
  ) async {
    final channel = await termux(tester, version: '1.18.20');
    // From here the manager reports the update running.
    channel.statusOutput = null;
    await tester.tap(find.byKey(const ValueKey('this-phone-update')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('this-phone-update-confirm')));
    await _settle(tester, frames: 4);
    expect(find.byType(PhoneSetupTermuxScreen), findsOneWidget);
    expect(find.text(_l10n.phoneSetupTermuxUpdatingTitle), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    await unmountPhone(tester);
  });

  testWidgets('Update is not offered when the pinned version is installed', (
    tester,
  ) async {
    await termux(tester, version: TermuxRuntime.openCode1.pinnedVersion);
    expect(find.byKey(const ValueKey('this-phone-update')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    await unmountPhone(tester);
  });

  test('no screen pushes the retired Termux wizard route (P1.3)', () {
    final pushes = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains("'/termux-setup'")) pushes.add(entity.path);
    }
    expect(pushes, isEmpty);
    expect(
      File('lib/ui/screens/termux_setup_screen.dart').existsSync(),
      isFalse,
    );
    expect(
      File('lib/ui/screens/builtin_server_screen.dart').existsSync(),
      isFalse,
    );
  });

  testWidgets('nothing set up: one act, set it up', (tester) async {
    await pumpPhone(
      tester,
      home: const ThisPhoneScreen(kind: PhoneHostKind.inApp),
      linux: PhoneLinux(installed: false, openCode: false),
    );
    await _settle(tester);
    expect(text(tester, 'this-phone-state'), _l10n.phoneServerCardNotSetUp);
    expect(find.text(_l10n.thisPhoneSetUp), findsOneWidget);
    expect(find.byKey(const ValueKey('this-phone-list')), findsNothing);
    await unmountPhone(tester);
  });
}
