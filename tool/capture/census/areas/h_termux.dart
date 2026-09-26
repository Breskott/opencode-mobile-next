// Census scenes for the ledger part `h-termux`
// (docs/design/ui-ledger/parts/h-termux.json). See tool/capture/census_test.dart.
//
// On this phone (the Termux setup wizard, its steps and the installed
// runtime's page with its confirm sheets), Running now, Storage on this
// phone, development services, Claude Code on this phone, the in-app server
// walkthrough and phone setup v2. The Termux side is one scripted `oc/termux`
// channel (support/h_termux_fakes.dart); phone setup v2 uses the golden
// scenes (test/support/phone_setup_scenes.dart).
//
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/server_probe.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/builtin/setup/phone_setup.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/development_service_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/termux_running_server.dart';
import 'package:opencode_mobile/termux/bridge.dart' show TermuxRuntime;
import 'package:opencode_mobile/termux/processes.dart';
import 'package:opencode_mobile/ui/screens/builtin_server_screen.dart';
import 'package:opencode_mobile/ui/screens/development_services_screen.dart';
import 'package:opencode_mobile/ui/screens/local_agent_screen.dart';
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_customize_sheet.dart';
import 'package:opencode_mobile/ui/screens/servers_screen.dart';
import 'package:opencode_mobile/ui/screens/termux_processes_screen.dart';
import 'package:opencode_mobile/ui/screens/termux_setup_screen.dart';
import 'package:opencode_mobile/ui/screens/termux_storage_screen.dart';
import 'package:opencode_mobile/ui/screens/workspace_screen.dart';
import 'package:opencode_mobile/ui/widgets/termux_phone_tools.dart';

import '../../../../test/support/development_service_fakes.dart';
import '../../../../test/support/phone_setup_scenes.dart';
import '../../fixtures.dart';
import '../census_core.dart';
import '../support/h_termux_fakes.dart';

// ---------------------------------------------------------------------------
// Mounting
// ---------------------------------------------------------------------------

class _Store extends ProfileStore {
  _Store({required super.prefs, required this.saved, this.activeProfileId});

  final List<ServerProfile> saved;
  final String? activeProfileId;

  @override
  List<ServerProfile> get profiles => List.unmodifiable(saved);

  @override
  String? get activeId => activeProfileId;

  @override
  Future<void> upsert(ServerProfile profile) async {}

  @override
  Future<void> setActiveId(String? id) async {}
}

final _routes = <String, WidgetBuilder>{
  '/home': (_) => const Scaffold(),
  '/servers': (_) => const Scaffold(),
  '/guide': (_) => const Scaffold(),
};

/// A controller over [profiles] with [active] the saved server in use;
/// connected when [connected].
Future<CaptureController> _controller(
  CensusKit kit, {
  List<ServerProfile> profiles = const [],
  String? active,
  bool connected = false,
  String version = '1.18.29',
}) async {
  final store = _Store(
    prefs: await kit.prefs(),
    saved: profiles,
    activeProfileId: active,
  );
  final controller = CaptureController(store);
  if (connected) {
    controller
      ..api = CaptureApi()
      ..repository = CaptureRepository()
      ..status = StreamStatus.connected
      ..directory = projectDirectory
      ..version = version;
  }
  kit.onDispose(controller.dispose);
  return controller;
}

/// Installs [fake] on the Termux channel and a loopback probe that answers.
void _phone(CensusKit kit, TermuxFake fake) {
  kit.mockChannel('oc/termux', fake.handle);
  final previous = termuxRunningServerProbe;
  termuxRunningServerProbe =
      ({required baseUrl, username, password, cancellation}) async =>
          const ServerProbeResult.success('2.0.10');
  kit.onDispose(() => termuxRunningServerProbe = previous);
}

/// Pushes [page] over a plain page (so Back shows, as in the app) and
/// settles.
Future<void> _pushed(
  CensusKit kit,
  Widget page,
  ConnectionController controller, {
  Duration settleFor = const Duration(seconds: 2),
}) async {
  await kit.pumpApp(
    const Scaffold(),
    controller: controller,
    store: controller.store,
    routes: _routes,
    settleFor: const Duration(milliseconds: 200),
  );
  await kit.push(page, settleFor: settleFor);
}

/// On this phone over [fake] with [profiles] saved.
Future<void> _setup(
  CensusKit kit,
  TermuxFake fake, {
  List<ServerProfile> profiles = const [],
  String? active,
  bool connected = false,
}) async {
  _phone(kit, fake);
  final controller = await _controller(
    kit,
    profiles: profiles,
    active: active,
    connected: connected,
  );
  await _pushed(kit, const TermuxSetupScreen(), controller);
}

/// The installed runtime page with OpenCode 1 running and in use.
Future<TermuxFake> _installedRunning(CensusKit kit) async {
  final fake = TermuxFake()
    ..inventory = 'ubuntu=installed\nversion=1.18.29\nruntime=opencode1\n'
    ..status = managerStatus(
      phase: 'ready',
      message: 'OpenCode is ready',
      version: '1.18.29',
      runtime: 'opencode1',
      output: '[oc] authenticated server ready on 127.0.0.1:4096\n',
    );
  final phone = phoneProfileV1();
  await _setup(
    kit,
    fake,
    profiles: [phone, laptopProfile()],
    active: phone.id,
    connected: true,
  );
  kit.expectText('OpenCode on this phone');
  return fake;
}

