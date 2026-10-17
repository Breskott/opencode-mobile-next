import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/usage_subscriptions.dart';

// Each test names the row of the 30-row table in
// docs/design/usage-subscriptions-contract-2026-10-13.md it protects.

final _now = DateTime.utc(2026, 10, 13, 12);

const _pc = UsageConnection(
  id: 'pc',
  name: 'PC',
  kind: UsageConnectionKind.openCodeServer,
);
const _inApp = UsageConnection(
  id: 'inapp',
  name: 'In-app Ubuntu',
  kind: UsageConnectionKind.inAppUbuntu,
);
const _laptop = UsageConnection(
  id: 'laptop',
  name: 'Laptop',
  kind: UsageConnectionKind.openCodeServer,
);
const _phone = UsageConnection(
  id: UsageConnection.phoneId,
  name: '',
  kind: UsageConnectionKind.phoneAgents,
);

List<UsageWindow> _both({double five = 20, double week = 40}) => [
  UsageWindow(
    id: 'primary',
    usedPercent: five,
    durationSeconds: 18000,
    resetsAt: _now.add(const Duration(hours: 2)),
  ),
  UsageWindow(
    id: 'secondary',
    usedPercent: week,
    durationSeconds: 604800,
    resetsAt: _now.add(const Duration(days: 3)),
  ),
];

UsageReading _reading(
  String provider,
  String connection, {
  String? account,
  UsageReadingStatus status = UsageReadingStatus.ok,
  List<UsageWindow>? windows,
  Duration age = const Duration(minutes: 1),
  UsageProblem? problem,
  String? plan,
  SignInMethod method = SignInMethod.plan,
}) => UsageReading(
  providerId: provider,
  displayName: provider,
  connectionId: connection,
  status: status,
  fetchedAt: _now.subtract(age),
  windows: windows ?? (status == UsageReadingStatus.ok ? _both() : const []),
  accountRef: account,
  plan: plan,
  problem: problem,
  method: method,
);

UsageSnapshot _merge(
  List<UsageReading> readings, {
  List<UsageConnection> connections = const [_inApp],
  List<UsageSignIn> signIns = const [],
  Set<String> authoritative = const {},
  double threshold = 80,
  Map<String, UsageAlertOverride> overrides = const {},
}) => mergeUsageSubscriptions(
  now: _now,
  connections: connections,
  readings: readings,
  signIns: signIns,
  authoritativeSignIns: authoritative,
  defaultThreshold: threshold,
  overrides: overrides,
);

