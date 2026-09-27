import '../domain/setup_assistant.dart';
import '../ui/kit/kit_redact.dart';
import 'client.dart';
import 'dialect.dart';
import 'transport.dart';

/// Setup inspection through the already authenticated, dialect-aware client.
///
/// The raw config map has a `sources` list in low-to-high priority order. It is
/// intentionally NOT a guessed effective config merge. Only the controller may
/// consume raw config; the UI receives its redacted snapshot.
class OpenCode2SetupConfigGateway implements SetupConfigGateway {
  OpenCode2SetupConfigGateway({required Api2Client client}) : _client = client;

  final Api2Client _client;

  @override
  SetupSupport get support => const SetupSupport(
    readConfig: true,
    mcpInventory: true,
    reason:
        'This server has no verified reversible configuration endpoint. '
        'Apply and Undo are unavailable.',
  );

  Future<Object?> _get(String path) async {
    try {
      return await _client.transport.getJson(
        path,
        query: {
          if (_client.directory != null)
            'location[directory]': _client.directory,
          if (_client.workspace != null)
            'location[workspace]': _client.workspace,
        },
      );
    } on Api2Error catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        throw const SetupFailure(
          SetupFailureCode.needsSignIn,
          'Sign in to this server to inspect setup.',
        );
      }
      if (error is Api2NetworkError) {
        throw const SetupFailure(
          SetupFailureCode.offline,
          'The server is unavailable. Reconnect and try again.',
        );
      }
      throw const SetupFailure(
        SetupFailureCode.transport,
        'The server could not load setup information.',
      );
    } on Api2RemovedInStable {
      throw const SetupFailure(
        SetupFailureCode.unsupported,
        'Setup inspection is unavailable on this server version.',
      );
    } catch (_) {
      throw const SetupFailure(
        SetupFailureCode.transport,
        'The server could not load setup information.',
      );
    }
  }

  @override
  Future<Map<String, Object?>> readConfig() async {
    final data = await _get('/config');
    KitRedact.registerCredentialValues(data);
    final sources = data is Map ? data['data'] : data;
    if (sources is! List ||
        sources.any((entry) => entry is! Map || entry['type'] is! String)) {
      throw const SetupFailure(
        SetupFailureCode.invalid,
        'The server returned an unsupported configuration response.',
      );
    }
    return {
      'sources': [
        for (final entry in sources)
          {
            'type': entry['type'],
            if (entry['path'] is String) 'path': entry['path'],
            if (entry['info'] is Map) 'info': entry['info'],
          },
      ],
    };
  }

  @override
  Future<void> patchConfig(Map<String, Object?> patch) async {
    throw SetupFailure(SetupFailureCode.unsupported, support.reason);
  }

  @override
  Future<List<SetupMcpStatus>> listMcpServers() async {
    final data = await _get('/mcp');
    final servers = data is Map ? data['data'] : null;
    if (servers is! List ||
        servers.any((entry) => entry is! Map || entry['name'] is! String)) {
      throw const SetupFailure(
        SetupFailureCode.invalid,
        'The server returned an unsupported MCP response.',
      );
    }
    const known = {'connected', 'pending', 'disabled', 'failed', 'needs_auth'};
    return [
      for (final server in servers)
        SetupMcpStatus(
          name: KitRedact.text(server['name'] as String),
          status:
              server['status'] is Map &&
                  known.contains(server['status']['status'])
              ? server['status']['status'] as String
              : 'unknown',
        ),
    ];
  }
}
