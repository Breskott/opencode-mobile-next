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
///
/// Never an endless "Connecting…" (design standard §4, the 8 s rule): an
/// agent that is not running says so at once, with the one action that
/// helps; one that runs but has written nothing after 8 s says it is
/// starting (on a phone, with how long it has been: an agent's first words
/// took four minutes on the owner's phone, 2026-09-25).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../domain/orchestration_gateway.dart';
import '../../../state/orchestration.dart';
import '../../app_theme.dart';
import '../../kit/kit.dart';
import '../../widgets/team_now.dart';
import '../../widgets/team_vocabulary.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

class AgentOutputScreen extends StatefulWidget {
  const AgentOutputScreen({
    super.key,
    required this.controller,
    required this.agentId,
    this.note,
  });

  final OrchestrationController controller;
  final String agentId;

  /// Why this page and not the agent's own conversation (it opened as the
  /// fallback of "Open conversation"); shown under the status line.
  final String? note;

  @override
  State<AgentOutputScreen> createState() => _AgentOutputScreenState();
}

class _AgentOutputScreenState extends State<AgentOutputScreen> {
  /// A drag that leaves less than this above the end still counts as
  /// "at the end" (a nudge does not stop following).
  static const _endSlack = 24.0;

  /// How long a live agent may stay silent before the line says so.
  static const quietAfter = Duration(seconds: 8);

  late AgentOutputTail _tail;
  final _scroll = ScrollController();
  bool _follow = true;
  late final DateTime _openedAt = DateTime.now();
  bool _quiet = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _tail = widget.controller.watchAgentOutput(widget.agentId)
      ..addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
    // After 8 s without a first word, then once a minute for the "so far".
    _clock = Timer(quietAfter, () {
      if (!mounted) return;
      setState(() => _quiet = true);
      _clock = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted && !_tail.received) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
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

  OrchestrationAgent? get _agent {
    for (final agent in widget.controller.snapshot.agents) {
      if (agent.id == widget.agentId || agent.sessionId == widget.agentId) {
        return agent;
      }
    }
    return null;
  }

  /// The status line while nothing has arrived: honest after 8 s.
  (String, AppStatusTone, KitAction?) _waiting(
    AppLocalizations l10n,
    OrchestrationAgent? agent,
  ) {
    final controller = widget.controller;
    if (agent != null && !teamAgentIsLive(agent)) {
      return (
        l10n.teamOutputNotRunning(teamAgentShortName(agent)),
        AppStatusTone.attention,
        teamUnstickAction(
          context,
          controller,
          keyPrefix: 'team-agent-output',
          wake: [agent],
          wakeLabel: l10n.teamAgentStartIt,
        ),
      );
    }
    if (!_quiet) {
      return (l10n.teamUiAgentOutputConnecting, AppStatusTone.neutral, null);
    }
    final hostMode = controller.host?.hostMode ?? controller.config.hostMode;
    if (hostMode == OrchestrationHostMode.phone) {
      final since = agent?.sessionStartedAt ?? _openedAt;
      final age = DateTime.now().difference(since);
      return (
        l10n.teamOutputStartingPhone(
          teamElapsedLabel(l10n, age.isNegative ? Duration.zero : age),
        ),
        AppStatusTone.progress,
        null,
      );
    }
    return (l10n.teamOutputSilent, AppStatusTone.progress, null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final tail = _tail;
    final text = tail.text;
    final agent = _agent;
    final (status, tone, action) = tail.ended
        ? (l10n.teamUiAgentOutputEnded, AppStatusTone.neutral, null)
        : !tail.available
        ? (l10n.teamUiAgentOutputUnavailable, AppStatusTone.attention, null)
        : tail.received
        ? (l10n.teamUiAgentOutputLive, AppStatusTone.progress, null)
        : _waiting(l10n, agent);
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
            // The agent by its role and short name, never the engine's.
            if (agent != null)
              Text(
                teamAgentTitle(l10n, agent),
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
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
            // The one status line (design standard §5): live, connecting,
            // unavailable or ended.
            KitStatusLine(
              key: const ValueKey('team-agent-output-status'),
              icon: tail.ended
                  ? AppIconography.cloudOff
                  : !tail.available
                  ? AppIconography.warning
                  : AppIconography.statusDot,
              tone: tone,
              message: status,
              action: action,
            ),
            if (widget.note case final note?)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: KitNotice(
                  key: const ValueKey('team-agent-output-note'),
                  icon: AppIconography.info,
                  message: note,
                  liveRegion: false,
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
                        child: KitButton.secondary(
                          key: const ValueKey('team-agent-output-jump'),
                          expand: false,
                          onPressed: () => _setFollow(true),
                          icon: AppIconography.down,
                          label: l10n.teamUiAgentOutputJump,
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
