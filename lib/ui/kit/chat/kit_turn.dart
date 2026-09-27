// One turn of a conversation (docs/ux-system/kit-api/KitTurn.md; STATE-16,
// KIT-41, STATE-5, AUTO-15, KIT-23, KIT-28, LOOK-26, LOOK-27): the person's
// prompt, then everything the agent did about it until it handed back, in
// order, with exactly one footer (Copy and More) once the turn has ended and
// none while it runs. The host groups messages into turns and derives the
// phase; the turn only lays them out.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../app_iconography.dart';
import '../kit_copy.dart';
import '../kit_icon_button.dart';
import '../kit_menu.dart';
import '../kit_motion.dart';
import '../kit_since.dart';
import '../kit_text.dart';
import '../kit_tokens.dart';
import 'kit_message.dart';

/// At this text scale and above the footer's meta words move above the
/// buttons, which stay on one row at the end (KitTurn.md Adaptive). The
/// same threshold as KitMessage and KitToolRow.
const double _kWrapTextScale = 1.3;

/// Where a turn stands. The host derives it; the turn only lays it out.
enum KitTurnPhase {
  /// Sent; nothing has come back yet.
  starting,

  /// The agent is working.
  running,

  /// A request in this turn waits for the person.
  waitingForYou,

  /// The agent handed back.
  finished,

  /// The person stopped it.
  stopped,

  /// The server or connection went away before it finished.
  interrupted,

  /// It ended on an error (the error is a KitNotice block).
  failed,
}

/// The one footer of a finished turn (STATE-16).
@immutable
class KitTurnFooter {
  const KitTurnFooter({
    required this.copyText,
    this.meta,
    this.menu = const <KitMenuItem>[],
  });

  /// The whole turn's reply prose, read at tap time (KIT-23). Never tool
  /// output or hidden text. It is copied verbatim (SEC-13): it is the
  /// person's own content.
  final String Function() copyText;

  /// Host words: "Sonnet 4.5 · 12k tokens · 10:42" (the model name as sent,
  /// COPY-2; the host isolates it with KitBidi.auto, COPY-30). Shown only on
  /// the [KitTurn.latest] turn.
  final String? meta;

  /// More: Fork from here, Revert, Read aloud, Details…
  final List<KitMenuItem> menu;
}

/// One turn: a prompt, then everything until the agent hands back, made of
/// steps whose boundaries are not drawn, and notices that do not end it
/// (STANDARDS STATE-16, KIT-41). A finished turn has one footer after its
/// last block; a running turn has none.
///
/// [blocks] is oldest first and holds only kit parts: `KitMessage` (reply,
/// thought, notice, marker), `KitWorkLine`, `KitToolRow` (a lone step),
/// `KitRequestCard` and `KitNotice` (an error). No block draws Copy or More;
/// the footer is the turn's only control row.
///
/// Long-press and right-click on the blocks, Shift+F10 inside the turn, and
/// the turn's semantic custom actions open the footer's menu plus a Copy
/// item, in every phase (running included). A prompt's own menu wins on the
/// prompt.
///
/// States: starting, starting (slow), running, waitingForYou, finished,
/// finished (latest), stopped, interrupted, failed, highlighted (KIT-12).
class KitTurn extends StatelessWidget {
  const KitTurn({
    super.key,
    this.prompt,
    required this.blocks,
    required this.phase,
    this.since,
    this.footer,
    this.latest = false,
    this.highlighted = false,
    this.turnKey,
    this.footerKey,
    this.copyKey,
    this.moreKey,
  });

  /// `KitMessage.prompt`; null for a turn with no prompt of its own (an
  /// automated first turn).
  final KitMessage? prompt;

  /// Oldest first; see the class comment for the allowed parts.
  final List<Widget> blocks;

  final KitTurnPhase phase;

  /// When the turn began, on this phone's clock; drives the starting line's
  /// escalation after `KitMotion.escalateAfter`.
  final DateTime? since;

  /// Drawn only when [phase] is finished, stopped, interrupted or failed.
  final KitTurnFooter? footer;

  /// The newest turn: the footer shows its meta words.
  final bool latest;

  /// The find-in-conversation current match: a surface1 band.
  final bool highlighted;

