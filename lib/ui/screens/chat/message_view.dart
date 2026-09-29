part of '../chat_screen.dart';

// The conversation transcript, drawn from the kit's chat parts only
// (KitTurn, KitMessage, KitWorkLine, KitQueuedMessage; STANDARDS STATE-16,
// KIT-41). This file decides what a server message is (a prompt, a step, a
// notice) and which part draws it; the parts draw.

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

// The transcript's vocabulary (STANDARDS STATE-16 is its frozen form). The
// server stores a conversation as a flat list of messages, and that list is
// not how a person reads it:
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
//
// The list is virtualised, one server message per row, so one turn spans
// several rows: each row draws its part of the turn as a KitTurn segment
// (first: the prompt; middle: a step; last: the step that ends the turn and
// carries the footer).

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

/// The newest turn when it got no answer, as (prompt index, index of the
/// step that ends it, or null when no step came): it ended on an error the
/// agent did not get past, and no step wrote any words. [refused]: the
/// server refused the prompt before any step (a session error), which is
/// the only way a turn with no step yet counts; a turn still starting is
/// not unanswered. Null when the newest turn was answered, stopped, or is
/// still running ([running]).
(int, int?)? _unansweredTurn(
  List<MessageWithParts> messages, {
  required bool refused,
  required bool running,
}) {
  if (running) return null;
  final prompt = messages.lastIndexWhere(_isPrompt);
  if (prompt < 0) return null;
  int? last;
  for (var index = prompt + 1; index < messages.length; index += 1) {
    final message = messages[index];
    if (message.info.role != 'assistant') continue;
    last = index;
    final said = message.parts.any(
      (part) => part.type == 'text' && part.text.trim().isNotEmpty,
    );
    if (said) return null;
  }
  if (last == null) return refused ? (prompt, null) : null;
  final info = messages[last].info;
  final raw = info.errorText;
  if (raw == null) return null;
  final kind = MessageErrorKind.refineFromText(
    info.errorKind ?? MessageErrorKind.unknown,
    raw,
  );
  if (kind == MessageErrorKind.aborted) return null;
  return (prompt, last);
}

/// The words of a prompt, when that is all it is: null when it carried
/// files, which a resend from here could not bring along.
String? _promptWordsOnly(MessageWithParts prompt) {
  if (prompt.parts.any((part) => part.type == 'file')) return null;
  final text = prompt.parts
      .where((part) => part.type == 'text')
      .map((part) => part.text)
      .where((value) => value.trim().isNotEmpty)
      .join('\n');
  return text.trim().isEmpty ? null : text;
}

