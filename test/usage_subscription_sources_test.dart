import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart'
    show ProviderInfo, ProvidersResponse;
import 'package:opencode_mobile/domain/agent_account.dart';
import 'package:opencode_mobile/domain/provider_usage.dart';
import 'package:opencode_mobile/domain/usage_subscriptions.dart';
import 'package:opencode_mobile/state/paseo_usage_monitor.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/usage_subscription_sources.dart';
import 'package:opencode_mobile/state/usage_subscriptions_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime.utc(2026, 10, 13, 12);

UsageReadContext _context({
  UsageReading? Function(String, String)? lastReading,
}) => UsageReadContext(
  connections: const [],
  now: _now,
  force: true,
  lastReading: lastReading,
);

class _Store extends ProfileStore {
  _Store(SharedPreferences prefs) : super(prefs: prefs);
  final entries = <ServerProfile>[];
  @override
  List<ServerProfile> get profiles => List.unmodifiable(entries);
}

ServerProfile _profile(String id, {ServerBackend? backend}) => ServerProfile(
  id: id,
  name: id,
  baseUrl: 'https://$id.example',
  username: 'u',
  password: 'p',
  backend: backend ?? ServerBackend.openCode,
);

class _Account implements AgentAccountGateway {
  _Account(this.account, {this.buckets = const [], this.fail});
  final AgentAccount account;
  final List<AccountRateBucket> buckets;
  final Object? fail;
  int closed = 0;
  @override
  AgentAccountSession openAccountSession() => _Session(this);
}

class _Session implements AgentAccountSession {
  _Session(this.owner);
  final _Account owner;
  @override
  bool get active => true;
  @override
  bool get supported => true;
  @override
  Stream<AccountEvent> get events => const Stream.empty();
  @override
  Future<AgentAccount> read() async {
    if (owner.fail != null) throw owner.fail!;
    return owner.account;
  }

  @override
  Future<List<AccountRateBucket>> rateLimits() async => owner.buckets;
  @override
  Future<AccountTokenUsage> usage() async => const AccountTokenUsage();
  @override
  Future<AccountDeviceCode> startDeviceLogin() => throw UnimplementedError();
  @override
  Future<bool> cancelLogin() async => true;
  @override
  Future<void> close() async => owner.closed++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Codex account', () {
    const pc = UsageConnection(
      id: 'codex1',
      name: 'Codex',
      kind: UsageConnectionKind.codexServer,
    );

    AgentAccountSource sourceFor(_Account gateway) =>
        AgentAccountSource(current: () => (connection: pc, gateway: gateway));

    test(
      'reads the 5-hour and weekly account limits and hashes the email',
      () async {
        final gateway = _Account(
          const AgentAccount(
            type: 'chatgpt',
            email: 'sam@example.com',
            plan: 'Plus',
            requiresSignIn: false,
          ),
          buckets: [
            AccountRateBucket(
              null,
              AccountRateWindow(37, 300, _now.add(const Duration(hours: 1))),
              AccountRateWindow(12, 10080, _now.add(const Duration(days: 2))),
            ),
          ],
        );
        final result = await sourceFor(gateway).read(_context());
        final r = result.readings.single;
        expect(r.status, UsageReadingStatus.ok);
        expect(r.plan, 'plus');
        expect(r.windows.map((w) => w.kind), [
          UsageWindowKind.fiveHour,
          UsageWindowKind.weekly,
        ]);
        expect(r.accountRef, matches(RegExp(r'^[a-f0-9]{64}$')));
        expect(r.accountRef, isNot(contains('sam')));
        expect(gateway.closed, 1);
      },
    );

