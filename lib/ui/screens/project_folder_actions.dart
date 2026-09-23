import 'package:flutter/material.dart';

import '../../builtin/builtin_linux.dart';
import '../../builtin/builtin_server.dart';
import '../../domain/workspace_paths.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../termux/bridge.dart';
import '../app_theme.dart';
import '../widgets/product_states.dart';

/// The ways a workspace gets a project folder: create one on a server this
/// app runs (Termux, or OpenCode inside the app), pick one of its projects,
/// or open an existing folder by its path.
///
/// Shared by Workspace (which blocks sessions until a folder is chosen) and
/// the project picker. The server's home folder is never an option; see
/// `workspace_paths.dart`.
class ProjectFolderActions {
  ProjectFolderActions._();

  /// Widget tests cannot reach the Termux bridge; they inject the creator.
  @visibleForTesting
  static Future<String> Function(String name)? createFolderOverride;

  @visibleForTesting
  static bool? canCreateOverride;

  /// Widget tests hand in a fake bridge for OpenCode inside the app.
  @visibleForTesting
  static BuiltinLinux? builtinLinuxOverride;

  static BuiltinLinux get _linux => builtinLinuxOverride ?? BuiltinLinux();

  /// Only a server this app runs can create folders: the app-managed Termux
  /// server and OpenCode inside the app. Other servers expose no
  /// folder-creation API, so the user creates the folder on that machine and
  /// opens it by path.
  static bool canCreate(ConnectionController controller) {
    final override = canCreateOverride;
    if (override != null) return override;
    final profile = controller.profile;
    return profile != null &&
        (TermuxBridge.supported &&
                TermuxBridge.managesServerUrl(profile.baseUrl) ||
            looksLikeInAppServer(profile));
  }

  /// Asks for a folder name, creates `/root/projects/<name>` on the managed
  /// server, and opens it. Returns the opened directory, or null when the
  /// user cancelled or the folder could not be created or opened.
  static Future<String?> createFolder(
    BuildContext context,
    ConnectionController controller,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NewFolderDialog(),
    );
    if (name == null || !context.mounted) return null;
    // Termux never serves 4097, so the address alone picks the right
    // creator here; were Ubuntu missing, the bridge says so itself.
    if (looksLikeInAppServer(controller.profile)) {
      return _createInApp(
        context,
        controller,
        BuiltinProjectFolders(_linux),
        BuiltinProjectFolders.pathFor(name),
      );
    }
    final create = createFolderOverride ?? TermuxBridge.createProjectFolder;
    String path;
    try {
      path = await create(name);
    } catch (error) {
      if (context.mounted) _notify(context, productErrorText(error));
      return null;
    }
    if (!context.mounted) return null;
    return _open(context, controller, path);
  }

  /// OpenCode inside the app: pick one of its projects, name a new one, or
  /// enter a path. Any other server: enter a path, which is confirmed on the
  /// server before it opens. Returns the opened directory, or null when
  /// cancelled or refused.
  static Future<String?> openFolder(
    BuildContext context,
    ConnectionController controller,
  ) async {
    final linux = _linux;
    if (await isInAppServer(controller.profile, linux)) {
      if (!context.mounted) return null;
      final folders = BuiltinProjectFolders(linux);
      final choice = await showModalBottomSheet<_InAppChoice>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _InAppProjectSheet(folders: folders),
      );
      if (choice == null || !context.mounted) return null;
      return switch (choice) {
        _OpenProject(:final name) => _open(
          context,
          controller,
          BuiltinProjectFolders.pathFor(name),
        ),
        _NewProject(:final name) => _createInApp(
          context,
          controller,
          folders,
          BuiltinProjectFolders.pathFor(name),
        ),
        _EnterPath() => _openByPath(context, controller, folders),
      };
    }
    if (!context.mounted) return null;
    return _openByPath(context, controller, null);
  }

  static Future<String?> _openByPath(
    BuildContext context,
    ConnectionController controller,
    BuiltinProjectFolders? inApp,
  ) async {
    final picked = await showDialog<({String path, bool create})>(
      context: context,
      builder: (_) => _OpenFolderDialog(controller: controller, inApp: inApp),
    );
    if (picked == null || !context.mounted) return null;
    if (picked.create && inApp != null) {
      return _createInApp(context, controller, inApp, picked.path);
    }
    return _open(context, controller, picked.path);
  }

  /// Makes [path] inside the app's Ubuntu (a new git project, or the folder
  /// that is already there) and opens it. OpenCode hears of the folder only
  /// once it exists: here folders are checked through Ubuntu, never through
  /// OpenCode, so it has no stale view of the folder to forget. (Dropping
  /// one anyway restarted OpenCode's event stream, flashing "Reconnecting".)
  static Future<String?> _createInApp(
    BuildContext context,
    ConnectionController controller,
    BuiltinProjectFolders folders,
    String path,
  ) async {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final ({String path, bool created}) made;
    try {
      made = await folders.create(path);
    } on BuiltinLinuxException catch (error) {
      if (context.mounted) {
        _notify(context, l10n.projectFolderCreateFailed(error.message));
      }
      return null;
    }
    if (!context.mounted) return null;
    return _open(context, controller, made.path);
  }

  static Future<String?> _open(
    BuildContext context,
    ConnectionController controller,
    String path,
  ) async {
    await controller.selectLocation(directory: path);
    final problem = controller.locationError;
    if (problem != null) {
      if (context.mounted) _notify(context, problem);
      return null;
    }
    return path;
  }

  static void _notify(BuildContext context, String message) =>
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
}

