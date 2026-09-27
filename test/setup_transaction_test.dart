import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/setup_assistant.dart';
import 'package:opencode_mobile/state/setup_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

Map<String, Object?> _copy(Map<String, Object?> value) =>
    (jsonDecode(jsonEncode(value)) as Map).cast<String, Object?>();

class _AtomicHost implements SetupTransactionalConfigGateway {
  Map<String, Object?> config = {
    'model': 'example/old',
    'mcp': <String, Object?>{},
    'unchanged': {'nullable': null},
  };
  int version = 0, reads = 0, writes = 0, restores = 0;
  String target = 'opaque-target';
  bool loseResponse = false, badReceipt = false, badReadback = false;
  void Function()? beforeCommit;
  Future<void> Function(int)? duringRead;
  Future<void> Function()? afterCommit;
  final originals = <String, SetupConfigRevision>{};
  List<SetupEdit> sent = const [];

  SetupConfigRevision get current => SetupConfigRevision(
    targetId: target,
    revision: '$version',
    config: config,
  );
  @override
  SetupSupport get support =>
      const SetupSupport(readConfig: true, writeConfig: true);
  @override
  Future<Map<String, Object?>> readConfig() async => _copy(config);
  @override
  Future<List<SetupMcpStatus>> listMcpServers() async => [];
  @override
  Future<void> patchConfig(Map<String, Object?> patch) async =>
      throw StateError('Legacy PATCH must never be called');
  @override
  Future<SetupConfigRevision> readSnapshot() async {
    reads++;
    await duringRead?.call(reads);
    if (badReadback && writes > 0) {
      version++;
    }
    return current;
  }

  @override
  Future<SetupConfigCommit> commit({
    required SetupConfigRevision expected,
    required List<SetupEdit> edits,
    required String operationId,
  }) async {
    beforeCommit?.call();
    if (expected.targetId != target || expected.revision != '$version') {
      throw const SetupFailure(
        SetupFailureCode.conflict,
        'Configuration changed.',
      );
    }
    final before = current;
    sent = edits;
    for (final edit in edits) {
      var at = config;
      for (final key in edit.path.take(edit.path.length - 1)) {
        at.putIfAbsent(key, () => <String, Object?>{});
        at = at[key] as Map<String, Object?>;
      }
      if (edit.remove) {
        at.remove(edit.path.last);
      } else {
        at[edit.path.last] = jsonDecode(jsonEncode(edit.value));
      }
    }
    version++;
    writes++;
    originals[operationId] = before;
    await afterCommit?.call();
    if (loseResponse) {
      throw StateError('Response lost');
    }
    return SetupConfigCommit(
      before: before,
      after: badReceipt
          ? SetupConfigRevision(
              targetId: 'wrong',
              revision: '$version',
              config: config,
            )
          : current,
      undoHandle: operationId,
    );
  }

  @override
  Future<SetupConfigCommit> restore({
    required SetupConfigCommit commit,
    required String operationId,
  }) async {
    if (commit.after.targetId != target ||
        commit.after.revision != '$version') {
      throw const SetupFailure(
        SetupFailureCode.conflict,
        'Configuration changed.',
      );
    }
    final before = current;
    config = _copy(originals[commit.undoHandle]!.config);
    version++;
    restores++;
    return SetupConfigCommit(
      before: before,
      after: current,
      undoHandle: operationId,
    );
  }
}

class _LegacyHost implements SetupConfigGateway {
  int writes = 0;
  @override
  SetupSupport get support =>
      const SetupSupport(readConfig: true, writeConfig: true);
  @override
  Future<Map<String, Object?>> readConfig() async => {'model': 'example/old'};
  @override
  Future<List<SetupMcpStatus>> listMcpServers() async => [];
  @override
  Future<void> patchConfig(Map<String, Object?> patch) async {
    writes++;
  }
}

