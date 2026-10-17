// The computer usage check: the app runs a one-shot reader on a saved
// OpenCode server through its terminal API. A fake terminal stands in for the
// server; nothing here touches a network, a process or a real sign-in.

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/provider_quota.dart';
import 'package:opencode_mobile/domain/terminal_lifecycle.dart';
import 'package:opencode_mobile/domain/usage_subscriptions.dart';
import 'package:opencode_mobile/state/computer_usage_source.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/usage_subscriptions_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/computer_usage_fakes.dart';

ServerProfile _profile(
  String id, {
  ServerBackend backend = ServerBackend.openCode,
  String url = 'https://pc.example',
}) => ServerProfile(
  id: id,
  name: id,
  baseUrl: url,
  username: 'u',
  password: 'p',
  backend: backend,
);

class _Rig {
  _Rig(this.prefs, this.source, this.ports, this.now);
  final SharedPreferences prefs;
  final ComputerUsageSource source;
  final List<FakeComputerPort> ports;
  DateTime Function() now;
}

Future<_Rig> _rig(
  List<List<FakeStep>> runs, {
  List<ServerProfile>? profiles,
  Duration timeout = const Duration(seconds: 3),
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'oc.usageComputerReader.pc': true,
    ...prefs,
  });
  final store = await SharedPreferences.getInstance();
  final ports = <FakeComputerPort>[];
  var run = 0;
  late _Rig rig;
  final source = ComputerUsageSource(
    prefs: store,
    profiles: () => profiles ?? [_profile('pc')],
    isReadable: (_) => true,
    isInApp: (p) => p.id == 'inapp',
    createPort: (_) {
      final port = FakeComputerPort(
        runs[run < runs.length ? run : runs.length - 1],
      );
      run++;
      ports.add(port);
      return port;
    },
    loadSource: () async => 'SCRIPT',
    clock: () => rig.now(),
    timeout: timeout,
  );
  rig = _Rig(store, source, ports, () => computerNow);
  return rig;
}

UsageReadContext _context({
  bool force = true,
  bool background = false,
  DateTime? now,
  UsageReading? Function(String, String)? lastReading,
  Set<String> Function(String)? signedIn,
}) => UsageReadContext(
  connections: const [],
  now: now ?? computerNow,
  force: force,
  background: background,
  lastReading: lastReading,
  signedIn: signedIn,
);

