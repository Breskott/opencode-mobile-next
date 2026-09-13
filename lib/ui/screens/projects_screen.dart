import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/product_repository.dart';
import '../../domain/workspace_paths.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../widgets/product_states.dart';
import 'project_folder_actions.dart';
import '../app_iconography.dart';

class ProjectsScreen extends StatefulWidget {
  final ConnectionController controller;
  final String? selectedProjectID;

  const ProjectsScreen({
    super.key,
    required this.controller,
    required this.selectedProjectID,
  });

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final _search = TextEditingController();
  List<WorkspaceProject>? _projects;
  String? _error;
  String? _busyProjectID;
  bool _loading = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _search.addListener(_searchChanged);
    if (widget.controller.capabilities.projectManagement) {
      unawaited(_load());
    }
  }

  void _searchChanged() => setState(() {});

  Future<void> _load() async {
    if (!widget.controller.capabilities.projectManagement) return;
    final generation = ++_loadGeneration;
    setState(() => _loading = true);
    final repository = await widget.controller.prepareActionRepository();
    if (!mounted || generation != _loadGeneration) return;
    if (repository == null) {
      setState(() {
        _loading = false;
        _error = lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7ProjectProjectsReconnect;
      });
      return;
    }
    try {
      final projects = await repository.listProjects();
      projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _projects = projects;
        _error = null;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = productErrorText(error);
      });
    }
  }

  /// Real project folders only. The server's catch-all root and any home
  /// folder are never offered: they are not workspaces.
  List<WorkspaceProject> get _usableProjects => (_projects ?? const [])
      .where((project) => !isProtectedWorkspaceDirectory(project.directory))
      .toList(growable: false);

  List<WorkspaceProject> get _visibleProjects {
    final projects = _usableProjects;
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return projects;
    return projects
        .where(
          (project) =>
              project.name.toLowerCase().contains(query) ||
              project.directory.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  Future<void> _select(WorkspaceProject project) async {
    if (!widget.controller.capabilities.projectManagement) return;
    if (_busyProjectID != null) return;
    if (project.id == widget.selectedProjectID &&
        widget.controller.directory == project.directory &&
        widget.controller.workspace == null) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _busyProjectID = project.id);
    await widget.controller.selectLocation(directory: project.directory);
    if (!mounted) return;
    setState(() => _busyProjectID = null);
    final error = widget.controller.locationError;
    if (error != null) {
      _showMessage(error);
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _createFolder() async {
    if (_busyProjectID != null) return;
    final path = await ProjectFolderActions.createFolder(
      context,
      widget.controller,
    );
    if (path != null && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _openFolder() async {
    if (_busyProjectID != null) return;
    final path = await ProjectFolderActions.openFolder(
      context,
      widget.controller,
    );
    if (path != null && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _rename(WorkspaceProject project) async {
    if (!widget.controller.capabilities.projectManagement) return;
    if (_busyProjectID != null) return;
    final next = await showDialog<String>(
      context: context,
      builder: (_) => _RenameProjectDialog(project: project),
    );
    if (next == null || !mounted) return;
    final folderName = _basename(project.directory);
    final normalized = next.trim();
    final serverName = normalized.isEmpty || normalized == folderName
        ? ''
        : normalized;
    if (normalized == project.name && serverName.isNotEmpty) return;

    setState(() => _busyProjectID = project.id);
    try {
      final repository = await widget.controller.prepareActionRepository();
      if (!mounted) return;
      if (repository == null) {
        throw ProductException(
          lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7ProjectProjectsReconnect,
        );
      }
      final updated = await repository.renameProject(
        projectID: project.id,
        projectDirectory: project.directory,
        name: serverName,
      );
      if (!mounted) return;
      setState(() {
        _projects = [
          for (final item in _projects ?? const <WorkspaceProject>[])
            if (item.id == updated.id) updated else item,
        ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      });
      _showMessage(
        lookupAppLocalizations(
          Localizations.localeOf(context),
        ).e7ProjectProjectRenamed(updated.name),
      );
    } catch (error) {
      if (mounted) {
        _showMessage(
          lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7ProjectProjectRenameFailed(productErrorText(error)),
        );
      }
    } finally {
      if (mounted) setState(() => _busyProjectID = null);
    }
  }

  static String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isEmpty ? path : parts.last;
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    if (!widget.controller.capabilities.projectManagement) {
      final directory = widget.controller.directory;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            lookupAppLocalizations(
              Localizations.localeOf(context),
            ).projectContextTitle,
          ),
        ),
        body: ListView(
          key: const ValueKey('projects-context-list'),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            ListTile(
              key: const ValueKey('projects-configured-folder'),
              leading: const Icon(AppIconography.files),
              title: Text(
                lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).projectConfiguredFolder,
              ),
              subtitle: Text(
                directory == null || directory.isEmpty
                    ? l10n.e7ProjectProjectDefaultDirectory
                    : directory,
                textDirection: directory == null || directory.isEmpty
                    ? null
                    : TextDirection.ltr,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ProductEmptyState(
              icon: AppIconography.folderOpen,
              title: l10n.e7ProjectProjectSwitchUnavailable,
              message: l10n.e7ProjectProjectSwitchUnavailableDetail,
            ),
          ],
        ),
      );
    }
    final projects = _projects;
    final visible = _visibleProjects;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.e7ProjectProjectsTitle),
        actions: [
          IconButton(
            tooltip: l10n.e7ProjectProjectsRefresh,
            onPressed: _loading || _busyProjectID != null ? null : _load,
            icon: const Icon(AppIconography.retry),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          key: const ValueKey('projects-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                key: const ValueKey('project-search'),
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.e7ProjectProjectsSearch,
                  prefixIcon: const Icon(AppIconography.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.e7ProjectProjectsClearSearch,
                          onPressed: _search.clear,
                          icon: const Icon(AppIconography.close),
                        ),
                ),
              ),
            ),
            if (ProjectFolderActions.canCreate(widget.controller))
              ListTile(
                key: const ValueKey('projects-create-folder'),
                leading: const Icon(AppIconography.folderAdd),
                title: Text(l10n.projectFolderCreate),
                subtitle: Text(
                  l10n.projectFolderCreateSubtitle(managedProjectsDirectory),
                ),
                onTap: _createFolder,
              ),
            ListTile(
              key: const ValueKey('projects-open-folder'),
              leading: const Icon(AppIconography.folderOpen),
              title: Text(l10n.projectFolderOpen),
              subtitle: Text(l10n.projectFolderOpenSubtitle),
              onTap: _openFolder,
            ),
            SectionLabel(
              l10n.e7ProjectProjectsOpened,
              trailing: Text(
                l10n.e7ProjectProjectsCount(
                  visible.length,
                  _usableProjects.length,
                ),
              ),
            ),
            if (_loading && projects == null)
              const LinearProgressIndicator(minHeight: 2),
            if (_error != null && projects == null)
              ProductErrorState(message: _error!, onRetry: _load)
            else if (projects != null && _usableProjects.isEmpty)
              // Coherent with the Workspace chooser: the server's home folder
              // is never a project, so a fresh server starts with a new or
              // typed folder.
              ProductEmptyState(
                icon: Icons.folder_off_outlined,
                title: l10n.e7ProjectProjectsEmpty,
                message: l10n.e7ProjectProjectsEmptyDetail,
              )
            else if (visible.isEmpty)
              ProductEmptyState(
                icon: Icons.search_off_rounded,
                title: l10n.e7ProjectProjectsNoMatch,
                message: l10n.e7ProjectProjectsNoMatchDetail,
              )
            else
              for (final project in visible)
                _ProjectTile(
                  project: project,
                  active: project.id == widget.selectedProjectID,
                  busy: _busyProjectID == project.id,
                  onOpen: () => _select(project),
                  onRename: () => _rename(project),
                ),
            if (_error != null && projects != null)
              ListTile(
                key: const ValueKey('project-refresh-error'),
                leading: const Icon(AppIconography.error),
                title: Text(l10n.e7ProjectProjectsRefreshFailed),
                subtitle: Text(_error!),
                trailing: IconButton(
                  tooltip: l10n.workspaceRetryProjects,
                  onPressed: _load,
                  icon: const Icon(AppIconography.retry),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _search
      ..removeListener(_searchChanged)
      ..dispose();
    super.dispose();
  }
}

class _ProjectTile extends StatelessWidget {
  final WorkspaceProject project;
  final bool active;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onRename;

  const _ProjectTile({
    required this.project,
    required this.active,
    required this.busy,
    required this.onOpen,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final worktreeCount = project.worktrees.length;
    return ListTile(
      key: ValueKey('project-${project.id}'),
      selected: active,
      enabled: !busy,
      leading: busy
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(active ? AppIconography.files : AppIconography.files),
      title: Text(project.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            project.directory,
            textDirection: TextDirection.ltr,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (worktreeCount > 0)
            Text(l10n.e7ProjectProjectWorktrees(worktreeCount)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: ValueKey('rename-project-${project.id}'),
            tooltip: l10n.e7ProjectProjectRenameAction(project.name),
            onPressed: busy ? null : onRename,
            icon: const Icon(AppIconography.edit),
          ),
          Icon(
            active ? AppIconography.checkCircle : AppIconography.chevronRight,
          ),
        ],
      ),
      onTap: onOpen,
    );
  }
}

class _RenameProjectDialog extends StatefulWidget {
  final WorkspaceProject project;

  const _RenameProjectDialog({required this.project});

  @override
  State<_RenameProjectDialog> createState() => _RenameProjectDialogState();
}

class _RenameProjectDialogState extends State<_RenameProjectDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.project.name,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    return AlertDialog(
      title: Text(l10n.e7ProjectProjectRenameTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('project-name-input'),
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.e7ProjectProjectNameLabel,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Text(
              widget.project.directory,
              textDirection: TextDirection.ltr,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(l10n.e7ProjectProjectNameHint),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('confirm-rename-project'),
          onPressed: _submit,
          child: Text(l10n.e7ProjectProjectSave),
        ),
      ],
    );
  }

  void _submit() => Navigator.pop(context, _controller.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