class _RefuseAuditAction extends InMemorySharedPreferencesStore {
  _RefuseAuditAction(super.data, this.action) : super.withData();
  final String action;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key == 'flutter.oc.setupAudit.profile' && value is String) {
      final records = jsonDecode(value) as List;
      if (records.isNotEmpty && (records.last as Map)['action'] == action) {
        return false;
      }
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late _AtomicHost host;
  late SetupController controller;
  var current = true;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'oc.profiles': jsonEncode([
        {'id': 'profile'},
      ]),
    });
    prefs = await SharedPreferences.getInstance();
    host = _AtomicHost();
    current = true;
    controller = SetupController(
      gateway: host,
      prefs: prefs,
      profileId: 'profile',
      locationId: '/repo',
      isCurrent: () => current,
    );
  });
  tearDown(() => controller.dispose());
  const model = SetupEdit(path: ['model'], value: 'example/new');
  Future<SetupProposal> prepare([List<SetupEdit> edits = const [model]]) async {
    await controller.refresh();
    return controller.propose(edits);
  }

  Matcher failure(SetupFailureCode code) =>
      throwsA(isA<SetupFailure>().having((e) => e.code, 'code', code));

  test('exact raw snapshots detach and recursively freeze maps and lists', () {
    final nested = <String, Object?>{
      'nullable': null,
      'list': <Object?>['original'],
    };
    final source = <String, Object?>{'nested': nested};
    final revision = SetupConfigRevision(
      targetId: 'opaque',
      revision: 'one',
      config: source,
    );
    nested['nullable'] = 'changed';
    (nested['list'] as List).add('later');
    final retained = revision.config['nested'] as Map;
    expect(retained['nullable'], isNull);
    expect(retained['list'], ['original']);
    expect(() => revision.config['new'] = true, throwsUnsupportedError);
    expect(() => retained['nullable'] = 'changed', throwsUnsupportedError);
    expect(
      () => (retained['list'] as List).add('changed'),
      throwsUnsupportedError,
    );
  });

  for (final root in ['permission', 'mcp']) {
    test(
      '$root scalar or null ancestor cannot be silently replaced by nested edits',
      () async {
        host.config[root] = root == 'permission' ? 'deny' : null;
        final proposal = await prepare([
          if (root == 'permission')
            const SetupEdit(path: ['permission', 'read'], value: 'ask')
          else
            const SetupEdit(
              path: ['mcp', 'demo'],
              value: {
                'type': 'remote',
                'url': 'https://example.com',
                'enabled': false,
              },
            ),
        ]);
        expect(proposal.canApply, isFalse);
        expect(proposal.reason, isNotNull);
        await expectLater(
          controller.apply(proposal.id, confirmed: true),
          failure(SetupFailureCode.invalid),
        );
        expect(host.writes, 0);
        expect(host.config[root], root == 'permission' ? 'deny' : null);
      },
    );
  }

  test(
    'absent permission ancestor can be created and exactly removed by Undo',
    () async {
      expect(host.config.containsKey('permission'), isFalse);
      final proposal = await prepare(const [
        SetupEdit(path: ['permission', 'read'], value: 'ask'),
      ]);
      expect(proposal.canApply, isTrue);
      await controller.apply(proposal.id, confirmed: true);
      expect(host.config['permission'], {'read': 'ask'});
      await controller.undo(confirmed: true);
      expect(host.config.containsKey('permission'), isFalse);
    },
  );

  for (final action in ['accepted', 'verified']) {
    test(
      '$action audit refusal after dispatch produces uncertainty without Undo or replay',
      () async {
        final proposal = await prepare();
        final previousStore = SharedPreferencesStorePlatform.instance;
        addTearDown(() {
          SharedPreferencesStorePlatform.instance = previousStore;
        });
        SharedPreferencesStorePlatform.instance = _RefuseAuditAction({
          for (final key in prefs.getKeys()) 'flutter.$key': prefs.get(key)!,
        }, action);
        await expectLater(
          controller.apply(proposal.id, confirmed: true),
          failure(SetupFailureCode.uncertain),
        );
        expect(host.writes, 1);
        expect(host.config['model'], 'example/new');
        expect(controller.snapshot.phase, SetupPhase.uncertain);
        expect(controller.snapshot.canUndo, isFalse);
        expect(controller.audit.last['action'], 'uncertain');
        expect(
          controller.audit.any((row) => row['action'] == 'verified'),
          isFalse,
        );
        await expectLater(
          controller.apply(proposal.id, confirmed: true),
          failure(SetupFailureCode.invalid),
        );
        await expectLater(
          controller.undo(confirmed: true),
          failure(SetupFailureCode.invalid),
        );
        expect(host.writes, 1);
        expect(host.restores, 0);
      },
    );
  }

  test(
    'legacy PATCH capability cannot enable Apply without atomic source transaction',
    () async {
      final legacy = _LegacyHost();
      final other = SetupController(
        gateway: legacy,
        prefs: prefs,
        profileId: 'profile',
        locationId: '/repo',
      );
      addTearDown(other.dispose);
      await other.refresh();
      final proposal = await other.propose([model]);
      expect(proposal.canApply, isFalse);
      expect(other.support.writeConfig, isFalse);
      await expectLater(
        other.apply(proposal.id, confirmed: true),
        failure(SetupFailureCode.unsupported),
      );
      expect(legacy.writes, 0);
    },
  );

  test(
    'unreviewable executable and provider edits remain unavailable even on atomic hosts',
    () async {
      await controller.refresh();
      for (final edit in const [
        SetupEdit(path: ['provider', 'example'], value: {'name': 'Example'}),
        SetupEdit(path: ['agent', 'build'], value: {'description': 'example'}),
        SetupEdit(path: ['command', 'run'], value: {'description': 'example'}),
        SetupEdit(
          path: ['mcp', 'local'],
          value: {
            'type': 'local',
            'command': ['example'],
            'enabled': false,
          },
        ),
      ]) {
        final proposal = await controller.propose([edit]);
        expect(proposal.canApply, isFalse);
        expect(proposal.reason, isNotNull);
        await expectLater(
          controller.apply(proposal.id, confirmed: true),
          failure(SetupFailureCode.invalid),
        );
      }
      expect(host.writes, 0);
    },
  );

  test(
    'enabled MCP removal stays unavailable without runtime restoration',
    () async {
      host.config['mcp'] = {
        'live': {
          'type': 'remote',
          'enabled': true,
          'url': 'https://example.com',
        },
      };
      final proposal = await prepare(const [
        SetupEdit(path: ['mcp', 'live'], remove: true),
      ]);
      expect(proposal.canApply, isFalse);
      expect(host.writes, 0);
    },
  );

  test(
    'atomic CAS rejects concurrent change after controller preflight',
    () async {
      final proposal = await prepare();
      host.beforeCommit = () {
        host.version++;
      };
      await expectLater(
        controller.apply(proposal.id, confirmed: true),
        failure(SetupFailureCode.conflict),
      );
      expect(host.writes, 0);
      expect(controller.audit.last['action'], 'rejected');
    },
  );

  test(
    'revision-only change with equal config blocks Apply before dispatch',
    () async {
      final proposal = await prepare();
      host.version++;
      await expectLater(
        controller.apply(proposal.id, confirmed: true),
        failure(SetupFailureCode.conflict),
      );
      expect(host.writes, 0);
    },
  );

  test(
    'disabled MCP add Undo restores absent key and exact unrelated nulls',
    () async {
      final before = _copy(host.config);
      final proposal = await prepare(const [
        SetupEdit(
          path: ['mcp', 'demo'],
          value: {
            'type': 'remote',
            'url': 'https://example.com/mcp',
            'enabled': false,
          },
        ),
      ]);
      expect(proposal.canApply, isTrue);
      expect(proposal.changes.single.beforePresent, isFalse);
      expect(proposal.changes.single.afterPresent, isTrue);
      await controller.apply(proposal.id, confirmed: true);
      expect((host.config['mcp'] as Map).containsKey('demo'), isTrue);
      await controller.undo(confirmed: true);
      expect(host.config, before);
      expect((host.config['mcp'] as Map).containsKey('demo'), isFalse);
      expect(host.restores, 1);
      expect(
        controller.audit
            .where((e) => e['action'] == 'verified')
            .map((e) => e['operation']),
        ['apply', 'undo'],
      );
    },
  );

  test(
    'MCP removal Undo restores exact object through host handle without resending credentials',
    () async {
      host.config['mcp'] = {
        'demo': {
          'type': 'remote',
          'enabled': false,
          'url': 'https://example.com/mcp',
          'headers': {'Authorization': 'FAKE_PRIVATE_HEADER_VALUE'},
          'nullable': null,
        },
      };
      final before = _copy(host.config);
      final proposal = await prepare(const [
        SetupEdit(path: ['mcp', 'demo'], remove: true),
      ]);
      await controller.apply(proposal.id, confirmed: true);
      expect((host.config['mcp'] as Map).containsKey('demo'), isFalse);
      expect(host.sent.single.value, isNull);
      await controller.undo(confirmed: true);
      expect(jsonEncode(host.config) == jsonEncode(before), isTrue);
      expect(
        prefs
            .getString(controller.auditKey)!
            .contains('FAKE_PRIVATE_HEADER_VALUE'),
        isFalse,
      );
      expect(
        jsonEncode(
          controller.snapshot.config,
        ).contains('FAKE_PRIVATE_HEADER_VALUE'),
        isFalse,
      );
    },
  );

  test(
    'Undo preserves a present null instead of deleting its source key',
    () async {
      host.config['default_agent'] = null;
      final proposal = await prepare(const [
        SetupEdit(path: ['default_agent'], value: 'build'),
      ]);
      expect(proposal.changes.single.beforePresent, isTrue);
      expect(proposal.changes.single.before, isNull);
      await controller.apply(proposal.id, confirmed: true);
      await controller.undo(confirmed: true);
      expect(host.config.containsKey('default_agent'), isTrue);
      expect(host.config['default_agent'], isNull);
    },
  );

  test(
    'Undo revision conflict prevents restore even with unchanged values',
    () async {
      final proposal = await prepare();
      await controller.apply(proposal.id, confirmed: true);
      host.version++;
      await expectLater(
        controller.undo(confirmed: true),
        failure(SetupFailureCode.conflict),
      );
      expect(host.restores, 0);
    },
  );

  for (final mode in ['receipt', 'readback', 'lost-response']) {
    test('$mode uncertainty disables retry and Undo', () async {
      final proposal = await prepare();
      host.badReceipt = mode == 'receipt';
      host.badReadback = mode == 'readback';
      host.loseResponse = mode == 'lost-response';
      await expectLater(
        controller.apply(proposal.id, confirmed: true),
        failure(SetupFailureCode.uncertain),
      );
      expect(controller.snapshot.phase, SetupPhase.uncertain);
      expect(controller.snapshot.canUndo, isFalse);
      await expectLater(
        controller.apply(proposal.id, confirmed: true),
        failure(SetupFailureCode.invalid),
      );
      await expectLater(
        controller.undo(confirmed: true),
        failure(SetupFailureCode.invalid),
      );
      expect(host.writes, 1);
      expect(host.restores, 0);
      expect(controller.audit.last['action'], 'uncertain');
    });
  }

  test('scope change while reading preflight sends no mutation', () async {
    final proposal = await prepare();
    host.duringRead = (_) async {
      current = false;
    };
    await expectLater(
      controller.apply(proposal.id, confirmed: true),
      failure(SetupFailureCode.offline),
    );
    expect(host.writes, 0);
  });

  test(
    'offline after dispatch reconciles original scope without ready publication',
    () async {
      final proposal = await prepare();
      final phases = <SetupPhase>[];
      final subscription = controller.changes.listen(
        (s) => phases.add(s.phase),
      );
      addTearDown(subscription.cancel);
      host.afterCommit = () async {
        controller.setOnline(false);
      };
      await expectLater(
        controller.apply(proposal.id, confirmed: true),
        failure(SetupFailureCode.offline),
      );
      await Future<void>.delayed(Duration.zero);
      expect(host.reads, 3);
      expect(host.writes, 1);
      expect(controller.audit.last['action'], 'verified');
      expect(controller.snapshot.phase, SetupPhase.offline);
      expect(phases, isNot(contains(SetupPhase.ready)));
    },
  );

  test(
    'scope change after dispatch reconciles but never publishes ready to another scope',
    () async {
      final proposal = await prepare();
      host.afterCommit = () async {
        current = false;
      };
      await expectLater(
        controller.apply(proposal.id, confirmed: true),
        failure(SetupFailureCode.offline),
      );
      expect(host.reads, 3);
      expect(controller.audit.last['action'], 'verified');
      expect(controller.snapshot.phase, SetupPhase.applying);
    },
  );

  test(
    'operation phases expose applying verifying ready and undoing',
    () async {
      final proposal = await prepare();
      final phases = <SetupPhase>[];
      final subscription = controller.changes.listen(
        (s) => phases.add(s.phase),
      );
      await controller.apply(proposal.id, confirmed: true);
      await controller.undo(confirmed: true);
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      expect(phases, [
        SetupPhase.applying,
        SetupPhase.verifying,
        SetupPhase.ready,
        SetupPhase.undoing,
        SetupPhase.verifying,
        SetupPhase.ready,
      ]);
    },
  );
}
