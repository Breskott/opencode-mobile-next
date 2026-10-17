// The chats list (ChatsHomeScreen) and the all-conversations page
// (GlobalSessionsScreen) in their main states, from the real code.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opencode_mobile/api/models.dart' show Session;
import 'package:opencode_mobile/domain/chat_feed.dart';
import 'package:opencode_mobile/ui/screens/chats/chats_home_screen.dart';
import 'package:opencode_mobile/ui/screens/chats/chats_host.dart';
import 'package:opencode_mobile/ui/screens/global_sessions_screen.dart';
import 'package:widgetbook/widgetbook.dart';

import '../catalog.dart';
import '../fakes/fake_app.dart';
import '../fakes/fake_chats_host.dart';
import '../fakes/fake_gateway.dart';

Widget _list(FakeHost Function() host) => FakeAppScene<FakeApp>(
  platform: FakePlatform.android,
  create: () => FakeApp.create(profiles: const []),
  builder: (context, app) => ProviderScope(
    overrides: [chatsHostProvider.overrideWithValue(host())],
    child: const ChatsHomeScreen(),
  ),
);

const _min = Duration(minutes: 1);
const _hour = Duration(hours: 1);
const _day = Duration(days: 1);

List<ChatFeedItem> _typicalDay() => [
  feedRow(
    'a',
    'Fix the flaky checkout test',
    status: ChatStatus.needsYou,
    ago: _min * 2,
    preview: 'Allow running flutter test?',
    contextUsage: 0.42,
  ),
  feedRow(
    'b',
    'Add dark mode to settings',
    status: ChatStatus.running,
    ago: _min * 9,
    preview: 'Editing lib/settings/theme.dart',
    contextUsage: 0.18,
  ),
  feedRow(
    'c',
    'Explain the payments module',
    ago: _min * 40,
    preview: 'It talks to the card processor through one gateway.',
    finishedUnseen: true,
  ),
  feedRow(
    'd',
    'Speed up the CI pipeline',
    project: 'infra',
    dir: '/home/dev/infra',
    ago: _day * 3,
    preview: 'The slowest step is the Docker build.',
  ),
  feedRow(
    'e',
    'Rename the Cart class',
    ago: _day * 4,
    preview: 'Done. I renamed it in 14 files.',
  ),
  feedRow(
    'f',
    'Draft release notes for 2.4',
    project: 'docs',
    dir: '/home/dev/docs',
    git: false,
    ago: _day * 6,
  ),
];

List<ChatFeedItem> _manyLong() => [
  feedRow(
    'a',
    'Investigate why the order confirmation e-mail is sent twice for '
        'customers who pay with a saved card and then press back',
    status: ChatStatus.needsYou,
    ago: _min * 4,
    preview: 'Should I add a unique key to the e-mail job, or lock the order?',
  ),
  feedRow(
    'b',
    'Migrate the whole inventory service from the old REST endpoints to '
        'the new event stream without a maintenance window',
    status: ChatStatus.running,
    ago: _min * 12,
    preview: 'Step 3 of 7: replaying yesterday\'s events into the new store',
  ),
  for (var i = 0; i < 8; i++)
    feedRow(
      'm$i',
      const [
        'Make the product search tolerate typos in the brand name and keep '
            'the results sorted by what people actually buy',
        'Why does the checkout total flicker for one frame after the coupon '
            'is applied on slow phones',
        'ملخص التغييرات في خدمة الدفع وكيفية اختبارها على الأجهزة البطيئة',
        'Write a migration guide for the three teams that still call the '
            'v1 pricing API directly',
      ][i % 4],
      project: const [
        'shopfront',
        'inventory',
        'billing-service-with-a-long-name',
      ][i % 3],
      dir: '/home/dev/${const ['shopfront', 'inventory', 'billing'][i % 3]}',
      ago: _hour * (i + 2),
      preview:
          'I looked at the three call sites and only one of them needs '
          'the change; the other two already handle it.',
      contextUsage: i.isEven ? 0.75 + i / 40 : null,
    ),
  for (var i = 0; i < 4; i++)
    feedRow(
      'o$i',
      'Old conversation number ${i + 1} with a title that keeps going and '
          'going past any reasonable width on a phone',
      ago: _day * (i + 2),
    ),
];

final _projects = [
  feedProject('shopfront', chats: 3, running: 0, needs: 1),
  feedProject('infra', chats: 1),
  feedProject('docs', chats: 1, git: false),
];

