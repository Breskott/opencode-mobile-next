import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/server_gateway.dart'
    show ProductException, ServerCapabilities;
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../app_iconography.dart';
import '../desktop/desktop_interaction.dart';
import '../widgets/product_states.dart';
import 'files_screen.dart';
import 'project_health_screen.dart';
import 'terminal_screen.dart';
import 'workspace_screen.dart';
import 'worktrees_screen.dart';

/// A tool scoped to the current project, in the order the Project tab lists
/// them.
enum ProjectTool { files, changes, terminal, health, worktrees, search }

/// Asks the shell for a tool that lives inside the Project tab (Files and its
/// search), from a search result on any route.
class OpenProjectToolIntent extends Intent {
  const OpenProjectToolIntent(this.tool);
  final ProjectTool tool;
}

/// Opens a Project tool that is a screen of its own. Shared by the tab's rows
/// and by search, so both doors do exactly the same thing. Files and Search
/// are not here: they live inside the tab ([OpenProjectToolIntent]).
Future<void> openProjectTool(
  BuildContext context,
  ConnectionController controller,
  ProjectTool tool,
) async {
  final l10n = _l10n(context);
  final navigator = Navigator.of(context);
  try {
    switch (tool) {
      case ProjectTool.files || ProjectTool.search:
        return;
      case ProjectTool.changes:
        final prompt = await pushWorkingTreeReview(context, controller);
        if (context.mounted) await deliverReviewPrompt(context, prompt);
      case ProjectTool.terminal:
        await navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => TerminalPage(controller: controller),
          ),
        );
      case ProjectTool.health:
        final repository = await controller.prepareActionRepository();
        if (!context.mounted) return;
        if (repository == null) {
          throw ProductException(l10n.e7WorkspaceDisconnected);
        }
        await navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => ProjectHealthScreen(
              repository: repository,
              repositoryResolver: controller.prepareActionRepository,
              capabilities: controller.capabilities,
            ),
          ),
        );
      case ProjectTool.worktrees:
        final repository = await controller.prepareActionRepository();
        if (!context.mounted) return;
        if (repository == null) {
          throw ProductException(l10n.e7WorkspaceDisconnected);
        }
        final directory = controller.directory;
        final project = directory == null
            ? null
            : WorkspaceScreen.projectForDirectory(
                await repository.listProjects(),
                directory,
              );
        if (!context.mounted) return;
        if (project == null) {
          throw ProductException(l10n.e7LibraryNoProjectFolderIsOpenChooseOne);
        }
        await navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) =>
                WorktreesScreen(controller: controller, project: project),
          ),
        );
    }
  } catch (error) {
    if (context.mounted) showProductError(context, error);
  }
}

/// Lets the shell offer system Back to the Project tab before leaving it.
class ProjectHubBackController {
  bool Function()? _handler;
  bool handleBack() => _handler?.call() ?? false;
}

/// The Project tab: every tool that acts on the current project, one row
/// each. A row the connected server cannot serve is absent, not disabled, and
/// the shell drops the whole tab when no row is left (UX plan 5.1, rule 7).
///
/// Files opens inside the tab rather than over it, so the file browser keeps
/// its folder, search and scroll position across tab switches the way it did
/// when it was the tab. The other tools are full screens of their own.
class ProjectHub extends StatefulWidget {
  const ProjectHub({
    super.key,
    required this.controller,
    this.focusSearchSignal,
    this.openFilesSignal,
    this.backController,
  });

  final ConnectionController controller;

  /// Bumped by the shell's Ctrl/Cmd+F while this tab is showing.
  final ValueListenable<int>? focusSearchSignal;

  /// Bumped by the shell when a search result means Files.
  final ValueListenable<int>? openFilesSignal;
  final ProjectHubBackController? backController;

  /// Changes and Search ride on Files' gate: the working-tree review and the
  /// file finder are served by the same file API, and Files was their only
  /// door before this tab existed.
  static List<ProjectTool> toolsFor(ServerCapabilities capabilities) => [
    if (capabilities.fileBrowsing) ProjectTool.files,
    if (capabilities.fileBrowsing) ProjectTool.changes,
    if (capabilities.terminal) ProjectTool.terminal,
    if (capabilities.projectManagement) ProjectTool.health,
    if (capabilities.projectManagement) ProjectTool.worktrees,
    if (capabilities.fileBrowsing) ProjectTool.search,
  ];

  static bool isAvailable(ServerCapabilities capabilities) =>
      toolsFor(capabilities).isNotEmpty;

  @override
  State<ProjectHub> createState() => _ProjectHubState();
}

class _ProjectHubState extends State<ProjectHub> {
  final _filesBack = FilesBackController();
  final _focusFilesSearch = ValueNotifier<int>(0);

