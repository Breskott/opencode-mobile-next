// P3.2 wiring through the connection controller: the bootstrap photo
// recovery puts a photo the camera handed back after Android stopped the app
// into the draft of the conversation that asked for it, and deleting the
// server takes pending saved-prompt Undo with it.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/draft_attachments.dart';
import 'package:opencode_mobile/state/draft_photo_recovery.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/prompt_photos.dart';
import 'package:opencode_mobile/state/prompt_shelf.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/stash_memory_vault.dart';

class _Picker extends ImagePicker {
  LostDataResponse lost = LostDataResponse.empty();
  @override
  Future<LostDataResponse> retrieveLostData() async => lost;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    root = await Directory.systemTemp.createTemp('oc-p32-wiring-');
  });
  tearDown(() => root.delete(recursive: true));

  Future<ConnectionController> controller(
    Map<String, Object> extra, {
    PromptPhotoStore Function(SharedPreferences prefs)? photos,
  }) async {
    SharedPreferences.setMockInitialValues({
      'oc.profiles': jsonEncode([
        {'id': 'laptop', 'name': 'Laptop', 'baseUrl': 'http://localhost'},
        {'id': 'phone', 'name': 'Phone', 'baseUrl': 'http://phone'},
      ]),
      'oc.activeProfile': 'laptop',
      ...extra,
    });
    final prefs = await SharedPreferences.getInstance();
    final store = ProfileStore(prefs: prefs);
    await store.load();
    return ConnectionController(
      store,
      draftAttachmentVault: DraftAttachmentVault(
        directory: () async => Directory('${root.path}/drafts'),
      ),
      stashAttachmentVault: StashMemoryVault(),
      promptPhotoStore: photos?.call(prefs),
    );
  }

  test(
    'a returned photo joins its own conversation\'s draft, text kept',
    () async {
      final source = File('${root.path}/whiteboard.png');
      await source.writeAsBytes(base64Decode('iVBORw0KGgo='));
      final picker = _Picker()
        ..lost = LostDataResponse(files: [XFile(source.path)]);
      final c = await controller(
        {
          PromptPhotoStore.key: jsonEncode(
            const PendingPromptPhoto(
              id: 'request',
              profileID: 'laptop',
              sessionID: 'origin',
            ).toJson(),
          ),
          'oc.sessionDrafts': jsonEncode([
            {
              'sessionID': 'origin',
              'profileID': 'laptop',
              'text': 'Explain this diagram',
              'updatedAt': 1,
            },
          ]),
        },
        photos: (prefs) => PromptPhotoStore(
          prefs,
          picker: picker,
          vault: DraftAttachmentVault(
            directory: () async => Directory('${root.path}/recovery'),
          ),
        ),
      );
      addTearDown(c.dispose);
      // The controller read its drafts before recovery ran.
      expect(c.sessionDraft('origin'), 'Explain this diagram');
      expect(await c.recoverPendingPhoto(), DraftPhotoRecoveryResult.attached);
      final draft = c.savedSessionDraft('origin', profileID: 'laptop')!;
      expect(draft.text, 'Explain this diagram');
      expect(draft.attachments.single.filename, 'whiteboard.png');
      expect(c.promptPhotos.pending, isNull);
      // Its bytes come back from the draft vault.
      final restored = await c.restoreDraftAttachments(
        'origin',
        profileID: 'laptop',
        directory: null,
        workspace: null,
      );
      expect(restored.attachments.single.mime, 'image/png');
      // Nothing waited for, nothing to do.
      expect(
        await c.recoverPendingPhoto(),
        DraftPhotoRecoveryResult.nothingPending,
      );
    },
  );

  test('removing the server refuses its outstanding Undo', () async {
    final c = await controller({});
    addTearDown(c.dispose);
    await c.savePromptStash(
      const StashedPrompt(id: 'keep', text: 'Keep for later', createdAt: 1),
      locationRevision: c.locationRevision,
    );
    final undo = await c.deleteSavedPrompt(
      'keep',
      locationRevision: c.locationRevision,
    );
    expect(c.promptStash, isEmpty);
    final result = await c.deleteProfileAndLocalData('laptop');
    expect(result.removedProfile, isTrue);
    await expectLater(c.undoSavedPrompt(undo), throwsStateError);
    expect(PromptShelfStore(c.store.prefs).stashes('laptop'), isEmpty);
    expect(
      c.store.prefs.getKeys().where((key) => key.contains('laptop')),
      isEmpty,
    );
  });
}
