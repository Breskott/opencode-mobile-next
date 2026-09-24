import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../state/profiles.dart' show isLoopbackHost;
import '../app_theme.dart';
import '../kit/kit.dart';
import 'connection_failure.dart';
import 'grace_timer.dart';
import 'work_status_line.dart' show confirmPhoneServerRestart;

/// What the app shows while it reconnects to a saved server, and what that
/// turns into when it does not work: one [KitStateView] page (design
/// standard §3), never a card around a message.
///
/// Each state says what is true now:
///
/// - **connecting**: "Connecting to …", progress, nothing to press;
/// - **starting** (the phone's own server is being started): "Starting
///   OpenCode…" with progress. The title never says "stopped" while it
///   starts, and no button pretends to be the progress (§2);
/// - **not answering** (still connecting after [notAnsweringGrace]): says
///   so, keeps the progress, and offers Restart for the phone's own server,
///   Try again, and Choose another server;
/// - **failed / stopped**: the diagnosis's title and explanation, its one
///   fixing action as primary, Try again as secondary, Change server and a
///   setup link as tertiary; what to check, the address and the raw error
///   are under Details.
class SavedServerConnectionCard extends StatelessWidget {
  const SavedServerConnectionCard({
    super.key,
    required this.profileName,
    required this.baseUrl,
    required this.error,
    required this.attempts,
    required this.supportsTermux,
    this.usesConnectionToken = false,
    this.requiresTokenReentry = false,
    required this.onChangeServer,
    required this.onRetry,
    this.onOpenTermuxSetup,
    this.onUpdatePassword,
    this.onUpdateToken,
    this.onStartPhoneServer,
    this.startingPhoneServer = false,
    this.inAppServer = false,
    this.startingInAppServer = false,
    this.inAppStartFailed = false,
    this.onOpenInAppSetup,
  });

  final String profileName;
  final String baseUrl;

  /// Null while connecting; the raw error text once a connect attempt failed.
  final String? error;

  /// How many attempts have failed in a row, including this one.
  final int attempts;
  final bool supportsTermux;
  final bool usesConnectionToken;
  final bool requiresTokenReentry;
  final VoidCallback onChangeServer;
  final VoidCallback onRetry;
  final VoidCallback? onOpenTermuxSetup;
  final VoidCallback? onUpdatePassword;
  final VoidCallback? onUpdateToken;

  /// Starts (or restarts) the app-managed phone server; given only for it.
  final VoidCallback? onStartPhoneServer;

  /// True while the phone server is being started.
  final bool startingPhoneServer;

  /// The profile is OpenCode running inside this app. Its failures offer
  /// [onStartPhoneServer] and nothing about Termux or tunnels.
  final bool inAppServer;

  /// The in-app server is booting.
  final bool startingInAppServer;

  /// The last start of the in-app server ended without an answer.
  final bool inAppStartFailed;

  /// Opens the in-app server's setup, where its log is. Given only after a
  /// start failed, when the log is what the person needs.
  final VoidCallback? onOpenInAppSetup;

  /// The server is the phone's own: it is named "OpenCode on this phone".
  bool get _onThisPhone => inAppServer || onStartPhoneServer != null;

  bool get _starting => startingInAppServer || startingPhoneServer;

  /// Technical text for Details: the address the person typed (the in-app
  /// server's address is the app's business), then the raw error.
  String? _details(String? rawError) {
    final lines = [if (!inAppServer) baseUrl, ?rawError];
    return lines.isEmpty ? null : lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final waiting = !_starting && error == null && !requiresTokenReentry;
    // Nothing is said during an ordinary connect; after the grace time the
    // screen says the server is not answering and offers the ways out
    // (work-tab cleanup item 10, standard §4).
    return GraceTimer(
      waiting: waiting,
      restartKey: attempts,
      builder: (context, overdue) {
        final l10n = lookupAppLocalizations(Localizations.localeOf(context));
        if (_starting) return _startingState(l10n);
        if (requiresTokenReentry || error != null) {
          return _failedState(context, l10n);
        }
        if (overdue) return _notAnsweringState(context, l10n);
        return _connectingState(l10n);
      },
    );
  }

  Widget _connectingState(AppLocalizations l10n) => KitStateView(
    key: const ValueKey('saved-server-connecting'),
    icon: AppIconography.terminal,
    tone: AppStatusTone.progress,
    title: attempts > 1
        ? l10n.e7SetupConnectingAttempt(attempts)
        : l10n.e7SetupConnectingProfile(profileName),
    titleKey: const ValueKey('saved-server-title'),
    body: l10n.e7SetupOpeningWorkspace,
    bodyKey: const ValueKey('saved-server-explanation'),
    progress: const KitProgress.waiting(
      key: ValueKey('saved-server-connect-progress'),
    ),
    details: _details(null),
  );

  Widget _startingState(AppLocalizations l10n) => KitStateView(
    key: const ValueKey('saved-server-starting'),
    icon: AppIconography.play,
    tone: AppStatusTone.progress,
    title: inAppServer ? l10n.inAppServerStarting : l10n.connectStartingPhone,
    titleKey: const ValueKey('saved-server-title'),
    body: inAppServer ? l10n.inAppServerStartingBody : l10n.connectStartingBody,
    bodyKey: const ValueKey('saved-server-explanation'),
    progress: const KitProgress.waiting(
      key: ValueKey('saved-server-connect-progress'),
    ),
    tertiary: [
      KitAction(
        key: const ValueKey('saved-server-change'),
        label: l10n.e7SetupChangeServer,
        onPressed: onChangeServer,
      ),
    ],
    details: _details(null),
  );

