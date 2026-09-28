import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../app_iconography.dart';
import '../glass/kit_glass.dart';
import '../kit_bottom_inset.dart';
import '../kit_buttons.dart';
import '../kit_chip.dart';
import '../kit_field.dart';
import '../kit_icon.dart';
import '../kit_icon_button.dart';
import '../kit_layout.dart';
import '../kit_level_meter.dart';
import '../kit_motion.dart';
import '../kit_segmented.dart';
import '../kit_tappable.dart';
import '../kit_text.dart';
import '../kit_tokens.dart';
import '../motion/kit_haptics.dart';
import '../motion/kit_motion_parts.dart';
import 'kit_composer_chips.dart';

/// What Send does while a reply is being written.
enum KitComposerDelivery {
  /// The default (P6.6 "Queue over Steer"): sent when the reply finishes.
  afterThisReply,

  /// Steer: reaches the agent at its next step (OpenCode 2 only).
  addToThisTurn,
}

/// Where voice mode stands (P10.3).
enum KitVoicePhase {
  /// Getting the microphone.
  starting,

  /// Recording; the level meter moves.
  listening,

  /// Turning speech into text.
  transcribing,

  /// A voice turn was sent; waiting for the reply.
  waitingReply,

  /// Reading the reply aloud.
  speakingReply,

  /// The reply could not be read automatically; "Read it aloud" is offered.
  replyReady,

  /// A request needs the person; listening waits.
  paused,

  /// The app may not use the microphone: explained in the mode, with a fix.
  micDenied,

  /// The engine failed: the reason, with a fix.
  failed,
}

/// Voice mode's state and actions. Non-null [KitComposer.voice] turns the
/// pill into voice mode.
@immutable
class KitComposerVoice {
  const KitComposerVoice({
    required this.phase,
    required this.onExit,
    this.conversation = false,
    this.level,
    this.listeningSince,
    this.onListen,
    this.onStopListening,
    this.onStopSpeaking,
    this.onReadReply,
    this.readRepliesAloud = false,
    this.onReadRepliesAloudChanged,
    this.reason,
    this.fix,
    this.voiceKey,
  });

  final KitVoicePhase phase;

  /// Leaves voice mode; the draft keeps what was said.
  final VoidCallback onExit;

  /// True: speech is sent and replies loop (voice conversation); false:
  /// dictation into the draft.
  final bool conversation;

  /// 0..1 while listening ([KitLevelMeter.listen]).
  final ValueListenable<double>? level;

  /// When this recording began: the elapsed time ("0:42"), no cap (P10.3).
  final DateTime? listeningSince;

  /// Starts listening (idle, replyReady, after a reply).
  final VoidCallback? onListen;

  /// Ends this recording: dictation fills the draft, conversation sends.
  final VoidCallback? onStopListening;

  /// speakingReply: stop reading aloud.
  final VoidCallback? onStopSpeaking;

  /// replyReady: read the reply by hand.
  final VoidCallback? onReadReply;

  final bool readRepliesAloud;

  /// Null: the "Read replies aloud" toggle is not shown.
  final ValueChanged<bool>? onReadRepliesAloudChanged;

  /// micDenied / failed: the words.
  final String? reason;

  /// micDenied: "Allow microphone"; failed: "Try again".
  final KitAction? fix;

  final Key? voiceKey;
}

