import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/setup_assistant.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/setup_audit_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _AuditDisk extends InMemorySharedPreferencesStore {
  _AuditDisk(super.data, {this.delay = false, this.refuse = false})
    : super.withData();
  final bool delay;
  bool refuse;
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key.endsWith('oc.setupAudit.audit')) {
      if (delay && !started.isCompleted) {
        started.complete();
        await release.future;
      }
      if (refuse) return false;
    }
    return super.setValue(type, key, value);
  }
}

Matcher _failure(SetupFailureCode code) =>
    isA<SetupFailure>().having((error) => error.code, 'code', code);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'oc.profiles': jsonEncode([
        {'id': 'audit', 'name': 'Audit', 'baseUrl': 'http://localhost:4096'},
      ]),
    });
    prefs = await SharedPreferences.getInstance();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
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

  test(
    'two controllers share one audit writer without losing records',
    () async {
      final first = SetupAuditStore.forProfile(prefs, 'audit');
      final second = SetupAuditStore.forProfile(prefs, 'audit');
      expect(identical(first, second), isTrue);
      await Future.wait([
        first.append('proposal-1', 'proposed', operation: 'review'),
        second.append('proposal-2', 'pending', operation: 'apply'),
      ]);
      await prefs.reload();
      expect(first.records.map((record) => record['id']), [
        'proposal-1',
        'proposal-2',
      ]);
      expect(() => first.records.clear(), throwsUnsupportedError);
      expect(
        () => first.records.first['action'] = 'verified',
        throwsUnsupportedError,
      );
    },
  );

  test(
    'audit history is bounded and legacy metadata remains readable',
    () async {
      await prefs.setString(
        'oc.setupAudit.audit',
        jsonEncode([
          {
            'id': 'proposal-0',
            'action': 'proposed',
            'at': '2026-09-27T10:00:00Z',
          },
        ]),
      );
      final owner = SetupAuditStore.forProfile(prefs, 'audit');
      expect(owner.isAvailable, isTrue);
      expect(owner.records.single.keys.toSet(), {'id', 'action', 'at'});
      for (var i = 1; i <= 102; i++) {
        await owner.append('proposal-$i', 'verified', operation: 'apply');
      }
      expect(owner.records.length, 100);
      expect(owner.records.first['id'], 'proposal-3');
      await prefs.reload();
      expect(
        (jsonDecode(prefs.getString('oc.setupAudit.audit')!) as List).length,
        100,
      );
    },
  );

  test(
    'absent profiles and invalid metadata cannot create audit keys',
    () async {
      final absent = SetupAuditStore.forProfile(prefs, 'missing');
      expect(absent.isAvailable, isFalse);
      await expectLater(
        absent.append('proposal-1', 'proposed'),
        throwsA(_failure(SetupFailureCode.offline)),
      );
      final owner = SetupAuditStore.forProfile(prefs, 'audit');
      for (final write in [
        () => owner.append('https://example.invalid/private', 'proposed'),
        () => owner.append('proposal-1', 'untrusted prose'),
        () => owner.append('proposal-1', 'proposed', operation: 'raw input'),
      ]) {
        await expectLater(write(), throwsA(_failure(SetupFailureCode.storage)));
      }
      expect(prefs.containsKey('oc.setupAudit.audit'), isFalse);
      expect(prefs.containsKey('oc.setupAudit.missing'), isFalse);
    },
  );

  test(
    'receipt acceptance and historical Undo IDs remain distinct metadata',
    () async {
      final owner = SetupAuditStore.forProfile(prefs, 'audit');
      await owner.append('undo-1', 'verified', operation: 'undo');
      final opaqueId = List.filled(48, 'a').join();
      await owner.append(opaqueId, 'accepted', operation: 'apply');
      expect(owner.records.last['action'], 'accepted');
      expect(owner.records.first['id'], 'undo-1');
    },
  );

  test('corrupt or untrusted stored metadata refuses overwrite', () async {
    final owner = SetupAuditStore.forProfile(prefs, 'audit');
    for (final raw in [
      '{broken',
      '{}',
      jsonEncode([
        {
          'id': 'proposal-1',
          'action': 'proposed',
          'at': '2026-09-27T10:00:00Z',
          'config': {},
        },
      ]),
      jsonEncode([
        {
          'id': 'proposal-1',
          'action': 'untrusted prose',
          'at': '2026-09-27T10:00:00Z',
        },
      ]),
      jsonEncode([
        {
          'id': 'https://example.invalid/private',
          'action': 'proposed',
          'at': '2026-09-27T10:00:00Z',
        },
      ]),
    ]) {
      await prefs.setString('oc.setupAudit.audit', raw);
      expect(owner.isAvailable, isFalse);
      expect(owner.records, isEmpty);
      await expectLater(
        owner.append('proposal-2', 'pending'),
        throwsA(_failure(SetupFailureCode.storage)),
      );
      expect(prefs.getString('oc.setupAudit.audit') == raw, isTrue);
    }
  });

  test('refused storage does not fabricate a durable audit record', () async {
    final owner = SetupAuditStore.forProfile(prefs, 'audit');
    await owner.append('proposal-1', 'proposed');
    final disk = _AuditDisk(
      await SharedPreferencesStorePlatform.instance.getAll(),
      refuse: true,
    );
    SharedPreferencesStorePlatform.instance = disk;
    await expectLater(
      owner.append('proposal-2', 'pending'),
      throwsA(_failure(SetupFailureCode.storage)),
    );
    expect(owner.records.map((record) => record['id']), ['proposal-1']);
    disk.refuse = false;
    await owner.append('proposal-2', 'pending');
    expect(owner.records.length, 2);
  });

  test(
    'profile deletion drains audit then rejects old and new handles',
    () async {
      final profiles = ProfileStore(prefs: prefs);
      await profiles.load();
      final disk = _AuditDisk(
        await SharedPreferencesStorePlatform.instance.getAll(),
        delay: true,
      );
      SharedPreferencesStorePlatform.instance = disk;
      final owner = SetupAuditStore.forProfile(prefs, 'audit');
      final writing = owner.append('proposal-1', 'pending', operation: 'apply');
      await disk.started.future;
      var removed = false;
      final removal = profiles.remove('audit').then((_) => removed = true);
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      final removedBeforeDrain = removed;
      await expectLater(
        owner.append('proposal-2', 'pending'),
        throwsA(_failure(SetupFailureCode.offline)),
      );
      disk.release.complete();
      await writing;
      await removal;
      await prefs.reload();
      expect(removedBeforeDrain, isFalse);
      expect(profiles.profileScopedPreferenceKeys('audit'), isEmpty);
      expect(owner.records, isEmpty);
      final reopened = SetupAuditStore.forProfile(prefs, 'audit');
      expect(identical(owner, reopened), isTrue);
      await expectLater(
        reopened.append('proposal-3', 'pending'),
        throwsA(_failure(SetupFailureCode.offline)),
      );
    },
  );

  test(
    'close stops admission synchronously even while writes are draining',
    () async {
      final owner = SetupAuditStore.forProfile(prefs, 'audit');
      final drain = SetupAuditStore.closeProfile(prefs, 'audit');
      expect(owner.isAvailable, isFalse);
      await expectLater(
        owner.append('proposal-1', 'pending'),
        throwsA(_failure(SetupFailureCode.offline)),
      );
      await drain;
      expect(prefs.containsKey('oc.setupAudit.audit'), isFalse);
    },
  );
}
