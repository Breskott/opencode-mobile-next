import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/team_directories.dart' show aiTeamHome;
import '../../state/profiles.dart'
    show
        OrchestrationConfig,
        OrchestrationHostKind,
        OrchestrationHostMode,
        OrchestrationProvider;
import '../builtin_linux.dart';
import '../setup/aiteam_scripts.dart';

/// AI Team inside the app: a Gas City team for the projects of the in-app
/// OpenCode, with no Termux.
///
/// The programs come from the `aiteam` setup component (install only). This
/// class does the rest, per project and on request, never as part of the
/// first setup (a team needs a project, which only exists after it):
/// - [turnOn] makes the team's store once, adds the project to it (with a
///   git `origin` on the phone when it has none, where the agents push their
///   work), starts the supervisor and waits until it answers;
/// - [start] / [stop] run the supervisor as the app's second long-running
///   service ([BuiltinLinux.startService]), beside the OpenCode server, so
///   it lives as long as the app does and not as long as some script;
/// - [config] is the AI Team plugin config the in-app profile gets, which
///   is what makes the Team card, the Inbox gates and the plugin screens
///   show this team.
///
/// Security: every app on an Android phone shares 127.0.0.1, so the
/// supervisor listens there only (explicitly, not by default), on its own
/// port so it never meets a Termux team on 8372, and accepts no other Host
/// header. It has no password of its own yet; see the report for what that
/// leaves open.
class BuiltinTeam {
  BuiltinTeam({
    BuiltinLinux? linux,
    Future<String?> Function(Uri url)? httpGet,
    this.pollInterval = const Duration(seconds: 2),
  }) : _linux = linux ?? BuiltinLinux(),
       _get = httpGet ?? _loopbackGet;

  final BuiltinLinux _linux;
  final Future<String?> Function(Uri url) _get;
  final Duration pollInterval;

  static const serviceName = 'aiteam';

  /// Not Termux's 8372: the two runtimes can both be on one phone.
  static const port = 8472;
  static const url = 'http://127.0.0.1:$port';
  static const city = 'phone';

  /// Also the rule that keeps the team's own sessions out of the person's
  /// lists (team_directories.dart), so the two cannot drift apart.
  static const home = aiTeamHome;
  static const cityDir = '$home/city';

  /// Bare repositories on the phone that stand in for `origin` when a
  /// project has none. Outside /root/projects, so they never show up as
  /// projects themselves.
  static const originsDir = '$home/origins';

  /// True for the plugin config [config] writes: the team inside this app.
  static bool isBuiltinConfig(OrchestrationConfig? config) =>
      config != null &&
      config.provider == OrchestrationProvider.gascity &&
      _samePort(config.url);

  static bool _samePort(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'http' &&
        uri.host == '127.0.0.1' &&
        uri.port == port;
  }

  /// The plugin config for the in-app profile: this phone, loopback, no
  /// front; the supervisor honours `X-GC-Request` on loopback, which gives
  /// the app its controls (create a task, give it to an agent).
  static OrchestrationConfig config({DateTime? now}) => OrchestrationConfig(
    provider: OrchestrationProvider.gascity,
    url: url,
    city: city,
    hostMode: OrchestrationHostMode.phone,
    hostKind: OrchestrationHostKind.phone,
    enabledAt: (now ?? DateTime.now()).toUtc(),
  );

  /// The team's name for the project at [path] (its folder name, made
  /// safe): Gas City calls it a rig.
  static String rigName(String path) {
    final trimmed = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    final base = trimmed.substring(trimmed.lastIndexOf('/') + 1);
    var name = base
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (name.length > 40) name = name.substring(0, 40);
    return name.isEmpty ? 'project' : name;
  }

  // ---- scripts (static, so tests can run and read them) -------------------

  /// The supervisor's settings: loopback only, its own port, and loopback
  /// Host headers only. Rewritten on every start, so a changed default in a
  /// later Gas City can never open it to the network.
  static const supervisorConfig =
      '[supervisor]\n'
      'bind = "127.0.0.1"\n'
      'port = $port\n'
      'allowed_hosts = ["127.0.0.1", "localhost"]\n';

  /// The lean team: one worker per project and the planner, the patrols and
  /// the witness off. The phone runs a handful of processes, not thirty
  /// (Android stops an app's child processes past 32).
  static const _cityPatches =
      '[[patches.agent]]\nname = "gastown.mayor"\nsuspended = true\n'
      '[[patches.agent]]\nname = "gastown.deacon"\nsuspended = true\n'
      '[[patches.agent]]\nname = "gastown.boot"\nsuspended = true\n';

