import 'package:flutter/material.dart';

import '../../builtin/builtin_folders.dart';
import '../../builtin/builtin_linux.dart';
import '../../builtin/builtin_server.dart';
import '../../domain/workspace_paths.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../termux/bridge.dart';
import '../widgets/folder_browser.dart';
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

  /// Widget tests list folders without Ubuntu's files on disk.
  @visibleForTesting
  static FolderLister? folderListerOverride;

  /// OpenCode inside the app: browse its folders from the projects folder
  /// and open one, name a new project in the folder shown, or enter a path.
  /// Any other server: enter a path, which is confirmed on the server
  /// before it opens (OpenCode lists files only inside the project it is
  /// asked about, so its folders cannot be browsed from here). Returns the
  /// opened directory, or null when cancelled or refused.
  static Future<String?> openFolder(
    BuildContext context,
    ConnectionController controller,
  ) async {
    final linux = _linux;
    if (await isInAppServer(controller.profile, linux)) {
      if (!context.mounted) return null;
      final folders = BuiltinProjectFolders(linux);
      final choice = await showModalBottomSheet<FolderBrowserChoice>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => FolderBrowserSheet(
          list: folderListerOverride ?? BuiltinFolders(linux).list,
          knownProjects: () => _knownProjects(controller),
        ),
      );
      if (choice == null || !context.mounted) return null;
      return switch (choice) {
        FolderBrowserOpen(:final path) => _open(context, controller, path),
        FolderBrowserCreate(:final path) => _createInApp(
          context,
          controller,
          folders,
          path,
        ),
        FolderBrowserEnterPath(:final startPath) => _openByPath(
          context,
          controller,
          folders,
          startPath: startPath,
        ),
      };
    }
    if (!context.mounted) return null;
    return _openByPath(context, controller, null);
  }

  /// The folders the connected OpenCode already has as projects, for the
  /// browser's marks. Asked of the connection as it is; nothing is started.
  static Future<Set<String>> _knownProjects(
    ConnectionController controller,
  ) async {
    final repository = controller.repository;
    if (repository == null) return const {};
    final projects = await repository.listProjects().timeout(
      const Duration(seconds: 5),
    );
    return {
      for (final project in projects)
        for (final directory in [project.directory, ...project.worktrees])
          ConnectionController.normalizeDirectoryPath(directory),
    };
  }

  static Future<String?> _openByPath(
    BuildContext context,
    ConnectionController controller,
    BuiltinProjectFolders? inApp, {
    String? startPath,
  }) async {
    final picked = await showDialog<({String path, bool create})>(
      context: context,
      builder: (_) => _OpenFolderDialog(
        controller: controller,
        inApp: inApp,
        startPath: startPath,
      ),
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
  const _OpenFolderDialog({
    required this.controller,
    this.inApp,
    this.startPath,
  });

  final ConnectionController controller;

  /// The folder the browser was showing: the path starts there.
  final String? startPath;

  /// Given for OpenCode inside the app: the path is checked, and a missing
  /// folder created, through the app's own Ubuntu instead of OpenCode.
  final BuiltinProjectFolders? inApp;

  @override
  State<_OpenFolderDialog> createState() => _OpenFolderDialogState();
}

class _OpenFolderDialogState extends State<_OpenFolderDialog> {
  late final _path = TextEditingController(
    text: switch (widget.startPath) {
      null => '',
      '/' => '/',
      final start => '$start/',
    },
  );
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
