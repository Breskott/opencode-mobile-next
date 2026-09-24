// The in-app AI Team runtime (lib/builtin/team/builtin_team.dart): its
// scripts parse in dash and bash, the status output is read right, the
// plugin config is the phone's loopback one on the team's own port, and
// turn-on runs store → project → supervisor → health in order against a
// fake Linux.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/builtin/setup/aiteam_scripts.dart';
import 'package:opencode_mobile/builtin/team/builtin_team.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/profiles.dart';

/// Answers the channel like BuiltinLinux.kt, recording every call.
class _FakeLinux {
  _FakeLinux(this.channel);

  final MethodChannel channel;
  final calls = <MethodCall>[];
  final services = <String>{};
  int Function(String script) exitCodeFor = (_) => 0;
  String Function(String script) outputFor = (_) => '';

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          final args = (call.arguments as Map?) ?? const {};
          switch (call.method) {
            case 'status':
              return {
                'installed': true,
                'phase': 'ready',
                'services': services.toList(),
              };
            case 'run':
              final script = args['script'] as String;
              return {
                'exitCode': exitCodeFor(script),
                'output': outputFor(script),
              };
            case 'startService':
              services.add(args['name'] as String);
              return null;
            case 'stopService':
              services.remove(args['name'] as String);
              return null;
            case 'serviceLog':
              return 'supervisor log tail';
          }
          return null;
        });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(
    () => debugPlatformCapabilities = const PlatformCapabilities(
      platform: TargetPlatform.android,
      isWeb: false,
    ),
  );
  tearDown(() => debugPlatformCapabilities = null);

  group('scripts', () {
    final shells = [
      for (final shell in ['dash', 'bash'])
        if (Process.runSync('sh', ['-c', 'command -v $shell']).exitCode == 0)
          shell,
    ];

    test('every team script parses', () async {
      final scripts = {
        'city': BuiltinTeam.cityScript,
        'rig': BuiltinTeam.rigScript('/root/projects/my app', 'my-app'),
        'service': BuiltinTeam.serviceScript,
        'register': BuiltinTeam.registerScript,
        'status': BuiltinTeam.statusScript,
      };
      for (final entry in scripts.entries) {
        for (final shell in shells) {
          final result = await Process.run(shell, ['-n', '-c', entry.value]);
          expect(
            result.exitCode,
            0,
            reason: '${entry.key} in $shell: ${result.stderr}',
          );
        }
      }
    }, skip: shells.isEmpty ? 'no dash or bash here' : false);

    test('the supervisor listens on loopback only, on its own port', () {
      expect(BuiltinTeam.supervisorConfig, contains('bind = "127.0.0.1"'));
      expect(BuiltinTeam.supervisorConfig, contains('port = 8472'));
      expect(
        BuiltinTeam.supervisorConfig,
        contains('allowed_hosts = ["127.0.0.1", "localhost"]'),
      );
      // Rewritten on every start, not only when the store is made.
      expect(BuiltinTeam.serviceScript, contains('bind = "127.0.0.1"'));
      expect(BuiltinTeam.serviceScript, contains('exec gc supervisor run'));
    });

    test('a project is added once, with the lean team', () {
      final script = BuiltinTeam.rigScript('/root/projects/demo', 'demo');
      expect(script, contains('gc rig add "\$project" --name "\$rig"'));
      expect(script, contains('max_active_sessions = 1'));
      expect(script, contains('name = "gastown.mayor"'));
      expect(script, contains('/root/aiteam/origins/\$rig.git'));
      expect(
        () => BuiltinTeam.rigScript('relative', 'demo'),
        throwsArgumentError,
      );
      expect(
        () => BuiltinTeam.rigScript('/root/projects/x', 'x; rm -rf /'),
        throwsArgumentError,
      );
    });

    test('installed means the component check passes, every line', () async {
      final dir = await Directory.systemTemp.createTemp('oc-team-bin');
      addTearDown(() => dir.delete(recursive: true));
      final bin = Directory('${dir.path}/bin')..createSync();
      final agentBin = Directory('${dir.path}/agent-bin')..createSync();
      void fake(String name, String output) {
        final file = File('${bin.path}/$name')
          ..writeAsStringSync('#!/bin/sh\necho "$output"\n');
        Process.runSync('chmod', ['755', file.path]);
      }

      fake('gc', AiTeamPins.gascity);
      fake('bd', 'bd version ${AiTeamPins.beads} (abc)');
      fake('dolt', 'dolt version ${AiTeamPins.dolt}');
      for (final tool in ['tmux', 'jq', 'lsof', 'git']) {
        fake(tool, tool);
      }
      final script = BuiltinTeam.statusScript.replaceAll(
        AiTeamScripts.agentBin,
        agentBin.path,
      );
      Future<String> run() async =>
          (await Process.run(
                'sh',
                ['-c', script],
                environment: {'PATH': '${bin.path}:/usr/bin:/bin'},
              )).stdout
              as String;

      // Everything answers, but the agents' opencode is missing: a check
      // whose `set -e` were ignored would still say installed.
      expect(await run(), isNot(contains('installed')));
      File('${agentBin.path}/opencode').writeAsStringSync('#!/bin/sh\n');
      Process.runSync('chmod', ['755', '${agentBin.path}/opencode']);
      expect(await run(), contains('installed'));
      // An older Gas City is not the pinned one.
      fake('gc', '1.4.0');
      expect(await run(), isNot(contains('installed')));
    });

    test('the status script reads the store in a real shell', () async {
      final dir = await Directory.systemTemp.createTemp('oc-team');
      addTearDown(() => dir.delete(recursive: true));
      final city = File('${dir.path}/city.toml');
      await city.writeAsString('''
[workspace]
provider = "opencode"

[[rigs]]
name = "demo"
default_branch = "master"

[[rigs]]
name = "my-app"

[[patches.agent]]
name = "gastown.polecat"
dir = "demo"
''');
      final script = BuiltinTeam.statusScript.replaceAll(
        BuiltinTeam.cityDir,
        dir.path,
      );
      final result = await Process.run('sh', ['-c', script]);
      final state = BuiltinTeam.parseStatus(result.stdout as String);
      expect(state.rigs, ['demo', 'my-app']);
      expect(state.hasProject('/root/projects/demo'), isTrue);
      expect(state.hasProject('/root/projects/other'), isFalse);
    });
  });

  test('project names become safe team names', () {
    expect(BuiltinTeam.rigName('/root/projects/my app'), 'my-app');
    expect(BuiltinTeam.rigName('/root/projects/demo/'), 'demo');
    expect(BuiltinTeam.rigName('/root/projects/..'), 'project');
  });

  test('the plugin config is the phone team on loopback', () {
    final config = BuiltinTeam.config(now: DateTime.utc(2026, 9, 24));
    expect(config.url, 'http://127.0.0.1:8472');
    expect(config.city, 'phone');
    expect(config.hostMode, OrchestrationHostMode.phone);
    expect(config.front, isFalse);
    expect(BuiltinTeam.isBuiltinConfig(config), isTrue);
    // Termux's team on 8372 is not this one.
    expect(
      BuiltinTeam.isBuiltinConfig(
        config.copyWith(url: 'http://127.0.0.1:8372'),
      ),
      isFalse,
    );
    expect(BuiltinTeam.isBuiltinConfig(null), isFalse);
  });

  group('turn on', () {
    late _FakeLinux fake;
    late BuiltinTeam team;
    var supervisorUp = false;
    var cityUp = false;

    setUp(() {
      fake = _FakeLinux(const MethodChannel(BuiltinLinux.channelName))
        ..install();
      supervisorUp = false;
      cityUp = false;
      team = BuiltinTeam(
        linux: BuiltinLinux(),
        pollInterval: Duration.zero,
        httpGet: (uri) async {
          if (uri.path == '/health') {
            return supervisorUp ? '{"status":"ok"}' : null;
          }
          return cityUp ? '{"status":"ok"}' : '{"status":"starting"}';
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fake.channel, null);
    });

    test('store, project, supervisor as a service, register, health', () async {
      fake.outputFor = (script) {
        if (script.contains('gc register')) {
          supervisorUp = true;
          cityUp = true;
        }
        return '';
      };
      final stages = <BuiltinTeamStage>[];
      // The supervisor answers once the service runs.
      supervisorUp = true;
      await team.turnOn(
        '/root/projects/demo',
        notice: 'OpenCode and AI Team are running',
        onStage: stages.add,
      );
      expect(stages, [
        BuiltinTeamStage.preparing,
        BuiltinTeamStage.addingProject,
        BuiltinTeamStage.starting,
        BuiltinTeamStage.waiting,
      ]);
      final methods = fake.calls.map((call) => call.method).toList();
      final runs = [
        for (final call in fake.calls)
          if (call.method == 'run') (call.arguments as Map)['script'] as String,
      ];
      expect(runs.first, contains('gc init'));
      expect(runs[1], contains('gc rig add'));
      expect(runs.last, contains('gc register'));
      final start = fake.calls.firstWhere((c) => c.method == 'startService');
      expect((start.arguments as Map)['name'], 'aiteam');
      expect((start.arguments as Map)['port'], 8472);
      expect(
        (start.arguments as Map)['notice'],
        'OpenCode and AI Team are running',
      );
      expect(
        methods.indexOf('startService'),
        lessThan(methods.lastIndexOf('run')),
      );
      expect(fake.services, contains('aiteam'));
    });

    test('a failing step says which, with its output', () async {
      fake.exitCodeFor = (script) => script.contains('gc rig add') ? 65 : 0;
      fake.outputFor = (script) => script.contains('gc rig add')
          ? '[oc] /root/projects/demo is not a git project'
          : '';
      await expectLater(
        team.turnOn('/root/projects/demo', notice: 'n'),
        throwsA(
          isA<BuiltinTeamException>()
              .having((e) => e.stage, 'stage', BuiltinTeamStage.addingProject)
              .having((e) => e.detail, 'detail', contains('not a git project')),
        ),
      );
      expect(fake.calls.where((c) => c.method == 'startService'), isEmpty);
    });

    test('a supervisor that dies while starting is reported', () async {
      fake.install();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fake.channel, (call) async {
            fake.calls.add(call);
            switch (call.method) {
              case 'status':
                // It never stays up.
                return {'installed': true, 'phase': 'ready', 'services': []};
              case 'run':
                return {'exitCode': 0, 'output': ''};
              case 'serviceLog':
                return 'panic: something';
            }
            return null;
          });
      await expectLater(
        team.start(notice: 'n'),
        throwsA(
          isA<BuiltinTeamException>()
              .having((e) => e.exited, 'exited', isTrue)
              .having((e) => e.detail, 'detail', 'panic: something'),
        ),
      );
    });

    test('ensureRunning starts only a stopped team', () async {
      await team.ensureRunning(notice: 'n');
      expect(fake.services, {'aiteam'});
      fake.calls.clear();
      await team.ensureRunning(notice: 'n');
      expect(fake.calls.where((c) => c.method == 'startService'), isEmpty);
    });
  });
}
