import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/codex/gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/paseo/gateway.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/settings_screen.dart';
import 'package:opencode_mobile/ui/screens/terminal_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api extends OpenCodeApi {
  _Api(this._capabilities) : super(baseUrl: 'http://localhost');

  final ServerCapabilities _capabilities;

  @override
  ServerCapabilities get capabilities => _capabilities;

  @override
  Future<Health> health() async => Health(healthy: true, version: '1.18.23');
}

class _Repository
    implements ProductRepository, SessionImportGateway, UsageStatisticsGateway {
  @override
  bool get sessionImportSupported => true;

  @override
  bool get usageStatisticsSupported => true;

  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<List<TerminalProcess>> listTerminals() async => [];

  @override
  Future<TerminalShellSettings> loadTerminalShellSettings() async =>
      const TerminalShellSettings(selected: '', options: []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ConnectionController> _controller({
  ServerCapabilities capabilities = ServerCapabilities.allV1,
}) async {
  SharedPreferences.setMockInitialValues({
    'oc.profiles': jsonEncode([
      {
        'id': 'profile-1',
        'name': 'Workstation',
        'baseUrl': 'http://localhost:4096',
        'username': '',
      },
    ]),
    'oc.activeProfile': 'profile-1',
  });
  final preferences = await SharedPreferences.getInstance();
  final store = ProfileStore(prefs: preferences);
  await store.load();
  return ConnectionController(store)
    ..api = _Api(capabilities)
    ..repository = _Repository()
    ..status = StreamStatus.connected;
}

Widget _app(
  ConnectionController controller, {
  Locale locale = const Locale('en'),
  SettingsGroup? initialGroup,
}) => MaterialApp(
  theme: AppTheme.light(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: SettingsScreen(controller: controller, initialGroup: initialGroup),
);

final _en = lookupAppLocalizations(const Locale('en'));

Finder _row(String key) => find.byKey(ValueKey(key));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The phone is the product; Termux, voice, Tailscale and the background
  // service rows only exist there.
  setUp(() {
    debugPlatformCapabilities = const PlatformCapabilities.android();
    // ProfileStore reads passwords through flutter_secure_storage, whose
    // unmocked channel never answers inside testWidgets.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });
  tearDown(() => debugPlatformCapabilities = null);

  testWidgets('the eight groups appear in the plan order, each keyed', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    const slugs = [
      'connection',
      'conversation-defaults',
      'notifications',
      'appearance',
      'agent-setup',
      'usage',
      'privacy',
      'help',
    ];
    expect(SettingsGroup.values.map((group) => group.slug), slugs);
    var previous = double.negativeInfinity;
    for (final slug in slugs) {
      final group = _row('settings-group-$slug');
      expect(group, findsOneWidget, reason: slug);
      final top = tester.getTopLeft(group).dy;
      expect(top, greaterThan(previous), reason: '$slug is out of order');
      previous = top;
    }
  });

  testWidgets('Disconnect is the last, separated row of Connection', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    final connection = _row('settings-group-connection');
    final disconnect = _row('settings-disconnect');
    expect(
      find.descendant(of: connection, matching: disconnect),
      findsOneWidget,
    );
    final tiles = find.descendant(
      of: connection,
      matching: find.byType(ListTile),
    );
    final lastTileBottom = tester.getBottomLeft(tiles.last).dy;
    // Below every door of the group, with a gap that sets it apart.
    expect(
      tester.getTopLeft(disconnect).dy,
      greaterThanOrEqualTo(lastTileBottom + 8),
    );
    expect(
      tester.getBottomLeft(disconnect).dy,
      lessThanOrEqualTo(tester.getBottomLeft(connection).dy),
    );
  });

  testWidgets('search finds every hub row by its title and spec keywords', (
    tester,
  ) async {
    final controller = await _controller(
      capabilities: const ServerCapabilities(agentAccount: true),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    // query -> keys of rows that must be among the results.
    final cases = <String, List<String>>{
      // Titles.
      _en.settingsHubThisServer: ['settings-category-server'],
      _en.activitySavedServers: ['settings-saved-servers'],
      _en.onboardingTermuxSetup: ['settings-on-this-phone'],
      _en.settingsHubAccounts: ['settings-accounts'],
      _en.a2aTitle: ['settings-external-agents'],
      _en.tailscaleTitle: ['settings-tailscale'],
      _en.e7SettingsUi8: ['settings-disconnect'],
      _en.settingsHubModelAndMode: ['settings-model-and-mode'],
      _en.e7SettingsUi35: ['default-shell-settings-entry'],
      _en.e7SettingsUi74: ['saved-permissions-entry'],
      _en.chatUiTranscriptDisplay: ['settings-transcript-display'],
      _en.settingsHubVoice: ['settings-voice'],
      _en.e7SettingsUi3: ['settings-category-background'],
      _en.e7AppearanceTitle: ['settings-category-appearance'],
      _en.libraryModelsAgentsTitle: ['settings-models'],
      _en.libraryProvidersTitle: ['settings-providers'],
      _en.libraryMcpTitle: ['settings-mcp'],
      _en.libraryCommandsToolsTitle: ['settings-commands-tools'],
      _en.teamUiPluginsTitle: ['settings-category-plugins'],
      _en.importTitle: ['library-import-session'],
      _en.libraryTerminalTitle: ['library-terminal'],
      _en.usageTitle: ['settings-category-usage'],
      _en.quotaTitle: ['settings-category-quota'],
      _en.settingsHubPrivacyRow: ['settings-category-privacy'],
      _en.onboardingSetupGuide: ['settings-setup-guide'],
      _en.e7LibraryReportABug: ['library-report-bug'],
      _en.e7SettingsUi88: ['app-diagnostics-entry'],
      _en.e7SettingsUi92: ['settings-privacy-data-use'],
      _en.e7SettingsUi94: ['settings-voice-notices'],
      _en.e7SettingsUi96: ['settings-about-notices'],
      // Keywords from the phase 2 spec.
      'host': ['settings-category-server', 'settings-saved-servers'],
      'url': ['settings-category-server', 'settings-saved-servers'],
      'password': ['settings-category-server', 'settings-saved-servers'],
      'profile': ['settings-category-server', 'settings-saved-servers'],
      'termux': ['settings-on-this-phone'],
      'local': ['settings-on-this-phone'],
      'on-device': ['settings-on-this-phone'],
      'alerts': ['settings-category-background'],
      'quiet': ['settings-category-background'],
      'battery': ['settings-category-background'],
      'background': ['settings-category-background'],
      'check-in': ['settings-category-background'],
      'theme': ['settings-category-appearance'],
      'dark': ['settings-category-appearance'],
      'language': ['settings-category-appearance'],
      'arabic': ['settings-category-appearance'],
      'font': ['settings-category-appearance'],
      'provider': ['settings-models', 'settings-providers'],
      'api key': ['settings-providers'],
      'mcp': ['settings-mcp'],
      'tools': ['settings-commands-tools', 'settings-mcp'],
      'skills': ['settings-commands-tools'],
      'cost': ['settings-category-usage'],
      'tokens': ['settings-category-usage'],
      'budget': ['settings-category-usage', 'settings-category-quota'],
      'quota': ['settings-category-usage', 'settings-category-quota'],
      'limit': ['settings-category-usage', 'settings-category-quota'],
      'drafts': ['settings-category-privacy'],
      'queue': ['settings-category-privacy'],
      'read state': ['settings-category-privacy'],
      'guide': ['settings-setup-guide'],
      'bug': ['library-report-bug'],
      'diagnostics': ['app-diagnostics-entry'],
      'version': ['settings-about-notices'],
      'licenses': ['settings-voice-notices', 'settings-about-notices'],
    };

    final search = find.byKey(const Key('library-search'));
    for (final entry in cases.entries) {
      await tester.enterText(search, entry.key);
      await tester.pump();
      for (final key in entry.value) {
        expect(_row(key), findsOneWidget, reason: '"${entry.key}" -> $key');
      }
      // A search narrows: it never just shows the whole hub.
      expect(
        find.byKey(const Key('library-search-summary')),
        findsOneWidget,
        reason: entry.key,
      );
    }

    // A title search is specific: unrelated groups drop out entirely.
    await tester.enterText(search, _en.settingsHubModelAndMode);
    await tester.pump();
    expect(_row('settings-group-conversation-defaults'), findsOneWidget);
    expect(_row('settings-group-connection'), findsNothing);
    expect(_row('settings-group-help'), findsNothing);
  });

  testWidgets('keyboard shortcuts are a Help row on desktop only', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    expect(_row('library-keyboard-shortcuts'), findsNothing);

    debugPlatformCapabilities = const PlatformCapabilities(
      platform: TargetPlatform.linux,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    final search = find.byKey(const Key('library-search'));
    await tester.enterText(search, _en.e7LibraryKeyboardShortcuts);
    await tester.pump();
    expect(_row('library-keyboard-shortcuts'), findsOneWidget);
    await tester.enterText(search, 'hotkeys');
    await tester.pump();
    expect(_row('library-keyboard-shortcuts'), findsOneWidget);
  });

  testWidgets('search recovers from no results and clears', (tester) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    final search = find.byKey(const Key('library-search'));
    await tester.enterText(search, 'shell');
    await tester.pumpAndSettle();
    expect(_row('library-terminal'), findsOneWidget);
    expect(_row('default-shell-settings-entry'), findsOneWidget);
    expect(_row('settings-providers'), findsNothing);
    await tester.enterText(search, 'not-a-real-tool');
    await tester.pumpAndSettle();
    expect(find.textContaining('not-a-real-tool'), findsWidgets);
    expect(find.byType(ListTile), findsNothing);
    for (final group in SettingsGroup.values) {
      expect(_row('settings-group-${group.slug}'), findsNothing);
    }
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(_row('settings-providers'), findsOneWidget);
    expect(_row('settings-group-help'), findsOneWidget);
  });

  group('rows the server cannot serve are absent', () {
    const agentSetupRows = [
      'settings-models',
      'settings-providers',
      'settings-mcp',
      'settings-commands-tools',
      'library-import-session',
      'library-terminal',
    ];

    for (final backend in {
      'Codex': codexServerCapabilities,
      'Paseo': paseoServerCapabilities,
    }.entries) {
      testWidgets('${backend.key} hides the server catalog rows', (
        tester,
      ) async {
        final capabilities = backend.value;
        final controller = await _controller(capabilities: capabilities);
        addTearDown(controller.dispose);
        await tester.pumpWidget(_app(controller));
        await tester.pumpAndSettle();

        expect(capabilities.serverCatalog, isFalse);
        expect(_row('settings-models'), findsNothing);
        expect(_row('settings-providers'), findsNothing);
        expect(_row('settings-mcp'), findsNothing);
        expect(_row('settings-commands-tools'), findsNothing);
        expect(
          _row('library-terminal'),
          capabilities.terminal ? findsOneWidget : findsNothing,
        );
        expect(
          _row('library-import-session'),
          capabilities.sessionImportExport ? findsOneWidget : findsNothing,
        );
        expect(
          _row('default-shell-settings-entry'),
          capabilities.shellSettings ? findsOneWidget : findsNothing,
        );
        // The one deliberate exception (port §7 row 22): disabled, with its
        // reason, instead of absent.
        expect(
          _row('gated-shell-settings'),
          capabilities.shellSettings ? findsNothing : findsOneWidget,
        );
        expect(
          _row('settings-accounts'),
          capabilities.agentAccount ? findsOneWidget : findsNothing,
        );
        // Absent rows are absent from search too, not dead results.
        await tester.enterText(find.byKey(const Key('library-search')), 'mcp');
        await tester.pump();
        expect(_row('settings-mcp'), findsNothing);
        // What is about the app, not the server, survives.
        await tester.tap(find.byTooltip('Clear search'));
        await tester.pump();
        expect(_row('settings-category-appearance'), findsOneWidget);
        expect(_row('settings-category-server'), findsOneWidget);
      });
    }

    testWidgets('a group with no rows is absent', (tester) async {
      debugPlatformCapabilities = const PlatformCapabilities(
        platform: TargetPlatform.linux,
      );
      final controller = await _controller(
        capabilities: const ServerCapabilities(
          serverCatalog: false,
          terminal: false,
          sessionImportExport: false,
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      for (final key in agentSetupRows) {
        expect(_row(key), findsNothing, reason: key);
      }
      // Plugins ("In this app") still needs only a saved server.
      expect(_row('settings-group-agent-setup'), findsOneWidget);
      // No background service off Android: the Notifications group is gone
      // rather than an empty header.
      expect(_row('settings-category-background'), findsNothing);
      expect(_row('settings-group-notifications'), findsNothing);
      expect(find.text(_en.settingsHubGroupNotifications), findsNothing);
    });
  });

  testWidgets(
    'the default model uses the catalog name and explains its scope',
    (tester) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      controller.selectedModel = ModelRef(
        providerID: 'opencode',
        modelID: 'nemotron-free',
      );
      controller.catalog = const CatalogSnapshot(
        providers: [],
        agents: [],
        models: [
          CatalogModel(
            id: 'nemotron-free',
            providerID: 'opencode',
            name: 'Nemotron Ultra',
            enabled: true,
            status: 'active',
            contextLimit: 100000,
            outputLimit: 8000,
            reasoning: true,
            attachments: false,
            tools: true,
            variants: [],
          ),
        ],
      );
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();
      // Once as the conversation default, once on the Models door.
      expect(find.textContaining('Nemotron Ultra'), findsNWidgets(2));
      expect(find.textContaining('opencode/nemotron-free'), findsNothing);
      expect(find.textContaining('New chats:'), findsOneWidget);
    },
  );

  testWidgets('the hub carries no pending badge of its own', (tester) async {
    final controller = await _controller()
      ..permissions = {
        'perm-1': PermissionRequest(
          id: 'perm-1',
          sessionID: 'ses_run',
          permission: 'edit',
          patterns: const ['lib/main.dart'],
        ),
      };
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    // One global badge only, and it is not here. Nor does the hub repeat
    // pending work as a destination of its own.
    expect(find.byType(Badge), findsNothing);
    expect(find.text('Mission Control'), findsNothing);
    expect(find.text('Requests'), findsNothing);
  });

  testWidgets(
    'Terminal stays reachable from the hub and opens with an app bar',
    (tester) async {
      final controller = await _controller();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      final row = _row('library-terminal');
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: _row('settings-group-agent-setup'), matching: row),
        findsOneWidget,
      );

      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.byType(TerminalScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Terminal'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('an entry point can open the hub scrolled to a group', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, initialGroup: SettingsGroup.help));
    await tester.pumpAndSettle();

    final help = tester.getRect(_row('settings-group-help'));
    expect(help.top, lessThan(700));
    expect(help.top, greaterThanOrEqualTo(0));
    expect(
      tester.getRect(_row('settings-group-connection')).bottom,
      lessThan(0),
    );
  });

  group('layout at 320 dp and 2.5x text', () {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('no overflow in ${locale.languageCode}', (tester) async {
        const phone = Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = phone;
        addTearDown(tester.view.reset);
        final controller = await _controller(
          capabilities: const ServerCapabilities(agentAccount: true),
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: phone,
              textScaler: TextScaler.linear(AppTheme.maxTextScale),
            ),
            child: _app(controller, locale: locale),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          Directionality.of(tester.element(_row('settings-group-help'))),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );

        // Walk the whole hub so every row has been laid out and painted.
        final scrollable = find.byType(Scrollable).first;
        for (final group in SettingsGroup.values) {
          await tester.scrollUntilVisible(
            _row('settings-group-${group.slug}'),
            300,
            scrollable: scrollable,
          );
          expect(tester.takeException(), isNull, reason: group.slug);
        }
        // No row is wider than the phone.
        for (final tile in tester.widgetList<ListTile>(find.byType(ListTile))) {
          final box = tester.renderObject<RenderBox>(find.byWidget(tile));
          expect(box.size.width, lessThanOrEqualTo(phone.width));
        }

        // Searching reflows the same rows; it must not overflow either.
        await tester.enterText(find.byKey(const Key('library-search')), 'a');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
