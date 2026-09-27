/// The AI Team page while the team is on (programme P3.4, "the team page
/// is one page"; [TeamPage] shows the off state in its place): what the
/// team does now, what needs the person, its tasks, and the team itself,
/// in the person's words.
///
/// Top to bottom, in one scroll view:
///
/// 1. The top bar ([KitTopBar]): "AI Team" with where the team runs as its
///    subtitle ("On this phone", "On pop-os", plus "· Paused" when the
///    person paused it, "· Cooling down" when the heat guard paused it,
///    "· Stopped" when Android stopped it, "· Not answering"). The board is
///    its action; Search joins it only when there are more than eight
///    tasks, and opens the pinned [KitSearchField] with its one filter
///    menu. Its menu: Refresh, Change address (a team found at an
///    address), the phone's Termux team's own controls (keep it running,
///    stop, remove; reachable in every state) and Turn off: the
///    team-plugin-sheet's switches, merged here. Turned off, [TeamPage]
///    shows the off state on the same page.
/// 2. One line for the whole team when something is in flight: the heat
///    guard's pause (why, and that it carries on by itself — never Resume),
///    else the team's Now ([teamNowLine]). Android stopping the phone's
///    Termux team is its own line above it, with Start the team again, and
///    then the page says nothing that contradicts it.
/// 3. What needs the person, only when something does, with no heading of
///    its own: one question as a request block with its answers. The one
///    question's block is also its task's row: it names the task, carries
///    its step count and opens its conversation, so the task is not listed
///    again below. Several questions are no section of their own (owner
///    rule 2026-09-27): each one's task row becomes the question ("Needs
///    you · Keep drafts in SQLite? · 2 min ago") and opens the Gate sheet
///    of `gate_sheet.dart`; a question with no task listed is a row of its
///    own at the top of the same list.
/// 4. **Tasks**: ONE panel of rows with no heading, ordered by urgency
///    (owner rule 2026-09-27): what needs the person, then what runs, then
///    what waits, then what finished (three shown, the rest behind one
///    row), never split into state sections. A row is the task's title,
///    one supporting line ("Working · 3 of 5 steps done", "Done · merged 5h
///    ago") and one leading mark ([KitTaskMark]) that carries the state; it
///    opens the task's conversation ([TeamConversation.open]), the same
///    page every other door to a task opens.
/// 5. The team itself, one panel: the **agents** row ("3 agents · 1
///    working", opening [TeamAgentsScreen]); **how it runs** (the host's
///    speed in one line, opening Technical details); and **what it spent
///    today** when the host reports it (an estimate for the whole team,
///    never a task's cost; unknown is never zero).
///
/// **Give the team a task** (TEAM-204, only with `controlMessage`) is the
/// screen's one primary button, pinned below the list; it opens
/// [StartRunSheet] through [TeamConversation.start], so a task given here
/// lands in its conversation like one given from Solo · Team. A task the
/// host made but its workers refused comes back as a notice at the top of
/// the list. Old data shows the one status line with its age (the rows
/// stay at full strength, LOOK-14); pull to refresh calls
/// [OrchestrationController.refresh].
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;

import '../../../builtin/team/builtin_team.dart' show BuiltinTeam;
import '../../../builtin/thermal_guard.dart';
import '../../../builtin/thermal_guard_teams.dart'
    show thermalGuardSlotProvider;
import '../../../domain/orchestration_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/connection.dart';
import '../../../state/orchestration.dart';
import '../../../state/team_overview.dart';
import '../../../termux/team_runtime.dart';
import '../../app_theme.dart';
import '../../kit/kit.dart';
import '../../kit/scenes/team_scenes.dart';
import '../../widgets/relative_time.dart';
import '../../widgets/team_now.dart';
import '../../widgets/team_discovery_card.dart'
    show teamHostDisclaimer, teamHostKindFor;
import '../../widgets/team_host_form.dart'
    show TeamHostProbe, showTeamTurnOffSheet;
import '../../widgets/team_phone_onboarding.dart' show TeamPhoneKilledNotice;
import '../../widgets/team_phone_section.dart' show TeamPhoneSection;
import '../../widgets/team_receipt.dart';
import '../../widgets/team_switch.dart';
import '../../widgets/team_technical_details.dart';
import '../../widgets/team_vocabulary.dart';
import '../settings/plugins_screen.dart' show teamPhoneProfile;
import '../team_conversation/team_conversation.dart' show TeamConversation;
import 'gate_sheet.dart';
import 'start_run_sheet.dart';
import 'team_board_screen.dart';
import 'team_agents_screen.dart';
import 'team_needs_you.dart';
import 'team_states.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// The task search's filters, offered with the search field only.
enum TeamRunFilter { active, blocked, completed, all }

