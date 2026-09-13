import 'package:flutter/services.dart';

import '../domain/workspace_paths.dart';
import '../platform/platform_capabilities.dart';

/// The runtime selected for the one app-managed Ubuntu server. It is separate
/// from a server's reported version and survives restarts in the manager state.
enum TermuxRuntime {
  openCode1('opencode1', '1.18.29'),
  openCode2('opencode2', '0.0.0-beta-18600');

  const TermuxRuntime(this.wireName, this.pinnedVersion);
  final String wireName;
  final String pinnedVersion;

  static TermuxRuntime parse(String? value) => switch (value?.trim()) {
    null || '' || 'opencode1' => openCode1,
    'opencode2' => openCode2,
    _ => throw const TermuxBridgeException(
      'The managed server has an unsupported runtime selection.',
      code: 'invalid_runtime',
    ),
  };
}

/// Drives Termux over the `oc/termux` method channel.
///
/// Termux is an Android app and the channel is implemented only by the
/// Android runner, so every entry point here is a no-op-with-an-answer on
/// desktop rather than a throw: `MissingPluginException` is not a
/// `PlatformException`, so a bridge that caught only the latter let a raw
/// framework exception escape into UI code that had no idea what it meant.
class TermuxBridge {
  static const _channel = MethodChannel('oc/termux');

  /// Every failure the bridge can report for "this platform has no Termux".
  static const unsupportedPlatformCode = 'unsupported_platform';

  /// Whether the Termux bridge can do anything at all here.
  static bool get supported => platformCapabilities.supportsTermux;

  static TermuxBridgeException get _unsupported => const TermuxBridgeException(
    'Termux runs on Android. This desktop build connects to an OpenCode '
    'server you start yourself.',
    code: unsupportedPlatformCode,
  );

  static const termuxHome = '/data/data/com.termux/files/home';
  static const _managerPath = '$termuxHome/.oc/manager.sh';
  static const managedServerPort = 4096;
  static const managedServerUrl = 'http://127.0.0.1:$managedServerPort';

  /// The OpenCode server version a published build installs and updates to.
  ///
  /// Pinned, deliberately. `latest` meant an APK sitting on a phone for
  /// months would one day install a server release published long after this
  /// client was written and tested against it — a protocol change on the
  /// server side would then break setup on a device whose owner changed
  /// nothing. This is the version the app's contracts and fixtures are
  /// verified against; raising it is a code change with a test run behind it,
  /// not something that happens on its own.
  ///
  /// Keep this in step with the shell fallback in [_managerScript]
  /// (`requested_version="${2:-…}"`); a test asserts the two agree.
  static const defaultOpenCodeVersion = '1.18.29';

  /// The npm dist-tag, available only when a caller passes it to
  /// [installAndServeScript] on purpose. Nothing in the app does today: it
  /// exists so a deliberate "install whatever is newest" flow has a name
  /// rather than a magic string.
  static const latestOpenCodeVersion = 'latest';

