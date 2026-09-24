// The phone setup screens (start, customize, progress, ready, the welcome
// line) and the "This phone" card in fixed states, for the design standard's
// goldens (test/goldens/phone_setup_golden_test.dart) and the before/after
// renders (tool/capture/design_standard_setup_test.dart).
//
// It drives only the screens' public constructors and the engine seam
// (`PhoneSetup.engine`), so the same file renders the code before and after
// the design-kit migration.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/builtin/builtin_server.dart';
import 'package:opencode_mobile/builtin/setup/phone_setup.dart';
import 'package:opencode_mobile/builtin/setup/setup_contract.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/termux_running_server.dart';
import 'package:opencode_mobile/termux/bridge.dart' show TermuxRuntime;
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_progress_screen.dart';
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_ready_screen.dart';
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_start_screen.dart';
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_welcome_entry.dart';
import 'package:opencode_mobile/ui/widgets/phone_server_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart' show captureTheme;
import 'fake_setup_engine.dart';

/// OpenCode inside the app, stood in for: installed or not, running or not,
/// with a measured size.
class SceneLinux extends BuiltinLinux {
  SceneLinux({this.installed = true, this.running = true});

  bool installed;
  bool running;

  @override
  Future<BuiltinLinuxStatus> status() async => BuiltinLinuxStatus(
    installed: installed,
    phase: installed ? BuiltinLinuxPhase.ready : BuiltinLinuxPhase.idle,
    serverRunning: running,
    bytesUsed: installed ? 1181116006 : null,
  );

  @override
  Future<BuiltinLinuxRunResult> run(
    String script, {
    Duration timeout = const Duration(minutes: 2),
  }) async => const BuiltinLinuxRunResult(exitCode: 0, output: '');

  @override
  Future<String> serverLog({int tailBytes = 32768}) async => '';
}

class _Store extends ProfileStore {
  _Store({required super.prefs, required this.saved});

  final List<ServerProfile> saved;

  @override
  List<ServerProfile> get profiles => List.unmodifiable(saved);

  @override
  String? get activeId => saved.isEmpty ? null : saved.first.id;
}

final scenePhoneProfile = ServerProfile(
  id: 'phone',
  name: 'This phone, built-in (OpenCode 1)',
  baseUrl: BuiltinLinux.serverUrl,
  username: BuiltinLinux.serverUsername,
  password: 'secret',
  serverVersion: '1.18.29',
);

const _ids = ['linux', 'essentials', 'python', 'node', 'opencode'];

/// A job of the fake registry: [done] finished, [current] as given, the rest
/// waiting.
SetupProgress sceneJob({
  SetupState state = SetupState.running,
  double overall = .42,
  int? eta,
  Set<String> done = const {},
  ComponentProgress? current,
  String? error,
  String log = '',
}) => SetupProgress(
  state: state,
  overall: overall,
  etaSeconds: eta,
  error: error,
  logTail: log,
  current: current?.id,
  jobId: 'scene',
  firstSetup: true,
  components: [
    for (final id in _ids)
      if (id == current?.id)
        current!
      else if (done.contains(id))
        ComponentProgress(
          id: id,
          state: ComponentState.done,
          version: switch (id) {
            'linux' => '24.04',
            'python' => '3.12.3',
            'node' => '24.2',
            _ => null,
          },
        )
      else
        ComponentProgress(id: id, state: ComponentState.pending),
  ],
);

const sceneNodeDownloading = ComponentProgress(
  id: 'node',
  state: ComponentState.running,
  stage: 'Downloading',
  bytesDone: 18000000,
  bytesTotal: 30000000,
);

/// One fixed state of a setup screen or the card.
class SetupScene {
  const SetupScene(
    this.name, {
    required this.home,
    this.progress,
    this.linux,
    this.profiles = const [],
    this.before,
    this.push = false,
  });

  /// The golden's base name (`<name>_dark.png`) and the render's suffix.
  final String name;
  final Widget Function() home;

  /// What the engine reports; idle when null.
  final SetupProgress? progress;
  final SceneLinux? linux;
  final List<ServerProfile> profiles;

  /// Pushed over a plain page, as the app opens it (Back shows).
  final bool push;

  /// Taps or waits after the first frames.
  final Future<void> Function(WidgetTester tester)? before;
}

Future<void> _openCustomize(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('phone-setup-start-customize')));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget _start({TermuxRunningServer? termux, bool inApp = false}) =>
    PhoneSetupStartScreen(
      termuxProbe: () async => termux ?? const TermuxRunningServer.absent(),
      inAppProbe: () async => inApp,
      openProgress: (_) async {},
    );

Widget _progress() => PhoneSetupProgressScreen(
  engine: PhoneSetup.engine,
  firstSetup: true,
  openReady: (_) async {},
);

