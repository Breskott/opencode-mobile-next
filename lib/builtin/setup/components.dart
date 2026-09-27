import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../../termux/bridge.dart' show TermuxBridge, TermuxRuntime;
import '../../termux/opencode_ubuntu_setup.dart';
import '../../voice/model_manifest.dart';
import '../builtin_linux.dart';
import 'aiteam_scripts.dart';
import 'setup_contract.dart';
import 'voice_component.dart';

/// Every component the phone setup can install, in dependency order
/// (docs/design/phone-setup-v2-2026-09-24.md, "Components").
///
/// Adding a tool means adding one entry here: a check script and an install
/// script. The engine, the Kotlin job runner and the screens stay as they
/// are.
///
/// [params] are per component id; `opencode` reads `runtime`
/// (`opencode1`, the default, or `opencode2`) and `version` (the pinned one
/// unless a caller asks for another on purpose).
///
/// The estimates start from the emulator (setup.json keeps each component's
/// start and end; 2026-09-24: Linux base 8.5 s, essentials 29 s, Python 17 s,
/// Node 5 s, OpenCode 26 s, start 7 s on a fast network) and are raised for a
/// phone, where proot makes apt and npm several times slower. They weigh the
/// bar and the ETA against each other, and the ETA rescales them by the
/// pace it measures, so being off by a factor only shows in the first 10 s.
///
/// [host] is where the job runs. On Termux an older build installed Node
/// from Ubuntu's own packages; that Node already runs OpenCode there, so
/// the Termux check accepts it rather than replacing it under a working
/// server (an existing Termux install is recognised as done).
List<SetupComponent> setupComponents(
  AppLocalizations l10n, {
  Map<String, Map<String, String>> params = const {},
  SetupHostKind host = SetupHostKind.builtin,
}) {
  final openCode = params[SetupComponentIds.openCode] ?? const {};
  final runtime = TermuxRuntime.parse(openCode['runtime']);
  final version = openCode['version'];
  return [
    SetupComponent(
      id: SetupComponentIds.linux,
      title: l10n.phoneSetupLinuxTitle,
      shortTitle: l10n.phoneSetupLinuxTitle,
      why: l10n.phoneSetupLinuxWhy,
      required: true,
      native: true,
      estimatedSeconds: 15,
      downloadBytes: 30 * _mb,
      checkScript: SetupScripts.linuxCheck,
      installScript: '',
    ),
    SetupComponent(
      id: SetupComponentIds.essentials,
      title: l10n.phoneSetupEssentialsTitle,
      shortTitle: l10n.phoneSetupEssentialsShort,
      why: l10n.phoneSetupEssentialsWhy,
      dependsOn: const [SetupComponentIds.linux],
      required: true,
      estimatedSeconds: 60,
      downloadBytes: 45 * _mb,
      checkScript: SetupScripts.essentialsCheck,
      presenceScript:
          'command -v git >/dev/null 2>&1 || '
          'command -v curl >/dev/null 2>&1 || command -v ssh >/dev/null 2>&1',
      installScript: SetupScripts.essentialsInstall,
    ),
    SetupComponent(
      id: SetupComponentIds.python,
      title: 'Python',
      shortTitle: 'Python',
      dependsOn: const [SetupComponentIds.essentials],
      defaultOn: true,
      estimatedSeconds: 40,
      downloadBytes: 25 * _mb,
      checkScript: SetupScripts.pythonCheck,
      installScript: SetupScripts.pythonInstall,
      removeScript: SetupScripts.pythonRemove,
      presenceScript: SetupScripts.pythonPresence,
    ),
    SetupComponent(
      id: SetupComponentIds.node,
      title: 'Node.js',
      shortTitle: 'Node.js',
      why: l10n.phoneSetupNodeWhy,
      // curl comes with the essentials; Ubuntu Base has none.
      dependsOn: const [SetupComponentIds.essentials],
      required: true,
      estimatedSeconds: 20,
      downloadBytes: 58 * _mb,
      checkScript: host == SetupHostKind.termux
          ? SetupScripts.termuxNodeCheck
          : SetupScripts.nodeCheck,
      presenceScript:
          '[ -e /opt/node ] || [ -L /opt/node ] || '
          'command -v node >/dev/null 2>&1',
      installScript: SetupScripts.nodeInstall,
    ),
    SetupComponent(
      id: SetupComponentIds.openCode,
      title: 'OpenCode',
      shortTitle: 'OpenCode',
      why: l10n.phoneSetupOpenCodeWhy,
      dependsOn: const [SetupComponentIds.node],
      required: true,
      estimatedSeconds: 100,
      downloadBytes: 50 * _mb,
      checkScript: SetupScripts.openCodeCheck(runtime, version: version),
      presenceScript:
          'command -v opencode >/dev/null 2>&1 || '
          'command -v opencode2 >/dev/null 2>&1 || '
          '[ -e /usr/local/lib/node_modules/opencode-ai ] || '
          '[ -e /usr/local/lib/node_modules/opencode ]',
      installScript: SetupScripts.openCodeInstall(runtime, version: version),
    ),
    // Several agents sharing the work on one project. Opt-in and install
    // only: a team belongs to a project, which the first setup does not
    // have yet, so it is turned on later, per project (BuiltinTeam).
    SetupComponent(
      id: SetupComponentIds.aiTeam,
      title: l10n.aiteamComponentTitle,
      shortTitle: l10n.aiteamComponentTitle,
      // Its agents are OpenCode, and it needs Git and curl.
      dependsOn: const [
        SetupComponentIds.essentials,
        SetupComponentIds.openCode,
      ],
      // Mostly the three downloads; the ETA's pace scaling corrects it.
      estimatedSeconds: 150,
      downloadBytes: AiTeamPins.deviceDownloadBytes,
      checkScript: AiTeamScripts.checkScript,
      installScript: AiTeamScripts.installScript(
        downloading: l10n.aiteamComponentStageDownloading('{index}', '{total}'),
        preparing: l10n.aiteamComponentStagePreparing,
      ),
      removeScript: AiTeamScripts.removeScript,
      presenceScript:
          '[ -e /opt/aiteam ] || [ -L /opt/aiteam ] || '
          '[ -e /root/aiteam ] || [ -e /root/.gc ] || '
          '[ -e /var/cache/oc-setup/aiteam ] || '
          '[ -L /usr/local/bin/gc ] || [ -e /usr/local/bin/gc ] || '
          '[ -L /usr/local/bin/bd ] || [ -e /usr/local/bin/bd ] || '
          '[ -L /usr/local/bin/dolt ] || [ -e /usr/local/bin/dolt ]',
    ),
    SetupComponent(
      id: SetupComponentIds.start,
      title: l10n.phoneSetupStartTitle,
      shortTitle: l10n.phoneSetupStartTitle,
      why: l10n.phoneSetupStartWhy,
      dependsOn: const [SetupComponentIds.openCode],
      required: true,
      jobStep: true,
      estimatedSeconds: 15,
      checkScript: '',
      installScript: '',
    ),
    // Voice typing's speech model: installed by the app into its own
    // storage, not inside Linux (SetupComponent.app), so nothing here
    // depends on Linux. Last, after the start: a working agent does not
    // wait for it, and a failed download leaves OpenCode running. Its size
    // is the pack this phone would use, once the device has been asked.
    if (platformCapabilities.supportsVoice)
      SetupComponent(
        id: SetupComponentIds.voice,
        title: l10n.voiceComponentTitle,
        shortTitle: l10n.voiceComponentTitle,
        summary: l10n.voiceComponentSummary,
        // Mostly the download; the ETA's pace scaling corrects it.
        estimatedSeconds: 45,
        downloadBytes:
            VoiceSetupComponent.instance.lastOfferBytes ??
            voiceModelPack('base').downloadBytes,
        checkScript: '',
        installScript: '',
        app: VoiceSetupComponent.instance,
      ),
  ];
}

