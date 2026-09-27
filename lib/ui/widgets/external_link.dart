import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../app_iconography.dart';
import '../kit/kit_buttons.dart';
import '../kit/kit_copy.dart';
import '../kit/kit_redact.dart';
import '../kit/kit_dialog.dart';
import '../kit/kit_sheet.dart' show KitConfirmKind, showKitConfirm;
import '../kit/kit_technical_value.dart';
import 'product_states.dart';

/// What [openExternalLink] did, so callers can react without re-deriving it.
enum ExternalLinkOutcome {
  /// The URL failed the policy below and was never handed to the platform.
  blocked,

  /// The URL was allowed but the user declined the confirmation (or copied
  /// the link instead of opening it).
  cancelled,

  /// Handed to the platform and accepted.
  opened,

  /// Handed to the platform, which had no app for it.
  noHandler,

  /// The platform threw while opening it.
  failed,
}

/// Hard ceiling on a link this app will even consider. A server can put an
/// arbitrarily long string in a markdown link or a form field, and neither the
/// confirmation dialog nor the platform intent should have to carry it.
const _maxExternalLinkLength = 2048;

/// The single gate every URL the app did not author must pass before it can
/// reach the platform launcher — markdown links in agent output, OpenCode 2
/// external form fields, update notices, and anything added later.
///
/// The policy is deliberately narrow, because the source is a server that may
/// be malicious or compromised:
///
/// - only `https:` opens directly;
/// - `http:` opens only after a separate, explicitly insecure confirmation;
/// - every other scheme is refused — `intent:`, `file:`, `content:`,
///   `javascript:`, `data:`, and any app-private scheme, none of which the
///   user can evaluate from a link label;
/// - embedded credentials (`https://user:pass@host`) are refused, because they
///   move secrets into browser history and make the host unreadable;
/// - a host is required, so opaque URLs cannot slip through;
/// - the effective destination host is shown before anything opens.
///
/// Every answer is a kit modal ([showKitConfirm], [showKitAlert]); a
/// snackbar is only ever done-with-undo (KIT-34).
///
/// [launcher] exists for tests; production goes to `url_launcher`.
Future<ExternalLinkOutcome> openExternalLink(
  BuildContext context,
  String? value, {
  Future<bool> Function(Uri uri)? launcher,
}) async {
  final copy = _sharedCopy(context);
  final uri = safeExternalLinkUri(value);
  if (uri == null) {
    // Blocked is the answer to the person's tap, so it is said in a
    // blocking alert; the outcome returns at once. The refused value is not
    // echoed: it may be long, hostile or unreadable.
    if (context.mounted) {
      unawaited(
        showKitAlert(
          context,
          title: copy.externalLinkBlockedTitle,
          body: copy.externalLinkBlockedBody,
          icon: AppIconography.locked,
          alertKey: const ValueKey('external-link-blocked'),
        ),
      );
    }
    return ExternalLinkOutcome.blocked;
  }
  final insecure = uri.scheme == 'http';
  final address = uri.toString();
  final safeAddress = KitRedact.text(address);

  // The destination host stays in sight (not folded under Details): it is
  // what the person checks before anything opens. The whole address is one
  // tap away under Details, and "Copy link" uses it without leaving the
  // app. On http the risky choice is the error-toned one, Enter never
  // confirms it (KitConfirmKind.destructive), and "Don't open" is the way
  // back.
  if (!context.mounted) return ExternalLinkOutcome.cancelled;
  final confirmed = await showKitConfirm(
    context,
    title: insecure
        ? copy.e7SharedOpenInsecureHTTPLink
        : copy.e7SharedOpenExternalLink,
    body: copy.externalLinkOpensHost(KitRedact.text(externalLinkHost(uri))),
    confirmLabel: insecure ? copy.e7SharedOpenHTTPLink : copy.e7SharedOpenLink,
    kind: insecure ? KitConfirmKind.destructive : KitConfirmKind.neutral,
    cancelLabel: insecure ? copy.externalLinkDontOpen : null,
    icon: insecure ? AppIconography.warning : AppIconography.externalLink,
    consequences: [if (insecure) copy.e7SharedHTTPIsNotEncryptedOtherDevicesOn],
    alternative: KitAction(
      key: const ValueKey('external-link-copy'),
      label: copy.externalLinkCopy,
      icon: AppIconography.copy,
      onPressed: () {
        // Untrusted links may contain credentials. The approved launcher
        // alone receives the original URI; display and clipboard stay masked.
        if (context.mounted) {
          unawaited(KitCopy.copy(context, safeAddress));
        }
      },
    ),
    details: [KitTechnicalValue(copy.externalLinkAddress, safeAddress)],
    sheetKey: const ValueKey('external-link-confirm'),
  );
  if (!confirmed) return ExternalLinkOutcome.cancelled;
  if (!context.mounted) return ExternalLinkOutcome.cancelled;

  try {
    final opened =
        await (launcher?.call(uri) ??
            launchUrl(uri, mode: LaunchMode.externalApplication));
    if (opened) return ExternalLinkOutcome.opened;
    if (context.mounted) {
      unawaited(
        showKitAlert(
          context,
          title: copy.externalLinkOpenFailedTitle,
          body: copy.e7SharedNoAppCouldOpenThisLink,
          icon: AppIconography.externalLink,
          details: [KitTechnicalValue(copy.externalLinkAddress, safeAddress)],
          alertKey: const ValueKey('external-link-no-app'),
        ),
      );
    }
    return ExternalLinkOutcome.noHandler;
  } catch (error) {
    if (context.mounted) {
      unawaited(
        showKitAlert(
          context,
          title: copy.externalLinkOpenFailedTitle,
          body: productErrorText(error, l10n: copy),
          icon: AppIconography.error,
          details: [KitTechnicalValue(copy.externalLinkAddress, safeAddress)],
          alertKey: const ValueKey('external-link-failed'),
        ),
      );
    }
    return ExternalLinkOutcome.failed;
  }
}

/// The parsed URL when [value] passes the policy documented on
/// [openExternalLink], otherwise null. Surfaces can call this to describe the
/// destination — or to withhold the affordance entirely — without duplicating
/// the rules.
Uri? safeExternalLinkUri(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > _maxExternalLinkLength) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'http') return null;
  if (uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
  // Normalize the scheme so `HTTPS://` cannot present itself as something the
  // policy never inspected.
  return uri.scheme == scheme ? uri : uri.replace(scheme: scheme);
}

/// `example.com`, or `example.com:8443` when the URL names a port — what the
/// user is asked to approve.
String externalLinkHost(Uri uri) =>
    uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;

AppLocalizations _sharedCopy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));
