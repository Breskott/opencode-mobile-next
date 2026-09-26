import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/state/migration_runner.dart';
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

Map<String, Object?> _oldDraft({
  String profile = 'a',
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

  test('old preferences move once and preserve the other profile', () async {
    SharedPreferences.setMockInitialValues({
      'oc.sessionDrafts': jsonEncode([
        _oldDraft(text: 'Use password=fake-credential in example'),
        _oldDraft(profile: 'b', text: 'Other server'),
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
    expect(
      shelf.stashes('a').single.text,
      'Use password=${KitRedact.mask} in example',
    );
    expect(SessionDraftStore(prefs: prefs).load().values.single.profileID, 'b');
    expect(prefs.getBool('oc.savedPromptMigrationV1.a'), isTrue);
    expect((await runner().runForProfile('a')).alreadyComplete, isTrue);
    expect(shelf.stashes('a'), hasLength(1));
    final keysBefore = prefs.getKeys();
    expect(
      (await runner().runForProfile('deleted-profile')).blocker,
      DraftMigrationBlocker.unknownOwner,
    );
    expect(prefs.getKeys(), keysBefore);
  });

  test(
    'copied attachments survive collection of the old draft vault',
    () async {
      final draftVault = StashMemoryVault();
      final savedVault = StashMemoryVault();
      const photo = PromptAttachment(
        filename: 'draft-photo.png',
        mime: 'image/png',
        url: 'data:image/png;base64,ZmFrZS1waG90bw==',
      );
      final refs = await draftVault.store('a', [photo]);
      SharedPreferences.setMockInitialValues({
        'oc.sessionDrafts': jsonEncode([
          {
            ..._oldDraft(text: ''),
            'attachments': refs.map((ref) => ref.toJson()).toList(),
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
      expect(prefs.containsKey('oc.sessionDrafts'), isFalse);
      final prompt = shelf.stashes('a').single;
      expect(prompt.attachments, isEmpty);
      expect(prompt.attachmentRefs, hasLength(1));
      final restored = await shelf.restoreAttachments(
        'a',
        prompt.id,
        sameLocation: true,
      );
      expect(restored.attachments.single.url, photo.url);
      expect(restored.unavailable, isEmpty);
      expect(
        (await draftVault.restore('a', refs, sameLocation: true)).attachments,
        isEmpty,
      );
    },
  );

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
    },
  );

  test(
    'corrupt, ownerless and missing-attachment sources stay intact',
    () async {
      for (final fixture in <(String, DraftMigrationBlocker)>[
        ('not json', DraftMigrationBlocker.corruptDrafts),
        (
          jsonEncode([_oldDraft(profile: '')]),
          DraftMigrationBlocker.unknownOwner,
        ),
        (
          jsonEncode([
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
          DraftMigrationBlocker.unavailableAttachments,
        ),
      ]) {
        SharedPreferences.setMockInitialValues({
          'oc.sessionDrafts': fixture.$1,
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
        expect(result.blocker, fixture.$2);
        expect(prefs.getString('oc.sessionDrafts'), fixture.$1);
        expect(prefs.containsKey(MigrationRunner.markerKey('a')), isFalse);
        expect(shelf.stashes('a'), isEmpty);
      }
    },
  );
}
