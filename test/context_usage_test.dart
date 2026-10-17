// The context-window maths (what the ring, the sheet, the nudge and the
// chats list read), the per-profile memory behind the list's rings, and the
// Paseo agent usage mapping.
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/paseo/mappers.dart';
import 'package:opencode_mobile/state/context_usage.dart';
import 'package:opencode_mobile/state/context_usage_memory.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

CatalogModel _model(String id, int limit) => CatalogModel(
  id: id,
  providerID: 'p',
  name: 'Model $id',
  enabled: true,
  status: 'active',
  contextLimit: limit,
  outputLimit: 0,
  reasoning: false,
  attachments: false,
  tools: false,
  variants: const [],
);

CatalogSnapshot _catalog() => CatalogSnapshot(
  providers: const [],
  models: [_model('m', 200000), _model('nolimit', 0)],
  agents: const [],
);

MessageWithParts _reply(String id, int tokens, {String model = 'm'}) =>
    MessageWithParts(
      info: MessageInfo(
        id: id,
        sessionID: 's',
        role: 'assistant',
        providerID: 'p',
        modelID: model,
        tokens: Tokens(input: tokens),
      ),
      parts: const [],
    );

MessageWithParts _prompt(String id) => MessageWithParts(
  info: MessageInfo(id: id, sessionID: 's', role: 'user'),
  parts: [Part(type: 'text', text: 'hi')],
);

MessageWithParts _compaction(String id) => MessageWithParts(
  info: MessageInfo(id: id, sessionID: 's', role: 'user'),
  parts: [Part(type: 'v2:compaction', toolName: 'completed')],
);

