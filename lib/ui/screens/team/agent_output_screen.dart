/// The live output page (02-ux-flows-and-screens §5.2 "Output"): the
/// agent's session transcript as the host streams it, drawn with the
/// chat's own parts ([TeamAgentTranscript]: its words as the reply's prose,
/// its tool calls as the chat's folded work lines, commands in LTR mono).
/// It is the fallback of "Open conversation" when the agent's OpenCode
/// session cannot be read (a team on a computer without a readable store).
///
/// Built from kit parts (screen-team-1): a [KitScreen] with a [KitTopBar]
/// (Live output, the agent by role and name; Copy as its one action), the
/// one [KitStatusLine], the fallback note in a [KitNotice], and the
/// transcript under a [KitJumpPillLayer].
///
/// Follow-latest works like the chat and the shell output sheet: on by
/// default, every new capture scrolls to the end; a drag up stops
/// following so the person can read; the "Jump to latest" pill resumes and
/// jumps. No switch repeats that. Once the host stops serving the session
/// (404) the status line says so and whatever the controller cached stays
/// on screen.
///
/// Never an endless "Connecting…" (design standard §4, the 8 s rule): an
/// agent that is not running says so at once, with the one action that
/// helps; one that runs but has written nothing after 8 s says it is
/// starting (on a phone, with how long it has been: an agent's first words
/// took four minutes on the owner's phone, 2026-09-25).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../domain/orchestration_gateway.dart';
import '../../../state/orchestration.dart';
import '../../app_theme.dart';
import '../../kit/kit.dart';
import '../../widgets/team_now.dart';
import '../../widgets/team_vocabulary.dart';
import '../team_conversation/team_conversation.dart' show TeamAgentTranscript;

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
    final tokens = KitTokens.of(context);
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
    return KitScreen(
      key: const ValueKey('team-agent-output-page'),
      topBar: KitTopBar(
        title: l10n.teamUiAgentOutputTitle,
        // The agent by its role and short name, never the engine's.
        subtitle: agent == null ? null : teamAgentTitle(l10n, agent),
        actions: [
          if (text.isNotEmpty)
            KitAction.copy(
              key: const ValueKey('team-agent-output-copy'),
              label: l10n.teamUiAgentOutputCopy,
              text: () => text,
            ),
        ],
      ),
      header: [
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
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: tokens.gutter,
              vertical: tokens.space1,
            ),
            child: KitNotice(
              key: const ValueKey('team-agent-output-note'),
              icon: AppIconography.info,
              message: note,
              liveRegion: false,
            ),
          ),
      ],
      body: KitJumpPillLayer(
        pill: KitJumpPill(
          pillKey: const ValueKey('team-agent-output-jump'),
          label: l10n.teamUiAgentOutputJump,
          visible: !_follow && canFollow,
          onPressed: () => _setFollow(true),
        ),
        child: NotificationListener<ScrollUpdateNotification>(
          onNotification: _onScroll,
          child: ListView(
            key: const ValueKey('team-agent-output-list'),
            controller: _scroll,
            padding: EdgeInsetsDirectional.fromSTEB(
              tokens.space2,
              tokens.space3,
              tokens.space2,
              KitScreen.endPadding(context),
            ),
            children: [
              if (text.isEmpty)
                Padding(
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: tokens.gutter - tokens.space2,
                  ),
                  child: KitText(
                    l10n.teamUiAgentOutputEmpty,
                    key: const ValueKey('team-agent-output-empty'),
                    role: KitTextRole.secondary,
                    tone: KitTextTone.secondary,
                  ),
                )
              else
                // What it said and did, drawn as the chat draws a reply:
                // prose, and its calls folded into lines.
                TeamAgentTranscript(
                  key: const ValueKey('team-agent-output-text'),
                  text: text,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
