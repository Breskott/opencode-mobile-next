// Actual widgets over local server-contract fixtures, not native execution proof.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';
import '../../test/support/setup_capture_preferences.dart';
import 'fixtures.dart';

final _parent = Session(
  id: checkoutSessionID,
  title: 'Refine the checkout',
  directory: projectDirectory,
);
final _child = Session(
  id: 'child-review',
  parentID: checkoutSessionID,
  title: 'Review keyboard behavior',
  directory: projectDirectory,
);
const _finalResult =
    'The keyboard review is ready. The draft stays visible and the task view preserves your work.';

class _TaskApi extends CaptureApi {
  bool returned = false;
  @override
  Future<Session> session(String id) async =>
      id == _child.id ? _child : _parent;
  @override
  Future<List<Session>> sessions() async => [_parent, _child];
  @override
  Future<Map<String, String>> sessionStatuses() async => {
    for (final session in [_parent, _child])
      session.id: busy.contains(session.id) ? 'busy' : 'idle',
  };
  @override
  Future<ServerPage<MessageWithParts>> messagePage(
    String id, {
    String? cursor,
    int limit = 100,
  }) async => ServerPage(
    items: [
      MessageWithParts(
        info: MessageInfo(id: 'answer-$id', sessionID: id, role: 'assistant'),
        parts: [
          Part(
            type: 'text',
            text: id == _child.id
                ? 'I’m reviewing how the keyboard affects the checkout draft.'
                : returned
                ? _finalResult
                : 'I’m delegating the keyboard review. You can keep working while the agent checks it.',
          ),
          if (id != _child.id && !returned)
            Part(
              type: 'tool',
              id: 'delegated-task',
              messageID: 'answer-$id',
              toolName: 'task',
              toolState: ToolState.fromJson({
                'status': busy.contains(_parent.id) ? 'running' : 'completed',
                'input': {
                  'description': 'Review keyboard behavior',
                  'subagent_type': 'explore',
                },
                'metadata': {'sessionID': _child.id},
                'output': 'Agent continues independently.',
              }, toolName: 'task'),
            ),
        ],
      ),
    ],
  );
}

class _TaskRepository extends CaptureRepository {
  _TaskRepository(this.api);
  final _TaskApi api;
  @override
  Future<List<Session>> listSessionChildren(String id) async =>
      id == _parent.id ? [_child] : [];
  @override
  Future<Session> getSessionDetails(String id) async =>
      id == _child.id ? _child : _parent;
  @override
  Future<ManagedShellList> loadRunningShells() async =>
      const ManagedShellList(supported: false);
  @override
  Future<BackgroundWorkSupport> loadBackgroundWorkSupport() async =>
      BackgroundWorkSupport.subagents;
  @override
  Future<BackgroundWorkResult> backgroundSession(String sessionID) async {
    api.busy = {_child.id};
    return BackgroundWorkResult.promoted;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  for (final scale in [1.0, 2.5]) {
    testWidgets('Server-backed Tasks journey at $scale text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _TaskApi()..busy = {_parent.id, _child.id};
      final controller = await captureController(
        prefs: await setupCapturePreferences(),
        api: api,
        repository: _TaskRepository(api),
      );
      controller.sessionsById = {_parent.id: _parent};
      controller.busySessions = {_parent.id, _child.id};
      addTearDown(controller.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: ProviderScope(
            overrides: [connProvider.overrideWithValue(controller)],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: captureTheme(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              onGenerateRoute: (settings) => MaterialPageRoute<void>(
                builder: (_) => ChatScreen(
                  sessionID: settings.name!.substring('/chat/'.length),
                ),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: const ChatScreen(sessionID: checkoutSessionID),
            ),
          ),
        ),
      );
      Future<void> frames() async {
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      Future<void> shot(String state) async {
        await frames();
        expect(tester.takeException(), isNull);
        await writePng(
          'docs/qa/chat-task-repair/${scale == 1 ? 'normal' : 'large'}-$state.png',
          await capturePng(tester, boundary),
        );
      }

      await frames();
      await tester.enterText(
        find.byKey(const Key('chat-composer-field')),
        'Keep the review concise.',
      );
      await shot('chat');
      expect(find.byTooltip('Stop'), findsOneWidget);
      await tester.tap(find.byKey(const Key('running-work-indicator')));
      await shot('tasks');
      await tester.ensureVisible(find.text('Run in background'));
      await tester.tap(find.text('Run in background'));
      await frames();
      await tester.ensureVisible(find.byKey(Key('work-agent-${_child.id}')));
      await shot('background');
      await tester.tap(find.byKey(Key('work-agent-${_child.id}')));
      await shot('child');
      // The server has delivered the final result into the parent's history.
      // The focused widget test separately covers live event reconciliation.
      api.returned = true;
      api.busy = {};
      controller.busySessions = {};
      controller.notifyListeners();
      await tester.tap(find.byKey(const Key('subagent-parent-session')));
      await shot('parent-result');
      expect(find.text(_finalResult), findsWidgets);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('chat-composer-field')))
            .controller!
            .text,
        'Keep the review concise.',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