/// The first-run welcome's top, where the line about a started setup sits.
Widget _welcome() => Scaffold(
  appBar: AppBar(),
  body: SafeArea(
    child: Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final l10n = lookupAppLocalizations(Localizations.localeOf(context));
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          children: [
            Text(
              l10n.onboardingValueTitle,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.onboardingValueBody,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            const PhoneSetupWelcomeEntry(restoreTimeout: Duration.zero),
            Text(
              l10n.firstRunWhereQuestion,
              style: theme.textTheme.titleMedium,
            ),
          ],
        );
      },
    ),
  ),
);

/// Settings → Servers with "This phone" above another saved server.
Widget _servers({bool connected = false}) => Consumer(
  builder: (context, ref, _) {
    final connection = ref.read(connProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Servers')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          PhoneServerCard(
            connection: connection,
            profile: scenePhoneProfile,
            connected: connected,
            onOpen: () {},
            pollInterval: null,
          ),
          const Divider(height: 17),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text('L')),
            title: Text('Laptop'),
            subtitle: Text('http://100.64.0.7:4096'),
          ),
        ],
      ),
    );
  },
);

final setupScenes = <SetupScene>[
  SetupScene('setup_start', home: _start),
  SetupScene(
    'setup_start_progress',
    home: _start,
    progress: sceneJob(
      state: SetupState.running,
      done: {'linux', 'essentials', 'python'},
      current: sceneNodeDownloading,
    ),
  ),
  SetupScene(
    'setup_start_stopped',
    home: _start,
    progress: sceneJob(
      state: SetupState.interrupted,
      overall: .5,
      done: {'linux', 'essentials', 'python'},
    ),
  ),
  SetupScene('setup_start_ready', home: () => _start(inApp: true)),
  SetupScene(
    'setup_start_termux',
    home: () => _start(
      termux: TermuxRunningServer.running(
        runtime: TermuxRuntime.openCode1,
        version: '1.18.29',
        observedAt: DateTime(2026, 9, 24),
      ),
    ),
    before: (tester) async {
      await tester.tap(
        find.byKey(const ValueKey('phone-setup-start-other-ways')),
      );
      // Long enough for the tap's ink to fade.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    },
  ),
  SetupScene('setup_customize', home: _start, before: _openCustomize),
  SetupScene(
    'setup_progress_running',
    home: _progress,
    push: true,
    progress: sceneJob(
      eta: 130,
      done: {'linux', 'essentials', 'python'},
      current: sceneNodeDownloading,
    ),
  ),
  SetupScene(
    'setup_progress_failed',
    home: _progress,
    push: true,
    progress: sceneJob(
      state: SetupState.failed,
      overall: .55,
      done: {'linux', 'essentials', 'python'},
      current: const ComponentProgress(
        id: 'node',
        state: ComponentState.failed,
        stage: 'Downloading Node.js 24',
        error: 'Exit code 6',
      ),
      log: 'curl: (6) Could not resolve host: nodejs.org\n',
    ),
  ),
  SetupScene(
    'setup_ready',
    home: () => PhoneSetupReadyScreen(linux: SceneLinux()),
  ),
  SetupScene(
    'setup_welcome_entry',
    home: _welcome,
    progress: sceneJob(
      state: SetupState.interrupted,
      overall: .5,
      done: {'linux', 'essentials', 'python'},
    ),
  ),
  SetupScene(
    'phone_card_running',
    home: _servers,
    linux: SceneLinux(),
    profiles: [scenePhoneProfile],
  ),
  SetupScene(
    'phone_card_stopped',
    home: _servers,
    linux: SceneLinux(running: false),
    profiles: [scenePhoneProfile],
  ),
  SetupScene(
    'phone_card_setting_up',
    home: _servers,
    linux: SceneLinux(),
    profiles: [scenePhoneProfile],
    progress: sceneJob(
      done: {'linux', 'essentials', 'python'},
      current: sceneNodeDownloading,
    ),
  ),
];

/// Builds [scene] under [boundary] at 412x915 and runs its [SetupScene.before].
Future<void> pumpSetupScene(
  WidgetTester tester,
  SetupScene scene, {
  required GlobalKey boundary,
  bool light = false,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final controller = ConnectionController(
    _Store(prefs: prefs, saved: scene.profiles),
  );
  addTearDown(controller.dispose);
  final engine = FakeSetupEngine();
  if (scene.progress case final progress?) engine.emit(progress);
  PhoneSetup.engine = engine;
  final linux = scene.linux ?? SceneLinux();
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: ProviderScope(
        overrides: [
          bootstrapProvider.overrideWithValue(AppBootstrap(controller.store)),
          connProvider.overrideWithValue(controller),
          builtinLinuxProvider.overrideWithValue(linux),
          builtinServerStarterProvider.overrideWith((ref) {
            final starter = BuiltinServerStarter(
              linux: linux,
              pollInterval: Duration.zero,
            );
            ref.onDispose(starter.dispose);
            return starter;
          }),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: captureTheme(light: light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: scene.push
              ? const Scaffold(body: SizedBox.shrink())
              : scene.home(),
        ),
      ),
    ),
  );
  if (scene.push) {
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => scene.home()),
    );
  }
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await scene.before?.call(tester);
}
