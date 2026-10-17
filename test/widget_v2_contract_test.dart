import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/background/widget_snapshot.dart';
import 'package:opencode_mobile/background/widget_v2_contract.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Store extends ProfileStore {
  _Store(SharedPreferences prefs) : super(prefs: prefs);
  final saved = ServerProfile(
    id: 'p1',
    name: 'Example',
    baseUrl: 'http://localhost:4096',
  );
  @override
  List<ServerProfile> get profiles => [saved];
  @override
  String? get activeId => saved.id;
}

class _Gateway implements ServerGateway {
  _Gateway({this.steering = true});
  final bool steering;
  final calls = <String>[];
  PromptDelivery? delivery;
  bool fail = false;
  @override
  ServerCapabilities get capabilities =>
      ServerCapabilities(promptSteering: steering);
  @override
  Future<void> abort(String sessionID) async {
    calls.add('stop:$sessionID');
  }

  @override
  Future<void> promptAsync(
    String sessionID, {
    required String text,
    ModelRef? model,
    String? agent,
    String? variant,
    List<PromptAttachment> attachments = const [],
    List<PromptAgentMention> agentMentions = const [],
    PromptDelivery? delivery,
  }) async {
    calls.add('prompt:$sessionID');
    this.delivery = delivery;
    if (fail) throw StateError('secret remote payload');
  }

  @override
  Future<void> respondPermission(
    String requestID,
    String reply, {
    String? legacySessionID,
    String? legacyPermissionID,
    String? message,
  }) async {
    calls.add('permission:$requestID:$reply');
  }

