import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/product_repository.dart';
import '../../api/sse.dart';
import '../../domain/return_brief.dart';
import '../../domain/workspace_paths.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../../state/connection.dart';
import '../../state/interaction_defaults.dart';
import '../../state/nudges.dart';
import '../../domain/orchestration_gateway.dart' show OrchestrationRun;
import '../../state/orchestration.dart';
import '../desktop/desktop_interaction.dart';
import '../navigation/chat_route.dart';
import '../widgets/default_notices.dart';
import '../widgets/grace_timer.dart';
import '../widgets/safety_confirms.dart';
import '../widgets/other_servers_panel.dart';
import '../widgets/other_projects_panel.dart';
import '../kit/kit.dart';
import '../kit/scenes/states_scenes.dart';
import '../widgets/product_states.dart' show productErrorText;
import '../widgets/relative_time.dart';
import '../widgets/session_title.dart';
import '../widgets/request_routes.dart';
import '../widgets/older_sessions_pager.dart';
import '../widgets/team_task_row.dart';
import '../widgets/team_discover.dart' show teamPossibleOn;
import '../widgets/team_vocabulary.dart' show teamGatedRuns;
import 'chat_screen.dart' show ChatScreen;
import 'team_conversation/team_conversation.dart';
import 'team/team_intro_screen.dart';
import '../widgets/termux_phone_tools.dart';
import '../widgets/work_status_line.dart';
import '../../termux/bridge.dart';
import 'global_sessions_screen.dart';
import 'isolated_task_sheet.dart';
import 'session_context_screen.dart';
import 'new_conversation_sheet.dart';
import 'project_folder_actions.dart';
import 'projects_screen.dart';
import 'run_result_screen.dart';
import '../app_theme.dart';
import '../../domain/team_directories.dart';

/// The Work tab (docs/ux-system/map/all.json `workspace`, proposal
/// "redesign"): a kit-only rebuild of today's layout with one New
/// conversation whose chooser ([showNewConversationSheet], slice-P4.5)
/// offers Solo · Team · In a separate copy · On a cloud machine where the
/// server supports each. The rest of the new structure (one "N need you"
/// row to Inbox, the AI Team as a notice until first use) waits for its
/// wave-3 slice.
/// From expanded it is a [KitScreen.twoPane]: the list at the start and the
/// selected conversation beside it.
class WorkspaceScreen extends StatefulWidget {
  final ConnectionController controller;

  /// The server is this phone's own (Termux or in the app): the status line
  /// calls it "OpenCode on this phone" and offers [onRestartServer].
  final bool serverOnThisPhone;

  /// Restarts the phone's server and reconnects; null when this server
  /// cannot be restarted from here.
  final Future<void> Function()? onRestartServer;

  const WorkspaceScreen({
    super.key,
    required this.controller,
    this.serverOnThisPhone = false,
    this.onRestartServer,
  });

  /// Test seam: replaces the phone's leftover-process watcher, so the status
  /// line's "OpenCode has been busy" state can be shown without Termux.
  @visibleForTesting
  static Widget Function(
    BuildContext context,
    Widget Function(BuildContext context, WorkRunawayNotice? notice) builder,
  )?
  debugRunawayWatcher;

  /// The catalog project that owns [directory]: its root or a listed
  /// worktree first, then any project containing it. Shared with the Project
  /// tab so both name the same project for the same folder.
  static WorkspaceProject? projectForDirectory(
    List<WorkspaceProject> projects,
    String directory,
  ) {
    for (final project in projects) {
      if (project.directory == directory ||
          project.worktrees.contains(directory)) {
        return project;
      }
    }
    for (final project in projects) {
      if (ConnectionController.projectContainsDirectory(project, directory)) {
        return project;
      }
    }
    return null;
  }

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  List<WorkspaceProject>? _projects;
  List<WorkspaceInfo> _workspaces = const [];
  String? _projectError;
  String? _workspaceError;
  String? _selectedProjectID;
  String? _selectedWorkspaceID;
  String? _selectedDirectory;
  bool _creating = false;
  int _loadGeneration = 0;
  int _dataRefreshRevision = 0;

  /// Conversations archived in this window whose Undo is still open: hidden
  /// from every list until the archive is committed or undone.
  final Set<String> _pendingArchive = {};

  /// The conversation open in the detail pane (expanded and wider).
  String? _selectedSessionID;

  /// A failed act, said once above the list until dismissed (§4.8: where the
  /// thing is, never a snackbar).
  String? _notice;

  /// A project picked on a fresh connection is being opened.
  bool _selectingInitial = false;

  /// Said once per server after this tab opened a project by itself (the
  /// only one, or the one worked on most recently) instead of asking.
  String? _defaultNotice;

  /// Whether another project could have been opened instead: only then does
  /// the notice offer the way to one.
  bool _defaultCanChange = false;

  /// Whether this server can run an AI Team (a Termux phone asks its
  /// runtime once), for New conversation's Team choice.
  String? _teamAskedFor;
  bool _teamPossible = false;

  /// Opening the saved project was tried and left no folder open: the
  /// folder chooser may show.
  bool _restoreGaveUp = false;

  /// The project folder that is about to open while none is open yet: the
  /// saved one being restored, or the one picked for a fresh connection.
  /// While it is set the header names it and the folder chooser stays away
  /// (work-tab cleanup item 1: the chooser flashed during a restore).
  String? get _pendingDirectory {
    final controller = widget.controller;
    if (controller.directory != null) return null;
    if (_selectingInitial && _selectedDirectory != null) {
      return _selectedDirectory;
    }
    if (_restoreGaveUp) return null;
    return controller.savedProjectDirectory;
  }

  /// The folder the header names: the open one, else the one opening.
  String? get _headerDirectory =>
      widget.controller.directory ?? _pendingDirectory;

  @override
  void initState() {
    super.initState();
    _dataRefreshRevision = widget.controller.dataRefreshRevision;
    widget.controller.addListener(_changed);
    widget.controller.nudges.addListener(_nudgesChanged);
    _load();
  }

  @override
  void didUpdateWidget(WorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    // Another connection behind the same tab: listen to it and start over.
    oldWidget.controller.removeListener(_changed);
    oldWidget.controller.nudges.removeListener(_nudgesChanged);
    widget.controller.addListener(_changed);
    widget.controller.nudges.addListener(_nudgesChanged);
    _dataRefreshRevision = widget.controller.dataRefreshRevision;
    _restoreGaveUp = false;
    _selectingInitial = false;
    _selectedSessionID = null;
    unawaited(_load());
  }

  void _nudgesChanged() {
    if (mounted) setState(() {});
  }

  bool _nudgeCheckQueued = false;