  final Key? turnKey, footerKey, copyKey, moreKey;

  @override
  Widget build(BuildContext context) => _TurnFrame(turn: this);
}

bool _ended(KitTurnPhase phase) => switch (phase) {
  KitTurnPhase.finished ||
  KitTurnPhase.stopped ||
  KitTurnPhase.interrupted ||
  KitTurnPhase.failed => true,
  KitTurnPhase.starting ||
  KitTurnPhase.running ||
  KitTurnPhase.waitingForYou => false,
};

class _TurnFrame extends StatefulWidget {
  const _TurnFrame({required this.turn});

  final KitTurn turn;

  @override
  State<_TurnFrame> createState() => _TurnFrameState();
}

class _TurnFrameState extends State<_TurnFrame> {
  bool _menuOpen = false;

  KitTurnFooter? get _footer => widget.turn.footer;

  AppLocalizations get _l10n =>
      lookupAppLocalizations(Localizations.localeOf(context));

  /// Verbatim (SEC-13): the reply is the person's own content.
  void _copyReply() {
    final footer = _footer;
    if (footer == null) return;
    KitCopy.copy(context, footer.copyText(), redact: false);
  }

  /// The long-press menu: Copy, then the footer's menu.
  List<KitMenuItem> _menuItems() {
    final footer = _footer;
    if (footer == null) return const <KitMenuItem>[];
    return <KitMenuItem>[
      KitMenuItem(
        label: _l10n.kitTurnCopy,
        icon: AppIconography.copy,
        onSelected: _copyReply,
      ),
      ...footer.menu,
    ];
  }

  Future<void> _openMenu({
    required List<KitMenuItem> items,
    BuildContext? anchor,
    Offset? position,
  }) async {
    if (items.isEmpty || _menuOpen) return;
    _menuOpen = true;
    try {
      await showKitMenu(
        anchor ?? context,
        items: items,
        position: position,
        semanticsLabel: _l10n.kitTurnActions,
      );
    } finally {
      _menuOpen = false;
    }
  }

