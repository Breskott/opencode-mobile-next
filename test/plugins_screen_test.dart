import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/domain/plugin_inventory.dart';
import 'package:opencode_mobile/domain/server_gateway.dart'
    show StreamStatus, CommandInfo;
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/gascity_probe.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit_top_bar.dart';
import 'package:opencode_mobile/ui/screens/settings/plugins_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api extends OpenCodeApi {
  _Api(this.supported) : super(baseUrl: 'https://plugins.example');
  final bool supported;
  @override
  ServerCapabilities get capabilities =>
      ServerCapabilities(pluginInventory: supported);
}

class _Repository implements ProductRepository, PluginGateway {
  int calls = 0;
  Completer<List<PluginInfo>>? gate;
  bool fail = false;
  int commandCalls = 0;
  Completer<List<CommandInfo>>? commandGate;
  List<CommandInfo> commands = const [
    CommandInfo(name: 'review', subtask: false),
  ];
  @override
  Future<List<CommandInfo>> listCommands() async {
    commandCalls++;
    return commandGate?.future ?? commands;
  }

  List<PluginInfo> plugins = [];
  @override
  Future<List<PluginInfo>> listPlugins() {
    calls++;
    if (fail) return Future.error(StateError('synthetic-secret'));
    return gate?.future ?? Future.value(plugins);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _plugin = PluginInfo(
  id: 'reviewer',
  status: PluginStatus.active,
  source: PluginSourceKind.package,
  packageName: '@example/reviewer',
  terminalUi: true,
);

Future<ConnectionController> _controller(
  _Repository repository, {
  bool supported = true,
}) async {
  SharedPreferences.setMockInitialValues({
    'oc.profiles': jsonEncode([
      {'id': 'plugins', 'name': 'Test', 'baseUrl': 'https://plugins.example'},
    ]),
    'oc.activeProfile': 'plugins',
  });
  final store = ProfileStore(prefs: await SharedPreferences.getInstance());
  await store.load();
  final controller = ConnectionController(store)
    ..api = _Api(supported)
    ..repository = repository
    ..status = StreamStatus.connected;
  addTearDown(controller.dispose);
  return controller;
}

Widget _app(ConnectionController controller, {double textScale = 1}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      // The real Plugins screen, so the section is exercised where it lives.
      // The probe never finds an AI Team host and never touches the network.
      home: PluginsSettingsScreen(
        controller: controller,
        probe: (url, {city}) async =>
            const ProbeUnreachable(error: 'no answer'),
      ),
    );

/// Opens the reviewer plugin's Details (tapping its row).
Future<void> _details(WidgetTester tester) async {
  await tester.tap(find.text('Reviewer'));
  await tester.pumpAndSettle();
}

Future<void> _closeSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(5, 5));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (_) async => null),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, null),
  );

  testWidgets('a plugin row opens its details; nothing offers command links '
      '(slice-P3.1: plugins-mapping-dialog and its clear sheet are gone)', (
    tester,
  ) async {
    final repository = _Repository()..plugins = [_plugin];
    final controller = await _controller(repository);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    // The row is the one way in: no row menu, no page menu.
    expect(find.byKey(const ValueKey('plugin-menu-reviewer')), findsNothing);
    expect(find.byKey(const ValueKey('plugins-section-menu')), findsNothing);
    expect(find.text('Link commands'), findsNothing);
    expect(find.text('Clear personal command links'), findsNothing);
    await _details(tester);
    expect(find.byKey(const ValueKey('plugin-details-sheet')), findsOneWidget);
    expect(find.text('Package · @example/reviewer'), findsOneWidget);
    expect(find.text('reviewer'), findsOneWidget);
    expect(find.textContaining('command links'), findsNothing);
    // Reading the inventory never asks for the server's commands.
    expect(repository.commandCalls, 0);
    await _closeSheet(tester);
    expect(find.byKey(const ValueKey('plugin-details-sheet')), findsNothing);
  });

  testWidgets('one Plugins screen: "In this app" above "On the server"', (
    tester,
  ) async {
    final repository = _Repository()..plugins = [_plugin];
    await tester.pumpWidget(_app(await _controller(repository)));
    await tester.pumpAndSettle();

    // The kit's top bar (screen-library-3, TEST-19: KitTopBar replaced the
    // Material AppBar).
    expect(find.byType(KitTopBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(KitTopBar),
        matching: find.text('Plugins'),
      ),
      findsOneWidget,
    );
    final app = find.text('In this app');
    final server = find.text('On the server');
    expect(app, findsOneWidget);
    expect(server, findsOneWidget);
    expect(tester.getTopLeft(app).dy, lessThan(tester.getTopLeft(server).dy));
    final team = find.byKey(const ValueKey('plugins-ai-team-row'));
    expect(tester.getTopLeft(team).dy, lessThan(tester.getTopLeft(server).dy));
    // The server's plugins are carded in the section's own row group,
    // like "In this app", and its actions are the page's top bar's.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('plugins-section-server-group')),
        matching: find.text('Reviewer'),
      ),
      findsOneWidget,
    );
    expect(find.text('Loaded by the server for this project.'), findsNothing);
    expect(find.byTooltip('Refresh plugins'), findsOneWidget);
  });

  testWidgets('unsupported servers make no plugin request', (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(
      _app(await _controller(repository, supported: false)),
    );
    await tester.pumpAndSettle();
    // Hide, don't disable: without an inventory the "On the server" section
    // is absent, while "In this app" stays.
    expect(find.byKey(const ValueKey('plugins-section-server')), findsNothing);
    expect(find.text('On the server'), findsNothing);
    expect(
      find.text('This server does not support plugin inspection.'),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('plugins-section-app')), findsOneWidget);
    expect(find.byKey(const ValueKey('plugins-ai-team-row')), findsOneWidget);
    expect(repository.calls, 0);
  });

  testWidgets(
    'empty, failure and retry states are distinct and hide raw errors',
    (tester) async {
      final repository = _Repository()..fail = true;
      await tester.pumpWidget(_app(await _controller(repository)));
      await tester.pumpAndSettle();
      expect(find.text('Could not load plugins. Try again.'), findsOneWidget);
      expect(find.textContaining('synthetic-secret'), findsNothing);
      expect(find.text('No plugins reported for this project.'), findsNothing);
      repository.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(
        find.text('No plugins reported for this project.'),
        findsOneWidget,
      );
      expect(repository.calls, 2);
    },
  );

  testWidgets('late previous-location inventory is discarded', (tester) async {
    final repository = _Repository()..gate = Completer<List<PluginInfo>>();
    final controller = await _controller(repository);
    await tester.pumpWidget(_app(controller));
    await tester.pump();
    final oldResponse = repository.gate!;
    repository.gate = null;
    controller.directory = '/new-location';
    controller.locationRevision++;
    controller.notifyListeners();
    await tester.pumpAndSettle();
    oldResponse.complete([_plugin]);
    await tester.pumpAndSettle();
    expect(find.text('Reviewer'), findsNothing);
    expect(find.text('No plugins reported for this project.'), findsOneWidget);
    expect(repository.calls, 2);
  });

  testWidgets('late inventory after disposal is ignored', (tester) async {
    final repository = _Repository()..gate = Completer<List<PluginInfo>>();
    final controller = await _controller(repository);
    await tester.pumpWidget(_app(controller));
    await tester.pump();
    final lateResponse = repository.gate!;
    await tester.pumpWidget(const SizedBox.shrink());
    lateResponse.complete([_plugin]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('plugin events and reconnect refetch current inventory', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = await _controller(repository);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    repository.plugins = [_plugin];
    controller.handleEventForTesting(
      EventEnvelope(type: 'plugin.updated', properties: {}),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reviewer'), findsOneWidget);
    // Where it comes from is under its Details.
    await _details(tester);
    expect(find.text('Package · @example/reviewer'), findsOneWidget);
    expect(find.text('Terminal UI declared'), findsOneWidget);
    await _closeSheet(tester);
    controller.status = StreamStatus.disconnected;
    controller.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Reviewer'), findsNothing);
    repository.plugins = [];
    controller.status = StreamStatus.connected;
    controller.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('No plugins reported for this project.'), findsOneWidget);
    expect(repository.calls, 3);
  });

  testWidgets('flat plugin rows fit a narrow phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository()
      ..plugins = [
        _plugin,
        const PluginInfo(
          id: null,
          status: PluginStatus.failed,
          source: PluginSourceKind.local,
          terminalUi: false,
        ),
      ];
    await tester.pumpWidget(_app(await _controller(repository), textScale: 2));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Plugin without an ID'), 150);
    expect(tester.takeException(), isNull);
    expect(find.byType(Card), findsNothing);
  });
}
