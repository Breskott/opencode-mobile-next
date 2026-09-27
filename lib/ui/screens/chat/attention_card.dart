part of '../chat_screen.dart';

// What the agent asks for, above the composer: one KitRequestCard per
// request (K2 §2.1, P4.1b). A permission, an OpenCode 1 question and an
// OpenCode 2 form share the one card: who asks and why, the common answer
// in place, one Details that opens the one request sheet, and a receipt
// once answered (Sending, Not confirmed yet, Not accepted). A request
// arriving mid-sentence never takes focus from the composer. One card shows
// at a time, oldest first; the card says how many more wait.
//
// Transcript turn model (STATE-16): a card is the turn's one control while
// the agent waits; the work line above it says so.

/// Who asks, in the card's caption: "The agent".
String _requestWho(BuildContext context) => _chatL10n(context).chatRequestWho;

/// The chat screen's controller for a card inside it; null outside a chat
/// (a gallery), where the card cannot answer and says why.
ConnectionController? _requestConnection(BuildContext context) =>
    context.findAncestorStateOfType<_ChatScreenState>()?._conn;

/// "The agent waits until you answer. Nothing is lost." plus how many other
/// requests of this conversation wait behind this one.
String _requestIfIgnored(BuildContext context, int others) {
  final l10n = _chatL10n(context);
  return others <= 0
      ? l10n.chatRequestIfIgnored
      : '${l10n.chatRequestIfIgnored} ${l10n.chatRequestMoreWaiting(others)}';
}

/// Keeps a request card to [KitTokens.requestMaxHeightShare] of the window,
/// so the transcript and the composer keep their room in a short window
/// (landscape, the keyboard up); past that the card scrolls in its slot.
class _RequestSlot extends StatelessWidget {
  const _RequestSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight:
          MediaQuery.sizeOf(context).height * KitTokens.requestMaxHeightShare,
    ),
    child: ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      children: [child],
    ),
  );
}

/// A permission request: Allow once and Reject in place (one tap for the
/// common answer), Details for the whole command, the change, a note with
/// Reject and "Always allow".
class _PermissionAttentionCard extends StatefulWidget {
  const _PermissionAttentionCard({
    super.key,
    required this.permission,
    required this.onReview,
    this.autoApprovalFailed = false,
  });

  final PermissionRequest permission;

  /// Details: the request sheet.
  final VoidCallback onReview;

  /// The session approves automatically but this request's reply failed,
  /// so the card says why it is asking after all.
  final bool autoApprovalFailed;

  @override
  State<_PermissionAttentionCard> createState() =>
      _PermissionAttentionCardState();
}

class _PermissionAttentionCardState extends State<_PermissionAttentionCard> {
  late final DateTime _seen = requestSeenNow();

  @override
  Widget build(BuildContext context) => _RequestSlot(child: _content(context));

  Widget _content(BuildContext context) {
    final l10n = _chatL10n(context);
    final conn = _requestConnection(context);
    final permission = widget.permission;
    final detail = widget.autoApprovalFailed
        ? l10n.approvalsUiFailedDetail
        : null;
    if (conn == null) {
      return permissionRequestCard(
        context,
        permission: permission,
        who: _requestWho(context),
        since: _seen,
        detail: detail,
        onAllow: null,
        onReject: null,
        disabledReason: l10n.chatRequestNoConnection,
        onDetails: widget.onReview,
        detailsKey: const Key('permission-card-review'),
      );
    }
    final answers = PermissionAnswers.of(conn);
    return ListenableBuilder(
      listenable: answers,
      builder: (context, _) {
        final answered = answers.answerFor(permission.id);
        void answer(String reply, {String? message}) => unawaited(
          answerPermissionRequest(conn, permission, reply, message: message),
        );
        return permissionRequestCard(
          context,
          permission: permission,
          who: _requestWho(context),
          since: _seen,
          detail: detail,
          ifIgnored: _requestIfIgnored(
            context,
            conn.permissionsForSession(permission.sessionID).length - 1,
          ),
          answered: answered,
          onAllow: () => answer('once'),
          onReject: () => answer('reject'),
          onRetry: answered == null
              ? null
              : () => answer(answered.reply, message: answered.message),
          onDetails: widget.onReview,
          detailsKey: const Key('permission-card-review'),
        );
      },
    );
  }
}

