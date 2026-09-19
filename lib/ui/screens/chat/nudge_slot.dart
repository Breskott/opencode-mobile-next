part of '../chat_screen.dart';

/// The conversation side of the one-time nudges (UX plan 5.8 item 4). The
/// trigger rules live in [ConversationNudgeWatcher]; this only reads facts
/// from existing state, renders the single slot and wires each action to the
/// door that already exists for it.
extension _ChatNudges on _ChatScreenState {
  NudgeRegistry get _nudges => _conn.nudges;

  void _startNudges() {
    // The demo has no approvals, notifications or compaction to point at.
    if (_conn.isIsolated) return;
    _nudgeWatcher = ConversationNudgeWatcher(
      registry: _nudges,
      conversation: widget.sessionID,
    );
    _nudges.addListener(_nudgesChanged);
  }

  void _stopNudges() {
    if (_nudgeWatcher == null) return;
    _nudges.removeListener(_nudgesChanged);
    _nudgeWatcher?.dispose();
  }

  /// THE place to make nudges yield to another inline card above the
  /// composer (for example the phase 3b "Get told when it's done?" card):
  /// add its visibility here. While this is true no nudge is offered (and
  /// none is consumed) and a showing nudge is hidden until the card is gone.
  bool get _nudgeSuppressed =>
      _conn.permissionsForSession(widget.sessionID).isNotEmpty ||
      _conn.questionForSession(widget.sessionID) != null ||
      _conn.formForSession(widget.sessionID) != null ||
      _retryState != null;

  ConversationNudgeFacts _nudgeFacts() {
    final busy = _conn.busySessions.contains(widget.sessionID);
    final summary = _conn.sessionsById[widget.sessionID]?.summary;
    return ConversationNudgeFacts(
      busy: busy,
      hasAssistantReply: _messages.any(
        (message) => message.info.role == 'assistant',
      ),
      pendingPermissions: {
        for (final permission in _conn.permissionsForSession(widget.sessionID))
          permission.id: permission.permission,
      },
      // The Approvals sheet is offered on every connected server (see
      // _openSessionMenu); it has nothing to add once it is already on.
      approvalsAvailable: !_conn.autoApprovalFor(widget.sessionID).automatic,
      runChangedFiles: runChangedFiles(_messages) || (summary?.files ?? 0) > 0,
      reviewAvailable: _conn.capabilities.sessionDiff,
      contextUsage: _contextWindowUsage(),
      compactAvailable: _supportsSessionCompact,
      finishedRunNotificationsReady: _conn.finishedRunNotificationsReady,
      suppressed: _nudgeSuppressed,
    );
  }

  /// Facts come from many sources (events, the catalog, permissions), all of
  /// which end in a rebuild, so they are reported once after each frame
  /// rather than from every mutation site. An offer notifies the registry,
  /// which must not happen while building.
  void _queueNudgeObservation() {
    if (_nudgeWatcher == null || _nudgeObserveQueued) return;
    _nudgeObserveQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nudgeObserveQueued = false;
      if (mounted) _nudgeWatcher?.observe(_nudgeFacts());
    });
  }

  Widget _nudgeSlot(BuildContext context) {
    final active = _nudgeWatcher == null
        ? null
        : _nudges.activeFor(widget.sessionID);
    if (active == null || _nudgeSuppressed) return const SizedBox.shrink();
    final strings = _chatL10n(context);
    void done() => unawaited(_nudges.dismiss(active.id));
    final (message, actionLabel, icon, action) = switch (active.id) {
      NudgeId.approvals => (
        strings.nudgeApprovals(
          permissionRequestTitle(active.detail, l10n: strings),
        ),
        strings.approvalsUiMenu,
        AppIconography.shield,
        () => unawaited(
          showSessionApprovalsSheet(
            context,
            controller: _conn,
            sessionID: widget.sessionID,
          ),
        ),
      ),
      NudgeId.reviewChanges => (
        strings.nudgeReviewChanges,
        strings.demoReviewChanges,
        AppIconography.review,
        () => unawaited(_showDiff()),
      ),
      NudgeId.compact => (
        strings.nudgeCompact(active.detail),
        strings.chatUiCompactSession,
        AppIconography.idea,
        () => unawaited(_compact()),
      ),
      // Work owns the pin tip; a conversation never renders it.
      NudgeId.leaveAndBeTold || NudgeId.pinConversations => (
        strings.nudgeLeave,
        strings.e7GlossaryGotIt,
        AppIconography.notificationImportant,
        () {},
      ),
    };
    return NudgeCard(
      id: active.id,
      message: message,
      actionLabel: actionLabel,
      icon: icon,
      dismissTooltip: strings.nudgeDismiss,
      onDismiss: done,
      onAction: () {
        // Taking the action is also the end of the tip.
        done();
        action();
      },
    );
  }
}