  static bool managesServerUrl(String? value) {
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null || uri.scheme != 'http') return false;
    final port = uri.hasPort ? uri.port : 80;
    return uri.host == '127.0.0.1' && port == managedServerPort;
  }

  static Future<TermuxCapabilities> capabilities() async {
    if (!supported) return const TermuxCapabilities.unavailable();
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'getCapabilities',
      );
      return TermuxCapabilities.fromMap(raw ?? const {});
    } on MissingPluginException {
      // A runner with no `oc/termux` handler: honestly nothing installed.
      return const TermuxCapabilities.unavailable();
    }
  }

  static Future<bool> requestPermission() =>
      _invokeFlag('requestRunCommandPermission');

  static Future<bool> openTermux() => _invokeFlag('openTermux');

  static Future<bool> openAppSettings() => _invokeFlag('openAppSettings');

  /// Every one of these answers "did the platform do the thing?", so a
  /// missing channel is simply `false` — never an exception a caller that
  /// wanted a bool has to know about.
  static Future<bool> _invokeFlag(String method) async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<TermuxCommandResult> run(
    String script, {
    bool background = true,
    String? workdir,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!supported) throw _unsupported;
    try {
      final raw = await _channel
          .invokeMapMethod<String, dynamic>('runInTermux', {
            'script': script,
            'background': background,
            'workdir': workdir ?? termuxHome,
            'timeoutMs': timeout.inMilliseconds,
          });
      final command = TermuxCommandResult.fromMap(raw ?? const {});
      if (!command.successful) {
        throw TermuxBridgeException(
          command.failureMessage,
          code: 'command_failed',
        );
      }
      return command;
    } on MissingPluginException {
      // The Android runner registers `oc/termux`; nothing else does. Reaching
      // here means a platform slipped past [supported] — report it the way a
      // caller already handles rather than letting a framework exception out.
      throw _unsupported;
    } on PlatformException catch (error) {
      throw TermuxBridgeException(
        error.message ?? 'Termux command failed.',
        code: error.code,
      );
    }
  }

  static Future<void> verifyBridge() async {
    final result = await run("printf 'opencode-bridge-ok'");
    if (result.stdout.trim() != 'opencode-bridge-ok') {
      throw const TermuxBridgeException(
        'Termux returned an unexpected bridge response.',
        code: 'invalid_probe',
      );
    }
  }

  /// Keeps the managed on-device OpenCode server able to reach providers
  /// while Android is idle. The manager releases this lock when the server is
  /// stopped or exits; repeated acquisitions are safe in Termux.
  static Future<void> ensureWakeLock() async {
    await run(ensureWakeLockScript, timeout: const Duration(seconds: 10));
  }

  static const ensureWakeLockScript =
      "termux-wake-lock >/dev/null 2>&1 || true; "
      "echo opencode-server-wake-lock-held";

  static Future<TermuxSetupStatus> status() async {
    final result = await run(statusScript());
    return TermuxSetupStatus.parse(result.stdout);
  }

  static Future<TermuxStorageSnapshot> storage() async {
    final result = await run(
      storageScript(),
      timeout: const Duration(seconds: 8),
    );
    return TermuxStorageSnapshot.parse(result.stdout);
  }

  static String storageScript() =>
      '''
set -euo pipefail
LC_ALL=C timeout -k 1s 5s df -Pk '$termuxHome' | awk 'NR == 2 { printf "total_kib=%s\\navailable_kib=%s\\n", \$2, \$4 }'
''';

  // ---- Phone tools (TEAM-304/305): storage and process views -------------
  //
  // `~/.oc/tools.sh` lives beside manager.sh and is rewritten on every call
  // (tmp + mv, so a scan already running keeps its own copy). Every verb
  // answers with JSON or `key=value` lines that lib/termux/storage.dart and
  // lib/termux/processes.dart parse; nothing here starts or stops the
  // managed server.
  static const toolsPath = '$termuxHome/.oc/tools.sh';

  static const toolVerbs = {
    'storage-scan',
    'storage-status',
    'storage-summary',
    'storage-cancel',
    'storage-clean',
    'procs-scan',
    'procs-stop',
  };

  static String toolsScriptForTesting() => _toolsScript;

  /// Shell that installs the current tools script and runs [verb]. A
  /// `storage-scan` is dispatched into the background (it measures tens of
  /// gigabytes) and acknowledged with `tools-started:<pid>`; every other verb
  /// runs in the foreground and prints its answer.
  static String toolsCommandScript(String verb, {String argument = ''}) {
    if (!toolVerbs.contains(verb)) {
      throw ArgumentError.value(verb, 'verb', 'Unknown tools verb.');
    }
    if (!RegExp(r'^[A-Za-z0-9_]{0,32}$').hasMatch(argument)) {
      throw ArgumentError.value(argument, 'argument', 'Invalid argument.');
    }
    final launch = verb == 'storage-scan'
        ? r"""
rm -f "$OC_DIR/storage-scan.cancel"
scan_pid=$(cat "$OC_DIR/storage-scan.pid" 2>/dev/null || true)
case "$scan_pid" in
  ''|*[!0-9]*) ;;
  *) if kill -0 "$scan_pid" 2>/dev/null; then
       echo "tools-already-running:$scan_pid"
       exit 0
     fi ;;
esac
set -m
nohup "$TOOLS" storage-scan >/dev/null 2>&1 </dev/null &
echo "tools-started:$!"
"""
        : 'exec "\$TOOLS" $verb${argument.isEmpty ? '' : " '$argument'"}\n';
    return '''
set -eu
OC_DIR="$termuxHome/.oc"
TOOLS="$toolsPath"
mkdir -p "\$OC_DIR"
umask 077
tools_tmp="\$TOOLS.tmp.\$\$"
cat > "\$tools_tmp" <<'OC_TOOLS_EOF'
$_toolsScript
OC_TOOLS_EOF
chmod 700 "\$tools_tmp"
mv "\$tools_tmp" "\$TOOLS"
[ -x "\$TOOLS" ] || { echo 'tools-install-failed' >&2; exit 74; }
$launch''';
  }

  /// Runs one tools verb and returns its stdout.
  static Future<String> runTool(
    String verb, {
    String argument = '',
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final result = await run(
      toolsCommandScript(verb, argument: argument),
      timeout: timeout,
    );
    return result.stdout;
  }

  /// Grant/revoke only this app's managed-server recovery permit.
  static String recoveryControlScript(String token, {required bool enable}) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(token)) {
      throw ArgumentError.value(token, 'token');
    }
    return '''
set -eu
MANAGER="$_managerPath"
[ -x "\$MANAGER" ] || { echo 'managed-server-missing' >&2; exit 75; }
${enable ? '[ ! -e "$termuxHome/.oc/setup.lock" ] || exit 75' : ''}
manager_tmp="\$MANAGER.tmp.\$\$"
cat > "\$manager_tmp" <<'OC_MANAGER_EOF'
$_managerScript
OC_MANAGER_EOF
chmod 700 "\$manager_tmp"
mv "\$manager_tmp" "\$MANAGER"
exec "\$MANAGER" ${enable ? 'recovery-arm' : 'recovery-disarm'} '$token'
''';
  }

  static Future<TermuxSetupSnapshot> setupSnapshot() async {
    final result = await run(setupSnapshotScript());
    return TermuxSetupSnapshot.parse(result.stdout);
  }

  /// Inspects only the app-owned Ubuntu installation; never starts a server.
  static Future<TermuxInstallation> inspectInstallation() async {
    final result = await run(
      installationScript(),
      timeout: const Duration(seconds: 25),
    );
    return TermuxInstallation.parse(result.stdout);
  }

  static String installationScript() => r'''
set -eu
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
runtime=$(cat "$HOME/.oc/runtime" 2>/dev/null || true)
recorded_runtime="$runtime"
case "$runtime" in
  ''|opencode1) runtime=opencode1; command=opencode ;;
  opencode2) command=opencode2 ;;
  *) echo 'unsupported-managed-runtime' >&2; exit 64 ;;
esac
if [ ! -d "$PREFIX/var/lib/proot-distro/containers/opencode-ubuntu/rootfs" ] &&
   [ ! -d "$PREFIX/var/lib/proot-distro/installed-rootfs/opencode-ubuntu" ]; then
  printf 'ubuntu=absent\nversion=\n'
  [ -z "$recorded_runtime" ] || printf 'runtime=%s\n' "$runtime"
  exit 0
fi
# A missing/broken proot command or a hung version probe is an error, not an
# absent installation. Bound the whole login, including container startup.
timeout -k 2s 20s proot-distro login opencode-ubuntu -- bash -c '
set -eu
runtime="$1"
binary="$2"
recorded_runtime="$3"
if ! command -v "$binary" >/dev/null 2>&1; then
  printf "ubuntu=installed\nversion=\n"
  [ -z "$recorded_runtime" ] || printf "runtime=%s\n" "$runtime"
  exit 0
fi
version=$("$binary" --version)
if [ "$runtime" = opencode2 ]; then version=${version#opencode2 v}; fi
printf "ubuntu=installed\nversion=%s\n" "$version"
[ -z "$recorded_runtime" ] || printf "runtime=%s\n" "$runtime"
' -- "$runtime" "$command" "$recorded_runtime"
''';

  static Future<String> diagnostics() async {
    final result = await run(diagnosticsScript());
    return result.stdout.trim();
  }

  /// Shell that creates `/root/projects/<name>` inside the managed container
  /// and prints its absolute path. [name] must already pass
  /// `projectFolderNameProblem`, so it is a single safe path segment.
  static String createProjectFolderScript(String name) =>
      '''
set -eu
timeout -k 2s 30s proot-distro login opencode-ubuntu -- sh -c '
set -eu
name="\$1"
case "\$name" in ""|.|..|*/*|.*) echo "invalid-folder-name" >&2; exit 64 ;; esac
dir="$managedProjectsDirectory/\$name"
mkdir -p "\$dir"
test -d "\$dir"
printf "%s\\n" "\$dir"
' -- '$name'
''';

  /// Creates a project folder under `/root/projects` in the managed
  /// container and returns its absolute path. Only the app-managed Termux
  /// server can do this; other servers have no folder-creation API.
  static Future<String> createProjectFolder(String name) async {
    final problem = projectFolderNameProblem(name);
    if (problem != null) {
      throw TermuxBridgeException(problem, code: 'invalid_folder_name');
    }
    final folder = name.trim();
    final result = await run(
      createProjectFolderScript(folder),
      timeout: const Duration(seconds: 45),
    );
    final path = result.stdout.trim().split('\n').last.trim();
    if (path != '$managedProjectsDirectory/$folder') {
      throw TermuxBridgeException(
        'The folder could not be created in the managed server.',
        code: 'folder_not_created',
      );
    }
    return path;
  }

  static bool isLaunchAcknowledged(String output) => RegExp(
    r'(^|\n)manager-(started|already-running):[0-9]+($|\n)',
  ).hasMatch(output.trim());

  static const unlockCommand =
      "mkdir -p ~/.termux && touch ~/.termux/termux.properties && "
      "grep -q '^allow-external-apps=true' ~/.termux/termux.properties || "
      "echo 'allow-external-apps=true' >> ~/.termux/termux.properties; "
      "termux-reload-settings; echo bridge-unlocked";

  static String installAndServeScript({
    int port = 4096,
    required String password,
    String? version,
    TermuxRuntime runtime = TermuxRuntime.openCode1,
  }) {
    final selectedVersion = version ?? runtime.pinnedVersion;
    if (port < 1024 || port > 65535) {
      throw ArgumentError.value(
        port,
        'port',
        'Must be between 1024 and 65535.',
      );
    }
    if (!RegExp(r'^[A-Za-z0-9._+-]+$').hasMatch(selectedVersion)) {
      throw ArgumentError.value(version, 'version', 'Invalid package version.');
    }
    if (password.isEmpty) {
      throw ArgumentError.value(password, 'password', 'Must not be empty.');
    }

    final quotedPassword = _shellQuote(password);
    return '''
set -eu
OC_DIR="$termuxHome/.oc"
MANAGER="$_managerPath"
LOCK="\$OC_DIR/setup.lock"
mkdir -p "\$OC_DIR"
umask 077

if [ ! -e "\$MANAGER" ] && [ -d "\$OC_DIR/bin" ]; then
  touch "\$OC_DIR/legacy-install"
fi
manager_tmp="\$MANAGER.tmp.\$\$"
cat > "\$manager_tmp" <<'OC_MANAGER_EOF'
$_managerScript
OC_MANAGER_EOF
chmod 700 "\$manager_tmp"
mv "\$manager_tmp" "\$MANAGER"
[ -x "\$MANAGER" ] || {
  echo 'manager-install-failed' >&2
  exit 74
}

process_start() {
  stat_line=\$(cat "/proc/\$1/stat" 2>/dev/null) || return 1
  stat_line=\${stat_line##*) }
  set -- \$stat_line
  printf '%s' "\${20:-}"
}

self_start=\$(process_start "\$\$")
if [ -f "\$LOCK" ]; then
  owner_pid=''
  owner_start=''
  read -r owner_pid owner_start < "\$LOCK" 2>/dev/null || true
  live_start=\$(process_start "\$owner_pid" 2>/dev/null || true)
  if [ -n "\$owner_pid" ] && [ -n "\$owner_start" ] && [ "\$owner_start" = "\$live_start" ] &&
     kill -0 "\$owner_pid" 2>/dev/null; then
    echo "manager-already-running:\$owner_pid"
    exit 0
  fi
  rm -f "\$LOCK"
fi
if mkdir "\$LOCK" 2>/dev/null; then
  printf '%s %s\n' "\$\$" "\$self_start" > "\$LOCK/owner"
else
  owner_pid=''
  owner_start=''
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    read -r owner_pid owner_start < "\$LOCK/owner" 2>/dev/null && break
    sleep 0.1
  done
  live_start=\$(process_start "\$owner_pid" 2>/dev/null || true)
  case "\$owner_pid" in
    ''|*[!0-9]*) ;;
    *) if [ -n "\$owner_start" ] && [ "\$owner_start" = "\$live_start" ] &&
         kill -0 "\$owner_pid" 2>/dev/null; then
         echo "manager-already-running:\$owner_pid"
         exit 0
       fi ;;
  esac
  if [ -z "\$owner_pid" ] || [ -z "\$owner_start" ]; then
    echo 'setup-lock-owner-missing; use Retry' >&2
  else
    echo 'setup-lock-stale; use Retry' >&2
  fi
  exit 75
fi
cleanup_dispatch() {
  lock_pid=''
  lock_start=''
  read -r lock_pid lock_start < "\$LOCK/owner" 2>/dev/null || true
  if [ "\$lock_pid" = "\$\$" ] && [ "\$lock_start" = "\$self_start" ]; then
    rm -f "\$LOCK/owner" "\$LOCK"/owner.tmp.*
    rmdir "\$LOCK" 2>/dev/null || true
  fi
}
trap cleanup_dispatch EXIT

# Changing generations in an existing installation is a separate migration.
# First-run selection and same-runtime repair never rewrite that decision.
[ ! -f "\$OC_DIR/runtime-switch" ] || { echo 'managed-runtime-switch-pending' >&2; exit 75; }
old_runtime=\$(cat "\$OC_DIR/runtime" 2>/dev/null || true)
old_version=\$(sed -n 's/^version=//p' "\$OC_DIR/state" 2>/dev/null || true)
if { [ -n "\$old_runtime" ] || [ -n "\$old_version" ]; } &&
   [ "\${old_runtime:-opencode1}" != '${runtime.wireName}' ]; then
  echo 'managed-runtime-migration-required' >&2
  exit 64
fi
printf '%s' '${runtime.wireName}' > "\$OC_DIR/runtime.tmp.\$\$"
mv "\$OC_DIR/runtime.tmp.\$\$" "\$OC_DIR/runtime"
password_tmp="\$OC_DIR/server.password.tmp.\$\$"
printf '%s' $quotedPassword > "\$password_tmp"
chmod 600 "\$password_tmp"
mv "\$password_tmp" "\$OC_DIR/server.password"
started_at=\$(date +%s)
printf 'phase=queued\nmessage=Setup queued\nport=$port\nrunner=proot\nversion=\npid=\nstarted_at=%s\nruntime=${runtime.wireName}\n' "\$started_at" > "\$OC_DIR/state"
# From this point a stale dispatcher lock is safer than deleting a lock while
# the child is claiming it. Stop & retry handles stale ownership explicitly.
trap - EXIT
rm -f "\$OC_DIR/server-log.active"
"\$MANAGER" rotate-log install
set -m
nohup "\$MANAGER" setup '$port' '$selectedVersion' "\$\$" "\$self_start" '${runtime.wireName}' > >("\$MANAGER" write-log install) 2>&1 </dev/null &
manager_pid=\$!
manager_start=\$(process_start "\$manager_pid" || true)
[ -n "\$manager_start" ] || {
  wait "\$manager_pid" 2>/dev/null || true
  echo 'manager-exited-before-start' >&2
  exit 70
}
printf '%s %s\n' "\$manager_pid" "\$manager_start" > "\$OC_DIR/manager.pid"
claimed=0
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  lock_pid=''
  lock_start=''
  read -r lock_pid lock_start < "\$LOCK/owner" 2>/dev/null || true
  if [ "\$lock_pid" = "\$manager_pid" ] && [ "\$lock_start" = "\$manager_start" ]; then
    claimed=1
    break
  fi
  kill -0 "\$manager_pid" 2>/dev/null || break
  sleep 0.1
done
if [ "\$claimed" != 1 ]; then
  kill -KILL "\$manager_pid" 2>/dev/null || true
  wait "\$manager_pid" 2>/dev/null || true
  echo 'manager-lock-claim-failed' >&2
  exit 70
fi
echo "manager-started:\$manager_pid"
''';
  }

  static String statusScript() =>
      '''
if [ -x "$_managerPath" ]; then
  exec "$_managerPath" status
fi
if [ -f "$termuxHome/.oc/state" ]; then
  port=4096
  while IFS='=' read -r name value; do
    [ "\$name" = port ] && port="\$value"
  done < "$termuxHome/.oc/state"
  printf 'phase=failed\nmessage=Setup manager is missing after launch\nport=%s\nrunner=\nversion=\npid=\n' "\$port"
  exit 0
fi
printf 'phase=idle\nmessage=No setup has been started\nport=4096\nrunner=\nversion=\npid=\n'
''';

  static String setupSnapshotScript() =>
      '''
OC_DIR="$termuxHome/.oc"
if [ -x "$_managerPath" ]; then
  if manager_output=\$("$_managerPath" status 2>&1); then
    printf '%s\n' "\$manager_output"
    manager_error=''
  else
    manager_error="\$manager_output"
    port=4096
    if [ -f "\$OC_DIR/state" ]; then
      while IFS='=' read -r name value; do
        [ "\$name" = port ] && port="\$value"
      done < "\$OC_DIR/state"
    fi
    printf 'phase=failed\nmessage=Could not read setup manager status\nport=%s\nrunner=\nversion=\npid=\n' "\$port"
  fi
elif [ -f "\$OC_DIR/state" ]; then
  manager_error='Setup manager is missing after launch'
  port=4096
  while IFS='=' read -r name value; do
    [ "\$name" = port ] && port="\$value"
  done < "\$OC_DIR/state"
  printf 'phase=failed\nmessage=Setup manager is missing after launch\nport=%s\nrunner=\nversion=\npid=\n' "\$port"
else
  manager_error=''
  printf 'phase=idle\nmessage=No setup has been started\nport=4096\nrunner=\nversion=\npid=\n'
fi
printf '%s\n' '__OC_SETUP_OUTPUT__'
if [ -n "\$manager_error" ]; then
  printf '[oc] status error: %s\n' "\$manager_error"
fi
tail -n 160 "\$OC_DIR/install.log" 2>/dev/null || true
if [ -f "\$OC_DIR/server-log.active" ] && [ -s "\$OC_DIR/server.log" ]; then
  printf '\n%s\n' '[oc] server output'
  tail -n 60 "\$OC_DIR/server.log" 2>/dev/null || true
fi
''';

  static String diagnosticsScript() =>
      '''
if [ -x "$_managerPath" ]; then
  exec "$_managerPath" diagnostics
fi
OC_DIR="$termuxHome/.oc"
echo '===== OpenCode bootstrap diagnostics ====='
echo 'Manager: missing or not executable'
echo '===== state ====='
if [ -f "\$OC_DIR/state" ]; then cat "\$OC_DIR/state"; else echo 'No state file'; fi
echo '===== bootstrap files ====='
ls -la "\$OC_DIR" 2>&1 || true
echo '===== setup lock ====='
if [ -f "\$OC_DIR/setup.lock" ]; then
  echo 'Legacy file lock:'
  cat "\$OC_DIR/setup.lock"
elif [ -f "\$OC_DIR/setup.lock/owner" ]; then
  cat "\$OC_DIR/setup.lock/owner"
elif [ -d "\$OC_DIR/setup.lock" ]; then
  echo 'Setup lock directory exists without an owner'
else
  echo 'No setup lock'
fi
echo '===== install.log (last 120 lines) ====='
tail -n 120 "\$OC_DIR/install.log" 2>/dev/null || true
echo '===== server.log (last 80 lines) ====='
tail -n 80 "\$OC_DIR/server.log" 2>/dev/null || true
''';

  static String restartScript({
    int port = managedServerPort,
    required String operationID,
    String? recoveryToken,
    String? expectedOperationID,
    TermuxRuntime? switchTarget,
    String? switchPassword,
  }) {
    if (port < 1024 || port > 65535) {
      throw ArgumentError.value(
        port,
        'port',
        'Must be between 1024 and 65535.',
      );
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(operationID)) {
      throw ArgumentError.value(
        operationID,
        'operationID',
        'Invalid restart ID',
      );
    }
    if (recoveryToken != null &&
        (!RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(recoveryToken) ||
            expectedOperationID == null ||
            !RegExp(r'^[a-zA-Z0-9_-]{0,64}$').hasMatch(expectedOperationID))) {
      throw ArgumentError('Invalid recovery identity');
    }
    if (switchTarget != null &&
        (switchPassword == null ||
            switchPassword.isEmpty ||
            recoveryToken != null)) {
      throw ArgumentError('A runtime switch needs its saved credential');
    }
    final recoveryArgs = recoveryToken == null
        ? ''
        : ' ${_shellQuote(expectedOperationID!)} ${_shellQuote(recoveryToken)}';
    final stagedPassword = switchTarget == null
        ? ''
        : 'printf \'%s\' ${_shellQuote(switchPassword!)} > "\$OC_DIR/switch-password-$operationID"';
    final launchCommand = switchTarget == null
        ? '"\$MANAGER" restart \'$port\' \'$operationID\'$recoveryArgs &\n'
              'operation_pid=\$!\nwait "\$operation_pid"'
        : 'nohup "\$MANAGER" restart \'$port\' \'$operationID\' \'\' \'\' '
              '\'${switchTarget.wireName}\' >/dev/null 2>&1 </dev/null &\n'
              'operation_pid=\$!\nprintf "manager-started:%s\\n" "\$operation_pid"';
    final staleLockAction = switchTarget == null
        ? r'''echo 'managed-operation-lock-is-stale; use Stop then retry' >&2
  exit 75'''
        : r'''# Only an explicit runtime operation may reclaim a dead dispatcher.
  # A live manager with missing ownership stays unavailable; never stop it here.
  recorded_pid=''; recorded_start=''
  read -r recorded_pid recorded_start < "$OC_DIR/manager.pid" 2>/dev/null || true
  if [ -n "$recorded_pid" ] && [ -n "$recorded_start" ] &&
     [ "$(process_start "$recorded_pid" 2>/dev/null || true)" = "$recorded_start" ] &&
     kill -0 "$recorded_pid" 2>/dev/null; then
    echo 'managed-operation-owner-is-still-active' >&2; exit 75
  fi
  current_pid=''; current_start=''
  if [ -f "$LOCK" ]; then
    read -r current_pid current_start < "$LOCK" 2>/dev/null || true
  else
    read -r current_pid current_start < "$LOCK/owner" 2>/dev/null || true
  fi
  [ "$current_pid" = "$owner_pid" ] && [ "$current_start" = "$owner_start" ] || {
    echo 'managed-operation-owner-changed' >&2; exit 75;
  }
  if [ -f "$LOCK" ]; then rm -f "$LOCK";
  else rm -f "$LOCK/owner"; rmdir "$LOCK" || exit 75; fi''';
    return '''
set -eu
OC_DIR="$termuxHome/.oc"
MANAGER="$_managerPath"
LOCK="\$OC_DIR/setup.lock"
mkdir -p "\$OC_DIR"
umask 077

process_start() {
  stat_line=\$(cat "/proc/\$1/stat" 2>/dev/null) || return 1
  stat_line=\${stat_line##*) }
  set -- \$stat_line
  printf '%s' "\${20:-}"
}

owner_pid=''
owner_start=''
if [ -f "\$LOCK" ]; then
  read -r owner_pid owner_start < "\$LOCK" 2>/dev/null || true
elif [ -f "\$LOCK/owner" ]; then
  read -r owner_pid owner_start < "\$LOCK/owner" 2>/dev/null || true
fi
live_start=\$(process_start "\$owner_pid" 2>/dev/null || true)
if [ -n "\$owner_pid" ] && [ -n "\$owner_start" ] &&
   [ "\$owner_start" = "\$live_start" ] && kill -0 "\$owner_pid" 2>/dev/null; then
  echo 'another-managed-operation-is-running' >&2
  exit 75
fi
if [ -e "\$LOCK" ]; then
  $staleLockAction
fi

manager_tmp="\$MANAGER.tmp.\$\$"
cat > "\$manager_tmp" <<'OC_MANAGER_EOF'
$_managerScript
OC_MANAGER_EOF
chmod 700 "\$manager_tmp"
mv "\$manager_tmp" "\$MANAGER"
[ -x "\$MANAGER" ] || {
  echo 'manager-install-failed' >&2
  exit 74
}
$stagedPassword
set -m
$launchCommand
''';
  }

  static String stopScript({int port = 4096}) =>
      '''
rm -f "$termuxHome/.oc/recovery-permit"
if [ -x "$_managerPath" ]; then
  exec "$_managerPath" stop '$port'
fi
OC_DIR="$termuxHome/.oc"
process_start() {
  stat_line=\$(cat "/proc/\$1/stat" 2>/dev/null) || return 1
  stat_line=\${stat_line##*) }
  set -- \$stat_line
  printf '%s' "\${20:-}"
}
read_lock() {
  if [ -f "\$OC_DIR/setup.lock" ]; then
    cat "\$OC_DIR/setup.lock"
  else
    cat "\$OC_DIR/setup.lock/owner" 2>/dev/null
  fi
}
setup_process() {
  local -a args=()
  mapfile -d '' -t args < "/proc/\$1/cmdline" 2>/dev/null || return 1
  [ "\${args[1]:-}" = "\$OC_DIR/manager.sh" ] || return 1
  [ "\${args[2]:-}" = setup ] || [ "\${args[2]:-}" = restart ]
}
process_group() {
  stat_line=\$(cat "/proc/\$1/stat" 2>/dev/null) || return 1
  stat_line=\${stat_line##*) }
  set -- \$stat_line
  printf '%s' "\${3:-}"
}
lock_pid=''
lock_start=''
for _ in 1 2 3 4 5 6 7 8 9 10; do
  read -r lock_pid lock_start < <(read_lock) && break
  [ -d "\$OC_DIR/setup.lock" ] || break
  sleep 0.1
done
live_start=\$(process_start "\$lock_pid" 2>/dev/null || true)
if [ -n "\$lock_pid" ] && [ -n "\$lock_start" ] && [ "\$lock_start" = "\$live_start" ] &&
   kill -0 "\$lock_pid" 2>/dev/null; then
  lock_owned=1
  pid="\$lock_pid"
else
  lock_owned=0
  manager_start=''
  read -r pid manager_start < "\$OC_DIR/manager.pid" 2>/dev/null || true
fi
case "\$pid" in
  ''|*[!0-9]*) ;;
  *)
    if setup_process "\$pid"; then
      if [ "\$lock_owned" != 1 ]; then
        echo 'bootstrap-owner-is-unverified' >&2
        exit 75
      fi
      kill -STOP "\$pid" 2>/dev/null || true
      stopped_start=\$(process_start "\$pid" 2>/dev/null || true)
      if [ "\$stopped_start" != "\$lock_start" ] || ! setup_process "\$pid"; then
        [ -z "\$stopped_start" ] || kill -CONT "\$pid" 2>/dev/null || true
        echo 'bootstrap-owner-changed-before-stop' >&2
        exit 75
      fi
      [ "\$(process_group "\$pid" 2>/dev/null || true)" = "\$pid" ] || {
        kill -CONT "\$pid" 2>/dev/null || true
        echo 'bootstrap-owner-is-not-isolated' >&2
        exit 75
      }
      kill -STOP -- "-\$pid" 2>/dev/null || true
      if [ "\$(process_start "\$pid" 2>/dev/null || true)" != "\$lock_start" ] ||
         ! setup_process "\$pid"; then
        kill -CONT -- "-\$pid" 2>/dev/null || true
        echo 'bootstrap-owner-changed-before-stop' >&2
        exit 75
      fi
      kill -KILL -- "-\$pid" 2>/dev/null || true
    elif [ "\$lock_owned" = 1 ] && kill -0 "\$pid" 2>/dev/null; then
      echo 'bootstrap-owner-is-still-active' >&2
      exit 75
    fi
    ;;
esac
current_pid=''
current_start=''
read -r current_pid current_start < <(read_lock) || true
if [ "\$current_pid" != "\$lock_pid" ] || [ "\$current_start" != "\$lock_start" ]; then
  echo 'setup-lock-owner-changed' >&2
  exit 75
fi
if [ -f "\$OC_DIR/setup.lock" ]; then
  rm -f "\$OC_DIR/setup.lock"
else
  rm -f "\$OC_DIR/setup.lock/owner" "\$OC_DIR/setup.lock"/owner.tmp.*
  rmdir "\$OC_DIR/setup.lock" 2>/dev/null || true
fi
rm -f "\$OC_DIR/manager.pid"
termux-wake-unlock >/dev/null 2>&1 || true
printf 'phase=stopped\nmessage=Bootstrap state cleared\nport=$port\nrunner=\nversion=\npid=\n' > "$termuxHome/.oc/state"
echo 'bootstrap-state-cleared'
''';

  static String managerScriptForTesting() => _managerScript;

  static String _shellQuote(String value) =>
      "'${value.replaceAll("'", "'\"'\"'")}'";

  static const _managerScript = r'''#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

OC_DIR="$HOME/.oc"
STATE="$OC_DIR/state"
MANAGER="$OC_DIR/manager.sh"
MANAGER_PID="$OC_DIR/manager.pid"
LOCK_DIR="$OC_DIR/setup.lock"
SERVER_PID="$OC_DIR/server.pid"
SERVER_LOG="$OC_DIR/server.log"
SERVER_LOG_ACTIVE="$OC_DIR/server-log.active"
PASSWORD_FILE="$OC_DIR/server.password"
RUNTIME_FILE="$OC_DIR/runtime"
RECOVERY_PERMIT="$OC_DIR/recovery-permit"
SWITCH_FILE="$OC_DIR/runtime-switch"
V2_DATA_MODE="$OC_DIR/opencode2-data-mode"
LEGACY_MARKER="$OC_DIR/legacy-install"
UBUNTU_INSTALL_MARKER="$OC_DIR/opencode-ubuntu-installing"
SERVER_RUNNER="$OC_DIR/server-runner.sh"
PROOT_NAME=opencode-ubuntu
LOG_MAX_BYTES=1048576
LOG_BACKUPS=2
DISK_RESERVE_KIB=524288
FRESH_SETUP_REQUIRED_KIB=1572864
UPDATE_REQUIRED_KIB=786432
mkdir -p "$OC_DIR"

managed_runtime() {
  local runtime="${CURRENT_RUNTIME:-$(cat "$RUNTIME_FILE" 2>/dev/null || true)}"
  case "$runtime" in
    ''|opencode1) printf opencode1 ;;
    opencode2) printf opencode2 ;;
    *) echo 'unsupported-managed-runtime' >&2; return 64 ;;
  esac
}

runtime_command() {
  case "$(managed_runtime)" in
    opencode1) printf opencode ;;
    opencode2) printf opencode2 ;;
    *) return 64 ;;
  esac
}

runtime_version() {
  local runtime binary version
  runtime=$(managed_runtime) || return
  binary=$(runtime_command) || return
  version=$(proot-distro login "$PROOT_NAME" -- "$binary" --version) || return
  if [ "$runtime" = opencode2 ]; then version=${version#opencode2 v}; fi
  printf '%s' "$version" | tr -d '\r\n'
}

log_path() {
  case "${1:-}" in
    install) printf '%s' "$OC_DIR/install.log" ;;
    server) printf '%s' "$SERVER_LOG" ;;
    *) return 64 ;;
  esac
}

rotate_log() {
  local path
  path=$(log_path "${1:-}") || return 64
  local size=0
  if [ -f "$path" ]; then
    size=$(wc -c < "$path" 2>/dev/null || printf '0')
  fi
  case "$size" in ''|*[!0-9]*) size=0 ;; esac
  [ "$size" -eq 0 ] || {
    rm -f "$path.$LOG_BACKUPS"
    local index=$((LOG_BACKUPS - 1))
    while [ "$index" -ge 1 ]; do
      [ ! -f "$path.$index" ] || mv "$path.$index" "$path.$((index + 1))"
      index=$((index - 1))
    done
    mv "$path" "$path.1"
    local bounded="$path.1.tmp.$$"
    tail -c "$LOG_MAX_BYTES" "$path.1" > "$bounded"
    chmod 600 "$bounded"
    mv "$bounded" "$path.1"
  }
  : > "$path"
  chmod 600 "$path"
}

write_log() {
  local name="${1:-}"
  local path
  path=$(log_path "$name") || return 64
  touch "$path"
  chmod 600 "$path"
  local LC_ALL=C
  local size
  size=$(wc -c < "$path" 2>/dev/null || printf '0')
  case "$size" in ''|*[!0-9]*) size=0 ;; esac
  local line=''
  while IFS= read -r line || [ -n "$line" ]; do
    printf '%s\n' "$line" >> "$path"
    size=$((size + ${#line} + 1))
    if [ "$size" -ge "$LOG_MAX_BYTES" ]; then
      rotate_log "$name"
      size=0
    fi
    line=''
  done
}

install_server_runner() {
  local tmp="$SERVER_RUNNER.tmp.$$"
  cat > "$tmp" <<'OC_SERVER_RUNNER'
#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
port="$1"
password_file="$2"
manager="$3"
runtime="${4:-opencode1}"
case "$runtime" in
  opencode1) binary=opencode ;;
  opencode2) binary=opencode2 ;;
  *) exit 64 ;;
esac
runtime_env=()
data_mode=$(cat "$HOME/.oc/opencode2-data-mode" 2>/dev/null || true)
case "$data_mode" in ''|default|isolated) ;; *) exit 64 ;; esac
if [ "$runtime" = opencode2 ] && [ "$data_mode" = isolated ]; then
  # The beta honors these overrides before reading its global configuration.
  # Clear only conflicting OpenCode config inputs, retaining Termux/tool paths.
  unset OPENCODE_CONFIG OPENCODE_CONFIG_CONTENT
  runtime_env=(
    -u OPENCODE_CONFIG -u OPENCODE_CONFIG_CONTENT
    XDG_DATA_HOME=/root/.oc-opencode2/data
    XDG_CACHE_HOME=/root/.oc-opencode2/cache
    XDG_STATE_HOME=/root/.oc-opencode2/state
    XDG_CONFIG_HOME=/root/.oc-opencode2/config
    OPENCODE_CONFIG_DIR=/root/.oc-opencode2/config/opencode
    OPENCODE_DB=/root/.oc-opencode2/data/opencode/opencode.db
  )
fi
"$manager" rotate-log server
# The server never runs from the container's home folder: OpenCode would watch
# and scan every dotfile and cache under it. Projects live in /root/projects,
# and the app still asks the user to create or open a folder inside it.
proot-distro login opencode-ubuntu -- mkdir -p /root/projects >/dev/null 2>&1 || true
if [ "${#runtime_env[@]}" -gt 0 ]; then
  proot-distro login opencode-ubuntu -- mkdir -p /root/.oc-opencode2/data/opencode \
    /root/.oc-opencode2/cache /root/.oc-opencode2/state /root/.oc-opencode2/config/opencode || exit 74
fi
proot-distro login --work-dir /root/projects opencode-ubuntu -- env \
  "${runtime_env[@]}" \
  OPENCODE_SERVER_USERNAME=opencode \
  OPENCODE_SERVER_PASSWORD="$(cat "$password_file")" \
  OPENCODE_PASSWORD="$(cat "$password_file")" \
  "$binary" serve --hostname 127.0.0.1 --port "$port" \
  2>&1 | "$manager" write-log server
code="${PIPESTATUS[0]}"
"$manager" server-exited "$port" "$$" "$code" >/dev/null 2>&1 || true
exit "$code"
OC_SERVER_RUNNER
  chmod 700 "$tmp"
  mv "$tmp" "$SERVER_RUNNER"
}

write_state() {
  local phase="$1"
  local message="$2"
  local port="${3:-4096}"
  local runner="${4:-proot}"
  local version="${5:-}"
  local pid="${6:-}"
  local operation_result="${7:-}"
  # Phase/status writers retain the accepted operation's clock. Only a new
  # dispatcher or accepted restart initializes it; legacy state stays unknown.
  local started_at="${CURRENT_STARTED_AT-$(read_state_value started_at)}"
  local runtime
  runtime=$(managed_runtime) || return 64
  local tmp="$STATE.tmp.$$"
  printf 'phase=%s\nmessage=%s\nport=%s\nrunner=%s\nversion=%s\npid=%s\noperation=%s\noperation_result=%s\nfailure_kind=%s\nrecovery_token=%s\nstarted_at=%s\nruntime=%s\n' \
    "$phase" "$message" "$port" "$runner" "$version" "$pid" \
    "${CURRENT_OPERATION:-}" "$operation_result" "${8:-${CURRENT_RECOVERY:+recovery}}" "${CURRENT_RECOVERY:-}" "$started_at" "$runtime" > "$tmp"
  mv "$tmp" "$STATE"
}

fail_setup() {
  local message="$1"
  local port="${2:-4096}"
  trap - ERR
  write_state failed "$message" "$port"
  printf '[oc] ERROR: %s\n' "$message"
  exit 1
}

fail_restart_preflight() {
  local message="$1"
  if [ "${OLD_SERVER_LIVE:-0}" = 1 ]; then
    trap - ERR
    write_state ready "$message; the original server is still running" \
      "$CURRENT_PORT" proot "$OLD_SERVER_VERSION" "$OLD_SERVER_PID" not_performed
    printf '[oc] ERROR: %s\n' "$message"
    exit 1
  fi
  fail_setup "$message" "$CURRENT_PORT"
}

on_setup_error() {
  local code=$?
  local line="${BASH_LINENO[0]:-unknown}"
  local stage
  stage=$(read_state_value message)
  [ -n "$stage" ] || stage='Setup'
  trap - ERR
  write_state failed "$stage failed (exit $code; setup line $line)" "$CURRENT_PORT"
  printf '[oc] ERROR: %s failed at setup line %s (exit %s)\n' "$stage" "$line" "$code"
  exit "$code"
}

read_state_value() {
  local key="$1"
  [ -f "$STATE" ] || return 0
  while IFS='=' read -r name value; do
    if [ "$name" = "$key" ]; then
      printf '%s' "$value"
      return 0
    fi
  done < "$STATE"
}

process_command() {
  local pid="$1"
  [ -r "/proc/$pid/cmdline" ] || return 1
  tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null
}

process_start() {
  local stat_line
  stat_line=$(cat "/proc/$1/stat" 2>/dev/null) || return 1
  stat_line=${stat_line##*) }
  set -- $stat_line
  printf '%s' "${20:-}"
}

claim_setup_lock() {
  local expected_pid="$1"
  local expected_start="$2"
  local owner_pid=""
  local owner_start=""
  read -r owner_pid owner_start < "$LOCK_DIR/owner" 2>/dev/null || return 1
  [ "$owner_pid" = "$expected_pid" ] && [ "$owner_start" = "$expected_start" ] || return 1
  local self_start
  self_start=$(process_start "$$") || return 1
  printf '%s %s\n' "$$" "$self_start" > "$LOCK_DIR/owner.tmp.$$"
  mv "$LOCK_DIR/owner.tmp.$$" "$LOCK_DIR/owner"
}

read_setup_lock() {
  if [ -f "$LOCK_DIR" ]; then
    cat "$LOCK_DIR"
  else
    cat "$LOCK_DIR/owner" 2>/dev/null
  fi
}

clear_setup_lock() {
  if [ -f "$LOCK_DIR" ]; then
    rm -f "$LOCK_DIR"
  else
    rm -f "$LOCK_DIR/owner" "$LOCK_DIR"/owner.tmp.*
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
}

clear_setup_lock_if_owner() {
  local expected_pid="$1"
  local expected_start="$2"
  local current_pid=""
  local current_start=""
  read -r current_pid current_start < <(read_setup_lock) || true
  if [ "$current_pid" = "$expected_pid" ] && [ "$current_start" = "$expected_start" ]; then
    clear_setup_lock
    return 0
  fi
  echo 'setup-lock-owner-changed' >&2
  return 75
}

process_group() {
  local stat_line
  stat_line=$(cat "/proc/$1/stat" 2>/dev/null) || return 1
  stat_line=${stat_line##*) }
  set -- $stat_line
  printf '%s' "${3:-}"
}

process_parent() {
  local stat_line
  stat_line=$(cat "/proc/$1/stat" 2>/dev/null) || return 1
  stat_line=${stat_line##*) }
  set -- $stat_line
  printf '%s' "${2:-}"
}

group_is_managed_tree() {
  local root="$1"
  local group="$2"
  local stat_file stat_line member member_group current parent found_root=0 depth
  for stat_file in /proc/[0-9]*/stat; do
    stat_line=$(cat "$stat_file" 2>/dev/null || true)
    [ -n "$stat_line" ] || continue
    member=${stat_file#/proc/}
    member=${member%/stat}
    stat_line=${stat_line##*) }
    set -- $stat_line
    member_group="${3:-}"
    [ "$member_group" = "$group" ] || continue
    current="$member"
    depth=0
    while [ "$current" != "$root" ]; do
      parent=$(process_parent "$current" 2>/dev/null || true)
      case "$parent" in ''|0|1|*[!0-9]*) return 1 ;; esac
      current="$parent"
      depth=$((depth + 1))
      [ "$depth" -le 64 ] || return 1
    done
    [ "$member" != "$root" ] || found_root=1
  done
  [ "$found_root" = 1 ]
}

setup_process() {
  local pid="$1"
  local -a args=()
  mapfile -d '' -t args < "/proc/$pid/cmdline" 2>/dev/null || return 1
  [ "${args[1]:-}" = "$MANAGER" ] || return 1
  [ "${args[2]:-}" = setup ] || [ "${args[2]:-}" = restart ]
}

claim_direct_lock() {
  local owner_pid=""
  local owner_start=""
  local live_start=""
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    :
  else
    read -r owner_pid owner_start < <(read_setup_lock) || true
    live_start=$(process_start "$owner_pid" 2>/dev/null || true)
    if [ -n "$owner_pid" ] && [ -n "$owner_start" ] &&
       [ "$owner_start" = "$live_start" ] && kill -0 "$owner_pid" 2>/dev/null; then
      echo 'another-managed-operation-is-running' >&2
      return 75
    fi
    echo 'managed-operation-lock-is-stale; use Stop then retry' >&2
    return 75
  fi
  local self_start
  self_start=$(process_start "$$") || return 75
  printf '%s %s\n' "$$" "$self_start" > "$LOCK_DIR/owner.tmp.$$"
  mv "$LOCK_DIR/owner.tmp.$$" "$LOCK_DIR/owner"
}

server_process() {
  local pid="$1"
  local port="$2"
  local -a args=()
  mapfile -d '' -t args < "/proc/$pid/cmdline" 2>/dev/null || return 1
  [ "${args[1]:-}" = "$SERVER_RUNNER" ] &&
    [ "${args[2]:-}" = "$port" ] &&
    [ "${args[3]:-}" = "$PASSWORD_FILE" ] &&
    [ "${args[4]:-}" = "$MANAGER" ]
}

stop_verified_server_process() {
  local pid="$1"
  local expected_start="$2"
  local port="$3"
  [ -n "$expected_start" ] || return 75
  [ "$(process_start "$pid" 2>/dev/null || true)" = "$expected_start" ] || return 0
  server_process "$pid" "$port" || return 75
  kill -STOP "$pid" 2>/dev/null || return 0
  local group
  group=$(process_group "$pid" 2>/dev/null || true)
  if [ "$(process_start "$pid" 2>/dev/null || true)" != "$expected_start" ] ||
     ! server_process "$pid" "$port" || ! group_is_managed_tree "$pid" "$group"; then
    if [ "$(process_start "$pid" 2>/dev/null || true)" = "$expected_start" ]; then
      kill -CONT "$pid" 2>/dev/null || true
    fi
    return 75
  fi
  kill -STOP -- "-$group" 2>/dev/null || true
  if [ "$(process_start "$pid" 2>/dev/null || true)" != "$expected_start" ] ||
     ! server_process "$pid" "$port" || ! group_is_managed_tree "$pid" "$group"; then
    kill -CONT -- "-$group" 2>/dev/null || true
    return 75
  fi
  kill -KILL -- "-$group" 2>/dev/null || true
}

stop_verified_setup_process() {
  local pid="$1"
  local expected_start="$2"
  [ -n "$expected_start" ] || return 75
  [ "$(process_start "$pid" 2>/dev/null || true)" = "$expected_start" ] || return 0
  setup_process "$pid" || return 75
  kill -STOP "$pid" 2>/dev/null || return 0
  local group
  group=$(process_group "$pid" 2>/dev/null || true)
  if [ "$(process_start "$pid" 2>/dev/null || true)" != "$expected_start" ] ||
     ! setup_process "$pid" || ! group_is_managed_tree "$pid" "$group"; then
    if [ "$(process_start "$pid" 2>/dev/null || true)" = "$expected_start" ]; then
      kill -CONT "$pid" 2>/dev/null || true
    fi
    return 75
  fi
  kill -STOP -- "-$group" 2>/dev/null || true
  if [ "$(process_start "$pid" 2>/dev/null || true)" != "$expected_start" ] ||
     ! setup_process "$pid" || ! group_is_managed_tree "$pid" "$group"; then
    kill -CONT -- "-$group" 2>/dev/null || true
    return 75
  fi
  kill -KILL -- "-$group" 2>/dev/null || true
}

stop_server() {
  local port="${1:-4096}"
  local pid=""
  local saved_start=""
  if [ -f "$SERVER_PID" ]; then
    read -r pid saved_start < "$SERVER_PID" 2>/dev/null || true
  fi
  case "$pid" in
    ''|*[!0-9]*) ;;
    *)
      if kill -0 "$pid" 2>/dev/null; then
        local current_start
        current_start=$(process_start "$pid" 2>/dev/null || true)
        if [ -n "$saved_start" ] && [ "$saved_start" != "$current_start" ]; then
          : # The recorded process exited and its PID was reused. Never kill it.
        else
          server_process "$pid" "$port" || return 75
          stop_verified_server_process "$pid" "$current_start" "$port" || return 75
        fi
      fi
      ;;
  esac
  rm -f "$SERVER_PID"

}

stop_legacy_server() {
  local port="${1:-4096}"
  [ -f "$LEGACY_MARKER" ] || return 0
  local legacy_pid
  for legacy_pid in $(pgrep -f "[o]pencode serve --hostname 127.0.0.1 --port $port" 2>/dev/null || true); do
    kill "$legacy_pid" 2>/dev/null || true
  done
  rm -f "$LEGACY_MARKER"
}

release_setup_lock() {
  local lock_pid=""
  local lock_start=""
  local self_start
  self_start=$(process_start "$$" || true)
  read -r lock_pid lock_start < <(read_setup_lock) || true
  if [ "$lock_pid" = "$$" ] && [ -n "$self_start" ] && [ "$lock_start" = "$self_start" ]; then
    clear_setup_lock_if_owner "$lock_pid" "$lock_start"
  fi
}

stop_setup() {
  local lock_pid=""
  local lock_start=""
  local live_start
  read -r lock_pid lock_start < <(read_setup_lock) || true
  live_start=$(process_start "$lock_pid" 2>/dev/null || true)
  local pid=""
  local lock_owned=0
  if [ -n "$lock_pid" ] && [ -n "$lock_start" ] && [ "$lock_start" = "$live_start" ] &&
     kill -0 "$lock_pid" 2>/dev/null; then
    lock_owned=1
    pid="$lock_pid"
  else
    lock_owned=0
    local recorded_start=""
    read -r pid recorded_start < "$MANAGER_PID" 2>/dev/null || true
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && setup_process "$pid"; then
      echo 'bootstrap-owner-is-unverified' >&2
      return 75
    fi
    pid=""
  fi
  case "$pid" in
    ''|*[!0-9]*) ;;
    *)
      if [ "$pid" != "$$" ] && kill -0 "$pid" 2>/dev/null; then
        if setup_process "$pid"; then
          stop_verified_setup_process "$pid" "$lock_start" || return 75
        elif [ "$lock_owned" = 1 ]; then
          echo 'bootstrap-owner-is-still-active' >&2
          return 75
        fi
      fi
      ;;
  esac
  rm -f "$MANAGER_PID"
  clear_setup_lock_if_owner "$lock_pid" "$lock_start"
}

cleanup_setup() {
  rm -f "$MANAGER_PID"
  rm -f "$OC_DIR/ubuntu-base.tar.gz" "$OC_DIR/ubuntu-base.tar.gz.tmp"
  release_setup_lock
  if [ "${SETUP_SUCCEEDED:-0}" != 1 ]; then
    if [ "${SERVER_STARTED:-0}" = 1 ]; then
      stop_server "$CURRENT_PORT"
    fi
    if [ "${KEEP_WAKE_LOCK_ON_FAILURE:-0}" != 1 ]; then
      termux-wake-unlock >/dev/null 2>&1 || true
    fi
  fi
}

ubuntu_rootfs_exists() {
  [ -d "$PREFIX/var/lib/proot-distro/containers/$PROOT_NAME/rootfs" ] ||
    [ -d "$PREFIX/var/lib/proot-distro/installed-rootfs/$PROOT_NAME" ]
}

ubuntu_usable() {
  ubuntu_rootfs_exists &&
    proot-distro login "$PROOT_NAME" -- true >/dev/null 2>&1
}

cleanup_app_owned_partial_install() {
  rm -f "$OC_DIR/ubuntu-base.tar.gz" "$OC_DIR/ubuntu-base.tar.gz.tmp"
  if [ -f "$UBUNTU_INSTALL_MARKER" ] && ubuntu_rootfs_exists && ! ubuntu_usable; then
    command -v proot-distro >/dev/null 2>&1 || return 0
    printf '[oc] removing interrupted app-owned Ubuntu install\n'
    proot-distro remove "$PROOT_NAME" >/dev/null 2>&1 ||
      fail_setup 'Could not remove the interrupted app-owned Ubuntu install' "$CURRENT_PORT"
    rm -f "$UBUNTU_INSTALL_MARKER"
  fi
}

cleanup_legacy_npm_cache() {
  ubuntu_usable || return 0
  # Older installer revisions used npm's persistent cache. A failed download
  # can leave hundreds of MiB of corrupt entries there, then make the storage
  # preflight fail before the next repair attempt can start.
  proot-distro login "$PROOT_NAME" -- npm cache clean --force >/dev/null 2>&1 || true
}

require_setup_space() {
  local required_kib="$FRESH_SETUP_REQUIRED_KIB"
  if ubuntu_usable; then
    required_kib="$UPDATE_REQUIRED_KIB"
  fi
  local disk_line available_kib
  disk_line=$(df -Pk "$HOME" 2>/dev/null | tail -n 1) ||
    fail_setup 'Could not check available storage before setup' "$CURRENT_PORT"
  set -- $disk_line
  available_kib="${4:-}"
  case "$available_kib" in
    ''|*[!0-9]*) fail_setup 'Could not read available storage before setup' "$CURRENT_PORT" ;;
  esac
  if [ "$available_kib" -lt "$required_kib" ]; then
    local required_mib=$((required_kib / 1024))
    local available_mib=$((available_kib / 1024))
    local reserve_mib=$((DISK_RESERVE_KIB / 1024))
    fail_setup "Not enough storage: ${available_mib} MiB free; setup needs ${required_mib} MiB including a ${reserve_mib} MiB safety reserve" "$CURRENT_PORT"
  fi
  printf '[oc] storage preflight: %s MiB free; preserving %s MiB reserve\n' \
    "$((available_kib / 1024))" "$((DISK_RESERVE_KIB / 1024))"
}

select_official_termux_repository() {
  local source_file="$PREFIX/etc/apt/sources.list"
  local desired_source='deb https://packages.termux.dev/apt/termux-main stable main'
  mkdir -p "$PREFIX/etc/apt"
  # Keep the user's previous main-repository selection recoverable. Other
  # optional Termux repositories in sources.list.d are deliberately untouched.
  if [ -s "$source_file" ] && [ ! -e "$source_file.oc-before-opencode" ]; then
    cp "$source_file" "$source_file.oc-before-opencode" || return 1
  fi
  local source_tmp="$source_file.oc-tmp.$$"
  printf '%s\n' "$desired_source" > "$source_tmp" || return 1
  chmod 644 "$source_tmp" || return 1
  mv "$source_tmp" "$source_file" || return 1
  printf '[oc] selected official Termux repository: packages.termux.dev\n'
}

termux_main_repository_configured() {
  local source_file
  for source_file in \
    "$PREFIX/etc/apt/sources.list" \
    "$PREFIX/etc/apt/sources.list.d/"*.list \
    "$PREFIX/etc/apt/sources.list.d/"*.sources; do
    [ -f "$source_file" ] || continue
    if [ -n "$(grep -Ev '^[[:space:]]*(#|$)' "$source_file" 2>/dev/null || true)" ]; then
      return 0
    fi
  done
  return 1
}

proot_supports_named_containers() {
  local help_output
  help_output=$(proot-distro install --help 2>&1) || return 1
  case "$help_output" in
    *--name*) return 0 ;;
    *) return 1 ;;
  esac
}

termux_dependencies_healthy() {
  command -v curl >/dev/null 2>&1 || return 1
  command -v proot-distro >/dev/null 2>&1 || return 1
  curl --version >/dev/null 2>&1 || return 1
  proot_supports_named_containers
}

prepare_termux_dependencies() {
  if termux_dependencies_healthy; then
    printf '[oc] existing Termux dependencies are healthy; package upgrade skipped\n'
    return 0
  fi

  export DEBIAN_FRONTEND=noninteractive
  write_state installing_dependencies 'Refreshing Termux packages' "$CURRENT_PORT"
  if termux_main_repository_configured; then
    if ! apt-get update; then
      printf '[oc] current Termux repository failed; switching the main repository to packages.termux.dev\n'
      select_official_termux_repository ||
        fail_setup 'Could not select the official Termux package repository' "$CURRENT_PORT"
      apt-get update ||
        fail_setup 'Could not refresh packages.termux.dev; check the network and retry' "$CURRENT_PORT"
    fi
  else
    select_official_termux_repository ||
      fail_setup 'Could not select the official Termux package repository' "$CURRENT_PORT"
    apt-get update ||
      fail_setup 'Could not refresh packages.termux.dev; check the network and retry' "$CURRENT_PORT"
  fi

  # A partial dependency install can leave libcurl ahead of OpenSSL. Repair the
  # entire package set first, keeping existing config files non-interactively.
  write_state installing_dependencies 'Repairing the Termux package set' "$CURRENT_PORT"
  apt-get -y --no-remove -o Dpkg::Options::="--force-confold" --fix-broken install ||
    fail_setup 'Could not repair the interrupted Termux package transaction' "$CURRENT_PORT"
  apt-get -y --no-remove -o Dpkg::Options::="--force-confold" upgrade ||
    fail_setup 'Could not complete the safe Termux package upgrade' "$CURRENT_PORT"

  write_state installing_dependencies 'Installing Termux dependencies' "$CURRENT_PORT"
  apt-get -y --no-remove -o Dpkg::Options::="--force-confold" install \
    proot-distro curl openssl ||
    fail_setup 'Could not install the Termux dependencies' "$CURRENT_PORT"
  termux_dependencies_healthy ||
    fail_setup 'Termux dependencies are still unusable after the package repair' "$CURRENT_PORT"
}

install_ubuntu_base() {
  local archive="$OC_DIR/ubuntu-base.tar.gz"
  local base_url='https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release'
  local filename checksum
  case "$(uname -m)" in
    aarch64|arm64)
      filename='ubuntu-base-24.04.4-base-arm64.tar.gz'
      checksum='04207713ece899c3740823d33690441ad3a7f0ded1101aca744e2b0f37ac7ff2'
      ;;
    arm|armv7l|armv8l)
      filename='ubuntu-base-24.04.4-base-armhf.tar.gz'
      checksum='991520b47f6586f38a78505cf016e300b6191bb8ff86a0723481ec23a37ab7f4'
      ;;
    x86_64|amd64)
      filename='ubuntu-base-24.04.4-base-amd64.tar.gz'
      checksum='c1e67ef7b17a6300e136118bd1dc04725009cb376c1aad10abcf8cd453628d58'
      ;;
    *) fail_setup "Unsupported CPU architecture: $(uname -m)" "$CURRENT_PORT" ;;
  esac

  rm -f "$archive"
  curl --fail --location --retry 5 --retry-all-errors --connect-timeout 20 \
    "$base_url/$filename" -o "$archive"
  printf '%s  %s\n' "$checksum" "$archive" | sha256sum -c -

  if ubuntu_rootfs_exists; then
    [ -f "$UBUNTU_INSTALL_MARKER" ] ||
      fail_setup 'An existing Ubuntu container is not usable; setup will not delete it' "$CURRENT_PORT"
    proot-distro remove "$PROOT_NAME" >/dev/null 2>&1 ||
      fail_setup 'Could not remove the interrupted app-owned Ubuntu install' "$CURRENT_PORT"
    if ubuntu_usable; then
      rm -f "$UBUNTU_INSTALL_MARKER"
      return
    fi
  fi
  printf 'source=canonical-ubuntu-base-24.04.4\n' > "$UBUNTU_INSTALL_MARKER"
  proot-distro install "$archive" --name "$PROOT_NAME"
  rm -f "$archive"
  ubuntu_usable || fail_setup 'Ubuntu Base extraction did not create a usable container' "$CURRENT_PORT"
  rm -f "$UBUNTU_INSTALL_MARKER"
}

install_runtime() {
  local requested_version="$1"
  write_state installing_opencode 'Installing OpenCode' "$CURRENT_PORT"
  proot-distro login "$PROOT_NAME" -- env OC_REQUESTED_VERSION="$requested_version" OC_RUNTIME="$CURRENT_RUNTIME" bash -s <<'OC_PROOT_SETUP'
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
# Keep Node filesystem calls visible to PRoot's path translation.
export UV_USE_IO_URING=0
if ! command -v node >/dev/null 2>&1 ||
   ! command -v npm >/dev/null 2>&1 ||
   ! command -v curl >/dev/null 2>&1 ||
   ! command -v git >/dev/null 2>&1 ||
   ! command -v ssh >/dev/null 2>&1 ||
   [ ! -s /etc/ssl/certs/ca-certificates.crt ]; then
  apt-get update -y -o Acquire::Retries=5
  # Skip optional distro tooling, but retain Git and SSH explicitly for coding
  # projects: these must not depend on npm/git's recommended-package defaults.
  apt-get install -y --no-install-recommends -o Acquire::Retries=5 \
    nodejs npm curl ca-certificates git openssh-client
fi
export NODE_OPTIONS="${NODE_OPTIONS:+$NODE_OPTIONS }--dns-result-order=ipv4first"
# Project folders live here; the server starts in it instead of /root.
mkdir -p /root/projects
case "${OC_RUNTIME:-opencode1}" in
  opencode1) command=opencode ;;
  opencode2) command=opencode2 ;;
  *) printf '[oc] ERROR: Unsupported managed runtime\n' >&2; exit 64 ;;
esac
install_opencode() {
  local npm_cache
  local install_code
  local binary_package
  local binary_suffix
  local main_package=opencode-ai
  case "$(node -p 'process.arch')" in
    arm64) binary_suffix=linux-arm64 ;;
    x64) binary_suffix=linux-x64-baseline ;;
    *) printf '[oc] ERROR: OpenCode requires a 64-bit ARM or x64 Ubuntu environment\n' >&2; return 64 ;;
  esac
  if [ "${OC_RUNTIME:-opencode1}" = opencode2 ]; then
    binary_package="@opencode-ai/cli-$binary_suffix"
    main_package=@opencode-ai/cli
  else
    binary_package="opencode-$binary_suffix"
  fi
  npm_cache=$(mktemp -d /tmp/opencode-mobile-npm.XXXXXX)
  # Make the compatible Ubuntu binary a required package. Optional dependency
  # failures must not silently leave postinstall trying a musl-only fallback.
  # Keep upstream postinstall intact and visible so runtime errors are actionable.
  if npm install -g \
    --include=optional \
    --foreground-scripts \
    --cache "$npm_cache" \
    --fetch-retries=5 \
    --fetch-retry-mintimeout=10000 \
    --fetch-retry-maxtimeout=60000 \
    --fetch-timeout=300000 \
    "$binary_package@$OC_REQUESTED_VERSION" \
    "$main_package@$OC_REQUESTED_VERSION"; then
    install_code=0
  else
    install_code=$?
  fi
  rm -rf -- "$npm_cache"
  return "$install_code"
}
install_opencode || {
  printf '[oc] OpenCode installation failed; retrying in 10 seconds\n'
  sleep 10
  install_opencode
}
"$command" --version
OC_PROOT_SETUP

}

setup() {
  CURRENT_PORT="${1:-4096}"
  local requested_version="${2:-}"
  local dispatcher_pid="${3:-}"
  local dispatcher_start="${4:-}"
  CURRENT_RUNTIME="${5:-$(managed_runtime)}"
  managed_runtime >/dev/null || return 64
  if [ -z "$requested_version" ]; then
    case "$CURRENT_RUNTIME" in
      opencode1) requested_version=1.18.29 ;;
      opencode2) requested_version=0.0.0-beta-18600 ;;
    esac
  fi
  SETUP_SUCCEEDED=0
  SERVER_STARTED=0
  if ! claim_setup_lock "$dispatcher_pid" "$dispatcher_start"; then
    write_state failed 'Setup manager could not claim its launch lock' "$CURRENT_PORT"
    rm -f "$MANAGER_PID"
    return 75
  fi
  trap on_setup_error ERR
  trap cleanup_setup EXIT
  [ "$(process_group "$$" 2>/dev/null || true)" = "$$" ] ||
    fail_setup 'Setup manager did not start in an isolated process group' "$CURRENT_PORT"
  termux-wake-lock >/dev/null 2>&1 || true
  write_state preparing 'Preparing Termux' "$CURRENT_PORT"
  printf '\n[oc] setup started at %s\n' "$(date -Iseconds 2>/dev/null || date)"

  cleanup_app_owned_partial_install
  cleanup_legacy_npm_cache
  require_setup_space

  prepare_termux_dependencies

  if [ -f "$UBUNTU_INSTALL_MARKER" ] || ! ubuntu_usable; then
    write_state installing_ubuntu 'Installing Ubuntu environment' "$CURRENT_PORT"
    install_ubuntu_base
  fi

  install_runtime "$requested_version"

  local installed_version
  installed_version=$(runtime_version 2>/dev/null)
  [ -n "$installed_version" ] || fail_setup 'OpenCode installed but did not report a version' "$CURRENT_PORT"
  if [ "$CURRENT_RUNTIME" = opencode1 ]; then
    write_state refreshing_models 'Refreshing the OpenCode model catalog' "$CURRENT_PORT" proot "$installed_version"
    proot-distro login "$PROOT_NAME" -- opencode models --refresh >/dev/null ||
      fail_setup 'OpenCode updated, but its model catalog could not be refreshed' "$CURRENT_PORT"
  fi
  [ -s "$PASSWORD_FILE" ] || fail_setup 'The local server password is missing' "$CURRENT_PORT"

  stop_legacy_server "$CURRENT_PORT"
  stop_server "$CURRENT_PORT"
  start_server "$installed_version"
}

start_server() {
  local installed_version="$1"
  local starting_phase="${2:-starting_server}"
  local password
  local runtime health_path
  runtime=$(managed_runtime) || return 64
  case "$runtime" in
    opencode1) health_path=/global/health ;;
    opencode2) health_path=/api/health ;;
  esac
  if [ -n "${CURRENT_RECOVERY:-}" ]; then
    recovery_permitted "$CURRENT_RECOVERY" || fail_setup 'Automatic recovery was disabled' "$CURRENT_PORT"
  fi
  password=$(cat "$PASSWORD_FILE")
  install_server_runner
  : > "$SERVER_LOG_ACTIVE"
  if [ "$starting_phase" = restarting ]; then
    write_state restarting 'Restarting the local server' "$CURRENT_PORT" proot "$installed_version"
  else
    write_state starting_server 'Starting the local server' "$CURRENT_PORT" proot "$installed_version"
  fi
  set -m
  nohup "$SERVER_RUNNER" "$CURRENT_PORT" "$PASSWORD_FILE" "$MANAGER" "$runtime" \
    >/dev/null 2>&1 </dev/null &
  local server_pid=$!
  SERVER_STARTED=1
  local server_start
  server_start=$(process_start "$server_pid") ||
    fail_setup 'Could not record the managed server process identity' "$CURRENT_PORT"
  if [ "$(process_group "$server_pid" 2>/dev/null || true)" != "$server_pid" ]; then
    kill -STOP "$server_pid" 2>/dev/null || true
    if [ "$(process_start "$server_pid" 2>/dev/null || true)" = "$server_start" ]; then
      kill -KILL "$server_pid" 2>/dev/null || true
    fi
    fail_setup 'Managed server did not start in an isolated process group' "$CURRENT_PORT"
  fi
  printf '%s %s\n' "$server_pid" "$server_start" > "$SERVER_PID"

  for _ in {1..30}; do
    if ! kill -0 "$server_pid" 2>/dev/null; then
      fail_setup 'OpenCode server exited during startup' "$CURRENT_PORT"
    fi
    if (exec 3<>"/dev/tcp/127.0.0.1/$CURRENT_PORT") 2>/dev/null; then
      exec 3>&-
      exec 3<&-
      local auth_codes
      auth_codes=$(proot-distro login "$PROOT_NAME" -- env \
        OC_PORT="$CURRENT_PORT" OC_PASSWORD="$password" OC_HEALTH_PATH="$health_path" bash -s <<'OC_AUTH_CHECK'
unauth=$(curl --max-time 2 -s -o /dev/null -w '%{http_code}' \
  "http://127.0.0.1:$OC_PORT$OC_HEALTH_PATH" || true)
auth=$(curl --max-time 2 -s -o /dev/null -w '%{http_code}' \
  -u "opencode:$OC_PASSWORD" "http://127.0.0.1:$OC_PORT$OC_HEALTH_PATH" || true)
printf '%s %s' "$unauth" "$auth"
OC_AUTH_CHECK
)
      if [ "$auth_codes" = '401 200' ]; then
        write_state ready 'OpenCode is ready' "$CURRENT_PORT" proot "$installed_version" "$server_pid" "${CURRENT_OPERATION:+completed}"
        printf '[oc] authenticated server ready on 127.0.0.1:%s\n' "$CURRENT_PORT"
        SETUP_SUCCEEDED=1
        if [ "${SWITCH_COMMIT:-0}" = 1 ]; then rm -f "$SWITCH_FILE" || true; fi
        return 0
      fi
    fi
    sleep 1
  done
  fail_setup 'OpenCode server did not become authenticated and ready within 30 seconds' "$CURRENT_PORT"
}

recovery_permitted() {
  [ -f "$RECOVERY_PERMIT" ] && [ "$(cat "$RECOVERY_PERMIT")" = "$1" ]
}

recovery_port_busy() {
  (exec 3<>"/dev/tcp/127.0.0.1/$CURRENT_PORT") 2>/dev/null
}

recovery_server_absent() {
  local tracked_pid='' tracked_start=''
  read -r tracked_pid tracked_start < "$SERVER_PID" 2>/dev/null || true
  if [ -n "$tracked_pid" ] && kill -0 "$tracked_pid" 2>/dev/null; then return 75; fi
  if recovery_port_busy; then return 75; fi
  return 0
}

recovery_preflight() {
  local expected_operation="$1" token="$2"
  recovery_permitted "$token" || return 75
  [ "$(read_state_value operation)" = "$expected_operation" ] || return 75
  [ "$(read_state_value phase)" = failed ] || return 75
  [ "$(read_state_value runner)" = proot ] || return 75
  [ "$(read_state_value port)" = "$CURRENT_PORT" ] || return 75
  case "$(read_state_value failure_kind)" in crash|recovery) ;; *) return 75 ;; esac
  # A live PID, even one whose identity no longer matches, is never stopped
  # by automatic recovery. Manual management can explain that conflict.
  recovery_server_absent
}

recovery_arm() {
  [ ! -f "$SWITCH_FILE" ] || return 75
  local token="$1" pid='' saved_start=''
  [[ "$token" =~ ^[a-zA-Z0-9_-]{1,64}$ ]] || return 64
  [ ! -e "$LOCK_DIR" ] || return 75
  [ "$(read_state_value phase)" = ready ] || return 75
  [ "$(read_state_value runner)" = proot ] || return 75
  read -r pid saved_start < "$SERVER_PID" 2>/dev/null || return 75
  [ -n "$saved_start" ] && [ "$(process_start "$pid" 2>/dev/null || true)" = "$saved_start" ] || return 75
  server_process "$pid" "$(read_state_value port)" || return 75
  umask 077
  printf '%s' "$token" > "$RECOVERY_PERMIT.tmp.$$"
  mv "$RECOVERY_PERMIT.tmp.$$" "$RECOVERY_PERMIT"
  cat "$STATE"
}

recovery_disarm() {
  local token="$1"
  if [ -f "$RECOVERY_PERMIT" ] && ! recovery_permitted "$token"; then return 0; fi
  rm -f "$RECOVERY_PERMIT"
  # A dispatched recovery may still be in preflight/startup. Revoke first,
  # then cancel only the operation that carries this permit, using the
  # manager's PID/start-time and process-group ownership checks.
  if [ "$(read_state_value recovery_token)" = "$token" ]; then
    case "$(read_state_value phase)" in
      restarting|starting_server)
        stop_setup || return 75
        stop_server "$(read_state_value port)" || return 75
        CURRENT_OPERATION=$(read_state_value operation)
        write_state stopped 'Automatic recovery disabled' "$(read_state_value port)"
        ;;
    esac
  fi
}

write_switch() {
  local previous="$1" target="$2" phase="$3"
  printf 'switch_previous=%s\nswitch_target=%s\nswitch_phase=%s\nswitch_operation=%s\n' \
    "$previous" "$target" "$phase" "$CURRENT_OPERATION" > "$SWITCH_FILE.tmp.$$"
  chmod 600 "$SWITCH_FILE.tmp.$$"
  mv "$SWITCH_FILE.tmp.$$" "$SWITCH_FILE"
}

switch_value() {
  local key="$1" name value
  [ -f "$SWITCH_FILE" ] || return 0
  while IFS='=' read -r name value; do
    [ "$name" != "$key" ] || { printf '%s' "$value"; return; }
  done < "$SWITCH_FILE"
}

# Explicitly authorized generation change. One slot, one lock, one server.
# The old binary/data/credential remain available for a deliberate return.
switch_runtime() {
  local target="$1" previous installed_version current
  case "$target" in opencode1|opencode2) ;; *) return 64 ;; esac
  CURRENT_PORT="${CURRENT_PORT:-4096}"
  local staged_password="$OC_DIR/switch-password-$CURRENT_OPERATION"
  [ -s "$staged_password" ] || return 64
  claim_direct_lock || return 75
  SETUP_SUCCEEDED=0
  SERVER_STARTED=0
  KEEP_WAKE_LOCK_ON_FAILURE=1
  CURRENT_STARTED_AT=$(date +%s)
  printf '%s %s\n' "$$" "$(process_start "$$")" > "$MANAGER_PID"
  trap on_setup_error ERR
  trap cleanup_setup EXIT
  [ "$(process_group "$$" 2>/dev/null || true)" = "$$" ] ||
    fail_setup 'Switch manager did not start in an isolated process group' "$CURRENT_PORT"
  # Rotate only after this operation owns the lock. Start its logger after
  # rotation so neither old output nor the logger's cached old size leaks in.
  rotate_log install
  exec > >("$MANAGER" write-log install) 2>&1
  current=$(managed_runtime) || return 64
  local recorded_data_mode
  recorded_data_mode=$(cat "$V2_DATA_MODE" 2>/dev/null || true)
  case "$recorded_data_mode" in ''|default|isolated) ;; *) fail_setup 'The OpenCode 2 data location record is unreadable' ;; esac
  previous=$(switch_value switch_previous)
  [ -n "$previous" ] || previous="$current"
  case "$previous" in opencode1|opencode2) ;; *) fail_setup 'The previous runtime record is unreadable' ;; esac
  if [ "$target" = opencode1 ] && [ "$current" = opencode2 ] &&
     [ "$(cat "$V2_DATA_MODE" 2>/dev/null || true)" != isolated ]; then
    fail_setup 'This OpenCode 2 installation has no separate OpenCode 1 data to return to'
  fi
  if [ -s "$OC_DIR/password-$target" ] &&
     ! cmp -s "$staged_password" "$OC_DIR/password-$target"; then
    fail_setup 'The saved profile credential differs from this runtime; restore its original saved credential before returning'
  fi
  ubuntu_usable || fail_setup 'The managed Ubuntu environment is unavailable'
  # Revocation is durable and precedes every generation-changing action.
  rm -f "$RECOVERY_PERMIT"
  # Capture current credential only when its runtime is known, never replace a
  # previous credential with a target credential after an interrupted launch.
  if [ ! -f "$SWITCH_FILE" ] && [ -s "$PASSWORD_FILE" ]; then
    cp "$PASSWORD_FILE" "$OC_DIR/password-$current.tmp.$$"
    chmod 600 "$OC_DIR/password-$current.tmp.$$"
    mv "$OC_DIR/password-$current.tmp.$$" "$OC_DIR/password-$current"
  fi
  write_switch "$previous" "$target" preparing
  write_state preparing 'Preparing the selected OpenCode runtime' "$CURRENT_PORT"
  # An existing first-run OC2 install keeps its original default XDG paths.
  # Only OC1 installations opting into OC2 for the first time get isolation.
  if [ ! -f "$V2_DATA_MODE" ]; then
    if [ "$current" = opencode2 ]; then data_mode=default; else data_mode=isolated; fi
    printf '%s' "$data_mode" > "$V2_DATA_MODE.tmp.$$"
    mv "$V2_DATA_MODE.tmp.$$" "$V2_DATA_MODE"
  fi
  CURRENT_RUNTIME="$target"
  installed_version=$(runtime_version 2>/dev/null || true)
  if [ -z "$installed_version" ]; then
    require_setup_space
    local requested_version
    case "$target" in
      opencode1) requested_version=1.18.29 ;;
      opencode2) requested_version=0.0.0-beta-18600 ;;
    esac
    install_runtime "$requested_version"
    installed_version=$(runtime_version 2>/dev/null || true)
  fi
  [ -n "$installed_version" ] || fail_setup 'The selected OpenCode command is unavailable'
  # Journal survives a crash on either side of the only destructive boundary.
  write_switch "$previous" "$target" stopping
  write_state restarting 'Switching the managed local server' "$CURRENT_PORT"
  stop_server "$CURRENT_PORT" || fail_setup 'The tracked process is not the managed OpenCode server'
  KEEP_WAKE_LOCK_ON_FAILURE=0
  local port_released=0
  for _ in {1..30}; do
    if ! (exec 3<>"/dev/tcp/127.0.0.1/$CURRENT_PORT") 2>/dev/null; then port_released=1; break; fi
    exec 3>&- 2>/dev/null || true
    exec 3<&- 2>/dev/null || true
    sleep 0.2
  done
  [ "$port_released" = 1 ] || fail_setup 'The local server port is still in use; no replacement was started'
  cp "$staged_password" "$PASSWORD_FILE.tmp.$$"
  chmod 600 "$PASSWORD_FILE.tmp.$$"
  mv "$PASSWORD_FILE.tmp.$$" "$PASSWORD_FILE"
  rm -f "$staged_password"
  cp "$PASSWORD_FILE" "$OC_DIR/password-$target.tmp.$$"
  mv "$OC_DIR/password-$target.tmp.$$" "$OC_DIR/password-$target"
  printf '%s' "$target" > "$RUNTIME_FILE.tmp.$$"
  mv "$RUNTIME_FILE.tmp.$$" "$RUNTIME_FILE"
  write_switch "$previous" "$target" starting
  termux-wake-lock >/dev/null 2>&1 || true
  SWITCH_COMMIT=1
  start_server "$installed_version"
  # Authenticated readiness is the commit point. Until this deletion, a fresh
  # app process must display an unresolved switch and selectable return.
  rm -f "$SWITCH_FILE"
}

restart() {
  CURRENT_PORT="${1:-4096}"
  CURRENT_OPERATION="${2:-}"
  local expected_operation="${3:-}"
  CURRENT_RECOVERY="${4:-}"
  [[ "$CURRENT_OPERATION" =~ ^[a-zA-Z0-9_-]{1,64}$ ]] || return 64
  if [ -n "${5:-}" ]; then switch_runtime "$5"; return; fi
  [ ! -f "$SWITCH_FILE" ] || { echo 'managed-runtime-switch-pending' >&2; return 75; }
  SETUP_SUCCEEDED=0
  SERVER_STARTED=0
  KEEP_WAKE_LOCK_ON_FAILURE=0
  OLD_SERVER_LIVE=0
  OLD_SERVER_PID=""
  OLD_SERVER_VERSION=$(read_state_value version)
  if ! claim_direct_lock; then
    echo 'another-managed-operation-is-running' >&2
    return 75
  fi
  if [ -n "$CURRENT_RECOVERY" ]; then
    if ! recovery_preflight "$expected_operation" "$CURRENT_RECOVERY"; then
      release_setup_lock
      echo 'recovery-owner-or-state-changed' >&2
      return 75
    fi
  fi
  CURRENT_STARTED_AT=$(date +%s)
  printf '%s %s\n' "$$" "$(process_start "$$")" > "$MANAGER_PID"
  trap on_setup_error ERR
  trap cleanup_setup EXIT
  local old_pid=""
  local old_start=""
  local live_start=""
  read -r old_pid old_start < "$SERVER_PID" 2>/dev/null || true
  live_start=$(process_start "$old_pid" 2>/dev/null || true)
  if [ -n "$old_pid" ] && [ -n "$live_start" ] && kill -0 "$old_pid" 2>/dev/null &&
     { [ -z "$old_start" ] || [ "$old_start" = "$live_start" ]; } &&
     server_process "$old_pid" "$CURRENT_PORT"; then
    OLD_SERVER_LIVE=1
    OLD_SERVER_PID="$old_pid"
    KEEP_WAKE_LOCK_ON_FAILURE=1
  fi
  [ "$(process_group "$$" 2>/dev/null || true)" = "$$" ] ||
    fail_restart_preflight 'Restart manager did not start in an isolated process group'
  printf '\n[oc] server restart started at %s\n' "$(date -Iseconds 2>/dev/null || date)"
  # Publish this operation before any preflight can block. A prior ready
  # snapshot must never be mistaken for completion of the requested restart.
  write_state restarting 'Checking the local server before restart' \
    "$CURRENT_PORT" proot "$OLD_SERVER_VERSION" "$OLD_SERVER_PID"

  ubuntu_usable || fail_restart_preflight 'The managed Ubuntu environment is unavailable'
  [ -s "$PASSWORD_FILE" ] || fail_restart_preflight 'The local server password is missing'
  local installed_version
  if ! installed_version=$(runtime_version 2>/dev/null); then
    fail_restart_preflight 'The installed OpenCode command is unavailable'
  fi
  [ -n "$installed_version" ] || fail_restart_preflight 'The installed OpenCode command is unavailable'

  if [ -n "$CURRENT_RECOVERY" ]; then
    recovery_permitted "$CURRENT_RECOVERY" && recovery_server_absent ||
      fail_restart_preflight 'The server changed before automatic recovery; no replacement was started'
  else
    stop_server "$CURRENT_PORT" ||
      fail_restart_preflight 'The tracked process is not the managed OpenCode server'
  fi
  OLD_SERVER_LIVE=0
  KEEP_WAKE_LOCK_ON_FAILURE=0
  termux-wake-lock >/dev/null 2>&1 || true
  write_state restarting 'Restarting the local server' "$CURRENT_PORT"
  rm -f "$SERVER_LOG_ACTIVE"

  local port_released=0
  for _ in {1..30}; do
    if ! (exec 3<>"/dev/tcp/127.0.0.1/$CURRENT_PORT") 2>/dev/null; then
      port_released=1
      break
    fi
    exec 3>&- 2>/dev/null || true
    exec 3<&- 2>/dev/null || true
    sleep 0.2
  done
  [ "$port_released" = 1 ] ||
    fail_setup 'The local server port is still in use; no replacement was started' "$CURRENT_PORT"

  start_server "$installed_version" restarting
}

status() {
  if [ ! -f "$STATE" ]; then
    printf 'phase=idle\nmessage=No setup has been started\nport=4096\nrunner=\nversion=\npid=\n'
    return 0
  fi
  CURRENT_OPERATION=$(read_state_value operation)
  local phase
  phase=$(read_state_value phase)
  if [ "$phase" = ready ]; then
    local pid saved_start current_start
    pid=""
    saved_start=""
    read -r pid saved_start < "$SERVER_PID" 2>/dev/null || true
    current_start=$(process_start "$pid" 2>/dev/null || true)
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null ||
       { [ -n "$saved_start" ] && [ "$saved_start" != "$current_start" ]; } ||
       ! server_process "$pid" "$(read_state_value port)"; then
      write_state failed 'The local OpenCode server stopped unexpectedly' "$(read_state_value port)" proot '' '' '' crash
      rm -f "$SERVER_PID" "$SERVER_LOG_ACTIVE"
      termux-wake-unlock >/dev/null 2>&1 || true
    elif [ -z "$saved_start" ] && [ -n "$current_start" ]; then
      printf '%s %s\n' "$pid" "$current_start" > "$SERVER_PID"
    fi
  fi
  case "$phase" in
    queued|preparing|installing_dependencies|installing_ubuntu|installing_opencode|refreshing_models|restarting|starting_server)
      local manager_pid manager_start live_start latest_phase
      manager_pid=""
      manager_start=""
      read -r manager_pid manager_start < "$MANAGER_PID" 2>/dev/null || true
      live_start=$(process_start "$manager_pid" 2>/dev/null || true)
      if [ -z "$manager_pid" ] || [ -z "$manager_start" ] ||
         [ "$manager_start" != "$live_start" ] || ! kill -0 "$manager_pid" 2>/dev/null ||
         ! setup_process "$manager_pid"; then
        latest_phase=$(read_state_value phase)
        if [ "$latest_phase" = "$phase" ]; then
          write_state failed 'Setup stopped unexpectedly; see live output for details' "$(read_state_value port)"
        fi
      fi
      ;;
  esac
  cat "$STATE"
  # A persisted authenticated-ready result commits only its own transition.
  # This completes harmless journal cleanup after a crash between those writes.
  if [ "$(read_state_value phase)" = ready ] && [ -f "$SWITCH_FILE" ] &&
     [ -n "$(switch_value switch_operation)" ] &&
     [ "$(read_state_value operation)" = "$(switch_value switch_operation)" ] &&
     [ "$(managed_runtime)" = "$(switch_value switch_target)" ]; then
    rm -f "$SWITCH_FILE" || true
  fi
  if [ -f "$SWITCH_FILE" ]; then
    cat "$SWITCH_FILE"
    # State may describe the package being staged while the old server still
    # owns the slot. Report the durable active-generation marker separately.
    printf 'runtime=%s\n' "$(managed_runtime)"
  fi
  if [ "$(cat "$V2_DATA_MODE" 2>/dev/null || true)" = isolated ]; then
    printf 'switch_return=opencode1\n'
  fi
}

server_exited() {
  local port="${1:-4096}"
  local runner_pid="${2:-}"
  local code="${3:-1}"
  local current_pid current_start
  current_pid=""
  current_start=""
  read -r current_pid current_start < "$SERVER_PID" 2>/dev/null || true
  [ -n "$runner_pid" ] && [ "$current_pid" = "$runner_pid" ] || return 0
  [ -n "$current_start" ] && [ "$(process_start "$runner_pid" 2>/dev/null || true)" = "$current_start" ] || return 0
  CURRENT_OPERATION=$(read_state_value operation)
  rm -f "$SERVER_PID" "$SERVER_LOG_ACTIVE"
  write_state failed "OpenCode server exited (code $code)" "$port" proot '' '' '' crash
  termux-wake-unlock >/dev/null 2>&1 || true
}

diagnostics() {
  printf '%s\n' '===== OpenCode on-device status ====='
  status
  printf '%s\n' '===== setup lock ====='
  if [ -f "$LOCK_DIR" ]; then
    printf '%s\n' 'Legacy file lock:'
    cat "$LOCK_DIR"
  elif [ -d "$LOCK_DIR" ]; then
    read_setup_lock || echo 'Directory lock has no owner'
  else
    echo 'No setup lock'
  fi
  printf '%s\n' '===== install.log (last 120 lines) ====='
  tail -n 120 "$OC_DIR/install.log" 2>/dev/null || true
  printf '%s\n' '===== server.log (last 80 lines) ====='
  tail -n 80 "$SERVER_LOG" 2>/dev/null || true
}

stop() {
  local port="${1:-4096}"
  write_state stopping 'Stopping the local server' "$port"
  stop_setup
  stop_legacy_server "$port"
  stop_server "$port"
  termux-wake-unlock >/dev/null 2>&1 || true
  write_state stopped 'Local server stopped' "$port"
  echo '[oc] server stopped'
}

case "${1:-status}" in
  setup) shift; setup "$@" ;;
  restart) shift; restart "$@" ;;
  recovery-arm) shift; recovery_arm "$@" ;;
  recovery-disarm) shift; recovery_disarm "$@" ;;
  status) status ;;
  diagnostics) diagnostics ;;
  stop) shift; stop "$@" ;;
  server-exited) shift; server_exited "$@" ;;
  rotate-log) shift; rotate_log "$@" ;;
  write-log) shift; write_log "$@" ;;
  *) echo "usage: $0 {setup|restart|status|diagnostics|stop}" >&2; exit 64 ;;
esac
''';

  static const _toolsScript = r'''#!/data/data/com.termux/files/usr/bin/bash
# OpenCode Mobile phone tools: storage and process views of the managed
# Termux environment (TEAM-304/305). Installed to ~/.oc/tools.sh beside
# manager.sh; every verb prints JSON on stdout and nothing else.
set -uo pipefail

OC_DIR="$HOME/.oc"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
PROOT_NAME=opencode-ubuntu
SCAN_JSON="$OC_DIR/storage-scan.json"
SCAN_MANIFEST="$OC_DIR/storage-scan.paths"
SCAN_LOG="$OC_DIR/storage-scan.log"
SCAN_PID="$OC_DIR/storage-scan.pid"
SCAN_STATE="$OC_DIR/storage-scan.state"
SCAN_CANCEL="$OC_DIR/storage-scan.cancel"
STOP_WAIT_SECONDS=5
ORPHAN_CPU_SECONDS=300
mkdir -p "$OC_DIR"
umask 077

# ---------------------------------------------------------------- helpers --

rootfs_dir() {
  local base="$PREFIX/var/lib/proot-distro"
  if [ -d "$base/containers/$PROOT_NAME/rootfs" ]; then
    printf '%s' "$base/containers/$PROOT_NAME/rootfs"
  elif [ -d "$base/installed-rootfs/$PROOT_NAME" ]; then
    printf '%s' "$base/installed-rootfs/$PROOT_NAME"
  else
    return 1
  fi
}

json_str() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\t'/\\t}
  s=${s//$'\r'/\\r}
  printf '"%s"' "$s"
}

# Bytes used by a path (file or directory); 0 when absent.
path_bytes() {
  local out
  [ -e "$1" ] || { printf 0; return; }
  out=$(du -sb -- "$1" 2>/dev/null | cut -f1)
  case "$out" in
    ''|*[!0-9]*)
      out=$(du -sk -- "$1" 2>/dev/null | cut -f1)
      case "$out" in ''|*[!0-9]*) out=0 ;; esac
      out=$((out * 1024)) ;;
  esac
  printf '%s' "$out"
}

log() { printf '[oc] %s\n' "$*"; }

now_epoch() { date +%s; }

# ---------------------------------------------------------------- storage --

# One category is described by a key, whether the app may remove its paths
# and an optional note key; the paths are appended by scan_category.
CAT_KEYS=()
CAT_DELETABLE=()
CAT_NOTE=()
CAT_BYTES=()
CAT_PATHS=()   # newline separated "bytes<TAB>path" records per category

scan_check_cancel() {
  if [ -e "$SCAN_CANCEL" ]; then
    log 'Scan cancelled'
    printf cancelled > "$SCAN_STATE"
    rm -f "$SCAN_PID"
    exit 0
  fi
}

# add_path <category index> <path>: measures and records an existing path.
add_path() {
  local index="$1" path="$2" bytes
  [ -e "$path" ] || return 0
  case "$path" in *$'\n'*|*$'\t'*) return 0 ;; esac
  scan_check_cancel
  bytes=$(path_bytes "$path")
  CAT_BYTES[$index]=$(( ${CAT_BYTES[$index]} + bytes ))
  CAT_PATHS[$index]+="$bytes"$'\t'"$path"$'\n'
  log "  $(human_bytes "$bytes")  $(display_path "$path")"
}

# The rootfs prefix is long and identical on every line; the log shows
# "ubuntu:/root/..." instead, with Termux paths relative to $PREFIX and ~.
display_path() {
  local path="$1"
  case "$path" in
    "${SCAN_ROOTFS:-/nonexistent}"/*) printf 'ubuntu:%s' "${path#"$SCAN_ROOTFS"}" ;;
    "$HOME"/*) printf '~%s' "${path#"$HOME"}" ;;
    "$PREFIX"/*) printf 'termux:%s' "${path#"$PREFIX"}" ;;
    *) printf '%s' "$path" ;;
  esac
}

new_category() {
  CAT_KEYS+=("$1")
  CAT_DELETABLE+=("$2")
  CAT_NOTE+=("${3:-}")
  CAT_BYTES+=(0)
  CAT_PATHS+=('')
  NEW_INDEX=$(( ${#CAT_KEYS[@]} - 1 ))
}

human_bytes() {
  local b="$1"
  if [ "$b" -ge 1073741824 ]; then
    printf '%d.%d GB' $((b / 1073741824)) $(( (b % 1073741824) * 10 / 1073741824 ))
  elif [ "$b" -ge 1048576 ]; then
    printf '%d MB' $((b / 1048576))
  elif [ "$b" -ge 1024 ]; then
    printf '%d KB' $((b / 1024))
  else
    printf '%d B' "$b"
  fi
}

PROJECT_JSON=''

scan_projects() {
  local rootfs="$1" projects="$rootfs/root/projects" dir name bytes build_bytes sub kind
  local build_index="$2"
  [ -d "$projects" ] || return 0
  for dir in "$projects"/*/; do
    dir=${dir%/}
    [ -d "$dir" ] || continue
    name=${dir##*/}
    scan_check_cancel
    log "Project $name"
    bytes=$(path_bytes "$dir")
    build_bytes=0
    # Names are inventory hints only: a folder named build may contain sources.
    while IFS= read -r sub; do
      [ -n "$sub" ] || continue
      kind=$(path_bytes "$sub")
      build_bytes=$((build_bytes + kind))
      add_path "$build_index" "$sub"
    done < <(find "$dir" -xdev -type d \( -name build -o -name .dart_tool -o -name node_modules -o -name target \) -prune -print 2>/dev/null | sort)
    PROJECT_JSON+="$( [ -z "$PROJECT_JSON" ] || printf ',' ){\"name\":$(json_str "$name"),\"path\":$(json_str "$dir"),\"bytes\":$bytes,\"build_bytes\":$build_bytes}"
  done
}

write_scan_result() {
  local total="$1" json='' manifest='' index key paths line bytes path first
  for index in "${!CAT_KEYS[@]}"; do
    key=${CAT_KEYS[$index]}
    paths=''
    first=1
    while IFS=$'\t' read -r bytes path; do
      [ -n "$path" ] || continue
      [ "$first" = 1 ] || paths+=','
      first=0
      paths+="{\"path\":$(json_str "$path"),\"bytes\":$bytes}"
      manifest+="$key"$'\t'"${CAT_DELETABLE[$index]}"$'\t'"$bytes"$'\t'"$path"$'\n'
    done <<< "${CAT_PATHS[$index]}"
    [ -z "$json" ] || json+=','
    json+="{\"key\":\"$key\",\"label_key\":\"termuxStorageCat_$key\",\"bytes\":${CAT_BYTES[$index]},\"deletable\":${CAT_DELETABLE[$index]}"
    [ -z "${CAT_NOTE[$index]}" ] || json+=",\"note_key\":\"${CAT_NOTE[$index]}\""
    json+=",\"paths\":[$paths]}"
  done
  printf '{"scanned_at":%s,"total_bytes":%s,"categories":[%s],"projects":[%s],"cleanup_policy":2,"stale":false}\n' \
    "$(now_epoch)" "$total" "$json" "$PROJECT_JSON" > "$SCAN_JSON.tmp.$$"
  printf '%s' "$manifest" > "$SCAN_MANIFEST.tmp.$$"
  mv "$SCAN_MANIFEST.tmp.$$" "$SCAN_MANIFEST"
  mv "$SCAN_JSON.tmp.$$" "$SCAN_JSON"
}

# Scans and cleans share one lock so a scan cannot publish pre-clean sizes
# during removal. A dead owner is recoverable without touching user data.
storage_operation_lock() {
  local lock="$OC_DIR/storage-operation.lock" owner='' modified now identity claim
  if [ -e "$lock" ] || [ -L "$lock" ]; then
    [ -d "$lock" ] && [ ! -L "$lock" ] || return 1
    identity=$(stat -c '%d:%i:%Y' -- "$lock" 2>/dev/null) || return 1
    read -r owner < "$lock/pid" 2>/dev/null || true
    case "$owner" in
      '')
        # Older tools could crash between mkdir and writing the PID. Never
        # reclaim a fresh directory: its creator may still be initializing it.
        modified=${identity##*:}
        now=$(now_epoch)
        case "$modified:$now" in *[!0-9:]*) return 1 ;; esac
        [ "$((now - modified))" -ge 60 ] || return 1
        [ ! -L "$lock/pid" ] && [ ! -s "$lock/pid" ] || return 1 ;;
      *[!0-9]*) return 1 ;;
      *) kill -0 "$owner" 2>/dev/null && return 1 ;;
    esac
    # Another caller may have recovered this lock while it was inspected.
    [ "$(stat -c '%d:%i:%Y' -- "$lock" 2>/dev/null)" = "$identity" ] || return 1
    [ "$(cat "$lock/pid" 2>/dev/null)" = "$owner" ] || return 1
    rm -f -- "$lock/pid"
    rmdir -- "$lock" 2>/dev/null || return 1
  fi
  # Publish a complete directory atomically. A competing complete lock is
  # nonempty, so mv -T cannot replace it. There is no new empty-PID window.
  claim=$(mktemp -d "$OC_DIR/storage-operation-claim.XXXXXX") || return 1
  if ! printf '%s\n' "$$" > "$claim/pid" ||
     ! mv -T -- "$claim" "$lock" 2>/dev/null; then
    rm -f -- "$claim/pid"
    rmdir -- "$claim" 2>/dev/null || true
    return 1
  fi
  trap 'rm -f -- "$OC_DIR/storage-operation.lock/pid"; rmdir -- "$OC_DIR/storage-operation.lock" 2>/dev/null || true' EXIT
}

storage_scan() {
  storage_operation_lock || { echo 'storage-busy' >&2; return 75; }
  # The dispatcher clears a stale cancel file before launching; one placed
  # after that (or before the first measurement) stops the scan early.
  printf '%s\n' "$$" > "$SCAN_PID"
  printf running > "$SCAN_STATE"
  : > "$SCAN_LOG"
  exec >> "$SCAN_LOG" 2>&1
  if ( storage_scan_body ); then
    [ "$(cat "$SCAN_STATE" 2>/dev/null)" != running ] || printf done > "$SCAN_STATE"
  else
    log 'Scan failed'
    printf failed > "$SCAN_STATE"
  fi
  rm -f "$SCAN_PID"
}

storage_scan_body() {
  local rootfs i_build i_scratch i_outputs i_tool i_team i_oc i_projects i_shared dir total
  log 'Measuring storage on this phone'
  rootfs=$(rootfs_dir || true)
  SCAN_ROOTFS=$rootfs
  if [ -n "$rootfs" ]; then
    log "Ubuntu rootfs: $rootfs"
  else
    log 'Ubuntu rootfs: not installed'
  fi

  new_category build_caches true termuxStorageNoteBuildCaches; i_build=$NEW_INDEX
  new_category agent_scratch false termuxStorageNoteAgentScratch; i_scratch=$NEW_INDEX
  new_category project_build_outputs false termuxStorageNoteProjectBuildOutputs; i_outputs=$NEW_INDEX
  new_category toolchains false termuxStorageNoteToolchains; i_tool=$NEW_INDEX
  new_category ai_team false termuxStorageNoteAiTeam; i_team=$NEW_INDEX
  new_category opencode false termuxStorageNoteOpenCode; i_oc=$NEW_INDEX
  new_category projects false termuxStorageNoteProjects; i_projects=$NEW_INDEX

  new_category shared_caches false termuxStorageNoteSharedCaches; i_shared=$NEW_INDEX

  log 'Build caches'
  if [ -n "$rootfs" ]; then
    add_path "$i_build" "$rootfs/root/.gradle/caches"
    add_path "$i_build" "$rootfs/root/.npm/_cacache"
  fi
  add_path "$i_build" "$HOME/.npm/_cacache"

  log 'Other caches and package data (read only)'
  if [ -n "$rootfs" ]; then
    for dir in "$rootfs/root/.gradle/wrapper" "$rootfs/root/.pub-cache" \
               "$rootfs/root/.cache" "$rootfs/root/.dartServer"; do
      add_path "$i_shared" "$dir"
    done
  fi
  add_path "$i_shared" "$HOME/.cache"
  # npm may contain configuration and other user data outside _cacache.
  for dir in "$HOME/.npm"/* "$HOME/.npm"/.[!.]*; do
    [ "${dir##*/}" = _cacache ] || add_path "$i_shared" "$dir"
  done

  log 'Agent scratch'
  if [ -n "$rootfs" ] && [ -d "$rootfs/tmp/opencode" ]; then
    for dir in "$rootfs/tmp/opencode"/* "$rootfs/tmp/opencode"/.[!.]*; do
      [ -e "$dir" ] || continue
      case "${dir##*/}" in
        flutter|flutter-*|*.tar.xz|*.zip) continue ;;
      esac
      add_path "$i_scratch" "$dir"
    done
  fi
  add_path "$i_scratch" "$PREFIX/tmp"

  log 'Toolchains'
  if [ -n "$rootfs" ]; then
    add_path "$i_tool" "$rootfs/usr/lib/android-sdk"
    add_path "$i_tool" "$rootfs/usr/lib/jvm"
    if [ -d "$rootfs/tmp/opencode" ]; then
      for dir in "$rootfs/tmp/opencode"/*; do
        [ -e "$dir" ] || continue
        case "${dir##*/}" in
          flutter|flutter-*|*.tar.xz|*.zip) add_path "$i_tool" "$dir" ;;
        esac
      done
    fi
  fi

  log 'AI Team'
  add_path "$i_team" "$HOME/.oc/aiteam"
  add_path "$i_team" "$HOME/.oc/city"
  for dir in "$PREFIX/bin/gc" "$PREFIX/bin/bd" "$PREFIX/bin/dolt"; do
    add_path "$i_team" "$dir"
  done
  if [ -n "$rootfs" ]; then
    for dir in "$rootfs"/root/aiteam*; do
      add_path "$i_team" "$dir"
    done
  fi

  log 'OpenCode'
  if [ -n "$rootfs" ]; then
    add_path "$i_oc" "$rootfs/usr/local/lib/node_modules"
    add_path "$i_oc" "$rootfs/root/.local/share/opencode"
  fi

  log 'Projects'
  if [ -n "$rootfs" ]; then
    scan_projects "$rootfs" "$i_outputs"
    for dir in "$rootfs"/root/projects/*/; do
      dir=${dir%/}
      [ -d "$dir" ] || continue
      add_path "$i_projects" "$dir"
    done
  fi

  scan_check_cancel
  log 'Measuring the whole Termux install'
  total=$(( $(path_bytes "$PREFIX") + $(path_bytes "$HOME") ))
  write_scan_result "$total"
  log "Scan complete: $(human_bytes "$total") used"
}

scan_pid_alive() {
  local pid
  pid=$(cat "$SCAN_PID" 2>/dev/null || true)
  case "$pid" in ''|*[!0-9]*) return 1 ;; esac
  kill -0 "$pid" 2>/dev/null
}

storage_status() {
  local state
  state=$(cat "$SCAN_STATE" 2>/dev/null || printf idle)
  if [ "$state" = running ] && ! scan_pid_alive; then
    state=failed
    printf failed > "$SCAN_STATE"
  fi
  printf 'state=%s\n' "$state"
  printf '%s\n' '__OC_TOOLS_LOG__'
  tail -n 80 "$SCAN_LOG" 2>/dev/null || true
  printf '%s\n' '__OC_TOOLS_JSON__'
  # While a scan runs the file is the previous scan's; the app already has it.
  [ "$state" = running ] || [ ! -f "$SCAN_JSON" ] || cat "$SCAN_JSON"
}

# Cheap answer for the settings row: the last scan's total and clock.
storage_summary() {
  local state
  state=$(cat "$SCAN_STATE" 2>/dev/null || printf idle)
  if [ "$state" = running ] && ! scan_pid_alive; then state=failed; fi
  printf 'state=%s\n' "$state"
  [ "$state" != stale ] || return 0
  [ -f "$SCAN_JSON" ] || return 0
  sed -n 's/^{"scanned_at":\([0-9]*\),"total_bytes":\([0-9]*\),.*/scanned_at=\1\ntotal_bytes=\2/p' "$SCAN_JSON"
}

storage_cancel() {
  : > "$SCAN_CANCEL"
  if scan_pid_alive; then
    local pid
    pid=$(cat "$SCAN_PID")
    # du is the long pole; interrupt the whole scan group politely.
    kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
    printf cancelled > "$SCAN_STATE"
    rm -f "$SCAN_PID"
  fi
  printf '{"cancelled":true}\n'
}

# process_users <category> <snapshot>: classifies a successfully captured
# process snapshot, printing users of a category one per line.
process_users() {
  local category="$1" snapshot="$2" line pid comm args
  while IFS= read -r line; do
    set -- $line
    pid=${1:-}
    case "$pid" in ''|*[!0-9]*) continue ;; esac
    [ "$pid" != "$$" ] || continue
    comm=${7:-}
    shift 7 2>/dev/null || shift $#
    args="$*"
    case "$category" in
      build_caches|project_build_outputs|toolchains)
        case "$args" in
          *GradleDaemon*|*gradle*wrapper*|*"gradle "*|*KotlinCompileDaemon*|*analysis_server*|*frontend_server*|*"flutter "*|*"flutter_tools"*|*npm-cli.js*|*npx-cli.js*|*"npm install"*|*"npm ci"*|*"npm cache"*)
            printf '%s\n' "$comm" ;;
        esac ;;
      agent_scratch)
        case "$args" in
          *"opencode acp"*|*"opencode run"*|*"opencode2 acp"*|*"opencode2 run"*|*/tmp/opencode/*)
            printf '%s\n' "$comm" ;;
        esac ;;
      ai_team)
        case "$comm" in gc|dolt|bd|tmux) printf '%s\n' "$comm" ;; esac
        case "$args" in *"/bin/gc "*|*"dolt sql-server"*|*"gc start"*) printf '%s\n' "$comm" ;; esac ;;
      opencode)
        case "$args" in *"opencode serve"*|*"opencode2 serve"*|*node*) printf '%s\n' "$comm" ;; esac ;;
    esac
  done <<< "$snapshot"
}

# Exact regenerable caches only. Never authorize by basename, category flag,
# or a broad HOME/PREFIX prefix from a previous scan.
clean_path_allowed() {
  local path="$1" rootfs="$2" canonical expected base
  case "$path" in
    "$HOME/.npm/_cacache")
      base=$(realpath -e -- "$HOME" 2>/dev/null) || return 1
      expected="$base/.npm/_cacache" ;;
    *)
      [ -n "$rootfs" ] || return 1
      case "$path" in
        "$rootfs/root/.gradle/caches"|"$rootfs/root/.npm/_cacache") ;;
        *) return 1 ;;
      esac
      base=$(realpath -e -- "$PREFIX" 2>/dev/null) || return 1
      expected="$base${path#"$PREFIX"}" ;;
  esac
  # Android may alias /data/data and /data/user/0. Resolve the trusted Termux
  # anchors, then refuse replaced parents, rootfs or cache symlinks beneath them.
  canonical=$(realpath -e -- "$path" 2>/dev/null) || return 1
  [ "$canonical" = "$expected" ] && [ -d "$path" ] && [ ! -L "$path" ] || return 1
  [ "$(stat -c %u -- "$path" 2>/dev/null)" = "$(id -u)" ]
}

# A failed measurement must never become zero in destructive accounting.
clean_path_bytes() {
  local out
  out=$(du -sb -- "$1" 2>/dev/null) || return 1
  out=${out%%$'\t'*}
  case "$out" in ''|*[!0-9]*) return 1 ;; esac
  printf '%s' "$out"
}

storage_clean() {
  local category="${1:-}" rootfs users line manifest_key deletable bytes path freed=0 reason
  local removed='' refused='' kept='' before after snapshot process_names
  case "$category" in
    build_caches) ;;
    agent_scratch|project_build_outputs|toolchains|ai_team|opencode|projects|shared_caches)
      printf '{"freed_bytes":0,"removed":[],"refused":[{"path":"","reason":"never_deletable"}]}\n'
      return 0 ;;
    *) echo 'unknown-category' >&2; return 64 ;;
  esac
  storage_operation_lock || { echo 'storage-busy' >&2; return 75; }
  [ -f "$SCAN_MANIFEST" ] || { echo 'no-scan' >&2; return 65; }
  # Legacy reports do not carry the narrower policy. Interrupted cleanups and
  # scans cannot supply an actionable report either.
  if [ "$(cat "$SCAN_STATE" 2>/dev/null)" != done ] ||
     ! grep -q '"cleanup_policy":2,"stale":false' "$SCAN_JSON" 2>/dev/null; then
    printf '{"freed_bytes":0,"removed":[],"refused":[{"path":"","reason":"rescan_required"}],"rescan_required":true}\n'
    return 0
  fi
  rootfs=$(rootfs_dir || true)
  # Process substitution hides its producer's exit status. Capture and check
  # discovery and classification before changing any report or cache path.
  if ! snapshot=$(list_processes) ||
     ! process_names=$(process_users "$category" "$snapshot" | sort -u); then
    printf '{"freed_bytes":0,"removed":[],"refused":[{"path":"","reason":"process_check_failed"}]}\n'
    return 0
  fi
  users=''
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    [ -z "$users" ] || users+=','
    users+=$(json_str "$line")
  done <<< "$process_names"
  if [ -n "$users" ]; then
    printf '{"freed_bytes":0,"removed":[],"refused":[{"path":"","reason":"in_use","processes":[%s]}]}\n' "$users"
    return 0
  fi
  # Invalidate before mutation so crashes cannot leave a fresh-looking report.
  printf stale > "$SCAN_STATE"
  sed 's/"stale":false/"stale":true/' "$SCAN_JSON" > "$SCAN_JSON.tmp.$$" || return 1
  mv "$SCAN_JSON.tmp.$$" "$SCAN_JSON" || return 1
  while IFS= read -r line; do
    IFS=$'\t' read -r manifest_key deletable bytes path <<< "$line"
    if [ "$manifest_key" != "$category" ]; then
      kept+="$line"$'\n'
      continue
    fi
    reason=''
    if [ "$deletable" != true ] || ! clean_path_allowed "$path" "$rootfs"; then
      reason=protected
    elif ! before=$(clean_path_bytes "$path"); then
      reason=measure_failed
    else
      rm -rf --one-file-system -- "$path" 2>/dev/null || true
      if [ -e "$path" ] || [ -L "$path" ]; then
        # Keep the entry on partial failure, and count only measured shrinkage.
        reason=remove_failed
        if after=$(clean_path_bytes "$path") && [ "$after" -lt "$before" ]; then
          freed=$((freed + before - after))
        fi
      else
        freed=$((freed + before))
        [ -z "$removed" ] || removed+=','
        removed+="{\"path\":$(json_str "$path"),\"bytes\":$before}"
      fi
    fi
    if [ -n "$reason" ]; then
      kept+="$line"$'\n'
      [ -z "$refused" ] || refused+=','
      refused+="{\"path\":$(json_str "$path"),\"reason\":\"$reason\"}"
    fi
  done < "$SCAN_MANIFEST"
  printf '%s' "$kept" > "$SCAN_MANIFEST.tmp.$$"
  mv "$SCAN_MANIFEST.tmp.$$" "$SCAN_MANIFEST"
  printf '{"freed_bytes":%s,"removed":[%s],"refused":[%s],"rescan_required":true}\n' "$freed" "$removed" "$refused"
}

# -------------------------------------------------------------- processes --

# Every process this user can see, one per line:
# pid ppid pcpu time rss etimes comm args. Termux ships procps; the /proc
# walk covers a base install without it.
list_processes() {
  if command -v ps >/dev/null 2>&1; then
    ps -eo pid=,ppid=,pcpu=,time=,rss=,etimes=,comm=,args= 2>/dev/null
    return
  fi
  local dir pid stat rest fields comm ppid utime stime rss start uptime ticks=100 cpu elapsed args
  uptime=$(cut -d' ' -f1 /proc/uptime 2>/dev/null); uptime=${uptime%%.*}
  for dir in /proc/[0-9]*; do
    pid=${dir#/proc/}
    stat=$(cat "$dir/stat" 2>/dev/null) || continue
    comm=${stat#*(}; comm=${comm%%)*}
    rest=${stat##*) }
    fields=($rest)
    ppid=${fields[1]:-0}; utime=${fields[11]:-0}; stime=${fields[12]:-0}
    start=${fields[19]:-0}; rss=$(( ${fields[21]:-0} * 4 ))
    cpu=$(( (utime + stime) / ticks ))
    elapsed=$(( ${uptime:-0} - start / ticks )); [ "$elapsed" -ge 0 ] || elapsed=0
    args=$(tr '\0' ' ' < "$dir/cmdline" 2>/dev/null); args=${args% }
    [ -n "$args" ] || args=$comm
    printf '%s %s %s %s %s %s %s %s\n' "$pid" "$ppid" \
      "$( [ "$elapsed" -gt 0 ] && printf '%s' $((cpu * 100 / elapsed)) || printf 0 )" \
      "$cpu" "$rss" "$elapsed" "$comm" "$args"
  done
}


declare -A P_PPID P_CPU P_TIME P_RSS P_ELAPSED P_COMM P_ARGS P_GROUP P_PROTECTED P_REASON
P_ORDER=()

time_to_seconds() {
  local t="$1" days=0 h=0 m=0 s=0 hms
  case "$t" in *-*) days=${t%%-*}; t=${t#*-} ;; esac
  hms=(${t//:/ })
  case "${#hms[@]}" in
    3) h=${hms[0]}; m=${hms[1]}; s=${hms[2]} ;;
    2) m=${hms[0]}; s=${hms[1]} ;;
    1) s=${hms[0]} ;;
  esac
  for v in days h m s; do
    case "${!v}" in ''|*[!0-9]*) printf -v "$v" 0 ;; esac
  done
  printf '%s' $(( ((days * 24 + 10#$h) * 60 + 10#$m) * 60 + 10#$s ))
}

read_processes() {
  local line pid ppid cpu time rss elapsed comm args
  while IFS= read -r line; do
    set -- $line
    pid=${1:-}
    case "$pid" in ''|*[!0-9]*) continue ;; esac
    ppid=${2:-0}; cpu=${3:-0}; time=${4:-0}; rss=${5:-0}; elapsed=${6:-0}; comm=${7:-}
    shift 7 2>/dev/null || shift $#
    args="$*"
    [ "$pid" != "$$" ] && [ "$pid" != 1 ] || continue
    case "$comm" in ps) continue ;; esac
    case "$args" in "$0 "*|*"/.oc/tools.sh "*) continue ;; esac
    case "$ppid" in ''|*[!0-9]*) ppid=0 ;; esac
    case "$rss" in ''|*[!0-9]*) rss=0 ;; esac
    case "$elapsed" in ''|*[!0-9]*) elapsed=0 ;; esac
    case "$cpu" in ''|*[!0-9.]*) cpu=0 ;; esac
    P_ORDER+=("$pid")
    P_PPID[$pid]=$ppid
    P_CPU[$pid]=$cpu
    P_TIME[$pid]=$(time_to_seconds "$time")
    P_RSS[$pid]=$rss
    P_ELAPSED[$pid]=$elapsed
    P_COMM[$pid]=$comm
    P_ARGS[$pid]=$args
    P_GROUP[$pid]=''
    P_PROTECTED[$pid]=false
    P_REASON[$pid]=''
  done < <(list_processes)
}

is_opencode_server() {
  case "${P_ARGS[$1]}" in
    *"opencode serve"*|*"opencode2 serve"*|*"/.oc/manager.sh"*|*"/.oc/server-runner.sh"*) return 0 ;;
  esac
  return 1
}

is_sshd() {
  [ "${P_COMM[$1]}" = sshd ] && return 0
  case "${P_ARGS[$1]}" in sshd|"sshd "*|*/sshd|*"/sshd "*) return 0 ;; esac
  return 1
}

is_ai_team_root() {
  case "${P_COMM[$1]}" in gc|dolt|tmux|bd) return 0 ;; esac
  case "${P_ARGS[$1]}" in
    *"opencode acp"*|*"opencode2 acp"*|*"/bin/gc "*|*"dolt sql-server"*|"tmux"*|*"/bin/tmux"*|*"/bin/dolt"*|*"/bin/bd "*|*"/.oc/aiteam/"*) return 0 ;;
  esac
  return 1
}

is_build_daemon() {
  case "${P_ARGS[$1]}" in
    *GradleDaemon*|*GradleWrapperMain*|*KotlinCompileDaemon*|*analysis_server*|*frontend_server*|*"dart:analysis"*|*"gradle"*) return 0 ;;
  esac
  case "${P_COMM[$1]}" in java|gradle|kotlin*|dart) return 0 ;; esac
  return 1
}

# has_ancestor <pid> <predicate>: walks live parents.
has_ancestor() {
  local pid="${P_PPID[$1]:-0}" guard=0
  while [ -n "${pid:-}" ] && [ "$pid" != 0 ] && [ "$guard" -lt 64 ]; do
    [ -n "${P_COMM[$pid]+x}" ] || return 1
    if "$2" "$pid"; then return 0; fi
    pid=${P_PPID[$pid]:-0}
    guard=$((guard + 1))
  done
  return 1
}

group_in() { [ "${P_GROUP[$1]}" = "$2" ]; }
group_opencode() { group_in "$1" opencode_server; }
group_ai_team() { group_in "$1" ai_team; }
group_build() { group_in "$1" build_daemons; }
group_owner() { group_opencode "$1" || group_ai_team "$1"; }
is_named_root() { is_opencode_server "$1" || is_ai_team_root "$1" || is_build_daemon "$1"; }

classify_processes() {
  local pid
  # Roots first, then children inherit their root's group.
  for pid in "${P_ORDER[@]}"; do
    if is_sshd "$pid"; then
      P_GROUP[$pid]=other; P_PROTECTED[$pid]=true
    elif is_opencode_server "$pid"; then
      P_GROUP[$pid]=opencode_server; P_PROTECTED[$pid]=true
    elif is_ai_team_root "$pid"; then
      P_GROUP[$pid]=ai_team
    fi
  done
  for pid in "${P_ORDER[@]}"; do
    [ -z "${P_GROUP[$pid]}" ] || continue
    if has_ancestor "$pid" group_ai_team; then
      P_GROUP[$pid]=ai_team
    elif has_ancestor "$pid" group_opencode; then
      P_GROUP[$pid]=opencode_server
    fi
  done
  for pid in "${P_ORDER[@]}"; do
    [ -z "${P_GROUP[$pid]}" ] || continue
    if is_build_daemon "$pid"; then
      P_GROUP[$pid]=build_daemons
    elif [ "${P_COMM[$pid]}" = node ] || [ "${P_COMM[$pid]}" = bun ]; then
      P_GROUP[$pid]=build_daemons
    fi
  done
  for pid in "${P_ORDER[@]}"; do
    [ -z "${P_GROUP[$pid]}" ] || continue
    if has_ancestor "$pid" group_build; then P_GROUP[$pid]=build_daemons; fi
  done
  # Orphans: a helper whose parent is gone, or one that has burned real CPU
  # with no live OpenCode or AI Team ancestor. Shells and the Termux app's
  # own processes are never orphans; the root of a named group keeps it.
  local ppid parent_gone
  for pid in "${P_ORDER[@]}"; do
    [ "${P_PROTECTED[$pid]}" = false ] || continue
    case "${P_COMM[$pid]}" in
      sh|bash|zsh|fish|login|sleep|com.termux*|termux*|tail|cat|proot|su) continue ;;
    esac
    ppid=${P_PPID[$pid]}
    parent_gone=0
    if [ "$ppid" = 1 ] || [ "$ppid" = 0 ] || [ -z "${P_COMM[$ppid]+x}" ]; then parent_gone=1; fi
    if is_named_root "$pid"; then continue; fi
    if [ "$parent_gone" = 1 ]; then
      P_GROUP[$pid]=orphans; P_REASON[$pid]=parent_gone
    elif [ "${P_TIME[$pid]}" -gt "$ORPHAN_CPU_SECONDS" ] && ! has_ancestor "$pid" group_owner; then
      P_GROUP[$pid]=orphans; P_REASON[$pid]=cpu_no_owner
    fi
  done
  for pid in "${P_ORDER[@]}"; do
    [ -n "${P_GROUP[$pid]}" ] || P_GROUP[$pid]=other
  done
}

proc_name() {
  local pid="$1" name="${P_COMM[$1]}" args="${P_ARGS[$1]}" first
  # A short, recognisable label: the binary plus its first verb.
  first=${args%% *}
  first=${first##*/}
  case "$args" in
    *"opencode serve"*) name='opencode serve' ;;
    *"opencode2 serve"*) name='opencode2 serve' ;;
    *"opencode acp"*) name='opencode acp' ;;
    *"opencode run"*) name='opencode run' ;;
    *GradleDaemon*) name='Gradle daemon' ;;
    *KotlinCompileDaemon*) name='Kotlin daemon' ;;
    *analysis_server*) name='Dart analysis server' ;;
    *"/.oc/manager.sh"*|*"/.oc/server-runner.sh"*) name='OpenCode manager' ;;
    *) case "$name" in node|bun|python*|sh|bash|java)
         # Name the script, not the interpreter: "minimax-coding-plan-mcp".
         local rest=${args#* } script part
         script=${rest%% *}
         if [ "$rest" != "$args" ] && [ -n "$script" ]; then
           case "$script" in -*) ;; *)
             while [ -n "$script" ]; do
               part=${script##*/}
               case "$part" in
                 ''|index.js|index.mjs|index.cjs|main.js|cli.js|server.js|dist|bin|build|lib|out|src|.bin)
                   [ "$script" != "$part" ] || { script=''; break; }
                   script=${script%/*} ;;
                 *) name=$part; break ;;
               esac
             done ;;
           esac
         fi ;;
       esac ;;
  esac
  printf '%s' "$name"
}

procs_json() {
  local pid cwd first=1
  printf '['
  for pid in "${P_ORDER[@]}"; do
    cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null || true)
    [ "$first" = 1 ] || printf ','
    first=0
    printf '{"pid":%s,"ppid":%s,"group":"%s","name":%s,"cmd":%s,"cpu_pct":%s,"cpu_seconds":%s,"rss_kb":%s,"elapsed_s":%s,"cwd":%s,"orphan_reason":%s,"protected":%s}' \
      "$pid" "${P_PPID[$pid]}" "${P_GROUP[$pid]}" "$(json_str "$(proc_name "$pid")")" \
      "$(json_str "${P_ARGS[$pid]}")" "${P_CPU[$pid]}" "${P_TIME[$pid]}" "${P_RSS[$pid]}" \
      "${P_ELAPSED[$pid]}" "$(json_str "$cwd")" \
      "$( [ -z "${P_REASON[$pid]}" ] && printf null || printf '"%s"' "${P_REASON[$pid]}" )" \
      "${P_PROTECTED[$pid]}"
  done
  printf ']\n'
}

procs_scan() {
  read_processes
  classify_processes
  procs_json
}

procs_stop() {
  local target="${1:-}" pid targets=() refused='' first_refused=1 remaining='' stopped='' killed=''
  local first_stopped=1 first_killed=1 first_remaining=1 waited
  read_processes
  classify_processes
  case "$target" in
    '') echo 'usage: procs-stop <pid|group>' >&2; return 64 ;;
    *[!0-9]*)
      case "$target" in
        ai_team|build_daemons|orphans|other) ;;
        opencode_server) printf '{"stopped":[],"killed":[],"remaining":[],"refused":[{"pid":0,"reason":"protected_group"}]}\n'; return 0 ;;
        *) echo 'unknown-group' >&2; return 64 ;;
      esac
      for pid in "${P_ORDER[@]}"; do
        [ "${P_GROUP[$pid]}" = "$target" ] || continue
        if [ "${P_PROTECTED[$pid]}" = true ]; then
          [ "$first_refused" = 1 ] || refused+=','
          first_refused=0
          refused+="{\"pid\":$pid,\"reason\":\"protected\"}"
        else
          targets+=("$pid")
        fi
      done ;;
    *)
      if [ -z "${P_COMM[$target]+x}" ]; then
        printf '{"stopped":[],"killed":[],"remaining":[],"refused":[{"pid":%s,"reason":"not_found"}]}\n' "$target"
        return 0
      fi
      if [ "${P_PROTECTED[$target]}" = true ]; then
        printf '{"stopped":[],"killed":[],"remaining":[],"refused":[{"pid":%s,"reason":"protected"}]}\n' "$target"
        return 0
      fi
      targets=("$target") ;;
  esac
  for pid in "${targets[@]}"; do kill -TERM "$pid" 2>/dev/null || true; done
  waited=0
  while [ "$waited" -lt "$((STOP_WAIT_SECONDS * 10))" ]; do
    local alive=0
    for pid in "${targets[@]}"; do kill -0 "$pid" 2>/dev/null && alive=1; done
    [ "$alive" = 1 ] || break
    sleep 0.1
    waited=$((waited + 1))
  done
  for pid in "${targets[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill -KILL "$pid" 2>/dev/null || true
      [ "$first_killed" = 1 ] || killed+=','
      first_killed=0
      killed+="$pid"
    else
      [ "$first_stopped" = 1 ] || stopped+=','
      first_stopped=0
      stopped+="$pid"
    fi
  done
  sleep 0.2
  for pid in "${targets[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      [ "$first_remaining" = 1 ] || remaining+=','
      first_remaining=0
      remaining+="{\"pid\":$pid,\"name\":$(json_str "$(proc_name "$pid")")}"
    fi
  done
  printf '{"stopped":[%s],"killed":[%s],"remaining":[%s],"refused":[%s]}\n' "$stopped" "$killed" "$remaining" "$refused"
}

# ------------------------------------------------------------------ verbs --

case "${1:-}" in
  storage-scan) storage_scan ;;
  storage-status) storage_status ;;
  storage-summary) storage_summary ;;
  storage-cancel) storage_cancel ;;
  storage-clean) shift; storage_clean "$@" ;;
  procs-scan) procs_scan ;;
  procs-stop) shift; procs_stop "$@" ;;
  *) echo "usage: $0 {storage-scan|storage-status|storage-summary|storage-cancel|storage-clean <category>|procs-scan|procs-stop <pid|group>}" >&2; exit 64 ;;
esac
''';

  // ---------------------------------------------------------------------------
  // AI Team on this phone (TEAM-301): ~/.oc/aiteam.sh next to manager.sh.
  // ---------------------------------------------------------------------------

  /// Where the bridge writes [_aiteamScript].
  static const aiteamPath = '$termuxHome/.oc/aiteam.sh';

  /// Where an install dispatched with the bundled manifest writes it.
  static const aiteamManifestPath = '$termuxHome/.oc/aiteam-manifest.json';

  /// The loopback supervisor every phone-hosted city listens on.
  static const aiteamSupervisorUrl = 'http://127.0.0.1:8372';

  /// The verbs `aiteam.sh` runs detached from the bridge shell (their
  /// progress is read back through `status`).
  static const aiteamDetachedVerbs = {
    'install',
    'init',
    'start',
    'stop',
    'remove',
  };

  static String aiteamScriptForTesting() => _aiteamScript;

  static String aiteamStatusScript() => aiteamVerbScript('status');

  static String aiteamLogPathScript() => aiteamVerbScript('log');

  /// The last [lines] of the AI Team live log (`~/.oc/aiteam/aiteam.log`),
  /// or nothing when no verb has run yet. Read inline: no script rewrite,
  /// no verb lock, so the setup screen can poll it beside `status`.
  static String aiteamLogTailScript({int lines = 200}) {
    if (lines < 1 || lines > 5000) {
      throw ArgumentError.value(lines, 'lines');
    }
    return 'tail -n $lines "\$HOME/.oc/aiteam/aiteam.log" 2>/dev/null || true\n';
  }

  /// The project folders of the managed server (`/root/projects/*` inside
  /// the rootfs), one name per line, in either proot-distro layout; empty
  /// when the rootfs is missing or has no projects yet.
  static String aiteamProjectsScript() =>
      '''
base="\${PREFIX:-/data/data/com.termux/files/usr}/var/lib/proot-distro"
for rootfs in "\$base/containers/opencode-ubuntu/rootfs" "\$base/installed-rootfs/opencode-ubuntu"; do
  if [ -d "\$rootfs$managedProjectsDirectory" ]; then
    for p in "\$rootfs$managedProjectsDirectory"/*/; do
      [ -d "\$p" ] || continue
      case "\$p" in *.git/) continue ;; esac
      basename "\$p"
    done
    break
  fi
done
''';

  /// The bridge shell for one `aiteam.sh` verb: rewrites the script from
  /// this build, then either runs the verb inline (`status`, `log`) or
  /// queues it and launches it detached in its own process group, printing
  /// `aiteam-started:<pid>` (or `aiteam-busy:<verb>:<pid>` with exit 75
  /// while another verb still runs). [manifestJson], when given, is written
  /// to [aiteamManifestPath] first so an install can read the bundled
  /// manifest as a local path.
  static String aiteamVerbScript(
    String verb, {
    List<String> args = const [],
    String? manifestJson,
  }) {
    if (!RegExp(r'^[a-z]+$').hasMatch(verb)) {
      throw ArgumentError.value(verb, 'verb');
    }
    for (final arg in args) {
      if (arg.contains('\n') || arg.contains('\x00')) {
        throw ArgumentError.value(arg, 'args', 'Must be a single line.');
      }
    }
    if (manifestJson != null &&
        manifestJson.contains('OC_AITEAM_MANIFEST_EOF')) {
      throw ArgumentError.value(manifestJson, 'manifestJson');
    }
    final quotedArgs = args.map(_shellQuote).join(' ');
    final buffer = StringBuffer('''
set -eu
OC_DIR="\$HOME/.oc"
AITEAM="\$OC_DIR/aiteam.sh"
mkdir -p "\$OC_DIR"
umask 077
aiteam_tmp="\$AITEAM.tmp.\$\$"
cat > "\$aiteam_tmp" <<'OC_AITEAM_EOF'
$_aiteamScript
OC_AITEAM_EOF
chmod 700 "\$aiteam_tmp"
mv "\$aiteam_tmp" "\$AITEAM"
[ -x "\$AITEAM" ] || {
  echo 'aiteam-install-failed' >&2
  exit 74
}
''');
    if (manifestJson != null) {
      buffer.write('''
manifest_tmp="\$OC_DIR/aiteam-manifest.json.tmp.\$\$"
cat > "\$manifest_tmp" <<'OC_AITEAM_MANIFEST_EOF'
$manifestJson
OC_AITEAM_MANIFEST_EOF
mv "\$manifest_tmp" "\$OC_DIR/aiteam-manifest.json"
''');
    }
    if (!aiteamDetachedVerbs.contains(verb)) {
      buffer.write('exec bash "\$AITEAM" $verb $quotedArgs\n');
      return buffer.toString();
    }
    buffer.write('''
bash "\$AITEAM" queue '$verb' || exit \$?
set -m
nohup bash "\$AITEAM" '$verb' $quotedArgs >/dev/null 2>&1 </dev/null &
echo "aiteam-started:\$!"
''');
    return buffer.toString();
  }

  /// Runs one `aiteam.sh` verb through the bridge and returns its stdout.
  static Future<String> aiteam(
    String verb, {
    List<String> args = const [],
    String? manifestJson,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final result = await run(
      aiteamVerbScript(verb, args: args, manifestJson: manifestJson),
      timeout: timeout,
    );
    return result.stdout;
  }

  static const _aiteamScript = r'''#!/data/data/com.termux/files/usr/bin/bash
# AI Team on this phone (TEAM-301): the managed Gas City runtime in the
# hybrid native layout (docs/qa/ai-team/spike-phone-2026-09.md §3f).
# gc, bd and dolt run natively in Termux; only the OpenCode agent process
# runs inside the glibc rootfs through the `opencode` wrapper.
#
# Verbs: install <manifest> | init <project> [--city n] [--rig n] | start |
#        stop | status | remove | log
# Every verb except status/log appends to ~/.oc/aiteam/aiteam.log and to the
# OpenCode install live output (~/.oc/install.log via manager.sh write-log).
set -Eeuo pipefail

OC_DIR="$HOME/.oc"
AITEAM_DIR="$OC_DIR/aiteam"
STATE="$AITEAM_DIR/state"
CONFIG="$AITEAM_DIR/config"
LOG="$AITEAM_DIR/aiteam.log"
VERB_LOCK="$AITEAM_DIR/verb.lock"
CITY_DIR="$AITEAM_DIR/city"
CITY_TOML="$AITEAM_DIR/city.toml"
SUPERVISOR_PID="$AITEAM_DIR/supervisor.pid"
SUPERVISOR_LOG="$AITEAM_DIR/supervisor.log"
REMOVED_FILE="$OC_DIR/aiteam-removed"
MANAGER="$OC_DIR/manager.sh"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
BIN_DIR="$PREFIX/bin"
TMP_DIR="$PREFIX/tmp/aiteam"
GC_URL="${AITEAM_URL:-http://127.0.0.1:8372}"
HEALTH_TIMEOUT="${AITEAM_HEALTH_TIMEOUT:-120}"
DEFAULT_CITY=phone
INSTALL_NAMES='gc bd dolt wrapper'

# ---------------------------------------------------------------------------
# state, config, logging
# ---------------------------------------------------------------------------

read_kv() {
  local file="$1" key="$2" name value
  [ -f "$file" ] || return 0
  while IFS='=' read -r name value; do
    if [ "$name" = "$key" ]; then
      printf '%s' "$value"
      return 0
    fi
  done < "$file"
}

state_value() { read_kv "$STATE" "$1"; }
config_value() { read_kv "$CONFIG" "$1"; }

# write_state <phase> <message> [supervisor_pid]
# Phases: idle downloading verifying installing-packages installed
# creating-city city-ready starting ready stopping stopped removing
# failed:<reason>. Keeps the verb name and pid of the running verb.
write_state() {
  local phase="$1" message="$2" supervisor="${3-$(state_value supervisor_pid)}"
  mkdir -p "$AITEAM_DIR"
  local tmp="$STATE.tmp.$$"
  printf 'phase=%s\nmessage=%s\nverb=%s\npid=%s\nsupervisor_pid=%s\nupdated_at=%s\n' \
    "$phase" "$message" "${CURRENT_VERB:-}" "${CURRENT_PID:-}" "$supervisor" "$(date +%s)" > "$tmp"
  mv "$tmp" "$STATE"
}

set_config() {
  local key="$1" value="$2"
  mkdir -p "$AITEAM_DIR"
  local tmp="$CONFIG.tmp.$$"
  { [ ! -f "$CONFIG" ] || grep -v "^$key=" "$CONFIG" || true; printf '%s=%s\n' "$key" "$value"; } > "$tmp"
  mv "$tmp" "$CONFIG"
}

log() { printf '[aiteam] %s\n' "$*"; }

# The managed Ubuntu rootfs, in either proot-distro layout; empty when it is
# not installed.
rootfs_dir() {
  local base="$PREFIX/var/lib/proot-distro"
  if [ -d "$base/containers/opencode-ubuntu/rootfs" ]; then
    printf '%s' "$base/containers/opencode-ubuntu/rootfs"
  elif [ -d "$base/installed-rootfs/opencode-ubuntu" ]; then
    printf '%s' "$base/installed-rootfs/opencode-ubuntu"
  else
    return 1
  fi
}

# A project the app names by its path inside the rootfs (/root/projects/x)
# lives natively under the rootfs directory; resolve it there when the
# path does not exist on the Termux side.
resolve_project() {
  local project="$1" rootfs
  if [ ! -d "$project" ]; then
    case "$project" in
      /root/*)
        if rootfs=$(rootfs_dir) && [ -d "$rootfs$project" ]; then
          project="$rootfs$project"
        fi ;;
    esac
  fi
  printf '%s' "$project"
}

live_sink() {
  if [ -x "$MANAGER" ]; then "$MANAGER" write-log install; else cat > /dev/null; fi
}

# Mirror everything a verb prints into aiteam.log and the OpenCode install
# live output so the setup screen's panel shows it.
attach_log() {
  mkdir -p "$AITEAM_DIR"
  touch "$LOG"
  chmod 600 "$LOG"
  # fd 3 keeps the original stdout (the terminal when run by hand over SSH;
  # /dev/null when the bridge dispatched the verb).
  exec 3>&1
  exec > >(tee -a "$LOG" >(live_sink) >&3) 2>&1
}

fail() {
  local reason="$1"
  shift
  local message="${*:-$reason}"
  trap - ERR
  write_state "failed:$reason" "$message"
  log "ERROR: $message"
  release_verb_lock
  exit "${FAIL_CODE:-1}"
}

on_verb_error() {
  local code=$?
  local line="${BASH_LINENO[0]:-unknown}"
  local stage
  stage=$(state_value message)
  [ -n "$stage" ] || stage="$CURRENT_VERB"
  fail "${CURRENT_VERB}-error" "$stage failed (exit $code; line $line)"
}

# ---------------------------------------------------------------------------
# processes
# ---------------------------------------------------------------------------

process_group() {
  local stat_line
  stat_line=$(cat "/proc/$1/stat" 2>/dev/null) || return 1
  stat_line=${stat_line##*) }
  set -- $stat_line
  printf '%s' "${3:-}"
}

process_alive() {
  case "${1:-}" in ''|*[!0-9]*) return 1 ;; esac
  kill -0 "$1" 2>/dev/null
}

process_cmdline() { { tr '\0' ' ' < "/proc/$1/cmdline"; } 2>/dev/null || true; }

# Long verbs own their process group so a Stop can take the whole tree down
# and so the bridge's shell exiting never takes the verb with it.
ensure_isolated() {
  [ "$(process_group "$$" 2>/dev/null || true)" = "$$" ] && return 0
  [ "${AITEAM_ISOLATED:-}" != 1 ] || return 0
  AITEAM_ISOLATED=1 exec setsid "${BASH:-bash}" "$0" "$@"
}

claim_verb_lock() {
  mkdir -p "$AITEAM_DIR"
  if mkdir "$VERB_LOCK" 2>/dev/null; then
    printf '%s %s\n' "$$" "$CURRENT_VERB" > "$VERB_LOCK/owner"
    return 0
  fi
  local owner_pid='' owner_verb=''
  [ -f "$VERB_LOCK/owner" ] && { read -r owner_pid owner_verb < "$VERB_LOCK/owner" || true; }
  if process_alive "$owner_pid"; then
    echo "aiteam-busy:${owner_verb:-unknown}:$owner_pid" >&2
    return 75
  fi
  rm -rf "$VERB_LOCK"
  mkdir "$VERB_LOCK" 2>/dev/null || return 75
  printf '%s %s\n' "$$" "$CURRENT_VERB" > "$VERB_LOCK/owner"
}

release_verb_lock() {
  local owner_pid=''
  [ -f "$VERB_LOCK/owner" ] && { read -r owner_pid _ < "$VERB_LOCK/owner" || true; }
  [ "$owner_pid" = "$$" ] || return 0
  rm -f "$VERB_LOCK/owner"
  rmdir "$VERB_LOCK" 2>/dev/null || true
}

begin_verb() {
  CURRENT_VERB="$1"
  CURRENT_PID="$$"
  claim_verb_lock || exit 75
  trap on_verb_error ERR
  trap release_verb_lock EXIT
  attach_log
  write_state queued "Starting $CURRENT_VERB"
  printf '\n[aiteam] %s started at %s\n' "$CURRENT_VERB" "$(date -Iseconds 2>/dev/null || date)"
}

# queue <verb>: the dispatcher's synchronous gate. Refuses while another
# verb owns the lock (aiteam-busy:<verb>:<pid>, exit 75), else records the
# queued verb so a status read between dispatch and the verb's first write
# already reports it as busy.
queue_verb() {
  local next="${1:-}"
  case "$next" in install|init|start|stop|remove) ;; *) exit 64 ;; esac
  local owner_pid='' owner_verb=''
  [ -f "$VERB_LOCK/owner" ] && { read -r owner_pid owner_verb < "$VERB_LOCK/owner" || true; }
  if process_alive "$owner_pid"; then
    echo "aiteam-busy:${owner_verb:-unknown}:$owner_pid" >&2
    exit 75
  fi
  CURRENT_VERB="$next" CURRENT_PID='' write_state queued "Queued $next"
  echo "aiteam-queued:$next"
}

verb_alive() {
  process_alive "${1:-}" || return 1
  case "$(process_cmdline "$1")" in *aiteam*) return 0 ;; esac
  return 1
}

supervisor_alive() {
  local pid
  pid=$(cat "$SUPERVISOR_PID" 2>/dev/null || true)
  process_alive "$pid" || return 1
  case "$(process_cmdline "$pid")" in *supervisor*) return 0 ;; esac
  return 1
}

health_json() {
  local city="${1:-}"
  if [ -n "$city" ]; then
    curl -s -m 5 "$GC_URL/v0/city/$city/health" 2>/dev/null || true
  else
    curl -s -m 5 "$GC_URL/health" 2>/dev/null || true
  fi
}

health_status() {
  local body
  body=$(health_json "$@")
  [ -n "$body" ] || { printf unreachable; return 0; }
  printf '%s' "$body" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p' | head -1
}

# ---------------------------------------------------------------------------
# manifest (schema 1, tool/host/aiteam-manifest-*.json)
# ---------------------------------------------------------------------------

manifest_str() { printf '%s' "$MANIFEST" | sed -n "s/.*\"$1\":\"\([^\"]*\)\".*/\1/p" | head -1; }

manifest_file_field() {
  local object
  object=$(printf '%s' "$MANIFEST" | sed -n "s/.*\"$1\":{\([^}]*\)}.*/\1/p" | head -1)
  case "$2" in
    bytes) printf '%s' "$object" | sed -n 's/.*"bytes":\([0-9]*\).*/\1/p' | head -1 ;;
    *) printf '%s' "$object" | sed -n "s/.*\"$2\":\"\([^\"]*\)\".*/\1/p" | head -1 ;;
  esac
}

manifest_packages() {
  printf '%s' "$MANIFEST" | sed -n 's/.*"termux_packages":\[\([^]]*\)\].*/\1/p' | tr -d '"' | tr ',' ' '
}

install_target() {
  case "$1" in
    gc) printf '%s' "$BIN_DIR/gc" ;;
    bd) printf '%s' "$BIN_DIR/bd" ;;
    dolt) printf '%s' "$BIN_DIR/dolt" ;;
    wrapper) printf '%s' "$BIN_DIR/opencode" ;;
    *) return 64 ;;
  esac
}

fetch() {
  local source="$1" target="$2"
  case "$source" in
    http://*|https://*|file://*)
      curl -fsSL --retry 3 --retry-delay 2 -o "$target" "$source" ;;
    *) cp "$source" "$target" ;;
  esac
}

# ---------------------------------------------------------------------------
# install <manifest-path-or-url>
# ---------------------------------------------------------------------------

# free_mb <path>: megabytes free on the filesystem holding <path> (0 when unknown).
free_mb() {
  local kb
  # No df or awk on PATH (test fixtures, odd Termux installs): do not guess,
  # let the install proceed and fail honestly later.
  command -v df >/dev/null 2>&1 && command -v awk >/dev/null 2>&1 || { echo 999999; return 0; }
  kb=$(df -Pk "$1" 2>/dev/null | awk 'NR==2 {print $4}') || kb=''
  case "$kb" in ''|*[!0-9]*) echo 999999 ;; *) echo $((kb / 1024)) ;; esac
}

# require_space <mb> <what>: fail no-space with an honest sentence when the
# phone cannot hold <what>. Dolt and gc misbehave in confusing ways on a
# full disk (a start that only "times out"), so check up front.
require_space() {
  local need="$1" what="$2" have
  have=$(free_mb "$HOME")
  [ "$have" -ge "$need" ] || fail no-space "Not enough space on this phone for $what: $have MB free, $need MB needed"
}

install_runtime() {
  local source="${1:-}"
  [ -n "$source" ] || { echo 'usage: aiteam.sh install <manifest-path-or-url>' >&2; exit 64; }
  begin_verb install
  rm -f "$REMOVED_FILE"
  local arch="${AITEAM_ARCH:-$(uname -m)}"
  local want_arch
  case "$arch" in
    aarch64|arm64) want_arch=arm64 ;;
    x86_64|amd64) want_arch=x86_64 ;;
    *) fail unsupported-arch "AI Team needs a 64-bit phone (this one reports $arch)" ;;
  esac
  require_space 900 'the AI Team runtime (three binaries plus packages)'
  write_state downloading 'Downloading the AI Team manifest'
  mkdir -p "$TMP_DIR"
  chmod 700 "$TMP_DIR"
  local manifest_path="$TMP_DIR/manifest.json"
  fetch "$source" "$manifest_path" || fail manifest-download "Could not download the manifest from $source"
  MANIFEST=$(tr -d '\n\r\t ' < "$manifest_path")
  local base_url
  base_url=$(manifest_str base_url)
  [ -n "$base_url" ] || fail manifest-invalid 'The manifest has no base_url'
  [ "$(manifest_str arch)" = "$want_arch" ] || fail manifest-invalid "The manifest is not a $want_arch build"

  local name file bytes sha target
  for name in $INSTALL_NAMES; do
    file=$(manifest_file_field "$name" name)
    bytes=$(manifest_file_field "$name" bytes)
    sha=$(manifest_file_field "$name" sha256)
    [ -n "$file" ] && [ -n "$bytes" ] && [ -n "$sha" ] ||
      fail manifest-invalid "The manifest has no complete entry for $name"
    write_state downloading "Downloading $file ($((bytes / 1048576)) MB)"
    log "downloading $base_url$file"
    fetch "$base_url$file" "$TMP_DIR/$file.part" ||
      fail download "Could not download $file"
  done

  write_state verifying 'Verifying checksums'
  for name in $INSTALL_NAMES; do
    file=$(manifest_file_field "$name" name)
    bytes=$(manifest_file_field "$name" bytes)
    sha=$(manifest_file_field "$name" sha256)
    local actual_bytes actual_sha
    actual_bytes=$(wc -c < "$TMP_DIR/$file.part" | tr -d ' ')
    actual_sha=$(sha256sum "$TMP_DIR/$file.part" | cut -d' ' -f1)
    if [ "$actual_bytes" != "$bytes" ] || [ "$actual_sha" != "$sha" ]; then
      rm -f "$TMP_DIR"/*.part
      echo "checksum-mismatch $name"
      FAIL_CODE=65 fail "checksum-mismatch $name" \
        "$file did not match the pinned checksum (got $actual_bytes bytes, $actual_sha)"
    fi
    log "verified $file ($bytes bytes)"
  done

  write_state installing-packages 'Installing Termux packages'
  local packages
  packages=$(manifest_packages)
  [ -n "$packages" ] || packages='libicu git jq tmux'
  # shellcheck disable=SC2086
  pkg install -y $packages || fail packages "Could not install Termux packages: $packages"

  write_state installing-packages 'Installing gc, bd, dolt and the opencode wrapper'
  mkdir -p "$BIN_DIR"
  for name in $INSTALL_NAMES; do
    file=$(manifest_file_field "$name" name)
    target=$(install_target "$name")
    chmod 755 "$TMP_DIR/$file.part"
    mv -f "$TMP_DIR/$file.part" "$target"
    log "installed $target"
  done
  rm -rf "$TMP_DIR"

  # Dolt and beads refuse to run without an identity and a maintainer role.
  dolt config --global --add user.name 'OpenCode Mobile' >/dev/null 2>&1 || true
  dolt config --global --add user.email 'aiteam@opencode-mobile.local' >/dev/null 2>&1 || true
  git config --global user.name >/dev/null 2>&1 || git config --global user.name 'OpenCode Mobile'
  git config --global user.email >/dev/null 2>&1 || git config --global user.email 'aiteam@opencode-mobile.local'
  git config --global beads.role maintainer

  set_config gascity "$(manifest_str gascity)"
  set_config beads "$(manifest_str beads)"
  set_config dolt "$(manifest_str dolt)"
  set_config pack "$(manifest_str pack)"
  set_config manifest "$source"
  set_config installed_at "$(date +%s)"
  write_state installed 'AI Team runtime installed' ''
  log 'install finished'
}

# ---------------------------------------------------------------------------
# init <project-path> [--city name] [--rig name]
# ---------------------------------------------------------------------------

safe_name() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9_-' '-' | sed 's/^-*//; s/-*$//' | cut -c1-40
}

init_city() {
  local project='' city='' rig=''
  while [ $# -gt 0 ]; do
    case "$1" in
      --city) city="${2:-}"; shift 2 ;;
      --rig) rig="${2:-}"; shift 2 ;;
      *) project="$1"; shift ;;
    esac
  done
  [ -n "$project" ] || { echo 'usage: aiteam.sh init <project-path> [--city name] [--rig name]' >&2; exit 64; }
  begin_verb init
  require_space 150 'the team city and its store'
  [ -x "$BIN_DIR/gc" ] || fail not-installed 'Install the AI Team runtime first'
  project=${project%/}
  project=$(resolve_project "$project")
  [ -d "$project" ] || fail project-missing "Project folder not found: $project"
  git -C "$project" rev-parse --git-dir >/dev/null 2>&1 ||
    fail project-not-git "$project is not a git repository"
  [ -n "$city" ] || city="$DEFAULT_CITY"
  [ -n "$rig" ] || rig=$(safe_name "$(basename "$project")")
  [ -n "$rig" ] || rig=project
  city=$(safe_name "$city")
  [ -n "$city" ] || city="$DEFAULT_CITY"

  write_state creating-city "Preparing $project"
  local origin
  if ! origin=$(git -C "$project" remote get-url origin 2>/dev/null); then
    origin="$project.git"
    log "no origin remote; creating a bare origin at $origin"
    [ -d "$origin" ] || git init -q --bare "$origin"
    git -C "$project" remote add origin "$origin"
    git -C "$project" push -q origin HEAD || fail project-push "Could not push $project to its new origin"
  fi

  write_state creating-city "Creating city $city"
  local pack pack_source pack_version
  pack=$(config_value pack)
  pack_source='https://github.com/gastownhall/gascity-packs/tree/main/gastown'
  pack_version=${pack#gastown@}
  [ -n "$pack_version" ] && [ "$pack_version" != "$pack" ] || pack_version='sha:33d3a430a67d1782ad364556cb566bdb01d0afe3'
  cat > "$CITY_TOML" <<CITY_TOML_EOF
[workspace]
provider = "opencode"
install_agent_hooks = ["opencode"]
[providers]
[providers.opencode]
base = "builtin:opencode"
ready_delay_ms = 0
[defaults]
[defaults.rig]
[defaults.rig.imports]
[defaults.rig.imports.gastown]
source = "$pack_source"
version = "$pack_version"
[daemon]
patrol_interval = "30s"
max_restarts = 5
restart_window = "1h"
shutdown_timeout = "5s"
CITY_TOML_EOF
  rm -rf "$CITY_DIR"
  (cd "$AITEAM_DIR" && gc init --file ./city.toml --name "$city" --no-start city) ||
    fail gc-init 'gc init failed'
  [ -d "$CITY_DIR" ] || fail gc-init 'gc init produced no city directory'
  (cd "$CITY_DIR" && gc rig add "$project" --name "$rig") || fail gc-rig-add 'gc rig add failed'
  (cd "$CITY_DIR" && gc import install) || fail gc-import 'gc import install failed'
  # Lean profile: one polecat, the patrol agents suspended; must come after
  # `gc import install` or the pack's agents are not known yet.
  printf '\n[[patches.agent]]\nname = "gastown.mayor"\nsuspended = true\n[[patches.agent]]\nname = "gastown.deacon"\nsuspended = true\n[[patches.agent]]\nname = "gastown.boot"\nsuspended = true\n[[patches.agent]]\nname = "gastown.witness"\ndir = "%s"\nsuspended = true\n[[patches.agent]]\nname = "gastown.polecat"\ndir = "%s"\nmax_active_sessions = 1\n' \
    "$rig" "$rig" >> "$CITY_DIR/city.toml"
  # The Termux exec shim does not rewrite `#!/usr/bin/env bash`.
  sed -i 's|#!/usr/bin/env bash|#!/bin/bash|' "$HOME"/.gc/cache/repos/*/gastown/assets/scripts/*.sh 2>/dev/null || true

  set_config city "$city"
  set_config rig "$rig"
  set_config project "$project"
  set_config origin "$origin"
  set_config city_dir "$CITY_DIR"
  write_state city-ready "City $city created for $rig" ''
  log "init finished: city=$city rig=$rig project=$project"
}

# ---------------------------------------------------------------------------
# start / stop
# ---------------------------------------------------------------------------

start_runtime() {
  begin_verb start
  [ -x "$BIN_DIR/gc" ] || fail not-installed 'Install the AI Team runtime first'
  local city
  city=$(config_value city)
  [ -n "$city" ] && [ -d "$CITY_DIR" ] || fail no-city 'Create a city first (init)'
  write_state starting 'Starting the AI Team supervisor'
  termux-wake-lock >/dev/null 2>&1 || true
  if supervisor_alive && [ "$(health_status "$city")" = ok ]; then
    write_state ready 'AI Team is running on this phone'
    log 'supervisor already running'
    return 0
  fi
  rm -f "$SUPERVISOR_PID"
  # Its own session with none of this verb's descriptors (the log tee's
  # pipe included): the verb exits, the supervisor keeps running (§3f).
  (
    cd "$CITY_DIR"
    for fd in /proc/$BASHPID/fd/*; do
      fd=${fd##*/}
      [ "$fd" -gt 2 ] 2>/dev/null && eval "exec $fd>&-"
    done
    nohup setsid gc supervisor run > "$SUPERVISOR_LOG" 2>&1 < /dev/null &
    echo $! > "$SUPERVISOR_PID"
  )
  local pid
  pid=$(cat "$SUPERVISOR_PID")
  log "supervisor pid $pid"
  local waited=0
  while [ "$(health_status)" != ok ]; do
    process_alive "$pid" || fail supervisor-exited 'The supervisor exited before it became healthy'
    [ "$waited" -lt 30 ] || break
    sleep 1
    waited=$((waited + 1))
  done
  write_state starting "Registering city $city" "$pid"
  (cd "$CITY_DIR" && timeout -k 5 60 gc register "$CITY_DIR" --name "$city" --yes) ||
    log 'gc register did not confirm; waiting on health anyway'
  write_state starting "Waiting for city $city" "$pid"
  waited=0
  while [ "$(health_status "$city")" != ok ]; do
    process_alive "$pid" || fail supervisor-exited 'The supervisor exited before the city became healthy'
    [ "$waited" -lt "$HEALTH_TIMEOUT" ] || fail health-timeout "City $city did not become healthy in $HEALTH_TIMEOUT s"
    sleep 1
    waited=$((waited + 1))
  done
  write_state ready 'AI Team is running on this phone' "$pid"
  log "city $city healthy"
}

# Kills every process of ours that works inside the city (gc/bd/dolt agents,
# proot-distro logins for agent worktrees) — never anything else.
kill_city_processes() {
  local city_dir="$1" signal="$2" entry pid cwd cmdline
  [ -n "$city_dir" ] || return 0
  for entry in /proc/[0-9]*; do
    pid=${entry#/proc/}
    [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ] || continue
    cwd=$(readlink "$entry/cwd" 2>/dev/null || true)
    cmdline=$(process_cmdline "$pid")
    case "$cwd" in
      "$city_dir"|"$city_dir"/*) ;;
      *) case "$cmdline" in
           *"$city_dir"*) ;;
           *) continue ;;
         esac ;;
    esac
    case "$cmdline" in
      *aiteam.sh*) continue ;;
    esac
    log "$signal pid $pid (${cmdline:0:60})"
    kill "-$signal" "$pid" 2>/dev/null || true
  done
}

stop_supervisor() {
  local pid
  pid=$(cat "$SUPERVISOR_PID" 2>/dev/null || true)
  if [ -d "$CITY_DIR" ]; then
    (cd "$CITY_DIR" && timeout -k 5 30 gc supervisor stop) >/dev/null 2>&1 || true
  fi
  if process_alive "$pid"; then
    kill -TERM "$pid" 2>/dev/null || true
    local waited=0
    while process_alive "$pid" && [ "$waited" -lt 10 ]; do sleep 1; waited=$((waited + 1)); done
    process_alive "$pid" && kill -KILL "$pid" 2>/dev/null || true
  fi
  kill_city_processes "$CITY_DIR" TERM
  sleep 1
  kill_city_processes "$CITY_DIR" KILL
  rm -f "$SUPERVISOR_PID"
}

stop_runtime() {
  begin_verb stop
  write_state stopping 'Stopping the AI Team'
  stop_supervisor
  termux-wake-unlock >/dev/null 2>&1 || true
  write_state stopped 'AI Team stopped' ''
  log 'stopped'
}

# ---------------------------------------------------------------------------
# remove: binaries, ~/.oc/aiteam (city + Dolt store), ~/.gc, ~/.dolt.
# Never the project folder or its bare origin.
# ---------------------------------------------------------------------------

remove_runtime() {
  begin_verb remove
  write_state removing 'Removing the AI Team from this phone'
  stop_supervisor
  termux-wake-unlock >/dev/null 2>&1 || true
  local removed=() path
  for path in "$BIN_DIR/gc" "$BIN_DIR/bd" "$BIN_DIR/dolt"; do
    [ -e "$path" ] || continue
    rm -f "$path"
    removed+=("$path")
  done
  if [ -f "$BIN_DIR/opencode" ] && grep -q 'AI Team' "$BIN_DIR/opencode" 2>/dev/null; then
    rm -f "$BIN_DIR/opencode"
    removed+=("$BIN_DIR/opencode")
  fi
  for path in "$HOME/.gc" "$HOME/.dolt" "$PREFIX/tmp/aiteam"; do
    [ -e "$path" ] || continue
    rm -rf "$path"
    removed+=("$path")
  done
  # Printed before the log itself goes: aiteam.log lives in $AITEAM_DIR.
  for path in "${removed[@]}" "$AITEAM_DIR"; do log "removed $path"; done
  rm -rf "$AITEAM_DIR"
  removed+=("$AITEAM_DIR")
  printf '%s\n' "${removed[@]}" > "$REMOVED_FILE"
  trap - EXIT
  exit 0
}

# ---------------------------------------------------------------------------
# status (JSON) and log
# ---------------------------------------------------------------------------

json_str() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\t'/\\t}
  value=${value//$'\r'/}
  printf '"%s"' "$value"
}

json_or_null() { if [ -n "$1" ]; then json_str "$1"; else printf null; fi; }
json_num_or_null() { case "$1" in ''|*[!0-9]*) printf null ;; *) printf '%s' "$1" ;; esac; }

binary_version() {
  local binary="$1" out
  [ -x "$BIN_DIR/$binary" ] || return 0
  # gc, bd and dolt all answer `<binary> version` (gc rejects --version).
  # Never let a probe failure abort a status read under set -e.
  out=$(timeout 5 "$BIN_DIR/$binary" version 2>/dev/null | grep -v '^time=' | head -1 || true)
  printf '%s' "$out" | sed 's/^[a-z]* version //; s/ (.*$//' | tr -d '\r\n' || true
  return 0
}

agents_count() {
  local city="$1" body
  [ -n "$city" ] || return 0
  body=$(curl -s -m 5 "$GC_URL/v0/city/$city/agents" 2>/dev/null || true)
  [ -n "$body" ] || return 0
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$body" | jq -r '(.items // []) | length' 2>/dev/null || true
  else
    printf '%s' "$body" | grep -o '"id":' | wc -l | tr -d ' '
  fi
}

status_json() {
  local phase message verb pid supervisor city rig project url installed
  phase=$(state_value phase)
  message=$(state_value message)
  verb=$(state_value verb)
  pid=$(state_value pid)
  supervisor=$(state_value supervisor_pid)
  city=$(config_value city)
  rig=$(config_value rig)
  project=$(config_value project)
  local last_error='' busy=false killed=false health='' agents='' gc_v bd_v dolt_v
  gc_v=$(binary_version gc)
  bd_v=$(binary_version bd)
  dolt_v=$(binary_version dolt)
  if [ -x "$BIN_DIR/gc" ] && [ -x "$BIN_DIR/bd" ] && [ -x "$BIN_DIR/dolt" ]; then installed=true; else installed=false; fi
  [ -n "$phase" ] || phase=idle
  if verb_alive "$pid"; then
    busy=true
  else
    pid=''
  fi
  local age=0 updated
  updated=$(state_value updated_at)
  case "$updated" in ''|*[!0-9]*) ;; *) age=$(( $(date +%s) - updated )) ;; esac
  local state_phase="$phase" reason=''
  case "$phase" in
    failed:*)
      reason=${phase#failed:}
      last_error="${message:-$reason}"
      phase=failed ;;
    queued)
      # Dispatched but not yet running: busy for a grace period, then a
      # launch that never happened.
      if [ "$busy" = false ] && [ "$age" -lt 30 ]; then busy=true; fi
      if [ "$busy" = false ]; then
        last_error="$verb never started"
        CURRENT_VERB="$verb" CURRENT_PID='' write_state "failed:interrupted" "$last_error"
        phase=failed; reason=interrupted; state_phase=failed:interrupted
      fi ;;
    downloading|verifying|installing-packages|creating-city|starting|stopping|removing)
      # A verb's pid can be momentarily unobservable between two of its own
      # writes (the detached shell re-execs under setsid); only a phase that
      # has sat unowned for a while is a real interruption.
      if [ "$busy" = false ] && [ "$age" -lt 10 ]; then busy=true; fi
      if [ "$busy" = false ]; then
        last_error="$verb stopped unexpectedly while $phase"
        CURRENT_VERB="$verb" CURRENT_PID='' write_state "failed:interrupted" "$last_error"
        phase=failed; reason=interrupted; state_phase=failed:interrupted
      fi ;;
  esac
  local supervisor_live=false
  if supervisor_alive; then supervisor_live=true; else supervisor=''; fi
  if [ "$phase" = ready ]; then
    if [ "$supervisor_live" = true ]; then
      health=$(health_status "$city")
      agents=$(agents_count "$city")
    else
      killed=true
      health=unreachable
    fi
  elif [ "$supervisor_live" = true ]; then
    health=$(health_status "$city")
  fi
  local removed='[]'
  if [ -f "$REMOVED_FILE" ]; then
    removed='['
    local first=1 line
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      [ "$first" = 1 ] || removed="$removed,"
      removed="$removed$(json_str "$line")"
      first=0
    done < "$REMOVED_FILE"
    removed="$removed]"
  fi
  printf '{"installed":%s,"versions":{"gc":%s,"bd":%s,"dolt":%s},"phase":%s,"state_phase":%s,"reason":%s,"message":%s,"verb":%s,"busy":%s,"pid":%s,"supervisor_pid":%s,"health":%s,"agents":%s,"city":%s,"rig":%s,"project":%s,"url":%s,"last_error":%s,"killed_by_android":%s,"removed":%s,"log":%s,"updated_at":%s}\n' \
    "$installed" "$(json_or_null "$gc_v")" "$(json_or_null "$bd_v")" "$(json_or_null "$dolt_v")" \
    "$(json_str "$phase")" "$(json_str "$state_phase")" "$(json_or_null "$reason")" \
    "$(json_or_null "$message")" "$(json_or_null "$verb")" "$busy" \
    "$(json_num_or_null "$pid")" "$(json_num_or_null "$supervisor")" "$(json_or_null "$health")" \
    "$(json_num_or_null "$agents")" "$(json_or_null "$city")" "$(json_or_null "$rig")" \
    "$(json_or_null "$project")" "$(json_str "$GC_URL")" "$(json_or_null "$last_error")" "$killed" \
    "$removed" "$(json_str "$LOG")" "$(json_num_or_null "$(state_value updated_at)")"
}

verb="${1:-status}"
case "$verb" in
  install|init|start|stop|remove)
    ensure_isolated "$@"
    shift
    case "$verb" in
      install) install_runtime "$@" ;;
      init) init_city "$@" ;;
      start) start_runtime ;;
      stop) stop_runtime ;;
      remove) remove_runtime ;;
    esac ;;
  queue) shift; queue_verb "$@" ;;
  status) status_json ;;
  log) printf '%s\n' "$LOG" ;;
  *) echo "usage: $0 {install|init|start|stop|status|remove|log}" >&2; exit 64 ;;
esac
''';
}

