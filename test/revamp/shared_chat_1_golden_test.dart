// Golden renders of shared-chat-1's pages (wave 2a), rebuilt from kit parts:
// the model sheet (loaded, details and agent unfolded, no models, catalog
// failed), Continue on computer (command, unavailable), Open on another
// phone (QR) and the transcript display toggles. Phone 412x915 and one wide
// window (1280x800), dark and light (owner decision 2026-09-27: no Arabic),
// with the app's real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/shared_chat_1_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/domain/session_handoff.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit_sheet.dart';
import 'package:opencode_mobile/ui/widgets/pickers.dart';
import 'package:opencode_mobile/ui/widgets/session_handoff_sheets.dart';
import 'package:opencode_mobile/ui/widgets/transcript_display_toggles.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

String _name(String shot, Size size, bool light) => [
  shot,
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

const _catalogModels = [
  CatalogModel(
    id: 'claude-opus-5-5',
    providerID: 'anthropic',
    name: 'Claude Opus 5.5',
    enabled: true,
    status: 'active',
    contextLimit: 1000000,
    outputLimit: 128000,
    reasoning: true,
    attachments: true,
    tools: true,
    variants: [
      CatalogVariant(id: 'high'),
      CatalogVariant(id: 'max'),
    ],
    cost: ModelCost(inputPerMillion: 5, outputPerMillion: 25),
  ),
  CatalogModel(
    id: 'claude-sonnet-5',
    providerID: 'anthropic',
    name: 'Claude Sonnet 5',
    enabled: true,
    status: 'active',
    contextLimit: 1000000,
    outputLimit: 64000,
    reasoning: true,
    attachments: true,
    tools: true,
    variants: [],
  ),
  CatalogModel(
    id: 'gpt-6-sol',
    providerID: 'openai',
    name: 'GPT-6 Sol',
    enabled: true,
    status: 'active',
    contextLimit: 400000,
    outputLimit: 128000,
    reasoning: true,
    attachments: true,
    tools: true,
    variants: [],
  ),
  CatalogModel(
    id: 'gemini-3-pro',
    providerID: 'google',
    name: 'Gemini 3 Pro',
    enabled: true,
    status: 'active',
    contextLimit: 2000000,
    outputLimit: 64000,
    reasoning: true,
    attachments: true,
    tools: true,
    variants: [],
  ),
  CatalogModel(
    id: 'legacy-2',
    providerID: 'openai',
    name: 'Legacy 2',
    enabled: false,
    status: 'active',
    contextLimit: 128000,
    outputLimit: 16000,
    reasoning: false,
    attachments: false,
    tools: true,
    variants: [],
  ),
];

Future<ConnectionController> _controller({
  List<CatalogModel> models = _catalogModels,
  bool failed = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final controller = ConnectionController(ProfileStore(prefs: prefs))
    ..catalogDetailed = true
    ..selectedAgent = 'build'
    ..selectedModel = ModelRef(
      providerID: 'anthropic',
      modelID: 'claude-opus-5-5',
    );
  if (failed) {
    controller.catalogError = 'Server answered 503 Service Unavailable';
  } else {
    controller.catalog = CatalogSnapshot(
      providers: const [
        CatalogProvider(id: 'anthropic', name: 'Anthropic', enabled: true),
        CatalogProvider(id: 'openai', name: 'OpenAI', enabled: true),
        CatalogProvider(id: 'google', name: 'Google', enabled: true),
      ],
      models: models,
      agents: const [
        CatalogAgent(id: 'build', mode: 'primary', hidden: false),
        CatalogAgent(id: 'plan', mode: 'primary', hidden: false),
      ],
    );
  }
  return controller;
}

/// Pumps a host whose one button opens [open], taps it and captures.
Future<void> _shot(
  WidgetTester tester,
  String shot, {
  required bool light,
  required Future<void> Function(BuildContext context) open,
  ConnectionController? controller,
  Size size = _phone,
  Future<void> Function()? then,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  final conn = controller ?? await _controller();
  addTearDown(conn.dispose);
  try {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [connProvider.overrideWithValue(conn)],
        child: RepaintBoundary(
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
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => open(context),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    if (then != null) {
      await then();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/${_name(shot, size, light)}.png'),
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
  }
}

final _command = SessionResumeCommand.build(
  cli: SessionResumeCli.openCode2,
  sessionID: 'ses_0123456789abcdef',
  directory: '/home/dev/My Projects/acme',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final size in [_phone, _wide]) {
      testWidgets('model sheet loaded ${size.width.toInt()} · $mode', (
        tester,
      ) async {
        await _shot(
          tester,
          'chat_model_picker_sheet_loaded',
          light: light,
          size: size,
          open: (context) => showModelPicker(context),
        );
      });

      testWidgets('continue on computer ${size.width.toInt()} · $mode', (
        tester,
      ) async {
        await _shot(
          tester,
          'chat_continue_on_computer_sheet_available',
          light: light,
          size: size,
          open: (context) => showContinueOnComputerSheet(
            context,
            command: _command,
            exportAvailable: true,
          ),
        );
      });

      testWidgets('continue on phone ${size.width.toInt()} · $mode', (
        tester,
      ) async {
        await _shot(
          tester,
          'chat_continue_on_phone_sheet_qr',
          light: light,
          size: size,
          open: (context) => showContinueOnPhoneSheet(
            context,
            link: SessionLink.tryCreate(
              profileID: '1757500000000000',
              sessionID: 'ses_0123456789abcdef',
            ),
          ),
        );
      });
    }

    testWidgets('model sheet details and agent · $mode', (tester) async {
      await _shot(
        tester,
        'chat_model_picker_sheet_details',
        light: light,
        open: (context) => showModelPicker(context, focusAgent: true),
        then: () async {
          await tester.tap(find.byKey(const Key('model-picker-options')));
        },
      );
    });

    testWidgets('model sheet no models · $mode', (tester) async {
      await _shot(
        tester,
        'chat_model_picker_sheet_no_models',
        light: light,
        controller: await _controller(models: const []),
        open: (context) => showModelPicker(context),
      );
    });

    testWidgets('model sheet catalog failed · $mode', (tester) async {
      await _shot(
        tester,
        'chat_model_picker_sheet_failed',
        light: light,
        controller: await _controller(failed: true),
        open: (context) => showModelPicker(context),
      );
    });

    testWidgets('continue on computer unavailable · $mode', (tester) async {
      await _shot(
        tester,
        'chat_continue_on_computer_sheet_unavailable',
        light: light,
        open: (context) => showContinueOnComputerSheet(
          context,
          command: SessionResumeCommand.build(
            cli: SessionResumeCli.openCode2,
            sessionID: 'ses_1',
            directory: null,
          ),
          exportAvailable: true,
          offerReload: true,
        ),
      );
    });

    testWidgets('transcript display toggles · $mode', (tester) async {
      await _shot(
        tester,
        'chat_transcript_display_toggles_default',
        light: light,
        open: (context) => showKitSheet<void>(
          context,
          title: AppLocalizations.of(context).chatUiTranscriptDisplay,
          body: (context) => const TranscriptDisplayToggles(
            reasoningExpanded: true,
            timestampsVisible: false,
          ),
        ),
      );
    });
  }
}