class _NewFolderDialog extends StatefulWidget {
  const _NewFolderDialog();

  @override
  State<_NewFolderDialog> createState() => _NewFolderDialogState();
}

class _NewFolderDialogState extends State<_NewFolderDialog> {
  final _name = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final problem = projectFolderNameProblem(_name.text);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    return AlertDialog(
      title: Text(l10n.projectFolderCreate),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.projectFolderCreateMessage(managedProjectsDirectory)),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('new-folder-name'),
            controller: _name,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_problem != null) setState(() => _problem = null);
            },
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.projectFolderNameLabel,
              hintText: l10n.projectFolderNameHint,
              errorText: _problem,
              errorMaxLines: 3,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.projectFolderCancel),
        ),
        FilledButton(
          key: const ValueKey('new-folder-create'),
          onPressed: _submit,
          child: Text(l10n.projectFolderCreateAction),
        ),
      ],
    );
  }
}

class _OpenFolderDialog extends StatefulWidget {
  const _OpenFolderDialog({required this.controller, this.inApp});

  final ConnectionController controller;

  /// Given for OpenCode inside the app: the path is checked, and a missing
  /// folder created, through the app's own Ubuntu instead of OpenCode.
  final BuiltinProjectFolders? inApp;

  @override
  State<_OpenFolderDialog> createState() => _OpenFolderDialogState();
}

class _OpenFolderDialogState extends State<_OpenFolderDialog> {
  final _path = TextEditingController();
  String? _problem;
  bool _checking = false;

  /// The typed folder does not exist and this app can make it.
  bool _canCreateMissing = false;

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_checking) return;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final path = _path.text.trim();
    final problem = workspaceDirectoryProblem(path);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    setState(() {
      _checking = true;
      _problem = null;
    });
    final inApp = widget.inApp;
    if (inApp != null) {
      // Checked in Ubuntu, not by asking OpenCode: OpenCode would remember a
      // missing folder as broken and keep failing there after it is made.
      String? failure;
      var exists = false;
      try {
        exists = await inApp.exists(path);
      } on BuiltinLinuxException catch (error) {
        failure = l10n.projectFolderCheckFailed(error.message);
      }
      if (!mounted) return;
      if (failure != null || !exists) {
        setState(() {
          _checking = false;
          _problem = failure ?? l10n.projectFolderMissing;
          _canCreateMissing = failure == null;
        });
        return;
      }
      Navigator.of(context).pop((path: path, create: false));
      return;
    }
    final serverProblem = await widget.controller.probeProjectFolder(path);
    if (!mounted) return;
    if (serverProblem != null) {
      setState(() {
        _checking = false;
        _problem = serverProblem;
      });
      return;
    }
    Navigator.of(context).pop((path: path, create: false));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    return AlertDialog(
      title: Text(l10n.projectFolderOpen),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.projectFolderOpenMessage),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('open-folder-path'),
            controller: _path,
            autofocus: true,
            enabled: !_checking,
            keyboardType: TextInputType.url,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_problem != null || _canCreateMissing) {
                setState(() {
                  _problem = null;
                  _canCreateMissing = false;
                });
              }
            },
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.projectFolderPathLabel,
              hintText: l10n.projectFolderPathHint(managedProjectsDirectory),
              errorText: _problem,
              errorMaxLines: 4,
            ),
          ),
          if (_checking) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.projectFolderCancel),
        ),
        // A missing folder turns the one action into making it; editing the
        // path turns it back.
        if (_canCreateMissing)
          FilledButton(
            key: const ValueKey('open-folder-create-missing'),
            onPressed: () => Navigator.of(
              context,
            ).pop((path: _path.text.trim(), create: true)),
            child: Text(l10n.projectFolderCreateIt),
          )
        else
          FilledButton(
            key: const ValueKey('open-folder-confirm'),
            onPressed: _checking ? null : _submit,
            child: Text(l10n.projectFolderOpenAction),
          ),
      ],
    );
  }
}

