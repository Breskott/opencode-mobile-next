import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;

import '../../api/mcp_oauth.dart' show McpOAuthCallbackException;
import '../../api/opencode_api.dart';
import '../../api/product_repository.dart';
import '../../feedback/bug_report.dart';
import '../../l10n/app_localizations.dart';
import '../../state/profiles.dart' show SecureStorageUnavailable;
import '../app_theme.dart';
import '../kit/kit_buttons.dart';
import '../kit/kit_dialog.dart';
import '../kit/kit_layout.dart';
import '../kit/kit_notice.dart';
import '../kit/kit_progress.dart';
import '../kit/kit_row.dart';
import '../kit/kit_state_view.dart';
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

/// Maps any thrown object onto copy that is safe to show users.
///
/// - [ProductException], [ApiException], and [McpOAuthCallbackException]
///   carry product-facing messages and pass through unchanged.
/// - [SecureStorageUnavailable] names the missing keyring; any other
///   [PlatformException] is a device-side failure, so its own message is
///   shown rather than blaming the server.
/// - A [String] is treated as already-composed product copy.
/// - Everything else — [StateError]s, socket/transport failures, and other
///   internals — collapses to one generic connectivity line instead of leaking
///   `Bad state:` prefixes or raw exception dumps.
String productErrorText(Object error, {AppLocalizations? l10n}) {
  if (error is ProductException) return error.message;
  if (error is ApiException) return error.message;
  if (error is McpOAuthCallbackException) return error.message;
  if (error is SecureStorageUnavailable) return error.message;
  if (error is PlatformException) {
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) return message;
    return l10n?.e7SharedDeviceReportedError(error.code) ??
        'This device reported an error (${error.code}).';
  }
  if (error is String && error.trim().isNotEmpty) return error;
  return l10n?.e7SharedOpenCodeUnreachableTryAgain ??
      'OpenCode is unreachable. Try again.';
}

/// Tells the person that an act they just started failed.
///
/// A snackbar is only ever done-with-undo (KIT-34), so a failure with no
/// part of its own to sit on is a blocking alert (kit-v2 §4.8): [title]
/// (default "Couldn't finish that") and the thrown object routed through
/// [productErrorText], so raw exceptions never reach users. Returns at once;
/// the alert closes on Close, back or Esc.
void showProductError(BuildContext context, Object error, {String? title}) {
  final l10n = _copy(context);
  unawaited(
    showKitAlert(
      context,
      title: title ?? l10n.productStatesActionFailedTitle,
      body: productErrorText(error, l10n: l10n),
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
  });

  final String? message;
  final VoidCallback onRetry;
  final Widget child;

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
///   the body, never the title.
/// - [title] names what failed ("Couldn't load files"); by default
///   "Couldn't load this", or "Can't reach the server" for a network error.
/// - [error] is only classified ([KitErrorKind.of]) and never shown;
///   [errorKind] overrides the classification.
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
        (errorKind ?? KitErrorKind.of(error)) == KitErrorKind.network;
    final details = this.details;
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