void main() {
  group('contextFraction', () {
    test('tokens over the window; null when either is unknown', () {
      expect(contextFraction(84000, 200000), 0.42);
      expect(contextFraction(0, 200000), isNull);
      expect(contextFraction(5, 0), isNull);
    });
  });

  group('contextReadingFor', () {
    test('reads the newest reply against its own model', () {
      final reading = contextReadingFor([
        _prompt('u1'),
        _reply('a1', 40000),
        _prompt('u2'),
        _reply('a2', 168000),
      ], _catalog())!;
      expect(reading.tokens, 168000);
      expect(reading.limit, 200000);
      expect(reading.fraction, 0.84);
      expect(reading.modelName, 'Model m');
      expect(reading.replies.map((reply) => reply.fraction), [0.2, 0.84]);
      expect(reading.replies.map((reply) => reply.messageID), ['a1', 'a2']);
    });

    test('a reply with no tokens is not a bar', () {
      final reading = contextReadingFor([
        _reply('a1', 0),
        _reply('a2', 20000),
      ], _catalog())!;
      expect(reading.replies, hasLength(1));
    });

    test('marks the reply after a compaction, the drop in the chart', () {
      final reading = contextReadingFor([
        _reply('a1', 150000),
        _compaction('c1'),
        _reply('a2', 30000),
        _reply('a3', 50000),
      ], _catalog())!;
      expect(reading.replies.map((reply) => reply.afterCompaction), [
        false,
        true,
        false,
      ]);
      expect(reading.fraction, 0.25);
    });

    test('a compaction before any reply marks nothing', () {
      final reading = contextReadingFor([
        _compaction('c1'),
        _reply('a1', 30000),
      ], _catalog())!;
      expect(reading.replies.single.afterCompaction, isFalse);
    });

    test('unknown when there is no catalog, no reply, or no window', () {
      expect(contextReadingFor([_reply('a', 5000)], null), isNull);
      expect(contextReadingFor([_prompt('u')], _catalog()), isNull);
      expect(
        contextReadingFor([_reply('a', 5000, model: 'nolimit')], _catalog()),
        isNull,
      );
      expect(
        contextReadingFor([_reply('a', 5000, model: 'gone')], _catalog()),
        isNull,
      );
    });

    test('an unknown model on the newest reply hides the ring, as before', () {
      expect(
        contextReadingFor([
          _reply('a1', 5000),
          _reply('a2', 5000, model: 'gone'),
        ], _catalog()),
        isNull,
      );
    });
  });

  group('paseoContextUse', () {
    test('used over max tokens from an agent usage report', () {
      final use = paseoContextUse({
        'contextWindowUsedTokens': 50000,
        'contextWindowMaxTokens': 200000,
        'totalCostUsd': 0.4,
      })!;
      expect(use.tokens, 50000);
      expect(use.limit, 200000);
      expect(use.fraction, 0.25);
    });

    test('absent, partial or unusable usage is unknown', () {
      expect(paseoContextUse(null), isNull);
      expect(paseoContextUse({'totalCostUsd': 1}), isNull);
      expect(paseoContextUse({'contextWindowUsedTokens': 5}), isNull);
      expect(
        paseoContextUse({
          'contextWindowUsedTokens': 0,
          'contextWindowMaxTokens': 100,
        }),
        isNull,
      );
      expect(
        paseoContextUse({
          'contextWindowUsedTokens': 5,
          'contextWindowMaxTokens': 0,
        }),
        isNull,
      );
    });

    test('the session carries it', () {
      final session = paseoSession({
        'id': 'a1',
        'cwd': '/p',
        'provider': 'claude',
        'lastUsage': {
          'contextWindowUsedTokens': 100000,
          'contextWindowMaxTokens': 200000,
        },
      });
      expect(session.contextUse?.fraction, 0.5);
    });
  });

  group('ContextUsageMemory', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test(
      'remembers a value per session under oc.contextUsage.<profile>',
      () async {
        final memory = ContextUsageMemory.forProfile(prefs, 'alpha');
        expect(memory.usageOf('s1'), isNull);
        memory.remember('s1', 0.8123456);
        expect(memory.usageOf('s1'), 0.812);
        await Future<void>.delayed(Duration.zero);
        expect(
          prefs.getString('oc.contextUsage.alpha'),
          contains('"s1":0.812'),
        );
        // A fresh owner (a restart) reads it back.
        SharedPreferences.setMockInitialValues({
          'oc.contextUsage.beta': '{"s9":0.5}',
        });
        final other = await SharedPreferences.getInstance();
        expect(ContextUsageMemory.forProfile(other, 'beta').usageOf('s9'), 0.5);
      },
    );

    test('null forgets, nonsense is not kept', () {
      final memory = ContextUsageMemory.forProfile(prefs, 'alpha');
      memory.remember('s1', 0.9);
      memory.remember('s1', null);
      expect(memory.usageOf('s1'), isNull);
      memory.remember('s2', double.nan);
      expect(memory.usageOf('s2'), isNull);
    });

    test('keeps the newest 200 sessions', () {
      final memory = ContextUsageMemory.forProfile(prefs, 'alpha');
      for (var i = 0; i < ContextUsageMemory.maxEntries + 5; i++) {
        memory.remember('s$i', 0.5);
      }
      expect(memory.usageOf('s0'), isNull);
      expect(memory.usageOf('s4'), isNull);
      expect(memory.usageOf('s5'), 0.5);
      expect(memory.usageOf('s204'), 0.5);
    });

    test(
      'the profile sweep finds the key, and a late write cannot undo it',
      () async {
        final memory = ContextUsageMemory.forProfile(prefs, 'alpha');
        memory.remember('s1', 0.9);
        await Future<void>.delayed(Duration.zero);
        final store = ProfileStore(prefs: prefs);
        expect(
          store.profileScopedPreferenceKeys('alpha'),
          contains('oc.contextUsage.alpha'),
        );
        await store.removeScopedPreferences('alpha');
        expect(prefs.containsKey('oc.contextUsage.alpha'), isFalse);
        // The deleted server's chat still open: nothing comes back.
        memory.remember('s2', 0.95);
        await Future<void>.delayed(Duration.zero);
        expect(prefs.containsKey('oc.contextUsage.alpha'), isFalse);
        expect(memory.usageOf('s2'), isNull);
      },
    );
  });
}