  Widget _notAnsweringState(BuildContext context, AppLocalizations l10n) {
    final restart = onStartPhoneServer;
    final retry = KitAction(
      key: const ValueKey('saved-server-not-answering-retry'),
      label: l10n.commonRetry,
      onPressed: onRetry,
    );
    return KitStateView(
      key: const ValueKey('saved-server-not-answering'),
      icon: AppIconography.cloudOff,
      tone: AppStatusTone.attention,
      title: _onThisPhone
          ? l10n.workServerNotAnsweringPhone
          : l10n.workServerNotAnswering(profileName),
      titleKey: const ValueKey('saved-server-title'),
      body: l10n.workServerKeepsTrying,
      bodyKey: const ValueKey('saved-server-explanation'),
      progress: const KitProgress.waiting(
        key: ValueKey('saved-server-connect-progress'),
      ),
      // The phone's own server: restarting it is the way out the app cannot
      // take alone. It asks first, because a turn in progress stops.
      primary: restart == null
          ? retry
          : KitAction(
              key: const ValueKey('saved-server-restart'),
              label: l10n.workServerRestart,
              onPressed: () async {
                if (await confirmPhoneServerRestart(context)) restart();
              },
            ),
      secondary: restart == null ? null : retry,
      tertiary: [
        KitAction(
          key: const ValueKey('saved-server-choose-another'),
          label: l10n.workChooseAnotherServer,
          onPressed: onChangeServer,
        ),
      ],
      details: _details(null),
    );
  }

  Widget _failedState(BuildContext context, AppLocalizations l10n) {
    final failure = ConnectionFailure.diagnose(
      l10n: l10n,
      error: error ?? 'Connection token is required',
      baseUrl: baseUrl,
      supportsTermux: supportsTermux,
      usesConnectionToken: usesConnectionToken,
      requiresTokenReentry: requiresTokenReentry,
      attempts: attempts,
      managedPhoneServer: onStartPhoneServer != null,
      inAppServer: inAppServer,
      inAppStartFailed: inAppStartFailed,
    );
    final termuxSetup =
        !inAppServer &&
            supportsTermux &&
            !usesConnectionToken &&
            isLoopbackHost(Uri.tryParse(baseUrl)?.host ?? '')
        ? onOpenTermuxSetup
        : null;
    final retry = KitAction(
      key: const ValueKey('saved-server-retry'),
      label: l10n.isolatedTaskRetryOpen,
      onPressed: onRetry,
    );
    final change = KitAction(
      key: const ValueKey('saved-server-change'),
      label: l10n.e7SetupChangeServer,
      onPressed: onChangeServer,
    );
    final start = onStartPhoneServer;
    final (KitAction primary, bool primaryIsRetry) = switch (failure.primary) {
      ConnectionFailureAction.startPhoneServer when start != null => (
        KitAction(
          key: const ValueKey('saved-server-start-phone'),
          label: l10n.phoneServerStartAndConnect,
          onPressed: start,
        ),
        false,
      ),
      ConnectionFailureAction.openTermuxSetup when termuxSetup != null => (
        KitAction(
          key: const ValueKey('saved-server-open-termux'),
          label: l10n.e7SetupCheckTermux,
          onPressed: termuxSetup,
        ),
        false,
      ),
      ConnectionFailureAction.updatePassword when onUpdatePassword != null => (
        KitAction(
          key: const ValueKey('saved-server-update-password'),
          label: l10n.e7SetupUpdatePassword,
          onPressed: onUpdatePassword,
        ),
        false,
      ),
      ConnectionFailureAction.updateToken when onUpdateToken != null => (
        KitAction(
          key: const ValueKey('saved-server-update-token'),
          label: l10n.updateConnectionToken,
          onPressed: onUpdateToken,
        ),
        false,
      ),
      ConnectionFailureAction.changeServer => (
        KitAction(
          key: const ValueKey('saved-server-change-primary'),
          label: l10n.e7SetupChangeServer,
          onPressed: onChangeServer,
        ),
        false,
      ),
      _ => (
        KitAction(
          key: const ValueKey('saved-server-retry-primary'),
          label: l10n.isolatedTaskRetryOpen,
          onPressed: onRetry,
        ),
        true,
      ),
    };
    final startsServer =
        failure.primary == ConnectionFailureAction.startPhoneServer &&
        start != null;
    final primaryIsChange =
        failure.primary == ConnectionFailureAction.changeServer;
    // A stopped phone server is a normal state with one fix, not an error.
    final stopped = startsServer && !inAppStartFailed;
    return KitStateView(
      key: const ValueKey('saved-server-failed'),
      icon: stopped ? AppIconography.stopCircle : AppIconography.cloudOff,
      tone: stopped ? AppStatusTone.attention : AppStatusTone.failure,
      title: failure.title,
      titleKey: const ValueKey('saved-server-title'),
      body: failure.explanation,
      bodyKey: const ValueKey('saved-server-explanation'),
      primary: primary,
      // Starting the in-app server already connects: a second "try again"
      // next to it would be the same button twice.
      secondary: primaryIsRetry || (inAppServer && startsServer) ? null : retry,
      tertiary: [
        if (!primaryIsChange) change,
        if (inAppServer && onOpenInAppSetup != null)
          KitAction(
            key: const ValueKey('saved-server-open-in-app-setup'),
            label: l10n.inAppServerOpenSetup,
            onPressed: onOpenInAppSetup,
          )
        else if ((primaryIsRetry || startsServer) && termuxSetup != null)
          KitAction(
            key: const ValueKey('saved-server-open-termux'),
            label: l10n.onboardingTermuxSetup,
            onPressed: termuxSetup,
          ),
      ],
      detailNotes: [
        if (failure.checks.isNotEmpty) l10n.e7SetupWhatToCheck,
        for (final check in failure.checks) '• $check',
      ],
      details: _details(failure.rawError),
    );
  }
}
