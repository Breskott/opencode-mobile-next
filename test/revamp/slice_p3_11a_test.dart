// Behaviour of slice-P3.11a's merges outside the chat library: each merged
// pair has one landing, and these tests assert the surviving one.
//
// - The Work folder row opens the project sheet with that folder under an
//   open Details (workspace-directory-details-dialog merged into
//   workspace-context-sheet).
// - A Work row's menu opens Conversation context
//   (workspace-session-details-sheet merged into session-context).
// - The question sheet pins Send to its foot and enables it as the person
//   answers (question-sheet-dismiss already confirms through KitConfirm).
//
// The other merged pairs are asserted in the existing tests of their files:
// test/session_command_handoff_test.dart (continue on computer),
// test/revamp/screen_library_3_test.dart (server sign-in, forget, accounts),
// test/revamp/screen_usage_2_test.dart and test/provider_quota_screen_test.dart
// (quota monitoring in place), test/project_hub_test.dart (Manage project's
// tools on the Project tab) and test/session_context_screen_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/activity_screen.dart';
import 'package:opencode_mobile/ui/screens/home_screen.dart';
import 'package:opencode_mobile/ui/screens/session_context_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _en = lookupAppLocalizations(const Locale('en'));

class _Api extends OpenCodeApi {
  _Api() : super(baseUrl: 'http://localhost');

  @override
  ServerCapabilities get capabilities => const ServerCapabilities(
    fileBrowsing: false,
    terminal: false,
    projectManagement: false,
    globalSessionSearch: false,
    sessionImportExport: false,
    serverCatalog: false,
  );

  @override
  Future<List<Session>> sessions() async => [];
}

class _Repository implements ProductRepository {
  int listProjectsCalls = 0;

  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<List<WorkspaceProject>> listProjects() async {
    listProjectsCalls++;
    return [];
  }

  @override
  Future<List<WorkspaceInfo>> listWorkspaces() async => [];

  @override
  Future<List<TerminalProcess>> listTerminals() async => [];

  @override
  Future<CatalogSnapshot> loadCatalog() async =>
      const CatalogSnapshot(providers: [], models: [], agents: []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Store extends ProfileStore {
  _Store({required super.prefs});

  final profile = ServerProfile(
    id: 'folder-server',
    name: 'Studio',
    baseUrl: 'http://localhost',
  );

  @override
  List<ServerProfile> get profiles => [profile];

  @override
  String? get activeId => profile.id;
}

/// A server that works in one configured folder and cannot manage
/// projects, with one conversation in that folder.
Future<ConnectionController> _folderServer(_Repository repository) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final controller = ConnectionController(_Store(prefs: prefs))
    ..api = _Api()
    ..repository = repository
    ..status = StreamStatus.connected
    ..directory = '/workspace/shopfront';
  controller.sessionsById['ses-1'] = Session(
    id: 'ses-1',
    title: 'Fix the checkout test',
    directory: '/workspace/shopfront',
    time: SessionTime(created: 1, updated: 1),
  );
  return controller;
}

Widget _home(ConnectionController controller) => ProviderScope(
  overrides: [connProvider.overrideWithValue(controller)],
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: HomeScreen(),
  ),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class _Answers extends ConnectionController {
  _Answers(super.store);

  List<List<String>>? answers;

  @override
  Future<void> refreshPendingQuestions() async {}

  @override
  Future<void> answerQuestion(
    String id,
    List<List<String>> answers, {
    PendingRequestIdentity? expectedRequest,
  }) async {
    this.answers = answers;
  }
}

const _question = PendingQuestion(
  id: 'q-1',
  sessionID: 'ses-1',
  prompts: [
    QuestionPrompt(
      title: 'Target',
      question: 'Where should this deploy?',
      multiple: false,
      custom: false,
      choices: [
        QuestionChoice(label: 'Staging', description: 'Test first'),
        QuestionChoice(label: 'Production', description: 'Live'),
      ],
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the Work folder row opens the project sheet with the folder '
      'under an open Details, not a folder dialog', (tester) async {
    _phone(tester);
    final repository = _Repository();
    final controller = await _folderServer(repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_home(controller));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('restricted-directory-context')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('workspace-context-sheet')), findsOne);
    expect(
      find.byKey(const ValueKey('workspace-directory-details')),
      findsNothing,
    );
    // A server that cannot manage projects is offered no project rows.
    expect(find.byKey(const ValueKey('context-switch-project')), findsNothing);
    expect(find.byKey(const ValueKey('manage-project-entry')), findsNothing);
    // Details is open on the folder, copyable.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('workspace-context-sheet')),
        matching: find.textContaining('/workspace/shopfront'),
      ),
      findsWidgets,
    );
    expect(find.text(_en.workspaceContextFolder), findsOneWidget);
    expect(repository.listProjectsCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Work row\'s menu opens Conversation context, where its '
      'folder and link now live', (tester) async {
    _phone(tester);
    final controller = await _folderServer(_Repository());
    addTearDown(controller.dispose);
    await tester.pumpWidget(_home(controller));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Fix the checkout test'));
    await tester.pumpAndSettle();
    expect(find.text(_en.chatUiDetails), findsNothing);
    await tester.tap(find.text(_en.e7SharedSessionContext).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(SessionContextScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workspace-session-details')),
      findsNothing,
    );
  });

  group('question sheet', () {
    Future<_Answers> open(WidgetTester tester) async {
      _phone(tester);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = _Answers(ProfileStore(prefs: prefs))
        ..repository = _Repository()
        ..status = StreamStatus.connected;
      controller.questions = {'q-1': _question};
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: KitButton.primary(
                  label: 'Open',
                  onPressed: () =>
                      showQuestionSheet(context, controller, _question),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      return controller;
    }

    Finder send() => find.byKey(const ValueKey('question-send'));

    testWidgets('Send is pinned to the sheet\'s foot, outside the scrolling '
        'answers', (tester) async {
      await open(tester);
      expect(send(), findsOneWidget);
      expect(
        find.descendant(of: find.byType(Scrollable), matching: send()),
        findsNothing,
      );
      // The answers scroll; Send stays in view without scrolling.
      expect(send().hitTestable(), findsOneWidget);
    });

    testWidgets('Send enables as the person answers, and sends', (
      tester,
    ) async {
      final controller = await open(tester);
      expect(find.text(_en.activityAnswerEveryQuestion), findsOneWidget);
      await tester.tap(send());
      await tester.pump();
      expect(controller.answers, isNull);

      await tester.tap(find.text('Staging'));
      await tester.pump();
      expect(find.text(_en.activityAnswerEveryQuestion), findsNothing);

      await tester.tap(send());
      await tester.pumpAndSettle();
      expect(controller.answers, [
        ['Staging'],
      ]);
    });
  });
}
