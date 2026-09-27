import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;

import '../../api/mcp_oauth.dart' show McpOAuthCallbackException;
import '../../api/opencode_api.dart';
import '../../api/product_repository.dart';
import '../../api2/transport.dart' show Api2Error, Api2NetworkError;
import '../../builtin/builtin_folders.dart'
    show FolderListException, FolderListProblem;
import '../../builtin/builtin_linux.dart' show BuiltinLinuxException;
import '../../feedback/bug_report.dart';
import '../../l10n/app_localizations.dart';
import '../../state/local_server_controls.dart' show LocalServerControlFailure;
import '../../state/profiles.dart' show SecureStorageUnavailable;
import '../../termux/bridge.dart' show TermuxBridgeException;
import '../../termux/local_agent_runtime.dart' show LocalAgentFailure;
import '../app_theme.dart';
import '../kit/kit_buttons.dart';
import '../kit/kit_dialog.dart';
import '../kit/kit_layout.dart';
import '../kit/kit_notice.dart';
import '../kit/kit_progress.dart';
import '../kit/kit_redact.dart';
import '../kit/kit_row.dart';
import '../kit/kit_state_view.dart';
import '../kit/kit_technical_value.dart';
import '../kit/kit_text.dart';
import '../kit/kit_tokens.dart';
import '../kit/motion/kit_reveal.dart';

// The shared "not the normal content" states (map page
// embedded-product-states, proposal fix): every public name here is a thin
// wrapper over a kit part, so the ~25 pages that embed them take the kit's
// look and honesty rules in one change (kit-v2 §2.2, STATE-1 to STATE-3).

AppLocalizations _copy(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(Localizations.localeOf(context));

/// A page-size state where it has the room, the inline form in a slot
/// shorter than a short window (a sheet's fixed-height error box), so the
/// actions stay in sight instead of scrolling below the slot. Both scroll
/// (always), so pull-to-refresh keeps working.
Widget _adaptiveState(Widget Function(KitStateSize size) build) =>
    LayoutBuilder(
      builder: (context, constraints) {
        final short =
            constraints.hasBoundedHeight &&
            constraints.maxHeight < KitLayout.shortHeight;
        if (!short) return build(KitStateSize.page);
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [build(KitStateSize.inline)],
        );
      },
    );

/// What kind of failure a thrown object (or a raw failure string) is, for
/// the words [productErrorText] says. Never shown itself.
enum _Failure {
  /// App-authored words for people: shown as they are.
  words,
  network,
  timedOut,
  certificate,
  signIn,
  notFound,
  conflict,
  busy,
  server,
  rejected,
  unexpected,
  device,
  storage,

  /// Termux did not finish a command the app sent it.
  termux,

  /// Nothing known about it: the generic connectivity line.
  unknown,
}

/// A raw failure string that is transport or exception text, not words for
/// people: an exception class name, an HTTP status, an OS error, a body.
final RegExp _technical = RegExp(
  r'\b[A-Z][A-Za-z0-9]*(Exception|Error)\b'
  r'|^\s*(Exception|Error|Bad state|Invalid argument)\b'
  r'|\bHTTP\s*[1-5]\d\d\b'
  r'|\b(status|answered|returned|responded|code)\D{0,12}\b[1-5]\d\d\b'
  r'|\bOS Error\b|\berrno\b|\bstack ?trace\b|^\s*#\d+\s'
  r'|^\s*[<{\[]'
  r'|\bCannot reach\b.*:',
  caseSensitive: false,
);

final RegExp _httpStatus = RegExp(
  r'\b(?:HTTP|status(?: code)?|answered|returned|responded)\D{0,12}\b([1-5]\d\d)\b',
  caseSensitive: false,
);

/// The kind of failure a status code says.
_Failure _forStatus(int code) => switch (code) {
  401 || 403 => _Failure.signIn,
  404 || 410 => _Failure.notFound,
  408 => _Failure.timedOut,
  409 => _Failure.conflict,
  429 => _Failure.busy,
  >= 500 => _Failure.server,
  >= 400 => _Failure.rejected,
  _ => _Failure.unexpected,
};

