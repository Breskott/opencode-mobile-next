import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../../builtin/builtin_folders.dart';
import '../../domain/workspace_paths.dart';
import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import '../kit/kit_bidi.dart';
import '../kit/kit_buttons.dart';
import '../kit/kit_field.dart';
import '../kit/kit_icon_button.dart';
import '../kit/kit_motion.dart';
import '../kit/kit_notice.dart';
import '../kit/kit_progress.dart';
import '../kit/kit_row.dart';
import '../kit/kit_row_parts.dart';
import '../kit/kit_section_label.dart';
import '../kit/kit_sheet.dart';
import '../kit/kit_since.dart';
import '../kit/kit_state_view.dart';
import '../kit/kit_text.dart';
import '../kit/kit_tokens.dart';
import '../kit/scenes/folders_open_scene.dart';
import 'product_states.dart' show productErrorDetails;

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

/// "Open a project" for a server on this phone (OpenCode inside the app, or
/// the one this app runs in Termux): the folders of its Ubuntu, browsed from
/// the projects folder; [list] says how they are read.
///
/// Built from kit parts only (revamp unit shared-work-1): the one sheet
/// frame ([KitSheet]) with its title, a scrolling body and pinned actions.
/// The body is the folder being shown (left to right, mono), then the
/// folders on one panel of [KitRow]s, then "New project" ([KitField] and
/// Create). A project (a git repository, a project OpenCode knows, or any
/// folder straight in the projects folder) opens with a tap, and its
/// chevron shows what is in it; any other folder is gone into with a tap.
/// "Up one folder" goes back up to `/`. Pinned below: "Open `<folder>`" for
/// the folder being shown, and "Enter a path".
///
/// States (project-folder-browser map record):
/// - loading: skeleton rows once a listing is slower than a touch answer;
///   after [KitMotion.escalateAfter] a word says the phone is still reading
///   (a Termux read may take up to 15 s), through [KitSince];
/// - empty: an empty folder says so; an empty projects folder (first run)
///   offers its first step, "New project", which puts the cursor in the
///   name field;
/// - error: what went wrong, "Try again", and "Up one folder" when there is
///   a folder above (a permission error is left by going up);
/// - disabled: the rows do nothing while a listing runs.
///
/// The home folder and `/` are never offered as a project
/// (`workspace_paths.dart`); the projects folder itself is where projects
/// live, so it is not offered either.
///
/// Not here yet: cloning a repository needs a gateway call (wave 3), and
/// recent projects first needs their order from the server.
class FolderBrowserSheet extends StatefulWidget {
  const FolderBrowserSheet({
    super.key,
    required this.list,
    this.knownProjects,
    this.start = managedProjectsDirectory,
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
  final _nameFocus = FocusNode(debugLabel: 'folder-browser-name');
  late String _path = BuiltinRootfsFolders.normalize(widget.start) ?? '/';
  List<FolderEntry>? _entries;
  Object? _error;
  bool _loading = true;

  /// When the listing now running began; null when none runs.
  DateTime? _loadingSince;

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
    _nameFocus.dispose();
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
      _loadingSince = clock.now();
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
      _loadingSince = null;
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
              managedProjectsDirectory);

  /// The folder shown can be opened as it is: not home or `/`, and not the
  /// projects folder that holds the projects.
  bool get _canOpenHere =>
      !isProtectedWorkspaceDirectory(_path) &&
      _path != managedProjectsDirectory;

  bool get _settled => !_loading && _error == null && _entries != null;

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
    KitSheet.close<FolderBrowserChoice>(
      context,
      exists ? FolderBrowserOpen(path) : FolderBrowserCreate(path),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final media = MediaQuery.of(context);
    final maxHeight =
        (media.size.height - media.viewInsets.bottom - media.padding.top) * .9;
    // While the name is typed the keyboard leaves little room: the folders
    // step aside for the field, which keeps its place in the tree (and its
    // focus).
    final typing = media.viewInsets.bottom > 0;
    final canOpen = _settled && _canOpenHere;
    return SafeArea(
      child: Padding(
        padding: EdgeInsetsDirectional.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: KitSheet(
            key: const ValueKey('in-app-projects'),
            title: l10n.projectFolderInAppTitle,
            // The route this sheet opens in draws the drag handle.
            handle: false,
            onClose: () => KitSheet.close<FolderBrowserChoice>(context),
            loading: _loading && !_showSkeleton,
            primary: canOpen
                ? KitAction(
                    key: const ValueKey('folder-browser-open'),
                    label: l10n.folderBrowserOpen(_nameOf(_path)),
                    icon: AppIconography.folderOpen,
                    onPressed: () => KitSheet.close<FolderBrowserChoice>(
                      context,
                      FolderBrowserOpen(_path),
                    ),
                  )
                : null,
            tertiary: [
              KitAction(
                key: const ValueKey('in-app-enter-path'),
                label: l10n.projectFolderEnterPath,
                onPressed: () => KitSheet.close<FolderBrowserChoice>(
                  context,
                  FolderBrowserEnterPath(_path),
                ),
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _where(context, l10n, canOpen: canOpen),
                if (!typing) _folders(context, l10n),
                _newProject(context, l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The folder being shown, and why it cannot be opened when it cannot.
  Widget _where(
    BuildContext context,
    AppLocalizations l10n, {
    required bool canOpen,
  }) {
    final tokens = KitTokens.of(context);
    final entries = _entries;
    final String? note = canOpen || !_settled || entries!.isEmpty
        ? null
        : isProtectedWorkspaceDirectory(_path)
        ? l10n.folderBrowserHomeHere
        : _path == managedProjectsDirectory
        ? l10n.folderBrowserProjectsHere
        : null;
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: tokens.space3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KitText.mono(
            _path,
            key: const ValueKey('folder-browser-path'),
            // One line that keeps the root and the folder's own name.
            cut: KitMonoCut.middle,
            tone: KitTextTone.secondary,
            semanticsLabel: l10n.folderBrowserCurrent(_path),
          ),
          if (note != null) ...[
            SizedBox(height: tokens.space2),
            KitText(
              note,
              key: const ValueKey('folder-browser-note'),
              role: KitTextRole.secondary,
            ),
          ],
        ],
      ),
    );
  }

  /// "Up one folder", the folders on one panel, and the state of the
  /// listing (loading, slow, empty, error).
  Widget _folders(BuildContext context, AppLocalizations l10n) {
    final tokens = KitTokens.of(context);
    final parent = BuiltinRootfsFolders.parentOf(_path);
    final entries = _entries;
    final error = _error;
    final Widget? state;
    if (_loading && _showSkeleton) {
      state = _loadingState(l10n);
    } else if (error != null) {
      state = _errorState(l10n, error, parent);
    } else if (entries != null && entries.isEmpty) {
      state = _emptyState(l10n);
    } else {
      state = null;
    }
    final rows = state != null ? const <FolderEntry>[] : entries ?? const [];
    // After an error the state itself offers the way up, next to its
    // words; the row would say it twice.
    final up = error == null ? parent : null;
    return KeyedSubtree(
      key: const ValueKey('folder-browser-list'),
      child: Padding(
        padding: EdgeInsetsDirectional.only(bottom: tokens.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (up != null || rows.isNotEmpty)
              KitRowGroup(
                margin: EdgeInsetsDirectional.zero,
                children: [
                  if (up != null) _upRow(context, l10n, up),
                  for (final entry in rows) _folderRow(context, l10n, entry),
                ],
              ),
            if (state != null) ...[
              if (up != null) SizedBox(height: tokens.space3),
              state,
            ],
          ],
        ),
      ),
    );
  }

  Widget _upRow(BuildContext context, AppLocalizations l10n, String parent) =>
      KitRow(
        key: const ValueKey('folder-browser-up'),
        leading: KitRow.icon(context, AppIconography.chevronUp),
        title: l10n.folderBrowserUp,
        // Isolated left to right, so `/root` never reads `root/` in a
        // right-to-left sentence.
        supporting: TextSpan(
          text: KitBidi.ltr(parent),
          style: KitText.styleFor(KitTextRole.mono),
        ),
        enabled: !_loading,
        onTap: () => _load(parent),
      );

  Widget _folderRow(
    BuildContext context,
    AppLocalizations l10n,
    FolderEntry entry,
  ) {
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
          ? KitIconButton(
              key: ValueKey('folder-browse-${entry.name}'),
              icon: AppIconography.chevronRight,
              size: 20,
              tooltip: l10n.folderBrowserShowInside(entry.name),
              onPressed: _loading ? null : () => _load(entry.path),
            )
          : const KitChevron(),
      enabled: !_loading,
      onTap: project
          ? () => KitSheet.close<FolderBrowserChoice>(
              context,
              FolderBrowserOpen(entry.path),
            )
          : () => _load(entry.path),
    );
  }

  /// Skeleton rows; once the read has taken [KitMotion.escalateAfter], one
  /// word that it is still going (a Termux read may take up to 15 s).
  Widget _loadingState(AppLocalizations l10n) => KitSince(
    since: _loadingSince,
    builder: (context, status) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status.isSlow) ...[
          KitNotice(
            key: const ValueKey('folder-browser-slow'),
            icon: AppIconography.clock,
            title: l10n.folderBrowserSlowTitle,
            message: l10n.folderBrowserSlowBody,
          ),
          SizedBox(height: KitTokens.of(context).space3),
        ],
        const KitSkeletonRows(count: 4),
      ],
    ),
  );

