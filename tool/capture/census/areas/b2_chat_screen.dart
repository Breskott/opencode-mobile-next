// Census scenes for the ledger part `b2-chat-screen`
// (docs/design/ui-ledger/parts/b2-chat-screen.json). See tool/capture/census_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';

import '../../fixtures.dart';
import '../census_core.dart';
import '../support/b1_chat_screen_support.dart';

const _subagents = [
  CatalogAgent(
    id: 'explore',
    mode: 'subagent',
    description: 'Reads the codebase and answers questions about it',
    hidden: false,
  ),
  CatalogAgent(
    id: 'reviewer',
    mode: 'subagent',
    description: 'Reviews a diff for bugs and missing tests',
    hidden: false,
    color: '#7C8CF8',
  ),
  CatalogAgent(
    id: 'test-runner',
    mode: 'subagent',
    description: 'Runs the test suite and summarises failures',
    hidden: false,
    model: 'anthropic/claude-haiku-3-5',
  ),
];

Future<void> _longPressPrompt(CensusKit kit) async {
  await kit.longPress(find.text(userPrompt));
  kit.expectVisible(find.byKey(const ValueKey('message-action-delete')));
}

final b2ChatScreenArea = CensusArea(
  'b2-chat-screen',
  shots: [
    CensusShot(
      'chat-message-actions-sheet',
      state: 'prompt',
      (kit) async {
        await openChat(kit);
        await _longPressPrompt(kit);
        kit.expectVisible(find.byKey(const ValueKey('message-action-fork')));
      },
      note: 'Long-press on your own prompt.',
    ),
    CensusShot(
      'chat-message-actions-sheet',
      state: 'reply',
      (kit) async {
        await openChat(kit);
        await kit.tapKey('message-actions-msg_assistant');
        kit.expectVisible(find.byKey(const ValueKey('message-action-copy')));
      },
      note:
          'The ⋯ button under the assistant reply (same sheet as a long-press).',
    ),
    CensusShot('chat-delete-message-sheet', (kit) async {
      await openChat(kit);
      await _longPressPrompt(kit);
      await kit.tapKey('message-action-delete');
      kit.expectText('Delete this message?');
    }, note: 'Long-press a prompt › Delete message.'),
    CensusShot(
      'chat-revert-confirm-sheet',
      (kit) async {
        await openChat(kit);
        await sessionMenuAction(kit, 'Revert last prompt');
        kit.expectText('Revert from this prompt?');
      },
      note:
          'Conversation menu › Conversation actions › Revert last prompt '
          '(OpenCode 1, no staged revert).',
    ),
    CensusShot(
      'chat-run-shell-dialog',
      (kit) async {
        await openChat(kit);
        await sessionMenuAction(kit, 'Run shell command');
        kit.expectVisible(find.byType(AlertDialog));
        await kit.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
          checkoutCommand,
        );
      },
      note: 'Conversation menu › Run shell command, with a command typed.',
    ),
    CensusShot('command-launcher-sheet', state: 'commands', (kit) async {
      await openChat(kit);
      await openCommandLauncher(kit);
      kit.expectText('Commands and agents');
    }, note: 'Composer + › Commands.'),
    CensusShot(
      'command-launcher-sheet',
      state: 'search',
      (kit) async {
        await openChat(kit);
        await openCommandLauncher(kit);
        await kit.enterText(
          find.byKey(const Key('command-launcher-search')),
          'share',
        );
        kit.expectText('Commands and agents');
      },
      note:
          'Typing filters the commands (and would list "Go to" results '
          'from the rest of the app when any match).',
    ),
    CensusShot(
      'command-launcher-sheet',
      state: 'delegate',
      (kit) async {
        await openChat(
          kit,
          configure: (c) => c.catalog = CatalogSnapshot(
            providers: sampleCatalog().providers,
            models: sampleCatalog().models,
            agents: _subagents,
          ),
        );
        await openCommandLauncher(kit);
        await kit.tapKey('composer-tools-agents-tab');
        kit.expectVisible(find.byKey(const Key('composer-agent-reviewer')));
      },
      note: 'The Delegate tab with three server subagents.',
    ),
    CensusShot('chat-rename-session-dialog', (kit) async {
      await openChat(kit);
      await openCommandLauncher(kit);
      await kit.enterText(
        find.byKey(const Key('command-launcher-search')),
        'rename',
      );
      await kit.tapKey('command-mobile-rename');
      kit.expectText('Rename conversation');
      kit.expectVisible(find.byType(AlertDialog));
    }, note: 'Commands › /rename.'),
    CensusShot(
      'session-menu-sheet',
      state: 'closed',
      (kit) async {
        await openChat(kit);
        await openSessionMenu(kit);
        kit.expectText('Conversation actions');
      },
      note: 'The chat app bar overflow, sections folded.',
    ),
    CensusShot('session-menu-sheet', state: 'actions', (kit) async {
      await openChat(kit);
      await openSessionMenu(kit);
      await kit.tapText('Conversation actions');
      kit.expectText('Run shell command');
    }, note: 'Conversation actions unfolded.'),
    CensusShot(
      'session-menu-sheet',
      state: 'display',
      (kit) async {
        await openChat(kit);
        await openSessionMenu(kit);
        await kit.tapText('Display and context');
        kit.expectText('Context usage');
      },
      note: 'Display and context unfolded (transcript toggles).',
    ),
    CensusShot(
      'chat-leave-unsaved-draft-sheet',
      (kit) async {
        final controller = await openChat(kit, pushed: true);
        controller.refuseDraftWrites = true;
        await kit.enterText(
          find.byKey(const Key('chat-composer-field')),
          'Keep the basket after reopening the app',
        );
        await kit.settle();
        await kit.tapTooltip('Back');
        kit.expectVisible(find.byKey(const ValueKey('leave-unsaved-draft')));
      },
      note:
          'Back while the draft cannot be written (faked storage refusal); '
          'the composer shows the unsaved-draft row too.',
    ),
  ],
  notRendered: {},
);