/// What the in-app project sheet was closed with.
sealed class _InAppChoice {
  const _InAppChoice();
}

class _OpenProject extends _InAppChoice {
  const _OpenProject(this.name);
  final String name;
}

class _NewProject extends _InAppChoice {
  const _NewProject(this.name);
  final String name;
}

class _EnterPath extends _InAppChoice {
  const _EnterPath();
}

/// OpenCode inside the app keeps its projects in one folder, so choosing one
/// is a tap and making one is a name. A full path stays one tap away.
class _InAppProjectSheet extends StatefulWidget {
  const _InAppProjectSheet({required this.folders});

  final BuiltinProjectFolders folders;

  @override
  State<_InAppProjectSheet> createState() => _InAppProjectSheetState();
}

class _InAppProjectSheetState extends State<_InAppProjectSheet> {
  final _name = TextEditingController();
  List<String>? _projects;
  String? _listError;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final projects = await widget.folders.list();
      if (mounted) setState(() => _projects = projects);
    } on BuiltinLinuxException catch (error) {
      if (mounted) setState(() => _listError = error.message);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    final name = _name.text.trim();
    final problem = projectFolderNameProblem(name);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    // A name that is already a project simply opens it.
    Navigator.of(context).pop(
      _projects?.contains(name) == true
          ? _OpenProject(name)
          : _NewProject(name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final muted = theme.textTheme.bodyMedium!.copyWith(
      color: AppTheme.mutedOf(theme),
    );
    final projects = _projects;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .85,
          ),
          child: ListView(
            key: const ValueKey('in-app-projects'),
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  l10n.projectFolderInAppTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (projects == null && _listError == null)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else if (_listError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Text(
                    l10n.projectFolderInAppListFailed(_listError!),
                    style: muted,
                  ),
                )
              else if (projects!.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Text(l10n.projectFolderInAppEmpty, style: muted),
                )
              else
                for (final name in projects)
                  ListTile(
                    key: ValueKey('in-app-project-$name'),
                    leading: const Icon(AppIconography.folderOpen),
                    title: Text(name),
                    onTap: () => Navigator.of(context).pop(_OpenProject(name)),
                  ),
              const Divider(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Text(
                  l10n.projectFolderNewProject,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('in-app-new-project-name'),
                        controller: _name,
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) {
                          if (_problem != null) setState(() => _problem = null);
                        },
                        onSubmitted: (_) => _create(),
                        decoration: InputDecoration(
                          labelText: l10n.projectFolderProjectNameLabel,
                          hintText: l10n.projectFolderNameHint,
                          helperText: l10n.projectFolderNewProjectHelp(
                            BuiltinLinux.projectsDir,
                          ),
                          helperMaxLines: 2,
                          errorText: _problem,
                          errorMaxLines: 3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton(
                        key: const ValueKey('in-app-new-project-create'),
                        onPressed: _create,
                        child: Text(l10n.projectFolderCreateAction),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextButton(
                    key: const ValueKey('in-app-enter-path'),
                    onPressed: () =>
                        Navigator.of(context).pop(const _EnterPath()),
                    child: Text(l10n.projectFolderEnterPath),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
