// "Claude Code on this phone": the wizard block, the Servers card and the
// one saved server, over a fake LocalAgentRuntime whose answers the test
// scripts. No Termux and no device; docs/claude-on-this-phone.md lists the
// on-device checks that remain.
//
// Covers: the offer and "Not now"; needs_ubuntu turning into the button
// that opens the wizard; the step list while installing, with the live
// output; sign-in required, the visible terminal, and the re-read on
// resume; ready -> Connect creating exactly one Paseo server with the
// loopback address and the password, which never reaches a log or the
// screen; the card's controls behind their confirm sheets; and the layout
// at 320 dp / 2.5x in LTR English and RTL Arabic.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/local_agent_server.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:opencode_mobile/termux/local_agent_runtime.dart';
import 'package:opencode_mobile/ui/widgets/local_agent_onboarding.dart';
import 'package:opencode_mobile/ui/widgets/local_agent_server_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _password = 'c0ffee' * 8;

LocalAgentStatus _status(
  LocalAgentPhase phase, {
  bool busy = false,
  bool installed = false,
  LocalAgentStep? step,
  String verb = '',
  LocalAgentSignIn signedIn = LocalAgentSignIn.no,
  LocalAgentFailureKind? failureKind,
  String message = '',
  bool killed = false,
}) => LocalAgentStatus(
  phase: phase,
  busy: busy,
  installed: installed,
  step: step,
  verb: verb,
  signedIn: signedIn,
  failureKind: failureKind,
  message: message,
  killedByAndroid: killed,
  nodeVersion: installed ? 'v24.21.0' : '',
  paseoVersion: installed ? '0.8.0' : '',
  claudeVersion: installed ? '2.1.278' : '',
);

LocalAgentStatus _ready({LocalAgentSignIn signedIn = LocalAgentSignIn.yes}) =>
    _status(LocalAgentPhase.ready, installed: true, signedIn: signedIn);

class _FakeRuntime extends LocalAgentRuntime {
  _FakeRuntime(this.current)
    : super(
        runner: (_, {Duration timeout = Duration.zero}) async => '',
        terminalOpener: (_) async => true,
      );

  LocalAgentStatus current;
  String log = '';
  final calls = <String>[];
  final results = <String, LocalAgentStatus>{};
  final failures = <String, LocalAgentFailure>{};
  final gates = <String, Completer<void>>{};
  List<String> projectList = ['/root/projects/my-first-project'];
  bool terminalOpens = true;

  Future<LocalAgentStatus> _verb(String verb) async {
    calls.add(verb);
    await gates[verb]?.future;
    final failure = failures[verb];
    if (failure != null) throw failure;
    return current = results[verb] ?? current;
  }

  @override
  Future<LocalAgentStatus> status() async => current;

  @override
  Future<String> logTail({int lines = 200}) async => log;

  @override
  Future<LocalAgentStatus> install() => _verb('install');

  @override
  Future<LocalAgentStatus> start() => _verb('start');

  @override
  Future<LocalAgentStatus> restart() => _verb('restart');

  @override
  Future<LocalAgentStatus> stop() => _verb('stop');

  @override
  Future<LocalAgentStatus> remove({bool forgetSignIn = false}) =>
      _verb(forgetSignIn ? 'remove-forget' : 'remove');

  @override
  Future<String> password() async {
    calls.add('password');
    return _password;
  }

  @override
  Future<bool> openSignIn() async {
    calls.add('signin');
    return terminalOpens;
  }

  @override
  Future<List<String>> projects() async => projectList;

  @override
  Future<String> ensureProject(String path) async {
    calls.add('ensure:$path');
    return path;
  }
}

class _FakeChannel implements LiveEventChannel {
  _FakeChannel(this.onStatus);
  final void Function(StreamStatus status) onStatus;

  @override
  void start() => onStatus(StreamStatus.connected);

  @override
  Future<void> dispose() async {}
}

class _Gateway implements ServerGateway {
  String? _directory;
  bool _closed = false;

