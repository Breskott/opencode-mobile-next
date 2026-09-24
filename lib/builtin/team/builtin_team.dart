import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  static const home = '/root/aiteam';
  static const cityDir = '$home/city';

  /// Bare repositories on the phone that stand in for `origin` when a
  /// project has none. Outside /root/projects, so they never show up as
  /// projects themselves.
  static const originsDir = '$home/origins';

  /// What the phone-side origins' hook did with each merge, one line per
  /// push to a project's branch (see [originHook]); the Plugins section
  /// reads the newest line per project.
  static const pullLog = '$home/pull.log';

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
        //
        // An origin made here also gets the hook that brings the team's
        // merged work into the project folder (rewritten on every run, so
        // a project added by an older version gets it too), and the work
        // merged before it existed is brought in once now.
        'case "\$(git -C "\$project" remote get-url origin)" in\n'
        '  $originsDir/*) git -C "\$project" push -q origin HEAD || true ;;\n'
        'esac\n'
        '$_hookFunctions'
        'oc_install_hook "\$project" "\$rig" || true\n'
        'gc import install\n'
        'grep -q \'name = "gastown.mayor"\' city.toml || '
        "printf '\\n%s' ${_quote(_cityPatches)} >> city.toml\n"
        'grep -qx "dir = \\"\$rig\\"" city.toml || '
        "printf '\\n%s' ${_quote(_rigPatches(rig))} >> city.toml\n"
        'echo rig-ready\n';
  }

  /// The `post-receive` hook of a phone-side origin (only the ones
  /// [rigScript] makes): the refinery merges into the origin, and this
  /// brings that merge into the project folder the person's own
  /// conversations work in, so nobody has to `git pull`.
  ///
  /// It only ever fast-forwards the branch the project has checked out,
  /// and leaves the project alone when that is not safe:
  /// - `dirty`: the project has changes of its own to tracked files (the
  ///   team's own bookkeeping, `.beads/` and the lines Gas City adds to
  ///   `.gitignore`, does not count; git itself still refuses to overwrite
  ///   any of it);
  /// - `diverged`: the project has commits the origin does not;
  /// - `skipped`: the project is not on a branch;
  /// - `failed`: git refused (the reason is logged).
  /// Otherwise `brought-in`, or `up-to-date`. Every outcome is one line in
  /// [pullLog]: time, project, outcome, commit, detail (tab-separated).
  ///
  /// It never fails the push: the refs are in already when it runs, and it
  /// always exits 0. The project and its team name come from the origin's
  /// own settings (`oc-mobile.project`, `oc-mobile.rig`, written with the
  /// hook) or from `OC_PROJECT` / `OC_RIG`. Run with `--now` (the app's
  /// "Bring the team's work in", [bringInScript]) it acts without a push
  /// and prints the line.
  static const originHook =
      '#!/bin/sh\n'
      '# Written by OpenCode Mobile (AI Team) on every team start: brings\n'
      '# the work merged here into the project folder.\n'
      'log=$pullLog\n'
      r'''project=${OC_PROJECT:-$(git config --get oc-mobile.project 2>/dev/null)}
rig=${OC_RIG:-$(git config --get oc-mobile.rig 2>/dev/null)}
[ -n "$project" ] && [ -n "$rig" ] || exit 0
now=
[ "${1:-}" = --now ] && now=1
refs=
[ -n "$now" ] || refs=$(cat)
# A hook runs with the origin's GIT_DIR and friends set; the project is
# another repository.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_QUARANTINE_PATH \
  GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_PREFIX \
  GIT_COMMON_DIR GIT_NAMESPACE 2>/dev/null || true
oc_log() {
  line=$(printf '%s\t%s\t%s\t%s\t%s' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$rig" "$1" "$2" "$(printf '%s' "$3" | tr '\t\n' '  ' | cut -c1-200)")
  mkdir -p "$(dirname "$log")"
  printf '%s\n' "$line" >> "$log"
  if [ "$(wc -l < "$log")" -gt 400 ]; then
    tail -n 200 "$log" > "$log.tmp" && mv "$log.tmp" "$log"
  fi
  [ -z "$now" ] || printf '%s\n' "$line"
}
g() { git -C "$project" "$@"; }
if ! branch=$(g symbolic-ref -q --short HEAD 2>/dev/null); then
  [ -n "$now" ] && oc_log skipped - "the project is not on a branch"
  exit 0
fi
if [ -z "$now" ]; then
  printf '%s\n' "$refs" | grep -q " refs/heads/$branch\$" || exit 0
fi
if ! out=$(g fetch -q origin "+refs/heads/$branch:refs/remotes/origin/$branch" 2>&1); then
  oc_log failed - "could not read the team's copy: $out"
  exit 0
fi
new=$(g rev-parse -q --verify "refs/remotes/origin/$branch^{commit}") || exit 0
short=$(g rev-parse --short "$new")
subject=$(g log -1 --format=%s "$new")
if g merge-base --is-ancestor "$new" HEAD; then
  oc_log up-to-date "$short" "$subject"
  exit 0
fi
if ! g merge-base --is-ancestor HEAD "$new"; then
  oc_log diverged "$short" "$branch has commits the team's copy does not"
  exit 0
fi
changes=$(g status --porcelain --untracked-files=no -- . ':(exclude).beads' ':(exclude).gitignore' | cut -c4- | head -n 5 | tr '\n' ' ')
if [ -n "$changes" ]; then
  oc_log dirty "$short" "$changes"
  exit 0
fi
if out=$(g merge -q --ff-only "$new" 2>&1); then
  oc_log brought-in "$short" "$subject"
else
  oc_log failed "$short" "$out"
fi
exit 0
''';

  /// `oc_install_hook PROJECT RIG`: gives the project's origin [originHook]
  /// when that origin is one of this phone's ([originsDir]; an origin of
  /// the project's own is never touched), then brings in once whatever the
  /// team merged before the hook was there. Idempotent.
  static const _hookFunctions =
      'oc_install_hook() {\n'
      '  oc_origin=\$(git -C "\$1" remote get-url origin 2>/dev/null) '
      '|| return 0\n'
      '  case "\$oc_origin" in $originsDir/*) ;; *) return 0 ;; esac\n'
      '  git -C "\$oc_origin" config oc-mobile.project "\$1" &&\n'
      '  git -C "\$oc_origin" config oc-mobile.rig "\$2" &&\n'
      '  mkdir -p "\$oc_origin/hooks" &&\n'
      "  cat > \"\$oc_origin/hooks/post-receive\" <<'OC_HOOK' &&\n"
      '${originHook}OC_HOOK\n'
      '  chmod 755 "\$oc_origin/hooks/post-receive" || return 1\n'
      '  OC_PROJECT="\$1" OC_RIG="\$2" '
      'sh "\$oc_origin/hooks/post-receive" --now </dev/null >/dev/null 2>&1 '
      '|| true\n'
      '}\n';

  /// Gives every project of the team its origin hook (a team made by an
  /// older version has none); part of every start, from the projects Gas
  /// City lists in `.gc/site.toml`.
  static const hooksScript =
      '$_hookFunctions'
      'if [ -f $cityDir/.gc/site.toml ]; then\n'
      "  awk '/^name = / { n = \$0; sub(/^name = \"/, \"\", n); "
      'sub(/"\$/, "", n) } '
      '/^path = / { p = \$0; sub(/^path = "/, "", p); sub(/"\$/, "", p); '
      "if (n != \"\") print n \"\\t\" p; n = \"\" }' "
      '$cityDir/.gc/site.toml |\n'
      "  while IFS='\t' read -r oc_rig oc_project; do\n"
      '    oc_install_hook "\$oc_project" "\$oc_rig" || true\n'
      '  done\n'
      'fi\n';

  /// Brings the team's merged work into the project at [path] now, as the
  /// origin's hook does after every merge; prints the outcome line.
  static String bringInScript(String path, String rig) {
    if (!path.startsWith('/') || path.contains('\n')) {
      throw ArgumentError.value(path, 'path', 'Must be an absolute path.');
    }
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(rig)) {
      throw ArgumentError.value(rig, 'rig', 'Letters, digits, - and _ only.');
    }
    return 'OC_PROJECT=${_quote(path)} OC_RIG=$rig\n'
        'export OC_PROJECT OC_RIG\n'
        'set -- --now\n'
        '$originHook';
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
      '$hooksScript'
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
      // The newest bring-in outcome per project (originHook).
      '[ -f $pullLog ] && '
      "awk -F '\\t' 'NF >= 3 { last[\$2] = \$0 } "
      "END { for (r in last) print \"pull\\t\" last[r] }' $pullLog\n"
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
      bringIns: {
        for (final pull in [
          for (final line in lines)
            if (line.startsWith('pull\t'))
              ?BuiltinTeamBringIn.parse(line.substring(5)),
        ])
          pull.rig: pull,
      },
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

  /// Brings the team's merged work into the project at [path] now, on the
  /// same terms as the origin's hook ([originHook]); null when the script
  /// said nothing (the project has no phone-side origin).
  Future<BuiltinTeamBringIn?> bringIn(String path) async {
    final result = await _linux.run(
      bringInScript(path, rigName(path)),
      timeout: const Duration(minutes: 2),
    );
    BuiltinTeamBringIn? last;
    for (final line in result.output.split('\n')) {
      last = BuiltinTeamBringIn.parse(line.trim()) ?? last;
    }
    return last;
  }

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
    this.bringIns = const {},
    this.running = false,
  });

  /// The programs are there (the setup component ran).
  final bool installed;

  /// The team's store exists.
  final bool hasCity;

  /// The projects the team works on, by team name ([BuiltinTeam.rigName]).
  final List<String> rigs;

  /// The newest bring-in outcome per project, by team name.
  final Map<String, BuiltinTeamBringIn> bringIns;

  /// The supervisor runs as the app's service.
  final bool running;

  bool hasProject(String path) => rigs.contains(BuiltinTeam.rigName(path));

  BuiltinTeamBringIn? bringInFor(String path) =>
      bringIns[BuiltinTeam.rigName(path)];
}