/// The installed runtime page with OpenCode 2 installed and stopped.
Future<void> _installedStopped(CensusKit kit) async {
  final fake = TermuxFake()
    ..inventory = 'ubuntu=installed\nversion=2.0.10\nruntime=opencode2\n'
    ..status = managerStatus(
      phase: 'stopped',
      message: 'Local server stopped',
      version: '2.0.10',
      runtime: 'opencode2',
      pid: '',
    );
  await _setup(
    kit,
    fake,
    profiles: [laptopProfile(), phoneProfileV2()],
    active: 'laptop',
  );
  kit.expectText('OpenCode is stopped');
}

/// The wizard with Termux ready and nothing installed: step 3's choices.
TermuxFake _freshPhone() => TermuxFake();

Future<void> _scrollToText(CensusKit kit, String text) async {
  await kit.scrollTo(find.text(text));
  kit.expectText(text);
  await kit.tester.ensureVisible(find.text(text).first);
  await kit.settle(const Duration(milliseconds: 500));
}

// ---------------------------------------------------------------------------
// Local fakes
// ---------------------------------------------------------------------------

/// OpenCode inside the app, for the walkthrough.
class _CensusLinux extends BuiltinLinux {
  _CensusLinux({
    this.installed = false,
    this.openCode = false,
    this.running = false,
  });

  final bool installed;
  final bool openCode;
  final bool running;

  @override
  Future<BuiltinLinuxStatus> status() async => BuiltinLinuxStatus(
    installed: installed,
    phase: installed ? BuiltinLinuxPhase.ready : BuiltinLinuxPhase.idle,
    serverRunning: running,
    serverPort: running ? BuiltinLinux.serverPort : null,
    abi: 'arm64-v8a',
    bytesUsed: installed ? 1181116006 : null,
  );

  @override
  Future<BuiltinLinuxRunResult> run(
    String script, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (script == BuiltinLinux.versionScript(TermuxRuntime.openCode1) ||
        script == BuiltinLinux.versionScript(TermuxRuntime.openCode2)) {
      return openCode
          ? const BuiltinLinuxRunResult(exitCode: 0, output: '1.18.29\n')
          : const BuiltinLinuxRunResult(exitCode: 1, output: '');
    }
    return const BuiltinLinuxRunResult(exitCode: 0, output: '');
  }

  @override
  Future<String> serverLog({int tailBytes = 32768}) async =>
      running ? _serverLog : '';
}

const _serverLog =
    '''INFO  2026-09-25T09:12:04 +0ms service=default version=1.18.29 args=["serve","--hostname","127.0.0.1","--port","4097"] opencode
INFO  2026-09-25T09:12:05 +812ms service=server listening on http://127.0.0.1:4097
INFO  2026-09-25T09:12:09 +4102ms service=provider init
INFO  2026-09-25T09:12:11 +2011ms service=session id=ses_7f2a created
INFO  2026-09-25T09:13:40 +89002ms service=bus type=message.updated publishing''';

Future<void> _builtin(CensusKit kit, _CensusLinux linux) async {
  final controller = await _controller(kit);
  await _pushed(
    kit,
    BuiltinServerScreen(linux: linux, pollInterval: const Duration(hours: 1)),
    controller,
  );
  kit.expectText('OpenCode inside the app');
}

/// Development services over a server that tracks commands, with
/// "Shopfront preview" registered when [registered].
Future<ServicesConnection> _services(
  CensusKit kit, {
  bool registered = true,
  bool supported = true,
}) async {
  final prefs = await kit.prefs();
  final store = _Store(
    prefs: prefs,
    saved: [laptopProfile()],
    activeProfileId: 'laptop',
  );
  final connection = ServicesConnection(store, ServiceRepository())
    ..directory = sampleService.directory
    ..status = StreamStatus.connected
    ..supported = supported;
  kit.onDispose(connection.dispose);
  if (registered) {
    await DevelopmentServiceStore(
      preferences: prefs,
      profileID: 'laptop',
      canWrite: () => true,
    ).save(sampleService);
  }
  await _pushed(
    kit,
    DevelopmentServicesScreen(controller: connection),
    connection,
  );
  kit.expectText('Development services');
  return connection;
}

Future<void> _servicesRunning(CensusKit kit) async {
  await _services(kit);
  await kit.tapText('Start');
  await kit.tap(find.text('Start').last);
  await kit.settle(const Duration(seconds: 2));
  kit.expectText('Logs');
}

/// Claude Code's own page with claude.sh reporting [status].
Future<TermuxFake> _localAgent(
  CensusKit kit,
  String status, {
  String log = '',
}) async {
  final fake = TermuxFake()
    ..claudeStatus = status
    ..claudeLog = log;
  _phone(kit, fake);
  final controller = await _controller(kit);
  await _pushed(kit, LocalAgentScreen(onConnected: () {}), controller);
  return fake;
}

final _claudeReady = claudeStatusLine(
  phase: 'ready',
  installed: true,
  signedIn: 'yes',
);

