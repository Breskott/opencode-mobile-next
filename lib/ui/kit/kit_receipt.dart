import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../app_iconography.dart';
import '../theme_roles.dart';
import 'kit_bidi.dart';
import 'kit_buttons.dart';
import 'kit_motion.dart';
import 'kit_since.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';

/// What happened to a write the phone sent (docs/ux-system/kit-api/
/// KitReceipt.md; K2 §1.16, §4.8, §4.9; STATE-5, STATE-10, AUTO-4,
/// DATA-11, A11Y-3).
enum KitReceiptState {
  /// In flight.
  sending,

  /// Left the phone; no echo yet. Never reads as "Done" (STATE-10).
  sent,

  /// The server echoed it.
  confirmed,

  /// No echo in time, or the echo was lost: Try again.
  notConfirmed,

  /// The server said no: the reason, in words.
  refused,

  /// Someone answered it on another device first.
  answeredElsewhere,
}

/// A write's receipt, shown in place as a mark and a word: "Sending…",
/// "Sent", "Done" (or the act, [label]), "Not confirmed yet" with Try
/// again, "Not accepted: {reason}", "Answered on {where}".
///
/// With [automatic] it is the automation vertical's `KitAutoLine` (AUTO-4):
/// "Restarted the phone's server at 10:42" with Undo while the window is
/// open.
///
/// A waiting receipt (sending or sent, with [since]) turns into "Not
/// confirmed yet" with Try again after [KitMotion.escalateAfter], on
/// [KitSince]'s timer. Undo shows only when [onUndo] is given, only on a
/// confirmed receipt, and only until [at] + [KitMotion.undoWindow] (with no
/// [at], for as long as the caller passes [onUndo]); the caller passes it
/// only where the server exposes an inverse (DATA-11).
///
/// One live region carries the words, so each change of words is announced
/// once and a rebuild with the same words is not (A11Y-3). The mark is
/// decoration: the word already says it. No haptics: the send tick fired
/// when the person sent (MOT-11).
///
/// States: sending, sent, confirmed, not confirmed, refused, answered
/// elsewhere, automatic (working = sending; answered = confirmed /
/// answeredElsewhere).
class KitReceipt extends StatelessWidget {
  const KitReceipt({
    super.key,
    required this.state,
    this.label,
    this.reason,
    this.where,
    this.at,
    this.since,
    this.onRetry,
    this.onUndo,
    this.onTap,
    this.automatic = false,
    this.retryKey,
    this.undoKey,
  });

  final KitReceiptState state;

  /// The words for the act, replacing the confirmed word: "Allowed once",
  /// "Restarted the phone's server". Used only once the write is
  /// confirmed: a label never makes a sent write read as done (STATE-10).
  final String? label;

  /// [KitReceiptState.refused]: the server's reason in plain words.
  final String? reason;

  /// [KitReceiptState.answeredElsewhere]: the other device, "the laptop".
  final String? where;

  /// The time of the latest transition, shown as "at 10:42"; also where the
  /// Undo window starts.
  final DateTime? at;

  /// When the write was sent. A sending or sent receipt escalates to "Not
  /// confirmed yet" after [KitMotion.escalateAfter].
  final DateTime? since;

  /// "Try again" on a not-confirmed (or escalated) receipt.
  final VoidCallback? onRetry;

  /// "Undo" on a confirmed receipt, inside the window.
  final VoidCallback? onUndo;

  /// The receipt opens where the write lives (the gate sheet).
  final VoidCallback? onTap;

  /// The automatic-action line (KitAutoLine, AUTO-4).
  final bool automatic;

  final Key? retryKey;
  final Key? undoKey;

