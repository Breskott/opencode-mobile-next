// Regenerate deliberately, and look at every changed image before committing it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/project_fixture_gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/phone_team_setup.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/team/projects/team_execution_gate.dart';
import 'package:opencode_mobile/ui/screens/team/projects/team_projects_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_phone_setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../phone_team_setup_test.dart'
    as fake
    show phoneForGolden, healthForGolden, PhoneTeamSetupPortsForGolden;
import '../../team_project_fixture_test.dart' show MemoryPersistence;
import '../kit/kit_gallery.dart';

class _Gateway extends ProjectFixtureGateway {
  _Gateway() : super(persistence: MemoryPersistence());
  @override
  OrchestrationCapabilities get capabilities =>
      const OrchestrationCapabilities(projects: true, projectLifecycle: true);
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
    await loadKitGalleryFonts();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'plugins.it_nomads.com/flutter_secure_storage',
      'oc/background',
      'oc/shortcut',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (call) async => call.method == 'readAll' ? <String, String>{} : null,
      );
    }
  });

  final shots = <({Size size, bool light})>[
    (size: const Size(412, 915), light: false),
    (size: const Size(1280, 800), light: true),
  ];
  for (final shot in shots) {
    for (final scene in [
      'reply',
      'confirm',
      'check',
      'failed',
      'ready',
      'blocked',
    ]) {
      testWidgets(
        'phone team setup $scene ${kitGallerySize(shot.size)} ${shot.light}',
        (tester) async {
          final prefs = await SharedPreferences.getInstance();
          final connection = ConnectionController(ProfileStore(prefs: prefs));
          var clock = DateTime.utc(2026, 9, 30, 12);
          late PhoneTeamSetupController flow;
          final proof = Completer<void>();
          final held = <fake.PhoneTeamSetupPortsForGolden>[];
          OrchestrationController? owner;
          Future<void> open(BuildContext context) async {
            final phone = fake.phoneForGolden();
            held.add(phone);
            switch (scene) {
              case 'reply':
                phone.reply = true;
              case 'confirm':
                phone.host = const PhoneTeamHostState(
                  serverRunning: true,
                  terminals: 2,
                );
              case 'failed':
                phone.started = fake.healthForGolden(
                  boundary: false,
                  reason: 'boundary_proof_failed',
                );
              case 'check':
                phone.holdStart = proof.future;
            }
            flow = PhoneTeamSetupController(
              phone,
              now: () => clock,
              delay: (_) async {},
              readyAttempts: 1,
            );
            if (scene == 'blocked') {
              owner?.dispose();
              owner = OrchestrationController(
                profile: ServerProfile(
                  id: 'p',
                  name: 'This phone',
                  baseUrl: 'http://127.0.0.1:4097',
                ),
                config: const OrchestrationConfig(
                  provider: OrchestrationProvider.fixture,
                  url: 'fixture://golden',
                ),
                store: OrchestrationStore(prefs),
                gatewayFactory: (_, _) => _Gateway(),
              );
              await owner!.start();
              TeamExecutionGate.bind(owner!, connection);
              unawaited(
                pushKitPage<void>(
                  context,
                  (_) =>
                      TeamProjectsScreen(controller: owner!.projectController!),
                ),
              );
              return;
            }
            unawaited(
              openPhoneTeamSetup(
                context,
                connection,
                controller: flow,
                autoStart: false,
              ),
            );
            unawaited(flow.run());
          }

          await kitGalleryShot(
            tester,
            name: kitGalleryName(
              'kit_teamphonesetup_$scene',
              shot.size,
              light: shot.light,
            ),
            size: shot.size,
            light: shot.light,
            open: open,
            then: (tester) async {
              // Twelve seconds into whatever step is working.
              clock = clock.add(const Duration(seconds: 12));
              await tester.pump(const Duration(seconds: 1));
              await tester.pump(const Duration(milliseconds: 300));
            },
            settleAfterThen: false,
          );
          proof.complete();
          // The reply scene holds the flow on a running reply (and its
          // 2 s poll); let it end so no timer outlives the test.
          // Both theme passes opened their own flow.
          for (final phone in held) {
            phone.finishReply();
          }
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 3));
          owner?.dispose();
          connection.dispose();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }
}
