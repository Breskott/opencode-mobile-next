// Connecting a provider from the chat model picker: the end-of-list row,
// the per-provider key or sign-in actions, the free-model note, and the way
// back with the new provider's models.
//
// Regenerate deliberately, and look at every changed image before committing it:
//   flutter test --update-goldens --dart-define=CAPTURE_EVIDENCE=true \
//     test/picker_signin_test.dart --plain-name "evidence"

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/widgets/pickers.dart';
import 'package:opencode_mobile/ui/widgets/provider_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/capture/fixtures.dart' show loadCaptureFonts;

const _evidence = bool.fromEnvironment('CAPTURE_EVIDENCE');

class _Repository implements ProductRepository {
  List<IntegrationInfo> integrations = const [];
  final savedKeys = <String>[];
  int oauthCalls = 0;
  void Function(String id)? onKeySaved;

  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<List<IntegrationInfo>> listIntegrations() async => integrations;

  @override
  Future<void> connectIntegrationKey(
    String id,
    String key, {
    String? label,
  }) async {
    savedKeys.add(id);
    onKeySaved?.call(id);
  }

  @override
  Future<IntegrationAuthLaunch> startIntegrationOAuth(
    String id,
    String methodID, {
    Map<String, String> inputs = const {},
    String? label,
  }) async {
    oauthCalls++;
    return const IntegrationAuthLaunch(
      attemptID: 'attempt-1',
      url: 'https://provider-auth.example.com/authorize',
      instructions: '',
      mode: IntegrationAuthMode.auto,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Controller extends ConnectionController {
  _Controller(super.store);

  /// What the catalog becomes once a refresh runs after a key was saved.
  CatalogSnapshot? afterRefresh;
  int refreshCalls = 0;

  @override
  Future<void> refreshCatalog() async {
    refreshCalls++;
    final next = afterRefresh;
    if (next != null) {
      catalog = next;
      notifyListeners();
    }
  }
}

CatalogModel _model(String provider, String id, String name) => CatalogModel(
  id: id,
  providerID: provider,
  name: name,
  enabled: true,
  status: 'active',
  contextLimit: 131072,
  outputLimit: 16384,
  reasoning: false,
  attachments: false,
  tools: true,
  variants: const [],
);

const _freeProviders = [
  CatalogProvider(id: 'opencode', name: 'OpenCode Zen', enabled: true),
];

CatalogSnapshot _freeOnly() => CatalogSnapshot(
  providers: _freeProviders,
  models: [_model('opencode', 'big-pickle', 'Big Pickle')],
  agents: const [],
);

CatalogSnapshot _withAnthropic() => CatalogSnapshot(
  providers: const [
    ..._freeProviders,
    CatalogProvider(id: 'anthropic', name: 'Anthropic', enabled: true),
  ],
  models: [
    _model('opencode', 'big-pickle', 'Big Pickle'),
    _model('anthropic', 'claude-opus', 'Claude Opus'),
  ],
  agents: const [],
);

CatalogSnapshot _paidOnly() => CatalogSnapshot(
  providers: const [
    CatalogProvider(id: 'local', name: 'Local models', enabled: true),
  ],
  models: [_model('local', 'small-local', 'Small Local')],
  agents: const [],
);

const _keyMethod = IntegrationMethodInfo(type: 'key', label: 'API key');
const _browserMethod = IntegrationMethodInfo(
  type: 'oauth',
  id: 'oauth-1',
  label: 'Browser sign-in',
);

Future<_Controller> _controller(
  _Repository repository,
  CatalogSnapshot catalog,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = ProfileStore(prefs: prefs);
  await store.upsert(
    ServerProfile(
      id: 'picker-test',
      name: 'Test server',
      baseUrl: 'https://picker.example',
    ),
  );
  await store.setActiveId('picker-test');
  return _Controller(store)
    ..repository = repository
    ..status = StreamStatus.connected
    ..catalogDetailed = true
    ..catalog = catalog;
}

Widget _app(_Controller controller, {ThemeMode mode = ThemeMode.dark}) =>
    ProviderScope(
      overrides: [connProvider.overrideWithValue(controller)],
      child: MaterialApp(
        themeMode: mode,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showModelPicker(context),
                child: const Text('Choose model'),
              ),
            ),
          ),
        ),
      ),
    );