CatalogComponent chatsHome() => catalogComponent(
  area: 'Chats',
  screen: 'ChatsHomeScreen',
  name: 'Chats list',
  useCases: [
    WidgetbookUseCase(
      name: 'Loading',
      builder: (_) =>
          _list(() => FakeHost(FakeFeed(loading: true, projects: _projects))),
    ),
    WidgetbookUseCase(
      name: 'Empty (first run)',
      builder: (_) => _list(() => FakeHost(FakeFeed())),
    ),
    WidgetbookUseCase(
      name: 'A typical day',
      builder: (_) => _list(
        () => FakeHost(FakeFeed(items: _typicalDay(), projects: _projects)),
      ),
    ),
    WidgetbookUseCase(
      name: 'Many chats, long titles',
      builder: (_) => _list(
        () => FakeHost(FakeFeed(items: _manyLong(), projects: _projects)),
      ),
    ),
    WidgetbookUseCase(
      name: 'Offline',
      builder: (_) => _list(
        () => FakeHost(
          FakeFeed(
            items: _typicalDay(),
            projects: _projects,
            complete: false,
            unreachableServers: const ['main'],
          ),
          sources: FakeSources(const [
            ChatListSource(
              id: 'main',
              name: 'Workstation',
              kind: ChatListSourceKind.openCode,
              shown: true,
              onThisPhone: false,
              main: true,
              unreachable: true,
            ),
          ]),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Several connections',
      builder: (_) => _list(
        () => FakeHost(
          FakeFeed(
            items: [
              feedRow(
                'a',
                'Fix the flaky checkout test',
                status: ChatStatus.needsYou,
                ago: _min * 2,
                preview: 'Allow running flutter test?',
                sourceId: 'profile:main',
                sourceLabel: 'Workstation',
              ),
              feedRow(
                'b',
                'Review the pull request',
                status: ChatStatus.running,
                ago: _min * 8,
                agentId: 'claude',
                agentLabel: 'Claude Code',
                preview: 'Reading the diff of 6 files',
              ),
              feedRow(
                'c',
                'Plan the weekend trip',
                ago: _hour * 3,
                sourceId: 'profile:laptop',
                sourceLabel: 'Laptop',
                preview: 'Two trains leave before nine.',
              ),
              feedRow(
                'd',
                'Explain the build',
                ago: _day * 2,
                agentId: 'claude',
                agentLabel: 'Claude Code',
              ),
            ],
            projects: _projects,
          ),
          sources: FakeSources(const [
            ChatListSource(
              id: 'main',
              name: 'Workstation',
              kind: ChatListSourceKind.openCode,
              shown: true,
              onThisPhone: false,
              main: true,
            ),
            ChatListSource(
              id: 'laptop',
              name: 'Laptop',
              kind: ChatListSourceKind.openCode,
              shown: true,
              onThisPhone: false,
            ),
            ChatListSource(
              id: 'claude',
              name: 'Claude Code',
              kind: ChatListSourceKind.agents,
              shown: true,
            ),
          ]),
        ),
      ),
    ),
  ],
);

Widget _all(FakeServer Function() server) => FakeAppScene<FakeApp>(
  platform: FakePlatform.android,
  create: () => server().connect(),
  builder: (context, app) => GlobalSessionsScreen(controller: app.connection),
);

FakeServer _allServer({bool empty = false}) {
  final sessions = empty
      ? <String, Session>{}
      : {
          for (final s in [
            fakeSession('s1', 'Fix the flaky checkout test', ago: _min * 2),
            fakeSession('s2', 'Add dark mode to settings', ago: _hour * 3),
            fakeSession('s3', 'Explain the payments module', ago: _hour * 26),
            fakeSession(
              's4',
              'Speed up the CI pipeline',
              ago: _day * 3,
              directory: '/home/dev/infra',
            ),
            fakeSession(
              's5',
              'Draft release notes for 2.4',
              ago: _day * 6,
              directory: '/home/dev/docs',
            ),
          ])
            s.id: s,
        };
  return FakeServer(sessions: sessions, busy: empty ? {} : {'s2'});
}

CatalogComponent allConversations() => catalogComponent(
  area: 'Chats',
  screen: 'GlobalSessionsScreen',
  name: 'All conversations',
  useCases: [
    WidgetbookUseCase(
      name: 'Grouped by project',
      builder: (_) => _all(_allServer),
    ),
    WidgetbookUseCase(
      name: 'Nothing yet',
      builder: (_) => _all(() => _allServer(empty: true)),
    ),
  ],
);