/// An OpenCode 1 question, on the same card as an OpenCode 2 form: the
/// question's header as the title and its words under it.
///
/// - One prompt with one answer: the options in place; a tap sends at once
///   and the chosen option carries the receipt. "Something else" opens a
///   field whose text is kept as a draft of this request until it lands.
/// - One prompt with several answers: "Answer" opens the request sheet with
///   every option and Send.
/// - Anything longer (two or more prompts, long options, several answers
///   plus a typed one): "Answer" opens the full question sheet, as a form's
///   Answer opens the form.
class _QuestionAttentionCard extends StatefulWidget {
  const _QuestionAttentionCard({
    super.key,
    required this.question,
    required this.replying,
    required this.onAnswer,
    required this.onMore,
  });

  final PendingQuestion question;

  /// The screen's own answer in flight (a sheet answered it); the card's
  /// own answers carry their receipt instead.
  final bool replying;

  /// Used only outside a chat screen, where the card has no connection.
  final ValueChanged<List<List<String>>> onAnswer;

  /// The full question sheet.
  final VoidCallback onMore;

  @override
  State<_QuestionAttentionCard> createState() => _QuestionAttentionCardState();
}

class _QuestionAttentionCardState extends State<_QuestionAttentionCard> {
  late final DateTime _seen = requestSeenNow();
  final TextEditingController _other = TextEditingController();

  /// The answer in words and when it left; null while nothing is in flight.
  String? _answer;
  DateTime? _since;
  String? _refused;

  List<QuestionPrompt> get _prompts => widget.question.prompts;

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  KitDraft? _draft(ConnectionController? conn) {
    final profileId = conn?.profile?.id ?? conn?.store.activeId ?? '';
    if (profileId.isEmpty) return null;
    return KitDraft(
      target: 'request.${widget.question.id}',
      profileId: profileId,
      controller: _other,
    );
  }

