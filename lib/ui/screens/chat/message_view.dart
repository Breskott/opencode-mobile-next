part of '../chat_screen.dart';

class _PromptErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  final VoidCallback? onChooseModel;

  const _PromptErrorBanner({
    required this.message,
    required this.onDismiss,
    this.onChooseModel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Servers may attach a stack trace; the user reads one line and can open
    // the rest. A "model not found" answer gets the button that fixes it.
    final words = agentErrorWords(message, _chatL10n(context));
    final headline = words.headline;
    // The server's exact words stay one tap away whenever the sentence shown
    // is not theirs.
    final hasDetails = words.humanized || errorHasDetails(message);
    final kind = MessageErrorKind.refineFromText(
      MessageErrorKind.unknown,
      message,
    );
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        key: const ValueKey('prompt-error-banner'),
        margin: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 0),
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 4, 6),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  AppIconography.error,
                  size: 20,
                  color: scheme.onErrorContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        key: const ValueKey('prompt-error-headline'),
                        style: TextStyle(
                          color: scheme.onErrorContainer,
                          height: 1.35,
                        ),
                      ),
                      if (words.hint case final hint?)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            hint,
                            key: const ValueKey('prompt-error-hint'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onErrorContainer.withValues(
                                alpha: .8,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _chatL10n(context).chatUiDismissPromptError,
                  visualDensity: VisualDensity.compact,
                  onPressed: onDismiss,
                  icon: Icon(
                    AppIconography.close,
                    size: 19,
                    color: scheme.onErrorContainer,
                  ),
                ),
              ],
            ),
            if (hasDetails ||
                (kind == MessageErrorKind.modelNotFound &&
                    onChooseModel != null))
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (hasDetails)
                    TextButton(
                      key: const ValueKey('prompt-error-details'),
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.onErrorContainer,
                      ),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(_chatL10n(context).chatUiErrorDetails),
                          content: SingleChildScrollView(
                            child: SelectableText(
                              message,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: AppTheme.monoFamily,
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(_chatL10n(context).isolatedTaskClose),
                            ),
                          ],
                        ),
                      ),
                      child: Text(_chatL10n(context).chatUiDetails),
                    ),
                  if (kind == MessageErrorKind.modelNotFound &&
                      onChooseModel != null)
                    FilledButton.tonal(
                      key: const ValueKey('prompt-error-choose-model'),
                      onPressed: onChooseModel,
                      child: Text(_chatL10n(context).chatUiChooseModel),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Suggestion chips for an empty transcript, seeded from the active location.
///
/// With a project directory selected, the first chip names that project so
/// the invitation matches where the session actually runs. With no directory
/// (a fresh server with zero projects serves its own default directory, which
/// usually has no git repository), the project- and git-dependent chips are
/// replaced with one that always works.
@visibleForTesting
List<String> emptyTranscriptSuggestions({
  required String? directory,
  AppLocalizations? l10n,
}) {
  final strings = l10n ?? lookupAppLocalizations(const Locale('en'));
  final trimmed = directory?.trim() ?? '';
  if (trimmed.isEmpty) {
    return [
      strings.chatUiListWhatSInThisDirectory,
      strings.chatUiFindAndFixABug,
    ];
  }
  final parts = trimmed
      .replaceAll('\\', '/')
      .split('/')
      .where((part) => part.isNotEmpty)
      .toList();
  final name = parts.isEmpty ? trimmed : parts.last;
  return [
    strings.chatUiExplainProject(name),
    strings.chatUiWhatChangedRecently,
    strings.chatUiFindAndFixABug,
  ];
}

/// The first thing a new session shows: a prompt-shaped invitation to act,
/// with suggestions that insert real starting points into the composer.
class _EmptyTranscript extends StatelessWidget {
  const _EmptyTranscript({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  List<String> _fallbackSuggestions(BuildContext context) => [
    _chatL10n(context).chatUiExplainThisProject,
    _chatL10n(context).chatUiWhatChangedRecently,
    _chatL10n(context).chatUiFindAndFixABug,
  ];

  /// Resolves the chip list from the live connection when a provider scope is
  /// available; hosts without one (isolated widget tests) keep the static
  /// defaults.
  List<String> _suggestionsFor(BuildContext context) {
    try {
      final directory = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(connProvider).directory;
      return emptyTranscriptSuggestions(
        directory: directory,
        l10n: _chatL10n(context),
      );
    } catch (_) {
      return _fallbackSuggestions(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: _entrance(
                  reduceMotion,
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '>',
                            style: theme.textTheme.headlineSmall!.copyWith(
                              color: theme.colorScheme.primary,
                              fontFamily: AppTheme.monoFamily,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 11,
                            height: 22,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: .45,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _chatL10n(context).chatUiStartCoding,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _chatL10n(
                          context,
                        ).chatUiDescribeAChangeAskAboutThisProject,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final suggestion in _suggestionsFor(context))
                            ActionChip(
                              key: ValueKey('empty-suggestion-$suggestion'),
                              label: Text(suggestion),
                              onPressed: () => onSuggestion(suggestion),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // The "more" affordance is drawn as the same Material
                      // icon the meta row uses: Roboto has no glyph for the
                      // midline-ellipsis character, which rendered as a box.
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: _chatL10n(
                                context,
                              ).chatUiTipTypeForCommandsTap,
                            ),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Icon(
                                AppIconography.more,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            TextSpan(
                              text: _chatL10n(
                                context,
                              ).chatUiUnderAMessageForActions,
                            ),
                          ],
                        ),
                        key: const ValueKey('empty-transcript-tip'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _entrance(bool reduceMotion, Widget child) => reduceMotion
      ? child
      : TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: child,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 10),
              child: child,
            ),
          ),
        );
}

/// A floating affordance shown when the transcript is scrolled away from the
/// newest message; tapping returns to the live end of the conversation.
class _JumpToLatestButton extends StatelessWidget {
  const _JumpToLatestButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pill = Material(
      key: const ValueKey('jump-to-latest'),
      color: theme.colorScheme.surfaceContainerHigh,
      elevation: 3,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Tooltip(
          message: _chatL10n(context).chatUiJumpToLatest,
          // 48dp target: this pill floats over a scrolling list, where
          // undersized targets cause accidental transcript scrolls.
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(
              AppIconography.down,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return pill;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: pill,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.scale(scale: .9 + t * .1, child: child),
      ),
    );
  }
}

/// A floating chip over long transcripts naming how much history sits above,
/// opening the timeline for direct navigation.
class _EarlierMessagesPill extends StatelessWidget {
  const _EarlierMessagesPill({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: const ValueKey('earlier-messages-pill'),
      color: theme.colorScheme.surfaceContainerHigh,
      elevation: 2,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        // 44dp floor: the pill floats over the scrolling transcript, so an
        // undersized target scrolls the list instead of opening the timeline.
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 10, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _chatL10n(context).chatUiEarlierMessageCount(count),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Icon(
                AppIconography.chevronDown,
                size: 15,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Finds the mapper's v2-only variant tag on a message, if any: a part whose
/// `type` starts with `v2:` (see `mapApi2Message`). v1 servers never emit
/// these, and `Part.isRenderable` is false for them, so the v1 rendering
/// path is untouched.
@visibleForTesting
Part? v2VariantPart(MessageWithParts message) {
  for (final part in message.parts) {
    if (part.type.startsWith('v2:')) return part;
  }
  return null;
}

// The transcript's vocabulary. The server stores a conversation as a flat
// list of messages, and that list is not how a person reads it:
//
//  * A **prompt** is what you sent: your words and attachments.
//  * A **turn** is one prompt and everything the agent did about it, until it
//    stopped and handed back to you. It is the unit a reader thinks in, and
//    the unit that gets one footer (model, usage, the "more" control).
//  * A **step** is one model call inside a turn, which the server stores as
//    one assistant message: a thought, perhaps a sentence, some tool calls.
//    A long turn is dozens of them. The boundary between two steps is
//    plumbing and is never drawn.
//  * A **notice** is something that happened during a turn and that nobody
//    typed: the project moved, instructions changed, context was added. The
//    server files it under the `user` role; it does not end the turn.
//  * The **reply** is the prose of a whole turn, which is what "copy" copies.

/// Whether [message] is something a person wrote, as opposed to a notice the
/// server filed under the same role.
bool _isPrompt(MessageWithParts message) =>
    message.info.role == 'user' && v2VariantPart(message) == null;

/// Whether the assistant message at [index] is the last step of its turn:
/// nothing but notices stands between it and the next prompt, or the end.
bool _endsTurn(List<MessageWithParts> messages, int index) {
  if (messages[index].info.role != 'assistant') return false;
  for (var next = index + 1; next < messages.length; next += 1) {
    if (_isPrompt(messages[next])) return true;
    if (messages[next].info.role == 'assistant') return false;
  }
  return true;
}

/// For each turn, the one message that carries its "more" control: the step
/// that ends the turn when that step draws anything, otherwise the last step
/// that does. A turn often ends on pure bookkeeping (a `step-finish`), and
/// the control must not vanish with it.
Set<int> _turnActionOwners(
  List<MessageWithParts> messages,
  List<List<Part>> display, {
  required bool metaAlways,
}) {
  final owners = <int>{};
  int? lastStep;
  int? lastWithBody;
  bool hasBody(int index) =>
      display[index].any((part) => part.isRenderable) ||
      messages[index].info.errorText != null ||
      messages[index].info.finish == 'length';
  void closeTurn() {
    final end = lastStep;
    if (end != null) {
      final endDraws =
          hasBody(end) ||
          metaAlways ||
          _messageMeta(messages, end).modelLabel != null;
      final owner = endDraws ? end : lastWithBody;
      if (owner != null) owners.add(owner);
    }
    lastStep = null;
    lastWithBody = null;
  }

  for (var index = 0; index < messages.length; index += 1) {
    if (_isPrompt(messages[index])) {
      closeTurn();
    } else if (messages[index].info.role == 'assistant') {
      lastStep = index;
      if (hasBody(index)) lastWithBody = index;
    }
  }
  closeTurn();
  return owners;
}

/// The assistant messages of the turn that holds [index], oldest first.
/// Notices inside the turn are skipped, not treated as its edge.
List<MessageWithParts> _turnSteps(List<MessageWithParts> messages, int index) {
  var start = index;
  while (start > 0 && !_isPrompt(messages[start - 1])) {
    start -= 1;
  }
  var end = index;
  while (end + 1 < messages.length && !_isPrompt(messages[end + 1])) {
    end += 1;
  }
  return [
    for (var i = start; i <= end; i += 1)
      if (messages[i].info.role == 'assistant') messages[i],
  ];
}

/// A quiet divider-row for session-state changes (`model-switched`,
/// `agent-switched`, `location-switched`) and the compaction-running pill:
/// hairline — center pill — hairline, deliberately quieter than any bubble.
class TranscriptMarker extends StatelessWidget {
  const TranscriptMarker({
    super.key,
    required this.label,
    this.icon,
    this.leading,
    this.detail,
  });

  final String label;
  final IconData? icon;

  /// Replaces [icon] when set (compaction-running uses an inline spinner).
  final Widget? leading;

  /// Long-press/tooltip detail (e.g. the previous model); not shown inline.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hairline = Expanded(child: Divider(color: AppTheme.hairline(theme)));
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        shape: StadiumBorder(
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading ??
              Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          hairline,
          const SizedBox(width: 8),
          detail == null ? pill : Tooltip(message: detail!, child: pill),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: AppTheme.hairline(theme))),
        ],
      ),
    );
  }
}

/// Full-width quiet card for `synthetic` / `system` / `skill` messages and
/// completed/failed compaction: collapsed two-line preview, tap toggles the
/// full text.
class TranscriptNotice extends StatefulWidget {
  const TranscriptNotice({
    super.key,
    required this.header,
    required this.icon,
    required this.text,
    this.headerMono,
    this.markdown = false,
    this.error = false,
  });

  final String header;

  /// Appended to [header] in the mono app font (the skill name chip).
  final String? headerMono;
  final IconData icon;
  final String text;

  /// Renders the expanded body through the markdown widget (compaction
  /// summaries).
  final bool markdown;
  final bool error;

  @override
  State<TranscriptNotice> createState() => _TranscriptNoticeState();
}

class _TranscriptNoticeState extends State<TranscriptNotice> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final tint = widget.error
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    final body = widget.text.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        button: body.isNotEmpty,
        expanded: body.isEmpty ? null : _open,
        label: widget.headerMono == null
            ? widget.header
            : '${widget.header} ${widget.headerMono}',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: body.isEmpty ? null : () => setState(() => _open = !_open),
          child: Container(
            width: double.infinity,
            // A notice is a line in the transcript, not a card: no frame, and
            // it shares the prose's left edge.
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(widget.icon, size: 16, color: tint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: widget.header,
                          children: [
                            if (widget.headerMono case final mono?)
                              TextSpan(
                                text: ' $mono',
                                style: const TextStyle(
                                  fontFamily: AppTheme.monoFamily,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: tint,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (body.isNotEmpty)
                      Icon(
                        _open
                            ? AppIconography.chevronUp
                            : AppIconography.chevronDown,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
                // Closed, a routine notice is its header alone; the detail is one
                // tap away. An error keeps its first lines in view.
                if (body.isNotEmpty && (_open || widget.error))
                  _chatSizeTransition(
                    reduceMotion: reduceMotion,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _open && widget.markdown
                          ? ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: _proseWidthCap,
                              ),
                              child: MarkdownText(body, selectable: false),
                            )
                          : Text(
                              body,
                              maxLines: _open ? null : 2,
                              overflow: _open ? null : TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dispatches a mapper-tagged v2-only message (`v2:switch` / `v2:notice` /
/// `v2:compaction`) to its transcript treatment. Unknown tags degrade to a
/// generic notice — never crash, never drop silently.
class V2TranscriptRow extends StatelessWidget {
  const V2TranscriptRow({
    super.key,
    required this.part,
    required this.messageId,
    this.parentSessionID,
    this.knownSessions = const {},
    this.onOpenChild,
  });

  final Part part;
  final String messageId;
  final String? parentSessionID;
  final Map<String, Session> knownSessions;
  final ValueChanged<String>? onOpenChild;

  @override
  Widget build(BuildContext context) {
    final result = BackgroundAgentResult.fromPart(part);
    if (result != null) {
      return BackgroundAgentResultCard(
        key: ValueKey('background-result-$messageId'),
        result: result,
        rawText: part.text,
        onOpenChild: result.isKnownChild(parentSessionID, knownSessions)
            ? onOpenChild
            : null,
      );
    }
    final kind = part.toolName ?? '';
    switch (part.type) {
      case 'v2:switch':
        final (icon, prefix) = switch (kind) {
          'model' => (AppIconography.processor, _chatL10n(context).chatUiModel),
          'agent' => (AppIconography.support, _chatL10n(context).chatUiAgent),
          _ => (Icons.drive_file_move_outline, _chatL10n(context).chatUiMoved),
        };
        final detail = kind == 'location'
            ? part.url
            : part.filename == null
            ? null
            : _chatL10n(context).chatUiPreviouslyValue(part.filename ?? '');
        return TranscriptMarker(
          key: ValueKey('transcript-marker-$kind-switched-$messageId'),
          icon: icon,
          label: '$prefix → ${part.text}',
          detail: detail,
        );
      case 'v2:compaction':
        return switch (kind) {
          'running' => TranscriptMarker(
            key: ValueKey('compaction-running-$messageId'),
            label: part.text.isEmpty
                ? _chatL10n(context).chatUiCompactingConversation
                : part.text,
            leading: const SizedBox.square(
              dimension: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          'failed' => TranscriptNotice(
            key: ValueKey('compaction-failed-$messageId'),
            icon: AppIconography.collapse,
            header: _chatL10n(context).chatUiCompactionFailed,
            text: part.text,
            error: true,
          ),
          _ => TranscriptNotice(
            key: ValueKey('compaction-completed-$messageId'),
            icon: AppIconography.collapse,
            header: _chatL10n(context).chatUiContextCompacted,
            text: part.text,
            markdown: true,
          ),
        };
      default:
        final (icon, header, mono) = switch (kind) {
          'instructions' => (
            AppIconography.note,
            _chatL10n(context).sessionInstructionsUpdated,
            null,
          ),
          'synthetic' => (
            AppIconography.sparkle,
            part.filename ?? _chatL10n(context).chatUiContextAdded,
            null,
          ),
          'system' => (
            AppIconography.settingsAdvanced,
            part.filename ?? _chatL10n(context).chatUiSystemUpdate,
            null,
          ),
          'skill' => (
            AppIcons.run,
            _chatL10n(context).chatUiSkill,
            part.filename ?? part.text,
          ),
          _ => (
            AppIconography.server,
            part.filename ?? _chatL10n(context).chatUiServerMessage,
            null,
          ),
        };
        return TranscriptNotice(
          key: ValueKey('transcript-notice-$messageId'),
          icon: icon,
          header: header,
          headerMono: mono,
          text: kind == 'instructions'
              ? _chatL10n(context).sessionInstructionsApplied
              : kind == 'skill' && part.filename == null
              ? ''
              : part.text,
        );
    }
  }
}

const _contextToolNames = {'read', 'list', 'glob', 'grep'};

bool _isToolPart(Part part) => part.type == 'tool';

List<List<Part>> _timelineDisplayParts(List<MessageWithParts> messages) {
  final display = List.generate(messages.length, (_) => <Part>[]);
  final pendingParts = <Part>[];
  String? pendingType;
  int? pendingOwner;

  void flushPending() {
    if (pendingOwner case final owner?) {
      if (pendingType == 'text') {
        display[owner].add(_mergeTextParts(pendingParts));
      } else {
        display[owner].addAll(pendingParts);
      }
    }
    pendingParts.clear();
    pendingType = null;
    pendingOwner = null;
  }

  void appendPart(int owner, Part part) {
    final mergeable =
        part.type == 'tool' || part.type == 'text' || part.type == 'reasoning';
    if (!mergeable) {
      flushPending();
      display[owner].add(part);
      return;
    }
    // Two kinds of stretch: what the agent says (text) and what it does
    // (thoughts and tool calls). A stretch of work runs across as many steps
    // as it takes and belongs to the step that began it, so it can be drawn
    // as one thing.
    final kind = part.type == 'text' ? 'text' : 'work';
    if (pendingType != null && pendingType != kind) flushPending();
    pendingType ??= kind;
    pendingOwner ??= owner;
    pendingParts.add(part);
  }

  for (var index = 0; index < messages.length; index += 1) {
    final message = messages[index];
    final parts = message.parts.where((part) => part.isRenderable);
    if (message.info.role != 'assistant') {
      flushPending();
      display[index].addAll(parts);
      continue;
    }

    if (message.info.errorText != null && parts.isEmpty) flushPending();
    for (final part in parts) {
      appendPart(index, part);
    }
    if (message.info.errorText != null) flushPending();

    final nextIsAssistant =
        index + 1 < messages.length &&
        messages[index + 1].info.role == 'assistant';
    if (!nextIsAssistant) flushPending();
  }
  flushPending();
  return display;
}

Part _mergeTextParts(List<Part> parts) {
  assert(parts.isNotEmpty);
  if (parts.length == 1) return parts.single;
  final first = parts.first;
  final buffer = StringBuffer();
  for (final part in parts) {
    if (part.text.trim().isEmpty) continue;
    if (buffer.isNotEmpty &&
        !buffer.toString().endsWith('\n') &&
        !part.text.startsWith('\n')) {
      buffer.write('\n\n');
    }
    buffer.write(part.text);
  }
  return Part(
    id: first.id,
    messageID: first.messageID,
    type: first.type,
    text: buffer.toString(),
  );
}

class _AssistantPartRun {
  const _AssistantPartRun(
    this.parts, {
    this.grouped = false,
    this.heading,
    this.note,
  });

  final List<Part> parts;
  final bool grouped;

  /// What the agent said it was about to do, when it said so in a line
  /// ("Patching home shell") right before this run of tool calls. The run
  /// carries it as its title, so a step is one line instead of two.
  final String? heading;

  /// The rest of the thought [heading] opened, shown inside the opened step.
  final String? note;
}

/// Splits a thought into a title for the work that follows it and the rest.
/// Models open a thought with a short line naming what they are about to do
/// ("**Rebuilding latest source**"), then explain. That line titles the step;
/// the explanation waits inside it. A thought with no such opening line keeps
/// its own block.
({String heading, String? note})? _stepHeading(Part part) {
  if (part.type != 'reasoning') return null;
  final text = part.text.trim();
  if (text.isEmpty) return null;
  final breakAt = text.indexOf('\n');
  final first = (breakAt < 0 ? text : text.substring(0, breakAt)).trim();
  if (first.length > 72) return null;
  // Models differ. Some open every thought with a title of their own
  // ("**Rebuilding latest source**"); others think in long prose whose first
  // line is just its first sentence ("Okay, let me look at the router.").
  // Only a line the model marked as a heading may title a step when more
  // follows it; prose stays a thinking block of its own.
  final markedHeading =
      first.startsWith('#') ||
      (first.startsWith('**') && first.endsWith('**') && first.length > 4);
  if (breakAt >= 0 && !markedHeading) return null;
  final plain = first.replaceAll(RegExp(r'[*_`#]+'), '').trim();
  if (plain.isEmpty) return null;
  final rest = breakAt < 0 ? '' : text.substring(breakAt).trim();
  return (heading: plain, note: rest.isEmpty ? null : rest);
}

List<_AssistantPartRun> _groupAssistantParts(List<Part> parts) {
  final runs = <_AssistantPartRun>[];
  var index = 0;
  while (index < parts.length) {
    final current = parts[index];
    if (!_isToolPart(current)) {
      if (current.type != 'text' && current.type != 'reasoning') {
        runs.add(_AssistantPartRun([current]));
        index += 1;
        continue;
      }
      final textParts = <Part>[current];
      var next = index + 1;
      while (next < parts.length && parts[next].type == current.type) {
        textParts.add(parts[next]);
        next += 1;
      }
      runs.add(_AssistantPartRun([_mergeTextParts(textParts)]));
      index = next;
      continue;
    }

    final toolParts = <Part>[current];
    var next = index + 1;
    while (next < parts.length && _isToolPart(parts[next])) {
      toolParts.add(parts[next]);
      next += 1;
    }
    // A one-line thought right before the call or the run is its title, not
    // a row of its own.
    ({String heading, String? note})? title;
    if (runs.isNotEmpty && !runs.last.grouped) {
      title = _stepHeading(runs.last.parts.single);
      if (title != null) runs.removeLast();
    }
    runs.add(
      _AssistantPartRun(
        toolParts,
        grouped: toolParts.length > 1,
        heading: title?.heading,
        note: title?.note,
      ),
    );
    index = next;
  }
  return runs;
}

/// One human sentence for a tool group's header, e.g. "Read 3 files, edited
/// 1, ran 2 commands". Segments follow the way a turn unfolds — look, change,
/// run — and the file noun is elided after a read segment already names it.
String _toolRunSentence(List<Part> parts, AppLocalizations strings) {
  var reads = 0;
  var searches = 0;
  var lists = 0;
  var edits = 0;
  var commands = 0;
  var web = 0;
  var agents = 0;
  var other = 0;
  var notRun = 0;
  for (final part in parts) {
    if (!part.toolState.executed) {
      notRun++;
      continue;
    }
    switch (part.toolName?.trim().toLowerCase() ?? '') {
      case 'read':
        reads++;
      case 'glob' || 'grep':
        searches++;
      case 'list':
        lists++;
      case 'edit' || 'write' || 'patch' || 'apply_patch' || 'multiedit':
        edits++;
      case 'bash' || 'shell':
        commands++;
      case 'webfetch' || 'websearch':
        web++;
      case 'task' || 'subagent':
        agents++;
      default:
        other++;
    }
  }
  final segments = <String>[
    if (reads > 0) strings.chatUiReadFiles(reads),
    if (searches > 0) strings.chatUiSearched(searches),
    if (lists > 0) strings.chatUiListedFolders(lists),
    if (edits > 0) strings.chatUiEditedFiles(edits),
    if (commands > 0) strings.chatUiRanCommands(commands),
    if (web > 0) strings.chatUiFetchedPages(web),
    if (agents > 0) strings.chatUiDelegatedTasks(agents),
    if (other > 0) strings.chatUiOtherCalls(other),
    if (notRun > 0) strings.chatUiStepsNotRun(notRun),
  ];
  if (segments.isEmpty) return '';
  final sentence = segments.join(strings.chatUiSeparator);
  return sentence[0].toUpperCase() + sentence.substring(1);
}

class _ToolCallGroup extends StatefulWidget {
  const _ToolCallGroup({
    super.key,
    required this.parts,
    required this.expansionStore,
    required this.filePreviewLoader,
    required this.onAttachFile,
    required this.onDownloadFile,
    this.onOpenSession,
    this.heading,
    this.note,
  });

  /// The agent's own one-line name for this step; replaces the generic
  /// "Explored" / "Tools" title when present.
  final String? heading;
  final String? note;
  final List<Part> parts;
  final Map<String, bool> expansionStore;
  final ToolOutputFileLoader filePreviewLoader;
  final ToolOutputFileAction? onAttachFile;
  final ToolOutputFileAction onDownloadFile;

  /// Opens a subagent's child session from a `task` card; null hides it.
  final ValueChanged<String>? onOpenSession;

  @override
  State<_ToolCallGroup> createState() => _ToolCallGroupState();
}

class _ToolCallGroupState extends State<_ToolCallGroup> {
  late bool _expanded;

  String get _storeKey =>
      'tools:${widget.parts.first.id ?? widget.parts.first.callID}';

  /// The user's explicit toggle, surviving list recycling; null when the
  /// group has never been toggled by hand.
  bool? get _userChoice => widget.expansionStore[_storeKey];

  @override
  void initState() {
    super.initState();
    _expanded = _userChoice ?? _shouldOpen(widget.parts);
  }

  @override
  void didUpdateWidget(covariant _ToolCallGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A manual collapse is never undone by the run itself: auto-expansion
    // only applies while the user has not toggled the group.
    if (_userChoice case final choice?) {
      _expanded = choice;
      return;
    }
    if (_shouldOpen(widget.parts)) {
      _expanded = true;
    }
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      widget.expansionStore[_storeKey] = _expanded;
    });
  }

  bool _shouldOpen(List<Part> parts) => parts.any(
    (part) =>
        // Running progress is already named in the summary header. Only
        // actionable errors and produced files reveal the full group by default.
        part.toolState.status == 'error' ||
        part.toolState.outputFiles.isNotEmpty,
  );

  bool get _running => widget.parts.any(
    (part) =>
        part.toolState.executed &&
        (part.toolState.status == 'pending' ||
            part.toolState.status == 'running'),
  );

  bool get _failed =>
      widget.parts.any((part) => part.toolState.status == 'error');

  bool get _notRun => widget.parts.any((part) => !part.toolState.executed);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // While running, the header names the tool actually executing instead of
    // the static run summary, like a build log's live line.
    Part? runningPart;
    for (final part in widget.parts.reversed) {
      final status = part.toolState.status;
      if (part.toolState.executed &&
          (status == 'running' || status == 'pending')) {
        runningPart = part;
        break;
      }
    }
    final summary = runningPart != null
        ? runningToolTicker(
            runningPart.toolName ?? 'tool',
            runningPart.toolState,
            l10n: _chatL10n(context),
          )
        : _toolRunSentence(widget.parts, _chatL10n(context));
    final allContext = widget.parts.every(
      (part) => _contextToolNames.contains(part.toolName?.trim().toLowerCase()),
    );
    final kind = allContext && !_notRun
        ? (_running
              ? _chatL10n(context).chatUiExploring
              : _chatL10n(context).chatUiExplored)
        : (_running
              ? _chatL10n(context).chatUiRunningTools
              : _chatL10n(context).chatUiTools);
    final title = widget.heading ?? kind;
    final status = _failed
        ? _chatL10n(context).chatUiBackgroundError
        : _running
        ? _chatL10n(context).chatUiRunning
        : _notRun
        ? _chatL10n(context).chatUiIncludesStepsNotRun
        : _chatL10n(context).chatUiCompleted;
    return Container(
      key: const Key('tool-call-group'),
      // No frame: a run of tool calls is a line of the reply. Its steps,
      // when opened, hang off a single rule on the leading edge.
      child: Column(
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            label: _chatL10n(
              context,
            ).chatUiToolGroupSemantics(title, widget.parts.length, status),
            child: InkWell(
              key: const Key('tool-call-group-header'),
              onTap: _toggle,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(4, 6, 4, 6),
                  child: Row(
                    children: [
                      Icon(
                        AppIconography.search,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      // Natural width up to a share of the row, so the summary
                      // starts right after the title and nothing is left
                      // unused before the status icon.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * .56,
                        ),
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (_running && !reduceMotion)
                        SizedBox.square(
                          dimension: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      else
                        Icon(
                          _failed
                              ? AppIconography.error
                              : _running
                              ? AppIconography.waitingStart
                              : _notRun
                              ? AppIconography.blocked
                              : AppIconography.checkCircle,
                          size: 14,
                          color: _failed
                              ? theme.colorScheme.error
                              : _notRun
                              ? theme.colorScheme.onSurfaceVariant
                              : AppTheme.successOf(theme),
                        ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _expanded ? .5 : 0,
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 150),
                        child: Icon(
                          AppIconography.chevronDown,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_expanded)
            Container(
              key: const Key('tool-call-group-steps'),
              margin: const EdgeInsetsDirectional.only(start: 11),
              decoration: BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(color: AppTheme.hairline(theme)),
                ),
              ),
              child: Column(
                children: [
                  if (widget.note case final note?) StepNote(note),
                  for (var index = 0; index < widget.parts.length; index++) ...[
                    ToolCard(
                      key: ValueKey(
                        widget.parts[index].id ?? widget.parts[index].callID,
                      ),
                      toolName: widget.parts[index].toolName!,
                      state: widget.parts[index].toolState,
                      embedded: true,
                      expansionStore: widget.expansionStore,
                      expansionKey:
                          'tool:${widget.parts[index].id ?? widget.parts[index].callID}',
                      filePreviewLoader: widget.filePreviewLoader,
                      onAttachFile: widget.onAttachFile,
                      onDownloadFile: widget.onDownloadFile,
                      onOpenSession: widget.onOpenSession,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Everything the agent did between two things it said: thoughts, tool calls
/// and runs of them, folded under one line. Closed, the line says how much
/// was done and what kind; while work is going on it names the step in hand.
/// Open, the steps hang off a rule in the order they happened.
class _WorkGroup extends StatefulWidget {
  const _WorkGroup({
    super.key,
    required this.runs,
    required this.expansionStore,
    required this.buildRun,
  });

  final List<_AssistantPartRun> runs;
  final Map<String, bool> expansionStore;
  final Widget Function(_AssistantPartRun run) buildRun;

  @override
  State<_WorkGroup> createState() => _WorkGroupState();
}

class _WorkGroupState extends State<_WorkGroup> {
  late bool _expanded;

  Iterable<Part> get _tools => widget.runs
      .expand((run) => run.parts)
      .where((part) => part.type == 'tool');

  String get _storeKey {
    final first = widget.runs.first.parts.first;
    return 'work:${first.id ?? first.callID ?? first.messageID}';
  }

  bool? get _userChoice => widget.expansionStore[_storeKey];

  /// Whether the work ended on a failure. Agents fail and retry all the
  /// time (a patch that did not apply, then one that did); a failure they got
  /// past is a detail of the steps, not the state of the work.
  bool get _endedFailed =>
      _tools.isNotEmpty && _tools.last.toolState.status == 'error';

  // Only an unrecovered failure or a produced file is worth opening unasked.
  // Progress is already named on the closed line.
  bool get _shouldOpen =>
      _endedFailed ||
      _tools.any((part) => part.toolState.outputFiles.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _expanded = _userChoice ?? _shouldOpen;
  }

  @override
  void didUpdateWidget(covariant _WorkGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_userChoice case final choice?) {
      _expanded = choice;
    } else if (_shouldOpen) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = _chatL10n(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    _AssistantPartRun? liveRun;
    Part? livePart;
    for (final run in widget.runs.reversed) {
      for (final part in run.parts.reversed) {
        final status = part.toolState.status;
        if (part.type == 'tool' &&
            part.toolState.executed &&
            (status == 'running' || status == 'pending')) {
          liveRun = run;
          livePart = part;
          break;
        }
      }
      if (livePart != null) break;
    }
    final running = livePart != null;
    final failed = _endedFailed;
    final title = running
        ? liveRun!.heading ??
              runningToolTicker(
                livePart.toolName ?? 'tool',
                livePart.toolState,
                l10n: strings,
              )
        : strings.usageModelSteps('${widget.runs.length}');
    final summary = running
        ? strings.usageModelSteps('${widget.runs.length}')
        : _toolRunSentence(_tools.toList(), strings);
    return Column(
      key: const Key('work-group'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          label: '$title, $summary',
          child: InkWell(
            key: const Key('work-group-header'),
            onTap: () => setState(() {
              _expanded = !_expanded;
              widget.expansionStore[_storeKey] = _expanded;
            }),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 6, 4, 6),
                child: Row(
                  children: [
                    Icon(
                      AppIconography.timeline,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * .56,
                      ),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (running && !reduceMotion)
                      SizedBox.square(
                        dimension: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    else
                      Icon(
                        failed
                            ? AppIconography.error
                            : running
                            ? AppIconography.waitingStart
                            : AppIconography.checkCircle,
                        size: 14,
                        color: failed
                            ? theme.colorScheme.error
                            : AppTheme.successOf(theme),
                      ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _expanded ? .5 : 0,
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 150),
                      child: Icon(
                        AppIconography.chevronDown,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded)
          Container(
            key: const Key('work-group-steps'),
            margin: const EdgeInsetsDirectional.only(start: 11),
            padding: const EdgeInsetsDirectional.only(start: 6),
            decoration: BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(color: AppTheme.hairline(theme)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final run in widget.runs) widget.buildRun(run)],
            ),
          ),
      ],
    );
  }
}

/// Upper bound for assistant prose line length on wide screens; tool cards
/// and diffs keep the full transcript width.
const _proseWidthCap = 640.0;

class _AssistantMessagePart extends StatelessWidget {
  const _AssistantMessagePart({
    required this.part,
    required this.reasoningExpanded,
    required this.expansionStore,
    required this.filePreviewLoader,
    required this.onAttachFile,
    required this.onDownloadFile,
    this.streaming = false,
    this.onOpenSession,
    this.searchQuery = '',
    this.heading,
    this.note,
  });

  /// See [_AssistantPartRun.heading] and [_AssistantPartRun.note].
  final String? heading;
  final String? note;
  final Part part;
  final String searchQuery;
  final bool reasoningExpanded;

  /// Opens a subagent's child session from a `task` card; null hides it.
  final ValueChanged<String>? onOpenSession;

  /// True while this is the text block the assistant is still writing; it
  /// gets a soft primary tint so the eye lands where the transcript grows.
  final bool streaming;
  final Map<String, bool> expansionStore;
  final ToolOutputFileLoader filePreviewLoader;
  final ToolOutputFileAction? onAttachFile;
  final ToolOutputFileAction onDownloadFile;

  @override
  Widget build(BuildContext context) {
    if (part.type == 'text') {
      final theme = Theme.of(context);
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      return Padding(
        key: const Key('assistant-text-block'),
        padding: const EdgeInsets.only(bottom: 4),
        child: AnimatedContainer(
          key: const Key('assistant-text-surface'),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: streaming ? AppTheme.liveTint(theme) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _proseWidthCap),
            // Selectable on touch platforms: message actions live behind the
            // ⋯ button in the meta row, so prose no longer has to give up
            // selection for the long-press. Desktop keeps the transcript-wide
            // SelectionArea instead of nesting a second selection surface.
            child: TranscriptHighlight(
              query: searchQuery,
              child: MarkdownText(
                part.text,
                selectable: !desktopInteractions,
                onChoice: (option) => _insertChoice(context, option),
              ),
            ),
          ),
        ),
      );
    }
    if (part.type == 'reasoning') {
      return _Reasoning(
        text: part.text,
        expanded: reasoningExpanded,
        expansionStore: expansionStore,
        expansionKey: 'reasoning:${part.id ?? part.messageID}',
      );
    }
    if (part.type == 'tool') {
      // v2 shell messages carry their shellID in metadata; the design's key
      // list names their card `shell-card-<shellID>`.
      String? shellID;
      if (part.toolName == 'shell') {
        final raw = part.toolState.metadata?['shellID'];
        if (raw != null) shellID = raw.toString();
      }
      return ToolCard(
        key: shellID != null
            ? ValueKey('shell-card-$shellID')
            : ValueKey(part.id ?? part.callID),
        toolName: part.toolName ?? 'tool',
        state: part.toolState,
        heading: heading,
        note: note,
        expansionStore: expansionStore,
        expansionKey: 'tool:${part.id ?? part.callID}',
        filePreviewLoader: filePreviewLoader,
        onAttachFile: onAttachFile,
        onDownloadFile: onDownloadFile,
        onOpenSession: onOpenSession,
      );
    }
    if (part.type == 'file') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Chip(
          avatar: const Icon(AppIconography.attach, size: 16),
          label: Text(part.filename ?? _chatL10n(context).chatUiAttachment),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  /// Routes a tapped ```choices option into the composer through the same
  /// path the empty-transcript suggestion chips use. Hosts without the chat
  /// screen (isolated previews) fall back to the clipboard.
  static Future<void> _insertChoice(BuildContext context, String option) async {
    final chat = context.findAncestorStateOfType<_ChatScreenState>();
    if (chat != null) {
      chat._insertSuggestion(option);
      return;
    }
    await Clipboard.setData(ClipboardData(text: option));
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(_chatL10n(context).chatUiCopiedPasteItIntoTheComposer),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  final MessageWithParts m;
  final _MessageMeta meta;
  final List<Part> parts;
  final bool reasoningExpanded;
  final Map<String, bool> expansionStore;
  final bool showTimestamp;
  final bool highlighted;
  final String searchQuery;
  final TranscriptMatch? searchMatch;
  final String searchLabel;
  final ValueChanged<BuildContext>? onSearchExcerptContext;
  final VoidCallback? onLongPress;

  /// Desktop right-click menu for this message. Built on click so it reflects
  /// current capabilities, and it carries the same actions as the long-press
  /// sheet [onLongPress] opens.
  final List<ContextMenuAction> Function()? contextActions;
  final ToolOutputFileLoader filePreviewLoader;
  final ToolOutputFileAction? onAttachFile;
  final ToolOutputFileAction onDownloadFile;

  /// Recovery actions for typed assistant errors: compact the session after
  /// a context overflow, open the providers screen after an auth failure,
  /// send "Continue" after an output-length cut. Null hides the button.
  final VoidCallback? onCompact;
  final VoidCallback? onOpenProviders;
  final VoidCallback? onContinue;
  final VoidCallback? onChooseModel;

  /// Opens the child session a `task` tool call delegated to (its id is the
  /// argument); null hides the action on task cards.
  final ValueChanged<String>? onOpenSession;
  const _MessageView({
    super.key,
    required this.m,
    required this.meta,
    required this.parts,
    required this.reasoningExpanded,
    required this.expansionStore,
    required this.showTimestamp,
    this.highlighted = false,
    this.searchQuery = '',
    this.searchMatch,
    this.searchLabel = '',
    this.onSearchExcerptContext,
    this.onLongPress,
    this.contextActions,
    required this.filePreviewLoader,
    required this.onAttachFile,
    required this.onDownloadFile,
    this.onCompact,
    this.onOpenProviders,
    this.onContinue,
    this.onChooseModel,
    this.onOpenSession,
    this.queued = false,
    this.showActions = true,
    this.errorRecovered = false,
  });

  /// See [_AssistantErrorRow.recovered].
  final bool errorRecovered;

  /// Whether the "more" control is drawn under this message. A reply is
  /// usually several messages; only the one that ends it carries the control,
  /// so it appears once per turn. Long-press and right-click stay on every
  /// message.
  final bool showActions;

  /// True for a user prompt the server has accepted but not started: it
  /// runs after the current turn (OpenCode 1 queues mid-turn sends).
  final bool queued;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = m.info.role == 'user';
    final visibleParts = parts.where((p) => p.isRenderable).toList();
    final assistantRuns = isUser
        ? const <_AssistantPartRun>[]
        : _groupAssistantParts(visibleParts);
    final createdAt = m.info.time?.created;

    // Usage rides on the same preference as timestamps: both are detail a
    // reader opts into, and the model label alone marks a switch.
    final metaParts = <String>[
      if (showTimestamp && createdAt != null)
        _fmtSessionTime(createdAt, context),
      ?meta.modelLabel,
      if (showTimestamp) ...[
        if (meta.turnTokens case final tokens?)
          _chatL10n(context).chatUiTokenCount(_fmtTokens(tokens)),
        if (meta.turnCost case final cost?) _fmtCost(cost),
      ],
    ];
    final streaming =
        !isUser && m.info.errorText == null && m.info.time?.isDone == false;
    // A message whose parts are all non-renderable bookkeeping (`step-finish`,
    // `patch`, `snapshot`) has nothing to say; without this guard it drew an
    // empty bubble with a lone "…" actions button after every tool card and
    // at the end of the turn.
    if (!isUser &&
        visibleParts.isEmpty &&
        metaParts.isEmpty &&
        m.info.errorText == null &&
        m.info.finish != 'length') {
      return const SizedBox.shrink();
    }

    final body = GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.translucent,
      // Where the "more" control is drawn, the long-press is only a shortcut
      // to it, and excluding it keeps each message part as its own semantics
      // node. Where it is not, the long-press is the way in, so assistive
      // technology must see it.
      excludeFromSemantics: showActions,
      child: AnimatedContainer(
        // The key must not encode the highlight flag: a highlight-driven
        // remount would kill this fade and reset per-part expansion state.
        key: ValueKey('message-highlight-${m.info.id}'),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        padding: isUser
            ? const EdgeInsetsDirectional.fromSTEB(6, 10, 6, 6)
            : const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 2),
        decoration: BoxDecoration(
          color: highlighted
              ? theme.colorScheme.primaryContainer.withValues(alpha: .24)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (searchMatch case final match?)
              Builder(
                builder: (context) {
                  onSearchExcerptContext?.call(context);
                  return TranscriptMatchExcerpt(
                    match: match,
                    label: searchLabel,
                  );
                },
              ),
            Container(
              key: isUser ? ValueKey('user-prompt-${m.info.id}') : null,
              // Keep prompts readable on wide screens instead of stretching
              // them across a tablet.
              constraints: isUser
                  ? const BoxConstraints(maxWidth: _proseWidthCap)
                  : null,
              // Your words and the agent's share one column and one left
              // edge. A rule in the accent colour on the leading side is what
              // says "you wrote this": no bubble, no fill, no lost width.
              margin: isUser
                  ? const EdgeInsetsDirectional.only(start: 8)
                  : EdgeInsets.zero,
              padding: isUser
                  ? const EdgeInsetsDirectional.fromSTEB(10, 2, 4, 2)
                  : const EdgeInsets.symmetric(horizontal: 4),
              decoration: isUser
                  ? BoxDecoration(
                      border: BorderDirectional(
                        start: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 3,
                        ),
                      ),
                    )
                  : null,
              child: isUser
                  ? _UserMessageContent(
                      parts: visibleParts,
                      searchQuery: searchQuery,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final stretch in _stretches(assistantRuns))
                          if (stretch.length > 1)
                            _WorkGroup(
                              key: ValueKey(
                                'work:${stretch.first.parts.first.id ?? stretch.first.parts.first.callID}',
                              ),
                              runs: stretch,
                              expansionStore: expansionStore,
                              buildRun: (run) =>
                                  _runWidget(run, assistantRuns, streaming),
                            )
                          else
                            _runWidget(
                              stretch.single,
                              assistantRuns,
                              streaming,
                            ),
                      ],
                    ),
            ),
            if (queued)
              Padding(
                key: ValueKey('queued-message-${m.info.id}'),
                padding: const EdgeInsetsDirectional.only(top: 3, end: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.queue,
                      size: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _chatL10n(context).chatUiQueuedRunsAfterThisTurn,
                      style: theme.textTheme.labelSmall!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            if (m.info.errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: _AssistantErrorRow(
                  info: m.info,
                  recovered: errorRecovered,
                  onCompact: onCompact,
                  onOpenProviders: onOpenProviders,
                  onContinue: onContinue,
                  onChooseModel: onChooseModel,
                ),
              ),
            if (m.info.finish == 'length' &&
                m.info.errorKind != MessageErrorKind.outputLength)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  _chatL10n(context).chatUiAnswerWasCutOffByTheLength,
                  key: const Key('message-length-footer'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.mutedOf(theme),
                  ),
                ),
              ),
            if (metaParts.isNotEmpty || (showActions && onLongPress != null))
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  top: 1,
                  start: 6,
                  end: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (metaParts.isNotEmpty)
                      Flexible(
                        child: Text(
                          key: ValueKey('message-meta-${m.info.id}'),
                          metaParts.join('  ·  '),
                          style: theme.textTheme.labelSmall!.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (showActions && onLongPress != null)
                      Semantics(
                        button: true,
                        label: _chatL10n(context).chatUiMessageActions,
                        child: Tooltip(
                          message: _chatL10n(context).chatUiMessageActions,
                          child: InkWell(
                            key: ValueKey('message-actions-${m.info.id}'),
                            customBorder: const StadiumBorder(),
                            onTap: onLongPress,
                            // The target keeps the 44dp floor the rest of
                            // the product enforces. The glyph sits on a
                            // small tonal disc so it reads as a button
                            // instead of a bare "…" that, under the newest
                            // reply, looked like the answer trailing off.
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              child: Center(
                                child: _MessageActionsDisc(
                                  key: ValueKey(
                                    'message-actions-disc-${m.info.id}',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    final menu = contextActions;
    final content = TranscriptHighlight(query: searchQuery, child: body);
    if (menu == null) return content;
    return ContextMenuRegion(actions: menu, child: content);
  }

  /// Splits a message's runs into what is said and what is done: each text
  /// block (or attachment) stands alone, and each unbroken stretch of
  /// thoughts and tool calls between them is one list.
  static List<List<_AssistantPartRun>> _stretches(
    List<_AssistantPartRun> runs,
  ) {
    final stretches = <List<_AssistantPartRun>>[];
    var work = <_AssistantPartRun>[];
    for (final run in runs) {
      final type = run.parts.first.type;
      if (type == 'tool' || type == 'reasoning') {
        work.add(run);
        continue;
      }
      if (work.isNotEmpty) stretches.add(work);
      work = [];
      stretches.add([run]);
    }
    if (work.isNotEmpty) stretches.add(work);
    return stretches;
  }

  Widget _runWidget(
    _AssistantPartRun run,
    List<_AssistantPartRun> all,
    bool streaming,
  ) => run.grouped
      ? _ToolCallGroup(
          key: ValueKey(
            'tools:${run.parts.first.id ?? run.parts.first.callID}',
          ),
          parts: run.parts,
          heading: run.heading,
          note: run.note,
          expansionStore: expansionStore,
          filePreviewLoader: filePreviewLoader,
          onAttachFile: onAttachFile,
          onDownloadFile: onDownloadFile,
          onOpenSession: onOpenSession,
        )
      : _AssistantMessagePart(
          part: run.parts.single,
          heading: run.heading,
          note: run.note,
          searchQuery: searchQuery,
          reasoningExpanded: reasoningExpanded,
          expansionStore: expansionStore,
          filePreviewLoader: filePreviewLoader,
          onAttachFile: onAttachFile,
          onDownloadFile: onDownloadFile,
          onOpenSession: onOpenSession,
          streaming: streaming && identical(run, all.last),
        );

  static String _fmtTokens(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  /// Three decimals is the finest a reader can act on; anything smaller is
  /// "essentially free" rather than a string of zeros.
  static String _fmtCost(double cost) =>
      cost < .001 ? '< \$0.001' : '\$${cost.toStringAsFixed(3)}';
}

/// The visible face of the message-actions target: a "more" glyph on a small
/// tonal disc. The disc is what makes it read as a control; a bare glyph
/// under the newest reply looked like the answer trailing off.
class _MessageActionsDisc extends StatelessWidget {
  const _MessageActionsDisc({super.key});

  static const double diameter = 28;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        shape: BoxShape.circle,
      ),
      child: Icon(
        AppIconography.more,
        size: 16,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

/// The assistant error row, keyed on the server's typed error: overflow,
/// auth and length errors get the one action that fixes them; an abort is a
/// quiet "Stopped"; anything else keeps the plain red message.
class _AssistantErrorRow extends StatelessWidget {
  const _AssistantErrorRow({
    required this.info,
    this.recovered = false,
    this.onCompact,
    this.onOpenProviders,
    this.onContinue,
    this.onChooseModel,
  });

  final MessageInfo info;

  /// True when the turn went on after this error (the server retried, or the
  /// agent took another step). It is then a line in the story, not an alarm.
  final bool recovered;
  final VoidCallback? onCompact;
  final VoidCallback? onOpenProviders;
  final VoidCallback? onContinue;
  final VoidCallback? onChooseModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final raw = info.errorText ?? '';
    final words = agentErrorWords(raw, _chatL10n(context));
    final text = words.headline;
    final details = words.humanized || errorHasDetails(raw) ? raw : null;
    final kind = MessageErrorKind.refineFromText(
      info.errorKind ?? MessageErrorKind.unknown,
      raw,
    );
    switch (kind) {
      case MessageErrorKind.modelNotFound:
        return _ErrorActionCard(
          key: const Key('error-card-model-not-found'),
          icon: AppIconography.model,
          text: text,
          details: details,
          actionKey: const Key('error-action-choose-model'),
          actionLabel: _chatL10n(context).chatUiChooseModel,
          onAction: onChooseModel,
        );
      case MessageErrorKind.contextOverflow:
        return _ErrorActionCard(
          key: const Key('error-card-context-overflow'),
          icon: AppIconography.collapse,
          text: text,
          details: details,
          actionKey: const Key('error-action-compact'),
          actionLabel: _chatL10n(context).chatUiCompactSession,
          onAction: onCompact,
        );
      case MessageErrorKind.providerAuth:
        return _ErrorActionCard(
          key: const Key('error-card-provider-auth'),
          icon: Icons.key_off_rounded,
          text: text,
          actionKey: const Key('error-action-providers'),
          actionLabel: _chatL10n(context).chatUiOpenProviders,
          onAction: onOpenProviders,
        );
      case MessageErrorKind.outputLength:
        return _ErrorActionCard(
          key: const Key('error-card-output-length'),
          icon: AppIconography.textShort,
          text: text,
          details: details,
          actionKey: const Key('error-action-continue'),
          actionLabel: _chatL10n(context).returnBriefContinue,
          onAction: onContinue,
        );
      case MessageErrorKind.aborted:
        return Row(
          key: const Key('message-stopped'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.stop, size: 14, color: AppTheme.mutedOf(theme)),
            const SizedBox(width: 4),
            Text(
              _chatL10n(context).workStopped,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.mutedOf(theme),
              ),
            ),
          ],
        );
      case MessageErrorKind.contentFilter:
      case MessageErrorKind.unknown:
        return _ErrorActionCard(
          key: const Key('error-card-generic'),
          icon: AppIconography.error,
          text: text,
          hint: recovered ? _chatL10n(context).agentErrorRecovered : words.hint,
          recovered: recovered,
          details: details,
          actionKey: const Key('error-action-none'),
          actionLabel: '',
          onAction: null,
        );
    }
  }
}

class _ErrorActionCard extends StatelessWidget {
  const _ErrorActionCard({
    super.key,
    required this.icon,
    required this.text,
    required this.actionKey,
    required this.actionLabel,
    required this.onAction,
    this.details,
    this.hint,
    this.recovered = false,
  });

  final IconData icon;
  final String text;

  /// What happens next, or what to do; under the headline.
  final String? hint;

  /// A past problem the turn got over: drawn as a quiet line, no card.
  final bool recovered;
  final Key actionKey;
  final String actionLabel;
  final VoidCallback? onAction;

  /// The full server text (stack trace included) behind a Details button;
  /// null when the headline is the whole message.
  final String? details;

  Future<void> _showDetails(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(_chatL10n(context).chatUiErrorDetails),
      content: SingleChildScrollView(
        child: SelectableText(
          details ?? text,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontFamily: AppTheme.monoFamily),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_chatL10n(context).isolatedTaskClose),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      // Same language as the rest of the transcript: no card. A problem that
      // needs you is marked by a rule in the error colour on the leading
      // edge (as your own prompts are by the accent); one the turn got over
      // is a quiet line.
      margin: EdgeInsetsDirectional.only(start: recovered ? 0 : 4),
      padding: recovered
          ? const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 0)
          : const EdgeInsetsDirectional.fromSTEB(10, 2, 4, 0),
      decoration: recovered
          ? null
          : BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(color: scheme.error, width: 3),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  icon,
                  size: 16,
                  color: recovered ? scheme.onSurfaceVariant : scheme.error,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: recovered
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                    if (hint case final hint?)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          hint,
                          key: const Key('error-hint'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (onAction == null && details != null)
                TextButton(
                  key: const Key('error-action-details'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: recovered ? scheme.onSurfaceVariant : null,
                  ),
                  onPressed: () => _showDetails(context),
                  child: Text(_chatL10n(context).chatUiDetails),
                ),
            ],
          ),
          // With an action to take, both buttons get a row. Details alone
          // sits at the end of the sentence's line instead of costing one.
          if (onAction != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (details != null)
                  TextButton(
                    key: const Key('error-action-details'),
                    onPressed: () => _showDetails(context),
                    child: Text(_chatL10n(context).chatUiDetails),
                  ),
                if (onAction != null)
                  TextButton(
                    key: actionKey,
                    onPressed: onAction,
                    child: Text(actionLabel),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MessageMeta {
  const _MessageMeta({this.modelLabel, this.turnTokens, this.turnCost});

  final String? modelLabel;
  final int? turnTokens;
  final double? turnCost;

  bool get isEmpty =>
      modelLabel == null && turnTokens == null && turnCost == null;
}

String? _modelLabel(MessageInfo info) {
  final provider = info.providerID?.trim();
  final model = info.modelID?.trim();
  if (model?.isNotEmpty != true) return null;
  return provider?.isNotEmpty == true
      ? presentedModelLabel(provider!, model!)
      : model;
}

_MessageMeta _messageMeta(List<MessageWithParts> messages, int index) {
  final current = messages[index];
  if (current.info.role != 'assistant') return const _MessageMeta();
  // Everything about a turn is said once, in its footer: a label between
  // two steps would cut the turn in half.
  if (!_endsTurn(messages, index)) return const _MessageMeta();

  final steps = _turnSteps(messages, index);
  final models = <String>[];
  for (final step in steps) {
    final label = _modelLabel(step.info);
    if (label != null && (models.isEmpty || models.last != label)) {
      models.add(label);
    }
  }
  String? previousModel;
  for (
    var previous = messages.indexOf(steps.first) - 1;
    previous >= 0;
    previous -= 1
  ) {
    final info = messages[previous].info;
    if (info.role != 'assistant') continue;
    previousModel = _modelLabel(info);
    break;
  }
  // Named when the turn ran on a different model than the one before it, or
  // changed model part-way.
  final modelChanged =
      models.isNotEmpty && (models.length > 1 || models.first != previousModel);
  final currentModel = models.join(' → ');

  var turnTokens = 0;
  var turnCost = 0.0;
  for (final step in steps) {
    turnTokens += step.info.tokens.total;
    turnCost += step.info.cost;
  }
  return _MessageMeta(
    modelLabel: modelChanged ? currentModel : null,
    turnTokens: turnTokens > 0 ? turnTokens : null,
    turnCost: turnCost > 0 ? turnCost : null,
  );
}

class _UserMessageContent extends StatelessWidget {
  final List<Part> parts;
  final String searchQuery;

  const _UserMessageContent({required this.parts, this.searchQuery = ''});

  @override
  Widget build(BuildContext context) {
    final text = parts
        .where((part) => part.type == 'text')
        .map((part) => part.text)
        .where((value) => value.trim().isNotEmpty)
        .join('\n');
    final files = parts.where((part) => part.type == 'file').toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (text.isNotEmpty)
          TranscriptHighlight(
            query: searchQuery,
            child: MarkdownText(text, selectable: false),
          ),
        if (text.isNotEmpty && files.isNotEmpty) const SizedBox(height: 8),
        for (final file in files) _AttachmentPart(part: file),
      ],
    );
  }
}

class _AttachmentPart extends StatelessWidget {
  final Part part;

  const _AttachmentPart({required this.part});

  String _filename(BuildContext context) =>
      part.filename?.trim().isNotEmpty == true
      ? part.filename!.trim()
      : _chatL10n(context).chatUiAttachment;

  String _type(BuildContext context) {
    final dot = _filename(context).lastIndexOf('.');
    if (dot < 0 || dot == _filename(context).length - 1) {
      return _chatL10n(context).chatUiFILE;
    }
    return _filename(context).substring(dot + 1).toUpperCase();
  }

  bool get _isReference =>
      part.mime == PromptAttachment.directoryReferenceMime &&
      Uri.tryParse(part.url ?? '')?.scheme == 'file';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reference = _isReference;
    void openPreview() => showFilePreviewSheet(
      context,
      FilePreviewData.fromDataUrl(
        name: _filename(context),
        mimeType: part.mime,
        url: part.url,
      ),
    );

    return Semantics(
      container: true,
      button: !reference,
      excludeSemantics: true,
      label: reference
          ? _chatL10n(context).chatUiReferenceName(_filename(context))
          : _chatL10n(context).chatUiPreviewAttachmentName(_filename(context)),
      onTap: reference ? null : openPreview,
      child: Tooltip(
        message: reference
            ? _chatL10n(context).chatUiProjectReferenceName(_filename(context))
            : _chatL10n(context).chatUiPreviewAttachment,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          onTap: reference ? null : openPreview,
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: .5),
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              border: Border.all(color: AppTheme.hairline(theme)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  reference ? AppIconography.bookmark : AppIconography.attach,
                  size: 17,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reference
                            ? '@${_filename(context)}'
                            : _filename(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        reference
                            ? _chatL10n(context).chatUiProjectReference
                            : _chatL10n(
                                context,
                              ).chatUiAttachmentType(_type(context)),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!reference) ...[
                  const SizedBox(width: 8),
                  const Icon(AppIconography.visible, size: 15),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Reasoning extends StatefulWidget {
  final String text;
  final bool expanded;
  final Map<String, bool>? expansionStore;
  final String? expansionKey;
  const _Reasoning({
    required this.text,
    required this.expanded,
    this.expansionStore,
    this.expansionKey,
  });

  @override
  State<_Reasoning> createState() => _ReasoningState();
}

class _ReasoningState extends State<_Reasoning> {
  late bool _open;

  static String? _preview(String text) {
    final line = text.trim().split('\n').first;
    final plain = line.replaceAll(RegExp(r'[*_`#]+'), '').trim();
    if (plain.isEmpty) return null;
    // One line's worth: the row is a label for the thought, not the thought.
    return plain.length <= 80
        ? plain
        : '${plain.substring(0, 80).trimRight()}…';
  }

  // Measurement cache: the painter is retained by the State and re-laid-out
  // only when the text, style, direction, or width actually changes, instead
  // of allocating a fresh TextPainter on every rebuild of a streaming turn.
  TextPainter? _painter;
  String? _measuredText;
  TextStyle? _measuredStyle;
  TextDirection? _measuredDirection;
  double? _measuredWidth;
  bool _short = true;

  bool? get _stored => widget.expansionKey == null
      ? null
      : widget.expansionStore?[widget.expansionKey!];

  /// The transcript-wide default that was in force when the user last
  /// toggled this block by hand. A per-part choice only outlives the default
  /// it was made under: once the global toggle flips, a stale override from
  /// an off-screen block must not resist the new default.
  String? get _defaultKey =>
      widget.expansionKey == null ? null : '${widget.expansionKey}@default';

  void _persist(bool open) {
    if (widget.expansionKey case final key?) {
      widget.expansionStore?[key] = open;
      widget.expansionStore?[_defaultKey!] = widget.expanded;
    }
  }

  @override
  void initState() {
    super.initState();
    final stored = _stored;
    final storedDefault = _defaultKey == null
        ? null
        : widget.expansionStore?[_defaultKey!];
    if (stored != null &&
        storedDefault != null &&
        storedDefault != widget.expanded) {
      widget.expansionStore?.remove(widget.expansionKey);
      widget.expansionStore?.remove(_defaultKey);
      _open = widget.expanded;
    } else {
      _open = stored ?? widget.expanded;
    }
  }

  @override
  void didUpdateWidget(covariant _Reasoning oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded) {
      // The transcript-wide toggle sets a new default. Per-part overrides are
      // dropped rather than overwritten with the toggle's value: stamping the
      // store meant one flip permanently erased every per-part choice in the
      // session, and flipping back could not restore them.
      if (widget.expansionKey case final key?) {
        widget.expansionStore?.remove(key);
        widget.expansionStore?.remove(_defaultKey);
      }
      _open = widget.expanded;
    }
  }

  @override
  void dispose() {
    _painter?.dispose();
    super.dispose();
  }

  bool _isShort(TextStyle style, TextDirection direction, double maxWidth) {
    if (_painter == null ||
        _measuredText != widget.text ||
        _measuredStyle != style ||
        _measuredDirection != direction ||
        _measuredWidth != maxWidth) {
      final painter = _painter ?? TextPainter();
      painter
        ..text = TextSpan(text: widget.text, style: style)
        ..textDirection = direction
        ..layout(maxWidth: maxWidth);
      _painter = painter;
      _measuredText = widget.text;
      _measuredStyle = style;
      _measuredDirection = direction;
      _measuredWidth = maxWidth;
      _short = painter.computeLineMetrics().length < 2;
    }
    return _short;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodySmall!.copyWith(
      fontStyle: FontStyle.italic,
      color: theme.colorScheme.onSurfaceVariant,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final short = _isShort(
          textStyle,
          Directionality.of(context),
          constraints.maxWidth - 14,
        );
        return Container(
          key: const Key('assistant-reasoning-block'),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: theme.colorScheme.secondary.withValues(alpha: .5),
                width: 2,
              ),
            ),
          ),
          child: short
              ? KeyedSubtree(
                  key: const Key('reasoning-inline'),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(8, 5, 4, 5),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _proseWidthCap,
                      ),
                      child: MarkdownText(
                        widget.text,
                        baseStyle: textStyle,
                        selectable: false,
                      ),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      button: true,
                      expanded: _open,
                      excludeSemantics: true,
                      label: _open
                          ? _chatL10n(context).chatUiCollapseReasoningDetails
                          : _chatL10n(context).chatUiExpandReasoningDetails,
                      child: InkWell(
                        key: const Key('reasoning-toggle'),
                        onTap: () => setState(() {
                          _open = !_open;
                          _persist(_open);
                        }),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              8,
                              4,
                              4,
                              4,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  AppIconography.model,
                                  size: 13,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 5),
                                // Closed, the row is the thought's first
                                // line. The word "Reasoning" and what it
                                // means appear once it is opened.
                                if (_open)
                                  InfoLabel.glossary(
                                    Glossary.reasoning,
                                    key: const Key('reasoning-glossary'),
                                    iconSize: 13,
                                    style: theme.textTheme.labelSmall!.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                if (!_open) ...[
                                  Flexible(
                                    child: Text(
                                      // What it was thinking about, not an
                                      // instruction to tap.
                                      _preview(widget.text) ??
                                          _chatL10n(context).chatUiTapToExpand,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall!
                                          .copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_open)
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          8,
                          4,
                          4,
                          4,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _proseWidthCap,
                          ),
                          child: MarkdownText(
                            widget.text,
                            baseStyle: textStyle,
                            selectable: false,
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _SubagentContextBanner extends StatelessWidget {
  final int? position;
  final int? total;
  final Future<void> Function() onParent;
  final Future<void> Function() onAll;

  const _SubagentContextBanner({
    required this.position,
    required this.total,
    required this.onParent,
    required this.onAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = position != null && total != null
        ? _chatL10n(context).chatUiPositionOfTotal(position!, total!)
        : _chatL10n(context).chatUiDelegatedSession;
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 16),
        child: Row(
          children: [
            Icon(AppIconography.nested, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _chatL10n(context).chatUiSubagentCount(count),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            IconButton(
              key: const ValueKey('subagent-parent-session'),
              tooltip: _chatL10n(context).chatUiOpenParentSession,
              onPressed: onParent,
              icon: const Icon(AppIconography.send),
            ),
            IconButton(
              key: const ValueKey('subagent-session-list'),
              tooltip: _chatL10n(context).chatUiShowAllSubagentSessions,
              onPressed: onAll,
              icon: const Icon(AppIconography.branch),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedSessionBanner extends StatelessWidget {
  final String url;
  final VoidCallback onStop;

  const _SharedSessionBanner({required this.url, required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
        child: Row(
          children: [
            const Icon(AppIconography.globe, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_chatL10n(context).chatUiSharedAnyoneWithTheLinkCanView),
                  Semantics(
                    label: _chatL10n(context).chatUiSharedLink(url),
                    child: SelectableText(
                      url,
                      maxLines: 1,
                      style: const TextStyle(
                        fontFamily: AppTheme.monoFamily,
                        fontSize: AppTheme.captionFontSize,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: _chatL10n(context).chatUiCopyShareLink,
              onPressed: () => Clipboard.setData(ClipboardData(text: url)),
              icon: const Icon(AppIcons.copy),
            ),
            TextButton(
              onPressed: onStop,
              child: Text(_chatL10n(context).chatUiStopSharing),
            ),
          ],
        ),
      ),
    );
  }
}

/// The single surface for everything pending between the transcript and the
/// composer (design doc §5): offline drafts waiting for a reconnect, and —
/// on OpenCode 2 — server inbox items (admitted, not-yet-delivered sends).
/// One bubble anatomy; only icon and status line differ by kind. Both kinds
/// coexist in arrival order, so the user sees one list of "things that will
/// reach the agent", never two queue UIs.
class _PendingSendsStrip extends StatelessWidget {
  const _PendingSendsStrip({
    required this.drafts,
    required this.inboxItems,
    required this.isSending,
    required this.isAcceptedUnrecorded,
    required this.onEdit,
    required this.onResend,
    required this.onDiscard,
    required this.onCancelInbox,
    required this.onFlipDelivery,
  });

  final List<QueuedPrompt> drafts;
  final List<Api2InboxItem> inboxItems;

  /// Whether a flush is dispatching a draft or persisting its outcome.
  final bool Function(QueuedPrompt entry) isSending;

  /// Whether the server accepted a draft's send but the device could not
  /// record it; resending it would be a certain duplicate.
  final bool Function(QueuedPrompt entry) isAcceptedUnrecorded;
  final ValueChanged<QueuedPrompt> onEdit;

  /// Explicit resend of a draft whose earlier send was never confirmed.
  final ValueChanged<QueuedPrompt> onResend;
  final ValueChanged<QueuedPrompt> onDiscard;
  final ValueChanged<Api2InboxItem> onCancelInbox;
  final ValueChanged<Api2InboxItem> onFlipDelivery;

  @override
  Widget build(BuildContext context) {
    // Merge both kinds into arrival order.
    final entries = <({int time, Widget child})>[
      for (var index = 0; index < drafts.length; index++)
        (
          time: drafts[index].createdAt,
          child: _QueuedPromptBubble(
            key: ValueKey('queued-send-$index'),
            entry: drafts[index],
            sending: isSending(drafts[index]),
            acceptedUnrecorded: isAcceptedUnrecorded(drafts[index]),
            onEdit: () => onEdit(drafts[index]),
            onResend: () => onResend(drafts[index]),
            onDiscard: () => onDiscard(drafts[index]),
          ),
        ),
      for (final item in inboxItems)
        (
          time: item.timeCreated ?? 0,
          child: _InboxSendBubble(
            key: ValueKey('pending-send-${item.id}'),
            item: item,
            onCancel: () => onCancelInbox(item),
            onFlipDelivery: () => onFlipDelivery(item),
          ),
        ),
    ]..sort((a, b) => a.time.compareTo(b.time));
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 180),
        // No container-level size animation here: the strip lives inside a
        // scroll view, where an AnimatedSize re-measures every frame and
        // never settles. Items animate individually instead.
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 2, 8, 2),
                  child: entry.child,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared bubble anatomy for the pending-sends strip: right-aligned
/// 14-radius `surfaceContainerLow` bubble with an `outlineVariant` border,
/// two-line text preview, and an icon + status line.
class _PendingSendBubble extends StatelessWidget {
  const _PendingSendBubble({
    required this.text,
    required this.attachmentCount,
    required this.icon,
    required this.label,
    required this.semanticsLabel,
    this.error = false,
    this.actions = const [],
  });

  final String text;
  final int attachmentCount;
  final IconData icon;
  final String label;
  final String semanticsLabel;
  final bool error;

  /// Inline actions on the status row (flip delivery, cancel, edit): one tap
  /// each, no sheet in between.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = error
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 6, 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: error
                ? theme.colorScheme.error.withValues(alpha: .6)
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (text.isNotEmpty)
              Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            if (attachmentCount > 0)
              Text(
                _chatL10n(context).chatUiAttachmentCount(attachmentCount),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: statusColor),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                    ),
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  for (final action in actions) action,
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A 32 dp inline action on a pending-send bubble.
class _PendingSendAction extends StatelessWidget {
  const _PendingSendAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;

  /// Null renders the action disabled — a draft whose send is on the wire
  /// must not be edited into a second send or discarded as unsent.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 32, height: 32),
    padding: EdgeInsets.zero,
    iconSize: 17,
    icon: Icon(icon),
  );
}

/// A queued draft in one of three states: waiting for the next flush,
/// on the wire right now, or dispatched without a confirmed outcome. The
/// last state never resends on its own — the socket may have dropped after
/// the prompt reached the server — so it offers an explicit resend beside
/// the usual edit and discard.
class _QueuedPromptBubble extends StatelessWidget {
  const _QueuedPromptBubble({
    super.key,
    required this.entry,
    required this.sending,
    required this.acceptedUnrecorded,
    required this.onEdit,
    required this.onResend,
    required this.onDiscard,
  });

  final QueuedPrompt entry;
  final bool sending;
  final bool acceptedUnrecorded;
  final VoidCallback onEdit;
  final VoidCallback onResend;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final error = entry.error;
    final review = entry.dispatched && !sending;
    final l10n = _chatL10n(context);
    final String label;
    final IconData icon;
    if (sending) {
      label = l10n.queuedSending;
      icon = AppIconography.upload;
    } else if (review && acceptedUnrecorded) {
      // The controller's recorded reason names the acceptance; the generic
      // "unconfirmed" copy would invite a resend that is a certain duplicate.
      label = error ?? l10n.queuedDeliveryUnconfirmed;
      icon = AppIconography.cloudCheck;
    } else if (review) {
      label = error == null
          ? l10n.queuedDeliveryUnconfirmed
          : l10n.queuedDeliveryUnconfirmedWithError(error);
      icon = AppIconography.question;
    } else if (error != null) {
      label = _chatL10n(context).chatUiFailedDetail(error);
      icon = AppIconography.error;
    } else {
      label = _chatL10n(context).chatUiQueuedWillSendWhenReconnected;
      icon = AppIconography.clock;
    }
    return _PendingSendBubble(
      text: entry.text,
      attachmentCount: entry.attachments.length,
      icon: icon,
      label: label,
      error: review || (!sending && error != null),
      semanticsLabel: _chatL10n(context).chatUiQueuedDraftLabel(label),
      actions: [
        if (review && !acceptedUnrecorded)
          _PendingSendAction(
            key: const ValueKey('queued-action-resend'),
            icon: AppIconography.send,
            tooltip: l10n.queuedResendTooltip,
            onPressed: onResend,
          ),
        _PendingSendAction(
          key: const ValueKey('queued-action-edit'),
          icon: AppIconography.edit,
          tooltip: _chatL10n(context).chatUiEditDraft,
          onPressed: sending ? null : onEdit,
        ),
        _PendingSendAction(
          key: const ValueKey('queued-action-discard'),
          icon: AppIconography.delete,
          tooltip: _chatL10n(context).chatUiDiscardDraft,
          onPressed: sending ? null : onDiscard,
        ),
      ],
    );
  }
}

/// A server inbox item in the strip. `user` items get inline flip and
/// cancel actions (server items are immutable, so cancel-back-to-composer
/// is the edit affordance); synthetic/compaction/move items are
/// informational.
class _InboxSendBubble extends StatelessWidget {
  const _InboxSendBubble({
    super.key,
    required this.item,
    required this.onCancel,
    required this.onFlipDelivery,
  });

  final Api2InboxItem item;
  final VoidCallback onCancel;
  final VoidCallback onFlipDelivery;

  bool get _isUser => item.type == 'user';
  bool get _steering => item.delivery == Api2Delivery.steer;

  @override
  Widget build(BuildContext context) {
    final label = !_isUser
        ? _chatL10n(context).chatUiContextUpdatePending
        : _steering
        ? _chatL10n(context).chatUiSteeringAtTheNextStep
        : _chatL10n(context).chatUiWaitingForThisRunToFinish;
    return _PendingSendBubble(
      text: _isUser ? (item.promptText ?? '') : '',
      attachmentCount: 0,
      icon: !_isUser
          ? AppIconography.sparkle
          : _steering
          ? AppIcons.run
          : AppIcons.queue,
      label: label,
      semanticsLabel: _chatL10n(context).chatUiPendingSendLabel(label),
      actions: [
        // Only the flip that changes the current mode is offered; the server
        // has no reorder, so none is faked.
        if (_isUser)
          _steering
              ? _PendingSendAction(
                  key: const ValueKey('inbox-action-queue'),
                  icon: AppIcons.queue,
                  tooltip: _chatL10n(context).chatUiWaitForThisRunInstead,
                  onPressed: onFlipDelivery,
                )
              : _PendingSendAction(
                  key: const ValueKey('inbox-action-steer'),
                  icon: AppIcons.run,
                  tooltip: _chatL10n(context).chatUiSendNowAndSteerInstead,
                  onPressed: onFlipDelivery,
                ),
        if (_isUser)
          _PendingSendAction(
            key: const ValueKey('inbox-action-cancel'),
            icon: AppIconography.close,
            tooltip: _chatL10n(context).chatUiCancelAndReturnToTheComposer,
            onPressed: onCancel,
          ),
      ],
    );
  }
}

/// A server-authored background result remains separate from the parent's own
/// reply. The readable outcome is primary; exact protocol text is inspectable.
class BackgroundAgentResultCard extends StatefulWidget {
  const BackgroundAgentResultCard({
    super.key,
    required this.result,
    required this.rawText,
    this.onOpenChild,
  });

  final BackgroundAgentResult result;
  final String rawText;
  final ValueChanged<String>? onOpenChild;

  @override
  State<BackgroundAgentResultCard> createState() =>
      _BackgroundAgentResultCardState();
}

class _BackgroundAgentResultCardState extends State<BackgroundAgentResultCard> {
  bool _details = false;

  @override
  Widget build(BuildContext context) {
    final strings = _chatL10n(context);
    final theme = Theme.of(context);
    final result = widget.result;
    final status = switch (result.state) {
      'completed' => strings.chatUiBackgroundComplete,
      'error' => strings.chatUiBackgroundError,
      _ => strings.chatUiBackgroundCancelled,
    };
    final color = switch (result.state) {
      'completed' => AppTheme.successOf(theme),
      'error' => theme.colorScheme.error,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    return Card.filled(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  result.state == 'completed'
                      ? AppIconography.checkCircle
                      : Icons.info_outline,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.chatUiBackgroundResult,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.description.isEmpty
                            ? result.agent
                            : result.description,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${result.agent} · $status',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            MarkdownText(
              result.body.isEmpty ? strings.chatUiNoResultText : result.body,
              selectable: false,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (widget.onOpenChild != null)
                  TextButton.icon(
                    onPressed: () => widget.onOpenChild!(result.childID),
                    icon: const Icon(AppIconography.branch, size: 18),
                    label: Text(strings.chatUiResultOpenChild),
                  ),
                TextButton.icon(
                  onPressed: () => setState(() => _details = !_details),
                  icon: Icon(
                    _details ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                  label: Text(strings.chatUiResultSourceDetails),
                ),
              ],
            ),
            if (_details)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SelectableText(
                  widget.rawText,
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: AppTheme.monoFamily,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