  /// A row's supporting line (like `kitCurrentSpan`): "Sent · ",
  /// "Not confirmed yet · ", "Not accepted: {reason} · ",
  /// "Answered on {where} · ". No actions: a row's actions live in its
  /// KitRowMenu or its sheet.
  static InlineSpan span(
    BuildContext context,
    KitReceiptState state, {
    String? reason,
    String? label,
    String? where,
  }) {
    final roles = KitTokens.of(context).roles;
    return TextSpan(
      text:
          '${_visibleWord(context, state, reason: reason, label: label, where: where)} · ',
      style: TextStyle(color: _wordColor(roles, state)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final waits =
        state == KitReceiptState.sending || state == KitReceiptState.sent;
    return KitSince(
      since: waits ? since : null,
      builder: (context, status) {
        final shown = status.isSlow ? KitReceiptState.notConfirmed : state;
        final undo = onUndo;
        if (shown != KitReceiptState.confirmed || undo == null) {
          return _body(context, shown, undoOpen: false);
        }
        // The Undo window rides the kit's one wait timer: it closes when a
        // wait begun at [at] turns slow, and [KitMotion.undoWindow] equals
        // [KitMotion.escalateAfter] (both 8 s, K2 §1.16/§1.17). With no
        // [at], it stays open while the caller offers [onUndo].
        assert(KitMotion.undoWindow == KitMotion.escalateAfter);
        return KitSince(
          since: at,
          builder: (context, window) =>
              _body(context, shown, undoOpen: !window.isSlow),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    KitReceiptState shown, {
    required bool undoOpen,
  }) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final reduced = KitMotion.reduced(context);
    final fade = reduced ? Duration.zero : KitMotion.quick;

    final word = _visibleWord(
      context,
      shown,
      reason: reason,
      label: label,
      where: where,
    );
    final time = at == null ? null : _time(context, at!);
    final atWords = time == null ? null : l10n.kitReceiptAt(time);
    final trimmedReason = reason?.trim();
    final semanticsLabel = [
      _plainWord(context, shown, label: label, where: where),
      if (shown == KitReceiptState.refused &&
          trimmedReason != null &&
          trimmedReason.isNotEmpty)
        KitBidi.auto(trimmedReason),
      ?atWords,
    ].join(', ');

    final glyphSize = _glyphSize(context, tokens);
    final mark = SizedBox.square(
      dimension: glyphSize,
      child: AnimatedSwitcher(
        duration: fade,
        switchInCurve: KitMotion.enter,
        switchOutCurve: KitMotion.exit,
        child: KeyedSubtree(
          key: ValueKey(shown),
          child: _mark(context, shown, roles, glyphSize, reduced: reduced),
        ),
      ),
    );

    final words = KitText.rich(
      TextSpan(
        children: [
          TextSpan(
            text: word,
            style: TextStyle(color: _wordColor(roles, shown)),
          ),
          if (atWords != null)
            TextSpan(
              text: ' $atWords',
              style: TextStyle(color: roles.text2),
            ),
        ],
      ),
      role: KitTextRole.secondary,
    );

    Widget line = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: tokens.space2),
        Flexible(child: words),
      ],
    );
    final tap = onTap;
    if (tap != null) {
      line = InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(tokens.space2),
        hoverColor: roles.surface2,
        focusColor: roles.surface3,
        highlightColor: roles.surface3,
        splashFactory: NoSplash.splashFactory,
        // A 48 dp target (LAY-9) whose words stay flush with the text above.
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: tokens.minTarget),
          child: line,
        ),
      );
    }
    // The one live region (A11Y-3): its label changes once per transition,
    // and a rebuild with the same words sends nothing new to announce.
    line = Semantics(
      container: true,
      liveRegion: true,
      button: tap != null,
      onTap: tap,
      label: semanticsLabel,
      child: ExcludeSemantics(child: line),
    );

    final retry = onRetry;
    final actions = <Widget>[
      if (shown == KitReceiptState.notConfirmed && retry != null)
        KitButton.tertiary(
          key: retryKey,
          label: l10n.kitTryAgain,
          onPressed: retry,
        ),
      if (undoOpen)
        KitButton.tertiary(
          key: undoKey,
          label: l10n.kitUndoAction,
          onPressed: onUndo,
        ),
    ];

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: tokens.space2,
      children: [
        line,
        AnimatedSwitcher(
          duration: fade,
          switchInCurve: KitMotion.enter,
          switchOutCurve: KitMotion.exit,
          child: actions.isEmpty
              ? const SizedBox.shrink(key: ValueKey('none'))
              : Wrap(
                  key: ValueKey((shown, undoOpen)),
                  spacing: tokens.space2,
                  children: actions,
                ),
        ),
      ],
    );
  }
}

