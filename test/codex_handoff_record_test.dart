import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/codex/handoff_record.dart';
import 'package:opencode_mobile/codex/transport.dart';
import 'package:opencode_mobile/domain/agent_handoff_record.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';

Map<String, dynamic> _thread(List<Map<String, dynamic>> turns) => {
  'id': 'source',
  'historyMode': 'legacy',
  'turns': turns,
};

Map<String, dynamic> _turn(
  List<Map<String, dynamic>> items, {
  String id = 'turn-1',
  String status = 'completed',
}) => {'id': id, 'status': status, 'itemsView': 'full', 'items': items};

Map<String, dynamic> _user(String text, {String id = 'user-1'}) => {
  'id': id,
  'type': 'userMessage',
  'content': [
    {'type': 'text', 'text': text},
  ],
};

Map<String, dynamic> _answer(String text, {String id = 'answer-1'}) => {
  'id': id,
  'type': 'agentMessage',
  'phase': 'final_answer',
  'text': text,
};

HandoffRecord _record(Map<String, dynamic> thread, {int maxBytes = 98304}) =>
    buildAgentHandoffRecord(
      session: Session(
        id: 'source',
        directory: '/repo',
        agent: 'Codex',
        model: 'gpt-6.1-sol',
      ),
      messages: codexHandoffMessages(thread),
      lastState: 'waiting for you',
      maxBytes: maxBytes,
    );

