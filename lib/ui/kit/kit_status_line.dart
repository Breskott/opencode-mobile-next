import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import 'kit_buttons.dart';
import 'kit_icon.dart';
import 'kit_icon_button.dart';
import 'kit_menu.dart';
import 'kit_since.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';
import 'motion/kit_motion_parts.dart';
import 'motion/kit_reveal.dart';

/// Which condition a status is, in priority order, highest first (KIT-35;
/// `work` placed below the shell conditions and above updates, so a team's
/// Now line is never hidden by "Update ready", which STATE-19 calls the
/// lowest condition).
enum KitStatusKind {
  /// Offline, reconnecting, not answering.
  connection,

  /// Android stopped the app; background checks paused.
  appStopped,

  /// The phone is hot; the team is paused.
  heat,

  /// A risky switch is on for this screen (KitSwitchRow.risk). Never
  /// dismissible (SEC-9).
  riskySwitch,

  /// A working screen's own line: the team Now line, a live process.
  work,

  /// An app, code-push or server update is ready (STATE-19).
  update,

  /// Anything else a screen shows (a search summary, a counter).
  info,
}

/// One condition, produced by the one status source for its entity
/// (ARCH-8): the words are decided there, once; screens pass this object,
/// not strings, and render it with [KitStatusLine.of].
@immutable
class KitStatus {
  const KitStatus({
    required this.kind,
    required this.icon,
    required this.message,
    this.id,
    this.key,
    this.messageKey,
    this.supportingKey,
    this.dismissTooltip,
    this.tone = AppStatusTone.neutral,
    this.supporting,
    this.next,
    this.action,
    this.more = const [],
    this.since,
    this.onSlow = const [],
    this.onDismiss,
  }) : assert(
         kind != KitStatusKind.riskySwitch || onDismiss == null,
         'A risky switch line is never dismissible: hiding it would hide a '
         'live risk (SEC-9). Offer its "Turn off" as the action instead.',
       );

  final KitStatusKind kind;

  /// Stable identity for dedupe and announcements: `connection:<profileId>`.
  final String? id;
  final Key? key;
  final Key? messageKey;
  final Key? supportingKey;
  final String? dismissTooltip;
  final IconData icon;

  /// "Reconnecting to laptop…"
  final String message;
  final AppStatusTone tone;
  final String? supporting;

  /// The Now line: "Working on the login fix · a reviewer checks it next ·
  /// about 6 min".
  final String? next;
  final KitAction? action;
  final List<KitAction> more;

  /// When the wait began; the line escalates after
  /// [KitMotion.escalateAfter].
  final DateTime? since;

  /// At most two ways out, offered once the wait turned slow.
  final List<KitAction> onSlow;
  final VoidCallback? onDismiss;

  /// Lower is more important ([kind]'s index).
  int get priority => kind.index;

  /// The same condition as one line: the words and More, with the action
  /// folded into More (first) and no supporting, Now or slow line. For a
  /// page about something else (the phone's own setup under a saved
  /// server's connection problem, B6): the truth stays on screen, its ways
  /// out one tap away, without pushing every step of the page down.
  KitStatus compact() {
    final action = this.action;
    return KitStatus(
      kind: kind,
      icon: icon,
      message: message,
      id: id,
      key: key,
      messageKey: messageKey,
      dismissTooltip: dismissTooltip,
      tone: tone,
      more: [?action, ...more],
      onDismiss: onDismiss,
    );
  }

  /// The one status to show among [statuses] (nulls ignored): the lowest
  /// [priority] value; ties keep the first. Used by `KitStatusLineSlot`.
  static KitStatus? highest(Iterable<KitStatus?> statuses) {
    KitStatus? best;
    for (final status in statuses) {
      if (status == null) continue;
      if (best == null || status.priority < best.priority) best = status;
    }
    return best;
  }
}