/// The composer (VL §5; docs/ux-system/kit-api/KitComposer.md): a surface2
/// glass pill (KitGlass, dimmed) holding attach, the field, the model chip,
/// voice, and send or stop. Send is an accent circle; Stop is a text1
/// circle with a ground square.
///
/// States: idle empty, idle with text, sending, busy empty, busy with text
/// (stop + send, delivery choice), busy with text that cannot send yet,
/// offline, read-only, focused, voice (every [KitVoicePhase]) (KIT-12). No
/// loading or empty state of its own.
///
/// The composer never clears or rewrites [controller]'s text: the host
/// clears it after a send it accepted (DATA-1).
class KitComposer extends StatefulWidget {
  const KitComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onSend,
    this.fieldLabel,
    this.busy = false,
    this.onStop,
    this.stopping = false,
    this.sending = false,
    this.canSendWhileBusy = false,
    this.delivery = KitComposerDelivery.afterThisReply,
    this.onDeliveryChanged,
    this.offline = false,
    this.readOnlyReason,
    this.note,
    this.attachments,
    this.suggestions,
    this.model,
    this.onTools,
    this.toolsDisabledReason,
    this.onVoice,
    this.voice,
    this.onOpenEditor,
    this.onContentInserted,
    this.composerKey,
    this.fieldKey,
    this.sendKey,
    this.stopKey,
    this.toolsKey,
    this.voiceButtonKey,
    this.editorKey,
    this.deliveryKey,
    this.hasAttachments = false,
  });

  /// The message carries attachments or references, so Send is live (and
  /// the editor button shows) even with an empty field (chat-3).
  final bool hasAttachments;

  final TextEditingController controller;
  final FocusNode focusNode;

  /// "Ask OpenCode…", "Ask {agent}…", "Message the team…".
  final String hint;
  final VoidCallback onSend;

  /// The field's accessible name; null: "Message".
  final String? fieldLabel;

  /// A reply is being written.
  final bool busy;

  /// Stop's own tap is in flight.
  final bool stopping;

  /// Send's own tap is in flight.
  final bool sending;

  /// The server accepts a send during a reply.
  final bool canSendWhileBusy;

  /// Send queues: "Send when back online".
  final bool offline;

  /// Null: no Stop (a host that cannot stop).
  final VoidCallback? onStop;
  final KitComposerDelivery delivery;

  /// Null: no choice (the words still say "after this reply").
  final ValueChanged<KitComposerDelivery>? onDeliveryChanged;

  /// Non-null: no typing; the reason is shown in the pill.
  final String? readOnlyReason;

  /// One muted line at the top of the pill ("Goes to the team's planner").
  final String? note;

  /// Non-null: "+" is hidden and this shows in the note line.
  final String? toolsDisabledReason;

  /// [KitComposerChips.attachments], above the field.
  final KitComposerChips? attachments;

  /// [KitComposerChips.suggestions], above the field.
  final KitComposerChips? suggestions;

  /// [KitComposerChips.model], in the bottom row.
  final KitComposerChips? model;

  /// "+": the host's tools sheet (attach, photos, commands…).
  final VoidCallback? onTools;

  /// The mic: the host enters voice mode; null: no voice.
  final VoidCallback? onVoice;

  /// Full-screen editor; shown only when there is text.
  final VoidCallback? onOpenEditor;

  /// Non-null: voice mode.
  final KitComposerVoice? voice;

  /// IME images.
  final ValueChanged<KeyboardInsertedContent>? onContentInserted;

  final Key? composerKey,
      fieldKey,
      sendKey,
      stopKey,
      toolsKey,
      voiceButtonKey,
      editorKey,
      deliveryKey;

  /// Lays [composer] over the bottom of [body] (the transcript) as the
  /// floating navigation layer: [body] scrolls under the glass, and the
  /// composer's height is published with KitBottomInset.add so the last
  /// message, KitJumpPill and KitUndo stay clear of it. The keyboard lifts
  /// the composer; nothing else moves.
  ///
  /// [composer] is the glass [KitComposer], or the host's widget that
  /// builds one. [above] is solid content pinned over the composer (a
  /// request card, a note, a find bar): it sits on the ground, edge to edge
  /// on its own gutters, so the body passes under it unseen; the composer
  /// stays the only glass (visual language §6). The published height
  /// counts both, and the layer never grows past the body: [above] gets
  /// the room the composer leaves. [aboveMinHeight] is kept free for
  /// [above] whatever the composer's height (a waiting request at large
  /// text with the keyboard up): the composer then scrolls within the rest,
  /// its field and Send in view. Zero when [above] has nothing to protect.
  static Widget layer({
    Key? key,
    required Widget body,
    required Widget composer,
    Widget? above,
    double aboveMinHeight = 0,
  }) => _KitComposerLayer(
    key: key,
    body: body,
    composer: composer,
    above: above,
    aboveMinHeight: aboveMinHeight,
  );

  @override
  State<KitComposer> createState() => _KitComposerState();
}

