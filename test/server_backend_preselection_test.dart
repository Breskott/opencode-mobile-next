import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/server_probe.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/servers_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/server_editor.dart';

class _Store extends ProfileStore {
  _Store({required super.prefs, required this.saved});

  final List<ServerProfile> saved;
  var writes = 0;

  @override
  List<ServerProfile> get profiles => List.unmodifiable(saved);

  @override
  String? get activeId => null;

  @override
  Future<String?> secureStorageProblem() async => null;

  @override
  Future<void> upsert(ServerProfile profile) async {
    writes++;
    saved
      ..removeWhere((p) => p.id == profile.id)
      ..add(profile);
  }
}

class _Connection extends ConnectionController {
  _Connection(super.store);

  var connects = 0;

  @override
  Future<void> connect(
    ServerProfile profile, {
    bool redetectOnFailure = true,
  }) async {
    connects++;
  }
}

Future<(_Store, _Connection)> _pump(
  WidgetTester tester, {
  ServersRouteRequest? request,
  List<ServerProfile> profiles = const [],
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final store = _Store(
    prefs: await SharedPreferences.getInstance(),
    saved: [...profiles],
  );
  final connection = _Connection(store);
  addTearDown(connection.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bootstrapProvider.overrideWithValue(AppBootstrap(store)),
        connProvider.overrideWithValue(connection),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: RouteSettings(name: '/servers', arguments: request),
          builder: (_) => const ServersScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (store, connection);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late int probes;

  setUp(() {
    probes = 0;
    final previousPlatform = debugPlatformCapabilities;
    final previousServerProbe = serverProbe;
    final previousSocketProbe = socketAgentProbe;
    addTearDown(() {
      debugPlatformCapabilities = previousPlatform;
      serverProbe = previousServerProbe;
      socketAgentProbe = previousSocketProbe;
    });
    debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
    serverProbe = ({required baseUrl, username, password}) async {
      probes++;
      throw StateError('Unexpected network probe');
    };
    socketAgentProbe =
        ({
          required backend,
          required baseUrl,
          required secret,
          required directory,
        }) async {
          probes++;
          throw StateError('Unexpected socket probe');
        };
  });

  for (final backend in ServerBackend.values) {
    testWidgets('${backend.name} entry opens its fields without acting and '
        'Back can change the kind', (tester) async {
      final (store, connection) = await _pump(
        tester,
        request: ServersRouteRequest.add(backend: backend),
      );
      expect(find.byKey(const ValueKey('server-kind-step')), findsNothing);
      expect(
        find.text(
          backend == ServerBackend.openCode
              ? 'Step 2 of 4 · Pair or enter the address'
              : 'Step 2 of 4 · Address and sign-in',
        ),
        findsOneWidget,
      );
      if (backend == ServerBackend.openCode) {
        expect(
          find.byKey(const ValueKey('server-pairing-actions')),
          findsOneWidget,
        );
      } else {
        expect(
          find.byKey(const ValueKey('codex-server-address-field')),
          findsOneWidget,
        );
        expect(
          find.text(
            backend == ServerBackend.codex
                ? 'Connection token'
                : 'Daemon password (optional)',
          ),
          findsOneWidget,
        );
      }
      await tester.pump(const Duration(seconds: 2));
      expect(probes, 0);
      expect(connection.connects, 0);
      expect(store.writes, 0);

      await tester.tap(find.byKey(const ValueKey('server-editor-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('server-kind-step')), findsOneWidget);
      final next = backend == ServerBackend.codex ? 'paseo' : 'codex';
      await chooseServerKind(tester, kind: next);
      expect(find.byKey(const ValueKey('server-kind-step')), findsNothing);
      expect(
        find.text(
          next == 'codex' ? 'Connection token' : 'Daemon password (optional)',
        ),
        findsOneWidget,
      );
      expect(probes, 0);
      expect(connection.connects, 0);
      expect(store.writes, 0);
    });
  }

  testWidgets(
    'generic Add keeps the first question and has no default action',
    (tester) async {
      final (store, connection) = await _pump(
        tester,
        request: const ServersRouteRequest.add(),
      );
      expect(find.byKey(const ValueKey('server-kind-step')), findsOneWidget);
      expect(find.text('Step 1 of 4 · What runs there'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('codex-server-address-field')),
        findsNothing,
      );
      expect(probes, 0);
      expect(connection.connects, 0);
      expect(store.writes, 0);
    },
  );

  for (final backend in [ServerBackend.codex, ServerBackend.paseo]) {
    testWidgets('editing a saved ${backend.name} keeps its backend without '
        'connecting', (tester) async {
      final (store, connection) = await _pump(
        tester,
        profiles: [
          ServerProfile(
            id: 'saved',
            name: 'Saved computer',
            backend: backend,
            baseUrl: 'ws://127.0.0.1:4500',
            codexDirectory: '/project',
          ),
        ],
      );
      await tester.longPress(
        find
            .descendant(
              of: find.byKey(const ValueKey('saved-server-rows')),
              matching: find.byType(KitRow),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('server-kind-step')), findsNothing);
      expect(
        find.text(
          backend == ServerBackend.codex
              ? 'Connection token'
              : 'Daemon password (optional)',
        ),
        findsOneWidget,
      );
      expect(store.profiles.single.backend, backend);
      expect(probes, 0);
      expect(connection.connects, 0);
      expect(store.writes, 0);
    });
  }
}
