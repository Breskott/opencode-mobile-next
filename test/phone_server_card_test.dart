import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/server_probe.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/builtin/builtin_server.dart';
import 'package:opencode_mobile/builtin/local_terminal.dart';
import 'package:opencode_mobile/builtin/setup/phone_setup.dart';
import 'package:opencode_mobile/builtin/setup/setup_contract.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/l10n/app_localizations_ar.dart';
import 'package:opencode_mobile/l10n/app_localizations_en.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/local_terminal_screen.dart';
import 'package:opencode_mobile/ui/screens/servers_screen.dart';
import 'package:opencode_mobile/ui/widgets/phone_server_card.dart';
import 'package:opencode_mobile/ui/widgets/server_switcher_sheet.dart';
import 'package:opencode_mobile/ui/widgets/terminal_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_local_terminal.dart';
import 'support/fake_setup_engine.dart';

// Screen D (docs/design/phone-setup-v2-2026-09-24.md): "This phone", the one
// place OpenCode inside the app is managed, in the switcher and in Servers.

class _Store extends ProfileStore {
  _Store({required super.prefs});

  final saved = <ServerProfile>[];
  String? selected;

  @override
  List<ServerProfile> get profiles => List.unmodifiable(saved);

  @override
  String? get activeId => selected;

  @override
  Future<void> setActiveId(String? id) async => selected = id;

  @override
  Future<void> upsert(ServerProfile profile) async {
    saved
      ..removeWhere((item) => item.id == profile.id)
      ..add(profile);
  }
}

class _Connection extends ConnectionController {
  _Connection(_Store super.store);

  final deleted = <String>[];
  var disconnects = 0;

  @override
  Future<void> disconnect({
    bool keepActive = false,
    bool silent = false,
  }) async {
    disconnects++;
    api = null;
    notifyListeners();
  }

  @override
  Future<DeleteProfileResult> deleteProfileAndLocalData(
    String profileId,
  ) async {
    deleted.add(profileId);
    final store = this.store as _Store;
    store.saved.removeWhere((profile) => profile.id == profileId);
    if (store.selected == profileId) store.selected = null;
    return const DeleteProfileResult();
  }
}

/// The Android side of OpenCode inside the app: installed, a server that
/// runs once started, a measured size.
class _Linux extends BuiltinLinux {
  bool installed = true;
  bool running = true;
  int? bytesUsed = 734003200;
  final calls = <String>[];
  Completer<void>? startGate;

  @override
  Future<BuiltinLinuxStatus> status() async => BuiltinLinuxStatus(
    installed: installed,
    phase: installed ? BuiltinLinuxPhase.ready : BuiltinLinuxPhase.idle,
    serverRunning: running,
    bytesUsed: bytesUsed,
  );

  @override
  Future<BuiltinLinuxRunResult> run(
    String script, {
    Duration timeout = const Duration(minutes: 2),
  }) async => const BuiltinLinuxRunResult(exitCode: 0, output: '');

  @override
  Future<void> startServer(String script, {int port = 4097}) async {
    calls.add('start');
    await startGate?.future;
    running = true;
  }

  @override
  Future<void> stopServer() async {
    calls.add('stop');
    running = false;
  }

  @override
  Future<String> serverLog({int tailBytes = 32768}) async =>
      'opencode server listening\n';

  @override
  Future<void> uninstall() async {
    calls.add('uninstall');
    installed = false;
    running = false;
  }
}

/// Words and addresses a person must never see for this server.
const _forbidden = ['0 B', '127.0.0.1', '4097', 'built-in', 'Ubuntu'];

void expectNoForbiddenText() {
  for (final text in _forbidden) {
    expect(find.textContaining(text), findsNothing, reason: text);
  }
}