  static String _rigPatches(String rig) =>
      '[[patches.agent]]\nname = "gastown.witness"\ndir = "$rig"\n'
      'suspended = true\n'
      '[[patches.agent]]\nname = "gastown.polecat"\ndir = "$rig"\n'
      'max_active_sessions = 1\n';

  /// The environment of every team script and of the supervisor (so of its
  /// agents too). The three programs send usage metrics by default; this
  /// app sends nothing about its users' work anywhere, so all of them are
  /// told not to.
  /// Gas City tuned for a phone. Android stops an app's child processes
  /// past 32 in all, oldest first, and the oldest is the OpenCode server
  /// (seen on the Android 14 emulator: a default team peaked at 40 and
  /// Android killed OpenCode and the team). The defaults poll every 30 s,
  /// run up to 8 store probes at once and give each session its own
  /// polling process; here:
  /// - patrols every minute, the frequent health orders every two;
  /// - one store probe and one session start at a time;
  /// - queued nudges delivered inside the supervisor, not by a process
  ///   per session;
  /// - the maintenance orders a single phone project does not need are
  ///   left out, among them the two that wake an AI "dog" (a whole
  ///   OpenCode session, and model usage) for digests and stale stores.
  static const phoneTuning =
      '[daemon]\n'
      'patrol_interval = "60s"\n'
      'max_restarts = 5\n'
      'restart_window = "1h"\n'
      'shutdown_timeout = "5s"\n'
      'nudge_dispatcher = "supervisor"\n'
      'probe_concurrency = 1\n'
      'max_wakes_per_tick = 1\n'
      '[orders]\n'
      'skip = ["digest-generate", "mol-dog-stale-db", "mol-dog-backup", '
      '"mol-dog-compactor", "mol-dog-phantom-db", "mol-dog-doctor", '
      '"spawn-storm-detect", "cross-rig-deps", "jsonl-export", '
      '"dolt-remotes-patrol", "prune-branches", "wisp-compact"]\n'
      '[[orders.overrides]]\nname = "dolt-health"\ninterval = "2m"\n'
      // Three minutes, not two: dolt-health and beads-health firing on the
      // same tick made the tallest spike (33 on the Android 15 emulator).
      '[[orders.overrides]]\nname = "beads-health"\ninterval = "3m"\n'
      '[[orders.overrides]]\nname = "gate-sweep"\ninterval = "1m"\n'
      '[[orders.overrides]]\nname = "order-tracking-sweep"\ninterval = "2m"\n'
      '[[orders.overrides]]\nname = "orphan-sweep"\ninterval = "10m"\n';

  static const _env =
      'export HOME=/root GC_BIN=/usr/local/bin/gc\n'
      'export DO_NOT_TRACK=1 GC_DISABLE_USAGE_METRICS=1 BD_DISABLE_METRICS=1 '
      'DOLT_DISABLE_EVENT_FLUSH=1\n'
      'command -v gc >/dev/null || '
      '{ echo "[oc] AI Team is not installed" >&2; exit 69; }\n';

  /// Makes the team's store once (`gc init`); does nothing when it exists.
  static String get cityScript =>
      'set -eu\n'
      '$_env'
      'mkdir -p $home /root/.gc\n'
      "cat > /root/.gc/supervisor.toml <<'OC_EOF'\n"
      '${supervisorConfig}OC_EOF\n'
      'if [ -f $home/city.ready ] && [ -f $cityDir/city.toml ]; then\n'
      '  echo city-ready\n'
      '  exit 0\n'
      'fi\n'
      "cat > $home/city.toml <<'OC_EOF'\n"
      '[workspace]\n'
      'provider = "opencode"\n'
      'install_agent_hooks = ["opencode"]\n'
      '[providers]\n'
      '[providers.opencode]\n'
      'base = "builtin:opencode"\n'
      'ready_delay_ms = 0\n'
      '[defaults]\n'
      '[defaults.rig]\n'
      '[defaults.rig.imports]\n'
      '[defaults.rig.imports.gastown]\n'
      'source = "${AiTeamPins.packSource}"\n'
      'version = "${AiTeamPins.packVersion}"\n'
      '$phoneTuning'
      'OC_EOF\n'
      // Under proot on a busy phone the store's first start can outlast
      // Gas City's own wait and leave it half made ("dirty tables"); a
      // clean second try works. The leftovers of a try (its database
      // server) are stopped first; the bracket keeps the pattern from
      // matching this script's own command line.
      'cd $home\n'
      'try=1\n'
      'while :; do\n'
      "  pkill -f 'dolt[ ]sql-server --config $cityDir' 2>/dev/null || true\n"
      "  pkill -f '__gc[-]managed-dolt' 2>/dev/null || true\n"
      '  rm -rf $cityDir $home/city.ready\n'
      '  if gc init --file ./city.toml --name $city --no-start city && '
      '[ -d $cityDir/.gc ]; then break; fi\n'
      '  [ "\$try" -lt 3 ] || '
      '{ echo "[oc] The team store could not be made" >&2; exit 70; }\n'
      '  try=\$((try + 1))\n'
      '  echo "[oc] Making the team store again (try \$try of 3)"\n'
      '  sleep 3\n'
      'done\n'
      'touch $home/city.ready\n'
      'echo city-ready\n';

