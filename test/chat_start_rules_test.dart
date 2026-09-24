import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';

List<String> _labels(ChatStartFacts facts, [AppLocalizations? l10n]) => [
  for (final starter in chatStartSuggestions(facts, l10n: l10n)) starter.label,
];

void main() {
  group('starters', () {
    test('an empty folder gets ways to make something', () {
      // A folder created a second ago has no bugs and no history.
      expect(
        _labels(
          const ChatStartFacts(
            directory: '/root/projects/my-app',
            entries: 0,
            git: true,
          ),
        ),
        [
          'Build a small web page',
          'Write a Python script that…',
          'Start a Node.js project',
          'Set up a README',
        ],
      );
    });

    test('a folder with files gets ways to work on them', () {
      expect(
        _labels(const ChatStartFacts(directory: '/work/oc_app', entries: 12)),
        ['Explain this project', 'Find and fix a bug', 'Add tests'],
      );
    });

    test('"what changed recently" needs Git history', () {
      expect(
        _labels(
          const ChatStartFacts(
            directory: '/work/oc_app',
            entries: 12,
            git: true,
            hasHistory: true,
          ),
        ),
        [
          'Explain this project',
          'What changed recently?',
          'Find and fix a bug',
          'Add tests',
        ],
      );
      // A repository without a commit has nothing recent to read.
      expect(
        _labels(
          const ChatStartFacts(
            directory: '/work/oc_app',
            entries: 12,
            git: true,
          ),
        ),
        isNot(contains('What changed recently?')),
      );
    });

    test('an unknown listing is treated as a folder with files', () {
      // Backends without file browsing still get useful starters.
      expect(_labels(const ChatStartFacts(directory: '/work/oc_app')), [
        'Explain this project',
        'Find and fix a bug',
        'Add tests',
      ]);
    });

    test('nothing is offered while the folder is being looked at', () {
      expect(
        chatStartSuggestions(const ChatStartFacts.pending('/work/oc_app')),
        isEmpty,
      );
    });

    test('no project and the projects root are not asked about', () {
      // A fresh server with zero projects serves its own default folder,
      // and the phone's folder of projects is not a project either.
      for (final directory in [null, '', '   ', '/root/projects']) {
        expect(_labels(ChatStartFacts(directory: directory, entries: 4)), [
          "List what's in this folder",
          'Find and fix a bug',
        ]);
      }
      expect(
        _labels(
          const ChatStartFacts(
            directory: '/root/projects/FinanceHub3',
            entries: 0,
          ),
        ).first,
        'Build a small web page',
      );
    });

    test('an unfinished sentence goes in with a space, not an ellipsis', () {
      expect(
        const ChatStarter('Write a Python script that…').text,
        'Write a Python script that ',
      );
      expect(const ChatStarter('Add tests').text, 'Add tests');
    });

    test('Arabic starters are Arabic', () {
      final ar = lookupAppLocalizations(const Locale('ar'));
      expect(
        _labels(
          const ChatStartFacts(directory: '/root/projects/my-app', entries: 0),
          ar,
        ),
        [
          ar.chatStartBuildWebPage,
          ar.chatStartPythonScript,
          ar.chatStartNodeProject,
          ar.chatStartReadme,
        ],
      );
      expect(
        const ChatStarter('اكتب سكربت بايثون…').text,
        'اكتب سكربت بايثون ',
      );
    });
  });

  group('project name', () {
    test('trailing slashes and Windows separators still yield the name', () {
      expect(
        const ChatStartFacts(directory: '/work/oc_app/').projectName,
        'oc_app',
      );
      expect(
        const ChatStartFacts(directory: r'C:\work\oc_app').projectName,
        'oc_app',
      );
      expect(const ChatStartFacts(directory: '  ').projectName, isNull);
    });
  });

  group('facts line', () {
    test('an empty Git folder', () {
      expect(
        chatStartFactsLine(
          const ChatStartFacts(directory: '/p/my-app', entries: 0, git: true),
        ),
        'Empty folder · Git',
      );
    });

    test('files, Git and changes', () {
      expect(
        chatStartFactsLine(
          const ChatStartFacts(
            directory: '/p/app',
            entries: 24,
            git: true,
            changes: 3,
          ),
        ),
        '24 items · Git · 3 changes',
      );
      expect(
        chatStartFactsLine(
          const ChatStartFacts(
            directory: '/p/app',
            entries: 1,
            git: true,
            changes: 1,
          ),
        ),
        '1 item · Git · 1 change',
      );
    });

    test('a clean tree and a folder without Git say less', () {
      expect(
        chatStartFactsLine(
          const ChatStartFacts(
            directory: '/p/app',
            entries: 5,
            git: true,
            changes: 0,
          ),
        ),
        '5 items · Git',
      );
      expect(
        chatStartFactsLine(
          const ChatStartFacts(directory: '/p/app', entries: 5, git: false),
        ),
        '5 items',
      );
    });

    test('nothing known is nothing said; pending says it is looking', () {
      expect(
        chatStartFactsLine(const ChatStartFacts(directory: '/p/app')),
        isNull,
      );
      expect(
        chatStartFactsLine(const ChatStartFacts.pending('/p/app')),
        'Looking at the folder…',
      );
    });

    test('Arabic counts use Arabic plurals', () {
      final ar = lookupAppLocalizations(const Locale('ar'));
      expect(
        chatStartFactsLine(
          const ChatStartFacts(
            directory: '/p/app',
            entries: 3,
            git: true,
            changes: 2,
          ),
          l10n: ar,
        ),
        '3 عناصر · Git · تغييران',
      );
    });
  });
}
