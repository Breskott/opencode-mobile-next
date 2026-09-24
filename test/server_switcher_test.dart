import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/server_probe.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/termux_running_server.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:opencode_mobile/ui/screens/home_screen.dart';
import 'package:opencode_mobile/ui/screens/servers_screen.dart';
import 'package:opencode_mobile/ui/widgets/termux_running_server_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/capture/fixtures.dart' show loadCaptureFonts;

// UX plan 5.1: the server name in the app bar is the server switcher, the
// single door to servers while connected. It only chooses; the Servers screen
// keeps the one connect flow.

class _Api extends OpenCodeApi {
  _Api(String baseUrl) : super(baseUrl: baseUrl);

  @override
  Future<List<Session>> sessions() async => [];

  @override
  Future<List<FileNode>> listFiles([String path = '']) async => [];
}

class _Repository implements ProductRepository {
  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<List<WorkspaceProject>> listProjects() async => [];

  @override
  Future<List<WorkspaceInfo>> listWorkspaces() async => [];

  @override
  Future<CatalogSnapshot> loadCatalog() async =>
      const CatalogSnapshot(providers: [], models: [], agents: []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Connection extends ConnectionController {
  _Connection(super.store);

  final attempted = <ServerProfile>[];
  var disconnects = 0;

  @override
  Future<void> connect(
    ServerProfile profile, {
    bool redetectOnFailure = true,
  }) async {
    attempted.add(profile);
    api = _Api(profile.baseUrl);
  }

  @override
  Future<void> disconnect({bool keepActive = false, bool silent = false}) {
    disconnects++;
    return super.disconnect(keepActive: keepActive, silent: silent);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  const termux = MethodChannel('oc/termux');
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final secrets = <String, String>{};
  final oldProbe = termuxRunningServerProbe;

  final work = ServerProfile(
    id: 'work',
    name: 'Work server',
    baseUrl: 'https://work.example.test',
    password: 'synthetic-work',
  );
  final home = ServerProfile(
    id: 'home',
    name: 'Home workstation with a rather long name',
    baseUrl: 'https://home.example.test:4096',
    password: 'synthetic-home',
  );
  final phone = ServerProfile(
    id: 'phone',
    name: 'Phone',
    baseUrl: TermuxBridge.managedServerUrl,
    password: 'synthetic-phone',
  );

  setUp(() {
    secrets.clear();
    messenger.setMockMethodCallHandler(secure, (call) async {
      final args = call.arguments as Map;
      final key = args['key'] as String?;
      switch (call.method) {
        case 'write':
          secrets[key!] = args['value'] as String;
          return null;
        case 'read':
          return secrets[key];
        case 'delete':
          secrets.remove(key);
          return null;
        case 'readAll':
          return secrets;
        case 'containsKey':
          return secrets.containsKey(key);
      }
      return null;
    });
  });

  tearDown(() {
    debugPlatformCapabilities = null;
    termuxRunningServerProbe = oldProbe;
    messenger.setMockMethodCallHandler(termux, null);
    messenger.setMockMethodCallHandler(secure, null);
  });

  /// The phone reports a ready OpenCode 1 server that answers on loopback.
  void fakeRunningPhoneServer() {
    debugPlatformCapabilities = const PlatformCapabilities.android();
    termuxRunningServerProbe =
        ({required baseUrl, username, password, cancellation}) async =>
            const ServerProbeResult.success('1.18.29');
    messenger.setMockMethodCallHandler(termux, (call) async {
      if (call.method == 'getCapabilities') {
        return {
          'installed': true,
          'serviceAvailable': true,
          'protocolSupported': true,
          'permissionGranted': true,
        };
      }
      return {
        'exitCode': 0,
        'stdout':
            'phase=ready\nport=4096\nruntime=opencode1\nversion=1.18.29\npid=12\n',
        'stderr': '',
      };
    });
  }

  Future<_Connection> pumpShell(
    WidgetTester tester, {
    required List<ServerProfile> profiles,
    Size size = const Size(390, 844),
    double textScale = 1,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = ProfileStore(prefs: await SharedPreferences.getInstance());
    for (final profile in profiles) {
      await store.upsert(profile);
    }
    await store.setActiveId(profiles.first.id);
    final connection = _Connection(store)
      ..api = _Api(profiles.first.baseUrl)
      ..repository = _Repository()
      ..status = StreamStatus.connected;
    addTearDown(connection.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapProvider.overrideWithValue(AppBootstrap(store)),
          connProvider.overrideWithValue(connection),
        ],
        child: MaterialApp(
          locale: locale,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routes: {
            '/servers': (_) => const ServersScreen(),
            '/home': (_) => const Scaffold(body: Text('Connected home')),
            '/termux-setup': (_) => const Scaffold(body: Text('Phone setup')),
          },
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return connection;
  }

  Future<void> openSwitcher(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('server-switcher-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('server-switcher-sheet')), findsOneWidget);
  }

  Finder inSheet(Finder finder) => find.descendant(
    of: find.byKey(const ValueKey('server-switcher-sheet')),
    matching: finder,
  );

  testWidgets('the app bar server name opens the switcher; no overflow menu', (
    tester,
  ) async {
    await pumpShell(tester, profiles: [work, home]);

    // The removed doors: nothing connection-level hides behind three dots.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
      ),
      findsNothing,
    );
    expect(find.text('Model / agent'), findsNothing);
    expect(find.text('Disconnect'), findsNothing);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Refresh')),
      findsNothing,
    );

    final button = find.byKey(const ValueKey('server-switcher-button'));
    expect(
      find.descendant(
        of: button,
        matching: find.byKey(const ValueKey('server-profile-title')),
      ),
      findsOneWidget,
    );
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(button),
      matchesSemantics(
        label: 'Server Connected\nServer: Work server\nWork',
        hint: 'Switch server',
        isButton: true,
        // It is still the app bar's title.
        isHeader: true,
        namesRoute: true,
        tooltip: 'Connected',
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );

    await openSwitcher(tester);
    final current = find.byKey(const ValueKey('server-switcher-current'));
    expect(
      find.descendant(of: current, matching: find.text('Work server')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: current, matching: find.text('Connected')),
      findsOneWidget,
    );
    // Saved servers: every other profile, never the current one twice.
    expect(inSheet(find.text('Saved servers')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('server-switcher-profile-home')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('server-switcher-profile-work')),
      findsNothing,
    );
    expect(
      inSheet(find.text('https://home.example.test:4096')),
      findsOneWidget,
    );

    // Order: current, saved, Add, Manage, and Disconnect last.
    double top(String key) => tester.getTopLeft(find.byKey(ValueKey(key))).dy;
    final order = [
      top('server-switcher-current'),
      top('server-switcher-profile-home'),
      top('server-switcher-add'),
      top('server-switcher-manage'),
      top('server-switcher-disconnect'),
    ];
    expect(order, [...order]..sort());
    expect(inSheet(find.text('Add server')), findsOneWidget);
    expect(inSheet(find.text('Manage servers')), findsOneWidget);
    expect(inSheet(find.text('Disconnect')), findsOneWidget);
    // No Termux on this platform: the phone card has nothing to show.
    expect(find.byKey(const ValueKey('termux-running-server')), findsNothing);
  });

  testWidgets('the current server status follows the connection', (
    tester,
  ) async {
    final connection = await pumpShell(tester, profiles: [work]);
    await openSwitcher(tester);
    expect(inSheet(find.text('Connected')), findsOneWidget);
    expect(inSheet(find.text('Saved servers')), findsNothing);
    connection.status = StreamStatus.reconnecting;
    connection.notifyListeners();
    await tester.pump();
    expect(inSheet(find.text('Reconnecting')), findsOneWidget);
    expect(inSheet(find.text('Connected')), findsNothing);
  });

  testWidgets('tapping a saved server runs the Servers connect flow', (
    tester,
  ) async {
    final connection = await pumpShell(tester, profiles: [work, home]);
    await openSwitcher(tester);
    await tester.tap(
      find.byKey(const ValueKey('server-switcher-profile-home')),
    );
    await tester.pumpAndSettle();

    expect(connection.attempted.map((p) => p.id), ['home']);
    expect(connection.disconnects, 0);
    expect(find.byKey(const ValueKey('server-switcher-sheet')), findsNothing);
    expect(find.text('Connected home'), findsOneWidget);
  });

  testWidgets('a server that needs its password again opens its editor', (
    tester,
  ) async {
    final locked = ServerProfile(
      id: 'locked',
      name: 'Locked server',
      baseUrl: 'https://locked.example.test',
      requiresPasswordReentry: true,
    );
    final connection = await pumpShell(tester, profiles: [work, locked]);
    // What a restart without the keystore entry leaves behind.
    connection.store.profiles
            .firstWhere((profile) => profile.id == 'locked')
            .requiresPasswordReentry =
        true;
    await openSwitcher(tester);
    await tester.tap(
      find.byKey(const ValueKey('server-switcher-profile-locked')),
    );
    await tester.pumpAndSettle();

    expect(connection.attempted, isEmpty);
    expect(find.byKey(const ValueKey('server-url-field')), findsOneWidget);
    expect(find.text('https://locked.example.test'), findsWidgets);
  });

  testWidgets('Add server opens the editor; Manage servers opens Servers', (
    tester,
  ) async {
    final connection = await pumpShell(tester, profiles: [work, home]);
    await openSwitcher(tester);
    await tester.tap(find.byKey(const ValueKey('server-switcher-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('server-url-field')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('server-url-field')))
          .controller!
          .text,
      isNot(contains('example.test')),
    );
    expect(connection.attempted, isEmpty);

    // Back out of the editor and the Servers screen under it.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await openSwitcher(tester);
    await tester.tap(find.byKey(const ValueKey('server-switcher-manage')));
    await tester.pumpAndSettle();
    expect(find.byType(ServersScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('server-url-field')), findsNothing);
    expect(connection.attempted, isEmpty);
    expect(connection.api, isNotNull);
  });

  testWidgets('Disconnect confirms: cancel stays connected, confirm leaves', (
    tester,
  ) async {
    final connection = await pumpShell(tester, profiles: [work, home]);
    await openSwitcher(tester);
    await tester.tap(find.byKey(const ValueKey('server-switcher-disconnect')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('disconnect-confirm-sheet')),
      findsOneWidget,
    );
    expect(find.textContaining('Work server'), findsWidgets);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(connection.disconnects, 0);
    expect(connection.api, isNotNull);
    expect(
      find.byKey(const ValueKey('disconnect-confirm-sheet')),
      findsNothing,
    );
    // The switcher is still there to choose something else.
    expect(find.byKey(const ValueKey('server-switcher-sheet')), findsOneWidget);
    expect(find.byType(ServersScreen), findsNothing);

    await tester.tap(find.byKey(const ValueKey('server-switcher-disconnect')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-disconnect')));
    await tester.pumpAndSettle();
    expect(connection.disconnects, 1);
    expect(connection.api, isNull);
    expect(find.byType(ServersScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  group('the server on this phone', () {
    testWidgets('its card leads the saved servers and connects in place', (
      tester,
    ) async {
      fakeRunningPhoneServer();
      final connection = await pumpShell(tester, profiles: [work, phone, home]);
      await openSwitcher(tester);

      final card = find.byKey(const ValueKey('termux-running-server'));
      expect(inSheet(card), findsOneWidget);
      expect(inSheet(find.byType(TermuxRunningServerEntry)), findsOneWidget);
      // Found live on the phone: above every saved server, below the current.
      expect(
        tester.getTopLeft(card).dy,
        greaterThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('server-switcher-current')))
              .dy,
        ),
      );
      expect(
        tester.getTopLeft(card).dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('server-switcher-profile-home')),
              )
              .dy,
        ),
      );
      // Controlled where it is shown.
      expect(
        find.byKey(const ValueKey('termux-running-server-restart')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('termux-running-server-stop')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('termux-running-server-connect')),
      );
      await tester.pumpAndSettle();
      expect(connection.attempted.map((p) => p.id), ['phone']);
      expect(find.text('Connected home'), findsOneWidget);
    });

    testWidgets('connected through it: its menu disconnects after confirming', (
      tester,
    ) async {
      fakeRunningPhoneServer();
      final connection = await pumpShell(tester, profiles: [phone, work]);
      await openSwitcher(tester);

      await tester.tap(
        find.byKey(const ValueKey('termux-running-server-menu')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('termux-running-server-disconnect')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('disconnect-confirm-sheet')),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(connection.disconnects, 0);
      expect(connection.api, isNotNull);

      await tester.tap(
        find.byKey(const ValueKey('termux-running-server-menu')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('termux-running-server-disconnect')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-disconnect')));
      await tester.pumpAndSettle();
      expect(connection.disconnects, 1);
      expect(connection.api, isNull);
      expect(find.byType(ServersScreen), findsOneWidget);
    });

    testWidgets('connected through it: Open returns to the shell as it is', (
      tester,
    ) async {
      fakeRunningPhoneServer();
      final connection = await pumpShell(tester, profiles: [phone, work]);
      await openSwitcher(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('termux-running-server-connect')),
          matching: find.text('Open'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('termux-running-server-connect')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('server-switcher-sheet')), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(ServersScreen), findsNothing);
      // No reconnect: that would drop the live connection it already has.
      expect(connection.attempted, isEmpty);
      expect(connection.disconnects, 0);
    });

    testWidgets('Manage setup opens the phone setup', (tester) async {
      fakeRunningPhoneServer();
      await pumpShell(tester, profiles: [work, phone]);
      await openSwitcher(tester);
      await tester.tap(
        find.byKey(const ValueKey('termux-running-server-menu')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('termux-running-server-manage')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Phone setup'), findsOneWidget);
    });
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
      'the app bar and the sheet fit 320 dp at 2.5x in ${locale.languageCode}',
      (tester) async {
        fakeRunningPhoneServer();
        await pumpShell(
          tester,
          profiles: [home, phone, work],
          size: const Size(320, 640),
          textScale: 2.5,
          locale: locale,
        );
        expect(tester.takeException(), isNull);
        final bar = tester.getRect(find.byType(AppBar));
        final button = tester.getRect(
          find.byKey(const ValueKey('server-switcher-button')),
        );
        expect(button.left, greaterThanOrEqualTo(bar.left));
        expect(button.right, lessThanOrEqualTo(bar.right));

        await openSwitcher(tester);
        expect(tester.takeException(), isNull);
        final sheet = tester.getRect(
          find.byKey(const ValueKey('server-switcher-sheet')),
        );
        for (final key in [
          'server-switcher-current',
          'termux-running-server',
          'server-switcher-profile-work',
          'server-switcher-add',
          'server-switcher-manage',
          'server-switcher-disconnect',
        ]) {
          final finder = find.byKey(ValueKey(key));
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          final rect = tester.getRect(finder);
          expect(rect.left, greaterThanOrEqualTo(sheet.left), reason: key);
          expect(rect.right, lessThanOrEqualTo(sheet.right), reason: key);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
