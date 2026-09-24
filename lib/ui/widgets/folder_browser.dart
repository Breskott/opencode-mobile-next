import 'dart:async';

import 'package:flutter/material.dart';

import '../../builtin/builtin_folders.dart';
import '../../builtin/builtin_linux.dart';
import '../../domain/workspace_paths.dart';
import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import '../kit/kit.dart';
import '../kit/scenes/folders_open_scene.dart';

/// Lists the folders directly inside an absolute path.
typedef FolderLister = Future<List<FolderEntry>> Function(String path);

/// What the folder browser was closed with.
sealed class FolderBrowserChoice {
  const FolderBrowserChoice();
}

/// Open [path], which is there, as the project.
final class FolderBrowserOpen extends FolderBrowserChoice {
  const FolderBrowserOpen(this.path);
  final String path;
}

/// Make [path] a new project (a folder that is not there yet), then open it.
final class FolderBrowserCreate extends FolderBrowserChoice {
  const FolderBrowserCreate(this.path);
  final String path;
}

/// Type a path instead, starting from [startPath], the folder being shown.
final class FolderBrowserEnterPath extends FolderBrowserChoice {
  const FolderBrowserEnterPath(this.startPath);
  final String startPath;
}

/// "Open a project" for OpenCode inside the app: the folders of its Ubuntu,
/// browsed from the projects folder. The list is the content: a project
/// (a git repository, a project OpenCode knows, or any folder straight in
/// the projects folder) opens with a tap, and its chevron shows what is in
/// it; any other folder is gone into with a tap. "Up one folder" goes back
/// up to `/`. Below, one primary opens the folder being shown, then "New
/// project" makes one inside it, then "Enter a path".
///
/// The home folder and `/` are never offered as a project
/// (`workspace_paths.dart`); the projects folder itself is where projects
/// live, so it is not offered either.
class FolderBrowserSheet extends StatefulWidget {
  const FolderBrowserSheet({
    super.key,
    required this.list,
    this.knownProjects,
    this.start = BuiltinLinux.projectsDir,
  });

  final FolderLister list;

  /// The folders OpenCode already has as projects (normalised paths). A
  /// failure only leaves the marks out.
  final Future<Set<String>> Function()? knownProjects;

  final String start;

  @override
  State<FolderBrowserSheet> createState() => _FolderBrowserSheetState();
}

class _FolderBrowserSheetState extends State<FolderBrowserSheet> {
  final _name = TextEditingController();
  late String _path = BuiltinRootfsFolders.normalize(widget.start) ?? '/';
  List<FolderEntry>? _entries;
  Object? _error;
  bool _loading = true;

  /// Skeleton rows only once a listing takes longer than a touch answer,
  /// so going into a folder does not flash.
  bool _showSkeleton = true;
  Timer? _skeletonTimer;
  int _generation = 0;
  Set<String> _known = const {};
  String? _problem;

  @override
  void initState() {
    super.initState();
    _load(_path);
    _loadKnown();
  }

