import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/automation_policy.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _Storage extends InMemorySharedPreferencesStore {
  _Storage() : super.withData({});
  bool refuse = false;
  bool throwWrite = false;
  Completer<void>? gate;
  Completer<void>? started;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    started?.complete();
    started = null;
    await gate?.future;
    if (throwWrite) throw StateError('fake storage failure');
    return refuse ? false : super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late _Storage storage;
  late AutomationPolicyController controller;

  setUp(() async {
    KitRedact.clearKnownSecrets();
    storage = _Storage();
    SharedPreferencesStorePlatform.instance = storage;
    SharedPreferences.resetStatic();
    prefs = await SharedPreferences.getInstance();
    controller = AutomationPolicyController(
      profileId: 'server-a',
      preferences: prefs,
    );
  });
  tearDown(() {
    controller.dispose();
    KitRedact.clearKnownSecrets();
  });

  test('fresh profile defaults follow consent boundaries without writing', () {
    expect(controller.value.supervision, AutomationSupervision.high);
    expect(controller.value.allowsAutoApproval, isFalse);
    expect(controller.value.allowsAutoMerge, isFalse);
    for (final behavior in AutomationBehavior.values) {
      expect(
        controller.value.allows(behavior),
        !{
          AutomationBehavior.restartDevServices,
          AutomationBehavior.stopIdleHelpers,
          AutomationBehavior.cleanCaches,
          AutomationBehavior.updateWhenIdle,
          AutomationBehavior.monitorOtherServers,
          AutomationBehavior.monitorQuota,
        }.contains(behavior),
        reason: behavior.name,
      );
    }
    expect(prefs.getKeys(), isEmpty);
    expect(
      () => controller.value.behaviors[AutomationBehavior.reconnect] = false,
      throwsUnsupportedError,
    );
  });

  test(
    'every choice can be disabled and survives restart per server',
    () async {
      await controller.setSupervision(AutomationSupervision.balanced);
      expect(controller.value.allowsAutoApproval, isTrue);
      expect(controller.value.allowsAutoMerge, isTrue);
      await controller.setAutoApprove(false);
      expect(controller.value.allowsAutoApproval, isFalse);
      expect(controller.value.allowsAutoMerge, isTrue);
      await controller.setAutoMergeOnGreen(false);
      for (final behavior in AutomationBehavior.values) {
        await controller.setBehavior(behavior, true);
        expect(controller.value.allows(behavior), isTrue);
        await controller.setBehavior(behavior, false);
      }
      final restored = AutomationPolicyController(
        profileId: 'server-a',
        preferences: prefs,
      );
      final other = AutomationPolicyController(
        profileId: 'server-b',
        preferences: prefs,
      );
      addTearDown(restored.dispose);
      addTearDown(other.dispose);
      expect(restored.value.supervision, AutomationSupervision.balanced);
      expect(restored.value.allowsAutoApproval, isFalse);
      expect(restored.value.allowsAutoMerge, isFalse);
      expect(restored.value.behaviors.values, everyElement(isFalse));
      expect(other.value.allows(AutomationBehavior.reconnect), isTrue);
      expect(other.value.allowsAutoApproval, isFalse);
      expect(prefs.getKeys(), {'oc.automation.server-a'});

      await controller.setSupervision(AutomationSupervision.autonomous);
      expect(controller.value.allowsAutoApproval, isTrue);
      await controller.setSupervision(AutomationSupervision.high);
      expect(controller.value.allowsAutoApproval, isFalse);
      expect(controller.value.allowsAutoMerge, isFalse);
      await controller.disableAll();
      expect(controller.value.behaviors.values, everyElement(isFalse));
    },
  );

  test(
    'concurrent edits compose and notify only after durable success',
    () async {
      final observed = <AutomationPolicy>[];
      controller.addListener(() => observed.add(controller.value));
      storage.gate = Completer<void>();
      storage.started = Completer<void>();
      final started = storage.started!.future;
      final first = controller.setBehavior(AutomationBehavior.reconnect, false);
      final second = controller.setBehavior(
        AutomationBehavior.monitorQuota,
        true,
      );
      await started;
      expect(observed, isEmpty);
      expect(controller.value.allows(AutomationBehavior.reconnect), isTrue);
      storage.gate!.complete();
      await Future.wait([first, second]);
      expect(observed, hasLength(2));
      expect(controller.value.allows(AutomationBehavior.reconnect), isFalse);
      expect(controller.value.allows(AutomationBehavior.monitorQuota), isTrue);
      expect(
        jsonDecode(prefs.getString('oc.automation.server-a')!)['behaviors'],
        containsPair('monitorQuota', true),
      );
    },
  );

  test(
    'reversible deletion pause drains admitted edits and resumes the same owner',
    () async {
      final shared = AutomationPolicyController.forProfile(prefs, 'shared-a');
      addTearDown(AutomationPolicyController.resetShared);
      addTearDown(shared.dispose);
      storage.gate = Completer<void>();
      storage.started = Completer<void>();
      final started = storage.started!.future;
      final first = shared.setBehavior(AutomationBehavior.reconnect, false);
      await started;
      final second = shared.setBehavior(AutomationBehavior.monitorQuota, true);
      final paused = shared.pauseForDeletion();
      await expectLater(shared.disableAll(), throwsStateError);
      expect(
        AutomationPolicyController.forProfile(prefs, 'shared-a'),
        same(shared),
      );
      storage.gate!.complete();
      await Future.wait([first, second, paused]);
      expect(shared.value.allows(AutomationBehavior.reconnect), isFalse);
      expect(shared.value.allows(AutomationBehavior.monitorQuota), isTrue);

      shared.cancelDeletion();
      await shared.setBehavior(AutomationBehavior.reconnect, true);
      expect(shared.value.allows(AutomationBehavior.reconnect), isTrue);
      expect(shared.value.allows(AutomationBehavior.monitorQuota), isTrue);
      await prefs.reload();
      expect(
        jsonDecode(prefs.getString('oc.automation.shared-a')!)['behaviors'],
        containsPair('monitorQuota', true),
      );
      await shared.prepareForDeletion();
      shared.cancelDeletion();
      await expectLater(shared.disableAll(), throwsStateError);
    },
  );

  test('refused and throwing writes preserve truth and permit retry', () async {
    await controller.setBehavior(AutomationBehavior.reconnect, false);
    var notifications = 0;
    controller.addListener(() => notifications++);
    for (final throws in [false, true]) {
      storage.refuse = !throws;
      storage.throwWrite = throws;
      await expectLater(
        controller.setSupervision(AutomationSupervision.autonomous),
        throwsStateError,
      );
      expect(controller.value.allowsAutoApproval, isFalse);
      final reopened = AutomationPolicyController(
        profileId: 'server-a',
        preferences: prefs,
      );
      expect(reopened.value.allowsAutoApproval, isFalse);
      expect(reopened.value.allows(AutomationBehavior.reconnect), isFalse);
      reopened.dispose();
    }
    expect(notifications, 0);
    storage.refuse = storage.throwWrite = false;
    await controller.setSupervision(AutomationSupervision.balanced);
    expect(notifications, 1);
  });

  test('malformed, future and partial storage never grant consent', () async {
    for (final raw in [
      '{',
      '[]',
      '{"version":2,"supervision":"autonomous","autoApprove":true}',
      '{"version":1,"supervision":"unknown","behaviors":{}}',
      '{"version":1,"supervision":"balanced","autoApprove":"true",'
          '"behaviors":{"monitorQuota":"true"}}',
    ]) {
      await prefs.setString('oc.automation.server-a', raw);
      final restored = AutomationPolicyController(
        profileId: 'server-a',
        preferences: prefs,
      );
      expect(restored.value.allowsAutoApproval, isFalse);
      expect(restored.value.allowsAutoMerge, isFalse);
      expect(restored.value.behaviors.values, everyElement(isFalse));
      restored.dispose();
    }
  });

  test('quiesce before profile sweep prevents late resurrection', () async {
    final other = AutomationPolicyController(
      profileId: 'server-b',
      preferences: prefs,
    );
    addTearDown(other.dispose);
    await other.setSupervision(AutomationSupervision.balanced);
    final keep = prefs.getString('oc.automation.server-b');
    storage.gate = Completer<void>();
    storage.started = Completer<void>();
    final started = storage.started!.future;
    final write = controller.setSupervision(AutomationSupervision.autonomous);
    await started;
    final stopped = controller.prepareForDeletion();
    final profiles = ProfileStore(prefs: prefs);
    final deletion = stopped.then(
      (_) => profiles.removeScopedPreferences('server-a'),
    );
    await expectLater(controller.disableAll(), throwsStateError);
    storage.gate!.complete();
    await write;
    await stopped;
    expect(await deletion, isEmpty);
    expect(prefs.getString('oc.automation.server-a'), isNull);
    expect(prefs.getString('oc.automation.server-b'), keep);
    expect(
      profiles.profileScopedPreferenceKeys('server-b'),
      contains('oc.automation.server-b'),
    );
  });

  test(
    'redaction boundary rejects protected payloads and secret IDs',
    () async {
      // Synthetic registration makes a normally safe enum name protected.
      KitRedact.registerKnownSecret('autonomous');
      await expectLater(
        controller.setSupervision(AutomationSupervision.autonomous),
        throwsStateError,
      );
      expect(prefs.getKeys(), isEmpty);
      expect(controller.value.allowsAutoApproval, isFalse);
      expect(
        () => AutomationPolicyController(profileId: '', preferences: prefs),
        throwsArgumentError,
      );
      expect(
        () => AutomationPolicyController(
          profileId: 'token=fake-only-credential',
          preferences: prefs,
        ),
        throwsArgumentError,
      );
    },
  );
}
