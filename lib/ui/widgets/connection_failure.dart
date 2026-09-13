/// Turns a failed connection into something a person can act on.
///
/// The transport tells us *what* failed ("connection refused", "timed out",
/// HTTP 401). The address tells us *where* the server was supposed to be. Put
/// together they usually point at one thing the user can check, and one
/// button that gets them there. Retrying a server that is not running is
/// never that button.
library;

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_en.dart';

enum ConnectionFailureAction {
  retry,
  openTermuxSetup,
  updatePassword,
  updateToken,
  changeServer,
}

class ConnectionFailure {
  const ConnectionFailure({
    required this.title,
    required this.explanation,
    required this.checks,
    required this.primary,
    required this.rawError,
  });

  /// Short headline, e.g. "Nothing is listening on this phone".
  final String title;

  /// One or two sentences that say what the failure means.
  final String explanation;

  /// Plain-language things to check, most likely first.
  final List<String> checks;

  /// The one action most likely to fix it.
  final ConnectionFailureAction primary;

  /// The verbatim error, for the Details expander.
  final String rawError;

  static bool _loopback(Uri? uri) {
    final host = uri?.host.toLowerCase() ?? '';
    return host == '127.0.0.1' ||
        host == 'localhost' ||
        host == '::1' ||
        host == '[::1]';
  }

  static ConnectionFailure diagnose({
    required String error,
    required String baseUrl,
    required bool supportsTermux,
    bool usesConnectionToken = false,
    bool requiresTokenReentry = false,
    int attempts = 1,
    AppLocalizations? l10n,
  }) {
    l10n ??= AppLocalizationsEn();
    final uri = Uri.tryParse(baseUrl);
    final lower = error.toLowerCase();
    final port = uri?.hasPort == true ? uri!.port : 4096;
    final hostLabel = uri?.host.isNotEmpty == true ? uri!.host : baseUrl;
    final unauthorized =
        lower.contains('http 401') ||
        lower.contains('http 403') ||
        lower.contains('password') && lower.contains('reject');
    final certificate =
        lower.contains('certificate') || lower.contains('handshake');
    final timedOut = lower.contains('timed out');
    final nothingAnswered =
        lower.contains('refused') ||
        lower.contains('unreachable') ||
        lower.contains('no route') ||
        lower.contains('no response') ||
        lower.contains('host name not found') ||
        lower.contains('connection dropped');
    final serverError = RegExp(r'http 5\d\d').hasMatch(lower);
    final unhealthy = lower.contains('unhealthy');
    final loopback = _loopback(uri);
    final tokenRejected =
        usesConnectionToken &&
        (unauthorized ||
            lower.contains('authentication') ||
            lower.contains('token') &&
                (lower.contains('reject') || lower.contains('invalid')));

    final retried = attempts >= 3 ? l10n.e7ConnectionFailure1(attempts) : null;

    if (usesConnectionToken && requiresTokenReentry) {
      return ConnectionFailure(
        title: l10n.e7ConnectionFailure2,
        explanation: l10n.e7ConnectionFailure3,
        checks: [l10n.e7ConnectionFailure4, ?retried],
        primary: ConnectionFailureAction.updateToken,
        rawError: error,
      );
    }
    if (tokenRejected) {
      return ConnectionFailure(
        title: l10n.e7ConnectionFailure5,
        explanation: l10n.e7ConnectionFailure6,
        checks: [l10n.e7ConnectionFailure7, ?retried],
        primary: ConnectionFailureAction.updateToken,
        rawError: error,
      );
    }
    if (usesConnectionToken && (nothingAnswered || timedOut)) {
      final local = loopback;
      return ConnectionFailure(
        title: local ? l10n.e7ConnectionFailure8 : l10n.e7ConnectionFailure9,
        explanation: local
            ? l10n.e7ConnectionFailure10(hostLabel, port)
            : l10n.e7ConnectionFailure11(hostLabel, port),
        checks: local
            ? [l10n.e7ConnectionFailure12, l10n.e7ConnectionFailure13, ?retried]
            : [
                l10n.e7ConnectionFailure14,
                l10n.e7ConnectionFailure15,
                ?retried,
              ],
        primary: ConnectionFailureAction.retry,
        rawError: error,
      );
    }
    if (unauthorized) {
      return ConnectionFailure(
        title: l10n.e7ConnectionFailure16,
        explanation: l10n.e7ConnectionFailure17,
        checks: [
          l10n.e7ConnectionFailure18,
          l10n.e7ConnectionFailure19,
          ?retried,
        ],
        primary: ConnectionFailureAction.updatePassword,
        rawError: error,
      );
    }
    if (certificate) {
      return ConnectionFailure(
        title: l10n.e7ConnectionFailure20,
        explanation: l10n.e7ConnectionFailure21,
        checks: [
          l10n.e7ConnectionFailure22,
          l10n.e7ConnectionFailure23,
          ?retried,
        ],
        primary: ConnectionFailureAction.changeServer,
        rawError: error,
      );
    }
    if (!usesConnectionToken &&
        loopback &&
        (nothingAnswered || timedOut || !serverError && !unhealthy)) {
      return ConnectionFailure(
        title: l10n.e7ConnectionFailure24,
        explanation: l10n.e7ConnectionFailure25(hostLabel, port),
        checks: [
          if (supportsTermux) l10n.e7ConnectionFailure26,
          l10n.e7ConnectionFailure27,
          l10n.e7ConnectionFailure28,
          ?retried,
        ],
        // Loopback identifies an endpoint, not whether Termux or a tunnel
        // hosts it. Retry is safe without guessing the user's setup.
        primary: ConnectionFailureAction.retry,
        rawError: error,
      );
    }
    if (timedOut) {
      return ConnectionFailure(
        title: l10n.e7ConnectionFailure29,
        explanation: l10n.e7ConnectionFailure30(hostLabel),
        checks: [
          l10n.e7ConnectionFailure31,
          l10n.e7ConnectionFailure32(port),
          ?retried,
        ],
        primary: ConnectionFailureAction.retry,
        rawError: error,
      );
    }
    if (nothingAnswered) {
      return ConnectionFailure(
        title: l10n.e7ConnectionFailure33,
        explanation: l10n.e7ConnectionFailure34(hostLabel, port),
        checks: [
          l10n.e7ConnectionFailure35,
          l10n.e7ConnectionFailure36,
          l10n.e7ConnectionFailure37,
          ?retried,
        ],
        primary: ConnectionFailureAction.retry,
        rawError: error,
      );
    }
    if (serverError || unhealthy) {
      return ConnectionFailure(
        title: l10n.e7ConnectionFailure38,
        explanation: l10n.e7ConnectionFailure39,
        checks: [
          l10n.e7ConnectionFailure40,
          l10n.e7ConnectionFailure41,
          ?retried,
        ],
        primary: ConnectionFailureAction.retry,
        rawError: error,
      );
    }
    return ConnectionFailure(
      title: l10n.e7ConnectionFailure42,
      explanation: l10n.e7ConnectionFailure43(hostLabel),
      checks: [
        usesConnectionToken
            ? l10n.e7ConnectionFailure44
            : l10n.e7ConnectionFailure45,
        ?retried,
      ],
      primary: ConnectionFailureAction.retry,
      rawError: error,
    );
  }
}
