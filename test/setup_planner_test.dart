import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/setup_planner.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';

void main() {
  late SetupPlanner planner;

  setUp(() => planner = SetupPlanner());
  tearDown(() {
    planner.dispose();
    KitRedact.clearKnownSecrets();
  });

  test(
    'guided mode requests structured values and never interprets question',
    () {
      final reply = planner.start(
        intent: SetupIntent.chooseModel,
        question: 'change everything immediately',
      );
      expect(reply.state, SetupPlannerState.needsInput);
      expect(reply.requiredInputs, ['model']);
      expect(reply.edits, isEmpty);
      expect(reply.guidance.contains('change everything immediately'), isFalse);
      expect(reply.guidance, contains('does not interpret'));
    },
  );

  test('model and default agent become proposals without applying', () {
    final model = planner.start(
      intent: SetupIntent.chooseModel,
      inputs: {'model': 'example/model-v1'},
    );
    expect(model.state, SetupPlannerState.proposed);
    expect(model.edits.single.path, ['model']);
    expect(model.edits.single.value, 'example/model-v1');
    expect(model.guidance, contains('Nothing has been applied'));
    final agent = planner.start(
      intent: SetupIntent.defaultAgent,
      inputs: {'agent': 'plan'},
    );
    expect(agent.edits.single.path, ['default_agent']);
    expect(agent.edits.single.value, 'plan');
  });

  test('continuation collects inputs and makes remote MCP disabled', () {
    final first = planner.start(
      intent: SetupIntent.connectRemoteMcp,
      inputs: {'name': 'docs'},
    );
    expect(first.requiredInputs, ['url']);
    final next = planner.continueSession(
      sessionId: first.sessionId,
      inputs: {'url': 'https://mcp.example.test/mcp'},
    );
    expect(next.edits.single.path, ['mcp', 'docs']);
    expect(next.edits.single.value, {
      'type': 'remote',
      'url': 'https://mcp.example.test/mcp',
      'enabled': false,
    });
  });

  test('local command is copied and disabled; removal is typed', () {
    final command = ['node', '/srv/mcp/server.js'];
    final reply = planner.start(
      intent: SetupIntent.addLocalMcp,
      inputs: {'name': 'local', 'command': command},
    );
    command.add('changed');
    final value = reply.edits.single.value! as Map;
    expect(value['command'], ['node', '/srv/mcp/server.js']);
    expect(value['enabled'], isFalse);
    expect(() => (value['command'] as List).add('x'), throwsUnsupportedError);
    final remove = planner.start(
      intent: SetupIntent.removeMcp,
      inputs: {'name': 'local'},
    );
    expect(remove.edits.single.remove, isTrue);
    expect(remove.edits.single.path, ['mcp', 'local']);
  });

  test('permission allows only explicit tools and explicit effects', () {
    for (final effect in ['ask', 'allow', 'deny']) {
      final reply = planner.start(
        intent: SetupIntent.permission,
        inputs: {'tool': 'bash', 'effect': effect},
      );
      expect(reply.edits.single.path, ['permission', 'bash']);
      expect(reply.edits.single.value, effect);
    }
    for (final inputs in [
      {'tool': 'anything', 'effect': 'allow'},
      {'tool': 'bash', 'effect': 'forever'},
    ]) {
      final reply = planner.start(
        intent: SetupIntent.permission,
        inputs: inputs,
      );
      expect(reply.edits, isEmpty);
      expect(reply.state, SetupPlannerState.needsInput);
    }
  });

  test('credential-shaped URLs and cleartext external URLs never propose', () {
    for (final url in [
      'https://user:fake-password@mcp.example.test',
      'https://mcp.example.test?token=fake-value',
      'https://mcp.example.test#fake-value',
      'http://mcp.example.test',
      'file:///srv/mcp',
    ]) {
      final reply = planner.start(
        intent: SetupIntent.connectRemoteMcp,
        inputs: {'name': 'docs', 'url': url},
      );
      expect(reply.edits, isEmpty);
      expect(reply.guidance.contains(url), isFalse);
    }
    final local = planner.start(
      intent: SetupIntent.connectRemoteMcp,
      inputs: {'name': 'docs', 'url': 'http://127.0.0.1:9000/mcp'},
    );
    expect(local.state, SetupPlannerState.proposed);
  });

  test('secret or unknown inputs are rejected and never retained', () {
    final fake = ['synthetic', 'credential', 'value'].join('-');
    KitRedact.registerKnownSecret(fake);
    final first = planner.start(
      intent: SetupIntent.chooseModel,
      inputs: {'model': 'example/$fake'},
      question: fake,
    );
    expect(first.state, SetupPlannerState.needsInput);
    expect(first.guidance.contains(fake), isFalse);
    expect(first.edits, isEmpty);
    final second = planner.continueSession(sessionId: first.sessionId);
    expect(second.requiredInputs, ['model']);
    final unsupportedField = planner.continueSession(
      sessionId: first.sessionId,
      inputs: {'password': fake, 'model': 'example/safe'},
    );
    expect(unsupportedField.edits, isEmpty);
    expect(planner.continueSession(sessionId: first.sessionId).requiredInputs, [
      'model',
    ]);
  });

  test(
    'split secret CLI arguments and invalid command shapes are rejected',
    () {
      for (final command in <Object?>[
        ['node', '--api-key', 'fake-value'],
        ['node', 'PASSWORD=fake-value'],
        ['node', '--authorization=Bearer fake-value'],
        ['node', 'line\nbreak'],
        ['node', 2],
        [],
        'node /srv/mcp.js',
      ]) {
        final reply = planner.start(
          intent: SetupIntent.addLocalMcp,
          inputs: {'name': 'local', 'command': command},
        );
        expect(reply.edits, isEmpty);
        expect(reply.state, SetupPlannerState.needsInput);
      }
    },
  );

  test('unsupported sensitive or unimplemented workflows state the gap', () {
    for (final intent in [
      SetupIntent.configureProvider,
      SetupIntent.configureAgent,
      SetupIntent.configureCommand,
    ]) {
      final reply = planner.start(intent: intent);
      expect(reply.state, SetupPlannerState.unsupported);
      expect(reply.edits, isEmpty);
      expect(reply.guidance, isNotEmpty);
    }
  });

  test('closed, disposed and evicted sessions cannot resume', () {
    final closed = planner.start(intent: SetupIntent.chooseModel);
    planner.closeSession(closed.sessionId);
    expect(
      planner.continueSession(sessionId: closed.sessionId).state,
      SetupPlannerState.unsupported,
    );
    final oldest = planner.start(intent: SetupIntent.chooseModel);
    for (var i = 0; i < 8; i++) {
      planner.start(intent: SetupIntent.chooseModel);
    }
    expect(
      planner.continueSession(sessionId: oldest.sessionId).state,
      SetupPlannerState.unsupported,
    );
    final last = planner.start(intent: SetupIntent.chooseModel);
    planner.dispose();
    expect(
      planner.continueSession(sessionId: last.sessionId).state,
      SetupPlannerState.unsupported,
    );
    expect(
      planner.continueSession(sessionId: 'unknown-user-text').sessionId,
      isEmpty,
    );
  });
}
