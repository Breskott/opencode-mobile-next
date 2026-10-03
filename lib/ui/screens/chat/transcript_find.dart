part of '../chat_screen.dart';

/// Find in this conversation, docked under the top bar: the field and its
/// close, the count once ("3 of 12 matches") with previous and next, and,
/// only while part of the history is not loaded, what is missing and the
/// way to search it all. The hits themselves are marked in the transcript.
class _TranscriptFindBar extends StatefulWidget {
  const _TranscriptFindBar({
    required this.controller,
    required this.focusNode,
    required this.count,
    required this.current,
    required this.hasOlder,
    required this.loading,
    required this.onChanged,
    required this.onNext,
    required this.onPrevious,
    required this.onClose,
    required this.onLoadOlder,
    required this.needsReload,
    required this.searchingAll,
    required this.onCancelLoading,
    this.error,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final int count;
  final int current;
  final bool hasOlder;
  final bool loading;
  final bool needsReload;
  final bool searchingAll;
  final VoidCallback onCancelLoading;
  final Object? error;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onClose;
  final VoidCallback onLoadOlder;

  @override
  State<_TranscriptFindBar> createState() => _TranscriptFindBarState();
}

class _TranscriptFindBarState extends State<_TranscriptFindBar> {
  late String _text = widget.controller.text;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(_TranscriptFindBar old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
      _text = widget.controller.text;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  /// Every edit the person makes goes to the screen at once (the screen
  /// settles the search itself). A selection change is not an edit, and a
  /// query the screen set itself (from the timeline) is already searched.
  void _onText() {
    final text = widget.controller.text;
    if (text == _text) return;
    setState(() => _text = text);
    if (widget.focusNode.hasFocus) widget.onChanged(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    final tokens = KitTokens.of(context);
    final count = widget.count;
    final error = widget.error;
    final searched = _text.trim().isNotEmpty;
    final older = KitAction(
      key: const ValueKey('transcript-find-older'),
      label: widget.needsReload ? l10n.historyReload : l10n.transcriptFindAll,
      working: widget.loading,
      onPressed: widget.loading ? () {} : widget.onLoadOlder,
    );
    return CallbackShortcuts(
      key: const ValueKey('transcript-find-bar'),
      // Esc clears a query first (the field's own); with none it closes.
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsetsDirectional.fromSTEB(
          tokens.gutter,
          tokens.space2,
          tokens.space1,
          tokens.space2,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: KitSearchField(
                  label: l10n.transcriptFindHint,
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  // Clear (its button) may run before the field has focus.
                  onChanged: (query) {
                    if (query.isEmpty) widget.onChanged(query);
                  },
                  onSubmitted: (_) => widget.onNext(),
                  fieldKey: const ValueKey('transcript-find-input'),
                ),
              ),
              KitIconButton(
                icon: AppIconography.close,
                tooltip: l10n.transcriptFindClose,
                onPressed: widget.onClose,
              ),
            ],
          ),
          if (searched)
            Padding(
              padding: EdgeInsetsDirectional.only(end: tokens.space1),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: KitText(
                        count == 0
                            ? l10n.transcriptFindNone
                            : l10n.transcriptFindCount(
                                widget.current + 1,
                                count,
                              ),
                        role: KitTextRole.secondary,
                        tone: KitTextTone.secondary,
                        tabular: true,
                      ),
                    ),
                  ),
                  KitIconButton(
                    key: const ValueKey('transcript-find-previous'),
                    icon: AppIconography.chevronUp,
                    tooltip: l10n.transcriptFindPrevious,
                    onPressed: count == 0 ? null : widget.onPrevious,
                  ),
                  KitIconButton(
                    key: const ValueKey('transcript-find-next'),
                    icon: AppIconography.chevronDown,
                    tooltip: l10n.transcriptFindNext,
                    onPressed: count == 0 ? null : widget.onNext,
                  ),
                ],
              ),
            ),
          if (error != null)
            KitNotice.error(
              key: const ValueKey('transcript-find-older-error'),
              message: productErrorText(error, l10n: l10n),
              error: error,
              retry: older,
            )
          else if (widget.searchingAll)
            KitNotice(
              key: const ValueKey('transcript-find-searching-all'),
              icon: AppIconography.history,
              tone: AppStatusTone.progress,
              message: l10n.transcriptFindPartial,
              actions: [
                KitAction(
                  key: const ValueKey('transcript-find-cancel-all'),
                  label: l10n.transcriptFindStopSearchingAll,
                  onPressed: widget.onCancelLoading,
                ),
              ],
            )
          else if (widget.hasOlder)
            KitNotice(
              key: const ValueKey('transcript-find-partial'),
              icon: AppIconography.history,
              message: l10n.transcriptFindPartial,
              actions: [older],
            ),
        ],
      ),
    );
  }
}
