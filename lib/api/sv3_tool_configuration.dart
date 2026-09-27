import 'package:opencode_sdk/opencode_sdk.dart' as sdk;

import '../domain/server_gateway.dart';
import '../domain/sv3_tool_configuration.dart';
import '../ui/kit/kit_redact.dart';

/// OpenCode 1 companion adapter using the coordinator's authenticated SDK client.
///
/// Construct alongside the ordinary gateway, with the same capabilities and
/// location. Recreate when profile/location changes; this immutable location
/// prevents an in-flight write from drifting to another project. This adapter
/// neither owns nor closes `client`. SDK transport logging must remain disabled
/// because PATCH responses may contain provider credentials.
class V1ToolConfigurationGateway
    implements ToolConfigurationGateway, McpConfigurationGateway {
  final sdk.OpencodeSdk _client;
  final ServerCapabilities _capabilities;
  final String? _directory;
  final String? _workspace;

  V1ToolConfigurationGateway({
    required sdk.OpencodeSdk client,
    required ServerCapabilities capabilities,
    String? directory,
    String? workspace,
  }) : _client = client,
       _capabilities = capabilities,
       _directory = directory,
       _workspace = workspace;

  @override
  Future<void> setCodingToolEnabled(
    String toolID,
    bool enabled, {
    required CodingToolConfigScope scope,
  }) async {
    if (!_capabilities.canConfigureCodingTools(gateway: this)) {
      throw const ToolConfigurationException(
        ToolConfigurationError.unavailable,
      );
    }
    if (toolID.isEmpty ||
        toolID != toolID.trim() ||
        toolID.contains(RegExp(r'[\x00-\x1f\x7f]')) ||
        KitRedact.containsSecret(toolID)) {
      throw const ToolConfigurationException(
        ToolConfigurationError.invalidToolID,
      );
    }
    await _writePatch(sdk.Config(tools: {toolID: enabled}), scope);
  }

  @override
  Future<void> setMcpServerEnabled(
    String name,
    bool enabled, {
    required CodingToolConfigScope scope,
  }) async {
    if (!_capabilities.canConfigureMcpEnablement(gateway: this)) {
      throw const ToolConfigurationException(
        ToolConfigurationError.unavailable,
      );
    }
    if (name.trim().isEmpty ||
        name != name.trim() ||
        name.contains(RegExp(r'[\x00-\x1f\x7f]')) ||
        KitRedact.containsSecret(name)) {
      throw const ToolConfigurationException(
        ToolConfigurationError.invalidMcpServer,
      );
    }
    await _writePatch(
      sdk.Config(
        mcp: {
          name: sdk.OpencodeSdkRawUnion013({'enabled': enabled}),
        },
      ),
      scope,
    );
  }

  Future<void> _writePatch(
    sdk.Config patch,
    CodingToolConfigScope scope,
  ) async {
    if (scope == CodingToolConfigScope.project &&
        _directory?.trim().isNotEmpty != true) {
      throw const ToolConfigurationException(
        ToolConfigurationError.projectRequired,
      );
    }

    // Patch just one entry: never fetch, retain, log or expose credential-bearing
    // configuration, and never rewrite another tool or server's setting.
    try {
      switch (scope) {
        case CodingToolConfigScope.project:
          await _client.getConfigApi().configUpdate(
            directory: _directory,
            workspace: _workspace,
            config: patch,
          );
        case CodingToolConfigScope.global:
          await _client.getGlobalApi().globalConfigUpdate(config: patch);
      }
    } catch (_) {
      throw const ToolConfigurationException(
        ToolConfigurationError.requestFailed,
      );
    }
  }
}
