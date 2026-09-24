import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../kit/kit.dart';

/// One entry of a [LocalServerRow]'s overflow menu.
class LocalServerRowMenuItem {
  const LocalServerRowMenuItem({
    required this.keySuffix,
    required this.label,
    required this.onSelected,
  });

  /// Appended to the row's key prefix (`…-disconnect`, `…-recheck`, …).
  final String keySuffix;
  final String label;
  final VoidCallback onSelected;
}

/// A server this app runs on the phone, as one row of the servers list
/// (design standard §6; docs/design/phone-server-screens-cleanup-2026-09-24.md
/// §1): the Servers screen and the server switcher.
///
/// The OpenCode server and the Claude Code daemon keep their own state
/// classes; a person meets both the same way: a phone icon (a filled accent
/// circle when it is the server in use), the name ("This phone"), one line
/// that says what it runs and where it stands ("OpenCode 2 · Running"), and
/// the menu. Tapping the row does the one likely thing: connect to a
/// running server, start a stopped one, or open the details of the one in
/// use. Restart, Stop (error-coloured, confirmed by the caller) and the
/// host's own entries (Details, Disconnect, Forget) are in the menu, so the
/// list carries no buttons.
///
/// Every key is `<keyPrefix>` or `<keyPrefix>-<part>`: `-connect` is the
/// row while tapping it connects, `-start` the small Start action of a
/// stopped server, `-menu` the menu and `-restart`, `-stop` and each host
/// entry's suffix its items.
class LocalServerRow extends StatelessWidget {
  const LocalServerRow({
    super.key,
    required this.keyPrefix,
    required this.title,
    required this.status,
    required this.connectedLabel,
    required this.stopped,
    required this.locked,
    required this.inProgress,
    required this.connected,
    required this.menuTooltip,
    required this.menuItems,
    required this.startLabel,
    required this.restartLabel,
    required this.stopLabel,
    this.failure,
    this.onStart,
    this.onConnect,
    this.onRestart,
    this.onStop,
    this.onOpen,
    this.running = true,
  });

  final String keyPrefix;

  /// The server's name: "This phone", "Claude Code on this phone".
  final String title;

  /// What it runs and where it stands: "OpenCode 2 · Running".
  final String status;

  /// The word that leads [status] when this is the server in use.
  final String connectedLabel;

  /// Installed and not running: tapping starts it, and a small Start action
  /// sits at the row's end.
  final bool stopped;

  /// Every control rests (a check or an operation is under way).
  final bool locked;

  /// An operation is running: the leading mark turns into the working mark.
  final bool inProgress;
  final bool connected;

  /// False for a server that is neither running nor stopped (not answering,
  /// no access): Restart and Stop leave the menu and the row opens [onOpen].
  final bool running;
  final String? failure;
  final String menuTooltip;
  final List<LocalServerRowMenuItem> menuItems;
  final String startLabel;
  final String restartLabel;
  final String stopLabel;

  /// Null hides the control (a host that cannot control the server).
  final VoidCallback? onStart;
  final VoidCallback? onConnect;
  final VoidCallback? onRestart;
  final VoidCallback? onStop;

  /// What tapping the row does when it is the server in use, or when it
  /// cannot be connected to: its details.
  final VoidCallback? onOpen;

  ValueKey<String> _key(String part) => ValueKey('$keyPrefix-$part');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failure = this.failure;
    final VoidCallback? tap;
    final Key? rowKey;
    if (locked) {
      tap = null;
      rowKey = null;
    } else if (stopped) {
      tap = onStart;
      rowKey = null;
    } else if (running && !connected) {
      tap = onConnect;
      rowKey = _key('connect');
    } else {
      tap = onOpen;
      rowKey = null;
    }
    final items = [
      if (running && !stopped && onRestart != null)
        KitMenuItem(
          key: _key('restart'),
          label: restartLabel,
          onSelected: onRestart!,
        ),
      if (running && !stopped && onStop != null)
        KitMenuItem(
          key: _key('stop'),
          label: stopLabel,
          destructive: true,
          onSelected: onStop!,
        ),
      for (final item in menuItems)
        KitMenuItem(
          key: _key(item.keySuffix),
          label: item.label,
          onSelected: item.onSelected,
        ),
    ];
    final Widget? start = stopped && onStart != null
        ? KitButton.tertiary(
            key: _key('start'),
            label: startLabel,
            onPressed: locked ? null : onStart,
          )
        : null;
    // At large text the small Start moves under the row's line (KitRow's
    // `below`), so the name keeps its width.
    final large = MediaQuery.textScalerOf(context).scale(14) > 21;
    final below = [
      if (failure != null)
        Text(
          failure,
          key: _key('failure'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      if (start != null && large) KitInset(child: start),
    ];
    final trailing = [
      if (start != null && !large) start,
      if (items.isNotEmpty)
        KitRowMenu(
          key: _key('menu'),
          tooltip: menuTooltip,
          enabled: !locked,
          items: items,
        ),
    ];
    return KeyedSubtree(
      key: ValueKey(keyPrefix),
      child: Semantics(
        container: true,
        selected: connected,
        liveRegion: true,
        child: KitRow(
          key: rowKey,
          leading: inProgress
              ? const KitStatusMark(state: KitMarkState.working)
              : KitRowIcon(AppIconography.phone, current: connected),
          title: title,
          titleMaxLines: large ? 2 : 1,
          supporting: TextSpan(
            children: [
              if (connected) kitCurrentSpan(context, connectedLabel),
              TextSpan(text: status, semanticsLabel: status),
            ],
          ),
          supportingMaxLines: large ? 2 : 1,
          supportingKey: _key('runtime'),
          below: below.isEmpty
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: below,
                ),
          onTap: tap,
          trailing: trailing.isEmpty
              ? null
              : Row(mainAxisSize: MainAxisSize.min, children: trailing),
        ),
      ),
    );
  }
}
