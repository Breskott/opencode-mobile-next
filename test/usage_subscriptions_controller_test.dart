import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/background/usage_widget_snapshot.dart';
import 'package:opencode_mobile/demo/demo_store.dart';
import 'package:opencode_mobile/domain/provider_quota.dart';
import 'package:opencode_mobile/domain/usage_subscriptions.dart';
import 'package:opencode_mobile/state/notification_preferences.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/provider_quota_monitor.dart';
import 'package:opencode_mobile/state/usage_subscription_sources.dart';
import 'package:opencode_mobile/state/usage_subscriptions_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_quota_test.dart' show providerQuotaFixture;

final _now = DateTime.utc(2026, 10, 13, 12);

const _inApp = UsageConnection(
  id: 'inapp',
  name: 'In-app Ubuntu',
  kind: UsageConnectionKind.inAppUbuntu,
);
const _pc = UsageConnection(
  id: 'pc',
  name: 'PC',
  kind: UsageConnectionKind.openCodeServer,
);

UsageWindow _w(String id, double used, int seconds, {Duration? resetIn}) =>
    UsageWindow(
      id: id,
      usedPercent: used,
      durationSeconds: seconds,
      resetsAt: _now.add(resetIn ?? const Duration(hours: 2)),
    );

UsageReading _reading(
  String provider,
  String connection, {
  String? account,
  double five = 20,
  double week = 40,
  Duration age = const Duration(minutes: 1),
  UsageReadingStatus status = UsageReadingStatus.ok,
}) => UsageReading(
  providerId: provider,
  displayName: provider,
  connectionId: connection,
  status: status,
  fetchedAt: _now.subtract(age),
  accountRef: account,
  windows: status == UsageReadingStatus.ok
      ? [_w('primary', five, 18000), _w('secondary', week, 604800)]
      : const [],
);

class _Source implements UsageSource {
  _Source(this.results);
  List<UsageSourceResult> results;
  int calls = 0;
  bool throwNext = false;
  @override
  Future<UsageSourceResult> read(UsageReadContext context) async {
    calls++;
    if (throwNext) throw StateError('private-source-failure');
    return results[(calls - 1).clamp(0, results.length - 1)];
  }
}

