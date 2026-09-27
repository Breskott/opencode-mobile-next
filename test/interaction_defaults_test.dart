import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/interaction_defaults.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:opencode_mobile/voice/model_manifest.dart';
import 'package:opencode_mobile/voice/read_aloud.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _RefusingStore extends InMemorySharedPreferencesStore {
  _RefusingStore()
    : super.withData({
        'flutter.oc.profiles': jsonEncode([
          {'id': 'a'},
        ]),
      });
  bool refuse = true;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      refuse ? false : super.setValue(valueType, key, value);
}

WorkspaceProject project(String id) => WorkspaceProject(
  id: id,
  name: 'Project $id',
  directory: '/work/$id',
  worktrees: const [],
  updatedAt: 0,
);

CatalogModel model(
  String id, {
  String provider = 'provider',
  bool enabled = true,
}) => CatalogModel(
  id: id,
  providerID: provider,
  name: 'Friendly $id',
  enabled: enabled,
  status: 'active',
  contextLimit: 100,
  outputLimit: 10,
  reasoning: false,
  attachments: false,
  tools: true,
  variants: const [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'oc.profiles': jsonEncode([
        for (final id in ['a', 'b', 'safe']) {'id': id},
      ]),
    });
    KitRedact.clearKnownSecrets();
  });
  tearDown(KitRedact.clearKnownSecrets);

  test(
    'pickers skip single options and project defaults respect available IDs',
    () {
      expect(
        InteractionDefaults.picker(<String>[], label: (v) => v).value,
        isNull,
      );
      final single = InteractionDefaults.picker(['one'], label: (v) => v);
      expect(single.value, 'one');
      expect(single.skipPicker, isTrue);
      expect(single.canChange, isFalse);
      final many = InteractionDefaults.picker(['one', 'two'], label: (v) => v);
      expect(many.skipPicker, isFalse);
      expect(many.canChange, isTrue);
      final first = InteractionDefaults.project([]);
      expect(first.value!.name, 'my-app');
      expect(first.value!.needsCreation, isTrue);
      final projects = [project('a'), project('b')];
      expect(
        InteractionDefaults.project([projects.first]).value!.project!.id,
        'a',
      );
      expect(
        InteractionDefaults.project(
          projects,
          lastUsedID: 'b',
        ).value!.project!.id,
        'b',
      );
      expect(
        InteractionDefaults.project(projects, lastUsedID: 'gone').value,
        isNull,
      );
      expect(
        InteractionDefaults.project(
          projects,
          lastUsedID: 'b',
          explicitID: 'a',
        ).reason,
        DefaultReason.explicitChoice,
      );
    },
  );

  test(
    'signed-in model uses server IDs and friendly name without overriding a choice',
    () {
      final models = [
        model('a'),
        model('b'),
        model('b', provider: 'other'),
        model('off', enabled: false),
      ];
      DefaultChoice<CatalogModel> resolve({
        bool signedIn = true,
        CatalogModel? explicit,
      }) => InteractionDefaults.model(
        models,
        signedIn: signedIn,
        serverProviderID: 'provider',
        serverModelID: 'b',
        explicitChoice: explicit,
      );
      expect(resolve(signedIn: false).value, isNull);
      expect(resolve().value!.providerID, 'provider');
      expect(resolve().label, 'Friendly b');
      expect(resolve().reason, DefaultReason.serverDefault);
      expect(resolve(explicit: model('a')).value!.id, 'a');
      expect(resolve(explicit: model('off')).value!.id, 'b');
      expect(InteractionDefaults.model(models, signedIn: true).value, isNull);
      expect(
        InteractionDefaults.model([model('only')], signedIn: true).value!.id,
        'only',
      );
      expect(
        InteractionDefaults.model([
          model('off', enabled: false),
        ], signedIn: true).value,
        isNull,
      );
    },
  );

  test(
    'voice pack uses physical RAM thresholds, supported packs and explicit choice',
    () {
      DefaultChoice<VoiceModelPack> resolve(int? ram, {String? explicit}) =>
          InteractionDefaults.voicePack(
            totalMemoryMb: ram,
            supportedPacks: voiceModelPacks,
            explicitID: explicit,
          );
      expect(resolve(1023).value, isNull);
      expect(resolve(1024).value!.id, 'tiny');
      expect(resolve(1535).value!.id, 'tiny');
      expect(resolve(1536).value!.id, 'base');
      expect(resolve(3399).value!.id, 'base');
      expect(resolve(3400).value!.id, 'small');
      expect(resolve(null).value!.id, 'tiny');
      expect(resolve(8000, explicit: 'base').value!.id, 'base');
      expect(resolve(1100, explicit: 'small').value!.id, 'tiny');
      expect(
        InteractionDefaults.voicePack(
          totalMemoryMb: 8000,
          supportedPacks: [],
        ).value,
        isNull,
      );
    },
  );

  test(
    'voice matches full locale before language and retains explicit choice',
    () {
      const voices = [
        ReadAloudVoice(id: 'en', label: 'English', locale: 'en-US'),
        ReadAloudVoice(id: 'ar-eg', label: 'Arabic Egypt', locale: 'ar-EG'),
        ReadAloudVoice(id: 'ar-ae', label: 'Arabic UAE', locale: 'ar-AE'),
      ];
      expect(
        InteractionDefaults.voice(voices, locale: 'AR_ae').value!.id,
        'ar-ae',
      );
      expect(
        InteractionDefaults.voice(voices, locale: 'ar-SA').value!.id,
        'ar-eg',
      );
      expect(InteractionDefaults.voice(voices, locale: 'fr-FR').value, isNull);
      expect(
        InteractionDefaults.voice(
          voices,
          locale: 'ar-AE',
          explicitID: 'en',
        ).value!.id,
        'en',
      );
      expect(InteractionDefaults.voice([], locale: 'ar').value, isNull);
      expect(
        InteractionDefaults.voice([voices.first], locale: 'ar').skipPicker,
        isTrue,
      );
    },
  );

  test(
    'Queue is default and review picks confirmed changes, preserving overrides',
    () {
      expect(InteractionDefaults.delivery().value, PromptDelivery.queue);
      expect(
        InteractionDefaults.delivery(
          explicitChoice: PromptDelivery.steer,
        ).isAutomatic,
        isFalse,
      );
      const session = DefaultReviewScope.session;
      const working = DefaultReviewScope.workingTree;
      const branch = DefaultReviewScope.branch;
      expect(
        InteractionDefaults.review({session: 0, working: 3, branch: 4}).value,
        working,
      );
      expect(
        InteractionDefaults.review({session: 2, working: 3}).value,
        session,
      );
      expect(
        InteractionDefaults.review({session: null, branch: 1}).value,
        branch,
      );
      expect(
        InteractionDefaults.review({session: null, working: 0}).value,
        isNull,
      );
      expect(InteractionDefaults.review({working: 0}).value, isNull);
      expect(
        InteractionDefaults.review({
          working: 1,
          branch: 0,
        }, explicitChoice: branch).value,
        branch,
      );
      expect(
        InteractionDefaults.review({working: 1}, explicitChoice: session).value,
        working,
      );
    },
  );

  test(
    'project and once-only notices survive restart, stay isolated and delete with profile',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = InteractionDefaultsStore(prefs, profileID: 'a');
      final other = InteractionDefaultsStore(prefs, profileID: 'b');
      await store.rememberProject('second');
      final choice = InteractionDefaults.delivery();
      final notices = await Future.wait([
        store.takeAnnouncement(DefaultKind.delivery, choice),
        store.takeAnnouncement(DefaultKind.delivery, choice),
      ]);
      expect(notices, ['queue', null]);
      final restarted = InteractionDefaultsStore(prefs, profileID: 'a');
      expect(restarted.lastProjectID, 'second');
      expect(
        await restarted.takeAnnouncement(DefaultKind.delivery, choice),
        isNull,
      );
      expect(other.lastProjectID, isNull);
      expect(
        await other.takeAnnouncement(DefaultKind.delivery, choice),
        'queue',
      );
      expect(
        await store.takeAnnouncement(
          DefaultKind.review,
          InteractionDefaults.review({DefaultReviewScope.session: null}),
        ),
        isNull,
      );
      expect(
        await store.takeAnnouncement(
          DefaultKind.model,
          InteractionDefaults.model(
            [model('a')],
            signedIn: true,
            explicitChoice: model('a'),
          ),
        ),
        isNull,
      );
      expect(
        await store.takeAnnouncement(
          DefaultKind.model,
          InteractionDefaults.model([model('a')], signedIn: true),
        ),
        'Friendly a',
      );
      await store.drain();
      final profiles = ProfileStore(prefs: prefs);
      expect(await profiles.removeScopedPreferences('a'), isEmpty);
      expect(restarted.lastProjectID, isNull);
      await expectLater(
        restarted.takeAnnouncement(DefaultKind.delivery, choice),
        throwsStateError,
      );
      expect(
        await other.takeAnnouncement(DefaultKind.delivery, choice),
        isNull,
      );
    },
  );

  test(
    'refused storage does not remember a project or consume a notice',
    () async {
      final backend = _RefusingStore();
      SharedPreferencesStorePlatform.instance = backend;
      final prefs = await SharedPreferences.getInstance();
      final store = InteractionDefaultsStore(prefs, profileID: 'a');
      await expectLater(store.rememberProject('project'), throwsStateError);
      expect(store.lastProjectID, isNull);
      await expectLater(
        store.takeAnnouncement(
          DefaultKind.delivery,
          InteractionDefaults.delivery(),
        ),
        throwsStateError,
      );
      backend.refuse = false;
      await store.rememberProject('project');
      expect(store.lastProjectID, 'project');
      expect(
        await store.takeAnnouncement(
          DefaultKind.delivery,
          InteractionDefaults.delivery(),
        ),
        'queue',
      );
    },
  );

  test(
    'sensitive values are never persisted or announced, invalid write does not poison queue',
    () async {
      const fakeSecret = 'fake-credential-for-defaults-test';
      KitRedact.registerKnownSecret(fakeSecret);
      final prefs = await SharedPreferences.getInstance();
      final store = InteractionDefaultsStore(prefs, profileID: 'safe');
      await expectLater(store.rememberProject(fakeSecret), throwsArgumentError);
      await store.rememberProject('safe-project');
      final choice = InteractionDefaults.picker([fakeSecret], label: (v) => v);
      expect(
        await store.takeAnnouncement(DefaultKind.project, choice),
        KitRedact.mask,
      );
      expect(prefs.getKeys().any((k) => k.contains(fakeSecret)), isFalse);
      expect(
        prefs.getKeys().any(
          (k) => prefs.get(k).toString().contains(fakeSecret),
        ),
        isFalse,
      );
      expect(
        () => InteractionDefaultsStore(prefs, profileID: fakeSecret),
        throwsArgumentError,
      );
      expect(store.lastProjectID, 'safe-project');
    },
  );
}
