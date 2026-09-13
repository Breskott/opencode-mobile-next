/// The live output page (02-ux-flows-and-screens §5.2 "Output"): the
/// agent's session transcript as the host streams it, monospace and LTR
/// in every locale, one tap away from the Agent detail (§5.3).
///
/// Follow-latest works like the chat and the shell output sheet: on by
/// default, every new capture scrolls to the end; a drag up stops
/// following so the person can read; the Follow switch (or the "Jump to
/// latest" pill) resumes and jumps. Once the host stops serving the
/// session (404) the status line says so and whatever the controller
/// cached stays on screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../state/orchestration.dart';
import '../../app_theme.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

class AgentOutputScreen extends StatefulWidget {
  const AgentOutputScreen({
    super.key,
    required this.controller,
    required this.agentId,
  });

  final OrchestrationController controller;
  final String agentId;

  @override
  State<AgentOutputScreen> createState() => _AgentOutputScreenState();
}

class _AgentOutputScreenState extends State<AgentOutputScreen> {
  /// A drag that leaves less than this above the end still counts as
  /// "at the end" (a nudge does not stop following).
  static const _endSlack = 24.0;

  late AgentOutputTail _tail;
  final _scroll = ScrollController();
  bool _follow = true;

  @override
  void initState() {
    super.initState();
    _tail = widget.controller.watchAgentOutput(widget.agentId)
      ..addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
  }

  @override
  void dispose() {
    _tail.removeListener(_changed);
    widget.controller.unwatchAgentOutput(widget.agentId);
    _scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (_follow) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
    }
  }

  void _jumpToEnd() {
    if (!mounted || !_scroll.hasClients) return;
    final end = _scroll.position.maxScrollExtent;
    if (_scroll.offset != end) _scroll.jumpTo(end);
  }

  void _setFollow(bool value) {
    setState(() => _follow = value);
    if (value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
    }
  }

  bool _onScroll(ScrollUpdateNotification notification) {
    if (_follow &&
        notification.dragDetails != null &&
        notification.metrics.pixels <
            notification.metrics.maxScrollExtent - _endSlack) {
      setState(() => _follow = false);
    }
    return false;
  }

  String? get _name {
    for (final agent in widget.controller.snapshot.agents) {
      if (agent.id == widget.agentId || agent.sessionId == widget.agentId) {
        return agent.name;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final tail = _tail;
    final text = tail.text;
    final (status, tone) = tail.ended
        ? (l10n.teamUiAgentOutputEnded, AppStatusTone.neutral)
        : !tail.available
        ? (l10n.teamUiAgentOutputUnavailable, AppStatusTone.attention)
        : tail.received
        ? (l10n.teamUiAgentOutputLive, AppStatusTone.progress)
        : (l10n.teamUiAgentOutputConnecting, AppStatusTone.neutral);
    final statusColor = tone == AppStatusTone.neutral
        ? muted
        : AppTheme.statusColor(theme, tone);
    final canFollow = !tail.ended && tail.available;
    return Scaffold(
      key: const ValueKey('team-agent-output-page'),
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.teamUiAgentOutputTitle,
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_name case final name?)
              Text(
                name,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
                textDirection: TextDirection.ltr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('team-agent-output-copy'),
            tooltip: l10n.teamUiAgentOutputCopy,
            onPressed: text.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (!context.mounted) return;
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(
                        content: Text(l10n.teamUiCopied),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
            icon: const Icon(AppIconography.copy),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                key: const ValueKey('team-agent-output-status'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      tail.ended
                          ? AppIconography.cloudOff
                          : !tail.available
                          ? AppIconography.warning
                          : AppIconography.statusDot,
                      size: 16,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SwitchListTile.adaptive(
              key: const ValueKey('team-agent-output-follow'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Text(l10n.teamUiAgentOutputFollow),
              value: _follow,
              onChanged: canFollow ? _setFollow : null,
            ),
            const Divider(height: 1),
            Expanded(
              child: Stack(
                children: [
                  NotificationListener<ScrollUpdateNotification>(
                    onNotification: _onScroll,
                    child: ListView(
                      key: const ValueKey('team-agent-output-list'),
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 72),
                      children: [
                        // Output is a terminal transcript: LTR always.
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: text.isEmpty
                              ? Text(
                                  l10n.teamUiAgentOutputEmpty,
                                  key: const ValueKey(
                                    'team-agent-output-empty',
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: muted,
                                  ),
                                )
                              : Text(
                                  text,
                                  key: const ValueKey('team-agent-output-text'),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: AppTheme.monoFamily,
                                    fontSize: AppTheme.codeFontSize,
                                    height: AppTheme.codeLineHeight,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  if (!_follow && canFollow)
                    PositionedDirectional(
                      bottom: 16,
                      start: 0,
                      end: 0,
                      child: Center(
                        child: FilledButton.tonalIcon(
                          key: const ValueKey('team-agent-output-jump'),
                          onPressed: () => _setFollow(true),
                          icon: const Icon(AppIconography.down, size: 18),
                          label: Text(l10n.teamUiAgentOutputJump),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
