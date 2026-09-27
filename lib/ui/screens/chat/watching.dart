part of '../chat_screen.dart';

/// How the chat page shows a conversation someone else drives: an AI Team
/// worker's OpenCode session, which the team's own driver (Gas City's
/// `opencode acp`) owns. The page is the ordinary chat, read-only:
///
/// - one slim status line says who is being watched ([banner]);
/// - the composer is replaced by one action ([messageLabel]) that goes
///   through the caller's own path ([onMessage], the team's message
///   control), so nothing is ever typed into the watched session;
/// - nothing that changes the session is offered: no conversation menu
///   (share, fork, revert, rename, delete, compact), no message actions
///   beyond copy, no approvals, questions or forms answered here, no
///   drafts, no read receipts, no model or agent choice;
/// - it reads the transcript again every [pollInterval]: the watched
///   session runs in another OpenCode process on the same store, so the
///   connected server's event stream never carries its updates.
class ChatWatch {
  const ChatWatch({
    required this.banner,
    required this.note,
    this.messageLabel,
    this.onMessage,
    this.pollInterval = const Duration(seconds: 4),
  });

  /// The status line: "Watching furiosa · Worker · AI Team".
  final String banner;

  /// One muted sentence where the composer was: why there is no field.
  final String note;

  /// The one action where the composer was ("Message the worker"); null
  /// with [onMessage] null shows only [note].
  final String? messageLabel;

  /// Sends the person's words the caller's way (the team's message
  /// control). The chat never sends into the watched session.
  final Future<void> Function(BuildContext context)? onMessage;

  /// How often the transcript is read again.
  final Duration pollInterval;
}

extension _ChatWatching on _ChatScreenState {
  bool get _watching => widget.watch != null;

  /// Reads the watched transcript again every [ChatWatch.pollInterval]
  /// while the app is in front. The history merge keeps the reading
  /// position; a read already in flight is not doubled.
  void _startWatchPolling() {
    final watch = widget.watch;
    if (watch == null) return;
    _watchPoll?.cancel();
    _watchPoll = Timer.periodic(watch.pollInterval, (_) {
      if (!mounted) return;
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
      unawaited(_conn.ensureSession(widget.sessionID));
      if (_loading || _loadingOlder) return;
      _scheduleRecentHistoryRefresh();
    });
  }

  void _stopWatchPolling() {
    _watchPoll?.cancel();
    _watchPoll = null;
  }

  /// The one status line while watching.
  _ChatStatus _watchingStatus(ChatWatch watch) => _ChatStatus(
    id: 'watching',
    key: const ValueKey('chat-watching-banner'),
    icon: AppIconography.agent,
    tone: AppStatusTone.progress,
    message: watch.banner,
  );

  /// A child session the watched one delegated to: watched the same way.
  void _openWatchedChild(String id) {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) return;
    unawaited(
      pushKitPage<void>(
        context,
        (_) => ChatScreen(sessionID: id, watch: widget.watch),
      ),
    );
  }
}

/// A watched conversation with nothing in it yet: the worker has not said
/// anything, or its first turn is still being written.
class _WatchingEmpty extends StatelessWidget {
  const _WatchingEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    return KitStateView(
      key: const ValueKey('chat-watching-empty'),
      icon: AppIconography.agent,
      title: l10n.chatWatchEmptyTitle,
      body: l10n.chatWatchEmptyBody,
      liveRegion: false,
    );
  }
}

/// Where the composer was, while watching: the note, then the one action.
class _WatchingComposer extends StatefulWidget {
  const _WatchingComposer({required this.watch});

  final ChatWatch watch;

  @override
  State<_WatchingComposer> createState() => _WatchingComposerState();
}

class _WatchingComposerState extends State<_WatchingComposer> {
  bool _busy = false;

  Future<void> _message() async {
    final send = widget.watch.onMessage;
    if (send == null || _busy) return;
    setState(() => _busy = true);
    try {
      await send(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final watch = widget.watch;
    final label = watch.messageLabel;
    return SafeArea(
      top: false,
      child: Padding(
        key: const ValueKey('chat-watching-composer'),
        padding: EdgeInsetsDirectional.fromSTEB(
          tokens.gutter,
          tokens.space2,
          tokens.gutter,
          tokens.space3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KitText(
              watch.note,
              key: const ValueKey('chat-watching-note'),
              role: KitTextRole.secondary,
              tone: KitTextTone.secondary,
            ),
            if (label != null && watch.onMessage != null) ...[
              SizedBox(height: tokens.space2),
              KitButton.secondary(
                key: const ValueKey('chat-watching-message'),
                icon: AppIconography.chat,
                label: label,
                // The action opens its own sheet; no spinner behind it.
                onPressed: _busy ? null : () => unawaited(_message()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