class _Bridge implements UsageAlertBridge {
  List<LegacyQuotaRule> legacy = const [];
  List<QuotaWatch> lastWanted = const [];
  bool? lastAlertsOn;
  @override
  List<LegacyQuotaRule> legacyRules() => legacy;
  @override
  Future<void> reconcile(
    List<QuotaWatch> wanted, {
    required bool alertsOn,
  }) async {
    lastWanted = wanted;
    lastAlertsOn = alertsOn;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late List<UsageConnection> connections;
  late SharedNotifyRules rules;
  late _Bridge bridge;
  late int nativeRefreshes;
  late DateTime clockNow;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    connections = [_inApp, _pc];
    rules = const SharedNotifyRules();
    bridge = _Bridge();
    nativeRefreshes = 0;
    clockNow = _now;
  });

  UsageSubscriptionsController make(
    List<UsageSource> sources, {
    bool bridged = true,
  }) {
    final controller = UsageSubscriptionsController(
      prefs: prefs,
      connections: () => connections,
      sources: sources,
      sharedRules: () => rules,
      setQuotaAlerts: (value) async =>
          rules = rules.copyWith(quotaAlerts: value),
      alertBridge: bridged ? bridge : null,
      widget: UsageWidgetSnapshot(
        prefs: prefs,
        isAndroid: true,
        refreshNative: () async => nativeRefreshes++,
      ),
      clock: () => clockNow,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  UsageSourceResult ok(List<UsageReading> readings) =>
      UsageSourceResult(readings: readings);

  test('one refresh gathers every source into a single list', () async {
    final a = _Source([
      ok([_reading('codex', 'inapp', account: 'a')]),
    ]);
    final b = _Source([
      ok([
        _reading('claude', 'pc'),
        _reading('codex', 'pc', account: 'a', age: const Duration(minutes: 30)),
      ]),
    ]);
    final c = make([a, b]);
    expect(c.snapshot.loaded, isFalse);
    await c.refresh();
    expect(c.snapshot.loaded, isTrue);
    expect(c.snapshot.subscriptions.map((s) => s.providerId).toSet(), {
      'codex',
      'claude',
    });
    final codex = c.snapshot.subscriptions.firstWhere(
      (s) => s.providerId == 'codex',
    );
    expect(codex.signedInOn, hasLength(2));
    expect(codex.readFrom, _inApp);
  });

  test('a source that throws is ignored and the others still show', () async {
    final bad = _Source([const UsageSourceResult()])..throwNext = true;
    final good = _Source([
      ok([_reading('codex', 'inapp', account: 'a')]),
    ]);
    final c = make([bad, good]);
    await c.refresh();
    expect(c.snapshot.subscriptions, hasLength(1));
  });

  test('numbers survive a restart and show before the first refresh', () async {
    final first = make([
      _Source([
        ok([_reading('codex', 'pc', account: 'a')]),
      ]),
    ]);
    await first.refresh();
    expect(prefs.getString('oc.usageLast.pc'), isNotNull);
    // Nothing private is stored with the numbers.
    expect(prefs.getString('oc.usageLast.pc'), isNot(contains('token')));

    final second = make([
      _Source([const UsageSourceResult()]),
    ]);
    expect(second.snapshot.loaded, isFalse);
    expect(second.snapshot.subscriptions.single.providerId, 'codex');
    expect(second.snapshot.subscriptions.single.windows, hasLength(2));
  });

  test(
    'an unreachable connection keeps its numbers as offlineStale, then recovers',
    () async {
      final source = _Source([
        ok([_reading('codex', 'pc', account: 'a')]),
        const UsageSourceResult(unreached: {'pc'}),
        ok([_reading('codex', 'pc', account: 'a')]),
      ]);
      final c = make([source]);
      await c.refresh();
      expect(c.snapshot.subscriptions.single.state, SubscriptionState.ok);
      await c.refresh();
      var s = c.snapshot.subscriptions.single;
      expect(s.state, SubscriptionState.offlineStale);
      expect(s.windows, isNotEmpty);
      expect(s.signedInOn.single.online, isFalse);
      // U8: unreachable is unknown, not "not signed in".
      expect(
        c.snapshot.isOffline(c.connections().firstWhere((x) => x.id == 'pc')),
        isTrue,
      );
      expect(
        c.snapshot.hasAnswered(c.connections().firstWhere((x) => x.id == 'pc')),
        isFalse,
      );
      await c.refresh();
      expect(
        c.snapshot.isOffline(c.connections().firstWhere((x) => x.id == 'pc')),
        isFalse,
      );
      s = c.snapshot.subscriptions.single;
      expect(s.state, SubscriptionState.ok);
    },
  );

  test(
    'rate limited keeps the last numbers; a broken reader says so',
    () async {
      final source = _Source([
        ok([_reading('codex', 'inapp', account: 'a')]),
        const UsageSourceResult(
          failures: [UsageFailure('inapp', 'codex', UsageProblem.rateLimited)],
        ),
        const UsageSourceResult(
          failures: [UsageFailure('inapp', 'codex', UsageProblem.broken)],
        ),
      ]);
      final c = make([source]);
      await c.refresh();
      await c.refresh();
      expect(c.snapshot.subscriptions.single.state, SubscriptionState.ok);
      expect(c.snapshot.subscriptions.single.windows, isNotEmpty);
      await c.refresh();
      expect(
        c.snapshot.subscriptions.single.state,
        SubscriptionState.readerBroken,
      );
      expect(c.snapshot.subscriptions.single.fix, UsageFix.tryAgain);
    },
  );

  test('an older reading never replaces a newer one', () async {
    final source = _Source([
      ok([_reading('codex', 'inapp', account: 'a', five: 10)]),
      ok([
        _reading(
          'codex',
          'inapp',
          account: 'a',
          five: 90,
          age: const Duration(hours: 2),
        ),
      ]),
    ]);
    final c = make([source]);
    await c.refresh();
    await c.refresh();
    expect(c.snapshot.subscriptions.single.fiveHour!.usedPercent, 10);
  });

  test(
    'sign-ins with no reader show cantReadYet; a signed-out cached plan flips',
    () async {
      final source = _Source([
        UsageSourceResult(
          signIns: const [
            UsageSignIn(
              providerId: 'codex',
              connectionId: 'pc',
              displayName: 'Codex',
            ),
          ],
          authoritativeSignIns: const {'pc'},
        ),
        const UsageSourceResult(signIns: [], authoritativeSignIns: {'pc'}),
      ]);
      final c = make([source]);
      await c.refresh();
      expect(
        c.snapshot.subscriptions.single.state,
        SubscriptionState.cantReadYet,
      );
      expect(c.snapshot.subscriptions.single.fixConnection, _pc);
      // The sign-in is gone and nothing was ever read: nothing to keep.
      await c.refresh();
      expect(c.snapshot.subscriptions, isEmpty);
      expect(c.snapshot.addable, contains('codex'));
    },
  );

  test(
    'a plan that was read and then disappears from the server stays as not signed in',
    () async {
      final source = _Source([
        ok([_reading('codex', 'pc', account: 'a')]),
        const UsageSourceResult(signIns: [], authoritativeSignIns: {'pc'}),
      ]);
      final c = make([source]);
      await c.refresh();
      await c.refresh();
      final s = c.snapshot.subscriptions.single;
      expect(s.state, SubscriptionState.notSignedIn);
      expect(s.fix, UsageFix.signIn);
    },
  );

  test(
    'a removed profile loses its cache, its overrides and its widget rows',
    () async {
      final source = _Source([
        ok([
          _reading('codex', 'pc', account: 'a'),
          _reading('codex', 'inapp', account: 'b'),
        ]),
      ]);
      final c = make([source]);
      await c.refresh();
      final pcKey = usageSubscriptionKey('codex', 'a', 'pc');
      final keepKey = usageSubscriptionKey('codex', 'b', 'inapp');
      await c.setThresholdFor(pcKey, 95);
      await c.setThresholdFor(keepKey, 90);
      connections = [_inApp];
      c.removeProfile('pc');
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString('oc.usageLast.pc'), isNull);
      expect(c.snapshot.subscriptions.single.accountRef, 'b');
      final blob =
          jsonDecode(prefs.getString(UsageSubscriptionsController.alertsKey)!)
              as Map;
      expect((blob['overrides'] as Map).keys, [keepKey]);
      final feed = jsonDecode(prefs.getString('oc.widgetUsageSubs')!) as Map;
      expect((feed['entries'] as List).single['key'], keepKey);
    },
  );

  test(
    'the profile deletion sweep finds the cached numbers by their key',
    () async {
      final c = make([
        _Source([
          ok([_reading('codex', 'pc', account: 'a')]),
        ]),
      ]);
      await c.refresh();
      final store = ProfileStore(prefs: prefs);
      expect(
        store.profileScopedPreferenceKeys('pc'),
        contains(UsageSubscriptionsController.lastKey('pc')),
      );
      expect(store.profileScopedPreferenceKeys('inapp'), isEmpty);
    },
  );

  group('alerts', () {
    test(
      'every readable subscription is watched at 80 with no enrolment step',
      () async {
        final c = make([
          _Source([
            ok([
              _reading('codex', 'inapp', account: 'a'),
              _reading('glm', 'inapp', account: 'g'),
            ]),
          ]),
        ]);
        await c.refresh();
        expect(c.defaultThreshold, 80);
        expect(bridge.lastWanted.map((w) => w.threshold).toSet(), {80});
        expect(bridge.lastWanted.map((w) => w.providerId).toSet(), {
          'codex',
          'glm',
        });
        expect(bridge.lastAlertsOn, isFalse);
        await c.setAlertsOn(true);
        expect(c.alertsOn, isTrue);
        expect(rules.quotaAlerts, isTrue);
        expect(bridge.lastAlertsOn, isTrue);
      },
    );

    test(
      'a per-subscription override changes only that watch and persists',
      () async {
        final source = _Source([
          ok([
            _reading('codex', 'inapp', account: 'a'),
            _reading('glm', 'inapp', account: 'g'),
          ]),
        ]);
        final c = make([source]);
        await c.refresh();
        final key = usageSubscriptionKey('codex', 'a', 'inapp');
        expect(await c.setThresholdFor(key, 90), isTrue);
        expect(
          bridge.lastWanted
              .firstWhere((w) => w.providerId == 'codex')
              .threshold,
          90,
        );
        expect(
          bridge.lastWanted.firstWhere((w) => w.providerId == 'glm').threshold,
          80,
        );
        expect(c.alertOverrides.single.providerId, 'codex');

        final again = make([source]);
        expect(again.subscription(key)!.alertThreshold, 90);
        expect(await c.setThresholdFor(key, null), isTrue);
        expect(c.alertOverrides, isEmpty);
      },
    );

    test('bad levels are refused and change nothing', () async {
      final c = make([
        _Source([const UsageSourceResult()]),
      ]);
      expect(await c.setDefaultThreshold(0), isFalse);
      expect(await c.setDefaultThreshold(101), isFalse);
      expect(await c.setDefaultThreshold(double.nan), isFalse);
      expect(await c.setThresholdFor('codex|a', 150), isFalse);
      expect(c.defaultThreshold, 80);
    });

    test(
      'the default level moves every subscription without an override',
      () async {
        final c = make([
          _Source([
            ok([_reading('codex', 'inapp', account: 'a', five: 70)]),
          ]),
        ]);
        await c.refresh();
        expect(c.snapshot.subscriptions.single.state, SubscriptionState.ok);
        await c.setDefaultThreshold(60);
        expect(
          c.snapshot.subscriptions.single.state,
          SubscriptionState.nearLimit,
        );
        expect(bridge.lastWanted.single.threshold, 60);
      },
    );

    test(
      '"tell me when it resets" is off by default and per subscription',
      () async {
        final c = make([
          _Source([
            ok([_reading('codex', 'inapp', account: 'a')]),
          ]),
        ]);
        await c.refresh();
        final key = usageSubscriptionKey('codex', 'a', 'inapp');
        expect(c.notifyOnResetDefault, isFalse);
        expect(c.subscription(key)!.notifyOnReset, isFalse);
        await c.setNotifyOnReset(key, true);
        expect(c.subscription(key)!.notifyOnReset, isTrue);
        expect(c.subscription(key)!.hasAlertOverride, isFalse);
      },
    );

    test(
      'migration keeps a chosen threshold from the old per-source rules, once',
      () async {
        bridge.legacy = const [
          LegacyQuotaRule(
            connectionId: 'inapp',
            providerId: 'codex',
            accountRef: 'a',
            threshold: 90,
          ),
          LegacyQuotaRule(
            connectionId: 'inapp',
            providerId: 'glm',
            accountRef: 'g',
            threshold: 80,
          ),
          LegacyQuotaRule(
            connectionId: 'pc',
            providerId: 'codex',
            accountRef: 'z',
            threshold: 100,
          ),
        ];
        final source = _Source([
          ok([
            _reading('codex', 'inapp', account: 'a'),
            _reading('glm', 'inapp', account: 'g'),
            _reading('codex', 'pc', account: 'z'),
          ]),
        ]);
        final c = make([source]);
        await c.refresh();
        expect(
          c
              .subscription(usageSubscriptionKey('codex', 'a', 'inapp'))!
              .alertThreshold,
          90,
        );
        expect(
          c
              .subscription(usageSubscriptionKey('glm', 'g', 'inapp'))!
              .hasAlertOverride,
          isFalse,
        );
        expect(
          c
              .subscription(usageSubscriptionKey('codex', 'z', 'pc'))!
              .alertThreshold,
          100,
        );
        // A rule that appears later is not migrated again.
        bridge.legacy = const [
          LegacyQuotaRule(
            connectionId: 'inapp',
            providerId: 'glm',
            accountRef: 'g',
            threshold: 50,
          ),
        ];
        final next = make([source]);
        await next.refresh();
        expect(
          next
              .subscription(usageSubscriptionKey('glm', 'g', 'inapp'))!
              .hasAlertOverride,
          isFalse,
        );
      },
    );
  });

  group('widget feed', () {
    Future<Map<String, dynamic>> feed(UsageSubscriptionsController c) async {
      await c.refresh();
      return jsonDecode(prefs.getString('oc.widgetUsageSubs')!)
          as Map<String, dynamic>;
    }

    test(
      'one entry per subscription in page order, each with both windows',
      () async {
        final c = make([
          _Source([
            ok([
              _reading('codex', 'inapp', account: 'a', five: 82, week: 41),
              _reading('claude', 'pc', five: 22, week: 35),
            ]),
          ]),
        ]);
        final doc = await feed(c);
        final entries = (doc['entries'] as List).cast<Map<String, dynamic>>();
        expect(entries.map((e) => e['provider']), ['codex', 'claude']);
        expect(entries.first['state'], 'near');
        final windows = (entries.first['windows'] as List).cast<Map>();
        expect(windows.map((w) => w['seconds']), [18000, 604800]);
        expect(windows.map((w) => w['left']), [18, 59]);
        expect(entries.toString(), isNot(contains('"a"')));
      },
    );

    test('rows that need setup show by default and can be hidden', () async {
      final source = _Source([
        UsageSourceResult(
          readings: [_reading('codex', 'inapp', account: 'a')],
          signIns: const [
            UsageSignIn(
              providerId: 'glm',
              connectionId: 'pc',
              displayName: 'GLM',
            ),
          ],
          authoritativeSignIns: const {'pc'},
        ),
      ]);
      final c = make([source]);
      var doc = await feed(c);
      var entries = (doc['entries'] as List).cast<Map<String, dynamic>>();
      final setup = entries.singleWhere((e) => e['provider'] == 'glm');
      expect(setup['state'], 'setup');
      expect(setup['action'], 'set_up');
      expect(setup['profileId'], 'pc');
      expect(setup['windows'], isEmpty);

      await c.setWidgetSettings(
        const UsageWidgetSettings(showSetupRows: false),
      );
      doc =
          jsonDecode(prefs.getString('oc.widgetUsageSubs')!)
              as Map<String, dynamic>;
      entries = (doc['entries'] as List).cast<Map<String, dynamic>>();
      expect(entries.map((e) => e['provider']), ['codex']);
      // The choice survives a restart.
      expect(make([source]).widgetSettings.showSetupRows, isFalse);
    });

    test('hidden subscriptions and the window choice apply', () async {
      final c = make([
        _Source([
          ok([
            _reading('codex', 'inapp', account: 'a'),
            _reading('claude', 'pc'),
          ]),
        ]),
      ]);
      await c.refresh();
      await c.setWidgetSettings(
        UsageWidgetSettings(
          hiddenKeys: {usageSubscriptionKey('claude', null, 'pc')},
          windows: UsageWidgetWindows.weekly,
        ),
      );
      final doc = jsonDecode(prefs.getString('oc.widgetUsageSubs')!) as Map;
      final entries = (doc['entries'] as List).cast<Map>();
      expect(entries.map((e) => e['provider']), ['codex']);
      expect((entries.single['windows'] as List).single['seconds'], 604800);
    });

    test(
      'sign-in rows carry the key or sign-in action and the fixing connection',
      () async {
        final c = make([
          _Source([
            ok([
              _reading('glm', 'pc', status: UsageReadingStatus.notSignedIn),
              _reading('claude', 'pc', status: UsageReadingStatus.notSignedIn),
            ]),
          ]),
        ]);
        final doc = await feed(c);
        final byProvider = {
          for (final e in (doc['entries'] as List).cast<Map>())
            e['provider']: e,
        };
        expect(byProvider['glm']!['action'], 'add_key');
        expect(byProvider['claude']!['action'], 'sign_in');
        expect(byProvider['claude']!['state'], 'signin');
        expect(byProvider['claude']!['profileId'], 'pc');
      },
    );

    test('an offline plan is labelled stale in the feed', () async {
      final c = make([
        _Source([
          ok([_reading('codex', 'pc', account: 'a')]),
          const UsageSourceResult(unreached: {'pc'}),
        ]),
      ]);
      await c.refresh();
      final doc = await feed(c);
      expect((doc['entries'] as List).single['state'], 'stale');
    });
  });

  group('the collector source and the alert bridge', () {
    late DemoPreferences memory;
    late _MemStore store;
    late ProviderQuotaMonitor monitor;
    late Map<String, Object> reply;
    late List<String> reads;

    ProviderQuotaSnapshot snap({
      QuotaProvider provider = QuotaProvider.codex,
      String account = 'a',
      double used = 25,
    }) {
      final data = providerQuotaFixture(
        provider: provider,
        fetchedAtMs: _now.millisecondsSinceEpoch,
      );
      (data['account'] as Map)['ref'] = account * 64;
      ((data['windows'] as List).first as Map)['usedPercent'] = used;
      return ProviderQuotaSnapshot.fromJson(data);
    }

    QuotaCollectorSource make0({Set<String> inApp = const {'inapp'}}) =>
        QuotaCollectorSource(
          profiles: () => store.entries,
          isReadable: (id) => store.entries.any((p) => p.id == id),
          isInApp: (p) => p.id == 'inapp',
          inAppEnabled: (id) => inApp.contains(id),
          createGateway: (profile, provider) {
            reads.add('${profile.id}:${provider.name}');
            return _QGateway(() async {
              final r = reply['${profile.id}:${provider.name}'];
              if (r is ProviderQuotaFailure) throw r;
              if (r is ProviderQuotaSnapshot) return r;
              throw const ProviderQuotaFailure(QuotaFailureKind.unavailable);
            });
          },
          monitor: monitor,
          sharedRules: () => rules,
        );

    setUp(() {
      memory = DemoPreferences();
      store = _MemStore(memory);
      for (final id in ['inapp', 'pc']) {
        store.entries.add(
          ServerProfile(
            id: id,
            name: id,
            baseUrl: 'https://$id.example',
            username: 'u',
            password: 'p',
          ),
        );
      }
      reads = [];
      reply = {};
      monitor = ProviderQuotaMonitor(
        store: store,
        createGateway: (_, _) => throw StateError('the monitor must not read'),
        isReadable: (id) => store.entries.any((p) => p.id == id),
        networkWifi: () async => true,
        alert: ({required profileID, required key, required token}) async =>
            true,
        dismiss: (_) async => true,
        clock: () => _now,
      );
      addTearDown(monitor.dispose);
    });

    UsageReadContext context({bool force = true}) =>
        UsageReadContext(connections: connections, now: _now, force: force);

    test(
      'In-app Ubuntu is read for every provider; a remote one only when consented',
      () async {
        reply = {
          'inapp:codex': snap(),
          'inapp:glm': snap(provider: QuotaProvider.glm, account: 'c'),
        };
        final result = await make0().read(context());
        expect(reads, ['inapp:codex', 'inapp:minimax', 'inapp:glm']);
        expect(reads.where((r) => r.startsWith('pc')), isEmpty);
        final codex = result.readings.firstWhere(
          (r) => r.providerId == 'codex',
        );
        expect(codex.status, UsageReadingStatus.ok);
        expect(codex.accountRef, 'a' * 64);
        expect(codex.plan, 'plus');
        expect(codex.windows.single.usedPercent, 25);
        // MiniMax answered "unavailable" on an In-app reader: broken, not offline.
        expect(
          result.failures.map((f) => '${f.providerId}:${f.problem.name}'),
          ['minimax:broken'],
        );
        expect(result.unreached, isEmpty);
      },
    );

    test(
      'a remote collector that cannot be reached marks the connection offline',
      () async {
        final snapshot = snap();
        await monitor.enroll(
          'pc',
          snapshot,
          notifications: false,
          threshold: 80,
        );
        final result = await make0().read(context());
        expect(reads, contains('pc:codex'));
        expect(result.unreached, {'pc'});
      },
    );

    test(
      'an expired collector sign-in is authRequired; signed out is kept only if used before',
      () async {
        reply = {
          'inapp:codex': const ProviderQuotaFailure(
            QuotaFailureKind.collectorAuth,
          ),
        };
        var result = await make0().read(context());
        expect(result.readings.single.status, UsageReadingStatus.authRequired);
        reply = {};
        result = await make0().read(
          UsageReadContext(
            connections: connections,
            now: _now,
            force: true,
            lastReading: (c, p) =>
                p == 'glm' ? _reading('glm', 'inapp', account: 'g') : null,
          ),
        );
        expect(result.readings, isEmpty);
      },
    );

    test(
      'rate limited by the provider is a problem, not an error state',
      () async {
        final json = providerQuotaFixture(
          fetchedAtMs: _now.millisecondsSinceEpoch,
        );
        json['status'] = 'rateLimited';
        json['windows'] = <Object?>[];
        json['ordinaryUsageAllowed'] = null;
        (json['account'] as Map)
          ..['status'] = 'unverified'
          ..remove('ref');
        reply = {'inapp:codex': ProviderQuotaSnapshot.fromJson(json)};
        final result = await make0().read(context());
        expect(
          result.failures.any(
            (f) =>
                f.providerId == 'codex' &&
                f.problem == UsageProblem.rateLimited,
          ),
          isTrue,
        );
      },
    );

    test(
      'alerts: In-app readings are enrolled at the effective level without a step',
      () async {
        reply = {'inapp:codex': snap(account: 'a')};
        final source = make0();
        await source.read(context());
        rules = rules.copyWith(quotaAlerts: true);
        await source.reconcile(const [
          QuotaWatch(connectionId: 'inapp', providerId: 'codex', threshold: 80),
        ], alertsOn: true);
        final enrolled = monitor.rulesFor('inapp', QuotaProvider.codex)!;
        expect(enrolled.threshold, 80);
        expect(enrolled.notifications, isTrue);
        expect(enrolled.account, 'a' * 64);

        // An override changes the monitor's per-source level.
        await source.reconcile(const [
          QuotaWatch(connectionId: 'inapp', providerId: 'codex', threshold: 92),
        ], alertsOn: true);
        expect(monitor.rulesFor('inapp', QuotaProvider.codex)!.threshold, 92);
        expect(source.legacyRules().single.threshold, 92);
      },
    );

    test(
      'alerts off: nothing is enrolled, remote collectors are never auto-enrolled',
      () async {
        reply = {'inapp:codex': snap(), 'pc:codex': snap(account: 'b')};
        final source = make0();
        await source.read(context());
        await source.reconcile(const [
          QuotaWatch(connectionId: 'inapp', providerId: 'codex', threshold: 80),
        ], alertsOn: false);
        expect(monitor.rulesFor('inapp', QuotaProvider.codex), isNull);
        await source.reconcile(const [
          QuotaWatch(connectionId: 'pc', providerId: 'codex', threshold: 80),
        ], alertsOn: true);
        expect(monitor.rulesFor('pc', QuotaProvider.codex), isNull);
      },
    );
  });
}

class _MemStore extends ProfileStore {
  _MemStore(this.memory) : super(prefs: memory);
  final DemoPreferences memory;
  final entries = <ServerProfile>[];
  @override
  List<ServerProfile> get profiles => List.unmodifiable(entries);
}

class _QGateway implements ProviderQuotaGateway {
  _QGateway(this.run);
  final Future<ProviderQuotaSnapshot> Function() run;
  @override
  Future<ProviderQuotaSnapshot> readSnapshot() => run();
  @override
  void close() {}
}
