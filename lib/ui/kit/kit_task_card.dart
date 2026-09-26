// One AI Team task on the board (docs/ux-system/kit-api/KitTaskCard.md;
// kit-v2.md §5 "task card", §9.2; docs/design/team-board-2026-09-26.md §2
// "Card anatomy", where STANDARDS KIT-27/KIT-28 override its "⋯").
import 'package:flutter/material.dart';

import '../app_iconography.dart';
import 'kit_buttons.dart';
import 'kit_icon.dart';
import 'kit_icon_button.dart';
import 'kit_menu.dart';
import 'kit_needs_you.dart';
import 'kit_receipt.dart';
import 'kit_surface.dart';
import 'kit_tappable.dart';
import 'kit_task_mark.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';

/// A task's priority (TB §2; Linear's five levels).
enum KitPriority { urgent, high, normal, low, someday }

/// The one flag line a card may carry. In-flight writes are a receipt,
/// not a flag (see [KitTaskCard.receipt]).
enum KitTaskFlagKind {
  /// KitNeedsYou's word and mark tone (the only attention on a card).
  needsYou,

  /// "Blocked by Sync engine": blocked glyph, text1 (never attention,
  /// LOOK-4).
  blocked,

  /// "Stopped with an error": neutral error glyph, text1 (never red,
  /// LOOK-5).
  failed,

  /// "Cancelled": stop glyph, text2.
  stopped,

  /// "In epic: Onboarding": its own glyph, text2.
  info,
}

/// The card's one flag line.
@immutable
class KitTaskFlag {
  const KitTaskFlag({required this.kind, required this.label, this.icon});

  final KitTaskFlagKind kind;

  /// The whole line, from the host's ARB ("Blocked by {title}"). For
  /// [KitTaskFlagKind.needsYou] it follows KitNeedsYou's "Needs you · ";
  /// an empty label shows the needs-you word alone.
  final String label;

  /// [KitTaskFlagKind.info] only; the other kinds have fixed glyphs.
  final IconData? icon;
}

/// One piece of the meta line; pieces are joined with " · ".
@immutable
class KitTaskMeta {
  const KitTaskMeta(
    this.label, {
    this.icon,
    this.priority,
    this.strong = false,
  });

  /// "High", "Bug", "fox", "12 min ago".
  final String label;

  /// A type glyph (bug, feature, epic).
  final IconData? icon;

  /// Draws [KitPriorityGlyph] before the label.
  final KitPriority? priority;

  /// text1 semibold (urgent and high), otherwise text2.
  final bool strong;
}

/// One task on the AI Team board: its mark, its title in the person's
/// words, one muted meta line and at most one flag line, or a receipt while
/// a move is in flight. A tap opens the task's conversation.
///
/// Contract for the host (LOOK-24, AUTO-17): [onOpen] on a needs-you card
/// opens the conversation scrolled to its `KitRequestCard`. The card never
/// answers, never moves a task and never shows "Done" without the host's
/// echo (STATE-10).
///
/// States: default, needs you, blocked, failed, stopped, done, working
/// (moving receipt), disabled (read-only).
class KitTaskCard extends StatelessWidget {
  const KitTaskCard({
    super.key,
    required this.title,
    required this.mark,
    required this.onOpen,
    this.paused = false,
    this.meta = const [],
    this.flag,
    this.receipt,
    this.action,
    this.menu = const [],
    this.onLongPress,
    this.cardKey,
    this.titleKey,
    this.metaKey,
    this.flagKey,
    this.actionKey,
  }) : assert(
         onLongPress == null || menu.length == 0,
         'KitTaskCard.onLongPress is a compatibility hook for '
         'TeamBoardCardView only: it cannot combine with menu.',
       );

  /// The task's words as written (COPY-2); 2 lines, 3 from 1.3× text.
  final String title;

  final KitTaskState mark;

  /// The task's conversation (scrolled to its request card when needs you).
  final VoidCallback onOpen;

  /// A waiting or working task that is paused (KitTaskMark).
  final bool paused;

  final List<KitTaskMeta> meta;

  final KitTaskFlag? flag;

  /// A move in flight; replaces the flag line while present.
  final KitReceipt? receipt;

  /// ONE trailing icon action (KIT-27), e.g. "Move or change"; its icon and
  /// label are required. Null: none (read-only). Disabled while [receipt]
  /// is sending or sent, with its `disabledReason` as the hint.
  final KitAction? action;

  /// Long-press, right-click, Shift+F10 and semantic actions (KIT-28).
  final List<KitMenuItem> menu;

  /// A compatibility hook for `TeamBoardCardView` only; asserts [menu] is
  /// empty.
  final VoidCallback? onLongPress;

