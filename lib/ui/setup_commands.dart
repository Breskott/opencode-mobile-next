import '../state/profiles.dart';

/// The commands a person runs on their computer, written once. The connect
/// screen shows the one that starts the chosen agent and the setup guide
/// lists the rest; both must print the same text or a copied command and a
/// read one drift apart.
///
/// Sources: `docs/paseo-connection.md`, `docs/codex-connection.md`.
abstract final class SetupCommands {
  /// Starts OpenCode 2 and prints a pairing code.
  static const pair = 'opencode2 pair';

  /// Older servers that do not print a pairing code.
  static const legacyServe =
      'OPENCODE_SERVER_PASSWORD=your-secret \\\n'
      '  opencode serve --hostname 127.0.0.1 --port 4096';

  /// The Paseo daemon, kept off the relay. This app never uses the relay.
  static const paseoStart = 'paseo start --no-relay';

  static const paseoStartPrivateNetwork =
      "PASEO_PASSWORD='choose-a-long-secret' \\\n"
      '  paseo start --no-relay --listen "\$(tailscale ip -4):6767"';

  static const codexToken =
      'umask 077\n'
      "python3 -c 'import secrets; "
      'print(secrets.token_urlsafe(32), end="")\' '
      '> /absolute/path/codex-capability-token\n'
      'chmod 600 /absolute/path/codex-capability-token';

  static const codexStart =
      'codex app-server \\\n'
      '  --listen ws://127.0.0.1:4141 \\\n'
      '  --ws-auth capability-token \\\n'
      '  --ws-token-file /absolute/path/codex-capability-token';

  static const codexUsb = 'adb reverse tcp:4141 tcp:4141';

  /// The one command that starts [backend] on the computer.
  static String startFor(ServerBackend backend) => switch (backend) {
    ServerBackend.openCode => pair,
    ServerBackend.paseo => paseoStart,
    ServerBackend.codex => codexStart,
  };
}
