import 'package:flutter/material.dart';
import '../kit_buttons.dart';
import '../kit_text.dart';
import '../kit_tokens.dart';
import '../kit_tappable.dart';
import 'kit_team_data.dart';

KitTextTone teamTone(KitTeamState state) => switch (state) {
  KitTeamState.needsYou => KitTextTone.attention,
  KitTeamState.failed => KitTextTone.primary,
  _ => KitTextTone.secondary,
};

IconData teamIcon(KitTeamState state) => switch (state) {
  KitTeamState.empty => Icons.inbox_outlined,
  KitTeamState.loading => Icons.hourglass_empty,
  KitTeamState.running => Icons.pending_outlined,
  KitTeamState.needsYou => Icons.notifications_none,
  KitTeamState.stalled => Icons.pause_circle_outline,
  KitTeamState.failed => Icons.error_outline,
  KitTeamState.done => Icons.check_circle_outline,
  KitTeamState.stale => Icons.history,
};

Widget teamRow(
  BuildContext context, {
  required String title,
  required String status,
  KitTeamState state = KitTeamState.done,
  String? detail,
  String? meta,
  VoidCallback? onPressed,
  int? completed,
  int? total,
}) {
  final t = KitTokens.of(context);
  final color = switch (state) {
    KitTeamState.needsYou => t.roles.attention,
    KitTeamState.failed => t.roles.danger,
    _ => t.roles.text2,
  };
  final content = Padding(
    padding: EdgeInsets.symmetric(vertical: t.space3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Icon(teamIcon(state), size: t.smallIconSize, color: color),
        ),
        SizedBox(width: t.space2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KitText(title, role: KitTextRole.rowTitle),
              if (status.isNotEmpty)
                KitText(
                  status,
                  role: KitTextRole.secondary,
                  tone: teamTone(state),
                ),
              if (detail != null)
                KitText(
                  detail,
                  role: KitTextRole.secondary,
                  tone: KitTextTone.secondary,
                ),
              if (meta != null)
                KitText(
                  meta,
                  role: KitTextRole.secondary,
                  tone: KitTextTone.secondary,
                ),
              if (completed != null &&
                  total != null &&
                  total > 0 &&
                  completed >= 0 &&
                  completed <= total)
                Padding(
                  padding: EdgeInsets.only(top: t.space2),
                  child: LinearProgressIndicator(
                    value: completed / total,
                    color: t.roles.text2,
                    backgroundColor: t.roles.surface3,
                    minHeight: t.space1,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  return onPressed == null
      ? content
      : KitTappable(onTap: onPressed, child: content);
}

Widget teamCard(
  BuildContext context, {
  required String title,
  required String status,
  required KitTeamState state,
  String? summary,
  List<KitTeamItem> items = const [],
  List<Widget> content = const [],
  KitAction? primary,
  List<KitAction> actions = const [],
  bool flat = false,
}) {
  final t = KitTokens.of(context);
  final attention = state == KitTeamState.needsYou;
  final mutations =
      state != KitTeamState.stale && state != KitTeamState.loading;
  final column = Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state == KitTeamState.failed || attention) ...[
            ExcludeSemantics(
              child: Icon(
                teamIcon(state),
                color: attention ? t.roles.attention : t.roles.danger,
                size: t.smallIconSize,
              ),
            ),
            SizedBox(width: t.space2),
          ],
          Expanded(
            child: KitText(
              title,
              role: KitTextRole.headline,
              tone: attention ? KitTextTone.attention : KitTextTone.primary,
            ),
          ),
        ],
      ),
      SizedBox(height: t.space1),
      KitText(
        status,
        role: state == KitTeamState.failed
            ? KitTextRole.rowTitle
            : KitTextRole.secondary,
        tone: teamTone(state),
      ),
      if (summary != null) ...[
        SizedBox(height: t.space2),
        KitText(summary, role: KitTextRole.body),
      ],
      for (final item in items)
        teamRow(
          context,
          title: item.title,
          status: '',
          state: item.state,
          detail: item.detail,
          meta: item.meta,
          onPressed: item.onPressed,
        ),
      ...content,
      if (mutations && (primary != null || actions.isNotEmpty)) ...[
        SizedBox(height: t.space3),
        KitActionBlock(primary: primary, tertiary: actions),
      ],
    ],
  );
  if (flat) return column;
  return DecoratedBox(
    decoration: ShapeDecoration(
      color: attention
          ? Color.alphaBlend(
              t.roles.attention.withValues(alpha: .09),
              t.roles.surface1,
            )
          : t.roles.surface1,
      shape: (t.shapeOf(KitShape.card) as RoundedRectangleBorder).copyWith(
        side: attention
            ? BorderSide(color: t.roles.attention.withValues(alpha: .30))
            : BorderSide.none,
      ),
    ),
    child: Padding(padding: EdgeInsets.all(t.space4), child: column),
  );
}
