import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import 'kit_bidi.dart';
import 'kit_copy.dart';
import 'kit_layout.dart';
import 'kit_motion.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';

/// One action a kit part can show. Its place (primary, secondary, tertiary,
/// menu) is decided by the slot it is put in, never by the caller styling a
/// button (design standard §2).
///
/// A disabled action ([onPressed] null) should carry [disabledReason]: the
/// block or stack that shows it renders that reason as a visible line and
/// as the button's semantic hint (STATE-8; kit-KitAction-v2). Strict-mode
/// assertion of this rule waits on the `KitAsserts` seam (KitAction.md, Open
/// question 1), which has not landed; until then this is enforced by
/// rendering, not by a debug assert.
@immutable
class KitAction {
  const KitAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.key,
    this.destructive = false,
    this.working = false,
    this.disabledReason,
    this.shortcut,
  }) : copyText = null;

  /// A text action that copies (KIT-23): "Copy details", "Copy all". Runs
  /// [KitCopy.copy] with [text]'s value at tap time; the button shows a
  /// check and "Copied" for [KitMotion.copiedHold], announced once; never a
  /// SnackBar.
  const KitAction.copy({
    required this.label,
    required String Function() text,
    this.icon = AppIconography.copy,
    this.key,
    this.shortcut,
  }) : copyText = text,
       onPressed = null,
       destructive = false,
       working = false,
       disabledReason = null;

  /// A verb naming what happens (COPY-8): "Delete conversation".
  final String label;

  /// Null disables it; then [disabledReason] should say why.
  final VoidCallback? onPressed;
  final IconData? icon;
  final Key? key;

  /// Loses data or ends running work (LOOK-5). Never primary outside a
  /// confirmation. The act confirms first or offers Undo per the app's
  /// undo-or-confirm table; this flag decides neither.
  final bool destructive;

  /// This action's own tap is in flight (a second or two); never lasting
  /// status (STATE-7). A working action is never shown disabled.
  final bool working;

  /// Why it cannot run now, in one short sentence: "Fill in the server
  /// address first." Rendered as one muted line under the button by
  /// [KitActionBlock] and [KitActionStack], and as the button's semantic
  /// hint.
  final String? disabledReason;

  /// The key combination that does the same ("Ctrl+Enter"), as the
  /// shortcuts help writes it. Shown after the label on a fine pointer
  /// (visual language §5 "keyboard hints on buttons"). Display only; the
  /// shortcut layer binds it.
  final String? shortcut;

  /// Set only by [KitAction.copy].
  final String Function()? copyText;

  /// True when it can be pressed: an [onPressed] or a copy.
  bool get enabled => onPressed != null || copyText != null;
}

enum KitButtonRole { primary, secondary, tertiary }

/// The only buttons a migrated screen uses (visual language §5): primary
/// (accent filled, `onAccent` words), secondary (`surface3`) and tertiary
/// (words in `text2`), all at least 48 dp tall, 50 dp at full width, with
/// 14 dp corners. A destructive primary is the one `dangerFill` button,
/// used only inside a confirmation.
///
/// [working] swaps the icon for a small spinner while the button's own tap
/// is in flight (a second or two, e.g. creating a conversation): the icon
/// and the spinner crossfade over [KitMotion.quick], and a button without
/// an icon makes room for the spinner smoothly instead of jumping (§10).
/// It is never a status display: a state that lasts, like "Starting the server…", is
/// progress in a [KitStateView], not a disabled button (§2). While
/// [working] is true, taps are ignored (the button keeps its enabled fill
/// so it never reads as disabled, C21 f).
///
/// [shortcut] shows the key combination after the label on a fine pointer
/// (kit-KitAction-v2), isolated left to right ([KitBidi.ltr]).
class KitButton extends StatelessWidget {
  const KitButton({
    super.key,
    required this.role,
    required this.label,
    required this.onPressed,
    this.icon,
    this.working = false,
    this.expand = true,
    this.destructive = false,
    this.maxLines = 2,
    this.shortcut,
  }) : copyText = null,
       disabledReason = null,
       copied = false;

