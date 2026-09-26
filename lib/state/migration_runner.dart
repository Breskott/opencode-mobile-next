import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/kit/kit_redact.dart';
import 'draft_attachments.dart';
import 'prompt_shelf.dart';
import 'saved_prompt_safety.dart';
import 'session_drafts.dart';

enum DraftMigrationBlocker {
  unknownOwner,
  corruptDrafts,
  unavailableAttachments,
  changedDuringMigration,
  storage,
}

/// No raw exception or draft content is exposed in migration status.
class DraftMigrationResult {
  const DraftMigrationResult({
    this.migrated = 0,
    this.alreadyComplete = false,
    this.blocker,
  });

  /// Verified shelf copies, including copies recovered from an interrupted run.
  /// On a blocked run, these may still have corresponding legacy source rows.
  final int migrated;
  final bool alreadyComplete;
  final DraftMigrationBlocker? blocker;
  bool get complete => blocker == null;
}

/// Moves legacy drafts into Saved prompts once for each known profile.
///
/// Run before loading drafts into ConnectionController, while ordinary draft
/// writes and profile deletion are paused. Share the attachment-enabled shelf
/// with the Saved prompts controller and use a separate draft vault root.
/// Concurrent calls on this runner are serialized. This is not a transaction
/// lane for other SessionDraftStore instances: startup exclusivity is required.
/// Source rows are removed only after their complete shelf copies are verified;
/// any failed run can safely be retried after restart.
class MigrationRunner {
  MigrationRunner({
    required this.prefs,
    required this.shelf,
    required this.draftVault,
    required this.profileExists,
    SessionDraftStore? draftStore,
  }) : draftStore = draftStore ?? SessionDraftStore(prefs: prefs);

  final SharedPreferences prefs;
  final PromptShelfStore shelf;
  final DraftAttachmentVault draftVault;
  final SessionDraftStore draftStore;
  final bool Function(String profileId) profileExists;
  Future<void> _tail = Future<void>.value();

  static String markerKey(String profileId) =>
      'oc.savedPromptMigrationV1.$profileId';

  Future<DraftMigrationResult> runForProfile(String profileId) {
    final next = _tail.then((_) => _run(profileId));
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  void _checkOwner(String profileId) {
    if (profileId.isEmpty ||
        KitRedact.text(profileId) != profileId ||
        !profileExists(profileId)) {
      throw StateError('Draft owner unavailable');
    }
  }

  String _fingerprint(SessionDraft draft) =>
      sha256.convert(utf8.encode(jsonEncode(draft.toJson()))).toString();

  Future<DraftMigrationResult> _run(String profileId) async {
    var migrated = 0;
    try {
      _checkOwner(profileId);
      if (prefs.getBool(markerKey(profileId)) == true) {
        return const DraftMigrationResult(alreadyComplete: true);
      }
      final original = draftStore.load();
      if (!draftStore.readable) {
        return const DraftMigrationResult(
          blocker: DraftMigrationBlocker.corruptDrafts,
        );
      }
      if (original.values.any((draft) => draft.profileID.isEmpty)) {
        return const DraftMigrationResult(
          blocker: DraftMigrationBlocker.unknownOwner,
        );
      }
      final candidates = original.values
          .where((draft) => draft.profileID == profileId)
          .toList();
      for (final draft in candidates) {
        _checkOwner(profileId);
        if (draft.attachments.any(
          (ref) => (ref.blob != null && ref.url != null) || ref.bytes < 0,
        )) {
          return DraftMigrationResult(
            migrated: migrated,
            blocker: DraftMigrationBlocker.corruptDrafts,
          );
        }
        final restored = await draftVault.restore(
          profileId,
          draft.attachments,
          sameLocation: true,
        );
        if (restored.unavailable.isNotEmpty) {
          return DraftMigrationResult(
            migrated: migrated,
            blocker: DraftMigrationBlocker.unavailableAttachments,
          );
        }
        final prompt = sanitizeSavedPrompt(
          StashedPrompt(
            id: 'legacy-draft-${_fingerprint(draft)}',
            text: draft.text,
            createdAt: draft.updatedAt,
            directory: draft.directory,
            workspace: draft.workspace,
            attachments: restored.attachments,
          ),
        );
        final existing = shelf
            .stashes(profileId)
            .where((entry) => entry.id == prompt.id)
            .firstOrNull;
        if (existing == null) {
          await shelf.stash(
            profileId,
            prompt,
            checkCurrent: () => _checkOwner(profileId),
          );
        }
        // A deterministic ID is a retry hint, not proof of an intact copy.
        final saved = shelf
            .stashes(profileId)
            .firstWhere((entry) => entry.id == prompt.id);
        final recovery = await shelf.restoreAttachments(
          profileId,
          prompt.id,
          sameLocation: true,
          checkCurrent: () => _checkOwner(profileId),
        );
        final verified = StashedPrompt(
          id: saved.id,
          text: saved.text,
          createdAt: saved.createdAt,
          directory: saved.directory,
          workspace: saved.workspace,
          references: saved.references,
          attachments: recovery.attachments,
        );
        if (recovery.unavailable.isNotEmpty ||
            jsonEncode(verified.toJson()) != jsonEncode(prompt.toJson())) {
          return DraftMigrationResult(
            migrated: migrated,
            blocker: DraftMigrationBlocker.storage,
          );
        }
        migrated++;
      }
      _checkOwner(profileId);
      final current = draftStore.load();
      if (!draftStore.readable ||
          jsonEncode(
                current.map((key, draft) => MapEntry(key, draft.toJson())),
              ) !=
              jsonEncode(
                original.map((key, draft) => MapEntry(key, draft.toJson())),
              )) {
        return DraftMigrationResult(
          migrated: migrated,
          blocker: DraftMigrationBlocker.changedDuringMigration,
        );
      }
      final retained = {
        for (final entry in current.entries)
          if (entry.value.profileID != profileId) entry.key: entry.value,
      };
      if (candidates.isNotEmpty && !await draftStore.save(retained)) {
        return DraftMigrationResult(
          migrated: migrated,
          blocker: DraftMigrationBlocker.storage,
        );
      }
      _checkOwner(profileId);
      if (!await draftVault.collect(const {}, owner: profileId)) {
        return DraftMigrationResult(
          migrated: migrated,
          blocker: DraftMigrationBlocker.storage,
        );
      }
      _checkOwner(profileId);
      if (!await prefs.setBool(markerKey(profileId), true)) {
        await prefs.reload();
        return DraftMigrationResult(
          migrated: migrated,
          blocker: DraftMigrationBlocker.storage,
        );
      }
      return DraftMigrationResult(migrated: migrated);
    } catch (_) {
      // SharedPreferences optimistically updates its cache before disk writes.
      try {
        await prefs.reload();
      } catch (_) {}
      return DraftMigrationResult(
        migrated: migrated,
        blocker: profileId.isEmpty || !profileExists(profileId)
            ? DraftMigrationBlocker.unknownOwner
            : DraftMigrationBlocker.storage,
      );
    }
  }
}
