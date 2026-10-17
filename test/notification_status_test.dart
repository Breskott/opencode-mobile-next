import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/background/notification_status.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';

final _en = lookupAppLocalizations(const Locale('en'));
final _ar = lookupAppLocalizations(const Locale('ar'));
final _now = DateTime(2026, 10, 14, 13, 5);

String _clock(DateTime t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}';

NotificationStatus _build(
  NotificationStatusInput input, {
  AppLocalizations? l10n,
}) =>
    buildNotificationStatus(input, l10n ?? _en, formatTime: _clock, now: _now);

const _tests = StatusChat(
  id: 's1',
  title: 'UI review and feedback',
  project: 'IPTV_King',
  liveLine: 'Running the tests',
  tasksDone: 5,
  tasksTotal: 6,
  elapsed: Duration(minutes: 4),
);
const _shop = StatusChat(
  id: 's2',
  title: 'shopfront',
  liveLine: 'Editing theme.dart',
);
const _third = StatusChat(id: 's3', title: 'docs', liveLine: 'Reading files');
const _fourth = StatusChat(id: 's4', title: 'api');

void main() {
  group('one chat working', () {
    test('names what it does, with the tasks and a real progress bar', () {
      final status = _build(const NotificationStatusInput(working: [_tests]));
      expect(status.kind, NotificationStatusKind.working);
      expect(status.title, 'Running the tests');
      expect(status.text, 'UI review and feedback · 5 of 6 tasks');
      expect(status.subText, 'IPTV_King · 4 min');
      expect(status.progress, 83);
      expect(status.lines, isEmpty);
      expect(status.actions, [
        NotificationStatusAction.open,
        NotificationStatusAction.stopReply,
      ]);
      expect(status.sessionId, 's1');
    });

    test('without tasks there is no bar, never an endless spinner', () {
      final status = _build(
        const NotificationStatusInput(
          working: [
            StatusChat(id: 'a', title: 'Fix login', liveLine: 'Editing files'),
          ],
        ),
      );
      expect(status.progress, isNull);
      expect(status.title, 'Editing files');
      expect(status.text, 'Fix login');
    });

    test('a chat with no live line still says it is working', () {
      final status = _build(const NotificationStatusInput(working: [_fourth]));
      expect(status.title, 'Working…');
    });

    test('a long run is told in hours', () {
      final status = _build(
        const NotificationStatusInput(
          working: [StatusChat(id: 'a', elapsed: Duration(minutes: 135))],
        ),
      );
      expect(status.subText, '2 h');
    });
  });

  group('several chats working', () {
    test('two chats are two lines', () {
      final status = _build(
        const NotificationStatusInput(working: [_tests, _shop]),
      );
      expect(status.kind, NotificationStatusKind.severalWorking);
      expect(status.title, '2 conversations working');
      expect(status.lines, [
        'UI review and feedback · Running the tests',
        'shopfront · Editing theme.dart',
      ]);
      expect(status.progress, isNull);
      expect(status.actions, [NotificationStatusAction.open]);
      expect(status.sessionId, isEmpty);
    });

    test('three chats show two lines and "+1 more"', () {
      final status = _build(
        const NotificationStatusInput(working: [_tests, _shop, _third]),
      );
      expect(status.title, '3 conversations working');
      expect(status.lines, [
        'UI review and feedback · Running the tests',
        'shopfront · Editing theme.dart',
        '+1 more',
      ]);
    });

    test('five chats say "+3 more"', () {
      final status = _build(
        const NotificationStatusInput(
          working: [_tests, _shop, _third, _fourth, _fourth],
        ),
      );
      expect(status.lines.last, '+3 more');
    });
  });

  group('needs you', () {
    test('one request says whose it is and offers Open', () {
      final status = _build(
        const NotificationStatusInput(
          pendingCount: 1,
          firstPendingTitle: 'IPTV_King',
          firstPendingProject: 'docs',
        ),
      );
      expect(status.kind, NotificationStatusKind.needsYou);
      expect(status.title, '1 needs you');
      expect(status.text, 'IPTV_King · docs');
      expect(status.actions, [NotificationStatusAction.open]);
    });

    test('two requests use the plural', () {
      final status = _build(const NotificationStatusInput(pendingCount: 2));
      expect(status.title, '2 need you');
    });

    test('beats working and adds how many are still working', () {
      final status = _build(
        const NotificationStatusInput(
          pendingCount: 1,
          firstPendingTitle: 'docs',
          firstPendingProject: 'site',
          working: [_tests, _shop],
        ),
      );
      expect(status.kind, NotificationStatusKind.needsYou);
      expect(status.title, '1 needs you');
      expect(status.text, 'docs · site · 2 still working');
      expect(status.lines, [
        'UI review and feedback · Running the tests',
        'shopfront · Editing theme.dart',
      ]);
      expect(status.progress, isNull);
    });

    test('never repeats the request itself', () {
      final status = _build(
        const NotificationStatusInput(
          pendingCount: 1,
          firstPendingTitle: 'IPTV_King',
        ),
      );
      expect(status.text, isNot(contains('npm')));
      expect(status.text, isNot(contains('Run this')));
    });

    test('beats every pause and the reconnecting state', () {
      final status = _build(
        const NotificationStatusInput(
          pendingCount: 1,
          reconnecting: true,
          pause: NotificationPauseReason.androidLimit,
        ),
      );
      expect(status.kind, NotificationStatusKind.needsYou);
    });
  });

  group('waiting', () {
    test('names the provider and the time of the next try', () {
      final status = _build(
        NotificationStatusInput(
          retries: [
            StatusRetry(
              chatId: 's1',
              chatTitle: 'UI review and feedback',
              provider: 'Experiential Labs',
              nextTry: DateTime(2026, 10, 14, 13, 12),
            ),
          ],
        ),
      );
      expect(status.kind, NotificationStatusKind.waiting);
      expect(status.title, 'Waiting · Experiential Labs limit');
      expect(status.text, 'Tries again at 13:12 · UI review and feedback');
      expect(status.actions, [
        NotificationStatusAction.open,
        NotificationStatusAction.stopReply,
      ]);
      expect(status.sessionId, 's1');
      expect(status.progress, isNull);
    });

    test('without a provider or a time it still says so plainly', () {
      final status = _build(
        const NotificationStatusInput(
          retries: [StatusRetry(chatId: 's1', chatTitle: 'Fix login')],
        ),
      );
      expect(status.title, 'Waiting · the provider is busy');
      expect(status.text, 'Tries again soon · Fix login');
    });

    test('a time already past reads "soon"', () {
      final status = _build(
        NotificationStatusInput(
          retries: [
            StatusRetry(chatId: 's1', nextTry: DateTime(2026, 10, 14, 12)),
          ],
        ),
      );
      expect(status.text, 'Tries again soon');
    });

    test('shows the retry that comes first', () {
      final status = _build(
        NotificationStatusInput(
          retries: [
            StatusRetry(
              chatId: 'late',
              provider: 'B',
              nextTry: DateTime(2026, 10, 14, 14),
            ),
            StatusRetry(
              chatId: 'soon',
              provider: 'A',
              nextTry: DateTime(2026, 10, 14, 13, 10),
            ),
          ],
        ),
      );
      expect(status.sessionId, 'soon');
      expect(status.title, 'Waiting · A limit');
    });

    test('a working chat wins and notes that another one waits', () {
      final status = _build(
        const NotificationStatusInput(
          working: [_tests],
          retries: [StatusRetry(chatId: 's9', chatTitle: 'old')],
        ),
      );
      expect(status.kind, NotificationStatusKind.working);
      expect(status.text, 'UI review and feedback · 5 of 6 tasks · 1 waiting');
    });
  });

  group('paused', () {
    test('Android background limit', () {
      final status = _build(
        const NotificationStatusInput(
          pause: NotificationPauseReason.androidLimit,
        ),
      );
      expect(status.kind, NotificationStatusKind.pausedAndroid);
      expect(status.title, "Paused · Android's background limit");
      expect(status.text, contains('Open OpenCode'));
      expect(status.actions, [NotificationStatusAction.open]);
    });

    test('the limit beats a chat that was working', () {
      final status = _build(
        const NotificationStatusInput(
          pause: NotificationPauseReason.androidLimit,
          working: [_tests],
        ),
      );
      expect(status.kind, NotificationStatusKind.pausedAndroid);
    });

    test('phone is hot', () {
      final status = _build(
        const NotificationStatusInput(pause: NotificationPauseReason.phoneHot),
      );
      expect(status.kind, NotificationStatusKind.pausedHot);
      expect(status.title, 'Paused · phone is hot');
      expect(status.text, 'Resumes when it cools down');
      expect(status.actions, [NotificationStatusAction.open]);
    });

    test('hot does not hide chats that still work', () {
      final status = _build(
        const NotificationStatusInput(
          pause: NotificationPauseReason.phoneHot,
          working: [_tests],
        ),
      );
      expect(status.kind, NotificationStatusKind.working);
    });

    test('paused while idle offers Start', () {
      final status = _build(
        const NotificationStatusInput(pause: NotificationPauseReason.idle),
      );
      expect(status.kind, NotificationStatusKind.pausedIdle);
      expect(status.title, 'Paused · nothing was running');
      expect(status.text, 'Tap to start OpenCode again');
      expect(status.actions, [NotificationStatusAction.start]);
    });
  });

  group('reconnecting', () {
    test('one server is not named', () {
      final status = _build(
        const NotificationStatusInput(
          reconnecting: true,
          serverName: 'PC',
          reconnectingLastActivity: 'Running the tests',
        ),
      );
      expect(status.kind, NotificationStatusKind.reconnecting);
      expect(status.title, 'Reconnecting');
      expect(status.text, 'Running the tests');
    });

    test('several servers name the one that dropped', () {
      final status = _build(
        const NotificationStatusInput(
          reconnecting: true,
          serverName: 'PC',
          liveServerCount: 2,
        ),
      );
      expect(status.title, 'Reconnecting to PC');
      expect(status.text, 'Waiting for the connection');
    });

    test('beats working: the chats may not still be running', () {
      final status = _build(
        const NotificationStatusInput(reconnecting: true, working: [_tests]),
      );
      expect(status.kind, NotificationStatusKind.reconnecting);
    });
  });

  group('idle', () {
    test('ready, with the last reply and New chat', () {
      final status = _build(
        NotificationStatusInput(
          lastReplyAt: _now.subtract(const Duration(minutes: 12)),
          lastReplyTitle: 'UI review and feedback',
        ),
      );
      expect(status.kind, NotificationStatusKind.idle);
      expect(status.title, 'Ready · nothing running');
      expect(status.text, 'Last reply 12 min ago · UI review and feedback');
      expect(status.actions, [NotificationStatusAction.newChat]);
      expect(status.progress, isNull);
    });

    test('the phone server adds Stop OpenCode and says where it runs', () {
      final status = _build(
        NotificationStatusInput(
          phoneServerRunning: true,
          lastReplyAt: _now.subtract(const Duration(seconds: 20)),
        ),
      );
      expect(status.subText, 'on this phone');
      expect(status.text, 'Last reply just now');
      expect(status.actions, [
        NotificationStatusAction.newChat,
        NotificationStatusAction.stopServer,
      ]);
    });

    test('no reply yet', () {
      final status = _build(const NotificationStatusInput());
      expect(status.text, 'Ready when you are');
    });

    test('hours', () {
      final status = _build(
        NotificationStatusInput(
          lastReplyAt: _now.subtract(const Duration(hours: 3, minutes: 5)),
        ),
      );
      expect(status.text, 'Last reply 3 h ago');
    });
  });

  group('setup', () {
    test('step and percent, no actions beyond Open', () {
      final status = _build(
        const NotificationStatusInput(
          setup: StatusSetup(
            step: 4,
            steps: 5,
            name: 'Installing OpenCode',
            percent: 60,
          ),
        ),
      );
      expect(status.kind, NotificationStatusKind.setup);
      expect(status.title, 'Setup · 4 of 5');
      expect(status.text, 'Installing OpenCode');
      expect(status.progress, 60);
      expect(status.actions, [NotificationStatusAction.open]);
    });

    test('a working chat beats setup, setup beats ready', () {
      const setup = StatusSetup(step: 1, steps: 5);
      expect(
        _build(
          const NotificationStatusInput(setup: setup, working: [_tests]),
        ).kind,
        NotificationStatusKind.working,
      );
      expect(
        _build(const NotificationStatusInput(setup: setup)).kind,
        NotificationStatusKind.setup,
      );
    });
  });

  group('several servers', () {
    test('add "on <server>" beside the app name', () {
      final status = _build(
        const NotificationStatusInput(
          working: [_tests],
          liveServerCount: 2,
          serverName: 'PC',
        ),
      );
      expect(status.subText, 'IPTV_King · 4 min · on PC');
    });

    test('one server never names itself', () {
      final status = _build(
        const NotificationStatusInput(working: [_tests], serverName: 'PC'),
      );
      expect(status.subText, isNot(contains('PC')));
    });
  });

  group('lock screen', () {
    test('shows only counts, never titles, lines or the live line', () {
      final secret = _build(
        const NotificationStatusInput(
          pendingCount: 2,
          firstPendingTitle: 'Secret chat title',
          working: [
            StatusChat(
              id: 'x',
              title: 'Secret chat title',
              liveLine: 'Secret task text',
            ),
          ],
        ),
      );
      expect(secret.publicTitle, 'OpenCode · 2 need you');
      expect(secret.publicTitle, isNot(contains('Secret')));

      final working = _build(
        const NotificationStatusInput(
          working: [
            StatusChat(id: 'x', title: 'Secret chat title', liveLine: 'Secret'),
          ],
        ),
      );
      expect(working.publicTitle, '1 working');

      final waiting = _build(
        const NotificationStatusInput(
          retries: [StatusRetry(chatId: 'x', chatTitle: 'Secret chat title')],
        ),
      );
      expect(waiting.publicTitle, 'Waiting');
      expect(_build(const NotificationStatusInput()).publicTitle, 'Ready');
    });
  });

  group('payload and language', () {
    test('the payload carries exactly what Android reads', () {
      final payload = _build(
        const NotificationStatusInput(working: [_tests]),
      ).toPayload();
      expect(payload.keys.toSet(), {
        'kind',
        'title',
        'text',
        'lines',
        'subText',
        'progress',
        'actions',
        'sessionId',
        'publicTitle',
      });
      expect(payload['kind'], 'working');
      expect(payload['actions'], ['open', 'stop_reply']);
    });

    test('equal inputs give equal statuses', () {
      const input = NotificationStatusInput(working: [_tests, _shop]);
      expect(_build(input), _build(input));
      expect(_build(input).hashCode, _build(input).hashCode);
      expect(
        _build(input),
        isNot(_build(const NotificationStatusInput(working: [_tests]))),
      );
    });

    test('Arabic copy is used when the language is Arabic', () {
      final status = _build(
        const NotificationStatusInput(pause: NotificationPauseReason.phoneHot),
        l10n: _ar,
      );
      expect(status.title, isNot('Paused · phone is hot'));
      expect(status.title, contains('ساخن'));
    });
  });
}
