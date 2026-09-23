import 'package:flutter/services.dart';

import '../platform/platform_capabilities.dart';
import '../termux/bridge.dart' show TermuxRuntime;
import '../termux/opencode_ubuntu_setup.dart';

/// Where the built-in Ubuntu is in its life, as the Android side reports it.
enum BuiltinLinuxPhase {
  idle,
  installing,
  ready,
  failed;

  static BuiltinLinuxPhase parse(Object? value) => switch (value) {
    'installing' => installing,
    'ready' => ready,
    'failed' => failed,
    _ => idle,
  };
}

/// One reading of `status`.
class BuiltinLinuxStatus {
  const BuiltinLinuxStatus({
    required this.installed,
    required this.phase,
    this.message,
    this.serverRunning = false,
    this.serverPort,
    this.abi = '',
    this.bytesUsed,
  });

  /// Nothing installed and nothing running: what a runner without the
  /// channel (desktop, tests) honestly has.
  const BuiltinLinuxStatus.absent()
    : installed = false,
      phase = BuiltinLinuxPhase.idle,
      message = null,
      serverRunning = false,
      serverPort = null,
      abi = '',
      bytesUsed = null;

  factory BuiltinLinuxStatus.fromMap(Map<Object?, Object?> map) {
    int? asInt(Object? value) => value is num ? value.toInt() : null;
    final message = map['message'];
    return BuiltinLinuxStatus(
      installed: map['installed'] == true,
      phase: BuiltinLinuxPhase.parse(map['phase']),
      message: message is String && message.trim().isNotEmpty ? message : null,
      serverRunning: map['serverRunning'] == true,
      serverPort: asInt(map['serverPort']),
      abi: (map['abi'] ?? '').toString(),
      bytesUsed: asInt(map['bytesUsed']),
    );
  }

  final bool installed;
  final BuiltinLinuxPhase phase;
  final String? message;
  final bool serverRunning;
  final int? serverPort;
  final String abi;
  final int? bytesUsed;
}

/// The answer of one `run`.
class BuiltinLinuxRunResult {
  const BuiltinLinuxRunResult({required this.exitCode, required this.output});

  final int exitCode;

  /// The last 64 KB of stdout and stderr together.
  final String output;

  bool get ok => exitCode == 0;
}