enum _Trailing { mic, send, sendDisabled, sending, stop, stopAndSend, none }

class _KitComposerState extends State<KitComposer> {
  bool _hasText = false;

  /// Esc hid the suggestions; they come back when the text changes or the
  /// host hands new ones.
  bool _suggestionsHidden = false;
  String _textAtHide = '';

  @override
  void initState() {
    super.initState();
    _hasText = _textOf(widget.controller);
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(KitComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
      _hasText = _textOf(widget.controller);
    }
    if (oldWidget.suggestions != widget.suggestions) {
      _suggestionsHidden = false;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  static bool _textOf(TextEditingController c) => c.text.trim().isNotEmpty;

  void _onText() {
    final has = _textOf(widget.controller);
    final unhide = _suggestionsHidden && widget.controller.text != _textAtHide;
    if (has != _hasText || unhide) {
      setState(() {
        _hasText = has;
        if (unhide) _suggestionsHidden = false;
      });
    }
  }

  bool get _hasContent => _hasText || widget.hasAttachments;

  /// The height a touch caret handle hangs below the line it marks (the
  /// Material handle; Cupertino's is shorter).
  static const double _handleClearance = 22;

  bool get _readOnly => widget.readOnlyReason != null;

  bool get _canSendNow =>
      !_readOnly &&
      widget.voice == null &&
      _hasContent &&
      !widget.sending &&
      (!widget.busy || widget.canSendWhileBusy);

  void _send() {
    if (!_canSendNow) return;
    KitHaptics.send(context);
    widget.onSend();
  }

  bool get _suggestionsShown {
    final s = widget.suggestions;
    return s != null &&
        !_suggestionsHidden &&
        (s.suggestions?.isNotEmpty ?? false);
  }

  void _escape() {
    if (_suggestionsShown) {
      setState(() {
        _suggestionsHidden = true;
        _textAtHide = widget.controller.text;
      });
      return;
    }
    final voice = widget.voice;
    if (voice != null) {
      voice.onExit();
      return;
    }
    widget.focusNode.unfocus();
  }

  _Trailing _trailing() {
    if (_readOnly) {
      return widget.busy && widget.onStop != null
          ? _Trailing.stop
          : _Trailing.none;
    }
    final stop = widget.onStop != null;
    if (widget.sending) {
      return widget.busy && stop ? _Trailing.stopAndSend : _Trailing.sending;
    }
    if (widget.busy) {
      if (!_hasContent) return stop ? _Trailing.stop : _Trailing.sendDisabled;
      if (widget.canSendWhileBusy) {
        return stop ? _Trailing.stopAndSend : _Trailing.send;
      }
      return stop ? _Trailing.stop : _Trailing.none;
    }
    if (_hasContent) return _Trailing.send;
    return widget.onVoice != null ? _Trailing.mic : _Trailing.sendDisabled;
  }

  String _sendWords(AppLocalizations l10n) {
    if (widget.sending) return l10n.kitComposerSending;
    if (widget.offline) return l10n.kitComposerSendOffline;
    if (widget.busy) {
      return widget.delivery == KitComposerDelivery.addToThisTurn
          ? l10n.kitComposerAddToTurn
          : l10n.kitComposerSendAfter;
    }
    return l10n.kitComposerSend;
  }

  bool get _deliveryShown =>
      !_readOnly &&
      widget.busy &&
      _hasContent &&
      widget.canSendWhileBusy &&
      widget.onDeliveryChanged != null;

  String? _noteLine(AppLocalizations l10n) {
    final reason = widget.readOnlyReason;
    if (reason != null) return reason;
    final parts = <String>[
      if (widget.note case final note? when note.isNotEmpty) note,
      if (widget.toolsDisabledReason case final r? when r.isNotEmpty) r,
      if (widget.offline) l10n.kitComposerOffline,
      if (widget.busy && _hasContent && !widget.canSendWhileBusy)
        l10n.kitComposerCannotSendYet,
      if (widget.busy &&
          _hasContent &&
          widget.canSendWhileBusy &&
          widget.onDeliveryChanged == null)
        widget.delivery == KitComposerDelivery.addToThisTurn
            ? l10n.kitComposerAddToTurn
            : l10n.kitComposerSendsAfter,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final radius = KitLayout.windowOf(context).isWide
        ? tokens.composerRadiusWide
        : tokens.composerRadius;
    final voice = widget.voice;

    final content = voice == null
        ? KeyedSubtree(
            key: const ValueKey('kit-composer-text'),
            child: _textContent(context, l10n),
          )
        : KeyedSubtree(
            key: const ValueKey('kit-composer-voice'),
            child: _VoiceContent(voice: voice, l10n: l10n),
          );

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _escape},
      child: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: Semantics(
          key: widget.composerKey,
          container: true,
          explicitChildNodes: true,
          child: KitGlass(
            borderRadius: BorderRadius.circular(radius),
            dim: true,
            shadow: true,
            flow: true,
            child: Padding(
              padding: EdgeInsets.all(tokens.space1),
              child: KitSwap(
                pace: KitPace.standard,
                alignment: AlignmentDirectional.bottomCenter,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _textContent(BuildContext context, AppLocalizations l10n) {
    final tokens = KitTokens.of(context);
    final media = MediaQuery.of(context);
    final note = _noteLine(l10n);
    final short = KitLayout.isShort(context);
    // Under [KitComposer.layer] the room is the layer's own height (a page
    // frame has already taken the keyboard off it and hidden the inset);
    // elsewhere, the window less the keyboard.
    final available =
        _KitComposerRoom.of(context) ??
        media.size.height - media.viewInsets.bottom;
    final fieldCap = (available * KitLayout.composerMaxShare)
        .floorToDouble()
        .clamp(tokens.minTarget, double.infinity);
    final readOnly = _readOnly;
    final inserted = widget.onContentInserted;

    final field = ConstrainedBox(
      // At least one 48 dp target tall (LAY-9): the field's own node is
      // the tap target a screen reader and G5 measure.
      constraints: BoxConstraints(
        minHeight: tokens.minTarget,
        maxHeight: fieldCap,
      ),
      // The field needs a Material ancestor; the glass is the composer's
      // own surface, so a host that floats it outside a Scaffold (the
      // layer) still works.
      child: Material(
        type: MaterialType.transparency,
        child: KitField.composer(
          label: widget.fieldLabel ?? l10n.kitComposerField,
          controller: widget.controller,
          hint: widget.hint,
          focusNode: widget.focusNode,
          onSubmitted: (_) => _send(),
          contentInsertion: inserted == null
              ? null
              : ContentInsertionConfiguration(onContentInserted: inserted),
          maxLines: short ? 3 : 8,
          enabled: !readOnly,
          disabledReason: widget.readOnlyReason,
          fieldKey: widget.fieldKey,
        ),
      ),
    );

    final bottomRow = <Widget>[
      if (!readOnly &&
          widget.onTools != null &&
          widget.toolsDisabledReason == null)
        KitIconButton(
          key: widget.toolsKey,
          icon: AppIconography.add,
          tooltip: l10n.kitComposerTools,
          onPressed: widget.onTools,
        ),
      if (!readOnly && widget.model != null)
        Flexible(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: widget.model!,
          ),
        )
      else
        const Spacer(),
      if (!readOnly && _hasContent && widget.onOpenEditor != null)
        KitIconButton(
          key: widget.editorKey,
          icon: AppIconography.expand,
          tooltip: l10n.kitComposerEditor,
          onPressed: widget.onOpenEditor,
        ),
      KitSwap(child: _trailingControl(context, l10n)),
    ];

    // What sits above the field: the note, the delivery choice, the
    // suggestions and the attachments. When they do not fit (large text on
    // a small window, where the delivery choice stacks as radio rows) they
    // scroll and give their room up to the field and the send row, which
    // always stay; nothing is truncated (KIT-24).
    final accessories = <Widget>[
      if (note != null)
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: tokens.space3,
            end: tokens.space3,
            top: tokens.space2,
          ),
          child: KitText(
            note,
            role: KitTextRole.secondary,
            tone: KitTextTone.secondary,
          ),
        ),
      if (_deliveryShown)
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: tokens.space2,
            end: tokens.space2,
            top: tokens.space2,
          ),
          child: KitSegmented<KitComposerDelivery>(
            key: widget.deliveryKey,
            semanticsLabel: l10n.kitComposerDeliveryLabel,
            selected: widget.delivery,
            onChanged: widget.onDeliveryChanged,
            segments: [
              KitSegment(
                value: KitComposerDelivery.afterThisReply,
                label: l10n.kitComposerSendAfterShort,
              ),
              KitSegment(
                value: KitComposerDelivery.addToThisTurn,
                label: l10n.kitComposerAddToTurnShort,
              ),
            ],
          ),
        ),
      if (!readOnly && _suggestionsShown)
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: tokens.space2,
            end: tokens.space2,
            top: tokens.space2,
          ),
          child: widget.suggestions!,
        ),
      if (!readOnly && widget.attachments != null)
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: tokens.space2,
            end: tokens.space2,
            top: tokens.space2,
          ),
          child: widget.attachments!,
        ),
    ];

    final handleClearance = _hasText && available >= 6 * tokens.minTarget
        ? _handleClearance
        : 0.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final above = accessories.isEmpty
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: accessories,
              );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (above != null)
              constraints.hasBoundedHeight
                  ? Flexible(
                      child: SingleChildScrollView(
                        key: const ValueKey<String>('kit-composer-accessories'),
                        child: above,
                      ),
                    )
                  : above,
            Padding(
              // Keyed so a note, suggestions or attachments appearing above it
              // never re-create the field (focus and the keyboard stay).
              key: const ValueKey<String>('kit-composer-field-slot'),
              padding: EdgeInsetsDirectional.only(
                start: tokens.space3,
                end: tokens.space3,
                top: tokens.space2,
                // With words in the field its caret handle can hang below
                // the last line; this keeps it off the send row, so the
                // prompt editor and Send stay pressable (320 dp, 2x text).
                // A short room keeps the height for the field instead.
                bottom: handleClearance,
              ),
              child: field,
            ),
            Row(children: bottomRow),
          ],
        );
      },
    );
  }

  Widget _trailingControl(BuildContext context, AppLocalizations l10n) {
    final tokens = KitTokens.of(context);
    final wide = KitLayout.windowOf(context).isWide;
    final trailing = _trailing();
    final sendShortcut = wide && !_readOnly ? 'Enter' : null;

    Widget stop() => _Circle(
      key: const ValueKey('kit-composer-stop'),
      kind: _CircleKind.stop,
      label: l10n.kitComposerStop,
      tappableKey: widget.stopKey,
      working: widget.stopping,
      disabledReason: widget.stopping ? l10n.kitWorking : null,
      onTap: widget.stopping ? null : widget.onStop,
    );

    Widget send({bool enabled = true}) => _Circle(
      key: const ValueKey('kit-composer-send'),
      kind: enabled ? _CircleKind.send : _CircleKind.sendDisabled,
      label: _sendWords(l10n),
      tappableKey: widget.sendKey,
      shortcut: sendShortcut,
      working: widget.sending,
      disabledReason: widget.sending
          ? l10n.kitComposerSending
          : (enabled ? null : widget.hint),
      onTap: enabled && !widget.sending ? _send : null,
    );

    return switch (trailing) {
      _Trailing.none => const SizedBox.shrink(key: ValueKey('none')),
      _Trailing.mic => _Circle(
        key: const ValueKey('kit-composer-mic'),
        kind: _CircleKind.mic,
        label: l10n.kitComposerVoice,
        tappableKey: widget.voiceButtonKey,
        onTap: widget.onVoice,
      ),
      _Trailing.send => send(),
      _Trailing.sending => send(),
      _Trailing.sendDisabled => send(enabled: false),
      _Trailing.stop => stop(),
      _Trailing.stopAndSend => Row(
        key: const ValueKey('stop-and-send'),
        mainAxisSize: MainAxisSize.min,
        spacing: tokens.space2,
        children: [stop(), send()],
      ),
    };
  }
}