  /// The "pin" tip (UX plan 5.8): once a second project has been used, Work
  /// is no longer one short list and pinning starts to pay. Runs after the
  /// frame because an offer notifies listeners. [canOffer] is false while
  /// Work is behind another tab or route, where a tip would be spent unseen.
  void _queuePinNudge({required bool visible, required bool canOffer}) {
    if (_nudgeCheckQueued) return;
    _nudgeCheckQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nudgeCheckQueued = false;
      if (!mounted) return;
      final controller = widget.controller;
      final nudges = controller.nudges;
      if (!visible) {
        // One nudge app-wide: a tip left behind must not block the rest.
        nudges.releaseScope(NudgeRegistry.workScope);
        return;
      }
      final directory = controller.directory;
      final profileID = controller.profile?.id ?? '';
      if (directory != null && controller.isConnected) {
        unawaited(
          nudges.noteProjectUsed(profileID: profileID, directory: directory),
        );
      }
      if (canOffer && nudges.secondProjectUsed) {
        nudges.offer(NudgeId.pinConversations, scope: NudgeRegistry.workScope);
      }
    });
  }

  void _changed() {
    if (!mounted) return;
    final shouldReload =
        _dataRefreshRevision != widget.controller.dataRefreshRevision &&
        widget.controller.repository != null;
    _dataRefreshRevision = widget.controller.dataRefreshRevision;
    setState(() {});
    if (shouldReload) unawaited(_load());
  }

  Future<void> _refreshWorkspace() async {
    await _load();
    if (!mounted) return;
    await widget.controller.refreshSessions();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (!widget.controller.capabilities.projectManagement) {
      if (mounted) {
        setState(() {
          _projects = const [];
          _workspaces = const [];
          _projectError = null;
          _workspaceError = null;
        });
      }
      return;
    }
    final repository = await widget.controller.prepareActionRepository();
    if (!mounted || generation != _loadGeneration) return;
    if (repository == null) {
      setState(() => _projectError = _l10n(context).e7WorkspaceDisconnected);
      return;
    }
    setState(() {
      _projectError = null;
      _workspaceError = null;
    });
    try {
      final projects = await repository.listProjects();
      if (!mounted || generation != _loadGeneration) return;
      // A later catalog may confirm the restored folder. Omission leaves
      // the user's choice intact rather than selecting a different project.
      await widget.controller.revalidateRestoredLocation();
      if (!mounted || generation != _loadGeneration) return;
      projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      var shouldSelectInitialLocation = false;
      var shouldRestoreSaved = false;
      DefaultChoice<DefaultProject>? projectDefault;
      setState(() {
        _projects = projects;
        if (projects.isEmpty && widget.controller.directory != null) {
          _selectedProjectID = null;
          _selectedDirectory = widget.controller.directory;
          _selectedWorkspaceID = widget.controller.workspace;
          return;
        }
        final controllerDirectory = widget.controller.directory;
        final saved = widget.controller.savedProjectDirectory;
        if (controllerDirectory != null) {
          _restoreGaveUp = false;
          _selectedDirectory = controllerDirectory;
          _selectedWorkspaceID = widget.controller.workspace;
          final matching = WorkspaceScreen.projectForDirectory(
            projects,
            controllerDirectory,
          );
          // An unlisted explicit folder is still the active context. Never
          // label it with a different catalog project's name.
          _selectedProjectID = matching?.id;
        } else if (saved != null && !_restoreGaveUp) {
          // The person already has a project on this server: it is being
          // restored (or is opened now), never replaced by another one.
          _selectedDirectory = saved;
          _selectedWorkspaceID = null;
          _selectedProjectID = WorkspaceScreen.projectForDirectory(
            projects,
            saved,
          )?.id;
          shouldRestoreSaved = true;
        } else {
          // Only a real project folder is opened automatically. The server's
          // catch-all root and any home folder are skipped, so a fresh
          // connection lands on the folder chooser instead of `/root`.
          // Defaults instead of questions (P6.6): the project still picked
          // here, else the only one, else the one worked on most recently
          // (the list is newest first). None: the chooser proposes a new
          // "my-app".
          final usable = projects
              .where(
                (project) =>
                    !isProtectedWorkspaceDirectory(project.directory) &&
                    !isAiTeamDirectory(project.directory),
              )
              .toList();
          final choice = InteractionDefaults.project(
            usable,
            explicitID: _selectedProjectID,
            lastUsedID: usable.firstOrNull?.id,
          );
          final selected = choice.value?.project;
          if (selected == null) {
            _selectedProjectID = null;
            _selectedDirectory = null;
            _selectedWorkspaceID = null;
            return;
          }
          _selectedProjectID = selected.id;
          _selectedDirectory = selected.directory;
          _selectedWorkspaceID = null;
          shouldSelectInitialLocation = true;
          _selectingInitial = true;
          projectDefault = choice;
        }
      });
      final selected = _selectedProject;
      if (shouldSelectInitialLocation && selected != null) {
        try {
          await widget.controller.selectInitialLocation(
            directory: _selectedDirectory ?? selected.directory,
          );
        } finally {
          if (mounted) setState(() => _selectingInitial = false);
        }
        final opened = projectDefault;
        if (opened != null &&
            mounted &&
            widget.controller.directory != null &&
            widget.controller.locationError == null) {
          unawaited(_announceProject(opened));
        }
      }
      if (shouldRestoreSaved) await _restoreSaved();
    } catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _projectError = productErrorText(error));
      }
    }
    if (generation != _loadGeneration) return;
    await _loadWorkspaces();
  }

  /// Says once per server which project this tab opened by itself, with
  /// the way to another one when there is one; nothing when it was the
  /// person's own pick.
  Future<void> _announceProject(DefaultChoice<DefaultProject> choice) async {
    final said = await claimDefaultNotice(
      kind: DefaultKind.project,
      choice: choice,
      profileId: widget.controller.profile?.id,
      prefs: widget.controller.store.prefs,
    );
    if (said == null || !mounted) return;
    final l10n = _l10n(context);
    final name = KitBidi.auto(said);
    setState(() {
      _defaultCanChange = choice.canChange;
      _defaultNotice = choice.reason == DefaultReason.onlyOption
          ? l10n.defaultProjectOnlyNotice(name)
          : l10n.defaultProjectLastUsedNotice(name);
    });
  }

  /// Opens the saved project when the connection came up without it. When
  /// connect is still restoring it there is nothing to do but wait; when the
  /// attempt leaves no folder open, the folder chooser may show.
  Future<void> _restoreSaved() async {
    final controller = widget.controller;
    if (controller.restoringSavedLocation) return;
    try {
      await controller.restoreSavedLocation();
    } catch (_) {
      // Reported through locationError; the chooser below is the way on.
    }
    if (!mounted) return;
    if (controller.directory == null && !controller.restoringSavedLocation) {
      setState(() => _restoreGaveUp = true);
    }
  }

  Future<void> _loadWorkspaces() async {
    final repository = await widget.controller.prepareActionRepository();
    if (!mounted) return;
    if (repository == null) return;
    try {
      final workspaces = await repository.listWorkspaces();
      if (!mounted) return;
      setState(() {
        _workspaces = workspaces
            .where(
              (workspace) =>
                  _selectedProjectID == null ||
                  workspace.projectID == _selectedProjectID,
            )
            .toList();
      });
    } catch (error) {
      if (mounted) setState(() => _workspaceError = productErrorText(error));
    }
  }

  WorkspaceProject? get _selectedProject {
    for (final project in _projects ?? const <WorkspaceProject>[]) {
      if (project.id == _selectedProjectID) return project;
    }
    return null;
  }

  bool get _hasExternalSessionDirectory {
    final directory = _selectedDirectory;
    final project = _selectedProject;
    if (directory == null || project == null) return false;
    return project.directory != directory &&
        !project.worktrees.contains(directory);
  }

  WorkspaceInfo? get _selectedWorkspace {
    for (final workspace in _workspaces) {
      if (workspace.id == _selectedWorkspaceID) return workspace;
    }
    return null;
  }

  /// The folder this screen's conversations run in.
  String? get _contextDirectory =>
      widget.controller.directory ??
      _selectedWorkspace?.directory ??
      _selectedDirectory ??
      _selectedProject?.directory;

  static String _workspaceName(WorkspaceInfo workspace) =>
      workspace.branch?.isNotEmpty == true ? workspace.branch! : workspace.name;

  Future<void> _selectWorkspace(WorkspaceInfo? workspace) async {
    await widget.controller.selectLocation(
      directory: workspace?.directory ?? _selectedDirectory,
      workspace: workspace?.id,
    );
    if (!mounted) return;
    setState(() {
      _selectedWorkspaceID = widget.controller.workspace;
      _selectedDirectory = widget.controller.directory;
    });
    // The environment switch failed: say so where the person is.
    final error = widget.controller.locationError;
    if (error != null) _say(error);
  }

  static bool _isPhoneProjectsRoot(String path) =>
      path.replaceAll(RegExp(r'/+$'), '') == '/root/projects';

  static String _basename(String path) {
    final parts = path.split('/').where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? path : parts.last;
  }

  /// What a session is blocked on, or null when nothing is waiting. A run
  /// waiting on a permission, question, or form is not making progress, so
  /// the row names the blocker rather than saying "Working". Permission
  /// outranks question outranks form, the order Activity answers them in.
  String? _blocker(String sessionID, AppLocalizations l10n) {
    final controller = widget.controller;
    if (controller.permissionsForSession(sessionID).isNotEmpty) {
      return l10n.monitorPermission;
    }
    if (controller.questionForSession(sessionID) != null) {
      return l10n.monitorQuestion;
    }
    if (controller.formForSession(sessionID) != null) return l10n.monitorForm;
    return null;
  }

  Future<void> _createSession() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final session = await widget.controller.createSession();
      if (!mounted) return;
      await Navigator.of(context).pushNamed(
        '/chat/${session.id}',
        arguments: const ChatRouteArguments.newlyCreated(),
      );
      await widget.controller.refreshSessions();
    } catch (error) {
      if (mounted) {
        _say(_l10n(context).e7WorkspaceCreateFailed(productErrorText(error)));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  /// The project a fresh-worktree task would be created for, or null when
  /// the action must stay hidden: no contract-proven create on this
  /// connection, no project selected, or a managed workspace (not a local
  /// git checkout) is active.
  WorkspaceProject? get _isolatedTaskProject {
    final capabilities = widget.controller.capabilities;
    if (!capabilities.projectManagement || !capabilities.worktreeCreate) {
      return null;
    }
    // Nothing starts before a project folder is open (or while it opens).
    if (widget.controller.workspaceChoiceRequired) return null;
    if (_selectedWorkspaceID != null) return null;
    final project = _selectedProject;
    if (project == null || project.directory.trim().isEmpty) return null;
    return project;
  }

  Future<void> _startIsolatedTask() async {
    final project = _isolatedTaskProject;
    if (_creating || project == null) return;
    final session = await showIsolatedTaskSheet(
      context,
      controller: widget.controller,
      project: project,
    );
    if (!mounted || session == null) return;
    await Navigator.of(context).pushNamed(
      '/chat/${session.id}',
      arguments: const ChatRouteArguments.newlyCreated(),
    );
    if (mounted) await widget.controller.refreshSessions();
  }

  @override
  Widget build(BuildContext context) {
    // The Work tab, top to bottom (work-tab cleanup, 2026-09-24): the
    // project header from the first frame, one loading bar, at most one
    // status line, this project's conversations in one list ordered by
    // urgency, the other projects once each, and New conversation docked
    // below the list.
    // Project discovery and session inventory are independent: a pending
    // or failed catalog never hides conversations the server can list.
    // Rows archived by swipe or menu vanish at once and come back on Undo;
    // the server call only happens once the Undo window has closed.
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final tokens = KitTokens.of(context);
    final controller = widget.controller;
    final sessions = controller
        .sortedSessions()
        .where((session) => !_pendingArchive.contains(session.id))
        .toList();
    // One list, one order (UX plan 5.7; owner decision 2026-09-27, no state
    // sections): what needs me, what is running, what I pinned, what I did
    // recently. A conversation appears once, in the first group that fits: a
    // blocked or running pin returns among the pins as soon as it is
    // answered or finishes, because every group is cut from the same sorted
    // list.
    final blockers = <String, String>{
      for (final session in sessions) session.id: ?_blocker(session.id, l10n),
    };
    final attention = sessions
        .where((session) => blockers.containsKey(session.id))
        .toList();
    final active = sessions
        .where(
          (session) =>
              !blockers.containsKey(session.id) &&
              controller.busySessions.contains(session.id),
        )
        .toList();
    final pinned = sessions
        .where(
          (session) =>
              !blockers.containsKey(session.id) &&
              !controller.busySessions.contains(session.id) &&
              controller.isSessionPinned(session.id),
        )
        .toList();
    final recent = sessions
        .where(
          (session) =>
              !blockers.containsKey(session.id) &&
              !controller.busySessions.contains(session.id) &&
              !controller.isSessionPinned(session.id),
        )
        .toList();
    // A finished result nobody has looked at carries its mark in its own
    // row; the separate "Unreviewed work" card is gone (item 5).
    final acknowledged = controller.returnBriefAcknowledgement;
    ReturnBriefRun? unreviewed(Session session) =>
        blockers.containsKey(session.id)
        ? null
        : ReturnBrief.unreviewedRun(
            session,
            readStateKnown: controller.supportsSessionReadState,
            isUnread: controller.isSessionUnread,
            isBusy: controller.busySessions.contains,
            ack: acknowledged,
          );
    final archived = controller.archivedSessions();
    // The team's open tasks are conversations too (docs/design/team-
    // conversation-2026-09-26.md): what needs the person sorts with the
    // needs-you rows, the rest with the running rows, each with the team's
    // mark.
    final team = controller.orchestration;
    final teamTasks = team == null
        ? const <OrchestrationRun>[]
        : teamOpenTasks(team);
    final teamGated = team == null
        ? const <String>{}
        : teamGatedRuns(team.snapshot);
    final teamNeedsYou = [
      for (final run in teamTasks)
        if (teamGated.contains(run.id)) run,
    ];
    final teamRunning = [
      for (final run in teamTasks)
        if (!teamGated.contains(run.id)) run,
    ];
    Widget teamRow(OrchestrationRun run) => TeamTaskRow(
      key: ValueKey('team-work-${run.id}'),
      team: team!,
      run: run,
      onOpen: () => _openTeamTask(team, run.id),
    );
    final capabilities = controller.capabilities;
    final pinNudge = controller.nudges.activeFor(NudgeRegistry.workScope);
    _queuePinNudge(
      visible:
          TickerMode.valuesOf(context).enabled &&
          (ModalRoute.of(context)?.isCurrent ?? true),
      // Only with something to pin, a way to pin it, and no pin here yet:
      // someone who already pins has nothing to learn from the tip.
      canOffer:
          controller.canPinSessions &&
          controller.pinnedSessionIDs.isEmpty &&
          recent.isNotEmpty,
    );

    // A project is being restored (or picked for a fresh connection): the
    // header names it and the chooser waits. The chooser only appears once
    // that has finished and there really is no project (item 1).
    final restoring =
        capabilities.projectManagement &&
        controller.workspaceChoiceRequired &&
        _pendingDirectory != null;

    // No project folder yet (or an older build saved the server's home
    // folder): sessions cannot start until the user creates or opens one.
    // The chooser waits for the project list so an auto-opened project does
    // not flash it first, and it keeps the server-wide session finder so
    // earlier conversations stay reachable.
    if (capabilities.projectManagement &&
        controller.workspaceChoiceRequired &&
        !restoring &&
        (_projects != null || _projectError != null)) {
      // The chooser is a state of its own; a server that stops answering is
      // still said above it, in the same one status line.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkStatusLine(
            controller: controller,
            serverOnThisPhone: widget.serverOnThisPhone,
            onRestartServer: widget.onRestartServer,
          ),
          Expanded(child: _chooser(capabilities)),
        ],
      );
    }

    final partial =
        controller.hasMoreSessions ||
        controller.sessionsLoading ||
        controller.sessionsError != null;
    // Loading for the first time: nothing listed yet and something is on
    // its way. Skeleton rows stand in, and no empty or "load more" text
    // contradicts them (item 4).
    final firstLoad =
        sessions.isEmpty &&
        _pendingArchive.isEmpty &&
        controller.sessionsError == null &&
        (restoring ||
            controller.sessionsLoading ||
            controller.locationLoading ||
            controller.connectionLoading);
    // One bar for everything loading the first time (item 3).
    final loading =
        firstLoad ||
        restoring ||
        (capabilities.projectManagement &&
            _projects == null &&
            _projectError == null) ||
        controller.locationLoading ||
        controller.connectionLoading;
    // Teach only when the list is known to be empty. A partial or failed
    // load cannot claim "no conversations yet", and a row waiting out its
    // Undo window is hidden, not gone.
    final nothingYet =
        !partial &&
        !firstLoad &&
        sessions.isEmpty &&
        archived.isEmpty &&
        _pendingArchive.isEmpty;
    final headerDirectory = _headerDirectory;
    // Asked here so the chooser knows by the time New conversation is
    // tapped.
    _teamPossibleNow();
    final wide = KitScreen.showsDetail(context);
    // The conversation in the detail pane; gone once it is archived,
    // deleted or no longer listed.
    final selectedID = wide ? _selectedSessionID : null;
    final detailID =
        selectedID != null &&
            controller.sessionsById.containsKey(selectedID) &&
            !_pendingArchive.contains(selectedID)
        ? selectedID
        : null;

    Widget row(Session session, {bool busy = false, String? blocker}) =>
        _SessionRow(
          controller: controller,
          session: session,
          busy: busy,
          blocker: blocker,
          unreviewed: busy ? null : unreviewed(session),
          selected: session.id == detailID,
          onOpen: _openSession,
          onDetails: _openSessionContext,
          onReview: _review,
          onMarkReviewed: _markReviewed,
          onPin: _togglePin,
          onRename: _rename,
          onShare: _share,
          onUnshare: _unshare,
          onDelete: _delete,
          archive: capabilities.sessionArchive ? _archiveSwipe(session) : null,
          sharingAvailable: capabilities.sessionShare,
        );

    // The top of the one list, most urgent first: needs you (the team's
    // gated tasks too), running (the team's other open tasks too), pins.
    final head = <Widget>[
      for (final session in attention)
        KeyedSubtree(
          key: ValueKey('work-needs-you-${session.id}'),
          child: row(
            session,
            busy: controller.busySessions.contains(session.id),
            blocker: blockers[session.id],
          ),
        ),
      for (final run in teamNeedsYou) teamRow(run),
      for (final session in active)
        KeyedSubtree(
          key: ValueKey('work-running-${session.id}'),
          child: row(session, busy: true),
        ),
      for (final run in teamRunning) teamRow(run),
      for (final session in pinned)
        KeyedSubtree(
          key: ValueKey('work-pinned-${session.id}'),
          child: row(
            session,
            busy: controller.busySessions.contains(session.id),
          ),
        ),
    ];
    // The empty state only when the whole list is empty.
    final showEmpty = head.isEmpty && recent.isEmpty && !partial && !firstLoad;

    final notice = _notice;
    // No project on this server yet: the empty state says so and holds
    // the search itself.
    final noProjects =
        capabilities.projectManagement &&
        _projects?.isEmpty == true &&
        headerDirectory == null;
    final header = <Widget>[
      // Which project this is stays put while the list scrolls (UX plan
      // 5.7), and it is there from the first frame: the folder is known
      // before the project list is (item 2). A single chevron opens the
      // project sheet with the full folder path, switching and managing.
      if (capabilities.projectManagement && headerDirectory != null)
        _ProjectHeader(
          key: const ValueKey('current-project-entry'),
          // The phone server's folder of projects is where it starts, not
          // a project: say a project is still to be chosen.
          name: _isPhoneProjectsRoot(headerDirectory)
              ? l10n.e7WorkspaceChooseProject
              : _projectName(headerDirectory),
          // With no project yet there is nothing to describe or manage:
          // go straight to the list, where creating one comes first.
          onTap: _isPhoneProjectsRoot(headerDirectory)
              ? _openProjects
              : _openContextSheet,
        ),
      // Still context, not management: the conversation is running
      // somewhere other than the project root.
      if (capabilities.projectManagement && _hasExternalSessionDirectory)
        KitRow(
          key: const ValueKey('active-session-directory'),
          leading: KitRow.icon(context, AppIconography.nested),
          title: _basename(_selectedDirectory!),
          supporting: TextSpan(
            text: l10n.e7WorkspaceActiveDirectory(
              KitBidi.ltr(_selectedDirectory!),
            ),
          ),
          onTap: () => _openContextSheet(folder: _selectedDirectory),
        ),
      if (!capabilities.projectManagement &&
          controller.directory?.isNotEmpty == true)
        KitRow(
          key: const ValueKey('restricted-directory-context'),
          leading: KitRow.icon(context, AppIconography.files),
          title: _basename(controller.directory!),
          // A path reads left to right in any interface: isolate it.
          supporting: TextSpan(text: KitBidi.ltr(controller.directory!)),
          onTap: () => _openContextSheet(folder: controller.directory),
        ),
    ];

    final list = KitRefresh(
      onRefresh: _refreshWorkspace,
      child: DesktopScrollbarArea(
        builder: (scrollController) => CustomScrollView(
          controller: scrollController,
          key: const PageStorageKey('workspace-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. At most one status line, and only with something to
            // do (item 3, 6, 7).
            SliverToBoxAdapter(child: _statusLine(context, l10n)),
            // A failed act, said where the list is, until dismissed.
            if (notice != null)
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  tokens.gutter,
                  tokens.space2,
                  tokens.gutter,
                  tokens.space2,
                ),
                sliver: SliverToBoxAdapter(
                  child: KitNotice(
                    key: const ValueKey('work-notice'),
                    message: notice,
                    tone: AppStatusTone.failure,
                    icon: AppIconography.warning,
                    onDismiss: () => setState(() => _notice = null),
                    dismissLabel: l10n.workspaceDismissNotice,
                  ),
                ),
              ),
            if (noProjects)
              SliverToBoxAdapter(
                child: KitStateView(
                  size: KitStateSize.inline,
                  liveRegion: false,
                  icon: AppIconography.folders,
                  illustration: const StatesFolderScene(),
                  title: l10n.e7WorkspaceNoProjects,
                  body: capabilities.globalSessionSearch
                      ? l10n.e7WorkspaceNoProjectsSearch
                      : l10n.e7WorkspaceServerNoProjects,
                  tertiary: [
                    if (capabilities.globalSessionSearch)
                      KitAction(
                        label: l10n.workspaceSearchAllSessions,
                        onPressed: _openAllSessions,
                      ),
                  ],
                ),
              ),
            // A project this tab opened by itself, said once (P6.6).
            if (_defaultNotice case final said?)
              SliverPadding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: tokens.gutter,
                  vertical: tokens.space2,
                ),
                sliver: SliverToBoxAdapter(
                  // The only project has no other to offer; the header
                  // still opens the project sheet.
                  child: _defaultCanChange
                      ? KitNotice.offer(
                          key: const ValueKey('work-default-project'),
                          icon: AppIconography.folders,
                          message: said,
                          action: KitAction(
                            label: l10n.defaultProjectChange,
                            onPressed: () {
                              setState(() => _defaultNotice = null);
                              unawaited(_openProjects());
                            },
                          ),
                          dismissLabel: l10n.workspaceDismissNotice,
                          onDismiss: () =>
                              setState(() => _defaultNotice = null),
                        )
                      : KitNotice(
                          key: const ValueKey('work-default-project'),
                          icon: AppIconography.folders,
                          message: said,
                          dismissLabel: l10n.workspaceDismissNotice,
                          onDismiss: () =>
                              setState(() => _defaultNotice = null),
                        ),
                ),
              ),
            // The pin tip sits just above the list it is about.
            if (pinNudge != null)
              SliverPadding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: tokens.gutter,
                  vertical: tokens.space2,
                ),
                sliver: SliverToBoxAdapter(
                  child: KitNotice.offer(
                    key: ValueKey('nudge-${pinNudge.id.name}'),
                    icon: AppIconography.pin,
                    message: l10n.nudgePin,
                    action: KitAction(
                      label: l10n.e7GlossaryGotIt,
                      onPressed: () =>
                          unawaited(controller.nudges.dismiss(pinNudge.id)),
                    ),
                    dismissLabel: l10n.nudgeDismiss,
                    onDismiss: () =>
                        unawaited(controller.nudges.dismiss(pinNudge.id)),
                  ),
                ),
              ),
            // Ordered by urgency: what waits on the person (amber mark and
            // the words "Needs you"), then running work (spinner and
            // "Working"), then pins, then the rest newest first. The row's
            // mark and worded state carry the meaning, not a heading. The
            // urgent head moves gently as rows come and go (design
            // standard §10); the rest may be long, so it stays lazy.
            if (firstLoad)
              SliverToBoxAdapter(child: _firstLoadRows(l10n))
            else if (showEmpty)
              SliverToBoxAdapter(
                child: KitStateView(
                  key: ValueKey(
                    nothingYet ? 'work-empty-teaching' : 'work-empty-recent',
                  ),
                  size: KitStateSize.inline,
                  liveRegion: false,
                  icon: AppIconography.chat,
                  illustration: const StatesSheetScene(),
                  title: nothingYet
                      ? l10n.emptyTeachWorkTitle
                      : l10n.e7WorkspaceNoRecent,
                  body: nothingYet
                      ? l10n.emptyTeachWorkMessage
                      : controller.directory == null
                      ? l10n.e7WorkspaceChooseFolderToStart
                      : l10n.e7WorkspaceStartInWorkspace,
                  // No button here: the pinned New conversation is the
                  // one action that fills this list, and an empty Work
                  // tab keeps exactly one of them (workspace_hierarchy_test
                  // pins that).
                ),
              )
            else ...[
              if (head.isNotEmpty)
                SliverToBoxAdapter(child: KitAnimatedRows(children: head)),
              SliverList.builder(
                itemCount: recent.length,
                itemBuilder: (context, index) => row(recent[index]),
              ),
            ],
            // Older pages: the list pages itself as its end comes near
            // (target-ia §1.4), with skeletons while a page loads and a
            // failed page said in place. Built lazily, so a long list asks
            // for the next page only once it is scrolled to.
            if (OlderSessionsPager.showsFor(controller))
              SliverList.builder(
                itemCount: 1,
                itemBuilder: (context, _) =>
                    OlderSessionsPager(controller: controller),
              ),
            // One way to every other conversation (R3, R4): All
            // conversations spans every project on the server and holds the
            // Archived filter, so no separate archived row or menu repeats
            // it. The AI Team keeps its own door in Settings.
            if (capabilities.globalSessionSearch && !noProjects)
              SliverToBoxAdapter(
                child: KitRow(
                  key: const ValueKey('search-all-sessions'),
                  leading: KitRow.icon(context, AppIconography.searchList),
                  title: l10n.workspaceSearchAllSessions,
                  supporting: TextSpan(text: l10n.workspaceSearchAllDetail),
                  trailing: const KitChevron(),
                  onTap: _openAllSessions,
                ),
              ),
            // 5. Everything else going on: the other projects on this
            // server once each, then other servers with something
            // running or waiting (items 6 and 8).
            // The same gap as between the sections above (SectionLabel's
            // top): the panel's own label carries none.
            SliverPadding(
              padding: EdgeInsetsDirectional.only(top: tokens.sectionGap),
              sliver: SliverToBoxAdapter(
                child: OtherProjectsPanel(
                  controller: controller,
                  currentDirectory: headerDirectory,
                  onAllProjects: _openProjects,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: OtherServersPanel(controller: controller),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                key: const ValueKey('workspace-scroll-end'),
                height: tokens.space4,
              ),
            ),
          ],
        ),
      ),
    );

    // 6. New conversation, pinned below the list rather than over it, so
    // no row or header ever sits under it or under the tab bar: the list
    // ends where the pinned block begins (item 9, standard §1).
    final bottom = _QuickAskPill(
      creating: _creating,
      onTap: _creating || controller.workspaceChoiceRequired
          ? null
          : _newConversation,
    );

    if (!wide) {
      return KitScreen(
        header: header,
        // One bar for everything loading the first time (item 3).
        loading: loading,
        loadingLabel: l10n.workLoadingLabel,
        // Pull to refresh draws the brand's portal (design standard §10).
        body: list,
        bottom: bottom,
      );
    }
    // Expanded and wider (C37): the list at the start, the selected
    // conversation beside it instead of a pushed page.
    return KitScreen.twoPane(
      listPaneKey: const ValueKey('work-list-pane'),
      detailPaneKey: const ValueKey('work-detail-pane'),
      loading: loading,
      loadingLabel: l10n.workLoadingLabel,
      list: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...header,
          Expanded(child: list),
        ],
      ),
      detail: detailID == null
          ? null
          : ChatScreen(
              key: ValueKey('work-detail-$detailID'),
              sessionID: detailID,
            ),
      emptyDetail: KitStateView(
        key: const ValueKey('work-detail-empty'),
        icon: AppIconography.chat,
        liveRegion: false,
        title: l10n.workspaceDetailEmptyTitle,
        body: l10n.workspaceDetailEmptyBody,
      ),
      bottom: bottom,
    );
  }

  Widget _chooser(ServerCapabilities capabilities) {
    final controller = widget.controller;
    return _WorkspaceFolderChooser(
      notice: controller.locationNotice,
      server: controller.profile?.name,
      projectError: _projectError,
      canCreate: ProjectFolderActions.canCreate(controller),
      onCreate: _createProjectFolder,
      onOpen: _openProjectFolder,
      onBrowse: _openProjects,
      onSearchAll: capabilities.globalSessionSearch ? _openAllSessions : null,
      onRetry: _load,
    );
  }

  /// The project's name for [directory]: the catalog's when it lists the
  /// project, else the folder's own name.
  String _projectName(String directory) {
    final projects = _projects;
    final project = projects == null
        ? null
        : WorkspaceScreen.projectForDirectory(projects, directory);
    return project?.name ?? _basename(directory);
  }

  /// Placeholder rows while the list loads the first time. Once the server
  /// has not answered for [notAnsweringGrace] (the status line above says
  /// so, with its way out), they give way to the unplugged drawing: rows
  /// that never fill in would say "loading" forever.
  Widget _firstLoadRows(AppLocalizations l10n) {
    final controller = widget.controller;
    final lost = WorkStatusLine.serverLost(controller);
    return GraceTimer(
      waiting: lost,
      restartKey: controller.connectionAttemptRevision,
      builder: (context, overdue) {
        final failed =
            controller.status == StreamStatus.disconnected &&
            controller.connectionError != null &&
            !controller.manualReconnectInProgress;
        if (!lost || !(overdue || failed)) return const KitSkeletonRows();
        return KitStateView(
          key: const ValueKey('work-not-answering-list'),
          size: KitStateSize.inline,
          liveRegion: false,
          icon: AppIconography.cloudOff,
          illustration: const StatesUnpluggedScene(),
          title: l10n.workNotAnsweringListTitle,
          body: l10n.workNotAnsweringListBody,
        );
      },
    );
  }

  /// The one status line, in priority order: server not answering (inside
  /// [WorkStatusLine]), the project list, the waiting requests, a leftover
  /// process on the phone, a location notice.
  Widget _statusLine(BuildContext context, AppLocalizations l10n) {
    final controller = widget.controller;
    final capabilities = controller.capabilities;
    Widget line(WorkRunawayNotice? runaway) {
      final stale =
          controller.isConnected &&
          (controller.permissionsError != null ||
              controller.questionsError != null ||
              (capabilities.forms && controller.formsError != null));
      final notice = controller.locationNotice;
      return WorkStatusLine(
        controller: controller,
        serverOnThisPhone: widget.serverOnThisPhone,
        onRestartServer: widget.onRestartServer,
        others: [
          // A failed load is a failure, never the "needs you" amber
          // (LOOK-4).
          if (capabilities.projectManagement && _projectError != null)
            WorkStatus(
              id: 'projects',
              icon: AppIconography.warning,
              tone: AppStatusTone.failure,
              message: l10n.workspaceProjectListUnavailable,
              action: KitAction(
                key: const ValueKey('work-status-projects-retry'),
                label: l10n.workspaceRetryProjects,
                onPressed: _load,
              ),
              more: [
                if (capabilities.globalSessionSearch)
                  KitAction(
                    label: l10n.workspaceSearchAllSessions,
                    onPressed: _openAllSessions,
                  ),
              ],
            ),
          if (capabilities.projectManagement && _workspaceError != null)
            WorkStatus(
              id: 'workspaces',
              icon: AppIconography.warning,
              tone: AppStatusTone.failure,
              message: _workspaceError!,
              action: KitAction(
                label: l10n.commonRetry,
                onPressed: _loadWorkspaces,
              ),
            ),
          if (stale)
            WorkStatus(
              id: 'stale',
              message: l10n.workStale,
              action: KitAction(
                key: const ValueKey('work-status-stale-refresh'),
                label: l10n.workRefresh,
                onPressed: () => unawaited(_refreshRequests()),
              ),
            ),
          runaway?.status(l10n),
          if (notice != null)
            WorkStatus(
              id: 'notice',
              message: notice,
              messageKey: const ValueKey('location-recovery-notice'),
              onDismiss: controller.dismissLocationNotice,
            ),
        ],
      );
    }

    final debugWatcher = WorkspaceScreen.debugRunawayWatcher;
    if (debugWatcher != null) {
      return debugWatcher(context, (context, notice) => line(notice));
    }
    // A leftover helper burning CPU on the phone's own server is watched
    // only where there is a phone server to watch (TEAM-305).
    if (platformCapabilities.supportsTermux &&
        TermuxBridge.managesServerUrl(controller.profile?.baseUrl)) {
      return TermuxRunawayWatcher(builder: (context, notice) => line(notice));
    }
    return line(null);
  }

  Future<void> _refreshRequests() async {
    final controller = widget.controller;
    await Future.wait<void>([
      controller.refreshPendingPermissions(),
      controller.refreshPendingQuestions(),
      if (controller.capabilities.forms) controller.refreshPendingForms(),
    ]);
  }

  /// Opens [session]: beside the list from expanded, else as a page.
  void _openSession(Session session) {
    if (KitScreen.showsDetail(context)) {
      setState(() => _selectedSessionID = session.id);
      return;
    }
    Navigator.of(context).pushNamed('/chat/${session.id}');
  }

  /// Asks once per server whether it can run a team; the answer shows or
  /// hides the Solo · Team choice.
  bool _teamPossibleNow() {
    final profile = widget.controller.profile;
    if (profile == null) return false;
    if (widget.controller.orchestration != null) return true;
    final asked = '${profile.id}|${profile.baseUrl}';
    if (_teamAskedFor != asked) {
      _teamAskedFor = asked;
      _teamPossible = false;
      unawaited(() async {
        final possible = await teamPossibleOn(profile);
        if (!mounted || _teamAskedFor != asked) return;
        if (possible != _teamPossible) setState(() => _teamPossible = possible);
      }());
    }
    return _teamPossible;
  }

  /// What New conversation can offer here: Team where a team can run,
  /// a separate copy where the server makes worktrees of this project, and
  /// the project's other cloud machines.
  NewConversationOptions _newConversationOptions() {
    final project = _isolatedTaskProject;
    final current = _selectedProject;
    return NewConversationOptions(
      project:
          current?.name ??
          (_selectedDirectory == null ? null : _basename(_selectedDirectory!)),
      team: _teamPossibleNow(),
      teamOn: widget.controller.orchestration != null,
      separateCopy: project != null,
      clouds: [
        for (final workspace in _workspaces)
          if (workspace.id != _selectedWorkspaceID)
            NewConversationCloud(
              id: workspace.id,
              name: _workspaceName(workspace),
              status: workspace.status,
            ),
      ],
    );
  }

  /// The one New conversation: asks how to start where there is more than
  /// one way, remembers the answer for this server, and starts it. Every
  /// start ends in a conversation (or, for a team that is off, the team's
  /// off state, where it is set up).
  Future<void> _newConversation() async {
    if (_creating) return;
    final options = _newConversationOptions();
    if (options.onlySolo) {
      await _createSession();
      return;
    }
    final profile = widget.controller.profile;
    final prefs = widget.controller.store.prefs;
    final choice = await showNewConversationSheet(
      context,
      options: options,
      remembered: profile == null
          ? null
          : NewConversationMemory.read(prefs, profile.id),
    );
    if (!mounted || choice == null) return;
    if (profile != null) {
      await NewConversationMemory.remember(prefs, profile.id, choice);
    }
    if (!mounted) return;
    switch (choice.kind) {
      case NewConversationKind.solo:
        await _createSession();
      case NewConversationKind.team:
        await _createTeamTask();
      case NewConversationKind.separateCopy:
        await _startIsolatedTask();
      case NewConversationKind.cloud:
        await _createOnCloud(choice.workspaceId!);
    }
  }

  /// Moves to the cloud machine and starts the conversation there.
  Future<void> _createOnCloud(String workspaceId) async {
    WorkspaceInfo? target;
    for (final workspace in _workspaces) {
      if (workspace.id == workspaceId) target = workspace;
    }
    if (target == null) return;
    await _selectWorkspace(target);
    if (!mounted) return;
    // The move failed (and said so): nothing starts in the wrong place.
    if (widget.controller.locationError != null ||
        _selectedWorkspaceID != workspaceId) {
      return;
    }
    await _createSession();
  }

  /// New team task: the team's conversation when it is on, else its intro
  /// ("Set it up" for this kind of server).
  Future<void> _createTeamTask() async {
    final team = widget.controller.orchestration;
    if (team == null) {
      await openTeamIntro(context, widget.controller);
    } else {
      await TeamConversation.start(context, team);
    }
  }

  void _openTeamTask(OrchestrationController team, String runId) =>
      unawaited(TeamConversation.open(context, team, runId: runId));

  Future<void> _openAllSessions() => pushKitPage<void>(
    context,
    (_) => GlobalSessionsScreen(controller: widget.controller),
  );

  Future<void> _createProjectFolder() async {
    final path = await ProjectFolderActions.createFolder(
      context,
      widget.controller,
      suggestedName: ProjectFolderActions.suggestedName(_projects),
    );
    if (path != null && mounted) await _load();
  }

  Future<void> _openProjectFolder() async {
    final path = await ProjectFolderActions.openFolder(
      context,
      widget.controller,
    );
    if (path != null && mounted) await _load();
  }

  Future<void> _openProjects() async {
    await pushKitPage<bool>(
      context,
      (_) => ProjectsScreen(
        controller: widget.controller,
        selectedProjectID: _selectedProjectID,
      ),
    );
    if (mounted) await _load();
  }

  /// One project switchboard (audit UX-P0-02; map `workspace-context-sheet`,
  /// proposal "fix"): titled with the project and the server it is on, it
  /// switches project, starts a new one, chooses where it runs ("Runs on",
  /// the current one marked in words), and keeps the folder path under
  /// Details, last and collapsed. The project's tools live on the Project
  /// tab (manage-project merged into project-hub, slice-P3.11a).
  ///
  /// Opened from a folder row ([folder] set: a conversation running outside
  /// the project root, or a server that cannot manage projects), Details
  /// shows that folder, open, instead of a separate folder dialog (map
  /// `workspace-directory-details-dialog`, merged here).
  Future<void> _openContextSheet({String? folder}) async {
    final controller = widget.controller;
    final l10n = _l10n(context);
    final manages = controller.capabilities.projectManagement;
    final title = !manages && folder != null
        ? _basename(folder)
        : _selectedProject?.name ??
              (_selectedDirectory == null
                  ? l10n.e7WorkspaceNoProjectSelected
                  : _basename(_selectedDirectory!));
    final server = controller.profile?.name;
    final workspace = _selectedWorkspace;
    final subtitle = [
      if (server != null && server.isNotEmpty)
        l10n.workspaceContextOn(KitBidi.auto(server)),
      if (workspace != null) KitBidi.auto(_workspaceName(workspace)),
    ].join(' · ');
    final directory = folder ?? _contextDirectory;
    final canCreate = manages && ProjectFolderActions.canCreate(controller);
    final choice = await showKitSheet<_ContextChoice>(
      context,
      title: title,
      subtitle: subtitle.isEmpty ? null : subtitle,
      icon: AppIconography.files,
      sheetKey: const ValueKey('workspace-context-sheet'),
      body: (sheetContext) {
        void pick(_ContextChoice choice) =>
            Navigator.of(sheetContext).pop(choice);
        Widget runsOn({
          required Key key,
          required IconData icon,
          required String name,
          required bool current,
          String? path,
          required _ContextChoice choice,
        }) => KitRow(
          key: key,
          leading: KitRowIcon(icon, current: current),
          title: name,
          selected: current,
          supporting: current || path != null
              ? TextSpan(
                  children: [
                    if (current)
                      kitCurrentSpan(
                        sheetContext,
                        l10n.workspaceContextCurrent,
                      ),
                    if (path != null && path.isNotEmpty)
                      TextSpan(text: KitBidi.ltr(path)),
                  ],
                )
              : null,
          onTap: () => pick(choice),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!controller.supportsSessionReadState)
              KitNotice(
                message: l10n.returnBriefStatusUnknown,
                icon: AppIconography.info,
                liveRegion: false,
              ),
            if (manages)
              KitRowGroup(
                children: [
                  KitRow(
                    key: const ValueKey('context-switch-project'),
                    leading: KitRow.icon(sheetContext, AppIconography.swap),
                    title: l10n.e7WorkspaceSwitchProject,
                    supporting: TextSpan(
                      text: l10n.e7WorkspaceOpenProjectCount(
                        _projects?.length ?? 0,
                      ),
                    ),
                    trailing: const KitChevron(),
                    onTap: () => pick(const _ContextChoice.switchProject()),
                  ),
                  if (canCreate)
                    KitRow(
                      key: const ValueKey('context-new-project'),
                      leading: KitRow.icon(
                        sheetContext,
                        AppIconography.folderAdd,
                      ),
                      title: l10n.workspaceContextNewProject,
                      trailing: const KitChevron(),
                      onTap: () => pick(const _ContextChoice.newProject()),
                    ),
                ],
              ),
            if (_workspaces.isNotEmpty)
              KitRowGroup(
                label: l10n.workspaceContextRunsOn,
                children: [
                  runsOn(
                    key: const ValueKey('workspace-option-local'),
                    icon: AppIconography.computer,
                    name: l10n.e7WorkspaceThisComputer,
                    current: _selectedWorkspaceID == null,
                    choice: const _ContextChoice.workspace(null),
                  ),
                  for (final workspace in _workspaces)
                    runsOn(
                      key: ValueKey('workspace-option-${workspace.id}'),
                      icon: AppIconography.cloud,
                      name: _workspaceName(workspace),
                      current: workspace.id == _selectedWorkspaceID,
                      path: workspace.directory,
                      choice: _ContextChoice.workspace(workspace),
                    ),
                ],
              ),
            KitDetailsFold(
              foldKey: const ValueKey('workspace-context-details'),
              initiallyExpanded: folder != null,
              values: [
                KitTechnicalValue(
                  l10n.workspaceContextFolder,
                  directory?.isNotEmpty == true
                      ? directory!
                      : l10n.e7WorkspaceNoFolder,
                  copyable: directory?.isNotEmpty == true,
                ),
              ],
            ),
          ],
        );
      },
    );
    if (!mounted || choice == null) return;
    if (choice.newProject) {
      await _createProjectFolder();
      return;
    }
    if (choice.switchProject) {
      await _openProjects();
      return;
    }
    await _selectWorkspace(choice.workspace);
  }

  String _titleOf(Session session) {
    final l10n = _l10n(context);
    return presentedSessionTitle(
      session,
      fallback: l10n.globalSessionsUntitled,
      l10n: l10n,
    );
  }

  /// Says a failed act once, above the list (§4.8), until dismissed.
  void _say(Object error) {
    if (!mounted) return;
    setState(() => _notice = error is String ? error : productErrorText(error));
  }

  /// A conversation's facts, from its row's menu: Conversation context,
  /// where the folder and shared link sit under Details beside how full
  /// the conversation is (map `workspace-session-details-sheet`, merged
  /// into session-context in slice-P3.11a).
  Future<void> _openSessionContext(Session session) => pushKitPage<void>(
    context,
    (_) => SessionContextScreen(
      controller: widget.controller,
      sessionID: session.id,
    ),
  );

  /// The finished run [session] stands for, if it is still unreviewed.
  ReturnBriefRun? _unreviewedRun(Session session) {
    final controller = widget.controller;
    return ReturnBrief.unreviewedRun(
      session,
      readStateKnown: controller.supportsSessionReadState,
      isUnread: controller.isSessionUnread,
      isBusy: controller.busySessions.contains,
      ack: controller.returnBriefAcknowledgement,
    );
  }

  /// Review results: the run's result screen, retired if the project or
  /// server changes under it. Looking is not acknowledging; the mark stays
  /// until the conversation is opened or marked reviewed.
  Future<void> _review(Session session) async {
    final controller = widget.controller;
    final scope = controller.returnBriefScope;
    bool current() =>
        mounted &&
        controller.returnBriefScope == scope &&
        controller.isProfileReadable(scope.$1);
    final routes = RequestRoutes(changes: controller, isPending: current);
    try {
      await pushKitPage<void>(context, (context) {
        routes.own(ModalRoute.of(context));
        return RunResultScreen(controller: controller, sessionID: session.id);
      });
    } finally {
      routes.close();
    }
  }

  /// Mark as reviewed: this device stops flagging the run. The conversation
  /// stays unread on the server and nothing is answered, exactly what the
  /// old card's "Dismiss shown items" did for one row.
  Future<void> _markReviewed(Session session) async {
    final controller = widget.controller;
    final run = _unreviewedRun(session);
    if (run == null) return;
    final failed = _l10n(context).workMarkReviewedFailed;
    try {
      await controller.dismissReturnBrief(
        ReturnBrief.single(run),
        expectedScope: controller.returnBriefScope,
      );
    } catch (_) {
      _say(failed);
    }
  }

  Future<void> _togglePin(Session session) async {
    final controller = widget.controller;
    final failed = _l10n(context).sessionPinFailed;
    try {
      await controller.setSessionPinned(
        session.id,
        !controller.isSessionPinned(session.id),
        locationRevision: controller.locationRevision,
      );
    } catch (_) {
      _say(failed);
    }
  }

  /// Archive, from the swipe and from the menu alike (one path, P3.12):
  /// the row goes at once, Undo stands for the window, and only then is
  /// the server told. Archiving has no server-side reverse, so the undo
  /// window *is* the safety net (DATA-11 a, b).
  KitSwipeAction _archiveSwipe(Session session) {
    final l10n = _l10n(context);
    final title = _titleOf(session);
    return KitSwipeAction(
      id: ValueKey('session-dismiss-${session.id}'),
      label: l10n.e7WorkspaceArchive,
      icon: AppIconography.archive,
      undoMessage: l10n.e7WorkspaceArchivedToast(title),
      onAct: () async {
        if (!mounted || _pendingArchive.contains(session.id)) return false;
        setState(() {
          _pendingArchive.add(session.id);
          if (_selectedSessionID == session.id) _selectedSessionID = null;
        });
        return true;
      },
      onUndo: () {
        if (mounted) setState(() => _pendingArchive.remove(session.id));
      },
      // Worded now: the commit may run after Work has gone (the window
      // closes, a new Undo arrives, the route pops or the app pauses).
      onCommit: () =>
          _commitArchive(session, l10n.workspaceArchiveFailed(title)),
    );
  }

  Future<void> _commitArchive(Session session, String failed) async {
    final controller = widget.controller;
    try {
      final repository = await controller.prepareActionRepository();
      if (repository == null) throw ProductException(failed);
      await repository.archiveSession(session.id);
      await controller.refreshSessions();
    } catch (_) {
      _say(failed);
    } finally {
      if (mounted) setState(() => _pendingArchive.remove(session.id));
    }
  }

  Future<ServerOperationsGateway> _requireActionRepository() async {
    final failureMessage = _l10n(context).e7WorkspaceReconnectingShortly;
    final repository = await widget.controller.prepareActionRepository();
    if (repository != null) return repository;
    throw ProductException(failureMessage);
  }

  /// Rename: one field; a failure stays in the dialog under the field.
  Future<void> _rename(Session session) async {
    final l10n = _l10n(context);
    final controller = widget.controller;
    final renamed = await showKitInputDialog(
      context,
      title: l10n.e7WorkspaceRenameSession,
      label: l10n.e7WorkspaceTitle,
      confirmLabel: l10n.fileSave,
      initial: session.title ?? '',
      dialogKey: const ValueKey('workspace-rename-dialog'),
      onSubmit: (value) async {
        final title = value.trim();
        if (title.isEmpty) return null;
        try {
          await controller.renameSession(session.id, title);
          return null;
        } catch (error) {
          return productErrorText(error);
        }
      },
    );
    if (renamed != null && mounted) await controller.refreshSessions();
  }

  /// Share: says who can see it; the link is copied once the server has
  /// made it. A failure stays in the confirmation (DATA-14).
  Future<void> _share(Session session) async {
    final l10n = _l10n(context);
    String? link;
    final shared = await showKitConfirm(
      context,
      icon: AppIconography.globe,
      title: l10n.e7WorkspaceShareConfirm,
      body: l10n.e7WorkspaceShareDetail(_titleOf(session)),
      consequences: [l10n.workspaceShareCopiesLink],
      confirmLabel: l10n.e7WorkspaceShareSession,
      sheetKey: const ValueKey('workspace-share-confirm'),
      confirmKey: const ValueKey('workspace-share-confirm-button'),
      action: () async {
        final repository = await _requireActionRepository();
        final url = await repository.shareSession(session.id);
        if (url == null || url.isEmpty) {
          throw ProductException(l10n.e7WorkspaceNoShareLink);
        }
        link = url;
      },
    );
    final url = link;
    if (!shared || url == null || !mounted) return;
    await KitCopy.copy(
      context,
      url,
      announcement: l10n.e7WorkspaceShareCopied,
      redact: false,
    );
    await widget.controller.refreshSessions();
  }

  Future<void> _unshare(Session session) async {
    if (!await confirmStopSharing(context)) return;
    try {
      final repository = await _requireActionRepository();
      await repository.unshareSession(session.id);
      await widget.controller.refreshSessions();
    } catch (error) {
      _say(error);
    }
  }

  /// Delete: nobody can bring it back, so it is confirmed (DATA-11); a
  /// shared conversation also says its link stops working. A failure stays
  /// in the confirmation (DATA-14).
  Future<void> _delete(Session session) async {
    final l10n = _l10n(context);
    final controller = widget.controller;
    final deleted = await showKitConfirm(
      context,
      kind: KitConfirmKind.destructive,
      icon: AppIconography.delete,
      title: l10n.e7WorkspaceDeleteConfirm,
      body: l10n.e7WorkspaceDeleteDetail(_titleOf(session)),
      consequences: [
        if (session.shareUrl != null) l10n.workspaceDeleteSharedLink,
      ],
      confirmLabel: l10n.promptStashDelete,
      sheetKey: const ValueKey('workspace-delete-confirm'),
      confirmKey: const ValueKey('workspace-delete-confirm-button'),
      action: () => controller.deleteSession(session.id),
    );
    if (!deleted || !mounted) return;
    if (_selectedSessionID == session.id) {
      setState(() => _selectedSessionID = null);
    }
    await controller.refreshSessions();
  }

  @override
  void dispose() {
    _loadGeneration++;
    widget.controller.removeListener(_changed);
    widget.controller.nudges.removeListener(_nudgesChanged);
    final nudges = widget.controller.nudges;
    // Deferred: listeners must not rebuild while the tree is being torn down.
    scheduleMicrotask(() => nudges.releaseScope(NudgeRegistry.workScope));
    super.dispose();
  }
}

