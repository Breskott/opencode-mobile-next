import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/widgets/other_projects_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Controller extends ConnectionController {
  _Controller(super.store);

  List<ProfileLocation> recents = const [];
  List<ElsewhereConversation> elsewhere = const [];
  final switched = <String?>[];
  final opened = <String?>[];
  final forgotten = <String>[];

  @override
  List<ProfileLocation> get recentLocations => recents;

  @override
  Future<List<ElsewhereConversation>> conversationsElsewhere({
    int limit = 6,
  }) async => elsewhere;

  @override
  Future<void> selectLocation({String? directory, String? workspace}) async {
    switched.add(directory);
    this.directory = directory;
  }

  @override
  Future<void> selectLocationForExistingSession({
    String? directory,
    String? workspace,
  }) async {
    opened.add(directory);
    this.directory = directory;
  }

  @override
  Future<void> forgetRecentLocation(String directory) async {
    forgotten.add(directory);
    recents = [
      for (final location in recents)
        if (location.directory != directory) location,
    ];
    notifyListeners();
  }
}

/// A healthy v1 server that answers the connect-time reads locally.
class _BadgeApi extends OpenCodeApi {
  _BadgeApi() : super(baseUrl: 'http://127.0.0.1:1');

  @override
  Future<Health> health() async => Health(healthy: true, version: '1.18.23');

  @override
  Future<List<Session>> sessions() async => const [];

  @override
  Future<Map<String, String>> sessionStatuses() async => const {};

  @override
  Future<ProvidersResponse> providers() async =>
      ProvidersResponse(providers: const []);

  @override
  Future<ProvidersResponse> configuredProviders() async =>
      ProvidersResponse(providers: const []);

  @override
  Future<List<AgentInfo>> agents() async => const [];

  @override
  Future<List<PermissionRequest>> pendingPermissions() async => const [];

  @override
  Future<List<PermissionRequest>> pendingPermissionsV2() =>
      Future.error(ApiException('V2 unavailable', statusCode: 404));

  @override
  Future<List<Map<String, dynamic>>> pendingQuestionsV2() =>
      Future.error(ApiException('V2 unavailable', statusCode: 404));
}

class _BadgeRepository extends SdkProductRepository {
  _BadgeRepository(OpenCodeApi api) : super(api.sdkClient);

  @override
  Future<ChatDefaults> loadChatDefaults() async => const ChatDefaults();

  @override
  Future<List<PendingQuestion>> listQuestions() async => const [];

  @override
  Future<CatalogSnapshot> loadCatalog() async =>
      const CatalogSnapshot(providers: [], models: [], agents: []);

  @override
  Future<List<IntegrationInfo>> listIntegrations() async => const [];
}

class _Channel extends EventStream {
  _Channel({
    required super.api,
    required super.onEvent,
    required super.onStatus,
    super.onError,
  });

  @override
  void start() => onStatus(StreamStatus.connecting);

  @override
  Future<void> dispose() async {}

  void emit(EventEnvelope value) => onEvent(value);
}

EventStreamFactory _channels(List<_Channel> opened) =>
    ({required api, required onEvent, required onStatus, onError}) {
      final channel = _Channel(
        api: api,
        onEvent: onEvent,
        onStatus: onStatus,
        onError: onError,
      );
      opened.add(channel);
      return channel;
    };

ElsewhereConversation _conversation(
  String id,
  String title,
  String directory, {
  bool running = false,
}) => ElsewhereConversation(
  session: Session(id: id, title: title, directory: directory),
  directory: directory,
  running: running,
);

