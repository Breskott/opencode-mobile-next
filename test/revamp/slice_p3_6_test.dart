// slice-P3.6 "A worker is its conversation" (docs/ux-system/programmes.json
// P3.6; docs/qa/slice-P3.6-2026-09-27/README.md): tapping a worker opens the
// chat in watching mode (its live output when its session cannot be read);
// messaging a worker happens in that conversation's composer; the worker's
// state comes from its session; team-agent is a short status page whose
// primary opens the conversation, reached from the conversation's top bar.
//
// Also the chat call sites wired here: P6.7's "Always allow" invitation
// under the permission card, P10.4's automatic voice setup on the first mic
// tap, and the team conversation's "AI Team" opening the one team page.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit.dart' show KitDraft;
import 'package:opencode_mobile/ui/screens/chat_screen.dart';
import 'package:opencode_mobile/ui/screens/team/agent_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_agents_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_page.dart';
import 'package:opencode_mobile/voice/controller.dart';
import 'package:opencode_mobile/voice/model_manager.dart';
import 'package:opencode_mobile/voice/model_manifest.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/complete_message_history.dart';
import '../support/team_chat_fixture.dart';
import '../voice_controller_test.dart'
    show FakeVoiceRecognizer, FakeVoiceRecorder, ReadyVoiceModelManager;

Finder _key(String value) => find.byKey(ValueKey(value));

final _en = lookupAppLocalizations(const Locale('en'));

const _secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// furiosa's own session in its work folder, and its transcript.
List<GlobalSessionResult> _store() => [
  teamSession(
    'ses_furiosa',
    teamPolecatDir,
    updated: DateTime.utc(2026, 9, 25, 19, 54),
    title: 'Polecat startup: claim work and execute',
  ),
];

Map<String, List<MessageWithParts>> _transcript() => {
  'ses_furiosa': [
    teamChatMessage('m1', 'user', 'Run gc prime and claim your work.'),
    teamChatMessage(
      'm2',
      'assistant',
      'Claimed ma-1. Adding the toggle to Settings.',
    ),
  ],
};

/// A model manager with no speech model on the phone yet.
class _MissingModels extends ReadyVoiceModelManager {
  _MissingModels(super.preferences) {
    state = VoiceModelState.required;
  }