enum _CircleKind { send, sendDisabled, mic, stop, listen, voiceSend, voiceDone }

/// A 40 dp circle in a 48 dp target: Send, the mic, Stop.
class _Circle extends StatelessWidget {
  const _Circle({
    super.key,
    required this.kind,
    required this.label,
    required this.onTap,
    this.tappableKey,
    this.shortcut,
    this.working = false,
    this.disabledReason,
  });

  final _CircleKind kind;
  final String label;
  final VoidCallback? onTap;
  final Key? tappableKey;
  final String? shortcut;
  final bool working;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final stop = kind == _CircleKind.stop;
    final disabled = kind == _CircleKind.sendDisabled;
    final fill = stop
        ? roles.text1
        : disabled
        ? roles.surface3
        : roles.accent;
    final ink = stop
        ? roles.ground
        : disabled
        ? roles.text3
        : roles.onAccent;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final still = KitMotion.reduced(context);

    Widget glyph;
    if (working) {
      glyph = still
          ? Icon(
              AppIconography.statusDot,
              size: KitIconSize.small.logical,
              color: ink,
            )
          : SizedBox.square(
              dimension: KitIconSize.small.logical,
              child: CircularProgressIndicator(strokeWidth: 2, color: ink),
            );
    } else if (stop) {
      const side = KitTokens.composerStopSquare;
      glyph = SizedBox.square(
        key: const ValueKey('kit-composer-stop-square'),
        dimension: side,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(side / 4),
          ),
        ),
      );
    } else {
      final icon = switch (kind) {
        _CircleKind.mic || _CircleKind.listen => AppIconography.mic,
        _CircleKind.voiceDone => AppIconography.check,
        _ => AppIconography.send,
      };
      glyph = Icon(icon, size: KitIconSize.small.logical, color: ink);
      // The send glyph points the way the words go (LAY-8); the mic does
      // not mirror.
      if (rtl && icon == AppIconography.send) {
        glyph = Transform.flip(flipX: true, child: glyph);
      }
    }

    return KitTappable(
      tappableKey: tappableKey,
      shape: KitShape.circle,
      label: label,
      tooltip: label,
      shortcut: shortcut,
      disabledReason: onTap == null ? (disabledReason ?? label) : null,
      onTap: onTap,
      child: SizedBox.square(
        dimension: tokens.minTarget,
        child: Center(
          child: SizedBox.square(
            dimension: KitTokens.composerActionSize,
            child: DecoratedBox(
              key: ValueKey('kit-composer-circle-${kind.name}'),
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              child: Center(child: glyph),
            ),
          ),
        ),
      ),
    );
  }
}

