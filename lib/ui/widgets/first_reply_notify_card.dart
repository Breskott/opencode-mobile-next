import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../../state/connection.dart';
import '../../state/first_run.dart';
import '../app_theme.dart';

/// "Get told when it's done?" — the one time the app asks for notifications
/// (UX plan 5.6 step 6).
///
/// It appears above the composer once the first reply of a new person's
/// first run has completed: the moment they have watched the agent work and
/// can see why they would rather leave than wait. Accepting turns on the
/// background connection through the same call as Settings → Notifications,
/// which is what raises Android's notification permission. Either answer is
/// final; Settings stays the home for changing it.
///
/// The card decides for itself whether it exists, so the conversation only
/// tells it whether a reply has completed.
class FirstReplyNotifyCard extends StatefulWidget {
  const FirstReplyNotifyCard({
    super.key,
    required this.controller,
    required this.replyCompleted,
    this.compact = false,
  });

  final ConnectionController controller;

  /// True once this conversation holds a finished reply and is idle.
  final bool replyCompleted;

  /// True while the conversation is short on height (keyboard up, small
  /// window). The person is writing; the composer keeps the room and the
  /// question waits until they look up again.
  final bool compact;

  @override
  State<FirstReplyNotifyCard> createState() => _FirstReplyNotifyCardState();

  /// Whether this question is still owed to the person on this device. Other
  /// inline cards above the composer (the one-time tips) stay quiet until it
  /// has been answered, so a first run is never asked two things at once.
  static bool pendingFor(ConnectionController controller) =>
      !controller.isIsolated &&
      platformCapabilities.supportsNotifications &&
      platformCapabilities.supportsBackgroundService &&
      FirstRun(controller.store.prefs).notifyAskPending;
}

class _FirstReplyNotifyCardState extends State<FirstReplyNotifyCard> {
  bool _working = false;

  /// Set on either answer so the card leaves at once, before the write to
  /// preferences has finished.
  bool _answered = false;

  FirstRun get _firstRun => FirstRun(widget.controller.store.prefs);

  bool get _due {
    final controller = widget.controller;
    if (_answered || !widget.replyCompleted || controller.isIsolated) {
      return false;
    }
    // Notifications are delivered by the background service; where neither
    // exists there is nothing to offer (hide, don't disable).
    if (!platformCapabilities.supportsNotifications ||
        !platformCapabilities.supportsBackgroundService) {
      return false;
    }
    return _firstRun.notifyAskPending;
  }

  Future<void> _accept() async {
    if (_working) return;
    setState(() => _working = true);
    final controller = widget.controller;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = lookupAppLocalizations(
      Localizations.localeOf(context),
    ).e7SettingsUi22;
    final prefs = controller.notificationPreferences;
    if (!prefs.finishedRuns) await controller.setNotifyFinishedRuns(true);
    if (!prefs.requests) await controller.setNotifyRequests(true);
    final enabled = await controller.setKeepLiveInBackground(true);
    // Asked once: a refusal at Android's own prompt is an answer too.
    await _firstRun.answerNotifyAsk();
    if (!enabled) {
      messenger?.showSnackBar(
        SnackBar(content: Text(controller.backgroundLive.lastError ?? failed)),
      );
    }
    if (mounted) setState(() => _answered = true);
  }

  Future<void> _decline() async {
    setState(() => _answered = true);
    await _firstRun.answerNotifyAsk();
  }

  @override
  Widget build(BuildContext context) {
    if (!_due) return const SizedBox.shrink();
    // Already on (turned on in Settings between the reply and now): the
    // question has been answered elsewhere, so it is not asked.
    if (widget.controller.keepLiveInBackground) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_answered) _decline();
      });
      return const SizedBox.shrink();
    }
    if (widget.compact) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final copy = lookupAppLocalizations(Localizations.localeOf(context));
    return Center(
      child: ConstrainedBox(
        // At large text the sentence is tall. It scrolls inside the card so
        // the transcript and the composer always keep most of the screen.
        constraints: BoxConstraints(
          maxWidth: 860,
          maxHeight: MediaQuery.sizeOf(context).height * .42,
        ),
        child: Semantics(
          container: true,
          child: Card.filled(
            key: const ValueKey('first-reply-notify-card'),
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              AppIconography.activity,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  copy.firstRunNotifyTitle,
                                  style: theme.textTheme.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  copy.firstRunNotifyBody,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 4,
                    children: [
                      TextButton(
                        key: const ValueKey('first-reply-notify-decline'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _working ? null : _decline,
                        child: Text(copy.firstRunNotifyDecline),
                      ),
                      FilledButton.tonal(
                        key: const ValueKey('first-reply-notify-accept'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _working ? null : _accept,
                        child: Text(copy.firstRunNotifyAccept),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
