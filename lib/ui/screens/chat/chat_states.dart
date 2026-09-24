part of '../chat_screen.dart';

// The chat's states and its one status line, on the design kit
// (docs/design/design-standard.md §9 step 5). Everything here is drawn with
// lib/ui/kit/; test/design_standard_test.dart checks this file whole.
//
// - First load: the loading bar under the top bar (in the screen) and
//   placeholder turns ([_ChatLoadingBody]), never an empty-state text.
// - A conversation that could not load: [_ChatLoadError], a page state.
// - At most one status line under the top bar ([_ChatStatusLine]), most
//   urgent first: the connection, then what the screen passes in (a message
//   that was not sent, a prompt the server refused, a staged revert, the
//   subagent context, sharing).

/// The conversation's first load: placeholder turns where the transcript
/// will be. The screen's loading bar says it is loading.
class _ChatLoadingBody extends StatelessWidget {
  const _ChatLoadingBody();

  @override
  Widget build(BuildContext context) =>
      const KitSkeletonTranscript(key: ValueKey('chat-loading'));
}

/// The conversation could not be loaded and nothing of it is on screen yet.
class _ChatLoadError extends StatelessWidget {
  const _ChatLoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    return KitStateView(
      key: const ValueKey('chat-load-error'),
      icon: AppIconography.error,
      tone: AppStatusTone.failure,
      title: l10n.chatLoadFailedTitle,
      body: l10n.chatLoadFailedBody,
      primary: KitAction(
        key: const ValueKey('chat-load-retry'),
        label: l10n.commonRetry,
        onPressed: onRetry,
      ),
      // The failure surface is where a bug is found, so the report stays
      // one tap away here, as it was on the old error state.
      tertiary: [
        KitAction(
          key: const ValueKey('product-error-report-bug'),
          label: l10n.e7LibraryReportABug,
          onPressed: () => unawaited(openBugReport(context)),
        ),
      ],
      details: productErrorText(error, l10n: l10n),
    );
  }
}

/// What the chat's status line can say.
class _ChatStatus {
  const _ChatStatus({
    required this.id,
    required this.message,
    this.icon = AppIconography.info,
    this.tone = AppStatusTone.neutral,
    this.supporting,
    this.action,
    this.more = const [],
    this.onDismiss,
    this.dismissTooltip,
    this.key,
    this.messageKey,
    this.supportingKey,
    this.supportingSemanticsLabel,
  });

  /// Stable name of the kind of status, for keys and tests.
  final String id;
  final String message;
  final IconData icon;
  final AppStatusTone tone;
  final String? supporting;
  final KitAction? action;
  final List<KitAction> more;
  final VoidCallback? onDismiss;
  final String? dismissTooltip;
  final Key? key;
  final Key? messageKey;
  final Key? supportingKey;
  final String? supportingSemanticsLabel;

  Widget line() => KitStatusLine(
    key: key ?? ValueKey('chat-status-$id'),
    icon: icon,
    tone: tone,
    message: message,
    messageKey: messageKey,
    supporting: supporting,
    supportingKey: supportingKey,
    supportingSemanticsLabel: supportingSemanticsLabel,
    action: action,
    more: more,
    onDismiss: onDismiss,
    dismissTooltip: dismissTooltip,
  );
}

