import 'package:opencode_sdk/opencode_sdk.dart' as sdk;

import '../domain/server_gateway.dart';
import '../domain/terminal_lifecycle.dart';

/// Rerun facet for the existing authenticated v1 SDK. The composition owner
/// supplies the source PTY's pinned location and owns the client's lifetime.
/// No new authentication state is created and the old PTY is never deleted.
class SdkTerminalCommandGateway implements TerminalCommandGateway {
  SdkTerminalCommandGateway(
    this._client, {
    required this.directory,
    this.workspace,
  });

  final sdk.OpencodeSdk _client;
  final String directory;
  final String? workspace;

  @override
  Future<TerminalProcess> rerunTerminalCommand(TerminalProcess ended) async {
    final command = terminalRerunSnapshot(ended);
    if (directory.trim().isEmpty) {
      throw const ProductException('The terminal location is unavailable.');
    }
    try {
      final response = await _client.getPtyApi().ptyCreate(
        directory: directory,
        workspace: workspace,
        ptyCreateRequest: sdk.PtyCreateRequest(
          command: command.command,
          args: command.arguments,
          cwd: command.directory,
          title: command.title,
        ),
      );
      final process = response.data;
      if (process == null || process.id.isEmpty) {
        throw const FormatException('Missing terminal');
      }
      return TerminalProcess(
        id: process.id,
        title: process.title,
        command: process.command,
        arguments: List.unmodifiable(process.args),
        directory: process.cwd,
        running: process.status == sdk.PtyStatusEnum.running,
        pid: process.pid,
        exitCode: process.exitCode,
      );
    } catch (_) {
      // Requests and raw errors can contain command arguments or credentials.
      // A failed response is not proof the server did not start the command.
      throw const ProductException(
        'Could not confirm the rerun. Refresh terminals before trying again.',
      );
    }
  }
}
