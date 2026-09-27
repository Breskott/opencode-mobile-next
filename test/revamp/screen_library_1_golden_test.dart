// Golden renders of screen-library-1's pages (wave 2b): Integrations
// (providers, MCP servers, resources), its questions (connect method, key,
// sign-in questions, sign in at host, disconnect, an MCP row's menu with an
// explained gate), the page on a server without a catalog, and Models with
// no provider signed in. Phone 412x915 and one wide window (1280x800) for
// the page, dark and light (owner decision 2026-09-27: no Arabic), with the
// app's real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/screen_library_1_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/mcp_oauth.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/library_screen.dart';
import 'package:opencode_mobile/ui/widgets/provider_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;

class _Repository implements ProductRepository {
  List<McpServerInfo> servers = const [];
  List<McpResourceInfo> resources = const [];
  List<IntegrationInfo> integrations = const [];

  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<List<McpServerInfo>> listMcpServers() async => servers;

  @override
  Future<List<McpResourceInfo>> listMcpResources() async => resources;

  @override
  Future<List<IntegrationInfo>> listIntegrations() async => integrations;

  @override
  Future<McpAuthLaunch> startMcpAuthentication(String name) async =>
      McpAuthLaunch(
        authorizationUrl: Uri.parse(
          'https://github.com/login/oauth/authorize?client_id=mcp',
        ),
        oauthState: 'state-1',
      );