Future<_Controller> _pump(
  WidgetTester tester, {
  List<ProfileLocation> recents = const [],
  List<ElsewhereConversation> elsewhere = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final controller = _Controller(ProfileStore(prefs: prefs))
    ..status = StreamStatus.connected
    ..directory = '/work/app'
    ..recents = recents
    ..elsewhere = elsewhere;
  addTearDown(controller.dispose);
  final pushed = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateRoute: (settings) {
        pushed.add(settings.name ?? '');
        return MaterialPageRoute<void>(
          builder: (_) => Scaffold(body: Text('route ${settings.name}')),
        );
      },
      home: Scaffold(body: OtherProjectsPanel(controller: controller)),
    ),
  );
  await tester.pump();
  await tester.pump();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('with one project in play the Work tab shows nothing extra', (
    tester,
  ) async {
    await _pump(
      tester,
      recents: const [ProfileLocation(directory: '/work/app')],
    );
    expect(find.byKey(const Key('other-projects-panel')), findsNothing);
    expect(find.text('Other projects'), findsNothing);
  });

  Finder row(String directory) =>
      find.byKey(ValueKey('other-project-$directory'));
  Finder inRow(String directory, String text) =>
      find.descendant(of: row(directory), matching: find.textContaining(text));

  testWidgets('each other project is one row that says what runs there', (
    tester,
  ) async {
    final controller = await _pump(
      tester,
      recents: const [
        ProfileLocation(directory: '/work/app'),
        ProfileLocation(directory: '/work/FinanceHub3'),
        ProfileLocation(directory: '/work/site'),
      ],
      elsewhere: [
        _conversation('s1', 'Fix offers', '/work/FinanceHub3', running: true),
        _conversation('s2', 'Tidy css', '/work/site'),
      ],
    );
    // The current project is the header's job, not a row.
    expect(row('/work/app'), findsNothing);
    expect(find.text('Other projects'), findsOneWidget);
    expect(inRow('/work/FinanceHub3', 'FinanceHub3'), findsOneWidget);
    expect(inRow('/work/FinanceHub3', 'Running · Fix offers'), findsOneWidget);
    // Nothing live in site: its row names no conversation.
    expect(find.textContaining('Tidy css'), findsNothing);
    // Each project is named once on the whole panel.
    expect(find.textContaining('site'), findsOneWidget);

    await tester.tap(find.text('site'));
    await tester.pump();
    expect(controller.switched, ['/work/site']);
  });

  testWidgets('the row menu opens the live conversation, named, in its own '
      'project', (tester) async {
    final controller = await _pump(
      tester,
      elsewhere: [
        _conversation('s1', 'Fix offers', '/work/FinanceHub3', running: true),
        _conversation('s2', 'Tidy css', '/work/site'),
      ],
    );
    // One tap target per row (R2): no trailing button that looks like the
    // row's own.
    expect(
      find.byKey(const ValueKey('other-project-open-/work/FinanceHub3')),
      findsNothing,
    );
    await tester.longPress(find.text('FinanceHub3'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('other-project-open-/work/site')),
      findsNothing,
    );
    expect(find.text('Open “Fix offers”'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('other-project-open-/work/FinanceHub3')),
    );
    await tester.pumpAndSettle();
    expect(controller.opened, ['/work/FinanceHub3']);
    expect(find.text('route /chat/s1'), findsOneWidget);
  });

  testWidgets('at most three rows, then All projects; needs you comes first', (
    tester,
  ) async {
    final opened = <String>[];
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = _Controller(ProfileStore(prefs: prefs))
      ..status = StreamStatus.connected
      ..directory = '/work/app'
      ..recents = [
        for (final name in ['app', 'a', 'b', 'c', 'd'])
          ProfileLocation(directory: '/work/$name'),
      ];
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: OtherProjectsPanel(
            controller: controller,
            onAllProjects: () => opened.add('all'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('a'), findsOneWidget);
    expect(find.text('c'), findsOneWidget);
    expect(find.text('d'), findsNothing);
    controller.elsewhereAttention.handle(
      EventEnvelope(
        type: 'question.asked',
        directory: '/work/d',
        properties: const {'id': 'q1', 'sessionID': 's9'},
      ),
    );
    await tester.pump();
    // Stuck on the person: it moves up into the three shown.
    expect(inRow('/work/d', 'Needs you'), findsOneWidget);
    expect(find.text('c'), findsNothing);
    await tester.tap(find.text('All projects'));
    expect(opened, ['all']);
  });

  testWidgets('a project where an agent is stopped on you says so, live', (
    tester,
  ) async {
    final controller = await _pump(
      tester,
      recents: const [
        ProfileLocation(directory: '/work/app'),
        ProfileLocation(directory: '/work/FinanceHub3'),
      ],
      elsewhere: [_conversation('s1', 'Fix offers', '/work/FinanceHub3')],
    );
    expect(find.textContaining('Needs you'), findsNothing);
    expect(controller.waitingElsewhereCount, 0);

    // From the server-wide event channel, while looking at another project.
    controller.elsewhereAttention.handle(
      EventEnvelope(
        type: 'permission.v2.asked',
        directory: '/work/FinanceHub3',
        properties: const {'id': 'req1', 'sessionID': 's1'},
      ),
    );
    await tester.pump();
    expect(inRow('/work/FinanceHub3', 'Needs you · Fix offers'), findsOne);
    expect(controller.waitingElsewhereCount, 1);
    // The Inbox badge counts it once this server's global channel reported
    // it (the badge is the attention feed since c96a7fb4): see "the Inbox
    // badge counts ..." below, which connects for real.

    // A project not listed yet earns a row the moment it needs you.
    controller.elsewhereAttention.handle(
      EventEnvelope(
        type: 'question.asked',
        directory: '/work/site',
        properties: const {'id': 'q1', 'sessionID': 's7'},
      ),
    );
    await tester.pump();
    expect(inRow('/work/site', 'Needs you'), findsOneWidget);

    controller.elsewhereAttention.handle(
      EventEnvelope(
        type: 'permission.v2.replied',
        directory: '/work/FinanceHub3',
        properties: const {'requestID': 'req1'},
      ),
    );
    await tester.pump();
    expect(inRow('/work/FinanceHub3', 'Needs you'), findsNothing);
  });

  // The badge is the attention feed (c96a7fb4): another project's request
  // counts for the saved server whose global channel reported it.
  // A plain test: connecting starts the controller's own timers, which
  // dispose cancels.
  test('the Inbox badge counts a request stopped on you in another '
      'project, from the server-wide channel', () async {
    const secure = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(secure, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(secure, null));
    SharedPreferences.setMockInitialValues({});
    final store = ProfileStore(prefs: await SharedPreferences.getInstance());
    final server = ServerProfile(
      id: 'server',
      name: 'server',
      baseUrl: 'http://127.0.0.1:1',
    );
    await store.upsert(server);
    final global = <_Channel>[];
    final controller = ConnectionController(
      store,
      apiFactory: (_) => _BadgeApi(),
      repositoryFactory: (api) => _BadgeRepository(api),
      eventStreamFactory: _channels([]),
      globalEventStreamFactory: _channels(global),
    );
    addTearDown(controller.dispose);
    await controller.connect(server);
    expect(global, hasLength(1));
    final before = controller.unifiedAttentionCount;

    global.single.emit(
      EventEnvelope(
        type: 'permission.v2.asked',
        directory: '/work/FinanceHub3',
        properties: const {'id': 'req1', 'sessionID': 's1'},
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.waitingElsewhereCount, 1);
    expect(controller.unifiedAttentionCount, before + 1);

    global.single.emit(
      EventEnvelope(
        type: 'permission.v2.replied',
        directory: '/work/FinanceHub3',
        properties: const {'requestID': 'req1'},
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.unifiedAttentionCount, before);
  });

  testWidgets('a project can be taken off the list', (tester) async {
    final controller = await _pump(
      tester,
      recents: const [
        ProfileLocation(directory: '/work/app'),
        ProfileLocation(directory: '/work/old'),
      ],
    );
    await tester.longPress(find.text('old'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from recent projects'));
    await tester.pumpAndSettle();
    expect(controller.forgotten, ['/work/old']);
    expect(find.text('old'), findsNothing);
  });

  test('a server remembers its recent projects, newest first', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = ProfileStore(prefs: prefs);
    for (final name in ['a', 'b', 'a', 'c']) {
      await store.setLocation('p1', directory: '/work/$name');
    }
    expect(store.recentLocations('p1').map((l) => l.directory), [
      '/work/c',
      '/work/a',
      '/work/b',
    ]);
    // Another server has its own list.
    expect(store.recentLocations('p2'), isEmpty);

    for (var i = 0; i < 12; i++) {
      await store.setLocation('p1', directory: '/work/n$i');
    }
    expect(
      store.recentLocations('p1'),
      hasLength(ProfileStore.maxRecentLocations),
    );

    await store.forgetRecentLocation('p1', '/work/n11');
    expect(
      store.recentLocations('p1').map((l) => l.directory),
      isNot(contains('/work/n11')),
    );
    // Removed with the server: the key is inside the per-profile sweep.
    expect(
      store.profileScopedPreferenceKeys('p1'),
      contains('oc.recentLocations.p1'),
    );
  });
}