Future<void> _open(WidgetTester tester, _Controller controller) async {
  await tester.pumpWidget(_app(controller));
  await tester.tap(find.text('Choose model'));
  await tester.pumpAndSettle();
}

Finder _key(String k) => find.byKey(ValueKey(k));

/// Scrolls [target] to the middle of the sheet, clear of its pinned footer.
Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.pumpAndSettle();
  final context = tester.element(target);
  await Scrollable.ensureVisible(context, alignment: 0.3);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorage = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorage, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorage, null);
  });
  setUpAll(() => ProviderLogo.imageProviderOverride = (_) => null);
  tearDownAll(() => ProviderLogo.imageProviderOverride = null);

  final anthropic = IntegrationInfo(
    id: 'anthropic',
    name: 'Anthropic',
    methods: const [_browserMethod, _keyMethod],
    connectionCount: 0,
  );
  const cloud = IntegrationInfo(
    id: 'cloud',
    name: 'Cloud',
    methods: [_browserMethod],
    connectionCount: 0,
  );

  testWidgets('a connect row ends the list and opens Providers', (
    tester,
  ) async {
    final controller = await _controller(_Repository(), _paidOnly());
    addTearDown(controller.dispose);
    await _open(tester, controller);
    await _reveal(tester, _key('model-picker-connect-provider'));
    expect(find.text('Connect a provider'), findsOneWidget);
    // Not the free-only note: a paid provider is listed.
    expect(_key('model-picker-free-only'), findsNothing);
    await tester.tap(find.byKey(const Key('model-picker-connect-provider')));
    await tester.pumpAndSettle();
    expect(find.text('Providers'), findsWidgets);
    final before = controller.refreshCalls;
    await tester.pageBack();
    await tester.pumpAndSettle();
    // Back in the picker, with the catalog refreshed.
    expect(find.text('Choose a model'), findsOneWidget);
    expect(controller.refreshCalls, greaterThan(before));
  });

  testWidgets('per provider: an API key row, a sign-in row, none for '
      'providers that offer nothing', (tester) async {
    final repository = _Repository()
      ..integrations = [
        anthropic,
        const IntegrationInfo(
          id: 'google',
          name: 'Google',
          methods: [_browserMethod],
          connectionCount: 0,
        ),
        cloud,
        const IntegrationInfo(
          id: 'google-vertex',
          name: 'Vertex',
          methods: [],
          connectionCount: 0,
        ),
      ];
    final controller = await _controller(repository, _freeOnly());
    addTearDown(controller.dispose);
    await _open(tester, controller);
    await _reveal(tester, _key('picker-connect-anthropic'));
    expect(find.text('Add an API key for Anthropic'), findsOneWidget);
    // Google offers only a browser sign-in here: nothing invented.
    expect(find.text('Sign in to Google'), findsOneWidget);
    // Only key-led providers are listed unprompted.
    expect(_key('picker-connect-cloud'), findsNothing);
    expect(_key('picker-connect-google-vertex'), findsNothing);
  });

  testWidgets('a connected but unloaded provider offers its key too', (
    tester,
  ) async {
    final repository = _Repository()
      ..integrations = [
        IntegrationInfo(
          id: 'cloud',
          name: 'Cloud',
          methods: const [_keyMethod],
          connectionCount: 1,
        ),
      ];
    final controller = await _controller(repository, _paidOnly());
    addTearDown(controller.dispose);
    controller.unloadedProviderIDs = const {'cloud'};
    await _open(tester, controller);
    await _reveal(tester, _key('picker-connect-cloud'));
    expect(find.text('Add an API key for Cloud'), findsOneWidget);
    expect(
      find.textContaining('the server has not loaded it', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('the key flow from the picker returns with the models, and '
      'the typed key is never shown', (tester) async {
    final repository = _Repository()..integrations = [anthropic];
    final controller = await _controller(repository, _freeOnly());
    addTearDown(controller.dispose);
    repository.onKeySaved = (_) => controller.afterRefresh = _withAnthropic();
    await _open(tester, controller);
    expect(find.text('Claude Opus'), findsNothing);
    await _reveal(tester, _key('picker-connect-anthropic'));
    await tester.tap(_key('picker-connect-anthropic'));
    await tester.pumpAndSettle();

    // Straight into the key dialog for that provider.
    expect(_key('provider-key-field'), findsOneWidget);
    expect(find.text('Get a key from Anthropic'), findsOneWidget);
    await tester.tap(find.text('Get a key from Anthropic'));
    await tester.pumpAndSettle();
    expect(find.text('Open external link?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: _key('external-link-confirm'),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();
    expect(_key('provider-key-field'), findsOneWidget);

    await tester.enterText(_key('provider-key-field'), 'sk-typed-secret-999');
    await tester.pump();
    // The field is a secret one: obscured, never a visible label.
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: _key('provider-key-field'),
              matching: find.byType(EditableText),
            ),
          )
          .obscureText,
      isTrue,
    );
    await tester.tap(_key('confirm-provider-key'));
    await tester.pumpAndSettle();

    expect(repository.savedKeys, ['anthropic']);
    expect(repository.oauthCalls, 0);
    expect(find.textContaining('sk-typed-secret-999'), findsNothing);
    // Back in the picker: the provider's models are ready to pick, and the
    // free-only note is gone.
    expect(find.text('Choose a model'), findsOneWidget);
    expect(find.text('Claude Opus'), findsOneWidget);
    expect(
      find.text('Anthropic is ready. Its models are in the list.'),
      findsOneWidget,
    );
    expect(_key('model-picker-free-only'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a provider still busy reloading says the reload waits', (
    tester,
  ) async {
    final repository = _Repository()..integrations = [anthropic];
    final controller = await _controller(repository, _freeOnly());
    addTearDown(controller.dispose);
    repository.onKeySaved = (_) {
      controller
        ..unloadedProviderIDs = const {'anthropic'}
        ..providerReloadWaitingOn = 2;
    };
    await _open(tester, controller);
    await _reveal(tester, _key('picker-connect-anthropic'));
    await tester.tap(_key('picker-connect-anthropic'));
    await tester.pumpAndSettle();
    await tester.enterText(_key('provider-key-field'), 'sk-x');
    await tester.tap(_key('confirm-provider-key'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a model'), findsOneWidget);
    expect(
      find.textContaining('waits for 2 running replies', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('only the free model: a note at the top with both actions', (
    tester,
  ) async {
    final repository = _Repository()..integrations = [anthropic];
    final controller = await _controller(repository, _freeOnly());
    addTearDown(controller.dispose);
    await _open(tester, controller);
    expect(
      find.text("Only OpenCode's free model is available — it's slower."),
      findsOneWidget,
    );
    expect(find.text('Add an API key'), findsOneWidget);
    expect(_key('model-picker-free-connect'), findsOneWidget);
    // "Add an API key" goes to the key dialog of the first key provider.
    await tester.tap(_key('model-picker-free-add-key'));
    await tester.pumpAndSettle();
    expect(_key('provider-key-field'), findsOneWidget);
  });

  testWidgets('no models at all: the empty state and the connect row both '
      'lead to Providers', (tester) async {
    final controller = await _controller(
      _Repository(),
      const CatalogSnapshot(providers: [], models: [], agents: []),
    );
    addTearDown(controller.dispose);
    await _open(tester, controller);
    await tester.tap(_key('model-picker-open-providers'));
    await tester.pumpAndSettle();
    expect(find.text('Providers'), findsWidgets);
  });

  testWidgets(
    'evidence',
    variant: TargetPlatformVariant.only(TargetPlatform.android),
    (tester) async {
      // ARCH-11
      if (!_evidence) return;
      await loadCaptureFonts();
      final repository = _Repository()
        ..integrations = [
          anthropic,
          const IntegrationInfo(
            id: 'google',
            name: 'Google',
            methods: [_keyMethod],
            connectionCount: 0,
          ),
        ];
      for (final (name, size, mode) in [
        ('phone_dark', const Size(412, 915), ThemeMode.dark),
        ('wide_light', const Size(1280, 800), ThemeMode.light),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        final controller = await _controller(repository, _freeOnly());
        await tester.pumpWidget(
          RepaintBoundary(
            key: const Key('shot'),
            child: _app(controller, mode: mode),
          ),
        );
        await tester.tap(find.text('Choose model'));
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const Key('shot')),
          matchesGoldenFile('goldens/picker_signin_$name.png'),
        );
        controller.dispose();
      }
      addTearDown(tester.view.reset);
    },
  );
}
