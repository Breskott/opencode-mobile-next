// Census scenes for the ledger part `c-chat-compose`
// (docs/design/ui-ledger/parts/c-chat-compose.json). See tool/capture/census_test.dart.
//
// The composer and message-view pieces of ChatScreen and their sheets, all
// rendered inside the real ChatScreen over the capture fixtures; private
// sheets are opened by tapping the real controls.
//
// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/nudges.dart';
import 'package:opencode_mobile/state/offline_queue.dart';
import 'package:opencode_mobile/state/prompt_shelf.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';

import '../../fixtures.dart';
import '../census_core.dart';

// ---------------------------------------------------------------------------
// Fakes and sample data
// ---------------------------------------------------------------------------

/// The capture API with a one-page history, an optional capability set (an
/// OpenCode 2 inbox for the Steer/Queue control) and a send that can fail.
class _Api extends CaptureApi {
  ServerCapabilities? caps;

  @override
  ServerCapabilities get capabilities => caps ?? super.capabilities;

  @override
  Future<ServerPage<MessageWithParts>> messagePage(
    String id, {
    String? cursor,
    int limit = 100,
  }) async => ServerPage(items: cursor == null ? await messages(id) : const []);
}

const _childSessionID = 'ses_checkout_explore';
const _shareUrl = 'https://opncd.ai/s/shopfront-demo';

MessageWithParts _user(String id, String text, int created) => MessageWithParts(
  info: messageInfo(id, 'user', created: created, completed: created),
  parts: [Part(id: '$id-text', messageID: id, type: 'text', text: text)],
);

MessageWithParts _reply(String id, String text, int created) =>
    MessageWithParts(
      info: messageInfo(
        id,
        'assistant',
        created: created,
        completed: created + 20 * 1000,
      ),
      parts: [Part(id: '$id-text', messageID: id, type: 'text', text: text)],
    );

/// Two earlier turns, then the sample checkout turn: three prompts to reuse.
List<MessageWithParts> _longTranscript() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return [
    _user(
      'msg_u1',
      'Where does the cart total get computed?',
      now - 20 * 60 * 1000,
    ),
    _reply(
      'msg_a1',
      'In `CartRepository.total()`, which sums the line items and applies '
          'the active coupon.',
      now - 19 * 60 * 1000,
    ),
    _user(
      'msg_u2',
      'Add a test for a coupon that expires mid-checkout',
      now - 10 * 60 * 1000,
    ),
    _reply(
      'msg_a2',
      'Added `coupon_expiry_test.dart`; it passes locally.',
      now - 9 * 60 * 1000,
    ),
    ...sampleTranscript(),
  ];
}

/// A turn that ended on a model the server does not know.
List<MessageWithParts> _modelErrorTurn() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return [
    sampleTranscript().first,
    MessageWithParts(
      info: MessageInfo(
        id: 'msg_assistant',
        sessionID: checkoutSessionID,
        role: 'assistant',
        providerID: 'openai',
        modelID: 'gpt-5.6',
        time: MsgTime(created: now - 80 * 1000, completed: now - 79 * 1000),
        errorText:
            'ProviderModelNotFoundError: Model not found: openai/gpt-5.6. '
            'Did you mean: gpt-5.6-pro?\n'
            '    at resolveModel (/\$bunfs/root/provider.js:212:11)\n'
            '    at async prompt (/\$bunfs/root/session.js:439:1)',
        errorKind: MessageErrorKind.modelNotFound,
      ),
      parts: const [],
    ),
  ];
}

/// Mounts the real ChatScreen for [sessionID] over [api] and settles.
Future<CaptureController> _chat(
  CensusKit kit, {
  _Api? api,
  String sessionID = checkoutSessionID,
  Map<String, Object> prefValues = const {},
  Future<void> Function(CaptureController controller)? before,
  Duration settleFor = const Duration(seconds: 2),
}) async {
  final source =
      api ??
      (_Api()
        ..busy = {}
        ..messagesHandler = (_) async => sampleTranscript());
  final controller = await kit.connected(api: source, prefValues: prefValues);
  if (before != null) await before(controller);
  await kit.pumpApp(
    ChatScreen(sessionID: sessionID),
    controller: controller,
    settleFor: settleFor,
  );
  return controller;
}

final _composerField = find.byKey(const Key('chat-composer-field'));

Future<void> _type(CensusKit kit, String text) async {
  await kit.tap(_composerField, settleFor: const Duration(milliseconds: 300));
  await kit.enterText(_composerField, text);
  await kit.settle(const Duration(milliseconds: 500));
}