  Future<void> _send(
    ConnectionController? conn,
    List<List<String>> answers,
    String words,
  ) async {
    if (_answer != null) return;
    if (conn == null) {
      widget.onAnswer(answers);
      return;
    }
    setState(() {
      _answer = words;
      _since = requestSeenNow();
      _refused = null;
    });
    try {
      await conn.answerQuestion(widget.question.id, answers);
      unawaited(_draft(conn)?.clear());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _answer = null;
        _since = null;
        _refused = productErrorText(error);
      });
    }
  }

  KitRequestCard _card(
    BuildContext context, {
    required KitRequestAnswers answers,
    VoidCallback? onDetails,
  }) {
    final l10n = _chatL10n(context);
    final first = _prompts.firstOrNull;
    final title = first?.title.trim().isNotEmpty == true
        ? first!.title.trim()
        : l10n.chatUiOpenCodeNeedsInput;
    final count = _prompts.length;
    final sending = _answer != null;
    return KitRequestCard.ask(
      kind: KitRequestKind.question,
      title: title,
      who: _requestWho(context),
      reason: KitNeedsYouReason.decision,
      ifIgnored: _requestIfIgnored(context, 0),
      announcement: l10n.chatUiQuestionLabel(title),
      since: _seen,
      detail: first == null || first.question.trim().isEmpty
          ? null
          : count > 1
          ? l10n.chatUiQuestionsSummary(first.question, count)
          : first.question,
      phase: sending ? KitRequestPhase.sending : KitRequestPhase.waiting,
      answer: _answer,
      receipt: sending
          ? KitReceipt(state: KitReceiptState.sending, since: _since)
          : _refused == null
          ? null
          : KitReceipt(state: KitReceiptState.refused, reason: _refused),
      answers: answers,
      onDetails: onDetails,
      detailsKey: const Key('question-card-more'),
    );
  }

  @override
  Widget build(BuildContext context) => _RequestSlot(child: _content(context));

  Widget _content(BuildContext context) {
    final l10n = _chatL10n(context);
    final conn = _requestConnection(context);
    final first = _prompts.firstOrNull;
    final single =
        first != null &&
        _prompts.length == 1 &&
        !questionPrefersSheet(widget.question);

    if (single && !first.multiple) {
      final choices = [
        for (final (index, choice) in first.choices.indexed)
          KitChoice<String>(
            key: ValueKey('question-card-option-$index'),
            value: choice.label,
            title: choice.label,
            supporting: choice.description.trim().isEmpty
                ? null
                : choice.description,
          ),
      ];
      late final KitRequestCard card;
      final answers = KitRequestChoose<String>(
        choices: choices,
        chosen: _answer,
        onChosen: (label) => unawaited(
          _send(conn, [
            [label],
          ], label),
        ),
        other: first.custom
            ? KitChoiceOther(
                label: l10n.chatRequestOtherAnswer,
                fieldLabel: l10n.chatRequestOtherField,
                draft: _draft(conn),
                fieldKey: const Key('question-card-custom-0'),
                onSubmitted: (text) => unawaited(
                  _send(conn, [
                    [text],
                  ], text),
                ),
              )
            : null,
      );
      card = _card(
        context,
        answers: answers,
        onDetails: conn == null
            ? null
            : () => unawaited(
                showQuestionDetails(
                  context,
                  controller: conn,
                  question: widget.question,
                  card: card,
                ),
              ),
      );
      return card;
    }

    if (single && !first.custom && conn != null) {
      late final KitRequestCard card;
      card = _card(
        context,
        answers: KitRequestChooseMany<String>(
          choices: [
            for (final choice in first.choices)
              KitChoice<String>(
                value: choice.label,
                title: choice.label,
                supporting: choice.description.trim().isEmpty
                    ? null
                    : choice.description,
              ),
          ],
          onSend: (chosen) =>
              unawaited(_send(conn, [chosen.toList()], chosen.join(', '))),
        ),
        onDetails: () => unawaited(
          showQuestionDetails(
            context,
            controller: conn,
            question: widget.question,
            card: card,
          ),
        ),
      );
      return card;
    }

    return _card(
      context,
      answers: const KitRequestInSheet(key: Key('question-card-answer')),
      onDetails: widget.onMore,
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
  // Servers retry for many reasons (a dropped connection, an overloaded
  // provider). Only call it a rate limit when it is one, or when the server
  // gave no reason; otherwise the cause is named on the line below.
  final cause = classifyAgentError(retry.message ?? '');
  final rateLimit = cause == null || cause == AgentErrorCause.rateLimited;
  final next = retry.next;
  if (next == null) {
    return rateLimit
        ? strings.chatUiRateLimitRetry(attempt)
        : strings.chatUiRetryingSoon(attempt);
  }
  final delta = next.difference(now ?? DateTime.now());
  final remaining = delta.isNegative ? Duration.zero : delta;
  return rateLimit
      ? strings.chatUiRateLimitCountdown(attempt, _countdown(remaining))
      : strings.chatUiRetryingCountdown(attempt, _countdown(remaining));
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

/// A provider retry: a condition of the running turn, not something that
/// needs the person (LOOK-4), so a working notice rather than the request
/// card. It names the attempt, counts down to the next one, and gives the
/// server's reason in plain words when it sent one.
class _RetryAttentionCard extends StatelessWidget {
  const _RetryAttentionCard({super.key, required this.retry});

  final SessionRetryState retry;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final title = retryBannerHeadline(retry, l10n: _chatL10n(context));
    final raw = retry.message?.trim();
    // The reason in plain words, when the app knows it; never the server's
    // own text. A rate limit is already the title.
    final words = raw == null || raw.isEmpty
        ? null
        : agentErrorWords(raw, _chatL10n(context));
    final message =
        words == null ||
            !words.humanized ||
            classifyAgentError(raw!) == AgentErrorCause.rateLimited
        ? null
        : words.headline;
    final hasMessage = message != null && message.isNotEmpty;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: KitLayout.readingWidth),
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: tokens.gutter,
            vertical: tokens.space1,
          ),
          child: KitNotice(
            title: hasMessage ? title : null,
            message: hasMessage ? message : title,
            tone: AppStatusTone.progress,
            icon: AppIcons.retry,
          ),
        ),
      ),
    );
  }
}

