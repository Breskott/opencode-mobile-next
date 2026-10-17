import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/library_screen.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/widgets/provider_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/capture/fixtures.dart' show loadCaptureFonts;

class _Api extends OpenCodeApi {
  _Api() : super(baseUrl: 'https://auth-test.example');
  @override
  ServerCapabilities get capabilities => const ServerCapabilities(
    providerRuntimeRefresh: false,
    integrationCommandAuth: true,
  );
  @override
  Future<Health> health() async => Health(healthy: true, version: 'test');
  @override
  Future<List<Session>> sessions() async => [];
  @override
  Future<Map<String, String>> sessionStatuses() async => {};
  @override
  Future<ProvidersResponse> providers() async =>
      ProvidersResponse(providers: []);
  @override
  Future<List<AgentInfo>> agents() async => [];
  @override
  Future<List<PermissionRequest>> pendingPermissions() async => [];
  @override
  Future<List<PermissionRequest>> pendingPermissionsV2() async => [];
  @override
  Future<List<Map<String, dynamic>>> pendingQuestionsV2() async => [];
}

class _Events extends EventStream {
  _Events({
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

class _Repository implements ProductRepository, IntegrationAuthRecoveryGateway {
  int starts = 0;
  int statusCalls = 0;
  final cancels = <String>[];
  String instructions = 'Enter code: VPFI-KC2ZK';

  /// What the status check does: null waits on [gate]; a function decides.
  Completer<IntegrationAuthStatus>? gate;
  Object? statusError;

  IntegrationAuthLaunch get launch => IntegrationAuthLaunch(
    attemptID: 'attempt-$starts',
    url: 'https://auth.openai.example/codex/device',
    instructions: instructions,
    mode: IntegrationAuthMode.auto,
  );

  @override
  void setLocation({String? directory, String? workspace}) {}
  @override
  Future<List<IntegrationInfo>> listIntegrations() async => [
    IntegrationInfo(
      id: 'openai',
      name: 'OpenAI',
      connectionCount: 0,
      methods: [
        const IntegrationMethodInfo(
          type: 'oauth',
          id: '0',
          label: 'ChatGPT Pro/Plus (headless)',
        ),
        ...extraMethods,
      ],
    ),
  ];
  List<IntegrationMethodInfo> extraMethods = const [];
  @override
  Future<List<McpServerInfo>> listMcpServers() async => [];
  @override
  Future<List<McpResourceInfo>> listMcpResources() async => [];
  @override
  Future<List<WorkspaceProject>> listProjects() async => [];
  @override
  Future<WorkspaceProject?> loadCurrentProject() async => null;
  @override
  Future<List<PendingQuestion>> listQuestions() async => [];
  @override
  Future<CatalogSnapshot> loadCatalog() async =>
      const CatalogSnapshot(providers: [], models: [], agents: []);
  @override
  Future<ChatDefaults> loadChatDefaults() async => const ChatDefaults();
  @override
  Future<IntegrationAuthLaunch> startIntegrationOAuth(
    String id,
    String methodID, {
    Map<String, String> inputs = const {},
    String? label,
  }) async {
    starts++;
    return launch;
  }

  @override
  Future<IntegrationAuthStatus> integrationOAuthStatus(String attemptID) {
    statusCalls++;
    if (statusError != null) return Future.error(statusError!);
    return gate!.future;
  }

  @override
  Future<void> cancelIntegrationOAuth(String attemptID) async {
    cancels.add(attemptID);
  }

  @override
  void restoreIntegrationAuthAttempt({
    required String integrationID,
    required String attemptID,
    required bool command,
    String? directory,
    String? workspace,
  }) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The server answered the check with a refusal (OpenCode's
/// ProviderAuthOauthMissing after a restart, or OauthCallbackFailed).
ProductException get _serverRefused => ProductException(
  'Could not check provider authentication',
  cause: DioException(
    requestOptions: RequestOptions(path: '/provider/openai/oauth/callback'),
    response: Response(
      requestOptions: RequestOptions(path: '/provider/openai/oauth/callback'),
      statusCode: 400,
    ),
  ),
);

Future<ConnectionController> _controller(_Repository repository) async {
  SharedPreferences.setMockInitialValues({});
  final store = ProfileStore(prefs: await SharedPreferences.getInstance());
  final profile = ServerProfile(
    id: 'auth-test',
    name: 'Test',
    baseUrl: 'https://auth-test.example',
    username: 'opencode',
    password: 'synthetic-server-password',
  );
  await store.upsert(profile);
  final api = _Api();
  final controller = ConnectionController(
    store,
    apiFactory: (_) => api,
    repositoryFactory: (_) => repository,
    eventStreamFactory:
        ({required api, required onEvent, required onStatus, onError}) =>
            _Events(
              api: api,
              onEvent: onEvent,
              onStatus: onStatus,
              onError: onError,
            ),
  );
  addTearDown(controller.dispose);
  await controller.connect(profile, redetectOnFailure: false);
  return controller;
}

Widget _screen(
  ConnectionController controller, {
  Future<bool> Function(Uri)? launcher,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: IntegrationsScreen(
    controller: controller,
    mode: IntegrationsMode.providers,
    authorizationLauncher: launcher ?? (_) async => true,
  ),
);

/// Taps the provider, then Open browser and the external-link question.
Future<void> _openBrowser(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('connect-provider-openai')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open browser'));
  await tester.pumpAndSettle();
  if (find.text('Open link').evaluate().isNotEmpty) {
    await tester.tap(find.text('Open link'));
    await tester.pumpAndSettle();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final clipboard = <String>[];
  setUp(() {
    integrationAutoWaitPause = Duration.zero;
    clipboard.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(storage, (_) async => null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    ProviderLogo.logoLoaderOverride = (_) => null;
  });
  tearDown(() {
    integrationAutoWaitPause = const Duration(seconds: 3);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(storage, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    ProviderLogo.logoLoaderOverride = null;
  });

  test('a device code is taken from the instructions, prose is not', () {
    expect(providerDeviceCode('Enter code: VPFI-KC2ZK'), 'VPFI-KC2ZK');
    expect(providerDeviceCode('Enter code: ABCD-EFGH'), 'ABCD-EFGH');
    expect(
      providerDeviceCode('Open the page and enter code: 1234-ABCD there.'),
      '1234-ABCD',
    );
    expect(
      providerDeviceCode('Complete authorization in your browser.'),
      isNull,
    );
    expect(providerDeviceCode('Enter the code from the page'), isNull);
    expect(providerDeviceCode('Paste the code: below'), isNull);
    expect(providerInstructionsWithoutCode('Enter code: VPFI-KC2ZK'), '');
    expect(
      providerInstructionsWithoutCode('Go to the page. Enter code: AB12-CD34'),
      'Go to the page',
    );
  });

  testWidgets(
    'the sheet shows the code with Copy, Open browser copies it too',
    (tester) async {
      final repository = _Repository()
        ..gate = Completer<IntegrationAuthStatus>();
      final controller = await _controller(repository);
      await tester.pumpWidget(_screen(controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('connect-provider-openai')));
      await tester.pumpAndSettle();
      final sheet = find.byKey(const ValueKey('authorization-launch-sheet'));
      expect(
        find.descendant(of: sheet, matching: find.text('VPFI-KC2ZK')),
        findsOneWidget,
      );
      // The code is its own element: no "The server says" echo of it.
      expect(find.textContaining('The server says'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('kit-one-time-code-copy')));
      await tester.pump();
      expect(clipboard, ['VPFI-KC2ZK']);

      clipboard.clear();
      await tester.tap(find.text('Open browser'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open link'));
      await tester.pumpAndSettle();
      expect(clipboard, ['VPFI-KC2ZK']);
      expect(find.text('Code copied'), findsOneWidget);
      // A confirmation, not a banner: it clears itself.
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Code copied'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('instructions without a code show no copy control', (
    tester,
  ) async {
    final repository = _Repository()
      ..instructions = 'Complete authorization in your browser.'
      ..gate = Completer<IntegrationAuthStatus>();
    final controller = await _controller(repository);
    await tester.pumpWidget(_screen(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('connect-provider-openai')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kit-one-time-code')), findsNothing);
    expect(find.byKey(const ValueKey('kit-one-time-code-copy')), findsNothing);
    expect(
      find.textContaining('Complete authorization in your browser.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Open browser'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open link'));
    await tester.pumpAndSettle();
    expect(clipboard, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('an automatic sign-in finishes by itself, with no Finish tap', (
    tester,
  ) async {
    final repository = _Repository()..gate = Completer<IntegrationAuthStatus>();
    final controller = await _controller(repository);
    await tester.pumpWidget(_screen(controller));
    await tester.pumpAndSettle();
    await _openBrowser(tester);

    // The app is already holding the check open, and says what it waits on.
    expect(repository.statusCalls, 1);
    expect(
      find.text('Waiting for approval in the browser', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Sign-in waiting', findRichText: true), findsNothing);

    // The person approves in the browser; the server's check resolves.
    repository.gate!.complete(
      const IntegrationAuthStatus(state: IntegrationAuthState.complete),
    );
    await tester.pumpAndSettle();
    expect(repository.statusCalls, 1, reason: 'one held check, no taps');
    expect(controller.pendingIntegrationAuth, isEmpty);
    expect(find.text('OpenAI is connected'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('the waiting row offers Copy code and Open browser again', (
    tester,
  ) async {
    final repository = _Repository()..gate = Completer<IntegrationAuthStatus>();
    final controller = await _controller(repository);
    var launches = 0;
    await tester.pumpWidget(
      _screen(
        controller,
        launcher: (_) async {
          launches++;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _openBrowser(tester);
    expect(launches, 1);
    await tester.tap(find.byKey(const ValueKey('pending-auth-openai')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pending-auth-open-browser')), findsOne);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('sign-in-sheet')),
        matching: find.text('VPFI-KC2ZK'),
      ),
      findsOneWidget,
    );
    clipboard.clear();
    await tester.tap(find.byKey(const ValueKey('pending-auth-open-browser')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open link'));
    await tester.pumpAndSettle();
    expect(launches, 2);
    expect(clipboard, ['VPFI-KC2ZK']);
    expect(repository.statusCalls, 1, reason: 'still the same held check');
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'a restored sign-in the server no longer has ends, with Start again',
    (tester) async {
      final repository = _Repository()..statusError = _serverRefused;
      final controller = await _controller(repository);
      // A sign-in saved by an earlier run of the app.
      await controller.startRecoverableIntegrationOAuth(
        'openai',
        '0',
        locationRevision: controller.locationRevision,
      );
      expect(repository.starts, 1);
      await tester.pumpWidget(_screen(controller));
      await tester.pumpAndSettle();

      expect(repository.statusCalls, 1, reason: 'the screen re-attached');
      expect(find.text('Sign-in ended', findRichText: true), findsOneWidget);
      // Never red: a neutral logo, no failed mark, secondary words.
      final row = find.byKey(const ValueKey('pending-auth-openai'));
      expect(
        find.descendant(of: row, matching: find.byType(KitTaskMark)),
        findsNothing,
      );
      expect(
        find.descendant(of: row, matching: find.byType(ProviderLogo)),
        findsOneWidget,
      );
      final word = tester.widget<RichText>(
        find.descendant(
          of: row,
          matching: find.textContaining('Sign-in ended', findRichText: true),
        ),
      );
      final span = (word.text as TextSpan).children!
          .whereType<TextSpan>()
          .first;
      final danger = KitTokens.of(tester.element(row)).roles.danger;
      expect(span.style?.color, isNot(danger));
      expect(find.text('Sign-in waiting', findRichText: true), findsNothing);
      expect(
        find.text('Waiting for approval in the browser', findRichText: true),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('pending-auth-openai')));
      await tester.pumpAndSettle();
      expect(find.text('Start again'), findsOneWidget);
      expect(find.textContaining('Nothing was added'), findsOneWidget);

      // Start again asks the server for a new code.
      repository.statusError = null;
      repository.gate = Completer<IntegrationAuthStatus>();
      await tester.tap(find.byKey(const ValueKey('pending-auth-restart')));
      await tester.pumpAndSettle();
      expect(repository.starts, 2);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('authorization-launch-sheet')),
          matching: find.text('VPFI-KC2ZK'),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'a check that never gets an answer is retried, then the sign-in ends',
    (tester) async {
      final repository = _Repository()
        ..statusError = const ProductException('cut');
      final controller = await _controller(repository);
      await controller.startRecoverableIntegrationOAuth(
        'openai',
        '0',
        locationRevision: controller.locationRevision,
      );
      await tester.pumpWidget(_screen(controller));
      await tester.pumpAndSettle();
      expect(repository.statusCalls, 4, reason: 'one try and three retries');
      expect(find.text('Sign-in ended', findRichText: true), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('Cancel on the code sheet cancels the attempt and clears the '
      'row', (tester) async {
    final repository = _Repository()..gate = Completer<IntegrationAuthStatus>();
    final controller = await _controller(repository);
    await tester.pumpWidget(_screen(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('connect-provider-openai')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.cancels, ['attempt-1']);
    expect(controller.pendingIntegrationAuth, isEmpty);
    expect(find.byKey(const ValueKey('pending-auth-openai')), findsNothing);
    expect(find.text('Sign-in waiting', findRichText: true), findsNothing);
    expect(find.byKey(const ValueKey('connect-provider-openai')), findsOne);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('cancelling a waiting sign-in never says it expired', (
    tester,
  ) async {
    final repository = _Repository()..gate = Completer<IntegrationAuthStatus>();
    final controller = await _controller(repository);
    await tester.pumpWidget(_screen(controller));
    await tester.pumpAndSettle();
    await _openBrowser(tester);
    await tester.tap(find.byKey(const ValueKey('pending-auth-openai')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pending-auth-cancel')));
    await tester.pumpAndSettle();
    // The held check ends with the attempt gone, as the server answers it.
    repository.gate!.complete(
      const IntegrationAuthStatus(state: IntegrationAuthState.expired),
    );
    await tester.pumpAndSettle();
    expect(repository.cancels, ['attempt-1']);
    expect(find.byKey(const ValueKey('pending-auth-openai')), findsNothing);
    expect(find.textContaining('expired', findRichText: true), findsNothing);
    expect(find.text('Sign-in ended', findRichText: true), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('a provider with a key and two sign-ins is described whole', (
    tester,
  ) async {
    await loadCaptureFonts();
    tester.view.physicalSize = const Size(360, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _Repository()
      ..extraMethods = const [
        IntegrationMethodInfo(type: 'api', id: '1', label: 'Add an API key'),
        IntegrationMethodInfo(
          type: 'oauth',
          id: '2',
          label: 'ChatGPT Pro/Plus (browser)',
        ),
      ];
    final controller = await _controller(repository);
    await tester.pumpWidget(_screen(controller));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('connect-provider-openai'));
    final text = find.descendant(
      of: row,
      matching: find.textContaining('headless', findRichText: true),
    );
    expect(text, findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