/// What the context sheet was dismissed with: switch project, start a new
/// one, or move to a workspace (`null` meaning the project's own local
/// checkout).
class _ContextChoice {
  const _ContextChoice.switchProject()
    : workspace = null,
      switchProject = true,
      newProject = false;
  const _ContextChoice.newProject()
    : workspace = null,
      switchProject = false,
      newProject = true;
  const _ContextChoice.workspace(this.workspace)
    : switchProject = false,
      newProject = false;

  final WorkspaceInfo? workspace;
  final bool switchProject;
  final bool newProject;
}

/// A section's count, in figures that line up.
class _SessionRow extends StatelessWidget {
  final ConnectionController controller;
  final Session session;
  final bool busy;

  /// What the run is blocked on (permission, question, form), already
  /// worded for the row; null when nothing is waiting.
  final String? blocker;

  /// The finished, not yet reviewed run this row stands for: it carries the
  /// Unreviewed mark, and its menu offers Review results and Mark as
  /// reviewed.
  final ReturnBriefRun? unreviewed;

  /// The row open in the detail pane (expanded and wider).
  final bool selected;

  final ValueChanged<Session> onOpen;
  final ValueChanged<Session> onDetails;
  final ValueChanged<Session> onReview;
  final ValueChanged<Session> onMarkReviewed;
  final ValueChanged<Session> onPin;
  final ValueChanged<Session> onRename;
  final ValueChanged<Session> onShare;
  final ValueChanged<Session> onUnshare;
  final ValueChanged<Session> onDelete;