void main() {
  test('row 1: nothing signed in shows the add list and no cards', () {
    final s = _merge(const []);
    expect(s.subscriptions, isEmpty);
    expect(s.addable, usagePlanProviders);
    expect(s.hasSeveralConnections, isFalse);
  });

  test('row 2: In-app Ubuntu Codex is one readable card', () {
    final s = _merge([_reading('codex', 'inapp', account: 'a', plan: 'plus')]);
    expect(s.subscriptions, hasLength(1));
    final c = s.subscriptions.single;
    expect(c.state, SubscriptionState.ok);
    expect(c.readFrom, _inApp);
    expect(c.planLabel, 'plus');
    expect(c.fiveHour!.leftPercent, 80);
    expect(c.weekly!.leftPercent, 60);
    expect(s.addable, isNot(contains('codex')));
  });

  test(
    'row 3: signed in on a PC no reader reaches is cantReadYet with Set up',
    () {
      final s = _merge(
        const [],
        connections: [_inApp, _pc],
        signIns: const [
          UsageSignIn(
            providerId: 'codex',
            connectionId: 'pc',
            displayName: 'Codex',
          ),
        ],
        authoritative: {'pc'},
      );
      final c = s.subscriptions.single;
      expect(c.state, SubscriptionState.cantReadYet);
      expect(c.fix, UsageFix.setUp);
      expect(c.fixConnection, _pc);
      expect(c.windows, isEmpty);
      expect(c.signedInOn.single.readsFromHere, isFalse);
    },
  );

  test('row 4: once the PC is read the same sign-in shows numbers', () {
    final s = _merge(
      [_reading('codex', 'pc', account: 'a')],
      connections: [_inApp, _pc],
      signIns: const [UsageSignIn(providerId: 'codex', connectionId: 'pc')],
      authoritative: {'pc'},
    );
    expect(s.subscriptions, hasLength(1));
    expect(s.subscriptions.single.state, SubscriptionState.ok);
    expect(s.subscriptions.single.readFrom, _pc);
  });

  test(
    'row 5: offline keeps the numbers, marks them stale, flags a reset since',
    () {
      final windows = [
        UsageWindow(
          id: 'primary',
          usedPercent: 90,
          durationSeconds: 18000,
          resetsAt: _now.subtract(const Duration(minutes: 30)),
        ),
      ];
      final s = _merge(
        [
          _reading(
            'codex',
            'pc',
            account: 'a',
            windows: windows,
            age: const Duration(hours: 3),
            problem: UsageProblem.offline,
          ),
        ],
        connections: [_pc],
      );
      final c = s.subscriptions.single;
      expect(c.state, SubscriptionState.offlineStale);
      expect(c.windows, hasLength(1));
      expect(c.resetSinceLastReading, isTrue);
      expect(c.signedInOn.single.online, isFalse);
      expect(c.readFrom, _pc);
    },
  );

  test('row 5: stale numbers without a passed reset do not claim one', () {
    final s = _merge(
      [
        _reading(
          'codex',
          'pc',
          account: 'a',
          age: const Duration(hours: 3),
          problem: UsageProblem.offline,
        ),
      ],
      connections: [_pc],
    );
    expect(s.subscriptions.single.resetSinceLastReading, isFalse);
  });

  test(
    'row 6: the same account on two connections is one card, freshest wins',
    () {
      final s = _merge(
        [
          _reading(
            'codex',
            'pc',
            account: 'a',
            age: const Duration(minutes: 40),
          ),
          _reading(
            'codex',
            'inapp',
            account: 'a',
            windows: _both(five: 55),
            age: const Duration(minutes: 2),
          ),
        ],
        connections: [_inApp, _pc],
      );
      expect(s.subscriptions, hasLength(1));
      final c = s.subscriptions.single;
      expect(c.readFrom, _inApp);
      expect(c.fiveHour!.usedPercent, 55);
      expect(c.signedInOn.map((e) => e.connection.id), ['inapp', 'pc']);
      expect(c.signedInOn.first.readsFromHere, isTrue);
      expect(c.signedInOn.last.readsFromHere, isFalse);
    },
  );

  test('row 6: freshest wins whichever connection holds it', () {
    final s = _merge(
      [
        _reading('codex', 'inapp', account: 'a', age: const Duration(hours: 1)),
        _reading(
          'codex',
          'pc',
          account: 'a',
          windows: _both(five: 10),
          age: const Duration(minutes: 1),
        ),
      ],
      connections: [_inApp, _pc],
    );
    expect(s.subscriptions.single.readFrom, _pc);
    expect(s.subscriptions.single.fiveHour!.usedPercent, 10);
  });

  test(
    'row 7: two accounts stay two cards and ask for the connection name',
    () {
      final s = _merge(
        [
          _reading('codex', 'pc', account: 'personal'),
          _reading(
            'codex',
            'laptop',
            account: 'work',
            windows: _both(five: 70),
          ),
        ],
        connections: [_pc, _laptop],
      );
      expect(s.subscriptions, hasLength(2));
      expect(s.subscriptions.every((c) => c.showConnectionName), isTrue);
      expect(s.subscriptions.map((c) => c.accountRef).toSet(), {
        'personal',
        'work',
      });
    },
  );

  test('row 7: a lone card does not ask for the connection name', () {
    final s = _merge(
      [_reading('codex', 'pc', account: 'a')],
      connections: [_pc],
    );
    expect(s.subscriptions.single.showConnectionName, isFalse);
  });

  test('row 9: a removed connection takes only its own plans along', () {
    final readings = [
      _reading('codex', 'pc', account: 'a'),
      _reading('glm', 'pc', account: 'g'),
      _reading('codex', 'inapp', account: 'a'),
    ];
    final s = _merge(readings, connections: [_inApp]);
    expect(s.subscriptions.map((c) => c.providerId), ['codex']);
    expect(s.subscriptions.single.signedInOn.map((e) => e.connection.id), [
      'inapp',
    ]);
  });

  test('row 11: signed out where it was used stays listed with a fix', () {
    final s = _merge([
      _reading('codex', 'inapp', status: UsageReadingStatus.notSignedIn),
      _reading('glm', 'inapp', status: UsageReadingStatus.notSignedIn),
    ]);
    final codex = s.subscriptions.firstWhere((c) => c.providerId == 'codex');
    final glm = s.subscriptions.firstWhere((c) => c.providerId == 'glm');
    expect(codex.state, SubscriptionState.notSignedIn);
    expect(codex.fix, UsageFix.signIn);
    expect(glm.fix, UsageFix.addKey);
    expect(codex.windows, isEmpty);
  });

  test(
    'row 11: a cached provider the server no longer lists is signed out',
    () {
      final s = _merge(
        [_reading('codex', 'pc', account: 'a')],
        connections: [_pc],
        authoritative: {'pc'},
      );
      expect(s.subscriptions.single.state, SubscriptionState.notSignedIn);
      expect(s.subscriptions.single.fixConnection, _pc);
    },
  );

  test('row 11: but only when the server actually answered', () {
    final s = _merge(
      [_reading('codex', 'pc', account: 'a')],
      connections: [_pc],
    );
    expect(s.subscriptions.single.state, SubscriptionState.ok);
  });

  test('row 12: a never-used provider is only in the add list', () {
    final s = _merge([_reading('codex', 'inapp', account: 'a')]);
    expect(s.subscriptions.map((c) => c.providerId), ['codex']);
    expect(s.addable, ['claude', 'glm', 'minimax']);
  });

  test('row 13: an expired sign-in turns the card red with Sign in again', () {
    final s = _merge(
      [
        _reading(
          'codex',
          'pc',
          account: 'a',
          status: UsageReadingStatus.authRequired,
        ),
      ],
      connections: [_pc],
    );
    final c = s.subscriptions.single;
    expect(c.state, SubscriptionState.signInExpired);
    expect(c.fix, UsageFix.signIn);
    expect(c.fixConnection, _pc);
    expect(c.signedInOn.single.state, SignInState.expired);
  });

  test(
    'row 13: another connection with the same account takes over reading',
    () {
      final s = _merge(
        [
          _reading(
            'codex',
            'pc',
            account: 'a',
            status: UsageReadingStatus.authRequired,
            age: const Duration(minutes: 1),
          ),
          _reading(
            'codex',
            'inapp',
            account: 'a',
            age: const Duration(hours: 1),
          ),
        ],
        connections: [_inApp, _pc],
      );
      expect(s.subscriptions, hasLength(1));
      final c = s.subscriptions.single;
      expect(c.state, SubscriptionState.ok);
      expect(c.readFrom, _inApp);
      expect(
        c.signedInOn.firstWhere((e) => e.connection.id == 'pc').state,
        SignInState.expired,
      );
    },
  );

  test('rows 14 and 15: an API key is not a plan card', () {
    final s = _merge(
      const [],
      connections: [_pc],
      signIns: const [
        UsageSignIn(
          providerId: 'codex',
          connectionId: 'pc',
          method: SignInMethod.apiKey,
          displayName: 'OpenAI',
        ),
        UsageSignIn(
          providerId: 'claude',
          connectionId: 'pc',
          method: SignInMethod.apiKey,
          displayName: 'Claude',
        ),
      ],
      authoritative: {'pc'},
    );
    expect(s.subscriptions, isEmpty);
    expect(s.apiKeyAccounts.map((a) => a.providerId), ['codex', 'claude']);
    // Claude stays on the add list: its plan limits come from Claude Code.
    expect(s.addable, ['claude', 'glm', 'minimax']);
    expect(s.apiKeyAccounts.last.viaOpenCode, isTrue);
    expect(s.apiKeyAccounts.first.viaOpenCode, isFalse);
  });

  test('rows 14 and 15: a key plus a plan reading is still a plan', () {
    final s = _merge(
      [_reading('codex', 'pc', account: 'a')],
      connections: [_pc],
      signIns: const [
        UsageSignIn(
          providerId: 'codex',
          connectionId: 'pc',
          method: SignInMethod.apiKey,
        ),
      ],
    );
    expect(s.subscriptions, hasLength(1));
    expect(s.apiKeyAccounts, isEmpty);
  });

  test(
    'rows 16 and 17: Claude via the phone host or a PC is one card each',
    () {
      final s = _merge(
        [
          _reading('claude', UsageConnection.phoneId),
          _reading('claude', 'pc', windows: _both(five: 30)),
        ],
        connections: [_phone, _pc],
      );
      expect(s.subscriptions, hasLength(2));
      expect(s.subscriptions.map((c) => c.readFrom!.id).toSet(), {
        UsageConnection.phoneId,
        'pc',
      });
    },
  );

  test('row 18: Claude Code signed out offers Sign in on the phone', () {
    final s = _merge(
      [
        _reading(
          'claude',
          UsageConnection.phoneId,
          status: UsageReadingStatus.notSignedIn,
        ),
      ],
      connections: [_phone],
    );
    final c = s.subscriptions.single;
    expect(c.state, SubscriptionState.notSignedIn);
    expect(c.fix, UsageFix.signIn);
    expect(c.fixConnection, _phone);
  });

  test('rows 19 to 21: ok, near the alert level, and exhausted', () {
    final s = _merge([
      _reading(
        'codex',
        'inapp',
        account: 'a',
        windows: _both(five: 20, week: 79),
      ),
      _reading(
        'glm',
        'inapp',
        account: 'b',
        windows: _both(five: 80, week: 10),
      ),
      _reading(
        'minimax',
        'inapp',
        account: 'c',
        windows: _both(five: 100, week: 10),
      ),
    ]);
    SubscriptionState of(String p) =>
        s.subscriptions.firstWhere((c) => c.providerId == p).state;
    expect(of('codex'), SubscriptionState.ok);
    expect(of('glm'), SubscriptionState.nearLimit);
    expect(of('minimax'), SubscriptionState.exhausted);
    // Most urgent first.
    expect(s.subscriptions.map((c) => c.providerId), [
      'minimax',
      'glm',
      'codex',
    ]);
  });

  test(
    'row 20: a per-plan override moves the alert level for that plan only',
    () {
      final s = _merge(
        [
          _reading(
            'codex',
            'inapp',
            account: 'a',
            windows: _both(five: 85, week: 0),
          ),
          _reading(
            'glm',
            'inapp',
            account: 'b',
            windows: _both(five: 85, week: 0),
          ),
        ],
        overrides: {
          usageSubscriptionKey('codex', 'a', 'inapp'): const UsageAlertOverride(
            threshold: 90,
          ),
        },
      );
      final codex = s.subscriptions.firstWhere((c) => c.providerId == 'codex');
      final glm = s.subscriptions.firstWhere((c) => c.providerId == 'glm');
      expect(codex.state, SubscriptionState.ok);
      expect(codex.alertThreshold, 90);
      expect(codex.hasAlertOverride, isTrue);
      expect(glm.state, SubscriptionState.nearLimit);
      expect(glm.alertThreshold, 80);
      expect(glm.hasAlertOverride, isFalse);
    },
  );

  test(
    'row 22: GLM keeps all three windows, with 5 hours and the week first',
    () {
      final s = _merge([
        _reading(
          'glm',
          'inapp',
          account: 'g',
          windows: [
            UsageWindow(id: 'tools', usedPercent: 5, durationSeconds: 2592000),
            UsageWindow(id: 'week', usedPercent: 30, durationSeconds: 604800),
            UsageWindow(id: '5h', usedPercent: 10, durationSeconds: 18000),
          ],
        ),
      ]);
      final c = s.subscriptions.single;
      expect(c.windows.map((w) => w.kind), [
        UsageWindowKind.fiveHour,
        UsageWindowKind.weekly,
        UsageWindowKind.monthly,
      ]);
      expect(c.fiveHour!.usedPercent, 10);
      expect(c.weekly!.usedPercent, 30);
    },
  );

  test('row 23: a working reader with no limits is noLimits', () {
    final s = _merge([
      _reading('copilot', 'inapp', status: UsageReadingStatus.noLimits),
    ]);
    expect(s.subscriptions.single.state, SubscriptionState.noLimits);
  });

  test(
    'row 24: a rate-limited provider keeps the last numbers without an error',
    () {
      final s = _merge([
        _reading(
          'codex',
          'inapp',
          account: 'a',
          age: const Duration(minutes: 20),
          problem: UsageProblem.rateLimited,
        ),
      ]);
      final c = s.subscriptions.single;
      expect(c.state, SubscriptionState.ok);
      expect(c.windows, isNotEmpty);
      expect(c.fix, UsageFix.none);
    },
  );

  test('row 25: a broken reader keeps the numbers and offers Try again', () {
    final s = _merge([
      _reading('codex', 'inapp', account: 'a', problem: UsageProblem.broken),
    ]);
    final c = s.subscriptions.single;
    expect(c.state, SubscriptionState.readerBroken);
    expect(c.fix, UsageFix.tryAgain);
    expect(c.windows, isNotEmpty);
  });

  test('row 25: a reader that never worked shows broken without numbers', () {
    final s = _merge([
      _reading(
        'codex',
        'inapp',
        status: UsageReadingStatus.noLimits,
        problem: UsageProblem.broken,
      ),
    ]);
    expect(s.subscriptions.single.state, SubscriptionState.readerBroken);
    expect(s.subscriptions.single.windows, isEmpty);
  });

  test(
    'row 26: after hours away a passed reset is flagged on cached numbers',
    () {
      final s = _merge([
        _reading(
          'codex',
          'inapp',
          account: 'a',
          age: const Duration(hours: 6),
          windows: [
            UsageWindow(
              id: 'primary',
              usedPercent: 99,
              durationSeconds: 18000,
              resetsAt: _now.subtract(const Duration(hours: 1)),
            ),
          ],
        ),
      ]);
      expect(s.subscriptions.single.resetSinceLastReading, isTrue);
    },
  );

  test('row 27: Paseo-reported providers become cards with the same rules', () {
    final s = _merge(
      [
        _reading('copilot', UsageConnection.phoneId, windows: _both(five: 85)),
        _reading('kimi', UsageConnection.phoneId),
      ],
      connections: [_phone],
    );
    expect(s.subscriptions.map((c) => c.providerId).toSet(), {
      'copilot',
      'kimi',
    });
    expect(
      s.subscriptions.firstWhere((c) => c.providerId == 'copilot').state,
      SubscriptionState.nearLimit,
    );
    // Not one of the four offered plans: it does not appear under Add.
    expect(s.addable, usagePlanProviders);
  });

  test('rows 28 and 29: server names only matter with several connections', () {
    expect(_merge(const []).hasSeveralConnections, isFalse);
    expect(
      _merge(const [], connections: [_inApp, _pc]).hasSeveralConnections,
      isTrue,
    );
  });

  test('provider ids from OpenCode, Paseo and the collector all map', () {
    expect(canonicalUsageProviderId('openai'), 'codex');
    expect(canonicalUsageProviderId('codex'), 'codex');
    expect(canonicalUsageProviderId('zai-coding-plan'), 'glm');
    expect(canonicalUsageProviderId('minimax-coding-plan'), 'minimax');
    expect(canonicalUsageProviderId('anthropic'), 'claude');
    expect(canonicalUsageProviderId('openrouter'), isNull);
  });

  test('readings survive a JSON round trip without account text', () {
    final r = _reading('codex', 'pc', account: 'a' * 64, plan: 'pro');
    final back = UsageReading.fromJson(r.toJson(), 'pc')!;
    expect(back.accountRef, r.accountRef);
    expect(back.windows, hasLength(2));
    expect(back.fetchedAt, r.fetchedAt);
    expect(r.toJson().toString(), isNot(contains('token')));
    expect(UsageReading.fromJson({'provider': 'Bad Id'}, 'pc'), isNull);
  });

  // ----------------------------------------------------- fix batch, APK 2237

  test('U22: not-signed-in leftovers fold into the signed-in card', () {
    final s = _merge(
      [_reading('codex', 'inapp', status: UsageReadingStatus.notSignedIn)],
      connections: [_inApp, _pc],
      signIns: const [
        UsageSignIn(
          providerId: 'codex',
          connectionId: 'pc',
          displayName: 'Codex',
        ),
      ],
      authoritative: {'pc'},
    );
    final codex = s.subscriptions.where((c) => c.providerId == 'codex');
    expect(codex, hasLength(1));
    expect(codex.single.state, SubscriptionState.cantReadYet);
    expect(codex.single.showConnectionName, isFalse);
    // The connection that is not signed in stays listed on the one card.
    expect(
      codex.single.signedInOn.map((e) => (e.connection.id, e.state)),
      containsAll([
        ('pc', SignInState.signedIn),
        ('inapp', SignInState.notSignedIn),
      ]),
    );
  });

  test('U22: several not-signed-in records are one card', () {
    final s = _merge(
      [
        _reading('glm', 'inapp', status: UsageReadingStatus.notSignedIn),
        _reading('glm', 'pc', status: UsageReadingStatus.notSignedIn),
      ],
      connections: [_inApp, _pc],
    );
    expect(s.subscriptions, hasLength(1));
    expect(s.subscriptions.single.signedInOn, hasLength(2));
  });

  test('U22: two different accounts stay two cards', () {
    final s = _merge(
      [
        _reading('codex', 'inapp', account: 'a'),
        _reading('codex', 'pc', account: 'b'),
      ],
      connections: [_inApp, _pc],
    );
    expect(s.subscriptions, hasLength(2));
  });

  test('U19: Claude on an OpenCode server is a Details row, not a card', () {
    final s = _merge(
      const [],
      connections: [_pc],
      signIns: const [
        UsageSignIn(
          providerId: 'claude',
          connectionId: 'pc',
          displayName: 'Claude',
        ),
      ],
      authoritative: {'pc'},
    );
    expect(s.subscriptions, isEmpty);
    expect(s.apiKeyAccounts.single.viaOpenCode, isTrue);
    expect(s.addable, contains('claude'));
  });

  test('U19: a Paseo sign-in-needed status is still a Claude card', () {
    final s = _merge(
      [
        _reading(
          'claude',
          UsageConnection.phoneId,
          status: UsageReadingStatus.notSignedIn,
        ),
      ],
      connections: [_pc, _phone],
      signIns: const [UsageSignIn(providerId: 'claude', connectionId: 'pc')],
      authoritative: {'pc'},
    );
    expect(s.subscriptions.single.providerId, 'claude');
    expect(s.subscriptions.single.fixConnection, _phone);
  });

  test('U20: providers the reader cannot read are not plan cards', () {
    final s = _merge(
      const [],
      connections: [_pc],
      signIns: const [
        UsageSignIn(providerId: 'copilot', connectionId: 'pc'),
        UsageSignIn(providerId: 'kimi', connectionId: 'pc'),
        UsageSignIn(providerId: 'minimax', connectionId: 'pc'),
        UsageSignIn(providerId: 'glm', connectionId: 'pc'),
        UsageSignIn(providerId: 'codex', connectionId: 'pc'),
      ],
      authoritative: {'pc'},
    );
    expect(s.subscriptions.map((c) => c.providerId).toSet(), {
      'codex',
      'glm',
      'minimax',
    });
    expect(s.subscriptions.every((c) => c.fix == UsageFix.setUp), isTrue);
  });

  test('U20: Copilot from a Paseo reading is still a card', () {
    final s = _merge(
      [_reading('copilot', UsageConnection.phoneId)],
      connections: [_phone],
    );
    expect(s.subscriptions.single.providerId, 'copilot');
  });

  test('U8: an unreachable connection is offline, never "not signed in"', () {
    final s = mergeUsageSubscriptions(
      now: _now,
      connections: [_inApp, _pc],
      readings: const [],
      signIns: const [UsageSignIn(providerId: 'codex', connectionId: 'pc')],
      offlineConnections: {'pc'},
    );
    expect(s.isOffline(_pc), isTrue);
    expect(s.hasAnswered(_pc), isFalse);
    expect(s.subscriptions.single.signedInOn.single.online, isFalse);
    // The last known sign-in is kept.
    expect(
      s.subscriptions.single.signedInOn.single.state,
      SignInState.signedIn,
    );
  });

  test('U8: only a connection that answered can be "not signed in"', () {
    final s = _merge(
      const [],
      connections: [_inApp, _pc],
      authoritative: {'pc'},
    );
    expect(s.hasAnswered(_pc), isTrue);
    expect(s.hasAnswered(_inApp), isFalse);
  });

  test('U10: a record with no reading carries no read time', () {
    final s = _merge([
      _reading('codex', 'inapp', status: UsageReadingStatus.notSignedIn),
    ]);
    expect(s.subscriptions.single.fetchedAt, isNull);
    expect(s.subscriptions.single.checkedAt, isNull);
  });
}
