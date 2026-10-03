import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/orchestration/adapters/none.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/team_project_demo.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    for (final channel in [
      'plugins.it_nomads.com/flutter_secure_storage',
      'oc/background',
      'oc/shortcut',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
  });
  tearDown(() {
    for (final channel in [
      'plugins.it_nomads.com/flutter_secure_storage',
      'oc/background',
      'oc/shortcut',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), null);
    }
  });

  test(
    'built-in demo loads without filesystem recordings or a server',
    () async {
      final owner = createTeamProjectPreview(prefs);
      await owner.start();
      final projects = owner.projectController!;
      expect(owner.capabilities.projectLifecycle, isTrue);
      expect(projects.snapshot!.projects, isNotEmpty);
      expect(projects.snapshot!.simulated, isTrue);
      expect(owner.snapshot.gates, isNotEmpty);
      final seeded = projects.snapshot!.projects.first;
      await projects.execute(
        TeamProjectCommand(
          requestId: projects.newRequestId(),
          action: TeamProjectAction.advance,
          projectId: seeded.id,
          expectedRevision: seeded.revision,
        ),
      );
      final project = projects.snapshot!.projects.firstWhere(
        (p) => p.requests.any((r) => !r.answered && r.kind == 'question'),
      );
      final question = project.requests.firstWhere(
        (r) => !r.answered && r.kind == 'question',
      );
      final result = await projects.execute(
        TeamProjectCommand(
          requestId: projects.newRequestId(),
          action: TeamProjectAction.answerRequest,
          projectId: project.id,
          expectedRevision: project.revision,
          targetId: question.id,
          text: 'Keep the data on this device',
        ),
      );
      expect(result.accepted, isTrue);
      await owner.refresh();
      expect(owner.snapshot.gates.any((g) => g.id == question.id), isFalse);
      await owner.stop();
      owner.dispose();

      final reopened = createTeamProjectPreview(prefs);
      await reopened.start();
      final restored = reopened.projectController!.snapshot!.projects
          .firstWhere((p) => p.id == project.id);
      expect(
        restored.requests.firstWhere((r) => r.id == question.id).answered,
        isTrue,
      );
      expect(restored.tasks.where((t) => t.status == 'running'), isEmpty);
      await reopened.remove();
      reopened.dispose();
      expect(
        prefs.getKeys().where((k) => k.contains('team-project-preview')),
        isEmpty,
      );
    },
  );

  test('concurrent stop and remove wait for gateway closure', () async {
    final closing = Completer<void>();
    final gateway = _SlowClosingGateway(closing.future);
    final profile = ServerProfile(
      id: 'drain-demo',
      name: 'Drain demo',
      baseUrl: 'http://127.0.0.1',
    );
    final owner = OrchestrationController(
      profile: profile,
      config: teamProjectDemoConfig,
      store: OrchestrationStore(prefs),
      gatewayFactory: (_, _) => gateway,
    );
    await owner.start();
    await prefs.setString('oc.teamWorkspace.drain-demo', 'saved');
    final first = owner.stop();
    var removed = false;
    final removal = owner.remove().then((_) => removed = true);
    await Future<void>.delayed(Duration.zero);
    expect(removed, isFalse);
    expect(prefs.containsKey('oc.teamWorkspace.drain-demo'), isTrue);
    closing.complete();
    await first;
    await removal;
    expect(prefs.containsKey('oc.teamWorkspace.drain-demo'), isFalse);
    owner.dispose();
  });

  test('stop during initial loading never starts a late simulator', () async {
    var builds = 0;
    final owner = OrchestrationController(
      profile: ServerProfile(
        id: 'early-stop',
        name: 'Early stop',
        baseUrl: 'http://127.0.0.1',
      ),
      config: teamProjectDemoConfig,
      store: OrchestrationStore(prefs),
      gatewayFactory: (_, _) {
        builds++;
        return const NullOrchestrationGateway();
      },
    );
    final starting = owner.start();
    await owner.stop();
    await starting;
    expect(builds, 0);
    expect(owner.phase, OrchestrationPhase.stopped);
    owner.dispose();
  });

  test('stop drains a gateway factory that completes after shutdown', () async {
    final built = Completer<OrchestrationGateway>();
    final entered = Completer<void>();
    final gateway = _SlowClosingGateway(Future<void>.value());
    final owner = OrchestrationController(
      profile: ServerProfile(
        id: 'late-demo',
        name: 'Late demo',
        baseUrl: 'http://127.0.0.1',
      ),
      config: teamProjectDemoConfig,
      store: OrchestrationStore(prefs),
      gatewayFactory: (_, _) {
        entered.complete();
        return built.future;
      },
    );
    final starting = owner.start();
    await entered.future;
    var stopped = false;
    final stopping = owner.stop().then((_) => stopped = true);
    await Future<void>.delayed(Duration.zero);
    expect(stopped, isFalse);
    built.complete(gateway);
    await starting;
    await stopping;
    expect(owner.phase, OrchestrationPhase.stopped);
    expect(owner.projectController, isNull);
    owner.dispose();
  });

  test(
    'profile deletion closes the simulator before sweeping its records',
    () async {
      final store = ProfileStore(prefs: prefs);
      final doomed = ServerProfile(
        id: 'team-doomed',
        name: 'Demo host',
        baseUrl: 'http://127.0.0.1:4096',
        orchestration: teamProjectDemoConfig,
      );
      final keeper = ServerProfile(
        id: 'team-keeper',
        name: 'Other host',
        baseUrl: 'http://127.0.0.1:4097',
      );
      await store.upsert(doomed);
      await store.upsert(keeper);
      await prefs.setString('oc.teamWorkspace.team-keeper', 'keep');
      final owner = OrchestrationController(
        profile: doomed,
        config: teamProjectDemoConfig,
        store: OrchestrationStore(prefs),
      );
      await owner.start();
      final projects = owner.projectController!;
      expect(prefs.containsKey('oc.teamWorkspace.team-doomed'), isTrue);
      await projects.saveEditorDraft('project-new', 'Unsent local plan');
      expect(prefs.containsKey('oc.teamEditorDrafts.team-doomed'), isTrue);
      final connection = ConnectionController(store);
      connection.adoptOrchestrationForTesting(owner);
      await connection.deleteProfileAndLocalData(doomed.id);
      expect(prefs.containsKey('oc.teamWorkspace.team-doomed'), isFalse);
      expect(prefs.getString('oc.teamWorkspace.team-keeper'), 'keep');
      expect(
        (await projects.execute(
          TeamProjectCommand(
            requestId: 'after-delete',
            action: TeamProjectAction.advance,
          ),
        )).accepted,
        isFalse,
      );
      connection.dispose();
      owner.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(prefs.containsKey('oc.teamWorkspace.team-doomed'), isFalse);
    },
  );
}

class _SlowClosingGateway extends NullOrchestrationGateway {
  const _SlowClosingGateway(this.closed);
  final Future<void> closed;
  @override
  Future<void> close() => closed;
}