  /// Files is built on first use and then kept, so leaving it for the hub or
  /// another tab does not reload the tree.
  bool _filesBuilt = false;
  bool _filesOpen = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    widget.focusSearchSignal?.addListener(_searchFiles);
    widget.openFilesSignal?.addListener(_openFiles);
    widget.backController?._handler = _handleBack;
  }

  @override
  void didUpdateWidget(ProjectHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusSearchSignal != widget.focusSearchSignal) {
      oldWidget.focusSearchSignal?.removeListener(_searchFiles);
      widget.focusSearchSignal?.addListener(_searchFiles);
    }
    if (oldWidget.openFilesSignal != widget.openFilesSignal) {
      oldWidget.openFilesSignal?.removeListener(_openFiles);
      widget.openFilesSignal?.addListener(_openFiles);
    }
    if (oldWidget.backController != widget.backController) {
      oldWidget.backController?._handler = null;
      widget.backController?._handler = _handleBack;
    }
  }

  @override
  void dispose() {
    widget.focusSearchSignal?.removeListener(_searchFiles);
    widget.openFilesSignal?.removeListener(_openFiles);
    widget.backController?._handler = null;
    _focusFilesSearch.dispose();
    super.dispose();
  }

  bool get _canBrowse => widget.controller.capabilities.fileBrowsing;

  bool _handleBack() {
    if (!_filesOpen || !_canBrowse) return false;
    if (_filesBack.handleBack()) return true;
    setState(() => _filesOpen = false);
    return true;
  }

  void _openFiles() {
    if (!mounted || !_canBrowse) return;
    setState(() {
      _filesBuilt = true;
      _filesOpen = true;
    });
  }

  void _searchFiles() {
    if (!mounted || !_canBrowse) return;
    _openFiles();
    // Files may only be mounting in this frame; its listener exists after it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusFilesSearch.value++;
    });
  }

  /// One tool at a time: the rows that first ask the server something would
  /// otherwise stack two screens on a double tap.
  Future<void> _guard(Future<void> Function() open) async {
    if (_opening) return;
    _opening = true;
    try {
      await open();
    } finally {
      _opening = false;
    }
  }

  Future<void> _openTool(ProjectTool tool) =>
      _guard(() => openProjectTool(context, widget.controller, tool));

  @override
  Widget build(BuildContext context) {
    final showFiles = _filesOpen && _canBrowse;
    return Stack(
      children: [
        Offstage(
          offstage: showFiles,
          child: TickerMode(enabled: !showFiles, child: _hub(context)),
        ),
        if (_filesBuilt && _canBrowse)
          Offstage(
            offstage: !showFiles,
            child: TickerMode(enabled: showFiles, child: _files(context)),
          ),
      ],
    );
  }

  Widget _files(BuildContext context) {
    final l10n = _l10n(context);
    return Column(
      children: [
        // A visible way back: system Back does the same, but nothing here is
        // reachable by a gesture alone.
        ListTile(
          key: const ValueKey('project-hub-files-header'),
          dense: true,
          contentPadding: const EdgeInsetsDirectional.only(start: 4, end: 16),
          horizontalTitleGap: 4,
          leading: IconButton(
            key: const ValueKey('project-hub-files-back'),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => setState(() => _filesOpen = false),
            icon: const Icon(AppIconography.back),
          ),
          title: Text(
            l10n.readerUiFiles,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Expanded(
          child: FilesScreen(
            controller: widget.controller,
            focusSearchSignal: _focusFilesSearch,
            backController: _filesBack,
          ),
        ),
      ],
    );
  }

  Widget _hub(BuildContext context) {
    final l10n = _l10n(context);
    final directory = widget.controller.directory;
    final tools = ProjectHub.toolsFor(widget.controller.capabilities);
    return DesktopScrollbarArea(
      builder: (scrollController) => ListView(
        controller: scrollController,
        key: const ValueKey('project-hub'),
        padding: EdgeInsets.only(
          bottom: 24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ListTile(
            key: const ValueKey('project-hub-context'),
            leading: const Icon(AppIconography.files),
            title: Text(
              directory == null || directory.isEmpty
                  ? l10n.e7LibraryNoProjectSelected
                  : _basename(directory),
            ),
            subtitle: Text(
              directory == null || directory.isEmpty
                  ? l10n.e7LibraryNoProjectFolderIsOpenChooseOne
                  : directory,
              textDirection: directory == null || directory.isEmpty
                  ? null
                  : TextDirection.ltr,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 1),
          for (final tool in tools)
            switch (tool) {
              ProjectTool.files => _row(
                tool,
                icon: AppIconography.files,
                title: l10n.readerUiFiles,
                subtitle: l10n.projectHubFilesSubtitle,
                onTap: _openFiles,
              ),
              ProjectTool.changes => _row(
                tool,
                icon: AppIconography.review,
                title: l10n.readerUiChanges,
                subtitle: l10n.projectHubChangesSubtitle,
                onTap: () => _openTool(tool),
              ),
              ProjectTool.terminal => _row(
                tool,
                icon: AppIconography.terminal,
                title: l10n.libraryTerminalTitle,
                subtitle: l10n.chatUiOpenPersistentWorkspaceTerminals,
                onTap: () => _openTool(tool),
              ),
              ProjectTool.health => _row(
                tool,
                icon: AppIconography.diagnostics,
                title: l10n.e7LibraryProjectHealth,
                subtitle: l10n
                    .e7LibraryBranchChangedFilesLanguageServicesAndFormatters,
                onTap: () => _openTool(tool),
              ),
              ProjectTool.worktrees => _row(
                tool,
                icon: AppIconography.branch,
                title: l10n.e7LibraryWorktrees,
                subtitle: l10n.e7LibraryCreateAndManageIsolatedGitBranches,
                onTap: () => _openTool(tool),
              ),
              ProjectTool.search => _row(
                tool,
                icon: AppIconography.search,
                title: l10n.readerUiSearchFiles,
                subtitle: l10n.projectHubSearchSubtitle,
                onTap: _searchFiles,
              ),
            },
        ],
      ),
    );
  }

  Widget _row(
    ProjectTool tool, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => ListTile(
    key: ValueKey('project-hub-${tool.name}'),
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(AppIconography.chevronRight),
    onTap: onTap,
  );

  static String _basename(String directory) {
    final parts = directory.split('/').where((part) => part.isNotEmpty);
    return parts.isEmpty ? directory : parts.last;
  }
}

AppLocalizations _l10n(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(Localizations.localeOf(context));