/// An OpenCode 2 form of the open session, on the same card as a question:
/// the form's title, how many questions it asks, and Answer, which opens
/// the form. While its answers are on their way the card says so, and a
/// refused answer shows the server's reason above Answer again.
class _FormRequestCard extends StatefulWidget {
  const _FormRequestCard({
    super.key,
    required this.form,
    required this.onAnswer,
  });

  final Api2FormInfo form;
  final VoidCallback onAnswer;

  @override
  State<_FormRequestCard> createState() => _FormRequestCardState();
}

class _FormRequestCardState extends State<_FormRequestCard> {
  late final DateTime _seen = requestSeenNow();

  @override
  Widget build(BuildContext context) => _RequestSlot(child: _content(context));

  Widget _content(BuildContext context) => ListenableBuilder(
    listenable: FormAnswerReceipts.instance,
    builder: (context, _) {
      final l10n = _chatL10n(context);
      final form = widget.form;
      final title = form.title ?? l10n.chatUiInputRequested;
      final sent = FormAnswerReceipts.instance.receiptFor(form.id);
      final sending = sent != null && !sent.failed;
      return KitRequestCard.ask(
        kind: KitRequestKind.form,
        title: title,
        who: _requestWho(context),
        reason: KitNeedsYouReason.decision,
        ifIgnored: _requestIfIgnored(context, 0),
        announcement: l10n.chatUiQuestionLabel(title),
        since: _seen,
        detail: l10n.chatUiQuestionCount(form.fields.length),
        phase: sending ? KitRequestPhase.sending : KitRequestPhase.waiting,
        answer: sending ? l10n.kitRequestSendAnswers : null,
        receipt: sent == null
            ? null
            : sent.failed
            ? KitReceipt(state: KitReceiptState.refused, reason: sent.error)
            : KitReceipt(state: KitReceiptState.sending, since: sent.since),
        answers: KitRequestInSheet(
          key: ValueKey('form-request-answer-${form.id}'),
        ),
        onDetails: widget.onAnswer,
      );
    },
  );
}