  @override
  Future<void> cancelMcpAuthentication(String name) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Controller extends ConnectionController {
  _Controller(super.store, {this.caps});
  final ServerCapabilities? caps;

  @override
  ServerCapabilities get capabilities => caps ?? super.capabilities;

  @override
  Future<void> refreshCatalog() async {}
}

const _providers = [
  IntegrationInfo(
    id: 'anthropic',
    name: 'Anthropic',
    methods: [IntegrationMethodInfo(type: 'key', label: 'API key')],
    connections: [
      IntegrationConnectionInfo(
        type: 'credential',
        id: 'cred-1',
        label: 'Work',
      ),
    ],
    connectionCount: 1,
  ),
  IntegrationInfo(
    id: 'openai',
    name: 'OpenAI',
    methods: [
      IntegrationMethodInfo(type: 'oauth', id: 'chatgpt', label: 'ChatGPT'),
      IntegrationMethodInfo(type: 'key', label: 'API key'),
    ],
    connectionCount: 0,
  ),
  IntegrationInfo(
    id: 'groq',
    name: 'Groq',
    methods: [
      IntegrationMethodInfo(
        type: 'oauth',
        id: 'console',
        label: 'Groq console',
        prompts: [
          {
            'type': 'text',
            'key': 'org',
            'message': 'Organisation',
            'placeholder': 'acme',
          },
          {
            'type': 'select',
            'key': 'region',
            'message': 'Region',
            'options': [
              {'value': 'us', 'label': 'United States'},
              {'value': 'eu', 'label': 'Europe'},
            ],
          },
        ],
      ),
    ],
    connectionCount: 0,
  ),
  IntegrationInfo(
    id: 'ollama',
    name: 'Ollama',
    methods: [],
    connections: [IntegrationConnectionInfo(type: 'env', label: 'OLLAMA_HOST')],
    connectionCount: 1,
  ),
];

Future<_Controller> _server({ServerCapabilities? caps}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final store = ProfileStore(prefs: preferences);
  await store.upsert(
    ServerProfile(
      id: 'library-1',
      name: 'Laptop',
      baseUrl: 'https://laptop.example',
    ),
  );
  await store.setActiveId('library-1');
  final repository = _Repository()
    ..integrations = _providers
    ..servers = const [
      McpServerInfo(name: 'playwright', status: 'connected'),
      McpServerInfo(name: 'github', status: 'needs_auth'),
      McpServerInfo(name: 'postgres', status: 'failed'),
    ]
    ..resources = const [
      McpResourceInfo(
        name: 'Schema',
        server: 'postgres',
        uri: 'postgres://db/schema',
      ),
    ];
  return _Controller(store, caps: caps)
    ..repository = repository
    ..status = StreamStatus.connected
    ..catalog = const CatalogSnapshot(providers: [], models: [], agents: []);
}

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

String _name(String shot, Size size, bool light) => [
  shot,
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

Future<void> _shot(
  WidgetTester tester,
  String shot, {
  required bool light,
  required Widget home,
  Size size = _phone,
  Future<void> Function()? act,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  final boundary = GlobalKey();
  try {
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: captureTheme(light: light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (act != null) {
      await act();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/${_name(shot, size, light)}.png'),
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  setUpAll(() => ProviderLogo.imageProviderOverride = (_) => null);
  tearDownAll(() => ProviderLogo.imageProviderOverride = null);
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          secure,
          (call) async => call.method == 'readAll' ? <String, String>{} : null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, null);
  });

  for (final light in [false, true]) {
    final tone = light ? 'light' : 'dark';

    group('integrations ($tone)', () {
      for (final size in [_phone, _wide]) {
        testWidgets('loaded ${size.width.toInt()}', (tester) async {
          final controller = await _server();
          addTearDown(controller.dispose);
          await _shot(
            tester,
            'library_integrations_loaded',
            light: light,
            size: size,
            home: IntegrationsScreen(controller: controller),
          );
        });
      }

      testWidgets('mcp', (tester) async {
        final controller = await _server();
        addTearDown(controller.dispose);
        await _shot(
          tester,
          'library_integrations_mcp',
          light: light,
          home: IntegrationsScreen(
            controller: controller,
            mode: IntegrationsMode.mcp,
          ),
        );
      });

      testWidgets('unavailable', (tester) async {
        final controller = await _server(
          caps: const ServerCapabilities(serverCatalog: false),
        );
        addTearDown(controller.dispose);
        await _shot(
          tester,
          'library_integrations_unavailable',
          light: light,
          home: IntegrationsScreen(controller: controller),
        );
      });

      testWidgets('connect method sheet', (tester) async {
        final controller = await _server();
        addTearDown(controller.dispose);
        await _shot(
          tester,
          'library_integrations_connect_method_sheet',
          light: light,
          home: IntegrationsScreen(
            controller: controller,
            mode: IntegrationsMode.providers,
          ),
          act: () =>
              tester.tap(find.byKey(const ValueKey('connect-provider-openai'))),
        );
      });

      testWidgets('connect key dialog', (tester) async {
        final controller = await _server();
        addTearDown(controller.dispose);
        await _shot(
          tester,
          'library_integrations_connect_key_dialog',
          light: light,
          home: IntegrationsScreen(
            controller: controller,
            mode: IntegrationsMode.providers,
          ),
          act: () async {
            await tester.tap(
              find.byKey(const ValueKey('connect-provider-openai')),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('API key').last);
          },
        );
      });

      testWidgets('oauth inputs sheet', (tester) async {
        final controller = await _server();
        addTearDown(controller.dispose);
        await _shot(
          tester,
          'library_integrations_oauth_inputs_sheet',
          light: light,
          home: IntegrationsScreen(
            controller: controller,
            mode: IntegrationsMode.providers,
          ),
          act: () =>
              tester.tap(find.byKey(const ValueKey('connect-provider-groq'))),
        );
      });

      testWidgets('disconnect sheet', (tester) async {
        final controller = await _server();
        addTearDown(controller.dispose);
        await _shot(
          tester,
          'library_integrations_disconnect_sheet',
          light: light,
          home: IntegrationsScreen(
            controller: controller,
            mode: IntegrationsMode.providers,
          ),
          act: () async {
            await tester.tap(find.byKey(const ValueKey('provider-anthropic')));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Disconnect Anthropic'));
          },
        );
      });

      testWidgets('sign in at host sheet', (tester) async {
        final controller = await _server();
        addTearDown(controller.dispose);
        await _shot(
          tester,
          'library_integrations_sign_in_sheet',
          light: light,
          home: IntegrationsScreen(
            controller: controller,
            mode: IntegrationsMode.mcp,
          ),
          act: () => tester.tap(find.text('Sign in to github')),
        );
      });

      testWidgets('mcp menu with an explained gate', (tester) async {
        final controller = await _server();
        addTearDown(controller.dispose);
        await _shot(
          tester,
          'library_integrations_mcp_menu',
          light: light,
          home: IntegrationsScreen(
            controller: controller,
            mode: IntegrationsMode.mcp,
          ),
          act: () =>
              tester.tap(find.byKey(const ValueKey('mcp-server-playwright'))),
        );
      });
    });
  }
}
