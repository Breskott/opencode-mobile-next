part of '../chat_screen.dart';

/// The body of "Saved prompts": prompts kept on this device for this
/// server, newest first. The host opens it with [showKitSheet], which draws
/// the title, the close button and [loading]. Tapping a row restores it
/// into the draft at once; the host offers Undo (P3.2). Delete sits in the
/// row's menu and also acts at once: the prompt leaves the device now and
/// "Saved prompt deleted · Undo" puts it back exactly, so no confirmation
/// sheet stacks on this one (map prompt-stash-delete-sheet: remove).
///
/// The older drafts (saved before drafts named their server) live here too:
/// opening the sheet moves any that are left ([ConnectionController
/// .migrateOlderDrafts]); one that cannot move yet is named with a retry.
class _PromptStashSheet extends StatefulWidget {
  const _PromptStashSheet({
    required this.controller,
    required this.location,
    required this.profile,
    required this.loading,
  });
  final ConnectionController controller;
  final int location;
  final String profile;

  /// The sheet's one loading bar: on while the store is read or a restore
  /// is on its way out.
  final ValueNotifier<bool> loading;
  @override
  State<_PromptStashSheet> createState() => _PromptStashSheetState();
}

class _PromptStashSheetState extends State<_PromptStashSheet> {
  final _search = TextEditingController();
  String _query = '';
  String? _error;
  bool _deleting = false;
  bool _preparing = false;
  bool _invalidated = false;
  bool _readFailed = false;
  bool _migrationPending = false;
  List<StashedPrompt> _prompts = const [];

  bool get _current =>
      !_invalidated &&
      widget.controller.canUsePromptShelf &&
      widget.profile == widget.controller.promptShelfProfileID &&
      widget.location == widget.controller.locationRevision;
  bool get _unsafe => !_current || _preparing || _deleting || _readFailed;