/// Types [draft] (if any) and opens the prompt tools sheet with "+".
Future<void> _openTools(CensusKit kit, {String? draft}) async {
  if (draft != null) await _type(kit, draft);
  await kit.tapKey('composer-tools-button');
  kit.expectVisible(find.byKey(const Key('composer-tools-sheet')));
}

/// Opens the message-actions sheet of the assistant reply and picks
/// "Read reply prose".
Future<void> _startReadAloud(CensusKit kit) async {
  await kit.tapKey('message-actions-msg_assistant');
  await kit.tapText('Read reply prose');
}

void _mockVoices(CensusKit kit) {
  kit.mockChannel('oc/read-aloud', (call) async {
    if (call.method == 'voices') {
      return [
        {
          'id': 'en-us-x-iol-local',
          'label': 'English (US) · voice 1',
          'locale': 'en-US',
        },
        {
          'id': 'en-us-x-tpd-local',
          'label': 'English (US) · voice 2',
          'locale': 'en-US',
        },
        {
          'id': 'en-gb-x-rjs-local',
          'label': 'English (UK) · voice 1',
          'locale': 'en-GB',
        },
        {
          'id': 'ar-xa-x-ard-local',
          'label': 'Arabic · voice 1',
          'locale': 'ar',
        },
      ];
    }
    return null;
  });
}

/// Two prompts on the shelf of the capture profile.
Future<void> _seedStash(CensusKit kit, CaptureController controller) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await kit.tester.runAsync(() async {
    await controller.savePromptStash(
      StashedPrompt(
        id: 'stash-coupon',
        text:
            'Refactor the coupon flow so an expired coupon shows an inline '
            'error instead of failing the whole checkout.',
        createdAt: now - 2 * 60 * 60 * 1000,
        directory: projectDirectory,
      ),
      locationRevision: controller.locationRevision,
    );
    await controller.savePromptStash(
      StashedPrompt(
        id: 'stash-a11y',
        text: 'Audit the payment form for TalkBack labels and focus order.',
        createdAt: now - 26 * 60 * 60 * 1000,
        directory: projectDirectory,
      ),
      locationRevision: controller.locationRevision,
    );
  });
}

Future<void> _openStash(CensusKit kit) async {
  await _openTools(kit);
  await kit.tapKey('composer-tools-prompts');
  await kit.tapKey('composer-tool-saved');
  await kit.realWait();
  kit.expectText('Saved prompts');
}

Future<bool> _queue(
  CaptureController controller,
  String id,
  String text, {
  required int agoMinutes,
  String? error,
  bool dispatched = false,
}) {
  final created = DateTime.now().millisecondsSinceEpoch - agoMinutes * 60000;
  return controller.queuePrompt(
    QueuedPrompt(
      id: id,
      profileID: 'laptop',
      sessionID: checkoutSessionID,
      text: text,
      createdAt: created,
      error: error,
      dispatchedAt: dispatched ? created + 1000 : null,
    ),
  );
}

Future<void> _openSessionMenu(CensusKit kit) async {
  await kit.tapKey('session-actions-button');
}

Future<void> _openFind(CensusKit kit) async {
  await _openSessionMenu(kit);
  await kit.tapText('Find in conversation');
  kit.expectVisible(find.byKey(const ValueKey('transcript-find-bar')));
}

Future<void> _promptError(CensusKit kit, CaptureController controller) async {
  controller.handleEventForTesting(
    captureEvent('session.error', {
      'sessionID': checkoutSessionID,
      'error': {
        'name': 'ProviderModelNotFoundError',
        'data': {
          'message':
              'ProviderModelNotFoundError: Model not found: openai/gpt-5.6. '
              'Did you mean: gpt-5.6-pro?\n'
              '    at resolveModel (/\$bunfs/root/provider.js:212:11)\n'
              '    at async prompt (/\$bunfs/root/session.js:439:1)',
        },
      },
    }),
  );
  await kit.settle();
  kit.expectVisible(find.byKey(const ValueKey('prompt-error-banner')));
}

_Api _errorlessUserOnly() => _Api()
  ..busy = {}
  ..messagesHandler = (_) async => [sampleTranscript().first];

// ---------------------------------------------------------------------------
// The area
// ---------------------------------------------------------------------------