/// The kind of failure raw transport or exception text describes, or null
/// when it names none of the known kinds.
_Failure? _forText(String text) {
  final lower = text.toLowerCase();
  if (lower.contains('certificate') ||
      lower.contains('handshake') ||
      lower.contains('tls') && lower.contains('fail')) {
    return _Failure.certificate;
  }
  if (lower.contains('timed out') ||
      lower.contains('timeout') ||
      lower.contains('took too long')) {
    return _Failure.timedOut;
  }
  if (lower.contains('connection refused') ||
      lower.contains('unreachable') ||
      lower.contains('no route') ||
      lower.contains('host name not found') ||
      lower.contains('failed host lookup') ||
      lower.contains('name or service not known') ||
      lower.contains('connection dropped') ||
      lower.contains('connection reset') ||
      lower.contains('reset by peer') ||
      lower.contains('broken pipe') ||
      lower.contains('connection closed') ||
      lower.contains('no response') ||
      lower.contains('socketexception') ||
      lower.contains('clientexception') ||
      lower.contains('websocket') ||
      lower.contains('network') ||
      lower.contains('cannot reach')) {
    return _Failure.network;
  }
  if (lower.contains('filesystemexception') ||
      lower.contains('pathnotfound') ||
      lower.contains('no space left') ||
      lower.contains('read-only file system')) {
    return _Failure.storage;
  }
  if (lower.contains('platformexception') ||
      lower.contains('missingpluginexception')) {
    return _Failure.device;
  }
  final status = _httpStatus.firstMatch(text);
  if (status != null) return _forStatus(int.parse(status.group(1)!));
  return null;
}

/// The IO types, matched by name so this file imports no `dart:io`.
const Set<String> _storageTypes = {
  'FileSystemException',
  'PathNotFoundException',
  'PathAccessException',
  'PathExistsException',
};

/// Codes whose [BuiltinLinuxException] message the app wrote for people.
const Set<String> _builtinWordCodes = {
  'unsupported_platform',
  'missing_plugin',
  'storage_unavailable',
  'removal_failed',
  'confirmation_required',
  'team_state_unavailable',
};

/// One short sentence for people, not native text or command output (a
/// Java message, a script's last lines, an exit code, a class name).
bool _isSentence(String message) =>
    message.isNotEmpty &&
    message.length <= 200 &&
    !message.contains('\n') &&
    RegExp(r'[.?!]$').hasMatch(message) &&
    !_technical.hasMatch(message) &&
    !RegExp(r'\b(exit|error)\s+-?\d+\b').hasMatch(message);

/// A built-in Linux failure carries the app's sentence, or native text and
/// command output.
_Failure _builtin(BuiltinLinuxException error) {
  final message = error.message.trim();
  if (message.isEmpty) return _Failure.device;
  if (_builtinWordCodes.contains(error.code)) return _Failure.words;
  if (error.code == null && _isSentence(message)) return _Failure.words;
  return _forText(message) ?? _Failure.device;
}

/// A Termux bridge failure: the app's sentence (a setup check, a folder
/// name), or Termux's own output and native text.
_Failure _termux(TermuxBridgeException error) {
  final message = error.message.trim();
  if (error.code != 'command_failed' && _isSentence(message)) {
    return _Failure.words;
  }
  return _forText(message) ?? _Failure.termux;
}

