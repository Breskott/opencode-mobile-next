// The AI Team setup component (lib/builtin/setup/aiteam_scripts.dart and
// its registry entry): opt-in and install-only, so screen A's promise does
// not move; pinned downloads per CPU with their checksums; the local-mirror
// override; the engine's selection with AI Team; the "Adding AI Team" job
// label; the named-service calls on the Linux channel; and discovery leaving
// the in-app server alone.
import 'dart:ffi' show Abi;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/builtin/setup/aiteam_scripts.dart';
import 'package:opencode_mobile/builtin/setup/components.dart';
import 'package:opencode_mobile/builtin/setup/setup_contract.dart';
import 'package:opencode_mobile/builtin/setup/setup_engine.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_selection.dart';
import 'package:opencode_mobile/ui/widgets/team_discovery_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = lookupAppLocalizations(const Locale('en'));
  final registry = setupComponents(l10n);
  SetupComponent byId(String id) => registry.firstWhere((c) => c.id == id);

  group('opt-in and install only', () {
    test('the default selection and screen A totals leave AI Team out', () {
      final defaults = defaultSetupSelection(registry);
      expect(defaults, isNot(contains(SetupComponentIds.aiTeam)));
      final totals = setupTotals(
        installableComponents(expandSetupSelection(registry, defaults)),
      );
      // "About 4 minutes and ~208 MB" (docs/design/phone-setup-v2).
      expect(totals.bytes, 208 * 1000 * 1000);
      expect(setupDurationText(l10n, totals.seconds), 'About 4 minutes');
      expect(setupSizeText(l10n, totals.bytes), '208 MB');
    });

    test('AI Team is an optional install that needs OpenCode', () {
      final team = byId(SetupComponentIds.aiTeam);
      expect(team.title, 'AI Team');
      expect(team.required, isFalse);
      expect(team.defaultOn, isFalse);
      expect(team.jobStep, isFalse);
      expect(team.native, isFalse);
      expect(
        team.dependsOn,
        containsAll([SetupComponentIds.openCode, SetupComponentIds.essentials]),
      );
      expect(team.removeScript, AiTeamScripts.removeScript);
      // Install only: nothing in the job starts or registers a team.
      expect(team.installScript, isNot(contains('gc init')));
      expect(team.installScript, isNot(contains('supervisor')));
    });

    test('the engine runs AI Team after OpenCode and before the start', () {
      final job = expandSelection(registry, {SetupComponentIds.aiTeam});
      expect(job.map((c) => c.id), [
        SetupComponentIds.linux,
        SetupComponentIds.essentials,
        SetupComponentIds.node,
        SetupComponentIds.openCode,
        SetupComponentIds.aiTeam,
        SetupComponentIds.start,
      ]);
    });

    test('Customize with AI Team switched on counts its download', () {
      final chosen = {...defaultSetupSelection(registry), 'aiteam'};
      final totals = setupTotals(
        installableComponents(expandSetupSelection(registry, chosen)),
      );
      expect(totals.bytes, 208 * 1000 * 1000 + AiTeamPins.deviceDownloadBytes);
    });
  });

  group('pinned downloads', () {
    final hex = RegExp(r'^[0-9a-f]{64}$');

    test('three programs per CPU, each with a checksum and a size', () {
      for (final downloads in [AiTeamPins.arm64, AiTeamPins.x64]) {
        expect(downloads.map((d) => d.tool), ['gc', 'bd', 'dolt']);
        for (final download in downloads) {
          expect(download.sha256, matches(hex), reason: download.url);
          expect(download.bytes, greaterThan(10 * 1000 * 1000));
          expect(download.url, startsWith('https://github.com/'));
        }
      }
      expect(AiTeamPins.arm64.first.url, contains('linux_arm64'));
      expect(AiTeamPins.x64.first.url, contains('linux_amd64'));
      expect(AiTeamPins.x64.last.fileName, 'dolt-linux-amd64.tar.gz');
    });

    test('the emulator gets x86_64, everything else arm64', () {
      expect(AiTeamPins.forDevice(Abi.androidX64), AiTeamPins.x64);
      expect(AiTeamPins.forDevice(Abi.androidArm64), AiTeamPins.arm64);
    });

    test('the install script carries every URL and checksum', () {
      final script = AiTeamScripts.installScript(
        downloading: 'Downloading AI Team · {index} of {total}',
        preparing: 'Getting AI Team ready',
        baseUrlOverride: '',
      );
      for (final download in [...AiTeamPins.arm64, ...AiTeamPins.x64]) {
        expect(script, contains("'${download.url}'"));
        expect(script, contains(download.sha256));
      }
      expect(script, contains("oc_stage 'Downloading AI Team · 1 of 3'"));
      expect(script, contains("oc_stage 'Downloading AI Team · 3 of 3'"));
      expect(script, contains('oc_apt_install tmux jq lsof procps'));
      expect(script, contains(AiTeamScripts.agentWrapperScript));
      // Usage metrics off for all three programs.
      expect(script, contains('metrics.disabled true'));
      expect(script, contains('bd metrics off'));
    });

    test('a local mirror replaces the host, never the checksum', () {
      final script = AiTeamScripts.installScript(
        downloading: '{index}/{total}',
        preparing: 'ready',
        baseUrlOverride: 'http://127.0.0.1:8876/aiteam/',
      );
      expect(script, isNot(contains('github.com')));
      expect(
        script,
        contains(
          "'http://127.0.0.1:8876/aiteam/gascity_1.4.1_linux_arm64.tar.gz'",
        ),
      );
      for (final download in AiTeamPins.x64) {
        expect(script, contains(download.sha256));
      }
    });

    test('the check asks each program for its pinned version', () {
      final check = AiTeamScripts.checkScript;
      expect(check, contains("= '${AiTeamPins.gascity}' ]"));
      expect(check, contains("'^bd version ${AiTeamPins.beads}'"));
      expect(check, contains("'dolt version ${AiTeamPins.dolt}'"));
      expect(check.trim().split('\n').last, 'echo ${AiTeamPins.gascity}');
    });
  });

  group('adding tools', () {
    test('the job remembers what it adds, and the title names it', () {
      final params = SetupJobParams.adding({'python', 'aiteam'});
      expect(SetupJobParams.addingIds(params), ['python', 'aiteam']);
      expect(SetupJobParams.isFirstSetup(params), isFalse);
      expect(setupAddingTitle(l10n, registry, ['aiteam']), 'Adding AI Team');
      expect(
        setupAddingTitle(l10n, registry, ['python', 'aiteam']),
        'Adding Python and AI Team',
      );
    });

    test('a continued add job keeps its label', () {
      final params = effectiveJobParams(
        const {},
        SetupJobRecord(
          jobId: 'j',
          state: 'interrupted',
          components: const [],
          params: SetupJobParams.adding({'aiteam'}),
        ),
      );
      expect(SetupJobParams.addingIds(params), ['aiteam']);
    });

    test('progress read back from setup.json carries the label', () {
      final record = SetupJobRecord.parse(
        '{"jobId":"j","state":"running","order":["aiteam"],'
        '"components":{"aiteam":{"state":"running"}},'
        '"params":{"_job":{"adding":"aiteam"}}}',
      )!;
      final progress = progressFromRecord(
        record,
        [byId(SetupComponentIds.aiTeam)],
        l10n,
        now: DateTime(2026, 9, 24),
      );
      expect(progress.adding, ['aiteam']);
      expect(progress.firstSetup, isFalse);
    });
  });

  group('named services on the Linux channel', () {
    const channel = MethodChannel(BuiltinLinux.channelName);
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'status' => {
                'installed': true,
                'phase': 'ready',
                'serverRunning': true,
                'services': ['server', 'aiteam', 42],
              },
              'serviceLog' => 'tail',
              _ => null,
            };
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('start, stop and log speak the contract', () async {
      final linux = BuiltinLinux();
      await linux.startService(
        'aiteam',
        'exec gc supervisor run',
        port: 8472,
        notice: 'OpenCode and AI Team are running',
      );
      await linux.startService('other', 'sleep 1');
      await linux.stopService('aiteam');
      expect(await linux.serviceLog('aiteam', tailBytes: 10), 'tail');
      expect(calls.map((c) => c.method), [
        'startService',
        'startService',
        'stopService',
        'serviceLog',
      ]);
      expect(calls[0].arguments, {
        'name': 'aiteam',
        'script': 'exec gc supervisor run',
        'port': 8472,
        'notice': 'OpenCode and AI Team are running',
      });
      // No port and no notice: the keys are left out, not sent as null.
      expect(calls[1].arguments, {'name': 'other', 'script': 'sleep 1'});
      expect(calls[2].arguments, {'name': 'aiteam'});
      expect(calls[3].arguments, {'name': 'aiteam', 'tailBytes': 10});
    });

    test('status lists the running services', () async {
      final status = await BuiltinLinux().status();
      expect(status.services, ['server', 'aiteam']);
      expect(status.serviceRunning('aiteam'), isTrue);
      expect(status.serviceRunning('nope'), isFalse);
      expect(const BuiltinLinuxStatus.absent().services, isEmpty);
    });
  });

  test('discovery leaves the in-app server alone, not Termux or a PC', () {
    ServerProfile profile(String url) =>
        ServerProfile(id: url, name: url, baseUrl: url);
    // The in-app OpenCode (4097): a loopback team there is Termux's.
    expect(teamDiscoveryUrlsForProfile(profile('http://127.0.0.1:4097')), []);
    // Termux's server (4096) and a computer are still probed.
    expect(
      teamDiscoveryUrlsForProfile(profile('http://127.0.0.1:4096')),
      isNotEmpty,
    );
    expect(
      teamDiscoveryUrlsForProfile(profile('http://100.64.0.2:4096')),
      isNotEmpty,
    );
  });
}
