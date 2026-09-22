import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart' show ServerPage;
import 'package:opencode_mobile/state/profile_monitor.dart';
import 'package:opencode_mobile/state/profiles.dart';

import 'support/profile_monitor_fixture.dart';

/// A Paseo daemon knows its conversations' waiting requests only once it has
/// listed them.
class _ListFirstGateway extends MonitorTestGateway {
  _ListFirstGateway() : super(requests: [request(1)]);
  bool listed = false;

  @override
  Future<ServerPage<Session>> sessionPage({String? cursor, int limit = 100}) {
    listed = true;
    return super.sessionPage(cursor: cursor, limit: limit);
  }

  @override
  Future<List<PermissionRequest>> pendingPermissions() async =>
      listed ? super.pendingPermissions() : const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          storage,
          (call) async => call.method == 'readAll' ? <String, String>{} : null,
        ),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, null),
  );

  Future<ProfileStore> phoneStore() async {
    final store = await monitorStore(count: 1);
    await store.upsert(
      ServerProfile(
        id: 'claude',
        name: 'Claude Code (this phone)',
        baseUrl: 'http://127.0.0.1:6767',
        username: '',
        password: '',
      )..backend = ServerBackend.paseo,
    );
    return store;
  }

  ProfileMonitor monitorFor(
    ProfileStore store,
    MonitorTestGateway Function() gateway,
  ) => ProfileMonitor(
    store: store,
    isReadable: (_) => true,
    createGateway: (_) =>
        (gateway: gateway(), operations: MonitorTestOperations()),
    networkWifi: () async => false,
    alert: (_, r, k, t) async => true,
    dismiss: (_) async => true,
  );

  test('with two agents on this phone each is watched unless turned off; '
      'others are not', () async {
    final store = await phoneStore();
    final monitor = monitorFor(store, MonitorTestGateway.new);
    addTearDown(monitor.dispose);
    // One server on the phone alone: nothing to watch it from.
    expect(monitor.rulesFor('claude').enabled, isFalse);
    await store.upsert(
      ServerProfile(
        id: 'opencode',
        name: 'This device',
        baseUrl: 'http://127.0.0.1:4096',
        username: '',
        password: '',
      ),
    );
    expect(monitor.rulesFor('claude').enabled, isTrue);
    expect(monitor.rulesFor('opencode').enabled, isTrue);
    expect(monitor.rulesFor('profile-1').enabled, isFalse);

    await monitor.setEnabled('claude', false);
    expect(monitor.rulesFor('claude').enabled, isFalse);
  });

  test('Claude Code through Paseo is read; Codex still is not', () async {
    final store = await phoneStore();
    final monitor = monitorFor(store, MonitorTestGateway.new);
    addTearDown(monitor.dispose);
    final claude = store.profiles.firstWhere((p) => p.id == 'claude');
    expect(monitor.supportsProfile(claude), isTrue);
    claude.backend = ServerBackend.codex;
    expect(monitor.supportsProfile(claude), isFalse);
  });

  test('Wi-Fi only does not hold back a server reached without a '
      'network', () async {
    final store = await phoneStore();
    await store.prefs.setString(
      ProfileMonitor.rulesKey('claude'),
      jsonEncode(
        const ProfileNotifyRules(enabled: true, wifiOnly: true).toJson(),
      ),
    );
    final monitor = monitorFor(store, _ListFirstGateway.new);
    addTearDown(monitor.dispose);
    expect(monitor.rulesFor('claude').wifiOnly, isFalse);

    // Wi-Fi is off, and the waiting approval is still seen: the list is read
    // before the requests, as the daemon needs.
    await monitor.refresh();
    final snapshot = monitor.snapshotFor('claude');
    expect(snapshot.status, ProfileMonitorStatus.current);
    expect(snapshot.requests.map((r) => r.id), ['request-1']);
    expect(snapshot.runningCount, 1);
  });
}
