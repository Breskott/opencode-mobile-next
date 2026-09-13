import 'dart:async';

import 'support/complete_message_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/domain/session_handoff.dart';
import 'package:opencode_mobile/main.dart';
import 'package:opencode_mobile/platform/session_link.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';
import 'package:opencode_mobile/ui/screens/servers_screen.dart';
import 'package:opencode_mobile/update/shorebird_update_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryProfileStore extends ProfileStore {
  _MemoryProfileStore({required super.prefs, required this.saved});

  final List<ServerProfile> saved;
  String? selectedID;

  @override
  List<ServerProfile> get profiles => saved;

  @override
  String? get activeId => selectedID;

  @override
  Future<void> setActiveId(String? id) async {
    selectedID = id;
  }
}

/// A connected v1 transport that counts everything a link must never do:
/// creating a session or sending a prompt.
class _LinkApi extends OpenCodeApi with CompleteMessageHistory {
  _LinkApi({super.baseUrl = 'http://localhost:4096'});

  int created = 0;
  int prompted = 0;
  final healthResult = Completer<Health>();

  @override
  Future<Health> health() => healthResult.future;

  @override
  Future<Session> createSession() async {
    created += 1;
    return Session(id: 'created-$created');
  }

  @override
  Future<void> promptAsync(
    String sessionID, {
    required String text,
    ModelRef? model,
    String? agent,
    String? variant,
    List<PromptAttachment> attachments = const [],
    List<PromptAgentMention> agentMentions = const [],
    PromptDelivery? delivery,
  }) async {
    prompted += 1;
  }

  @override
  Future<List<MessageWithParts>> messages(String id) async => const [];

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
  Future<List<PermissionRequest>> pendingPermissionsV2() async => const [];

  @override
  Future<List<Map<String, dynamic>>> pendingQuestionsV2() async => const [];
}

class _LinkRepository implements ProductRepository {
  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<List<WorkspaceProject>> listProjects() async => const [];

  @override
  Future<List<WorkspaceInfo>> listWorkspaces() async => const [];

  @override
  Future<List<PendingQuestion>> listQuestions() async => const [];

  @override
  Future<ChatDefaults> loadChatDefaults() async => const ChatDefaults();

  @override
  Future<List<IntegrationInfo>> listIntegrations() async => const [];

  @override
  Future<WorkspaceProject?> loadCurrentProject() async => null;

  @override
  Future<CatalogSnapshot> loadCatalog() async =>
      const CatalogSnapshot(providers: [], models: [], agents: []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEventStream extends EventStream {
  _FakeEventStream({
    required super.api,
    required super.onEvent,
    required super.onStatus,
    super.onError,
  });

  @override
  void start() => onStatus(StreamStatus.connected);

  @override
  Future<void> dispose() async {}
}

class _NoUpdateService implements AppUpdateService {
  @override
  bool get isAvailable => false;

  @override
  Future<AppUpdateState> checkForUpdate() async => AppUpdateState.unavailable;

  @override
  Future<void> downloadUpdate() async {}
}

final _active = ServerProfile(
  id: 'server-1',
  name: 'Local',
  baseUrl: 'http://localhost:4096',
);

/// Builds a controller with `server-1` active and connected through fakes.
/// [others] are additional saved servers; [apis] collects every transport a
/// later `connect` creates so a test can complete its health probe.
Future<ConnectionController> _controller({
  bool connected = true,
  List<ServerProfile> others = const [],
  List<_LinkApi>? apis,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final store = _MemoryProfileStore(
    prefs: preferences,
    saved: [_active, ...others],
  );
  await store.setActiveId(_active.id);
  final controller = ConnectionController(
    store,
    apiFactory: (profile) {
      final api = _LinkApi(baseUrl: profile.baseUrl);
      apis?.add(api);
      return api;
    },
    repositoryFactory: (_) => _LinkRepository(),
    eventStreamFactory:
        ({required api, required onEvent, required onStatus, onError}) =>
            _FakeEventStream(
              api: api,
              onEvent: onEvent,
              onStatus: onStatus,
              onError: onError,
            ),
  );
  if (connected) {
    controller
      ..api = _LinkApi()
      ..repository = _LinkRepository()
      ..version = '1.18.25'
      ..status = StreamStatus.connected;
  }
  return controller;
}

SessionLinkIntent _intent() {
  final intent = SessionLinkIntent(
    channel: const MethodChannel('oc/link-test'),
  );
  addTearDown(intent.dispose);
  return intent;
}

Widget _app(ConnectionController controller, SessionLinkIntent intent) =>
    ProviderScope(
      overrides: [
        bootstrapProvider.overrideWithValue(AppBootstrap(controller.store)),
        connProvider.overrideWithValue(controller),
      ],
      child: OcApp(
        updateService: _NoUpdateService(),
        sessionLinkIntent: intent,
      ),
    );

Future<void> _drainNotices(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 5));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a link for the active server opens that exact session', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    final api = controller.api! as _LinkApi;
    final intent = _intent();

    await tester.pumpWidget(_app(controller, intent));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsNothing);

