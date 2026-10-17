import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/domain/settings_scope.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _Disk extends InMemorySharedPreferencesStore {
  _Disk(super.data) : super.withData();
  bool refuseAgents = false;
  Completer<void>? entered;
  Completer<void>? release;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key == 'flutter.oc.sessionAgents.laptop') {
      entered?.complete();
      await release?.future;
      if (refuseAgents) return false;
    }
    return super.setValue(type, key, value);
  }
}

/// OC1 deliberately does not implement SessionSelectionGateway.
class _Api extends OpenCodeApi {
  _Api() : super(baseUrl: 'https://laptop.example.test');
  final deleted = <String>[];

  @override
  Future<void> deleteSession(String id) async => deleted.add(id);
}

class _Controller extends ConnectionController {
  _Controller(super.store, this.owner) : super(isIsolated: true);
  final ServerProfile owner;

  @override
  ServerProfile get profile => owner;

  @override
  Future<ServerGateway?> prepareActionTransport() async => api;
}

ServerProfile _profile(String id) =>
    ServerProfile(id: id, name: id, baseUrl: 'https://$id.example.test');

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late SharedPreferences prefs;
  late ProfileStore store;
  late _Disk disk;

  setUp(() async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      secure,
      (call) async => call.method == 'readAll' ? <String, String>{} : null,
    );
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    disk = _Disk(await SharedPreferencesStorePlatform.instance.getAll());
    SharedPreferencesStorePlatform.instance = disk;
    store = ProfileStore(prefs: prefs);
    await store.load();
    await store.upsert(_profile('laptop'));
    await store.upsert(_profile('phone'));
    await store.setAgent('laptop', 'build');
    await store.setAgent('phone', 'build');
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(secure, null);
  });

  _Controller controller({String id = 'laptop', ProfileStore? profiles}) {
    final result = _Controller(profiles ?? store, _profile(id))
      ..api = _Api()
      ..selectedAgent = 'build'
      ..directory = '/project';
    result.sessionsById.addAll({
      'a': Session(id: 'a', directory: '/project'),
      'b': Session(id: 'b', directory: '/project'),
    });
    addTearDown(result.dispose);
    return result;
  }

  test(
    'choosing an OC1 chat agent leaves other chats and profile default alone',
    () async {
      final target = controller();
      expect(target.serverOwnsSessionSelection, isFalse);
      await target.selectAgentForSession('a', 'plan');

      expect(target.agentForSession('a'), 'plan');
      expect(target.selectionForSession('a').agent, 'plan');
      expect(target.agentForSession('b'), 'build');
      expect(target.selectedAgent, 'build');
      expect(prefs.getString('oc.agent.laptop'), 'build');
      expect(store.sessionAgentsFor('laptop'), {'a': 'plan'});
      expect(prefs.getString('oc.sessionAgents.laptop'), isNotNull);
      expect(store.sessionAgentsFor('phone'), isEmpty);
    },
  );

  test(
    'saved chat agent restores in a new controller and stays profile-specific',
    () async {
      final original = controller();
      await original.selectAgentForSession('a', 'plan');
      final restartedStore = ProfileStore(prefs: prefs);
      await restartedStore.load();
      expect(restartedStore.sessionAgentsFor('laptop'), {'a': 'plan'});
      final restarted = controller(profiles: restartedStore);
      final otherServer = controller(id: 'phone', profiles: restartedStore);

      expect(restarted.agentForSession('a'), 'plan');
      expect(restarted.agentForSession('b'), 'build');
      expect(otherServer.agentForSession('a'), 'build');
      await restarted.selectAgent('review');
      expect(restarted.agentForSession('a'), 'plan');
      expect(restarted.agentForSession('b'), 'review');
    },
  );

  test(
    'a chat choice is not published before storage acknowledges it',
    () async {
      final target = controller();
      disk.entered = Completer<void>();
      disk.release = Completer<void>();
      final saving = target.selectAgentForSession('a', 'plan');
      await disk.entered!.future;
      expect(target.agentForSession('a'), 'build');
      expect(target.selectedAgent, 'build');
      disk.release!.complete();
      await saving;
      expect(target.agentForSession('a'), 'plan');
      expect(target.agentForSession('b'), 'build');
    },
  );

  test(
    'refused chat-agent persistence throws and keeps the acknowledged choice',
    () async {
      final target = controller();
      await target.selectAgentForSession('a', 'plan');
      disk.refuseAgents = true;
      await expectLater(
        target.selectAgentForSession('a', 'review'),
        throwsA(anything),
      );

      expect(target.agentForSession('a'), 'plan');
      expect(target.agentForSession('b'), 'build');
      expect(target.selectedAgent, 'build');
      expect(store.sessionAgentsFor('laptop'), {'a': 'plan'});
      expect(
        (await disk.getAll())['flutter.oc.sessionAgents.laptop'],
        contains('plan'),
      );
    },
  );

  test('deleting a chat removes only its stored agent override', () async {
    final target = controller();
    await target.selectAgentForSession('a', 'plan');
    await target.selectAgentForSession('b', 'review');
    await target.deleteSession('a');
    // Session cleanup includes asynchronously persisted local shelves.
    await Future<void>.delayed(Duration.zero);

    expect((target.api! as _Api).deleted, ['a']);
    expect(target.sessionsById.containsKey('a'), isFalse);
    expect(store.sessionAgentsFor('laptop'), {'b': 'review'});
    expect(target.agentForSession('b'), 'review');
    expect(target.selectedAgent, 'build');
    expect(
      store.profileScopedPreferenceKeys('laptop'),
      contains('oc.sessionAgents.laptop'),
    );
  });
  test(
    'profile deletion drains a pending chat-agent write without resurrection',
    () async {
      final target = controller();
      await store.setSessionAgents('phone', {'other': 'review'});
      disk.entered = Completer<void>();
      disk.release = Completer<void>();
      final saving = target.selectAgentForSession('a', 'plan');
      final rejected = expectLater(
        saving,
        throwsA(
          isA<SettingsFailure>().having(
            (e) => e.reason,
            'reason',
            SettingsFailureReason.staleTarget,
          ),
        ),
      );
      await disk.entered!.future;
      final deletion = store.removeScopedPreferences('laptop');
      disk.release!.complete();
      await rejected;
      expect(await deletion, isEmpty);
      expect(prefs.containsKey('oc.sessionAgents.laptop'), isFalse);
      expect(store.sessionAgentsFor('laptop'), isEmpty);
      expect(store.sessionAgentsFor('phone'), {'other': 'review'});
      await expectLater(
        store.setSessionAgent('laptop', 'a', 'plan'),
        throwsA(
          isA<SettingsFailure>().having(
            (e) => e.reason,
            'reason',
            SettingsFailureReason.staleTarget,
          ),
        ),
      );
      expect(
        (await disk.getAll()).containsKey('flutter.oc.sessionAgents.laptop'),
        isFalse,
      );
    },
  );
}
