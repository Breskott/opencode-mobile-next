import 'package:flutter/widgets.dart';
import 'package:opencode_mobile/domain/phone_project_engine.dart';
import 'package:opencode_mobile/state/phone_team_setup.dart';
import 'package:opencode_mobile/ui/screens/team/team_phone_setup_screen.dart';
import 'package:widgetbook/widgetbook.dart';

import '../catalog.dart';
import '../fakes/fake_app.dart';

class _RecoveryPhone extends ChangeNotifier implements PhoneTeamSetupPorts {
  @override
  bool get hasServer => true;
  @override
  bool get wasOn => false;
  @override
  bool get replyRunning => false;
  @override
  Listenable get replyChanges => this;
  @override
  Future<PhoneTeamHostState> inspect() async => const PhoneTeamHostState();
  @override
  Future<void> stopServer() async {}
  @override
  Future<void> closeTerminals() async {}
  @override
  Future<void> stopEngine() async {}
  @override
  Future<PhoneEngineHealth> startEngine() async => const PhoneEngineHealth(
    profileId: 'phone',
    engineVersion: 'catalog',
    execution: true,
    boundary: true,
    oc1Verified: false,
    oc2: true,
    oc2Verified: true,
    commandActions: {},
  );
  @override
  Future<PhoneEngineHealth> probeEngine() => startEngine();
  @override
  Future<String?> startServer() async => 'componentRecovery';
  @override
  Future<bool> restoreServer() async => false;
  @override
  Future<void> attach() async {}
}

class _RecoveryScene implements SceneResource {
  _RecoveryScene(this.app) {
    flow = PhoneTeamSetupController(phone, delay: (_) async {});
  }
  final FakeApp app;
  final phone = _RecoveryPhone();
  late final PhoneTeamSetupController flow;
  @override
  void dispose() {
    flow.dispose();
    phone.dispose();
    app.dispose();
  }
}

CatalogComponent teamPhoneSetupScreen() => catalogComponent(
  area: 'Servers',
  screen: 'TeamPhoneSetupScreen',
  name: 'AI Team on this phone',
  useCases: [
    WidgetbookUseCase(
      name: 'Previous work needs Android recovery',
      builder: (_) => FakeAppScene<_RecoveryScene>(
        platform: FakePlatform.android,
        create: () async => _RecoveryScene(await FakeApp.create()),
        builder: (context, scene) => TeamPhoneSetupScreen(
          connection: scene.app.connection,
          controller: scene.flow,
        ),
      ),
    ),
  ],
);
