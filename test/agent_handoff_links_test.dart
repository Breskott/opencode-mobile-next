import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/agent_handoff_links.dart';
import 'package:opencode_mobile/domain/agent_handoff.dart' show HandoffOrigin;
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

HandoffLink _link({
  String id = 'handoff-1',
  String source = 'phone',
  String target = 'claude',
  String title = 'Fix the parser',
  String sourceSession = 'session-source',
  String targetSession = 'session-target',
  HandoffOrigin sourceOrigin = HandoffOrigin.server,
  HandoffOrigin targetOrigin = HandoffOrigin.server,
}) => HandoffLink(
  id: id,
  sourceProfileId: source,
  sourceSessionId: sourceSession,
  sourceOrigin: sourceOrigin,
  sourceTitle: title,
  targetProfileId: target,
  targetSessionId: targetSession,
  targetOrigin: targetOrigin,
  targetAgent: 'Claude Code',
  projectDirectory: '/projects/parser',
  handoffPath: '/projects/parser/.handoff/session-source.md',
);

class _Disk extends InMemorySharedPreferencesStore {
  _Disk(super.data) : super.withData();
  bool refuse = false;
  bool hold = false;
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key.startsWith('flutter.oc.agentHandoffs.')) {
      if (hold) {
        hold = false;
        entered.complete();
        await release.future;
      }
      if (refuse) return false;
    }
    return super.setValue(type, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (key.startsWith('flutter.oc.agentHandoffs.') && refuse) return false;
    return super.remove(key);
  }
}