/// The installed app-owned environment, independent of server running state.
class TermuxStorageSnapshot {
  const TermuxStorageSnapshot({
    required this.totalBytes,
    required this.availableBytes,
  });
  final int totalBytes;
  final int availableBytes;

  factory TermuxStorageSnapshot.parse(String output) {
    final values = <String, int>{};
    for (final line in output.trim().split('\n')) {
      final match = RegExp(
        r'^(total_kib|available_kib)=([0-9]{1,13})$',
      ).firstMatch(line);
      if (match == null || values.containsKey(match[1])) {
        throw const TermuxBridgeException(
          'Could not read Termux storage.',
          code: 'invalid_storage',
        );
      }
      values[match[1]!] = int.parse(match[2]!);
    }
    final total = values['total_kib'];
    final available = values['available_kib'];
    if (total == null || available == null || total <= 0 || available > total) {
      throw const TermuxBridgeException(
        'Could not read Termux storage.',
        code: 'invalid_storage',
      );
    }
    return TermuxStorageSnapshot(
      totalBytes: total * 1024,
      availableBytes: available * 1024,
    );
  }
}

class TermuxInstallation {
  final bool ubuntuInstalled;
  final String? openCodeVersion;
  final TermuxRuntime runtime;
  final bool runtimeSelected;

