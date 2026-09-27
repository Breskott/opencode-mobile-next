import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/setup_assistant.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/setup_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _Gateway implements SetupConfigGateway {
  _Gateway({this.writable = true});
  final bool writable;
  Map<String, Object?> config = {
    'model': 'example/old',
    'default_agent': 'build',
  };
  int writes = 0;
  bool throwOnPatch = false;
  Completer<void>? readGate;
  @override
  SetupSupport get support => SetupSupport(
    readConfig: true,
    writeConfig: writable,
    mcpInventory: true,
    reason: 'Reversible writes are unavailable.',
  );
  @override
  Future<Map<String, Object?>> readConfig() async {
    await readGate?.future;
    return (jsonDecode(jsonEncode(config)) as Map).cast<String, Object?>();
  }

  @override
  Future<void> patchConfig(Map<String, Object?> patch) async {
    writes++;
    if (throwOnPatch) throw StateError('untrusted server body');
    config.addAll(patch);
  }

  @override
  Future<List<SetupMcpStatus>> listMcpServers() async => [
    const SetupMcpStatus(name: 'example', status: 'needs_auth'),
    const SetupMcpStatus(name: 'other', status: 'arbitrary response body'),
  ];
}

class _RefusingAuditStore extends InMemorySharedPreferencesStore {
  _RefusingAuditStore(super.data) : super.withData();
  @override
  Future<bool> setValue(String type, String key, Object value) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late _Gateway gateway;
  late SetupController controller;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    gateway = _Gateway();
    controller = SetupController(
      gateway: gateway,
      prefs: prefs,
      profileId: 'one',
      locationId: '/repo',
    );
  });
  tearDown(() async => controller.dispose());
  const modelEdit = SetupEdit(path: ['model'], value: 'example/new');

  test(
    'redacted read strips arbitrary environment credentials and server errors',
    () async {
      gateway.config['mcp'] = {
        'example': {
          'environment': {'VALUE': 'fake-private-value'},
          'headers': {'Custom': 'fake-other-value'},
        },
      };
      await controller.refresh();
      final output = jsonEncode(controller.snapshot.config);
      expect(output.contains('fake-private-value'), isFalse);
      expect(output.contains('fake-other-value'), isFalse);
      expect(controller.snapshot.servers.last.status, 'unknown');
      expect(controller.snapshot.servers.first.status, 'needs_auth');
      expect(prefs.getKeys(), isEmpty);
    },
  );
  test(
    'propose requires review and apply verifies outcome then undo restores',
    () async {
      await controller.refresh();
      final proposal = await controller.propose([modelEdit]);
      expect(proposal.changes.single.before, 'example/old');
      expect(proposal.changes.single.after, 'example/new');
      expect(gateway.writes, 0);
      await expectLater(
        controller.apply(proposal.id, confirmed: false),
        throwsA(isA<SetupFailure>()),
      );
      final fresh = await controller.propose([modelEdit]);
      await controller.apply(fresh.id, confirmed: true);
      expect(gateway.config['model'], 'example/new');
      expect(controller.snapshot.canUndo, isTrue);
      await controller.undo(confirmed: true);
      expect(gateway.config['model'], 'example/old');
      expect(controller.snapshot.canUndo, isFalse);
      expect(
        controller.audit.where((r) => r['action'] == 'verified').length,
        2,
      );
      expect(
        prefs.getString(controller.auditKey)!.contains('example/'),
        isFalse,
      );
    },
  );
  test('unsupported production writes never call transport', () async {
    final readOnly = _Gateway(writable: false);
    final other = SetupController(
      gateway: readOnly,
      prefs: prefs,
      profileId: 'two',
      locationId: '/repo',
    );
    addTearDown(other.dispose);
    await other.refresh();
    final proposal = await other.propose([modelEdit]);
    expect(proposal.canApply, isFalse);
    expect(proposal.reason, 'Reversible writes are unavailable.');
    await expectLater(
      other.apply(proposal.id, confirmed: true),
      throwsA(isA<SetupFailure>()),
    );
    await expectLater(
      other.undo(confirmed: true),
      throwsA(isA<SetupFailure>()),
    );
    expect(readOnly.writes, 0);
  });
  test(
    'changed server configuration prevents apply and undo overwrites',
    () async {
      await controller.refresh();
      var proposal = await controller.propose([modelEdit]);
      gateway.config['model'] = 'external/change';
      await expectLater(
        controller.apply(proposal.id, confirmed: true),
        throwsA(
          isA<SetupFailure>().having(
            (e) => e.code,
            'code',
            SetupFailureCode.conflict,
          ),
        ),
      );
      expect(gateway.writes, 0);
      await controller.refresh();
      proposal = await controller.propose([modelEdit]);
      await controller.apply(proposal.id, confirmed: true);
      gateway.config['default_agent'] = 'external';
      await expectLater(
        controller.undo(confirmed: true),
        throwsA(
          isA<SetupFailure>().having(
            (e) => e.code,
            'code',
            SetupFailureCode.conflict,
          ),
        ),
      );
      expect(gateway.writes, 1);
    },
  );
  test('offline cannot dispatch writes; proposals remain reviewable', () async {
    await controller.refresh();
    controller.setOnline(false);
    final proposal = await controller.propose([modelEdit]);
    expect(proposal.canApply, isFalse);
    await expectLater(
      controller.apply(proposal.id, confirmed: true),
      throwsA(isA<SetupFailure>()),
    );
    expect(gateway.writes, 0);
  });
  test('secret inputs and overlapping patches fail validation', () async {
    await controller.refresh();
    expect(
      controller.validate([
        const SetupEdit(
          path: ['provider', 'demo', 'options', 'apiKey'],
          value: 'fake',
        ),
      ]),
      isNotEmpty,
    );
    expect(
      controller.validate([
        const SetupEdit(
          path: ['mcp', 'demo'],
          value: {
            'headers': {'Custom': 'fake'},
          },
        ),
      ]),
      isNotEmpty,
    );
    expect(controller.validate([modelEdit, modelEdit]), isNotEmpty);
    expect(
      controller.validate([
        const SetupEdit(path: ['unsupported'], value: true),
      ]),
      isNotEmpty,
    );
    expect(
      controller.validate([
        const SetupEdit(path: ['model'], value: null),
      ]),
      isNotEmpty,
    );
  });
  test(
    'new keys and removals are proposals only without reversible deletion',
    () async {
      await controller.refresh();
      var proposal = await controller.propose([
        const SetupEdit(
          path: ['mcp', 'new'],
          value: {
            'type': 'remote',
            'url': 'https://example.com/mcp',
            'enabled': false,
          },
        ),
      ]);
      expect(proposal.canApply, isFalse);
      proposal = await controller.propose([
        const SetupEdit(path: ['model'], remove: true),
      ]);
      expect(proposal.canApply, isFalse);
      expect(gateway.writes, 0);
    },
  );
  test(
    'unknown write outcome records uncertainty and prevents blind retry',
    () async {
      await controller.refresh();
      final proposal = await controller.propose([modelEdit]);
      gateway.throwOnPatch = true;
      await expectLater(
        controller.apply(proposal.id, confirmed: true),
        throwsA(
          isA<SetupFailure>().having(
            (e) => e.code,
            'code',
            SetupFailureCode.uncertain,
          ),
        ),
      );
      expect(controller.audit.last['action'], 'uncertain');
      expect(controller.snapshot.canUndo, isFalse);
      await expectLater(
        controller.propose([modelEdit]),
        throwsA(isA<SetupFailure>()),
      );
      expect(gateway.writes, 1);
    },
  );
  test(
    'profile deletion sweep includes audit and preserves another profile',
    () async {
      await controller.refresh();
      await controller.propose([modelEdit]);
      await prefs.setString('oc.setupAudit.two', '[]');
      final store = ProfileStore(prefs: prefs);
      expect(
        store.profileScopedPreferenceKeys('one'),
        contains(controller.auditKey),
      );
      expect(await store.removeScopedPreferences('one'), isEmpty);
      expect(prefs.containsKey(controller.auditKey), isFalse);
      expect(prefs.containsKey('oc.setupAudit.two'), isTrue);
    },
  );
  test(
    'controller serializes concurrent actions and exposes loading stream',
    () async {
      final phases = <SetupPhase>[];
      final subscription = controller.changes.listen(
        (state) => phases.add(state.phase),
      );
      gateway.readGate = Completer<void>();
      final refreshing = controller.refresh();
      await expectLater(
        controller.refresh(),
        throwsA(
          isA<SetupFailure>().having(
            (e) => e.code,
            'code',
            SetupFailureCode.busy,
          ),
        ),
      );
      gateway.readGate!.complete();
      await refreshing;
      await Future<void>.delayed(Duration.zero);
      expect(phases, [SetupPhase.loading, SetupPhase.ready]);
      await subscription.cancel();
    },
  );
  test(
    'offline transition during refresh cannot publish ready state',
    () async {
      gateway.readGate = Completer<void>();
      final refreshing = controller.refresh();
      controller.setOnline(false);
      gateway.readGate!.complete();
      await expectLater(refreshing, throwsA(isA<SetupFailure>()));
      expect(controller.snapshot.phase, SetupPhase.offline);
    },
  );
  test(
    'layered source config cannot masquerade as an effective diff',
    () async {
      gateway.config = {'sources': <Object?>[]};
      await controller.refresh();
      await expectLater(
        controller.propose([modelEdit]),
        throwsA(
          isA<SetupFailure>().having(
            (e) => e.code,
            'code',
            SetupFailureCode.unsupported,
          ),
        ),
      );
    },
  );
  test('basic shape validation rejects malformed scalar and MCP inputs', () {
    expect(
      controller.validate([
        const SetupEdit(path: ['model'], value: 42),
      ]),
      isNotEmpty,
    );
    expect(
      controller.validate([
        const SetupEdit(
          path: ['mcp', 'x'],
          value: {
            'type': 'remote',
            'url': 'https://example.com',
            'enabled': true,
          },
        ),
      ]),
      isNotEmpty,
    );
    expect(
      controller.validate([
        const SetupEdit(path: ['permission', '*'], value: 'ask'),
      ]),
      isEmpty,
    );
  });
  test('audit storage refusal prevents mutation', () async {
    await controller.refresh();
    final proposal = await controller.propose([modelEdit]);
    SharedPreferencesStorePlatform.instance = _RefusingAuditStore({});
    await expectLater(
      controller.apply(proposal.id, confirmed: true),
      throwsA(
        isA<SetupFailure>().having(
          (e) => e.code,
          'code',
          SetupFailureCode.storage,
        ),
      ),
    );
    expect(gateway.writes, 0);
  });
  test(
    'dispose drains in-flight refresh and clears profile snapshot',
    () async {
      await controller.refresh();
      gateway.readGate = Completer<void>();
      final refreshing = controller.refresh();
      final checked = expectLater(refreshing, throwsA(isA<SetupFailure>()));
      final closing = controller.dispose();
      gateway.readGate!.complete();
      await checked;
      await closing;
      expect(controller.snapshot.config, isEmpty);
      expect(controller.snapshot.proposal, isNull);
      expect(prefs.containsKey(controller.auditKey), isFalse);
    },
  );
  test('setup mutation capabilities default off for unknown servers', () {
    const capabilities = ServerCapabilities();
    expect(capabilities.setupConfigWrite, isFalse);
    expect(capabilities.setupAssistantSession, isFalse);
    expect(capabilities.setupConfigRead, isFalse);
    expect(ServerCapabilities.allV1.setupConfigRead, isTrue);
  });
}