  @override
  bool isInstalled(VoiceModelPack pack) => false;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _secure,
      (_) async => null,
    );
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_secure, null);
  });

  /// Lets the team's own timers run out before the test ends.
  Future<void> drain(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 10));
  }

  group('a worker is its conversation', () {
    testWidgets('an agents-list row opens the worker\'s conversation in '
        'watching mode; its own page is the conversation\'s one action, whose '
        'Open conversation comes back without a loop', (tester) async {
      phoneViewport(tester);
      final (team, gateway) = await bootTeam();
      final connection = await teamConnection(
        api: TeamChatApi(_transcript()),
        repository: TeamChatRepository(_store()),
      );
      await tester.pumpWidget(
        teamChatApp(
          connection,
          TeamAgentsScreen(controller: team, now: () => teamClock),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_key('team-home-agent-my-app/gastown.furiosa'));
      await tester.pumpAndSettle();

      // The chat page on furiosa's session, watching, never the agent page.
      expect(find.byType(AgentScreen), findsNothing);
      expect(
        tester.widget<ChatScreen>(find.byType(ChatScreen)).sessionID,
        'ses_furiosa',
      );
      expect(
        find.text('Claimed ma-1. Adding the toggle to Settings.'),
        findsOneWidget,
      );
      expect(find.text('Watching furiosa · Worker · Working'), findsOneWidget);
      // Messaging it is the conversation's composer.
      expect(_key('chat-watching-message-field'), findsOneWidget);

      // Its state, controls and details: the one top-bar action.
      await tester.tap(_key('chat-watching-details'));
      await tester.pumpAndSettle();
      expect(find.byType(AgentScreen), findsOneWidget);
      // A short status page: one pinned action, no message sheet.
      expect(_key('team-agent-open-conversation'), findsOneWidget);
      expect(_key('team-agent-control-message'), findsNothing);

      await tester.tap(_key('team-agent-open-conversation'));
      await tester.pumpAndSettle();
      // Opened from its page: Back is the way there, not a second copy.
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(_key('chat-watching-details'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AgentScreen), findsOneWidget);
      expect(gateway.messages, isEmpty);
      await drain(tester);
    });

    testWidgets('the status line says the worker\'s state from its session, '
        'and follows it', (tester) async {
      phoneViewport(tester);
      final (team, gateway) = await bootTeam();
      final connection = await teamConnection(
        api: TeamChatApi(_transcript()),
        repository: TeamChatRepository(_store()),
      );
      await tester.pumpWidget(
        teamChatApp(
          connection,
          Builder(
            builder: (context) => ChatScreen(
              sessionID: 'ses_furiosa',
              watch: teamAgentWatch(context, teamFuriosa(), team: team),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The agents list says stopped; its session runs.
      expect(
        find.text(
          _en.teamWatchBanner(
            'furiosa',
            _en.teamUiAgentRoleWorker,
            _en.teamUiHomeAgentStateWorking,
          ),
        ),
        findsOneWidget,
      );

      // Its session stops: the line says so without leaving the page.
      gateway.agentsOverride = [
        teamFuriosa(sessionRunning: false, sessionState: 'stopped'),
      ];
      await team.refresh();
      await tester.pumpAndSettle();
      expect(
        find.text(
          _en.teamWatchBanner(
            'furiosa',
            _en.teamUiAgentRoleWorker,
            _en.teamUiHomeAgentStateStopped,
          ),
        ),
        findsOneWidget,
      );
      await drain(tester);
    });

    testWidgets('no session on the server: the watching page drawn from the '
        'live output, titled by its task; its composer messages the worker '
        'once, with the receipt above it, and keeps an unsent draft', (
      tester,
    ) async {
      phoneViewport(tester);
      final (team, gateway) = await bootTeam();
      final connection = await teamConnection(
        api: TeamChatApi(const {}),
        repository: TeamChatRepository(const []),
      );
      // The saved server the draft is kept for.
      await _save(
        connection,
        ServerProfile(id: 'phone', name: 'Pixel', baseUrl: 'http://pixel'),
      );
      Widget page() => teamChatApp(
        connection,
        TeamWatchLiveScreen(
          team: team,
          agentId: 'my-app/gastown.furiosa',
          note: _en.teamWatchFallbackNotFound,
        ),
      );
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();

      // Which task this is; the worker is the status line's.
      expect(
        find.descendant(
          of: _key('chat-watching-live-title'),
          matching: find.text('Add the toggle to Settings'),
          matchRoot: true,
        ),
        findsOneWidget,
      );
      expect(_key('chat-watching-live-note'), findsOneWidget);
      expect(_key('chat-watching-details'), findsOneWidget);

      // A draft outlives the page.
      await tester.enterText(
        _key('chat-watching-message-field'),
        'Use the system setting',
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(
          KitDraft.keyFor('team-message.my-app/gastown.furiosa', 'phone'),
        ),
        'Use the system setting',
      );
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text('Use the system setting'), findsOneWidget);

      await tester.enterText(
        _key('chat-watching-message-field'),
        'Use the system setting as the default.',
      );
      await tester.pump();
      await tester.tap(_key('chat-watching-message-send'));
      await tester.pumpAndSettle();
      expect(gateway.messages, [
        ('my-app/gastown.furiosa', 'Use the system setting as the default.'),
      ]);
      expect(_key('chat-watching-message-receipt'), findsOneWidget);
      expect(find.text('Use the system setting as the default.'), findsNothing);
      expect(
        prefs.getString(
          KitDraft.keyFor('team-message.my-app/gastown.furiosa', 'phone'),
        ),
        isNull,
      );
      await drain(tester);
    });

    testWidgets('a team that takes no messages says so in the composer', (
      tester,
    ) async {
      phoneViewport(tester);
      final (team, gateway) = await bootTeam(
        // The team's read plane only: it takes no messages.
        capabilities: const OrchestrationCapabilities(
          runs: true,
          runSteps: true,
          workGraph: true,
          agents: true,
          agentOutput: true,
          sessionLink: true,
          eventStream: true,
        ),
      );
      final connection = await teamConnection(
        api: TeamChatApi(const {}),
        repository: TeamChatRepository(const []),
      );
      await tester.pumpWidget(
        teamChatApp(
          connection,
          TeamWatchLiveScreen(team: team, agentId: 'my-app/gastown.furiosa'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(_en.teamChatComposerCannot), findsOneWidget);
      expect(_key('chat-watching-message-send'), findsNothing);
      expect(gateway.messages, isEmpty);
      await drain(tester);
    });
  });

  testWidgets('the team conversation\'s AI Team opens the one team page, '
      'whose row for this task comes back to it', (tester) async {
    phoneViewport(tester);
    final (team, _) = await bootTeam();
    final connection = await teamConnection(
      api: TeamChatApi(const {}),
      repository: TeamChatRepository(const []),
    );
    // This team is the connected server's.
    final profile = ServerProfile(
      id: 'phone',
      name: 'This phone',
      baseUrl: 'http://127.0.0.1:4097',
      orchestration: team.config,
    );
    await _save(connection, profile);
    connection
      ..adoptConnectedProfileForTesting(profile)
      ..adoptOrchestrationForTesting(team);
    await tester.pumpWidget(
      teamChatApp(
        connection,
        TeamControllerScope(
          team: team,
          child: TeamConversationScreen(
            team: team,
            runId: teamTask.id,
            now: () => teamClock,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(_key('team-conversation-team-page'));
    await tester.pumpAndSettle();
    expect(find.byType(TeamPage), findsOneWidget);

    await tester.tap(find.text(teamTask.title));
    await tester.pumpAndSettle();
    expect(find.byType(TeamPage), findsNothing);
    expect(
      find.byType(TeamConversationScreen, skipOffstage: false),
      findsOneWidget,
    );
    await drain(tester);
  });

  group('chat call sites', () {
    testWidgets('P6.7: the third identical ask offers Always allow directly '
        'under its permission card', (tester) async {
      SharedPreferences.setMockInitialValues({
        'oc.profiles':
            '[{"id":"phone","name":"Pixel","baseUrl":"http://pixel",'
            '"username":""}]',
        'oc.activeProfile': 'phone',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = ProfileStore(prefs: prefs);
      await store.load();
      final connection = ConnectionController(store)
        ..api = _ChatApi()
        ..status = StreamStatus.connected;
      addTearDown(connection.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [connProvider.overrideWithValue(connection)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ChatScreen(sessionID: 'session-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> ask(String id) async {
        connection.handleEventForTesting(
          EventEnvelope(
            type: 'permission.asked',
            properties: {
              'id': id,
              'sessionID': 'session-1',
              'permission': 'bash',
              'patterns': ['git status'],
              'metadata': <String, Object?>{},
              'always': ['git *'],
            },
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> answered(String id) async {
        connection.handleEventForTesting(
          EventEnvelope(
            type: 'permission.replied',
            properties: {'requestID': id, 'sessionID': 'session-1'},
          ),
        );
        await tester.pumpAndSettle();
      }

      await ask('r1');
      expect(_key('permission-card-r1'), findsOneWidget);
      expect(_key('always-allow-invite'), findsNothing);
      await answered('r1');
      await ask('r2');
      expect(_key('always-allow-invite'), findsNothing);
      await answered('r2');
      await ask('r3');
      expect(_key('always-allow-invite'), findsOneWidget);
      expect(
        tester.getRect(_key('always-allow-invite')).top,
        greaterThanOrEqualTo(tester.getRect(_key('permission-card-r3')).bottom),
      );
    });

    testWidgets('P10.4: the first mic tap without a speech model opens the '
        'automatic setup', (tester) async {
      debugPlatformCapabilities = const PlatformCapabilities.android();
      addTearDown(() => debugPlatformCapabilities = null);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final voice = VoiceComposerController(
        models: _MissingModels(prefs),
        recorder: FakeVoiceRecorder(),
        recognizer: FakeVoiceRecognizer(),
      );
      addTearDown(voice.dispose);
      final connection = ConnectionController(ProfileStore(prefs: prefs))
        ..api = _ChatApi()
        ..status = StreamStatus.connected;
      await _save(
        connection,
        ServerProfile(id: 'phone', name: 'Pixel', baseUrl: 'http://pixel'),
      );
      connection.sessionsById['session-1'] = Session(id: 'session-1');
      addTearDown(connection.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [connProvider.overrideWithValue(connection)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ChatScreen(sessionID: 'session-1', voiceController: voice),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('composer-voice-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('voice-auto-setup')), findsOneWidget);
    });
  });
}

/// Saves [profile] and makes it the active server.
Future<void> _save(
  ConnectionController connection,
  ServerProfile profile,
) async {
  await connection.store.upsert(profile);
  await connection.store.setActiveId(profile.id);
}

class _ChatApi extends OpenCodeApi with CompleteMessageHistory {
  _ChatApi() : super(baseUrl: 'http://localhost');

  @override
  Future<Session> session(String id) async => Session(id: id);

  @override
  Future<List<MessageWithParts>> messages(String id) async => [];

  @override
  Future<List<PermissionRequest>> pendingPermissions() async => const [];

  @override
  Future<List<PermissionRequest>> pendingPermissionsV2() =>
      Future.error(ApiException('V2 unavailable', statusCode: 404));
}
