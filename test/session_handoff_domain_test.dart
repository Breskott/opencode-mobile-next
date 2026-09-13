import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/session_handoff.dart';

void main() {
  group('SessionResumeCommand', () {
    test('OpenCode 1 resumes with cd and --session', () {
      final command = SessionResumeCommand.build(
        cli: SessionResumeCli.openCode1,
        sessionID: 'ses_0123abc',
        directory: '/srv/project',
      );
      expect(command.available, isTrue);
      expect(command.unavailable, isNull);
      expect(
        command.command,
        "cd '/srv/project' && opencode --session 'ses_0123abc'",
      );
      expect(command.binary, 'opencode');
    });

    test('OpenCode 2 uses the opencode2 binary with the same flags', () {
      final command = SessionResumeCommand.build(
        cli: SessionResumeCli.openCode2,
        sessionID: 'ses_0123abc',
        directory: '/srv/project',
      );
      expect(
        command.command,
        "cd '/srv/project' && opencode2 --session 'ses_0123abc'",
      );
      expect(command.binary, 'opencode2');
    });

    test('directories with spaces and shell metacharacters are quoted', () {
      final command = SessionResumeCommand.build(
        cli: SessionResumeCli.openCode1,
        sessionID: 'ses_1',
        directory: r'/home/dev/My Projects/acme $HOME `x`',
      );
      expect(
        command.command,
        "cd '/home/dev/My Projects/acme \$HOME `x`' && opencode --session 'ses_1'",
      );
    });

    test("a single quote inside the directory becomes '\\''", () {
      final command = SessionResumeCommand.build(
        cli: SessionResumeCli.openCode2,
        sessionID: 'ses_1',
        directory: "/home/dev/it's here",
      );
      expect(
        command.command,
        "cd '/home/dev/it'\\''s here' && opencode2 --session 'ses_1'",
      );
    });

    test('a worktree session resumes inside the worktree directory', () {
      final command = SessionResumeCommand.build(
        cli: SessionResumeCli.openCode1,
        sessionID: 'ses_wt',
        directory: '/srv/project/.worktrees/feature-x',
        workspaceID: null,
      );
      expect(
        command.command,
        "cd '/srv/project/.worktrees/feature-x' && opencode --session 'ses_wt'",
      );
    });

    test('a managed workspace session is unavailable, not guessed', () {
      final command = SessionResumeCommand.build(
        cli: SessionResumeCli.openCode2,
        sessionID: 'ses_ws',
        directory: '/workspace/project',
        workspaceID: 'wrk_abc',
      );
      expect(command.available, isFalse);
      expect(command.command, isNull);
      expect(command.unavailable, SessionResumeUnavailable.managedWorkspace);
    });

    test('a missing or blank directory is unavailable', () {
      for (final directory in [null, '', '   ']) {
        final command = SessionResumeCommand.build(
          cli: SessionResumeCli.openCode1,
          sessionID: 'ses_1',
          directory: directory,
        );
        expect(command.available, isFalse, reason: 'directory=$directory');
        expect(
          command.unavailable,
          SessionResumeUnavailable.missingDirectory,
          reason: 'directory=$directory',
        );
      }
    });

    test('control characters in the directory are refused', () {
      final command = SessionResumeCommand.build(
        cli: SessionResumeCli.openCode1,
        sessionID: 'ses_1',
        directory: '/srv/proj\necho pwned',
      );
      expect(command.unavailable, SessionResumeUnavailable.unsafeDirectory);
    });

    test('session ids that could read as flags or shell text are refused', () {
      for (final id in ['-s', '--auto', 'ses 1', "ses'1", '', 'ses\$(x)']) {
        final command = SessionResumeCommand.build(
          cli: SessionResumeCli.openCode2,
          sessionID: id,
          directory: '/srv/project',
        );
        expect(
          command.unavailable,
          SessionResumeUnavailable.invalidSessionID,
          reason: 'id=$id',
        );
      }
    });
  });

  group('SessionLink', () {
    test('round-trips profile and session ids only', () {
      final link = SessionLink.tryCreate(
        profileID: '1757500000000000',
        sessionID: 'ses_abc-123',
      );
      expect(link, isNotNull);
      expect(
        link.toString(),
        'opencode-mobile://session?profile=1757500000000000&session=ses_abc-123',
      );
      expect(SessionLink.parse(link.toString()), link);
    });

    test('refuses ids that are not plain identifiers', () {
      expect(
        SessionLink.tryCreate(profileID: 'a b', sessionID: 'ses_1'),
        isNull,
      );
      expect(SessionLink.tryCreate(profileID: 'p1', sessionID: '-ses'), isNull);
      expect(SessionLink.tryCreate(profileID: null, sessionID: 'x'), isNull);
    });

    test('parses only the exact link shape', () {
      expect(
        SessionLink.parse('opencode-mobile://session?profile=p1&session=s1'),
        const SessionLink(profileID: 'p1', sessionID: 's1'),
      );
      expect(
        SessionLink.parse('OPENCODE-MOBILE://SESSION?profile=p1&session=s1'),
        const SessionLink(profileID: 'p1', sessionID: 's1'),
      );
      expect(
        SessionLink.parse(
          '  opencode-mobile://session/?profile=p1&session=s1  ',
        ),
        const SessionLink(profileID: 'p1', sessionID: 's1'),
      );
    });

    test('malformed links are ignored safely', () {
      final rejected = <Object?>[
        null,
        42,
        '',
        'not a link',
        'https://example.test/session?profile=p1&session=s1',
        'opencode-mobile://server?profile=p1&session=s1',
        'opencode-mobile://session?profile=p1',
        'opencode-mobile://session?session=s1',
        'opencode-mobile://session?profile=&session=s1',
        'opencode-mobile://session?profile=p1&session=s1&session=s2',
        'opencode-mobile://session/extra?profile=p1&session=s1',
        'opencode-mobile://session?profile=p1&session=s1#frag',
        'opencode-mobile://user@session?profile=p1&session=s1',
        'opencode-mobile://session:99?profile=p1&session=s1',
        'opencode-mobile://session?profile=p%201&session=s1',
        'opencode-mobile://session?profile=p1&session=%2Dflag',
        'opencode-mobile://session?profile=p1&session=s1&token=abc',
      ];
      for (final raw in rejected) {
        final parsed = SessionLink.parse(raw);
        if (raw ==
            'opencode-mobile://session?profile=p1&session=s1&token=abc') {
          // Extra parameters are dropped, never carried: the link still
          // resolves to its ids only.
          expect(parsed, const SessionLink(profileID: 'p1', sessionID: 's1'));
          continue;
        }
        expect(parsed, isNull, reason: 'raw=$raw');
      }
    });

    test('a very long link is ignored', () {
      final raw = 'opencode-mobile://session?profile=p1&session=${'a' * 2000}';
      expect(SessionLink.parse(raw), isNull);
    });
  });
}
