import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/domain/phone_project_engine.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/state/automatic_activity.dart';
import 'package:opencode_mobile/state/automation_policy.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/orchestration/adapters/inapp/phone_engine_gateway.dart';

import 'phone_project_engine_controller_test.dart' show NativeBridge;
import 'phone_project_engine_gateway_test.dart' as engine;
import 'support/stash_memory_vault.dart';

class _StatusApi extends OpenCodeApi {
  _StatusApi() : super(baseUrl: 'http://127.0.0.1:4097');
  final healthGate = Completer<Health>();
  Map<String, String> statuses = {};
  bool failStatus = false;
  Completer<Map<String, String>>? statusGate;
  int statusReads = 0;
  Completer<List<Session>>? sessionGate;
  @override
  Future<Health> health() => healthGate.future;
  @override
  Future<Map<String, String>> sessionStatuses() async {
    statusReads++;
    if (failStatus) throw ApiException('Status is unavailable');
    return statusGate == null ? Map.of(statuses) : statusGate!.future;
  }

  @override
  Future<List<Session>> sessions() async =>
      sessionGate == null ? [] : sessionGate!.future;

  @override
  Future<Session> session(String id) async =>
      Session(id: id, directory: directory);
}

class _ChatGateway extends PhoneEngineGateway {
  _ChatGateway({
    required super.baseUrl,
    required super.profileId,
    required super.bearerToken,
    required this.heartbeats,
  }) : super(
         health: PhoneEngineHealth.fromJson(
           engine.health(profileId),
           profileId,
         ),
       );

  final List<Map<String, dynamic>> heartbeats;

  @override
  Future<PhoneEngineHealth> probe() async => health!;

  @override
  Future<TeamWorkspace> teamWorkspace() async =>
      TeamWorkspace.fromJson(engine.workspace());

  @override
  Future<List<ActivityEvent>> activity({
    int? afterSeq,
    int limit = 100,
  }) async => [];

  @override
  Future<void> sendChatBusy({
    required int until,
    required List<String> sessionIds,
    required List<String> directories,
    required bool known,
    required String appInstance,
    required int sequence,
  }) async {
    // This suite tests admission observation/tracking, not HTTP decoding.
    // The gateway's actual request contract has its own focused test file.
    heartbeats.add({
      'until': until,
      'sessionIds': List<String>.of(sessionIds),
      'directories': List<String>.of(directories),
      'known': known,
      'appInstance': appInstance,
      'sequence': sequence,
    });
  }
}

class _Phone {
  _Phone(this.tester, this.connection, this.api, this.connect, this.heartbeats);
  final WidgetTester tester;
  final ConnectionController connection;
  final _StatusApi api;
  final Future<void> connect;
  final List<Map<String, dynamic>> heartbeats;
  Future<void> settle(Future<void> future) async {
    var done = false;
    Object? error;
    StackTrace? stack;
    unawaited(
      future.then<void>(
        (_) {
          done = true;
        },
        onError: (Object caught, StackTrace trace) {
          error = caught;
          stack = trace;
          done = true;
        },
      ),
    );
    for (var i = 0; i < 100 && !done; i++) {
      await tester.pump();
    }
    if (!done) {
      throw StateError('The fake-clock async operation did not drain');
    }
    if (error != null) {
      Error.throwWithStackTrace(error!, stack!);
    }
  }

