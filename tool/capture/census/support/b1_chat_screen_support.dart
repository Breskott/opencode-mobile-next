// Shared scene helpers for the census parts `b1-chat-screen` and
// `b2-chat-screen`: the real ChatScreen over the "shopfront" capture
// fixtures, with a controller whose drafts, queued sends, inbox, prompt shelf
// and draft storage can be faked per shot.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api2/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/draft_attachments.dart';
import 'package:opencode_mobile/state/offline_queue.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/prompt_shelf.dart';
import 'package:opencode_mobile/state/session_drafts.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';

import '../../fixtures.dart';
import '../census_core.dart';

/// The capture API with a one-page history and optional OpenCode 2 inbox.
class ChatCensusApi extends CaptureApi {
  bool inbox = false;

  @override
  ServerCapabilities get capabilities => inbox
      ? const ServerCapabilities(clientPromptMessageID: true, inbox: true)
      : ServerCapabilities.allV1;

  @override
  Future<ServerPage<MessageWithParts>> messagePage(
    String id, {
    String? cursor,
    int limit = 100,
  }) async => ServerPage(items: cursor == null ? await messages(id) : const []);
}

/// A capture controller whose local stores can be faked per shot.
class ChatCensusController extends CaptureController {
  ChatCensusController(super.store);

  SessionDraft? draft;
  DraftAttachmentRecovery? draftRecovery;
  List<QueuedPrompt> queued = const [];
  List<Api2InboxItem> inbox = const [];
  List<StashedPrompt>? stash;
  DraftAttachmentRecovery? stashRecovery;
  bool refuseDraftWrites = false;

  @override
  SessionDraft? savedSessionDraft(String sessionID, {String? profileID}) {
    if (draft case final value? when value.sessionID == sessionID) {
      return value;
    }
    return super.savedSessionDraft(sessionID, profileID: profileID);
  }

  @override
  Future<DraftAttachmentRecovery> restoreDraftAttachments(
    String sessionID, {
    required String profileID,
    required String? directory,
    required String? workspace,
  }) async {
    if (draftRecovery case final value?) return value;
    return super.restoreDraftAttachments(
      sessionID,
      profileID: profileID,
      directory: directory,
      workspace: workspace,
    );
  }

  @override
  Future<void> saveSessionDraft(
    String sessionID,
    String text, {
    String? profileID,
    List<PromptAttachment>? attachments,
    String? attachmentDirectory,
    String? attachmentWorkspace,
  }) async {
    if (refuseDraftWrites) {
      throw const SessionDraftWriteException(SessionDraftFailure.storage);
    }
    if (draft != null) return;
    return super.saveSessionDraft(
      sessionID,
      text,
      profileID: profileID,
      attachments: attachments,
      attachmentDirectory: attachmentDirectory,
      attachmentWorkspace: attachmentWorkspace,
    );
  }

  @override
  List<QueuedPrompt> queuedPromptsFor(String sessionID) => [
    for (final entry in queued)
      if (entry.sessionID == sessionID) entry,
  ];

  @override
  List<Api2InboxItem> inboxItemsFor(String sessionID) => [
    for (final item in inbox)
      if (item.sessionID == sessionID) item,
  ];

  @override
  bool get canUsePromptShelf => stash != null || super.canUsePromptShelf;

  @override
  List<StashedPrompt> get promptStash => stash ?? super.promptStash;

  @override
  Future<List<String>> preparePromptStash({
    required int locationRevision,
  }) async {
    if (stash != null) return const [];
    return super.preparePromptStash(locationRevision: locationRevision);
  }

  @override
  Future<DraftAttachmentRecovery> restorePromptStashAttachments(
    String id, {
    required int locationRevision,
  }) async {
    if (stashRecovery case final value?) return value;
    return super.restorePromptStashAttachments(
      id,
      locationRevision: locationRevision,
    );
  }
}

/// A connected [ChatCensusController] over [api], set up like
/// [captureController] (sample sessions, checkout session busy).
Future<ChatCensusController> chatCensusController(
  CensusKit kit, {
  required ChatCensusApi api,
  Map<String, Object> prefValues = const {},
}) async {
  final prefs = await kit.prefs(prefValues);
  final store = SeededProfileStore(
    prefs: prefs,
    seeded: [
      ServerProfile(
        id: 'laptop',
        name: 'Laptop',
        baseUrl: 'http://192.168.1.20:4096',
      ),
    ],
  );
  final controller = ChatCensusController(store)
    ..api = api
    ..repository = CaptureRepository()
    ..status = StreamStatus.connected
    ..directory = projectDirectory
    ..sessionsById = Map.of(api.sessionsById)
    ..busySessions = Set.of(api.busy);
  kit.onDispose(controller.dispose);
  return controller;
}

/// The finished checkout turn: prompt, reply, tools, code and choices.
List<MessageWithParts> finishedTranscript() => sampleTranscript();

/// Mounts the real ChatScreen for [sessionID]. [transcript] null means an
/// empty conversation. [pushed] puts the chat on a route over a plain page
/// so its app bar shows Back.
Future<ChatCensusController> openChat(
  CensusKit kit, {
  String sessionID = checkoutSessionID,
  List<MessageWithParts> Function()? transcript = finishedTranscript,
  bool busy = false,
  bool inbox = false,
  bool pushed = false,
  Map<String, Object> prefValues = const {},
  void Function(ChatCensusController controller)? configure,
}) async {
  final api = ChatCensusApi()
    ..inbox = inbox
    ..busy = busy ? {sessionID} : {}
    ..messagesHandler = (_) async => transcript?.call() ?? const [];
  final controller = await chatCensusController(
    kit,
    api: api,
    prefValues: prefValues,
  );
  configure?.call(controller);
  if (pushed) {
    await kit.pumpApp(
      const Scaffold(body: SizedBox.expand()),
      controller: controller,
    );
    await kit.push(
      ChatScreen(sessionID: sessionID),
      settleFor: const Duration(seconds: 2),
    );
  } else {
    await kit.pumpApp(ChatScreen(sessionID: sessionID), controller: controller);
  }
  return controller;
}

/// Opens the chat's single overflow (the session menu).
Future<void> openSessionMenu(CensusKit kit) async {
  await kit.tapKey('session-actions-button');
  kit.expectVisible(find.byKey(const Key('session-menu-sheet')));
}

/// Opens the session menu, expands "Conversation actions" and taps [label].
Future<void> sessionMenuAction(CensusKit kit, String label) async {
  await openSessionMenu(kit);
  await kit.tapText('Conversation actions');
  await kit.tapText(label);
}

/// Opens the composer's + tools sheet.
Future<void> openComposerTools(CensusKit kit) async {
  await kit.tapKey('composer-tools-button');
  kit.expectVisible(find.byKey(const Key('composer-tools-sheet')));
}

/// Opens the command launcher the way a person does: + then Commands.
Future<void> openCommandLauncher(CensusKit kit) async {
  await openComposerTools(kit);
  await kit.tapKey('composer-tool-commands');
  kit.expectVisible(find.byKey(const Key('command-launcher-search')));
}
