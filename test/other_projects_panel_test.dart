import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/widgets/other_projects_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Controller extends ConnectionController {
  _Controller(super.store);

  List<ProfileLocation> recents = const [];
  List<ElsewhereConversation> elsewhere = const [];
  final switched = <String?>[];
  final opened = <String?>[];
  final forgotten = <String>[];

  @override
  List<ProfileLocation> get recentLocations => recents;

  @override
  Future<List<ElsewhereConversation>> conversationsElsewhere({
    int limit = 6,
  }) async => elsewhere;

  @override
  Future<void> selectLocation({String? directory, String? workspace}) async {
    switched.add(directory);
    this.directory = directory;
  }

  @override
  Future<void> selectLocationForExistingSession({
    String? directory,
    String? workspace,
  }) async {
    opened.add(directory);
    this.directory = directory;
  }

  @override
  Future<void> forgetRecentLocation(String directory) async {
    forgotten.add(directory);
    recents = [
      for (final location in recents)
        if (location.directory != directory) location,
    ];
    notifyListeners();
  }
}

ElsewhereConversation _conversation(
  String id,
  String title,
  String directory, {
  bool running = false,
}) => ElsewhereConversation(
  session: Session(id: id, title: title, directory: directory),
  directory: directory,
  running: running,
);

Future<_Controller> _pump(
  WidgetTester tester, {
  List<ProfileLocation> recents = const [],
  List<ElsewhereConversation> elsewhere = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final controller = _Controller(ProfileStore(prefs: prefs))
    ..status = StreamStatus.connected
    ..directory = '/work/app'
    ..recents = recents
    ..elsewhere = elsewhere;
  addTearDown(controller.dispose);
  final pushed = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateRoute: (settings) {
        pushed.add(settings.name ?? '');
        return MaterialPageRoute<void>(
          builder: (_) => Scaffold(body: Text('route ${settings.name}')),
        );
      },
      home: Scaffold(body: OtherProjectsPanel(controller: controller)),
    ),
  );
  await tester.pump();
  await tester.pump();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('with one project in play the Work tab shows nothing extra', (
    tester,
  ) async {
    await _pump(
      tester,
      recents: const [ProfileLocation(directory: '/work/app')],
    );
    expect(find.byKey(const Key('recent-projects-strip')), findsNothing);
    expect(find.text('In other projects'), findsNothing);
  });

  testWidgets('recent projects are one tap away and show what runs there', (
    tester,
  ) async {
    final controller = await _pump(
      tester,
      recents: const [
        ProfileLocation(directory: '/work/app'),
        ProfileLocation(directory: '/work/FinanceHub3'),
        ProfileLocation(directory: '/work/site'),
      ],
      elsewhere: [
        _conversation('s1', 'Fix offers', '/work/FinanceHub3', running: true),
        _conversation('s2', 'Tidy css', '/work/site'),
      ],
    );
    // The current project is the header's job, not a chip.
    expect(find.text('app'), findsNothing);
    final strip = find.byKey(const Key('recent-projects-strip'));
    Finder chip(String label) =>
        find.descendant(of: strip, matching: find.text(label));
    expect(chip('FinanceHub3 · 1'), findsOneWidget);
    expect(chip('site'), findsOneWidget);

    await tester.tap(chip('site'));
    await tester.pump();
    expect(controller.switched, ['/work/site']);
  });

  testWidgets('conversations elsewhere are listed, running first in words, '
      'and open in their own project', (tester) async {
    final controller = await _pump(
      tester,
      elsewhere: [
        _conversation('s1', 'Fix offers', '/work/FinanceHub3', running: true),
        _conversation('s2', 'Tidy css', '/work/site'),
      ],
    );
    expect(find.text('In other projects'), findsOneWidget);
    expect(find.text('FinanceHub3 · Running'), findsOneWidget);
    expect(find.text('site'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('elsewhere-s1')));
    await tester.pumpAndSettle();
    expect(controller.opened, ['/work/FinanceHub3']);
    expect(find.text('route /chat/s1'), findsOneWidget);
  });

  testWidgets('a project where an agent is stopped on you says so, live', (
    tester,
  ) async {
    final controller = await _pump(
      tester,
      recents: const [
        ProfileLocation(directory: '/work/app'),
        ProfileLocation(directory: '/work/FinanceHub3'),
      ],
      elsewhere: [_conversation('s1', 'Fix offers', '/work/FinanceHub3')],
    );
    expect(find.textContaining('Needs you'), findsNothing);
    expect(controller.waitingElsewhereCount, 0);

    // From the server-wide event channel, while looking at another project.
    controller.elsewhereAttention.handle(
      EventEnvelope(
        type: 'permission.v2.asked',
        directory: '/work/FinanceHub3',
        properties: const {'id': 'req1', 'sessionID': 's1'},
      ),
    );
    await tester.pump();
    expect(find.text('FinanceHub3 · Needs you'), findsNWidgets(2));
    expect(controller.waitingElsewhereCount, 1);
    // The Inbox badge counts it.
    expect(controller.unifiedAttentionCount, 1);

    // A project not on the strip yet earns a chip the moment it needs you.
    controller.elsewhereAttention.handle(
      EventEnvelope(
        type: 'question.asked',
        directory: '/work/site',
        properties: const {'id': 'q1', 'sessionID': 's7'},
      ),
    );
    await tester.pump();
    expect(find.text('site · Needs you'), findsOneWidget);

    controller.elsewhereAttention.handle(
      EventEnvelope(
        type: 'permission.v2.replied',
        directory: '/work/FinanceHub3',
        properties: const {'requestID': 'req1'},
      ),
    );
    await tester.pump();
    expect(find.text('FinanceHub3 · Needs you'), findsNothing);
  });

  testWidgets('a project can be taken off the strip', (tester) async {
    final controller = await _pump(
      tester,
      recents: const [
        ProfileLocation(directory: '/work/app'),
        ProfileLocation(directory: '/work/old'),
      ],
    );
    await tester.longPress(find.text('old'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from recent projects'));
    await tester.pumpAndSettle();
    expect(controller.forgotten, ['/work/old']);
    expect(find.text('old'), findsNothing);
  });

  test('a server remembers its recent projects, newest first', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = ProfileStore(prefs: prefs);
    for (final name in ['a', 'b', 'a', 'c']) {
      await store.setLocation('p1', directory: '/work/$name');
    }
    expect(store.recentLocations('p1').map((l) => l.directory), [
      '/work/c',
      '/work/a',
      '/work/b',
    ]);
    // Another server has its own list.
    expect(store.recentLocations('p2'), isEmpty);

    for (var i = 0; i < 12; i++) {
      await store.setLocation('p1', directory: '/work/n$i');
    }
    expect(
      store.recentLocations('p1'),
      hasLength(ProfileStore.maxRecentLocations),
    );

    await store.forgetRecentLocation('p1', '/work/n11');
    expect(
      store.recentLocations('p1').map((l) => l.directory),
      isNot(contains('/work/n11')),
    );
    // Removed with the server: the key is inside the per-profile sweep.
    expect(
      store.profileScopedPreferenceKeys('p1'),
      contains('oc.recentLocations.p1'),
    );
  });
}