  /// The row's one swipe, and its twin in the menu; null where this server
  /// cannot archive. Delete is never on a swipe (KIT-29): it confirms.
  final KitSwipeAction? archive;

  /// §7 rows 10–12: menus list possible actions only.
  final bool sharingAvailable;

  const _SessionRow({
    required this.controller,
    required this.session,
    required this.busy,
    this.blocker,
    this.unreviewed,
    this.selected = false,
    required this.onOpen,
    required this.onDetails,
    required this.onReview,
    required this.onMarkReviewed,
    required this.onPin,
    required this.onRename,
    required this.onShare,
    required this.onUnshare,
    required this.onDelete,
    this.archive,
    this.sharingAvailable = true,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final updated = session.time?.updated ?? session.time?.created;
    final l10n = _l10n(context);
    final pinned = controller.isSessionPinned(session.id);
    final needsAttention = blocker != null;
    final isUnreviewed = !needsAttention && !busy && unreviewed != null;
    // The facts line wraps instead of cutting: one ellipsized line lost the
    // time and diff at 390dp and even "Working" at 320dp/2.5x. The status
    // comes first, so whatever is cut is the least essential.
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.25;
    final shared = session.shareUrl != null;
    // A leading mark of one width for every state, so titles line up.
    Widget lead(Widget child) => SizedBox.square(
      dimension: tokens.iconTileSize,
      child: Center(child: child),
    );
    final leading = needsAttention
        ? lead(
            KitNeedsYou.mark(
              key: ValueKey('session-attention-icon-${session.id}'),
            ),
          )
        : busy
        ? lead(
            const KitTaskMark(
              key: ValueKey('session-busy-dot'),
              state: KitTaskState.working,
            ),
          )
        : KitRow.icon(
            context,
            pinned ? AppIconography.pin : AppIconography.chat,
          );
    // The blocker outranks "Working": a run waiting on an answer is not
    // making progress.
    final status = needsAttention
        ? null
        : session.compactingSince != null
        ? l10n.e7WorkspaceCompacting
        : busy
        ? l10n.globalSessionsWorking
        : isUnreviewed
        ? l10n.workUnreviewed
        : null;
    final rest = [
      ?blocker,
      ?status,
      if (updated != null) relativeTimeLabel(updated, l10n: l10n),
      // The folder only earns its place when it differs from the open
      // project, e.g. a worktree; otherwise every row would repeat the
      // header.
      if (session.directory?.isNotEmpty == true &&
          !ConnectionController.sameDirectoryPath(
            session.directory,
            controller.directory,
          ))
        _basename(session.directory!),
    ];
    // The state word leads (STATE-9): "Needs you · Permission needed",
    // "Working", "Unreviewed" at label weight, then the muted facts.
    final supporting = TextSpan(
      children: [
        if (needsAttention) KitNeedsYou.span(context),
        if (rest.isNotEmpty && (needsAttention || status != null))
          TextSpan(
            text: rest.first,
            style: KitText.styleOf(
              context,
              KitTextRole.label,
              tone: KitTextTone.primary,
            ),
          ),
        if (rest.isNotEmpty)
          TextSpan(
            text: (needsAttention || status != null)
                ? rest.skip(1).map((fact) => ' · $fact').join()
                : rest.join(' · '),
          ),
      ],
    );

    return KitRow(
      // A kit row (design standard §6) whose title and facts may wrap: a
      // conversation title is the person's own words.
      key: ValueKey('session-row-${session.id}'),
      titleMaxLines: 2,
      supportingMaxLines: largeText ? 3 : 2,
      supportingKey: ValueKey('session-subtitle-${session.id}'),
      leading: leading,
      title: presentedSessionTitle(
        session,
        fallback: l10n.globalSessionsUntitled,
        l10n: l10n,
      ),
      supporting: rest.isEmpty && !needsAttention ? null : supporting,
      selected: selected,
      onTap: () => onOpen(session),
      swipe: archive,
      menuLabel: l10n.globalSessionsActions,
      // Every rare act on long-press, right-click, Shift+F10 and as a
      // semantic action (KIT-28); Archive joins from the swipe, Delete is
      // last and confirms.
      menu: [
        if (isUnreviewed) ...[
          KitMenuItem(
            key: ValueKey('session-review-${session.id}'),
            label: l10n.returnBriefReview,
            icon: AppIconography.guide,
            group: 'review',
            onSelected: () => onReview(session),
          ),
          KitMenuItem(
            key: ValueKey('session-mark-reviewed-${session.id}'),
            label: l10n.workMarkReviewed,
            icon: AppIconography.check,
            group: 'review',
            onSelected: () => onMarkReviewed(session),
          ),
        ],
        KitMenuItem(
          key: const ValueKey('session-menu-open'),
          label: l10n.globalSessionsOpen,
          icon: AppIconography.externalLink,
          onSelected: () => onOpen(session),
        ),
        KitMenuItem(
          key: const ValueKey('session-menu-details'),
          // Opens Conversation context, which holds the folder and link.
          label: l10n.e7SharedSessionContext,
          icon: AppIconography.info,
          onSelected: () => onDetails(session),
        ),
        if (controller.canPinSessions)
          KitMenuItem(
            key: const ValueKey('session-menu-pin'),
            label: pinned ? l10n.sessionUnpin : l10n.sessionPin,
            icon: AppIconography.pin,
            onSelected: () => onPin(session),
          ),
        KitMenuItem(
          key: const ValueKey('session-menu-rename'),
          label: l10n.e7WorkspaceRename,
          icon: AppIconography.edit,
          onSelected: () => onRename(session),
        ),
        if (sharingAvailable)
          KitMenuItem(
            key: const ValueKey('session-menu-share'),
            label: shared ? l10n.e7WorkspaceStopSharing : l10n.e7WorkspaceShare,
            icon: AppIconography.globe,
            onSelected: () => shared ? onUnshare(session) : onShare(session),
          ),
        KitMenuItem(
          key: const ValueKey('session-menu-delete'),
          label: l10n.promptStashDelete,
          icon: AppIconography.delete,
          destructive: true,
          onSelected: () => onDelete(session),
        ),
      ],
    );
  }

  static String _basename(String path) {
    final parts = path.split('/').where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? path : parts.last;
  }
}

/// One project entry opens the folder, workspace and management details.
class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({super.key, required this.name, required this.onTap});
  final String name;
  final VoidCallback onTap;