    intent.pending.value = const SessionLink(
      profileID: 'server-1',
      sessionID: 'ses_link',
    );
    await tester.pumpAndSettle();

    final chat = tester.widget<ChatScreen>(find.byType(ChatScreen));
    expect(chat.sessionID, 'ses_link');
    expect(chat.initialText, isEmpty);
    expect(chat.initialAttachments, isEmpty);
    expect(chat.discardIfUntouched, isFalse);
    expect(api.created, 0);
    expect(api.prompted, 0);
    expect(intent.pending.value, isNull);
    expect(find.byType(ServersScreen), findsNothing);
    expect(find.byType(MaterialBanner), findsNothing);
    expect(controller.profile?.id, 'server-1');

    // Nothing re-fires the same link on later controller changes.
    await controller.refreshSessions();
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(api.created, 0);
    expect(api.prompted, 0);
  });

  testWidgets(
    'an unknown server shows the honest state with a way to Servers',
    (tester) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      final api = controller.api! as _LinkApi;
      final intent = _intent();

      await tester.pumpWidget(_app(controller, intent));
      await tester.pumpAndSettle();

      intent.pending.value = const SessionLink(
        profileID: 'someone-elses-phone',
        sessionID: 'ses_link',
      );
      await tester.pumpAndSettle();

      expect(find.byType(ChatScreen), findsNothing);
      expect(
        find.byKey(const Key('session-link-server-missing')),
        findsOneWidget,
      );
      expect(
        find.text(
          'This server is not saved on this phone. Add it under '
          'Servers, then scan the code again.',
        ),
        findsOneWidget,
      );
      expect(intent.pending.value, isNull);
      expect(api.created, 0);
      expect(api.prompted, 0);
      // The connection is untouched.
      expect(controller.status, StreamStatus.connected);
      expect(identical(controller.api, api), isTrue);

      await tester.tap(find.text('Open Servers'));
      await tester.pumpAndSettle();
      expect(find.byType(ServersScreen), findsOneWidget);
      expect(
        find.byKey(const Key('session-link-server-missing')),
        findsNothing,
      );
      expect(find.byType(ChatScreen), findsNothing);
    },
  );

  testWidgets('dismissing the unknown-server state leaves everything alone', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    final intent = _intent();

    await tester.pumpWidget(_app(controller, intent));
    await tester.pumpAndSettle();
    intent.pending.value = const SessionLink(
      profileID: 'unknown',
      sessionID: 'ses_link',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('session-link-server-missing')),
      findsOneWidget,
    );

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session-link-server-missing')), findsNothing);
    expect(find.byType(ServersScreen), findsNothing);
    expect(find.byType(ChatScreen), findsNothing);
  });

  /// Cold-starts the shell the way production does: `_Root` connects the
  /// saved server once, so a later profile switch is not raced by it.
  Future<void> coldStart(
    WidgetTester tester,
    ConnectionController controller,
    SessionLinkIntent intent,
    List<_LinkApi> apis,
  ) async {
    await tester.pumpWidget(_app(controller, intent));
    await tester.pump();
    await tester.pump();
    expect(apis, hasLength(1));
    apis.single.healthResult.complete(Health(healthy: true, version: '1'));
    await tester.pumpAndSettle();
    expect(controller.status, StreamStatus.connected);
    expect(controller.profile?.id, 'server-1');
    apis.clear();
  }

  testWidgets('a link for another saved server switches to it, then opens', (
    tester,
  ) async {
    final other = ServerProfile(
      id: 'server-2',
      name: 'Desk',
      baseUrl: 'https://desk.example.test:4096',
    );
    final apis = <_LinkApi>[];
    final controller = await _controller(
      connected: false,
      others: [other],
      apis: apis,
    );
    addTearDown(controller.dispose);
    final intent = _intent();
    await coldStart(tester, controller, intent, apis);
    final original = controller.api! as _LinkApi;

    intent.pending.value = const SessionLink(
      profileID: 'server-2',
      sessionID: 'ses_desk',
    );
    await tester.pump();
    await tester.pump();
    expect(apis, hasLength(1));
    expect(apis.single.baseUrl, 'https://desk.example.test:4096');
    apis.single.healthResult.complete(Health(healthy: true, version: '1'));
    await tester.pumpAndSettle();

    expect(controller.profile?.id, 'server-2');
    final chat = tester.widget<ChatScreen>(find.byType(ChatScreen));
    expect(chat.sessionID, 'ses_desk');
    expect(chat.initialText, isEmpty);
    expect(original.created, 0);
    expect(original.prompted, 0);
    expect(apis.single.created, 0);
    expect(apis.single.prompted, 0);
    expect(intent.pending.value, isNull);
    expect(find.byType(MaterialBanner), findsNothing);
    expect(find.byType(ServersScreen), findsNothing);
    // The live connection's polling fallback is a periodic timer; retire it
    // before the tree is torn down.
    controller.dispose();
  });

  testWidgets('a saved server whose connection fails routes to Servers', (
    tester,
  ) async {
    final broken = ServerProfile(
      id: 'server-2',
      name: 'Broken',
      baseUrl: 'desk:4096', // no scheme → synchronous validation error
    );
    final apis = <_LinkApi>[];
    final controller = await _controller(
      connected: false,
      others: [broken],
      apis: apis,
    );
    addTearDown(controller.dispose);
    final intent = _intent();
    await coldStart(tester, controller, intent, apis);

    intent.pending.value = const SessionLink(
      profileID: 'server-2',
      sessionID: 'ses_desk',
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsNothing);
    expect(find.byType(ServersScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(intent.pending.value, isNull);
    expect(apis, isEmpty);
    await _drainNotices(tester);
  });

  testWidgets('a saved server needing its password again routes to Servers', (
    tester,
  ) async {
    final locked = ServerProfile(
      id: 'server-2',
      name: 'Locked',
      baseUrl: 'https://desk.example.test:4096',
      requiresPasswordReentry: true,
    );
    final controller = await _controller(others: [locked]);
    addTearDown(controller.dispose);
    final api = controller.api! as _LinkApi;
    final intent = _intent();

    await tester.pumpWidget(_app(controller, intent));
    await tester.pumpAndSettle();

    intent.pending.value = const SessionLink(
      profileID: 'server-2',
      sessionID: 'ses_desk',
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsNothing);
    expect(find.byType(ServersScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(intent.pending.value, isNull);
    expect(api.created, 0);
    expect(api.prompted, 0);
    // The active connection was not switched away.
    expect(controller.profile?.id, 'server-1');
    expect(identical(controller.api, api), isTrue);
    await _drainNotices(tester);
  });

  testWidgets('a malformed link never reaches routing', (tester) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    final api = controller.api! as _LinkApi;
    final intent = _intent();
    await tester.pumpWidget(_app(controller, intent));
    await tester.pumpAndSettle();

    // The bridge parses strictly; a bad payload leaves nothing pending.
    expect(
      SessionLink.parse('opencode-mobile://session?profile=server-1'),
      isNull,
    );
    expect(intent.pending.value, isNull);
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsNothing);
    expect(find.byType(ServersScreen), findsNothing);
    expect(find.byType(MaterialBanner), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(api.created, 0);
    expect(api.prompted, 0);
  });
}