/// Voice mode inside the pill: exit, the level meter with the phase words
/// and elapsed time, the read-aloud toggle, and the trailing circle.
class _VoiceContent extends StatefulWidget {
  const _VoiceContent({required this.voice, required this.l10n});

  final KitComposerVoice voice;
  final AppLocalizations l10n;

  @override
  State<_VoiceContent> createState() => _VoiceContentState();
}

class _VoiceContentState extends State<_VoiceContent> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(_VoiceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  void _syncTimer() {
    final ticking =
        widget.voice.phase == KitVoicePhase.listening &&
        widget.voice.listeningSince != null;
    if (ticking && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!ticking) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _words(AppLocalizations l10n) => switch (widget.voice.phase) {
    KitVoicePhase.starting => l10n.kitVoiceStarting,
    KitVoicePhase.listening => l10n.kitVoiceListening,
    KitVoicePhase.transcribing => l10n.kitVoiceTranscribing,
    KitVoicePhase.waitingReply => l10n.kitVoiceWaitingReply,
    KitVoicePhase.speakingReply => l10n.kitVoiceSpeaking,
    KitVoicePhase.replyReady => l10n.kitVoiceReplyReady,
    KitVoicePhase.paused => l10n.kitVoicePaused,
    KitVoicePhase.micDenied => l10n.kitVoiceMicDenied,
    KitVoicePhase.failed => l10n.kitVoiceFailed,
  };

  String? _elapsed(AppLocalizations l10n) {
    final since = widget.voice.listeningSince;
    if (widget.voice.phase != KitVoicePhase.listening || since == null) {
      return null;
    }
    var seconds = clock.now().difference(since).inSeconds;
    if (seconds < 0) seconds = 0;
    return l10n.kitVoiceElapsed(
      '${seconds ~/ 60}',
      (seconds % 60).toString().padLeft(2, '0'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final l10n = widget.l10n;
    final voice = widget.voice;
    final phase = voice.phase;
    final words = _words(l10n);
    final elapsed = _elapsed(l10n);
    final level = voice.level;
    final problem =
        phase == KitVoicePhase.micDenied || phase == KitVoicePhase.failed;
    final reason = problem ? voice.reason : null;

    final Widget? trailing = switch (phase) {
      KitVoicePhase.listening => _Circle(
        key: const ValueKey('kit-voice-stop-listening'),
        kind: voice.conversation
            ? _CircleKind.voiceSend
            : _CircleKind.voiceDone,
        label: voice.conversation ? l10n.kitVoiceSend : l10n.kitVoiceDone,
        onTap: voice.onStopListening == null
            ? null
            : () {
                if (voice.conversation) KitHaptics.send(context);
                voice.onStopListening!();
              },
        disabledReason: words,
      ),
      KitVoicePhase.speakingReply => _Circle(
        key: const ValueKey('kit-voice-stop-reading'),
        kind: _CircleKind.stop,
        label: l10n.kitVoiceStopReading,
        onTap: voice.onStopSpeaking,
        disabledReason: words,
      ),
      KitVoicePhase.replyReady when voice.onListen != null => _Circle(
        key: const ValueKey('kit-voice-listen'),
        kind: _CircleKind.listen,
        label: l10n.kitVoiceListen,
        onTap: voice.onListen,
      ),
      _ => null,
    };

    final extras = <Widget>[
      if (phase == KitVoicePhase.replyReady && voice.onReadReply != null)
        KitButton.tertiary(
          label: l10n.kitVoiceReadReply,
          onPressed: voice.onReadReply,
        ),
      if (problem && voice.fix != null)
        KitButton.fromAction(
          voice.fix!,
          role: KitButtonRole.tertiary,
          expand: false,
        ),
      if (voice.onReadRepliesAloudChanged != null)
        KitChip.action(
          label: l10n.kitVoiceReadAloud,
          selected: voice.readRepliesAloud,
          onPressed: () =>
              voice.onReadRepliesAloudChanged!(!voice.readRepliesAloud),
        ),
    ];

    final wordsBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (phase == KitVoicePhase.listening && level != null) ...[
              ExcludeSemantics(
                child: KitLevelMeter.listen(listenable: level, active: true),
              ),
              SizedBox(width: tokens.space2),
            ],
            Flexible(
              child: Semantics(
                liveRegion: true,
                container: true,
                label: words,
                excludeSemantics: true,
                // Body, not secondary: the phase words take the field's
                // place as the pill's main line, and 14 dp words beside the
                // meter fall under G5's measured contrast (record §1).
                child: KitText(
                  words,
                  role: KitTextRole.body,
                  tone: KitTextTone.primary,
                ),
              ),
            ),
            if (elapsed != null) ...[
              SizedBox(width: tokens.space2),
              ExcludeSemantics(
                child: KitText(
                  elapsed,
                  role: KitTextRole.secondary,
                  tone: KitTextTone.secondary,
                  tabular: true,
                ),
              ),
            ],
          ],
        ),
        if (reason != null && reason.isNotEmpty)
          KitText(
            reason,
            role: KitTextRole.secondary,
            tone: KitTextTone.secondary,
          ),
      ],
    );

    return Column(
      key: voice.voiceKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            KitIconButton(
              icon: AppIconography.close,
              tooltip: l10n.kitVoiceLeave,
              onPressed: voice.onExit,
            ),
            SizedBox(width: tokens.space1),
            Expanded(child: wordsBlock),
            if (trailing != null) KitSwap(child: trailing),
          ],
        ),
        if (extras.isNotEmpty)
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: tokens.space2,
              end: tokens.space2,
              bottom: tokens.space1,
            ),
            child: Wrap(
              spacing: tokens.space2,
              runSpacing: tokens.space1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: extras,
            ),
          ),
      ],
    );
  }
}