class BuiltinLinuxException implements Exception {
  const BuiltinLinuxException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Ubuntu shipped inside the app, with no Termux (GitHub issue #87).
///
/// The Android side (BuiltinLinux.kt) owns the download, proot and the one
/// long-running server process; this class only speaks its method channel and
/// writes the shell scripts that run inside Ubuntu. Instances are cheap and
/// hold no state, so a screen can take one as a parameter and a test can pass
/// a subclass or a mocked channel.
class BuiltinLinux {
  BuiltinLinux({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName =
      'io.github.eslamasabry.opencode_mobile/builtin_linux';

  /// Not Termux's 4096. [TermuxBridge.managesServerUrl] treats
  /// 127.0.0.1:4096 as the Termux server and would try Termux restarts and
  /// Termux wake locks on it; a separate port keeps the two apart, and both
  /// can even run at once.
  static const serverPort = 4097;
  static const serverUrl = 'http://127.0.0.1:$serverPort';
  static const serverUsername = 'opencode';

  /// The Ubuntu working directory the server starts in. Same rule as the
  /// Termux runner: never the home folder, which OpenCode would scan whole.
  static const projectsDir = '/root/projects';

  /// Where the start script reads the server password from, so the secret is
  /// not part of the long-running command line or the server log.
  static const passwordFile = '/root/.oc-builtin/server.password';

  /// The proot build ships for Android only; no other runner has the channel.
  static bool get supported => platformCapabilities.isAndroid;

  static bool managesServerUrl(String? value) {
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null || uri.scheme != 'http') return false;
    final port = uri.hasPort ? uri.port : 80;
    return uri.host == '127.0.0.1' && port == serverPort;
  }

  final MethodChannel _channel;

  Future<BuiltinLinuxStatus> status() async {
    if (!supported) return const BuiltinLinuxStatus.absent();
    final raw = await _invoke<Map<Object?, Object?>>('status');
    return BuiltinLinuxStatus.fromMap(raw ?? const {});
  }

  /// Starts the download and unpack; returns at once. Poll [status].
  Future<void> installUbuntu() => _invoke<void>('installUbuntu');

  Future<BuiltinLinuxRunResult> run(
    String script, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final raw = await _invoke<Map<Object?, Object?>>('run', {
      'script': script,
      'timeoutSeconds': timeout.inSeconds,
    });
    final exitCode = raw?['exitCode'];
    return BuiltinLinuxRunResult(
      exitCode: exitCode is num ? exitCode.toInt() : -1,
      output: (raw?['output'] ?? '').toString(),
    );
  }

  Future<void> startServer(String script, {int port = serverPort}) =>
      _invoke<void>('startServer', {'script': script, 'port': port});

  Future<void> stopServer() => _invoke<void>('stopServer');

  Future<String> serverLog({int tailBytes = 32768}) async =>
      await _invoke<String>('serverLog', {'tailBytes': tailBytes}) ?? '';

  /// Stops the server and deletes Ubuntu with everything inside it.
  Future<void> uninstall() => _invoke<void>('uninstall');

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    if (!supported) {
      throw const BuiltinLinuxException(
        'The built-in Linux runs on Android only.',
        code: 'unsupported_platform',
      );
    }
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw BuiltinLinuxException(
        error.message?.trim().isNotEmpty == true
            ? error.message!
            : 'The built-in Linux failed (${error.code}).',
        code: error.code,
      );
    } on MissingPluginException {
      throw const BuiltinLinuxException(
        'This build of the app has no built-in Linux.',
        code: 'missing_plugin',
      );
    }
  }

  static String _quote(String value) => "'${value.replaceAll("'", "'\"'\"'")}'";

  static final _versionPattern = RegExp(r'^[A-Za-z0-9._+-]+$');

  /// Installs OpenCode inside Ubuntu with the very script the Termux manager
  /// runs ([openCodeUbuntuSetupScript]), at the same pinned version unless a
  /// caller asks for another on purpose.
  ///
  /// OpenCode 1 then refreshes its model catalog, as the Termux setup does.
  /// Unlike Termux a failed refresh does not fail the install: the server
  /// fetches the catalog itself later, and a flaky network at this moment
  /// should not throw away a finished install.
  static String installOpenCodeScript({
    TermuxRuntime runtime = TermuxRuntime.openCode1,
    String? version,
  }) {
    final selected = version ?? runtime.pinnedVersion;
    if (!_versionPattern.hasMatch(selected)) {
      throw ArgumentError.value(version, 'version', 'Invalid package version.');
    }
    final refresh = runtime == TermuxRuntime.openCode1
        ? "opencode models --refresh >/dev/null 2>&1 || "
              "echo '[oc] The model list could not be refreshed now; "
              "OpenCode will fetch it later.'\n"
        : '';
    // Interpolated verbatim: the shared text is a raw string, so nothing in
    // it is re-read as Dart here.
    return 'set -eu\n'
        'export OC_REQUESTED_VERSION=${_quote(selected)}\n'
        'export OC_RUNTIME=${_quote(runtime.wireName)}\n'
        "bash -s <<'OC_PROOT_SETUP'\n"
        '${openCodeUbuntuSetupScript}OC_PROOT_SETUP\n'
        '$refresh';
  }

  /// Prints the installed version of [runtime], or fails when it is missing.
  static String versionScript(TermuxRuntime runtime) =>
      runtime == TermuxRuntime.openCode2
      ? 'command -v opencode2 >/dev/null 2>&1 && opencode2 --version'
      : 'command -v opencode >/dev/null 2>&1 && opencode --version';

  /// The version out of `opencode --version` / `opencode2 --version`, which
  /// the Termux manager trims the same way (`opencode2 v2.0.10` → `2.0.10`).
  static String? parseVersion(String output) {
    for (final raw in output.split('\n').reversed) {
      var line = raw.trim();
      if (line.isEmpty) continue;
      for (final prefix in const ['opencode2 v', 'opencode v']) {
        if (line.startsWith(prefix)) line = line.substring(prefix.length);
      }
      return _versionPattern.hasMatch(line) ? line : null;
    }
    return null;
  }

  /// Saves the server password inside Ubuntu, readable by its root only.
  static String writePasswordScript(String password) {
    if (password.isEmpty) {
      throw ArgumentError.value(password, 'password', 'Must not be empty.');
    }
    final dir = passwordFile.substring(0, passwordFile.lastIndexOf('/'));
    return 'set -eu\n'
        'umask 077\n'
        'mkdir -p $dir\n'
        "printf '%s' ${_quote(password)} > $passwordFile.tmp\n"
        'mv $passwordFile.tmp $passwordFile\n';
  }

  /// The long-running server, mirroring the Termux runner: started in
  /// [projectsDir], bound to 127.0.0.1 only (nothing on this phone's network
  /// or the internet can reach it), Basic auth `opencode` + the password.
  ///
  /// OpenCode 2 gets the Termux runner's isolated XDG folders, so its data and
  /// config never mix with OpenCode 1 installed in the same Ubuntu.
  static String serverScript({
    TermuxRuntime runtime = TermuxRuntime.openCode1,
    int port = serverPort,
  }) {
    if (port < 1024 || port > 65535) {
      throw ArgumentError.value(
        port,
        'port',
        'Must be between 1024 and 65535.',
      );
    }
    final opencode2 = runtime == TermuxRuntime.openCode2;
    final binary = opencode2 ? 'opencode2' : 'opencode';
    final isolated = opencode2
        ? 'mkdir -p /root/.oc-opencode2/data/opencode /root/.oc-opencode2/cache '
              '/root/.oc-opencode2/state /root/.oc-opencode2/config/opencode\n'
              'unset OPENCODE_CONFIG OPENCODE_CONFIG_CONTENT\n'
              'export XDG_DATA_HOME=/root/.oc-opencode2/data\n'
              'export XDG_CACHE_HOME=/root/.oc-opencode2/cache\n'
              'export XDG_STATE_HOME=/root/.oc-opencode2/state\n'
              'export XDG_CONFIG_HOME=/root/.oc-opencode2/config\n'
              'export OPENCODE_CONFIG_DIR=/root/.oc-opencode2/config/opencode\n'
              'export OPENCODE_DB=/root/.oc-opencode2/data/opencode/opencode.db\n'
        : '';
    return 'set -eu\n'
        'mkdir -p $projectsDir\n'
        'cd $projectsDir\n'
        '[ -s $passwordFile ] || { echo "[oc] The server password is missing" >&2; exit 78; }\n'
        '$isolated'
        'password=\$(cat $passwordFile)\n'
        'export OPENCODE_SERVER_USERNAME=$serverUsername\n'
        'export OPENCODE_SERVER_PASSWORD="\$password"\n'
        'export OPENCODE_PASSWORD="\$password"\n'
        'unset password\n'
        'exec $binary serve --hostname 127.0.0.1 --port $port\n';
  }
}