  @override
  void dispose() {
    _skeletonTimer?.cancel();
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadKnown() async {
    final load = widget.knownProjects;
    if (load == null) return;
    try {
      final known = await load();
      if (mounted) setState(() => _known = known);
    } catch (_) {
      // Only the "OpenCode project" marks depend on it.
    }
  }

  Future<void> _load(String path) async {
    final generation = ++_generation;
    _skeletonTimer?.cancel();
    setState(() {
      _loading = true;
      if (_entries == null && _error == null) _showSkeleton = true;
    });
    _skeletonTimer = Timer(KitMotion.quick, () {
      if (mounted && generation == _generation) {
        setState(() => _showSkeleton = true);
      }
    });
    List<FolderEntry>? entries;
    Object? error;
    try {
      entries = await widget.list(path);
    } catch (caught) {
      error = caught;
    }
    if (!mounted || generation != _generation) return;
    _skeletonTimer?.cancel();
    setState(() {
      _path = path;
      _entries = entries;
      _error = error;
      _loading = false;
      _showSkeleton = false;
      _problem = null;
    });
  }

  static String _join(String folder, String name) =>
      folder == '/' ? '/$name' : '$folder/$name';

  static String _nameOf(String path) =>
      path == '/' ? '/' : path.substring(path.lastIndexOf('/') + 1);

  bool _isProject(FolderEntry entry) =>
      !isProtectedWorkspaceDirectory(entry.path) &&
      (entry.isGit ||
          _known.contains(entry.path) ||
          BuiltinRootfsFolders.parentOf(entry.path) ==
              BuiltinLinux.projectsDir);

  /// The folder shown can be opened as it is: not home or `/`, and not the
  /// projects folder that holds the projects.
  bool get _canOpenHere =>
      !isProtectedWorkspaceDirectory(_path) &&
      _path != BuiltinLinux.projectsDir;

  void _create() {
    final name = _name.text.trim();
    final path = _join(_path, name);
    final problem =
        projectFolderNameProblem(name) ?? workspaceDirectoryProblem(path);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    // A name that is already a folder here simply opens it.
    final exists = _entries?.any((entry) => entry.name == name) ?? false;
    Navigator.of(
      context,
    ).pop(exists ? FolderBrowserOpen(path) : FolderBrowserCreate(path));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final media = MediaQuery.of(context);
    final maxHeight =
        (media.size.height - media.viewInsets.bottom - media.padding.top) * .9;
    // While the name is typed the keyboard leaves little room: the folders
    // step aside for the field. Only flex factors change, so the field keeps
    // its place in the tree (and its focus).
    final typing = media.viewInsets.bottom > 0;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            key: const ValueKey('in-app-projects'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(theme, l10n),
              // The folders and the actions share the height; each scrolls
              // on its own when it needs more.
              Flexible(
                flex: typing ? 0 : 1,
                child: typing ? const SizedBox.shrink() : _folders(theme, l10n),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(child: _actions(theme, l10n)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(ThemeData theme, AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.projectFolderInAppTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Semantics(
          label: l10n.folderBrowserCurrent(_path),
          excludeSemantics: true,
          child: Text(
            _path,
            key: const ValueKey('folder-browser-path'),
            // A path reads left to right in every language.
            textDirection: TextDirection.ltr,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: AppTheme.monoFamily,
              color: AppTheme.mutedOf(theme),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _folders(ThemeData theme, AppLocalizations l10n) {
    final parent = BuiltinRootfsFolders.parentOf(_path);
    final entries = _entries;
    final error = _error;
    final Widget? state;
    if (_loading && _showSkeleton) {
      state = const KitSkeletonRows(count: 4);
    } else if (error != null) {
      state = _errorState(l10n, error);
    } else if (entries != null && entries.isEmpty) {
      final projects = _path == BuiltinLinux.projectsDir;
      state = KitStateView(
        size: KitStateSize.inline,
        icon: AppIconography.folderOpen,
        illustration: const KitFoldersOpenScene(),
        title: projects
            ? l10n.folderBrowserNoProjectsTitle
            : l10n.folderBrowserEmptyTitle,
        body: projects
            ? l10n.folderBrowserNoProjectsBody
            : l10n.folderBrowserEmptyBody,
      );
    } else {
      state = null;
    }
    final rows = state != null ? const <FolderEntry>[] : entries ?? const [];
    final count = (parent != null ? 1 : 0) + (state != null ? 1 : rows.length);
    return ListView.builder(
      key: const ValueKey('folder-browser-list'),
      shrinkWrap: true,
      itemCount: count,
      itemBuilder: (context, index) {
        if (parent != null) {
          if (index == 0) return _upRow(theme, l10n, parent);
          index--;
        }
        if (state != null) return state;
        return _folderRow(theme, l10n, rows[index]);
      },
    );
  }

  Widget _upRow(ThemeData theme, AppLocalizations l10n, String parent) =>
      KitRow(
        key: const ValueKey('folder-browser-up'),
        leading: KitRow.icon(context, AppIconography.chevronUp),
        title: l10n.folderBrowserUp,
        // Isolated left to right, so `/root` does not read `root/` in Arabic.
        supporting: TextSpan(
          text: '\u2066$parent\u2069',
          style: const TextStyle(fontFamily: AppTheme.monoFamily),
        ),
        onTap: _loading ? null : () => _load(parent),
      );

  Widget _folderRow(ThemeData theme, AppLocalizations l10n, FolderEntry entry) {
    final project = _isProject(entry);
    final known =
        _known.contains(entry.path) &&
        !isProtectedWorkspaceDirectory(entry.path);
    final String? mark = known
        ? l10n.folderBrowserProject
        : entry.isGit
        ? l10n.folderBrowserGit
        : null;
    return KitRow(
      key: ValueKey('in-app-project-${entry.name}'),
      leading: KitRow.icon(
        context,
        known
            ? AppIconography.projects
            : entry.isGit
            ? AppIconography.branch
            : AppIconography.folderOpen,
      ),
      title: entry.name,
      supporting: mark == null ? null : TextSpan(text: mark),
      trailing: project
          ? IconButton(
              key: ValueKey('folder-browse-${entry.name}'),
              tooltip: l10n.folderBrowserShowInside(entry.name),
              onPressed: _loading ? null : () => _load(entry.path),
              icon: Icon(
                AppIconography.chevronRight,
                size: 20,
                color: AppTheme.mutedOf(theme),
              ),
            )
          : const KitChevron(),
      onTap: _loading
          ? null
          : project
          ? () => Navigator.of(context).pop(FolderBrowserOpen(entry.path))
          : () => _load(entry.path),
    );
  }

  Widget _errorState(AppLocalizations l10n, Object error) {
    final problem = error is FolderListException ? error.problem : null;
    return KitStateView(
      key: const ValueKey('folder-browser-error'),
      size: KitStateSize.inline,
      icon: AppIconography.warning,
      tone: AppStatusTone.attention,
      title: l10n.folderBrowserErrorTitle,
      body: switch (problem) {
        FolderListProblem.notInstalled => l10n.folderBrowserErrorNotInstalled,
        FolderListProblem.missing => l10n.folderBrowserErrorMissing,
        FolderListProblem.denied => l10n.folderBrowserErrorDenied,
        FolderListProblem.linked => l10n.folderBrowserErrorLinked,
        _ => l10n.folderBrowserErrorFailed,
      },
      secondary: KitAction(
        key: const ValueKey('folder-browser-retry'),
        label: l10n.folderBrowserRetry,
        icon: AppIconography.retry,
        onPressed: () => _load(_path),
      ),
      details: error.toString(),
    );
  }

  Widget _actions(ThemeData theme, AppLocalizations l10n) {
    final entries = _entries;
    final settled = !_loading && _error == null && entries != null;
    final String? note = !settled || entries.isEmpty
        ? null
        : isProtectedWorkspaceDirectory(_path)
        ? l10n.folderBrowserHomeHere
        : _path == BuiltinLinux.projectsDir
        ? l10n.folderBrowserProjectsHere
        : null;
    final field = TextField(
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
        // The path isolated left to right inside the sentence (Arabic).
        helperText: l10n.projectFolderNewProjectHelp('⁦$_path⁩'),
        helperMaxLines: 3,
        errorText: _problem,
        errorMaxLines: 3,
      ),
    );
    final create = KitButton.secondary(
      key: const ValueKey('in-app-new-project-create'),
      label: l10n.projectFolderCreateAction,
      icon: AppIconography.folderAdd,
      expand: false,
      onPressed: _create,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (settled && _canOpenHere) ...[
            KitButton.primary(
              key: const ValueKey('folder-browser-open'),
              label: l10n.folderBrowserOpen(_nameOf(_path)),
              icon: AppIconography.folderOpen,
              onPressed: () =>
                  Navigator.of(context).pop(FolderBrowserOpen(_path)),
            ),
            const SizedBox(height: 16),
          ] else if (note != null) ...[
            Text(
              note,
              key: const ValueKey('folder-browser-note'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.mutedOf(theme),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
          ],
          SectionLabel.inline(l10n.projectFolderNewProject),
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 340
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [field, const SizedBox(height: 8), create],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: field),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: create,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: KitInset(
              child: KitButton.tertiary(
                key: const ValueKey('in-app-enter-path'),
                label: l10n.projectFolderEnterPath,
                onPressed: () =>
                    Navigator.of(context).pop(FolderBrowserEnterPath(_path)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
