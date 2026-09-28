// Golden renders for slice-close-servers (review board closure,
// 2026-09-28): phone setup v2 with Termux as the host, in the states the
// owner's "Align with v2" / "Unify all installation into v2" notes cover —
// a too-old Termux (failed row with "Get the current Termux"), a denied
// permission ("Allow the permission in Settings"), a script failure (plain
// words, raw text under Details) and phone setup off Android ("Connect a
// server" with the command). Phone and a wide window; light, the app's real
// fonts, DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/slice_close_servers_termux_golden_test.dart
// and look at every changed image before committing it.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/setup/setup_contract.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_termux_job_screen.dart';

import '../../tool/capture/fixtures.dart' show loadCaptureFonts;
import '../support/fake_setup_engine.dart';
import '../support/termux_channel_fixture.dart';
import 'screen_phone_1_fixtures.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shot(
  WidgetTester tester,
  String name, {
  required Widget home,
  Size size = phoneSize,
  Future<void> Function()? act,
}) async {
  final boundary = GlobalKey();
  debugDefaultTargetPlatformOverride = TargetPlatform.android; // ARCH-11
  try {
    await pumpPhone(
      tester,
      home: home,
      size: size,
      light: true,
      boundary: boundary,
    );
    await _settle(tester);
    if (act != null) await act();
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/$name.png'),
    );
  } finally {
    debugDefaultTargetPlatformOverride = null;
    await unmountPhone(tester);
  }
}

String _name(String base, Size size) =>
    size == phoneSize ? '${base}_light' : '${base}_1280x800_light';

void main() {
  setUpAll(loadCaptureFonts);
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  });

  for (final size in [phoneSize, wideSize]) {
    testWidgets('too-old Termux: its failed row gets the current one ($size)', (
      tester,
    ) async {
      TermuxChannelFixture()
        ..protocolSupported = false
        ..install();
      await _shot(
        tester,
        _name('close_servers_termux_outdated', size),
        size: size,
        home: PhoneSetupTermuxJobScreen(
          engine: FakeSetupEngine(),
          firstSetup: true,
        ),
      );
    });

    testWidgets('a denied permission names Settings ($size)', (tester) async {
      TermuxChannelFixture()
        ..permissionGranted = false
        ..permissionResult = false
        ..install();
      await _shot(
        tester,
        _name('close_servers_termux_denied', size),
        size: size,
        home: PhoneSetupTermuxJobScreen(
          engine: FakeSetupEngine(),
          firstSetup: true,
        ),
        act: () async {
          final allow = find.byKey(const ValueKey('phone-setup-termux-allow'));
          await tester.ensureVisible(allow);
          await tester.pump();
          await tester.tap(allow);
        },
      );
    });

    testWidgets('off Android: connect a server instead ($size)', (
      tester,
    ) async {
      debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
      addTearDown(() => debugPlatformCapabilities = null);
      await _shot(
        tester,
        _name('close_servers_setup_unsupported', size),
        size: size,
        home: const PhoneSetupTermuxJobScreen(),
      );
    });
  }

  testWidgets('a script failure: plain words, the raw text under Details', (
    tester,
  ) async {
    TermuxChannelFixture().install();
    final engine = FakeSetupEngine()
      ..emit(
        const SetupProgress(
          state: SetupState.failed,
          jobId: 'setup-termux',
          current: 'python',
          overall: .45,
          firstSetup: true,
          components: [
            ComponentProgress(id: 'linux', state: ComponentState.done),
            ComponentProgress(id: 'essentials', state: ComponentState.done),
            ComponentProgress(
              id: 'python',
              state: ComponentState.failed,
              stage: 'Installing Python',
              error:
                  'dpkg: error processing package libc6 (--configure): '
                  'installed post-installation script returned exit status 1',
            ),
            ComponentProgress(id: 'node', state: ComponentState.pending),
            ComponentProgress(id: 'opencode', state: ComponentState.pending),
          ],
          logTail: 'Reading package lists...\nSetting up libc6 ...\n',
        ),
      );
    await _shot(
      tester,
      'close_servers_termux_script_failed_light',
      home: PhoneSetupTermuxJobScreen(engine: engine, firstSetup: true),
      act: () async {
        final details = find.byKey(const Key('setup-progress-details'));
        await tester.ensureVisible(details);
        await tester.pump();
        await tester.tap(details);
        await _settle(tester);
        await tester.ensureVisible(
          find.byKey(const ValueKey('setup-progress-row-python')),
        );
      },
    );
  });
}
