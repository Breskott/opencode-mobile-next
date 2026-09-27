import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/state/migration_runner.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/prompt_shelf.dart';
import 'package:opencode_mobile/state/session_drafts.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'support/stash_memory_vault.dart';

class _RefuseLegacyRemoval extends InMemorySharedPreferencesStore {
  _RefuseLegacyRemoval(String legacy)
    : super.withData({'flutter.oc.sessionDrafts': legacy});

  bool refuse = true;

  @override
  Future<bool> remove(String key) async =>
      refuse && key == 'flutter.oc.sessionDrafts' ? false : super.remove(key);
}

/// An older draft (saved before drafts recorded their server) has no
/// `profileID`; a live conversation draft names its server.
Map<String, Object?> _oldDraft({
  String profile = '',
  String session = 'conversation-1',
  String text = 'Older unsent prompt',
}) => {
  'sessionID': session,
  if (profile.isNotEmpty) 'profileID': profile,
  'text': text,
  'updatedAt': 123,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    KitRedact.clearKnownSecrets();
  });
  tearDown(KitRedact.clearKnownSecrets);

  test(
    'older drafts move once into Saved prompts; drafts naming a server stay',
    () async {
      // Raw 1.0.44 preferences: one older draft and two live drafts.
      SharedPreferences.setMockInitialValues({
        'oc.sessionDrafts': jsonEncode([
          _oldDraft(text: 'Use password=fake-credential in example'),
          _oldDraft(profile: 'a', session: 'live-a', text: 'Live on A'),
          _oldDraft(profile: 'b', session: 'live-b', text: 'Live on B'),
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      final vault = StashMemoryVault();
      final shelf = PromptShelfStore.withAttachmentFiles(prefs, vault: vault);
      MigrationRunner runner() => MigrationRunner(
        prefs: prefs,
        shelf: shelf,
        draftVault: StashMemoryVault(),
        profileExists: (id) => {'a', 'b'}.contains(id),
      );

      final first = await runner().runForProfile('a');
      expect(first.complete, isTrue);
      expect(first.migrated, 1);
      final saved = shelf.stashes('a').single;
      expect(saved.text, 'Use password=${KitRedact.mask} in example');
      expect(saved.createdAt, 123);
      expect(shelf.stashes('b'), isEmpty);
      final left = SessionDraftStore(prefs: prefs).load().values;
      expect(left.map((draft) => draft.text), ['Live on A', 'Live on B']);
      expect(prefs.getBool('oc.savedPromptMigrationV1.a'), isTrue);
      // The backup keeps the moved row (redacted) under a profile-scoped key.
      final backup = prefs.getString(MigrationRunner.backupKey('a'))!;
      expect(backup, contains('Use password=${KitRedact.mask} in example'));
      expect(backup, isNot(contains('fake-credential')));
      expect(
        ProfileStore(prefs: prefs).profileScopedPreferenceKeys('a'),
        containsAll([
          MigrationRunner.markerKey('a'),
          MigrationRunner.backupKey('a'),
        ]),
      );

      expect((await runner().runForProfile('a')).alreadyComplete, isTrue);
      expect(shelf.stashes('a'), hasLength(1));
      // Another server finds nothing left to move.
      final other = await runner().runForProfile('b');
      expect((other.complete, other.migrated), (true, 0));
      expect(shelf.stashes('b'), isEmpty);
      final keysBefore = prefs.getKeys();
      expect(
        (await runner().runForProfile('deleted-profile')).blocker,
        DraftMigrationBlocker.unknownOwner,
      );
      expect(prefs.getKeys(), keysBefore);
    },
  );

  test('copied attachments survive collection of the older drafts\' files; '
      'a live draft keeps its own', () async {
    final draftVault = StashMemoryVault();
    final savedVault = StashMemoryVault();
    const photo = PromptAttachment(
      filename: 'draft-photo.png',
      mime: 'image/png',
      url: 'data:image/png;base64,ZmFrZS1waG90bw==',
    );
    const live = PromptAttachment(
      filename: 'live.png',
      mime: 'image/png',
      url: 'data:image/png;base64,bGl2ZQ==',
    );
    final refs = await draftVault.store('', [photo]);
    final liveRefs = await draftVault.store('a', [live]);
    SharedPreferences.setMockInitialValues({
      'oc.sessionDrafts': jsonEncode([
        {
          ..._oldDraft(text: ''),
          'attachments': refs.map((ref) => ref.toJson()).toList(),
          'directory': '/project',
          'workspace': 'main',
        },
        {
          ..._oldDraft(profile: 'a', session: 'live', text: 'live'),
          'attachments': liveRefs.map((ref) => ref.toJson()).toList(),
          'directory': '/project',
          'workspace': 'main',
        },
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final shelf = PromptShelfStore.withAttachmentFiles(
      prefs,
      vault: savedVault,
    );
    final result = await MigrationRunner(
      prefs: prefs,
      shelf: shelf,
      draftVault: draftVault,
      profileExists: (id) => id == 'a',
    ).runForProfile('a');

    expect(result.complete, isTrue);
    final prompt = shelf.stashes('a').single;
    expect(prompt.attachments, isEmpty);
    expect(prompt.attachmentRefs, hasLength(1));
    expect(prompt.directory, '/project');
    final restored = await shelf.restoreAttachments(
      'a',
      prompt.id,
      sameLocation: true,
    );
    expect(restored.attachments.single.url, photo.url);
    expect(restored.unavailable, isEmpty);
    // The older draft's file is collected; the live draft's is not.
    expect(
      (await draftVault.restore('', refs, sameLocation: true)).attachments,
      isEmpty,
    );
    expect(
      (await draftVault.restore(
        'a',
        liveRefs,
        sameLocation: true,
      )).attachments.single.url,
      live.url,
    );
    expect(SessionDraftStore(prefs: prefs).load().values.single.text, 'live');
  });

  test(
    'failed source removal retries without duplicating saved prompts',
    () async {
      final raw = jsonEncode([_oldDraft()]);
      final disk = _RefuseLegacyRemoval(raw);
      final previousPlatform = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = disk;
      SharedPreferences.resetStatic();
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = previousPlatform;
        SharedPreferences.resetStatic();
      });
      final prefs = await SharedPreferences.getInstance();
      final vault = StashMemoryVault();
      MigrationRunner runner() => MigrationRunner(
        prefs: prefs,
        shelf: PromptShelfStore.withAttachmentFiles(prefs, vault: vault),
        draftVault: StashMemoryVault(),
        profileExists: (id) => id == 'a',
      );

      expect((await runner().runForProfile('a')).complete, isFalse);
      expect(prefs.getString('oc.sessionDrafts'), raw);
      expect(prefs.containsKey(MigrationRunner.markerKey('a')), isFalse);
      disk.refuse = false;
      expect((await runner().runForProfile('a')).complete, isTrue);
      expect(
        PromptShelfStore.withAttachmentFiles(prefs, vault: vault).stashes('a'),
        hasLength(1),
      );
      expect(prefs.containsKey('oc.sessionDrafts'), isFalse);
      expect(
        jsonDecode(prefs.getString(MigrationRunner.backupKey('a'))!),
        hasLength(1),
      );
    },
  );

  test('a corrupt draft index stays intact', () async {
    SharedPreferences.setMockInitialValues({'oc.sessionDrafts': 'not json'});
    final prefs = await SharedPreferences.getInstance();
    final shelf = PromptShelfStore.withAttachmentFiles(
      prefs,
      vault: StashMemoryVault(),
    );
    final result = await MigrationRunner(
      prefs: prefs,
      shelf: shelf,
      draftVault: StashMemoryVault(),
      profileExists: (id) => id == 'a',
    ).runForProfile('a');
    expect(result.blocker, DraftMigrationBlocker.corruptDrafts);
    expect(prefs.getString('oc.sessionDrafts'), 'not json');
    expect(prefs.containsKey(MigrationRunner.markerKey('a')), isFalse);
    expect(shelf.stashes('a'), isEmpty);
  });

  test('a missing attachment file does not hold back the text', () async {
    SharedPreferences.setMockInitialValues({
      'oc.sessionDrafts': jsonEncode([
        {
          ..._oldDraft(),
          'attachments': [
            {
              'filename': 'missing.png',
              'mime': 'image/png',
              'blob': '0' * 64,
              'bytes': 20,
            },
          ],
        },
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final shelf = PromptShelfStore.withAttachmentFiles(
      prefs,
      vault: StashMemoryVault(),
    );
    final result = await MigrationRunner(
      prefs: prefs,
      shelf: shelf,
      draftVault: StashMemoryVault(),
      profileExists: (id) => id == 'a',
    ).runForProfile('a');
    expect(result.complete, isTrue);
    final prompt = shelf.stashes('a').single;
    expect(prompt.text, 'Older unsent prompt');
    expect(prompt.attachmentCount, 0);
    // The backup still records which file the draft had.
    expect(
      prefs.getString(MigrationRunner.backupKey('a')),
      contains('missing.png'),
    );
  });

  test('a full Saved prompts keeps the older drafts where they are', () async {
    final raw = jsonEncode([_oldDraft()]);
    SharedPreferences.setMockInitialValues({'oc.sessionDrafts': raw});
    final prefs = await SharedPreferences.getInstance();
    final shelf = PromptShelfStore.withAttachmentFiles(
      prefs,
      vault: StashMemoryVault(),
    );
    for (var i = 0; i < PromptShelfStore.capacity; i++) {
      await shelf.stash(
        'a',
        StashedPrompt(id: 'kept-$i', text: 'kept $i', createdAt: i),
      );
    }
    MigrationRunner runner() => MigrationRunner(
      prefs: prefs,
      shelf: shelf,
      draftVault: StashMemoryVault(),
      profileExists: (id) => id == 'a',
    );
    expect(
      (await runner().runForProfile('a')).blocker,
      DraftMigrationBlocker.full,
    );
    expect(prefs.getString('oc.sessionDrafts'), raw);
    expect(prefs.containsKey(MigrationRunner.markerKey('a')), isFalse);
    await shelf.remove('a', 'kept-0');
    expect((await runner().runForProfile('a')).migrated, 1);
    expect(prefs.containsKey('oc.sessionDrafts'), isFalse);
  });
}