/// A condition on an otherwise working screen (design standard §5):
/// offline or reconnecting, Android stopped the app, heat, a risky switch
/// that is on, an update ready, or the team's Now line. One row: an icon,
/// the words, an optional action, and further actions behind a small menu.
/// At most one per window (`KitStatusLineSlot` picks it with
/// [KitStatus.highest]), not a card. It replaces every `MaterialBanner` and
/// the update and release snackbars.
///
/// States: condition, working, slow, now-line, error (+ disabled action).
///
/// - working (`tone: progress`): the icon in `accent`; no spinner. Give such
///   a line a [since], or its wait runs silently past 8 s (STATE-5).
/// - slow: [KitMotion.escalateAfter] after [since] the supporting line reads
///   "Still waiting after 8 s", and the first [onSlow] action takes the
///   action slot when it is empty (otherwise the [onSlow] actions go first
///   in More). Announced once.
/// - now-line: [next] under the message in `text2`; it unfolds when it first
///   appears and cross-fades when it changes.
/// - error (`tone: failure`): the neutral glyph in `text1` (LOOK-5); the
///   action is the fix ("Try again").
/// - disabled action: its `disabledReason` shows under the line; the line
///   itself is never disabled.
///
/// Accessibility: one live region, holding the message (and the slow
/// words once escalated). A change of the message or the escalation is
/// announced once; a new [supporting] or [next] (a time counting down) is
/// not re-announced.
///
/// Motion (§10): it fades and rises into place when it appears and again
/// when it becomes a different condition (its icon or tone changes); new
/// words for the same condition change in place. To have it fold away when
/// it goes, the host shows it through a [KitReveal]. Reduced motion:
/// instant. Haptics: none.
class KitStatusLine extends StatelessWidget {
  const KitStatusLine({
    super.key,
    required this.icon,
    required this.message,
    this.tone = AppStatusTone.neutral,
    this.action,
    this.more = const [],
    this.onDismiss,
    this.messageKey,
    this.dismissKey,
    this.dismissTooltip,
    this.controlsTogether = false,
    this.supporting,
    this.supportingKey,
    this.supportingSemanticsLabel,
    this.next,
    this.nextKey,
    this.since,
    this.onSlow = const [],
    this.moreKey,
  });

  /// Renders [status] from its entity's status source (ARCH-8). Its key
  /// defaults to `ValueKey('kit-status-<id or kind>')`, so a new condition is
  /// a new line (and a new announcement).
  factory KitStatusLine.of(KitStatus status, {Key? key, Key? messageKey}) =>
      KitStatusLine(
        key:
            key ??
            status.key ??
            ValueKey('kit-status-${status.id ?? status.kind.name}'),
        icon: status.icon,
        message: status.message,
        tone: status.tone,
        action: status.action,
        more: status.more,
        onDismiss: status.onDismiss,
        messageKey: messageKey ?? status.messageKey,
        supportingKey: status.supportingKey,
        dismissTooltip: status.dismissTooltip,
        supporting: status.supporting,
        next: status.next,
        since: status.since,
        onSlow: status.onSlow,
      );

  final IconData icon;
  final String message;
  final AppStatusTone tone;
  final KitAction? action;

  /// Other ways out, in a compact menu after [action].
  final List<KitAction> more;

  /// Only when dismissing changes nothing real (§5).
  final VoidCallback? onDismiss;
  final Key? messageKey;

  /// The close button's key and tooltip, when the caller names them.
  final Key? dismissKey;
  final String? dismissTooltip;

  /// When the line stacks (large text), keep the action, More and close on
  /// one row under the words instead of leaving close at the top: a
  /// height-limited slot that scrolls to its end then shows every control
  /// together (a one-time tip above the composer).
  final bool controlsTogether;

  /// Optional: one short muted sentence under [message], for what to do
  /// next ("Send it again") or a fact that belongs to the same condition
  /// ("2 drafts will send when connected"). Never the raw error: that goes
  /// behind a Details action.
  final String? supporting;
  final Key? supportingKey;

  /// What a screen reader says for [supporting] when its words alone would
  /// not (a bare link: "Shared conversation link …").
  final String? supportingSemanticsLabel;

  /// The Now line, under the message in `text2`: "Working on the login fix ·
  /// a reviewer checks it next · about 6 min".
  final String? next;
  final Key? nextKey;

  /// When the wait began, on this phone's clock. The line escalates
  /// [KitMotion.escalateAfter] later (see the class's slow state).
  final DateTime? since;

  /// At most two ways out after the escalation ("Retry", "Leave it
  /// running").
  final List<KitAction> onSlow;

  /// The More button's key; default `ValueKey('kit-status-more')`.
  final Key? moreKey;