const _mb = 1000 * 1000;

abstract final class SetupComponentIds {
  static const linux = 'linux';
  static const essentials = 'essentials';
  static const python = 'python';
  static const node = 'node';
  static const openCode = 'opencode';
  static const aiTeam = 'aiteam';

  /// Voice typing's speech model, installed by the app itself.
  static const voice = 'voice';

  /// Not installed: starting the server and connecting to it, the last step
  /// of every job (see [SetupComponent.jobStep]).
  static const start = 'start';
}

/// The scripts behind [setupComponents]. Checks exit 0 only when the piece is
/// there and works, and print its version on their last line. Installs are
/// idempotent and report with the prelude's helpers (setup_scripts.dart).
abstract final class SetupScripts {
  /// Run through proot only once the Kotlin side says Ubuntu is installed;
  /// before that there is nothing to run it in.
  static const linuxCheck =
      '[ -s /etc/os-release ] && . /etc/os-release && echo "\${VERSION%% *}"';

  static const essentialsCheck = '''set -e
command -v curl >/dev/null
command -v git >/dev/null
command -v ssh >/dev/null
[ -s /etc/ssl/certs/ca-certificates.crt ]
git --version | cut -d ' ' -f 3
''';

  static const essentialsInstall = '''set -eu
oc_apt_install curl ca-certificates git openssh-client
oc_version "\$(git --version | cut -d ' ' -f 3)"
''';

  static const pythonCheck = '''set -e
python3 -c 'import ensurepip, venv' >/dev/null
python3 -m pip --version >/dev/null
python3 --version | cut -d ' ' -f 2
''';

  static const pythonInstall = '''set -eu
oc_apt_install python3 python3-venv python3-pip
oc_version "\$(python3 --version | cut -d ' ' -f 2)"
''';

  static const pythonRemove = '''set -eu
export DEBIAN_FRONTEND=noninteractive
apt-get remove -y python3-venv python3-pip
apt-get autoremove -y
''';

