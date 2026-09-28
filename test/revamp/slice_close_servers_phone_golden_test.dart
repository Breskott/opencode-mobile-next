// Golden renders of This phone in Termux for slice-close-servers (review
// board closure, 2026-09-28): a failed start and a failed install each said
// in plain words with the act that fixes it, a switch stopped half way, the
// Update question without engine words, and an install already at the
// pinned version. Light, the app's real fonts, DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens \
//     test/revamp/slice_close_servers_phone_golden_test.dart
// and look at every changed image before committing it.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/phone_host.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:opencode_mobile/ui/screens/this_phone_screen.dart';

import '../../tool/capture/fixtures.dart' show loadCaptureFonts;
import '../support/termux_channel_fixture.dart';
import 'screen_phone_1_fixtures.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

ServerProfile _profile(String version) => ServerProfile(
  id: 'termux',
  name: 'This phone',
  baseUrl: TermuxBridge.managedServerUrl,
  password: 'synthetic-test-secret',
  serverVersion: version,
);

Future<void> _shot(
  WidgetTester tester,
  String name, {
  required String status,
  String version = '1.18.29',
  String runtime = 'opencode1',
  Size size = phoneSize,
  Future<void> Function()? act,
}) async {
  TermuxChannelFixture()
    ..inventoryOutput = 'ubuntu=installed\nversion=$version\nruntime=$runtime\n'
    ..statusOutput = status
    ..install();
  final boundary = GlobalKey();
  try {
    await pumpPhone(
      tester,
      home: const ThisPhoneScreen(kind: PhoneHostKind.termux),
      size: size,
      light: true,
      boundary: boundary,
      profiles: [_profile(version)],
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
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    await unmountPhone(tester);
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

  final startFailed = termuxSnapshot(
    phase: 'failed',
    message: 'OpenCode server exited (code 137)',
    version: '1.18.29',
    extra: 'failure_kind=crash\n',
  );

  for (final size in [phoneSize, const Size(1280, 800)]) {
    final suffix = size == phoneSize ? '' : '_1280x800';
    testWidgets('start failed ($size)', (tester) async {
      await _shot(
        tester,
        'close_servers_this_phone_start_failed${suffix}_light',
        status: startFailed,
        size: size,
      );
    });
  }

  testWidgets('start failed, Details open', (tester) async {
    await _shot(
      tester,
      'close_servers_this_phone_start_failed_details_light',
      status: startFailed,
      act: () async {
        final details = find.byKey(const ValueKey('this-phone-details'));
        await tester.ensureVisible(details);
        await _settle(tester);
        await tester.tap(details);
        await _settle(tester);
        await tester.ensureVisible(details);
      },
    );
  });

  testWidgets('install failed', (tester) async {
    await _shot(
      tester,
      'close_servers_this_phone_install_failed_light',
      status: termuxSnapshot(
        phase: 'failed',
        message: 'Could not install the Termux dependencies',
        version: '1.18.29',
      ),
    );
  });

  testWidgets('switch stopped half way', (tester) async {
    final version = TermuxRuntime.openCode2.pinnedVersion;
    await _shot(
      tester,
      'close_servers_this_phone_switch_stopped_light',
      version: version,
      runtime: 'opencode2',
      status: termuxSnapshot(
        phase: 'failed',
        message: 'OpenCode server exited (code 1)',
        version: version,
        runtime: TermuxRuntime.openCode2,
        extra:
            'failure_kind=crash\nswitch_previous=opencode1\n'
            'switch_target=opencode2\nswitch_phase=starting\n'
            'switch_return=opencode1\n',
      ),
    );
  });

  testWidgets('update question', (tester) async {
    await _shot(
      tester,
      'close_servers_this_phone_update_confirm_light',
      version: '1.18.20',
      status: termuxSnapshot(phase: 'ready', version: '1.18.20'),
      act: () async {
        await tester.tap(find.byKey(const ValueKey('this-phone-update')));
      },
    );
  });

  for (final size in [phoneSize, const Size(1280, 800)]) {
    final suffix = size == phoneSize ? '' : '_1280x800';
    testWidgets('up to date ($size)', (tester) async {
      final pinned = TermuxRuntime.openCode1.pinnedVersion;
      await _shot(
        tester,
        'close_servers_this_phone_up_to_date${suffix}_light',
        version: pinned,
        size: size,
        status: termuxSnapshot(phase: 'ready', version: pinned),
      );
    });
  }
}
