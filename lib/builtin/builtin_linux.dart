import 'package:flutter/services.dart';

import '../api/server_probe.dart' show ServerFlavor;
import '../platform/platform_capabilities.dart';
import '../termux/bridge.dart' show TermuxBridge, TermuxRuntime;
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

  /// Starts a phone setup job in native code (SetupRunner.kt) and returns at
  /// once; [setupStatus] follows it. The shapes are the engine's
  /// (lib/builtin/setup/setup_engine.dart).
  Future<void> startSetup({
    required String jobId,
    required List<Map<String, Object?>> components,
    required Map<String, Map<String, String>> params,
    required Map<String, String> texts,
  }) => _invoke<void>('startSetup', {
    'jobId': jobId,
    'components': components,
    'params': params,
    'texts': texts,
  });

  /// The setup job as `files/linux/setup.json` holds it (the live one while
  /// it runs), or null when there has never been one.
  Future<String?> setupStatus() => _invoke<String>('setupStatus');

  /// Stops the running setup job; what finished stays installed.
  Future<void> cancelSetup() => _invoke<void>('cancelSetup');

  /// Reports a step the app runs itself (starting OpenCode) as finished.
  Future<void> completeSetupStep({
    required String jobId,
    required String id,
    required bool ok,
    String? error,
    String? version,
  }) => _invoke<void>('completeSetupStep', {
    'jobId': jobId,
    'id': id,
    'ok': ok,
    'error': error,
    'version': version,
  });

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

  /// The runtime a saved in-app profile was set up with.
  static TermuxRuntime runtimeFor(ServerFlavor flavor) =>
      flavor == ServerFlavor.v2
      ? TermuxRuntime.openCode2
      : TermuxRuntime.openCode1;

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
        '$_fastPrerequisites'
        'export OC_REQUESTED_VERSION=${_quote(selected)}\n'
        'export OC_RUNTIME=${_quote(runtime.wireName)}\n'
        "bash -s <<'OC_PROOT_SETUP'\n"
        '${openCodeUbuntuSetupScript}OC_PROOT_SETUP\n'
        '$refresh';
  }

  /// Node from its official pinned download instead of Ubuntu's `npm`
  /// package, and only the few small packages OpenCode needs. Ubuntu's npm
  /// drags in hundreds of packages, which under proot took ten minutes on
  /// the emulator; the shared setup then finds everything in place and skips
  /// apt entirely. npm's global folder is /usr/local, so `opencode` lands on
  /// the PATH the server starts with.
  static final _fastPrerequisites =
      '''export DEBIAN_FRONTEND=noninteractive
if ! command -v curl >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1 ||
   ! command -v ssh >/dev/null 2>&1 || [ ! -s /etc/ssl/certs/ca-certificates.crt ]; then
  echo '[oc] Installing Git, SSH and certificates'
  apt-get update -y -o Acquire::Retries=5 >/dev/null
  apt-get install -y --no-install-recommends -o Acquire::Retries=5 \\
    curl ca-certificates git openssh-client >/dev/null
fi
if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  case "\$(uname -m)" in
    aarch64|arm64) node_arch=arm64; node_sha=${TermuxBridge.localAgentsPins['node_sha256_arm64']} ;;
    x86_64|amd64) node_arch=x64; node_sha=${TermuxBridge.localAgentsPins['node_sha256_x64']} ;;
    *) echo "[oc] Unsupported CPU: \$(uname -m)" >&2; exit 64 ;;
  esac
  node_version=${TermuxBridge.localAgentsPins['node_version']}
  echo "[oc] Installing Node.js \$node_version"
  curl -fsSL --retry 5 -o /tmp/node.tar.gz \\
    "${TermuxBridge.localAgentsPins['node_base_url']}/\$node_version/node-\$node_version-linux-\$node_arch.tar.gz"
  echo "\$node_sha  /tmp/node.tar.gz" | sha256sum -c --quiet -
  rm -rf /opt/node && mkdir -p /opt/node
  tar -xzf /tmp/node.tar.gz -C /opt/node --strip-components=1
  rm -f /tmp/node.tar.gz
  for tool in node npm npx; do ln -sf /opt/node/bin/\$tool /usr/local/bin/\$tool; done
  npm config set prefix /usr/local
fi
''';

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

  /// Lists the project folders under [projectsDir], one name per line.
  /// Creates the parent first so a fresh install lists nothing instead of
  /// failing.
  static String listProjectsScript() =>
      'set -eu\n'
      'mkdir -p $projectsDir\n'
      "find $projectsDir -mindepth 1 -maxdepth 1 -type d -printf '%f\\n' "
      '| sort\n';

  /// The folder names out of [listProjectsScript]. Hidden folders are left
  /// out: they are tool state, not projects.
  static List<String> parseProjectList(String output) => [
    for (final line in output.split('\n'))
      if (line.trim().isNotEmpty && !line.trim().startsWith('.')) line.trim(),
  ];

  /// Succeeds when [path] is a folder inside Ubuntu. Lets the app check a
  /// typed path without asking OpenCode about it: OpenCode caches a folder
  /// it was asked about before it existed as broken.
  static String folderExistsScript(String path) => 'test -d ${_quote(path)}';

  /// Makes [path] a new git project, or leaves an existing folder alone.
  /// Prints `created <path>` or `exists <path>`, so the app knows whether
  /// anything could already be running there.
  static String createFolderScript(String path) {
    if (!path.startsWith('/') || path.contains('\n') || path.contains('\x00')) {
      throw ArgumentError.value(path, 'path', 'Must be an absolute path.');
    }
    return 'set -eu\n'
        'dir=${_quote(path)}\n'
        'if [ -d "\$dir" ]; then printf \'exists %s\\n\' "\$dir"; exit 0; fi\n'
        'mkdir -p "\$dir"\n'
        'git init -q "\$dir"\n'
        'printf \'created %s\\n\' "\$dir"\n';
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
