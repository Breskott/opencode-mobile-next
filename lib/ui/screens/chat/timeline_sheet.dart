part of '../chat_screen.dart';

/// Where the timeline sends the person: a message to jump to (with the
/// words they searched for, carried into find), or a prompt to fork from.
class _TimelineSelection {
  const _TimelineSelection({
    required this.message,
    required this.fork,
    this.query = '',
  });

  final MessageWithParts message;
  final bool fork;
  final String query;
}

/// The message timeline in the kit's sheet frame: newest first,
/// searchable, each row a jump; in [forkMode] only the prompts that can be
/// forked. The host rebuilds it as older history loads into the transcript.
/// A drag on the rows closes the search keyboard.
class _TimelineSheet extends StatefulWidget {
  const _TimelineSheet({
    required this.messages,
    required this.forkMode,
    required this.forkAvailable,
    this.hasOlder = false,
    this.loadingOlder = false,
    this.olderNeedsReload = false,
    this.olderError,
    this.loadOlder,
  });

  final List<MessageWithParts> messages;
  final bool forkMode;
  final bool forkAvailable;
  final bool hasOlder;
  final bool loadingOlder;
  final bool olderNeedsReload;
  final Object? olderError;
  final Future<void> Function()? loadOlder;

  @override
  State<_TimelineSheet> createState() => _TimelineSheetState();
}

class _TimelineSheetState extends State<_TimelineSheet> {
  final _search = TextEditingController();
  final _index = TranscriptSearchIndex();

  @override
  void initState() {
    super.initState();
    // The list follows every keystroke; the field's settled callback is
    // only for its announcement.
    _search.addListener(_onQuery);
  }