_Failure _classify(Object error) {
  if (error is BuiltinLinuxException) return _builtin(error);
  if (error is TermuxBridgeException) return _termux(error);
  if (error is LocalServerControlFailure) {
    final message = error.message.trim();
    if (message.isEmpty) return _Failure.termux;
    if (_isSentence(message)) return _Failure.words;
    return _forText(message) ?? _Failure.termux;
  }
  if (error is LocalAgentFailure) {
    final message = error.message.trim();
    if (_isSentence(message)) return _Failure.words;
    return _forText(message) ?? _Failure.termux;
  }
  if (error is FolderListException) {
    return switch (error.problem) {
      FolderListProblem.timedOut => _Failure.timedOut,
      FolderListProblem.invalid || FolderListProblem.failed => _Failure.storage,
      _ => _Failure.words,
    };
  }
  if (error is ProductException ||
      error is McpOAuthCallbackException ||
      error is SecureStorageUnavailable) {
    return _Failure.words;
  }
  if (error is ApiException) {
    // The app's own sentence for a staged revert (connection, gateway).
    if (error.errorTag == 'SessionRevertPending') return _Failure.words;
    final code = error.statusCode;
    if (code != null && code >= 400) return _forStatus(code);
    return _forText(error.message) ?? _Failure.unexpected;
  }
  if (error is Api2NetworkError) {
    return error.timedOut ? _Failure.timedOut : _Failure.network;
  }
  if (error is Api2Error) {
    final code = error.statusCode;
    if (code != null && code >= 400) return _forStatus(code);
    return _forText(error.message) ?? _Failure.unexpected;
  }
  if (error is PlatformException) return _Failure.device;
  if (error is TimeoutException) return _Failure.timedOut;
  final type = error.runtimeType.toString();
  if (_storageTypes.contains(type)) return _Failure.storage;
  if (type == 'HandshakeException' || type == 'TlsException') {
    return _Failure.certificate;
  }
  if (KitErrorKind.of(error) == KitErrorKind.network) return _Failure.network;
  if (error is String) {
    if (error.trim().isEmpty) return _Failure.unknown;
    if (!_technical.hasMatch(error)) return _Failure.words;
    return _forText(error) ?? _Failure.unknown;
  }
  return _Failure.unknown;
}

/// The server's own reason for refusing a request (400 or 422), when it
/// is a short sentence for people ("Invalid option for form field: env")
/// rather than a body, a class name or transport text.
String? _rejectedReason(Object error) {
  final (message, code) = switch (error) {
    ApiException(:final message, :final statusCode) => (message, statusCode),
    Api2Error(:final message, :final statusCode) => (message, statusCode),
    _ => (null, null),
  };
  if (message == null || (code != 400 && code != 422)) return null;
  final marker = RegExp(r'\(HTTP \d{3}\):\s*').firstMatch(message);
  final reason = (marker == null ? message : message.substring(marker.end))
      .trim();
  if (reason.isEmpty ||
      reason.length > 160 ||
      reason.contains('\n') ||
      _technical.hasMatch(reason) ||
      reason.contains(RegExp(r'\bfailed\b', caseSensitive: false))) {
    return null;
  }
  return reason;
}

int? _statusOf(Object error) => switch (error) {
  ApiException(:final statusCode) => statusCode,
  Api2Error(:final statusCode) => statusCode,
  final String text => int.tryParse(
    _httpStatus.firstMatch(text)?.group(1) ?? '',
  ),
  _ => null,
};

