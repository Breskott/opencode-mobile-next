// Census scenes for the ledger part `b1-chat-screen`
// (docs/design/ui-ledger/parts/b1-chat-screen.json). See tool/capture/census_test.dart.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api2/models.dart';
import 'package:opencode_mobile/state/draft_attachments.dart';
import 'package:opencode_mobile/state/offline_queue.dart';
import 'package:opencode_mobile/state/prompt_shelf.dart';
import 'package:opencode_mobile/state/prompt_photos.dart';
import 'package:opencode_mobile/state/session_drafts.dart';

import '../../fixtures.dart';
import '../census_core.dart';
import '../support/b1_chat_screen_support.dart';

int get _now => DateTime.now().millisecondsSinceEpoch;

const _textAttachment = PromptAttachment(
  mime: 'text/plain',
  filename: 'checkout-log.txt',
  url: 'data:text/plain;base64,MDA6MDYgKzEyOiBBbGwgdGVzdHMgcGFzc2VkIQ==',
);

StashedPrompt _stashed() => StashedPrompt(
  id: 'stash_coupon',
  text:
      'Add a test for an expired coupon: the total must stay the same and '
      'the banner should say why.',
  createdAt: _now - 26 * 60 * 60 * 1000,
  directory: projectDirectory,
  attachments: const [_textAttachment],
);

/// Opens the prompt shelf through the composer's + tools and taps Restore on
/// the one saved prompt.
Future<void> _restoreStashed(CensusKit kit) async {
  await openComposerTools(kit);
  await kit.tapKey('composer-tools-prompts');
  await kit.tapKey('composer-tool-saved');
  kit.expectVisible(find.byKey(const Key('prompt-stash-sheet')));
  await kit.tapKey('restore-stash-stash_coupon');
}

QueuedPrompt _queued({int? dispatchedAt}) => QueuedPrompt(
  id: 'queued_suite',
  profileID: 'laptop',
  sessionID: checkoutSessionID,
  text: 'Run the full test suite and tell me which tests are still slow',
  createdAt: _now - 3 * 60 * 1000,
  dispatchedAt: dispatchedAt,
);