void main() {
  setUp(KitRedact.clearKnownSecrets);
  tearDown(KitRedact.clearKnownSecrets);

  test(
    'preserves full prompts and final text, excluding reasoning/commentary',
    () {
      const prompt = '  Keep this exactly\nالعربية 🚀\n```dart\nx();\n```';
      final answer = List.filled(6000, '界').join();
      final record = _record(
        _thread([
          _turn([
            _user(prompt),
            {
              'id': 'reasoning-1',
              'type': 'reasoning',
              'summary': ['private reasoning excluded'],
              'content': ['private reasoning body excluded'],
            },
            {
              ..._answer('interim commentary excluded', id: 'commentary-1'),
              'phase': 'commentary',
            },
            _answer(answer),
            {
              ..._answer('Legacy visible answer', id: 'legacy-1'),
              'phase': null,
            },
          ]),
        ]),
      );
      expect(record.markdown, contains(prompt));
      expect(record.markdown, contains(answer));
      expect(record.markdown, contains('Legacy visible answer'));
      expect(record.markdown, contains('did not record whether'));
      expect(record.markdown, isNot(contains('private reasoning')));
      expect(record.markdown, isNot(contains('interim commentary')));
      expect(record.byteLength, utf8.encode(record.markdown).length);
    },
  );

  test('retains command cwd and exit outcome, masking before shortening', () {
    const token = 'sk-test-super-secret-0123456789abcdefghijklmnop';
    final record = _record(
      _thread([
        _turn([
          _user('Run the tests'),
          {
            'id': 'command-1',
            'type': 'commandExecution',
            'command': 'dart test',
            'cwd': '/repo',
            'status': 'completed',
            'exitCode': 1,
            'aggregatedOutput': 'Failed\nAPI_KEY=$token',
            'arbitrary': 'excluded arbitrary metadata',
          },
        ]),
      ]),
    );
    for (final text in ['dart test', '/repo', 'exitCode: 1', 'Failed']) {
      expect(record.markdown, contains(text));
    }
    expect(record.markdown, contains('status: "error"'));
    expect(record.markdown, isNot(contains(token)));
    expect(record.markdown, isNot(contains('excluded arbitrary metadata')));
    expect(record.redacted, isTrue);
  });

  test('exports successful paths and step outcomes without patch bodies', () {
    final record = _record(
      _thread([
        _turn([
          _user('Fix the parser'),
          for (final status in ['completed', 'failed', 'declined'])
            {
              'id': 'file-$status',
              'type': 'fileChange',
              'status': status,
              'changes': [
                {
                  'path': 'lib/$status.dart',
                  'kind': {
                    'type': 'update',
                    'move_path': status == 'completed'
                        ? 'lib/moved.dart'
                        : null,
                  },
                  'diff': 'raw patch excluded',
                },
              ],
            },
        ]),
      ]),
    );
    final provenance = record.markdown.split('## Tasks').first;
    expect(provenance, contains('lib/completed.dart'));
    expect(provenance, contains('lib/moved.dart'));
    expect(provenance, isNot(contains('lib/failed.dart')));
    expect(provenance, isNot(contains('lib/declined.dart')));
    expect(record.markdown, contains('lib/failed.dart'));
    expect(record.markdown, contains('not executed'));
    expect(record.markdown, isNot(contains('raw patch excluded')));
  });

  test('summarizes known tools using allowlisted fields and text results', () {
    const token = 'sk-test-super-secret-0123456789abcdefghijklmnop';
    final record = _record(
      _thread([
        _turn([
          _user('Continue the work'),
          {
            'id': 'mcp-1',
            'type': 'mcpToolCall',
            'tool': 'inspect',
            'status': 'completed',
            'arguments': {
              'path': 'lib/parser.dart',
              'command': 'inspect parser',
              'url': 'excluded-tool-url',
              'secret': 'excluded-tool-argument',
            },
            'result': {
              'content': [
                {'type': 'text', 'text': 'Found parser\nAPI_KEY=$token'},
                {
                  'type': 'resource',
                  'resource': {'text': 'excluded-resource-body'},
                },
              ],
              'structuredContent': {'secret': 'excluded-structured-content'},
              '_meta': {'secret': 'excluded-tool-meta'},
            },
            'error': {'message': 'excluded-tool-error'},
          },
          {
            'id': 'dynamic-1',
            'type': 'dynamicToolCall',
            'tool': 'test',
            'status': 'completed',
            'success': false,
            'arguments': {'cmd': 'dart test', 'cwd': '/repo'},
            'contentItems': [
              {'type': 'inputText', 'text': 'Two tests failed'},
              {'type': 'inputImage', 'imageUrl': 'excluded-image-url'},
              {'type': 'inputAudio', 'audioUrl': 'excluded-audio-url'},
            ],
          },
          {
            'id': 'function-1',
            'type': 'functionCallOutput',
            'name': 'check',
            'output': [
              {'type': 'input_text', 'text': 'Check result'},
              {'type': 'input_image', 'image_url': 'excluded-function-image'},
              {
                'type': 'encrypted_content',
                'encrypted_content': 'excluded-encrypted-content',
              },
            ],
          },
          {
            'id': 'collab-1',
            'type': 'collabAgentToolCall',
            'tool': 'wait',
            'status': 'interrupted',
            'prompt': 'excluded-agent-prompt',
            'agentsStates': {'private-id': 'excluded-agent-state'},
          },
        ]),
      ]),
    );
    for (final included in [
      'mcp:inspect',
      'lib/parser.dart',
      'inspect parser',
      'Found parser',
      'dynamic:test',
      'Two tests failed',
      'status: "error"',
      'function:check',
      'Check result',
      'success not reported',
      'agent:wait',
      'status: "cancelled"',
      'Non-text result content excluded.',
    ]) {
      expect(record.markdown, contains(included));
    }
    expect(record.markdown, isNot(contains('excluded-')));
    expect(record.markdown, isNot(contains(token)));
    expect(record.redacted, isTrue);
  });

  test('bounds concatenated text tool results without silently clipping', () {
    expect(
      () => codexHandoffMessages(
        _thread([
          _turn([
            {
              'id': 'function-1',
              'type': 'functionCallOutput',
              'name': 'check',
              'output': [
                for (var i = 0; i < 2; i++)
                  {
                    'type': 'input_text',
                    'text': List.filled(600000, 'x').join(),
                  },
              ],
            },
          ]),
        ]),
      ),
      throwsA(
        isA<CodexFailure>().having(
          (e) => e.kind,
          'kind',
          CodexFailureKind.invalidResponse,
        ),
      ),
    );
  });

  test('discloses plan, compaction, attachments and unsupported items', () {
    final record = _record(
      _thread([
        _turn([
          {
            ..._user('Continue'),
            'content': [
              {'type': 'text', 'text': 'Continue'},
              {'type': 'image', 'url': 'data:secret-image-excluded'},
            ],
          },
          {'id': 'plan-1', 'type': 'plan', 'text': '1. Check the parser'},
          {
            'id': 'compact-1',
            'type': 'contextCompaction',
            'text': 'private compaction metadata excluded',
          },
          {
            'id': 'unknown-1',
            'type': 'futureItem',
            'metadata': 'private unsupported metadata excluded',
          },
        ]),
      ]),
    );
    expect(record.markdown, contains('1. Check the parser'));
    expect(record.markdown, contains('conversation compaction event'));
    expect(record.markdown, contains('Attachment contents excluded'));
    expect(record.markdown, contains('unsupported item'));
    expect(record.markdown, contains('No tasks reported.'));
    expect(record.markdown, isNot(contains('private compaction')));
    expect(record.markdown, isNot(contains('private unsupported')));
    expect(record.markdown, isNot(contains('secret-image')));
  });

  test(
    'records empty failed/interrupted turns without remote error bodies',
    () {
      final record = _record(
        _thread([
          {
            ..._turn([], status: 'failed'),
            'error': {'message': 'remote secret error excluded'},
          },
          _turn([], id: 'turn-2', status: 'interrupted'),
          _turn([], id: 'turn-3', status: 'inProgress'),
        ]),
      );
      expect(record.markdown, contains('The Codex turn failed.'));
      expect(record.markdown, contains('interrupted before completion'));
      expect(record.markdown, contains('still in progress'));
      expect(record.markdown, isNot(contains('remote secret error')));
    },
  );

  test('keeps newest turns full and refuses an oversized newest turn', () {
    final newest = List.filled(200, '界').join();
    final record = _record(
      _thread([
        _turn([_user(List.filled(3000, 'x').join()), _answer('Old answer')]),
        _turn([
          _user(newest, id: 'user-2'),
          _answer('New answer', id: 'answer-2'),
        ], id: 'turn-2'),
      ]),
      maxBytes: 2200,
    );
    expect(record.markdown, contains(newest));
    expect(record.markdown, contains('New answer'));
    expect(record.markdown, isNot(contains('Old answer')));
    expect(record.omittedMessages, 2);
    expect(record.byteLength, lessThanOrEqualTo(2200));
    expect(
      () => _record(
        _thread([
          _turn([_user(List.filled(100000, '界').join())]),
        ]),
      ),
      throwsA(isA<HandoffRecordTooLarge>()),
    );
  });

  test(
    'malformed identities, arrays, states and fields fail without content',
    () {
      final invalid = <Map<String, dynamic>>[
        {'id': 'source', 'turns': null},
        {..._thread([])}..remove('historyMode'),
        {..._thread([]), 'historyMode': 'unknown'},
        _thread([
          {'status': 'completed', 'items': []},
        ]),
        _thread([_turn([]), _turn([])]),
        _thread([
          _turn([_user('one'), _user('two')]),
        ]),
        _thread([_turn([], status: 'unknown')]),
        _thread([
          {..._turn([]), 'itemsView': 'summary'},
        ]),
        _thread([
          {..._turn([]), 'itemsView': 'notLoaded'},
        ]),
        _thread([
          {..._turn([])}..remove('itemsView'),
        ]),
        _thread([
          {'id': 'turn', 'status': 'completed', 'items': 'not-list'},
        ]),
        _thread([
          _turn([
            {..._answer('secret malformed text'), 'phase': 'unknown'},
          ]),
        ]),
        _thread([
          _turn([
            {'id': 'command', 'type': 'commandExecution', 'status': 'unknown'},
          ]),
        ]),
        _thread([
          _turn([
            {'id': 'user', 'type': 'userMessage', 'content': null},
          ]),
        ]),
      ];
      for (final thread in invalid) {
        expect(
          () => codexHandoffMessages(thread),
          throwsA(
            isA<CodexFailure>()
                .having((e) => e.kind, 'kind', CodexFailureKind.invalidResponse)
                .having(
                  (e) => e.toString(),
                  'safe copy',
                  isNot(contains('secret')),
                ),
          ),
        );
      }
    },
  );

  test('bounds mapped messages, total persisted items and text size', () {
    final tooManyMessages = _thread([
      _turn([for (var i = 0; i < 5001; i++) _answer('Answer', id: 'item-$i')]),
    ]);
    final tooManyItems = _thread([
      for (var turn = 0; turn < 2; turn++)
        _turn([
          for (var i = 0; i < 5001; i++)
            {'id': 'reason-$turn-$i', 'type': 'reasoning'},
        ], id: 'turn-$turn'),
    ]);
    final tooMuchText = _thread([
      _turn([_user(List.filled(1024 * 1024 + 1, 'x').join())]),
    ]);
    for (final thread in [tooManyMessages, tooManyItems, tooMuchText]) {
      expect(
        () => codexHandoffMessages(thread),
        throwsA(
          isA<CodexFailure>().having(
            (e) => e.kind,
            'kind',
            CodexFailureKind.invalidResponse,
          ),
        ),
      );
    }
  });
}