/// [KitComposer.layer]: the body fills the space and scrolls under the
/// glass; the composer floats at the bottom, lifted by the keyboard, and
/// its measured height is published to the body through
/// [KitBottomInset.add].
class _KitComposerLayer extends StatefulWidget {
  const _KitComposerLayer({
    super.key,
    required this.body,
    required this.composer,
    this.above,
    this.aboveMinHeight = 0,
  });

  final Widget body;
  final Widget composer;
  final Widget? above;
  final double aboveMinHeight;

  @override
  State<_KitComposerLayer> createState() => _KitComposerLayerState();
}

class _KitComposerLayerState extends State<_KitComposerLayer> {
  double _height = 0;

  void _onSize(Size size) {
    if (!mounted || size.height == _height) return;
    setState(() => _height = size.height);
  }

  /// [above] on the ground over [composer], within [maxHeight] (null:
  /// unbounded): the composer keeps its height and [above] gets the rest.
  Widget _aboveAndComposer(
    KitTokens tokens,
    double? maxHeight,
    Widget above,
    Widget composer,
  ) {
    final band = ColoredBox(
      color: tokens.roles.ground,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          // The composer's width plus the gutters the parts above draw
          // themselves.
          constraints: BoxConstraints(
            maxWidth: KitLayout.paneDetailMaxWidth + 2 * tokens.gutter,
          ),
          child: above,
        ),
      ),
    );
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        maxHeight == null ? band : Flexible(child: band),
        if (maxHeight == null)
          composer
        else
          // Never taller than the room: on a small window at a large text
          // size (320 dp, 2.5x) the composer scrolls within it, its field
          // and Send in view, instead of running off the screen.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (maxHeight - widget.aboveMinHeight).clamp(
                0.0,
                maxHeight,
              ),
            ),
            child: SingleChildScrollView(
              key: const ValueKey('kit-composer-room'),
              reverse: true,
              primary: false,
              child: composer,
            ),
          ),
      ],
    );
    if (maxHeight == null) return column;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: column,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final inherited = KitBottomInset.of(context).bottom;
    final composer = Padding(
      padding: EdgeInsetsDirectional.only(
        start: tokens.gutter,
        end: tokens.gutter,
        bottom: tokens.space2,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: KitLayout.paneDetailMaxWidth,
          ),
          child: widget.composer,
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          PositionedDirectional(
            start: 0,
            end: 0,
            top: 0,
            bottom: 0,
            child: KitBottomInset.add(extraBottom: _height, child: widget.body),
          ),
          // The composer's band is solid ground from its top edge to the
          // window's bottom edge, across the full width: the transcript
          // scrolls out of sight at the composer and never shows beside
          // or beneath it (owner report, build 2055). The measured height
          // excludes [inherited], which the body already clears.
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: ColoredBox(
              key: const ValueKey('kit-composer-band'),
              color: tokens.roles.ground,
              child: Padding(
                padding: EdgeInsetsDirectional.only(bottom: inherited),
                child: _SizeReporter(
                  onSize: _onSize,
                  // One structure with or without [above], so the composer's
                  // field keeps its state and focus when a part comes or goes.
                  child: _aboveAndComposer(
                    tokens,
                    constraints.hasBoundedHeight
                        ? (constraints.maxHeight - inherited).clamp(
                            0.0,
                            double.infinity,
                          )
                        : null,
                    widget.above ?? const SizedBox.shrink(),
                    _KitComposerRoom(
                      height: constraints.hasBoundedHeight
                          ? constraints.maxHeight
                          : null,
                      child: composer,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The height [KitComposer.layer] lays its composer out in: the field's
/// cap is a share of it (KitLayout.composerMaxShare).
class _KitComposerRoom extends InheritedWidget {
  const _KitComposerRoom({required this.height, required super.child});

  final double? height;

  static double? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_KitComposerRoom>()?.height;

  @override
  bool updateShouldNotify(_KitComposerRoom oldWidget) =>
      height != oldWidget.height;
}

/// Reports its child's laid-out size after each layout that changes it.
class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onSize, super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSizeReporter renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSize);

  ValueChanged<Size> onSize;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (size != _last) {
      _last = size;
      final reported = size;
      WidgetsBinding.instance.addPostFrameCallback((_) => onSize(reported));
    }
  }
}