  @override
  ServerCapabilities get capabilities =>
      const ServerCapabilities(projectManagement: false);

  @override
  Future<Health> health() async => Health(healthy: true, version: '0.8.0');

  @override
  LiveEventChannel openEventChannel({
    required void Function(EventEnvelope event) onEvent,
    required void Function(StreamStatus status) onStatus,
    void Function(Object error)? onError,
  }) => _FakeChannel(onStatus);

  @override
  LiveEventChannel openGlobalEventChannel({
    required void Function(EventEnvelope event) onEvent,
    required void Function(StreamStatus status) onStatus,
    void Function(Object error)? onError,
  }) => _FakeChannel(onStatus);

  @override
  Future<ServerPage<Session>> sessionPage({String? cursor, int limit = 100}) =>
      Future.value(const ServerPage(items: []));

  @override
  Future<List<Session>> sessions() async => const [];

  @override
  Future<Map<String, String>> sessionStatuses() async => const {};

  @override
  String? get directory => _directory;

  @override
  String? get workspace => null;

  @override
  bool get isClosed => _closed;

  @override
  void setLocation({String? directory, String? workspace}) =>
      _directory = directory;

  @override
  void close() => _closed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _Operations implements ServerOperationsGateway {
  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _MemoryStore extends ProfileStore {
  _MemoryStore({required super.prefs, List<ServerProfile> seeded = const []})
    : saved = List.of(seeded);

  final List<ServerProfile> saved;
  String? _activeId;

  @override
  List<ServerProfile> get profiles => List.unmodifiable(saved);

  @override
  String? get activeId => _activeId;

  @override
  Future<void> setActiveId(String? id) async => _activeId = id;

  @override
  Future<void> upsert(ServerProfile profile) async {
    final i = saved.indexWhere((p) => p.id == profile.id);
    if (i < 0) {
      saved.add(profile);
    } else {
      saved[i] = profile;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late _MemoryStore store;
  late ConnectionController controller;
  final connectedWith = <ServerProfile>[];
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    debugPlatformCapabilities = const PlatformCapabilities.android();
    addTearDown(() => debugPlatformCapabilities = null);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'oc/background',
      'oc/shortcut',
      'oc/termux',
      'plugins.it_nomads.com/flutter_secure_storage',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (call) async => call.method == 'readAll' ? <String, String>{} : null,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(MethodChannel(channel), null),
      );
    }
    connectedWith.clear();
  });

  /// Built inside the test body, not in setUp: a controller created outside
  /// the widget test's fake-async zone holds futures that never complete in
  /// it, and `connect` would wait on them forever.
  void init() {
    store = _MemoryStore(prefs: prefs);
    controller = ConnectionController(
      store,
      paseoGatewayFactory: (profile) {
        connectedWith.add(profile);
        return (gateway: _Gateway(), operations: _Operations());
      },
    );
    addTearDown(controller.dispose);
  }