  final Key? cardKey;
  final Key? titleKey;
  final Key? metaKey;
  final Key? flagKey;
  final Key? actionKey;

  bool get _resting =>
      mark == KitTaskState.done || mark == KitTaskState.stopped;

  bool get _moving {
    final state = receipt?.state;
    return state == KitReceiptState.sending || state == KitReceiptState.sent;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final word = KitTaskMark.wordFor(context, mark, paused: paused);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final flag = receipt == null ? this.flag : null;

    final metaStyle = KitText.styleOf(context, KitTextRole.secondary);
    final metaLine = meta.isEmpty
        ? null
        : Padding(
            padding: EdgeInsetsDirectional.only(top: tokens.space1),
            child: KitText.rich(
              TextSpan(
                children: [
                  for (var i = 0; i < meta.length; i++) ...[
                    if (i > 0)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: tokens.space1,
                          ),
                          child: KitText('·', role: KitTextRole.secondary),
                        ),
                      ),
                    ..._metaPiece(context, meta[i], tokens, metaStyle),
                  ],
                ],
              ),
              key: metaKey,
              role: KitTextRole.secondary,
            ),
          );

    final flagLine = flag == null
        ? null
        : Padding(
            key: flagKey,
            padding: EdgeInsetsDirectional.only(top: tokens.space2),
            child: _flagLine(context, flag, tokens),
          );

    // The receipt sits below the card's own node and its action, so a
    // screen reader reads title, action, then receipt (A11Y-4); it keeps
    // its own live region and Try again. A tap on it still opens the task.
    final receiptLine = receipt == null
        ? null
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: onOpen,
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                tokens.space2 + KitTokens.markSlotSize + tokens.space2,
                tokens.space2,
                tokens.space3,
                tokens.space3,
              ),
              child: receipt,
            ),
          );

    final label = [
      title,
      word,
      if (meta.isNotEmpty) meta.map((m) => m.label).join(', '),
      if (flag != null && flag.label.trim().isNotEmpty) flag.label,
    ].join('. ');

    final endPad = action == null
        ? tokens.space3
        : tokens.space2 + tokens.minTarget;
    final main = Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          mark == KitTaskState.needsYou
              ? KitNeedsYou.mark()
              : KitTaskMark(state: mark, paused: paused),
          SizedBox(width: tokens.space2),
          Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(top: tokens.space1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  KitText(
                    title,
                    key: titleKey,
                    role: KitTextRole.rowTitle,
                    tone: _resting ? KitTextTone.secondary : null,
                    maxLines: scale >= 1.3 ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  ?metaLine,
                  ?flagLine,
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final body = KitTappable(
      onTap: onOpen,
      menu: menu,
      onLongPress: onLongPress,
      tooltip: title,
      shape: KitShape.panel,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          tokens.space2,
          tokens.space3,
          endPad,
          receiptLine == null ? tokens.space3 : 0,
        ),
        child: main,
      ),
    );

    final trailing = action;
    Widget card = body;
    if (trailing != null) {
      final disabled = _moving || trailing.onPressed == null;
      card = Stack(
        children: [
          body,
          PositionedDirectional(
            top: tokens.space2,
            end: tokens.space2,
            child: KitIconButton(
              key: actionKey ?? trailing.key,
              icon: trailing.icon ?? AppIconography.more,
              tooltip: trailing.label,
              size: 20,
              shortcut: trailing.shortcut,
              onPressed: disabled ? null : trailing.onPressed,
              disabledReason: disabled ? trailing.disabledReason : null,
            ),
          ),
        ],
      );
    }

    return KeyedSubtree(
      key: cardKey,
      child: KitSurface(
        padding: KitSurfacePadding.none,
        child: receiptLine == null
            ? card
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [card, receiptLine],
              ),
      ),
    );
  }

  List<InlineSpan> _metaPiece(
    BuildContext context,
    KitTaskMeta piece,
    KitTokens tokens,
    TextStyle base,
  ) {
    final roles = tokens.roles;
    final lead = piece.priority != null
        ? KitPriorityGlyph(priority: piece.priority!)
        : piece.icon != null
        ? KitIcon(
            piece.icon!,
            size: KitIconSize.small,
            tone: KitTextTone.secondary,
          )
        : null;
    return [
      if (lead != null)
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: EdgeInsetsDirectional.only(end: tokens.space1),
            child: lead,
          ),
        ),
      TextSpan(
        text: piece.label,
        style: piece.strong
            ? TextStyle(color: roles.text1, fontWeight: FontWeight.w600)
            : null,
      ),
    ];
  }

  Widget _flagLine(BuildContext context, KitTaskFlag flag, KitTokens tokens) {
    final roles = tokens.roles;
    if (flag.kind == KitTaskFlagKind.needsYou) {
      final text = flag.label.trim();
      final span = text.isEmpty
          ? TextSpan(
              text: KitTaskMark.wordFor(context, KitTaskState.needsYou),
              style: KitText.styleOf(
                context,
                KitTextRole.label,
                tone: KitTextTone.attention,
              ),
            )
          : TextSpan(
              children: [
                KitNeedsYou.span(context),
                TextSpan(text: text),
              ],
            );
      return KitText.rich(span, role: KitTextRole.secondary);
    }
    final (
      IconData? glyph,
      KitTextTone tone,
      bool strong,
    ) = switch (flag.kind) {
      KitTaskFlagKind.blocked => (
        AppIconography.blocked,
        KitTextTone.primary,
        true,
      ),
      KitTaskFlagKind.failed => (
        AppIconography.error,
        KitTextTone.primary,
        true,
      ),
      KitTaskFlagKind.stopped => (
        AppIconography.stopCircle,
        KitTextTone.secondary,
        false,
      ),
      KitTaskFlagKind.info ||
      KitTaskFlagKind.needsYou => (flag.icon, KitTextTone.secondary, false),
    };
    final words = KitText.rich(
      TextSpan(
        text: flag.label,
        style: TextStyle(
          color: KitText.toneColor(roles, tone),
          fontWeight: strong ? FontWeight.w600 : null,
        ),
      ),
      role: KitTextRole.secondary,
      tone: tone,
    );
    if (glyph == null) return words;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KitIcon(glyph, size: KitIconSize.small, tone: tone),
        SizedBox(width: tokens.space1),
        Expanded(child: words),
      ],
    );
  }
}

