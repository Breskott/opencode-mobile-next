import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/server_gateway.dart' show ProductException;
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/profiles.dart' show ProfileLocation;
import '../app_theme.dart';
import 'product_states.dart';

/// Working in several projects at once, from the Work tab.
///
/// The app shows one project at a time; the server does not work that way.
/// A run started in one project keeps going when you look at another, and
/// until now it simply vanished from view. This panel keeps the others in
/// reach: the projects you have used recently are one tap away, each marked
/// when something is running there, and the conversations going on in them
/// are listed under the current project's own, so you can step into one
/// without first hunting for its project.
class OtherProjectsPanel extends StatefulWidget {
  const OtherProjectsPanel({super.key, required this.controller});

  final ConnectionController controller;

  @override
  State<OtherProjectsPanel> createState() => _OtherProjectsPanelState();
}

class _OtherProjectsPanelState extends State<OtherProjectsPanel> {
  List<ElsewhereConversation> _elsewhere = const [];
  (int, int, String?)? _loadedFor;
  Timer? _timer;
  String? _opening;
  String? _switching;
  bool _loading = false;

  ConnectionController get _conn => widget.controller;

  (int, int, String?) get _scope =>
      (_conn.connectionRevision, _conn.locationRevision, _conn.profile?.id);

  @override
  void initState() {
    super.initState();
    _conn.addListener(_changed);
    // What is running elsewhere changes without any event reaching this
    // project's stream, so it is looked up again while the tab is open.
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _load());
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _conn.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    // The strip reads the controller directly (recent projects, the current
    // one), so any change redraws it; a new project or server reloads the
    // list as well.
    if (mounted) setState(() {});
    if (_loadedFor != _scope) _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    final scope = _scope;
    try {
      final found = await _conn.conversationsElsewhere();
      if (!mounted || scope != _scope) return;
      setState(() {
        _elsewhere = found;
        _loadedFor = scope;
      });
    } catch (_) {
      // A convenience list: the Work tab stands without it.
      if (mounted && scope == _scope) setState(() => _loadedFor = scope);
    } finally {
      _loading = false;
      // The project changed while this was in flight: look again now, not
      // at the next tick.
      if (mounted && scope != _scope) unawaited(_load());
    }
  }

  /// Hosts without the app's delegates (isolated previews, some tests) fall
  /// back to English, as the rest of the Work tab does.
  static AppLocalizations _strings(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      lookupAppLocalizations(const Locale('en'));

  static String _name(String directory) {
    final parts = directory.split('/').where((part) => part.isNotEmpty);
    return parts.isEmpty ? directory : parts.last;
  }

  Future<void> _switchTo(ProfileLocation location) async {
    if (_switching != null) return;
    setState(() => _switching = location.directory);
    try {
      await _conn.selectLocation(
        directory: location.directory,
        workspace: location.workspace,
      );
      final error = _conn.locationError;
      if (error != null && mounted) showProductError(context, error);
    } catch (error) {
      if (mounted) showProductError(context, error);
    } finally {
      if (mounted) setState(() => _switching = null);
    }
  }

  Future<void> _open(ElsewhereConversation item) async {
    if (_opening != null) return;
    final id = item.session.id;
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) return;
    final profileID = _conn.profile?.id;
    setState(() => _opening = id);
    final navigator = Navigator.of(context);
    final strings = _strings(context);
    try {
      // The conversation's project becomes the current one: everything a
      // chat needs (its events, approvals, files) is per project.
      await _conn.selectLocationForExistingSession(
        directory: item.directory,
        workspace: item.session.workspaceID,
      );
      if (_conn.profile?.id != profileID || _conn.directory != item.directory) {
        throw ProductException(strings.e7WorkspaceLocationChangedReturn);
      }
      await navigator.pushNamed('/chat/$id');
    } catch (error) {
      if (mounted) showProductError(context, error);
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = _strings(context);
    final here = _conn.directory;
    final recents = [
      for (final location in _conn.recentLocations)
        if (location.directory != null && location.directory != here) location,
    ];
    if (recents.isEmpty && _elsewhere.isEmpty) return const SizedBox.shrink();
    final runningIn = <String, int>{};
    for (final item in _elsewhere) {
      if (item.running) {
        runningIn[item.directory] = (runningIn[item.directory] ?? 0) + 1;
      }
    }
    return Column(
      key: const Key('other-projects-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (recents.isNotEmpty)
          SingleChildScrollView(
            key: const Key('recent-projects-strip'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
            child: Row(
              spacing: 8,
              children: [
                for (final location in recents)
                  _ProjectChip(
                    key: ValueKey('recent-project-${location.directory}'),
                    name: _name(location.directory!),
                    running: runningIn[location.directory] ?? 0,
                    busy: _switching == location.directory,
                    tooltip: location.directory!,
                    onTap: () => _switchTo(location),
                    onForget: () =>
                        _conn.forgetRecentLocation(location.directory!),
                    forgetLabel: strings.otherProjectsForget,
                  ),
              ],
            ),
          ),
        if (_elsewhere.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 2),
            child: Text(
              strings.otherProjectsTitle,
              style: theme.textTheme.titleSmall,
            ),
          ),
          for (final item in _elsewhere)
            InkWell(
              key: ValueKey('elsewhere-${item.session.id}'),
              onTap: () => _open(item),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: item.running
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.session.title?.trim().isNotEmpty == true
                                  ? item.session.title!.trim()
                                  : strings.otherProjectsUntitled,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.running
                                  ? '${item.project} · ${strings.workRunning}'
                                  : item.project,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: item.running
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_opening == item.session.id)
                        const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          AppIconography.chevronRight,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ProjectChip extends StatelessWidget {
  const _ProjectChip({
    super.key,
    required this.name,
    required this.running,
    required this.busy,
    required this.tooltip,
    required this.onTap,
    required this.onForget,
    required this.forgetLabel,
  });

  final String name;
  final int running;
  final bool busy;
  final String tooltip;
  final VoidCallback onTap;
  final VoidCallback onForget;
  final String forgetLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      // Long-press takes a project off the strip; it is not deleted anywhere.
      onLongPress: () async {
        final forget = await showMenu<bool>(
          context: context,
          position: _menuPosition(context),
          items: [PopupMenuItem(value: true, child: Text(forgetLabel))],
        );
        if (forget == true) onForget();
      },
      // No tooltip: it would claim the long-press that removes the chip. The
      // full path is in the project header once you are there.
      child: Semantics(
        label: tooltip,
        child: ActionChip(
          onPressed: busy ? null : onTap,
          materialTapTargetSize: MaterialTapTargetSize.padded,
          side: BorderSide.none,
          backgroundColor: theme.colorScheme.surfaceContainerHigh,
          avatar: busy
              ? const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  AppIconography.files,
                  size: 16,
                  color: running > 0
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
          label: Text(
            running > 0 ? '$name · $running' : name,
            style: theme.textTheme.labelMedium,
          ),
        ),
      ),
    );
  }

  static RelativeRect _menuPosition(BuildContext context) {
    final box = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    return RelativeRect.fromLTRB(
      origin.dx,
      origin.dy + box.size.height,
      overlay.size.width - origin.dx - box.size.width,
      0,
    );
  }
}
