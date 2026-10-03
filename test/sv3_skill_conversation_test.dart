import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/domain/sv3_skill_capabilities.dart';
import 'package:opencode_mobile/state/sv3_skill_conversation.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';

const _skill = SkillInfo(
  id: 'skill-review',
  name: 'Review',
  location: '/skills/review/SKILL.md',
  content: 'Review changes.',
  slashCommand: false,
);

class _Gateway implements ServerGateway {
  @override
  ServerCapabilities capabilities = const ServerCapabilities();
  @override
  bool isClosed = false;
  final prompts = <(String, String)>[];
  bool failPrompt = false;
  int creates = 0;
  Future<Session> Function()? create;
  Map<Symbol, dynamic>? promptOptions;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #createSession) {
      creates++;
      return create!();
    }
    if (invocation.memberName == #promptAsync) {
      promptOptions = invocation.namedArguments;
      prompts.add((
        invocation.positionalArguments.single as String,
        invocation.namedArguments[#text] as String,
      ));
      return failPrompt
          ? Future<void>.error(StateError('synthetic transport error'))
          : Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _Operations implements ServerOperationsGateway, SessionSkillGateway {
  @override
  bool sessionSkillsSupported = true;
  final activations = <(String, String, bool)>[];
  bool failActivation = false;

  @override
  Future<void> activateSessionSkill(
    String sessionID,
    String skillID, {
    required bool resume,
  }) async {
    activations.add((sessionID, skillID, resume));
    if (failActivation) throw StateError('synthetic transport error');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SelectedGateway extends _Gateway implements SessionSelectionGateway {
  SessionSelection? selected;

  @override
  Future<Session> createSelectedSession(SessionSelection defaults) {
    selected = defaults;
    creates++;
    return create!();
  }
}

void main() {
  late _Gateway gateway;
  late _Operations operations;
  late SkillConversationController controller;
  late Session session;
  var current = true;
  Completer<Session>? creation;

  setUp(() {
    KitRedact.clearKnownSecrets();
    gateway = _Gateway();
    operations = _Operations();
    current = true;
    creation = null;
    session = Session(id: 'ses_new');
    gateway.create = () async =>
        creation == null ? session : await creation!.future;
    controller = SkillConversationController(
      gateway: gateway,
      operations: operations,
      isCurrent: () => current,
      selection: const SessionSelection(agent: 'reviewer', variant: 'focused'),
    );
  });
  tearDown(KitRedact.clearKnownSecrets);

  test('captures creation selection and refuses a stale connection', () async {
    final selected = _SelectedGateway()..create = () async => session;
    const selection = SessionSelection(agent: 'reviewer', variant: 'focused');
    final action = SkillConversationController(
      gateway: selected,
      operations: operations,
      isCurrent: () => current,
      selection: selection,
    );
    current = false;
    expect(
      (await action.useInNewConversation(_skill)).status,
      SkillConversationStatus.changed,
    );
    expect(selected.creates, 0);
    current = true;
    expect(
      (await action.useInNewConversation(_skill)).status,
      SkillConversationStatus.ready,
    );
    expect(selected.selected, same(selection));
    expect(selected.creates, 1);
  });

  test(
    'creates then stages the protocol skill ID without running agent',
    () async {
      final result = await controller.useInNewConversation(_skill);
      expect(result.status, SkillConversationStatus.ready);
      expect(result.session, same(session));
      expect(gateway.creates, 1);
      expect(operations.activations, [('ses_new', 'skill-review', false)]);
      expect(gateway.prompts, isEmpty);
      expect(
        (await controller.useInNewConversation(_skill)).status,
        SkillConversationStatus.alreadyStarted,
      );
      expect(gateway.creates, 1);
    },
  );

  test('unsupported or missing ID never creates a conversation', () async {
    operations.sessionSkillsSupported = false;
    expect(
      (await controller.useInNewConversation(_skill)).status,
      SkillConversationStatus.unsupported,
    );
    operations.sessionSkillsSupported = true;
    const missingID = SkillInfo(
      name: 'Review',
      location: '',
      content: '',
      slashCommand: true,
    );
    expect(
      (await controller.useInNewConversation(missingID)).status,
      SkillConversationStatus.invalidInput,
    );
    gateway.capabilities = const ServerCapabilities(serverCatalog: false);
    expect(controller.canUseSkill, isFalse);
    expect(controller.canAskForSkill, isFalse);
    expect(
      (await controller.askAgentToWriteSkill('Review code')).status,
      SkillConversationStatus.unsupported,
    );
    expect(gateway.capabilities.providerKeyPageLinks, isFalse);
    expect(gateway.creates, 0);
  });

  test(
    'connection change during create preserves session without activation',
    () async {
      creation = Completer<Session>();
      final pending = controller.useInNewConversation(_skill);
      current = false;
      creation!.complete(session);
      final result = await pending;
      expect(result.status, SkillConversationStatus.changed);
      expect(result.session, same(session));
      expect(operations.activations, isEmpty);
    },
  );

  test('ambiguous activation keeps session and never retries', () async {
    operations.failActivation = true;
    final result = await controller.useInNewConversation(_skill);
    expect(result.status, SkillConversationStatus.activationUncertain);
    expect(result.session, same(session));
    await controller.useInNewConversation(_skill);
    expect(gateway.creates, 1);
    expect(operations.activations.length, 1);
  });

  test(
    'creation failure prevents both dispatch and duplicate creation',
    () async {
      creation = Completer<Session>();
      final pending = controller.useInNewConversation(_skill);
      expect(
        (await controller.useInNewConversation(_skill)).status,
        SkillConversationStatus.alreadyStarted,
      );
      creation!.completeError(StateError('synthetic create error'));
      expect((await pending).status, SkillConversationStatus.creationUncertain);
      expect(gateway.creates, 1);
      expect(operations.activations, isEmpty);
    },
  );

  test(
    'authoring sends a redacted draft request and reports uncertain sends',
    () async {
      const fakeSecret = 'fake-sv3-provider-value';
      KitRedact.registerKnownSecret(fakeSecret);
      expect(
        (await controller.askAgentToWriteSkill('  ')).status,
        SkillConversationStatus.invalidInput,
      );
      gateway.failPrompt = true;
      final result = await controller.askAgentToWriteSkill(
        'Review code with $fakeSecret',
      );
      expect(result.status, SkillConversationStatus.promptUncertain);
      expect(result.session, same(session));
      expect(gateway.prompts.single.$1, 'ses_new');
      expect(gateway.promptOptions?[#agent], 'reviewer');
      expect(gateway.promptOptions?[#variant], 'focused');
      expect(gateway.prompts.single.$2.contains(fakeSecret), isFalse);
      expect(gateway.prompts.single.$2.contains('Do not install'), isTrue);
      await controller.askAgentToWriteSkill('Review code');
      expect(gateway.prompts.length, 1);
      expect(operations.activations, isEmpty);
    },
  );
}