Future<(SharedPreferences, _Disk)> _setup() async {
  SharedPreferences.setMockInitialValues({
    'oc.profiles': jsonEncode([
      {'id': 'phone'},
      {'id': 'claude'},
      {'id': 'other'},
    ]),
  });
  final disk = _Disk(await SharedPreferencesStorePlatform.instance.getAll());
  SharedPreferencesStorePlatform.instance = disk;
  SharedPreferences.resetStatic();
  return (await SharedPreferences.getInstance(), disk);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(KitRedact.clearKnownSecrets);
  tearDown(KitRedact.clearKnownSecrets);

  test(
    'one durable record supplies both conversation directions after restart',
    () async {
      final (prefs, _) = await _setup();
      final store = AgentHandoffLinks.forPreferences(prefs);
      await store.save(_link());
      expect(
        store.forSession('phone', 'session-source').single.targetAgent,
        'Claude Code',
      );
      expect(
        store.forSession('claude', 'session-target').single.sourceTitle,
        'Fix the parser',
      );
      expect(prefs.containsKey('oc.agentHandoffs.phone'), isTrue);
      expect(prefs.containsKey('oc.agentHandoffs.claude'), isFalse);

      SharedPreferences.resetStatic();
      final restarted = await SharedPreferences.getInstance();
      final links = AgentHandoffLinks.forPreferences(restarted);
      expect(
        links.forSession('claude', 'session-target').single.id,
        'handoff-1',
      );
      expect(links.forSession('other', 'session-target'), isEmpty);
    },
  );

  test(
    'redacts display metadata and rejects secret-bearing identifiers',
    () async {
      final (prefs, _) = await _setup();
      final store = AgentHandoffLinks.forPreferences(prefs);
      await store.save(_link(title: 'API_KEY=synthetic-private-value'));
      expect(
        prefs.getString('oc.agentHandoffs.phone'),
        isNot(contains('synthetic-private-value')),
      );
      await expectLater(
        store.save(_link(id: 'token=synthetic-private-value')),
        throwsFormatException,
      );
    },
  );

  test('same-profile handoff has one link and saves are idempotent', () async {
    final (prefs, _) = await _setup();
    final store = AgentHandoffLinks.forPreferences(prefs);
    final link = _link(target: 'phone');
    await store.save(link);
    await store.save(link);
    expect(store.forSession('phone', 'session-source'), hasLength(1));
    expect(store.forSession('phone', 'session-target'), hasLength(1));
    await expectLater(
      store.save(_link(target: 'phone', title: 'Different work')),
      throwsStateError,
    );
  });

  test(
    'runtime origins distinguish identical session IDs under one parent',
    () async {
      final (prefs, _) = await _setup();
      final store = AgentHandoffLinks.forPreferences(prefs);
      await store.save(
        _link(
          id: 'server-link',
          target: 'phone',
          sourceSession: 'shared',
          targetSession: 'server-target',
        ),
      );
      await store.save(
        _link(
          id: 'agent-link',
          target: 'phone',
          sourceSession: 'shared',
          targetSession: 'agent-target',
          sourceOrigin: HandoffOrigin.phoneAgent,
          targetOrigin: HandoffOrigin.phoneAgent,
        ),
      );
      expect(
        store
            .forSession('phone', 'shared', origin: HandoffOrigin.server)
            .single
            .id,
        'server-link',
      );
      expect(
        store
            .forSession('phone', 'shared', origin: HandoffOrigin.phoneAgent)
            .single
            .id,
        'agent-link',
      );
      expect(
        store.forSession('phone', 'agent-target', origin: HandoffOrigin.server),
        isEmpty,
      );
      expect(store.forSession('phone', 'shared'), hasLength(2));

      SharedPreferences.resetStatic();
      final restarted = AgentHandoffLinks.forPreferences(
        await SharedPreferences.getInstance(),
      );
      final persisted = restarted
          .forSession('phone', 'agent-target', origin: HandoffOrigin.phoneAgent)
          .single;
      expect(persisted.sourceOrigin, HandoffOrigin.phoneAgent);
      expect(persisted.targetOrigin, HandoffOrigin.phoneAgent);
      await AgentHandoffLinks.removeProfile(prefs, 'phone');
      expect(prefs.containsKey('oc.agentHandoffs.phone'), isFalse);
    },
  );

  test(
    'cross-origin links use the durable parent without a transient profile row',
    () async {
      final (prefs, _) = await _setup();
      final store = AgentHandoffLinks.forPreferences(prefs);
      await store.save(
        _link(target: 'phone', targetOrigin: HandoffOrigin.phoneAgent),
      );
      expect(
        store
            .forSession('phone', 'session-source', origin: HandoffOrigin.server)
            .single
            .targetOrigin,
        HandoffOrigin.phoneAgent,
      );
      expect(
        store
            .forSession(
              'phone',
              'session-target',
              origin: HandoffOrigin.phoneAgent,
            )
            .single
            .sourceOrigin,
        HandoffOrigin.server,
      );
      expect(
        store.forSession(
          'phone',
          'session-target',
          origin: HandoffOrigin.server,
        ),
        isEmpty,
      );
    },
  );

  test('concurrent saves keep each conversation link', () async {
    final (prefs, _) = await _setup();
    final store = AgentHandoffLinks.forPreferences(prefs);
    await Future.wait([
      store.save(_link(id: 'one')),
      store.save(_link(id: 'two')),
      store.save(_link(id: 'three', source: 'other')),
    ]);
    expect(store.forSession('phone', 'session-source'), hasLength(2));
    expect(store.forSession('claude', 'session-target'), hasLength(3));
  });

  test(
    'deleting target removes references from surviving source profiles',
    () async {
      final (prefs, _) = await _setup();
      final store = AgentHandoffLinks.forPreferences(prefs);
      await store.save(_link());
      await store.save(_link(id: 'unrelated', target: 'other'));
      await AgentHandoffLinks.removeProfile(prefs, 'claude');
      expect(
        store.forSession('phone', 'session-source').single.id,
        'unrelated',
      );
      expect(
        prefs.getString('oc.agentHandoffs.phone'),
        isNot(contains('claude')),
      );
      await expectLater(store.save(_link()), throwsStateError);
    },
  );

  test('profile-scoped cleanup removes inbound references too', () async {
    final (prefs, _) = await _setup();
    final store = AgentHandoffLinks.forPreferences(prefs);
    await store.save(_link());
    final profiles = ProfileStore(prefs: prefs);
    expect(await profiles.removeScopedPreferences('claude'), isEmpty);
    expect(prefs.containsKey('oc.agentHandoffs.phone'), isFalse);
  });

  test('deleting source removes its canonical key', () async {
    final (prefs, _) = await _setup();
    final store = AgentHandoffLinks.forPreferences(prefs);
    await store.save(_link());
    await AgentHandoffLinks.removeProfile(prefs, 'phone');
    expect(prefs.containsKey('oc.agentHandoffs.phone'), isFalse);
    expect(store.forSession('claude', 'session-target'), isEmpty);
  });

  test(
    'refused persistence reports failure and hides optimistic cache',
    () async {
      final (prefs, disk) = await _setup();
      final store = AgentHandoffLinks.forPreferences(prefs);
      disk.refuse = true;
      await expectLater(store.save(_link()), throwsStateError);
      expect(
        () => store.forSession('phone', 'session-source'),
        throwsStateError,
      );
      await prefs.reload();
      expect(prefs.containsKey('oc.agentHandoffs.phone'), isFalse);
      disk.refuse = false;
      await store.save(_link());
      expect(store.forSession('phone', 'session-source'), hasLength(1));
    },
  );

  test(
    'refused cross-profile removal remains retryable and is reported',
    () async {
      final (prefs, disk) = await _setup();
      final store = AgentHandoffLinks.forPreferences(prefs);
      await store.save(_link());
      disk.refuse = true;
      final profiles = ProfileStore(prefs: prefs);
      expect(
        await profiles.removeScopedPreferences('claude'),
        contains('oc.agentHandoffs.claude'),
      );
      expect(prefs.getString('oc.agentHandoffs.phone'), contains('claude'));
      disk.refuse = false;
      expect(await profiles.removeScopedPreferences('claude'), isEmpty);
      expect(prefs.containsKey('oc.agentHandoffs.phone'), isFalse);
    },
  );

  test(
    'deletion drains in-flight saves and rejects queued stale writes',
    () async {
      final (prefs, disk) = await _setup();
      final store = AgentHandoffLinks.forPreferences(prefs);
      disk.hold = true;
      final first = expectLater(store.save(_link()), throwsStateError);
      await disk.entered.future;
      expect(
        () => store.forSession('phone', 'session-source'),
        throwsStateError,
      );
      final queued = expectLater(
        store.save(_link(id: 'queued')),
        throwsStateError,
      );
      final deletion = AgentHandoffLinks.removeProfile(prefs, 'claude');
      disk.release.complete();
      await Future.wait([first, queued, deletion]);
      expect(prefs.containsKey('oc.agentHandoffs.phone'), isFalse);
      await AgentHandoffLinks.cancelDeletion(prefs, 'claude');
      await store.save(_link(id: 'fresh'));
      expect(store.forSession('phone', 'session-source').single.id, 'fresh');
    },
  );

  test(
    'corrupt stored links fail closed instead of replacing history',
    () async {
      final (prefs, _) = await _setup();
      await prefs.setString('oc.agentHandoffs.phone', '{broken');
      final store = AgentHandoffLinks.forPreferences(prefs);
      expect(
        () => store.forSession('phone', 'session-source'),
        throwsStateError,
      );
      await expectLater(store.save(_link()), throwsStateError);
      expect(prefs.getString('oc.agentHandoffs.phone'), '{broken');
      await AgentHandoffLinks.removeProfile(prefs, 'phone');
      expect(prefs.containsKey('oc.agentHandoffs.phone'), isFalse);
    },
  );
}
