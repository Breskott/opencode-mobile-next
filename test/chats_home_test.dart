import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/chat_feed.dart';
import 'package:opencode_mobile/ui/kit/kit_bidi.dart';
import 'package:opencode_mobile/ui/kit/kit_context_ring.dart';
import 'package:opencode_mobile/ui/kit/motion/kit_reveal.dart' show KitEntrance;
import 'package:opencode_mobile/ui/screens/chats/chats_host.dart'
    show leftoverNoticeLine;
import 'package:opencode_mobile/ui/widgets/work_status_line.dart'
    show WorkRunawayNotice;
import 'package:opencode_mobile/ui/screens/chats/chats_home_screen.dart';

import '../tool/capture/fixtures.dart' show loadCaptureFonts;
import 'support/chats_fakes.dart';

final _now = DateTime(2026, 10, 3, 12);

void clocked(
  String name,
  Future<void> Function(WidgetTester tester) body, {
  Size size = const Size(412, 915),
}) {
  testWidgets(name, (tester) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await withClock(Clock.fixed(_now), () => body(tester));
  });
}

FakeChatFeedSource _source() => FakeChatFeedSource(
  items: [
    chat(
      'a',
      'Fix the login bug',
      status: ChatStatus.needsYou,
      at: _now.subtract(const Duration(minutes: 2)),
      preview: 'Allow running the tests?',
    ),
    chat(
      'b',
      'Add dark mode',
      dir: '/root/projects/beta',
      project: 'beta',
      git: false,
      status: ChatStatus.running,
      at: _now.subtract(const Duration(minutes: 9)),
      preview: 'Editing theme.dart',
    ),
    chat(
      'c',
      'Explain the build',
      at: _now.subtract(const Duration(hours: 3)),
      preview: 'It runs gradle first.',
    ),
    chat(
      'd',
      'Old idea',
      dir: '/root/projects/beta',
      project: 'beta',
      git: false,
      at: _now.subtract(const Duration(days: 3)),
    ),
    chat(
      'sub',
      'Subagent work',
      parent: 'a',
      at: _now.subtract(const Duration(minutes: 1)),
    ),
  ],
  projects: [
    project('alpha', chats: 2, needs: 1, kind: 'dart'),
    project('beta', chats: 2, running: 1, git: false),
    project('quiet', chats: 0),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  FakeChatsHost host, {
  ChatFeedFilter? initialFilter,
  Widget? home,
}) async {
  await tester.pumpWidget(
    chatsApp(host, home ?? ChatsHomeScreen(initialFilter: initialFilter)),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

double _y(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text).first).dy;

void main() {
  setUpAll(loadCaptureFonts);

  clocked('lists Today, then Earlier, newest first', (tester) async {
    await _pump(tester, FakeChatsHost(_source()));
    expect(find.text('Conversations'), findsWidgets);
    expect(
      _y(tester, KitBidi.auto('Fix the login bug')),
      lessThan(_y(tester, KitBidi.auto('Add dark mode'))),
    );
    expect(
      _y(tester, KitBidi.auto('Add dark mode')),
      lessThan(_y(tester, KitBidi.auto('Explain the build'))),
    );
    expect(
      _y(tester, KitBidi.auto('Explain the build')),
      lessThan(_y(tester, KitBidi.auto('Old idea'))),
    );
    // The two time groups, no group of its own for a chat that needs you
    // (its amber word and the chip say it), and a subagent is not a row.
    expect(find.text('Needs you'), findsNothing);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Earlier'), findsOneWidget);
    expect(find.text(KitBidi.auto('Subagent work')), findsNothing);
    // Two lines per row: the state word only when it matters, then the
    // project and the time. No preview, no Git mark.
    expect(find.textContaining('Working', findRichText: true), findsWidgets);
    expect(find.textContaining('3d ago', findRichText: true), findsOneWidget);
    expect(find.text(KitBidi.auto('Allow running the tests?')), findsNothing);
    expect(find.text('Git'), findsNothing);
  });

  clocked('a chat that needs you sorts first inside its time group, not in a '
      'group of its own', (tester) async {
    await _pump(
      tester,
      FakeChatsHost(
        FakeChatFeedSource(
          items: [
            chat(
              'n',
              'Waiting on you, older',
              status: ChatStatus.needsYou,
              at: _now.subtract(const Duration(days: 3)),
            ),
            chat(
              'm',
              'Newer but fine',
              at: _now.subtract(const Duration(days: 2)),
            ),
            chat(
              't',
              'Today normal',
              at: _now.subtract(const Duration(minutes: 5)),
            ),
            chat(
              'u',
              'Today needs you',
              status: ChatStatus.needsYou,
              at: _now.subtract(const Duration(hours: 4)),
            ),
          ],
        ),
      ),
    );
    // No group header says it a third time; the chip still counts them.
    expect(find.text('Needs you'), findsNothing);
    expect(find.text('Needs you · 2'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Earlier'), findsOneWidget);
    double y(String title) => _y(tester, KitBidi.auto(title));
    // Today: the older chat that needs you is above the newer normal one.
    expect(y('Today needs you'), lessThan(y('Today normal')));
    // Earlier: the same, and both stay under the Earlier header.
    expect(y('Waiting on you, older'), lessThan(y('Newer but fine')));
    expect(_y(tester, 'Earlier'), lessThan(y('Waiting on you, older')));
    expect(y('Today normal'), lessThan(_y(tester, 'Earlier')));
  });

  clocked('rows carry no context ring or percentage, known use or not', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeChatsHost(
        FakeChatFeedSource(
          items: [
            chat(
              'full',
              'Nearly full',
              at: _now.subtract(const Duration(minutes: 1)),
              contextUsage: 0.82,
            ),
            chat(
              'roomy',
              'Plenty of room',
              at: _now.subtract(const Duration(minutes: 2)),
              contextUsage: 0.31,
            ),
            chat(
              'unknown',
              'Never opened',
              at: _now.subtract(const Duration(minutes: 3)),
            ),
          ],
          projects: [project('alpha', chats: 3)],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(KitContextRing), findsNothing);
    expect(find.text('82 %'), findsNothing);
  });

  clocked('a row with the server\'s dated placeholder title reads New '
      'conversation', (tester) async {
    await _pump(
      tester,
      FakeChatsHost(
        FakeChatFeedSource(
          items: [
            chat(
              'p',
              'New session - 2026-10-07T12:14:30.123Z',
              at: _now.subtract(const Duration(minutes: 1)),
            ),
          ],
          projects: [project('alpha', chats: 1)],
        ),
      ),
    );
    expect(find.textContaining('New session - 2026'), findsNothing);
    expect(find.text(KitBidi.auto('New conversation')), findsWidgets);
  });

  clocked('only a running row names a state; a finished one has none', (
    tester,
  ) async {
    final at = DateTime(2026, 9, 26, 10);
    await _pump(
      tester,
      FakeChatsHost(
        FakeChatFeedSource(
          items: [
            chat('a', 'Seen chat', at: at),
            chat('b', 'Finished chat', at: at, finishedUnseen: true),
            chat(
              'c',
              'Busy chat',
              at: at,
              status: ChatStatus.running,
              finishedUnseen: true,
            ),
          ],
        ),
      ),
    );
    // A finished conversation has no state word; a running one says Working.
    expect(find.textContaining('Done', findRichText: true), findsNothing);
    expect(find.textContaining('Working', findRichText: true), findsOneWidget);
  });

  clocked('the Needs you chip shows its count and filters', (tester) async {
    await _pump(tester, FakeChatsHost(_source()));
    expect(find.text('Needs you · 1'), findsOneWidget);
    await tester.tap(find.text('Needs you · 1'));
    await tester.pump();
    expect(find.text(KitBidi.auto('Fix the login bug')), findsOneWidget);
    expect(find.text(KitBidi.auto('Add dark mode')), findsNothing);
    expect(find.text(KitBidi.auto('Explain the build')), findsNothing);
    await tester.tap(find.text('Needs you · 1'));
    await tester.pump();
    expect(find.text(KitBidi.auto('Explain the build')), findsOneWidget);
  });

  clocked('Running filters, and with Needs you means either', (tester) async {
    await _pump(tester, FakeChatsHost(_source()));
    await tester.tap(find.byKey(const ValueKey('chats-filter-running')));
    await tester.pump();
    expect(find.text(KitBidi.auto('Add dark mode')), findsOneWidget);
    expect(find.text(KitBidi.auto('Fix the login bug')), findsNothing);
    await tester.tap(find.text('Needs you · 1'));
    await tester.pump();
    expect(find.text(KitBidi.auto('Add dark mode')), findsOneWidget);
    expect(find.text(KitBidi.auto('Fix the login bug')), findsOneWidget);
    expect(find.text(KitBidi.auto('Explain the build')), findsNothing);
  });

  clocked('the project sheet lists All projects and each project', (
    tester,
  ) async {
    await _pump(tester, FakeChatsHost(_source()));
    await tester.tap(find.text('All projects'));
    await tester.pumpAndSettle();
    expect(find.text('Show conversations from'), findsOneWidget);
    expect(find.text('4 conversations'), findsOneWidget);
    expect(find.text('2 conversations · needs you'), findsOneWidget);
    expect(find.text('2 conversations · 1 running'), findsOneWidget);
    expect(find.text('0 conversations'), findsOneWidget);
    expect(find.text('Open a project…'), findsOneWidget);
  });

  clocked('choosing a project filters, the chip names it', (tester) async {
    await _pump(tester, FakeChatsHost(_source()));
    await tester.tap(find.text('All projects'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(KitBidi.auto('beta')).last);
    await tester.pumpAndSettle();
    expect(find.text('Show conversations from'), findsNothing);
    expect(find.text(KitBidi.auto('Add dark mode')), findsOneWidget);
    expect(find.text(KitBidi.auto('Old idea')), findsOneWidget);
    expect(find.text(KitBidi.auto('Fix the login bug')), findsNothing);
    expect(find.text('All projects'), findsNothing);
    // Needs you counts inside the chosen project.
    expect(find.text('Needs you'), findsOneWidget);
  });

  clocked('Open a project… makes the chosen folder the filter', (tester) async {
    final host = FakeChatsHost(_source())
      ..openProjectResult = '/root/projects/quiet';
    await _pump(tester, host);
    await tester.tap(find.text('All projects'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open a project…'));
    await tester.pumpAndSettle();
    expect(host.projectOpens, 1);
    // The sheet closed before the browser opened: one sheet only.
    expect(find.text('Show conversations from'), findsNothing);
    // A folder without chats is an empty list that offers a start.
    expect(
      find.text('No conversations in ${KitBidi.auto('quiet')}'),
      findsOneWidget,
    );
    expect(
      find.text('Start a conversation in ${KitBidi.auto('quiet')}'),
      findsOneWidget,
    );
  });

  clocked('a temporary folder is never made the filter', (tester) async {
    final host = FakeChatsHost(_source())..openProjectResult = '/tmp/scratch';
    await _pump(tester, host);
    await tester.tap(find.text('All projects'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open a project…'));
    await tester.pumpAndSettle();
    expect(find.text('All projects'), findsOneWidget);
    expect(find.text(KitBidi.auto('Fix the login bug')), findsOneWidget);
  });

  clocked('no chats at all offers Start a chat', (tester) async {
    await _pump(tester, FakeChatsHost(FakeChatFeedSource()));
    expect(find.text('No conversations yet'), findsOneWidget);
    expect(find.text('Start a conversation'), findsOneWidget);
    expect(find.text('New conversation'), findsNothing);
  });

  clocked('no matches offers Clear filters, which clears them', (tester) async {
    final source = _source()
      ..items = [
        chat(
          'c',
          'Explain the build',
          at: _now.subtract(const Duration(hours: 3)),
        ),
      ];
    await _pump(tester, FakeChatsHost(source));
    await tester.tap(find.text('Needs you'));
    await tester.pump();
    expect(find.text('No matching conversations'), findsOneWidget);
    // Clear filters is the one primary action here (the shell allows one).
    expect(find.text('New conversation'), findsNothing);
    await tester.tap(find.text('Clear filters'));
    await tester.pump();
    expect(find.text(KitBidi.auto('Explain the build')), findsOneWidget);
  });

  clocked('a server that cannot list all projects says so, quietly', (
    tester,
  ) async {
    final source = _source()..acrossProjects = false;
    await _pump(tester, FakeChatsHost(source));
    expect(
      find.text(
        "Showing conversations in ${KitBidi.auto('alpha')} only. This server can't list all projects.",
      ),
      findsOneWidget,
    );
  });

  clocked('a partial list says some chats could not load', (tester) async {
    final source = _source()..complete = false;
    await _pump(tester, FakeChatsHost(source));
    expect(find.text("Some conversations couldn't load"), findsOneWidget);
  });

  clocked('tapping a row opens that conversation', (tester) async {
    final host = FakeChatsHost(_source());
    await _pump(tester, host);
    await tester.tap(find.text(KitBidi.auto('Explain the build')));
    await tester.pump();
    expect(host.opened, ['c']);
  });

  clocked('pull to refresh asks the source for a fresh list', (tester) async {
    final source = _source();
    await _pump(tester, FakeChatsHost(source));
    await tester.fling(
      find.text(KitBidi.auto('Fix the login bug')),
      const Offset(0, 500),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(source.refreshes, 1);
  });

  clocked('New chat opens the start screen on the filtered project', (
    tester,
  ) async {
    final host = FakeChatsHost(_source());
    await _pump(tester, host);
    await tester.tap(find.text('All projects'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(KitBidi.auto('beta')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New conversation'));
    await tester.pumpAndSettle();
    expect(find.text('What should we work on?'), findsOneWidget);
    expect(find.text(KitBidi.auto('beta')), findsWidgets);
  });

  clocked('an initial filter applies, and a new one replaces it', (
    tester,
  ) async {
    final host = FakeChatsHost(_source());
    await _pump(
      tester,
      host,
      initialFilter: const ChatFeedFilter(needsYou: true),
    );
    expect(find.text(KitBidi.auto('Fix the login bug')), findsOneWidget);
    expect(find.text(KitBidi.auto('Explain the build')), findsNothing);
    await _pump(
      tester,
      host,
      initialFilter: const ChatFeedFilter(running: true),
    );
    expect(find.text(KitBidi.auto('Add dark mode')), findsOneWidget);
    expect(find.text(KitBidi.auto('Fix the login bug')), findsNothing);
  });

  clocked(
    'names the agent first in the meta line only when it is not OpenCode',
    (tester) async {
      await _pump(tester, FakeChatsHost(_source()));
      expect(
        find.textContaining('Claude Code', findRichText: true),
        findsNothing,
      );
      final mixed = _source()
        ..items = [
          ..._source().items,
          chat(
            'cc',
            'Review the diff',
            at: _now.subtract(const Duration(minutes: 5)),
            agentId: 'claude',
            agentLabel: 'Claude Code',
          ),
        ];
      await _pump(tester, FakeChatsHost(mixed));
      expect(
        find.textContaining('Claude Code', findRichText: true),
        findsOneWidget,
      );
      // The default agent is never named, and no row carries an agent chip.
      expect(find.textContaining('OpenCode', findRichText: true), findsNothing);
    },
  );

  clocked('rows of two OpenCode servers name their server', (tester) async {
    final both = _source()
      ..items = [
        chat(
          'u',
          'Fix the build',
          at: _now.subtract(const Duration(minutes: 2)),
          sourceId: 'opencode',
          sourceLabel: 'This phone',
        ),
        chat(
          't',
          'Write the docs',
          at: _now.subtract(const Duration(minutes: 9)),
          sourceId: 'profile:termux',
          sourceLabel: 'Termux',
        ),
      ];
    await _pump(tester, FakeChatsHost(both));
    expect(find.textContaining('Termux', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('This phone', findRichText: true),
      findsOneWidget,
    );
  });

  clocked('the connections chip lists each source and hides one', (
    tester,
  ) async {
    final sources = FakeListSources(const [
      ChatListSource(
        id: 'ubuntu',
        name: 'This phone',
        kind: ChatListSourceKind.openCode,
        shown: true,
        main: true,
      ),
      ChatListSource(
        id: 'termux',
        name: 'Termux',
        kind: ChatListSourceKind.openCode,
        shown: true,
      ),
      ChatListSource(
        id: 'vps',
        name: 'VPS',
        kind: ChatListSourceKind.openCode,
        shown: false,
        onThisPhone: false,
      ),
    ]);
    await _pump(tester, FakeChatsHost(_source())..listSources = sources);
    expect(find.text('2 of 3 connections'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chats-filter-sources')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chats-sources-sheet')), findsOneWidget);
    expect(find.text('Always shown'), findsOneWidget);
    expect(find.text('On another computer'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chats-source-termux')));
    await tester.pumpAndSettle();
    expect(sources.changes, [('termux', false)]);
    // The connection the app is on can't be hidden.
    await tester.tap(find.byKey(const ValueKey('chats-source-ubuntu')));
    await tester.pumpAndSettle();
    expect(sources.changes, [('termux', false)]);
  });

  clocked(
    'a conversation read later arrives; the first ones are simply there',
    (tester) async {
      final source = _source();
      final host = FakeChatsHost(source);
      await _pump(tester, host);
      expect(find.byType(KitEntrance), findsNothing);
      source.items = [
        ...source.items,
        chat(
          'late',
          'Read from Termux',
          at: _now.subtract(const Duration(minutes: 1)),
        ),
      ];
      // The list builds again (here by a filter turned on and off).
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const ValueKey('chats-filter-running')));
        await tester.pump();
      }
      expect(
        find.ancestor(
          of: find.text(KitBidi.auto('Read from Termux')),
          matching: find.byType(KitEntrance),
        ),
        findsOneWidget,
      );
      expect(find.byType(KitEntrance), findsOneWidget);
    },
  );

  clocked('a row slow to open says Opening… until it opens', (tester) async {
    final host = FakeChatsHost(_source())..openGate = Completer<String?>();
    await _pump(tester, host);
    await tester.tap(find.text(KitBidi.auto('Explain the build')));
    await tester.pump();
    expect(find.byKey(const ValueKey('chats-row-opening')), findsOneWidget);
    expect(find.textContaining('Opening…', findRichText: true), findsOneWidget);
    host.openGate!.complete(null);
    await tester.pump();
    expect(find.byKey(const ValueKey('chats-row-opening')), findsNothing);
  });

  clocked('quiet lines scroll with the feed, not in the fixed header', (
    tester,
  ) async {
    final source = _source()..unreachableServers = ['termux'];
    await _pump(tester, FakeChatsHost(source));
    final line = find.byKey(const ValueKey('chats-unreachable'));
    expect(line, findsOneWidget);
    expect(
      find.ancestor(of: line, matching: find.byType(Scrollable)),
      findsWidgets,
    );
    // The filter chips stay fixed above the feed.
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('chats-filter-running')),
        matching: find.byType(CustomScrollView),
      ),
      findsNothing,
    );
  });

  clocked('a server that isn\'t answering is named, with Try again in the '
      'connections sheet', (tester) async {
    final source = _source()..unreachableServers = ['termux'];
    final sources = FakeListSources(const [
      ChatListSource(
        id: 'ubuntu',
        name: 'In-app Ubuntu',
        kind: ChatListSourceKind.openCode,
        shown: true,
        main: true,
      ),
      ChatListSource(
        id: 'termux',
        name: 'Termux',
        kind: ChatListSourceKind.openCode,
        shown: true,
        unreachable: true,
      ),
    ]);
    await _pump(tester, FakeChatsHost(source)..listSources = sources);
    expect(find.byKey(const ValueKey('chats-unreachable')), findsOneWidget);
    expect(find.byKey(const ValueKey('chats-incomplete')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('chats-filter-sources')));
    await tester.pumpAndSettle();
    expect(find.text("Isn't answering"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chats-source-retry-termux')));
    await tester.pumpAndSettle();
    expect(sources.retried, ['termux']);
  });

  clocked('a conversation waiting on you answers right in the list', (
    tester,
  ) async {
    final source = _source();
    final waiting = source.items.firstWhere(
      (item) => item.status == ChatStatus.needsYou,
    );
    final running = source.items.firstWhere(
      (item) => item.status == ChatStatus.running,
    );
    final host = FakeChatsHost(source)
      ..requestCards[waiting.sessionID] = const Text('Allow once card')
      ..requestCards[running.sessionID] = const Text('Not for running');
    await _pump(tester, host);
    expect(find.text('Allow once card'), findsOneWidget);
    // Only a conversation that waits on you shows its request.
    expect(find.text('Not for running'), findsNothing);
  });

  clocked('with one connection there is no connections chip', (tester) async {
    await _pump(tester, FakeChatsHost(_source()));
    expect(find.byKey(const ValueKey('chats-filter-sources')), findsNothing);
  });

  clocked('says which conversations are still loading while rows show', (
    tester,
  ) async {
    final source = _source()..stillLoading = ['Claude Code'];
    await _pump(tester, FakeChatsHost(source));
    expect(find.byKey(const ValueKey('chats-still-loading')), findsOneWidget);
    expect(find.byKey(const ValueKey('kit-loading-bar')), findsOneWidget);
    expect(find.textContaining('Loading'), findsOneWidget);
    await _pump(tester, FakeChatsHost(_source()));
    expect(find.byKey(const ValueKey('chats-still-loading')), findsNothing);
  });

  clocked('Other folders is hidden when no conversation lives there', (
    tester,
  ) async {
    await _pump(tester, FakeChatsHost(_source()));
    await tester.tap(find.byKey(const ValueKey('chats-filter-project')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chats-project-other')), findsNothing);
  });

  clocked('Other folders lists temp, home and root conversations', (
    tester,
  ) async {
    final source = _source()
      ..items = [
        ..._source().items,
        chat(
          't1',
          'Scratch idea',
          dir: '/tmp/scratch',
          project: 'tmp',
          git: false,
          at: _now.subtract(const Duration(minutes: 30)),
        ),
        chat(
          't2',
          'Home notes',
          dir: '/root',
          project: 'Home',
          git: false,
          at: _now.subtract(const Duration(minutes: 31)),
        ),
      ];
    await _pump(tester, FakeChatsHost(source));
    await tester.tap(find.byKey(const ValueKey('chats-filter-project')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chats-project-other')), findsOneWidget);
    expect(find.text('Other folders'), findsOneWidget);
    expect(find.text('2 conversations'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chats-project-other')));
    await tester.pumpAndSettle();
    // The chip reads Other folders and only those conversations show.
    expect(find.text('Other folders'), findsOneWidget);
    expect(find.text(KitBidi.auto('Scratch idea')), findsOneWidget);
    expect(find.text(KitBidi.auto('Home notes')), findsOneWidget);
    expect(find.text(KitBidi.auto('Fix the login bug')), findsNothing);
  });

  clocked('large text does not overflow', (tester) async {
    await tester.pumpWidget(
      chatsApp(FakeChatsHost(_source()), const ChatsHomeScreen(), textScale: 2),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    // The page title keeps to one line: it never breaks mid-word.
    final title = find.byType(Text).evaluate().map((e) => e.widget as Text);
    expect(title.any((t) => t.data == 'Conversation'), isFalse);
    final heading = tester.renderObject<RenderParagraph>(
      find.text('Conversations').first,
    );
    expect(heading.size.height, lessThan(34 * 1.5 * 1.3));
  });

  clocked('the leftover-process notice shows above the list only when the '
      'watcher reports something', (tester) async {
    final host = FakeChatsHost(_source());
    await _pump(tester, host);
    expect(find.byKey(const ValueKey('work-status-runaway')), findsNothing);

    host.leftover = Builder(
      builder: (context) => leftoverNoticeLine(
        context,
        WorkRunawayNotice(
          identity: 1,
          helper: 'node',
          busyFor: '10 min',
          onStop: () {},
          onDismiss: () {},
        ),
      ),
    );
    await _pump(tester, host);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text(
        'A leftover node process has been busy for 10 min with nothing to do',
      ),
      findsOneWidget,
    );
    expect(find.text('Stop node'), findsOneWidget);
  });
}