/// The word a receipt shows: the state word, or for confirmed the act.
String _visibleWord(
  BuildContext context,
  KitReceiptState state, {
  String? reason,
  String? label,
  String? where,
}) {
  final l10n = lookupAppLocalizations(Localizations.localeOf(context));
  final trimmed = reason?.trim();
  if (state == KitReceiptState.refused &&
      trimmed != null &&
      trimmed.isNotEmpty) {
    return l10n.kitReceiptRefusedReason(KitBidi.auto(trimmed));
  }
  return _plainWord(context, state, label: label, where: where);
}

/// The word without the refusal's reason (semantics lists that apart).
String _plainWord(
  BuildContext context,
  KitReceiptState state, {
  String? label,
  String? where,
}) {
  final l10n = lookupAppLocalizations(Localizations.localeOf(context));
  final act = label?.trim();
  final place = where?.trim();
  return switch (state) {
    KitReceiptState.sending => l10n.kitReceiptSending,
    KitReceiptState.sent => l10n.kitReceiptSent,
    KitReceiptState.confirmed =>
      act != null && act.isNotEmpty
          ? KitBidi.auto(act)
          : l10n.kitReceiptConfirmed,
    KitReceiptState.notConfirmed => l10n.kitReceiptNotConfirmed,
    KitReceiptState.refused => l10n.kitReceiptRefused,
    KitReceiptState.answeredElsewhere => l10n.kitReceiptAnsweredElsewhere(
      KitBidi.auto(place != null && place.isNotEmpty ? place : '…'),
    ),
  };
}

/// Words in `text2`, and in `text1` where the person may need to act
/// (LOOK-4/5: no amber, no red).
Color _wordColor(ThemeRoles roles, KitReceiptState state) => switch (state) {
  KitReceiptState.notConfirmed || KitReceiptState.refused => roles.text1,
  _ => roles.text2,
};

Widget _mark(
  BuildContext context,
  KitReceiptState state,
  ThemeRoles roles,
  double size, {
  required bool reduced,
}) => switch (state) {
  KitReceiptState.sending =>
    reduced
        ? Center(
            child: Icon(
              AppIconography.statusDot,
              size: KitTokens.markDotSize,
              color: roles.accent,
            ),
          )
        : Padding(
            padding: EdgeInsets.all(KitTokens.focusRingWidth(context)),
            child: CircularProgressIndicator(
              strokeWidth: KitTokens.focusRingWidth(context),
              color: roles.accent,
            ),
          ),
  KitReceiptState.sent || KitReceiptState.answeredElsewhere => Icon(
    AppIconography.check,
    size: size,
    color: roles.text2,
  ),
  KitReceiptState.confirmed => Icon(
    AppIconography.check,
    size: size,
    color: roles.success,
  ),
  KitReceiptState.notConfirmed => Icon(
    AppIconography.warning,
    size: size,
    color: roles.text1,
  ),
  KitReceiptState.refused => Icon(
    AppIconography.error,
    size: size,
    color: roles.text1,
  ),
};

/// [KitTokens.smallIconSize] grown with the person's text up to the kit's
/// cap, on whole physical pixels (LOOK-33).
double _glyphSize(BuildContext context, KitTokens tokens) {
  final scaled = tokens.iconSize(context, tokens.smallIconSize);
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return dpr > 0 ? (scaled * dpr).roundToDouble() / dpr : scaled;
}

/// The clock time of [at], in the person's 12/24-hour setting.
String _time(BuildContext context, DateTime at) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(at.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