  Widget app(
    Widget child, {
    Locale locale = const Locale('en'),
    double textScale = 1,
    bool rtl = false,
  }) => MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, inner) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: true,
      ),
      child: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: inner!,
      ),
    ),
    home: Scaffold(
      body: ListView(padding: const EdgeInsets.all(16), children: [child]),
    ),
  );

  Future<void> settle(WidgetTester tester, {int frames = 10}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await settle(tester, frames: 2);
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  /// The last step of every test: a connected controller keeps a polling
  /// timer, and the binding fails a test that ends with one pending.
  Future<void> finish(WidgetTester tester) async {
    await unmount(tester);
    controller.dispose();
    await tester.pump(const Duration(seconds: 3));
  }

  Widget block(
    _FakeRuntime runtime, {
    VoidCallback? onConnected,
    VoidCallback? onOpenPhoneSetup,
    bool autoStart = false,
  }) => LocalAgentOnboardingBlock(
    connection: controller,
    runtime: runtime,
    autoStart: autoStart,
    onConnected: onConnected ?? () {},
    onOpenPhoneSetup: onOpenPhoneSetup,
  );

  group('the wizard block', () {
    testWidgets('offers, and "Not now" is remembered', (tester) async {
      init();
      final runtime = _FakeRuntime(_status(LocalAgentPhase.absent));
      await tester.pumpWidget(app(block(runtime)));
      await settle(tester);
      expect(find.text(l10n.localAgentTitle), findsOneWidget);
      expect(find.text(l10n.localAgentOfferSize), findsOneWidget);
      await tapKey(tester, 'local-agent-skip');
      expect(find.byKey(const ValueKey('local-agent-offer')), findsNothing);
      expect(prefs.getBool(localAgentOfferSkippedKey), isTrue);

      await unmount(tester);
      await tester.pumpWidget(app(block(runtime)));
      await settle(tester);
      expect(find.byKey(const ValueKey('local-agent-offer')), findsNothing);
      expect(runtime.calls, isEmpty);
      await finish(tester);
    });

    testWidgets('is absent where there is no Termux at all', (tester) async {
      init();
      debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
      final runtime = _FakeRuntime(_ready());
      await tester.pumpWidget(app(block(runtime)));
      await settle(tester);
      expect(find.byKey(const ValueKey('local-agent-title')), findsNothing);
      await finish(tester);
    });

    testWidgets('needs_ubuntu becomes the button that opens the wizard, from '
        'status and from a refused install', (tester) async {
      init();
      var opened = 0;
      final runtime = _FakeRuntime(_status(LocalAgentPhase.needsUbuntu));
      await tester.pumpWidget(
        app(block(runtime, onOpenPhoneSetup: () => opened++)),
      );
      await settle(tester);
      expect(find.text(l10n.localAgentNeedsUbuntuBody), findsOneWidget);
      await tapKey(tester, 'local-agent-open-setup');
      expect(opened, 1);
      // No second Ubuntu path: the block never offers to install it.
      expect(find.byKey(const ValueKey('local-agent-set-up')), findsNothing);
      await unmount(tester);

      final refusing = _FakeRuntime(_status(LocalAgentPhase.absent))
        ..failures['install'] = const LocalAgentFailure(
          LocalAgentFailureKind.needsUbuntu,
          'Ubuntu is not set up on this phone yet.',
        );
      await tester.pumpWidget(
        app(block(refusing, onOpenPhoneSetup: () => opened++)),
      );
      await settle(tester);
      await tapKey(tester, 'local-agent-set-up');
      expect(
        find.byKey(const ValueKey('local-agent-needs-ubuntu')),
        findsOneWidget,
      );
      await tapKey(tester, 'local-agent-open-setup');
      expect(opened, 2);
      await finish(tester);
    });

    testWidgets('installing shows the steps and the live output, then asks '
        'for sign-in', (tester) async {
      init();
      final runtime = _FakeRuntime(_status(LocalAgentPhase.absent))
        ..gates['install'] = Completer<void>()
        ..results['install'] = _status(
          LocalAgentPhase.installed,
          installed: true,
        );
      await tester.pumpWidget(app(block(runtime)));
      await settle(tester);
      await tapKey(tester, 'local-agent-set-up');
      expect(find.byKey(const ValueKey('local-agent-setup')), findsOneWidget);
      for (final step in LocalAgentUiStep.values) {
        expect(
          find.byKey(ValueKey('local-agent-step-${step.name}')),
          findsOneWidget,
        );
      }

      runtime
        ..current = _status(
          LocalAgentPhase.installing,
          busy: true,
          verb: 'install',
          step: LocalAgentStep.paseo,
        )
        ..log = '[claude] installed Node.js v24.21.0 in /opt/oc-node\n';
      await tester.pump(localAgentPollInterval);
      await settle(tester, frames: 3);
      expect(find.textContaining('installed Node.js v24.21.0'), findsOneWidget);
      final states = localAgentStepStates(runtime.current);
      expect(states[LocalAgentUiStep.node], LocalAgentUiStepState.done);
      expect(states[LocalAgentUiStep.paseo], LocalAgentUiStepState.running);
      expect(states[LocalAgentUiStep.claude], LocalAgentUiStepState.idle);

      runtime.gates.remove('install')!.complete();
      await settle(tester);
      expect(find.byKey(const ValueKey('local-agent-sign-in')), findsOneWidget);
      expect(find.text(l10n.localAgentSignInBody), findsOneWidget);
      // Installed but not signed in: nothing was started on its own.
      expect(runtime.calls, ['install']);
      await finish(tester);
    });

    testWidgets('sign-in opens the visible terminal and is re-read when the '
        'app resumes', (tester) async {
      init();
      final runtime = _FakeRuntime(
        _status(LocalAgentPhase.installed, installed: true),
      )..results['start'] = _ready();
      await tester.pumpWidget(app(block(runtime)));
      await settle(tester);
      await tapKey(tester, 'local-agent-sign-in-open');
      expect(runtime.calls, ['signin']);

      // Back from Termux without a sign-in: say so, stay on the step.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      expect(find.text(l10n.localAgentSignInMissing), findsOneWidget);
      expect(find.byKey(const ValueKey('local-agent-sign-in')), findsOneWidget);

      await tapKey(tester, 'local-agent-sign-in-open');
      runtime.current = _status(
        LocalAgentPhase.installed,
        installed: true,
        signedIn: LocalAgentSignIn.yes,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      expect(find.byKey(const ValueKey('local-agent-stopped')), findsOneWidget);
      await tapKey(tester, 'local-agent-start');
      expect(find.byKey(const ValueKey('local-agent-ready')), findsOneWidget);
      // The block has no field that could take a credential.
      expect(find.byType(TextField), findsNothing);
      await finish(tester);
    });

    testWidgets('a terminal that did not open names the command to run', (
      tester,
    ) async {
      init();
      final runtime = _FakeRuntime(
        _status(LocalAgentPhase.installed, installed: true),
      )..terminalOpens = false;
      await tester.pumpWidget(app(block(runtime)));
      await settle(tester);
      await tapKey(tester, 'local-agent-sign-in-open');
      expect(
        find.text(
          l10n.localAgentSignInOpenFailed(
            TermuxBridge.localAgentsSignInCommand,
          ),
        ),
        findsOneWidget,
      );
      await finish(tester);
    });

    testWidgets('each failure has its own sentence and "Try again" resumes '
        'at the step that failed', (tester) async {
      init();
      final runtime = _FakeRuntime(
        _status(
          LocalAgentPhase.failed,
          installed: true,
          verb: 'start',
          failureKind: LocalAgentFailureKind.portInUse,
          message: 'Port 6767 on this phone is already used',
        ),
      )..results['start'] = _ready();
      await tester.pumpWidget(app(block(runtime)));
      await settle(tester);
      expect(find.text(l10n.localAgentFailedPortInUse), findsOneWidget);
      expect(
        localAgentStepStates(runtime.current)[LocalAgentUiStep.start],
        LocalAgentUiStepState.error,
      );
      await tapKey(tester, 'local-agent-retry');
      expect(runtime.calls, ['start']);
      expect(find.byKey(const ValueKey('local-agent-ready')), findsOneWidget);
      await finish(tester);

      for (final (kind, text) in [
        (LocalAgentFailureKind.checksum, l10n.localAgentFailedChecksum),
        (LocalAgentFailureKind.download, l10n.localAgentFailedDownload),
        (LocalAgentFailureKind.nativeBuild, l10n.localAgentFailedNativeBuild),
        (LocalAgentFailureKind.timeout, l10n.localAgentFailedTimeout),
        (LocalAgentFailureKind.interrupted, l10n.localAgentFailedInterrupted),
      ]) {
        expect(localAgentFailureText(l10n, kind, ''), text);
      }
      expect(
        localAgentFailureText(
          l10n,
          LocalAgentFailureKind.noSpace,
          'Not enough space on this phone for x: 900 MB free, 1536 MB needed',
        ),
        l10n.localAgentFailedNoSpace('900 MB free, 1536 MB needed.'),
      );
    });

    testWidgets('ready -> Connect saves exactly one Paseo server on loopback '
        'with the password, and never shows or logs it', (tester) async {
      init();
      final printed = <String>[];
      final previousPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');

      var connected = 0;
      final runtime = _FakeRuntime(_ready());
      await tester.pumpWidget(
        app(block(runtime, onConnected: () => connected++)),
      );
      await settle(tester);
      expect(find.text(l10n.localAgentReadyBody), findsOneWidget);
      await tapKey(tester, 'local-agent-connect');
      expect(
        find.byKey(const ValueKey('local-agent-project-sheet')),
        findsOneWidget,
      );
      expect(find.text('/root/projects/my-first-project'), findsOneWidget);
      await tapKey(tester, 'local-agent-project-continue');
      await settle(tester);

      expect(connected, 1);
      expect(store.saved, hasLength(1));
      final profile = store.saved.single;
      expect(profile.backend, ServerBackend.paseo);
      expect(profile.baseUrl, 'ws://127.0.0.1:6767');
      expect(profile.name, 'Claude Code on this phone');
      expect(profile.codexToken, _password);
      expect(profile.codexDirectory, '/root/projects/my-first-project');
      expect(isLocalAgentProfile(profile), isTrue);
      expect(connectedWith.single.id, profile.id);
      expect(controller.profile?.id, profile.id);
      // The secret is not part of what gets written as profile JSON.
      expect(profile.toJson().toString(), isNot(contains(_password)));
      expect(find.textContaining(_password), findsNothing);
      expect(printed.join('\n'), isNot(contains(_password)));

      // Connected already: the button reopens, it does not save again.
      await tapKey(tester, 'local-agent-connect');
      expect(connected, 2);
      expect(store.saved, hasLength(1));
      await finish(tester);
      // The framework checks its debug variables before tear-downs run.
      debugPrint = previousPrint;
    });

    testWidgets('connecting again with a typed path updates that one server', (
      tester,
    ) async {
      init();
      store.saved.add(
        ServerProfile(
          id: 'claude',
          name: 'My Claude',
          baseUrl: TermuxBridge.localAgentsUrl,
          backend: ServerBackend.paseo,
          codexToken: 'stale',
          codexDirectory: '/root/projects/old',
        ),
      );
      final runtime = _FakeRuntime(_ready());
      await tester.pumpWidget(app(block(runtime)));
      await settle(tester);
      await tapKey(tester, 'local-agent-connect');

      await tester.enterText(
        find.byKey(const ValueKey('local-agent-project-path')),
        'projects/relative',
      );
      await tapKey(tester, 'local-agent-project-continue');
      expect(find.text(l10n.localAgentProjectPathInvalid), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('local-agent-project-path')),
        '/root/projects/new-app',
      );
      await tapKey(tester, 'local-agent-project-continue');
      await settle(tester);
      expect(runtime.calls, contains('ensure:/root/projects/new-app'));
      expect(store.saved, hasLength(1));
      final profile = store.saved.single;
      expect(profile.id, 'claude');
      // A name the person chose is theirs to keep.
      expect(profile.name, 'My Claude');
      expect(profile.codexToken, _password);
      expect(profile.codexDirectory, '/root/projects/new-app');
      await finish(tester);
    });

    testWidgets('remove asks first and says what stays', (tester) async {
      init();
      final runtime = _FakeRuntime(
        _status(
          LocalAgentPhase.installed,
          installed: true,
          signedIn: LocalAgentSignIn.yes,
        ),
      )..results['remove'] = _status(LocalAgentPhase.absent);
      await tester.pumpWidget(app(block(runtime)));
      await settle(tester);
      await tapKey(tester, 'local-agent-menu');
      await tapKey(tester, 'local-agent-remove');
      expect(find.text(l10n.localAgentRemoveBody), findsOneWidget);
      expect(runtime.calls, isEmpty);
      await tapKey(tester, 'confirm-remove-local-agents');
      // Never the variant that forgets the person's Claude sign-in.
      expect(runtime.calls, ['remove']);
      await finish(tester);
    });

    testWidgets('autoStart skips the offer once Ubuntu is there', (
      tester,
    ) async {
      init();
      final runtime = _FakeRuntime(_status(LocalAgentPhase.absent))
        ..results['install'] = _status(
          LocalAgentPhase.installed,
          installed: true,
        );
      await tester.pumpWidget(app(block(runtime, autoStart: true)));
      await settle(tester);
      expect(runtime.calls, ['install']);
      expect(find.byKey(const ValueKey('local-agent-sign-in')), findsOneWidget);
      await finish(tester);
    });
  });

  group('the Servers card', () {
    Widget card(
      _FakeRuntime runtime, {
      ValueChanged<ServerProfile>? onConnect,
      VoidCallback? onManage,
      String? connectedProfileID,
      int busyConversations = 0,
    }) => LocalAgentServerEntry(
      profiles: store.profiles,
      busy: false,
      revision: 0,
      runtime: runtime,
      connectedProfileID: connectedProfileID,
      busyConversations: busyConversations,
      onConnect: onConnect ?? (_) {},
      onManage: onManage,
      onForget: (_) {},
    );

    testWidgets('is absent until something is installed', (tester) async {
      init();
      await tester.pumpWidget(
        app(card(_FakeRuntime(_status(LocalAgentPhase.absent)))),
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('local-agent-server')), findsNothing);
      await finish(tester);
    });

    testWidgets('stopped offers Start; running offers Connect, Restart and '
        'Stop behind their confirm sheets', (tester) async {
      init();
      final runtime =
          _FakeRuntime(
              _status(
                LocalAgentPhase.installed,
                installed: true,
                signedIn: LocalAgentSignIn.yes,
              ),
            )
            ..results['start'] = _ready()
            ..results['restart'] = _ready()
            ..results['stop'] = _status(
              LocalAgentPhase.installed,
              installed: true,
              signedIn: LocalAgentSignIn.yes,
            );
      await tester.pumpWidget(app(card(runtime, busyConversations: 1)));
      await settle(tester);
      expect(find.text(l10n.localAgentCardStopped), findsOneWidget);
      expect(
        find.byKey(const ValueKey('local-agent-server-connect')),
        findsNothing,
      );
      await tapKey(tester, 'local-agent-server-start');
      expect(runtime.calls, ['start']);
      expect(find.text(l10n.localAgentReadyTitle), findsOneWidget);

      await tapKey(tester, 'local-agent-server-restart');
      expect(find.text(l10n.localAgentRestartTitle), findsOneWidget);
      expect(find.text(l10n.termuxRestartBusyMessage(1)), findsNothing);
      expect(
        find.textContaining(l10n.termuxRestartBusyMessage(1)),
        findsOneWidget,
      );
      expect(runtime.calls, ['start']);
      await tapKey(tester, 'confirm-restart-local-agents');
      expect(runtime.calls, ['start', 'restart']);

      await tapKey(tester, 'local-agent-server-stop');
      expect(find.text(l10n.localAgentStopBody), findsOneWidget);
      await tester.tap(find.text(l10n.safetyStopLocalServerKeep));
      await settle(tester);
      expect(runtime.calls, ['start', 'restart']);
      await tapKey(tester, 'local-agent-server-stop');
      await tapKey(tester, 'confirm-stop-local-agents');
      expect(runtime.calls, ['start', 'restart', 'stop']);
      expect(find.text(l10n.localAgentCardStopped), findsOneWidget);
      await finish(tester);
    });

    testWidgets('Connect uses the saved server, or sends a person without '
        'one to the wizard; a failed control says why', (tester) async {
      init();
      final runtime = _FakeRuntime(_ready());
      var managed = 0;
      final connected = <ServerProfile>[];
      await tester.pumpWidget(
        app(card(runtime, onConnect: connected.add, onManage: () => managed++)),
      );
      await settle(tester);
      await tapKey(tester, 'local-agent-server-connect');
      expect(managed, 1);
      expect(connected, isEmpty);
      await unmount(tester);

      store.saved.add(
        ServerProfile(
          id: 'claude',
          name: 'Claude Code on this phone',
          baseUrl: TermuxBridge.localAgentsUrl,
          backend: ServerBackend.paseo,
          codexToken: _password,
          codexDirectory: '/root/projects/my-first-project',
        ),
      );
      runtime.failures['restart'] = const LocalAgentFailure(
        LocalAgentFailureKind.portInUse,
        'Port 6767 on this phone is already used by another program',
      );
      await tester.pumpWidget(
        app(card(runtime, onConnect: connected.add, onManage: () => managed++)),
      );
      await settle(tester);
      await tapKey(tester, 'local-agent-server-connect');
      expect(connected.single.id, 'claude');
      expect(managed, 1);

      await tapKey(tester, 'local-agent-server-restart');
      await tapKey(tester, 'confirm-restart-local-agents');
      expect(
        find.text(
          l10n.localAgentCardActionFailed(l10n.localAgentFailedPortInUse),
        ),
        findsOneWidget,
      );

      await tapKey(tester, 'local-agent-server-menu');
      for (final item in ['recheck', 'manage', 'forget']) {
        expect(
          find.byKey(ValueKey('local-agent-server-$item')),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(const ValueKey('local-agent-server-disconnect')),
        findsNothing,
      );
      await finish(tester);
    });
  });

  group('layout at 320dp and 2.5x', () {
    for (final rtl in [false, true]) {
      final locale = Locale(rtl ? 'ar' : 'en');
      final label = rtl ? 'RTL ar' : 'LTR en';

      testWidgets('every block view and the card · $label', (tester) async {
        init();
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final views = <(LocalAgentStatus, String)>[
          (_status(LocalAgentPhase.absent), 'local-agent-offer'),
          (_status(LocalAgentPhase.needsUbuntu), 'local-agent-needs-ubuntu'),
          (
            _status(
              LocalAgentPhase.installing,
              busy: true,
              verb: 'install',
              step: LocalAgentStep.claude,
            ),
            'local-agent-setup',
          ),
          (
            _status(LocalAgentPhase.installed, installed: true),
            'local-agent-sign-in',
          ),
          (
            _status(
              LocalAgentPhase.installed,
              installed: true,
              signedIn: LocalAgentSignIn.yes,
              killed: true,
            ),
            'local-agent-stopped',
          ),
          (_ready(), 'local-agent-ready'),
          (
            _status(
              LocalAgentPhase.failed,
              installed: true,
              verb: 'install',
              step: LocalAgentStep.paseo,
              failureKind: LocalAgentFailureKind.nativeBuild,
            ),
            'local-agent-failed',
          ),
        ];
        for (final (status, key) in views) {
          final runtime = _FakeRuntime(status)
            ..log = '[claude] downloading https://nodejs.org/dist/v24.21.0/\n';
          await tester.pumpWidget(
            app(
              block(runtime, onOpenPhoneSetup: () {}),
              locale: locale,
              textScale: 2.5,
              rtl: rtl,
            ),
          );
          await settle(tester);
          expect(tester.takeException(), isNull, reason: key);
          expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
          await unmount(tester);
        }

        for (final status in [
          _ready(),
          _status(LocalAgentPhase.installed, installed: true, killed: true),
        ]) {
          await tester.pumpWidget(
            app(
              LocalAgentServerEntry(
                profiles: const [],
                busy: false,
                revision: 0,
                runtime: _FakeRuntime(status),
                onConnect: (_) {},
                onManage: () {},
              ),
              locale: locale,
              textScale: 2.5,
              rtl: rtl,
            ),
          );
          await settle(tester);
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const ValueKey('local-agent-server')),
            findsOneWidget,
          );
          await finish(tester);
        }
      });
    }
  });
}