/// Plain words, in the app's voice, for why something failed: safe to show
/// as a state's body, a notice's message or an alert's body.
///
/// Words, never exception text: a thrown object is classified and the kind
/// is said in words (no connection, timed out, certificate, sign-in refused,
/// not found, changed meanwhile, busy, server problem with its status code,
/// a device or storage failure). The raw text goes to [productErrorDetails],
/// for the Details fold.
///
/// - [ProductException], [McpOAuthCallbackException] and
///   [SecureStorageUnavailable] carry sentences the app wrote for people and
///   pass through unchanged.
/// - [ApiException] and [Api2Error] never pass their message through: their
///   status code (or transport cause) picks the words.
/// - A [PlatformException] is "something on this device didn't work"; its
///   native text is details only.
/// - A [String] is treated as words unless it reads as exception or
///   transport text (a class name, an HTTP status, an OS error, a body), in
///   which case it is classified like a thrown object.
/// - Everything else collapses to the generic connectivity line.
///
/// The caller's title names what failed ("Couldn't load older
/// conversations"); these words say why and what to do.
String productErrorText(Object error, {AppLocalizations? l10n}) {
  final copy = l10n ?? lookupAppLocalizations(const Locale('en'));
  final failure = _classify(error);
  return switch (failure) {
    _Failure.words => switch (error) {
      ProductException(:final message) => message,
      McpOAuthCallbackException(:final message) => message,
      SecureStorageUnavailable(:final message) => message,
      BuiltinLinuxException(:final message) => message.trim(),
      TermuxBridgeException(:final message) => message.trim(),
      LocalAgentFailure(:final message) => message.trim(),
      LocalServerControlFailure(:final message) => message.trim(),
      FolderListException(:final problem) => switch (problem) {
        FolderListProblem.notInstalled => copy.folderBrowserErrorNotInstalled,
        FolderListProblem.missing => copy.folderBrowserErrorMissing,
        FolderListProblem.denied => copy.folderBrowserErrorDenied,
        FolderListProblem.linked => copy.folderBrowserErrorLinked,
        _ => copy.productErrorStorage,
      },
      ApiException(:final message) => message,
      final String text => text,
      _ => copy.e7SharedOpenCodeUnreachableTryAgain,
    },
    _Failure.network => copy.e7SharedOpenCodeUnreachableTryAgain,
    _Failure.timedOut => copy.productErrorTimedOut,
    _Failure.certificate => copy.productErrorCertificate,
    _Failure.signIn => copy.productErrorSignIn,
    _Failure.notFound => copy.productErrorNotFound,
    _Failure.conflict => copy.productErrorConflict,
    _Failure.busy => copy.productErrorBusy,
    _Failure.server => copy.productErrorServer(_statusOf(error) ?? 500),
    _Failure.rejected => switch (_rejectedReason(error)) {
      final reason? => copy.productErrorRejectedBecause(reason),
      null => copy.productErrorRejected,
    },
    _Failure.unexpected => copy.productErrorUnexpected,
    _Failure.device => copy.productErrorDevice,
    _Failure.storage => copy.productErrorStorage,
    _Failure.termux => copy.productErrorTermux,
    _Failure.unknown => copy.e7SharedOpenCodeUnreachableTryAgain,
  };
}

/// Whether [error] is a failure to reach the server at all, so a state
/// offers the network fix (Switch server) first: the kit's own
/// classification plus the app's transport failures ([ApiException] with a
/// transport cause, [Api2NetworkError]).
KitErrorKind productErrorKind(Object? error) {
  if (error == null) return KitErrorKind.other;
  return switch (_classify(error)) {
    _Failure.network || _Failure.timedOut => KitErrorKind.network,
    _ => KitErrorKind.of(error),
  };
}

/// The technical text behind [error], redacted, for a Details fold, Copy
/// details or a report; never for the headline or the body. Null when
/// there is nothing beyond the words [productErrorText] already says.
String? productErrorDetails(Object? error) {
  final String raw;
  switch (error) {
    case null:
      return null;
    case ProductException(:final cause):
      if (cause == null) return null;
      raw = '$cause';
    case SecureStorageUnavailable(:final cause):
      if (cause == null) return null;
      raw = '$cause';
    case McpOAuthCallbackException():
      return null;
    case BuiltinLinuxException(:final message, :final code):
      if (_builtin(error) == _Failure.words) return null;
      raw = [message, ?code].join('\n');
    case TermuxBridgeException(:final message, :final code):
      if (_termux(error) == _Failure.words) return null;
      raw = '$message\n$code';
    case LocalServerControlFailure(:final message):
      if (_classify(error) == _Failure.words) return null;
      raw = message;
    case LocalAgentFailure(:final message, :final kind):
      if (_classify(error) == _Failure.words) return null;
      raw = '$message\n${kind.name}';
    case FolderListException(:final problem, :final detail):
      raw = detail.isEmpty ? problem.name : detail;
    case ApiException(:final message, :final statusCode, :final errorTag):
      raw = [
        message,
        if (statusCode != null && !message.contains('$statusCode'))
          'HTTP $statusCode',
        ?errorTag,
      ].join('\n');
    case PlatformException(:final code, :final message, :final details):
      raw = [
        'PlatformException($code)',
        ?message,
        if (details != null) '$details',
      ].join('\n');
    case final String text:
      if (_classify(text) == _Failure.words) return null;
      raw = text;
    default:
      raw = '${error.runtimeType}: $error';
  }
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : KitRedact.text(trimmed);
}