void main() {
  late _Store store;
  late _Connection connection;
  late _Linux linux;
  late FakeSetupEngine engine;
  late FakeLocalTerminalBackend terminalBackend;
  late int progressOpened;
  late int startOpened;
  Set<String>? customizeAnswer;

  ServerProfile phone({
    ServerFlavor flavor = ServerFlavor.v1,
    String id = 'phone',
  }) => ServerProfile(
    id: id,
    name: 'This phone, built-in (OpenCode 1)',
    baseUrl: BuiltinLinux.serverUrl,
    username: BuiltinLinux.serverUsername,
    password: 'secret',
    flavor: flavor,
    serverVersion: flavor == ServerFlavor.v2 ? '2.0.10' : '1.18.29',
  );
  final work = ServerProfile(
    id: 'work',
    name: 'Work server',
    baseUrl: 'https://work.example.test',
    password: 'w',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = _Store(prefs: await SharedPreferences.getInstance());
    connection = _Connection(store);
    linux = _Linux();
    engine = FakeSetupEngine();
    terminalBackend = FakeLocalTerminalBackend();
    PhoneSetup.engine = engine;
    progressOpened = 0;
    startOpened = 0;
    customizeAnswer = {'python'};
    PhoneServerCardRoutes.openProgressOverride = (_) async => progressOpened++;
    PhoneServerCardRoutes.openStartOverride = (_) async => startOpened++;
    PhoneServerCardRoutes.customizeOverride = (_) async => customizeAnswer;
    serverProbe = ({required baseUrl, username, password}) async =>
        linux.running
        ? const ServerProbeResult.success('1.18.29')
        : const ServerProbeResult.failure('refused');
  });

  tearDown(() {
    PhoneServerCardRoutes.openProgressOverride = null;
    PhoneServerCardRoutes.openStartOverride = null;
    PhoneServerCardRoutes.customizeOverride = null;
    serverProbe = probeServerConnection;
    connection.dispose();
  });

  Widget app(
    Widget home, {
    Locale locale = const Locale('en'),
    double textScale = 1,
    Map<String, WidgetBuilder> routes = const {},
  }) => ProviderScope(
    overrides: [
      bootstrapProvider.overrideWithValue(AppBootstrap(store)),
      connProvider.overrideWithValue(connection),
      builtinLinuxProvider.overrideWithValue(linux),
      localTerminalProvider.overrideWith((ref) {
        final sessions = LocalTerminalSessions(backend: terminalBackend);
        ref.onDispose(sessions.dispose);
        return sessions;
      }),
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
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      routes: routes,
      home: home,
    ),
  );

  Future<ServerProfile> mountCard(
    WidgetTester tester, {
    ServerProfile? profile,
    bool connected = false,
    VoidCallback? onOpen,
    void Function(PhoneServerAction, int?)? onAction,
    VoidCallback? onRemoved,
    Locale locale = const Locale('en'),
    Size size = const Size(400, 800),
    double textScale = 1,
  }) async {
    final saved = profile ?? phone();
    store
      ..saved.add(saved)
      ..selected = saved.id;
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              PhoneServerCard(
                connection: connection,
                profile: saved,
                connected: connected,
                onOpen: onOpen,
                onAction: onAction,
                onRemoved: onRemoved,
                pollInterval: null,
              ),
            ],
          ),
        ),
        locale: locale,
        textScale: textScale,
      ),
    );
    await tester.pumpAndSettle();
    return saved;
  }

  String status(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('phone-server-status')))
      .data!;

  // The detail is the card row's supporting line (design standard §6), a
  // Text.rich.
  String detail(WidgetTester tester) {
    final text = tester.widget<Text>(
      find.byKey(const ValueKey('phone-server-detail')),
    );
    return text.data ?? text.textSpan!.toPlainText();
  }

  Future<void> choose(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(const ValueKey('phone-server-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  group('state', () {
    testWidgets('running: This phone, version and size, Stop and Show log', (
      tester,
    ) async {
      await mountCard(tester, connected: true);
      expect(find.text('This phone'), findsOneWidget);
      expect(status(tester), 'Running');
      expect(detail(tester), 'OpenCode 1.18.29 · 700.0 MB');
      expect(find.byKey(const ValueKey('phone-server-stop')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('phone-server-show-log')),
        findsOneWidget,
      );
      // Connected already: nothing to open, nothing to start.
      expect(find.byKey(const ValueKey('phone-server-open')), findsNothing);
      expect(find.byKey(const ValueKey('phone-server-start')), findsNothing);
      expectNoForbiddenText();
    });

    testWidgets('an unmeasured or empty size is left out, never "0 B"', (
      tester,
    ) async {
      linux.bytesUsed = 0;
      await mountCard(tester);
      expect(detail(tester), 'OpenCode 1.18.29');
      expectNoForbiddenText();
    });

    testWidgets('without a known version it names the OpenCode generation', (
      tester,
    ) async {
      linux.bytesUsed = null;
      await mountCard(tester, profile: phone()..serverVersion = null);
      expect(detail(tester), 'OpenCode 1');
    });

    testWidgets('running and not connected offers Open as the one action', (
      tester,
    ) async {
      var opened = 0;
      await mountCard(tester, onOpen: () => opened++);
      final filled = find.byWidgetPredicate((w) => w is FilledButton);
      expect(filled, findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('phone-server-open')));
      expect(opened, 1);
    });

    testWidgets('not installed any more: Set up', (tester) async {
      linux.installed = false;
      linux.running = false;
      await mountCard(tester);
      expect(status(tester), 'Not set up');
      await tester.tap(find.byKey(const ValueKey('phone-server-set-up')));
      await tester.pumpAndSettle();
      expect(startOpened, 1);
    });

    testWidgets('a running setup job shows Setting up and its progress', (
      tester,
    ) async {
      engine.emit(
        const SetupProgress(
          state: SetupState.running,
          components: [],
          overall: .4,
        ),
      );
      await mountCard(tester);
      expect(status(tester), 'Setting up');
      await tester.tap(find.byKey(const ValueKey('phone-server-progress')));
      await tester.pumpAndSettle();
      expect(progressOpened, 1);
      // Installing again while one runs would only queue behind it.
      await tester.tap(find.byKey(const ValueKey('phone-server-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('phone-server-update')), findsNothing);
    });

    testWidgets('an interrupted job offers Continue setup', (tester) async {
      engine.emit(
        const SetupProgress(
          state: SetupState.interrupted,
          components: [],
          overall: .4,
        ),
      );
      await mountCard(tester, connected: true);
      await tester.tap(find.byKey(const ValueKey('phone-server-continue')));
      await tester.pumpAndSettle();
      expect(progressOpened, 1);
    });
  });

  group('start and stop', () {
    testWidgets('Start starts the server, shows Starting, then Running', (
      tester,
    ) async {
      linux.running = false;
      linux.startGate = Completer<void>();
      await mountCard(tester);
      expect(status(tester), 'Stopped');
      await tester.tap(find.byKey(const ValueKey('phone-server-start')));
      await tester.pump();
      await tester.pump();
      expect(status(tester), 'Starting');
      expect(linux.calls, ['start']);
      linux.startGate!.complete();
      await tester.pumpAndSettle();
      expect(status(tester), 'Running');
    });

    testWidgets('Stop stops the server', (tester) async {
      await mountCard(tester, connected: true);
      await tester.tap(find.byKey(const ValueKey('phone-server-stop')));
      await tester.pumpAndSettle();
      expect(linux.calls, ['stop']);
      expect(status(tester), 'Stopped');
      expect(find.byKey(const ValueKey('phone-server-start')), findsOneWidget);
    });

    testWidgets('Show log opens the log in a terminal view', (tester) async {
      await mountCard(tester);
      await tester.tap(find.byKey(const ValueKey('phone-server-show-log')));
      await tester.pumpAndSettle();
      expect(find.byType(TerminalView), findsOneWidget);
      expect(find.textContaining('opencode server listening'), findsOneWidget);
    });
  });

  group('menu', () {
    testWidgets('Switch to OpenCode 2 re-runs opencode with its runtime', (
      tester,
    ) async {
      await mountCard(tester);
      await tester.tap(find.byKey(const ValueKey('phone-server-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Switch to OpenCode 2'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('phone-server-switch')));
      await tester.pumpAndSettle();
      expect(engine.runs, [
        {'opencode'},
      ]);
      expect(engine.runParams.single, {
        'opencode': {'runtime': 'opencode2'},
      });
      expect(progressOpened, 1);
    });

    testWidgets('on OpenCode 2 it offers the way back', (tester) async {
      await mountCard(tester, profile: phone(flavor: ServerFlavor.v2));
      expect(detail(tester), 'OpenCode 2.0.10 · 700.0 MB');
      await tester.tap(find.byKey(const ValueKey('phone-server-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Switch to OpenCode 1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('phone-server-switch')));
      await tester.pumpAndSettle();
      expect(engine.runParams.single, {
        'opencode': {'runtime': 'opencode1'},
      });
    });

    testWidgets('Update OpenCode re-runs opencode', (tester) async {
      await mountCard(tester);
      await choose(tester, 'phone-server-update');
      expect(engine.runs, [
        {'opencode'},
      ]);
      expect(engine.runParams.single, isEmpty);
      expect(progressOpened, 1);
    });

    testWidgets('Update on OpenCode 2 keeps OpenCode 2', (tester) async {
      await mountCard(tester, profile: phone(flavor: ServerFlavor.v2));
      await choose(tester, 'phone-server-update');
      expect(engine.runParams.single, {
        'opencode': {'runtime': 'opencode2'},
      });
    });

    testWidgets('Add tools installs what the sheet chose', (tester) async {
      await mountCard(tester);
      await choose(tester, 'phone-server-add-tools');
      expect(engine.runs, [
        {'python'},
      ]);
      expect(progressOpened, 1);
    });

    testWidgets('Add tools closed without a choice installs nothing', (
      tester,
    ) async {
      customizeAnswer = null;
      await mountCard(tester);
      await choose(tester, 'phone-server-add-tools');
      expect(engine.runs, isEmpty);
      expect(progressOpened, 0);
    });

    testWidgets('Remove says how much space comes back, then uninstalls', (
      tester,
    ) async {
      var removed = 0;
      store.saved.add(phone(flavor: ServerFlavor.v2, id: 'phone2'));
      store.saved.add(work);
      connection.api = OpenCodeApi(baseUrl: BuiltinLinux.serverUrl);
      await mountCard(tester, connected: true, onRemoved: () => removed++);
      await choose(tester, 'phone-server-remove');
      expect(
        find.text(
          'This deletes OpenCode, its tools and every project on this phone, '
          'and frees 700.0 MB.',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('phone-server-remove-confirm')),
      );
      await tester.pumpAndSettle();

      expect(connection.disconnects, 1);
      expect(linux.calls, ['uninstall']);
      // Every saved "This phone" entry goes; other servers stay.
      expect(connection.deleted.toSet(), {'phone', 'phone2'});
      expect(store.saved.map((profile) => profile.id), ['work']);
      expect(removed, 1);
      expect(
        find.text('OpenCode was removed from this phone.'),
        findsOneWidget,
      );
    });

    testWidgets('Remove cancelled changes nothing', (tester) async {
      await mountCard(tester);
      await choose(tester, 'phone-server-remove');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(linux.calls, isEmpty);
      expect(connection.deleted, isEmpty);
    });

    testWidgets(
      'Terminal opens a shell on this phone with the server stopped',
      (tester) async {
        linux.running = false;
        await mountCard(tester);
        expect(status(tester), 'Stopped');
        await choose(tester, 'phone-server-terminal');
        expect(find.byType(LocalTerminalView), findsOneWidget);
        expect(terminalBackend.calls, contains(startsWith('start')));
        // The server was left alone: the shell does not need it.
        expect(linux.calls, isEmpty);
      },
    );

    testWidgets(
      'Terminal stays in the menu while a server start does not answer',
      (tester) async {
        linux.running = false;
        linux.startGate = Completer<void>();
        await mountCard(tester);
        await tester.tap(find.byKey(const ValueKey('phone-server-start')));
        await tester.pump();
        await tester.pump();
        expect(status(tester), 'Starting');
        await tester.tap(find.byKey(const ValueKey('phone-server-menu')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        // Only the way in: nothing that would change the server mid-start.
        expect(
          find.byKey(const ValueKey('phone-server-terminal')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('phone-server-remove')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('phone-server-terminal')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(LocalTerminalView), findsOneWidget);
        expect(terminalBackend.calls, contains(startsWith('start')));
        linux.startGate!.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets('a host that must close first receives the action instead', (
      tester,
    ) async {
      final handed = <(PhoneServerAction, int?)>[];
      await mountCard(
        tester,
        onAction: (action, bytes) => handed.add((action, bytes)),
      );
      await choose(tester, 'phone-server-update');
      expect(handed, [(PhoneServerAction.update, 734003200)]);
      expect(engine.runs, isEmpty);
    });
  });

  group('layout', () {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('2.5x on 320dp, 48dp targets (${locale.languageCode})', (
        tester,
      ) async {
        await mountCard(
          tester,
          onOpen: () {},
          locale: locale,
          size: const Size(320, 800),
          textScale: 2.5,
        );
        expect(tester.takeException(), isNull);
        for (final key in [
          'phone-server-open',
          'phone-server-stop',
          'phone-server-show-log',
          'phone-server-menu',
        ]) {
          final size = tester.getSize(find.byKey(ValueKey(key)));
          expect(size.height, greaterThanOrEqualTo(48), reason: key);
          expect(size.width, greaterThanOrEqualTo(48), reason: key);
        }
        if (locale.languageCode == 'ar') {
          expect(find.text('هذا الهاتف'), findsOneWidget);
          expect(find.text('يعمل'), findsOneWidget);
          expect(
            Directionality.of(tester.element(find.text('هذا الهاتف'))),
            TextDirection.rtl,
          );
          // The status sits at the line's end: on the left in Arabic.
          expect(
            tester.getCenter(find.text('يعمل')).dx,
            lessThan(tester.getCenter(find.text('هذا الهاتف')).dx),
          );
        }
        expectNoForbiddenText();
      });
    }
  });

  test('the in-app server is named This phone everywhere', () {
    expect(serverDisplayName(phone(), AppLocalizationsEn()), 'This phone');
    expect(serverDisplayName(phone(), AppLocalizationsAr()), 'هذا الهاتف');
    expect(serverDisplayName(work, AppLocalizationsEn()), 'Work server');
    expect(formatPhoneStorage(1181116006), '1.1 GB');
    expect(formatPhoneStorage(734003200), '700.0 MB');
  });

  // Open point 4 of phone setup v2: setup saves one in-app profile per
  // OpenCode generation and names both "This phone".
  group('OpenCode 1 and 2 both on this phone', () {
    test('are told apart only when both exist; stored names are kept', () {
      final one = phone(id: 'one');
      final two = phone(id: 'two', flavor: ServerFlavor.v2)
        ..name = 'My pocket server';
      final all = [one, two, work];
      final en = AppLocalizationsEn(), ar = AppLocalizationsAr();

      expect(serverDisplayName(one, en, among: all), 'This phone · OpenCode 1');
      expect(serverDisplayName(two, en, among: all), 'This phone · OpenCode 2');
      expect(serverDisplayName(two, ar, among: all), 'هذا الهاتف · OpenCode 2');
      // One generation alone keeps the plain name.
      expect(serverDisplayName(two, en, among: [two, work]), 'This phone');
      expect(serverDisplayName(one, en, among: [one]), 'This phone');
      // Other servers never change.
      expect(serverDisplayName(work, en, among: all), 'Work server');
      // Nothing was renamed to get there.
      expect(one.name, 'This phone, built-in (OpenCode 1)');
      expect(two.name, 'My pocket server');
    });

    testWidgets('the card says which one it stands for', (tester) async {
      store.saved.add(phone(id: 'one'));
      await mountCard(
        tester,
        profile: phone(id: 'two', flavor: ServerFlavor.v2),
        connected: true,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('phone-server-title')))
            .data,
        'This phone · OpenCode 2',
      );
    });

    testWidgets('alone, the card is just This phone', (tester) async {
      await mountCard(tester, connected: true);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('phone-server-title')))
            .data,
        'This phone',
      );
    });
  });

  group('hosts', () {
    testWidgets('the switcher shows the card, not the old in-app row', (
      tester,
    ) async {
      store.saved.addAll([phone(), work]);
      store.selected = 'phone';
      connection.api = OpenCodeApi(baseUrl: BuiltinLinux.serverUrl);
      ServerSwitcherChoice? choice;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    choice = await showServerSwitcher(context, connection),
                child: const Text('Switch'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Switch'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('server-switcher-phone-phone')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('server-switcher-current')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('server-switcher-profile-work')),
        findsOneWidget,
      );
      expectNoForbiddenText();

      // The sheet closes first; the shell runs the action.
      await choose(tester, 'phone-server-update');
      expect(choice, isA<ServerSwitcherPhoneAction>());
      final action = choice! as ServerSwitcherPhoneAction;
      expect(action.action, PhoneServerAction.update);
      expect(action.profileID, 'phone');
      expect(engine.runs, isEmpty);
    });

    testWidgets('the switcher lists This phone when another server is on', (
      tester,
    ) async {
      store.saved.addAll([work, phone()]);
      store.selected = 'work';
      connection.api = OpenCodeApi(baseUrl: work.baseUrl);
      ServerSwitcherChoice? choice;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    choice = await showServerSwitcher(context, connection),
                child: const Text('Switch'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Switch'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('server-switcher-current')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('phone-server-open')));
      await tester.pumpAndSettle();
      final open = choice! as ServerSwitcherOpenServers;
      expect(open.request?.profileID, 'phone');
      expectNoForbiddenText();
    });

    testWidgets('Servers lists the card instead of the address row', (
      tester,
    ) async {
      store.saved.addAll([phone(), work]);
      store.selected = 'phone';
      tester.view
        ..physicalSize = const Size(400, 1600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(const ServersScreen()));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('phone-server-card-phone')),
        findsOneWidget,
      );
      expect(find.text('Work server'), findsOneWidget);
      // The old experimental entry is for setting up, not for a phone that
      // already has OpenCode.
      expect(
        find.byKey(const ValueKey('quick-add-builtin-card')),
        findsNothing,
      );
      expectNoForbiddenText();
    });
  });
}
