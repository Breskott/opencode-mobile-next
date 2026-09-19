import 'package:flutter/material.dart';

import '../app_theme.dart';

/// One entry of a [LocalServerCard]'s overflow menu.
class LocalServerCardMenuItem {
  const LocalServerCardMenuItem({
    required this.keySuffix,
    required this.label,
    required this.onSelected,
  });

  /// Appended to the card's key prefix (`…-disconnect`, `…-recheck`, …).
  final String keySuffix;
  final String label;
  final VoidCallback onSelected;
}

/// How a server this app found running on the phone looks, wherever it is
/// shown: the Servers screen and the server switcher.
///
/// The OpenCode server and the Claude Code daemon are different things with
/// different state, but a person controls both the same way (connect or
/// open, start, restart, stop, and a short menu), so they share this one
/// presentation and keep their own state classes. Every key is
/// `<keyPrefix>` or `<keyPrefix>-<part>`, which is what lets the OpenCode
/// card keep the keys it had before the presentation was factored out.
class LocalServerCard extends StatelessWidget {
  const LocalServerCard({
    super.key,
    required this.keyPrefix,
    required this.title,
    required this.subtitle,
    required this.stopped,
    required this.locked,
    required this.inProgress,
    required this.connected,
    required this.menuTooltip,
    required this.menuItems,
    required this.startLabel,
    required this.connectLabel,
    required this.openLabel,
    required this.restartLabel,
    required this.stopLabel,
    this.failure,
    this.onStart,
    this.onConnect,
    this.onRestart,
    this.onStop,
    this.detailsTitle,
    this.details = const [],
  });

  final String keyPrefix;
  final String title;
  final String subtitle;

  /// Installed and not running: the card offers Start and nothing else.
  final bool stopped;

  /// Every control is disabled (a check or an operation is under way).
  final bool locked;

  /// An operation is running: shows the progress line.
  final bool inProgress;
  final bool connected;
  final String? failure;
  final String menuTooltip;
  final List<LocalServerCardMenuItem> menuItems;
  final String startLabel;
  final String connectLabel;
  final String openLabel;
  final String restartLabel;
  final String stopLabel;

  /// Null hides the button (a host that cannot control Termux).
  final VoidCallback? onStart;
  final VoidCallback? onConnect;
  final VoidCallback? onRestart;
  final VoidCallback? onStop;

  /// Diagnosis, folded away: version and check time do not decide what a
  /// person does next.
  final String? detailsTitle;
  final List<Widget> details;

  ValueKey<String> _key(String part) => ValueKey('$keyPrefix-$part');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const touch = Size(48, 48);
    return Card.filled(
      key: ValueKey(keyPrefix),
      margin: const EdgeInsets.only(bottom: 16),
      color: theme.colorScheme.primaryContainer.withValues(
        alpha: stopped ? .18 : .35,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Icon(
                    AppIconography.phone,
                    color: stopped
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          key: _key('runtime'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<VoidCallback>(
                  key: _key('menu'),
                  tooltip: menuTooltip,
                  enabled: !locked,
                  onSelected: (action) => action(),
                  itemBuilder: (context) => [
                    for (final item in menuItems)
                      PopupMenuItem(
                        key: _key(item.keySuffix),
                        value: item.onSelected,
                        child: Text(item.label),
                      ),
                  ],
                ),
              ],
            ),
            if (inProgress)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8, end: 8),
                child: LinearProgressIndicator(key: _key('progress')),
              ),
            if (failure != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8, end: 8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    failure!,
                    key: _key('failure'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (stopped)
                    FilledButton.icon(
                      key: _key('start'),
                      style: FilledButton.styleFrom(minimumSize: touch),
                      onPressed: locked ? null : onStart,
                      icon: const Icon(AppIconography.forward),
                      label: Text(startLabel),
                    )
                  else ...[
                    FilledButton.icon(
                      key: _key('connect'),
                      style: FilledButton.styleFrom(minimumSize: touch),
                      onPressed: locked ? null : onConnect,
                      icon: const Icon(AppIconography.forward),
                      label: Text(connected ? openLabel : connectLabel),
                    ),
                    if (onRestart != null)
                      OutlinedButton.icon(
                        key: _key('restart'),
                        style: OutlinedButton.styleFrom(minimumSize: touch),
                        onPressed: locked ? null : onRestart,
                        icon: const Icon(AppIconography.restart),
                        label: Text(restartLabel),
                      ),
                    if (onStop != null)
                      OutlinedButton.icon(
                        key: _key('stop'),
                        style: OutlinedButton.styleFrom(minimumSize: touch),
                        onPressed: locked ? null : onStop,
                        icon: const Icon(AppIcons.stop),
                        label: Text(stopLabel),
                      ),
                  ],
                ],
              ),
            ),
            if (detailsTitle != null && details.isNotEmpty)
              ExpansionTile(
                tilePadding: const EdgeInsetsDirectional.only(end: 8),
                title: Text(detailsTitle!),
                children: [
                  for (final detail in details)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: detail,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
