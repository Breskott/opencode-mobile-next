part of '../chat_screen.dart';

/// Inline attention surface pinned directly above the composer. It replaces
/// the auto-opened, non-dismissible permission sheet: a request arriving
/// mid-sentence no longer steals the keyboard. One card shows at a time
/// (oldest request first); the full sheet stays one tap away behind Review.
class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.icon,
    required this.title,
    required this.announcement,
    this.summary,
    this.detail,
    this.primary,
    this.secondary,
    this.accent,
    this.minHeight = 72,
    this.body,
  });

  final IconData icon;
  final String title;

  /// Optional content between the header and the buttons — the question
  /// card puts its option rows here so every flavour shares one frame.
  final Widget? body;

  /// Icon and border tint; defaults to the primary colour. The retry banner
  /// passes the attention tone so it reads as a wait, not an ask.
  final Color? accent;

  /// Minimum card height; the permission card keeps 72 so its two buttons
  /// never crowd, the slimmer retry banner passes 0.
  final double minHeight;

  /// Read by TalkBack when the card appears, e.g. "Permission needed: Run a
  /// shell command". The visible title stays a plain [Text] for tests and
  /// for sighted readers.
  final String announcement;
  final String? summary;
  final String? detail;
  final Widget? primary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = accent ?? scheme.primary;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 2),
          child: Container(
            constraints: BoxConstraints(minHeight: minHeight),
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              border: Border.all(color: tint.withValues(alpha: .45)),
              boxShadow: AppTheme.raised(theme),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(icon, color: tint),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            container: true,
                            liveRegion: true,
                            label: announcement,
                            excludeSemantics: true,
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          if (summary case final summary?
                              when summary.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                summary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: AppTheme.monoFamily,
                                  fontSize: AppTheme.codeFontSize,
                                ),
                              ),
                            ),
                          if (detail case final detail? when detail.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                detail,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppTheme.mutedOf(theme),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (body case final body?)
                  Padding(padding: const EdgeInsets.only(top: 8), child: body),
                if (primary != null || secondary != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [?secondary, ?primary],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Permission requests first open their complete scope and available preview.
/// Arriving requests never steal focus or authorize work from the summary.
class _PermissionAttentionCard extends StatelessWidget {
  const _PermissionAttentionCard({
    super.key,
    required this.permission,
    required this.onReview,
    this.autoApprovalFailed = false,
  });

  final PermissionRequest permission;
  final VoidCallback onReview;

  /// The session approves automatically but this request's reply failed,
  /// so the card says why it is asking after all.
  final bool autoApprovalFailed;

  @override
  Widget build(BuildContext context) {
    final title = permissionRequestTitle(permission.permission);
    return _AttentionCard(
      icon: permissionActionIcon(permission.permission),
      title: title,
      announcement: _chatL10n(context).chatUiPermissionNeeded(title),
      summary: permission.patterns.isEmpty
          ? null
          : permission.patterns.join(' · '),
      detail: autoApprovalFailed
          ? _chatL10n(context).approvalsUiFailedDetail
          : permission.message,
      primary: FilledButton.icon(
        key: const Key('permission-card-review'),
        onPressed: onReview,
        icon: const Icon(AppIconography.checklist, size: 18),
        label: Text(_chatL10n(context).reviewTitle),
      ),
    );
  }
}

/// The question flavour of [_AttentionCard]: the prompt header and question,
/// every choice as a tappable option row, the free-text field when the
/// prompt accepts one, and More (opens the full sheet). A single-select
/// prompt answers on tap; multi-select and two-prompt questions collect
/// answers behind Send. Questions the card cannot hold — more than two
/// prompts or a long description — collapse to the question and an Answer
/// button that opens the sheet, mirroring `formPrefersFullScreen`.
class _QuestionAttentionCard extends StatefulWidget {
  const _QuestionAttentionCard({
    super.key,
    required this.question,
    required this.replying,
    required this.onAnswer,
    required this.onMore,
  });

  final PendingQuestion question;
  final bool replying;
  final ValueChanged<List<List<String>>> onAnswer;
  final VoidCallback onMore;

  @override
  State<_QuestionAttentionCard> createState() => _QuestionAttentionCardState();
}

class _QuestionAttentionCardState extends State<_QuestionAttentionCard> {
  late final List<Set<String>> _selected = List.generate(
    widget.question.prompts.length,
    (_) => <String>{},
  );
  late final List<TextEditingController> _custom = List.generate(
    widget.question.prompts.length,
    (_) => TextEditingController(),
  );

  List<QuestionPrompt> get _prompts => widget.question.prompts;

  /// Single-select, one prompt: a tap is the whole answer. Anything else
  /// needs Send so a half-finished selection is never sent early.
  bool get _answersOnTap => _prompts.length == 1 && !_prompts.single.multiple;

  bool get _complete {
    for (var i = 0; i < _prompts.length; i++) {
      if (_selected[i].isEmpty && _custom[i].text.trim().isEmpty) return false;
    }
    return true;
  }

  bool get _hasCustomText =>
      _custom.any((controller) => controller.text.trim().isNotEmpty);

  List<List<String>> _serialize() {
    final answers = <List<String>>[];
    for (var i = 0; i < _prompts.length; i++) {
      final prompt = _prompts[i];
      final customAnswer = _custom[i].text.trim();
      if (prompt.multiple) {
        answers.add([
          ..._selected[i],
          if (customAnswer.isNotEmpty) customAnswer,
        ]);
      } else {
        answers.add([
          if (customAnswer.isNotEmpty)
            customAnswer
          else if (_selected[i].isNotEmpty)
            _selected[i].first,
        ]);
      }
    }
    return answers;
  }

  void _send() {
    if (!_complete || widget.replying) return;
    widget.onAnswer(_serialize());
  }

  void _tap(int index, QuestionPrompt prompt, QuestionChoice choice) {
    if (widget.replying) return;
    setState(() {
      if (prompt.multiple) {
        if (!_selected[index].remove(choice.label)) {
          _selected[index].add(choice.label);
        }
      } else {
        _custom[index].clear();
        _selected[index]
          ..clear()
          ..add(choice.label);
      }
    });
    if (_answersOnTap) _send();
  }

  @override
  void dispose() {
    for (final controller in _custom) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = _prompts.firstOrNull;
    final title = first?.title.trim().isNotEmpty == true
        ? first!.title.trim()
        : _chatL10n(context).chatUiOpenCodeNeedsInput;
    final more = TextButton(
      key: const Key('question-card-more'),
      onPressed: widget.replying ? null : widget.onMore,
      child: Text(_chatL10n(context).chatUiMore),
    );
    if (first == null || questionPrefersSheet(widget.question)) {
      final count = _prompts.length;
      return _AttentionCard(
        icon: AppIconography.question,
        title: title,
        announcement: _chatL10n(context).chatUiQuestionLabel(title),
        detail: first == null
            ? null
            : count > 1
            ? _chatL10n(context).chatUiQuestionsSummary(first.question, count)
            : first.question,
        primary: FilledButton(
          key: const Key('question-card-answer'),
          onPressed: widget.replying ? null : widget.onMore,
          child: Text(_chatL10n(context).returnBriefAnswer),
        ),
      );
    }

    final sending = widget.replying;
    // Send earns its place only when a tap cannot be the whole answer.
    final showSend = !_answersOnTap || _hasCustomText;
    final Widget primary = sending
        ? Row(
            key: const Key('question-card-sending'),
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(
                _chatL10n(context).queuedSending,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppTheme.mutedOf(theme),
                ),
              ),
            ],
          )
        : showSend
        ? FilledButton(
            key: const Key('question-card-send'),
            onPressed: _complete ? _send : null,
            child: Text(_chatL10n(context).chatUiSend),
          )
        : more;

    return _AttentionCard(
      icon: AppIconography.question,
      title: title,
      announcement: _chatL10n(context).chatUiQuestionLabel(title),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < _prompts.length; index++) ...[
            if (index > 0)
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 2),
                child: Text(
                  _prompts[index].title,
                  style: theme.textTheme.labelLarge,
                ),
              ),
            if (_prompts[index].question.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _prompts[index].question,
                  key: ValueKey('question-card-question-$index'),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            for (final choice in _prompts[index].choices)
              QuestionOptionRow(
                choice: choice,
                multiple: _prompts[index].multiple,
                selected: _selected[index].contains(choice.label),
                enabled: !sending,
                onTap: () => _tap(index, _prompts[index], choice),
              ),
            if (_prompts[index].custom)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: QuestionCustomAnswerField(
                  key: ValueKey('question-card-custom-$index'),
                  controller: _custom[index],
                  enabled: !sending,
                  maxLines: 2,
                  onChanged: (value) => setState(() {
                    if (!_prompts[index].multiple && value.trim().isNotEmpty) {
                      _selected[index].clear();
                    }
                  }),
                  onSubmitted: (_) => _send(),
                ),
              ),
          ],
        ],
      ),
      secondary: identical(primary, more) ? null : more,
      primary: primary,
    );
  }
}