  const KitButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.working = false,
    this.expand = true,
    this.maxLines = 2,
    this.destructive = false,
    this.shortcut,
  }) : role = KitButtonRole.primary,
       copyText = null,
       disabledReason = null,
       copied = false;

  const KitButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.working = false,
    this.expand = true,
    this.destructive = false,
    this.maxLines = 2,
    this.shortcut,
  }) : role = KitButtonRole.secondary,
       copyText = null,
       disabledReason = null,
       copied = false;

  const KitButton.tertiary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.destructive = false,
    this.maxLines = 2,
    this.shortcut,
  }) : role = KitButtonRole.tertiary,
       working = false,
       expand = false,
       copyText = null,
       disabledReason = null,
       copied = false;

  /// Used only by [fromAction] to carry what a plain [KitAction] cannot
  /// name as a public constructor parameter without widening the four
  /// constructors above (KIT-43 additive rule): the copy behaviour and the
  /// reason a disabled action names.
  const KitButton._derived({
    super.key,
    required this.role,
    required this.label,
    this.onPressed,
    this.icon,
    this.working = false,
    this.expand = true,
    this.destructive = false,
    this.maxLines = 2,
    this.shortcut,
    this.copyText,
    this.disabledReason,
    this.copied = false,
  });

  factory KitButton.fromAction(
    KitAction action, {
    required KitButtonRole role,
    bool expand = true,
  }) => KitButton._derived(
    key: action.key,
    role: role,
    label: action.label,
    onPressed: action.onPressed,
    icon: action.icon,
    destructive: action.destructive,
    working: role != KitButtonRole.tertiary && action.working,
    expand: role != KitButtonRole.tertiary && expand,
    shortcut: action.shortcut,
    copyText: action.copyText,
    disabledReason: action.disabledReason,
  );

  /// A tertiary button's side padding; blocks pull the row back by it so
  /// the label lines up with the text above.
  static const tertiaryInset = 8.0;

  final KitButtonRole role;
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool working;
  final bool expand;
  final bool destructive;
  final int maxLines;
  final String? shortcut;

  /// Set only through [fromAction] from [KitAction.copyText].
  final String Function()? copyText;

  /// Set only through [fromAction] from [KitAction.disabledReason].
  final String? disabledReason;

  /// Set only by [_KitCopyButton]: keys the check icon `kit-action-copied`
  /// instead of `kit-button-icon` while a copy button shows it.
  final bool copied;

  @override
  Widget build(BuildContext context) {
    final copyText = this.copyText;
    if (copyText != null) {
      return _KitCopyButton(
        role: role,
        label: label,
        icon: icon,
        shortcut: shortcut,
        expand: expand,
        maxLines: maxLines,
        copyText: copyText,
        buttonKey: key,
      );
    }

    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final still = KitMotion.reduced(context);
    final Widget labelWidget = _KitButtonLabel(
      label: label,
      shortcut: shortcut,
      role: role,
      maxLines: maxLines,
    );
    Widget? leading;
    Widget child = labelWidget;
    if (role != KitButtonRole.tertiary && icon != null) {
      // The icon and the spinner share one slot and crossfade.
      leading = SizedBox.square(
        dimension: tokens.smallIconSize,
        child: AnimatedSwitcher(
          duration: still ? Duration.zero : KitMotion.quick,
          switchInCurve: KitMotion.enter,
          switchOutCurve: KitMotion.exit,
          child: working
              ? const _Spinner(key: ValueKey('kit-button-working'))
              : Icon(
                  icon,
                  key: copied ? _copiedKey : const ValueKey('kit-button-icon'),
                  size: tokens.smallIconSize,
                ),
        ),
      );
    } else if (role != KitButtonRole.tertiary) {
      // No icon: the spinner opens its own room before the words. (Under
      // reduced motion no AnimatedSize at all: at zero duration it would
      // re-dirty itself during layout.)
      final slot = AnimatedSwitcher(
        duration: still ? Duration.zero : KitMotion.quick,
        child: working
            ? Padding(
                key: const ValueKey('kit-button-working'),
                padding: EdgeInsetsDirectional.only(end: tokens.space2),
                child: const _Spinner(),
              )
            : const SizedBox.shrink(),
      );
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (still)
            slot
          else
            AnimatedSize(
              duration: KitMotion.quick,
              curve: KitMotion.enter,
              child: slot,
            ),
          Flexible(child: labelWidget),
        ],
      );
    } else if (working) {
      leading = const _Spinner();
    } else if (icon != null) {
      leading = Icon(
        icon,
        key: copied ? _copiedKey : null,
        size: tokens.smallIconSize,
      );
    }
    final minimum = expand
        ? Size.fromHeight(tokens.buttonHeight)
        : Size(tokens.minTarget, tokens.minTarget);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.buttonRadius),
    );
    // Taps never fire while the action's own tap is in flight (STATE-7):
    // the callback becomes a no-op so the fill stays the enabled colour
    // (never partial opacity, C21 f) instead of reading as disabled.
    final effectiveOnPressed = working ? () {} : onPressed;
    Widget result;
    switch (role) {
      case KitButtonRole.primary:
        // Destructive is primary only where the whole sheet or screen is
        // that one confirmed act (design standard §2): the one red fill.
        final style = FilledButton.styleFrom(
          minimumSize: minimum,
          shape: shape,
          elevation: 0,
          backgroundColor: destructive ? roles.dangerFill : roles.accent,
          foregroundColor: destructive ? roles.onDangerFill : roles.onAccent,
          disabledBackgroundColor: roles.surface3,
          disabledForegroundColor: roles.text3,
        );
        result = leading == null
            ? FilledButton(
                onPressed: effectiveOnPressed,
                style: style,
                child: child,
              )
            : FilledButton.icon(
                onPressed: effectiveOnPressed,
                style: style,
                icon: leading,
                label: labelWidget,
              );
      case KitButtonRole.secondary:
        final style = FilledButton.styleFrom(
          minimumSize: minimum,
          shape: shape,
          elevation: 0,
          backgroundColor: roles.surface3,
          foregroundColor: destructive ? roles.danger : roles.text1,
          disabledBackgroundColor: roles.surface3,
          disabledForegroundColor: roles.text3,
        );
        result = leading == null
            ? FilledButton.tonal(
                onPressed: effectiveOnPressed,
                style: style,
                child: child,
              )
            : FilledButton.tonalIcon(
                onPressed: effectiveOnPressed,
                style: style,
                icon: leading,
                label: labelWidget,
              );
      case KitButtonRole.tertiary:
        final style = TextButton.styleFrom(
          minimumSize: minimum,
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: tertiaryInset),
          foregroundColor: destructive ? roles.danger : roles.text2,
          disabledForegroundColor: roles.text3,
        );
        result = leading == null
            ? TextButton(
                onPressed: effectiveOnPressed,
                style: style,
                child: labelWidget,
              )
            : TextButton.icon(
                onPressed: effectiveOnPressed,
                style: style,
                icon: leading,
                label: labelWidget,
              );
    }
    final reason = disabledReason;
    if (reason != null && onPressed == null) {
      // STATE-8: a disabled control's reason is also its semantic hint.
      // MergeSemantics folds the hint into the button's own (boundary)
      // node instead of leaving it stranded on a separate one.
      result = MergeSemantics(
        child: Semantics(hint: reason, child: result),
      );
    }
    return result;
  }
}

