import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/server_probe.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/servers_screen.dart';

import 'support/setup_capture_preferences.dart';

class _Store extends ProfileStore {
  _Store({required super.prefs, required this.saved});
  final List<ServerProfile> saved;
  @override
  List<ServerProfile> get profiles => saved;
  @override
  String? get activeId => null;
  @override
  Future<void> upsert(ServerProfile profile) async {
    saved.removeWhere((p) => p.id == profile.id);
    saved.add(profile);
  }
}

class _Connection extends ConnectionController {
  _Connection(super.store);
  int connectCalls = 0;
  @override
  Future<void> connect(
    ServerProfile profile, {
    bool redetectOnFailure = true,
  }) async {
    connectCalls++;
    api = OpenCodeApi(baseUrl: profile.baseUrl);
  }
}

Future<(_Store, _Connection)> _state(List<ServerProfile> profiles) async {
  final store = _Store(prefs: await setupCapturePreferences(), saved: profiles);
  return (store, _Connection(store));
}

Widget _app(_Store store, _Connection controller, {double scale = 1}) =>
    ProviderScope(
      overrides: [
        bootstrapProvider.overrideWithValue(AppBootstrap(store)),
        connProvider.overrideWithValue(controller),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        routes: {
          '/home': (_) => const Scaffold(body: Text('Connected')),
          '/termux-setup': (context) => Scaffold(
            body: Text(
              'Termux route: ${ModalRoute.of(context)!.settings.arguments}',
            ),
          ),
        },
        home: const ServersScreen(),
      ),
    );

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUp(() {
    debugPlatformCapabilities = const PlatformCapabilities.android();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          secure,
          (call) async => call.method == 'readAll' ? <String, String>{} : null,
        );
  });
  tearDown(() {
    debugPlatformCapabilities = null;
    serverProbe = probeServerConnection;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, null);
  });

  testWidgets(
    'saved labels distinguish confirmed generation from legacy default',
    (tester) async {
      final (store, conn) = await _state([
        ServerProfile(
          id: 'unknown',
          name: 'Unprobed',
          baseUrl: 'https://legacy.example',
        ),
        ServerProfile(
          id: 'v1',
          name: 'Computer',
          baseUrl: 'https://one.example',
          serverVersion: '1.18.25',
        ),
        ServerProfile(
          id: 'v2',
          name: 'Next',
          baseUrl: 'https://two.example',
          flavor: ServerFlavor.v2,
        ),
        ServerProfile(
          id: 'codex',
          name: 'Codex computer',
          baseUrl: 'wss://codex.example',
          backend: ServerBackend.codex,
          serverVersion: '1.0',
        ),
      ]);
      addTearDown(conn.dispose);
      await tester.pumpWidget(_app(store, conn));
      await tester.pumpAndSettle();
      for (final entry in {
        'unknown': 'OpenCode',
        'v1': 'OpenCode 1',
        'v2': 'OpenCode 2',
      }.entries) {
        final finder = find.byKey(ValueKey('server-generation-${entry.key}'));
        await _reveal(tester, finder);
        expect(tester.widget<Text>(finder).data, entry.value);
      }
      expect(
        find.byKey(const ValueKey('server-generation-codex')),
        findsNothing,
      );
      expect(store.saved.first.flavor, ServerFlavor.v1);
    },
  );

  for (final flavor in [ServerFlavor.v1, ServerFlavor.v2]) {
    testWidgets('OpenCode 2 entry preserves actual $flavor autodetection', (
      tester,
    ) async {
      serverProbe = ({required baseUrl, username, password}) async =>
          ServerProbeResult.success('fixture-version', flavor: flavor);
      final (store, conn) = await _state([]);
      addTearDown(conn.dispose);
      await tester.pumpWidget(_app(store, conn));
      await tester.pumpAndSettle();
      final entry = find.byKey(const ValueKey('connect-existing-opencode2'));
      await _reveal(tester, entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.text('OpenCode 2'), findsOneWidget);
      expect(find.text('OpenCode 1 or 2'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('opencode-autodetect-help')),
        findsOneWidget,
      );
      final url = find.byKey(const ValueKey('server-url-field'));
      await _reveal(tester, url);
      await tester.enterText(url, 'https://existing.example');
      final test = find.byKey(const ValueKey('test-server-connection'));
      await _reveal(tester, test);
      await tester.tap(test);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-server-profile')));
      await tester.pumpAndSettle();
      expect(store.saved.single.flavor, flavor);
      expect(store.saved.single.serverVersion, 'fixture-version');
    });
  }

  for (final mode in ['mixed-local', 'single-local', 'mixed-remote']) {
    testWidgets('$mode connection routes runtime choices only when needed', (
      tester,
    ) async {
      final url = mode == 'mixed-remote'
          ? 'https://work.example'
          : 'http://127.0.0.1:4096';
      final (store, conn) = await _state([
        ServerProfile(
          id: 'one',
          name: 'OpenCode one',
          baseUrl: url,
          serverVersion: '1.18.25',
        ),
        if (mode != 'single-local')
          ServerProfile(
            id: 'two',
            name: 'OpenCode two',
            baseUrl: url,
            flavor: ServerFlavor.v2,
          ),
      ]);
      addTearDown(conn.dispose);
      await tester.pumpWidget(_app(store, conn));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OpenCode one'));
      await tester.pumpAndSettle();
      expect(conn.connectCalls, mode == 'mixed-local' ? 0 : 1);
      expect(
        find.text('Termux route: null'),
        mode == 'mixed-local' ? findsOneWidget : findsNothing,
      );
      expect(store.saved.first.flavor, ServerFlavor.v1);
      if (mode != 'single-local') {
        expect(store.saved.last.flavor, ServerFlavor.v2);
      }
    });
  }

  for (final changed in [true, false]) {
    testWidgets(
      'editing endpoint ${changed ? "clears" : "retains"} cached generation evidence',
      (tester) async {
        final (store, conn) = await _state([
          ServerProfile(
            id: 'server',
            name: 'Saved server',
            baseUrl: 'https://old.example',
            flavor: ServerFlavor.v2,
            serverVersion: '0.0.0-beta',
          ),
        ]);
        addTearDown(conn.dispose);
        await tester.pumpWidget(_app(store, conn));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PopupMenuButton<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        final url = find.byKey(const ValueKey('server-url-field'));
        await _reveal(tester, url);
        await tester.enterText(
          url,
          changed ? 'https://new.example' : 'https://old.example/',
        );
        await tester.tap(find.byKey(const ValueKey('save-server-profile')));
        await tester.pumpAndSettle();
        final saved = store.saved.single;
        expect(saved.flavor, changed ? ServerFlavor.v1 : ServerFlavor.v2);
        expect(saved.serverVersion, changed ? isNull : '0.0.0-beta');
        final label = tester.widget<Text>(
          find.byKey(const ValueKey('server-generation-server')),
        );
        expect(label.data, changed ? 'OpenCode' : 'OpenCode 2');
      },
    );
  }

  testWidgets('known OC1 user reaches phone setup with no runtime forced', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (store, conn) = await _state([
      ServerProfile(
        id: 'v1',
        name: 'Computer',
        baseUrl: 'https://one.example',
        serverVersion: '1.18.25',
      ),
    ]);
    addTearDown(conn.dispose);
    await tester.pumpWidget(_app(store, conn, scale: 2));
    await tester.pumpAndSettle();
    final entry = find.byKey(const ValueKey('quick-add-termux-card'));
    await _reveal(tester, entry);
    expect(
      find.text('Set up OpenCode 1 or 2 here with Termux.'),
      findsOneWidget,
    );
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.text('Termux route: null'), findsOneWidget);
    expect(store.saved.single.flavor, ServerFlavor.v1);
    expect(tester.takeException(), isNull);
  });
}