/// What [BuiltinTeam.originHook] did with the team's merged work.
enum BuiltinTeamBringInOutcome {
  broughtIn('brought-in'),
  upToDate('up-to-date'),
  dirty('dirty'),
  diverged('diverged'),
  skipped('skipped'),
  failed('failed');

  const BuiltinTeamBringInOutcome(this.word);

  /// The word in the log.
  final String word;
}

/// One line of [BuiltinTeam.pullLog].
class BuiltinTeamBringIn {
  const BuiltinTeamBringIn({
    required this.time,
    required this.rig,
    required this.outcome,
    this.commit,
    this.detail = '',
  });

  final DateTime? time;
  final String rig;
  final BuiltinTeamBringInOutcome outcome;

  /// The short hash of the team's newest commit, when known.
  final String? commit;

  /// The commit's subject, the changes that kept it out, or git's reason.
  final String detail;

  /// The project was left behind the team's work.
  bool get leftBehind => switch (outcome) {
    BuiltinTeamBringInOutcome.dirty ||
    BuiltinTeamBringInOutcome.diverged ||
    BuiltinTeamBringInOutcome.failed => true,
    _ => false,
  };

  /// A log line (time, project, outcome, commit, detail; tab-separated), or
  /// null for anything else.
  static BuiltinTeamBringIn? parse(String line) {
    final parts = line.split('\t');
    if (parts.length < 3) return null;
    final outcome = BuiltinTeamBringInOutcome.values
        .where((value) => value.word == parts[2].trim())
        .firstOrNull;
    if (outcome == null) return null;
    final commit = parts.length > 3 ? parts[3].trim() : '';
    return BuiltinTeamBringIn(
      time: DateTime.tryParse(parts[0].trim()),
      rig: parts[1].trim(),
      outcome: outcome,
      commit: commit.isEmpty || commit == '-' ? null : commit,
      detail: parts.length > 4 ? parts.sublist(4).join(' ').trim() : '',
    );
  }
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