/// A button's label, with [shortcut] appended on a fine pointer
/// (kit-KitAction-v2, visual language §5): mono, `text3` on a tertiary
/// button or the button's own foreground otherwise, isolated left to right.
class _KitButtonLabel extends StatelessWidget {
  const _KitButtonLabel({
    required this.label,
    required this.shortcut,
    required this.role,
    required this.maxLines,
  });

  final String label;
  final String? shortcut;
  final KitButtonRole role;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
    final shortcut = this.shortcut;
    if (shortcut == null || !KitLayout.finePointer(context)) return text;
    final tokens = KitTokens.of(context);
    final hintStyle = role == KitButtonRole.tertiary
        ? KitText.styleOf(context, KitTextRole.mono, tone: KitTextTone.tertiary)
        : KitText.styleFor(KitTextRole.mono);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: text),
        SizedBox(width: tokens.space1),
        KitBidi.ltrText(shortcut, style: hintStyle),
      ],
    );
  }
}

/// The small spinner a working button shows.
class _Spinner extends StatelessWidget {
  const _Spinner({super.key});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: KitTokens.of(context).smallIconSize,
    child: const CircularProgressIndicator(strokeWidth: 2),
  );
}

/// The private stateful body of a [KitAction.copy] button (kit-KitAction-v2,
/// KIT-23): runs [KitCopy.copy] at tap time, then swaps its icon and label
/// for a check and "Copied" for [KitMotion.copiedHold] before reverting.
class _KitCopyButton extends StatefulWidget {
  const _KitCopyButton({
    required this.role,
    required this.label,
    required this.copyText,
    this.icon,
    this.shortcut,
    this.expand = true,
    this.maxLines = 2,
    this.buttonKey,
  });