    test(
      'an API key account is an apiKey sign-in, never a plan reading',
      () async {
        final result = await sourceFor(
          _Account(const AgentAccount(type: 'apiKey', requiresSignIn: false)),
        ).read(_context());
        expect(result.readings, isEmpty);
        expect(result.signIns.single.method, SignInMethod.apiKey);
        final merged = mergeUsageSubscriptions(
          now: _now,
          connections: const [pc],
          readings: const [],
          signIns: result.signIns,
        );
        expect(merged.subscriptions, isEmpty);
        expect(merged.apiKeyAccounts.single.providerId, 'codex');
      },
    );

    test(
      'signed out is listed only when it needs a sign-in or was used',
      () async {
        const out = AgentAccount(requiresSignIn: true);
        expect(
          (await sourceFor(
            _Account(out),
          ).read(_context())).readings.single.status,
          UsageReadingStatus.notSignedIn,
        );
        expect(
          (await sourceFor(
            _Account(const AgentAccount(requiresSignIn: false)),
          ).read(_context())).readings,
          isEmpty,
        );
      },
    );

    test(
      'a failing session is a broken reader and closes; a dropped link is offline',
      () async {
        final broken = await sourceFor(
          _Account(
            const AgentAccount(requiresSignIn: false),
            fail: StateError('private'),
          ),
        ).read(_context());
        expect(broken.failures.single.problem, UsageProblem.broken);
        final dropped = await sourceFor(
          _Account(
            const AgentAccount(requiresSignIn: false),
            fail: const AgentAccountException(AgentAccountFailure.disconnected),
          ),
        ).read(_context());
        expect(dropped.unreached, {'codex1'});
      },
    );

