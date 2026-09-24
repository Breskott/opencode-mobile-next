// TEAM-301: the managed Gas City runtime on the phone.
//
// The shell half runs the embedded `aiteam.sh` with bash on this machine
// against fixture paths: a temp HOME and $PREFIX, stub gc/bd/dolt/pkg/
// termux-wake-lock on PATH, and a local HTTP server that serves the
// manifest files and plays the loopback supervisor. The Dart half checks
// the status parsing, the polling wrapper and the loopback control mode of
// the Gas City gateway.
@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/gascity_gateway.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:opencode_mobile/termux/team_runtime.dart';

const _gcStub = r'''#!/bin/bash
# gc stub: records calls, fakes init/rig/import/register, plays supervisor.
calls="$HOME/.oc/gc-calls.log"
marker="$HOME/.oc/aiteam/supervisor.marker"
case "${1:-}" in
  version|--version) echo 'gc version 1.4.1'; exit 0 ;;
  init)
    echo "$*" >> "$calls"
    printf 'GC_BIN=%s\nLINKER_EXEC=%s\nLD_PRELOAD=%s\n' "${GC_BIN:-}" \
      "${TERMUX_EXEC__SYSTEM_LINKER_EXEC__MODE:-}" "${LD_PRELOAD:-}" \
      > "$HOME/.oc/gc-init-env.log"
    mkdir -p city
    cp ./city.toml city/city.toml
    exit 0 ;;
  rig) echo "$*" >> "$calls"; exit 0 ;;
  import)
    if grep -q 'patches.agent' city.toml; then p=yes; else p=no; fi
    echo "$* patches=$p" >> "$calls"
    scripts="$HOME/.gc/cache/repos/abc123/gastown/assets/scripts"
    mkdir -p "$scripts"
    printf '#!/usr/bin/env bash\necho worktree\n' > "$scripts/worktree-setup.sh"
    exit 0 ;;
  register) echo "$*" >> "$calls"; exit 0 ;;
  supervisor)
    case "${2:-}" in
      run)
        echo "supervisor run cwd=$PWD" >> "$calls"
        echo $$ > "$marker"
        trap 'rm -f "$marker"; exit 0' TERM INT
        while :; do sleep 0.2; done ;;
      stop)
        echo 'supervisor stop' >> "$calls"
        p=$(cat "$marker" 2>/dev/null || true)
        [ -z "$p" ] || kill -TERM "$p" 2>/dev/null || true
        exit 0 ;;
    esac ;;
esac
echo "other $*" >> "$calls"
exit 0
''';

const _bdStub = r'''#!/bin/bash
case "${1:-}" in version|--version) echo 'bd version 1.2.2' ;; esac
''';

const _doltStub = r'''#!/bin/bash
case "${1:-}" in
  version) echo 'dolt version 2.3.3' ;;
  config)
    echo "dolt $*" >> "$HOME/.oc/dolt-calls.log"
    mkdir -p "$HOME/.dolt"
    echo '{}' > "$HOME/.dolt/config_global.json" ;;
esac
''';

const _pkgStub = r'''#!/bin/bash
echo "pkg $*" >> "$HOME/.oc/pkg-calls.log"
''';

const _wakeStub = r'''#!/bin/bash
echo "$(basename "$0")" >> "$HOME/.oc/wake.log"
''';

/// One fixture: temp HOME, $PREFIX, stubs, a git project and the server.
class _Fixture {
  _Fixture._(this.root, this.server);

  final Directory root;
  final HttpServer server;
  final files = <String, List<int>>{};
  String manifestJson = '';

  String get home => '${root.path}/home';
  String get prefix => '${root.path}/prefix';
  String get bin => '$prefix/bin';
  String get stubs => '${root.path}/stubs';
  String get project => '${root.path}/projects/calc';
  String get origin => '${root.path}/projects/calc.git';
  String get ocDir => '$home/.oc';
  String get aiteamDir => '$ocDir/aiteam';
  String get cityDir => '$aiteamDir/city';
  String get script => '$ocDir/aiteam.sh';
  String get baseUrl => 'http://127.0.0.1:${server.port}/aiteam/';
  String get supervisorUrl => 'http://127.0.0.1:${server.port}';
  String get manifestPath => '${root.path}/manifest.json';

  bool get supervisorUp => File('$aiteamDir/supervisor.marker').existsSync();