/// "Rate limited. Retrying 2 in 0:42" — the server sends no attempt ceiling,
/// so the banner names the attempt rather than inventing a total. [now]
/// defaults to the wall clock; tests pass a fixed instant.
@visibleForTesting
String retryBannerHeadline(
  SessionRetryState retry, {
  DateTime? now,
  AppLocalizations? l10n,
}) {
  final strings = l10n ?? lookupAppLocalizations(const Locale('en'));
  final attempt = retry.attempt > 0 ? ' ${retry.attempt}' : '';
  final next = retry.next;
  if (next == null) return strings.chatUiRateLimitRetry(attempt);
  final delta = next.difference(now ?? DateTime.now());
  final remaining = delta.isNegative ? Duration.zero : delta;
  return strings.chatUiRateLimitCountdown(attempt, _countdown(remaining));
}

String _countdown(Duration d) {
  final total = d.inSeconds;
  final minutes = total ~/ 60;
  final seconds = (total % 60).toString().padLeft(2, '0');
  if (minutes >= 60) {
    final hours = minutes ~/ 60;
    return '$hours:${(minutes % 60).toString().padLeft(2, '0')}:$seconds';
  }
  return '$minutes:$seconds';
}

/// The provider-retry flavour of [_AttentionCard]: a slim banner naming the
/// attempt and counting down to the next one, the server's own words when
/// it sent any, and Stop wired to the same abort as the app-bar button.
class _RetryAttentionCard extends StatelessWidget {
  const _RetryAttentionCard({super.key, required this.retry});