/// The server's exact words, for a status or error that shows the app's.
Future<void> _showChatErrorDetails(BuildContext context, String text) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_chatL10n(context).chatUiErrorDetails),
        content: SingleChildScrollView(
          child: SelectableText(
            text,
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

/// A prompt the server refused, or a session-level failure with no home in
/// the transcript: the plain sentence, what to do, the fix when there is one
/// (a model the server does not know), and the server's words under Details.
_ChatStatus _promptErrorStatus(
  BuildContext context, {
  required String message,
  required VoidCallback onDismiss,
  VoidCallback? onChooseModel,
}) {
  final l10n = _chatL10n(context);
  final words = agentErrorWords(message, l10n);
  final kind = MessageErrorKind.refineFromText(
    MessageErrorKind.unknown,
    message,
  );
  final details = words.humanized || errorHasDetails(message)
      ? KitAction(
          key: const ValueKey('prompt-error-details'),
          label: l10n.chatUiDetails,
          onPressed: () => unawaited(_showChatErrorDetails(context, message)),
        )
      : null;
  final choose = kind == MessageErrorKind.modelNotFound && onChooseModel != null
      ? KitAction(
          key: const ValueKey('prompt-error-choose-model'),
          label: l10n.chatUiChooseModel,
          onPressed: onChooseModel,
        )
      : null;
  return _ChatStatus(
    id: 'prompt-error',
    key: const ValueKey('prompt-error-banner'),
    icon: AppIconography.error,
    tone: AppStatusTone.failure,
    message: words.headline,
    messageKey: const ValueKey('prompt-error-headline'),
    supporting: words.hint,
    supportingKey: const ValueKey('prompt-error-hint'),
    action: choose ?? details,
    more: [if (choose != null && details != null) details],
    onDismiss: onDismiss,
    dismissTooltip: l10n.chatUiDismissPromptError,
  );
}

/// A message that did not reach the server. Its text is back in the
/// message box, so sending it again is the composer's own Send.
_ChatStatus _sendErrorStatus(
  BuildContext context, {
  required Object error,
  required VoidCallback onDismiss,
}) {
  final l10n = _chatL10n(context);
  final raw = productErrorText(error, l10n: l10n);
  final words = agentErrorWords(raw, l10n);
  final reason = words.headline.trim();
  return _ChatStatus(
    id: 'send-error',
    icon: AppIconography.error,
    tone: AppStatusTone.failure,
    message: l10n.chatSendFailed,
    supporting: reason.isEmpty ? l10n.chatSendFailedKept : reason,
    supportingKey: const ValueKey('chat-send-error-reason'),
    action: words.humanized || errorHasDetails(raw)
        ? KitAction(
            key: const ValueKey('chat-send-error-details'),
            label: l10n.chatUiDetails,
            onPressed: () => unawaited(_showChatErrorDetails(context, raw)),
          )
        : null,
    onDismiss: onDismiss,
  );
}

/// A revert that waits for review before it is applied.
_ChatStatus _stagedRevertStatus(
  BuildContext context, {
  required VoidCallback onReview,
}) {
  final l10n = _chatL10n(context);
  return _ChatStatus(
    id: 'staged-revert',
    icon: AppIconography.history,
    tone: AppStatusTone.attention,
    message: l10n.revertStaged,
    action: KitAction(
      key: const ValueKey('chat-status-revert-review'),
      label: l10n.revertReview,
      onPressed: onReview,
    ),
  );
}

/// This conversation is a subagent's: where it sits, the way to its
/// parent, and its siblings behind More.
_ChatStatus _subagentStatus(
  BuildContext context, {
  required int? position,
  required int? total,
  required Future<void> Function() onParent,
  required Future<void> Function() onAll,
}) {
  final l10n = _chatL10n(context);
  final count = position != null && total != null
      ? l10n.chatUiPositionOfTotal(position, total)
      : l10n.chatUiDelegatedSession;
  return _ChatStatus(
    id: 'subagent',
    icon: AppIconography.nested,
    message: l10n.chatUiSubagentCount(count),
    action: KitAction(
      key: const ValueKey('subagent-parent-session'),
      label: l10n.chatUiOpenParentSession,
      onPressed: () => unawaited(onParent()),
    ),
    more: [
      KitAction(
        key: const ValueKey('subagent-session-list'),
        label: l10n.chatUiShowAllSubagentSessions,
        onPressed: () => unawaited(onAll()),
      ),
    ],
  );
}

/// The conversation is shared by link: the link itself (what other people
/// can open), Stop sharing (asks first; also in the conversation menu), and
/// Copy behind More.
_ChatStatus _sharedStatus(
  BuildContext context, {
  required String url,
  required VoidCallback onStop,
}) {
  final l10n = _chatL10n(context);
  return _ChatStatus(
    id: 'shared',
    icon: AppIconography.globe,
    message: l10n.chatUiSharedAnyoneWithTheLinkCanView,
    supporting: url,
    supportingSemanticsLabel: l10n.chatUiSharedLink(url),
    action: KitAction(
      key: const ValueKey('chat-status-stop-sharing'),
      label: l10n.chatUiStopSharing,
      onPressed: onStop,
    ),
    more: [
      KitAction(
        key: const ValueKey('chat-status-copy-share-link'),
        label: l10n.chatUiCopyShareLink,
        onPressed: () => unawaited(Clipboard.setData(ClipboardData(text: url))),
      ),
    ],
  );
}

/// The chat's one status line (design standard §5), under the top bar.
///
/// The connection comes first, with the Work tab's words and 8 s rule
/// ([notAnsweringGrace]): while the app reconnects, only the loading bar
/// shows; after 8 s without an answer, or at once when the last attempt
/// failed or nothing is reconnecting (no bar would say anything),
/// "`server` isn't answering" with the way out (Restart for the phone's own
/// server, Try again otherwise) and the drafts waiting for it. A rejected
/// password or token says so at once, with its fix. Otherwise the first of
/// [others].
///
/// It is always in the tree (drawing nothing when there is nothing to say)
/// so the 8 s clock survives the screen's rebuilds. It adds no listener of
/// its own: the screen already rebuilds on every connection change.
class _ChatStatusLine extends StatelessWidget {
  const _ChatStatusLine({
    required this.controller,
    this.queuedNote,
    this.others = const [],
  });

  final ConnectionController controller;

  /// Drafts waiting for the connection, said under the connection line.
  final String? queuedNote;

  /// Lower-priority statuses, most urgent first; nulls are skipped.
  final List<_ChatStatus?> others;

  /// Not connected, for a reason the app may get over by itself.
  static bool serverLost(ConnectionController controller) =>
      !controller.isIsolated &&
      controller.status != StreamStatus.connected &&
      !controller.passwordRejected;

  /// Reconnecting right now: the screen's loading bar shows it.
  static bool reconnecting(ConnectionController controller) =>
      serverLost(controller) &&
      (controller.connectionLoading || controller.manualReconnectInProgress);

  _ChatStatus? _credentials(BuildContext context) {
    if (controller.isIsolated ||
        controller.status == StreamStatus.connected ||
        !controller.passwordRejected) {
      return null;
    }
    final l10n = _chatL10n(context);
    void edit() => unawaited(
      Navigator.of(context).pushNamed('/servers', arguments: 'edit-active'),
    );
    final token = controller.usesConnectionToken;
    return _ChatStatus(
      id: 'credentials',
      key: const ValueKey('connection-status-banner'),
      icon: AppIconography.locked,
      tone: AppStatusTone.failure,
      message: token
          ? l10n.connectionTokenRejected
          : l10n.e7BannerReconnectPassword,
      supporting: queuedNote,
      action: KitAction(
        key: ValueKey(token ? 'banner-update-token' : 'banner-update-password'),
        label: token ? l10n.updateConnectionToken : l10n.e7BannerUpdatePassword,
        onPressed: edit,
      ),
    );
  }

  /// The phone's own server (named "OpenCode on this phone", restartable)
  /// or another one. Only asked when the line is about to say so.
  ({bool onThisPhone, Future<void> Function()? restart}) _server(
    BuildContext context,
  ) {
    if (controller.profile == null) return (onThisPhone: false, restart: null);
    return phoneServerRestartFor(
      connection: controller,
      builtin: ProviderScope.containerOf(
        context,
        listen: false,
      ).read(builtinServerStarterProvider),
      context: context,
    );
  }

  _ChatStatus _notAnswering(BuildContext context) {
    final l10n = _chatL10n(context);
    final server = _server(context);
    final retrying = controller.manualReconnectInProgress;
    final retry = KitAction(
      key: const ValueKey('connection-banner-retry'),
      label: retrying ? l10n.e7BannerRetrying : l10n.commonRetry,
      onPressed: retrying
          ? null
          : () => unawaited(controller.retryConnection()),
    );
    final details = KitAction(
      key: const ValueKey('connection-banner-details'),
      label: l10n.e7BannerDetails,
      onPressed: () =>
          unawaited(showConnectionDetailsSheet(context, controller)),
    );
    final notes = [
      if (controller.usesConnectionToken) l10n.codexDraftReconnectNotice,
      ?queuedNote,
    ];
    final restart = server.restart;
    final phone = server.onThisPhone && restart != null;
    return _ChatStatus(
      id: 'server',
      key: const ValueKey('connection-status-banner'),
      icon: AppIconography.cloudOff,
      tone: AppStatusTone.attention,
      message: server.onThisPhone
          ? l10n.workServerNotAnsweringPhone
          : l10n.workServerNotAnswering(controller.profile?.name ?? 'OpenCode'),
      supporting: notes.isEmpty ? null : notes.join(' '),
      // The app keeps retrying by itself; for the phone's own server the
      // way out it cannot take alone is a restart, so that comes first.
      action: phone
          ? KitAction(
              key: const ValueKey('connection-banner-restart'),
              label: l10n.workServerRestart,
              onPressed: () => unawaited(() async {
                if (!await confirmPhoneServerRestart(context)) return;
                await restart();
              }()),
            )
          : retry,
      more: phone ? [retry, details] : [details],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lost = serverLost(controller);
    return GraceTimer(
      waiting: lost,
      restartKey: controller.connectionAttemptRevision,
      builder: (context, overdue) {
        _ChatStatus? status = _credentials(context);
        if (status == null &&
            lost &&
            // Nothing in flight (the last attempt ended): say so at once.
            (overdue || !reconnecting(controller))) {
          status = _notAnswering(context);
        }
        if (status == null) {
          for (final other in others) {
            if (other != null) {
              status = other;
              break;
            }
          }
        }
        return status?.line() ?? const SizedBox.shrink();
      },
    );
  }
}