void main() {
  group('reading the answer', () {
    test('only the exact marker line counts, through echo and ANSI codes', () {
      final answer = computerLine(computerCodexOk);
      final noisy =
          '\x1B[?2004h\x1B[1;32muser@pc\x1B[0m:~\$ node --input-type=module '
          '-e "const MARKER = \'OCMN_USAGE_V1\'"\r\n'
          'OCMN_USAGE_V1 not base64 at all\r\n'
          '\x1B[2K\r$answer\x1B[0m\r\n\x1B[?2004h';
      final result = parseComputerUsageOutput(noisy);
      expect(result, isNotNull);
      expect(result!.ok, isTrue);
      expect(result.auth[QuotaProvider.codex], 'oauth');
      expect(result.snapshots[QuotaProvider.codex]!.account.plan, 'plus');
      expect(parseComputerUsageOutput('echo OCMN_USAGE_V1 abcd\r\n'), isNull);
      expect(parseComputerUsageOutput('nothing here'), isNull);
      expect(parseComputerUsageOutput(''), isNull);
    });

    test('a line split across chunks is read once it is whole', () {
      final answer = computerLine(computerCodexOk);
      expect(parseComputerUsageOutput(answer.substring(0, 30)), isNull);
      expect(parseComputerUsageOutput('$answer\r\n'), isNotNull);
    });

    test('the error codes and a bad provider are fixed outcomes', () {
      final old = parseComputerUsageOutput(
        computerLine(computerAnswer(error: 'nodeTooOld')),
      );
      expect(old!.problem, ComputerUsageProblem.nodeTooOld);
      final failed = parseComputerUsageOutput(
        computerLine(computerAnswer(error: 'failed')),
      );
      expect(failed!.problem, ComputerUsageProblem.noAnswer);
      // A snapshot the app cannot trust is dropped, the others stay.
      final bad = computerSnapshot('glm', ref: computerRef)
        ..['schemaVersion'] = 9;
      final mixed = parseComputerUsageOutput(
        computerLine(
          computerAnswer(
            providers: {
              'codex': computerSnapshot('codex', ref: computerRef),
              'glm': bad,
            },
            auth: {'codex': 'oauth', 'glm': 'api'},
          ),
        ),
      );
      expect(mixed!.snapshots.keys, [QuotaProvider.codex]);
      expect(parseComputerUsageOutput('OCMN_USAGE_V1 ${'A' * 200000}'), isNull);
    });

    test('why Node did not run is chosen from words, never stored', () {
      expect(
        classifyComputerUsageOutput('bash: node: command not found'),
        ComputerUsageProblem.nodeMissing,
      );
      expect(
        classifyComputerUsageOutput("'node' is not recognized as a command"),
        ComputerUsageProblem.nodeMissing,
      );
      expect(
        classifyComputerUsageOutput('SyntaxError: Unexpected token'),
        ComputerUsageProblem.nodeTooOld,
      );
      expect(
        classifyComputerUsageOutput('\x1B[31mhello\x1B[0m'),
        ComputerUsageProblem.noAnswer,
      );
    });
  });

  group('one check', () {
    test('runs node first, reads the line, and removes the terminal', () async {
      final rig = await _rig([
        [
          FakeStep(output: ['\x1B[0m', '${computerLine(computerCodexOk)}\r\n']),
        ],
      ]);
      final result = await rig.source.readNow(_profile('pc'));
      expect(result.ok, isTrue);
      final port = rig.ports.single;
      expect(port.started, hasLength(1));
      expect(port.started.single.$1, 'node');
      expect(port.started.single.$2, ['--input-type=module', '-e', 'SCRIPT']);
      expect(port.started.single.$3, computerUsageTitle);
      expect(port.removed, ['pty_1']);
      expect(port.closed, 1);
    });

    test(
      'a silent reader times out and the terminal is still removed',
      () async {
        final rig = await _rig([
          [const FakeStep(hang: true)],
        ], timeout: const Duration(milliseconds: 300));
        final result = await rig.source.readNow(_profile('pc'));
        expect(result.problem, ComputerUsageProblem.noAnswer);
        // Never wait the full time again for a second try with nothing left.
        for (final port in rig.ports) {
          expect(port.removed, isNotEmpty);
          expect(port.removed.length, port.started.length);
          expect(port.closed, 1);
        }
      },
    );

    test('the login shell runs when node itself fails before output', () async {
      final rig = await _rig([
        [
          const FakeStep(connectError: true),
          FakeStep(output: ['${computerLine(computerCodexOk)}\r\n']),
        ],
      ]);
      final result = await rig.source.readNow(_profile('pc'));
      expect(result.ok, isTrue);
      final port = rig.ports.single;
      expect(port.started.map((s) => s.$1), ['node', 'bash']);
      final args = port.started.last.$2;
      expect(args.first, '-lc');
      expect(args[1], contains('node --input-type=module -e "\$1"'));
      expect(args[2], '_');
      expect(args.last, 'SCRIPT');
      expect(port.removed, ['pty_1', 'pty_2']);
    });

    test(
      'the login shell also runs when the server refuses the command',
      () async {
        final rig = await _rig([
          [
            const FakeStep(startError: ComputerUsageProblem.nodeMissing),
            FakeStep(output: ['${computerLine(computerCodexOk)}\r\n']),
          ],
        ]);
        expect((await rig.source.readNow(_profile('pc'))).ok, isTrue);
        expect(rig.ports.single.started.map((s) => s.$1), ['node', 'bash']);
      },
    );

    test('no Node anywhere is "needs Node.js 20"', () async {
      final rig = await _rig([
        [
          const FakeStep(connectError: true),
          const FakeStep(output: ['node: command not found\r\n']),
        ],
      ]);
      final result = await rig.source.readNow(_profile('pc'));
      expect(result.problem, ComputerUsageProblem.nodeMissing);
      expect(rig.source.problemFor('pc'), ComputerUsageProblem.nodeMissing);
    });

    test('the reader saying Node is too old is kept as that reason', () async {
      final rig = await _rig([
        [
          FakeStep(
            output: [
              '${computerLine(computerAnswer(error: 'nodeTooOld'))}\r\n',
            ],
          ),
        ],
      ]);
      final result = await rig.source.readNow(_profile('pc'));
      expect(result.problem, ComputerUsageProblem.nodeTooOld);
      expect(rig.source.problemFor('pc'), ComputerUsageProblem.nodeTooOld);
    });

    test(
      'a server without the terminal API says so and does not retry',
      () async {
        final rig = await _rig([
          [const FakeStep(startError: ComputerUsageProblem.serverTooOld)],
        ]);
        final result = await rig.source.readNow(_profile('pc'));
        expect(result.problem, ComputerUsageProblem.serverTooOld);
        expect(rig.ports.single.started, hasLength(1));
      },
    );

    test('an unreachable server does not retry either', () async {
      final rig = await _rig([
        [const FakeStep(startError: ComputerUsageProblem.unreachable)],
      ]);
      final result = await rig.source.readNow(_profile('pc'));
      expect(result.problem, ComputerUsageProblem.unreachable);
      expect(rig.ports.single.started, hasLength(1));
      expect(rig.ports.single.closed, 1);
    });

    test('the terminal is removed even when removing it throws', () async {
      final port = FakeComputerPort([
        FakeStep(output: ['${computerLine(computerCodexOk)}\r\n']),
      ])..removeThrows = true;
      final result = await runComputerUsageCheck(port, 'SCRIPT');
      expect(result.ok, isTrue);
      expect(port.removed, ['pty_1']);
    });
  });

  test('a socket that never closes does not keep the terminal alive', () async {
    final port = FakeComputerPort([
      FakeStep(
        output: ['${computerLine(computerCodexOk)}\r\n'],
        closeHangs: true,
      ),
    ]);
    final result = await runComputerUsageCheck(port, 'SCRIPT');
    expect(result.ok, isTrue);
    expect(port.removed, ['pty_1']);
  });

  group('opt-in and the sweep', () {
    test('nothing runs until it is turned on for that server', () async {
      final rig = await _rig(
        [
          [
            FakeStep(output: ['${computerLine(computerCodexOk)}\r\n']),
          ],
        ],
        prefs: const {'oc.usageComputerReader.pc': false},
      );
      final result = await rig.source.read(_context());
      expect(result.readings, isEmpty);
      expect(rig.ports, isEmpty);
    });

    test('turning on stores a per-profile key and reads at once', () async {
      final rig = await _rig(
        [
          [
            FakeStep(output: ['${computerLine(computerCodexOk)}\r\n']),
          ],
        ],
        prefs: const {'oc.usageComputerReader.pc': false},
      );
      expect(rig.source.isEnabled('pc'), isFalse);
      final profile = _profile('pc');
      final turned = await rig.source.turnOn(profile);
      expect(turned.ok, isTrue);
      expect(rig.prefs.getBool('oc.usageComputerReader.pc'), isTrue);
      expect(ComputerUsageSource.enabledKey('pc'), 'oc.usageComputerReader.pc');
      // The next refresh uses the answer the check just gave.
      final read = await rig.source.read(_context(force: false));
      expect(read.readings.single.providerId, 'codex');
      expect(rig.ports, hasLength(1));
    });

    test('turning off removes the key and forgets the answer', () async {
      final rig = await _rig([
        [
          FakeStep(output: ['${computerLine(computerCodexOk)}\r\n']),
        ],
      ]);
      await rig.source.readNow(_profile('pc'));
      await rig.source.turnOff('pc');
      expect(rig.prefs.containsKey('oc.usageComputerReader.pc'), isFalse);
      expect(rig.source.problemFor('pc'), isNull);
      expect(rig.source.foundOn('pc'), isEmpty);
      expect((await rig.source.read(_context())).readings, isEmpty);
    });

    test('the profile sweep finds the key', () async {
      SharedPreferences.setMockInitialValues({
        'oc.usageComputerReader.pc': true,
        'oc.usageComputerReader.other': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final store = ProfileStore(prefs: prefs);
      expect(store.profileScopedPreferenceKeys('pc'), {
        'oc.usageComputerReader.pc',
      });
    });

    test(
      'applies to saved OpenCode servers, not In-app Ubuntu or Paseo',
      () async {
        final rig = await _rig(
          [
            [
              FakeStep(output: ['${computerLine(computerCodexOk)}\r\n']),
            ],
          ],
          profiles: [
            _profile('inapp'),
            _profile('paseo', backend: ServerBackend.paseo),
            _profile('codexsrv', backend: ServerBackend.codex),
          ],
          prefs: const {
            'oc.usageComputerReader.inapp': true,
            'oc.usageComputerReader.paseo': true,
            'oc.usageComputerReader.codexsrv': true,
          },
        );
        expect((await rig.source.read(_context())).readings, isEmpty);
        expect(rig.ports, isEmpty);
      },
    );

    test('a server asking for its password again is skipped', () async {
      final rig = await _rig(
        [
          [
            FakeStep(output: ['${computerLine(computerCodexOk)}\r\n']),
          ],
        ],
        profiles: [
          ServerProfile(
            id: 'pc',
            name: 'pc',
            baseUrl: 'https://pc.example',
            username: 'u',
            password: '',
            requiresPasswordReentry: true,
          ),
        ],
      );
      expect((await rig.source.read(_context())).readings, isEmpty);
      expect(rig.ports, isEmpty);
    });
  });

  group('cadence', () {
    test(
      'background reads wait 15 minutes, a forced read never waits',
      () async {
        final rig = await _rig([
          [
            FakeStep(output: ['${computerLine(computerCodexOk)}\r\n']),
          ],
        ]);
        await rig.source.read(_context(background: true));
        expect(rig.ports, hasLength(1));
        rig.now = () => computerNow.add(const Duration(minutes: 14));
        await rig.source.read(
          _context(
            background: true,
            force: false,
            now: computerNow.add(const Duration(minutes: 14)),
          ),
        );
        expect(rig.ports, hasLength(1));
        await rig.source.read(
          _context(
            background: true,
            force: false,
            now: computerNow.add(const Duration(minutes: 16)),
          ),
        );
        expect(rig.ports, hasLength(2));
        await rig.source.read(_context(background: true, force: true));
        expect(rig.ports, hasLength(3));
      },
    );

    test(
      'opening Usage in the foreground reads at most once a minute',
      () async {
        final rig = await _rig([
          [
            FakeStep(output: ['${computerLine(computerCodexOk)}\r\n']),
          ],
        ]);
        await rig.source.read(_context(force: false));
        expect(rig.ports, hasLength(1));
        await rig.source.read(
          _context(
            force: false,
            now: computerNow.add(const Duration(seconds: 30)),
          ),
        );
        expect(rig.ports, hasLength(1));
        await rig.source.read(
          _context(
            force: false,
            now: computerNow.add(const Duration(seconds: 90)),
          ),
        );
        expect(rig.ports, hasLength(2));
      },
    );
  });

  group('what the app learns', () {
    test('Codex, GLM and MiniMax become readings with the plan ref', () async {
      final rig = await _rig([
        [
          FakeStep(
            output: [
              '${computerLine(computerAnswer(
                providers: {
                  'codex': computerSnapshot('codex', ref: computerRef, plan: 'plus'),
                  'glm': computerSnapshot('glm', ref: computerRef2, accountStatus: 'sourceBound'),
                  'minimax': computerSnapshot('minimax', ref: computerRef2, accountStatus: 'sourceBound'),
                },
                auth: {'codex': 'oauth', 'glm': 'api', 'minimax': 'api'},
              ))}\r\n',
            ],
          ),
        ],
      ]);
      final result = await rig.source.read(_context());
      expect(result.readings.map((r) => r.providerId).toSet(), {
        'codex',
        'glm',
        'minimax',
      });
      final codex = result.readings.firstWhere((r) => r.providerId == 'codex');
      expect(codex.connectionId, 'pc');
      expect(codex.accountRef, computerRef);
      expect(codex.plan, 'plus');
      expect(codex.windows, hasLength(1));
      expect(
        result.signIns.every((s) => s.method == SignInMethod.plan),
        isTrue,
      );
      expect(rig.source.foundOn('pc'), [
        QuotaProvider.codex,
        QuotaProvider.minimax,
        QuotaProvider.glm,
      ]);
    });

    test(
      'an OpenAI API key is a pay-as-you-go sign-in with no reading',
      () async {
        final rig = await _rig([
          [
            FakeStep(
              output: [
                '${computerLine(computerAnswer(auth: {'codex': 'api'}))}\r\n',
              ],
            ),
          ],
        ]);
        final result = await rig.source.read(_context());
        expect(result.readings, isEmpty);
        final signIn = result.signIns.single;
        expect(signIn.providerId, 'codex');
        expect(signIn.method, SignInMethod.apiKey);
        expect(rig.source.foundOn('pc'), isEmpty);
      },
    );

    test('a MiniMax pay-as-you-go key is the same, a plan key is not', () async {
      final rig = await _rig([
        [
          FakeStep(
            output: [
              '${computerLine(computerAnswer(
                providers: {'minimax': computerSnapshot('minimax', status: 'unsupported', ref: computerRef)},
                auth: {'minimax': 'api'},
              ))}\r\n',
            ],
          ),
        ],
      ]);
      final result = await rig.source.read(_context());
      expect(result.signIns.single.method, SignInMethod.apiKey);
      expect(result.readings, isEmpty);
    });

    test(
      'an expired sign-in, a rate limit and a broken answer are states',
      () async {
        final rig = await _rig([
          [
            FakeStep(
              output: [
                '${computerLine(computerAnswer(
                  providers: {
                    'codex': computerSnapshot('codex', status: 'authRequired'),
                    'glm': computerSnapshot('glm', status: 'rateLimited'),
                    'minimax': computerSnapshot('minimax', status: 'invalidResponse'),
                  },
                  auth: {'codex': 'oauth', 'glm': 'api', 'minimax': 'api'},
                ))}\r\n',
              ],
            ),
          ],
        ]);
        final result = await rig.source.read(_context());
        expect(result.readings.single.status, UsageReadingStatus.authRequired);
        expect(result.failures.map((f) => (f.providerId, f.problem)).toSet(), {
          ('glm', UsageProblem.rateLimited),
          ('minimax', UsageProblem.broken),
        });
      },
    );

    test('signed out now, but read here before, is "not signed in"', () async {
      final rig = await _rig([
        [
          FakeStep(output: ['${computerLine(computerAnswer())}\r\n']),
        ],
      ]);
      final before = UsageReading(
        providerId: 'glm',
        displayName: 'GLM',
        connectionId: 'pc',
        status: UsageReadingStatus.ok,
        fetchedAt: computerNow,
      );
      final result = await rig.source.read(
        _context(
          lastReading: (c, p) => c == 'pc' && p == 'glm' ? before : null,
        ),
      );
      expect(result.readings.single.status, UsageReadingStatus.notSignedIn);
      expect(result.readings.single.providerId, 'glm');
    });

    test('an unreachable server marks the connection offline', () async {
      final rig = await _rig([
        [const FakeStep(startError: ComputerUsageProblem.unreachable)],
      ]);
      final result = await rig.source.read(_context());
      expect(result.unreached, {'pc'});
      expect(result.failures, isEmpty);
    });

    test(
      'a broken reader fails the plans signed in there, no others',
      () async {
        final rig = await _rig([
          [
            const FakeStep(connectError: true),
            const FakeStep(output: ['node: command not found\r\n']),
          ],
        ]);
        final result = await rig.source.read(
          _context(signedIn: (c) => c == 'pc' ? {'codex', 'copilot'} : {}),
        );
        expect(result.failures.map((f) => f.providerId), ['codex']);
        expect(result.failures.single.problem, UsageProblem.broken);
        expect(result.unreached, isEmpty);
      },
    );

    test(
      'nothing the person owns is kept in memory beyond the numbers',
      () async {
        final rig = await _rig([
          [
            FakeStep(output: ['${computerLine(computerCodexOk)}\r\n']),
          ],
        ]);
        await rig.source.readNow(_profile('pc'));
        final dump = [
          rig.source.problemFor('pc').toString(),
          rig.source.foundOn('pc').toString(),
          rig.prefs.getKeys().join(','),
        ].join(' ');
        expect(dump, isNot(contains('SCRIPT')));
      },
    );
  });
}