/// Tells the person that an act they just started failed.
///
/// A snackbar is only ever done-with-undo (KIT-34), so a failure with no
/// part of its own to sit on is a blocking alert (kit-v2 §4.8): [title]
/// (default "Couldn't finish that"; better, what failed) and the thrown
/// object in words through [productErrorText], so raw exceptions never
/// reach users. The technical text ([productErrorDetails]) is folded under
/// "Error details", redacted. Returns at once; the alert closes on Close,
/// back or Esc.
void showProductError(BuildContext context, Object error, {String? title}) {
  final l10n = _copy(context);
  final details = productErrorDetails(error);
  unawaited(
    showKitAlert(
      context,
      title: title ?? l10n.productStatesActionFailedTitle,
      body: productErrorText(error, l10n: l10n),
      details: [
        if (details != null)
          KitTechnicalValue(l10n.productErrorDetailsLabel, details),
      ],
      icon: AppIconography.error,
      alertKey: const ValueKey('product-error-alert'),
    ),
  );
}

/// Keeps cached content mounted while a refresh failure offers a retry.
///
/// The failure is a [KitNotice.error] that unfolds over the kept content and
/// folds away once a retry works (design standard §10), instead of pushing
/// the list down in one frame.
class ProductRefreshBody extends StatelessWidget {
  const ProductRefreshBody({
    super.key,
    required this.message,
    required this.onRetry,
    required this.child,
    this.error,
  });

  /// The failure in words ([productErrorText]), never exception text.
  final String? message;
  final VoidCallback onRetry;
  final Widget child;

  /// The thrown object, when kept: classified for the network fix and its
  /// technical text offered through Copy details, never shown as words.
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final tokens = KitTokens.of(context);
    final message = this.message;
    return Column(
      children: [
        KitReveal(
          child: message == null
              ? null
              : Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    tokens.gutter,
                    tokens.space2,
                    tokens.gutter,
                    tokens.space2,
                  ),
                  child: KitNotice.error(
                    key: const ValueKey('product-refresh-failed'),
                    title: l10n.refreshFailed,
                    message: message,
                    error: error,
                    errorKind: error == null ? null : productErrorKind(error),
                    details: productErrorDetails(error),
                    retry: KitAction(
                      label: l10n.refreshRetry,
                      onPressed: onRetry,
                    ),
                  ),
                ),
        ),
        Expanded(key: const ValueKey('refresh-content'), child: child),
      ],
    );
  }
}

/// A first load with nothing to show yet: the kit's skeleton rows, in a
/// scroll view that always scrolls so pull-to-refresh still works.
class LoadingList extends StatelessWidget {
  final int rows;
  const LoadingList({super.key, this.rows = 5});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsetsDirectional.only(top: KitTokens.of(context).space2),
      children: [KitSkeletonRows(count: rows)],
    );
  }
}

/// A whole page with nothing in it: a [KitStateView] of page size (icon
/// tile, title, message, the one action). With [scrollable] (the default)
/// it fills its parent and always scrolls, so pull-to-refresh still works;
/// without it, it is the inline form for a parent that scrolls itself.
class ProductEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool scrollable;

  const ProductEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    KitStateView state(KitStateSize size) => KitStateView(
      icon: icon,
      title: title,
      body: message,
      size: size,
      primary: label != null && onAction != null
          ? KitAction(label: label, onPressed: onAction)
          : null,
    );
    return scrollable ? _adaptiveState(state) : state(KitStateSize.inline);
  }
}

