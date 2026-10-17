import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/background/usage_widget_snapshot.dart';
import 'package:opencode_mobile/domain/provider_usage.dart';
import 'package:opencode_mobile/paseo/provider_usage_gateway.dart';
import 'package:opencode_mobile/paseo/transport.dart';
import 'package:opencode_mobile/state/paseo_usage_monitor.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _bidi = String.fromCharCode(0x202e);
final _now = DateTime.utc(2026, 10, 12, 12);

Map<String, dynamic> _payload() => {
  'requestId': 'm1_1',
  'fetchedAt': _now.toIso8601String(),
  'providers': [
    {
      'providerId': 'claude',
      'displayName': 'Claude',
      'status': 'available',
      'planLabel': 'Max 20x (secret-plan)',
      'sourceLabel': 'oauth: user@example.com',
      'fetchedAt': _now.toIso8601String(),
      'error': null,
      'windows': [
        {
          'id': 'seven_day_opus',
          'label': 'Weekly Opus',
          'usedPct': 10,
          'resetsAt': '2026-10-15T00:00:00Z',
        },
        {
          'id': 'weekly',
          'label': 'Weekly',
          'remainingPct': 70.4,
          'resetsAt': '2026-10-14T00:00:00Z',
        },
        {
          'id': 'five_hour',
          'label': '5 hours',
          'usedPct': 38,
          'resetsAt': '2026-10-12T15:00:00Z',
        },
        {'id': 'no_numbers', 'label': 'Nothing'},
      ],
      'balances': [
        {'id': 'b', 'label': 'x', 'unit': 'usd'},
      ],
      'details': [
        {'id': 'd', 'label': 'x', 'value': 'secret-detail'},
      ],
      'futureField': {'a': 1},
    },
    {
      'providerId': 'zai',
      'displayName': 'Z.ai$_bidi evil\n name that is much too long to print',
      'status': 'available',
      'windows': [
        {'id': 'tokens', 'label': 'Tokens', 'usedPct': 120},
      ],
    },
    {
      'providerId': 'copilot',
      'displayName': 'Copilot',
      'status': 'error',
      'error': 'Bearer sk-secret-token failed',
      'windows': [],
    },
    {'providerId': 'Bad Id!', 'displayName': 'x', 'status': 'available'},
    'junk',
  ],
};

ServerProfile _paseo(String id) => ServerProfile(
  id: id,
  name: 'Desk',
  baseUrl: 'ws://100.64.0.1:6767',
  username: '',
  password: 'private-fixture-password',
  backend: ServerBackend.paseo,
);

class _Transport extends PaseoTransport {
  _Transport(this.reply) : super(endpoint: 'ws://127.0.0.1:6767');
  final Future<Map<String, dynamic>> Function(String type) reply;
  String? sentType;
  int closed = 0;
  @override
  Future<Map<String, dynamic>> request(
    String type,
    Map<String, dynamic> body, {
    bool mutation = false,
    Duration? timeout,
    int? expectedEpoch,
    void Function()? beforeSend,
    void Function(String type, Map<String, dynamic> payload)? onProgress,
    bool answerErrors = false,
  }) {
    sentType = type;
    return reply(type);
  }

  @override
  Future<void> close() async => closed++;
}

class _FakeGateway implements ProviderUsageGateway {
  _FakeGateway(this.run);
  final Future<List<ProviderUsageReading>> Function() run;
  int closed = 0;
  @override
  Future<List<ProviderUsageReading>> read() => run();
  @override
  Future<void> close() async => closed++;
}

class _Store extends ProfileStore {
  _Store(SharedPreferences prefs) : super(prefs: prefs);
  final entries = <ServerProfile>[];
  @override
  List<ServerProfile> get profiles => List.unmodifiable(entries);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parser', () {
    test('keeps numbers, prefers 5-hour then weekly, drops free text', () {
      final readings = parseProviderUsageList(_payload(), now: _now);
      expect(readings.map((r) => r.providerId), ['claude', 'zai']);
      final claude = readings.first;
      expect(claude.displayName, 'Claude');
      expect(claude.windows.map((w) => w.durationSeconds), [
        18000,
        604800,
        null,
      ]);
      expect(claude.windows.map((w) => w.remainingPercent), [62, 70, 90]);
      expect(claude.windows.first.resetsAt, DateTime.utc(2026, 10, 12, 15));
      expect(claude.windows.last.label, 'Weekly Opus');
      final zai = readings.last;
      expect(zai.windows.single.remainingPercent, 0);
      expect(zai.displayName.length, lessThanOrEqualTo(24));
      expect(zai.displayName, isNot(contains(_bidi)));
      expect(zai.displayName, isNot(contains('\n')));
      final dump = readings
          .expand(
            (r) => [
              r.providerId,
              r.displayName,
              ...r.windows.map((w) => w.label),
            ],
          )
          .join('|');
      for (final secret in ['secret', 'Max 20x', 'user@', 'Bearer']) {
        expect(dump, isNot(contains(secret)));
      }
    });