  static const _defaultMoreKey = ValueKey('kit-status-more');
  static const _defaultDismissKey = ValueKey('kit-status-dismiss');

  @override
  Widget build(BuildContext context) {
    assert(
      onSlow.length <= 2,
      'KitStatusLine.onSlow offers at most two ways out (got '
      '${onSlow.length}).',
    );
    return KitEntrance(
      trigger: (tone, icon),
      child: KitSince(
        since: since,
        builder: (context, wait) => LayoutBuilder(
          builder: (context, constraints) {
            final slow = wait.isSlow;
            final firstSlow = slow && onSlow.isNotEmpty ? onSlow.first : null;
            final effectiveAction = action ?? firstSlow;
            final effectiveMore = !slow
                ? more
                : action == null
                ? [...onSlow.skip(1), ...more]
                : [...onSlow, ...more];
            return _line(
              context,
              slow: slow,
              action: effectiveAction,
              more: effectiveMore,
              stacked: _stacks(
                context,
                constraints.maxWidth,
                effectiveAction,
                effectiveMore,
              ),
            );
          },
        ),
      ),
    );
  }

  /// The action moves under the words when both do not fit on one line
  /// (long words, large text), instead of squeezing the words.
  bool _stacks(
    BuildContext context,
    double width,
    KitAction? action,
    List<KitAction> more,
  ) {
    if (action == null) return false;
    final tokens = KitTokens.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final result = painter.width;
      painter.dispose();
      return result;
    }

