import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../app_theme.dart';

/// One action a kit part can show: a label, what it does, and optionally an
/// icon. Where it appears (primary, secondary, tertiary) is decided by the
/// slot it is put in, never by the caller styling a button
/// (design standard §2).
class KitAction {
  const KitAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.key,
    this.destructive = false,
    this.working = false,
  });

  final String label;

  /// Null disables it; a disabled action needs a visible reason nearby
  /// (§2), so prefer leaving it out.
  final VoidCallback? onPressed;
  final IconData? icon;
  final Key? key;

  /// Error-coloured. Confirm before acting; never primary.
  final bool destructive;

  /// This action's own tap is in flight (a second or two): a primary or
  /// secondary button shows a small spinner in place of its icon. Never a
  /// status display (see [KitButton.working]).
  final bool working;
}

enum KitButtonRole { primary, secondary, tertiary }

/// The only buttons a migrated screen uses: primary (filled), secondary
/// (tonal) and tertiary (text), all at least 48 dp tall.
///
/// [working] swaps the icon for a small spinner while the button's own tap
/// is in flight (a second or two, e.g. creating a conversation). It is never
/// a status display: a state that lasts, like "Starting the server…", is
/// progress in a [KitStateView], not a disabled button (§2).
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
  });

  const KitButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.working = false,
    this.expand = true,
    this.maxLines = 2,
  }) : role = KitButtonRole.primary,
       destructive = false;

  const KitButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.working = false,
    this.expand = true,
    this.destructive = false,
    this.maxLines = 2,
  }) : role = KitButtonRole.secondary;

  const KitButton.tertiary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.destructive = false,
    this.maxLines = 2,
  }) : role = KitButtonRole.tertiary,
       working = false,
       expand = false;

  factory KitButton.fromAction(
    KitAction action, {
    required KitButtonRole role,
    bool expand = true,
  }) => KitButton(
    key: action.key,
    role: role,
    label: action.label,
    onPressed: action.onPressed,
    icon: action.icon,
    destructive: action.destructive,
    working: role != KitButtonRole.tertiary && action.working,
    expand: role != KitButtonRole.tertiary && expand,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    final text = Text(
      label,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
    final Widget? leading = working
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : icon == null
        ? null
        : Icon(icon, size: 19);
    final minimum = expand ? const Size.fromHeight(48) : const Size(48, 48);
    switch (role) {
      case KitButtonRole.primary:
        final style = FilledButton.styleFrom(minimumSize: minimum);
        return leading == null
            ? FilledButton(onPressed: onPressed, style: style, child: text)
            : FilledButton.icon(
                onPressed: onPressed,
                style: style,
                icon: leading,
                label: text,
              );
      case KitButtonRole.secondary:
        final style = FilledButton.styleFrom(
          minimumSize: minimum,
          foregroundColor: destructive ? error : null,
        );
        return leading == null
            ? FilledButton.tonal(
                onPressed: onPressed,
                style: style,
                child: text,
              )
            : FilledButton.tonalIcon(
                onPressed: onPressed,
                style: style,
                icon: leading,
                label: text,
              );
      case KitButtonRole.tertiary:
        final style = TextButton.styleFrom(
          minimumSize: minimum,
          padding: const EdgeInsets.symmetric(horizontal: tertiaryInset),
          foregroundColor: destructive ? error : null,
        );
        return leading == null
            ? TextButton(onPressed: onPressed, style: style, child: text)
            : TextButton.icon(
                onPressed: onPressed,
                style: style,
                icon: leading,
                label: text,
              );
    }
  }
}

/// A block of actions in the one hierarchy (§2): primary, then secondary,
/// full width and stacked, then up to two tertiary text buttons aligned to
/// the start; more tertiary actions go into a "More" menu. From 600 dp wide
/// the block may sit in one row with the primary rightmost.
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

  /// The caller's own overflow menu (its own keys, items and colours), shown
  /// where the built "More" menu goes, after the tertiary buttons.
  final Widget? menu;

  bool get isEmpty =>
      primary == null && secondary == null && tertiary.isEmpty && menu == null;

  @override
  Widget build(BuildContext context) {
    if (isEmpty) return const SizedBox.shrink();
    final shown = tertiary.take(2).toList();
    final overflow = tertiary.skip(2).toList();
    final more = overflow.isEmpty
        ? null
        : PopupMenuButton<int>(
            key: const ValueKey('kit-actions-more'),
            tooltip: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).chatUiMore,
            icon: const Icon(AppIconography.more),
            onSelected: (index) => overflow[index].onPressed?.call(),
            itemBuilder: (_) => [
              for (var i = 0; i < overflow.length; i++)
                PopupMenuItem(
                  key: overflow[i].key,
                  value: i,
                  enabled: overflow[i].onPressed != null,
                  child: Text(overflow[i].label),
                ),
            ],
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (final action in shown)
                KitButton.fromAction(action, role: KitButtonRole.tertiary),
              ?more,
              ?menu,
              const SizedBox(width: 8),
              if (secondary case final secondary?) ...[
                KitButton.fromAction(
                  secondary,
                  role: KitButtonRole.secondary,
                  expand: false,
                ),
                const SizedBox(width: 8),
              ],
              if (primary case final primary?)
                KitButton.fromAction(
                  primary,
                  role: KitButtonRole.primary,
                  expand: false,
                ),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (primary case final primary?)
              KitButton.fromAction(primary, role: KitButtonRole.primary),
            if (primary != null && secondary != null) const SizedBox(height: 8),
            if (secondary case final secondary?)
              KitButton.fromAction(secondary, role: KitButtonRole.secondary),
            if (shown.isNotEmpty || more != null || menu != null) ...[
              if (primary != null || secondary != null)
                const SizedBox(height: 4),
              KitInset(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
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
          ],
        );
      },
    );
  }
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