  @override
  Future<void> close() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnknownGateway extends _Gateway implements MidTurnPromptGateway {
  _UnknownGateway() : super(steering: false);
  @override
  MidTurnPrompt? midTurnPrompt(String sessionID) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('oc/background'),
          (call) async =>
              call.method == 'clearWidgetProfile' ? {'cleared': true} : null,
        );
  });

  Future<
    ({
      ConnectionController controller,
      _Gateway gateway,
      SharedPreferences prefs,
    })
  >
  harness({bool steering = true, _Gateway? providedGateway}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = _Store(prefs);
    final gateway = providedGateway ?? _Gateway(steering: steering);
    final controller = ConnectionController(store)
      ..api = gateway
      ..status = StreamStatus.connected
      ..directory = '/private/project'
      ..sessionsById['s1'] = Session(id: 's1', title: 'Example');
    controller.adoptConnectedProfileForTesting(store.saved);
    controller.busySessions.add('s1');
    controller.notifyListeners();
    await Future<void>.delayed(Duration.zero);
    addTearDown(controller.dispose);
    return (controller: controller, gateway: gateway, prefs: prefs);
  }

  Map<String, dynamic> actionFor(
    SharedPreferences prefs,
    String kind, {
    String id = 'tap1',
  }) {
    final snapshot =
        jsonDecode(prefs.getString(WidgetSessionSnapshot.prefsKey)!) as Map;
    final row = (snapshot['sessions'] as List).first as Map;
    return {
      'id': id,
      'action': kind,
      'profileID': snapshot['profileID'],
      'scopeToken': snapshot['scopeToken'],
      'sessionID': row['id'],
      'expectedStartedAt': row['startedAt'],
      'text': 'Adjust the approach',
    };
  }

  test('malformed actions cannot enter background dispatch', () {
    expect(WidgetAction.fromPlatform({'id': 'tap', 'action': 'stop'}), isNull);
    expect(
      WidgetAction.fromPlatform({
        'id': 'tap',
        'action': 'delete',
        'profileID': 'p',
        'scopeToken': 's',
      }),
      isNull,
    );
  });
  test(
    'snapshot uses opaque project scope and bounded redacted titles',
    () async {
      final h = await harness();
      final value = h.prefs.getString(WidgetSessionSnapshot.prefsKey)!;
      expect(value, isNot(contains('/private/project')));
      final snapshot = jsonDecode(value) as Map;
      expect(snapshot['version'], 2);
      expect((snapshot['onDemand'] as Map).keys, ['fingerprint']);
      final target =
          jsonDecode(
                h.prefs.getString(
                  WidgetSessionSnapshot.targetKey(
                    snapshot['profileID'] as String,
                  ),
                )!,
              )
              as Map;
      expect(target['directory'], '/private/project');
      expect(target['scopeToken'], snapshot['scopeToken']);
      expect(
        safeWidgetTitle('password=synthetic-password\nTitle'),
        isNot(contains('synthetic-password')),
      );
      expect(safeWidgetTitle('a' * 200).length, 80);
    },
  );
  test('stale profile and scope never stop a conversation', () async {
    final h = await harness();
    final action = actionFor(h.prefs, 'stop')..['profileID'] = 'other';
    expect(
      (await h.controller.backgroundLive.handleNativeWidgetAction(
        action,
      ))['error'],
      'staleRequest',
    );
    expect(h.gateway.calls, isEmpty);
  });
  test('old run start never stops a replacement run', () async {
    final h = await harness();
    final action = actionFor(h.prefs, 'stop')..['expectedStartedAt'] = 1;
    expect(
      (await h.controller.backgroundLive.handleNativeWidgetAction(
        action,
      ))['error'],
      'staleRequest',
    );
    expect(h.gateway.calls, isEmpty);
  });
  test(
    'same action is dispatched once and its result is in snapshot',
    () async {
      final h = await harness();
      final action = actionFor(h.prefs, 'stop');
      expect(
        (await h.controller.backgroundLive.handleNativeWidgetAction(
          action,
        ))['status'],
        'accepted',
      );
      await h.controller.backgroundLive.handleNativeWidgetAction(action);
      expect(h.gateway.calls, ['stop:s1']);
      await Future<void>.delayed(Duration.zero);
      expect(
        jsonDecode(
          h.prefs.getString(WidgetSessionSnapshot.prefsKey)!,
        )['actionResult']['status'],
        'accepted',
      );
    },
  );
  test('supported steering selects steer delivery', () async {
    final h = await harness();
    final action = actionFor(h.prefs, 'steer');
    expect(
      (await h.controller.backgroundLive.handleNativeWidgetAction(
        action,
      ))['status'],
      'accepted',
    );
    expect(h.gateway.delivery, PromptDelivery.steer);
  });
  test(
    'OC1-style unsupported steering remains ordinary after-reply send',
    () async {
      final h = await harness(steering: false);
      expect(
        (await h.controller.backgroundLive.handleNativeWidgetAction(
          actionFor(h.prefs, 'steer'),
        ))['status'],
        'accepted',
      );
      expect(h.gateway.delivery, isNull);
    },
  );
  test(
    'uncertain send is not replayed and never exposes remote text',
    () async {
      final h = await harness();
      h.gateway.fail = true;
      final action = actionFor(h.prefs, 'steer');
      final result = await h.controller.backgroundLive.handleNativeWidgetAction(
        action,
      );
      expect(result['error'], 'uncertainDelivery');
      expect(jsonEncode(result), isNot(contains('secret remote payload')));
      await h.controller.backgroundLive.handleNativeWidgetAction(action);
      expect(h.gateway.calls, ['prompt:s1']);
    },
  );
  test('missing exact permission cannot approve another request', () async {
    final h = await harness();
    final action = actionFor(h.prefs, 'allowOnce')..['requestID'] = 'old';
    expect(
      (await h.controller.backgroundLive.handleNativeWidgetAction(
        action,
      ))['error'],
      'staleRequest',
    );
    expect(h.gateway.calls, isEmpty);
  });
  test('location switch revokes existing launcher actions', () async {
    final h = await harness();
    final action = actionFor(h.prefs, 'stop');
    h.controller.directory = '/different';
    expect(
      (await h.controller.backgroundLive.handleNativeWidgetAction(
        action,
      ))['error'],
      'staleRequest',
    );
    expect(h.gateway.calls, isEmpty);
  });
  test('needs-you and running rows survive the four-row cap', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final writer = WidgetSessionSnapshot(
      prefs: prefs,
      isAndroid: true,
      refreshNative: () async {},
    );
    await writer.update(
      sessions: [
        for (var i = 0; i < 6; i++) Session(id: 's$i', title: 'Session $i'),
      ],
      busySessions: {'s4'},
      connected: true,
      details: {
        's5': {'requestID': 'request'},
      },
    );
    final rows =
        jsonDecode(prefs.getString(WidgetSessionSnapshot.prefsKey)!)['sessions']
            as List;
    expect(rows.map((row) => row['id']).take(2), ['s5', 's4']);
  });

  test(
    'profile deletion drains queued widget writes before clearing',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final firstRefresh = Completer<void>();
      var refreshCount = 0;
      final writer = WidgetSessionSnapshot(
        prefs: prefs,
        isAndroid: true,
        refreshNative: () async {
          if (refreshCount++ == 0) await firstRefresh.future;
        },
      );
      final first = writer.update(
        sessions: [Session(id: 's1')],
        busySessions: {},
        connected: true,
        profileID: 'p',
      );
      final second = writer.update(
        sessions: [Session(id: 's2')],
        busySessions: {},
        connected: true,
        profileID: 'p',
      );
      final cleared = writer.clearForProfile('p');
      firstRefresh.complete();
      await Future.wait([first, second]);
      expect(await cleared, WidgetSnapshotClear.cleared);
      expect(prefs.getString(WidgetSessionSnapshot.prefsKey), isNull);
    },
  );
  test('unknown mixed-runtime behavior never sends a prompt', () async {
    final h = await harness(providedGateway: _UnknownGateway());
    expect(
      (await h.controller.backgroundLive.handleNativeWidgetAction(
        actionFor(h.prefs, 'steer'),
      ))['error'],
      'unsupported',
    );
    expect(h.gateway.calls, isEmpty);
  });
  test(
    'snapshot details cannot replace identity or introduce raw fields',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final writer = WidgetSessionSnapshot(
        prefs: prefs,
        isAndroid: true,
        refreshNative: () async {},
      );
      await writer.update(
        sessions: [Session(id: 'real', title: 'Safe')],
        busySessions: {},
        connected: true,
        details: {
          'real': {
            'id': 'foreign',
            'title': 'password=synthetic-password',
            'prompt': 'raw body',
            'step': 'token=synthetic-token',
            'todos': [
              {'title': 'password=synthetic-password', 'done': true},
            ],
          },
        },
      );
      final raw = prefs.getString(WidgetSessionSnapshot.prefsKey)!;
      final row = (jsonDecode(raw)['sessions'] as List).single;
      expect(row['id'], 'real');
      expect(row['title'], 'Safe');
      expect(raw, isNot(contains('raw body')));
      expect(raw, isNot(contains('synthetic-password')));
      expect(raw, isNot(contains('synthetic-token')));
    },
  );
  test(
    'native deletion refusal preserves snapshot and reports failure',
    () async {
      SharedPreferences.setMockInitialValues({
        WidgetSessionSnapshot.prefsKey: jsonEncode({
          'profileID': 'p',
          'sessions': [],
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('oc/background'),
            (call) async => {'cleared': false},
          );
      final writer = WidgetSessionSnapshot(
        prefs: prefs,
        isAndroid: true,
        refreshNative: () async {},
      );
      expect(await writer.clearForProfile('p'), WidgetSnapshotClear.failed);
      expect(prefs.getString(WidgetSessionSnapshot.prefsKey), isNotNull);
    },
  );
  test(
    'native profile style clear is called even without cached snapshot',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final clearedProfiles = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('oc/background'), (
            call,
          ) async {
            if (call.method == 'clearWidgetProfile') {
              clearedProfiles.add(
                (call.arguments as Map)['profileID'] as String,
              );
              return {'cleared': true};
            }
            return null;
          });
      final writer = WidgetSessionSnapshot(
        prefs: prefs,
        isAndroid: true,
        refreshNative: () async {},
      );
      expect(
        await writer.clearForProfile('p'),
        WidgetSnapshotClear.nothingToClear,
      );
      expect(clearedProfiles, ['p']);
    },
  );
  test('allow once confirms only the exact pending permission', () async {
    final h = await harness();
    h.controller.permissions['r1'] = PermissionRequest(
      id: 'r1',
      sessionID: 's1',
      permission: 'edit',
      patterns: const [],
    );
    final action = actionFor(h.prefs, 'allowOnce')..['requestID'] = 'r1';
    expect(
      (await h.controller.backgroundLive.handleNativeWidgetAction(
        action,
      ))['status'],
      'accepted',
    );
    expect(h.gateway.calls, ['permission:r1:once']);
    expect(h.controller.permissions.containsKey('r1'), isFalse);
  });
}