final b1ChatScreenArea = CensusArea(
  'b1-chat-screen',
  shots: [
    // -- the conversation itself -------------------------------------------
    CensusShot(
      'chat',
      state: 'finished',
      (kit) async {
        await openChat(kit);
        kit.expectText(userPrompt);
        kit.expectVisible(find.byKey(const Key('chat-composer-field')));
      },
      note:
          'A finished turn: prompt, answer, the folded tool work (3 reads, an '
          'edit, a test run), a Dart snippet and the choices block. The '
          "answer's opening paragraph (visible in the working state) is "
          'folded under the work line once the turn finishes.',
    ),
    CensusShot('chat', state: 'working', (kit) async {
      await openChat(
        kit,
        busy: true,
        transcript: () => sampleTranscript(streaming: true),
      );
      kit.expectText(userPrompt);
      kit.expectVisible(find.byKey(const Key('chat-stop-button')));
    }, note: 'The reply is streaming (cut mid-answer); Stop is live.'),
    CensusShot('chat', state: 'needs-you', (kit) async {
      await openChat(
        kit,
        busy: true,
        transcript: () => sampleTranscript(awaitingPermission: true),
        configure: (c) =>
            c.permissions = {samplePermission().id: samplePermission()},
      );
      kit.expectVisible(find.byKey(const Key('permission-card-review')));
    }, note: 'The run waits for approval to run the checkout tests.'),
    CensusShot('chat', state: 'empty', (kit) async {
      await openChat(kit, sessionID: darkModeSessionID, transcript: null);
      kit.expectVisible(find.byKey(const Key('chat-composer-field')));
    }, note: 'A conversation with no messages yet.'),

    // -- sheets ---------------------------------------------------------------
    CensusShot(
      'chat-draft-attachment-recovery-sheet',
      (kit) async {
        await openChat(
          kit,
          configure: (c) => c
            ..draft = SessionDraft(
              sessionID: checkoutSessionID,
              profileID: 'laptop',
              text: 'Also cover the coupon edge cases shown in the screenshot',
              updatedAt: _now - 40 * 60 * 1000,
              directory: projectDirectory,
              attachments: const [
                DraftAttachmentRef(
                  filename: 'coupon-flow.png',
                  mime: 'image/png',
                  blob: 'blob_coupon',
                  bytes: 184320,
                ),
                DraftAttachmentRef(
                  filename: 'checkout-log.txt',
                  mime: 'text/plain',
                  blob: 'blob_log',
                  bytes: 42,
                ),
              ],
            )
            ..draftRecovery = const DraftAttachmentRecovery(
              [_textAttachment],
              ['coupon-flow.png'],
            ),
        );
        kit.expectText('Some attachments need attention');
      },
      note:
          'Opens by itself when the saved draft of this conversation had an '
          'attachment that could not be read back (faked store).',
    ),
    CensusShot('chat-stash-attachments-unavailable-sheet', (kit) async {
      await openChat(
        kit,
        configure: (c) => c
          ..stash = [_stashed()]
          ..stashRecovery = const DraftAttachmentRecovery([], [
            'checkout-log.txt',
          ]),
      );
      await _restoreStashed(kit);
      kit.expectText('Some attachments cannot be restored');
    }, note: 'Composer + › Prompts › Saved prompts › Restore (faked shelf).'),
    CensusShot(
      'chat-stash-restore-confirm-sheet',
      (kit) async {
        await openChat(
          kit,
          configure: (c) => c
            ..stash = [_stashed()]
            ..stashRecovery = const DraftAttachmentRecovery([
              _textAttachment,
            ], []),
        );
        await kit.enterText(
          find.byKey(const Key('chat-composer-field')),
          'Check the payment form on a small phone',
        );
        await _restoreStashed(kit);
        kit.expectText('Restore saved prompt?');
      },
      note:
          'Restoring a saved prompt while the composer holds text (faked '
          'shelf).',
    ),
    CensusShot(
      'chat-discard-queued-draft-sheet',
      (kit) async {
        await openChat(kit, configure: (c) => c.queued = [_queued()]);
        await kit.tapKey('queued-action-discard');
        kit.expectText('Discard queued draft?');
      },
      note:
          'Discard on a draft queued while offline (the queue is faked; the '
          'connection itself is up).',
    ),
    CensusShot('chat-resend-queued-draft-sheet', (kit) async {
      await openChat(
        kit,
        configure: (c) =>
            c.queued = [_queued(dispatchedAt: _now - 2 * 60 * 1000)],
      );
      await kit.tapKey('queued-action-resend');
      kit.expectText('Send this draft again?');
    }, note: 'A queued draft whose send was never confirmed (faked queue).'),
    CensusShot(
      'chat-cancel-inbox-send-sheet',
      (kit) async {
        await openChat(
          kit,
          busy: true,
          inbox: true,
          transcript: () => sampleTranscript(streaming: true),
          configure: (c) => c.inbox = [
            Api2InboxItem(
              id: 'inbox_suite',
              sessionID: checkoutSessionID,
              timeCreated: _now - 20 * 1000,
              type: 'user',
              payload: const {'text': 'Then run the whole suite once more'},
              delivery: Api2Delivery.queue,
            ),
          ],
        );
        await kit.tapKey('inbox-action-cancel');
        kit.expectText('Cancel this pending message?');
      },
      note:
          'OpenCode 2 inbox: a message waiting for the running turn (faked '
          'inbox capability and item).',
    ),
    CensusShot(
      'chat-pending-photo-sheet',
      (kit) async {
        await openChat(
          kit,
          prefValues: {
            PromptPhotoStore.key: jsonEncode(
              const PendingPromptPhoto(
                id: 'photo_whiteboard',
                profileID: 'laptop',
                sessionID: darkModeSessionID,
                directory: projectDirectory,
                name: 'whiteboard.jpg',
              ).toJson(),
            ),
          },
        );
        await openComposerTools(kit);
        await kit.tapKey('composer-tool-camera');
        kit.expectText('Pending photo');
      },
      note:
          'Composer + › Take photo while a photo taken for another '
          'conversation is still pending.',
    ),
    CensusShot('chat-share-confirm-sheet', (kit) async {
      await openChat(kit);
      await sessionMenuAction(kit, 'Share conversation');
      kit.expectText('Share this conversation?');
    }, note: 'Conversation menu › Conversation actions › Share conversation.'),
  ],
  notRendered: {},
);
