import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/session_auto_approval.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// Refuses writes on demand, and can hold one write open so a deletion can
/// be started while a setting is still on its way to disk.
class _GatedStore extends InMemorySharedPreferencesStore {
  _GatedStore(super.data) : super.withData();
  bool refuse = false;
  Completer<void>? gate;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.contains('oc.autoApprove.')) {
      await gate?.future;
      if (refuse) return false;
    }
    return super.setValue(valueType, key, value);
  }
}

const _auto = SessionAutoApproval(mode: AutoApprovalMode.autoOnce);
const _autoInherit = SessionAutoApproval(
  mode: AutoApprovalMode.autoOnce,
  inheritToChildren: true,
);

Future<(SessionAutoApprovalStore, SharedPreferences, _GatedStore)> _boot([
  Map<String, Object> seed = const {},
]) async {
  final platform = _GatedStore({
    for (final entry in seed.entries) 'flutter.${entry.key}': entry.value,
  });
  SharedPreferencesStorePlatform.instance = platform;
  SharedPreferences.resetStatic();
  final prefs = await SharedPreferences.getInstance();
  return (SessionAutoApprovalStore(prefs), prefs, platform);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('persistence', () {
    test('a setting round-trips under the profile-scoped key', () async {
      final (store, prefs, _) = await _boot();
      expect(store.explicitFor('server-a', 'ses_1'), isNull);

      await store.set('server-a', 'ses_1', _autoInherit);

      expect(store.explicitFor('server-a', 'ses_1'), _autoInherit);
      expect(
        SessionAutoApprovalStore.keyFor('server-a'),
        'oc.autoApprove.server-a',
      );
      final raw = prefs.getString('oc.autoApprove.server-a');
      expect(raw, isNotNull);
      expect(jsonDecode(raw!), {
        'ses_1': {'mode': 'autoOnce', 'inheritToChildren': true},
      });
      // The deletion sweep must be able to find it by shape alone.
      expect(
        ProfileStore(prefs: prefs).profileScopedPreferenceKeys('server-a'),
        contains('oc.autoApprove.server-a'),
      );

      // A restart reads the same choice back; another profile sees nothing.
      final reopened = SessionAutoApprovalStore(prefs);
      expect(reopened.explicitFor('server-a', 'ses_1'), _autoInherit);
      expect(reopened.explicitFor('server-b', 'ses_1'), isNull);
    });

    test(
      'clearing removes the session entry so it follows its parent',
      () async {
        final (store, prefs, _) = await _boot();
        await store.set('server-a', 'ses_1', _auto);
        await store.set('server-a', 'ses_2', SessionAutoApproval.ask);

        await store.set('server-a', 'ses_1', null);

        expect(store.explicitFor('server-a', 'ses_1'), isNull);
        expect(store.explicitFor('server-a', 'ses_2'), SessionAutoApproval.ask);
        expect(jsonDecode(prefs.getString('oc.autoApprove.server-a')!), {
          'ses_2': {'mode': 'ask', 'inheritToChildren': false},
        });
      },
    );

    test('a refused write throws and leaves the last saved choice', () async {
      final (store, _, platform) = await _boot();
      await store.set('server-a', 'ses_1', _auto);

      platform.refuse = true;
      await expectLater(
        store.set('server-a', 'ses_1', SessionAutoApproval.ask),
        throwsStateError,
      );

      expect(store.explicitFor('server-a', 'ses_1'), _auto);
      // Disk agrees: a restart would not surprise the user either.
      final reopened = SessionAutoApprovalStore(
        await SharedPreferences.getInstance(),
      );
      expect(reopened.explicitFor('server-a', 'ses_1'), _auto);
    });

    test('malformed storage reads as no settings', () async {
      final (store, _, _) = await _boot({
        'oc.autoApprove.server-a':
            '{"ses_1": {"mode": "always"}, "": {"mode": "ask"}, "ses_2": 4}',
      });
      expect(store.settingsFor('server-a'), isEmpty);
      final (broken, _, _) = await _boot({'oc.autoApprove.server-a': 'nope'});
      expect(broken.settingsFor('server-a'), isEmpty);
      expect(
        broken.effectiveFor('server-a', 'ses_1', (_) => null).automatic,
        isFalse,
      );
    });

    test('an empty profile never reads or writes', () async {
      final (store, _, _) = await _boot();
      expect(store.explicitFor('', 'ses_1'), isNull);
      expect(
        store.effectiveFor('', 'ses_1', (_) => null),
        EffectiveAutoApproval.askByDefault,
      );
      await expectLater(store.set('', 'ses_1', _auto), throwsStateError);
    });
  });

  group('effective mode', () {
    final parents = <String, String?>{
      'child': 'parent',
      'grandchild': 'child',
      'parent': null,
      'loop-a': 'loop-b',
      'loop-b': 'loop-a',
    };
    String? parentOf(String id) => parents[id];

    test('new sessions ask', () async {
      final (store, _, _) = await _boot();
      final effective = store.effectiveFor('server-a', 'parent', parentOf);
      expect(effective.automatic, isFalse);
      expect(effective.explicit, isFalse);
      expect(effective.inherited, isFalse);
    });

    test('inheritance reaches child and grandchild', () async {
      final (store, _, _) = await _boot();
      await store.set('server-a', 'parent', _autoInherit);

      for (final id in ['child', 'grandchild']) {
        final effective = store.effectiveFor('server-a', id, parentOf);
        expect(effective.automatic, isTrue, reason: id);
        expect(effective.explicit, isFalse, reason: id);
        expect(effective.inheritedFrom, 'parent', reason: id);
      }
      final own = store.effectiveFor('server-a', 'parent', parentOf);
      expect(own.explicit, isTrue);
      expect(own.inherited, isFalse);
    });

    test('without inherit the choice stays on the parent', () async {
      final (store, _, _) = await _boot();
      await store.set('server-a', 'parent', _auto);
      expect(
        store.effectiveFor('server-a', 'parent', parentOf).automatic,
        isTrue,
      );
      expect(
        store.effectiveFor('server-a', 'child', parentOf).automatic,
        isFalse,
      );
      expect(
        store.effectiveFor('server-a', 'grandchild', parentOf).automatic,
        isFalse,
      );
    });

    test('an explicit child override wins over the parent', () async {
      final (store, _, _) = await _boot();
      await store.set('server-a', 'parent', _autoInherit);
      await store.set('server-a', 'child', SessionAutoApproval.ask);

      final child = store.effectiveFor('server-a', 'child', parentOf);
      expect(child.automatic, isFalse);
      expect(child.explicit, isTrue);
      // The opted-out child shields its own subtree from the grandparent.
      final grandchild = store.effectiveFor('server-a', 'grandchild', parentOf);
      expect(grandchild.automatic, isFalse);
      expect(grandchild.inherited, isFalse);

      // Clearing the override lets the parent's choice through again.
      await store.set('server-a', 'child', null);
      expect(
        store.effectiveFor('server-a', 'child', parentOf).inheritedFrom,
        'parent',
      );
      expect(
        store.effectiveFor('server-a', 'grandchild', parentOf).inheritedFrom,
        'parent',
      );
    });

    test('a parent cycle ends the walk', () async {
      final (store, _, _) = await _boot();
      expect(
        store.effectiveFor('server-a', 'loop-a', parentOf).automatic,
        isFalse,
      );
    });
  });

  group('profile deletion', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (call) async =>
                call.method == 'readAll' ? <String, String>{} : null,
          );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('oc/background'),
            (_) async => null,
          );
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            null,
          );
    });

    test('waits for an in-flight write, then removes the key', () async {
      final (_, prefs, platform) = await _boot({
        'oc.profiles': jsonEncode([
          {'id': 'doomed', 'name': 'Old', 'baseUrl': 'http://old.local:4096'},
          {'id': 'keeper', 'name': 'Keep', 'baseUrl': 'http://keep.local:4096'},
        ]),
        'oc.activeProfile': 'doomed',
        'oc.autoApprove.keeper': jsonEncode({
          'ses_k': {'mode': 'autoOnce', 'inheritToChildren': false},
        }),
      });
      final store = ProfileStore(prefs: prefs);
      await store.load();
      final controller = ConnectionController(store);
      addTearDown(controller.dispose);
      controller.sessionsById['ses_1'] = _session('ses_1');

      // Start a write and hold it on the platform side, then delete.
      platform.gate = Completer<void>();
      final write = controller.setSessionAutoApproval('ses_1', _autoInherit);
      final deletion = controller.deleteProfileAndLocalData('doomed');
      await Future<void>.delayed(Duration.zero);

      platform.gate!.complete();
      await write;
      final result = await deletion;

      expect(result.removedPreferenceKeys, contains('oc.autoApprove.doomed'));
      expect(prefs.getString('oc.autoApprove.doomed'), isNull);
      expect(
        SessionAutoApprovalStore(prefs).explicitFor('doomed', 'ses_1'),
        isNull,
      );
      // The other profile's choice is untouched.
      expect(
        SessionAutoApprovalStore(prefs).explicitFor('keeper', 'ses_k'),
        _auto,
      );
      // The controller's cache does not resurrect the deleted choice.
      expect(
        controller.sessionAutoApproval.explicitFor('doomed', 'ses_1'),
        isNull,
      );
    });
  });
  group('approve everything (server-wide)', () {
    String? noParent(String _) => null;

    test('reaches every conversation, including ones never seen', () async {
      final (store, prefs, _) = await _boot();
      expect(store.effectiveFor('p', 'new', noParent).automatic, isFalse);
      await store.setApprovesEverything('p', true);
      final effective = store.effectiveFor('p', 'new', noParent);
      expect(effective.automatic, isTrue);
      expect(effective.serverWide, isTrue);
      expect(effective.explicit, isFalse);
      // Only this server.
      expect(store.effectiveFor('other', 'new', noParent).automatic, isFalse);

      // Saved: a fresh store over the same preferences still has it.
      final reopened = SessionAutoApprovalStore(prefs);
      expect(reopened.approvesEverything('p'), isTrue);
      await reopened.setApprovesEverything('p', false);
      expect(reopened.effectiveFor('p', 'new', noParent).automatic, isFalse);
    });

    test('a conversation set to ask keeps asking', () async {
      final (store, _, _) = await _boot();
      await store.setApprovesEverything('p', true);
      await store.set('p', 'careful', SessionAutoApproval.ask);
      final effective = store.effectiveFor('p', 'careful', noParent);
      expect(effective.automatic, isFalse);
      expect(effective.explicit, isTrue);
    });

    test('is not listed as a conversation', () async {
      final (store, _, _) = await _boot();
      await store.setApprovesEverything('p', true);
      await store.set('p', 's1', _auto);
      expect(store.settingsFor('p').keys, ['s1']);
    });
  });
}

Session _session(String id, {String? parentID}) =>
    Session(id: id, title: id, parentID: parentID);