/// Search and filters appear only for a longer list than this: a short
/// list needs no controls to find a task in it.
const teamHomeSearchAfter = 8;

/// Finished tasks shown before "Show N more".
const teamHomeDoneShown = 3;

class TeamHomeScreen extends StatefulWidget {
  const TeamHomeScreen({
    super.key,
    required this.controller,
    this.onOpenRun,
    this.onOpenAgent,
    this.now,
    this.connection,
    this.thermalGuard,
    this.probe,
    this.teamRuntime,
    this.onTeamChanged,
  });

  final OrchestrationController controller;

  /// The connection whose server this team belongs to: Change address and
  /// Turn off write its profile. The app's own when null (none in a test
  /// without one: then the page offers neither).
  final ConnectionController? connection;

  /// The heat guard's slot ([thermalGuardSlotProvider] when null): a pause
  /// for heat reads as one, never as the person's pause.
  final ValueListenable<ThermalGuard?>? thermalGuard;

  /// The Gas City probe of the address form; tests pass a fake.
  final TeamHostProbe? probe;

  /// The Termux team runtime; tests pass a fake.
  final TermuxTeamRuntime? teamRuntime;

  /// After Change address or Turn off replaced this team. [TeamPage]
  /// follows the connection by itself; opened on its own (over a task's
  /// conversation), the page goes back to the start, since the team it
  /// showed is gone.
  final VoidCallback? onTeamChanged;

  /// Opens a task; its conversation ([TeamConversation.open]) when null.
  final ValueChanged<OrchestrationRun>? onOpenRun;

  /// Opens an agent's detail from the agents list; pushes [AgentScreen]
  /// when null.
  final ValueChanged<OrchestrationAgent>? onOpenAgent;

  /// Clock for relative ages and the "today" group; tests pin it.
  final DateTime Function()? now;

  @override
  State<TeamHomeScreen> createState() => _TeamHomeScreenState();
}

class _TeamHomeScreenState extends State<TeamHomeScreen> {
  TeamRunFilter _filter = TeamRunFilter.all;
  final _search = TextEditingController();
  String _query = '';

  /// The search field and filters, behind the top bar's search action.
  bool _searchOpen = false;

  /// The finished tasks past the first three.
  bool _doneExpanded = false;

  /// "Show team upkeep": off on every open, never persisted.
  bool _upkeepShown = false;
  bool _refreshing = false;

  /// A task the host made but its workers refused, said once at the top
  /// of the list until dismissed.
  MutationRecord? _refusal;

  /// Android stopped the phone's Termux team ([TeamPhoneKilledNotice]).
  bool _killed = false;

  /// Keeps the notice (and what it read) as the page moves between its
  /// states.
  final _killedKey = GlobalKey();

  /// Turn off could not stop the team on this phone.
  bool _offFailed = false;
  bool _switching = false;

  ConnectionController? _scopeConnection;
  ValueListenable<ThermalGuard?>? _scopeHeat;

  DateTime get _now => (widget.now ?? DateTime.now)();

  ConnectionController? get _connection =>
      widget.connection ?? _scopeConnection;

