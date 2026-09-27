import 'package:dio/dio.dart';

import '../domain/setup_assistant.dart';
import '../ui/kit/kit_redact.dart';
import 'opencode_api.dart';

/// Read-only setup view using the profile's existing authenticated transport.
///
/// Config is raw only at this adapter/controller boundary. UI callers must use
/// the setup controller's redacted snapshot, never this transport directly.
/// PATCH exists, but cannot promise deletion or restoration of layered config.
class OpenCode1SetupConfigGateway implements SetupConfigGateway {
  OpenCode1SetupConfigGateway({required OpenCodeApi api}) : _api = api;

  final OpenCodeApi _api;

  @override
  SetupSupport get support => const SetupSupport(
    readConfig: true,
    mcpInventory: true,
    reason:
        'This server cannot safely restore configuration changes. '
        'Apply and Undo are unavailable.',
  );

  Map<String, Object?> get _query => {
    if (_api.directory != null) 'directory': _api.directory,
    if (_api.workspace != null) 'workspace': _api.workspace,
  };

  Future<Object?> _get(String path) async {
    try {
      final response = await _api.dio.get<Object?>(
        path,
        queryParameters: _query,
      );
      return response.data;
    } on DioException catch (error) {
      final code = error.response?.statusCode;
      if (code == 401 || code == 403) {
        throw const SetupFailure(
          SetupFailureCode.needsSignIn,
          'Sign in to this server to inspect setup.',
        );
      }
      if (code == null) {
        throw const SetupFailure(
          SetupFailureCode.offline,
          'The server is unavailable. Reconnect and try again.',
        );
      }
      throw const SetupFailure(
        SetupFailureCode.transport,
        'The server could not load setup information.',
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
    if (data is! Map<String, dynamic>) {
      throw const SetupFailure(
        SetupFailureCode.invalid,
        'The server returned an unsupported configuration response.',
      );
    }
    return Map<String, Object?>.from(data);
  }

  @override
  Future<void> patchConfig(Map<String, Object?> patch) async {
    throw SetupFailure(SetupFailureCode.unsupported, support.reason);
  }

  @override
  Future<List<SetupMcpStatus>> listMcpServers() async {
    final data = await _get('/mcp');
    if (data is! Map<String, dynamic>) {
      throw const SetupFailure(
        SetupFailureCode.invalid,
        'The server returned an unsupported MCP response.',
      );
    }
    const known = {
      'connected',
      'disabled',
      'failed',
      'needs_auth',
      'needs_client_registration',
    };
    return [
      for (final entry in data.entries)
        SetupMcpStatus(
          name: KitRedact.text(entry.key),
          status: entry.value is Map && known.contains(entry.value['status'])
              ? entry.value['status'] as String
              : 'unknown',
        ),
    ];
  }
}