  void _onQuery() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _search
      ..removeListener(_onQuery)
      ..dispose();
    super.dispose();
  }

  /// A row's words: the message's prose with Markdown's marks dropped
  /// (backticks, bold, heading marks), else its files, tools or thought.
  String _preview(MessageWithParts message) {
    final text = message.parts
        .where((part) => part.type == 'text' && !part.synthetic)
        .map((part) => _plain(part.text))
        .where((text) => text.isNotEmpty)
        .join(' ')
        .trim();
    if (text.isNotEmpty) return text;

    final files = message.parts
        .where((part) => part.type == 'file' && !part.synthetic)
        .map((part) => part.filename?.trim())
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toList();
    if (files.isNotEmpty) return files.join(', ');

    final tools = message.parts
        .where((part) => part.type == 'tool')
        .map((part) => part.toolName?.trim())
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toList();
    if (tools.isNotEmpty) {
      return _chatL10n(context).chatUiToolsSummary(tools.join(', '));
    }

    final reasoning = message.parts
        .where((part) => part.type == 'reasoning')
        .map((part) => _plain(part.text))
        .firstWhere((text) => text.isNotEmpty, orElse: () => '');
    return reasoning.isNotEmpty ? reasoning : _chatL10n(context).chatUiMessage;
  }

  static String _plain(String markdown) => markdown
      .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true), '')
      .replaceAll(RegExp(r'`+|\*\*|__'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  bool _isForkable(MessageWithParts message) =>
      message.info.role == 'user' &&
      !message.info.id.startsWith('local-') &&
      message.parts.any((part) => part.type == 'text' && !part.synthetic);

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    final tokens = KitTokens.of(context);
    final query = _search.text.trim().toLowerCase();
    final hits = _index.search(widget.messages, query);
    final firstHits = <String, TranscriptMatch>{};
    for (final hit in hits) {
      firstHits.putIfAbsent(hit.messageID, () => hit);
    }
    final visible = widget.messages.reversed.where((message) {
      if (widget.forkMode && !_isForkable(message)) return false;
      if (query.isEmpty) return true;
      if (!widget.forkMode) return firstHits.containsKey(message.info.id);
      return _preview(message).toLowerCase().contains(query);
    }).toList();
    final error = widget.olderError;
    final loadOlder = widget.loadOlder;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final height = (MediaQuery.sizeOf(context).height * (largeText ? .96 : .86))
        .floorToDouble();

    return SizedBox(
      key: const ValueKey('timeline-sheet'),
      height: height,
      child: KitSheet(
        title: widget.forkMode
            ? l10n.chatUiForkFromPrompt
            : l10n.chatUiMessageTimeline,
        // Only what the rows cannot say: what forking does.
        subtitle: widget.forkMode
            ? l10n.chatUiChooseAPromptToRestoreItIn
            : widget.forkAvailable
            ? l10n.chatUiJumpAnywhereForkRestoresAPromptFor
            : null,
        fill: true,
        // The modal route draws the one handle (the theme's drag handle).
        handle: false,
        dismissKeyboardOnDrag: true,
        onClose: () => Navigator.pop(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KitSearchField(
              label: l10n.chatUiSearchMessages,
              controller: _search,
              onChanged: (_) {},
              // Messages, not occurrences: the rows below are the count.
              resultCount: query.isEmpty ? null : visible.length,
              partial: widget.hasOlder,
              fieldKey: const ValueKey('timeline-search'),
            ),
            SizedBox(height: tokens.space3),
            if (widget.hasOlder) ...[
              KitNotice(
                key: const ValueKey('timeline-older'),
                icon: AppIconography.history,
                tone: error == null
                    ? AppStatusTone.neutral
                    : AppStatusTone.failure,
                message: error == null
                    ? l10n.historyLoadedOnly
                    : productErrorText(error, l10n: l10n),
                actions: [
                  KitAction(
                    key: const ValueKey('timeline-load-older'),
                    label: widget.olderNeedsReload
                        ? l10n.historyReload
                        : l10n.historyLoadOlder,
                    working: widget.loadingOlder,
                    onPressed: loadOlder == null
                        ? null
                        : widget.loadingOlder
                        ? () {}
                        : () => unawaited(loadOlder()),
                  ),
                ],
              ),
              SizedBox(height: tokens.space3),
            ],
            if (visible.isEmpty)
              query.isNotEmpty && !widget.hasOlder
                  ? KitSearchNoMatch(
                      key: const ValueKey('timeline-no-match'),
                      query: _search.text.trim(),
                      onClear: _search.clear,
                    )
                  : KitStateView(
                      key: const ValueKey('timeline-empty'),
                      icon: AppIconography.history,
                      title: l10n.chatUiNoMatchingMessages,
                      size: KitStateSize.inline,
                    )
            else
              KitRowGroup(
                margin: EdgeInsetsDirectional.zero,
                children: [
                  for (final message in visible)
                    _timelineRow(context, message, firstHits[message.info.id]),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _timelineRow(
    BuildContext context,
    MessageWithParts message,
    TranscriptMatch? hit,
  ) {
    final l10n = _chatL10n(context);
    final isUser = message.info.role == 'user';
    final created = message.info.time?.created;
    final fork =
        widget.forkAvailable && !widget.forkMode && _isForkable(message);
    return KitRow(
      key: ValueKey('timeline-row-${message.info.id}'),
      leading: KitRow.icon(
        context,
        isUser ? AppIconography.person : AppIconography.sparkle,
      ),
      // The matched words when searching, else the message's own.
      title: hit == null ? _preview(message) : _plain(hit.preview),
      titleMaxLines: 2,
      supporting: TextSpan(
        text: [
          isUser ? l10n.chatUiYou : 'OpenCode',
          if (created != null) _fmtSessionTime(created, context),
        ].join(' · '),
      ),
      trailing: fork
          ? KitIconButton(
              key: ValueKey('timeline-fork-${message.info.id}'),
              icon: AppIconography.branch,
              tooltip: l10n.chatUiForkFromThisPrompt,
              onPressed: () => KitSheet.close(
                context,
                _TimelineSelection(message: message, fork: true),
              ),
            )
          : null,
      onTap: () => KitSheet.close(
        context,
        _TimelineSelection(
          message: message,
          fork: widget.forkMode,
          query: widget.forkMode ? '' : _search.text.trim(),
        ),
      ),
    );
  }
}