  final SessionRetryState retry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = retryBannerHeadline(retry, l10n: _chatL10n(context));
    final message = retry.message?.trim();
    return _AttentionCard(
      icon: AppIcons.retry,
      accent: AppTheme.statusColor(theme, AppStatusTone.attention),
      minHeight: 0,
      title: title,
      announcement: title,
      detail: message == null || message.isEmpty ? null : message,
    );
  }
}

/// A single-line, self-hiding note above the composer for composer-local
/// outcomes (queued, staged, already present). It replaces snackbars that
/// used to cover the field the user is typing into; confirmations of remote
/// actions stay snackbars.
class _ComposerNote extends StatelessWidget {
  const _ComposerNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 2, 24, 0),
          child: Semantics(
            liveRegion: true,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.mutedOf(theme),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One app-bar overflow for the whole session: the view destinations and
/// transcript toggles that used to sit behind a second icon, then the
/// mutation and utility actions. Every row pops with its action value.
class SessionMenuSheet extends StatelessWidget {
  const SessionMenuSheet({
    super.key,
    this.conversationTitle,
    required this.reasoningExpanded,
    required this.timestampsVisible,
    required this.todosAvailable,
    required this.changesAvailable,
    required this.forkAvailable,
    required this.revertAvailable,
    required this.compactAvailable,
    required this.terminalAvailable,
    required this.subagentsAvailable,
    required this.reverted,
    required this.shared,
    required this.sharingAvailable,
    this.stagedRevert = false,
    this.notesAvailable = false,
    this.skillsAvailable = false,
    this.resultsAvailable = false,
    this.approvalsAvailable = false,
    this.continueOnComputerAvailable = false,
    this.continueOnPhoneAvailable = false,
  });

  final bool reasoningExpanded;
  final bool timestampsVisible;
  final String? conversationTitle;
  final bool todosAvailable;
  final bool changesAvailable;
  final bool forkAvailable;
  final bool revertAvailable;
  final bool compactAvailable;
  final bool terminalAvailable;
  final bool subagentsAvailable;
  final bool reverted;
  final bool shared;
  final bool sharingAvailable;
  final bool stagedRevert;
  final bool notesAvailable;
  final bool skillsAvailable;
  final bool resultsAvailable;

  /// Per-session approval settings; off only where a session cannot be
  /// asked for permissions (the isolated demo).
  final bool approvalsAvailable;
  /// Session handoff (backlog F4): the terminal resume command for the
  /// computer that runs the server, and the QR link for another phone.
  /// Both pop a value; the chat screen builds the sheet and never sends.
  final bool continueOnComputerAvailable;
  final bool continueOnPhoneAvailable;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          key: const Key('session-menu-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (conversationTitle case final title?)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
                child: Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
            SectionLabel(_chatL10n(context).chatUiConversation),
            // Views are the frequent destinations, so they take a compact
            // chip row instead of a tile each and leave the actions below
            // reachable without scrolling on a phone.
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
              // A Wrap hands its children unbounded width, so the row's own
              // width is measured here and capped on each chip: a long label
              // at 2.5x text wraps inside its chip instead of running off
              // the sheet.
              child: LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (resultsAvailable)
                      _SessionMenuChip(
                        maxWidth: constraints.maxWidth,
                        icon: AppIconography.checkCircle,
                        label: _chatL10n(context).chatUiResults,
                        value: 'results',
                      ),
                    _SessionMenuChip(
                      maxWidth: constraints.maxWidth,
                      icon: AppIconography.search,
                      label: _chatL10n(context).transcriptFindTitle,
                      value: 'find',
                    ),
                    _SessionMenuChip(
                      maxWidth: constraints.maxWidth,
                      icon: AppIconography.timeline,
                      label: _chatL10n(context).chatUiTimeline,
                      value: 'timeline',
                    ),
                    if (changesAvailable)
                      _SessionMenuChip(
                        maxWidth: constraints.maxWidth,
                        icon: AppIconography.review,
                        label: _chatL10n(context).chatUiChanges,
                        value: 'changes',
                      ),
                    if (todosAvailable)
                      _SessionMenuChip(
                        maxWidth: constraints.maxWidth,
                        icon: AppIconography.checklist,
                        label: _chatL10n(context).chatUiTodos,
                        value: 'todos',
                      ),
                    if (subagentsAvailable)
                      _SessionMenuChip(
                        maxWidth: constraints.maxWidth,
                        icon: AppIconography.branch,
                        label: _chatL10n(context).usageSubagents,
                        value: 'subagents',
                      ),
                  ],
                ),
              ),
            ),
            ExpansionTile(
              title: Text(_chatL10n(context).chatUiDisplayAndContext),
              children: [
                TranscriptDisplayToggles(
                  reasoningExpanded: reasoningExpanded,
                  timestampsVisible: timestampsVisible,
                  dense: true,
                ),
                _SessionSheetRow(
                  icon: AppIconography.usageRing,
                  label: _chatL10n(context).chatUiContextUsage,
                  value: 'context',
                ),
              ],
            ),
            ExpansionTile(
              title: Text(_chatL10n(context).chatUiSessionActions),
              children: [
                if (skillsAvailable)
                  _SessionSheetRow(
                    icon: AppIconography.extensions,
                    label: _chatL10n(context).skillMenu,
                    value: 'skills',
                  ),
                if (notesAvailable)
                  _SessionSheetRow(
                    icon: AppIconography.note,
                    label: _chatL10n(context).sessionNoteTitle,
                    value: 'note',
                  ),
                if (approvalsAvailable)
                  _SessionSheetRow(
                    icon: AppIconography.permissions,
                    label: _chatL10n(context).approvalsUiMenu,
                    value: 'approvals',
                  ),
                _SessionSheetRow(
                  icon: AppIconography.retry,
                  label: _chatL10n(context).chatUiRetryLastPrompt,
                  value: 'retry',
                ),
                if (revertAvailable)
                  _SessionSheetRow(
                    icon: reverted
                        ? AppIconography.restore
                        : AppIconography.history,
                    label: reverted
                        ? (stagedRevert
                              ? _chatL10n(context).revertReviewTitle
                              : _chatL10n(context).chatUiRestoreMessages)
                        : _chatL10n(context).chatUiRevertLastPrompt,
                    value: reverted ? 'restore' : 'revert',
                  ),
                if (forkAvailable)
                  _SessionSheetRow(
                    icon: AppIconography.fork,
                    label: _chatL10n(context).chatUiForkSession,
                    value: 'fork',
                  ),
                if (compactAvailable)
                  _SessionSheetRow(
                    icon: AppIconography.collapse,
                    label: _chatL10n(context).chatUiCompactContext,
                    value: 'compact',
                  ),
                if (sharingAvailable)
                  _SessionSheetRow(
                    icon: shared
                        ? AppIconography.networkOff
                        : AppIconography.globe,
                    label: shared
                        ? _chatL10n(context).chatUiStopSharing
                        : _chatL10n(context).chatUiShareSession,
                    value: shared ? 'unshare' : 'share',
                  ),
                if (terminalAvailable)
                  _SessionSheetRow(
                    icon: AppIconography.terminal,
                    label: _chatL10n(context).chatUiRunShellCommand,
                    value: 'shell',
                  ),
                _SessionSheetRow(
                  icon: AppIcons.run,
                  label: _chatL10n(context).runResultsCommandsTitle,
                  value: 'slash',
                ),
                if (continueOnComputerAvailable)
                  _SessionSheetRow(
                    icon: AppIconography.computer,
                    label: _chatL10n(context).handoffUiComputerTitle,
                    value: 'continue-computer',
                  ),
                if (continueOnPhoneAvailable)
                  _SessionSheetRow(
                    icon: AppIconography.qrCode,
                    label: _chatL10n(context).handoffUiPhoneTitle,
                    value: 'continue-phone',
                  ),
                _SessionSheetRow(
                  icon: AppIconography.retry,
                  label: _chatL10n(context).chatUiReloadMessages,
                  value: 'reload',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionMenuChip extends StatelessWidget {
  const _SessionMenuChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.maxWidth,
  });

  final IconData icon;
  final String label;
  final String value;

  /// The chip row's measured width; a Wrap alone would let a long label at
  /// large text scales overflow the sheet.
  final double maxWidth;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: math.max(0, maxWidth)),
    child: ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      // Chips read as light chrome but keep the 48 dp Android target.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      onPressed: () => Navigator.pop(context, value),
    ),
  );
}
