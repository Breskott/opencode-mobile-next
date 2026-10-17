import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/background/widget_action_runner.dart';
import 'package:opencode_mobile/background/widget_snapshot.dart';
import 'package:opencode_mobile/background/widget_v2_contract.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/domain/team_project_gateway.dart';
import 'package:flutter/services.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Gateway implements ServerGateway {
  final mutations = <String>[];
  bool closed = false, fail = false;
  bool healthy = true;
  bool failHealth = false;
  int healthReads = 0, permissionReads = 0;
  Completer<void>? healthGate;
  void Function()? afterHealth;
  String marker = 'user-1', status = 'busy';
  List<PermissionRequest> pending = [
    PermissionRequest(
      id: 'permission',
      sessionID: 'session',
      permission: 'shell',
    ),
  ];
  Completer<void>? readGate;
  void Function()? afterRead;
  @override
  Future<Health> health() async {
    healthReads++;
    await healthGate?.future;
    afterHealth?.call();
    if (failHealth) throw StateError('private health failure');
    return Health(healthy: healthy);
  }

  @override
  Future<List<PermissionRequest>> pendingPermissions() async {
    permissionReads++;
    await readGate?.future;
    afterRead?.call();
    return pending;
  }

  @override
  Future<List<MessageWithParts>> messages(String id) async => [
    MessageWithParts(
      info: MessageInfo(id: marker, sessionID: id, role: 'user'),
    ),
  ];
  @override
  Future<Map<String, String>> sessionStatuses() async => {'session': status};
  @override
  Future<void> abort(String sessionID) async {
    mutations.add('stop:$sessionID');
  }

  @override
  Future<void> respondPermission(
    String requestID,
    String reply, {
    String? legacySessionID,
    String? legacyPermissionID,
    String? message,
  }) async {
    mutations.add('$requestID:$reply:$legacySessionID');
    if (fail) {
      throw StateError('credential or remote payload must never escape');
    }
  }

  @override
  void close() {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Team implements OrchestrationProjectGateway {
  TeamProject project = const TeamProject(
    id: 'team',
    revision: 7,
    status: 'paused',
    planApproved: true,
    simulated: false,
  );
  TeamCommandResult result = const TeamCommandResult(accepted: true);
  final commands = <TeamProjectCommand>[];
  bool closed = false;
  @override
  Future<TeamWorkspace> teamWorkspace() async =>
      TeamWorkspace(simulated: false, projects: [project]);
  @override
  Future<TeamCommandResult> executeProject(TeamProjectCommand command) async {
    commands.add(command);
    return result;
  }

  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final profile = ServerProfile(
    id: 'profile',
    name: 'Server',
    baseUrl: 'http://localhost:4096',
  );
  WidgetAction action([String kind = 'allowOnce']) => WidgetAction(
    id: 'tap',
    action: kind,
    profileID: 'profile',
    scopeToken: 'scope',
    sessionID: 'session',
    requestID: 'permission',
    expectedStartedAt: 1,
  );
  Map<String, dynamic> snapshot() => {
    'version': 2,
    'profileID': 'profile',
    'scopeToken': 'scope',
    'connected': false,
    'pendingCount': 1,
    'runningCount': 1,
    'onDemand': {'fingerprint': widgetProfileFingerprint(profile)},
    'sessions': [
      {
        'id': 'session',
        'busy': true,
        'startedAt': 1,
        'requestID': 'permission',
        'runMarker': 'user-1',
        'onDemandActions': ['allowOnce', 'reject', 'stop'],
      },
    ],
  };
  Map<String, dynamic> privateTarget() => {
    'profileID': profile.id,
    'scopeToken': 'scope',
    'fingerprint': widgetProfileFingerprint(profile),
    'directory': '/private/project',
    'workspace': 'private-workspace',
  };
  WidgetActionRunner runner(
    _Gateway gateway, {
    Future<bool> Function(WidgetAction, String)? current,
    DateTime Function()? now,
    Future<ServerProfile?> Function(String)? load,
  }) => WidgetActionRunner(
    loadProfile: load ?? (_) async => profile,
    loadTarget: (_, _) async => privateTarget(),
    isCurrent: current ?? (_, _) async => true,
    now: now,
    createTransport: (_, _, _) => WidgetActionTransport(gateway: gateway),
  );
  int deadline() =>
      DateTime.now().add(const Duration(seconds: 30)).millisecondsSinceEpoch;

  for (final kind in ['allowOnce', 'reject']) {
    test(
      '$kind cold tap confirms exact pending request and closes transport',
      () async {
        final gateway = _Gateway();
        final result = await runner(
          gateway,
        ).execute(action(kind), snapshot(), deadline());
        expect(result['status'], 'accepted');
        expect(gateway.mutations, [
          'permission:${kind == 'allowOnce' ? 'once' : 'reject'}:session',
        ]);
        expect(gateway.closed, isTrue);
        final updated = result['snapshot'] as Map;
        expect(
          (updated['sessions'] as List).single.containsKey('requestID'),
          isFalse,
        );
        expect(updated['scopeToken'], 'scope');
      },
    );
  }
  test('cold approval waits for health before reading or answering', () async {
    final gateway = _Gateway()..healthGate = Completer<void>();
    final result = runner(gateway).execute(action(), snapshot(), deadline());
    await Future<void>.delayed(Duration.zero);
    expect(gateway.healthReads, 1);
    expect(gateway.permissionReads, 0);
    expect(gateway.mutations, isEmpty);
    gateway.healthGate!.complete();
    expect((await result)['status'], 'accepted');
    expect(gateway.permissionReads, 1);
    expect(gateway.mutations, ['permission:once:session']);
    expect(gateway.closed, isTrue);
  });
  test('unhealthy cold transport never reads or answers permissions', () async {
    final gateway = _Gateway()..healthy = false;
    final result = await runner(
      gateway,
    ).execute(action(), snapshot(), deadline());
    expect(result['status'], 'rejected');
    expect(result['error'], 'unavailable');
    expect(gateway.permissionReads, 0);
    expect(gateway.mutations, isEmpty);
    expect(gateway.closed, isTrue);
  });
  test('failed health is sanitized and never answers permissions', () async {
    final gateway = _Gateway()..failHealth = true;
    final result = await runner(
      gateway,
    ).execute(action(), snapshot(), deadline());
    expect(result['status'], 'rejected');
    expect(result['error'], 'unavailable');
    expect(jsonEncode(result), isNot(contains('private health failure')));
    expect(gateway.permissionReads, 0);
    expect(gateway.mutations, isEmpty);
    expect(gateway.closed, isTrue);
  });
  test(
    'cancel during cold health closes without answering permissions',
    () async {
      final gateway = _Gateway()..healthGate = Completer<void>();
      final instance = runner(gateway);
      final result = instance.execute(action(), snapshot(), deadline());
      await Future<void>.delayed(Duration.zero);
      expect(gateway.healthReads, 1);
      instance.cancel();
      gateway.healthGate!.complete();
      expect((await result)['status'], 'rejected');
      expect(gateway.permissionReads, 0);
      expect(gateway.mutations, isEmpty);
      expect(gateway.closed, isTrue);
    },
  );
  test(
    'deadline during cold health never reads or answers permissions',
    () async {
      final gateway = _Gateway();
      var clock = DateTime.fromMillisecondsSinceEpoch(100);
      gateway.afterHealth = () =>
          clock = DateTime.fromMillisecondsSinceEpoch(201);
      final result = await runner(
        gateway,
        now: () => clock,
      ).execute(action(), snapshot(), 200);
      expect(result['status'], 'rejected');
      expect(result['error'], 'unavailable');
      expect(gateway.permissionReads, 0);
      expect(gateway.mutations, isEmpty);
      expect(gateway.closed, isTrue);
    },
  );
  test(
    'profile switch during cold health prevents permission dispatch',
    () async {
      final gateway = _Gateway();
      var current = true;
      gateway.afterHealth = () => current = false;
      final result = await runner(
        gateway,
        current: (_, _) async => current,
      ).execute(action(), snapshot(), deadline());
      expect(result['error'], 'staleRequest');
      expect(gateway.permissionReads, 0);
      expect(gateway.mutations, isEmpty);
      expect(gateway.closed, isTrue);
    },
  );
  test(
    'cold dispatch uses private target without exposing it in its result',
    () async {
      final gateway = _Gateway();
      Map<String, dynamic>? routed;
      final run = WidgetActionRunner(
        loadProfile: (_) async => profile,
        loadTarget: (_, _) async => privateTarget(),
        isCurrent: (_, _) async => true,
        createTransport: (_, target, _) {
          routed = target;
          return WidgetActionTransport(gateway: gateway);
        },
      );
      final result = await run.execute(action(), snapshot(), deadline());
      expect(result['status'], 'accepted');
      expect(routed?['directory'], '/private/project');
      expect(routed?['workspace'], 'private-workspace');
      expect(jsonEncode(result), isNot(contains('/private/project')));
      expect(jsonEncode(result), isNot(contains('private-workspace')));
    },
  );
  test(
    'missing or stale private target never constructs a transport',
    () async {
      for (final target in [
        null,
        {...privateTarget(), 'scopeToken': 'old'},
      ]) {
        final gateway = _Gateway();
        final run = WidgetActionRunner(
          loadProfile: (_) async => profile,
          loadTarget: (_, _) async => target,
          isCurrent: (_, _) async => true,
          createTransport: (_, _, _) => throw StateError('must not connect'),
        );
        final result = await run.execute(action(), snapshot(), deadline());
        expect(result['error'], 'staleRequest');
        expect(gateway.mutations, isEmpty);
      }
    },
  );
  test(
    'private target reader rejects mismatched identity and deleted target',
    () async {
      SharedPreferences.setMockInitialValues({
        WidgetSessionSnapshot.targetKey(profile.id): jsonEncode(
          privateTarget(),
        ),
      });
      final prefs = await SharedPreferences.getInstance();
      final fingerprint = widgetProfileFingerprint(profile);
      expect(
        readWidgetActionTarget(prefs, action(), fingerprint)?['directory'],
        '/private/project',
      );
      expect(readWidgetActionTarget(prefs, action(), 'changed'), isNull);
      await prefs.setString(
        WidgetSessionSnapshot.targetKey(profile.id),
        jsonEncode({...privateTarget(), 'scopeToken': 'changed'}),
      );
      expect(readWidgetActionTarget(prefs, action(), fingerprint), isNull);
      await prefs.remove(WidgetSessionSnapshot.targetKey(profile.id));
      expect(readWidgetActionTarget(prefs, action(), fingerprint), isNull);
    },
  );
  test('duplicate tap is dispatched once', () async {
    final gateway = _Gateway();
    final instance = runner(gateway);
    final first = instance.execute(action(), snapshot(), deadline());
    final second = instance.execute(action(), snapshot(), deadline());
    expect(identical(first, second), isTrue);
    await Future.wait([first, second]);
    expect(gateway.mutations, hasLength(1));
  });
  test('expired tap never constructs or dispatches transport', () async {
    final gateway = _Gateway();
    final result = await runner(gateway).execute(action(), snapshot(), 0);
    expect(result['status'], 'rejected');
    expect(gateway.mutations, isEmpty);
  });
  test(
    'deadline reached during pending read never dispatches afterwards',
    () async {
      final gateway = _Gateway();
      var clock = DateTime.fromMillisecondsSinceEpoch(100);
      gateway.afterRead = () =>
          clock = DateTime.fromMillisecondsSinceEpoch(201);
      final result = await runner(
        gateway,
        now: () => clock,
      ).execute(action(), snapshot(), 200);
      expect(result['status'], 'rejected');
      expect(gateway.mutations, isEmpty);
      expect(gateway.closed, isTrue);
    },
  );
  test(
    'cancel while read is in flight prevents late dispatch and closes',
    () async {
      final gateway = _Gateway()..readGate = Completer<void>();
      final instance = runner(gateway);
      final result = instance.execute(action(), snapshot(), deadline());
      await Future<void>.delayed(Duration.zero);
      instance.cancel();
      gateway.readGate!.complete();
      expect((await result)['status'], 'rejected');
      expect(gateway.mutations, isEmpty);
      expect(gateway.closed, isTrue);
    },
  );
  test('profile deletion during read prevents mutation', () async {
    final gateway = _Gateway();
    var current = true;
    gateway.afterRead = () => current = false;
    final result = await runner(
      gateway,
      current: (_, _) async => current,
    ).execute(action(), snapshot(), deadline());
    expect(result['error'], 'staleRequest');
    expect(gateway.mutations, isEmpty);
  });
  test('different pending request owner is never answered', () async {
    final gateway = _Gateway()
      ..pending = [
        PermissionRequest(
          id: 'permission',
          sessionID: 'another-session',
          permission: 'shell',
        ),
      ];
    final result = await runner(
      gateway,
    ).execute(action(), snapshot(), deadline());
    expect(result['error'], 'staleRequest');
    expect(gateway.mutations, isEmpty);
  });
  test('stop checks server user-message identity and busy status', () async {
    final gateway = _Gateway();
    final result = await runner(
      gateway,
    ).execute(action('stop'), snapshot(), deadline());
    expect(result['status'], 'accepted');
    expect(gateway.mutations, ['stop:session']);
    expect(
      ((result['snapshot'] as Map)['sessions'] as List).single['busy'],
      false,
    );
  });
  test('old run cannot stop a replacement run', () async {
    final gateway = _Gateway()..marker = 'replacement-user-message';
    final result = await runner(
      gateway,
    ).execute(action('stop'), snapshot(), deadline());
    expect(result['error'], 'staleRequest');
    expect(gateway.mutations, isEmpty);
  });
  test('idle run cannot be stopped', () async {
    final gateway = _Gateway()..status = 'idle';
    final result = await runner(
      gateway,
    ).execute(action('stop'), snapshot(), deadline());
    expect(result['error'], 'staleRequest');
    expect(gateway.mutations, isEmpty);
  });
  test(
    'mutation error is uncertain, sanitized, closed, and never retried',
    () async {
      final gateway = _Gateway()..fail = true;
      final instance = runner(gateway);
      final result = await instance.execute(action(), snapshot(), deadline());
      expect(result['status'], 'uncertain');
      expect(result['error'], 'uncertainDelivery');
      expect(jsonEncode(result), isNot(contains('credential')));
      await instance.execute(action(), snapshot(), deadline());
      expect(gateway.mutations, hasLength(1));
      expect(gateway.closed, isTrue);
    },
  );
  test(
    'unsupported row action is rejected before opening connection',
    () async {
      final gateway = _Gateway();
      final result = await runner(
        gateway,
      ).execute(action('voice'), snapshot(), deadline());
      expect(result['error'], 'unsupported');
      expect(gateway.closed, isFalse);
      expect(gateway.mutations, isEmpty);
    },
  );
  test(
    'durable ownership guard respects profile switch and deletion without opt-in writes',
    () async {
      SharedPreferences.setMockInitialValues({
        'oc.profiles': jsonEncode([profile.toJson()]),
        'oc.activeProfile': profile.id,
        'oc.widgetSessions': jsonEncode(snapshot()),
        WidgetSessionSnapshot.targetKey(profile.id): jsonEncode(
          privateTarget(),
        ),
        'oc.backgroundLive': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final before = {for (final key in prefs.getKeys()) key: prefs.get(key)};
      expect(
        await widgetActionIsCurrent(
          prefs,
          action(),
          widgetProfileFingerprint(profile),
        ),
        true,
      );
      expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, before);
      await prefs.setString('oc.activeProfile', 'other');
      expect(
        await widgetActionIsCurrent(
          prefs,
          action(),
          widgetProfileFingerprint(profile),
        ),
        false,
      );
      await prefs.setString('oc.activeProfile', profile.id);
      await prefs.setString('oc.profiles', '[]');
      expect(
        await widgetActionIsCurrent(
          prefs,
          action(),
          widgetProfileFingerprint(profile),
        ),
        false,
      );
      expect(prefs.getBool('oc.backgroundLive'), false);
    },
  );
  test(
    'suspension preserves target proofs and does not resurrect deletion',
    () async {
      SharedPreferences.setMockInitialValues({
        'oc.widgetSessions': jsonEncode(snapshot()),
        WidgetSessionSnapshot.targetKey(profile.id): jsonEncode(
          privateTarget(),
        ),
      });
      final prefs = await SharedPreferences.getInstance();
      final writer = WidgetSessionSnapshot(
        prefs: prefs,
        isAndroid: true,
        refreshNative: () async {},
      );
      await writer.update(
        sessions: const [],
        busySessions: const {},
        connected: false,
        profileID: 'profile',
        scopeToken: 'changed',
        preserveForOnDemand: true,
      );
      var stored = jsonDecode(prefs.getString('oc.widgetSessions')!) as Map;
      expect(stored['scopeToken'], 'scope');
      expect((stored['sessions'] as List).single['runMarker'], 'user-1');
      await prefs.remove('oc.widgetSessions');
      await writer.update(
        sessions: const [],
        busySessions: const {},
        connected: false,
        profileID: 'profile',
        preserveForOnDemand: true,
      );
      expect(prefs.containsKey('oc.widgetSessions'), false);
    },
  );
  for (final kind in ['resume', 'approvePlan']) {
    test('cold Team $kind uses reviewed revision and closes', () async {
      final team = _Team();
      if (kind == 'approvePlan') {
        team.project = const TeamProject(
          id: 'team',
          revision: 7,
          status: 'plan',
          tasks: [TeamTask()],
          specVersions: [TeamSpec()],
          simulated: false,
        );
      }
      final run = WidgetActionRunner(
        loadProfile: (_) async => profile,
        loadTarget: (_, _) async => privateTarget(),
        isCurrent: (_, _) async => true,
        createTransport: (_, _, _) => WidgetActionTransport(team: team),
      );
      final snap = snapshot()
        ..['sessions'] = [
          {
            'id': 'team:team',
            'onDemandActions': [kind],
            'team': {
              'runID': 'team',
              'gateID': 'gate',
              'revision': 7,
              'action': kind,
            },
          },
        ];
      final result = await run.execute(
        WidgetAction(
          id: 'tap',
          action: kind,
          profileID: 'profile',
          scopeToken: 'scope',
          runID: 'team',
          gateID: 'gate',
        ),
        snap,
        deadline(),
      );
      expect(result['status'], 'accepted');
      expect(team.commands.single.expectedRevision, 7);
      expect(team.commands.single.requestId, 'tap');
      expect(team.closed, true);
      expect(
        (((result['snapshot'] as Map)['sessions'] as List).single['team']
                as Map)
            .containsKey('action'),
        false,
      );
    });
  }
  test(
    'Team transport uncertainty cannot become retryable rejection',
    () async {
      final team = _Team()
        ..result = const TeamCommandResult(
          accepted: false,
          code: 'transportUncertain',
        );
      final run = WidgetActionRunner(
        loadProfile: (_) async => profile,
        loadTarget: (_, _) async => privateTarget(),
        isCurrent: (_, _) async => true,
        createTransport: (_, _, _) => WidgetActionTransport(team: team),
      );
      final snap = snapshot()
        ..['sessions'] = [
          {
            'id': 'team:team',
            'onDemandActions': ['resume'],
            'team': {
              'runID': 'team',
              'gateID': 'gate',
              'revision': 7,
              'action': 'resume',
            },
          },
        ];
      final result = await run.execute(
        const WidgetAction(
          id: 'tap',
          action: 'resume',
          profileID: 'profile',
          scopeToken: 'scope',
          runID: 'team',
          gateID: 'gate',
        ),
        snap,
        deadline(),
      );
      expect(result['status'], 'uncertain');
      expect(team.commands, hasLength(1));
    },
  );
  test('same-scope durable replacement during read blocks old stop', () async {
    final original = snapshot();
    SharedPreferences.setMockInitialValues({
      'oc.profiles': jsonEncode([profile.toJson()]),
      'oc.activeProfile': profile.id,
      'oc.widgetSessions': jsonEncode(original),
      WidgetSessionSnapshot.targetKey(profile.id): jsonEncode(privateTarget()),
    });
    final prefs = await SharedPreferences.getInstance();
    final updated = snapshot();
    (updated['sessions'] as List).single['runMarker'] = 'replacement';
    await prefs.setString('oc.widgetSessions', jsonEncode(updated));
    expect(
      await widgetActionIsCurrent(
        prefs,
        action('stop'),
        widgetProfileFingerprint(profile),
        expectedSnapshot: original,
      ),
      false,
    );
    (updated['sessions'] as List).single['requestID'] = 'new-request';
    await prefs.setString('oc.widgetSessions', jsonEncode(updated));
    expect(
      await widgetActionIsCurrent(
        prefs,
        action(),
        widgetProfileFingerprint(profile),
        expectedSnapshot: original,
      ),
      false,
    );
  });
  test(
    'target-only load reads target secrets without migrations or writes',
    () async {
      SharedPreferences.setMockInitialValues({
        'oc.profiles': jsonEncode([
          profile.toJson(),
          ServerProfile(
            id: 'other',
            name: 'Other',
            baseUrl: 'http://localhost:1',
          ).toJson(),
        ]),
        'oc.activeProfile': profile.id,
        'oc.keepLiveInBackground': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final before = {for (final key in prefs.getKeys()) key: prefs.get(key)};
      final reads = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (call) async {
              reads.add((call.arguments as Map)['key'] as String);
              return 'private';
            },
          );
      final loaded = await ProfileStore(
        prefs: prefs,
      ).loadForWidgetAction('profile');
      expect(loaded?.password, 'private');
      expect(reads, ['oc.teamEngineAuth.profile', 'pw.profile']);
      expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, before);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            null,
          );
    },
  );
}