  const TermuxInstallation({
    required this.ubuntuInstalled,
    this.openCodeVersion,
    this.runtime = TermuxRuntime.openCode1,
    this.runtimeSelected = false,
  });

  factory TermuxInstallation.parse(String output) {
    final match = RegExp(
      r'^ubuntu=(absent|installed)\r?\nversion=([^\r\n]*)(?:\r?\nruntime=(opencode1|opencode2))?\r?\n?$',
    ).firstMatch(output.trim());
    if (match == null) {
      throw const TermuxBridgeException(
        'Could not read the installed Ubuntu and OpenCode versions.',
        code: 'invalid_installation_probe',
      );
    }
    final installed = match[1] == 'installed';
    final version = match[2]!;
    if (version.isNotEmpty &&
        (!installed ||
            !RegExp(
              r'^\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?$',
            ).hasMatch(version))) {
      throw const TermuxBridgeException(
        'OpenCode returned an unexpected version response.',
        code: 'invalid_installation_probe',
      );
    }
    return TermuxInstallation(
      ubuntuInstalled: installed,
      openCodeVersion: version.isEmpty ? null : version,
      runtime: TermuxRuntime.parse(match[3]),
      runtimeSelected: match[3] != null,
    );
  }
}

class TermuxCapabilities {
  final bool installed;
  final String? version;
  final bool serviceAvailable;
  final bool protocolSupported;
  final bool permissionGranted;