  /// Adds the project at [path] to the team as [rig]; does nothing for one
  /// already there.
  ///
  /// The agents work on branches they push to `origin`; a project without
  /// one gets a bare repository on the phone, and one with no commit yet
  /// gets an empty first commit, since a branch needs something to start
  /// from. A project that has an origin keeps it. A bead store left in the
  /// project by an earlier team is moved aside, never deleted.
  static String rigScript(String path, String rig) {
    if (!path.startsWith('/') || path.contains('\n')) {
      throw ArgumentError.value(path, 'path', 'Must be an absolute path.');
    }
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(rig)) {
      throw ArgumentError.value(rig, 'rig', 'Letters, digits, - and _ only.');
    }
    return 'set -eu\n'
        '$_env'
        'project=${_quote(path)}\n'
        'rig=$rig\n'
        '[ -d "\$project/.git" ] || '
        '{ echo "[oc] \$project is not a git project" >&2; exit 65; }\n'
        '[ -f $cityDir/city.toml ] || '
        '{ echo "[oc] The team store is missing" >&2; exit 70; }\n'
        'cd "\$project"\n'
        'git rev-parse -q --verify HEAD >/dev/null || '
        "git commit -q --allow-empty -m 'Start'\n"
        'if ! git remote get-url origin >/dev/null 2>&1; then\n'
        '  origin=$originsDir/\$rig.git\n'
        '  mkdir -p $originsDir\n'
        '  [ -d "\$origin" ] || git init -q --bare "\$origin"\n'
        '  git remote add origin "\$origin"\n'
        '  git push -q origin HEAD\n'
        'fi\n'
        'cd $cityDir\n'
        'if ! grep -qx "name = \\"\$rig\\"" city.toml; then\n'
        '  if [ -e "\$project/.beads" ]; then\n'
        '    mv "\$project/.beads" "\$project/.beads.before-aiteam-\$(date +%s)"\n'
        '  fi\n'
        // As with the store itself, a slow first start can leave the
        // project's store half made; each retry starts clean, under a new
        // prefix (a new database), since the half-made one cannot be
        // initialised over.
        '  try=1\n'
        '  prefix=\n'
        '  until gc rig add "\$project" --name "\$rig" \$prefix; do\n'
        '    [ "\$try" -lt 3 ] || '
        '{ echo "[oc] The project could not be added to the team" >&2; exit 70; }\n'
        '    try=\$((try + 1))\n'
        '    echo "[oc] Adding the project again (try \$try of 3)"\n'
        '    gc rig remove "\$rig" >/dev/null 2>&1 || true\n'
        '    rm -rf "\$project/.beads"\n'
        '    prefix="--prefix r\$try\$(printf %s "\$rig" | tr -cd a-z | cut -c1-4)"\n'
        '    sleep 3\n'
        '  done\n'
        'fi\n'
        // `gc rig add` commits the project's new bead settings; an origin
        // on the phone gets that commit too, or the agents start from a
        // master that lacks it and spend their first minutes working out
        // why (seen on the emulator). Once the team has merged work, the
        // origin is ahead of the project and the push is refused, which is
        // fine.
        'case "\$(git -C "\$project" remote get-url origin)" in\n'
        '  $originsDir/*) git -C "\$project" push -q origin HEAD || true ;;\n'
        'esac\n'
        'gc import install\n'
        'grep -q \'name = "gastown.mayor"\' city.toml || '
        "printf '\\n%s' ${_quote(_cityPatches)} >> city.toml\n"
        'grep -qx "dir = \\"\$rig\\"" city.toml || '
        "printf '\\n%s' ${_quote(_rigPatches(rig))} >> city.toml\n"
        'echo rig-ready\n';
  }

  /// The supervisor, as the long-running service. `exec`, so stopping the
  /// service stops the supervisor itself, and with it the store and the
  /// agents it started.
  static String get serviceScript =>
      'set -eu\n'
      '$_env'
      // The agents' own `opencode` first (AiTeamScripts.agentWrapperScript).
      'export PATH=${AiTeamScripts.agentBin}:\$PATH\n'
      'cd $cityDir\n'
      'mkdir -p /root/.gc\n'
      "cat > /root/.gc/supervisor.toml <<'OC_EOF'\n"
      '${supervisorConfig}OC_EOF\n'
      'exec gc supervisor run\n';

  /// Registers the team with the running supervisor; a team registered
  /// already is fine. `gc register` records the team at once and then waits
  /// for it to come up, which under proot can take minutes; that wait is
  /// cut after a minute and left to the health check that follows (as the
  /// Termux runtime does).
  static String get registerScript =>
      'set -u\n'
      '$_env'
      'cd $cityDir\n'
      'rc=0\n'
      'out=\$(timeout -k 5 60 gc register $cityDir --name $city --yes 2>&1) '
      '|| rc=\$?\n'
      'case \$rc in 0|124|137) echo registered; exit 0 ;; esac\n'
      'case \$out in *already*|*exists*) echo registered; exit 0 ;; esac\n'
      'printf \'%s\\n\' "\$out" >&2\n'
      'exit 1\n';

  /// What is there: `installed`, `city` and one `rig <name>` per project.
  static String get statusScript =>
      // Installed means what the setup component's own check says (the
      // pinned versions), so an outdated install reads as not installed and
      // Add tools brings it up to date.
      // A shell of its own: `set -e` is ignored inside a subshell on the left
      // of &&, which would make every check pass.
      "if sh -s >/dev/null 2>&1 <<'OC_CHECK'\n"
      '${AiTeamScripts.checkScript}'
      'OC_CHECK\n'
      'then echo installed; fi\n'
      '[ -f $home/city.ready ] && [ -f $cityDir/city.toml ] && echo city\n'
      '[ -f $cityDir/city.toml ] && '
      "awk '/^\\[\\[rigs\\]\\]/ { r = 1; next } "
      "r && /^name = / { gsub(/\"/, \"\", \$3); print \"rig \" \$3; r = 0 }' "
      '$cityDir/city.toml\n'
      'exit 0\n';

  static BuiltinTeamState parseStatus(String output, {bool running = false}) {
    final lines = output.split('\n').map((line) => line.trim());
    return BuiltinTeamState(
      installed: lines.contains('installed'),
      hasCity: lines.contains('city'),
      rigs: [
        for (final line in lines)
          if (line.startsWith('rig ')) line.substring(4).trim(),
      ],
      running: running,
    );
  }

  // ---- operations ---------------------------------------------------------

  Future<BuiltinTeamState> status() async {
    final linux = await _linux.status();
    if (!linux.installed) return const BuiltinTeamState();
    final result = await _linux.run(
      statusScript,
      timeout: const Duration(seconds: 30),
    );
    return parseStatus(
      result.output,
      running: linux.serviceRunning(serviceName),
    );
  }

  /// Turns the team on for the project at [path]: store, project, supervisor,
  /// health, in that order, each safe to repeat. [onStage] hears where it
  /// is. Throws [BuiltinTeamException] with the stage that failed.
  Future<void> turnOn(
    String path, {
    required String notice,
    void Function(BuiltinTeamStage stage)? onStage,
    Duration healthTimeout = const Duration(minutes: 6),
  }) async {
    onStage?.call(BuiltinTeamStage.preparing);
    await _script(
      BuiltinTeamStage.preparing,
      cityScript,
      const Duration(minutes: 5),
    );
    onStage?.call(BuiltinTeamStage.addingProject);
    await _script(
      BuiltinTeamStage.addingProject,
      rigScript(path, rigName(path)),
      const Duration(minutes: 6),
    );
    await start(notice: notice, onStage: onStage, healthTimeout: healthTimeout);
  }

  /// Starts the supervisor unless it runs, registers the team and waits for
  /// it to answer. A supervisor that runs but does not answer is restarted
  /// once.
  Future<void> start({
    required String notice,
    void Function(BuiltinTeamStage stage)? onStage,
    Duration healthTimeout = const Duration(minutes: 6),
  }) async {
    onStage?.call(BuiltinTeamStage.starting);
    final linux = await _linux.status();
    if (!linux.serviceRunning(serviceName) || !await supervisorAnswers()) {
      await _linux.startService(
        serviceName,
        serviceScript,
        port: port,
        notice: notice,
      );
    }
    await _waitFor(
      BuiltinTeamStage.starting,
      supervisorAnswers,
      const Duration(seconds: 90),
    );
    await _script(
      BuiltinTeamStage.starting,
      registerScript,
      const Duration(minutes: 2),
    );
    onStage?.call(BuiltinTeamStage.waiting);
    await _waitFor(BuiltinTeamStage.waiting, cityAnswers, healthTimeout);
  }

  /// Starts the supervisor when it is not running, without waiting: for the
  /// app coming back after Android stopped it. The team answers a little
  /// later, and the Team card shows it as reconnecting meanwhile.
  Future<void> ensureRunning({required String notice}) async {
    try {
      final linux = await _linux.status();
      if (!linux.installed || linux.serviceRunning(serviceName)) return;
      await _linux.startService(
        serviceName,
        serviceScript,
        port: port,
        notice: notice,
      );
    } on BuiltinLinuxException {
      // The next open of the team says what is wrong.
    }
  }

  Future<void> stop() => _linux.stopService(serviceName);

  Future<bool> supervisorAnswers() => _answersOk(Uri.parse('$url/health'));

  Future<bool> cityAnswers() =>
      _answersOk(Uri.parse('$url/v0/city/$city/health'));

  Future<bool> _answersOk(Uri uri) async {
    final body = await _get(uri);
    if (body == null) return false;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map && decoded['status'] == 'ok';
    } on FormatException {
      return false;
    }
  }

  Future<void> _waitFor(
    BuiltinTeamStage stage,
    Future<bool> Function() ok,
    Duration timeout,
  ) async {
    final deadline = DateTime.now().add(timeout);
    while (!await ok()) {
      final running = (await _linux.status()).serviceRunning(serviceName);
      if (!running) {
        throw BuiltinTeamException(stage, await _logTail(), exited: true);
      }
      if (DateTime.now().isAfter(deadline)) {
        throw BuiltinTeamException(stage, await _logTail(), timedOut: true);
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  Future<String> _logTail() async {
    try {
      final log = await _linux.serviceLog(serviceName, tailBytes: 2048);
      return log.trim();
    } on BuiltinLinuxException {
      return '';
    }
  }

  Future<void> _script(
    BuiltinTeamStage stage,
    String script,
    Duration timeout,
  ) async {
    final BuiltinLinuxRunResult result;
    try {
      result = await _linux.run(script, timeout: timeout);
    } on BuiltinLinuxException catch (error) {
      throw BuiltinTeamException(stage, error.message);
    }
    if (!result.ok) {
      final output = result.output.trim();
      throw BuiltinTeamException(
        stage,
        output.isEmpty ? 'exit ${result.exitCode}' : _tail(output),
      );
    }
  }

  static String _tail(String text, {int lines = 12}) {
    final all = text.split('\n');
    return all.skip(all.length > lines ? all.length - lines : 0).join('\n');
  }

  static String _quote(String value) => "'${value.replaceAll("'", "'\"'\"'")}'";

  /// A GET on the phone's loopback with a short timeout; null when nothing
  /// answers.
  static Future<String?> _loopbackGet(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200 ? body : null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

/// Where [BuiltinTeam.turnOn] is.
enum BuiltinTeamStage { preparing, addingProject, starting, waiting }

/// What [BuiltinTeam.status] found.
class BuiltinTeamState {
  const BuiltinTeamState({
    this.installed = false,
    this.hasCity = false,
    this.rigs = const [],
    this.running = false,
  });

  /// The programs are there (the setup component ran).
  final bool installed;

  /// The team's store exists.
  final bool hasCity;

  /// The projects the team works on, by team name ([BuiltinTeam.rigName]).
  final List<String> rigs;

  /// The supervisor runs as the app's service.
  final bool running;

  bool hasProject(String path) => rigs.contains(BuiltinTeam.rigName(path));
}

class BuiltinTeamException implements Exception {
  const BuiltinTeamException(
    this.stage,
    this.detail, {
    this.exited = false,
    this.timedOut = false,
  });

  final BuiltinTeamStage stage;

  /// The technical reason (script output or the supervisor's log tail).
  final String detail;

  /// The supervisor stopped on its own.
  final bool exited;

  /// It did not answer in time.
  final bool timedOut;

  @override
  String toString() => 'AI Team (${stage.name}): $detail';
}
