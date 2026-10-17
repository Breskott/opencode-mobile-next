import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/background/usage_widget_snapshot.dart';
import 'package:opencode_mobile/domain/provider_quota.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/provider_quota_monitor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_quota_test.dart' show providerQuotaFixture;

class _Store extends ProfileStore {
  _Store(SharedPreferences prefs) : super(prefs: prefs);
  final entries = <ServerProfile>[];
  @override
  List<ServerProfile> get profiles => List.unmodifiable(entries);
}

class _Gateway implements ProviderQuotaGateway {
  _Gateway(this.read);
  final Future<ProviderQuotaSnapshot> Function() read;
  @override
  Future<ProviderQuotaSnapshot> readSnapshot() => read();
  @override
  void close() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late UsageWidgetSnapshot widget;
  var redraws = 0;
  final now = DateTime.utc(2026, 10, 12, 12);

  ProviderQuotaSnapshot snapshot({
    QuotaProvider provider = QuotaProvider.codex,
    double used = 38,
    bool unverified = false,
  }) {
    final data = providerQuotaFixture(
      provider: provider,
      fetchedAtMs: now.millisecondsSinceEpoch,
    );
    if (unverified) {
      (data['account'] as Map)
        ..['status'] = 'unverified'
        ..remove('ref');
      data['windows'] = <Object?>[];
      data['ordinaryUsageAllowed'] = null;
      return ProviderQuotaSnapshot.fromJson(data);
    }
    final first = (data['windows'] as List).first as Map;
    first['usedPercent'] = used;
    first['resetsAtMs'] = now.millisecondsSinceEpoch + 3 * 3600 * 1000;
    return ProviderQuotaSnapshot.fromJson(data);
  }