  final KitButtonRole role;
  final String label;
  final String Function() copyText;
  final IconData? icon;
  final String? shortcut;
  final bool expand;
  final int maxLines;
  final Key? buttonKey;

  @override
  State<_KitCopyButton> createState() => _KitCopyButtonState();
}

class _KitCopyButtonState extends State<_KitCopyButton> {
  Timer? _revert;
  bool _copied = false;

  @override
  void dispose() {
    _revert?.cancel();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await KitCopy.copy(context, widget.copyText());
    if (!mounted) return;
    setState(() => _copied = true);
    _revert?.cancel();
    _revert = Timer(KitMotion.copiedHold, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    return KitButton._derived(
      key: widget.buttonKey,
      role: widget.role,
      label: _copied ? l10n.kitCopied : widget.label,
      onPressed: _copied ? () {} : _handleTap,
      icon: _copied ? AppIconography.check : widget.icon,
      shortcut: widget.shortcut,
      expand: widget.expand,
      maxLines: widget.maxLines,
      copied: _copied,
    );
  }
}

/// The check icon shown while a copy button reads "Copied"; a distinct
/// value lets tests find `kit-action-copied` by key when the text alone
/// (also findable, per TEST-5) is ambiguous.
const _copiedKey = ValueKey('kit-action-copied');

/// A disabled action's reason (STATE-8, KitAction.md): one muted line,
/// found in tests by its text first (TEST-5); [id] disambiguates the key
/// when a block shows more than one.
class _KitActionReason extends StatelessWidget {
  const _KitActionReason(this.text, {required this.id});

  final String text;
  final String id;

  @override
  Widget build(BuildContext context) => Text(
    text,
    key: ValueKey('kit-action-reason-$id'),
    style: KitTokens.of(context).note,
  );
}

/// A block of actions in the one hierarchy (design standard §2): primary,
/// then secondary, then up to two tertiary actions, with the rest in
/// "More" (kit-actions-more). A disabled action's [KitAction.disabledReason]
/// shows as a muted line under its button (STATE-8). A destructive tertiary
/// makes the whole block lay out as [KitActionStack] on every window
/// (LAY-14, §2.7), so a destructive act never sits beside a frequent one.
/// From [KitWindow.medium] up (and not a short window) the block is one
/// end-aligned row with the primary at the end.
class KitActionBlock extends StatelessWidget {
  const KitActionBlock({
    super.key,
    this.primary,
    this.secondary,
    this.tertiary = const [],
    this.menu,
  });

  final KitAction? primary;
  final KitAction? secondary;
  final List<KitAction> tertiary;

  /// The caller's own overflow widget, where "More" goes.
  /// Retired by kit-KitAction-v2: pass the extra actions in [tertiary] (the
  /// block builds "More" itself). Kept working (KIT-43).
  final Widget? menu;

  bool get isEmpty =>
      primary == null && secondary == null && tertiary.isEmpty && menu == null;

