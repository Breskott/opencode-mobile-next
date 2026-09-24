import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/product_repository.dart';
import '../../domain/return_brief.dart';
import '../../domain/workspace_paths.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../../state/connection.dart';
import '../../state/nudges.dart';
import '../../state/orchestration.dart';
import '../desktop/context_menu.dart';
import '../desktop/desktop_interaction.dart';
import '../navigation/chat_route.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/safety_confirms.dart';
import '../widgets/nudge_card.dart';
import '../widgets/other_servers_panel.dart';
import '../widgets/other_projects_panel.dart';
import '../kit/kit.dart';
import '../widgets/product_states.dart' show productErrorText, showProductError;
import '../widgets/relative_time.dart';
import '../widgets/session_title.dart';
import '../widgets/request_routes.dart';
import '../widgets/session_inventory_footer.dart';
import '../widgets/team_card.dart';
import '../widgets/termux_phone_tools.dart';
import '../widgets/work_status_line.dart';
import '../../termux/bridge.dart';
import 'global_sessions_screen.dart';
import 'isolated_task_sheet.dart';
import 'manage_project_screen.dart';
import 'project_folder_actions.dart';
import 'projects_screen.dart';
import 'run_result_screen.dart';
import 'settings_screen.dart';
import 'team/team_home_screen.dart';
import '../app_theme.dart';
import '../../domain/team_directories.dart';

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
  final Set<String> _pendingArchive = {};

  /// A project picked on a fresh connection is being opened.
  bool _selectingInitial = false;

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
          final usable = projects.where(
            (project) =>
                !isProtectedWorkspaceDirectory(project.directory) &&
                !isAiTeamDirectory(project.directory),
          );
          final retained = usable.where(
            (project) => project.id == _selectedProjectID,
          );
          final selected = retained.isNotEmpty
              ? retained.first
              : usable.isNotEmpty
              ? usable.first
              : null;
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

  /// The compact context line under the project name: which workspace and
  /// which directory this screen's sessions will run in.
  String get _contextSubtitle {
    final parts = <String>[];
    final workspace = _selectedWorkspace;
    if (workspace != null) {
      parts.add(
        workspace.branch?.isNotEmpty == true
            ? workspace.branch!
            : workspace.name,
      );
    }
    final directory =
        widget.controller.directory ??
        _selectedWorkspace?.directory ??
        _selectedDirectory ??
        _selectedProject?.directory;
    parts.add(
      directory?.isNotEmpty == true
          ? directory!
          : _l10n(context).e7WorkspaceNoFolder,
    );
    return parts.join(' · ');
  }

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
    final error = widget.controller.locationError;
    if (error != null) _showError(error);
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
        _showError(
          _l10n(context).e7WorkspaceCreateFailed(productErrorText(error)),
        );
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
    // status line, what needs you, this project's conversations, the other
    // projects once each, and New conversation docked below the list.
    // Project discovery and session inventory are independent: a pending
    // or failed catalog never hides conversations the server can list.
    // Rows swiped to Archive vanish immediately and come back on Undo; the
    // server call only happens once the snackbar has gone.
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final controller = widget.controller;
    final sessions = controller
        .sortedSessions()
        .where((session) => !_pendingArchive.contains(session.id))
        .toList();
    // One order for every list (UX plan 5.7): what needs me, what is running,
    // what I pinned, what I did recently. A conversation appears once, in the
    // first section that fits: a blocked or running pin returns to Pinned as
    // soon as it is answered or finishes, because every section is cut from
    // the same sorted list.
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
    // Undo snackbar is hidden, not gone.
    final nothingYet =
        !partial &&
        !firstLoad &&
        sessions.isEmpty &&
        archived.isEmpty &&
        _pendingArchive.isEmpty;
    final showEmpty = recent.isEmpty && !partial && !firstLoad;
    final headerDirectory = _headerDirectory;

    Widget row(Session session, {bool busy = false, String? blocker}) =>
        _SessionRow(
          controller: controller,
          session: session,
          busy: busy,
          blocker: blocker,
          unreviewed: busy ? null : unreviewed(session),
          onOpen: _openSession,
          onAction: _sessionAction,
          sharingAvailable: capabilities.sessionShare,
          archiveAvailable: capabilities.sessionArchive,
        );

    return KitScreen(
      header: [
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
                ? _l10n(context).e7WorkspaceChooseProject
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
          ListTile(
            key: const ValueKey('active-session-directory'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            minLeadingWidth: 32,
            horizontalTitleGap: 12,
            leading: const SizedBox.square(
              dimension: 32,
              child: Icon(AppIconography.nested, size: 24),
            ),
            title: Text(_basename(_selectedDirectory!)),
            subtitle: Text(
              _l10n(context).e7WorkspaceActiveDirectory(_selectedDirectory!),
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _showDirectoryDetails(_selectedDirectory!),
          ),
        if (!capabilities.projectManagement &&
            controller.directory?.isNotEmpty == true)
          ListTile(
            key: const ValueKey('restricted-directory-context'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            minLeadingWidth: 32,
            horizontalTitleGap: 12,
            leading: const SizedBox.square(
              dimension: 32,
              child: Icon(AppIconography.files, size: 24),
            ),
            title: Text(_basename(controller.directory!)),
            subtitle: Text(
              controller.directory!,
              textDirection: TextDirection.ltr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onTap: () => _showDirectoryDetails(controller.directory!),
          ),
      ],
      // One bar for everything loading the first time (item 3).
      loading: loading,
      loadingLabel: l10n.workLoadingLabel,
      body: RefreshIndicator(
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
              if (capabilities.projectManagement &&
                  _projects?.isEmpty == true &&
                  headerDirectory == null)
                SliverToBoxAdapter(
                  child: KitStateView(
                    size: KitStateSize.inline,
                    liveRegion: false,
                    icon: AppIconography.folders,
                    title: _l10n(context).e7WorkspaceNoProjects,
                    body: capabilities.globalSessionSearch
                        ? _l10n(context).e7WorkspaceNoProjectsSearch
                        : _l10n(context).e7WorkspaceServerNoProjects,
                    tertiary: [
                      if (capabilities.globalSessionSearch)
                        KitAction(
                          label: _l10n(context).workspaceSearchAllSessions,
                          onPressed: _openAllSessions,
                        ),
                    ],
                  ),
                ),
              // 2. Work waiting on the user, first: the persona's top
              // job is seeing what needs them, and a blocked run reads
              // as "Working" anywhere else.
              if (attention.isNotEmpty)
                SliverToBoxAdapter(
                  child: SectionLabel(
                    _l10n(context).e7WorkspaceNeedsYou,
                    key: const ValueKey('workspace-needs-you'),
                    trailing: Text('${attention.length}'),
                  ),
                ),
              if (attention.isNotEmpty)
                SliverList.builder(
                  itemCount: attention.length,
                  itemBuilder: (context, index) => row(
                    attention[index],
                    busy: controller.busySessions.contains(attention[index].id),
                    blocker: blockers[attention[index].id],
                  ),
                ),
              // 3. Running work, with its live state; then pins.
              if (active.isNotEmpty)
                SliverToBoxAdapter(
                  child: SectionLabel(
                    l10n.workRunning,
                    key: const ValueKey('workspace-running'),
                    trailing: Text('${active.length}'),
                  ),
                ),
              if (active.isNotEmpty)
                SliverList.builder(
                  itemCount: active.length,
                  itemBuilder: (context, index) =>
                      row(active[index], busy: true),
                ),
              if (pinned.isNotEmpty)
                SliverToBoxAdapter(
                  child: SectionLabel(
                    l10n.sessionPinned,
                    trailing: Text('${pinned.length}'),
                  ),
                ),
              if (pinned.isNotEmpty)
                SliverList.builder(
                  itemCount: pinned.length,
                  itemBuilder: (context, index) => row(
                    pinned[index],
                    busy: controller.busySessions.contains(pinned[index].id),
                  ),
                ),
              // The pin tip sits on the list it is about.
              if (pinNudge != null)
                SliverToBoxAdapter(
                  child: NudgeCard(
                    id: pinNudge.id,
                    icon: AppIconography.pin,
                    message: l10n.nudgePin,
                    actionLabel: l10n.e7GlossaryGotIt,
                    dismissTooltip: l10n.nudgeDismiss,
                    onAction: () =>
                        unawaited(controller.nudges.dismiss(pinNudge.id)),
                    onDismiss: () =>
                        unawaited(controller.nudges.dismiss(pinNudge.id)),
                  ),
                ),
              // 4. Recent sessions. Search stays a one-tap icon; the
              // occasional actions sit behind one labelled menu so the
              // caption keeps its width on a phone at large text.
              SliverToBoxAdapter(
                child: SectionLabel(
                  _l10n(context).e7WorkspaceRecentSessions,
                  trailing: _SectionActions(
                    controller: controller,
                    onSearch: capabilities.globalSessionSearch
                        ? _openAllSessions
                        : null,
                    onOpenBackgroundSettings:
                        platformCapabilities.supportsBackgroundService
                        ? _openBackgroundSettings
                        : null,
                  ),
                ),
              ),
              if (firstLoad)
                const SliverToBoxAdapter(child: KitSkeletonRows())
              else if (showEmpty)
                SliverToBoxAdapter(
                  child: KitStateView(
                    key: ValueKey(
                      nothingYet ? 'work-empty-teaching' : 'work-empty-recent',
                    ),
                    size: KitStateSize.inline,
                    liveRegion: false,
                    icon: AppIconography.chat,
                    title: nothingYet
                        ? l10n.emptyTeachWorkTitle
                        : pinned.isNotEmpty
                        ? l10n.sessionsNoOtherRecent
                        : _l10n(context).e7WorkspaceNoRecent,
                    body: nothingYet
                        ? l10n.emptyTeachWorkMessage
                        : controller.directory == null
                        ? _l10n(context).e7WorkspaceChooseFolderToStart
                        : _l10n(context).e7WorkspaceStartInWorkspace,
                    // No button here: the pinned New conversation is the
                    // one action that fills this list, and an empty Work
                    // tab keeps exactly one of them (workspace_hierarchy_test
                    // pins that).
                  ),
                )
              else
                SliverList.builder(
                  itemCount: recent.length,
                  itemBuilder: (context, index) => row(recent[index]),
                ),
              // Older pages: skeletons while one loads, and the footer
              // (Load more, or an error with Try again) only when
              // nothing is loading.
              if (controller.sessionsLoadingMore)
                const SliverToBoxAdapter(child: KitSkeletonRows(count: 2))
              else if (!controller.sessionsLoading)
                SliverToBoxAdapter(
                  child: SessionInventoryFooter(controller: controller),
                ),
              // The AI Team plugin's card follows the person's own
              // conversations (UX plan 5.5, 5.7); what its agents need
              // from the person already reaches Inbox. It is not in the
              // tree at all while the profile has no plugin config.
              if (controller.orchestration case final team?)
                SliverToBoxAdapter(
                  child: TeamCard(
                    controller: team,
                    onOpen: () => _openTeamHome(team),
                  ),
                ),
              if (archived.isNotEmpty)
                SliverToBoxAdapter(
                  child: ListTile(
                    key: const ValueKey('workspace-archived'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    minLeadingWidth: 32,
                    horizontalTitleGap: 12,
                    leading: const SizedBox.square(
                      dimension: 32,
                      child: Icon(AppIconography.archive, size: 24),
                    ),
                    title: Text(_l10n(context).e7WorkspaceArchivedSessions),
                    // The footer owns partial-inventory truth. A count
                    // here would suggest every archived one was known.
                    subtitle: partial
                        ? null
                        : Text(
                            _l10n(
                              context,
                            ).e7WorkspaceArchivedCount(archived.length),
                          ),
                    trailing: const Icon(AppIconography.chevronRight),
                    onTap: _showArchived,
                  ),
                ),
              // 5. Everything else going on: the other projects on this
              // server once each, then other servers with something
              // running or waiting (items 6 and 8).
              SliverToBoxAdapter(
                child: OtherProjectsPanel(
                  controller: controller,
                  currentDirectory: headerDirectory,
                  onAllProjects: _openProjects,
                ),
              ),
              SliverToBoxAdapter(
                child: OtherServersPanel(controller: controller),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(
                  key: ValueKey('workspace-scroll-end'),
                  height: 16,
                ),
              ),
            ],
          ),
        ),
      ),
      // 6. New conversation, pinned below the list rather than over it, so
      // no row or header ever sits under it or under the tab bar: the list
      // ends where the pinned block begins (item 9, standard §1).
      bottom: _QuickAskPill(
        creating: _creating,
        onTap: _creating || controller.workspaceChoiceRequired
            ? null
            : _createSession,
        onIsolatedTask: _isolatedTaskProject == null
            ? null
            : _startIsolatedTask,
        isolatedTaskLabel: l10n.isolatedTaskAction,
      ),
    );
  }

  Widget _chooser(ServerCapabilities capabilities) {
    final controller = widget.controller;
    return _WorkspaceFolderChooser(
      notice: controller.locationNotice,
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
          if (capabilities.projectManagement && _projectError != null)
            WorkStatus(
              id: 'projects',
              icon: AppIconography.warning,
              tone: AppStatusTone.attention,
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
              tone: AppStatusTone.attention,
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

  Future<void> _showDirectoryDetails(String directory) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(_basename(directory)),
      content: SingleChildScrollView(
        child: SelectableText(directory, textDirection: TextDirection.ltr),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    ),
  );

  void _openSession(Session session) {
    Navigator.of(context).pushNamed('/chat/${session.id}');
  }

  void _openTeamHome(OrchestrationController team) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => TeamHomeScreen(controller: team)),
    );
  }

  void _openBackgroundSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            NotificationsSettingsScreen(controller: widget.controller),
      ),
    );
  }

  Future<void> _openAllSessions() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => GlobalSessionsScreen(controller: widget.controller),
    ),
  );

  Future<void> _createProjectFolder() async {
    final path = await ProjectFolderActions.createFolder(
      context,
      widget.controller,
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
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProjectsScreen(
          controller: widget.controller,
          selectedProjectID: _selectedProjectID,
        ),
      ),
    );
    if (mounted) await _load();
  }

  /// One coherent context sheet (audit UX-P0-02): project switching and
  /// workspace selection live together instead of a project row plus a
  /// separate strip of horizontal workspace chips.
  Future<void> _openContextSheet() async {
    final choice = await showModalBottomSheet<_ContextChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          key: const ValueKey('workspace-context-sheet'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const Icon(AppIconography.files),
                title: Text(
                  _selectedProject?.name ??
                      (_selectedDirectory == null
                          ? _l10n(context).e7WorkspaceNoProjectSelected
                          : _basename(_selectedDirectory!)),
                ),
                subtitle: SelectableText(
                  _contextSubtitle,
                  textDirection: _selectedDirectory == null
                      ? null
                      : TextDirection.ltr,
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
              ),
              const Divider(height: 1),
              if (!widget.controller.supportsSessionReadState)
                ListTile(
                  leading: const Icon(AppIconography.info),
                  title: Text(_l10n(context).returnBriefStatusUnknown),
                ),
              ListTile(
                key: const ValueKey('context-switch-project'),
                leading: const Icon(AppIconography.swap),
                title: Text(_l10n(context).e7WorkspaceSwitchProject),
                subtitle: Text(
                  _l10n(
                    context,
                  ).e7WorkspaceOpenProjectCount(_projects?.length ?? 0),
                ),
                trailing: const Icon(AppIconography.chevronRight),
                onTap: () => Navigator.of(
                  sheetContext,
                ).pop(const _ContextChoice.switchProject()),
              ),
              if (ManageProjectScreen.isAvailable(
                widget.controller.capabilities,
              ))
                ListTile(
                  key: const ValueKey('manage-project-entry'),
                  leading: const Icon(AppIconography.settings),
                  title: Text(_l10n(context).workspaceManageProject),
                  trailing: const Icon(AppIconography.chevronRight),
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(const _ContextChoice.manageProject()),
                ),
              if (_workspaces.isNotEmpty) ...[
                SectionLabel(_l10n(context).e7WorkspaceWorkspace),
                ListTile(
                  key: const ValueKey('workspace-option-local'),
                  leading: const Icon(AppIconography.computer),
                  title: Text(_l10n(context).e7WorkspaceThisComputer),
                  trailing: _selectedWorkspaceID == null
                      ? const Icon(AppIconography.check)
                      : null,
                  selected: _selectedWorkspaceID == null,
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(const _ContextChoice.workspace(null)),
                ),
                for (final workspace in _workspaces)
                  ListTile(
                    key: ValueKey('workspace-option-${workspace.id}'),
                    leading: const Icon(AppIconography.cloud),
                    title: Text(
                      workspace.branch?.isNotEmpty == true
                          ? workspace.branch!
                          : workspace.name,
                    ),
                    subtitle: Text(
                      workspace.directory ?? '',
                      textDirection: TextDirection.ltr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: workspace.id == _selectedWorkspaceID
                        ? const Icon(AppIconography.check)
                        : null,
                    selected: workspace.id == _selectedWorkspaceID,
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_ContextChoice.workspace(workspace)),
                  ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice.manageProject) {
      await _openManageProject();
      return;
    }
    if (choice.switchProject) {
      await _openProjects();
      return;
    }
    await _selectWorkspace(choice.workspace);
  }

  Future<void> _openManageProject() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ManageProjectScreen(
          controller: widget.controller,
          project: _selectedProject,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _sessionAction(String action, Session session) async {
    final failureMessage = _l10n(context).e7WorkspaceNoShareLink;
    try {
      switch (action) {
        case 'details':
          await showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            isScrollControlled: true,
            builder: (context) => SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      presentedSessionTitle(
                        session,
                        fallback: _l10n(context).globalSessionsUntitled,
                        l10n: _l10n(context),
                      ),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    if (session.directory?.isNotEmpty == true)
                      SelectableText(
                        session.directory!,
                        textDirection: TextDirection.ltr,
                      ),
                    for (final label in sessionUsageLabels(
                      session,
                      l10n: _l10n(context),
                    ))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(label),
                      ),
                    if (session.shareUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SelectableText(
                          _l10n(
                            context,
                          ).e7WorkspaceSharedUrl(session.shareUrl!),
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
          return;
        case 'review':
          await _review(session);
          return;
        case 'reviewed':
          await _markReviewed(session);
          return;
        case 'rename':
          await _rename(session);
          break;
        case 'share':
          if (!await _confirmShare(session)) return;
          final shareRepository = await _requireActionRepository();
          final url = await shareRepository.shareSession(session.id);
          if (url == null || url.isEmpty) {
            throw ProductException(failureMessage);
          }
          await Clipboard.setData(ClipboardData(text: url));
          if (mounted) _showMessage(_l10n(context).e7WorkspaceShareCopied);
          break;
        case 'unshare':
          if (!await confirmStopSharing(context)) return;
          final unshareRepository = await _requireActionRepository();
          await unshareRepository.unshareSession(session.id);
          if (mounted) _showMessage(_l10n(context).e7WorkspaceUnshared);
          break;
        case 'archive':
          if (!await _confirmArchive(session)) return;
          final archiveRepository = await _requireActionRepository();
          await archiveRepository.archiveSession(session.id);
          break;
        case 'swipe-archive':
          await _archiveWithUndo(session);
          return;
        case 'delete':
          if (!await _confirmDelete(session)) return;
          await widget.controller.deleteSession(session.id);
          break;
      }
      await widget.controller.refreshSessions();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

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
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) {
            routes.own(ModalRoute.of(context));
            return RunResultScreen(
              controller: controller,
              sessionID: session.id,
            );
          },
        ),
      );
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
      if (mounted) _showMessage(failed);
    }
  }

  /// Swipe-to-archive: hide the row at once, offer Undo for the snackbar's
  /// lifetime, and only then tell the server. Archiving has no server-side
  /// reverse, so the undo window *is* the safety net.
  Future<void> _archiveWithUndo(Session session) async {
    if (_pendingArchive.contains(session.id)) return;
    setState(() => _pendingArchive.add(session.id));
    final title = presentedSessionTitle(
      session,
      fallback: _l10n(context).globalSessionsUntitled,
      l10n: _l10n(context),
    );
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final snackBar = messenger.showSnackBar(
      SnackBar(
        key: ValueKey('archive-undo-${session.id}'),
        content: Text(_l10n(context).e7WorkspaceArchivedToast(title)),
        duration: const Duration(seconds: 5),
        // Material keeps a snackbar with an action open until it is acted
        // on; here the timeout *is* the commit, so it must run out.
        persist: false,
        action: SnackBarAction(
          label: _l10n(context).commonUndo,
          onPressed: () => messenger.hideCurrentSnackBar(
            reason: SnackBarClosedReason.action,
          ),
        ),
      ),
    );
    final reason = await snackBar.closed;
    if (!mounted) return;
    if (reason == SnackBarClosedReason.action) {
      setState(() => _pendingArchive.remove(session.id));
      return;
    }
    try {
      final archiveRepository = await _requireActionRepository();
      await archiveRepository.archiveSession(session.id);
      await widget.controller.refreshSessions();
    } catch (error) {
      if (mounted) _showError(error);
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

  Future<void> _rename(Session session) async {
    final controller = TextEditingController(text: session.title ?? '');
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_l10n(context).e7WorkspaceRenameSession),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: _l10n(context).e7WorkspaceTitle,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_l10n(context).projectFolderCancel),
          ),
          KitButton.primary(
            expand: false,
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            label: _l10n(context).fileSave,
          ),
        ],
      ),
    );
    controller.dispose();
    if (title?.isNotEmpty == true) {
      await widget.controller.renameSession(session.id, title!);
    }
  }

  Future<bool> _confirmArchive(Session session) => showConfirmSheet(
    context,
    icon: AppIconography.archive,
    title: _l10n(context).e7WorkspaceArchiveConfirm,
    message: _l10n(context).e7WorkspaceArchiveDetail(
      presentedSessionTitle(
        session,
        fallback: _l10n(context).globalSessionsUntitled,
        l10n: _l10n(context),
      ),
    ),
    confirmLabel: _l10n(context).e7WorkspaceArchive,
  );

  Future<bool> _confirmShare(Session session) => showConfirmSheet(
    context,
    icon: AppIconography.globe,
    title: _l10n(context).e7WorkspaceShareConfirm,
    message: _l10n(context).e7WorkspaceShareDetail(
      presentedSessionTitle(
        session,
        fallback: _l10n(context).globalSessionsUntitled,
        l10n: _l10n(context),
      ),
    ),
    confirmLabel: _l10n(context).e7WorkspaceShareSession,
  );

  Future<bool> _confirmDelete(Session session) => showConfirmSheet(
    context,
    icon: AppIconography.delete,
    title: _l10n(context).e7WorkspaceDeleteConfirm,
    message: _l10n(context).e7WorkspaceDeleteDetail(
      presentedSessionTitle(
        session,
        fallback: _l10n(context).globalSessionsUntitled,
        l10n: _l10n(context),
      ),
    ),
    confirmLabel: _l10n(context).promptStashDelete,
    destructive: true,
  );

  /// The pinned v1 HTTP schema accepts only numeric archive timestamps; zero
  /// remains stored rather than clearing the SQL archive filter. V2 has no
  /// archive-write endpoint. Do not invent an unarchive request here. See
  /// docs/verification/session-pins-and-unarchive.md for the upstream evidence.
  void _showArchived() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => ListenableBuilder(
        listenable: widget.controller,
        builder: (sheetContext, _) {
          final sessions = widget.controller.archivedSessions();
          final theme = Theme.of(sheetContext);
          return SafeArea(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sessions.length + 1,
              itemBuilder: (context, index) {
                if (index == sessions.length) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sessions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            lookupAppLocalizations(
                              Localizations.localeOf(context),
                            ).sessionsNoLoadedArchived,
                          ),
                        ),
                      SessionInventoryFooter(controller: widget.controller),
                    ],
                  );
                }
                final session = sessions[index];
                final title = presentedSessionTitle(
                  session,
                  fallback: _l10n(context).globalSessionsUntitled,
                  l10n: _l10n(context),
                );
                void run(String action) {
                  Navigator.pop(sheetContext);
                  unawaited(_sessionAction(action, session));
                }

                return ContextMenuRegion(
                  actions: () => [
                    ContextMenuAction(
                      label: _l10n(context).globalSessionsOpen,
                      icon: AppIconography.externalLink,
                      onSelected: () {
                        Navigator.pop(sheetContext);
                        _openSession(session);
                      },
                    ),
                    ContextMenuAction(
                      label: _l10n(context).promptStashDelete,
                      icon: AppIconography.delete,
                      destructive: true,
                      onSelected: () => run('delete'),
                    ),
                  ],
                  child: ListTile(
                    key: ValueKey('archived-session-${session.id}'),
                    leading: const Icon(AppIconography.package, size: 21),
                    title: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      session.directory ?? '',
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: PopupMenuButton<String>(
                      key: ValueKey('archived-session-actions-${session.id}'),
                      tooltip: _l10n(context).e7WorkspaceArchivedActions,
                      onSelected: run,
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'rename',
                          child: Text(_l10n(context).e7WorkspaceRename),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            _l10n(context).promptStashDelete,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openSession(session);
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(Object error) => showProductError(context, error);

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

/// What the context sheet was dismissed with: switch project, or move to a
/// workspace (`null` meaning the project's own local checkout).
class _ContextChoice {
  const _ContextChoice.switchProject()
    : workspace = null,
      switchProject = true,
      manageProject = false;
  const _ContextChoice.manageProject()
    : workspace = null,
      switchProject = false,
      manageProject = true;
  const _ContextChoice.workspace(this.workspace)
    : switchProject = false,
      manageProject = false;

  final WorkspaceInfo? workspace;
  final bool switchProject;
  final bool manageProject;
}

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
  final ValueChanged<Session> onOpen;
  final Future<void> Function(String, Session) onAction;

  /// §7 rows 10–12: menus list possible actions only.
  final bool sharingAvailable;
  final bool archiveAvailable;

  const _SessionRow({
    required this.controller,
    required this.session,
    required this.busy,
    this.blocker,
    this.unreviewed,
    required this.onOpen,
    required this.onAction,
    this.sharingAvailable = true,
    this.archiveAvailable = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final updated = session.time?.updated ?? session.time?.created;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final pinned = controller.isSessionPinned(session.id);
    final needsAttention = blocker != null;
    final isUnreviewed = !needsAttention && !busy && unreviewed != null;
    final location = controller.locationRevision;
    // The facts line wraps instead of cutting: one ellipsized line lost the
    // time and diff at 390dp and even "Working" at 320dp/2.5x. The status
    // comes first, so whatever is cut is the least essential.
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
    Future<void> togglePin() async {
      try {
        await controller.setSessionPinned(
          session.id,
          !pinned,
          locationRevision: location,
        );
      } catch (_) {
        if (context.mounted) showProductError(context, l10n.sessionPinFailed);
      }
    }

    final row = Dismissible(
      key: ValueKey('session-dismiss-${session.id}'),
      direction: DismissDirection.endToStart,
      // Swipe archives (with Undo) wherever the server can archive; delete
      // stays behind the menu's confirm. Either way this resolves false: the
      // parent removes or refreshes the row, so a cancel simply snaps back.
      confirmDismiss: (_) async {
        await onAction(archiveAvailable ? 'swipe-archive' : 'delete', session);
        return false;
      },
      background: archiveAvailable
          ? const _SwipeArchiveBackground()
          : const SwipeDeleteBackground(),
      child: ListTile(
        minTileHeight: 64,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minLeadingWidth: 32,
        horizontalTitleGap: 12,
        leading: SizedBox.square(
          dimension: 32,
          child: needsAttention
              ? Icon(
                  key: ValueKey('session-attention-icon-${session.id}'),
                  AppIconography.notificationImportant,
                  size: 21,
                  color: AppTheme.statusColor(theme, AppStatusTone.attention),
                )
              : busy
              ? const _BreathingDot()
              : Icon(
                  pinned ? AppIconography.pin : AppIconography.chat,
                  size: 21,
                  semanticLabel: pinned ? l10n.sessionPinned : null,
                ),
        ),
        title: Text(
          presentedSessionTitle(
            session,
            fallback: _l10n(context).globalSessionsUntitled,
            l10n: _l10n(context),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: _SessionRowSubtitle(
          key: ValueKey('session-subtitle-${session.id}'),
          // The blocker outranks "Working": a run waiting on an answer is
          // not making progress, and the colour says so. A finished result
          // nobody has looked at says Unreviewed.
          status: needsAttention
              ? blocker
              : session.compactingSince != null
              ? _l10n(context).e7WorkspaceCompacting
              : busy
              ? _l10n(context).globalSessionsWorking
              : isUnreviewed
              ? l10n.workUnreviewed
              : null,
          statusColor: needsAttention
              ? AppTheme.statusColor(theme, AppStatusTone.attention)
              : isUnreviewed
              ? theme.colorScheme.primary
              : null,
          maxLines: largeText ? 3 : 2,
          rest: [
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
          ],
        ),
        trailing: PopupMenuButton<String>(
          tooltip: _l10n(context).globalSessionsActions,
          onSelected: (value) =>
              value == 'pin' ? togglePin() : onAction(value, session),
          itemBuilder: (context) => [
            if (isUnreviewed) ...[
              PopupMenuItem(
                key: ValueKey('session-review-${session.id}'),
                value: 'review',
                child: Text(l10n.returnBriefReview),
              ),
              PopupMenuItem(
                key: ValueKey('session-mark-reviewed-${session.id}'),
                value: 'reviewed',
                child: Text(l10n.workMarkReviewed),
              ),
              const PopupMenuDivider(),
            ],
            PopupMenuItem(value: 'details', child: Text(l10n.chatUiDetails)),
            if (controller.canPinSessions)
              PopupMenuItem(
                value: 'pin',
                child: Text(pinned ? l10n.sessionUnpin : l10n.sessionPin),
              ),
            PopupMenuItem(
              value: 'rename',
              child: Text(_l10n(context).e7WorkspaceRename),
            ),
            if (sharingAvailable)
              PopupMenuItem(
                value: session.shareUrl == null ? 'share' : 'unshare',
                child: Text(
                  session.shareUrl == null
                      ? _l10n(context).e7WorkspaceShare
                      : _l10n(context).e7WorkspaceStopSharing,
                ),
              ),
            if (archiveAvailable)
              PopupMenuItem(
                value: 'archive',
                child: Text(_l10n(context).e7WorkspaceArchive),
              ),
            PopupMenuItem(
              value: 'delete',
              child: Text(
                _l10n(context).promptStashDelete,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ),
        onTap: () => onOpen(session),
      ),
    );
    // The same entries the trailing overflow menu lists, on the button a
    // mouse user actually reaches for. A pass-through off desktop.
    return ContextMenuRegion(
      actions: () => [
        if (isUnreviewed) ...[
          ContextMenuAction(
            label: l10n.returnBriefReview,
            icon: AppIconography.guide,
            onSelected: () => unawaited(onAction('review', session)),
          ),
          ContextMenuAction(
            label: l10n.workMarkReviewed,
            icon: AppIconography.check,
            onSelected: () => unawaited(onAction('reviewed', session)),
          ),
        ],
        ContextMenuAction(
          label: l10n.chatUiDetails,
          icon: AppIconography.info,
          onSelected: () => unawaited(onAction('details', session)),
        ),
        if (controller.canPinSessions)
          ContextMenuAction(
            label: pinned ? l10n.sessionUnpin : l10n.sessionPin,
            icon: pinned ? AppIconography.pin : AppIconography.pin,
            onSelected: () => unawaited(togglePin()),
          ),
        ContextMenuAction(
          menuKey: const ValueKey('session-menu-open'),
          label: _l10n(context).globalSessionsOpen,
          icon: AppIconography.externalLink,
          onSelected: () => onOpen(session),
        ),
        ContextMenuAction(
          menuKey: const ValueKey('session-menu-rename'),
          label: _l10n(context).e7WorkspaceRename,
          icon: AppIconography.edit,
          onSelected: () => unawaited(onAction('rename', session)),
        ),
        if (sharingAvailable)
          ContextMenuAction(
            menuKey: const ValueKey('session-menu-share'),
            label: session.shareUrl == null
                ? _l10n(context).e7WorkspaceShare
                : _l10n(context).e7WorkspaceStopSharing,
            icon: AppIconography.globe,
            onSelected: () => unawaited(
              onAction(session.shareUrl == null ? 'share' : 'unshare', session),
            ),
          ),
        if (archiveAvailable)
          ContextMenuAction(
            menuKey: const ValueKey('session-menu-archive'),
            label: _l10n(context).e7WorkspaceArchive,
            icon: AppIconography.archive,
            onSelected: () => unawaited(onAction('archive', session)),
          ),
        ContextMenuAction(
          menuKey: const ValueKey('session-menu-delete'),
          label: _l10n(context).promptStashDelete,
          icon: AppIconography.delete,
          destructive: true,
          onSelected: () => unawaited(onAction('delete', session)),
        ),
      ],
      child: row,
    );
  }

  static String _basename(String path) {
    final parts = path.split('/').where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? path : parts.last;
  }
}

/// The row subtitle: an optional status word first (tinted when it asks for
/// attention), then the usual dot-separated facts, wrapping to [maxLines].
class _SessionRowSubtitle extends StatelessWidget {
  const _SessionRowSubtitle({
    super.key,
    required this.status,
    required this.statusColor,
    required this.rest,
    this.maxLines = 2,
  });

  final String? status;
  final Color? statusColor;
  final List<String> rest;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final tail = rest.join(' · ');
    return Text.rich(
      TextSpan(
        children: [
          if (status case final status?)
            TextSpan(
              text: status,
              style: statusColor == null
                  ? null
                  : TextStyle(color: statusColor, fontWeight: FontWeight.w600),
            ),
          if (status != null && tail.isNotEmpty) const TextSpan(text: ' · '),
          if (tail.isNotEmpty) TextSpan(text: tail),
        ],
      ),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// One project entry opens the folder, workspace and management details.
class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({super.key, required this.name, required this.onTap});
  final String name;
  final VoidCallback onTap;

  /// Base sizes the name may use, largest first; heights keep the title's
  /// 1.25–1.375 leading.
  static const _nameRungs = [
    (size: 24.0, height: 30 / 24),
    (size: 20.0, height: 26 / 20),
    (size: 16.0, height: 22 / 16),
  ];

  /// Segments a line breaker will not split: runs of non-space, non-hyphen
  /// characters, keeping a trailing hyphen with the run it ends.
  static final _segment = RegExp(r'[^\s\-]+-?');

  static TextStyle nameStyle(
    BuildContext context,
    String name, {
    required double maxWidth,
  }) {
    final base = Theme.of(context).textTheme.titleLarge ?? const TextStyle();
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final segments = _segment
        .allMatches(name)
        .map((match) => match.group(0)!)
        .toList();
    final painter = TextPainter(textDirection: direction, textScaler: scaler);
    try {
      for (final rung in _nameRungs) {
        final style = base.copyWith(fontSize: rung.size, height: rung.height);
        var widest = 0.0;
        for (final segment in segments) {
          painter
            ..text = TextSpan(text: segment, style: style)
            ..layout();
          if (painter.width > widest) widest = painter.width;
        }
        if (widest <= maxWidth || rung == _nameRungs.last) return style;
      }
    } finally {
      painter.dispose();
    }
    return base;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Tooltip(
      message: _l10n(context).workspaceManageProjectHint,
      child: InkWell(
        key: const ValueKey('current-project-context'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  key: const ValueKey('current-project-name'),
                  style: nameStyle(
                    context,
                    name,
                    maxWidth: constraints.maxWidth - 64,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(AppIconography.chevronRight, size: 24),
            ],
          ),
        ),
      ),
    ),
  );
}

enum _SectionAction { refresh, background }

/// The Recent-sessions caption's controls: Search as a one-tap icon, and the
/// occasional actions (reload, terminal, background updates) behind a single
/// menu with visible labels. Two 48px targets leave the caption most of a
/// 320px row even at 2x text; four unlabelled icons did not.
///
/// Its own enum keeps `find.byType(PopupMenuButton<String>)` in existing
/// tests pointing at session rows only.
class _SectionActions extends StatelessWidget {
  const _SectionActions({
    required this.controller,
    required this.onSearch,
    required this.onOpenBackgroundSettings,
  });

  final ConnectionController controller;

  /// Null hides the icon: the server has no cross-directory session search.
  final VoidCallback? onSearch;

  /// Null omits the entry: this platform has no background service.
  final VoidCallback? onOpenBackgroundSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final keepLive = controller.keepLiveInBackground;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Labelled, because this search spans every folder on the server
        // while it sits beside a list scoped to one project.
        if (onSearch case final onSearch?)
          if (MediaQuery.textScalerOf(context).scale(14) > 18)
            IconButton(
              key: const ValueKey('search-all-sessions'),
              tooltip: l10n.e7WorkspaceSearchServer,
              onPressed: onSearch,
              icon: const Icon(AppIconography.searchList, size: 21),
            )
          else
            // Flexible: "All conversations" is longer than the label it
            // replaced, so on a 320dp phone the button gives up width and
            // ellipsizes instead of pushing the menu off the edge.
            Flexible(
              child: Tooltip(
                message: l10n.e7WorkspaceSearchServer,
                child: TextButton.icon(
                  key: const ValueKey('search-all-sessions'),
                  onPressed: onSearch,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(AppIconography.searchList, size: 19),
                  label: Text(
                    l10n.workspaceAllSessions,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
        PopupMenuButton<_SectionAction>(
          key: const ValueKey('workspace-section-menu'),
          onSelected: (action) {
            switch (action) {
              case _SectionAction.refresh:
                unawaited(controller.refreshSessions());
              case _SectionAction.background:
                onOpenBackgroundSettings?.call();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              key: const ValueKey('workspace-refresh-sessions'),
              value: _SectionAction.refresh,
              enabled: !controller.sessionsLoading,
              child: _MenuRow(
                icon: AppIconography.retry,
                label: l10n.sessionsReload,
              ),
            ),
            // Whether runs keep updating after the app closes was only
            // discoverable two levels into Settings; say it where the runs
            // are.
            if (onOpenBackgroundSettings != null)
              PopupMenuItem(
                key: const ValueKey('workspace-background-toggle'),
                value: _SectionAction.background,
                child: _MenuRow(
                  icon: keepLive
                      ? AppIconography.sync
                      : AppIconography.cloudOff,
                  label: keepLive
                      ? l10n.e7WorkspaceBackgroundOn
                      : l10n.e7WorkspaceBackgroundOff,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// A menu entry with a leading icon; the label wraps rather than clips at
/// large text.
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Flexible(child: Text(label)),
      ],
    );
  }
}

class _SwipeArchiveBackground extends StatelessWidget {
  const _SwipeArchiveBackground();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.secondaryContainer,
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsetsDirectional.only(end: 24),
      child: Icon(AppIconography.archive, color: scheme.onSecondaryContainer),
    );
  }
}

/// The busy marker on a session row: a primary dot that breathes slowly
/// instead of a spinner, because "working" is a state, not a wait. Holds
/// still when the platform asks for reduced motion.
class _BreathingDot extends StatefulWidget {
  const _BreathingDot();

  static const period = Duration(milliseconds: 1600);

  @override
  State<_BreathingDot> createState() => _BreathingDotState();
}

class _BreathingDotState extends State<_BreathingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _BreathingDot.period,
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: .4,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: _l10n(context).globalSessionsWorking,
      child: SizedBox.square(
        dimension: 22,
        child: Center(
          child: RepaintBoundary(
            child: FadeTransition(
              opacity: _opacity,
              child: Container(
                key: const ValueKey('session-busy-dot'),
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A composer-shaped invitation docked to the workspace: it looks like the
/// chat input and opens a fresh session in the active project ready to type.
class _QuickAskPill extends StatelessWidget {
  const _QuickAskPill({
    required this.creating,
    required this.onTap,
    this.onIsolatedTask,
    this.isolatedTaskLabel,
  });

  final bool creating;
  final VoidCallback? onTap;

  /// Explicit fresh-worktree launch, shown as its own 48dp target beside the
  /// plain quick-ask tap. Null hides it (capability or project missing).
  final VoidCallback? onIsolatedTask;
  final String? isolatedTaskLabel;

  /// Whether the isolated action is an icon beside the primary button
  /// (narrow phone or large text) rather than a labelled button beside it.
  static bool _compact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 400 ||
      MediaQuery.textScalerOf(context).scale(14) > 18;

  /// Chrome around a button label the layout must budget for: the theme's
  /// horizontal padding (M3's 24 each side when the theme sets none), the
  /// 18dp icon and its gap. Slightly generous, so a label that measures
  /// tight stacks rather than clips.
  static const _iconChrome = 18.0 + 8.0 + 2.0;

  static EdgeInsets _padding(ButtonStyle? style, EdgeInsets fallback) =>
      style?.padding?.resolve(const {})?.resolve(TextDirection.ltr) ?? fallback;

  static TextStyle _labelStyle(ThemeData theme, ButtonStyle? style) =>
      style?.textStyle?.resolve(const {}) ??
      theme.textTheme.labelLarge ??
      const TextStyle(fontSize: 14);

  /// Lays out [text] the way a button paints it and returns its size.
  static Size _measure(
    BuildContext context,
    String text,
    TextStyle style, {
    required double maxWidth,
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth < 0 ? 0 : maxWidth);
    final size = painter.size;
    painter.dispose();
    return size;
  }

  /// How the dock arranges itself in [width] and how tall that is, computed
  /// from the same text metrics the buttons use so the scroll end can clear
  /// the dock without a guess. [width] is the pill's own width (the page
  /// width less its 16dp rails).
  ///
  /// With an isolated action on a narrow phone or at large text, the primary
  /// label gets one line beside a 48dp icon when it fits; otherwise the
  /// isolated action becomes a labelled button above a full-width primary,
  /// instead of the primary clipping to "New ses…".
  static ({bool stacked, double height}) metrics(
    BuildContext context, {
    required double width,
    required bool hasIsolated,
  }) {
    final theme = Theme.of(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final filled = theme.filledButtonTheme.style;
    final filledPadding = _padding(
      filled,
      const EdgeInsets.symmetric(horizontal: 24),
    );
    final filledStyle = _labelStyle(theme, filled);
    final chrome = filledPadding.horizontal + _iconChrome;

    double primaryHeight(double available) {
      final label = _measure(
        context,
        l10n.workspaceNewSession,
        filledStyle,
        maxWidth: available - chrome,
        maxLines: 2,
      );
      final content = label.height > 18 ? label.height : 18;
      final height = content + filledPadding.vertical;
      return height > 48 ? height : 48;
    }

    // Wide layouts keep the labelled isolated button beside the primary; the
    // label always has a line there, so its height is the primary's.
    if (!hasIsolated || !_compact(context)) {
      return (stacked: false, height: primaryHeight(width));
    }
    final besideIcon = width - 8 - 48;
    final singleLine = _measure(
      context,
      l10n.workspaceNewSession,
      filledStyle,
      maxWidth: double.infinity,
    );
    if (singleLine.width <= besideIcon - chrome) {
      return (stacked: false, height: primaryHeight(besideIcon));
    }
    final text = theme.textButtonTheme.style;
    final textPadding = _padding(
      text,
      const EdgeInsets.symmetric(horizontal: 16),
    );
    final isolatedLabel = _measure(
      context,
      l10n.workspaceIsolatedTask,
      _labelStyle(theme, text),
      maxWidth: width - textPadding.horizontal - _iconChrome,
    );
    final isolatedHeight = isolatedLabel.height + textPadding.vertical;
    return (
      stacked: true,
      height:
          (isolatedHeight > 48 ? isolatedHeight : 48) +
          4 +
          primaryHeight(width),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isolated = onIsolatedTask;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final compact = _compact(context);
    // Two labelled actions, not a faux text field: tapping here creates a
    // conversation and leaves the page, so the control says so. The isolated
    // task keeps its own labelled target instead of an unexplained glyph.
    // Two lines before an ellipsis: the primary action's name is never the
    // thing cut.
    final primary = KitButton.primary(
      onPressed: onTap,
      working: creating,
      icon: AppIconography.add,
      label: l10n.workspaceNewSession,
    );
    return Material(
      key: const ValueKey('workspace-quick-ask'),
      // Opaque backing protects the controls from scrolling session text.
      // The button fill shares the page rail without an invisible inner tray.
      color: theme.scaffoldBackgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (isolated == null) return primary;
          final stacked = metrics(
            context,
            width: constraints.maxWidth,
            hasIsolated: true,
          ).stacked;
          if (stacked) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Tooltip(
                    message: isolatedTaskLabel ?? '',
                    child: TextButton.icon(
                      key: const ValueKey('workspace-isolated-task'),
                      onPressed: creating ? null : isolated,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(AppIconography.branch, size: 20),
                      label: Text(l10n.workspaceIsolatedTask),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                primary,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: primary),
              const SizedBox(width: 8),
              if (compact)
                IconButton(
                  key: const ValueKey('workspace-isolated-task'),
                  tooltip: isolatedTaskLabel ?? l10n.workspaceIsolatedTask,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: creating ? null : isolated,
                  icon: const Icon(AppIconography.branch),
                )
              else
                Tooltip(
                  message: isolatedTaskLabel ?? '',
                  child: TextButton.icon(
                    key: const ValueKey('workspace-isolated-task'),
                    onPressed: creating ? null : isolated,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(AppIconography.branch, size: 20),
                    label: Text(
                      l10n.workspaceIsolatedTask,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          );
        },
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

/// Blocking state shown while the connection has no usable project folder.
/// It replaces the session list and the quick-ask pill: nothing can run in
/// the server's home folder, so the only ways forward are creating a folder
/// (managed server) or opening an existing one.
class _WorkspaceFolderChooser extends StatelessWidget {
  const _WorkspaceFolderChooser({
    required this.notice,
    required this.projectError,
    required this.canCreate,
    required this.onCreate,
    required this.onOpen,
    required this.onBrowse,
    required this.onSearchAll,
    required this.onRetry,
  });

  final String? notice;
  final String? projectError;
  final bool canCreate;
  final VoidCallback onCreate;
  final VoidCallback onOpen;
  final VoidCallback onBrowse;
  final VoidCallback? onSearchAll;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final create = KitAction(
      key: const ValueKey('workspace-create-folder'),
      icon: AppIconography.folderAdd,
      label: l10n.projectFolderCreate,
      onPressed: onCreate,
    );
    final open = KitAction(
      key: const ValueKey('workspace-open-folder'),
      icon: AppIconography.folderOpen,
      label: l10n.projectFolderOpen,
      onPressed: onOpen,
    );
    final error = projectError;
    return KitStateView(
      key: const ValueKey('workspace-folder-chooser'),
      icon: error == null ? AppIconography.folders : AppIconography.warning,
      tone: error == null ? AppStatusTone.neutral : AppStatusTone.attention,
      title: l10n.projectFolderChooserTitle,
      body: notice ?? l10n.e7WorkspaceChooseFolderToStart,
      bodyKey: notice == null
          ? null
          : const ValueKey('location-recovery-notice'),
      primary: canCreate ? create : open,
      secondary: canCreate ? open : null,
      tertiary: [
        KitAction(
          key: const ValueKey('workspace-browse-projects'),
          label: l10n.projectFolderBrowse,
          onPressed: onBrowse,
        ),
        if (onSearchAll case final onSearchAll?)
          KitAction(
            key: const ValueKey('workspace-chooser-search-all'),
            label: l10n.workspaceSearchAllSessions,
            onPressed: onSearchAll,
          ),
        if (error != null)
          KitAction(label: l10n.workspaceRetryProjects, onPressed: onRetry),
      ],
      // Why there is no Create here, and a failed project list, are the
      // technical part: under Details, below the actions.
      detailNotes: [if (!canCreate) l10n.projectFolderNoCreateHint],
      details: error,
    );
  }
}

AppLocalizations _l10n(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(Localizations.localeOf(context));