  Widget _emptyState(AppLocalizations l10n) {
    final projects = _path == managedProjectsDirectory;
    return KitStateView(
      key: const ValueKey('folder-browser-empty'),
      size: KitStateSize.inline,
      icon: AppIconography.folderOpen,
      illustration: const KitFoldersOpenScene(),
      title: projects
          ? l10n.folderBrowserNoProjectsTitle
          : l10n.folderBrowserEmptyTitle,
      body: projects
          ? l10n.folderBrowserNoProjectsBody
          : l10n.folderBrowserEmptyBody,
      // The first run's first step: the cursor goes to the name.
      primary: projects
          ? KitAction(
              key: const ValueKey('folder-browser-first-project'),
              label: l10n.folderBrowserFirstProject,
              icon: AppIconography.folderAdd,
              onPressed: _nameFocus.requestFocus,
            )
          : null,
    );
  }

  Widget _errorState(AppLocalizations l10n, Object error, String? parent) {
    final problem = error is FolderListException ? error.problem : null;
    return KitStateView(
      key: const ValueKey('folder-browser-error'),
      size: KitStateSize.inline,
      icon: AppIconography.warning,
      // A neutral glyph with the words, never the danger colour (LOOK-5).
      tone: AppStatusTone.neutral,
      title: l10n.folderBrowserErrorTitle,
      body: switch (problem) {
        FolderListProblem.notInstalled => l10n.folderBrowserErrorNotInstalled,
        FolderListProblem.missing => l10n.folderBrowserErrorMissing,
        FolderListProblem.denied => l10n.folderBrowserErrorDenied,
        FolderListProblem.linked => l10n.folderBrowserErrorLinked,
        FolderListProblem.timedOut => l10n.folderBrowserErrorTimedOut,
        _ => l10n.folderBrowserErrorFailed,
      },
      secondary: KitAction(
        key: const ValueKey('folder-browser-retry'),
        label: l10n.folderBrowserRetry,
        icon: AppIconography.retry,
        onPressed: () => _load(_path),
      ),
      // A folder the app may not read is left by going up.
      tertiary: [
        if (parent != null)
          KitAction(
            key: const ValueKey('folder-browser-error-up'),
            label: l10n.folderBrowserUp,
            icon: AppIconography.chevronUp,
            onPressed: () => _load(parent),
          ),
      ],
      details: productErrorDetails(error),
    );
  }

  /// "New project": a name, made inside the folder being shown.
  Widget _newProject(BuildContext context, AppLocalizations l10n) {
    final tokens = KitTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KitSectionLabel(
          l10n.projectFolderNewProject,
          margin: EdgeInsets.zero,
          gapBefore: 0,
        ),
        KitField(
          key: const ValueKey('in-app-new-project-name'),
          controller: _name,
          focusNode: _nameFocus,
          label: l10n.projectFolderProjectNameLabel,
          hint: l10n.projectFolderNameHint,
          helper: l10n.projectFolderNewProjectHelp(KitBidi.ltr(_path)),
          error: _problem,
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_problem != null) setState(() => _problem = null);
          },
          onSubmitted: (_) => _create(),
        ),
        SizedBox(height: tokens.space2),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: KitButton.secondary(
            key: const ValueKey('in-app-new-project-create'),
            label: l10n.projectFolderCreateAction,
            icon: AppIconography.folderAdd,
            expand: false,
            onPressed: _create,
          ),
        ),
      ],
    );
  }
}