/// Priority as signal bars: three bars filled to the level, a filled
/// square with a bang for urgent, a dashed line for someday. Decorative:
/// the word beside it says the priority. The bars fill from the start edge.
class KitPriorityGlyph extends StatelessWidget {
  const KitPriorityGlyph({super.key, required this.priority});

  final KitPriority priority;

  @override
  Widget build(BuildContext context) {
    final roles = KitTokens.of(context).roles;
    return ExcludeSemantics(
      child: CustomPaint(
        size: const Size.square(20),
        painter: _KitPriorityPainter(
          priority: priority,
          lit: roles.text1,
          unlit: roles.surface3,
          dash: roles.text2,
          ink: roles.ground,
          rtl: Directionality.of(context) == TextDirection.rtl,
        ),
      ),
    );
  }
}

class _KitPriorityPainter extends CustomPainter {
  const _KitPriorityPainter({
    required this.priority,
    required this.lit,
    required this.unlit,
    required this.dash,
    required this.ink,
    this.rtl = false,
  });

  final KitPriority priority;
  final Color lit;
  final Color unlit;
  final Color dash;
  final Color ink;
  final bool rtl;

  static int _litBars(KitPriority priority) => switch (priority) {
    KitPriority.urgent || KitPriority.high => 3,
    KitPriority.normal => 2,
    KitPriority.low => 1,
    KitPriority.someday => 0,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (priority == KitPriority.urgent) {
      canvas.drawRRect(
        RRect.fromLTRBR(2, 2, w - 2, h - 2, const Radius.circular(4)),
        Paint()..color = lit,
      );
      final bang = Paint()
        ..color = ink
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas
        ..drawLine(Offset(w / 2, 6), Offset(w / 2, 11), bang)
        ..drawCircle(Offset(w / 2, 14), 1, Paint()..color = ink);
      return;
    }
    if (priority == KitPriority.someday) {
      final paint = Paint()
        ..color = dash
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (var x = 3.0; x < w - 2; x += 5) {
        canvas.drawLine(Offset(x, h / 2), Offset(x + 2, h / 2), paint);
      }
      return;
    }
    final on = _litBars(priority);
    const bar = 4.0;
    const gap = 2.0;
    for (var i = 0; i < 3; i++) {
      var left = 2 + i * (bar + gap);
      if (rtl) left = w - left - bar;
      final top = 17 - 4 - i * 4.0;
      canvas.drawRRect(
        RRect.fromLTRBR(left, top, left + bar, 17, const Radius.circular(1)),
        Paint()..color = i < on ? lit : unlit,
      );
    }
  }

  @override
  bool shouldRepaint(_KitPriorityPainter old) =>
      old.priority != priority ||
      old.lit != lit ||
      old.unlit != unlit ||
      old.dash != dash ||
      old.ink != ink ||
      old.rtl != rtl;
}
