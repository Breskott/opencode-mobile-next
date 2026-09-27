// Golden renders of Termux as a host of the v2 phone setup (P1.2): the
// person step leading the same checklist the in-app setup shows (phone and
// a wide window), an install an older build left in Termux recognised as
// done (every component skipped, only the start left), and This phone's
// "Add tools" for Termux, which is now the same Customize sheet as the
// in-app host. Light, the app's real fonts, DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/termux_v2_host_golden_test.dart
// and look at every changed image before committing it.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/setup/setup_contract.dart';
import 'package:opencode_mobile/state/phone_host.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_customize_sheet.dart';
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_termux_job_screen.dart';
import 'package:opencode_mobile/ui/screens/this_phone_screen.dart';

import '../../tool/capture/fixtures.dart' show loadCaptureFonts;
import '../support/fake_setup_engine.dart';
import '../support/termux_channel_fixture.dart';
import 'screen_phone_1_fixtures.dart';

/// The in-app registry plus AI Team, as Termux lists it.
const _registry = [
  ...FakeSetupEngine.fakeRegistry,
  SetupComponent(
    id: 'aiteam',
    title: 'AI Team',
    shortTitle: 'AI Team',
    checkScript: 'true',
    installScript: 'true',
    dependsOn: ['essentials', 'opencode'],
    estimatedSeconds: 150,
    downloadBytes: 160000000,
  ),
  SetupComponent(
    id: 'start',
    title: 'Start OpenCode',
    shortTitle: 'Start OpenCode',
    checkScript: '',
    installScript: '',
    dependsOn: ['opencode'],
    jobStep: true,
    required: true,
  ),
];

SetupProgress _existingInstall() => const SetupProgress(
  state: SetupState.running,
  jobId: 'setup-termux',
  current: 'start',
  overall: .96,
  firstSetup: true,
  components: [
    ComponentProgress(id: 'linux', state: ComponentState.skipped),
    ComponentProgress(
      id: 'essentials',
      state: ComponentState.skipped,
      version: '2.43.0',
    ),
    ComponentProgress(
      id: 'python',
      state: ComponentState.skipped,
      version: '3.12.3',
    ),
    ComponentProgress(
      id: 'node',
      state: ComponentState.skipped,
      version: '18.19.1',
    ),
    ComponentProgress(
      id: 'opencode',
      state: ComponentState.skipped,
      version: '1.18.32',
    ),
    ComponentProgress(
      id: 'start',
      state: ComponentState.running,
      stage: 'Starting OpenCode',
    ),
  ],
);

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
  List<ServerProfile> profiles = const [],
  Future<void> Function()? act,
}) async {
  final boundary = GlobalKey();
  try {
    await pumpPhone(
      tester,
      home: home,
      size: size,
      light: true,
      boundary: boundary,
      profiles: profiles,
    );
    if (act != null) await act();
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/$name.png'),
    );
  } finally {
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

  for (final size in [phoneSize, wideSize]) {
    testWidgets('Termux host: allow Termux leads the job ($size)', (
      tester,
    ) async {
      TermuxChannelFixture()
        ..permissionGranted = false
        ..install();
      await _shot(
        tester,
        size == phoneSize
            ? 'termux_v2_allow_light'
            : 'termux_v2_allow_1280x800_light',
        size: size,
        home: PhoneSetupTermuxJobScreen(
          engine: FakeSetupEngine(registry: _registry),
          firstSetup: true,
        ),
      );
    });
  }

  testWidgets('Termux host: an existing install is recognised as done', (
    tester,
  ) async {
    TermuxChannelFixture().install();
    final engine = FakeSetupEngine(registry: _registry)
      ..emit(_existingInstall());
    await _shot(
      tester,
      'termux_v2_existing_install_light',
      home: PhoneSetupTermuxJobScreen(engine: engine, firstSetup: true),
    );
  });

  testWidgets('Termux host: Add tools is the same Customize sheet', (
    tester,
  ) async {
    final engine = FakeSetupEngine(registry: _registry)
      ..optionalInstalled = {'python'};
    await _shot(
      tester,
      'termux_v2_add_tools_light',
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: KitButton.primary(
              label: 'open',
              expand: false,
              onPressed: () => showSetupCustomizeSheet(
                context,
                engine: engine,
                addMode: true,
              ),
            ),
          ),
        ),
      ),
      act: () async {
        await tester.tap(find.text('open'));
      },
    );
  });

  testWidgets('This phone in Termux: Add tools, and Claude Code beside it', (
    tester,
  ) async {
    TermuxChannelFixture()
      ..inventoryOutput =
          'ubuntu=installed\nversion=1.18.32\nruntime=opencode1\n'
      ..statusOutput = termuxSnapshot(phase: 'ready', version: '1.18.32')
      ..install();
    await _shot(
      tester,
      'termux_v2_this_phone_light',
      home: const ThisPhoneScreen(kind: PhoneHostKind.termux),
      profiles: [
        ServerProfile(
          id: 'termux',
          name: 'This phone',
          baseUrl: TermuxBridge.managedServerUrl,
          password: 'synthetic-test-secret',
          serverVersion: '1.18.32',
        ),
      ],
      act: () async {
        final row = find.byKey(const ValueKey('local-agent-row'));
        await tester.ensureVisible(row);
      },
    );
  });
}