/// Servers with the phone's OpenCode 2 and a remote server in use, and
/// Claude Code on this phone when [claude] is its status.
Future<void> _servers(
  CensusKit kit, {
  bool running = true,
  String? claude,
}) async {
  final fake = TermuxFake()
    ..inventory = 'ubuntu=installed\nversion=2.0.10\nruntime=opencode2\n'
    ..status = managerStatus(
      phase: running ? 'ready' : 'stopped',
      message: running ? 'OpenCode is ready' : 'Stopped',
      version: '2.0.10',
      runtime: 'opencode2',
      pid: running ? '123' : '',
    )
    ..claudeStatus = claude;
  _phone(kit, fake);
  final controller = await _controller(
    kit,
    profiles: [laptopProfile(), phoneProfileV2()],
    active: 'laptop',
    connected: true,
    version: '2.0.10',
  );
  await kit.pumpApp(
    const ServersScreen(),
    controller: controller,
    store: controller.store,
    routes: _routes,
  );
}

/// A phone setup v2 scene by its golden name, with the engine it installs
/// put back afterwards.
Future<void> _setupScene(CensusKit kit, String name) async {
  final previous = PhoneSetup.engine;
  kit.onDispose(() => PhoneSetup.engine = previous);
  final scene = setupScenes.firstWhere((s) => s.name == name);
  await pumpSetupScene(kit.tester, scene, boundary: kit.boundaryKey);
  await kit.settle(const Duration(seconds: 1));
}

// ---------------------------------------------------------------------------
// The shots
// ---------------------------------------------------------------------------