  ValueListenable<ThermalGuard?>? get _heat =>
      widget.thermalGuard ?? _scopeHeat;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The app's own connection and heat guard, when this page runs inside
    // the app's provider scope (a test without one passes its own or
    // none).
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      if (widget.connection == null) {
        try {
          _scopeConnection = container.read(connProvider);
        } catch (_) {
          _scopeConnection = null;
        }
      }
      if (widget.thermalGuard == null) {
        _scopeHeat = container.read(thermalGuardSlotProvider);
      }
    } on StateError {
      _scopeConnection = null;
      _scopeHeat = null;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Listenable?> _watched = const [];
  Listenable? _merged;

  /// The team, the heat guard (its slot and the guard in it) and the
  /// connection, merged once per set: a new merge on every build would
  /// subscribe again to a team that is being turned off.
  Listenable _watching() {
    final heat = _heat;
    final parts = [widget.controller, heat, heat?.value, _connection];
    var same = _merged != null && parts.length == _watched.length;
    for (var i = 0; same && i < parts.length; i++) {
      same = identical(parts[i], _watched[i]);
    }
    if (!same) {
      _watched = parts;
      _merged = Listenable.merge(parts);
    }
    return _merged!;
  }

  /// The connection's profile when it is this team's, else null.
  ConnectionController? get _owner {
    final connection = _connection;
    final profile = connection?.profile;
    if (connection == null ||
        profile == null ||
        profile.id != widget.controller.profileId ||
        profile.orchestration == null) {
      return null;
    }
    return connection;
  }

  /// The heat guard's hold on this team, when it matches this profile, its
  /// phone host and city ([teamOverview]).
  ThermalTeamHold? _heatHold() {
    final hold = _heat?.value?.holds[widget.controller.profileId];
    if (hold == null) return null;
    final controller = widget.controller;
    return teamOverview(
      profileId: controller.profileId,
      host: controller.host,
      agents: null,
      isStale: true,
      heatHold: hold,
    ).heatHold;
  }

  void _teamChanged() {
    final changed = widget.onTeamChanged;
    if (changed != null) return changed();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _changeAddress() async {
    final connection = _owner;
    if (connection == null || _switching) return;
    setState(() => _switching = true);
    try {
      final saved = await editTeamAddress(
        context,
        connection,
        probe: widget.probe,
      );
      if (saved) _teamChanged();
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _turnOff() async {
    final connection = _owner;
    final profile = connection?.profile;
    if (connection == null || profile == null || _switching) return;
    final confirmed = await showTeamTurnOffSheet(context, profile.name);
    if (!confirmed || !mounted) return;
    setState(() {
      _switching = true;
      _offFailed = false;
    });
    try {
      final outcome = await turnOffTeam(connection, profile);
      if (outcome == TeamOffOutcome.failed) {
        if (mounted) setState(() => _offFailed = true);
        return;
      }
      _teamChanged();
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  /// The phone's Termux team's own controls: keep it running, stop it,
  /// remove it (the section the old AI Team sheet carried).
  Future<void> _openPhoneControls() {
    final connection = _owner!;
    final l10n = _copy(context);
    return showKitSheet<void>(
      context,
      title: l10n.teamUiPhoneSectionTitle,
      icon: AppIconography.phone,
      sheetKey: const ValueKey('team-home-phone-sheet'),
      body: (sheetContext) => TeamPhoneSection(
        connection: connection,
        profile: connection.profile!,
        runtime: widget.teamRuntime,
        onRemoved: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  void _toggleSearch() => setState(() {
    _searchOpen = !_searchOpen;
    if (!_searchOpen) {
      _search.clear();
      _query = '';
      _filter = TeamRunFilter.all;
    }
  });

  void _openRun(OrchestrationRun run) {
    final open = widget.onOpenRun;
    if (open != null) return open(run);
    unawaited(TeamConversation.open(context, widget.controller, runId: run.id));
  }

  void _openAgents() {
    Navigator.of(context).push(
      KitPageRoute<void>(
        builder: (_) => TeamAgentsScreen(
          controller: widget.controller,
          onOpenAgent: widget.onOpenAgent,
          now: widget.now,
        ),
      ),
    );
  }

  void _openGate(OrchestrationGate gate) =>
      showGateSheet(context, widget.controller, gate.id, now: () => _now);

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final controller = widget.controller;
      if (controller.phase == OrchestrationPhase.failed) {
        await controller.retry();
      } else {
        await controller.refresh();
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _startRun() async {
    // The task's conversation opens once the host took it (the planner's
    // message or the direct task); back here, a refusal the sheet did not
    // say (the work item made, its worker pool refused it) is said once.
    final record = await TeamConversation.start(context, widget.controller);
    if (!mounted) return;
    if (record == null ||
        record.kind == MutationKind.message ||
        record.status != MutationStatus.rejected) {
      return;
    }
    setState(() => _refusal = record);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    return ListenableBuilder(
      listenable: _watching(),
      builder: (context, _) {
        final controller = widget.controller;
        final ready =
            controller.phase == OrchestrationPhase.ready &&
            controller.snapshot.hasData;
        final hold = _heatHold();
        final owner = _owner;
        final builtin = BuiltinTeam.isBuiltinConfig(controller.config);
        // The one primary action (design standard §2): pinned below the
        // list, never over it, only where this phone can give a task.
        final canStart = controller.capabilities.controlMessage && ready;
        final searchable =
            ready &&
            teamVisibleRuns(controller.snapshot.runs).length >
                teamHomeSearchAfter;
        final line = ready
            ? teamStatusLine(
                context,
                controller: controller,
                keyPrefix: 'team-home',
                onRetry: _refreshing ? null : _refresh,
              )
            : null;
        return KitScreen(
          key: const ValueKey('team-home'),
          topBar: KitTopBar(
            title: l10n.teamUiHomeTitle,
            // Where the team runs, in one phrase; the address, the version
            // and the engine are behind Technical details. A pause for
            // heat and Android's stop are said as what they are, never as
            // the person's pause.
            subtitle: _subtitle(l10n, controller, hold),
            actions: [
              if (searchable || _searchOpen)
                KitAction(
                  key: const ValueKey('team-home-search-open'),
                  label: _searchOpen
                      ? l10n.teamUiHomeSearchClose
                      : l10n.teamUiHomeSearchHint,
                  icon: _searchOpen
                      ? AppIconography.close
                      : AppIconography.search,
                  onPressed: _toggleSearch,
                ),
              // The board (docs/design/team-board-2026-09-26.md).
              if (ready)
                KitAction(
                  key: const ValueKey('team-home-board'),
                  label: l10n.teamBoardOpenTooltip,
                  icon: AppIconography.kanban,
                  onPressed: () =>
                      openTeamBoard(context, controller, now: widget.now),
                ),
            ],
            menu: [
              KitMenuItem(
                key: const ValueKey('team-home-refresh'),
                label: l10n.teamUiRefresh,
                icon: AppIconography.retry,
                enabled: !_refreshing,
                onSelected: () => unawaited(_refresh()),
              ),
              // The team-plugin-sheet's switches, on the team's own page.
              if (owner != null && !builtin)
                KitMenuItem(
                  key: const ValueKey('team-home-change-address'),
                  label: l10n.teamHomeChangeAddress,
                  icon: AppIconography.edit,
                  enabled: !_switching,
                  onSelected: () => unawaited(_changeAddress()),
                ),
              // The phone's Termux team's own controls, whatever state the
              // page is in (a stopped team is exactly when they are needed).
              if (owner != null && teamPhoneProfile(owner.profile))
                KitMenuItem(
                  key: const ValueKey('team-home-phone-controls'),
                  label: l10n.teamHomePhoneControls,
                  icon: AppIconography.phone,
                  onSelected: () => unawaited(_openPhoneControls()),
                ),
              if (owner != null)
                KitMenuItem(
                  key: const ValueKey('team-home-turn-off'),
                  label: l10n.teamUiTurnOff,
                  icon: AppIconography.unlink,
                  destructive: true,
                  enabled: !_switching,
                  onSelected: () => unawaited(_turnOff()),
                ),
            ],
            menuKey: const ValueKey('team-home-more'),
          ),
          // A list on its own: centred at the list width on a PC.
          width: KitScreenWidth.list,
          search: _searchOpen && ready ? _searchField(l10n) : null,
          // Android stopped the phone's Termux team: said here, with
          // Start the team again (map: team-phone-onboarding-killed).
          header: [
            ?line,
            if (_offFailed)
              Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: KitTokens.of(context).gutter,
                  vertical: KitTokens.of(context).space2,
                ),
                child: KitNotice(
                  key: const ValueKey('team-home-turn-off-failed'),
                  tone: AppStatusTone.failure,
                  icon: AppIconography.error,
                  message: l10n.teamHomeTurnOffFailed,
                  onDismiss: () => setState(() => _offFailed = false),
                ),
              ),
          ],
          // Stopped by Android: nothing loads until it starts again, and
          // the line above says so.
          loading: !_killed && (teamScreenLoading(controller) || _refreshing),
          loadingLabel: l10n.teamUiCardLoading,
          body: _body(context, hold),
          bottom: canStart
              ? KitButton.primary(
                  key: const ValueKey('team-home-start-run'),
                  label: l10n.teamUiStartRunFab,
                  icon: AppIconography.add,
                  onPressed: _startRun,
                )
              : null,
        );
      },
    );
  }

  static String _filterLabel(AppLocalizations l10n, TeamRunFilter f) =>
      switch (f) {
        TeamRunFilter.active => l10n.teamUiHomeFilterActive,
        TeamRunFilter.blocked => l10n.teamUiHomeFilterBlocked,
        TeamRunFilter.completed => l10n.teamUiHomeFilterCompleted,
        TeamRunFilter.all => l10n.teamUiHomeFilterAll,
      };

  /// The search field and its one filter menu (never a row of chips); the
  /// chosen filter reads as a removable chip in words.
  KitSearchField _searchField(AppLocalizations l10n) => KitSearchField(
    label: l10n.teamUiHomeSearchHint,
    controller: _search,
    autofocus: true,
    onChanged: (query) => setState(() => _query = query),
    filters: [
      for (final f in TeamRunFilter.values)
        KitMenuItem(
          key: ValueKey('team-home-filter-${f.name}'),
          label: _filterLabel(l10n, f),
          checked: f == _filter,
          onSelected: () => setState(() => _filter = f),
        ),
    ],
    activeFilter: _filter == TeamRunFilter.all
        ? null
        : _filterLabel(l10n, _filter),
    onClearFilter: () => setState(() => _filter = TeamRunFilter.all),
    fieldKey: const ValueKey('team-home-search'),
    clearKey: const ValueKey('team-home-search-clear'),
    filterKey: const ValueKey('team-home-filter-menu'),
  );

  String? _age(AppLocalizations l10n, DateTime? at) => at == null
      ? null
      : relativeTimeLabel(at.millisecondsSinceEpoch, now: _now, l10n: l10n);

  static bool _isFinished(OrchestrationRun run) =>
      run.state == RunState.completed || run.state == RunState.cancelled;

  bool _matches(OrchestrationRun run, String query, Set<String> gated) {
    if (query.isNotEmpty && !run.title.toLowerCase().contains(query)) {
      return false;
    }
    return switch (_filter) {
      TeamRunFilter.active =>
        run.state == RunState.working || run.state == RunState.planning,
      TeamRunFilter.blocked =>
        run.state == RunState.blocked ||
            run.state == RunState.failed ||
            run.state == RunState.waiting ||
            gated.contains(run.id),
      TeamRunFilter.completed => _isFinished(run),
      TeamRunFilter.all => true,
    };
  }

  /// Where the team runs, then what holds it: Android's stop, the heat
  /// guard's pause, else [teamHostCondition] (the person's pause, not
  /// answering).
  String _subtitle(
    AppLocalizations l10n,
    OrchestrationController controller,
    ThermalTeamHold? hold,
  ) {
    final String? held;
    if (_killed) {
      held = l10n.teamHomeHostStopped;
    } else if (hold != null) {
      held = hold.serviceStopped
          ? l10n.teamHomeHostStoppedForHeat
          : l10n.teamHomeHostCooling;
    } else {
      return teamHostPhrase(l10n, controller);
    }
    return [teamHostPlace(l10n, controller), held].join(teamUsageSeparator);
  }

  Widget _body(BuildContext context, ThermalTeamHold? hold) {
    final l10n = _copy(context);
    final tokens = KitTokens.of(context);
    final controller = widget.controller;
    // Android stopped the phone's Termux team (map:
    // team-phone-onboarding-killed): said at the top of the page, where it
    // scrolls (at large text it is taller than a fixed header allows).
    final killed = TeamPhoneKilledNotice.appliesTo(controller.config)
        ? TeamPhoneKilledNotice(
            key: _killedKey,
            controller: controller,
            runtime: widget.teamRuntime,
            onKilledChanged: (killed) {
              if (mounted) setState(() => _killed = killed);
            },
          )
        : null;
    // Stopped and nothing was read yet: that line is the page's state
    // (with Start the team again); no "not answering, the app keeps
    // trying" under it.
    if (killed != null && _killed && !controller.snapshot.hasData) {
      return ListView(
        key: const ValueKey('team-home-stopped'),
        padding: EdgeInsetsDirectional.only(
          bottom: KitScreen.endPadding(context),
        ),
        children: [killed],
      );
    }
    if (teamScreenState(
          context,
          controller: controller,
          keyPrefix: 'team-home',
          onRetry: _refreshing ? null : _refresh,
        )
        case final state?) {
      if (killed == null) return state;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          killed,
          Expanded(child: state),
        ],
      );
    }

    final snapshot = controller.snapshot;
    final gated = teamGatedRuns(snapshot);
    final gates = teamOpenGates(controller);
    // The host's upkeep (patrols, chores) is hidden by default and never
    // counted; the switch under the list reveals it.
    final runs = teamVisibleRuns(snapshot.runs);
    final upkeep = teamUpkeepRuns(snapshot.runs)
      ..sort((a, b) => teamCompareRuns(a, b, gated));
    final ordered = [...runs]..sort((a, b) => teamCompareRuns(a, b, gated));
    // One question in place names its task and stands for its row.
    final carded = gates.length == 1
        ? teamGateRun(snapshot, gates.single)
        : null;
    // Several questions: each task's row becomes its most urgent question;
    // a question whose task is not listed (or a second one on the same
    // task) is a row of its own at the top of the list.
    final gateOfRun = <String, OrchestrationGate>{};
    final looseGates = <OrchestrationGate>[];
    if (gates.length > 1) {
      final listedIds = {for (final run in runs) run.id};
      for (final gate in gates) {
        final id = teamGateRun(snapshot, gate)?.id;
        if (id != null &&
            listedIds.contains(id) &&
            !gateOfRun.containsKey(id)) {
          gateOfRun[id] = gate;
        } else {
          looseGates.add(gate);
        }
      }
    }
    final query = (_searchOpen ? _query : '').trim().toLowerCase();
    final filtering =
        _searchOpen && (query.isNotEmpty || _filter != TeamRunFilter.all);
    final visible = [
      for (final run in ordered)
        if (!filtering || _matches(run, query, gated)) run,
    ];
    final listed = [
      for (final run in visible)
        if (run.id != carded?.id) run,
    ];
    final loose =
        !filtering ||
            (_filter != TeamRunFilter.active &&
                _filter != TeamRunFilter.completed &&
                query.isEmpty)
        ? looseGates
        : const <OrchestrationGate>[];
    final open = [
      for (final run in listed)
        if (!_isFinished(run)) run,
    ];
    final done = [
      for (final run in listed)
        if (_isFinished(run)) run,
    ];
    final doneShown = _doneExpanded || filtering
        ? done
        : done.take(teamHomeDoneShown).toList();
    final hiddenDone = done.length - doneShown.length;
    final live = teamLiveAgents(snapshot.agents);
    final working = live.where((a) => a.state == AgentState.working).length;

    Widget row(OrchestrationRun run) {
      final gate = gateOfRun[run.id];
      final needsYou = gate != null || gated.contains(run.id);
      final record = gate == null ? null : teamGateMutation(controller, gate);
      final String line;
      if (gate != null) {
        // The row is the question: "Needs you · <question> · 2 min ago".
        line = [
          l10n.teamUiHomeRunNeedsYou,
          gate.title,
          ?_age(l10n, gate.createdAt),
        ].join(teamUsageSeparator);
      } else {
        final task = teamTaskLine(
          l10n,
          run,
          snapshot.work,
          needsYou: needsYou,
          now: _now,
          cycleOf: controller.cycleFor,
          explainWait: true,
          checkEvery: teamCheckInterval(controller),
          paused: teamRest(snapshot.agents) == TeamRest.paused,
        );
        // What happens next, once, on the working task's own row (the
        // team's Now line no longer repeats the task above the list).
        final reviewNext =
            !needsYou &&
            run.state == RunState.working &&
            teamRunStage(run, snapshot.work, cycleOf: controller.cycleFor) ==
                TeamStage.working;
        line = reviewNext
            ? [task, l10n.teamUiHomeRunReviewNext].join(teamUsageSeparator)
            : task;
      }
      final receipt =
          gate != null &&
              record != null &&
              record.status != MutationStatus.confirmed
          ? Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: tokens.space2,
              ),
              child: TeamReceiptChip(
                key: ValueKey('team-home-gate-${gate.id}-receipt'),
                record: record,
                onOpen: () => _openGate(gate),
              ),
            )
          : null;
      return KitRow(
        key: ValueKey('team-home-run-${run.id}'),
        leading: KitTaskMark(state: teamRunMark(run, needsYou: needsYou)),
        // A task's title is the person's own objective: two lines.
        title: run.title,
        titleMaxLines: 2,
        supporting: TextSpan(text: line),
        supportingMaxLines: 2,
        supportingKey: ValueKey('team-home-run-state-${run.id}'),
        // The receipt while the host has not confirmed an answer.
        trailing: receipt,
        // A question opens the Gate sheet; any other task its conversation.
        onTap: gate != null ? () => _openGate(gate) : () => _openRun(run),
      );
    }

    // The first section sits close under the top bar; the rest keep the
    // list's section spacing.
    final gap = SizedBox(height: tokens.sectionGap);
    final planning = teamPendingPlanning(controller, _now);
    // One status line (design standard §5): old data wins; else the team's
    // Now (what it is doing, what happens next) heads the list, where it
    // scrolls with it instead of taking room from the tasks.
    final stale =
        teamStatusLine(
          context,
          controller: controller,
          keyPrefix: 'team-home',
          onRetry: null,
        ) !=
        null;
    // A pause for heat is the guard's, not the person's: it says why and
    // that the team carries on by itself, and offers no Resume (waking the
    // agents would heat the phone again).
    final now = hold != null
        ? _heatLine(context, l10n, hold)
        : stale
        ? null
        : teamNowLine(
            context,
            controller: controller,
            now: _now,
            keyPrefix: 'team-home-now',
            // Working, in review and waiting are said on the task's row.
            taskLines: false,
          );
    final refusal = _refusal;
    final inset = EdgeInsetsDirectional.symmetric(
      horizontal: tokens.gutter,
      vertical: tokens.space2,
    );
    final children = <Widget>[
      ?killed,
      ?now,
      if (refusal != null)
        Padding(
          padding: inset,
          child: KitNotice(
            key: const ValueKey('team-home-direct-receipt'),
            tone: AppStatusTone.failure,
            icon: AppIconography.error,
            message: teamReceiptLine(l10n, refusal),
            onDismiss: () => setState(() => _refusal = null),
          ),
        ),
      for (final (index, request) in planning.indexed)
        Padding(
          padding: inset,
          child: TeamPlanningCard(
            controller: controller,
            request: request,
            now: widget.now,
            // One moving drawing per screen (design standard §10).
            ambient: index == 0,
          ),
        ),
      // 1. What needs the person, first, and only when something does: the
      // answer surface itself, no section heading over it.
      if (gates.length == 1) ...[
        SizedBox(height: tokens.space3),
        // The card's ring sits outside its border: inset by the gutter less
        // the ring, its edge lines up with the rows below.
        Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: tokens.gutter - KitTokens.needsYouRingWidth,
          ),
          child: TeamNeedsYouCard(
            keyPrefix: 'team-home-gate-${gates.single.id}',
            controller: controller,
            gate: gates.single,
            title: carded?.title ?? l10n.teamUiHomeNeedsYouFallbackTitle,
            detail: carded == null || _isFinished(carded)
                ? null
                : teamTaskSteps(
                    l10n,
                    TeamRunProgress.of(carded, snapshot.work),
                  ),
            onOpenTask: carded == null ? null : () => _openRun(carded),
            onOpen: () => _openGate(gates.single),
          ),
        ),
        gap,
      ] else
        SizedBox(height: tokens.space3),
      // 2. The tasks: one panel, most urgent first, what finished last.
      if (runs.isEmpty)
        KitStateView(
          key: const ValueKey('team-home-runs-empty'),
          size: KitStateSize.inline,
          liveRegion: false,
          icon: AppIconography.checklist,
          // The team gathered at an empty board, its one slot waiting;
          // not while a task is being planned, whose card has the drawing.
          illustration: planning.isEmpty ? const TeamBoardScene() : null,
          // Room for the board and its three agents to read (88 dp, the
          // inline default, cramped them).
          illustrationWidth: 168,
          title: l10n.teamUiCardEmptyTitle,
          // One sentence that teaches; the pinned button is the action, so
          // the state never repeats it.
          body: controller.capabilities.controlMessage
              ? l10n.emptyTeachTeamRunsMessage
              : l10n.teamUiCardEmptyHint,
        )
      else if (visible.isEmpty)
        KitStateView(
          key: const ValueKey('team-home-runs-empty-filtered'),
          size: KitStateSize.inline,
          liveRegion: false,
          icon: AppIconography.filterOff,
          title: l10n.teamUiHomeRunsEmptyFiltered,
          body: l10n.teamUiHomeRunsEmptyHint,
        ),
      if (runs.isEmpty || visible.isEmpty) gap,
      if (listed.isNotEmpty || loose.isNotEmpty) ...[
        KitRowGroup(
          key: const ValueKey('team-home-tasks'),
          // No heading: the page is the task list and its title says so.
          children: [
            for (final gate in loose)
              TeamGateRow(
                key: ValueKey('team-home-gate-${gate.id}'),
                receiptKey: ValueKey('team-home-gate-${gate.id}-receipt'),
                controller: controller,
                gate: gate,
                now: _now,
                onTap: () => _openGate(gate),
              ),
            for (final run in open) row(run),
            for (final run in doneShown) row(run),
            if (hiddenDone > 0)
              KitRow(
                key: const ValueKey('team-home-completed-more'),
                leading: KitRow.icon(context, AppIconography.chevronDown),
                title: l10n.teamUiHomeDoneMore(hiddenDone),
                onTap: () => setState(() => _doneExpanded = true),
              ),
          ],
        ),
        gap,
      ],
      if (upkeep.isNotEmpty) ...[
        KitRowGroup(
          leadingIcons: false,
          children: [
            KitSwitchRow(
              key: const ValueKey('team-home-upkeep-row'),
              switchKey: const ValueKey('team-home-upkeep-toggle'),
              title: l10n.teamUiHomeUpkeepToggle(upkeep.length),
              supporting: l10n.teamUiHomeUpkeepHint,
              value: _upkeepShown,
              onChanged: (shown) => setState(() => _upkeepShown = shown),
            ),
            if (_upkeepShown)
              for (final run in upkeep) row(run),
          ],
        ),
        gap,
      ],
      // 3. The team itself: who is on it, how it runs, what it spent. The
      // board opens from the top bar only (one entry point).
      KitRowGroup(
        key: const ValueKey('team-home-team'),
        children: [
          _AgentsRow(
            key: const ValueKey('team-home-agents-row'),
            live: live.length,
            total: snapshot.agents.length,
            rest: teamRest(snapshot.agents),
            cooling: hold != null,
            working: working,
            onTap: _openAgents,
          ),
          // How fast it runs where it runs (the place is the top bar's);
          // the address, version and access are behind it.
          KitRow(
            key: const ValueKey('team-home-host-row'),
            leading: KitRow.icon(context, AppIconography.speed),
            title: l10n.teamUiTechnicalDetails,
            supporting: TextSpan(
              text: teamHostDisclaimer(
                l10n,
                teamHostKindFor(
                  controller.config,
                  controller.host?.hostMode ?? controller.config.hostMode,
                ),
              ),
            ),
            supportingKey: const ValueKey('team-home-host-speed'),
            supportingMaxLines: 2,
            trailing: const KitChevron(),
            onTap: () => showTeamHostDetailsSheet(context, controller),
          ),
          ?_spentRow(context, l10n, controller),
        ],
      ),
    ];

    return KeyedSubtree(
      key: const ValueKey('team-home-data'),
      child: KitRefresh(
        key: const ValueKey('team-home-pull'),
        onRefresh: _refresh,
        child: ListView(
          key: const ValueKey('team-home-runs'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsetsDirectional.only(
            bottom: KitScreen.endPadding(context),
          ),
          children: children,
        ),
      ),
    );
  }

  /// The heat guard's line: paused (or stopped) since when, and that the
  /// team carries on by itself once the phone has cooled.
  Widget _heatLine(
    BuildContext context,
    AppLocalizations l10n,
    ThermalTeamHold hold,
  ) {
    final at = teamClockLabel(context, hold.since);
    return KitStatusLine(
      key: const ValueKey('team-home-heat'),
      icon: hold.serviceStopped
          ? AppIconography.stopCircle
          : AppIconography.pause,
      tone: AppStatusTone.attention,
      message: hold.serviceStopped
          ? l10n.teamHomeHeatStoppedLine(at)
          : l10n.teamHomeHeatPausedLine(at),
    );
  }

  /// What the whole team spent today, as the host estimates it; null when
  /// the host reports nothing (unknown is never "\$0").
  Widget? _spentRow(
    BuildContext context,
    AppLocalizations l10n,
    OrchestrationController controller,
  ) {
    if (!controller.capabilities.usage) return null;
    final evidence = controller.snapshot.usage?.evidence;
    final today = evidence != null && evidence.available
        ? evidence.today
        : null;
    if (today == null) return null;
    final cost = today.costUsdEstimate;
    final input = today.inputTokens, output = today.outputTokens;
    final tokens = input == null && output == null
        ? null
        : (input ?? 0) + (output ?? 0);
    final figures = [
      if (cost != null) l10n.teamUiUsageCostEstimated(teamCurrencyLabel(cost)),
      if (tokens != null) l10n.teamUiUsageTokens(teamCompactCount(tokens)),
    ];
    if (figures.isEmpty) return null;
    // Some use has no price, or history is missing: the figure is a floor.
    final incomplete = (today.unpriced ?? 0) > 0 || evidence!.partial;
    return KitRow(
      key: const ValueKey('team-home-spent'),
      leading: KitRow.icon(context, AppIconography.usage),
      title: l10n.teamHomeSpentToday(figures.join(teamUsageSeparator)),
      titleKey: const ValueKey('team-home-spent-figure'),
      supporting: TextSpan(
        text: incomplete ? l10n.teamHomeSpentPartial : l10n.teamHomeSpentHint,
      ),
      supportingMaxLines: 2,
    );
  }
}

/// "3 agents · 1 working", opening the agents list.
class _AgentsRow extends StatelessWidget {
  const _AgentsRow({
    super.key,
    required this.live,
    required this.total,
    required this.rest,
    required this.working,
    required this.onTap,
    this.cooling = false,
  });

  final int live;

  /// The heat guard holds the team: its agents rest to cool the phone,
  /// not because the person paused them.
  final bool cooling;

  /// Every agent the host lists, asleep and paused ones included.
  final int total;
  final TeamRest rest;
  final int working;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    // Asleep agents are the team too: "3 agents · asleep until there is
    // work", not "No agents".
    final title = switch (cooling ? null : rest) {
      null => [
        l10n.teamUiHomeAgentsRowCount(total),
        l10n.teamHomeAgentsCooling,
      ],
      TeamRest.asleep => [
        l10n.teamUiHomeAgentsRowCount(total),
        l10n.teamNowAgentsAsleep,
      ],
      TeamRest.paused => [
        l10n.teamUiHomeAgentsRowCount(total),
        l10n.teamNowAgentsPaused,
      ],
      TeamRest.awake => [
        l10n.teamUiHomeAgentsRowCount(live),
        if (working > 0) l10n.teamUiHomeAgentsRowWorking(working),
      ],
    }.join(teamUsageSeparator);
    return Semantics(
      button: true,
      hint: l10n.teamUiHomeAgentsRowHint,
      child: KitRow(
        leading: KitRow.icon(context, AppIconography.agent),
        title: title,
        trailing: const KitChevron(),
        onTap: onTap,
      ),
    );
  }
}
