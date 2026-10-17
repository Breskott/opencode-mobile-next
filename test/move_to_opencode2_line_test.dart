// Retirement phase 3: a phone server the app manages that still runs the
// older OpenCode shows ONE quiet "Move to OpenCode 2" line on This phone,
// with "Not now" that sticks per server. A tap runs the existing switch flow.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/builtin/setup/setup_contract.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/domain/opencode_history_copy.dart';
import 'package:opencode_mobile/state/move_to_opencode2.dart';
import 'package:opencode_mobile/state/phone_host.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:opencode_mobile/ui/screens/this_phone_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'revamp/screen_phone_1_fixtures.dart';
import 'support/termux_channel_fixture.dart';

class _HistoryLinux extends PhoneLinux {
  _HistoryLinux({this.check, this.throwCheck = false}) : super(running: true);
  BuiltinLinuxRunResult? check;
  bool throwCheck;
  Completer<BuiltinLinuxRunResult>? pending;
  final pendingChecks = <Completer<BuiltinLinuxRunResult>>[];

  @override
  Future<BuiltinLinuxRunResult> run(
    String script, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (script.contains(openCode1HistorySwitchCheckScript)) {
      if (throwCheck) throw StateError('check unavailable');
      if (pendingChecks.isNotEmpty) return pendingChecks.removeAt(0).future;
      return await (pending?.future ??
          Future.value(
            check ?? const BuiltinLinuxRunResult(exitCode: 0, output: ''),
          ));
    }
    return super.run(script, timeout: timeout);
  }
}

final _l10n = lookupAppLocalizations(const Locale('en'));

final _inAppTwo = ServerProfile(
  id: 'phone2',
  name: 'This phone',
  baseUrl: BuiltinLinux.serverUrl,
  username: BuiltinLinux.serverUsername,
  password: 'secret',
  flavor: ServerFlavor.v2,
  serverVersion: TermuxRuntime.openCode2.pinnedVersion,
);

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

