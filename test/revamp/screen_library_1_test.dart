// Behaviour of screen-library-1's pages (wave 2b): the Integrations page
// (providers, MCP servers) and the Models page, rebuilt from kit parts.
// What the person sees, what is sent, and that a key is never echoed.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/library_screen.dart';
import 'package:opencode_mobile/ui/widgets/provider_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository implements ProductRepository {
  List<McpServerInfo> servers = const [];
  List<IntegrationInfo> integrations = const [];
  CatalogSnapshot catalog = const CatalogSnapshot(
    providers: [],
    models: [],
    agents: [],
  );
  int listCalls = 0;
  final keys = <String>[];
  Object? keyError;
  final disconnected = <String>[];
  final connectedMcp = <String>[];

  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<List<McpServerInfo>> listMcpServers() async {
    listCalls++;
    return servers;
  }

  List<McpResourceInfo> resources = const [];

  @override
  Future<List<McpResourceInfo>> listMcpResources() async => resources;

  @override
  Future<List<IntegrationInfo>> listIntegrations() async {
    listCalls++;
    return integrations;
  }

  @override
  Future<CatalogSnapshot> loadCatalog() async => catalog;

  @override
  Future<void> connectIntegrationKey(
    String id,
    String key, {
    String? label,
  }) async {
    if (keyError case final error?) throw error;
    keys.add('$id=$key');
  }

  @override
  Future<void> disconnectIntegration(IntegrationInfo integration) async {
    disconnected.add(integration.id);
  }

  @override
  Future<void> connectMcp(String name) async => connectedMcp.add(name);

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

Future<_Controller> _controller(
  _Repository repository, {
  ServerCapabilities? caps,
}) async {
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
  return _Controller(store, caps: caps)
    ..repository = repository
    ..status = StreamStatus.connected;
}

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

const _anthropic = IntegrationInfo(
  id: 'anthropic',
  name: 'Anthropic',
  methods: [IntegrationMethodInfo(type: 'key', label: 'API key')],
  connectionCount: 0,
);