  Map<String, dynamic> stored(String profile) =>
      jsonDecode(prefs.getString(UsageWidgetSnapshot.key(profile))!)
          as Map<String, dynamic>;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    redraws = 0;
    widget = UsageWidgetSnapshot(
      prefs: prefs,
      isAndroid: true,
      refreshNative: () async => redraws++,
    );
  });

  test(
    'writes remaining percent, window length, reset and fetch time',
    () async {
      await widget.record(
        profileId: 'p1',
        profileName: 'Home',
        snapshot: snapshot(),
      );
      expect(stored('p1'), {
        'name': 'Home',
        'rows': {
          'codex': {
            'state': 'ok',
            'fetchedAt': now.millisecondsSinceEpoch,
            'windows': [
              {
                'seconds': 18000,
                'left': 62,
                'resetsAt': now.millisecondsSinceEpoch + 3 * 3600 * 1000,
              },
            ],
          },
        },
      });
      expect(redraws, 1);
      // The same numbers do not redraw again.
      await widget.record(
        profileId: 'p1',
        profileName: 'Home',
        snapshot: snapshot(),
      );
      expect(redraws, 1);
    },
  );

  test('keeps several providers of one server in one entry', () async {
    await widget.record(
      profileId: 'p1',
      profileName: 'Home',
      snapshot: snapshot(),
    );
    await widget.record(
      profileId: 'p1',
      profileName: 'Home',
      snapshot: snapshot(provider: QuotaProvider.minimax, used: 10),
    );
    final rows = stored('p1')['rows'] as Map;
    expect(rows.keys, containsAll(['codex', 'minimax']));
  });

  test('stores no account, plan, address, credential or error text', () async {
    await widget.record(
      profileId: 'p1',
      profileName: 'Home',
      snapshot: snapshot(),
    );
    final raw = prefs.getString(UsageWidgetSnapshot.key('p1'))!;
    expect(raw, isNot(contains('a' * 64)));
    expect(raw, isNot(contains('plus')));
    expect(raw, isNot(contains('http')));
    expect(raw, isNot(contains('ref')));
    expect(raw, isNot(contains('primary')));
  });

  test('Claude and unusable snapshots never appear', () async {
    await widget.record(
      profileId: 'p1',
      profileName: 'Home',
      snapshot: snapshot(provider: QuotaProvider.claude),
    );
    await widget.record(
      profileId: 'p1',
      profileName: 'Home',
      snapshot: snapshot(unverified: true),
    );
    expect(prefs.getString(UsageWidgetSnapshot.key('p1')), isNull);
    expect(redraws, 0);
    await widget.markAuthNeeded(
      profileId: 'p1',
      profileName: 'Home',
      provider: QuotaProvider.claude,
    );
    expect(prefs.getString(UsageWidgetSnapshot.key('p1')), isNull);
  });

  test('auth-needed keeps the numbers and flags the row', () async {
    await widget.record(
      profileId: 'p1',
      profileName: 'Home',
      snapshot: snapshot(),
    );
    await widget.markAuthNeeded(
      profileId: 'p1',
      profileName: 'Home',
      provider: QuotaProvider.codex,
    );
    final row = (stored('p1')['rows'] as Map)['codex'] as Map;
    expect(row['state'], 'auth');
    expect(row['fetchedAt'], now.millisecondsSinceEpoch);
    expect((row['windows'] as List).single['left'], 62);
    // A fresh measurement clears the flag.
    await widget.record(
      profileId: 'p1',
      profileName: 'Home',
      snapshot: snapshot(used: 40),
    );
    expect(((stored('p1')['rows'] as Map)['codex'] as Map)['state'], 'ok');
  });

  test('removing the last provider removes the entry', () async {
    await widget.record(
      profileId: 'p1',
      profileName: 'Home',
      snapshot: snapshot(),
    );
    await widget.removeProvider(profileId: 'p1', provider: QuotaProvider.codex);
    expect(prefs.getString(UsageWidgetSnapshot.key('p1')), isNull);
  });

  test('is inert off Android', () async {
    final other = UsageWidgetSnapshot(prefs: prefs, isAndroid: false);
    await other.record(
      profileId: 'p1',
      profileName: 'Home',
      snapshot: snapshot(),
    );
    expect(prefs.getKeys(), isEmpty);
  });

  test('the profile deletion sweep and clearForProfile remove it', () async {
    final store = _Store(prefs);
    await widget.record(
      profileId: 'p1',
      profileName: 'Home',
      snapshot: snapshot(),
    );
    await widget.record(
      profileId: 'p2',
      profileName: 'Other',
      snapshot: snapshot(),
    );
    expect(store.profileScopedPreferenceKeys('p1'), {
      UsageWidgetSnapshot.key('p1'),
    });
    expect(await store.removeScopedPreferences('p1'), isEmpty);
    expect(prefs.getString(UsageWidgetSnapshot.key('p1')), isNull);
    expect(prefs.getString(UsageWidgetSnapshot.key('p2')), isNotNull);
    redraws = 0;
    expect(await widget.clearForProfile('p2'), isTrue);
    expect(prefs.getString(UsageWidgetSnapshot.key('p2')), isNull);
    expect(redraws, 1);
  });

  test('not-signed-in writes a row with the way in and no numbers', () async {
    await widget.markNotSignedIn(
      profileId: 'p1',
      profileName: 'Home',
      providerId: 'glm',
    );
    final row = (stored('p1')['rows'] as Map)['glm'] as Map;
    expect(row['state'], 'signin');
    expect(row['action'], 'add_key');
    expect(row['windows'], isEmpty);
    await widget.markNotSignedIn(
      profileId: 'p1',
      profileName: 'Home',
      providerId: 'codex',
    );
    expect(
      (((stored('p1')['rows'] as Map)['codex']) as Map)['action'],
      'sign_in',
    );
    // Numbers arriving replace the row, target and all.
    await widget.record(
      profileId: 'p1',
      profileName: 'Home',
      snapshot: snapshot(),
    );
    final ok = (stored('p1')['rows'] as Map)['codex'] as Map;
    expect(ok['state'], 'ok');
    expect(ok.containsKey('action'), isFalse);
    // The server's data goes away as a whole.
    expect(await widget.clearForProfile('p1'), isTrue);
    expect(prefs.getString(UsageWidgetSnapshot.key('p1')), isNull);
  });

  test('not-signed-in keeps the numbers of a row that has them', () async {
    await widget.record(
      profileId: 'p1',
      profileName: 'Home',
      snapshot: snapshot(),
    );
    await widget.markNotSignedIn(
      profileId: 'p1',
      profileName: 'Home',
      providerId: 'codex',
    );
    final row = (stored('p1')['rows'] as Map)['codex'] as Map;
    expect(row['state'], 'ok');
    expect(row['windows'], isNotEmpty);
  });

  test('an expired sign-in with no row yet still gets a tap target', () async {
    await widget.markAuthNeeded(
      profileId: 'p1',
      profileName: 'Home',
      provider: QuotaProvider.codex,
    );
    final row = (stored('p1')['rows'] as Map)['codex'] as Map;
    expect(row['state'], 'auth');
    expect(row['action'], 'sign_in');
    expect(row['windows'], isEmpty);
  });

  group('through the quota monitor', () {
    late _Store store;
    late ProviderQuotaMonitor monitor;
    late Future<ProviderQuotaSnapshot> Function() read;

    setUp(() async {
      store = _Store(prefs);
      store.entries.add(
        ServerProfile(
          id: 'p1',
          name: 'Home',
          baseUrl: 'https://p1.example',
          username: 'fixture',
          password: 'private-fixture-password',
        ),
      );
      final first = snapshot();
      read = () async => first;
      monitor = ProviderQuotaMonitor(
        store: store,
        widget: widget,
        createGateway: (profile, provider) => _Gateway(() => read()),
        isReadable: (id) => id == 'p1',
        networkWifi: () async => true,
        alert: ({required profileID, required key, required token}) async =>
            true,
        dismiss: (key) async => true,
        clock: () => now,
      );
      addTearDown(monitor.dispose);
      expect(await monitor.enroll('p1', first, notifications: false), isTrue);
    });

    test('a fresh read is written, never the password or address', () async {
      await monitor.refresh();
      await pumpEventQueue();
      final raw = prefs.getString(UsageWidgetSnapshot.key('p1'))!;
      expect(stored('p1')['name'], 'Home');
      expect(raw, isNot(contains('private-fixture-password')));
      expect(raw, isNot(contains('example')));
      expect(((stored('p1')['rows'] as Map)['codex'] as Map)['state'], 'ok');
    });

    test('a collector sign-in failure flags the row', () async {
      await monitor.refresh();
      await pumpEventQueue();
      read = () async =>
          throw const ProviderQuotaFailure(QuotaFailureKind.collectorAuth);
      await monitor.refresh();
      await pumpEventQueue();
      expect(((stored('p1')['rows'] as Map)['codex'] as Map)['state'], 'auth');
    });

    test('signed out where it is read: the row offers the way in', () async {
      await monitor.refresh();
      await pumpEventQueue();
      final data = providerQuotaFixture(
        fetchedAtMs: now.millisecondsSinceEpoch,
      );
      data
        ..['status'] = 'unconfigured'
        ..['freshness'] = 'none'
        ..['windows'] = <Object?>[]
        ..['ordinaryUsageAllowed'] = null;
      (data['account'] as Map)
        ..['status'] = 'unverified'
        ..remove('ref')
        ..remove('plan');
      final signedOut = ProviderQuotaSnapshot.fromJson(data);
      read = () async => signedOut;
      await monitor.refresh();
      await pumpEventQueue();
      final row = (stored('p1')['rows'] as Map)['codex'] as Map;
      // The earlier numbers stay; only a row without numbers changes state.
      expect(row['state'], 'ok');
      await widget.removeProvider(
        profileId: 'p1',
        provider: QuotaProvider.codex,
      );
      await monitor.refresh();
      await pumpEventQueue();
      final offered = (stored('p1')['rows'] as Map)['codex'] as Map;
      expect(offered['state'], 'signin');
      expect(offered['action'], 'sign_in');
      read = () async => snapshot();
      await monitor.refresh();
      await pumpEventQueue();
      expect(((stored('p1')['rows'] as Map)['codex'] as Map)['state'], 'ok');
    });

    test('disabling monitoring and removing the server clear it', () async {
      await monitor.refresh();
      await pumpEventQueue();
      expect(await monitor.disable('p1', QuotaProvider.codex), isTrue);
      expect(prefs.getString(UsageWidgetSnapshot.key('p1')), isNull);
      await monitor.refresh();
      await widget.record(
        profileId: 'p1',
        profileName: 'Home',
        snapshot: snapshot(),
      );
      monitor.removeProfile('p1');
      await pumpEventQueue();
      expect(prefs.getString(UsageWidgetSnapshot.key('p1')), isNull);
    });
  });
}
