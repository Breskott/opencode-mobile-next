// Synthetic screenshots of the actual release setup widgets, with no device data.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/builtin/setup/setup_contract.dart';
import 'package:opencode_mobile/domain/opencode_history_copy.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/phone_host.dart';
import 'package:opencode_mobile/ui/screens/this_phone_screen.dart';
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_progress_screen.dart';

import '../../test/revamp/screen_phone_1_fixtures.dart';
import '../../test/support/fake_setup_engine.dart';
import 'fixtures.dart' show loadCaptureFonts, capturePng, writePng;

class _SeparateHistoryLinux extends PhoneLinux {
  _SeparateHistoryLinux() : super(running: true);
  @override
  Future<BuiltinLinuxRunResult> run(
    String script, {
    Duration timeout = const Duration(minutes: 2),
  }) async => script.contains(openCode1HistorySwitchCheckScript)
      ? const BuiltinLinuxRunResult(
          exitCode: 74,
          output: openCode1HistorySwitchBlockedMessage,
        )
      : super.run(script, timeout: timeout);
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  setUpAll(loadCaptureFonts);
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });
  const output = 'docs/qa/release-device-pass-2026-10-15';
  testWidgets('separate histories explain Stay', (tester) async {
    final boundary = GlobalKey();
    await pumpPhone(
      tester,
      boundary: boundary,
      home: const ThisPhoneScreen(kind: PhoneHostKind.inApp),
      profiles: [inAppProfile],
      linux: _SeparateHistoryLinux(),
    );
    await _frames(tester);
    expect(find.byKey(const ValueKey('this-phone-move-line')), findsNothing);
    final row = find.byKey(const ValueKey('this-phone-switch'));
    await tester.ensureVisible(row);
    await _frames(tester);
    await writePng(
      '$output/setup-separate-histories.png',
      await capturePng(tester, boundary, pixelRatio: 2),
    );
    await tester.tap(row);
    await _frames(tester);
    expect(
      find.byKey(const ValueKey('this-phone-switch-stay')),
      findsOneWidget,
    );
    await writePng(
      '$output/setup-stay.png',
      await capturePng(tester, boundary, pixelRatio: 2),
    );
    await unmountPhone(tester);
  });
  testWidgets('Python repair words and Details', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final engine = FakeSetupEngine()
      ..emit(
        SetupProgress(
          state: SetupState.failed,
          current: 'python',
          overall: .5,
          error: l10n.phoneSetupErrorPackageRepair,
          logTail:
              'dpkg --audit\nlibonig5:amd64: install reinstreq half-installed',
          components: [
            const ComponentProgress(
              id: 'linux',
              state: ComponentState.done,
              version: '24.04.5',
            ),
            const ComponentProgress(
              id: 'essentials',
              state: ComponentState.done,
              version: '2.43.0',
            ),
            ComponentProgress(
              id: 'python',
              state: ComponentState.failed,
              error: l10n.phoneSetupErrorPackageRepair,
            ),
          ],
        ),
      );
    final boundary = GlobalKey();
    await pumpPhone(
      tester,
      boundary: boundary,
      home: PhoneSetupProgressScreen(engine: engine),
    );
    await _frames(tester);
    await tester.ensureVisible(find.text('Details'));
    await _frames(tester);
    await writePng(
      '$output/setup-python-repair.png',
      await capturePng(tester, boundary, pixelRatio: 2),
    );
    await tester.tap(find.text('Details'));
    await _frames(tester);
    await writePng(
      '$output/setup-python-details.png',
      await capturePng(tester, boundary, pixelRatio: 2),
    );
    expect(tester.takeException(), isNull);
    await unmountPhone(tester);
  });
}
