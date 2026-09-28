// The model picker keeps its search results in view above the keyboard.
//
// Regenerate deliberately, and look at every changed image before committing it:
//   flutter test --update-goldens --dart-define=CAPTURE_EVIDENCE=true \
//     test/picker_search_keyboard_test.dart --plain-name "evidence"

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
const _shot = String.fromEnvironment('SHOT', defaultValue: 'after');

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorage = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorage, (_) async => null);
  });
  setUpAll(() => ProviderLogo.imageProviderOverride = (_) => null);
  tearDownAll(() => ProviderLogo.imageProviderOverride = null);

  testWidgets('search with the keyboard up keeps its results in view', (
    tester,
  ) async {
    await loadCaptureFonts();
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final catalog = CatalogSnapshot(
      providers: const [
        CatalogProvider(id: 'opencode', name: 'OpenCode Zen', enabled: true),
      ],
      models: [
        for (final n in ['Big Pickle', 'Pickle Mini', 'Other', 'Another'])
          _model('opencode', n.toLowerCase().replaceAll(' ', '-'), n),
      ],
      agents: const [],
    );
    final controller = await _controller(_Repository(), catalog);
    addTearDown(controller.dispose);
    await _open(tester, controller);
    // The keyboard opens under the sheet.
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('model-picker-search'));
    await tester.tap(field);
    await tester.enterText(field, 'pickle');
    await tester.pumpAndSettle();

    const keyboardTop = 915.0 - 320;
    for (final name in ['Big Pickle', 'Pickle Mini']) {
      final row = find.text(name);
      expect(row, findsOneWidget);
      final rect = tester.getRect(row);
      final viewport = tester.getRect(
        find.ancestor(of: row, matching: find.byType(Scrollable)).first,
      );
      expect(rect.top, greaterThanOrEqualTo(viewport.top), reason: name);
      expect(rect.bottom, lessThanOrEqualTo(viewport.bottom), reason: name);
      expect(rect.bottom, lessThan(keyboardTop), reason: name);
    }
    // The room the results have is more than a sliver.
    final list = tester.getRect(find.byKey(const Key('model-picker-list')));
    expect(list.height, greaterThan(100));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'evidence',
    variant: TargetPlatformVariant.only(TargetPlatform.android),
    (tester) async {
      // ARCH-11
      if (!_evidence) return;
      await loadCaptureFonts();
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final catalog = CatalogSnapshot(
        providers: const [
          CatalogProvider(id: 'opencode', name: 'OpenCode Zen', enabled: true),
        ],
        models: [
          for (final n in ['Big Pickle', 'Pickle Mini', 'Other', 'Another'])
            _model('opencode', n.toLowerCase().replaceAll(' ', '-'), n),
        ],
        agents: const [],
      );
      final controller = await _controller(_Repository(), catalog);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        RepaintBoundary(key: const Key('shot'), child: _app(controller)),
      );
      await tester.tap(find.text('Choose model'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('model-picker-search'));
      await tester.tap(field);
      await tester.enterText(field, 'pickle');
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('shot')),
        matchesGoldenFile(
          '../docs/qa/slice-chat-input-bugs-2026-09-29/picker-search-$_shot.png',
        ),
      );
    },
  );
}