    test('with no open Codex connection it reads nothing', () async {
      final result = await AgentAccountSource(
        current: () => null,
      ).read(_context());
      expect(result.readings, isEmpty);
      expect(result.unreached, isEmpty);
    });
  });

  group('OpenCode sign-ins', () {
    ProvidersResponse response(List<String> ids) => ProvidersResponse(
      providers: [
        for (final id in ids)
          ProviderInfo(id: id, name: id, modelIDs: const []),
      ],
    );

    test(
      'maps connected providers, ignores non-subscriptions, and is authoritative',
      () async {
        final source = OpenCodeSignInSource(
          profiles: () => [
            _profile('pc'),
            _profile('p1', backend: ServerBackend.paseo),
          ],
          isReadable: (_) => true,
          providers: (profile) async =>
              response(['openai', 'zai-coding-plan', 'openrouter']),
        );
        final result = await source.read(_context());
        expect(result.signIns.map((s) => '${s.connectionId}:${s.providerId}'), [
          'pc:codex',
          'pc:glm',
        ]);
        expect(result.authoritativeSignIns, {'pc'});
        expect(result.signIns.first.displayName, 'Codex');
      },
    );

    test(
      'a server that does not answer is unreached and not authoritative',
      () async {
        final source = OpenCodeSignInSource(
          profiles: () => [_profile('pc')],
          isReadable: (_) => true,
          providers: (_) async => throw StateError('private-address'),
        );
        final result = await source.read(_context());
        expect(result.unreached, {'pc'});
        expect(result.authoritativeSignIns, isEmpty);
        expect(result.signIns, isEmpty);
      },
    );

    test(
      'a server that needs its password again is skipped, never contacted',
      () async {
        var asked = 0;
        final source = OpenCodeSignInSource(
          profiles: () => [_profile('pc')..requiresPasswordReentry = true],
          isReadable: (_) => true,
          providers: (_) async {
            asked++;
            return response(const []);
          },
        );
        final result = await source.read(_context());
        expect(asked, 0);
        expect(result.unreached, isEmpty);
      },
    );
  });

  group('Paseo', () {
    late _Store store;
    late PaseoUsageMonitor monitor;
    late List<ProviderUsageReading> reply;
    var hostRunning = true;

    ProviderUsageReading reading(String id, {bool signIn = false}) =>
        ProviderUsageReading(
          providerId: id,
          displayName: id,
          fetchedAt: _now,
          needsSignIn: signIn,
          windows: signIn
              ? const []
              : [
                  ProviderUsageWindowReading(
                    durationSeconds: 18000,
                    label: '',
                    remainingPercent: 70,
                    resetsAt: _now.add(const Duration(hours: 1)),
                  ),
                  const ProviderUsageWindowReading(
                    durationSeconds: 604800,
                    label: '',
                    remainingPercent: 40,
                    resetsAt: null,
                  ),
                ],
        );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      store = _Store(prefs)
        ..entries.add(_profile('p1', backend: ServerBackend.paseo));
      reply = [reading('claude'), reading('copilot')];
      hostRunning = true;
      monitor = PaseoUsageMonitor(
        store: store,
        createGateway: (_) => _Gateway(() async => reply),
        isReadable: (id) => store.entries.any((p) => p.id == id),
        phoneSupported: () => true,
        phoneRead: () async => hostRunning ? reply : null,
        clock: () => _now,
      );
      addTearDown(monitor.dispose);
    });

    test(
      'opted-in servers and the phone host feed readings; others are not read',
      () async {
        final source = PaseoUsageSource(
          monitor: monitor,
          paseoProfileIds: () => ['p1'],
        );
        expect((await source.read(_context())).readings, isEmpty);

        await monitor.setEnabled('p1', true);
        await monitor.setEnabled(PaseoUsageMonitor.phoneId, true);
        final result = await source.read(_context());
        final byConn = <String, Set<String>>{};
        for (final r in result.readings) {
          byConn.putIfAbsent(r.connectionId, () => {}).add(r.providerId);
        }
        expect(byConn, {
          'p1': {'claude', 'copilot'},
          'phone': {'claude', 'copilot'},
        });
        final claude = result.readings.firstWhere(
          (r) => r.providerId == 'claude',
        );
        expect(claude.windows.map((w) => w.usedPercent), [30, 60]);
        expect(claude.windows.map((w) => w.kind), [
          UsageWindowKind.fiveHour,
          UsageWindowKind.weekly,
        ]);
      },
    );

    test('U17: with automatic reading no switch is needed', () async {
      final auto = PaseoUsageMonitor(
        store: store,
        createGateway: (_) => _Gateway(() async => reply),
        isReadable: (id) => store.entries.any((p) => p.id == id),
        phoneSupported: () => true,
        phoneRead: () async => hostRunning ? reply : null,
        autoRead: true,
        clock: () => _now,
      );
      addTearDown(auto.dispose);
      final source = PaseoUsageSource(
        monitor: auto,
        paseoProfileIds: () => ['p1'],
      );
      final result = await source.read(_context());
      expect(
        {for (final r in result.readings) r.connectionId},
        {'p1', 'phone'},
      );
      // A stopped host is still never started.
      hostRunning = false;
      expect((await source.read(_context())).unreached, contains('phone'));
    });

    test('a signed-out Claude Code becomes a not-signed-in reading', () async {
      reply = [reading('claude', signIn: true)];
      await monitor.setEnabled(PaseoUsageMonitor.phoneId, true);
      final result = await PaseoUsageSource(
        monitor: monitor,
        paseoProfileIds: () => const [],
      ).read(_context());
      expect(result.readings.single.status, UsageReadingStatus.notSignedIn);
      expect(result.readings.single.connectionId, 'phone');
    });

    test('a stopped phone host is unreached, never started', () async {
      hostRunning = false;
      await monitor.setEnabled(PaseoUsageMonitor.phoneId, true);
      final result = await PaseoUsageSource(
        monitor: monitor,
        paseoProfileIds: () => const [],
      ).read(_context());
      expect(result.readings, isEmpty);
      expect(result.unreached, {'phone'});
    });
  });
}

class _Gateway implements ProviderUsageGateway {
  _Gateway(this.run);
  final Future<List<ProviderUsageReading>> Function() run;
  @override
  Future<List<ProviderUsageReading>> read() => run();
  @override
  Future<void> close() async {}
}