  /// Tells the sheet frame whether to show its loading bar. After the
  /// frame, since the frame is this body's ancestor.
  void _syncLoading() {
    final busy = _preparing || _deleting;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.loading.value = busy;
    });
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.controller.profileDataChanges.addListener(_changed);
    _readPrompts();
    unawaited(_prepare());
  }

  void _readPrompts() {
    if (!_current) return;
    try {
      _prompts = widget.controller.promptStash;
    } catch (_) {
      _readFailed = true;
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() {
      if (!_current) _invalidated = true;
      if (_invalidated) {
        _prompts = const [];
      } else {
        _readPrompts();
      }
    });
  }

  Future<void> _prepare() async {
    if (!_current || _preparing || _deleting) return;
    setState(() {
      _preparing = true;
      _error = null;
    });
    try {
      await widget.controller.migrateOlderDrafts();
      if (!mounted || !_current) return;
      final deferred = await widget.controller.preparePromptStash(
        locationRevision: widget.location,
      );
      if (!mounted || !_current) return;
      setState(() {
        _readFailed = false;
        _migrationPending = deferred.isNotEmpty;
        _readPrompts();
      });
    } catch (_) {
      if (mounted && _current) setState(() => _readFailed = true);
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    widget.controller.removeListener(_changed);
    widget.controller.profileDataChanges.removeListener(_changed);
    super.dispose();
  }

  void _restore(StashedPrompt prompt) {
    if (_unsafe || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    setState(() => _deleting = true);
    Navigator.pop(context, prompt);
  }

  /// Delete at once, with Undo. The prompt leaves the device now; Undo
  /// puts it back exactly (text, attachments, references, date).
  Future<void> _delete(StashedPrompt prompt) async {
    if (_unsafe) return;
    final controller = widget.controller;
    final strings = _chatL10n(context);
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      final undo = await controller.deleteSavedPrompt(
        prompt.id,
        locationRevision: widget.location,
      );
      if (!mounted) return;
      showKitUndo(
        context,
        message: strings.promptStashDeleted,
        key: ValueKey('stash-deleted-${prompt.id}'),
        onUndo: () => controller.undoSavedPrompt(undo),
      );
    } catch (_) {
      if (mounted && _current) {
        setState(() => _error = strings.promptStashDeleteFailed);
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  bool _matches(StashedPrompt prompt, String query) {
    if (query.isEmpty) return true;
    final fields = <String>[
      prompt.text,
      ...prompt.attachmentNames,
      if (prompt.directory != null) prompt.directory!,
      if (prompt.workspace != null) prompt.workspace!,
      for (final reference in prompt.references) reference.description,
    ];
    return fields.any((field) => field.toLowerCase().contains(query));
  }

  String _supporting(BuildContext context, StashedPrompt prompt) {
    final l10n = _chatL10n(context);
    return [
      MaterialLocalizations.of(
        context,
      ).formatMediumDate(DateTime.fromMillisecondsSinceEpoch(prompt.createdAt)),
      if (prompt.attachmentCount > 0)
        l10n.promptStashAttachments(prompt.attachmentCount),
      if (prompt.references.isNotEmpty)
        l10n.promptStashReferences(prompt.references.length),
      if (prompt.locationBound)
        KitBidi.ltr(prompt.directory ?? l10n.promptDefaultLocation),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final l10n = _chatL10n(context);
      final query = _query.trim().toLowerCase();
      final prompts = _prompts.where((p) => _matches(p, query)).toList()
        // Newest first.
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final current = _current;
      final error = !current
          ? l10n.promptStashScopeChanged
          : _readFailed
          ? l10n.promptStashReadFailed
          : _error;
      final unsafe = _unsafe;
      final busyReason = !current ? l10n.promptStashScopeChanged : null;
      _syncLoading();
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KitSearchField(
            controller: _search,
            label: l10n.promptStashSearch,
            enabled: current,
            disabledReason: busyReason,
            resultCount: query.isEmpty ? null : prompts.length,
            onChanged: (value) => setState(() => _query = value),
          ),
          if (error != null)
            KitNotice(
              key: const Key('prompt-stash-error'),
              tone: AppStatusTone.failure,
              message: error,
              actions: [
                if (current && _readFailed)
                  KitAction(
                    label: l10n.commonRetry,
                    onPressed: _preparing ? null : () => unawaited(_prepare()),
                  ),
              ],
            ),
          if (widget.controller.olderDraftsBlocker case final blocker?
              when current)
            KitNotice(
              key: const Key('older-drafts-waiting'),
              message: blocker == DraftMigrationBlocker.full
                  ? l10n.promptStashOlderDraftsFull
                  : l10n.promptStashOlderDraftsWaiting,
              actions: [
                KitAction(
                  label: l10n.commonRetry,
                  onPressed: _preparing || _deleting
                      ? null
                      : () => unawaited(_prepare()),
                ),
              ],
            ),
          if (_migrationPending && current)
            KitNotice(
              message: l10n.promptStashMigrationPending,
              actions: [
                KitAction(
                  label: l10n.commonRetry,
                  onPressed: _preparing || _deleting
                      ? null
                      : () => unawaited(_prepare()),
                ),
              ],
            ),
          if (prompts.isEmpty && error == null && !_preparing)
            if (query.isNotEmpty)
              KitSearchNoMatch(
                query: _query.trim(),
                onClear: () {
                  _search.clear();
                  setState(() => _query = '');
                },
              )
            else
              KitStateView(
                key: const Key('prompt-stash-empty'),
                size: KitStateSize.inline,
                icon: AppIconography.bookmarks,
                title: l10n.promptStashEmptyTitle,
                body: l10n.promptStashEmptyBody,
              ),
          if (prompts.isNotEmpty)
            KitRowGroup(
              leadingIcons: false,
              children: [
                for (final prompt in prompts)
                  KitRow(
                    key: ValueKey('restore-stash-${prompt.id}'),
                    title: prompt.text.isEmpty
                        ? l10n.promptStashContextOnly
                        : prompt.text,
                    titleMaxLines: 2,
                    supporting: TextSpan(text: _supporting(context, prompt)),
                    supportingMaxLines: 2,
                    enabled: !unsafe,
                    disabledReason: unsafe
                        ? (busyReason ?? l10n.promptStashBusy)
                        : null,
                    onTap: unsafe ? null : () => _restore(prompt),
                    menuLabel: l10n.promptStashRowActions,
                    menu: unsafe
                        ? const []
                        : [
                            KitMenuItem(
                              key: ValueKey('restore-stash-menu-${prompt.id}'),
                              icon: AppIconography.unarchive,
                              label: l10n.promptStashRestoreToDraft,
                              onSelected: () => _restore(prompt),
                            ),
                            KitMenuItem(
                              key: ValueKey('delete-stash-${prompt.id}'),
                              icon: AppIconography.delete,
                              label: l10n.promptStashDeleteAction,
                              destructive: true,
                              onSelected: () => unawaited(_delete(prompt)),
                            ),
                          ],
                  ),
              ],
            ),
        ],
      );
    },
  );
}
