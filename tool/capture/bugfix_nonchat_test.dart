// Before/after captures for slice-bugfix-nonchat (2026-09-28): the pages
// whose look changed with a product fix, on a phone and a wide window, dark
// theme, real fonts, fakes only (no server).
//
//   flutter test --concurrency=1 --dart-define=BUGFIX_CAPTURE=before \
//     tool/capture/bugfix_nonchat_test.dart      # on the base commit
//   flutter test --concurrency=1 tool/capture/bugfix_nonchat_test.dart
//
// Output: docs/qa/slice-bugfix-nonchat-2026-09-28/<before|after>-<page>.png
//
// Same as the sibling capture files (capture_test, isolated_task_test):
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart'
    show IntegrationInfo, McpResourceInfo, McpServerInfo;
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/library_screen.dart';
import 'package:opencode_mobile/ui/screens/session_context_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

const _prefix = String.fromEnvironment('BUGFIX_CAPTURE', defaultValue: 'after');
const _out = 'docs/qa/slice-bugfix-nonchat-2026-09-28';

/// Every section of the integrations page fails to load.
class _FailingRepository extends CaptureRepository {
  @override
  Future<List<McpServerInfo>> listMcpServers() async =>
      throw StateError('mcp down');

  @override
  Future<List<McpResourceInfo>> listMcpResources() async =>
      throw StateError('resources down');

  @override
  Future<List<IntegrationInfo>> listIntegrations() async =>
      throw StateError('providers down');
}

MessageWithParts _message(
  String id,
  String role,
  String text, {
  Tokens? tokens,
  double cost = 0,
}) => MessageWithParts(
  info: MessageInfo(
    id: id,
    sessionID: checkoutSessionID,
    role: role,
    providerID: role == 'assistant' ? 'openai' : null,
    // Not in the catalog: the context limit is unknown.
    modelID: role == 'assistant' ? 'gpt-context' : null,
    tokens: tokens,
    cost: cost,
    time: MsgTime(created: 1, completed: 2),
  ),
  parts: [Part(type: 'text', text: text)],
);

Future<void> _shoot(
  WidgetTester tester,
  String name,
  Size size,
  Widget Function(CaptureController controller) home, {
  CaptureApi? api,
  CaptureRepository? repository,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final controller = await captureController(
    prefs: prefs,
    api: api,
    repository: repository,
  );
  addTearDown(controller.dispose);
  final key = GlobalKey();
  await tester.pumpWidget(
    captureApp(
      home: home(controller),
      boundaryKey: key,
      controller: controller,
    ),
  );
  await tester.pumpAndSettle();
  await writePng(
    '$_out/$_prefix-$name-${size.width.toInt()}x${size.height.toInt()}.png',
    await capturePng(tester, key, pixelRatio: 1),
  );
  await tester.pumpWidget(const SizedBox());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final size in const [Size(412, 915), Size(1280, 800)]) {
    testWidgets('integrations, every section failed $size', (tester) async {
      await _shoot(
        tester,
        'integrations-all-failed',
        size,
        (controller) => IntegrationsScreen(controller: controller),
        repository: _FailingRepository(),
      );
    });

    testWidgets('conversation context with an unknown limit $size', (
      tester,
    ) async {
      final messages = [
        _message('u1', 'user', 'Inspect context'),
        _message(
          'a1',
          'assistant',
          'Context ready',
          tokens: Tokens(input: 700, output: 40, cacheRead: 260),
          cost: .031,
        ),
      ];
      await _shoot(
        tester,
        'context-unknown-limit',
        size,
        (controller) => SessionContextScreen(
          controller: controller,
          sessionID: checkoutSessionID,
          initialMessages: messages,
        ),
        api: CaptureApi()..messagesHandler = (_) async => messages,
      );
    });
  }

  // A phone on its side: the loading diff in a 412dp-high room.
  testWidgets('diff loading in short landscape', (tester) async {
    const size = Size(915, 412);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    // Overflow stripes are part of the before picture, not a failure here.
    final previous = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = previous);
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: captureTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const KitScreen(
            topBar: KitTopBar(title: 'Changes'),
            body: KitDiffView(files: [], loading: true),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    FlutterError.onError = previous;
    await writePng(
      '$_out/$_prefix-diff-loading-915x412.png',
      await capturePng(tester, key, pixelRatio: 1),
    );
  });
}
