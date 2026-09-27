// Behaviour of shared-chat-1 (wave 2a): the model sheet, the two handoff
// sheets and the transcript display toggles, rebuilt from kit parts. The
// agent and thinking level sit in the sheet's pinned footer and model
// details under the chosen row (no dialogs on the sheet, P3.3), the
// unloaded providers are a Reload row, and the handoff sheet offers Reload
// where reloading helps.
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
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_code_block.dart';
import 'package:opencode_mobile/ui/kit/kit_row_parts.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/widgets/pickers.dart';
import 'package:opencode_mobile/ui/widgets/session_handoff_sheets.dart';
import 'package:opencode_mobile/ui/widgets/transcript_display_toggles.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _models = [
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
      CatalogVariant(id: 'high', disabled: false),
      CatalogVariant(id: 'max', disabled: false),
    ],
    cost: ModelCost(inputPerMillion: 5, outputPerMillion: 25),
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
];

Future<ConnectionController> _controller({
  List<CatalogModel> models = _models,
  bool detailed = true,
  Set<String> unloaded = const {},
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ConnectionController(ProfileStore(prefs: prefs))
    ..catalogDetailed = detailed
    ..unloadedProviderIDs = unloaded
    ..catalog = CatalogSnapshot(
      providers: const [
        CatalogProvider(id: 'anthropic', name: 'Anthropic', enabled: true),
        CatalogProvider(id: 'openai', name: 'OpenAI', enabled: true),
      ],
      models: models,
      agents: const [
        CatalogAgent(id: 'build', mode: 'primary', hidden: false),
        CatalogAgent(id: 'plan', mode: 'primary', hidden: false),
        CatalogAgent(id: 'explore', mode: 'subagent', hidden: false),
      ],
    )
    ..selectedAgent = 'build'
    ..selectedModel = ModelRef(
      providerID: 'anthropic',
      modelID: 'claude-opus-5-5',
    );
}

Widget _host(ConnectionController controller, {Widget? home}) => ProviderScope(
  overrides: [connProvider.overrideWithValue(controller)],
  child: MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home:
        home ??
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showModelPicker(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
  ),
);

Future<void> _open(WidgetTester tester, ConnectionController controller) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(controller));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  group('model sheet', () {
    testWidgets('opens as one kit sheet with the choice in its footer', (
      tester,
    ) async {
      final controller = await _controller();
      await _open(tester, controller);
      expect(find.text('Choose a model'), findsOneWidget);
      expect(find.text('Thinking: Default'), findsOneWidget);
      expect(find.text('Agent: Build'), findsOneWidget);
      // No dialog is ever stacked on the sheet.
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      // The primary names what it applies; the chosen model is shown once,
      // as the checked row.
      expect(find.text('Use Claude Opus 5.5 · Build'), findsOneWidget);
      expect(find.text('Claude Opus 5.5'), findsOneWidget);
      expect(find.byKey(const Key('model-picker-options')), findsNothing);
      // No count label over the list; Refresh sits in the filter row.
      expect(find.textContaining(RegExp(r'^\d+ models?$')), findsNothing);
      expect(find.byKey(const Key('model-picker-refresh')), findsOneWidget);
    });

    testWidgets('picking a model and applying saves it and closes', (
      tester,
    ) async {
      final controller = await _controller();
      await _open(tester, controller);
      final row = find.byKey(const ValueKey('model-option-openai-gpt-6-sol'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      // The primary now names the chosen model.
      expect(find.textContaining('Use GPT-6 Sol'), findsOneWidget);
      await tester.tap(find.byKey(const Key('model-picker-apply')));
      await tester.pumpAndSettle();
      expect(controller.selectedModel?.wireName, 'openai/gpt-6-sol');
      expect(find.text('Choose a model'), findsNothing);
    });

    testWidgets('the agent is chosen in the sheet, in words', (tester) async {
      final controller = await _controller();
      await _open(tester, controller);
      await tester.tap(find.byKey(const Key('model-picker-agent')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Edits files and runs commands',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Reads and plans; does not change files',
          findRichText: true,
        ),
        findsOneWidget,
      );
      // Subagents are not a session's agent.
      expect(find.text('Explore'), findsNothing);
      final plan = find.byKey(const ValueKey('model-picker-agent-plan'));
      await tester.ensureVisible(plan);
      await tester.pumpAndSettle();
      await tester.tap(plan);
      await tester.pumpAndSettle();
      // Staged until applied.
      expect(controller.selectedAgent, 'build');
      await tester.tap(find.byKey(const Key('model-picker-apply')));
      await tester.pumpAndSettle();
      expect(controller.selectedAgent, 'plan');
    });

    testWidgets('focusAgent opens with the agent menu open', (tester) async {
      final controller = await _controller();
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          controller,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showModelPicker(context, focusAgent: true),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Edits files and runs commands',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('details and thinking unfold in place', (tester) async {
      final controller = await _controller();
      await _open(tester, controller);
      // The chosen row carries its details; its context is already on its
      // supporting line, so it is not said again in words.
      final details = find.byKey(const Key('model-picker-details'));
      expect(details, findsOneWidget);
      final text = tester.widget<KitText>(details).text;
      expect(text, contains('Thinks before answering'));
      expect(
        text,
        contains(r'$5.00 per million tokens read, $25.00 per million written'),
      );
      expect(find.text('1,000,000 tokens of context'), findsNothing);

      await tester.tap(find.byKey(const Key('model-picker-thinking')));
      await tester.pumpAndSettle();
      final max = find.byKey(
        const ValueKey('model-variant-claude-opus-5-5-max'),
      );
      await tester.ensureVisible(max);
      await tester.pumpAndSettle();
      await tester.tap(max);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('model-picker-apply')));
      await tester.pumpAndSettle();
      expect(controller.selectedVariant, 'max');
    });

    testWidgets('a model without levels offers no thinking control', (
      tester,
    ) async {
      final controller = await _controller()
        ..selectedModel = ModelRef(providerID: 'openai', modelID: 'gpt-6-sol');
      await _open(tester, controller);
      expect(find.byKey(const Key('model-picker-thinking')), findsNothing);
      expect(find.text('Agent: Build'), findsOneWidget);
    });

    testWidgets('unloaded providers are a Reload row in the sheet', (
      tester,
    ) async {
      final controller = await _controller(unloaded: {'ollama'});
      await _open(tester, controller);
      expect(
        find.byKey(const ValueKey('picker-reload-providers')),
        findsOneWidget,
      );
      expect(
        find.textContaining('has not loaded it yet', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Reload providers'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets(
      'the basic-catalog notice shows only when details are missing',
      (tester) async {
        final withDetails = await _controller(detailed: false);
        await _open(tester, withDetails);
        expect(
          find.byKey(const Key('model-picker-basic-catalog')),
          findsNothing,
        );

        final bare = await _controller(
          detailed: false,
          models: const [
            CatalogModel(
              id: 'bare',
              providerID: 'openai',
              name: 'Bare',
              enabled: true,
              status: 'active',
              contextLimit: 0,
              outputLimit: 0,
              reasoning: false,
              attachments: false,
              tools: false,
              variants: [],
            ),
          ],
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await _open(tester, bare);
        expect(
          find.byKey(const Key('model-picker-basic-catalog')),
          findsOneWidget,
        );
      },
    );

    testWidgets('no models leads to signing in to a provider', (tester) async {
      final controller = await _controller(models: const []);
      await _open(tester, controller);
      expect(find.text('Sign in to a provider'), findsOneWidget);
      expect(find.text('Open providers'), findsOneWidget);
    });

    testWidgets('a long catalog grows on request', (tester) async {
      final many = [
        for (var i = 0; i < 70; i++)
          CatalogModel(
            id: 'm$i',
            providerID: 'openai',
            name: 'Model ${i.toString().padLeft(2, '0')}',
            enabled: true,
            status: 'active',
            contextLimit: 1000,
            outputLimit: 100,
            reasoning: false,
            attachments: false,
            tools: false,
            variants: const [],
          ),
      ];
      final controller = await _controller(models: many)
        ..selectedModel = ModelRef(providerID: 'openai', modelID: 'm0');
      await _open(tester, controller);
      final more = find.byKey(const Key('model-picker-more'));
      await tester.scrollUntilVisible(
        more,
        400,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Show 10 more models'), findsOneWidget);
      // Clear of the pinned primary before tapping.
      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(more, findsNothing);
    });
  });

  group('handoff sheets', () {
    Future<List<String?>> openComputer(
      WidgetTester tester,
      SessionResumeCommand command, {
      bool offerReload = false,
    }) async {
      final popped = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => popped.add(
                  await showContinueOnComputerSheet(
                    context,
                    command: command,
                    offerReload: offerReload,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return popped;
    }

    testWidgets('a missing folder offers Reload, which the host acts on', (
      tester,
    ) async {
      final popped = await openComputer(
        tester,
        SessionResumeCommand.build(
          cli: SessionResumeCli.openCode2,
          sessionID: 'ses_1',
          directory: null,
        ),
        offerReload: true,
      );
      await tester.tap(find.byKey(const Key('continue-on-computer-reload')));
      await tester.pumpAndSettle();
      expect(popped, ['reload']);
    });

    testWidgets(
      'a cloud environment is not offered a Reload that cannot help',
      (tester) async {
        await openComputer(
          tester,
          SessionResumeCommand.build(
            cli: SessionResumeCli.openCode2,
            sessionID: 'ses_ws',
            directory: '/workspace/acme',
            workspaceID: 'wrk_1',
          ),
          offerReload: true,
        );
        expect(
          find.byKey(const Key('continue-on-computer-unavailable')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('continue-on-computer-reload')),
          findsNothing,
        );
      },
    );

    testWidgets('the command wraps whole; the version note waits under '
        'Details; Export is not repeated here', (tester) async {
      await openComputer(
        tester,
        SessionResumeCommand.build(
          cli: SessionResumeCli.openCode2,
          sessionID: 'ses_0123456789abcdef',
          directory: '/home/dev/My Projects/acme',
        ),
      );
      final block = tester.widget<KitCodeBlock>(
        find
            .ancestor(
              of: find.byKey(const Key('continue-on-computer-command')),
              matching: find.byType(KitCodeBlock),
            )
            .first,
      );
      expect(block.wrap, isTrue);
      expect(find.textContaining('Verified against'), findsNothing);
      expect(
        find.byKey(const Key('continue-on-computer-details')),
        findsOneWidget,
      );
      // Export lives in the conversation menu (one entry point).
      expect(
        find.byKey(const Key('continue-on-computer-export')),
        findsNothing,
      );
      expect(find.textContaining('Moving to a different server'), findsNothing);
    });
  });

  group('transcript display toggles', () {
    testWidgets('say what on does, flip in place, and name their scope', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: TranscriptDisplayToggles(
              reasoningExpanded: false,
              timestampsVisible: true,
            ),
          ),
        ),
      );
      const reasoningOn =
          "When on, the model's reasoning opens under each answer.";
      expect(find.text(reasoningOn), findsOneWidget);
      expect(
        find.text('These apply to every conversation on this device.'),
        findsOneWidget,
      );
      final reasoning = find.byKey(const ValueKey('session-view-thinking'));
      expect(tester.widget<KitSwitchRow>(reasoning).value, isFalse);
      await tester.tap(reasoning);
      await tester.pumpAndSettle();
      expect(tester.widget<KitSwitchRow>(reasoning).value, isTrue);
      // The supporting line does not flip with the switch.
      expect(find.text(reasoningOn), findsOneWidget);
      expect(
        tester
            .widget<KitSwitchRow>(
              find.byKey(const ValueKey('session-view-timestamps')),
            )
            .value,
        isTrue,
      );
    });
  });
}