/// A page that could not load: a [KitStateView] in the failure tone with a
/// title that says what failed, the cause in words, and the fix.
///
/// - [message] is the cause in words (usually [productErrorText]); it is
///   the body, never the title. Words, not exception text: never
///   `'$error'`, `error.toString()` or an [ApiException]'s message.
/// - [title] names what failed ("Couldn't load files"); by default
///   "Couldn't load this", or "Can't reach the server" for a network error.
/// - [error] is only classified ([productErrorKind]) and never shown;
///   [errorKind] overrides the classification. When [details] is not given,
///   the fold holds [productErrorDetails] of [error].
/// - A network error offers Try again and Switch server ([onSwitchServer],
///   by default the server list) and no Report: the fix comes first
///   (STATE-3). Any other error offers Try again and "Report a problem",
///   which opens Report a problem with this failure attached.
/// - [details] is raw technical text: folded under Details, redacted, with
///   "Copy details".
class ProductErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  final String? title;
  final Object? error;
  final KitErrorKind? errorKind;
  final String? details;
  final VoidCallback? onSwitchServer;

  const ProductErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.title,
    this.error,
    this.errorKind,
    this.details,
    this.onSwitchServer,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final network =
        (errorKind ?? productErrorKind(error)) == KitErrorKind.network;
    final details = this.details ?? productErrorDetails(error);
    return _adaptiveState(
      (size) => _build(context, l10n, network: network, details: details, size),
    );
  }

  Widget _build(
    BuildContext context,
    AppLocalizations l10n,
    KitStateSize size, {
    required bool network,
    required String? details,
  }) {
    return KitStateView(
      key: const ValueKey('product-error-state'),
      size: size,
      icon: network ? AppIconography.server : AppIconography.error,
      tone: AppStatusTone.failure,
      title:
          title ??
          (network
              ? l10n.productStatesNetworkErrorTitle
              : l10n.productStatesErrorTitle),
      body: message,
      primary: KitAction(
        key: const ValueKey('product-error-retry'),
        label: l10n.refreshRetry,
        onPressed: () => unawaited(onRetry()),
      ),
      secondary: network
          ? KitAction(
              key: const ValueKey('product-error-switch-server'),
              label: l10n.productStatesSwitchServer,
              icon: AppIconography.server,
              onPressed:
                  onSwitchServer ??
                  () => unawaited(Navigator.of(context).pushNamed('/servers')),
            )
          : null,
      tertiary: [
        // Where a failure is found is where it is reported, one
        // implementation for every page that embeds this state. Not for a
        // network error: that is fixed, not reported (STATE-3).
        if (!network)
          KitAction(
            key: const ValueKey('product-error-report-bug'),
            label: l10n.e7LibraryReportABug,
            icon: AppIconography.bug,
            // The failure goes with the report: its title, the cause and
            // the redacted details, never the raw error (P8.2).
            onPressed: () => unawaited(
              openBugReport(
                context,
                error: KitReport(
                  title: title ?? l10n.productStatesErrorTitle,
                  details: KitReportHook.redact(
                    [message, ?details].join('\n\n'),
                  ),
                  errorType: error?.runtimeType.toString(),
                ),
              ),
            ),
          ),
        if (details != null)
          KitAction.copy(
            key: const ValueKey('product-error-copy-details'),
            label: l10n.kitCopyDetails,
            text: () => KitReportHook.redact(details),
          ),
      ],
      details: details,
    );
  }
}

/// A compact empty state for one section of a longer scrolling surface,
/// where the page-size [ProductEmptyState] is too tall: the inline
/// [KitStateView].
class ProductInlineEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ProductInlineEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    return KitStateView(
      icon: icon,
      title: title,
      body: message,
      size: KitStateSize.inline,
      primary: label != null && onAction != null
          ? KitAction(label: label, onPressed: onAction)
          : null,
    );
  }
}