  const TermuxCapabilities({
    required this.installed,
    required this.version,
    required this.serviceAvailable,
    required this.protocolSupported,
    required this.permissionGranted,
    this.platformSupported = true,
  });

  /// What a platform without a Termux bridge reports: nothing is installed,
  /// nothing is granted, and — unlike an Android phone that simply has not
  /// installed Termux yet — [platformSupported] says installing it would not
  /// help. Callers use that to choose between "install Termux" and "this is
  /// not a thing here".
  const TermuxCapabilities.unavailable()
    : installed = false,
      version = null,
      serviceAvailable = false,
      protocolSupported = false,
      permissionGranted = false,
      platformSupported = false;

  /// False when the running platform has no Termux bridge at all.
  final bool platformSupported;

  factory TermuxCapabilities.fromMap(Map<String, dynamic> map) =>
      TermuxCapabilities(
        installed: map['installed'] == true,
        version: map['version']?.toString(),
        serviceAvailable: map['serviceAvailable'] == true,
        protocolSupported: map['protocolSupported'] == true,
        permissionGranted: map['permissionGranted'] == true,
      );
}

class TermuxCommandResult {
  final String stdout;
  final String stderr;
  final int exitCode;
  final int errorCode;
  final String errorMessage;

  const TermuxCommandResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.errorCode,
    required this.errorMessage,
  });

  bool get successful => errorCode == -1 && exitCode == 0;

  String get failureMessage {
    final details = [
      errorMessage.trim(),
      stderr.trim(),
    ].where((part) => part.isNotEmpty).join('\n');
    return details.isEmpty
        ? 'Termux command failed (error $errorCode, exit $exitCode).'
        : details;
  }

  factory TermuxCommandResult.fromMap(Map<String, dynamic> map) =>
      TermuxCommandResult(
        stdout: map['stdout']?.toString() ?? '',
        stderr: map['stderr']?.toString() ?? '',
        exitCode: (map['exitCode'] as num?)?.toInt() ?? -1,
        errorCode: (map['err'] as num?)?.toInt() ?? -1,
        errorMessage: map['errorMessage']?.toString() ?? '',
      );
}