  void _invoke(KitMenuItem item) {
    final copyText = item.copyText;
    if (copyText != null) {
      KitCopy.copy(context, copyText());
    } else {
      item.onSelected();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isMenuKey =
        key == LogicalKeyboardKey.contextMenu ||
        (key == LogicalKeyboardKey.f10 &&
            HardwareKeyboard.instance.isShiftPressed);
    if (!isMenuKey) return KeyEventResult.ignored;
    final items = _menuItems();
    if (items.isEmpty) return KeyEventResult.ignored;
    _openMenu(items: items);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final turn = widget.turn;
    final tokens = KitTokens.of(context);
    final l10n = _l10n;
    final menuItems = _menuItems();
    final hasMenu = menuItems.isNotEmpty;

    final children = <Widget>[];
    void add(Widget child, double gap) {
      if (children.isNotEmpty) children.add(SizedBox(height: gap));
      children.add(child);
    }

    if (turn.prompt case final prompt?) add(prompt, 0);

    if (turn.blocks.isNotEmpty) {
      Widget blocks = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < turn.blocks.length; i++) ...[
            if (i > 0) SizedBox(height: tokens.space3),
            turn.blocks[i],
          ],
        ],
      );
      if (hasMenu) {
        // Inner parts with their own long-press (a tool row, selectable
        // prose) win the gesture arena; the turn's menu takes the rest.
        blocks = GestureDetector(
          behavior: HitTestBehavior.translucent,
          excludeFromSemantics: true,
          onLongPressStart: (details) =>
              _openMenu(items: menuItems, position: details.globalPosition),
          onSecondaryTapUp: (details) =>
              _openMenu(items: menuItems, position: details.globalPosition),
          child: blocks,
        );
      }
      add(blocks, tokens.space4);
    }

    final phaseLine = _phaseLine(context, turn, l10n);
    if (phaseLine != null) {
      add(phaseLine, turn.blocks.isEmpty ? tokens.space4 : tokens.space3);
    }

    final footer = turn.footer;
    if (footer != null && _ended(turn.phase)) {
      add(_footerRow(context, turn, footer, tokens, l10n), tokens.space1);
    }

    Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );

    body = _HighlightBand(highlighted: turn.highlighted, child: body);

    body = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: body,
    );

    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: tokens.sectionGap),
      child: Semantics(
        key: turn.turnKey,
        container: true,
        explicitChildNodes: true,
        customSemanticsActions: hasMenu
            ? <CustomSemanticsAction, VoidCallback>{
                for (final item in menuItems.where((item) => item.enabled))
                  CustomSemanticsAction(label: item.label): () => _invoke(item),
              }
            : null,
        child: body,
      ),
    );
  }

  Widget? _phaseLine(
    BuildContext context,
    KitTurn turn,
    AppLocalizations l10n,
  ) {
    Widget line(String words) => Align(
      alignment: AlignmentDirectional.topStart,
      child: KitText(
        words,
        role: KitTextRole.secondary,
        tone: KitTextTone.secondary,
      ),
    );
    return switch (turn.phase) {
      KitTurnPhase.starting when turn.blocks.isEmpty => KitSince(
        since: turn.since,
        builder: (context, status) => line(
          status.isSlow
              ? l10n.kitTurnStillStarting(status.elapsed.inSeconds)
              : l10n.kitTurnStarting,
        ),
      ),
      KitTurnPhase.stopped => line(l10n.kitTurnStopped),
      KitTurnPhase.interrupted => line(l10n.kitTurnInterrupted),
      _ => null,
    };
  }

  Widget _footerRow(
    BuildContext context,
    KitTurn turn,
    KitTurnFooter footer,
    KitTokens tokens,
    AppLocalizations l10n,
  ) {
    final meta = turn.latest ? footer.meta : null;
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KitIconButton(
          key: turn.copyKey,
          icon: AppIconography.copy,
          tooltip: l10n.kitTurnCopy,
          onPressed: _copyReply,
        ),
        if (footer.menu.isNotEmpty) ...[
          SizedBox(width: tokens.space2),
          Builder(
            builder: (anchor) => KitIconButton(
              key: turn.moreKey,
              icon: AppIconography.more,
              tooltip: l10n.kitTurnMore,
              onPressed: () => _openMenu(items: footer.menu, anchor: anchor),
            ),
          ),
        ],
      ],
    );
    final metaText = meta == null || meta.isEmpty
        ? null
        : KitText(meta, role: KitTextRole.caption, tone: KitTextTone.tertiary);
    final stacked =
        MediaQuery.textScalerOf(context).scale(1) >= _kWrapTextScale;

    final Widget row;
    if (metaText == null) {
      row = Align(alignment: AlignmentDirectional.centerEnd, child: buttons);
    } else if (stacked) {
      row = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          metaText,
          Align(alignment: AlignmentDirectional.centerEnd, child: buttons),
        ],
      );
    } else {
      row = Row(
        children: [
          Expanded(child: metaText),
          SizedBox(width: tokens.space2),
          buttons,
        ],
      );
    }
    return KeyedSubtree(key: turn.footerKey, child: row);
  }
}

/// The find-in-conversation band: surface1 with the panel radius, painted
/// `space2` outside the turn's content so the layout never moves when the
/// match changes (MOT-5). It cross-fades on `KitMotion.quick`.
class _HighlightBand extends StatelessWidget {
  const _HighlightBand({required this.highlighted, required this.child});

  final bool highlighted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final still = KitMotion.reduced(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: highlighted ? 1 : 0),
      duration: still ? Duration.zero : KitMotion.quick,
      curve: KitMotion.enter,
      builder: (context, amount, child) => CustomPaint(
        painter: amount == 0
            ? null
            : _BandPainter(
                color: tokens.roles.surface1.withValues(
                  alpha: tokens.roles.surface1.a * amount,
                ),
                outset: tokens.space2,
                radius: tokens.panelCornerRadius,
              ),
        child: child,
      ),
      child: child,
    );
  }
}

class _BandPainter extends CustomPainter {
  const _BandPainter({
    required this.color,
    required this.outset,
    required this.radius,
  });

  final Color color;
  final double outset;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).inflate(outset);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_BandPainter old) =>
      old.color != color || old.outset != outset || old.radius != radius;
}
