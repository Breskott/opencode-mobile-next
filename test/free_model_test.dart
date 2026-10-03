// Replies from OpenCode's free model (slice-builtin-speed): a server with no
// provider signed in answers with OpenCode's own free model, which is slower.
// The rule the chat, the model chip and This phone share.
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/free_model.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';

CatalogModel _model(String provider, String id, ModelCost? cost) =>
    CatalogModel(
      id: id,
      providerID: provider,
      name: id,
      enabled: true,
      status: 'active',
      contextLimit: 200000,
      outputLimit: 32000,
      reasoning: false,
      attachments: false,
      tools: true,
      variants: const [],
      cost: cost,
    );

const _free = ModelCost(inputPerMillion: 0, outputPerMillion: 0);
const _paid = ModelCost(inputPerMillion: 3, outputPerMillion: 15);

final _models = [
  _model('opencode', 'big-pickle', _free),
  _model('opencode', 'claude-sonnet-4', _paid),
  _model('opencode', 'no-price', null),
  _model('anthropic', 'claude-sonnet-4', _paid),
  _model('ollama', 'llama', _free),
];

bool _uses({
  List<String> signedIn = const [],
  required String provider,
  required String model,
}) => usesOpenCodeFreeModel(
  signedInProviderIDs: signedIn,
  providerID: provider,
  modelID: model,
  models: _models,
);

void main() {
  test('nobody signed in and OpenCode free model in use: yes', () {
    expect(_uses(provider: 'opencode', model: 'big-pickle'), isTrue);
    // OpenCode lists its own provider as connected without a sign-in.
    expect(
      _uses(signedIn: ['opencode'], provider: 'opencode', model: 'big-pickle'),
      isTrue,
    );
  });

  test('a composite catalog key still matches', () {
    expect(
      usesOpenCodeFreeModel(
        signedInProviderIDs: const [],
        providerID: 'opencode',
        modelID: 'big-pickle',
        models: [_model('opencode', 'opencode/big-pickle', _free)],
      ),
      isTrue,
    );
  });

  test('another provider signed in: the free model was a choice', () {
    expect(
      _uses(
        signedIn: ['opencode', 'anthropic'],
        provider: 'opencode',
        model: 'big-pickle',
      ),
      isFalse,
    );
  });

  test('a paid, unpriced, unknown or other provider model: no', () {
    expect(_uses(provider: 'opencode', model: 'claude-sonnet-4'), isFalse);
    expect(_uses(provider: 'opencode', model: 'no-price'), isFalse);
    expect(_uses(provider: 'opencode', model: 'missing'), isFalse);
    // A free local model is not OpenCode's shared free model.
    expect(_uses(provider: 'ollama', model: 'llama'), isFalse);
    expect(
      usesOpenCodeFreeModel(
        signedInProviderIDs: const [],
        providerID: null,
        modelID: null,
        models: _models,
      ),
      isFalse,
    );
  });
}