    test('ignores unknown statuses and fields', () {
      final payload = _payload();
      (payload['providers'] as List).add({
        'providerId': 'grok',
        'displayName': 'Grok',
        'status': 'brand-new-status',
        'windows': [
          {'id': 'x', 'label': 'x', 'usedPct': 1},
        ],
      });
      payload['extra'] = 1;
      expect(parseProviderUsageList(payload, now: _now), hasLength(2));
    });

    test('malformed payloads fail without text', () {
      for (final bad in [
        null,
        'text',
        {'providers': 'x'},
        {'error': 'provider_usage_list_failed'},
      ]) {
        expect(
          () => parseProviderUsageList(bad, now: _now),
          throwsA(isA<ProviderUsageFailure>()),
        );
      }
      expect(
        parseProviderUsageList({'providers': <Object>[]}, now: _now),
        isEmpty,
      );
    });

    test('a future fetch time is clamped to now', () {
      final payload = _payload();
      ((payload['providers'] as List).first as Map)['fetchedAt'] =
          '2030-01-01T00:00:00Z';
      expect(parseProviderUsageList(payload, now: _now).first.fetchedAt, _now);
    });
  });

  group('gateway', () {
    test('asks for provider.usage.list and closes', () async {
      final transport = _Transport((_) async => _payload());
      final gateway = PaseoProviderUsageGateway(
        _paseo('p'),
        transport: transport,
        clock: () => _now,
      );
      final readings = await gateway.read();
      await gateway.close();
      expect(transport.sentType, 'provider.usage.list.request');
      expect(readings, hasLength(2));
      expect(transport.closed, 1);
    });

    test(
      'an error reply, a timeout and a dropped link are unavailable',
      () async {
        for (final reply in <Future<Map<String, dynamic>> Function(String)>[
          (_) async => throw PaseoFailure(PaseoFailureKind.unavailable),
          (_) async => throw PaseoFailure(PaseoFailureKind.disconnected),
          (_) => Completer<Map<String, dynamic>>().future.timeout(
            const Duration(milliseconds: 5),
          ),
        ]) {
          final gateway = PaseoProviderUsageGateway(
            _paseo('p'),
            transport: _Transport(reply),
            clock: () => _now,
          );
          await expectLater(
            gateway.read(),
            throwsA(
              isA<ProviderUsageFailure>().having(
                (e) => e.kind,
                'kind',
                ProviderUsageFailureKind.unavailable,
              ),
            ),
          );
        }
      },
    );

    test('a reply that is not a provider list is invalid', () async {
      final gateway = PaseoProviderUsageGateway(
        _paseo('p'),
        transport: _Transport((_) async => {'requestId': 'x'}),
        clock: () => _now,
      );
      await expectLater(
        gateway.read(),
        throwsA(
          isA<ProviderUsageFailure>().having(
            (e) => e.kind,
            'kind',
            ProviderUsageFailureKind.invalidResponse,
          ),
        ),
      );
    });
  });

  group('monitor and widget snapshot', () {
    late SharedPreferences prefs;
    late _Store store;
    late UsageWidgetSnapshot widget;
    late PaseoUsageMonitor monitor;
    late Future<List<ProviderUsageReading>> Function() run;
    late List<_FakeGateway> gateways;
    var redraws = 0;

    Map<String, dynamic> stored(String id) =>
        jsonDecode(prefs.getString(UsageWidgetSnapshot.key(id))!)
            as Map<String, dynamic>;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      store = _Store(prefs)..entries.add(_paseo('p1'));
      store.entries.add(
        ServerProfile(
          id: 'oc',
          name: 'Plain',
          baseUrl: 'https://oc.example',
          username: 'u',
          password: 'p',
        ),
      );
      redraws = 0;
      widget = UsageWidgetSnapshot(
        prefs: prefs,
        isAndroid: true,
        refreshNative: () async => redraws++,
      );
      gateways = [];
      run = () async => parseProviderUsageList(_payload(), now: _now);
      monitor = PaseoUsageMonitor(
        store: store,
        widget: widget,
        createGateway: (profile) {
          final g = _FakeGateway(() => run());
          gateways.add(g);
          return g;
        },
        isReadable: (id) => store.entries.any((p) => p.id == id),
        clock: () => _now,
      );
      addTearDown(monitor.dispose);
    });

    test('is off by default and reads nothing', () async {
      expect(monitor.enabled('p1'), isFalse);
      expect(monitor.statusFor('p1'), PaseoUsageStatus.off);
      monitor.start();
      await monitor.refresh();
      expect(gateways, isEmpty);
      expect(prefs.getKeys(), isEmpty);
    });

    test('only Paseo servers can be switched on', () async {
      expect(monitor.paseoProfiles.map((p) => p.id), ['p1']);
      expect(await monitor.setEnabled('oc', true), isFalse);
      expect(prefs.getBool(PaseoUsageMonitor.key('oc')), isNull);
    });

    test(
      'switching on reads, writes the widget rows and keeps no free text',
      () async {
        expect(await monitor.setEnabled('p1', true), isTrue);
        await monitor.refresh();
        await pumpEventQueue();
        expect(monitor.statusFor('p1'), PaseoUsageStatus.current);
        final doc = stored('p1');
        expect(doc['name'], 'Desk');
        final rows = doc['rows'] as Map;
        expect(rows.keys, containsAll(['claude', 'zai']));
        final claude = rows['claude'] as Map;
        expect(claude['name'], 'Claude');
        expect((claude['windows'] as List).first, {
          'seconds': 18000,
          'left': 62,
          'resetsAt': DateTime.utc(2026, 10, 12, 15).millisecondsSinceEpoch,
        });
        final raw = prefs.getString(UsageWidgetSnapshot.key('p1'))!;
        for (final secret in [
          'secret',
          'Max 20x',
          'example.com',
          'private-fixture-password',
          '100.64',
          'Bearer',
        ]) {
          expect(raw, isNot(contains(secret)));
        }
        expect(gateways.every((g) => g.closed == 1), isTrue);
        expect(redraws, greaterThan(0));
      },
    );

    test('says when it last read and how many providers had numbers', () async {
      expect(monitor.lastReadAt('p1'), isNull);
      await monitor.setEnabled('p1', true);
      await monitor.refresh();
      expect(monitor.lastReadAt('p1'), _now);
      expect(monitor.shownProviders('p1'), greaterThan(0));
      // Signed out: the daemon answers, but with no plan numbers.
      run = () async => const [];
      await monitor.refresh();
      expect(monitor.statusFor('p1'), PaseoUsageStatus.current);
      expect(monitor.shownProviders('p1'), 0);
      await monitor.setEnabled('p1', false);
      expect(monitor.lastReadAt('p1'), isNull);
    });

    test('a failed read keeps the last numbers and says unavailable', () async {
      await monitor.setEnabled('p1', true);
      await monitor.refresh();
      final before = prefs.getString(UsageWidgetSnapshot.key('p1'));
      run = () async => throw const ProviderUsageFailure(
        ProviderUsageFailureKind.unavailable,
      );
      await monitor.refresh();
      expect(monitor.statusFor('p1'), PaseoUsageStatus.unavailable);
      expect(prefs.getString(UsageWidgetSnapshot.key('p1')), before);
    });

    test('providers the daemon stops reporting disappear', () async {
      await monitor.setEnabled('p1', true);
      await monitor.refresh();
      run = () async => parseProviderUsageList({
        'providers': [(_payload()['providers'] as List).first],
      }, now: _now);
      await monitor.refresh();
      expect((stored('p1')['rows'] as Map).keys, ['claude']);
    });

    test(
      'switching off, runtime gating and deletion clear or stop it',
      () async {
        await monitor.setEnabled('p1', true);
        await monitor.refresh();
        monitor.setRuntime(foreground: false, backgroundAllowed: false);
        final reads = gateways.length;
        await monitor.refresh();
        expect(gateways.length, reads);
        expect(monitor.statusFor('p1'), PaseoUsageStatus.paused);
        monitor.setRuntime(foreground: true, backgroundAllowed: false);
        await monitor.refresh();
        expect(await monitor.setEnabled('p1', false), isTrue);
        expect(prefs.getString(UsageWidgetSnapshot.key('p1')), isNull);
        expect(prefs.getBool(PaseoUsageMonitor.key('p1')), isNull);
      },
    );

    test('profile deletion sweeps the opt-in and the snapshot', () async {
      await monitor.setEnabled('p1', true);
      await monitor.refresh();
      expect(store.profileScopedPreferenceKeys('p1'), {
        PaseoUsageMonitor.key('p1'),
        UsageWidgetSnapshot.key('p1'),
      });
      monitor.removeProfile('p1');
      await pumpEventQueue();
      expect(prefs.getString(UsageWidgetSnapshot.key('p1')), isNull);
      expect(monitor.enabled('p1'), isFalse);
      expect(await store.removeScopedPreferences('p1'), isEmpty);
      expect(prefs.getKeys(), isEmpty);
    });
  });
}