  Future<Map<String, dynamic>> heartbeat() async {
    // Heartbeat tail callbacks are created under the fake clock. Pump their
    // actual queue instead of waiting for them from a different runAsync zone.
    await settle(
      connection.phoneProjectEngine.pushChatHeartbeat('phone', force: true),
    );
    return heartbeats.last;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final secrets = <String, String>{};
  setUp(() {
    addTearDown(AutomaticActivityController.resetShared);
    addTearDown(AutomationPolicyController.resetShared);
    secrets.clear();
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = call.arguments as Map? ?? {};
        final key = args['key'] as String?;
        switch (call.method) {
          case 'read':
            return secrets[key];
          case 'readAll':
            return Map<String, String>.of(secrets);
          case 'write':
            secrets[key!] = args['value'] as String;
            return null;
          case 'delete':
            secrets.remove(key);
            return null;
          case 'containsKey':
            return secrets.containsKey(key);
        }
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('oc/background'),
      (_) async => null,
    );
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('oc/background'),
      null,
    );
  });

  Future<_Phone> boot(WidgetTester tester) async {
    final profile = ServerProfile(
      id: 'phone',
      name: 'Phone',
      baseUrl: 'http://127.0.0.1:4097',
      teamEngineAuth: 'engine-private-token',
      orchestration: const OrchestrationConfig(
        provider: OrchestrationProvider.phoneEngine,
        url: 'http://127.0.0.1:42761',
      ),
    );
    final store = (await tester.runAsync(() async {
      final store = ProfileStore(prefs: await SharedPreferences.getInstance());
      await store.upsert(profile);
      return store;
    }))!;
    final api = _StatusApi();
    final beats = <Map<String, dynamic>>[];
    final connection = ConnectionController(
      store,
      apiFactory: (_) => api,
      phoneEngineBridge: NativeBridge(),
      phoneEngineGatewayBuilder:
          ({required baseUrl, required profileId, required bearerToken}) =>
              _ChatGateway(
                baseUrl: baseUrl,
                profileId: profileId,
                bearerToken: bearerToken,
                heartbeats: beats,
              ),
      localWakeLockEnsurer: () async {},
      draftAttachmentVault: StashMemoryVault(),
      stashAttachmentVault: StashMemoryVault(),
    );
    // Use the real transport factory and its before-dispatch fence, while
    // holding health so unrelated catalog/session loading never runs.
    final connecting = connection.connect(profile, redetectOnFailure: false);
    await tester.pump();
    connection.directory = '/root/projects/person';
    api.setLocation(directory: connection.directory);
    connection.status = StreamStatus.connected;
    final phone = _Phone(tester, connection, api, connecting, beats);
    await phone.heartbeat();
    addTearDown(() async {
      // Dispose first in the fake-clock zone so all periodic timers stop.
      connection.dispose();
      if (!api.healthGate.isCompleted) {
        api.healthGate.complete(Health(healthy: true, version: '1.18.32'));
      }
      await phone.settle(connecting);
      await phone.settle(connection.phoneProjectEngine.close());
    });
    return phone;
  }

  testWidgets('idle UNKNOWN recovers on the managed phone polling lane', (
    tester,
  ) async {
    final phone = await boot(tester);
    expect((await phone.heartbeat())['known'], isFalse);
    expect(phone.connection.busySessions, isEmpty);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(phone.api.statusReads, 1);
    expect((await phone.heartbeat())['known'], isTrue);
    expect(phone.heartbeats.last['sessionIds'], isEmpty);
    phone.api.failStatus = true;
    await phone.connection.reconcileBusySessionsForTesting();
    expect((await phone.heartbeat())['known'], isFalse);
    phone.api.failStatus = false;
    await phone.connection.reconcileBusySessionsForTesting();
    expect((await phone.heartbeat())['known'], isTrue);
  });

  testWidgets(
    'fresh busy and retry IDs without metadata block idle admission',
    (tester) async {
      final phone = await boot(tester);
      phone.api.statuses = {
        'ses_unknown_person': 'busy',
        'ses_unknown_retry': 'retry',
      };
      await phone.connection.reconcileBusySessionsForTesting();
      final beat = await phone.heartbeat();
      expect(beat['known'], isTrue);
      expect(
        beat['sessionIds'],
        containsAll(['ses_unknown_person', 'ses_unknown_retry']),
      );
      expect(phone.connection.sessionsById, isEmpty);
      expect(
        phone.connection.busySessions,
        containsAll(['ses_unknown_person', 'ses_unknown_retry']),
      );
    },
  );

  testWidgets(
    'unknown phone status is refreshed even while session page loading is pending',
    (tester) async {
      final phone = await boot(tester);
      phone.connection.sessionsLoading = true;
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(phone.api.statusReads, 1);
      expect((await phone.heartbeat())['known'], isTrue);
      phone.connection.sessionsLoading = false;
    },
  );

  testWidgets(
    'directory and transport scope changes reject late status reads',
    (tester) async {
      final phone = await boot(tester);
      final gate = phone.api.statusGate = Completer<Map<String, String>>();
      final reading = phone.connection.reconcileBusySessionsForTesting();
      phone.connection.directory = '/root/projects/other';
      phone.api.setLocation(directory: phone.connection.directory);
      gate.complete({'ses_old_directory': 'busy'});
      await reading;
      expect(phone.connection.busySessions, isEmpty);
      expect((await phone.heartbeat())['known'], isFalse);
      phone.api.statusGate = null;
      await phone.connection.reconcileBusySessionsForTesting();
      expect((await phone.heartbeat())['known'], isTrue);
      final old = phone.api.statusGate = Completer<Map<String, String>>();
      final retired = phone.connection.reconcileBusySessionsForTesting();
      phone.connection.suspendForLifecycle();
      old.complete({'ses_old_generation': 'busy'});
      await retired;
      expect(phone.connection.busySessions, isEmpty);
      expect((await phone.heartbeat())['known'], isFalse);
    },
  );

  testWidgets('a delayed session page cannot overwrite a newer busy poll', (
    tester,
  ) async {
    final phone = await boot(tester);
    final page = phone.api.sessionGate = Completer<List<Session>>();
    final refresh = phone.connection.refreshSessions();
    await tester.pump();
    phone.api.statuses = {'ses_new_person': 'busy'};
    await phone.connection.reconcileBusySessionsForTesting();
    page.complete([]);
    await refresh;
    expect((await phone.heartbeat())['known'], isTrue);
    expect(phone.heartbeats.last['sessionIds'], contains('ses_new_person'));
  });

  testWidgets('newer SSE UNKNOWN fences a pending idle snapshot', (
    tester,
  ) async {
    final phone = await boot(tester);
    final gate = phone.api.statusGate = Completer<Map<String, String>>();
    final reading = phone.connection.reconcileBusySessionsForTesting();
    phone.connection.handleEventForTesting(
      EventEnvelope(
        type: 'session.status',
        properties: {
          'sessionID': 'ses_unknown_person',
          'status': {'type': 'unrecognized'},
        },
      ),
    );
    gate.complete({});
    await reading;
    expect((await phone.heartbeat())['known'], isFalse);
  });

  testWidgets('newer busy SSE evidence wins over an older idle snapshot', (
    tester,
  ) async {
    final phone = await boot(tester);
    final gate = phone.api.statusGate = Completer<Map<String, String>>();
    final reading = phone.connection.reconcileBusySessionsForTesting();
    phone.connection.handleEventForTesting(
      EventEnvelope(
        type: 'session.status',
        properties: {
          'sessionID': 'ses_live_person',
          'status': {'type': 'busy'},
        },
      ),
    );
    gate.complete({});
    await reading;
    expect(
      (await phone.heartbeat())['sessionIds'],
      contains('ses_live_person'),
    );
  });

  testWidgets('status timeout and malformed snapshots remain UNKNOWN', (
    tester,
  ) async {
    final phone = await boot(tester);
    final gate = phone.api.statusGate = Completer<Map<String, String>>();
    final reading = phone.connection.reconcileBusySessionsForTesting();
    await tester.pump(const Duration(seconds: 4));
    await reading;
    expect((await phone.heartbeat())['known'], isFalse);
    gate.complete({});
    phone.api.statusGate = null;
    phone.api.statuses = {'ses_bad': 'unrecognized'};
    await phone.connection.reconcileBusySessionsForTesting();
    expect((await phone.heartbeat())['known'], isFalse);
    phone.api.statuses = {};
    await phone.connection.reconcileBusySessionsForTesting();
    expect((await phone.heartbeat())['known'], isTrue);
  });

  testWidgets(
    'pending real chat dispatch keeps fresh busy heartbeats during polling',
    (tester) async {
      final phone = await boot(tester);
      await phone.connection.reconcileBusySessionsForTesting();
      final onWire = Completer<void>();
      final release = Completer<void>();
      phone.api.dio.httpClientAdapter = engine.FakeEngineAdapter((
        request,
      ) async {
        onWire.complete();
        await release.future;
        return engine.jsonBody(null, 204);
      });
      await phone.heartbeat();
      final prompt = phone.api.promptAsync(
        'ses_human',
        text: 'Help with this project',
      );
      await phone.settle(onWire.future);
      await phone.connection.reconcileBusySessionsForTesting();
      final before = await phone.heartbeat();
      expect(before['known'], isTrue);
      expect(before['sessionIds'], contains('ses_human'));
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      final renewed = await phone.heartbeat();
      expect(renewed['known'], isTrue);
      expect(renewed['sessionIds'], contains('ses_human'));
      expect(
        renewed['sequence'] as int,
        greaterThan(before['sequence'] as int),
      );
      release.complete();
      await phone.settle(prompt);
    },
  );
}