/// For each turn, the one message that carries its "more" control: the step
/// that ends the turn when that step draws anything, otherwise the last step
/// that does. A turn often ends on pure bookkeeping (a `step-finish`), and
/// the control must not vanish with it.
Set<int> _turnActionOwners(
  List<MessageWithParts> messages,
  List<List<Part>> display, {
  required bool metaAlways,
  bool running = false,
  Set<String> ignore = const {},
}) {
  final owners = <int>{};
  int? lastStep;
  int? lastWithBody;
  bool hasBody(int index) =>
      display[index].any((part) => part.isRenderable) ||
      messages[index].info.errorText != null ||
      messages[index].info.finish == 'length';
  void closeTurn({bool last = false}) {
    final end = lastStep;
    // The turn in progress has no footer yet: its control would sit under
    // whatever step happens to be newest and jump down with every new one.
    // It arrives when the turn ends; long-press works meanwhile.
    if (end != null && !(last && running)) {
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
    // Not drawn, so neither a prompt that ends a turn nor a step of one.
    if (ignore.contains(messages[index].info.id)) continue;
    if (_isPrompt(messages[index])) {
      closeTurn();
    } else if (messages[index].info.role == 'assistant') {
      lastStep = index;
      if (hasBody(index)) lastWithBody = index;
    }
  }
  closeTurn(last: true);
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

/// A quiet divider row for session-state changes (`model-switched`,
/// `agent-switched`, `location-switched`) and the compaction-running line:
/// hairline, centred words, hairline ([KitMessage.marker]).
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

  /// Any non-null value draws the marker as working (compaction running);
  /// the kit's working mark replaces [icon].
  final Widget? leading;

  /// Retired by chat-1: the previous value is not shown (a switch says what
  /// it switched to). Kept so existing callers compile.
  final String? detail;

  @override
  Widget build(BuildContext context) =>
      KitMessage.marker(text: label, icon: icon, working: leading != null);
}

/// A background command that finished, as one line like the work lines:
/// the command as a person would say it and how it ended. The full command
/// and its output open under it. OpenCode 2 files these as notices whose
/// text is the raw `<shell …>` envelope; shown as it came, that was markup
/// and a wall of output after every background run.
class BackgroundShellResultRow extends StatefulWidget {
  const BackgroundShellResultRow({super.key, required this.result});

  final BackgroundShellResult result;

  @override
  State<BackgroundShellResultRow> createState() =>
      _BackgroundShellResultRowState();
}

class _BackgroundShellResultRowState extends State<BackgroundShellResultRow> {
  late bool _open = widget.result.outcome == BackgroundShellOutcome.failed;

  @override
  Widget build(BuildContext context) {
    final strings = _chatL10n(context);
    final result = widget.result;
    final (status, detail) = switch (result.outcome) {
      BackgroundShellOutcome.finished => (KitToolStatus.done, null),
      BackgroundShellOutcome.stopped => (KitToolStatus.stopped, null),
      BackgroundShellOutcome.failed => (
        KitToolStatus.failed,
        result.exitCode == null ? null : strings.workExitCode(result.exitCode!),
      ),
    };
    return KeyedSubtree(
      key: const Key('background-shell-result'),
      child: KitToolRow(
        kind: KitToolKind.shell,
        title: shortCommand(result.command),
        status: status,
        detail: detail,
        expanded: _open,
        onExpansionChanged: (open) => setState(() => _open = open),
        body: [
          KitTerminalView.output(
            key: const Key('background-shell-output'),
            command: result.command,
            output: result.output,
            onOpenFull: (text) => unawaited(
              showFilePreviewSheet(
                context,
                FilePreviewData(name: 'terminal.txt', text: text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Something that happened during a turn and that nobody typed (context
/// added, instructions updated, a compaction), as one line
/// ([KitMessage.notice]) that opens to its text.
class TranscriptNotice extends StatefulWidget {
  const TranscriptNotice({
    super.key,
    required this.header,
    required this.icon,
    required this.text,
    this.headerMono,
    this.markdown = false,
    this.error = false,
    this.actionLabel,
    this.onAction,
  });

  /// The one thing to do about this notice, on its line ("Compact again" on
  /// a failed compaction). Absent when there is nothing to do.
  final String? actionLabel;
  final VoidCallback? onAction;

  final String header;

  /// Appended to [header] in mono, isolated left-to-right (a skill name).
  final String? headerMono;
  final IconData icon;
  final String text;

  /// Retired by chat-1: the opened text is always Markdown now.
  final bool markdown;

  /// A failure: said in words ("Failed"), never in red, and opened at first
  /// so its reason is in view.
  final bool error;

  @override
  State<TranscriptNotice> createState() => _TranscriptNoticeState();
}

class _TranscriptNoticeState extends State<TranscriptNotice> {
  late bool _open = widget.error;

  @override
  Widget build(BuildContext context) {
    final body = widget.text.trim();
    final label = widget.actionLabel;
    final onAction = widget.onAction;
    return KitMessage.notice(
      text: widget.header,
      icon: widget.icon,
      technical: widget.headerMono,
      failed: widget.error,
      detail: body.isEmpty ? null : _proseMarkdown(context, body),
      expanded: body.isEmpty ? null : _open,
      onExpansionChanged: (open) => setState(() => _open = open),
      action: label == null || onAction == null
          ? null
          : KitAction(
              key: const Key('transcript-notice-action'),
              label: label,
              onPressed: onAction,
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
    this.onCompactAgain,
  });

  /// Retries a failed compaction. Given only for the newest failure while
  /// the conversation is idle; older ones are history.
  final VoidCallback? onCompactAgain;
  final Part part;
  final String messageId;
  final String? parentSessionID;
  final Map<String, Session> knownSessions;
  final ValueChanged<String>? onOpenChild;

  @override
  Widget build(BuildContext context) {
    final strings = _chatL10n(context);
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
    if (BackgroundShellResult.fromPart(part) case final shell?) {
      return BackgroundShellResultRow(
        key: ValueKey('background-shell-$messageId'),
        result: shell,
      );
    }
    final kind = part.toolName ?? '';
    switch (part.type) {
      case 'v2:switch':
        final (icon, prefix) = switch (kind) {
          'model' => (AppIconography.processor, strings.chatUiModel),
          'agent' => (AppIconography.support, strings.chatUiAgent),
          _ => (AppIconography.folderOpen, strings.chatUiMoved),
        };
        return TranscriptMarker(
          key: ValueKey('transcript-marker-$kind-switched-$messageId'),
          icon: icon,
          label: '$prefix → ${part.text}',
        );
      case 'v2:compaction':
        return switch (kind) {
          'running' => KitMessage.marker(
            key: ValueKey('compaction-running-$messageId'),
            text: part.text.isEmpty
                ? strings.chatUiCompactingConversation
                : part.text,
            working: true,
          ),
          'failed' => TranscriptNotice(
            key: ValueKey('compaction-failed-$messageId'),
            icon: AppIconography.collapse,
            header: strings.chatUiCompactionFailed,
            // What it means for the reader, then the reason when the app
            // knows it (the server's own text is never the copy).
            text: [
              strings.chatUiCompactionFailedHint,
              if (agentErrorWords(part.text, strings) case (
                :final headline,
                humanized: true,
                hint: _,
              ))
                headline,
            ].join(' '),
            error: true,
            actionLabel: strings.chatUiCompactAgain,
            onAction: onCompactAgain,
          ),
          _ => TranscriptNotice(
            key: ValueKey('compaction-completed-$messageId'),
            icon: AppIconography.collapse,
            header: strings.chatUiContextCompacted,
            text: part.text,
          ),
        };
      default:
        // A message type this app does not know carries nothing but its
        // name ("idle"): a row saying "Server message · idle" told the
        // reader nothing and repeated after every turn.
        if (kind == 'unknown' &&
            RegExp(r'^[a-z][a-z0-9._-]*$').hasMatch(part.text.trim())) {
          return const SizedBox.shrink();
        }
        final (icon, header, mono) = switch (kind) {
          'instructions' => (
            AppIconography.note,
            strings.sessionInstructionsUpdated,
            null,
          ),
          'synthetic' => (
            AppIconography.sparkle,
            part.filename ?? strings.chatUiContextAdded,
            null,
          ),
          'system' => (
            AppIconography.settingsAdvanced,
            part.filename ?? strings.chatUiSystemUpdate,
            null,
          ),
          'skill' => (
            AppIcons.run,
            strings.chatUiSkill,
            part.filename ?? part.text,
          ),
          _ => (
            AppIconography.server,
            part.filename ??
                _noticeTitle(part.text) ??
                strings.chatUiServerMessage,
            null,
          ),
        };
        final titledByText =
            part.filename == null &&
            !const {
              'instructions',
              'synthetic',
              'system',
              'skill',
            }.contains(kind) &&
            _noticeTitle(part.text) != null;
        return TranscriptNotice(
          key: ValueKey('transcript-notice-$messageId'),
          icon: icon,
          header: header,
          headerMono: mono,
          text: kind == 'instructions'
              ? strings.sessionInstructionsApplied
              : kind == 'skill' && part.filename == null
              ? ''
              : titledByText
              ? _noticeRest(part.text)
              : part.text,
        );
    }
  }
}

/// A notice's own first line, when it is short enough to be a title. "Server
/// message" says nothing; the message usually says what it is about.
String? _noticeTitle(String text) {
  final first = text.trim().split('\n').first.trim();
  final plain = first.replaceAll(RegExp(r'[*_`#]+'), '').trim();
  return plain.isEmpty || plain.length > 60 ? null : plain;
}

String _noticeRest(String text) {
  final trimmed = text.trim();
  final breakAt = trimmed.indexOf('\n');
  return breakAt < 0 ? '' : trimmed.substring(breakAt).trim();
}

/// Agent or person Markdown that no one selects or acts on inside it: a
/// prompt bubble (its long-press is the prompt's menu), a thought, a notice.
/// A reply's prose goes through [MarkdownText], which adds the agent blocks
/// (```choices```), file links and the code reader.
KitMarkdown _proseMarkdown(
  BuildContext context,
  String text, {
  KitTextRole role = KitTextRole.body,
}) => KitMarkdown(
  text,
  role: role,
  tone: role == KitTextRole.secondary ? KitTextTone.secondary : null,
  selectable: false,
  interactive: MarkdownInteractionScope.enabledOf(context),
  highlighter: TranscriptHighlight.decorate,
);

/// What the work of [tools] did, counted for the work line's words.
KitWorkCounts _workCounts(Iterable<Part> tools, {required int steps}) {
  var read = 0;
  var searched = 0;
  var listed = 0;
  var edited = 0;
  var ran = 0;
  var fetched = 0;
  var delegated = 0;
  var other = 0;
  var notRun = 0;
  for (final part in tools) {
    if (!part.toolState.executed) {
      notRun++;
      continue;
    }
    switch (part.toolName?.trim().toLowerCase() ?? '') {
      case 'read':
        read++;
      case 'glob' || 'grep':
        searched++;
      case 'list':
        listed++;
      case 'edit' || 'write' || 'patch' || 'apply_patch' || 'multiedit':
        edited++;
      case 'bash' || 'shell':
        ran++;
      case 'webfetch' || 'websearch':
        fetched++;
      case 'task' || 'subagent':
        delegated++;
      default:
        other++;
    }
  }
  return KitWorkCounts(
    read: read,
    searched: searched,
    listed: listed,
    edited: edited,
    ran: ran,
    fetched: fetched,
    delegated: delegated,
    other: other,
    notRun: notRun,
    steps: steps,
  );
}

bool _isToolPart(Part part) => part.type == 'tool';

/// What a finished turn did on its way to the answer: the passing words the
/// agent said between steps ("Now let me test each command:") and the
/// notices the server filed mid-turn (a background command finishing). Once
/// the turn is over they belong with the work, folded under its line.
///
/// Only passing words fold (decision 2026-09-28, review board "chat", gap
/// 17): an explanation the agent wrote before its last step ("The
/// flakiness comes from CheckoutBloc…") is part of the answer and stays in
/// view, below the turn's one work line. The work folds; the prose never
/// hides.
final _foldedIntoWork = Expando<bool>('folded into work');

/// Whether [text], said between steps, is passing words ("Looking into
/// it.", "Now let me run the tests:") rather than an explanation: one short
/// line, or one line that leads into the next step with a colon. A second
/// line, a paragraph break or a code block makes it an explanation.
bool _isPassingWords(String text) {
  final words = text.trim();
  if (words.isEmpty) return true;
  if (words.contains('\n') || words.contains('```')) return false;
  return words.length <= 80 || (words.endsWith(':') && words.length <= 200);
}

bool _isFoldedIntoWork(Object item) => _foldedIntoWork[item] ?? false;

/// A notice [_isFoldedIntoWork] took into the work line. It draws nothing of
/// its own in the transcript.
bool _isFoldedNotice(MessageWithParts message) => _isFoldedIntoWork(message);

bool _foldableNotice(MessageWithParts message) {
  final part = v2VariantPart(message);
  return part != null &&
      part.type == 'v2:notice' &&
      BackgroundAgentResult.fromPart(part) == null;
}

/// Marks, for each finished turn, what folds into its work. The turn still
/// running ([liveTail]) keeps everything in view: what the agent says while it
/// works is how the reader follows along. Every mark is written each time,
/// so a turn that is continued is unfolded again.
void _markFoldedWork(List<MessageWithParts> messages, {bool liveTail = false}) {
  var start = 0;
  void closeTurn(int end, {required bool live}) {
    // The turn in reading order: each entry is a part, or a notice message.
    final entries = <Object>[];
    var seenAssistant = false;
    for (var i = start; i < end; i += 1) {
      final message = messages[i];
      _foldedIntoWork[message] = false;
      if (message.info.role == 'assistant') {
        seenAssistant = true;
        for (final part in message.parts.where((part) => part.isRenderable)) {
          _foldedIntoWork[part] = false;
          entries.add(part);
        }
      } else if (seenAssistant && _foldableNotice(message)) {
        entries.add(message);
      }
    }
    if (live) return;
    bool isWork(Object entry) =>
        entry is Part && (entry.type == 'tool' || entry.type == 'reasoning');
    bool isText(Object entry) => entry is Part && entry.type == 'text';
    final lastWork = entries.lastIndexWhere(isWork);
    if (lastWork < 0) return;
    // Text before the last work is on the way; but a turn that ended on a
    // tool call still said something last, and that stays the answer.
    var cutoff = lastWork;
    if (!entries.skip(lastWork + 1).any(isText)) {
      cutoff = entries.lastIndexWhere(isText);
      while (cutoff > 0 && isText(entries[cutoff - 1])) {
        cutoff -= 1;
      }
    }
    for (var i = 0; i < entries.length; i += 1) {
      // Text folds only on the way to the answer, and only passing words;
      // a notice (a background command finishing) is part of the work
      // wherever it landed.
      final entry = entries[i];
      if ((entry is Part &&
              isText(entry) &&
              i < cutoff &&
              _isPassingWords(entry.text)) ||
          entry is MessageWithParts) {
        _foldedIntoWork[entry] = true;
      }
    }
  }

  for (var index = 0; index < messages.length; index += 1) {
    if (!_isPrompt(messages[index])) continue;
    closeTurn(index, live: false);
    start = index + 1;
  }
  closeTurn(messages.length, live: liveTail);
}

List<List<Part>> _timelineDisplayParts(
  List<MessageWithParts> messages, {
  bool liveTail = false,
}) {
  _markFoldedWork(messages, liveTail: liveTail);
  final display = List.generate(messages.length, (_) => <Part>[]);
  final pendingParts = <Part>[];
  String? pendingType;
  int? pendingOwner;
  int? lastAssistant;
  // The turn still running keeps its work where it happened, between the
  // words, so the reader can follow along; a finished turn gathers its
  // work into one line (the first stretch's place) with the explanation it
  // kept in view after it (see [_foldedIntoWork]).
  final liveFrom = liveTail ? messages.lastIndexWhere(_isPrompt) + 1 : null;
  int? poolOwner;
  var poolEnd = 0;

  void flushPending() {
    if (pendingOwner case final owner?) {
      if (pendingType == 'text') {
        display[owner].add(_mergeTextParts(pendingParts));
      } else if (poolOwner case final pool?) {
        display[pool].insertAll(poolEnd, pendingParts);
        poolEnd += pendingParts.length;
      } else {
        display[owner].addAll(pendingParts);
        if (liveFrom == null || owner < liveFrom) {
          poolOwner = owner;
          poolEnd = display[owner].length;
        }
      }
    }
    pendingParts.clear();
    pendingType = null;
    pendingOwner = null;
  }

  void appendPart(int owner, Part part) {
    final mergeable =
        part.type == 'tool' ||
        part.type == 'text' ||
        part.type == 'reasoning' ||
        _isFoldedIntoWork(part);
    if (!mergeable) {
      flushPending();
      poolOwner = null;
      display[owner].add(part);
      return;
    }
    // Two kinds of stretch: what the agent says (text) and what it does
    // (thoughts and tool calls). A stretch of work runs across as many steps
    // as it takes and belongs to the step that began it, so it can be drawn
    // as one thing.
    final kind = part.type == 'text' && !_isFoldedIntoWork(part)
        ? 'text'
        : 'work';
    if (pendingType != null && pendingType != kind) flushPending();
    pendingType ??= kind;
    pendingOwner ??= owner;
    pendingParts.add(part);
  }

  for (var index = 0; index < messages.length; index += 1) {
    final message = messages[index];
    final parts = message.parts.where((part) => part.isRenderable);
    if (_isFoldedNotice(message)) {
      // Drawn inside the work line of the step that began the stretch.
      for (final part in message.parts.where(
        (part) => part.type == 'v2:notice',
      )) {
        _foldedIntoWork[part] = true;
        appendPart(pendingOwner ?? lastAssistant!, part);
      }
      continue;
    }
    if (message.info.role != 'assistant') {
      flushPending();
      poolOwner = null;
      display[index].addAll(parts);
      continue;
    }
    lastAssistant = index;

    if (message.info.errorText != null && parts.isEmpty) flushPending();
    for (final part in parts) {
      appendPart(index, part);
    }
    if (message.info.errorText != null) {
      flushPending();
      // An error is drawn where it happened: work after it starts anew.
      poolOwner = null;
    }

    final nextIsAssistant =
        index + 1 < messages.length &&
        (messages[index + 1].info.role == 'assistant' ||
            _isFoldedNotice(messages[index + 1]));
    if (!nextIsAssistant) flushPending();
  }
  flushPending();
  return display;
}

/// [_mergeTextParts] for its parity test (a streamed reply's fragments
/// joined the way the transcript draws them).
@visibleForTesting
Part debugMergeTextParts(List<Part> parts) => _mergeTextParts(parts);

Part _mergeTextParts(List<Part> parts) {
  assert(parts.isNotEmpty);
  if (parts.length == 1) return parts.single;
  final first = parts.first;
  final buffer = StringBuffer();
  // What the buffer ends with, tracked from the last fragment written:
  // reading it back from the buffer would copy the whole prefix per
  // fragment, quadratic in a long streamed reply (codex-perf chat.md #1).
  var endsWithNewline = false;
  for (final part in parts) {
    if (part.text.trim().isEmpty) continue;
    if (buffer.isNotEmpty && !endsWithNewline && !part.text.startsWith('\n')) {
      buffer.write('\n\n');
    }
    buffer.write(part.text);
    endsWithNewline = part.text.endsWith('\n');
  }
  final merged = Part(
    id: first.id,
    messageID: first.messageID,
    type: first.type,
    text: buffer.toString(),
  );
  if (parts.any(_isFoldedIntoWork)) _foldedIntoWork[merged] = true;
  return merged;
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
    // A thought that is only markup ("**", a lone "#") draws an empty rule.
    if (current.type == 'reasoning' &&
        current.text.replaceAll(RegExp(r'[\s*_`#>-]+'), '').isEmpty) {
      index += 1;
      continue;
    }
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

/// Everything the agent did between two things it said: thoughts, tool calls
/// and runs of them, folded under one [KitWorkLine]. Closed, the line says
/// how much was done; while work is going on it names the step in hand, and
/// while a request waits for the person it says "Waiting for you" (never a
/// spinner, AUTO-15). Open, the steps hang off a rule in the order they
/// happened.
class _WorkGroup extends StatefulWidget {
  const _WorkGroup({
    super.key,
    required this.runs,
    required this.expansionStore,
    required this.buildRun,
    this.waitingForYou = false,
    this.stopped = false,
  });

  final List<_AssistantPartRun> runs;
  final Map<String, bool> expansionStore;
  final List<Widget> Function(_AssistantPartRun run) buildRun;

  /// A permission or question for this conversation waits for the person.
  final bool waitingForYou;

  /// The person stopped the turn this work belongs to.
  final bool stopped;

  @override
  State<_WorkGroup> createState() => _WorkGroupState();
}

class _WorkGroupState extends State<_WorkGroup> {
  Iterable<Part> get _tools => widget.runs
      .expand((run) => run.parts)
      .where((part) => part.type == 'tool');

  String get _storeKey {
    final first = widget.runs.first.parts.first;
    return 'work:${first.id ?? first.callID ?? first.messageID}';
  }

  /// Whether the work ended on a failure. Agents fail and retry all the
  /// time (a patch that did not apply, then one that did); a failure they got
  /// past is a detail of the steps, not the state of the work.
  bool get _endedFailed =>
      _tools.isNotEmpty && _tools.last.toolState.status == 'error';

  @override
  Widget build(BuildContext context) {
    final strings = _chatL10n(context);
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
    final state = livePart != null
        ? (widget.waitingForYou
              ? KitWorkState.waitingForYou
              : KitWorkState.running)
        : _endedFailed
        ? KitWorkState.endedFailed
        : widget.stopped
        ? KitWorkState.stopped
        : KitWorkState.done;
    final now = state == KitWorkState.running
        ? liveRun!.heading ??
              runningToolTicker(
                livePart!.toolName ?? 'tool',
                livePart.toolState,
                l10n: strings,
              )
        : null;
    // Only an unrecovered failure or a produced file is worth opening
    // unasked; progress is already named on the closed line.
    final opensByDefault =
        KitWorkLine.opensByDefault(state) ||
        _tools.any((part) => part.toolState.outputFiles.isNotEmpty);
    return KeyedSubtree(
      key: const Key('work-group'),
      child: KitWorkLine(
        counts: _workCounts(_tools, steps: widget.runs.length),
        state: state,
        now: now,
        expanded: widget.expansionStore[_storeKey] ?? opensByDefault,
        onExpansionChanged: (open) =>
            setState(() => widget.expansionStore[_storeKey] = open),
        lineKey: const Key('work-group-header'),
        stepsKey: const Key('work-group-steps'),
        steps: [for (final run in widget.runs) ...widget.buildRun(run)],
      ),
    );
  }
}

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
    this.heading,
    this.note,
  });

  /// See [_AssistantPartRun.heading] and [_AssistantPartRun.note].
  final String? heading;
  final String? note;
  final Part part;
  final bool reasoningExpanded;

  /// Opens a subagent's child session from a `task` card; null hides it.
  final ValueChanged<String>? onOpenSession;

  /// True while this is the block the assistant is still writing.
  final bool streaming;
  final Map<String, bool> expansionStore;
  final ToolOutputFileLoader filePreviewLoader;
  final ToolOutputFileAction? onAttachFile;
  final ToolOutputFileAction onDownloadFile;

  @override
  Widget build(BuildContext context) {
    if (part.type == 'text') {
      // The reply's prose: plain body text at the prose's start edge, capped
      // at a reading width on wide windows ([KitMessage.reply]'s look).
      // Selectable on touch; desktop keeps the transcript-wide selection.
      return KeyedSubtree(
        key: const Key('assistant-text-block'),
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: KitLayout.readingWidth),
            child: MarkdownText(
              part.text,
              selectable: !desktopInteractions,
              onChoice: (option) => _insertChoice(context, option),
            ),
          ),
        ),
      );
    }
    if (part.type == 'reasoning') {
      return _Reasoning(
        text: part.text,
        expanded: reasoningExpanded,
        working: streaming,
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
      final chat = context.findAncestorStateOfType<_ChatScreenState>();
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
        waitingForYou: chat?._toolWaitsForYou(part) ?? false,
        onRerunCommand: chat?._rerunShellCommand,
      );
    }
    if (part.type == 'file') {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: KitChip(
          icon: AppIconography.attach,
          label: part.filename ?? _chatL10n(context).chatUiAttachment,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  /// Routes a tapped ```choices option into the composer through the same
  /// path the empty-transcript suggestion chips use. Hosts without the chat
  /// screen (isolated previews) copy it instead (the kit says "Copied").
  static void _insertChoice(BuildContext context, String option) {
    final chat = context.findAncestorStateOfType<_ChatScreenState>();
    if (chat != null) {
      chat._insertSuggestion(option);
      return;
    }
    unawaited(KitCopy.copy(context, option));
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
  final ValueChanged<BuildContext>? onSearchExcerptContext;

  /// The message's actions as menu entries (copy, fork, read aloud, revert,
  /// delete): the prompt's long-press and right-click menu, and the reply's
  /// More, long-press and right-click menu (without Copy, which the turn's
  /// footer shows beside More).
  final List<KitMenuItem> Function()? contextActions;
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

  /// This turn got no answer: [onResendPrompt] sends its prompt again, and
  /// a "model not found" names [suggestedModel], which
  /// [onUseSuggestedModel] switches to before resending (see
  /// [_AssistantErrorRow]). On the prompt, [unanswered] marks it "Not
  /// answered".
  final VoidCallback? onResendPrompt;

  /// The newest reply was cut off by a lost connection: sends the prompt
  /// again. Null hides the action.
  final VoidCallback? onSendInterruptedAgain;
  final String? suggestedModel;
  final VoidCallback? onUseSuggestedModel;
  final bool unanswered;

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
    this.onSearchExcerptContext,
    this.contextActions,
    required this.filePreviewLoader,
    required this.onAttachFile,
    required this.onDownloadFile,
    this.onCompact,
    this.onOpenProviders,
    this.onContinue,
    this.onChooseModel,
    this.onResendPrompt,
    this.onSendInterruptedAgain,
    this.suggestedModel,
    this.onUseSuggestedModel,
    this.unanswered = false,
    this.onOpenSession,
    this.queued = false,
    this.showActions = true,
    this.errorRecovered = false,
    this.onCopy,
  });

  /// The host's copy of the turn's reply. The footer copies through the
  /// kit (KitCopy); a non-null value says there is a reply to copy.
  final VoidCallback? onCopy;

  /// See [_AssistantErrorRow.recovered].
  final bool errorRecovered;

  /// Whether this message ends its turn and carries the turn's footer. A
  /// reply is usually several messages; only the one that ends it carries
  /// the footer, so it appears once per turn. Long-press and right-click
  /// stay on every message.
  final bool showActions;

  /// True for a user prompt the server has accepted but not started: it
  /// runs after the current turn (OpenCode 1 queues mid-turn sends).
  final bool queued;

  _ChatScreenState? _chat(BuildContext context) =>
      context.findAncestorStateOfType<_ChatScreenState>();

  List<KitMenuItem> _menuItems({bool withCopy = true}) => [
    for (final item in contextActions?.call() ?? const <KitMenuItem>[])
      if (withCopy || item.key != const ValueKey('message-menu-copy')) item,
  ];

  @override
  Widget build(BuildContext context) {
    final visibleParts = parts
        .where((p) => p.isRenderable || _isFoldedIntoWork(p))
        .toList();
    if (m.info.role == 'user') {
      return _frame(context, _promptTurn(context, visibleParts));
    }
    return _frame(context, _replyTurn(context, visibleParts));
  }

  /// Where a find match shows. In place when the words are on screen as
  /// prose: the find mark highlights them and the bar holds the count.
  /// Only a match the transcript does not show where it is (a thought, tool
  /// data, a file name, folded passing words, or far down a very long
  /// message) gets an excerpt above the turn, which says where it is found
  /// and never repeats the count (review board: find bar).
  bool _matchNeedsExcerpt(TranscriptMatch match) {
    if (match.kind != 'text') return true;
    if (match.start > _inPlaceMatchReach) return true;
    final index = match.partIndex;
    return index >= 0 &&
        index < m.parts.length &&
        _isFoldedIntoWork(m.parts[index]);
  }

  /// How far into a message (in characters) a match can sit and still be
  /// in view when the find brings the message's start on screen.
  static const _inPlaceMatchReach = 480;

  /// The find-in-conversation excerpt above the turn when the match is not
  /// visible in place, and the highlight of the words it matched.
  Widget _frame(BuildContext context, Widget turn) {
    final match = searchMatch;
    if (match == null) {
      return TranscriptHighlight(query: searchQuery, child: turn);
    }
    if (!_matchNeedsExcerpt(match)) {
      return TranscriptHighlight(
        query: searchQuery,
        child: Builder(
          builder: (context) {
            onSearchExcerptContext?.call(context);
            return turn;
          },
        ),
      );
    }
    return TranscriptHighlight(
      query: searchQuery,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (context) {
              onSearchExcerptContext?.call(context);
              return TranscriptMatchExcerpt(match: match);
            },
          ),
          turn,
        ],
      ),
    );
  }

  Widget _promptTurn(BuildContext context, List<Part> visibleParts) {
    final text = visibleParts
        .where((part) => part.type == 'text')
        .map((part) => part.text)
        .where((value) => value.trim().isNotEmpty)
        .join('\n');
    final created = m.info.time?.created;
    return KitTurn(
      segment: KitTurnSegment.first,
      phase: KitTurnPhase.finished,
      highlighted: highlighted,
      prompt: KitMessage.prompt(
        bubbleKey: ValueKey('user-prompt-${m.info.id}'),
        body: _proseMarkdown(context, text),
        attachments: [
          for (final part in visibleParts)
            if (part.type == 'file') _attachment(context, part),
        ],
        time: showTimestamp && created != null
            ? DateTime.fromMillisecondsSinceEpoch(created)
            : null,
        menu: _menuItems(),
      ),
      blocks: [
        if (queued)
          Align(
            key: ValueKey('queued-message-${m.info.id}'),
            alignment: AlignmentDirectional.centerEnd,
            child: KitText(
              _chatL10n(context).chatUiQueuedRunsAfterThisTurn,
              role: KitTextRole.caption,
              tone: KitTextTone.tertiary,
            ),
          ),
        // The prompt got no answer: said on the prompt itself, so the
        // failure and the prompt it concerns read together (the error and
        // its Send again sit right under it).
        if (unanswered)
          Align(
            key: ValueKey('prompt-not-answered-${m.info.id}'),
            alignment: AlignmentDirectional.centerEnd,
            child: KitText(
              _chatL10n(context).chatUiPromptNotAnswered,
              role: KitTextRole.caption,
              tone: KitTextTone.secondary,
            ),
          ),
      ],
    );
  }

  /// A sent file as a read-only chip under the prompt; a picture or file
  /// opens its preview, a project reference names the folder it points at.
  KitAttachment _attachment(BuildContext context, Part part) {
    final strings = _chatL10n(context);
    final name = part.filename?.trim().isNotEmpty == true
        ? part.filename!.trim()
        : strings.chatUiAttachment;
    final reference =
        part.mime == PromptAttachment.directoryReferenceMime &&
        Uri.tryParse(part.url ?? '')?.scheme == 'file';
    final image = part.mime?.startsWith('image/') ?? false;
    return KitAttachment(
      id: part.id ?? part.url ?? name,
      label: reference ? '@$name' : name,
      kind: reference
          ? KitAttachmentKind.reference
          : image
          ? KitAttachmentKind.image
          : KitAttachmentKind.file,
      detail: reference ? strings.chatUiProjectReference : null,
      onOpen: reference
          ? null
          : () => unawaited(
              showFilePreviewSheet(
                context,
                FilePreviewData.fromDataUrl(
                  name: name,
                  mimeType: part.mime,
                  url: part.url,
                ),
              ),
            ),
    );
  }

  Widget _replyTurn(BuildContext context, List<Part> visibleParts) {
    final strings = _chatL10n(context);
    final chat = _chat(context);
    final messages = chat?._messages;
    final index = messages?.indexWhere((item) => item.info.id == m.info.id);
    final createdAt = m.info.time?.created;

    // Usage rides on the same preference as timestamps: both are detail a
    // reader opts into, and the model label alone marks a switch.
    final metaParts = <String>[
      if (showTimestamp && createdAt != null)
        _fmtSessionTime(createdAt, context),
      ?meta.modelLabel,
      if (showTimestamp) ...[
        if (meta.turnTokens case final tokens?)
          strings.chatUiTokenCount(_fmtTokens(tokens)),
        if (meta.turnCost case final cost?) _fmtCost(cost),
      ],
    ];
    final raw = m.info.errorText;
    // A message whose parts are all non-renderable bookkeeping (`step-finish`,
    // `patch`, `snapshot`) has nothing to say.
    if (visibleParts.isEmpty &&
        metaParts.isEmpty &&
        raw == null &&
        m.info.finish != 'length') {
      return const SizedBox.shrink();
    }

    final errorKind = raw == null
        ? null
        : MessageErrorKind.refineFromText(
            m.info.errorKind ?? MessageErrorKind.unknown,
            raw,
          );
    final stopped = errorKind == MessageErrorKind.aborted;
    final streaming = raw == null && m.info.time?.isDone == false;
    final waiting = streaming && _requestWaits(chat);
    final endsTurn =
        showActions ||
        (messages != null &&
            index != null &&
            index >= 0 &&
            _endsTurn(messages, index));

    // The conversation is still working on this turn: it has no footer yet,
    // even when its newest step is already written.
    final latest = _inLatestTurn(messages, index);
    final busy =
        chat != null &&
        latest &&
        chat._conn.busySessions.contains(chat.widget.sessionID);
    // The connection was lost mid-reply (or the server went quiet for good):
    // the turn stops "working" and says so. A refetch on reconnect brings
    // the finished reply back and this line goes with it.
    final connectionLost =
        streaming &&
        endsTurn &&
        latest &&
        chat != null &&
        !chat._conn.isIsolated &&
        !chat._conn.isConnected;
    final interrupted =
        connectionLost ||
        (streaming &&
            endsTurn &&
            chat != null &&
            !chat._conn.isIsolated &&
            !busy &&
            createdAt != null &&
            DateTime.now().millisecondsSinceEpoch - createdAt >
                KitMotion.escalateAfter.inMilliseconds);
    final working = streaming && !interrupted;

    final runs = _groupAssistantParts(visibleParts);
    final blocks = <Widget>[
      for (final stretch in _stretches(runs))
        if (stretch.length > 1 || stretch.single.grouped)
          _WorkGroup(
            key: ValueKey(
              'work:${stretch.first.parts.first.id ?? stretch.first.parts.first.callID}',
            ),
            runs: stretch,
            expansionStore: expansionStore,
            waitingForYou: waiting,
            stopped: stopped,
            buildRun: (run) => _stepWidgets(run, runs, working, chat),
          )
        else
          _runWidget(stretch.single, runs, working, chat),
      if (raw != null && !stopped)
        _AssistantErrorRow(
          info: m.info,
          recovered: errorRecovered,
          onCompact: onCompact,
          onOpenProviders: onOpenProviders,
          onContinue: onContinue,
          onChooseModel: onChooseModel,
          onResend: onResendPrompt,
          suggestion: suggestedModel,
          onUseSuggestion: onUseSuggestedModel,
        ),
      if (m.info.finish == 'length' &&
          m.info.errorKind != MessageErrorKind.outputLength)
        KitMessage.notice(
          noticeKey: const Key('message-length-footer'),
          icon: AppIconography.textShort,
          text: strings.chatUiAnswerWasCutOffByTheLength,
        ),
    ];

    final phase = stopped
        ? KitTurnPhase.stopped
        : raw != null && !errorRecovered
        ? KitTurnPhase.failed
        : interrupted
        ? KitTurnPhase.interrupted
        : waiting
        ? KitTurnPhase.waitingForYou
        : streaming || (busy && endsTurn)
        ? KitTurnPhase.running
        : KitTurnPhase.finished;

    final footer = onCopy == null && contextActions == null
        ? null
        : KitTurnFooter(
            copyText: () =>
                chat?._messageCopy(m).text ?? _replyText(visibleParts),
            copyLabel: chat?._messageCopy(m).label,
            meta: metaParts.isEmpty ? null : metaParts.join(' · '),
            menu: _menuItems(withCopy: false),
          );

    final Widget turn = KitTurn(
      segment: endsTurn ? KitTurnSegment.last : KitTurnSegment.middle,
      phase: phase,
      since: createdAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(createdAt),
      blocks: blocks,
      footer: footer,
      interruptedAction: connectionLost && onSendInterruptedAgain != null
          ? KitAction(
              key: const Key('interrupted-send-again'),
              label: strings.chatUiSendPromptAgain,
              onPressed: onSendInterruptedAgain,
            )
          : null,
      latest: latest,
      highlighted: highlighted,
      footerKey: ValueKey('message-meta-${m.info.id}'),
      copyKey: ValueKey('message-copy-${m.info.id}'),
      moreKey: ValueKey('message-actions-${m.info.id}'),
    );
    return stopped
        ? KeyedSubtree(key: const Key('message-stopped'), child: turn)
        : turn;
  }

  /// A permission or question for this conversation waits for the person:
  /// the running work then says "Waiting for you", never that it is running
  /// (AUTO-15).
  static bool _requestWaits(_ChatScreenState? chat) {
    if (chat == null) return false;
    final session = chat.widget.sessionID;
    return chat._conn.permissionsForSession(session).isNotEmpty ||
        chat._conn.questionForSession(session) != null;
  }

  /// Whether no prompt follows this message: its footer then shows the
  /// turn's model, time and usage words (older turns keep a quiet footer).
  static bool _inLatestTurn(List<MessageWithParts>? messages, int? index) {
    if (messages == null || index == null || index < 0) return true;
    for (var next = index + 1; next < messages.length; next += 1) {
      if (_isPrompt(messages[next])) return false;
    }
    return true;
  }

  static String _replyText(List<Part> parts) => parts
      .where((part) => part.type == 'text' && part.text.trim().isNotEmpty)
      .map((part) => part.text)
      .join('\n\n');

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
      if (type == 'tool' ||
          type == 'reasoning' ||
          _isFoldedIntoWork(run.parts.first)) {
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

  /// A run inside a work line: a run of tool calls is one step per call (the
  /// agent's heading and note on the first), anything else is its own step.
  List<Widget> _stepWidgets(
    _AssistantPartRun run,
    List<_AssistantPartRun> all,
    bool streaming,
    _ChatScreenState? chat,
  ) {
    if (!run.grouped) return [_runWidget(run, all, streaming, chat)];
    return [
      for (final (index, part) in run.parts.indexed)
        ToolCard(
          key: ValueKey(part.id ?? part.callID),
          toolName: part.toolName ?? 'tool',
          state: part.toolState,
          embedded: true,
          heading: index == 0 ? run.heading : null,
          note: index == 0 ? run.note : null,
          expansionStore: expansionStore,
          expansionKey: 'tool:${part.id ?? part.callID}',
          filePreviewLoader: filePreviewLoader,
          onAttachFile: onAttachFile,
          onDownloadFile: onDownloadFile,
          onOpenSession: onOpenSession,
          waitingForYou: chat?._toolWaitsForYou(part) ?? false,
          onRerunCommand: chat?._rerunShellCommand,
        ),
    ];
  }

  Widget _runWidget(
    _AssistantPartRun run,
    List<_AssistantPartRun> all,
    bool streaming,
    _ChatScreenState? chat,
  ) => run.parts.first.type == 'v2:notice'
      ? V2TranscriptRow(
          part: run.parts.first,
          messageId: run.parts.first.messageID ?? run.parts.first.id ?? '',
        )
      : run.grouped
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: _stepWidgets(run, all, streaming, chat),
        )
      : _AssistantMessagePart(
          part: run.parts.single,
          heading: run.heading,
          note: run.note,
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

/// The assistant error, keyed on the server's typed error: overflow, auth,
/// length and model errors get the one action that fixes them, named for
/// what it acts on; anything else says what happened. Every error offers
/// its exact server words ("Error details"), which can be copied (P8.3).
/// A stop is not an error: the turn says "You stopped this reply."
class _AssistantErrorRow extends StatelessWidget {
  const _AssistantErrorRow({
    required this.info,
    this.recovered = false,
    this.onCompact,
    this.onOpenProviders,
    this.onContinue,
    this.onChooseModel,
    this.onResend,
    this.suggestion,
    this.onUseSuggestion,
  });

  final MessageInfo info;

  /// True when the turn went on after this error (the server retried, or the
  /// agent took another step). It is then a line in the story, not an alarm.
  final bool recovered;
  final VoidCallback? onCompact;
  final VoidCallback? onOpenProviders;
  final VoidCallback? onContinue;
  final VoidCallback? onChooseModel;

  /// Sends the turn's prompt again as it was: given only for the newest
  /// turn when it got no answer and the prompt is words alone.
  final VoidCallback? onResend;

  /// The model the server suggested in a "model not found" error, by name,
  /// when this server has it; [onUseSuggestion] switches to it and resends.
  final String? suggestion;
  final VoidCallback? onUseSuggestion;

  @override
  Widget build(BuildContext context) {
    final strings = _chatL10n(context);
    final raw = info.errorText ?? '';
    final words = agentErrorWords(raw, strings);
    final kind = MessageErrorKind.refineFromText(
      info.errorKind ?? MessageErrorKind.unknown,
      raw,
    );
    // Words, never the server's text: that is under Error details.
    final text = _plainErrorHeadline(words, kind, strings);
    final useSuggestion = onUseSuggestion;
    final named = suggestion;
    final (String id, KitAction? fix) = switch (kind) {
      MessageErrorKind.modelNotFound => (
        'model-not-found',
        // The server named a model it has: one tap switches to it and sends
        // the prompt again (review board: prompt error).
        useSuggestion != null && named != null && !recovered
            ? KitAction(
                key: const Key('error-action-use-suggestion'),
                label: strings.chatUiUseModelAndResend(named),
                onPressed: useSuggestion,
              )
            : onChooseModel == null
            ? null
            : KitAction(
                key: const Key('error-action-choose-model'),
                label: strings.chatUiChooseModel,
                onPressed: onChooseModel,
              ),
      ),
      MessageErrorKind.contextOverflow => (
        'context-overflow',
        onCompact == null
            ? null
            : KitAction(
                key: const Key('error-action-compact'),
                label: strings.chatUiCompactSession,
                onPressed: onCompact,
              ),
      ),
      MessageErrorKind.providerAuth => (
        'provider-auth',
        onOpenProviders == null
            ? null
            : KitAction(
                key: const Key('error-action-providers'),
                label: strings.chatUiOpenProviders,
                onPressed: onOpenProviders,
              ),
      ),
      MessageErrorKind.outputLength => (
        'output-length',
        onContinue == null
            ? null
            : KitAction(
                key: const Key('error-action-continue'),
                label: strings.messageViewContinueReply,
                onPressed: onContinue,
              ),
      ),
      // Nothing to fix first: the same prompt can simply go again.
      _ => (
        'generic',
        onResend == null || recovered || kind == MessageErrorKind.contentFilter
            ? null
            : KitAction(
                key: const Key('error-action-resend'),
                label: strings.chatUiSendPromptAgain,
                onPressed: onResend,
              ),
      ),
    };
    final hint =
        kind == MessageErrorKind.contentFilter ||
            kind == MessageErrorKind.unknown
        ? (recovered ? strings.agentErrorRecovered : words.hint)
        : null;
    return KeyedSubtree(
      key: Key('error-card-$id'),
      child: KitNotice(
        // The kit's one error glyph for every kind (map Fix: no per-kind
        // icon in the error tone).
        tone: recovered ? AppStatusTone.neutral : AppStatusTone.failure,
        message: text,
        liveRegion: false,
        notes: [?hint],
        actions: [
          ?fix,
          KitAction(
            key: const Key('error-action-details'),
            label: strings.chatUiErrorDetails,
            onPressed: () => unawaited(
              _showChatErrorDetails(
                context,
                title: strings.chatUiErrorDetails,
                text: raw.trim().isEmpty ? text : raw,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageMeta {
  const _MessageMeta({this.modelLabel, this.turnTokens, this.turnCost});

  _MessageMeta withModelLabel(String? label) => _MessageMeta(
    modelLabel: label,
    turnTokens: turnTokens,
    turnCost: turnCost,
  );

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

/// A thought, folded under its first line ([KitMessage.thought]). The
/// transcript-wide "show reasoning" setting is the default; a per-thought
/// choice outlives only the default it was made under.
class _Reasoning extends StatefulWidget {
  final String text;
  final bool expanded;
  final bool working;
  final Map<String, bool>? expansionStore;
  final String? expansionKey;
  const _Reasoning({
    required this.text,
    required this.expanded,
    this.working = false,
    this.expansionStore,
    this.expansionKey,
  });

  @override
  State<_Reasoning> createState() => _ReasoningState();
}

class _ReasoningState extends State<_Reasoning> {
  late bool _open;

  /// The thought's first line, as its title: what it was thinking about.
  static String? _preview(String text) {
    final line = text.trim().split('\n').first;
    final plain = line.replaceAll(RegExp(r'[*_`#]+'), '').trim();
    if (plain.isEmpty) return null;
    return plain.length <= 80
        ? plain
        : '${plain.substring(0, 80).trimRight()}…';
  }

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
      // dropped rather than overwritten with the toggle's value.
      if (widget.expansionKey case final key?) {
        widget.expansionStore?.remove(key);
        widget.expansionStore?.remove(_defaultKey);
      }
      _open = widget.expanded;
    }
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: const Key('assistant-reasoning-block'),
    child: KitMessage.thought(
      thoughtKey: const Key('reasoning-toggle'),
      heading: widget.working ? null : _preview(widget.text),
      working: widget.working,
      body: _proseMarkdown(context, widget.text, role: KitTextRole.secondary),
      expanded: _open,
      onExpansionChanged: (open) => setState(() {
        _open = open;
        _persist(open);
      }),
    ),
  );
}

/// Everything waiting to reach the agent, as one bubble between the
/// transcript and the composer ([KitQueuedMessage], "Waiting to send · N"):
/// offline drafts waiting for a reconnect and, on OpenCode 2, sends the
/// server accepted but has not delivered. Oldest first, each with its own
/// state words and its own menu; the bubble never acts on its own.
class _PendingSendsStrip extends StatelessWidget {
  const _PendingSendsStrip({
    super.key,
    required this.drafts,
    required this.inboxItems,
    required this.isSending,
    required this.isAcceptedUnrecorded,
    required this.onEdit,
    required this.onResend,
    required this.onRetry,
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

  /// Sends a draft the server refused again, now; null while there is no
  /// connection to send it on (it then waits for the reconnect).
  final ValueChanged<QueuedPrompt>? onRetry;
  final ValueChanged<QueuedPrompt> onDiscard;
  final ValueChanged<Api2InboxItem> onCancelInbox;
  final ValueChanged<Api2InboxItem> onFlipDelivery;

  /// A draft whose send left and never came back confirmed: it can be sent
  /// again (the person decides; it never resends on its own).
  bool _unconfirmed(QueuedPrompt entry) =>
      entry.dispatched && !isSending(entry) && !isAcceptedUnrecorded(entry);

  /// A draft whose send the server refused before anything was delivered:
  /// sending it again is safe, so Retry is offered.
  bool _refused(QueuedPrompt entry) =>
      !entry.dispatched && !isSending(entry) && entry.error != null;

  KitQueuedItem _draftItem(
    BuildContext context,
    QueuedPrompt entry,
    int index,
  ) {
    final strings = _chatL10n(context);
    final sending = isSending(entry);
    final review = entry.dispatched && !sending;
    final accepted = review && isAcceptedUnrecorded(entry);
    final state = sending
        ? KitQueuedState.sending
        : accepted
        ? KitQueuedState.reachedServer
        : review
        ? KitQueuedState.notConfirmed
        : entry.error != null
        ? KitQueuedState.failed
        : KitQueuedState.waiting;
    return KitQueuedItem(
      id: entry.id,
      key: ValueKey('queued-send-$index'),
      text: entry.text,
      state: state,
      attachmentCount: entry.attachments.length,
      // The server's words never show as copy: its plain headline only
      // (agentErrorWords), the same words the transcript uses.
      reason: switch (entry.error) {
        final raw?
            when state == KitQueuedState.failed ||
                state == KitQueuedState.notConfirmed =>
          agentErrorWords(raw, strings).headline,
        _ => null,
      },
      menu: [
        if (_refused(entry) && onRetry != null)
          KitMenuItem(
            key: const ValueKey('queued-action-retry'),
            icon: AppIconography.retry,
            label: strings.queuedRetry,
            onSelected: () => onRetry!(entry),
          ),
        if (review && !accepted)
          KitMenuItem(
            key: const ValueKey('queued-action-resend'),
            icon: AppIconography.send,
            label: strings.messageViewSendAgain,
            onSelected: () => onResend(entry),
          ),
        KitMenuItem(
          key: const ValueKey('queued-action-edit'),
          icon: AppIconography.edit,
          label: strings.chatUiEditDraft,
          enabled: !sending,
          onSelected: () => onEdit(entry),
        ),
        KitMenuItem(
          key: const ValueKey('queued-action-discard'),
          icon: AppIconography.delete,
          label: strings.chatUiDiscardDraft,
          destructive: true,
          enabled: !sending,
          onSelected: () => onDiscard(entry),
        ),
      ],
    );
  }

  KitQueuedItem _inboxItem(BuildContext context, Api2InboxItem item) {
    final strings = _chatL10n(context);
    final isUser = item.type == 'user';
    final steering = item.delivery == Api2Delivery.steer;
    return KitQueuedItem(
      id: item.id,
      key: ValueKey('pending-send-${item.id}'),
      text: isUser ? (item.promptText ?? '') : '',
      state: !isUser
          ? KitQueuedState.contextUpdate
          : steering
          ? KitQueuedState.addToThisTurn
          : KitQueuedState.afterThisReply,
      menu: [
        // Only the flip that changes the current mode is offered; the server
        // has no reorder, so none is faked.
        if (isUser)
          steering
              ? KitMenuItem(
                  key: const ValueKey('inbox-action-queue'),
                  icon: AppIcons.queue,
                  label: strings.chatUiWaitForThisRunInstead,
                  onSelected: () => onFlipDelivery(item),
                )
              : KitMenuItem(
                  key: const ValueKey('inbox-action-steer'),
                  icon: AppIcons.run,
                  label: strings.chatUiSendNowAndSteerInstead,
                  onSelected: () => onFlipDelivery(item),
                ),
        if (isUser)
          KitMenuItem(
            key: const ValueKey('inbox-action-cancel'),
            icon: AppIconography.close,
            label: strings.chatUiCancelAndReturnToTheComposer,
            onSelected: () => onCancelInbox(item),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final entries = <({int time, KitQueuedItem item})>[
      for (final (index, draft) in drafts.indexed)
        (time: draft.createdAt, item: _draftItem(context, draft, index)),
      for (final item in inboxItems)
        (time: item.timeCreated ?? 0, item: _inboxItem(context, item)),
    ]..sort((a, b) => a.time.compareTo(b.time));
    // The bubble's one call to action: sending again the one message whose
    // delivery is unconfirmed. With several, each item's menu offers it
    // (the host confirms each resend; a batch resend waits for its own
    // confirmation).
    final unconfirmed = drafts.where(_unconfirmed).toList();
    // Otherwise, Retry for what the server refused: safe to send again, so
    // one tap sends every refused draft (each keeps Retry in its menu).
    final refused = onRetry == null
        ? const <QueuedPrompt>[]
        : drafts.where(_refused).toList();
    final strings = _chatL10n(context);
    final action = unconfirmed.length == 1
        ? KitAction(
            key: const ValueKey('queued-bubble-resend'),
            icon: AppIconography.send,
            label: strings.messageViewSendAgain,
            onPressed: () => onResend(unconfirmed.single),
          )
        : refused.isNotEmpty
        ? KitAction(
            key: const ValueKey('queued-bubble-retry'),
            icon: AppIconography.retry,
            label: refused.length == 1
                ? strings.queuedRetry
                : strings.queuedRetryAll(refused.length),
            onPressed: () {
              for (final entry in refused) {
                onRetry!(entry);
              }
            },
          )
        : null;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: KitLayout.paneDetailMaxWidth,
          maxHeight:
              MediaQuery.sizeOf(context).height * KitLayout.composerMaxShare,
        ),
        child: ListView(
          // Always mounted: never claim the page's primary controller.
          primary: false,
          shrinkWrap: true,
          padding: entries.isEmpty
              ? EdgeInsets.zero
              : EdgeInsetsDirectional.symmetric(
                  horizontal: tokens.space4,
                  vertical: tokens.space1,
                ),
          children: [
            KitQueuedMessage(
              items: [for (final entry in entries) entry.item],
              action: action,
            ),
          ],
        ),
      ),
    );
  }
}

/// A server-authored background result remains separate from the parent's own
/// reply. The readable outcome is primary; exact protocol text is inspectable
/// behind its details fold.
class BackgroundAgentResultCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final strings = _chatL10n(context);
    final tokens = KitTokens.of(context);
    final (status, mark) = switch (result.state) {
      'completed' => (strings.chatUiBackgroundComplete, KitMarkState.done),
      'error' => (strings.chatUiBackgroundError, KitMarkState.failed),
      _ => (strings.chatUiBackgroundCancelled, KitMarkState.waiting),
    };
    final open = onOpenChild;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        KitText(
          strings.chatUiBackgroundResult,
          role: KitTextRole.caption,
          tone: KitTextTone.secondary,
        ),
        SizedBox(height: tokens.space1),
        KitText(
          result.description.isEmpty ? result.agent : result.description,
          role: KitTextRole.rowTitle,
        ),
        SizedBox(height: tokens.space1),
        Row(
          children: [
            KitStatusMark(state: mark, label: status),
            SizedBox(width: tokens.space2),
            Expanded(
              child: KitText(
                '${result.agent} · $status',
                role: KitTextRole.secondary,
                tone: KitTextTone.secondary,
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.space3),
        MarkdownText(
          result.body.isEmpty ? strings.chatUiNoResultText : result.body,
          selectable: false,
        ),
        if (open != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: KitButton.tertiary(
              icon: AppIconography.branch,
              label: strings.chatUiResultOpenChild,
              onPressed: () => open(result.childID),
            ),
          ),
        KitDetailsFold(label: strings.chatUiResultSourceDetails, text: rawText),
      ],
    );
  }
}
