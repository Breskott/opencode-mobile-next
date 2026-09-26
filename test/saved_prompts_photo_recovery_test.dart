import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:opencode_mobile/state/draft_attachments.dart';
import 'package:opencode_mobile/state/draft_photo_recovery.dart';
import 'package:opencode_mobile/state/prompt_photos.dart';
import 'package:opencode_mobile/state/session_drafts.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _Picker extends ImagePicker {
  LostDataResponse lost = LostDataResponse.empty();
  @override
  Future<LostDataResponse> retrieveLostData() async => lost;
}

class _Disk extends InMemorySharedPreferencesStore {
  _Disk() : super.withData({});
  bool refuseDraft = false;
  bool refuseDiscard = false;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (refuseDraft && key == 'flutter.oc.sessionDrafts') return false;
    return super.setValue(type, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (refuseDiscard && key == 'flutter.${PromptPhotoStore.key}') return false;
    return super.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late SharedPreferences prefs;
  late _Disk disk;
  late SharedPreferencesStorePlatform originalPlatform;
  late _Picker picker;
  late PromptPhotoStore photos;
  late SessionDraftStore drafts;
  late DraftAttachmentVault vault;
  var exists = true;

  DraftPhotoRecovery recovery() => DraftPhotoRecovery(
    photos: photos,
    drafts: drafts,
    vault: vault,
    profileExists: (id) => id == 'origin' && exists,
    now: () => 99,
  );

  Future<void> pending() async {
    await prefs.setString(
      PromptPhotoStore.key,
      jsonEncode(
        const PendingPromptPhoto(
          id: 'request',
          profileID: 'origin',
          sessionID: 'conversation',
          directory: '/original-project',
          workspace: 'original-workspace',
        ).toJson(),
      ),
    );
    final source = File('${root.path}/camera.png');
    await source.writeAsBytes(base64Decode('iVBORw0KGgo='));
    picker.lost = LostDataResponse(files: [XFile(source.path)]);
  }

  setUp(() async {
    originalPlatform = SharedPreferencesStorePlatform.instance;
    KitRedact.clearKnownSecrets();
    exists = true;
    SharedPreferences.setMockInitialValues({});
    disk = _Disk();
    SharedPreferencesStorePlatform.instance = disk;
    SharedPreferences.resetStatic();
    prefs = await SharedPreferences.getInstance();
    root = await Directory.systemTemp.createTemp('oc-saved-photo-');
    picker = _Picker();
    photos = PromptPhotoStore(
      prefs,
      picker: picker,
      vault: DraftAttachmentVault(
        directory: () async => Directory('${root.path}/recovery'),
      ),
    );
    drafts = SessionDraftStore(prefs: prefs);
    vault = DraftAttachmentVault(
      directory: () async => Directory('${root.path}/drafts'),
    );
  });

  tearDown(() async {
    KitRedact.clearKnownSecrets();
    photos.dispose();
    SharedPreferencesStorePlatform.instance = originalPlatform;
    SharedPreferences.resetStatic();
    await root.delete(recursive: true);
  });

  test(
    'recovered photo keeps its origin draft, text, attachments and location',
    () async {
      const origin = SessionDraft(
        profileID: 'origin',
        sessionID: 'conversation',
        text: 'Continue this draft',
        updatedAt: 1,
        directory: '/current-project',
        workspace: 'current-workspace',
        attachments: [
          DraftAttachmentRef(
            filename: 'existing.txt',
            mime: 'text/plain',
            url: 'file:///current-project/existing.txt',
          ),
        ],
      );
      const other = SessionDraft(
        profileID: 'active-elsewhere',
        sessionID: 'conversation',
        text: 'Leave this alone',
        updatedAt: 2,
      );
      await drafts.save({origin.storageKey: origin, other.storageKey: other});
      await pending();
      expect(await recovery().recover(), DraftPhotoRecoveryResult.attached);
      final saved = drafts.load()[origin.storageKey]!;
      expect(saved.text, origin.text);
      expect(saved.directory, origin.directory);
      expect(saved.workspace, origin.workspace);
      expect(saved.attachments.length, 2);
      expect(
        saved.attachments.first.toJson(),
        origin.attachments.first.toJson(),
      );
      expect(drafts.load()[other.storageKey]!.toJson(), other.toJson());
      expect(photos.pending, isNull);
      expect(prefs.getBool('oc.draftAttachmentVault'), isTrue);
      final restored = await vault.restore(
        'origin',
        saved.attachments,
        sameLocation: true,
      );
      expect(restored.unavailable, isEmpty);
      expect(
        restored.attachments.last.url,
        'data:image/png;base64,iVBORw0KGgo=',
      );
      expect(
        await recovery().recover(),
        DraftPhotoRecoveryResult.nothingPending,
      );
    },
  );

  test(
    'failed draft save retains photo; restart after failed discard dedupes',
    () async {
      await pending();
      disk.refuseDraft = true;
      expect(
        await recovery().recover(),
        DraftPhotoRecoveryResult.retryRequired,
      );
      expect(drafts.load(), isEmpty);
      expect(photos.pending, isNotNull);
      expect((await photos.readPending('request')).mime, 'image/png');
      disk.refuseDraft = false;
      disk.refuseDiscard = true;
      expect(
        await recovery().recover(),
        DraftPhotoRecoveryResult.retryRequired,
      );
      expect(drafts.load().values.single.attachments.length, 1);
      expect(photos.pending, isNotNull);
      // Discard collected the recovery vault before preference removal failed.
      // The next service instance must dedupe without needing those old bytes.
      disk.refuseDiscard = false;
      expect(await recovery().recover(), DraftPhotoRecoveryResult.attached);
      expect(drafts.load().values.single.attachments.length, 1);
      expect(photos.pending, isNull);
      final restored = await vault.restore(
        'origin',
        drafts.load().values.single.attachments,
        sameLocation: true,
      );
      expect(restored.attachments.length, 1);
    },
  );

  test('deletion while copying cannot recreate the profile draft', () async {
    await pending();
    final copying = Completer<void>();
    final release = Completer<void>();
    vault = DraftAttachmentVault(
      directory: () async {
        if (!copying.isCompleted) copying.complete();
        await release.future;
        return Directory('${root.path}/drafts');
      },
    );
    final result = recovery().recover();
    await copying.future;
    exists = false;
    release.complete();
    expect(await result, DraftPhotoRecoveryResult.profileRemoved);
    expect(drafts.load(), isEmpty);
    expect(photos.pending, isNull);
    expect(
      await Directory(
        '${root.path}/drafts',
      ).list(recursive: true).where((entry) => entry is File).isEmpty,
      isTrue,
    );
  });

  test(
    'native recovery redacts filename metadata before persistence',
    () async {
      await pending();
      final source = File('${root.path}/camera.png');
      picker.lost = LostDataResponse(
        files: [XFile(source.path, name: 'password=fake-photo.png')],
      );
      await photos.recoverLostData();
      expect(photos.pending!.name, 'password=${KitRedact.mask}');
      expect(photos.pending!.ref!.filename, 'password=${KitRedact.mask}');
      expect(
        prefs.getString(PromptPhotoStore.key)!.contains('fake-photo.png'),
        isFalse,
      );
      expect(await recovery().recover(), DraftPhotoRecoveryResult.attached);
      expect(
        drafts.load().values.single.attachments.single.filename,
        'password=${KitRedact.mask}',
      );
    },
  );

  test(
    'draft metadata is redacted and a full draft retains pending photo',
    () async {
      const old = SessionDraft(
        profileID: 'origin',
        sessionID: 'conversation',
        text: 'password=fake-value',
        updatedAt: 1,
      );
      await drafts.save({old.storageKey: old});
      await pending();
      expect(await recovery().recover(), DraftPhotoRecoveryResult.attached);
      expect(drafts.load().values.single.text, 'password=${KitRedact.mask}');
      final full = SessionDraft(
        profileID: 'origin',
        sessionID: 'conversation',
        text: 'Keep all five',
        updatedAt: 1,
        attachments: List.generate(
          5,
          (index) => DraftAttachmentRef(
            filename: 'file-$index.txt',
            mime: 'text/plain',
            url: 'file:///project/file-$index.txt',
          ),
        ),
      );
      await drafts.save({full.storageKey: full});
      await pending();
      expect(
        await recovery().recover(),
        DraftPhotoRecoveryResult.retryRequired,
      );
      expect(drafts.load().values.single.toJson(), full.toJson());
      expect(photos.pending, isNotNull);
    },
  );
}
