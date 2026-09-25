import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import 'kit_motion.dart';
import 'kit_row.dart';
import 'motion/kit_reveal.dart';

/// A [KitRow]'s leading icon with an optional current mark (design
/// standard §6, "state lives in the row"): the thing the person is using
/// right now (the server they are connected to) sits in a filled accent
/// circle, every other row keeps the plain muted icon. The row says the
/// same in words ("Connected · …") so the mark is never colour-only.
class KitRowIcon extends StatelessWidget {
  const KitRowIcon(this.icon, {super.key, this.current = false, this.color});

  final IconData icon;

  /// The row is the one in use now.
  final bool current;

  /// The icon's colour when not current; muted by default.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!current) return KitRow.icon(context, icon, color: color);
    return Container(
      key: const ValueKey('kit-row-current-mark'),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: theme.colorScheme.onPrimary),
    );
  }
}

/// The start of a row's supporting line that says it is the current one,
/// in the accent colour: "Connected · ".
TextSpan kitCurrentSpan(BuildContext context, String word) => TextSpan(
  text: '$word · ',
  style: TextStyle(
    color: Theme.of(context).colorScheme.primary,
    fontWeight: FontWeight.w600,
  ),
);

/// One entry of a [KitRowMenu].
class KitMenuItem {
  const KitMenuItem({
    required this.label,
    required this.onSelected,
    this.key,
    this.destructive = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onSelected;
  final Key? key;

  /// Error-coloured; what it opens confirms before acting (§2).
  final bool destructive;
  final bool enabled;
}

/// A row's trailing overflow menu (§6: "a single icon action"): the rarer
/// things a row can do, so the row itself carries no buttons. Destructive
/// entries are error-coloured and confirm before acting.
class KitRowMenu extends StatelessWidget {
  const KitRowMenu({
    super.key,
    required this.items,
    this.tooltip,
    this.enabled = true,
  });

  final List<KitMenuItem> items;
  final String? tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<int>(
      tooltip:
          tooltip ??
          lookupAppLocalizations(Localizations.localeOf(context)).chatUiMore,
      enabled: enabled && items.isNotEmpty,
      icon: const Icon(AppIconography.more),
      iconColor: AppTheme.mutedOf(theme),
      onSelected: (index) => items[index].onSelected(),
      itemBuilder: (_) => [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem(
            key: items[i].key,
            value: i,
            enabled: items[i].enabled,
            child: Text(
              items[i].label,
              style: items[i].destructive
                  ? TextStyle(color: theme.colorScheme.error)
                  : null,
            ),
          ),
      ],
    );
  }
}

/// The trailing mark of a row that opens another screen.
class KitChevron extends StatelessWidget {
  const KitChevron({super.key});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 48,
    child: Icon(
      AppIconography.chevronRight,
      size: 20,
      color: AppTheme.mutedOf(Theme.of(context)),
    ),
  );
}

/// A setting that is on or off, as a row (§6): the title, what it does in
/// the supporting line (two lines allowed), and the switch at the end. The
/// whole row toggles; a null [onChanged] dims it, and its supporting line
/// says why.
class KitSwitchRow extends StatelessWidget {
  const KitSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.leading,
    this.supporting,
    this.switchKey,
    this.below,
  });

  final String title;
  final bool value;

  /// Under the supporting line: what the setting has done so far (a
  /// counter) or an error to act on.
  final Widget? below;
  final ValueChanged<bool>? onChanged;
  final Widget? leading;
  final String? supporting;
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return MergeSemantics(
      child: KitRow(
        title: title,
        leading: leading,
        titleMaxLines: 2,
        supporting: supporting == null ? null : TextSpan(text: supporting),
        supportingMaxLines: 2,
        below: below,
        onTap: onChanged == null ? null : () => onChanged(!value),
        trailing: Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: Switch.adaptive(
            key: switchKey,
            value: value,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

/// A row that unfolds what it stands for in place (§6): a group of rows
/// (the built-in plugins) or a rare choice (other OpenCode versions). Its
/// chevron points down when folded and turns up when open, while the rows
/// unfold under it ([KitReveal], §10); reduced motion makes both instant.
class KitExpandRow extends StatefulWidget {
  const KitExpandRow({
    super.key,
    required this.title,
    required this.children,
    this.leading,
    this.supporting,
    this.initiallyExpanded = false,
    this.headerKey,
  });

  final String title;
  final Widget? leading;
  final InlineSpan? supporting;
  final List<Widget> children;
  final bool initiallyExpanded;

  /// The tappable header, for tests.
  final Key? headerKey;

  @override
  State<KitExpandRow> createState() => _KitExpandRowState();
}

class _KitExpandRowState extends State<KitExpandRow> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          child: KitRow(
            key: widget.headerKey,
            title: widget.title,
            leading: widget.leading,
            supporting: widget.supporting,
            onTap: () => setState(() => _open = !_open),
            trailing: SizedBox.square(
              dimension: 48,
              child: AnimatedRotation(
                turns: _open ? .5 : 0,
                duration: KitMotion.reduced(context)
                    ? Duration.zero
                    : KitMotion.standard,
                curve: KitMotion.emphasized,
                child: Icon(
                  AppIconography.chevronDown,
                  size: 20,
                  color: AppTheme.mutedOf(theme),
                ),
              ),
            ),
          ),
        ),
        KitReveal(
          child: !_open
              ? null
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: widget.children,
                ),
        ),
      ],
    );
  }
}
