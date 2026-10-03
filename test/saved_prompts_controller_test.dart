import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/draft_attachments.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/prompt_shelf.dart';
import 'package:opencode_mobile/state/saved_prompt_safety.dart';
import 'package:opencode_mobile/state/saved_prompts_controller.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _Composer implements SavedPromptComposer {
  _Composer(this.value);
  @override
  StashedPrompt value;
  @override
  Future<void> replace(StashedPrompt next) async {
    value = next;
  }
}

class _RefusingPrefs extends InMemorySharedPreferencesStore {
  _RefusingPrefs() : super.withData({});
  bool refuse = false;
  @override
  Future<bool> remove(String key) async => refuse ? false : super.remove(key);
}

StashedPrompt _prompt(String id, {String text = 'Saved text'}) => StashedPrompt(
  id: id,
  text: text,
  createdAt: 42,
  directory: '/project',
  workspace: 'w',
  attachments: const [
    PromptAttachment(
      mime: 'text/plain',
      filename: 'note.txt',
      url: 'data:text/plain;charset=utf-8;base64,aGVsbG8=',
    ),
  ],
  references: const [
    ReviewReference(
      id: 'r',
      kind: ReviewReferenceKind.hunk,
      path: 'lib/a.dart',
      snippet: '+hello',
      comment: 'Check this',
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late Directory temp;
  late PromptShelfStore shelf;
  late SavedPromptsController controller;
  late bool exists;
  setUp(() async {
    KitRedact.clearKnownSecrets();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    temp = await Directory.systemTemp.createTemp('saved-prompts-');
    shelf = PromptShelfStore.withAttachmentFiles(
      prefs,
      vault: DraftAttachmentVault(directory: () async => temp),
    );
    exists = true;
    controller = SavedPromptsController(
      profileID: 'p',
      shelf: shelf,
      profileExists: (_) => exists,
    );
  });
  tearDown(() async {
    controller.dispose();
    KitRedact.clearKnownSecrets();
    await temp.delete(recursive: true);
  });

  test(
    'delete is durable immediately and Undo restores exact metadata and bytes',
    () async {
      await controller.save(_prompt('one'));
      final original = jsonEncode(controller.prompts.single.toJson());
      final undo = await controller.delete('one');
      expect(controller.prompts, isEmpty);
      expect(prefs.containsKey('oc.promptStash.p.one'), isFalse);
      await undo.undo();
      expect(jsonEncode(controller.prompts.single.toJson()), original);
      final recovered = await shelf.restoreAttachments(
        'p',
        'one',
        sameLocation: true,
      );
      expect(
        Uri.parse(recovered.attachments.single.url).data!.contentAsString(),
        'hello',
      );
      await expectLater(undo.undo(), throwsStateError);
    },
  );

  test(
    'restore preserves source and Undo restores full composer, refusing later edits',
    () async {
      await controller.save(_prompt('one'));
      final prior = _prompt('draft', text: 'Unsent text');
      final composer = _Composer(prior);
      final undo = await controller.restore(
        'one',
        composer: composer,
        sameLocation: true,
      );
      expect(composer.value.text, 'Saved text');
      expect(controller.prompts.single.id, 'one');
      await undo.undo();
      expect(composer.value.toJson(), prior.toJson());
      final stale = await controller.restore(
        'one',
        composer: composer,
        sameLocation: true,
      );
      composer.value = _prompt('draft', text: 'New editing');
      await expectLater(stale.undo(), throwsStateError);
      expect(composer.value.text, 'New editing');
      await expectLater(
        controller.restore('one', composer: composer, sameLocation: false),
        throwsStateError,
      );
    },
  );

  test(
    'profile sweep removes scoped data and outstanding Undo cannot resurrect it',
    () async {
      await controller.save(_prompt('one'));
      final undo = await controller.delete('one');
      await controller.save(_prompt('two'));
      await prefs.setBool('oc.savedPromptMigrationV1.p', true);
      await prefs.setString('oc.promptHistory.other', '[]');
      exists = false;
      controller.invalidate();
      expect(await shelf.clearForProfile('p'), isTrue);
      expect(
        await ProfileStore(prefs: prefs).removeScopedPreferences('p'),
        isEmpty,
      );
      await expectLater(undo.undo(), throwsStateError);
      expect(
        ProfileStore(prefs: prefs).profileScopedPreferenceKeys('p'),
        isEmpty,
      );
      expect(prefs.containsKey('oc.promptHistory.other'), isTrue);
      expect(
        await temp.list(recursive: true).where((f) => f is File).toList(),
        isEmpty,
      );
    },
  );

  test(
    'save redacts copy and encoded text payload without exposing fake credentials',
    () async {
      const fake = 'test-sensitive-value';
      KitRedact.registerKnownSecret(fake);
      final safe = sanitizeSavedPrompt(
        StashedPrompt(
          id: 'safe',
          text: fake,
          createdAt: 1,
          attachments: [
            PromptAttachment(
              mime: 'text/plain',
              filename: '$fake.txt',
              url: Uri.dataFromString(
                fake,
                mimeType: 'text/plain',
                base64: true,
              ).toString(),
            ),
          ],
        ),
      );
      expect(safe.text == KitRedact.mask, isTrue);
      expect(
        Uri.parse(safe.attachments.single.url).data!.contentAsString() ==
            KitRedact.mask,
        isTrue,
      );
      await controller.save(safe);
      expect(
        (prefs.getString('oc.promptStash.p.safe') ?? '').contains(fake),
        isFalse,
      );
      expect(
        () => sanitizeSavedPrompt(
          StashedPrompt(id: fake, text: 'x', createdAt: 1),
        ),
        throwsStateError,
      );
    },
  );

  test('refused deletion retains saved prompt and a retry works', () async {
    final old = SharedPreferencesStorePlatform.instance;
    final backend = _RefusingPrefs();
    SharedPreferencesStorePlatform.instance = backend;
    SharedPreferences.resetStatic();
    addTearDown(() {
      SharedPreferencesStorePlatform.instance = old;
      SharedPreferences.resetStatic();
    });
    final store = PromptShelfStore(await SharedPreferences.getInstance());
    final c = SavedPromptsController(
      profileID: 'p',
      shelf: store,
      profileExists: (_) => true,
    );
    addTearDown(c.dispose);
    await c.save(const StashedPrompt(id: 'x', text: 'kept', createdAt: 1));
    backend.refuse = true;
    await expectLater(c.delete('x'), throwsStateError);
    expect(c.prompts.single.text, 'kept');
    backend.refuse = false;
    await c.delete('x');
    expect(c.prompts, isEmpty);
  });
}