    final frame =
        tokens.gutter +
        tokens.iconSize(context, tokens.smallIconSize) +
        tokens.space3 +
        tokens.space1 +
        (more.isEmpty ? 0 : tokens.minTarget) +
        (onDismiss == null ? 0 : tokens.minTarget);
    final actionWidth =
        measure(action.label, KitText.styleOf(context, KitTextRole.button)) +
        2 * tokens.space2 +
        tokens.space1;
    final messageWidth = measure(
      message,
      KitText.styleOf(context, KitTextRole.body),
    );
    return messageWidth + actionWidth + frame > width;
  }

  Widget _icon(BuildContext context, KitTokens tokens, ThemeRoles roles) {
    final family = icon.fontFamily;
    if (family != null && family.startsWith('AppPhosphor')) {
      return KitIcon.status(tone, icon: icon);
    }
    // Compatibility for a glyph outside the app's set (a caller not yet on
    // AppIconography): KitIcon rejects it, so it is drawn plainly in the
    // neutral tone until the caller moves to an AppIconography verb.
    return Icon(
      icon,
      size: tokens.smallIconSize,
      color: KitText.toneColor(roles, KitTextTone.secondary),
    );
  }

  Widget _line(
    BuildContext context, {
    required bool slow,
    required KitAction? action,
    required List<KitAction> more,
    required bool stacked,
  }) {
    final theme = Theme.of(context);
    final roles = ThemeRoles.resolve(theme);
    final tokens = KitTokens.of(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final bodyStyle = KitText.styleOf(context, KitTextRole.body);
    final secondaryStyle = KitText.styleOf(context, KitTextRole.secondary);
    final dismiss = onDismiss;
    final moreMenu = more.isEmpty
        ? null
        : Builder(
            builder: (anchor) => KitIconButton(
              key: moreKey ?? _defaultMoreKey,
              icon: AppIconography.more,
              size: 20,
              tooltip: l10n.kitMore,
              onPressed: () => showKitMenu(
                anchor,
                items: [
                  for (final item in more)
                    KitMenuItem(
                      key: item.key,
                      label: item.label,
                      onSelected: () => item.onPressed?.call(),
                      enabled: item.onPressed != null,
                      destructive: item.destructive,
                      disabledReason: item.disabledReason,
                    ),
                ],
              ),
            ),
          );
    final dismissButton = dismiss == null
        ? null
        : KitIconButton(
            key: dismissKey ?? _defaultDismissKey,
            icon: AppIconography.close,
            size: 20,
            tooltip: dismissTooltip ?? l10n.kitSheetDismiss,
            onPressed: dismiss,
          );
    final slowLabel = KitSince.slowLabel(context);
    final announced = slow ? '$message\n$slowLabel' : message;
    final supporting = this.supporting;
    final Widget? supportingText = slow
        ? KeyedSubtree(
            key: const ValueKey('kit-status-slow'),
            // Already said by the live region above.
            child: ExcludeSemantics(
              child: Text(
                slowLabel,
                key: const ValueKey('kit-status-slow-text'),
                style: secondaryStyle,
              ),
            ),
          )
        : supporting == null
        ? null
        : KeyedSubtree(
            key: const ValueKey('kit-status-supporting'),
            child: Semantics(
              label: supportingSemanticsLabel,
              excludeSemantics: supportingSemanticsLabel != null,
              child: Text(
                supporting,
                key: supportingKey,
                style: secondaryStyle,
              ),
            ),
          );
    final next = this.next;
    final disabledReason = action == null || action.enabled
        ? null
        : action.disabledReason;
    final actionButton = action == null
        ? null
        : KitButton.fromAction(action, role: KitButtonRole.tertiary);
    // The icon lines up with the message's first line when the line stacks.
    final firstLine =
        MediaQuery.textScalerOf(context).scale(bodyStyle.fontSize ?? 16) *
        (bodyStyle.height ?? 1);
    // Stacked with the controls apart, More (and Dismiss) sit beside the
    // message while the action sits under it, inset towards the start: by
    // geometry alone a screen reader would read the action first (it
    // starts further left in the band More spans). Read the top row, then
    // the action under it (A11Y-4). The wrappers are always there (empty
    // otherwise) so a change of layout keeps the same elements.
    final ordered = stacked && !controlsTogether;
    Widget inOrder(double order, Widget child) => Semantics(
      container: ordered,
      sortKey: ordered ? OrdinalSortKey(order) : null,
      child: child,
    );
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: roles.hairline,
              width: KitTokens.hairlineWidth(context),
            ),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: KitTokens.statusLineMinHeight,
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: tokens.gutter,
              end: tokens.space1,
            ),
            child: Row(
              crossAxisAlignment: stacked
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: stacked
                      ? EdgeInsetsDirectional.only(top: tokens.space2)
                      : EdgeInsetsDirectional.zero,
                  child: SizedBox(
                    height: stacked ? firstLine : null,
                    child: Center(child: _icon(context, tokens, roles)),
                  ),
                ),
                SizedBox(width: tokens.space3),
                Expanded(
                  child: Padding(
                    padding: EdgeInsetsDirectional.symmetric(
                      vertical: tokens.space2,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          container: true,
                          sortKey: ordered ? const OrdinalSortKey(0) : null,
                          liveRegion: true,
                          label: announced,
                          excludeSemantics: true,
                          child: Text(
                            message,
                            key: messageKey,
                            style: bodyStyle,
                          ),
                        ),
                        if (supportingText != null)
                          Padding(
                            padding: EdgeInsetsDirectional.only(
                              top: tokens.space1,
                            ),
                            child: KitSwap(
                              alignment: AlignmentDirectional.topStart,
                              child: supportingText,
                            ),
                          ),
                        KitReveal(
                          child: next == null
                              ? null
                              : Padding(
                                  padding: EdgeInsetsDirectional.only(
                                    top: tokens.space1,
                                  ),
                                  child: KitSwap(
                                    pace: KitPace.standard,
                                    alignment: AlignmentDirectional.topStart,
                                    child: KeyedSubtree(
                                      key: ValueKey(next),
                                      child: Text(
                                        next,
                                        key: nextKey,
                                        style: secondaryStyle,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        // At large text the action moves under the words
                        // instead of squeezing them.
                        if (stacked && controlsTogether)
                          Row(
                            children: [
                              Expanded(
                                child: actionButton == null
                                    ? const SizedBox.shrink()
                                    : KitInset(child: actionButton),
                              ),
                              ?moreMenu,
                              ?dismissButton,
                            ],
                          )
                        else if (stacked && actionButton != null)
                          inOrder(3, KitInset(child: actionButton)),
                        if (disabledReason != null)
                          Padding(
                            padding: EdgeInsetsDirectional.only(
                              top: tokens.space1,
                            ),
                            child: Text(disabledReason, style: secondaryStyle),
                          ),
                      ],
                    ),
                  ),
                ),
                if (!stacked && actionButton != null) actionButton,
                if (!(stacked && controlsTogether)) ...[
                  if (moreMenu != null) inOrder(1, moreMenu),
                  if (dismissButton != null) inOrder(2, dismissButton),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