final hTermuxArea = CensusArea(
  'h-termux',
  shots: [
    // -- On this phone: the screen and its step states ----------------------
    CensusShot(
      'termux-setup',
      state: 'switch-pending',
      note:
          'A switch from OpenCode 1 to OpenCode 2 beta stopped half way: the '
          'shared runtime-switch control (Retry / Return to) at the top.',
      (kit) async {
        final fake = TermuxFake()
          ..inventory =
              'ubuntu=installed\nversion=0.0.0-beta-18600\nruntime=opencode2\n'
          ..status = managerStatus(
            phase: 'failed',
            message:
                'OpenCode server did not become authenticated and ready '
                'within 30 seconds',
            version: '0.0.0-beta-18600',
            runtime: 'opencode2',
            extra:
                'switch_return=opencode1\nswitch_previous=opencode1\n'
                'switch_target=opencode2\nswitch_phase=starting\n',
            output: '[oc] Checking the selected runtime\n',
          );
        final one = phoneProfileV1();
        await _setup(
          kit,
          fake,
          profiles: [laptopProfile(), one, phoneProfileV2()],
          active: 'laptop',
        );
        kit.expectText('OpenCode needs attention');
      },
    ),
    CensusShot(
      'termux-setup',
      state: 'setup-help-open',
      note:
          'Installed and running, scrolled to the bottom with "Setup help" '
          'unfolded: the shared "Connect existing server" control.',
      (kit) async {
        await _installedRunning(kit);
        await kit.tapText('Setup help');
        await kit.scrollTo(find.text('Connect existing server'));
        await kit.settle();
        kit.expectText('Connect existing server');
      },
    ),
    CensusShot(
      'termux-setup-unsupported',
      note: 'Reached on a desktop build (platform capabilities: Linux).',
      (kit) async {
        debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
        kit.onDispose(() => debugPlatformCapabilities = null);
        final controller = await _controller(kit);
        await _pushed(kit, const TermuxSetupScreen(), controller);
        kit.expectText('Setup on this phone is Android only');
      },
    ),
    CensusShot(
      'termux-setup-checking',
      note: 'Termux has not answered the capability check yet.',
      (kit) async {
        await _setup(kit, TermuxFake()..hangCapabilities = true);
        kit.expectVisible(find.textContaining('Checking Termux'));
      },
    ),
    CensusShot(
      'termux-setup-get-termux',
      note:
          'Termux is not installed. On Android the in-app server leads '
          '(BuiltinLinux.supported), so "Download page" is the secondary.',
      (kit) async {
        await _setup(kit, TermuxFake()..installed = false);
        kit.expectText('Get Termux');
        await _scrollToText(kit, 'Download page');
      },
    ),
    CensusShot(
      'termux-setup-connect-termux',
      state: 'first-visit',
      note: 'Termux is installed; the RUN_COMMAND permission is not granted.',
      (kit) async {
        await _setup(kit, TermuxFake()..permissionGranted = false);
        await _scrollToText(kit, 'Connect Termux once');
        kit.expectText('Copy & open Termux');
      },
    ),
    CensusShot(
      'termux-setup-connect-termux',
      state: 'no-answer',
      note:
          'Permission granted but the unlock line was never pasted: the '
          'bridge probe times out.',
      (kit) async {
        await _setup(kit, TermuxFake()..bridgeLocked = true);
        await _scrollToText(kit, 'Connect Termux once');
        kit.expectTextContaining('Termux did not answer');
      },
    ),
    CensusShot(
      'termux-setup-connect-termux',
      state: 'paste-guide',
      note: 'The same step scrolled to the illustrated paste guide.',
      (kit) async {
        await _setup(kit, TermuxFake()..permissionGranted = false);
        await _scrollToText(kit, 'Show command');
      },
    ),
    CensusShot(
      'termux-setup-choose',
      state: 'fresh-phone',
      note: 'Termux connected, nothing installed: the runtime choice.',
      (kit) async {
        await _setup(kit, _freshPhone());
        await _scrollToText(kit, 'Which OpenCode would you like to use?');
      },
    ),
    CensusShot(
      'termux-setup-choose',
      state: 'opencode2-picked',
      note: 'The same step with OpenCode 2 chosen: the install line names it.',
      (kit) async {
        await _setup(kit, _freshPhone());
        await _scrollToText(kit, 'Which OpenCode would you like to use?');
        await kit.tapKey('setup-runtime-opencode2');
        kit.expectText('Install & start');
      },
    ),
    CensusShot(
      'termux-setup-choose',
      state: 'ubuntu-only',
      note: 'Ubuntu is installed in Termux, OpenCode is not.',
      (kit) async {
        await _setup(
          kit,
          TermuxFake()..inventory = 'ubuntu=installed\nversion=\n',
        );
        await _scrollToText(
          kit,
          'Ubuntu is installed. OpenCode is not installed yet.',
        );
      },
    ),
    CensusShot(
      'termux-setup-choose',
      state: 'check-failed',
      note: 'The installation inventory timed out.',
      (kit) async {
        await _setup(kit, TermuxFake()..inventoryFails = true);
        await _scrollToText(kit, 'Could not check the installed environment.');
      },
    ),
    CensusShot('termux-setup-installing', state: 'setting-up-ubuntu', (
      kit,
    ) async {
      await _setup(
        kit,
        TermuxFake()
          ..status = managerStatus(
            phase: 'installing_ubuntu',
            message: 'Downloading Ubuntu 24.04',
            output: ubuntuLog,
          ),
      );
      kit.expectVisible(find.text('Setting up Ubuntu'));
    }),
    CensusShot('termux-setup-installing', state: 'getting-models-ready', (
      kit,
    ) async {
      await _setup(
        kit,
        TermuxFake()
          ..status = managerStatus(
            phase: 'refreshing_models',
            message: 'Refreshing the OpenCode model catalog',
            version: '1.18.29',
            output: setupLog,
          ),
      );
      kit.expectVisible(find.text('LIVE OUTPUT'));
    }),
    CensusShot(
      'termux-setup-installing',
      state: 'switching',
      note: 'Switching the phone from OpenCode 1 to OpenCode 2 beta.',
      (kit) async {
        await _setup(
          kit,
          TermuxFake()
            ..status = managerStatus(
              phase: 'installing_opencode',
              message: 'Installing OpenCode 2 beta',
              version: '0.0.0-beta-18600',
              runtime: 'opencode2',
              extra:
                  'switch_return=opencode1\nswitch_previous=opencode1\n'
                  'switch_target=opencode2\nswitch_phase=starting\n',
              output:
                  '[oc] Checking the selected runtime\n'
                  '[oc] Installing OpenCode 0.0.0-beta-18600\n',
            ),
        );
        kit.expectVisible(find.textContaining('Switching to'));
      },
    ),
    CensusShot(
      'termux-setup-connected',
      note:
          'Server ready with no version reported, another server in use: the '
          'wizard\'s step 3 connected state.',
      (kit) async {
        await _setup(
          kit,
          TermuxFake()
            ..status = managerStatus(
              phase: 'ready',
              message: 'OpenCode is ready',
            ),
          profiles: [laptopProfile(), phoneProfileV1()],
          active: 'laptop',
          connected: true,
        );
        await _scrollToText(kit, 'Continue to app');
      },
    ),
    CensusShot('termux-setup-failed', state: 'install-failed', (kit) async {
      await _setup(
        kit,
        TermuxFake()
          ..status = managerStatus(
            phase: 'failed',
            message: 'OpenCode installation failed',
            output: failedLog,
          ),
      );
      await _scrollToText(kit, 'Retry — resumes where setup left off');
      kit.expectText('LAST OUTPUT');
    }),
    CensusShot(
      'termux-setup-failed',
      state: 'termux-too-old',
      note: 'Termux is installed but cannot return command results.',
      (kit) async {
        await _setup(kit, TermuxFake()..protocolSupported = false);
        await _scrollToText(kit, 'Choose how to continue');
        kit.expectVisible(find.textContaining('Termux'));
      },
    ),
    CensusShot('termux-setup-installed', state: 'running', (kit) async {
      await _installedRunning(kit);
      kit.expectText('Continue to app');
    }),
    CensusShot('termux-setup-installed', state: 'stopped', (kit) async {
      await _installedStopped(kit);
    }),
    CensusShot('termux-setup-installed', state: 'needs-attention', (kit) async {
      await _setup(
        kit,
        TermuxFake()
          ..inventory = 'ubuntu=installed\nversion=1.18.29\nruntime=opencode1\n'
          ..status = managerStatus(
            phase: 'failed',
            message:
                'OpenCode server did not become authenticated and ready '
                'within 30 seconds',
            version: '1.18.29',
            runtime: 'opencode1',
            output: failedLog,
          ),
        profiles: [laptopProfile(), phoneProfileV1()],
        active: 'laptop',
      );
      kit.expectText('OpenCode needs attention');
    }),
    CensusShot(
      'termux-setup-installed',
      state: 'other-versions-open',
      note: 'Running, with "Other OpenCode versions" unfolded.',
      (kit) async {
        await _installedRunning(kit);
        await kit.tapKey('other-runtime-versions');
        kit.expectVisible(find.byKey(const ValueKey('switch-managed-runtime')));
      },
    ),
    CensusShot('termux-setup-switch-runtime-sheet', (kit) async {
      await _installedRunning(kit);
      await kit.tapKey('other-runtime-versions');
      await kit.tapKey('switch-managed-runtime');
      kit.expectVisible(find.textContaining('Switch to'));
      kit.expectText('Switch version');
    }),
    CensusShot('termux-setup-update-sheet', (kit) async {
      await _installedRunning(kit);
      await kit.tapKey('update-managed-opencode');
      kit.expectText('Update managed OpenCode?');
    }),
    CensusShot('termux-setup-restart-sheet', (kit) async {
      await _installedRunning(kit);
      await kit.tapKey('restart-managed-opencode');
      kit.expectText('Restart the local server?');
    }),
    CensusShot('termux-setup-start-installed-sheet', (kit) async {
      await _installedStopped(kit);
      await kit.tapKey('termux-start-installed');
      kit.expectText('Start installed OpenCode?');
    }),
    CensusShot('termux-setup-replace-installed-sheet', (kit) async {
      await _installedStopped(kit);
      await kit.tapKey('termux-reinstall');
      kit.expectText('Replace installed OpenCode?');
    }),
    CensusShot(
      'termux-setup-unchecked-install-sheet',
      note: 'Opened from "Install & start" after the inventory timed out.',
      (kit) async {
        await _setup(kit, TermuxFake()..inventoryFails = true);
        await kit.tapText('Install & start');
        kit.expectText('Continue without an installation check?');
      },
    ),

    // -- Running now -------------------------------------------------------
    CensusShot('termux-processes', state: 'loaded', (kit) async {
      _phone(kit, TermuxFake());
      await _pushed(kit, const TermuxProcessesScreen(), await _controller(kit));
      kit.expectText('Running now');
      kit.expectVisible(find.byKey(const ValueKey('termux-proc-200')));
    }),
    CensusShot('termux-processes', state: 'empty', (kit) async {
      _phone(kit, TermuxFake()..processes = '[]');
      await _pushed(kit, const TermuxProcessesScreen(), await _controller(kit));
      kit.expectVisible(find.byKey(const ValueKey('termux-procs-empty')));
    }),
    CensusShot('termux-processes-details-sheet', state: 'stoppable', (
      kit,
    ) async {
      _phone(kit, TermuxFake());
      await _pushed(kit, const TermuxProcessesScreen(), await _controller(kit));
      await kit.tapKey('termux-proc-300');
      kit.expectVisible(find.byKey(const ValueKey('termux-procs-details')));
    }),
    CensusShot(
      'termux-processes-details-sheet',
      state: 'orphan',
      note:
          'An orphaned helper (Stop without a second confirm). The protected '
          'form of this sheet ("Protected · open the server controls") is '
          'unreachable: a protected row\'s tap opens On this phone directly '
          '(_ProcessRow.onTap).',
      (kit) async {
        _phone(kit, TermuxFake());
        await _pushed(
          kit,
          const TermuxProcessesScreen(),
          await _controller(kit),
        );
        await kit.tapKey('termux-proc-200');
        kit.expectVisible(find.byKey(const ValueKey('termux-procs-details')));
      },
    ),
    CensusShot('termux-processes-stop-one-sheet', (kit) async {
      _phone(kit, TermuxFake());
      await _pushed(kit, const TermuxProcessesScreen(), await _controller(kit));
      await kit.tapKey('termux-proc-300');
      await kit.tapKey('termux-procs-details-stop');
      kit.expectVisible(
        find.byKey(const ValueKey('termux-procs-confirm-stop')),
      );
    }),
    CensusShot('termux-processes-stop-group-sheet', (kit) async {
      _phone(kit, TermuxFake());
      await _pushed(kit, const TermuxProcessesScreen(), await _controller(kit));
      await kit.tapKey('termux-procs-stop-group-ai_team');
      kit.expectVisible(
        find.byKey(const ValueKey('termux-procs-confirm-stop')),
      );
    }),

    // -- Storage on this phone -----------------------------------------------
    CensusShot('termux-storage', state: 'intro', (kit) async {
      _phone(kit, TermuxFake());
      await _pushed(kit, _storage(), await _controller(kit));
      kit.expectVisible(find.byKey(const ValueKey('termux-storage-intro')));
    }),
    CensusShot('termux-storage', state: 'scanning', (kit) async {
      _phone(
        kit,
        TermuxFake()
          ..storageStatus =
              'state=running\n__OC_TOOLS_LOG__\n$storageScanLog\n',
      );
      await _pushed(kit, _storage(), await _controller(kit));
      kit.expectVisible(find.byKey(const ValueKey('termux-storage-scanning')));
    }),
    CensusShot('termux-storage', state: 'report', (kit) async {
      _phone(kit, TermuxFake()..storageStatus = _storageDone());
      await _pushed(kit, _storage(), await _controller(kit));
      kit.expectVisible(find.byKey(const ValueKey('termux-storage-total')));
    }),
    CensusShot('termux-storage', state: 'category-open', (kit) async {
      _phone(kit, TermuxFake()..storageStatus = _storageDone());
      await _pushed(kit, _storage(), await _controller(kit));
      await kit.tapKey('termux-storage-cat-build_caches');
      kit.expectVisible(
        find.byKey(const ValueKey('termux-storage-clean-build_caches')),
      );
    }),
    CensusShot('termux-storage-clean-sheet', (kit) async {
      _phone(kit, TermuxFake()..storageStatus = _storageDone());
      await _pushed(kit, _storage(), await _controller(kit));
      await kit.tapKey('termux-storage-cat-build_caches');
      await kit.tapKey('termux-storage-clean-build_caches');
      kit.expectVisible(
        find.byKey(const ValueKey('termux-storage-confirm-remove')),
      );
    }),

    // -- Development services ------------------------------------------------
    CensusShot('development-services', state: 'empty', (kit) async {
      await _services(kit, registered: false);
      kit.expectText('Register service');
    }),
    CensusShot('development-services', state: 'registered', (kit) async {
      await _services(kit);
      kit.expectText('Shopfront preview');
    }),
    CensusShot('development-services', state: 'running', (kit) async {
      await _servicesRunning(kit);
    }),
    CensusShot(
      'development-services',
      state: 'unsupported',
      note: 'A server without tracked commands: saving works, Start hides.',
      (kit) async {
        await _services(kit, supported: false);
        kit.expectText('Shopfront preview');
      },
    ),
    CensusShot('development-services-editor-sheet', (kit) async {
      await _services(kit, registered: false);
      await kit.tapText('Register service');
      kit.expectText('Save service');
    }),
    CensusShot('development-services-logs-sheet', (kit) async {
      await _servicesRunning(kit);
      await kit.tapText('Logs');
      await kit.settle(const Duration(seconds: 1));
      kit.expectTextContaining('VITE ready');
    }),
    CensusShot('development-services-confirm-sheet', state: 'start', (
      kit,
    ) async {
      await _services(kit);
      await kit.tapText('Start');
      kit.expectText('Start · Shopfront preview');
    }),
    CensusShot(
      'development-services-confirm-sheet',
      state: 'remove',
      note: 'The destructive form of the same sheet.',
      (kit) async {
        await _services(kit);
        await kit.tapText('Remove configuration');
        kit.expectTextContaining('· Shopfront preview');
      },
    ),

    // -- Servers cards ------------------------------------------------------
    CensusShot(
      'embedded-termux-running-server-entry',
      state: 'running',
      note: 'Host: Servers, with a remote server in use.',
      (kit) async {
        await _servers(kit);
        kit.expectVisible(
          find.byKey(const ValueKey('termux-running-server-menu')),
        );
      },
    ),
    CensusShot(
      'embedded-termux-running-server-entry',
      state: 'menu-open',
      note: 'Host: Servers; the card\'s More menu.',
      (kit) async {
        await _servers(kit);
        await kit.tapKey('termux-running-server-menu');
        kit.expectVisible(
          find.byKey(const ValueKey('termux-running-server-manage')),
        );
      },
    ),
    CensusShot(
      'embedded-termux-running-server-entry',
      state: 'stopped',
      note: 'Host: Servers.',
      (kit) async {
        await _servers(kit, running: false);
        kit.expectVisible(
          find.byKey(const ValueKey('termux-running-server-start')),
        );
      },
    ),
    CensusShot(
      'embedded-termux-attention-line',
      note:
          'Host: Work. An orphaned MCP helper has used an hour of CPU (the '
          'scan is faked through WorkspaceScreen.debugRunawayWatcher).',
      (kit) async {
        final report = TermuxProcessReport.parse(sampleProcessesJson());
        WorkspaceScreen.debugRunawayWatcher = (context, builder) =>
            TermuxRunawayWatcher(builder: builder, scan: () async => report);
        kit.onDispose(() {
          WorkspaceScreen.debugRunawayWatcher = null;
          TermuxRunawayWatcher.resetDismissedForTesting();
        });
        final controller = await kit.connected();
        await kit.pumpApp(
          Scaffold(body: WorkspaceScreen(controller: controller)),
          controller: controller,
        );
        kit.expectVisible(find.byKey(const ValueKey('work-status-runaway')));
      },
    ),
    CensusShot(
      'embedded-setup-terminal',
      state: 'live-output',
      note: 'Host: On this phone while setup installs OpenCode.',
      (kit) async {
        await _setup(
          kit,
          TermuxFake()
            ..status = managerStatus(
              phase: 'installing_opencode',
              message: 'Installing OpenCode 1.18.29',
              output: setupLog,
            ),
        );
        await _scrollToText(kit, 'LIVE OUTPUT');
      },
    ),
    CensusShot(
      'embedded-setup-terminal',
      state: 'last-output',
      note: 'Host: On this phone after setup failed.',
      (kit) async {
        await _setup(
          kit,
          TermuxFake()
            ..status = managerStatus(
              phase: 'failed',
              message: 'OpenCode installation failed',
              output: failedLog,
            ),
        );
        await _scrollToText(kit, 'LAST OUTPUT');
      },
    ),

    // -- Claude Code on this phone -----------------------------------------
    CensusShot('local-agent-page', state: 'offer', (kit) async {
      await _localAgent(kit, claudeStatusLine(phase: 'absent'));
      kit.expectText('Claude Code');
      kit.expectVisible(find.byKey(const ValueKey('local-agent-set-up')));
    }),
    CensusShot('local-agent-page', state: 'installing', (kit) async {
      await _localAgent(
        kit,
        claudeStatusLine(
          phase: 'installing',
          busy: true,
          step: 'paseo',
          verb: 'install',
          message: 'Installing the Paseo daemon',
        ),
        log: claudeInstallLog,
      );
      kit.expectText('Claude Code');
    }),
    CensusShot('local-agent-page', state: 'sign-in', (kit) async {
      await _localAgent(
        kit,
        claudeStatusLine(phase: 'installed', installed: true),
      );
      kit.expectVisible(find.byKey(const ValueKey('local-agent-sign-in-open')));
    }),
    CensusShot('local-agent-page', state: 'ready', (kit) async {
      await _localAgent(kit, _claudeReady);
      kit.expectVisible(find.byKey(const ValueKey('local-agent-connect')));
    }),
    CensusShot(
      'embedded-local-agent-onboarding-block',
      state: 'needs-ubuntu',
      note: 'Host: the Claude Code page, before phone setup ran.',
      (kit) async {
        await _localAgent(kit, claudeStatusLine(phase: 'needs_ubuntu'));
        kit.expectVisible(
          find.byKey(const ValueKey('local-agent-needs-ubuntu-refresh')),
        );
      },
    ),
    CensusShot(
      'embedded-local-agent-onboarding-block',
      state: 'failed',
      note: 'Host: the Claude Code page, after the install failed.',
      (kit) async {
        await _localAgent(
          kit,
          claudeStatusLine(
            phase: 'failed',
            message: 'npm install failed: ECONNRESET',
            failureKind: 'network',
          ),
          log: '$claudeInstallLog\nnpm error code ECONNRESET\n',
        );
        kit.expectVisible(find.byKey(const ValueKey('local-agent-retry')));
      },
    ),
    CensusShot(
      'embedded-local-agent-onboarding-block',
      state: 'menu-open',
      note: 'Host: the Claude Code page; the block\'s More menu.',
      (kit) async {
        await _localAgent(kit, _claudeReady);
        await kit.tapKey('local-agent-menu');
        kit.expectVisible(find.byKey(const ValueKey('local-agent-remove')));
      },
    ),
    CensusShot('local-agent-project-sheet', (kit) async {
      await _localAgent(kit, _claudeReady);
      await kit.tapKey('local-agent-connect');
      await kit.settle(const Duration(seconds: 1));
      kit.expectText('Choose a project folder');
    }),
    CensusShot('remove-local-agents-confirm-sheet', (kit) async {
      await _localAgent(kit, _claudeReady);
      await kit.tapKey('local-agent-menu');
      await kit.tapKey('local-agent-remove');
      kit.expectText('Remove Claude Code from this phone?');
    }),
    CensusShot(
      'embedded-local-agent-server-entry',
      state: 'running',
      note: 'Host: Servers, under the phone\'s OpenCode card.',
      (kit) async {
        await _servers(kit, claude: _claudeReady);
        await kit.scrollTo(
          find.byKey(const ValueKey('local-agent-server-menu')),
        );
        kit.expectVisible(
          find.byKey(const ValueKey('local-agent-server-menu')),
        );
      },
    ),
    CensusShot(
      'embedded-local-agent-server-entry',
      state: 'stopped',
      note: 'Host: Servers.',
      (kit) async {
        await _servers(
          kit,
          claude: claudeStatusLine(
            phase: 'installed',
            installed: true,
            signedIn: 'yes',
          ),
        );
        await kit.scrollTo(
          find.byKey(const ValueKey('local-agent-server-start')),
        );
        kit.expectVisible(
          find.byKey(const ValueKey('local-agent-server-start')),
        );
      },
    ),
    CensusShot(
      'embedded-local-agent-server-entry',
      state: 'menu-open',
      note: 'Host: Servers; the row\'s More menu.',
      (kit) async {
        await _servers(kit, claude: _claudeReady);
        await kit.tapKey('local-agent-server-menu');
        kit.expectVisible(
          find.byKey(const ValueKey('local-agent-server-stop')),
        );
      },
    ),
    CensusShot('stop-local-agents-confirm-sheet', (kit) async {
      await _servers(kit, claude: _claudeReady);
      await kit.tapKey('local-agent-server-menu');
      await kit.tapKey('local-agent-server-stop');
      kit.expectText('Stop Claude Code on this phone?');
    }),
    CensusShot('restart-local-agents-sheet', (kit) async {
      await _servers(kit, claude: _claudeReady);
      await kit.tapKey('local-agent-server-menu');
      await kit.tapKey('local-agent-server-restart');
      kit.expectText('Restart Claude Code on this phone?');
    }),

    // -- OpenCode inside the app (issue #87 walkthrough) ------------------
    CensusShot('builtin-server-setup', state: 'fresh', (kit) async {
      await _builtin(kit, _CensusLinux());
      kit.expectVisible(find.byKey(const ValueKey('builtin-install-ubuntu')));
    }),
    CensusShot('builtin-server-setup', state: 'ubuntu-ready', (kit) async {
      await _builtin(kit, _CensusLinux(installed: true));
      await kit.scrollTo(
        find.byKey(const ValueKey('builtin-install-opencode')),
      );
      kit.expectVisible(find.byKey(const ValueKey('builtin-install-opencode')));
    }),
    CensusShot('builtin-server-setup', state: 'running', (kit) async {
      await _builtin(
        kit,
        _CensusLinux(installed: true, openCode: true, running: true),
      );
      await kit.scrollTo(find.byKey(const ValueKey('builtin-connect')));
      kit.expectVisible(find.byKey(const ValueKey('builtin-connect')));
    }),
    CensusShot('builtin-server-log-sheet', (kit) async {
      await _builtin(
        kit,
        _CensusLinux(installed: true, openCode: true, running: true),
      );
      await kit.tapKey('builtin-show-log');
      await kit.realWait();
      kit.expectVisible(find.byKey(const ValueKey('builtin-server-log')));
    }),
    CensusShot('builtin-server-remove-confirm-sheet', (kit) async {
      await _builtin(
        kit,
        _CensusLinux(installed: true, openCode: true, running: true),
      );
      await kit.tapKey('builtin-remove');
      kit.expectVisible(
        find.byKey(const ValueKey('builtin-server-remove-confirm')),
      );
    }),

    // -- Phone setup v2 ------------------------------------------------------
    CensusShot('phone-setup-start', state: 'first-time', (kit) async {
      await _setupScene(kit, 'setup_start');
      kit.expectVisible(
        find.byKey(const ValueKey('phone-setup-start-primary')),
      );
    }),
    CensusShot('phone-setup-start', state: 'stopped-part-way', (kit) async {
      await _setupScene(kit, 'setup_start_stopped');
      kit.expectVisible(
        find.byKey(const ValueKey('phone-setup-start-primary')),
      );
    }),
    CensusShot(
      'phone-setup-start',
      state: 'ready-in-app',
      note: 'OpenCode is already installed inside the app.',
      (kit) async {
        await _setupScene(kit, 'setup_start_ready');
        kit.expectVisible(
          find.byKey(const ValueKey('phone-setup-start-primary')),
        );
      },
    ),
    CensusShot(
      'phone-setup-start',
      state: 'termux-other-ways',
      note: 'OpenCode already runs in Termux; "Other ways" unfolded.',
      (kit) async {
        await _setupScene(kit, 'setup_start_termux');
        kit.expectVisible(
          find.byKey(const ValueKey('phone-setup-start-set-up-here')),
        );
      },
    ),
    CensusShot('phone-setup-customize-sheet', state: 'first-setup', (
      kit,
    ) async {
      await _setupScene(kit, 'setup_customize');
      kit.expectVisible(
        find.byKey(const ValueKey('phone-setup-customize-sheet')),
      );
    }),
    CensusShot(
      'phone-setup-customize-sheet',
      state: 'add-tools',
      note: 'Add mode, from the "This phone" card on Servers.',
      (kit) async {
        await _setupScene(kit, 'phone_card_running');
        await kit.present(
          (context) => showSetupCustomizeSheet(
            context,
            engine: PhoneSetup.engine,
            addMode: true,
          ),
        );
        kit.expectVisible(
          find.byKey(const ValueKey('phone-setup-customize-sheet')),
        );
      },
    ),
    CensusShot('phone-setup-progress', state: 'running', (kit) async {
      await _setupScene(kit, 'setup_progress_running');
      kit.expectVisible(find.byKey(const ValueKey('setup-progress-cancel')));
    }),
    CensusShot('phone-setup-progress', state: 'details-open', (kit) async {
      await _setupScene(kit, 'setup_progress_log');
      kit.expectTextContaining('Setting up git');
    }),
    CensusShot('phone-setup-progress', state: 'failed', (kit) async {
      await _setupScene(kit, 'setup_progress_failed');
      kit.expectVisible(find.byKey(const ValueKey('setup-progress-continue')));
    }),
    CensusShot('phone-setup-progress-stop-sheet', (kit) async {
      await _setupScene(kit, 'setup_progress_running');
      await kit.tapKey('setup-progress-cancel');
      kit.expectVisible(
        find.byKey(const ValueKey('phone-setup-progress-stop-confirm')),
      );
    }),
    CensusShot('phone-setup-ready', (kit) async {
      await _setupScene(kit, 'setup_ready');
      kit.expectVisible(find.byKey(const ValueKey('phone-setup-ready-create')));
    }),
  ],
  notRendered: {
    'embedded-managed-server-health':
        'Unreachable in the current code: ManagedServerHealth '
        '(lib/ui/widgets/managed_server_health.dart) no longer exists and '
        'Servers no longer embeds it; its recovery switch lives on as '
        'ManagedServerRecoveryOption under On this phone › Options (see '
        'termux-setup-installed--options).',
  },
);

Widget _storage() => TermuxStorageScreen(
  now: () => DateTime.fromMillisecondsSinceEpoch(1788800120000),
);

String _storageDone() =>
    'state=done\n__OC_TOOLS_LOG__\n$storageScanLog\n'
    '__OC_TOOLS_JSON__\n${storageReportJson()}\n';