class TermuxSetupStatus {
  final String phase;
  final String message;
  final int port;
  final String runner;
  final String version;
  final int? pid;
  final int? startedAtEpochSeconds;
  final String operationID;
  final String operationResult;
  final String failureKind;
  final TermuxRuntime runtime;
  final bool runtimeSelected;
  final TermuxRuntime? switchPrevious;
  final TermuxRuntime? switchTarget;
  final String switchPhase;
  final bool switchReturnAvailable;
  bool get switchPending => switchPrevious != null && switchTarget != null;

  const TermuxSetupStatus({
    required this.phase,
    required this.message,
    required this.port,
    required this.runner,
    required this.version,
    required this.pid,
    this.startedAtEpochSeconds,
    this.operationID = '',
    this.operationResult = '',
    this.failureKind = '',
    this.runtime = TermuxRuntime.openCode1,
    this.runtimeSelected = false,
    this.switchPrevious,
    this.switchTarget,
    this.switchPhase = '',
    this.switchReturnAvailable = false,
  });

  bool get isRunning => const {
    'queued',
    'preparing',
    'installing_dependencies',
    'installing_ubuntu',
    'installing_opencode',
    'refreshing_models',
    'restarting',
    'starting_server',
  }.contains(phase);
  bool get isReady => phase == 'ready';
  bool get isFailed => phase == 'failed';
  bool get canRecover =>
      isFailed &&
      !switchPending &&
      runner == 'proot' &&
      port == TermuxBridge.managedServerPort &&
      (failureKind == 'crash' || failureKind == 'recovery');