const _openaiConnected = IntegrationInfo(
  id: 'openai',
  name: 'OpenAI',
  methods: [IntegrationMethodInfo(type: 'key', label: 'API key')],
  connections: [
    IntegrationConnectionInfo(type: 'credential', id: 'cred-1', label: 'Work'),
  ],
  connectionCount: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
  setUpAll(() => ProviderLogo.imageProviderOverride = (_) => null);
  tearDownAll(() => ProviderLogo.imageProviderOverride = null);

  testWidgets('a key is sent from the one dialog and never shown again', (
    tester,
  ) async {
    final repository = _Repository()..integrations = const [_anthropic];
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        IntegrationsScreen(
          controller: controller,
          mode: IntegrationsMode.providers,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // One method: the row opens the key dialog titled for its provider.
    await tester.tap(find.byKey(const ValueKey('connect-provider-anthropic')));
    await tester.pumpAndSettle();
    expect(find.text('Connect Anthropic'), findsWidgets);

    // A rejected key keeps the dialog open with the reason; the server's
    // reply (which could quote the key) is not shown.
    repository.keyError = const ProductException('bad key sk-secret-1');
    await tester.enterText(
      find.byKey(const ValueKey('provider-key-field')),
      'sk-secret-1',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirm-provider-key')));
    await tester.pumpAndSettle();
    expect(
      find.text('The server didn\'t accept this key. Check it and try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('bad key'), findsNothing);

    repository.keyError = null;
    await tester.tap(find.byKey(const ValueKey('confirm-provider-key')));
    await tester.pumpAndSettle();
    expect(repository.keys, ['anthropic=sk-secret-1']);
    expect(find.text('Anthropic is connected'), findsOneWidget);
    expect(find.textContaining('sk-secret-1'), findsNothing);
  });

  testWidgets('Disconnect names the provider and confirms before it acts', (
    tester,
  ) async {
    final repository = _Repository()..integrations = const [_openaiConnected];
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        IntegrationsScreen(
          controller: controller,
          mode: IntegrationsMode.providers,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A connected row has no act of its own: a tap opens its menu.
    await tester.tap(find.byKey(const ValueKey('provider-openai')));
    await tester.pumpAndSettle();
    expect(find.text('Disconnect OpenAI'), findsOneWidget);
    // This server cannot list accounts: the item stays and says why.
    expect(
      find.text('This server can\'t list saved accounts from the app.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Disconnect OpenAI'));
    await tester.pumpAndSettle();
    expect(find.text('Disconnect OpenAI?'), findsOneWidget);
    expect(repository.disconnected, isEmpty);
    await tester.tap(find.byKey(const ValueKey('confirm-provider-disconnect')));
    await tester.pumpAndSettle();
    expect(repository.disconnected, ['openai']);
    expect(find.text('OpenAI disconnected'), findsOneWidget);
  });

  testWidgets('MCP rows: urgent first, the act named, no dead Remove', (
    tester,
  ) async {
    final repository = _Repository()
      ..servers = const [
        McpServerInfo(name: 'browser', status: 'connected'),
        McpServerInfo(name: 'github', status: 'failed'),
      ];
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        IntegrationsScreen(controller: controller, mode: IntegrationsMode.mcp),
      ),
    );
    await tester.pumpAndSettle();

    // One list ordered by urgency: the failed server comes first.
    final github = tester.getTopLeft(
      find.byKey(const ValueKey('mcp-server-github')),
    );
    final browser = tester.getTopLeft(
      find.byKey(const ValueKey('mcp-server-browser')),
    );
    expect(github.dy, lessThan(browser.dy));

    await tester.tap(find.text('Reconnect github'));
    await tester.pumpAndSettle();
    expect(repository.connectedMcp, ['github']);

    // Runtime removal is not on this server: the menu leaves Remove out
    // instead of listing a dead item.
    await tester.tap(find.byKey(const ValueKey('mcp-server-browser')));
    await tester.pumpAndSettle();
    expect(find.text('Disconnect browser'), findsOneWidget);
    expect(find.text('Remove browser until restart'), findsNothing);
  });

  // slice-R18: the group names explain themselves on tap, and the
  // Providers page carries no count in its bar.
  testWidgets('R18: Providers, MCP servers and Resources explain themselves; '
      'the Providers page has no connected count', (tester) async {
    final repository = _Repository()
      ..servers = const [McpServerInfo(name: 'browser', status: 'connected')]
      ..resources = const [
        McpResourceInfo(
          name: 'Schema',
          server: 'browser',
          uri: 'file:///schema.sql',
        ),
      ]
      ..integrations = const [_anthropic, _openaiConnected];
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(IntegrationsScreen(controller: controller)));
    await tester.pumpAndSettle();

    Future<void> explains(String label, String words) async {
      final term = find.text(label);
      await tester.ensureVisible(term);
      await tester.pumpAndSettle();
      await tester.tap(term);
      await tester.pumpAndSettle();
      expect(find.text(words), findsOneWidget, reason: label);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
    }

    await explains(
      'Providers',
      'The model providers this server can use. Connect one to start '
          'chatting.',
    );
    await explains(
      'MCP servers',
      'Model Context Protocol. Small add-on servers that give the agent '
          'extra tools, like a browser, a database, or a design tool. You '
          'connect them once and every conversation can use them.',
    );
    await explains(
      'Resources',
      'Files and data that connected MCP servers give the agent.',
    );

    await tester.pumpWidget(
      _app(
        IntegrationsScreen(
          controller: controller,
          mode: IntegrationsMode.providers,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('provider-openai')), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'\d+ of \d+ connected'), findRichText: true),
      findsNothing,
    );
  });

  testWidgets('MCP rows scan by colour: needs-you mark for sign-in, a '
      'failure-toned mark for failed; the page groups carry plain labels', (
    tester,
  ) async {
    final repository = _Repository()
      ..servers = const [
        McpServerInfo(name: 'browser', status: 'connected'),
        McpServerInfo(name: 'github', status: 'failed'),
        McpServerInfo(name: 'linear', status: 'needs_auth'),
      ]
      ..integrations = const [
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
            IntegrationConnectionInfo(
              type: 'credential',
              id: 'cred-2',
              label: 'Personal',
            ),
            IntegrationConnectionInfo(type: 'env', label: 'ANTHROPIC_API_KEY'),
          ],
          connectionCount: 3,
        ),
      ];
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(IntegrationsScreen(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.text('Providers and MCP'), findsOneWidget);
    // Plain group labels, no counts ("2 of 4 connected", "3").
    expect(find.text('Providers'), findsOneWidget);
    expect(find.text('MCP servers'), findsOneWidget);
    expect(find.textContaining(' connected'), findsNothing);
    // Several accounts collapse to a count.
    expect(
      find.textContaining(
        '2 accounts · Server environment',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Stored credential', findRichText: true),
      findsNothing,
    );

    // Needs you first, then failed, then the rest.
    final linear = find.byKey(const ValueKey('mcp-server-linear'));
    final github = find.byKey(const ValueKey('mcp-server-github'));
    final browser = find.byKey(const ValueKey('mcp-server-browser'));
    await tester.ensureVisible(browser);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(linear).dy,
      lessThan(tester.getTopLeft(github).dy),
    );
    expect(
      tester.getTopLeft(github).dy,
      lessThan(tester.getTopLeft(browser).dy),
    );
    expect(
      find.descendant(of: linear, matching: find.byType(KitTaskMark)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: browser, matching: find.byType(KitTaskMark)),
      findsNothing,
    );
    // The failed server's glyph takes the failure tone.
    final failedGlyph = tester.widget<Icon>(
      find.descendant(of: github, matching: find.byIcon(AppIconography.error)),
    );
    final context = tester.element(github);
    expect(
      failedGlyph.color,
      KitTokens.toneColor(KitTokens.of(context).roles, AppStatusTone.failure),
    );
  });

  testWidgets('a server without a catalog explains instead of loading', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = await _controller(
      repository,
      caps: const ServerCapabilities(serverCatalog: false),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(IntegrationsScreen(controller: controller)));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('integrations-unavailable')),
      findsOneWidget,
    );
    expect(
      find.text('This server doesn\'t share its providers, tools or commands.'),
      findsOneWidget,
    );
    expect(repository.listCalls, 0);
    expect(find.byKey(const ValueKey('add-mcp-server')), findsNothing);
  });
}
