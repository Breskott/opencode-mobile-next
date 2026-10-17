import 'package:flutter/material.dart';

import 'kit_bidi.dart';
import 'kit_tappable.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';

/// Which state a [KitFeedItem] names in its meta line.
enum KitFeedStateTone {
  /// "Needs you": amber, the only amber on the list.
  needsYou,

  /// "Working": the accent colour.
  running,

  /// "Failed", "Can't reopen": plain secondary text, never red.
  quiet,
}

/// One conversation in a feed (Chats home), two lines at most: the title on
/// one line, then one meta line in the small size. The meta line holds, in
/// order, the agent's name (only when it is not the default), the state word
/// (only when it matters), the project and the time:
/// "Needs you - shopfront - 2 h ago".
///
/// No preview, no Git mark, no pills: those live inside the conversation.
/// The whole row is one target. Its semantics read as one sentence: title,
/// agent, state, project, time. At large text the title and the meta line
/// each take a second line instead of being cut.
///
/// States: none - a conversation that exists; press, hover and focus come
/// from [KitTappable], and a missing state or time is only its content.
class KitFeedItem extends StatelessWidget {
  const KitFeedItem({
    super.key,
    required this.project,
    required this.title,
    required this.onTap,
    this.agent,
    this.state,
    this.stateTone = KitFeedStateTone.quiet,
    this.time,
    this.semanticsLabel,
    this.tappableKey,
  });

  /// The project's name; a name the server chose, so it is isolated for
  /// bidirectional text here.
  final String project;

  final String title;

  /// The agent's name ('Claude Code'), first in the meta line; null for the
  /// default agent.
  final String? agent;

  /// The state word ("Needs you", "Working", "Failed"); null when nothing
  /// needs saying.
  final String? state;
  final KitFeedStateTone stateTone;

  /// The relative time ("2 h ago").
  final String? time;

  final VoidCallback onTap;

  /// Overrides the spoken sentence; null builds it from the parts.
  final String? semanticsLabel;
  final Key? tappableKey;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final agent = this.agent;
    final state = this.state;
    final time = this.time;
    // From 1.3x text the lines take a second line, so nothing is cut.
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final base = KitText.styleOf(
      context,
      KitTextRole.secondary,
      tone: KitTextTone.secondary,
    );
    final stateColor = switch (stateTone) {
      KitFeedStateTone.needsYou => roles.attention,
      KitFeedStateTone.running => roles.accent,
      KitFeedStateTone.quiet => roles.text2,
    };
    final dot = ' \u00b7 ';
    final words =
        semanticsLabel ?? [title, ?agent, ?state, project, ?time].join(', ');
    final meta = TextSpan(
      style: base,
      children: [
        if (agent != null) TextSpan(text: '${KitBidi.auto(agent)}$dot'),
        if (state != null)
          TextSpan(
            text: '$state$dot',
            style: TextStyle(
              color: stateColor,
              fontWeight: stateTone == KitFeedStateTone.quiet
                  ? null
                  : FontWeight.w600,
            ),
          ),
        TextSpan(text: KitBidi.auto(project)),
        if (time != null) TextSpan(text: '$dot$time'),
      ],
    );
    return KitTappable(
      tappableKey: tappableKey,
      onTap: onTap,
      label: words,
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.gutter,
            vertical: tokens.space3,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: tokens.space1,
                  children: [
                    KitText(
                      KitBidi.auto(title),
                      role: KitTextRole.rowTitle,
                      maxLines: large ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    KitText.rich(
                      meta,
                      role: KitTextRole.secondary,
                      tone: KitTextTone.secondary,
                      maxLines: large ? null : 1,
                      overflow: large ? null : TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