  factory TermuxSetupStatus.parse(String output) {
    final values = <String, String>{};
    for (final line in output.split('\n')) {
      final separator = line.indexOf('=');
      if (separator <= 0) continue;
      values[line.substring(0, separator)] = line.substring(separator + 1);
    }
    final rawStartedAt = values['started_at'] ?? '';
    final startedAt = RegExp(r'^[0-9]+$').hasMatch(rawStartedAt)
        ? int.tryParse(rawStartedAt)
        : null;
    return TermuxSetupStatus(
      phase: values['phase'] ?? 'unknown',
      message: values['message'] ?? 'Unknown setup state',
      port: int.tryParse(values['port'] ?? '') ?? 4096,
      runner: values['runner'] ?? '',
      version: values['version'] ?? '',
      pid: int.tryParse(values['pid'] ?? ''),
      startedAtEpochSeconds: startedAt != null && startedAt >= 0
          ? startedAt
          : null,
      operationID: values['operation'] ?? '',
      operationResult: values['operation_result'] ?? '',
      failureKind: values['failure_kind'] ?? '',
      runtime: TermuxRuntime.parse(values['runtime']),
      runtimeSelected: values['runtime']?.trim().isNotEmpty == true,
      switchPrevious: values['switch_previous'] == null
          ? null
          : TermuxRuntime.parse(values['switch_previous']),
      switchTarget: values['switch_target'] == null
          ? null
          : TermuxRuntime.parse(values['switch_target']),
      switchPhase: values['switch_phase'] ?? '',
      switchReturnAvailable: values['switch_return'] == 'opencode1',
    );
  }
}

class TermuxSetupSnapshot {
  static const _marker = '__OC_SETUP_OUTPUT__';

  final TermuxSetupStatus status;
  final String output;

  const TermuxSetupSnapshot({required this.status, required this.output});

  factory TermuxSetupSnapshot.parse(String raw) {
    final markerIndex = raw.indexOf(_marker);
    if (markerIndex < 0) {
      return TermuxSetupSnapshot(
        status: TermuxSetupStatus.parse(raw),
        output: '',
      );
    }
    return TermuxSetupSnapshot(
      status: TermuxSetupStatus.parse(raw.substring(0, markerIndex)),
      output: raw.substring(markerIndex + _marker.length).trim(),
    );
  }
}

class TermuxBridgeException implements Exception {
  final String message;
  final String code;

  const TermuxBridgeException(this.message, {this.code = 'termux_error'});

  @override
  String toString() => message;
}
