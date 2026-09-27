import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../../state/connection.dart';
import '../../state/first_run.dart';
import '../app_theme.dart';
import '../kit/kit_ask_line.dart';
import '../kit/kit_buttons.dart';
import '../kit/kit_notice.dart';
import 'product_states.dart' show productErrorText;

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

  /// Why turning notifications on failed, said in place of the question
  /// (§4.8: a failure is a notice where the thing is, never a snackbar).
  /// The question is answered either way; dismissing clears the notice.
  String? _failure;

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
    final failed = lookupAppLocalizations(
      Localizations.localeOf(context),
    ).e7SettingsUi22;
    final prefs = controller.notificationPreferences;
    if (!prefs.finishedRuns) await controller.setNotifyFinishedRuns(true);
    if (!prefs.requests) await controller.setNotifyRequests(true);
    final enabled = await controller.setKeepLiveInBackground(true);
    // Asked once: a refusal at Android's own prompt is an answer too.
    await _firstRun.answerNotifyAsk();
    if (!mounted) return;
    setState(() {
      _answered = true;
      // The app's own sentence from the Android side ("Notification access
      // is required.") stays; exception text is said in words instead.
      final error = controller.backgroundLive.lastError;
      if (!enabled) _failure = error == null ? failed : productErrorText(error);
    });
  }

  Future<void> _decline() async {
    setState(() => _answered = true);
    await _firstRun.answerNotifyAsk();
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    if (failure != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: KitNotice(
            key: const ValueKey('first-reply-notify-failed'),
            tone: AppStatusTone.failure,
            message: failure,
            onDismiss: () => setState(() => _failure = null),
          ),
        ),
      );
    }
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
    final copy = lookupAppLocalizations(Localizations.localeOf(context));
    // One line, not a card: it sits above the composer, where every row is
    // taken from the transcript. The explanation is Android's own prompt.
    // Both answers stay in view; at large text they move under the question.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: KitAskLine(
          key: const ValueKey('first-reply-notify-card'),
          icon: AppIconography.inbox,
          question: copy.firstRunNotifyTitle,
          semanticsLabel: copy.firstRunNotifyBody,
          decline: KitAction(
            key: const ValueKey('first-reply-notify-decline'),
            label: copy.firstRunNotifyDecline,
            onPressed: _working ? null : _decline,
          ),
          accept: KitAction(
            key: const ValueKey('first-reply-notify-accept'),
            label: copy.firstRunNotifyAccept,
            onPressed: _working ? null : _accept,
          ),
        ),
      ),
    );
  }
}