/// A single-line, self-hiding note above the composer for composer-local
/// outcomes (queued, staged, already present). It replaces snackbars that
/// used to cover the field the user is typing into.
class _ComposerNote extends StatelessWidget {
  const _ComposerNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: KitLayout.readingWidth),
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(horizontal: tokens.gutter),
          child: Semantics(
            liveRegion: true,
            child: KitText(
              text,
              role: KitTextRole.caption,
              tone: KitTextTone.secondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

// revamp: redesign (slice-P10.2) — the one KitRow menu of Go to and Do,
// with the display toggles moved to Settings, is that slice's work; this is
// today's layout rebuilt from kit parts.

/// One app-bar overflow for the whole session: the view destinations as a
/// row of chips, then the display toggles and the session's actions, each
/// folded. Every row pops with its action value.
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
    final l10n = _chatL10n(context);
    final tokens = KitTokens.of(context);
    Widget chip(IconData icon, String label, String value) => KitChip.action(
      key: ValueKey('session-menu-$value'),
      icon: icon,
      label: label,
      onPressed: () => Navigator.pop(context, value),
    );
    return SafeArea(
      child: ListView(
        key: const Key('session-menu-sheet'),
        shrinkWrap: true,
        padding: EdgeInsetsDirectional.only(
          top: tokens.space4,
          bottom: tokens.space4,
        ),
        children: [
          if (conversationTitle case final title?)
            Padding(
              padding: EdgeInsetsDirectional.symmetric(horizontal: tokens.rail),
              child: KitText(KitBidi.auto(title), role: KitTextRole.headline),
            ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              tokens.rail,
              tokens.space4,
              tokens.rail,
              tokens.labelGap,
            ),
            child: Semantics(
              header: true,
              child: KitText(
                l10n.chatUiConversation,
                role: KitTextRole.label,
                tone: KitTextTone.secondary,
              ),
            ),
          ),
          // Views are the frequent destinations, so they take a compact
          // chip row and leave the actions below reachable without
          // scrolling on a phone. Chips wrap at large text.
          Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: tokens.rail),
            child: KitChipWrap(
              children: [
                if (resultsAvailable)
                  chip(
                    AppIconography.checkCircle,
                    l10n.chatUiResults,
                    'results',
                  ),
                chip(AppIconography.search, l10n.transcriptFindTitle, 'find'),
                chip(AppIconography.timeline, l10n.chatUiTimeline, 'timeline'),
                if (changesAvailable)
                  chip(AppIconography.review, l10n.chatUiChanges, 'changes'),
                if (todosAvailable)
                  chip(AppIconography.checklist, l10n.chatUiTodos, 'todos'),
                if (subagentsAvailable)
                  chip(AppIconography.branch, l10n.usageSubagents, 'subagents'),
              ],
            ),
          ),
          SizedBox(height: tokens.space4),
          KitExpandRow(
            title: l10n.chatUiDisplayAndContext,
            children: [
              TranscriptDisplayToggles(
                reasoningExpanded: reasoningExpanded,
                timestampsVisible: timestampsVisible,
                dense: true,
              ),
              _SessionMenuRow(
                icon: AppIconography.usageRing,
                label: l10n.chatUiContextUsage,
                value: 'context',
              ),
            ],
          ),
          KitExpandRow(
            title: l10n.chatUiSessionActions,
            children: [
              if (skillsAvailable)
                _SessionMenuRow(
                  icon: AppIconography.extensions,
                  label: l10n.skillMenu,
                  value: 'skills',
                ),
              if (notesAvailable)
                _SessionMenuRow(
                  icon: AppIconography.note,
                  label: l10n.sessionNoteTitle,
                  value: 'note',
                ),
              if (approvalsAvailable)
                _SessionMenuRow(
                  icon: AppIconography.permissions,
                  label: l10n.approvalsUiMenu,
                  value: 'approvals',
                ),
              _SessionMenuRow(
                icon: AppIconography.retry,
                label: l10n.chatUiRetryLastPrompt,
                value: 'retry',
              ),
              if (revertAvailable)
                _SessionMenuRow(
                  icon: reverted
                      ? AppIconography.restore
                      : AppIconography.history,
                  label: reverted
                      ? (stagedRevert
                            ? l10n.revertReviewTitle
                            : l10n.chatUiRestoreMessages)
                      : l10n.chatUiRevertLastPrompt,
                  value: reverted ? 'restore' : 'revert',
                ),
              if (forkAvailable)
                _SessionMenuRow(
                  icon: AppIconography.fork,
                  label: l10n.chatUiForkSession,
                  value: 'fork',
                ),
              if (compactAvailable)
                _SessionMenuRow(
                  icon: AppIconography.collapse,
                  label: l10n.chatUiCompactContext,
                  value: 'compact',
                ),
              if (sharingAvailable)
                _SessionMenuRow(
                  icon: shared
                      ? AppIconography.networkOff
                      : AppIconography.globe,
                  label: shared
                      ? l10n.chatUiStopSharing
                      : l10n.chatUiShareSession,
                  value: shared ? 'unshare' : 'share',
                ),
              if (terminalAvailable)
                _SessionMenuRow(
                  icon: AppIconography.terminal,
                  label: l10n.chatUiRunShellCommand,
                  value: 'shell',
                ),
              _SessionMenuRow(
                icon: AppIcons.run,
                label: l10n.runResultsCommandsTitle,
                value: 'slash',
              ),
              // Every server can: a complete JSON copy where the server
              // exports, the loaded transcript as Markdown everywhere.
              _SessionMenuRow(
                icon: AppIconography.download,
                label: l10n.chatUiExportThisConversation,
                value: 'export',
              ),
              if (continueOnComputerAvailable)
                _SessionMenuRow(
                  icon: AppIconography.computer,
                  label: l10n.handoffUiComputerTitle,
                  value: 'continue-computer',
                ),
              if (continueOnPhoneAvailable)
                _SessionMenuRow(
                  icon: AppIconography.qrCode,
                  label: l10n.handoffUiPhoneTitle,
                  value: 'continue-phone',
                ),
              _SessionMenuRow(
                icon: AppIconography.retry,
                label: l10n.chatUiReloadMessages,
                value: 'reload',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One action of the session menu: a kit row that pops with [value].
class _SessionMenuRow extends StatelessWidget {
  const _SessionMenuRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => KitRow(
    leading: KitRowIcon(icon),
    title: label,
    onTap: () => Navigator.pop(context, value),
  );
}