final _line = find.byKey(const ValueKey('this-phone-move-line'));

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  Future<dynamic> inApp(
    WidgetTester tester,
    ServerProfile profile, {
    bool dismissed = false,
    PhoneLinux? linux,
  }) async {
    final engine = await pumpPhone(
      tester,
      home: const ThisPhoneScreen(kind: PhoneHostKind.inApp),
      linux: linux ?? PhoneLinux(running: true),
      profiles: [profile],
      readyTimeout: const Duration(milliseconds: 300),
      configure: (controller) {
        if (dismissed) {
          controller.store.prefs.setBool(
            MoveToOpenCode2Dismissal.keyFor(profile.id),
            true,
          );
        }
      },
    );
    await _settle(tester);
    return engine;
  }

  testWidgets('older OpenCode in the app: the line, in plain words', (
    tester,
  ) async {
    await inApp(tester, inAppProfile);
    expect(_line, findsOneWidget);
    expect(find.text(_l10n.moveToOpenCode2Detail), findsOneWidget);
    expect(find.text(_l10n.moveToOpenCode2Title), findsOneWidget);
    expect(
      find.byKey(const ValueKey('this-phone-move-not-now')),
      findsOneWidget,
    );
    await unmountPhone(tester);
  });

  for (final unavailable in [false, true]) {
    testWidgets(
      '${unavailable ? 'unreadable history' : 'separate OC2 history'} hides the move and offers Stay',
      (tester) async {
        final linux = _HistoryLinux(
          check: const BuiltinLinuxRunResult(
            exitCode: 74,
            output: openCode1HistorySwitchBlockedMessage,
          ),
          throwCheck: unavailable,
        );
        final engine = await inApp(tester, inAppProfile, linux: linux);
        expect(_line, findsNothing);
        expect(find.text(_l10n.moveToOpenCode2Detail), findsNothing);
        final detail = unavailable
            ? _l10n.setupSwitchHistoryUnavailableDetail
            : _l10n.setupSwitchSeparateHistoryDetail;
        expect(find.textContaining(detail, findRichText: true), findsOneWidget);
        final row = find.byKey(const ValueKey('this-phone-switch'));
        await tester.ensureVisible(row);
        await tester.tap(row);
        await _settle(tester);
        expect(
          find.byKey(const ValueKey('this-phone-switch-blocked')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('this-phone-switch-confirm')),
          findsNothing,
        );
        await tester.tap(find.byKey(const ValueKey('this-phone-switch-stay')));
        await _settle(tester);
        expect(engine.runs, isEmpty);
        expect(linux.running, isTrue);
        expect(linux.starts, 0);
        expect(
          find.byKey(const ValueKey('this-phone-switch-blocked')),
          findsNothing,
        );
        await unmountPhone(tester);
      },
    );
  }

  testWidgets('pending check hides the offer until admitted', (tester) async {
    final linux = _HistoryLinux()..pending = Completer<BuiltinLinuxRunResult>();
    await inApp(tester, inAppProfile, linux: linux);
    expect(_line, findsNothing);
    linux.pending!.complete(
      const BuiltinLinuxRunResult(exitCode: 0, output: ''),
    );
    await _settle(tester);
    expect(_line, findsOneWidget);
    await unmountPhone(tester);
  });

  testWidgets(
    'history created after the page opens is rechecked before promising a move',
    (tester) async {
      final linux = _HistoryLinux();
      final engine = await inApp(tester, inAppProfile, linux: linux);
      expect(_line, findsOneWidget);
      linux.check = const BuiltinLinuxRunResult(
        exitCode: 74,
        output: openCode1HistorySwitchBlockedMessage,
      );
      await tester.tap(find.byKey(const ValueKey('this-phone-move')));
      await _settle(tester);
      expect(_line, findsNothing);
      expect(
        find.byKey(const ValueKey('this-phone-switch-blocked')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('this-phone-switch-confirm')),
        findsNothing,
      );
      expect(engine.runs, isEmpty);
      expect(linux.running, isTrue);
      await unmountPhone(tester);
    },
  );

  testWidgets('a concurrent refresh cannot replace the tapped safety result', (
    tester,
  ) async {
    final linux = _HistoryLinux();
    final engine = await inApp(tester, inAppProfile, linux: linux);
    final tapCheck = Completer<BuiltinLinuxRunResult>();
    final refreshCheck = Completer<BuiltinLinuxRunResult>();
    linux.pendingChecks.addAll([tapCheck, refreshCheck]);
    await tester.tap(find.byKey(const ValueKey('this-phone-move')));
    await _settle(tester);
    setupToolsChanged.value++;
    await _settle(tester);
    tapCheck.complete(
      const BuiltinLinuxRunResult(
        exitCode: 74,
        output: openCode1HistorySwitchBlockedMessage,
      ),
    );
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('this-phone-switch-blocked')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('this-phone-switch-confirm')),
      findsNothing,
    );
    expect(engine.runs, isEmpty);
    refreshCheck.complete(
      const BuiltinLinuxRunResult(
        exitCode: 74,
        output: openCode1HistorySwitchBlockedMessage,
      ),
    );
    await _settle(tester);
    expect(_line, findsNothing);
    await unmountPhone(tester);
  });

  testWidgets('OpenCode 2 already: no line', (tester) async {
    await inApp(tester, _inAppTwo);
    expect(_line, findsNothing);
    await unmountPhone(tester);
  });

  testWidgets('older OpenCode in Termux: the same line', (tester) async {
    TermuxChannelFixture()
      ..inventoryOutput =
          'ubuntu=installed\nversion=1.18.29\nruntime=opencode1\n'
      ..statusOutput = termuxSnapshot(phase: 'ready', version: '1.18.29')
      ..install();
    await pumpPhone(
      tester,
      home: const ThisPhoneScreen(kind: PhoneHostKind.termux),
      profiles: [_termuxProfile],
    );
    await _settle(tester);
    expect(_line, findsOneWidget);
    await unmountPhone(tester);
  });

  testWidgets(
    'Termux separate history hides the move and keeps both histories in place',
    (tester) async {
      final channel = TermuxChannelFixture()
        ..inventoryOutput =
            'ubuntu=installed\nversion=1.18.29\nruntime=opencode1\n'
        ..statusOutput = termuxSnapshot(phase: 'ready', version: '1.18.29')
        ..historyCheckExitCode = 74
        ..historyCheckOutput = openCode1HistorySwitchBlockedMessage
        ..install();
      await pumpPhone(
        tester,
        home: const ThisPhoneScreen(kind: PhoneHostKind.termux),
        profiles: [_termuxProfile],
      );
      await _settle(tester);
      expect(_line, findsNothing);
      final row = find.byKey(const ValueKey('this-phone-switch'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await _settle(tester);
      expect(
        find.byKey(const ValueKey('this-phone-switch-stay')),
        findsOneWidget,
      );
      expect(channel.switchCalls, 0);
      expect(channel.launchCalls, 0);
      await unmountPhone(tester);
    },
  );

  testWidgets('Not now hides the line and saves it for this server only', (
    tester,
  ) async {
    await inApp(tester, inAppProfile);
    await tester.tap(find.byKey(const ValueKey('this-phone-move-not-now')));
    await _settle(tester);
    expect(_line, findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('oc.moveToOpenCode2Dismissed.phone'), isTrue);
    // The plain switch row is still there for anyone who wants it later.
    expect(find.byKey(const ValueKey('this-phone-switch')), findsOneWidget);
    await unmountPhone(tester);
  });

  testWidgets('a dismissed line stays away when the page is opened again', (
    tester,
  ) async {
    await inApp(tester, inAppProfile, dismissed: true);
    expect(_line, findsNothing);
    await unmountPhone(tester);
  });

  testWidgets('a dismissal of another server does not hide this one', (
    tester,
  ) async {
    await pumpPhone(
      tester,
      home: const ThisPhoneScreen(kind: PhoneHostKind.inApp),
      linux: PhoneLinux(running: true),
      profiles: [inAppProfile],
      readyTimeout: const Duration(milliseconds: 300),
      configure: (controller) => controller.store.prefs.setBool(
        MoveToOpenCode2Dismissal.keyFor('another-server'),
        true,
      ),
    );
    await _settle(tester);
    expect(_line, findsOneWidget);
    await unmountPhone(tester);
  });

  testWidgets('tapping it runs the switch flow: sheet, then the OpenCode 2 '
      'install', (tester) async {
    final engine = await inApp(tester, inAppProfile);
    await tester.tap(find.byKey(const ValueKey('this-phone-move')));
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('this-phone-switch-sheet')),
      findsOneWidget,
    );
    // The sheet tells the truth about this direction: chats come along.
    expect(find.text(_l10n.setupSwitchToTwoDetail), findsOneWidget);
    expect(engine.runs, isEmpty);
    await tester.tap(find.byKey(const ValueKey('this-phone-switch-confirm')));
    await _settle(tester);
    expect(engine.runs, [
      {'opencode'},
    ]);
    expect(engine.runParams.single['opencode'], {
      'runtime': TermuxRuntime.openCode2.wireName,
    });
    await unmountPhone(tester);
  });

  testWidgets('cancelling the sheet leaves the line where it was', (
    tester,
  ) async {
    final engine = await inApp(tester, inAppProfile);
    await tester.tap(find.byKey(const ValueKey('this-phone-move')));
    await _settle(tester);
    await tester.tapAt(const Offset(200, 20));
    await _settle(tester);
    expect(engine.runs, isEmpty);
    expect(_line, findsOneWidget);
    await unmountPhone(tester);
  });

  test('the dismissal key is swept with the profile', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await MoveToOpenCode2Dismissal.dismiss(prefs, 'p1');
    await MoveToOpenCode2Dismissal.dismiss(prefs, 'p2');
    final store = ProfileStore(prefs: prefs);
    expect(store.profileScopedPreferenceKeys('p1'), {
      MoveToOpenCode2Dismissal.keyFor('p1'),
    });
    await store.removeScopedPreferences('p1');
    expect(MoveToOpenCode2Dismissal.dismissed(prefs, 'p1'), isFalse);
    expect(MoveToOpenCode2Dismissal.dismissed(prefs, 'p2'), isTrue);
  });
}