/// The one explainer row for a feature the connected server cannot do: a
/// [KitRow.unavailable] (kit-v2 §2.5, STATE-12).
///
/// Settings are where users go looking for a thing they remember, so a
/// vanished row reads as a bug (`docs/opencode2-ui-design.md` §7, rule 2).
/// The row keeps the title it would have had, dimmed through the theme's
/// muted text (never an `Opacity`), with the [explainer] as its reason.
/// Capability gating, not plan gating — no upsell styling, no call to
/// action.
///
/// Menu actions, nav destinations and More-grid tiles are *hidden* instead;
/// this widget is only for surviving settings/health surfaces.
class GatedRow extends StatelessWidget {
  /// Feature id; the row's key is `gated-<feature>`.
  final String feature;

  /// The title the enabled row would have carried.
  final String title;

  /// One honest line saying why the row is dead, e.g.
  /// "Not available on OpenCode 2 servers".
  final String explainer;

  final Widget? leading;

  /// Server generation the feature needs: 1 for v1-only features (the usual
  /// case), 2 for the rare v2-only row we choose to show. Spoken with the
  /// row, so a screen reader hears which server it needs.
  final int requiresGeneration;

  const GatedRow({
    super.key,
    required this.feature,
    required this.title,
    required this.explainer,
    this.leading,
    this.requiresGeneration = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      hint: _copy(context).productStatesRequiresServer(requiresGeneration),
      child: KitRow.unavailable(
        key: ValueKey('gated-$feature'),
        title: title,
        reason: explainer,
        leading: leading,
      ),
    );
  }
}

/// [GatedRow] under its old name for callers that embedded the tap-to-explain
/// variant. The reason line already says which server the feature needs, so
/// the tap snackbar is gone (a snackbar is only for Undo, KIT-34); the row is
/// the same [GatedRow].
class GatedRowTile extends StatelessWidget {
  final String feature;
  final String title;
  final String explainer;
  final Widget? leading;
  final int requiresGeneration;

  const GatedRowTile({
    super.key,
    required this.feature,
    required this.title,
    required this.explainer,
    this.leading,
    this.requiresGeneration = 1,
  });

  @override
  Widget build(BuildContext context) => GatedRow(
    feature: feature,
    title: title,
    explainer: explainer,
    leading: leading,
    requiresGeneration: requiresGeneration,
  );
}

/// The stock explainer for a v1 feature with no OpenCode 2 endpoint.
const String gatedOnV2Explainer = 'Not available on OpenCode 2 servers';

/// A section's name above its rows: the kit's `label` text role (visual
/// language §2, never uppercase) on the rails a [KitRowGroup] label uses,
/// 22 dp after the previous section and 8 dp above its panel (§4).
class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  /// Overrides the list-level inset for surfaces that already pad their own
  /// content — sheets and cards — so those can reuse this label instead of
  /// hand-rolling the same section caption.
  final EdgeInsetsGeometry? padding;

  final bool _inline;

  const SectionLabel(this.text, {super.key, this.trailing, this.padding})
    : _inline = false;

  /// The same label with no inset of its own, for already-padded contexts.
  const SectionLabel.inline(this.text, {super.key, this.trailing})
    : padding = null,
      _inline = true;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final label = Semantics(
      header: true,
      child: KitText(text, role: KitTextRole.label),
    );
    final trailing = this.trailing;
    return Padding(
      padding:
          padding ??
          (_inline
              ? EdgeInsetsDirectional.only(bottom: tokens.labelGap)
              : EdgeInsetsDirectional.fromSTEB(
                  tokens.gutter,
                  tokens.sectionGap,
                  tokens.gutter,
                  tokens.labelGap,
                )),
      child: trailing == null
          ? label
          // A Wrap, not a Row: when the caption and its status do not fit
          // on one line at large text scales, the status drops under the
          // caption instead of overflowing the edge.
          : Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: tokens.space2,
              runSpacing: tokens.space1 / 2,
              children: [label, trailing],
            ),
    );
  }
}