  @override
  Widget build(BuildContext context) {
    if (isEmpty) return const SizedBox.shrink();
    final tokens = KitTokens.of(context);
    final shown = tertiary.take(2).toList();
    final overflow = tertiary.skip(2).toList();
    final more = _buildMore(context, overflow, tokens);
    final hasDestructiveTertiary = tertiary.any((a) => a.destructive);
    // LAY-14, §2.7: a destructive tertiary forces the stacked layout, on
    // every window, so it is never beside a frequent action.
    final stacked =
        hasDestructiveTertiary ||
        KitLayout.windowOf(context) == KitWindow.compact ||
        KitLayout.isShort(context);

    if (!stacked) {
      final row = Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: tokens.space2,
        runSpacing: tokens.space2,
        children: [
          for (final action in shown)
            KitButton.fromAction(action, role: KitButtonRole.tertiary),
          ?more,
          ?menu,
          if (secondary case final secondary?)
            KitButton.fromAction(
              secondary,
              role: KitButtonRole.secondary,
              expand: false,
            ),
          if (primary case final primary?)
            KitButton.fromAction(
              primary,
              role: KitButtonRole.primary,
              expand: false,
            ),
        ],
      );
      // STATE-8: reasons collect under the row, end-aligned, in slot order.
      final reasons = [
        if (primary?.disabledReason case final reason?)
          _KitActionReason(reason, id: 'primary'),
        if (secondary?.disabledReason case final reason?)
          _KitActionReason(reason, id: 'secondary'),
        for (final action in shown)
          if (action.disabledReason case final reason?)
            _KitActionReason(reason, id: 'tertiary-${action.label}'),
      ];
      if (reasons.isEmpty) return row;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          row,
          Padding(
            padding: EdgeInsetsDirectional.only(top: tokens.space1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final reason in reasons)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: reason,
                  ),
              ],
            ),
          ),
        ],
      );
    }

    // Stacked (compact, a short window, or forced by a destructive
    // tertiary): primary, then secondary, full width, then the tertiary
    // actions. A non-forced stack still wraps up to two tertiary actions
    // side by side; a forced stack (or a reason to show) puts each tertiary
    // action, and its reason, on its own line so nothing sits beside a
    // destructive target (LAY-9).
    final tertiaryOneOnEachLine =
        hasDestructiveTertiary || shown.any((a) => a.disabledReason != null);
    final hasTertiaryLine = shown.isNotEmpty || more != null || menu != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (primary case final primary?) ...[
          KitButton.fromAction(primary, role: KitButtonRole.primary),
          if (primary.disabledReason case final reason?) ...[
            SizedBox(height: tokens.space1),
            _KitActionReason(reason, id: 'primary'),
          ],
        ],
        if (primary != null && secondary != null)
          SizedBox(height: tokens.space2),
        if (secondary case final secondary?) ...[
          KitButton.fromAction(secondary, role: KitButtonRole.secondary),
          if (secondary.disabledReason case final reason?) ...[
            SizedBox(height: tokens.space1),
            _KitActionReason(reason, id: 'secondary'),
          ],
        ],
        if (hasTertiaryLine && (primary != null || secondary != null))
          SizedBox(height: tokens.space2),
        if (hasTertiaryLine)
          tertiaryOneOnEachLine
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final action in shown) ...[
                      KitInset(
                        child: KitButton.fromAction(
                          action,
                          role: KitButtonRole.tertiary,
                        ),
                      ),
                      if (action.disabledReason case final reason?) ...[
                        SizedBox(height: tokens.space1),
                        _KitActionReason(
                          reason,
                          id: 'tertiary-${action.label}',
                        ),
                      ],
                      if (action != shown.last || more != null || menu != null)
                        SizedBox(height: tokens.space2),
                    ],
                    if (more case final more?) KitInset(child: more),
                    if (menu case final menu?) KitInset(child: menu),
                  ],
                )
              : KitInset(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: tokens.space1,
                    children: [
                      for (final action in shown)
                        KitButton.fromAction(
                          action,
                          role: KitButtonRole.tertiary,
                        ),
                      ?more,
                      ?menu,
                    ],
                  ),
                ),
      ],
    );
  }
}

/// The "More" overflow menu (kit-actions-more): a destructive action beyond
/// the first two tertiary actions renders last, after a divider (§2.7).
Widget? _buildMore(
  BuildContext context,
  List<KitAction> overflow,
  KitTokens tokens,
) {
  if (overflow.isEmpty) return null;
  final order = [
    for (var i = 0; i < overflow.length; i++)
      if (!overflow[i].destructive) i,
    for (var i = 0; i < overflow.length; i++)
      if (overflow[i].destructive) i,
  ];
  final firstDestructive = order.indexWhere((i) => overflow[i].destructive);
  return PopupMenuButton<int>(
    key: const ValueKey('kit-actions-more'),
    tooltip: lookupAppLocalizations(Localizations.localeOf(context)).kitMore,
    icon: const Icon(AppIconography.more),
    onSelected: (index) => overflow[index].onPressed?.call(),
    itemBuilder: (_) => [
      for (var position = 0; position < order.length; position++) ...[
        if (position == firstDestructive) const PopupMenuDivider(),
        PopupMenuItem(
          key: overflow[order[position]].key,
          value: order[position],
          enabled: overflow[order[position]].onPressed != null,
          child: Text(
            overflow[order[position]].label,
            style: overflow[order[position]].destructive
                ? TextStyle(color: tokens.roles.danger)
                : null,
          ),
        ),
      ],
    ],
  );
}

/// Pulls a row of tertiary buttons back by their padding, so their labels
/// line up with the text above them (start edge, either direction).
class KitInset extends StatelessWidget {
  const KitInset({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Transform.translate(
      offset: Offset(
        Directionality.of(context) == TextDirection.rtl
            ? KitButton.tertiaryInset
            : -KitButton.tertiaryInset,
        0,
      ),
      child: child,
    ),
  );
}