  /// The roles the name may use, largest first: a long single word steps
  /// down instead of breaking mid-word.
  static const _nameRungs = [
    KitTextRole.largeTitle,
    KitTextRole.title,
    KitTextRole.headline,
  ];

  /// Segments a line breaker will not split: runs of non-space, non-hyphen
  /// characters, keeping a trailing hyphen with the run it ends.
  static final _segment = RegExp(r'[^\s\-]+-?');

  static KitTextRole nameRole(
    BuildContext context,
    String name, {
    required double maxWidth,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final segments = _segment
        .allMatches(name)
        .map((match) => match.group(0)!)
        .toList();
    final painter = TextPainter(textDirection: direction, textScaler: scaler);
    try {
      for (final role in _nameRungs) {
        final style = KitText.styleOf(context, role);
        var widest = 0.0;
        for (final segment in segments) {
          painter
            ..text = TextSpan(text: segment, style: style)
            ..layout();
          if (painter.width > widest) widest = painter.width;
        }
        if (widest <= maxWidth) return role;
      }
    } finally {
      painter.dispose();
    }
    return _nameRungs.last;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final glyph = KitIconSize.large.logical;
    return LayoutBuilder(
      builder: (context, constraints) => KitTappable(
        tappableKey: const ValueKey('current-project-context'),
        tooltip: _l10n(context).workspaceManageProjectHint,
        surface: KitSurfaceLevel.ground,
        shape: KitShape.square,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsetsDirectional.all(tokens.gutter),
          child: Row(
            children: [
              Flexible(
                child: KitText(
                  name,
                  key: const ValueKey('current-project-name'),
                  role: nameRole(
                    context,
                    name,
                    maxWidth:
                        constraints.maxWidth -
                        tokens.gutter * 2 -
                        tokens.space2 -
                        glyph,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: tokens.space2),
              const KitIcon(
                AppIconography.chevronDown,
                tone: KitTextTone.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// New conversation, docked to the workspace: the one primary. How to
/// start (Solo · Team · a separate copy · a cloud machine) is asked by its
/// chooser, never by controls around the button.
class _QuickAskPill extends StatelessWidget {
  const _QuickAskPill({required this.creating, required this.onTap});

  final bool creating;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    // Two lines before an ellipsis: the primary action's name is never the
    // thing cut.
    return KeyedSubtree(
      key: const ValueKey('workspace-quick-ask'),
      child: KitButton.primary(
        key: const ValueKey('workspace-new'),
        onPressed: onTap,
        working: creating,
        icon: AppIconography.add,
        label: l10n.workspaceNewSession,
      ),
    );
  }
}

/// Compact usage labels for a session row: cost to the cent, and the diff
/// summary as "+120 −34 · 6 files". Empty when the server sent neither.
List<String> sessionUsageLabels(Session session, {AppLocalizations? l10n}) {
  final labels = <String>[];
  final cost = session.cost;
  if (cost != null && cost >= 0.005) labels.add('\$${cost.toStringAsFixed(2)}');
  final summary = session.summary;
  if (summary != null && (summary.additions > 0 || summary.deletions > 0)) {
    labels.add('+${summary.additions} −${summary.deletions}');
    if (summary.files > 0) {
      labels.add(
        l10n?.e7WorkspaceFileCount(summary.files) ??
            '${summary.files} ${summary.files == 1 ? 'file' : 'files'}',
      );
    }
  }
  return labels;
}

/// Blocking state shown while the connection has no usable project folder
/// (map `workspace-folder-chooser`, proposal "fix"). It replaces the session
/// list and the quick-ask pill: nothing can run in the server's home
/// folder, so the only ways forward are creating a folder (managed server)
/// or opening an existing one. A project list that failed to load says so
/// in its title and offers Try again first.
class _WorkspaceFolderChooser extends StatelessWidget {
  const _WorkspaceFolderChooser({
    required this.notice,
    required this.server,
    required this.projectError,
    required this.canCreate,
    required this.onCreate,
    required this.onOpen,
    required this.onBrowse,
    required this.onSearchAll,
    required this.onRetry,
  });

  final String? notice;

  /// The saved server's name, for the one line under the title.
  final String? server;
  final String? projectError;
  final bool canCreate;
  final VoidCallback onCreate;
  final VoidCallback onOpen;
  final VoidCallback onBrowse;
  final VoidCallback? onSearchAll;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    final create = KitAction(
      key: const ValueKey('workspace-create-folder'),
      icon: AppIconography.folderAdd,
      label: l10n.projectFolderCreate,
      onPressed: onCreate,
    );
    final open = KitAction(
      key: const ValueKey('workspace-open-folder'),
      icon: AppIconography.folderOpen,
      label: l10n.workspaceChooserEnterPath,
      onPressed: onOpen,
    );
    final browse = KitAction(
      key: const ValueKey('workspace-browse-projects'),
      label: l10n.workspaceChooserRecentProjects,
      onPressed: onBrowse,
    );
    final searchAll = onSearchAll == null
        ? null
        : KitAction(
            key: const ValueKey('workspace-chooser-search-all'),
            label: l10n.workspaceSearchAllSessions,
            onPressed: onSearchAll!,
          );
    final error = projectError;
    if (error != null) {
      return KitStateView(
        key: const ValueKey('workspace-folder-chooser'),
        icon: AppIconography.warning,
        tone: AppStatusTone.failure,
        // The project list that could not load is the unplugged drawing,
        // like every other load failure.
        illustration: const StatesUnpluggedScene(),
        titleKey: const ValueKey('workspace-chooser-error-title'),
        title: l10n.workspaceChooserLoadFailedTitle,
        body: notice ?? l10n.workspaceChooserLoadFailedBody,
        bodyKey: notice == null
            ? null
            : const ValueKey('location-recovery-notice'),
        primary: KitAction(
          key: const ValueKey('workspace-chooser-retry'),
          label: l10n.workspaceRetryProjects,
          onPressed: onRetry,
        ),
        secondary: canCreate ? create : open,
        tertiary: [if (canCreate) open, browse, ?searchAll],
        detailNotes: [if (!canCreate) l10n.projectFolderNoCreateHint],
        details: error,
      );
    }
    return KitStateView(
      key: const ValueKey('workspace-folder-chooser'),
      icon: AppIconography.folders,
      // A place with nothing in it yet.
      illustration: const StatesFolderScene(),
      title: l10n.projectFolderChooserTitle,
      // Why a folder, not the title again (slice-P3.11a).
      body:
          notice ??
          (server?.trim().isNotEmpty == true
              ? l10n.workspaceChooserBody(KitBidi.auto(server!.trim()))
              : l10n.e7WorkspaceChooseFolderToStart),
      bodyKey: notice == null
          ? null
          : const ValueKey('location-recovery-notice'),
      primary: canCreate ? create : open,
      secondary: canCreate ? open : null,
      tertiary: [browse, ?searchAll],
      // Why there is no Create here is the technical part: under Details,
      // below the actions.
      detailNotes: [if (!canCreate) l10n.projectFolderNoCreateHint],
    );
  }
}

AppLocalizations _l10n(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(Localizations.localeOf(context));