  static Future<_Fixture> create() async {
    final root = Directory.systemTemp.createTempSync('oc-aiteam-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fixture = _Fixture._(root, server);
    server.listen(fixture._handle);
    for (final dir in [
      fixture.home,
      fixture.bin,
      '${fixture.prefix}/tmp',
      fixture.stubs,
      fixture.ocDir,
    ]) {
      Directory(dir).createSync(recursive: true);
    }
    _executable(fixture.script, TermuxBridge.aiteamScriptForTesting());
    _executable('${fixture.stubs}/pkg', _pkgStub);
    _executable('${fixture.stubs}/termux-wake-lock', _wakeStub);
    _executable('${fixture.stubs}/termux-wake-unlock', _wakeStub);
    // The served "binaries" are the stubs: install copies them into $PREFIX/bin
    // where later verbs find them first on PATH.
    fixture.files['gc-1.4.1-android-arm64'] = utf8.encode(_gcStub);
    fixture.files['bd-1.2.2-android-arm64'] = utf8.encode(_bdStub);
    fixture.files['dolt-2.3.3-android-arm64'] = utf8.encode(_doltStub);
    fixture.files['opencode-wrapper.sh'] = File(
      'scripts/termux/aiteam-opencode-wrapper.sh',
    ).readAsBytesSync();
    fixture.manifestJson = fixture._manifest();
    File(fixture.manifestPath).writeAsStringSync(fixture.manifestJson);
    await fixture._gitProject();
    return fixture;
  }

  static void _executable(String path, String content) {
    File(path).writeAsStringSync(content);
    Process.runSync('chmod', ['755', path]);
  }

  String _manifest({Map<String, String> sha256Override = const {}}) {
    Map<String, Object> entry(String key, String name) {
      final bytes = files[name]!;
      return {
        'name': name,
        'bytes': bytes.length,
        'sha256': sha256Override[key] ?? sha256.convert(bytes).toString(),
      };
    }

    return const JsonEncoder.withIndent('  ').convert({
      'schema': 1,
      'base_url': baseUrl,
      'gascity': '1.4.1',
      'beads': '1.2.2',
      'dolt': '2.3.3',
      'pack': 'gastown@sha:33d3a430a67d1782ad364556cb566bdb01d0afe3',
      'arch': 'arm64',
      'termux_packages': ['libicu', 'git', 'jq', 'tmux'],
      'files': {
        'gc': entry('gc', 'gc-1.4.1-android-arm64'),
        'bd': entry('bd', 'bd-1.2.2-android-arm64'),
        'dolt': entry('dolt', 'dolt-2.3.3-android-arm64'),
        'wrapper': entry('wrapper', 'opencode-wrapper.sh'),
      },
    });
  }

  Future<void> _gitProject() async {
    Directory(project).createSync(recursive: true);
    File(
      '$project/calc.py',
    ).writeAsStringSync('def add(a, b):\n    return a + b\n');
    for (final args in [
      ['init', '-q', '-b', 'master'],
      ['add', '-A'],
      ['-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-qm', 'init'],
    ]) {
      final result = await Process.run('git', args, workingDirectory: project);
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    }
  }

  void _handle(HttpRequest request) {
    final path = request.uri.path;
    final response = request.response;
    if (path.startsWith('/aiteam/')) {
      final body = files[path.substring('/aiteam/'.length)];
      if (body == null) {
        response.statusCode = 404;
      } else {
        response.headers.contentType = ContentType.binary;
        response.add(body);
      }
    } else if (path == '/health') {
      _json(response, supervisorUp ? {'status': 'ok', 'uptime_sec': 1} : null);
    } else if (RegExp(r'^/v0/city/[^/]+/health$').hasMatch(path)) {
      _json(
        response,
        supervisorUp
            ? {'status': 'ok', 'uptime_sec': 1, 'city': path.split('/')[3]}
            : null,
      );
    } else if (RegExp(r'^/v0/city/[^/]+/agents$').hasMatch(path)) {
      _json(response, {
        'items': [
          {'id': 'gastown.polecat', 'state': 'idle'},
          {'id': 'gastown.refinery', 'state': 'idle'},
        ],
      });
    } else {
      response.statusCode = 404;
    }
    response.close();
  }

  void _json(HttpResponse response, Map<String, Object?>? body) {
    if (body == null) {
      response.statusCode = 503;
      return;
    }
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
  }

  Map<String, String> get environment => {
    ...Platform.environment,
    'HOME': home,
    'XDG_CONFIG_HOME': '$home/.config',
    'PREFIX': prefix,
    'PATH': '$bin:$stubs:${Platform.environment['PATH']}',
    'AITEAM_URL': supervisorUrl,
    'AITEAM_ARCH': 'aarch64',
    'AITEAM_HEALTH_TIMEOUT': '20',
  };

  /// `bash aiteam.sh <verb> args…` in the foreground.
  Future<ProcessResult> verb(List<String> args) => Process.run(
    'bash',
    [script, ...args],
    environment: environment,
    workingDirectory: root.path,
  );

  /// The bridge's dispatch script for [verb], run with bash on this machine.
  Future<ProcessResult> dispatch(
    String verb, {
    List<String> args = const [],
    String? manifestJson,
  }) => Process.run(
    'bash',
    [
      '-c',
      TermuxBridge.aiteamVerbScript(
        verb,
        args: args,
        manifestJson: manifestJson,
      ),
    ],
    environment: environment,
    workingDirectory: root.path,
  );

  Future<TeamRuntimeStatus> status() async {
    final result = await verb(['status']);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    return TeamRuntimeStatus.parse(result.stdout as String);
  }

  Future<TeamRuntimeStatus> waitIdle() async {
    for (var i = 0; i < 300; i++) {
      final current = await status();
      if (!current.busy) return current;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    fail('a verb stayed busy');
  }

  String read(String path) =>
      File(path).existsSync() ? File(path).readAsStringSync() : '';

  String get gcCalls => read('$ocDir/gc-calls.log');
  String get log => read('$aiteamDir/aiteam.log');

  Future<void> install() async {
    final result = await verb(['install', manifestPath]);
    expect(
      result.exitCode,
      0,
      reason: '${result.stdout}${result.stderr}\n$log',
    );
  }

  Future<void> init() async {
    final result = await verb(['init', project, '--city', 'phone']);
    expect(
      result.exitCode,
      0,
      reason: '${result.stdout}${result.stderr}\n$log',
    );
  }

  Future<void> start() async {
    final result = await verb(['start']);
    expect(
      result.exitCode,
      0,
      reason: '${result.stdout}${result.stderr}\n$log',
    );
  }

  Future<void> dispose() async {
    // Nothing of ours may survive the fixture: stop the stub supervisor.
    final marker = File('$aiteamDir/supervisor.marker');
    if (marker.existsSync()) {
      final pid = int.tryParse(marker.readAsStringSync().trim());
      if (pid != null) Process.killPid(pid, ProcessSignal.sigkill);
    }
    await server.close(force: true);
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // A late tee may still hold the log; the temp dir is not precious.
    }
  }
}

void main() {
  late _Fixture fx;

  setUp(() async => fx = await _Fixture.create());
  tearDown(() => fx.dispose());

  group('aiteam.sh', () {
    test('the embedded script and every dispatch pass bash -n', () {
      final scripts = {
        'aiteam.sh': TermuxBridge.aiteamScriptForTesting(),
        'status.sh': TermuxBridge.aiteamStatusScript(),
        'log.sh': TermuxBridge.aiteamLogPathScript(),
        'install.sh': TermuxBridge.aiteamVerbScript(
          'install',
          args: [TermuxBridge.aiteamManifestPath],
          manifestJson: '{"schema": 1}',
        ),
        'init.sh': TermuxBridge.aiteamVerbScript(
          'init',
          args: ["/root/projects/it's here", '--city', 'phone'],
        ),
        'remove.sh': TermuxBridge.aiteamVerbScript('remove'),
      };
      for (final entry in scripts.entries) {
        final file = File('${fx.root.path}/${entry.key}')
          ..writeAsStringSync(entry.value);
        final result = Process.runSync('bash', ['-n', file.path]);
        expect(result.exitCode, 0, reason: '${entry.key}: ${result.stderr}');
      }
      expect(
        () => TermuxBridge.aiteamVerbScript('init', args: ['a\nb']),
        throwsArgumentError,
      );
      expect(
        () => TermuxBridge.aiteamVerbScript('rm -rf'),
        throwsArgumentError,
      );
    });

    test('status before any install is idle and not installed', () async {
      final status = await fx.status();
      expect(status.phase, TeamRuntimePhase.idle);
      expect(status.installed, isFalse);
      expect(status.busy, isFalse);
      expect(status.killedByAndroid, isFalse);
      expect(status.url, fx.supervisorUrl);
      final log = await fx.verb(['log']);
      expect((log.stdout as String).trim(), '${fx.aiteamDir}/aiteam.log');
    });

    test(
      'install downloads, verifies, installs packages and binaries',
      () async {
        await fx.install();
        final status = await fx.status();
        expect(status.phase, TeamRuntimePhase.installed, reason: fx.log);
        expect(status.installed, isTrue);
        expect(status.versions, {
          'gc': '1.4.1',
          'bd': '1.2.2',
          'dolt': '2.3.3',
        });
        for (final name in ['gc', 'bd', 'dolt', 'opencode']) {
          expect(File('${fx.bin}/$name').existsSync(), isTrue, reason: name);
        }
        expect(
          fx.read('${fx.bin}/opencode'),
          contains('AI Team hybrid layout'),
        );
        expect(
          fx.read('${fx.ocDir}/pkg-calls.log').trim(),
          'pkg install -y libicu git jq tmux',
        );
        expect(
          fx.read('${fx.ocDir}/dolt-calls.log'),
          contains('dolt config --global --add user.name'),
        );
        final gitRole = await Process.run('git', [
          'config',
          '--global',
          'beads.role',
        ], environment: fx.environment);
        expect((gitRole.stdout as String).trim(), 'maintainer');
        expect(Directory('${fx.aiteamDir}/tmp').existsSync(), isFalse);
        expect(fx.read('${fx.aiteamDir}/config'), contains('gascity=1.4.1'));
        expect(fx.log, contains('verified gc-1.4.1-android-arm64'));
      },
    );

    test('install refuses a checksum mismatch with exit 65', () async {
      final bad = fx._manifest(sha256Override: {'bd': 'f' * 64});
      File(fx.manifestPath).writeAsStringSync(bad);
      final result = await fx.verb(['install', fx.manifestPath]);
      expect(result.exitCode, 65, reason: '${result.stdout}${result.stderr}');
      expect(result.stdout, contains('checksum-mismatch bd'));
      final status = await fx.status();
      expect(status.phase, TeamRuntimePhase.failed);
      expect(status.rawPhase, 'failed:checksum-mismatch bd');
      expect(status.checksumMismatch, isTrue);
      expect(status.lastError, contains('did not match'));
      expect(status.installed, isFalse);
      // Nothing was installed and no partial download stays behind.
      expect(File('${fx.bin}/gc').existsSync(), isFalse);
      expect(File('${fx.bin}/bd').existsSync(), isFalse);
      expect(
        Directory(
          '${fx.aiteamDir}/tmp',
        ).listSync().where((e) => e.path.endsWith('.part')),
        isEmpty,
      );
      expect(fx.read('${fx.ocDir}/pkg-calls.log'), isEmpty);
    });

    test('install refuses a manifest whose size differs', () async {
      final tampered = jsonDecode(fx.manifestJson) as Map<String, Object?>;
      final files = tampered['files'] as Map<String, Object?>;
      (files['gc'] as Map<String, Object?>)['bytes'] = 1;
      File(fx.manifestPath).writeAsStringSync(jsonEncode(tampered));
      final result = await fx.verb(['install', fx.manifestPath]);
      expect(result.exitCode, 65);
      expect(result.stdout, contains('checksum-mismatch gc'));
    });

    test('install takes the manifest from a URL too', () async {
      fx.files['manifest.json'] = utf8.encode(fx.manifestJson);
      final result = await fx.verb(['install', '${fx.baseUrl}manifest.json']);
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect((await fx.status()).phase, TeamRuntimePhase.installed);
    });

    test('install refuses a 32-bit phone', () async {
      final result = await Process.run(
        'bash',
        [fx.script, 'install', fx.manifestPath],
        environment: {...fx.environment, 'AITEAM_ARCH': 'armv7l'},
      );
      expect(result.exitCode, isNot(0));
      final status = await fx.status();
      expect(status.rawPhase, 'failed:unsupported-arch');
    });

    test('install refuses a manifest built for another architecture', () async {
      // An x86_64 emulator is allowed, but only with an x86_64 manifest.
      final result = await Process.run(
        'bash',
        [fx.script, 'install', fx.manifestPath],
        environment: {...fx.environment, 'AITEAM_ARCH': 'x86_64'},
      );
      expect(result.exitCode, isNot(0));
      final status = await fx.status();
      expect(status.rawPhase, 'failed:manifest-invalid');
    });

    test(
      'init creates the origin and the city, patches after import install',
      () async {
        await fx.install();
        await fx.init();
        final status = await fx.status();
        expect(status.phase, TeamRuntimePhase.cityReady, reason: fx.log);
        expect(status.city, 'phone');
        expect(status.rig, 'calc');
        expect(status.project, fx.project);
        // A bare origin next to the project, and the project points at it.
        expect(Directory(fx.origin).existsSync(), isTrue);
        final remote = await Process.run('git', [
          'remote',
          'get-url',
          'origin',
        ], workingDirectory: fx.project);
        expect((remote.stdout as String).trim(), fx.origin);
        // Recorded stub order: init, rig add, import install (no patches yet).
        final calls = fx.gcCalls
            .split('\n')
            .where((l) => l.isNotEmpty)
            .toList();
        expect(
          calls[0],
          startsWith('init --file ./city.toml --name phone --no-start city'),
        );
        expect(calls[1], 'rig add ${fx.project} --name calc');
        expect(calls[2], 'import install patches=no');
        final cityToml = fx.read('${fx.cityDir}/city.toml');
        expect(cityToml, contains('provider = "opencode"'));
        expect(
          cityToml,
          contains('version = "sha:33d3a430a67d1782ad364556cb566bdb01d0afe3"'),
        );
        expect(
          cityToml,
          contains(
            'name = "gastown.polecat"\ndir = "calc"\nmax_active_sessions = 1',
          ),
        );
        expect(cityToml, contains('name = "gastown.mayor"\nsuspended = true'));
        expect(
          cityToml.indexOf('[[patches.agent]]'),
          greaterThan(cityToml.indexOf('[daemon]')),
        );
        // The pack's `#!/bin/sh` scripts must run under Termux's shell with
        // the gc helper pinned (spike-phone §3h): termux-exec's system-linker
        // exec mode off and GC_BIN explicit. The LD_PRELOAD branch only runs
        // on Android, so it stays untouched on this Linux runner.
        expect(
          fx.read('${fx.ocDir}/gc-init-env.log'),
          'GC_BIN=${fx.prefix}/bin/gc\nLINKER_EXEC=disable\nLD_PRELOAD=\n',
        );
        // The env-bash shebang the Termux shim cannot run is rewritten.
        expect(
          fx.read(
            '${fx.home}/.gc/cache/repos/abc123/gastown/assets/scripts/worktree-setup.sh',
          ),
          startsWith('#!/bin/bash\n'),
        );
      },
    );

    test('init moves the bead store of an earlier city aside', () async {
      // A team removed and set up again: the project's .beads belongs to
      // the old city (gc refuses to initialise over it and cannot adopt
      // it), so it is kept next to the project and the rig starts fresh.
      await fx.install();
      Directory('${fx.project}/.beads').createSync();
      File('${fx.project}/.beads/config.yaml').writeAsStringSync(
        'issue_prefix: sp\nissue-prefix: sp\ndolt.auto-start: false\n',
      );
      await fx.init();
      expect((await fx.status()).phase, TeamRuntimePhase.cityReady);
      expect(fx.gcCalls, contains('rig add ${fx.project} --name calc\n'));
      expect(fx.log, contains('bead store from an earlier city'));
      expect(Directory('${fx.project}/.beads').existsSync(), isFalse);
      final kept = Directory(fx.project)
          .listSync()
          .map((e) => e.path.split('/').last)
          .where((n) => n.startsWith('.beads.before-aiteam-'))
          .toList();
      expect(kept, hasLength(1));
      expect(
        File('${fx.project}/${kept.single}/config.yaml').readAsStringSync(),
        contains('issue_prefix: sp'),
      );
    });

    test('init keeps an existing origin', () async {
      await fx.install();
      final elsewhere = '${fx.root.path}/elsewhere.git';
      await Process.run('git', ['init', '-q', '--bare', elsewhere]);
      await Process.run('git', [
        'remote',
        'add',
        'origin',
        elsewhere,
      ], workingDirectory: fx.project);
      await fx.init();
      expect(Directory(fx.origin).existsSync(), isFalse);
      expect(fx.read('${fx.aiteamDir}/config'), contains('origin=$elsewhere'));
    });

    test(
      'init resolves a /root/projects path into the rootfs (TEAM-302)',
      () async {
        // The app names the project as the managed server sees it; the
        // native side finds it under the proot-distro rootfs.
        final rootfs =
            '${fx.prefix}/var/lib/proot-distro/installed-rootfs/opencode-ubuntu';
        final inside = '$rootfs/root/projects/calc';
        Directory('$rootfs/root/projects').createSync(recursive: true);
        Process.runSync('cp', ['-r', fx.project, inside]);
        await fx.install();
        final result = await fx.verb([
          'init',
          '/root/projects/calc',
          '--city',
          'phone',
        ]);
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}${result.stderr}\n${fx.log}',
        );
        final status = await fx.status();
        expect(status.rawPhase, 'city-ready');
        expect(status.project, inside);
        expect(Directory('$inside.git').existsSync(), isTrue);
      },
    );

    test('init before install and with a bad project fails honestly', () async {
      var result = await fx.verb(['init', fx.project]);
      expect(result.exitCode, isNot(0));
      expect((await fx.status()).rawPhase, 'failed:not-installed');
      await fx.install();
      result = await fx.verb(['init', '${fx.root.path}/nowhere']);
      expect((await fx.status()).rawPhase, 'failed:project-missing');
      Directory('${fx.root.path}/plain').createSync();
      result = await fx.verb(['init', '${fx.root.path}/plain']);
      expect((await fx.status()).rawPhase, 'failed:project-not-git');
    });

    test('start holds the wake lock, detaches the supervisor, registers, '
        'waits for health; stop takes it all down', () async {
      await fx.install();
      await fx.init();
      await fx.start();
      var status = await fx.status();
      expect(status.phase, TeamRuntimePhase.ready, reason: fx.log);
      expect(status.isReady, isTrue);
      expect(status.health, 'ok');
      expect(status.agents, 2);
      expect(status.supervisorPid, isNotNull);
      expect(status.killedByAndroid, isFalse);
      expect(fx.supervisorUp, isTrue);
      final calls = fx.gcCalls.split('\n').where((l) => l.isNotEmpty).toList();
      final run = calls.indexWhere((c) => c.startsWith('supervisor run'));
      final register = calls.indexWhere((c) => c.startsWith('register'));
      expect(run, greaterThan(-1));
      expect(register, greaterThan(run));
      expect(calls[run], 'supervisor run cwd=${fx.cityDir}');
      expect(calls[register], 'register ${fx.cityDir} --name phone --yes');
      expect(fx.read('${fx.ocDir}/wake.log').trim(), 'termux-wake-lock');
      // The supervisor is not a child of the finished start verb.
      final stat = File(
        '/proc/${status.supervisorPid}/stat',
      ).readAsStringSync();
      final fields = stat.substring(stat.lastIndexOf(') ') + 2).split(' ');
      expect(fields[1], '1', reason: 'reparented to init: $stat');

      // A second start is a no-op on a healthy city.
      await fx.start();
      expect((await fx.status()).supervisorPid, status.supervisorPid);
      expect(fx.gcCalls.split('supervisor run').length - 1, 1);

      final stop = await fx.verb(['stop']);
      expect(stop.exitCode, 0, reason: '${stop.stdout}${stop.stderr}');
      status = await fx.status();
      expect(status.phase, TeamRuntimePhase.stopped);
      expect(status.supervisorPid, isNull);
      expect(fx.supervisorUp, isFalse);
      expect(fx.gcCalls, contains('supervisor stop'));
      expect(
        fx.read('${fx.ocDir}/wake.log').trim(),
        'termux-wake-lock\ntermux-wake-lock\ntermux-wake-unlock',
      );
    });

    test(
      'a supervisor that vanished while ready reads as killed by Android',
      () async {
        await fx.install();
        await fx.init();
        await fx.start();
        final pid = (await fx.status()).supervisorPid!;
        Process.killPid(pid, ProcessSignal.sigkill);
        File('${fx.aiteamDir}/supervisor.marker').deleteSync();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        final status = await fx.status();
        expect(status.phase, TeamRuntimePhase.ready);
        expect(status.killedByAndroid, isTrue);
        expect(status.isReady, isFalse);
        expect(status.health, 'unreachable');
        expect(status.supervisorPid, isNull);
        // Start again recovers.
        await fx.start();
        final again = await fx.status();
        expect(again.isReady, isTrue);
        expect(again.killedByAndroid, isFalse);
      },
    );

    test('start without a city or a supervisor that dies fails', () async {
      await fx.install();
      var result = await fx.verb(['start']);
      expect(result.exitCode, isNot(0));
      expect((await fx.status()).rawPhase, 'failed:no-city');
      await fx.init();
      // A gc whose supervisor exits at once.
      File('${fx.bin}/gc').writeAsStringSync(
        '#!/bin/bash\ncase "\$1" in version|--version) echo gc 1;; supervisor) exit 3;; esac\n',
      );
      result = await fx.verb(['start']);
      expect(result.exitCode, isNot(0));
      final status = await fx.status();
      expect(status.rawPhase, 'failed:supervisor-exited');
      expect(status.lastError, contains('exited'));
    });

    test(
      'remove deletes only the runtime and leaves the project and origin',
      () async {
        await fx.install();
        await fx.init();
        await fx.start();
        // Something else of the user's next to ours must survive too.
        File('${fx.bin}/keep-me').writeAsStringSync('x');
        final result = await fx.verb(['remove']);
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        final removed = (result.stdout as String)
            .split('\n')
            .where((l) => l.startsWith('[aiteam] removed '))
            .map((l) => l.substring('[aiteam] removed '.length))
            .toSet();
        expect(removed, {
          '${fx.bin}/gc',
          '${fx.bin}/bd',
          '${fx.bin}/dolt',
          '${fx.bin}/opencode',
          '${fx.home}/.gc',
          '${fx.home}/.dolt',
          fx.aiteamDir,
        });
        for (final path in removed) {
          expect(
            FileSystemEntity.typeSync(path),
            FileSystemEntityType.notFound,
            reason: path,
          );
        }
        expect(Directory(fx.cityDir).existsSync(), isFalse);
        expect(fx.supervisorUp, isFalse);
        // Untouched: the project, its origin, other binaries, OpenCode's own state.
        expect(File('${fx.project}/calc.py').existsSync(), isTrue);
        expect(Directory('${fx.project}/.git').existsSync(), isTrue);
        expect(Directory(fx.origin).existsSync(), isTrue);
        expect(File('${fx.bin}/keep-me').existsSync(), isTrue);
        expect(File(fx.script).existsSync(), isTrue);
        final status = await fx.status();
        expect(status.phase, TeamRuntimePhase.idle);
        expect(status.installed, isFalse);
        expect(status.hasCity, isFalse);
        expect(status.removed, containsAll(removed));
        expect(
          fx.read('${fx.ocDir}/wake.log'),
          endsWith('termux-wake-unlock\n'),
        );
      },
    );

    test('remove never deletes a foreign opencode in \$PREFIX/bin', () async {
      await fx.install();
      File('${fx.bin}/opencode').writeAsStringSync('#!/bin/bash\necho real\n');
      await fx.verb(['remove']);
      expect(File('${fx.bin}/opencode').existsSync(), isTrue);
      expect(File('${fx.bin}/gc').existsSync(), isFalse);
    });

    test('a verb that dies mid-way reads as failed, not busy forever', () async {
      await fx.install();
      File('${fx.aiteamDir}/state').writeAsStringSync(
        'phase=downloading\nmessage=Downloading gc\nverb=install\npid=999999\n'
        'supervisor_pid=\nupdated_at=1\n',
      );
      final status = await fx.status();
      expect(status.phase, TeamRuntimePhase.failed);
      expect(status.busy, isFalse);
      expect(
        status.lastError,
        'install stopped unexpectedly while downloading',
      );
      expect(status.rawPhase, 'failed:interrupted');
    });

    test(
      'every verb appends to aiteam.log and the OpenCode install log',
      () async {
        // A manager.sh stand-in with the real write-log contract.
        File('${fx.ocDir}/manager.sh').writeAsStringSync(
          '#!/bin/bash\n[ "\$1" = write-log ] && cat >> "\$HOME/.oc/install.log"\n',
        );
        Process.runSync('chmod', ['755', '${fx.ocDir}/manager.sh']);
        await fx.install();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(fx.log, contains('[aiteam] install started at'));
        expect(fx.log, contains('[aiteam] install finished'));
        expect(
          fx.read('${fx.ocDir}/install.log'),
          contains('[aiteam] install finished'),
        );
      },
    );

    test(
      'the bridge dispatch queues, detaches and refuses while busy',
      () async {
        // Bundled manifest: written by the dispatch next to aiteam.sh.
        final dispatch = await fx.dispatch(
          'install',
          args: ['${fx.ocDir}/aiteam-manifest.json'],
          manifestJson: fx.manifestJson,
        );
        expect(
          dispatch.exitCode,
          0,
          reason: '${dispatch.stdout}${dispatch.stderr}',
        );
        expect(dispatch.stdout, matches(RegExp(r'aiteam-started:[0-9]+')));
        expect(
          File(
            '${fx.ocDir}/aiteam-manifest.json',
          ).readAsStringSync().trimRight(),
          fx.manifestJson.trimRight(),
        );
        // Straight after dispatch the status is busy (queued or beyond).
        final first = await fx.status();
        expect(first.busy, isTrue, reason: first.toString());
        // A second verb is refused while the first runs.
        final busy = await fx.dispatch('start');
        expect(busy.exitCode, 75);
        expect(busy.stderr, contains('aiteam-busy:install:'));
        final done = await fx.waitIdle();
        expect(
          done.phase,
          TeamRuntimePhase.installed,
          reason: '$done\n${fx.log}',
        );
        expect(done.verb, 'install');
        // The inline verbs run through the same dispatch.
        final status = await Process.run('bash', [
          '-c',
          TermuxBridge.aiteamStatusScript(),
        ], environment: fx.environment);
        expect(
          TeamRuntimeStatus.parse(status.stdout as String).installed,
          isTrue,
        );
        final init = await fx.dispatch('init', args: [fx.project]);
        expect(init.exitCode, 0, reason: '${init.stdout}${init.stderr}');
        expect((await fx.waitIdle()).phase, TeamRuntimePhase.cityReady);
        final start = await fx.dispatch('start');
        expect(start.exitCode, 0, reason: '${start.stdout}${start.stderr}');
        final ready = await fx.waitIdle();
        expect(ready.isReady, isTrue, reason: fx.log);
        final stop = await fx.dispatch('stop');
        expect(stop.exitCode, 0);
        expect(
          (await fx.waitIdle()).phase,
          TeamRuntimePhase.stopped,
          reason: fx.log,
        );
      },
    );
  });

  group('TeamRuntimeStatus', () {
    test('parses every phase and the failed reason', () {
      for (final entry in {
        'idle': TeamRuntimePhase.idle,
        'queued': TeamRuntimePhase.queued,
        'downloading': TeamRuntimePhase.downloading,
        'verifying': TeamRuntimePhase.verifying,
        'installing-packages': TeamRuntimePhase.installingPackages,
        'installed': TeamRuntimePhase.installed,
        'creating-city': TeamRuntimePhase.creatingCity,
        'city-ready': TeamRuntimePhase.cityReady,
        'starting': TeamRuntimePhase.starting,
        'ready': TeamRuntimePhase.ready,
        'stopping': TeamRuntimePhase.stopping,
        'stopped': TeamRuntimePhase.stopped,
        'removing': TeamRuntimePhase.removing,
        'failed': TeamRuntimePhase.failed,
        'failed:checksum-mismatch gc': TeamRuntimePhase.failed,
        'something-new': TeamRuntimePhase.unknown,
      }.entries) {
        expect(
          TeamRuntimePhase.parse(entry.key),
          entry.value,
          reason: entry.key,
        );
      }
      expect(TeamRuntimePhase.downloading.isTransient, isTrue);
      expect(TeamRuntimePhase.ready.isTransient, isFalse);
      final status = TeamRuntimeStatus.parse(
        '{"installed":true,"versions":{"gc":"1.4.1","bd":null,"dolt":"2.3.3"},'
        '"phase":"failed","message":"gc did not match","verb":"install",'
        '"busy":false,"pid":null,"supervisor_pid":null,"health":null,'
        '"agents":null,"city":null,"rig":null,"project":null,'
        '"url":"http://127.0.0.1:8372","last_error":"gc did not match",'
        '"state_phase":"failed:checksum-mismatch gc","reason":"checksum-mismatch gc",'
        '"killed_by_android":false,"removed":[],"log":"/l","updated_at":1700000000}',
      );
      expect(status.phase, TeamRuntimePhase.failed);
      expect(status.rawPhase, 'failed:checksum-mismatch gc');
      expect(status.reason, 'checksum-mismatch gc');
      expect(
        TeamRuntimeStatus.parse('{"phase":"failed:x"}').reason,
        'x',
        reason: 'a status without state_phase still yields the token',
      );
      expect(status.versions, {'gc': '1.4.1', 'dolt': '2.3.3'});
      expect(status.checksumMismatch, isTrue);
      expect(status.city, '');
      expect(status.hasCity, isFalse);
      expect(status.updatedAt, DateTime.utc(2023, 11, 14, 22, 13, 20));
      expect(TeamRuntimeStatus.parse('garbage'), TeamRuntimeStatus.unreadable);
      expect(TeamRuntimeStatus.parse('[1]').phase, TeamRuntimePhase.unknown);
    });

    test('killedByAndroid and readiness', () {
      final killed = TeamRuntimeStatus.parse(
        '{"phase":"ready","killed_by_android":true,"health":"unreachable",'
        '"city":"phone","supervisor_pid":null}',
      );
      expect(killed.killedByAndroid, isTrue);
      expect(killed.isReady, isFalse);
      final ready = TeamRuntimeStatus.parse(
        '{"phase":"ready","killed_by_android":false,"health":"ok",'
        '"city":"phone","supervisor_pid":42,"agents":1}',
      );
      expect(ready.isReady, isTrue);
      expect(ready.supervisorPid, 42);
      expect(ready.agents, 1);
    });
  });

  group('TermuxTeamRuntime', () {
    test(
      'supportsAiTeam needs an arm64 device and an arm64 manifest',
      () async {
        final manifest = File('assets/aiteam/manifest.json').readAsStringSync();
        final parsed = TeamRuntimeManifest.parse(manifest)!;
        expect(parsed.arch, 'arm64');
        expect(parsed.gascity, '1.4.1');
        expect(parsed.baseUrl, 'http://100.126.15.6:8876/aiteam/');
        expect(
          manifest,
          File('tool/host/aiteam-manifest-2026-09-11.json').readAsStringSync(),
          reason: 'the asset is the pinned manifest',
        );
        Future<String> noRun(String script, {Duration? timeout}) async => '';
        final phone = TermuxTeamRuntime(
          runner: noRun,
          manifestLoader: () async => manifest,
          archProbe: () async => 'aarch64\n',
        );
        expect(await phone.supportsAiTeam, isTrue);
        expect(await phone.unsupportedReason, isNull);
        final x86 = TermuxTeamRuntime(
          runner: noRun,
          manifestLoader: () async => manifest,
          archProbe: () async => 'x86_64',
        );
        expect(await x86.supportsAiTeam, isFalse);
        expect(await x86.unsupportedReason, contains('64-bit ARM'));
        final noManifest = TermuxTeamRuntime(
          runner: noRun,
          manifestLoader: () async => null,
          archProbe: () async => 'aarch64',
        );
        expect(await noManifest.supportsAiTeam, isFalse);
        expect(await noManifest.unsupportedReason, contains('ships no'));
        expect(TeamRuntimeManifest.parse('{"schema":2}'), isNull);
        expect(TeamRuntimeManifest.parse('nope'), isNull);
      },
    );

    test(
      'a verb dispatches, polls status until idle and answers the last',
      () async {
        final scripts = <String>[];
        var polls = 0;
        Future<String> runner(String script, {Duration? timeout}) async {
          scripts.add(script);
          if (script.contains('exec bash "\$AITEAM" status')) {
            polls++;
            return polls < 3
                ? '{"phase":"downloading","busy":true,"pid":7}'
                : '{"phase":"installed","busy":false,"installed":true}';
          }
          return 'aiteam-started:7\n';
        }

        final runtime = TermuxTeamRuntime(
          runner: runner,
          manifestLoader: () async => fx.manifestJson,
          archProbe: () async => 'aarch64',
          pollInterval: const Duration(milliseconds: 10),
        );
        final status = await runtime.install();
        expect(status.phase, TeamRuntimePhase.installed);
        expect(polls, 3);
        expect(
          scripts.first,
          contains("'install' '${TermuxBridge.aiteamManifestPath}'"),
        );
        expect(scripts.first, contains('OC_AITEAM_MANIFEST_EOF'));
        expect(scripts.first, contains('"gascity": "1.4.1"'));
        expect(scripts.first, contains('bash "\$AITEAM" queue \'install\''));
        expect(scripts.first, contains('nohup bash "\$AITEAM" \'install\''));

        scripts.clear();
        await runtime.install(manifestUrl: 'https://example.test/m.json');
        expect(
          scripts.first,
          contains("'install' 'https://example.test/m.json'"),
        );
        expect(scripts.first, isNot(contains('OC_AITEAM_MANIFEST_EOF')));

        scripts.clear();
        await runtime.init(
          "/root/projects/it's here",
          city: 'phone',
          rig: 'app',
        );
        expect(
          scripts.first,
          contains(
            "'init' '/root/projects/it'\"'\"'s here' '--city' 'phone' '--rig' 'app'",
          ),
        );
        for (final verb in ['start', 'stop', 'remove']) {
          scripts.clear();
          await switch (verb) {
            'start' => runtime.start(),
            'stop' => runtime.stop(),
            _ => runtime.remove(),
          };
          expect(scripts.first, contains("nohup bash \"\$AITEAM\" '$verb'"));
        }
      },
    );

    test(
      'a refused dispatch is a bridge error, and statusStream ends on idle',
      () async {
        Future<String> runner(String script, {Duration? timeout}) async {
          if (script.contains('exec bash "\$AITEAM" status')) {
            return '{"phase":"ready","busy":false,"health":"ok","city":"phone"}';
          }
          throw const TermuxBridgeException(
            'aiteam-busy:install:12',
            code: 'command_failed',
          );
        }

        final runtime = TermuxTeamRuntime(
          runner: runner,
          manifestLoader: () async => null,
          archProbe: () async => 'aarch64',
        );
        await expectLater(
          runtime.start(),
          throwsA(isA<TermuxBridgeException>()),
        );
        await expectLater(
          runtime.install(),
          throwsA(
            isA<TermuxBridgeException>().having(
              (e) => e.code,
              'code',
              'aiteam_manifest_missing',
            ),
          ),
        );
        final statuses = await runtime.statusStream().toList();
        expect(statuses, hasLength(1));
        expect(statuses.single.isReady, isTrue);
      },
    );

    test(
      'logTail, managedProjects and createManagedProject (TEAM-302)',
      () async {
        final scripts = <String>[];
        final runtime = TermuxTeamRuntime(
          runner: (script, {Duration? timeout}) async {
            scripts.add(script);
            if (script.contains('aiteam.log')) return '[aiteam] hello\n';
            if (script.contains('mkdir -p')) return '/root/projects/new-app\n';
            if (script.contains('proot-distro')) {
              return 'calc\nnotes\n';
            }
            return '';
          },
          manifestLoader: () async => null,
          archProbe: () async => 'aarch64',
        );
        expect(await runtime.logTail(lines: 50), '[aiteam] hello\n');
        expect(scripts.last, contains('tail -n 50'));
        expect(scripts.last, contains('.oc/aiteam/aiteam.log'));
        expect(await runtime.managedProjects(), [
          '/root/projects/calc',
          '/root/projects/notes',
        ]);
        expect(scripts.last, contains('containers/opencode-ubuntu/rootfs'));
        expect(scripts.last, contains('installed-rootfs/opencode-ubuntu'));
        expect(
          await runtime.createManagedProject('new-app'),
          '/root/projects/new-app',
        );
        await expectLater(
          runtime.createManagedProject('../x'),
          throwsA(isA<TermuxBridgeException>()),
        );
        expect(
          () => TermuxBridge.aiteamLogTailScript(lines: 0),
          throwsArgumentError,
        );
        // A bridge failure reads as no log and no projects, never an error.
        final broken = TermuxTeamRuntime(
          runner: (_, {Duration? timeout}) async =>
              throw const TermuxBridgeException('gone'),
          manifestLoader: () async => null,
          archProbe: () async => 'aarch64',
        );
        expect(await broken.logTail(), '');
        expect(await broken.managedProjects(), isEmpty);
        // The projects script lists directories only, skipping bare origins.
        final tmp = Directory.systemTemp.createTempSync('oc-projects-');
        addTearDown(() => tmp.deleteSync(recursive: true));
        final projects =
            '${tmp.path}/var/lib/proot-distro/installed-rootfs/opencode-ubuntu/root/projects';
        Directory('$projects/calc').createSync(recursive: true);
        Directory('$projects/calc.git').createSync(recursive: true);
        Directory('$projects/zeta').createSync(recursive: true);
        File('$projects/README').writeAsStringSync('');
        final listed = Process.runSync(
          'bash',
          ['-c', TermuxBridge.aiteamProjectsScript()],
          environment: {'PREFIX': tmp.path},
        );
        expect(listed.exitCode, 0, reason: '${listed.stderr}');
        expect(listed.stdout.toString().trim().split('\n'), ['calc', 'zeta']);
      },
    );

    test('the manifest sums the declared download bytes', () {
      final manifest = TeamRuntimeManifest.parse(
        File('assets/aiteam/manifest.json').readAsStringSync(),
      )!;
      expect(manifest.totalBytes, greaterThan(250 * 1000 * 1000));
      expect(
        TeamRuntimeManifest.parse(
          '{"schema":1,"arch":"arm64","files":{"gc":{},"bd":{},"dolt":{},"wrapper":{}}}',
        )!.totalBytes,
        0,
      );
    });

    test('the phone config is Gas City on loopback with this phone as host', () {
      final runtime = TermuxTeamRuntime(
        runner: (script, {Duration? timeout}) async => '',
        manifestLoader: () async => null,
        archProbe: () async => 'aarch64',
      );
      final status = TeamRuntimeStatus.parse(
        '{"phase":"ready","health":"ok","city":"phone","url":"http://127.0.0.1:8372"}',
      );
      final config = runtime.phoneOrchestrationConfig(
        status,
        enabledAt: DateTime.utc(2026, 9, 11),
      );
      expect(config.provider, OrchestrationProvider.gascity);
      expect(config.url, 'http://127.0.0.1:8372');
      expect(config.city, 'phone');
      expect(config.hostMode, OrchestrationHostMode.phone);
      expect(config.hostKind, OrchestrationHostKind.phone);
      expect(config.front, isFalse);
      expect(config.enabledAt, DateTime.utc(2026, 9, 11));
      final restored = OrchestrationConfig.fromJson(config.toJson())!;
      expect(restored.hostMode, OrchestrationHostMode.phone);
      expect(restored.hostKind, OrchestrationHostKind.phone);
    });
  });

  group('GasCityGateway on the phone', () {
    test('loopback + phone host turns controls on without a front and '
        'posts with X-GC-Request only', () async {
      final requests = <HttpRequest>[];
      final bodies = <String>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        requests.add(request);
        bodies.add(await utf8.decoder.bind(request).join());
        request.response
          ..statusCode = 202
          ..headers.contentType = ContentType.json
          ..write('{"request_id":"corr-1"}');
        await request.response.close();
      });
      final url = 'http://127.0.0.1:${server.port}';
      final phone = GasCityGateway(
        url: url,
        city: 'phone',
        hostMode: OrchestrationHostMode.phone,
      );
      addTearDown(phone.close);
      expect(phone.loopbackControl, isTrue);
      expect(
        phone.capabilities.asMap(),
        OrchestrationCapabilities.gascityLoopback.asMap(),
      );
      expect(phone.capabilities.anyControl, isTrue);
      expect(phone.capabilities.phoneHost, isTrue);
      expect(phone.capabilities.mergeReadiness, isFalse);
      final receipt = await phone.assign(
        'oc-1',
        agentId: 'gastown.polecat',
        requestId: 'req-1',
      );
      expect(
        receipt.status,
        MutationReceiptStatus.accepted,
        reason: receipt.message,
      );
      expect(receipt.correlationId, 'corr-1');
      expect(requests, hasLength(1));
      expect(requests.single.uri.path, '/v0/city/phone/sling');
      expect(bodies.single, contains('"bead":"oc-1"'));
      expect(requests.single.headers.value('x-gc-request'), 'req-1');
      expect(requests.single.headers.value('idempotency-key'), isNull);
      // The front-only routes stay absent on loopback.
      expect(await phone.mergeReadiness('run-1'), isNull);
      expect(await phone.policy(), isNull);
      expect(
        (await phone.merge('run-1', requestId: 'm')).message,
        'front required',
      );
      expect(requests, hasLength(1));

      // The same URL as a computer host stays read-only (no front).
      final computer = GasCityGateway(url: url, city: 'phone');
      addTearDown(computer.close);
      expect(computer.loopbackControl, isFalse);
      expect(computer.capabilities.anyControl, isFalse);
      expect(
        (await computer.assign('oc-1', agentId: 'a', requestId: 'r')).message,
        'front required',
      );
      // And a phone host off loopback never gets the shortcut.
      final tailnet = GasCityGateway(
        url: 'http://100.64.0.9:8372',
        city: 'phone',
        hostMode: OrchestrationHostMode.phone,
      );
      addTearDown(tailnet.close);
      expect(tailnet.loopbackControl, isFalse);
      expect(tailnet.capabilities.anyControl, isFalse);
    });

    test('gascityLoopback is gascityRead plus the control switches, '
        'controlCreateWork (TEAM-306) and phoneHost', () {
      final read = OrchestrationCapabilities.gascityRead.asMap();
      final loopback = OrchestrationCapabilities.gascityLoopback.asMap();
      final front = OrchestrationCapabilities.gascityFront.asMap();
      for (final entry in loopback.entries) {
        final expected = switch (entry.key) {
          // The direct task path exists only where the planner can be
          // off and the supervisor is reachable: the phone's loopback.
          'phoneHost' || 'controlCreateWork' => true,
          final key when key.startsWith('control') => front[key],
          final key => read[key],
        };
        expect(entry.value, expected, reason: entry.key);
      }
      expect(front['controlCreateWork'], isFalse);
    });
  });
}