  // Python itself belongs to Ubuntu and survives pythonRemove. Inventory
  // describes the removable pip/venv component, including partial installs.
  static const pythonPresence = r'''set -eu
[ -r /var/lib/dpkg/status ] || exit 2
packages=$(dpkg-query -W -f='${Package} ${Status}\n') || exit 2
printf '%s\n' "$packages" | grep -Eq '^python3-(pip|venv) install ok installed$'
''';

  static String get _nodeVersion =>
      TermuxBridge.localAgentsPins['node_version']!;

  /// Only the pinned Node counts: an older one from Ubuntu's own packages or
  /// an earlier app would leave OpenCode on a Node it was not tested with.
  static String get nodeCheck =>
      '''set -e
[ "\$(node --version)" = '$_nodeVersion' ]
command -v npm >/dev/null
[ "\$(npm config get prefix)" = /usr/local ]
node --version | sed 's/^v//'
''';

  /// The Termux host: the pinned Node, or the Node an older build put in
  /// Termux's Ubuntu from its own packages, as long as it and npm run.
  static const termuxNodeCheck = '''set -e
node --version >/dev/null
command -v npm >/dev/null
node --version | sed 's/^v//'
''';

  /// Node from its official pinned download instead of Ubuntu's `npm`
  /// package, which drags in hundreds of packages (ten minutes under proot on
  /// the emulator). The download sits outside /tmp so a force-stopped run
  /// resumes it, and is deleted once unpacked. npm's global folder is
  /// /usr/local, so `opencode` lands on the PATH the server starts with.
  static String get nodeInstall {
    final pins = TermuxBridge.localAgentsPins;
    final plain = _nodeVersion.replaceFirst('v', '');
    return '''set -eu
case "\$(uname -m)" in
  aarch64|arm64) node_arch=arm64; node_sha=${pins['node_sha256_arm64']} ;;
  x86_64|amd64) node_arch=x64; node_sha=${pins['node_sha256_x64']} ;;
  *) echo "[oc] Unsupported CPU: \$(uname -m)" >&2; exit 64 ;;
esac
node_version=$_nodeVersion
node_file=/var/cache/oc-setup/node-\$node_version-linux-\$node_arch.tar.gz
oc_stage 'Downloading Node.js $plain'
oc_download "${pins['node_base_url']}/\$node_version/node-\$node_version-linux-\$node_arch.tar.gz" \\
  "\$node_file" "\$node_sha"
oc_stage 'Unpacking Node.js'
rm -rf /opt/node.new
mkdir -p /opt/node.new
tar -xzf "\$node_file" -C /opt/node.new --strip-components=1
rm -rf /opt/node
mv /opt/node.new /opt/node
for tool in node npm npx; do ln -sf /opt/node/bin/\$tool /usr/local/bin/\$tool; done
npm config set prefix /usr/local
rm -f "\$node_file"
oc_version "\$(node --version | sed 's/^v//')"
''';
  }

  /// Passes only for [runtime] at the requested version, so "Update
  /// OpenCode" (a new version) and "Switch to OpenCode 2" (the other runtime)
  /// both find something to do, while a plain continue skips it.
  static String openCodeCheck(TermuxRuntime runtime, {String? version}) {
    final selected = _version(runtime, version);
    return 'set -e\n'
        'installed=\$(${BuiltinLinux.versionScript(runtime)})\n'
        'installed=\${installed##* v}\n'
        '[ "\$installed" = \'$selected\' ]\n'
        'echo "\$installed"\n';
  }

  /// The shared text the Termux manager also runs
  /// ([openCodeUbuntuSetupScript]); it finds Node, Git and curl in place and
  /// goes straight to `npm install -g --foreground-scripts` (npm crashes
  /// under proot without it). OpenCode 1 then refreshes its model catalog;
  /// a failure there does not fail the install, the server fetches it later.
  static String openCodeInstall(TermuxRuntime runtime, {String? version}) {
    final selected = _version(runtime, version);
    final binary = runtime == TermuxRuntime.openCode2
        ? 'opencode2'
        : 'opencode';
    final refresh = runtime == TermuxRuntime.openCode1
        ? "oc_stage 'Getting the model list'\n"
              'opencode models --refresh >/dev/null 2>&1 || '
              "echo '[oc] The model list could not be refreshed now; "
              "OpenCode will fetch it later.'\n"
        : '';
    return 'set -eu\n'
        "oc_stage 'Installing OpenCode $selected'\n"
        "export OC_REQUESTED_VERSION='$selected'\n"
        "export OC_RUNTIME='${runtime.wireName}'\n"
        "bash -s <<'OC_PROOT_SETUP'\n"
        '${openCodeUbuntuSetupScript}OC_PROOT_SETUP\n'
        '$refresh'
        'installed=\$($binary --version)\n'
        'oc_version "\${installed##* v}"\n';
  }

  static final _versionPattern = RegExp(r'^[A-Za-z0-9._+-]+$');

  static String _version(TermuxRuntime runtime, String? version) {
    final selected = version ?? runtime.pinnedVersion;
    if (!_versionPattern.hasMatch(selected)) {
      throw ArgumentError.value(version, 'version', 'Invalid package version.');
    }
    return selected;
  }
}