final cChatComposeArea = CensusArea(
  'c-chat-compose',
  shots: [
    // -- embedded-composer ---------------------------------------------------
    CensusShot(
      'embedded-composer',
      state: 'draft',
      (kit) async {
        await _chat(kit);
        await _type(
          kit,
          'Keep the basket after reopening.\n'
          'Show a useful empty state.\n'
          'Check keyboard navigation.',
        );
        kit.expectVisible(find.byKey(const Key('prompt-editor-button')));
      },
      note: 'Host: ChatScreen after a finished turn, a three-line draft typed.',
    ),
    CensusShot(
      'embedded-composer',
      state: 'slash-commands',
      (kit) async {
        await _chat(kit);
        await _type(kit, '/');
        kit.expectText('Show all commands');
      },
      note: 'Host: ChatScreen; "/" typed opens the inline command list.',
    ),
    CensusShot(
      'embedded-composer',
      state: 'working',
      (kit) async {
        await _chat(
          kit,
          api: _Api()
            ..messagesHandler = (_) async => sampleTranscript(streaming: true),
        );
        kit.expectVisible(find.byKey(const Key('chat-stop-button')));
      },
      note: 'Host: ChatScreen while a run streams: Stop, activity ring.',
    ),
    CensusShot(
      'embedded-composer',
      state: 'working-steer-queue',
      (kit) async {
        await _chat(
          kit,
          api: _Api()
            ..caps = const ServerCapabilities(
              clientPromptMessageID: true,
              inbox: true,
            )
            ..messagesHandler = (_) async => sampleTranscript(streaming: true),
        );
        await _type(kit, 'Also check the coupon field on small phones');
        kit.expectText('Steer');
      },
      note:
          'Host: ChatScreen on a server with an inbox (OpenCode 2 capability '
          'faked on the v1 fixture) while a run streams, a draft typed: the '
          'Steer | Queue control.',
    ),

    // -- prompt-tools-sheet --------------------------------------------------
    CensusShot('prompt-tools-sheet', state: 'default', (kit) async {
      await _chat(kit);
      await _openTools(kit);
      kit.expectText('Prompt tools');
    }),
    CensusShot('prompt-tools-sheet', state: 'advanced', (kit) async {
      await _chat(kit);
      await _openTools(kit);
      await kit.tapKey('composer-tools-advanced');
      kit.expectText('Prompt tools');
    }, note: 'Advanced group expanded.'),
    CensusShot(
      'prompt-tools-sheet',
      state: 'prompts',
      (kit) async {
        await _chat(kit);
        await _openTools(kit, draft: 'Run the checkout tests on CI too');
        await kit.tapKey('composer-tools-prompts');
        kit.expectVisible(find.byKey(const Key('composer-tool-stash')));
      },
      note: 'A draft typed; the Prompts group expanded.',
    ),

    // -- prompt-editor and its discard sheet ---------------------------------
    CensusShot('prompt-editor', (kit) async {
      await _chat(kit);
      await _type(
        kit,
        'Fix the flaky checkout test.\n\n'
        'Constraints:\n'
        '- keep the public API of CheckoutBloc\n'
        '- no fixed delays in tests\n'
        '- run the whole checkout suite before you finish',
      );
      await kit.tapKey('prompt-editor-button');
      kit.expectVisible(find.byKey(const Key('prompt-editor-screen')));
    }, note: 'Opened from the composer with a multi-line draft.'),
    CensusShot('prompt-editor-discard-sheet', (kit) async {
      await _chat(kit);
      await _type(kit, 'Fix the flaky checkout test.');
      await kit.tapKey('prompt-editor-button');
      await kit.enterText(
        find.byKey(const Key('prompt-editor-field')),
        'Fix the flaky checkout test, then speed up the suite.',
      );
      await kit.tapTooltip('Close prompt editor');
      kit.expectText('Discard prompt changes?');
    }),

    // -- prompt-history-sheet ------------------------------------------------
    CensusShot(
      'prompt-history-sheet',
      (kit) async {
        await _chat(
          kit,
          api: _Api()
            ..busy = {}
            ..messagesHandler = (_) async => _longTranscript(),
        );
        await _openTools(kit);
        await kit.tapKey('composer-tools-prompts');
        await kit.tapKey('composer-tool-history');
        kit.expectText('Reuse a prompt');
      },
      note: 'Three prompts sent earlier in this conversation.',
    ),

    // -- prompt-stash-sheet and delete ---------------------------------------
    CensusShot('prompt-stash-sheet', state: 'loaded', (kit) async {
      await _chat(kit, before: (c) => _seedStash(kit, c));
      await _openStash(kit);
      kit.expectVisible(find.byKey(const ValueKey('restore-stash-stash-a11y')));
    }),
    CensusShot('prompt-stash-sheet', state: 'empty', (kit) async {
      await _chat(kit);
      await _openStash(kit);
    }),
    // -- embedded-transcript-find-bar ----------------------------------------
    CensusShot(
      'embedded-transcript-find-bar',
      state: 'open',
      (kit) async {
        await _chat(kit);
        await _openFind(kit);
      },
      note: 'Host: ChatScreen; opened from the conversation menu.',
    ),
    CensusShot(
      'embedded-transcript-find-bar',
      state: 'matches',
      (kit) async {
        await _chat(kit);
        await _openFind(kit);
        await kit.enterText(
          find.byKey(const ValueKey('transcript-find-input')),
          'checkout',
        );
        await kit.settle();
        kit.expectTextContaining('of');
      },
      note: '"checkout" typed: match count and navigation.',
    ),
    CensusShot('embedded-transcript-find-bar', state: 'no-match', (kit) async {
      await _chat(kit);
      await _openFind(kit);
      await kit.enterText(
        find.byKey(const ValueKey('transcript-find-input')),
        'webhook',
      );
      await kit.settle();
    }),

    // -- read aloud ----------------------------------------------------------
    CensusShot(
      'chat-read-aloud-consent-sheet',
      (kit) async {
        _mockVoices(kit);
        await _chat(kit);
        await _startReadAloud(kit);
        kit.expectText('Use the system speech engine?');
      },
      note: 'Message actions of the reply › Read reply prose.',
    ),
    CensusShot(
      'chat-read-aloud-voice-sheet',
      (kit) async {
        _mockVoices(kit);
        await _chat(kit);
        await _startReadAloud(kit);
        // Consent reads with the voice for the app's language (P10.4); the
        // choice is "Read with another voice".
        await kit.tapText('Read aloud');
        await kit.realWait();
        await kit.tapKey('message-actions-msg_assistant');
        await kit.tapText('Read with another voice');
        await kit.realWait();
        kit.expectText('Choose a reading voice');
      },
      note: 'Four offline voices from a mocked system engine.',
    ),

    // -- embedded-transcript-display-toggles ---------------------------------
    CensusShot(
      'embedded-transcript-display-toggles',
      (kit) async {
        await _chat(kit);
        await _openSessionMenu(kit);
        await kit.tapText('Display and context');
        kit.expectVisible(find.byKey(const ValueKey('session-view-thinking')));
      },
      note: 'Host: the conversation menu, Display and context expanded.',
    ),

    // -- prompt error banner and its details ---------------------------------
    CensusShot(
      'embedded-prompt-error-banner',
      (kit) async {
        final controller = await _chat(kit, api: _errorlessUserOnly());
        await _promptError(kit, controller);
      },
      note:
          'Host: ChatScreen; the server refused the prompt (unknown model) '
          'with no reply to carry the error.',
    ),
    CensusShot('chat-prompt-error-details-dialog', (kit) async {
      final controller = await _chat(kit, api: _errorlessUserOnly());
      await _promptError(kit, controller);
      final details = find.byKey(const ValueKey('prompt-error-details'));
      if (details.evaluate().isEmpty) await kit.tapTooltip('More');
      await kit.tap(details);
      kit.expectText('Error details');
    }),

    // -- subagent and shared banners -----------------------------------------
    CensusShot(
      'embedded-subagent-context-banner',
      (kit) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final api = _Api()
          ..busy = {}
          ..messagesHandler = (id) async => [
            _reply(
              'msg_child_1',
              'The coupon validation lives in `lib/checkout/coupon.dart`; '
                  'expiry is checked only on apply, not at payment.',
              now - 3 * 60 * 1000,
            ),
          ];
        api.sessionsById[_childSessionID] = Session(
          id: _childSessionID,
          parentID: checkoutSessionID,
          title: 'Explore coupon validation',
          directory: projectDirectory,
          time: SessionTime(created: now - 5 * 60 * 1000, updated: now),
        );
        api.sessionsById['ses_checkout_review'] = Session(
          id: 'ses_checkout_review',
          parentID: checkoutSessionID,
          title: 'Review the checkout diff',
          directory: projectDirectory,
          time: SessionTime(created: now - 4 * 60 * 1000, updated: now),
        );
        await _chat(kit, api: api, sessionID: _childSessionID);
        kit.expectTextContaining('Subagent');
      },
      note: 'Host: a delegated (child) conversation, one of two siblings.',
    ),
    CensusShot(
      'embedded-shared-session-banner',
      (kit) async {
        final api = _Api()
          ..busy = {}
          ..messagesHandler = (_) async => sampleTranscript();
        final base = api.sessionsById[checkoutSessionID]!;
        api.sessionsById[checkoutSessionID] = Session(
          id: base.id,
          title: base.title,
          directory: base.directory,
          time: base.time,
          cost: base.cost,
          summary: base.summary,
          model: base.model,
          agent: base.agent,
          shareUrl: _shareUrl,
        );
        await _chat(kit, api: api);
        kit.expectText('Shared: anyone with the link can view');
      },
      note: 'Host: ChatScreen for a conversation shared by link.',
    ),

    // -- embedded-message-view -----------------------------------------------
    CensusShot(
      'embedded-message-view',
      state: 'loaded',
      (kit) async {
        await _chat(
          kit,
          api: _Api()
            ..busy = {}
            ..messagesHandler = (_) async => _longTranscript(),
        );
        await kit.tapText('Read 3 files, edited 1 file, ran 1 command');
        kit.expectText(userPrompt);
      },
      note:
          'Three turns; the last turn\'s work line expanded (reads, edit, '
          'command), then code and choices. The expanded group repeats the '
          'same summary line inside itself (as rendered).',
    ),
    CensusShot(
      'embedded-message-view',
      state: 'working',
      (kit) async {
        await _chat(
          kit,
          api: _Api()
            ..messagesHandler = (_) async => sampleTranscript(streaming: true),
        );
        kit.expectText(userPrompt);
      },
      note: 'The reply is still streaming.',
    ),
    CensusShot(
      'embedded-message-view',
      state: 'empty',
      (kit) async {
        await _chat(
          kit,
          api: _Api()
            ..busy = {}
            ..messagesHandler = (_) async => [],
          sessionID: darkModeSessionID,
        );
        kit.expectVisible(find.byKey(const Key('chat-composer-field')));
      },
      note: 'A conversation with no messages yet: the start area.',
    ),
    CensusShot(
      'embedded-message-view',
      state: 'model-error',
      (kit) async {
        await _chat(
          kit,
          api: _Api()
            ..busy = {}
            ..messagesHandler = (_) async => _modelErrorTurn(),
        );
        kit.expectVisible(find.byKey(const Key('error-action-details')));
      },
      note: 'The reply ended on a model the server does not know.',
    ),
    CensusShot('chat-message-error-details-dialog', (kit) async {
      await _chat(
        kit,
        api: _Api()
          ..busy = {}
          ..messagesHandler = (_) async => _modelErrorTurn(),
      );
      await kit.tapKey('error-action-details');
      kit.expectText('Error details');
    }),

    // -- embedded-pending-sends-strip ----------------------------------------
    CensusShot(
      'embedded-pending-sends-strip',
      (kit) async {
        await _chat(
          kit,
          before: (controller) async {
            await _queue(
              controller,
              'queued-1',
              'Also run the payments tests',
              agoMinutes: 6,
              error: 'Provider is overloaded. Please retry.',
            );
            await _queue(
              controller,
              'queued-2',
              'Update the changelog entry for the checkout fix',
              agoMinutes: 4,
              dispatched: true,
            );
            await _queue(
              controller,
              'queued-3',
              'Then open a pull request with a short summary',
              agoMinutes: 2,
            );
          },
        );
        kit.expectVisible(find.byKey(const ValueKey('queued-action-resend')));
      },
      note:
          'Host: ChatScreen with three offline-queued drafts: failed, '
          'delivery unconfirmed (Send again), waiting. The third bubble is '
          'clipped under the composer and the unconfirmed label is '
          'ellipsized (as rendered). '
          'OpenCode 2 inbox bubbles are not shown: they need a live v2 '
          'gateway.',
    ),

    // -- embedded-chat-nudge-slot --------------------------------------------
    CensusShot(
      'embedded-chat-nudge-slot',
      (kit) async {
        final controller = await _chat(
          kit,
          prefValues: {NudgeRegistry.firstReplySeenKey: true},
        );
        controller.nudges.offer(
          NudgeId.reviewChanges,
          scope: checkoutSessionID,
        );
        await kit.settle();
        kit.expectTextContaining('This run changed files');
      },
      note: 'Host: ChatScreen after a run that edited files: the review tip.',
    ),
  ],
  notRendered: {
    'embedded-model-shortcuts':
        'desktop-only input with no visible surface: a Focus wrapper that '
        'handles hardware-keyboard shortcuts (Ctrl+B, F2, Shift+F2)',
  },
);
