import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../app_iconography.dart';
import 'kit_bidi.dart';
import 'kit_copy.dart';
import 'kit_layout.dart';
import 'kit_motion.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';

/// The one icon-only control (kit-v2.md §1.10).
///
/// States: disabled, working.
class KitIconButton extends StatefulWidget {
  const KitIconButton({
    super.key,
    required this.icon,
    String? tooltip,

    /// Retired by kit-KitIconButton-v2: use [tooltip]. Forwards to it.
    String? label,
    required this.onPressed,
    this.size = 24,
    this.destructive = false,
    this.working = false,
    this.selected,
    this.shortcut,
    this.disabledReason,
  }) : assert(
         (tooltip ?? label ?? '').length > 0,
         'KitIconButton needs a non-empty tooltip (KIT-22)',
       ),
       assert(size == 20 || size == 22 || size == 24, 'LOOK-33 sizes only'),
       tooltip = tooltip ?? label,
       copyText = null;

  /// Copies what [text] returns, read at tap time, through `KitCopy.copy`.
  /// The glyph turns into a check for `KitMotion.copiedHold`, and "Copied"
  /// is announced once per tap. It never shows a SnackBar.
  const KitIconButton.copy({
    super.key,
    required String Function() text,
    this.tooltip, // null: l10n.kitCopy ("Copy"); prefer a noun: "Copy command"
    this.size = 24,
    this.shortcut,
  }) : copyText = text,
       icon = AppIconography.copy,
       onPressed = null,
       destructive = false,
       working = false,
       selected = null,
       disabledReason = null;

  final IconData icon;

  /// What pressing it does, in the person's words: "Remove header". It is
  /// both the tooltip text and the semantic label. It is null only on
  /// [KitIconButton.copy], where it resolves to l10n.kitCopy.
  final String? tooltip;

  /// Null means disabled (KitButton-style dimming, never partial opacity).
  /// On [KitIconButton.copy] it is null, and the button is still enabled.
  final VoidCallback? onPressed;

  /// The glyph size: 20, 22 or 24 (LOOK-33). It keeps today's default of 24.
  final double size;

  /// Tints the glyph `danger`. Use it only for an act that loses data or
  /// ends running work (LOOK-5); the act itself confirms or offers Undo
  /// (DATA-11).
  final bool destructive;

  /// This tap is in flight (at most a second or two). The glyph becomes the
  /// small spinner and taps are ignored. It is never lasting status
  /// (STATE-7).
  final bool working;

  /// A toggle (follow output, wrap lines). Null means it is not a toggle;
  /// true or false maps to toggled semantics.
  final bool? selected;

  /// The key combination that does the same thing, as the shortcuts help
  /// sheet writes it ("Ctrl+R"). It is shown after the label in the hover
  /// tooltip on a fine pointer. The button does not bind it; the shortcut
  /// layer does.
  final String? shortcut;

  /// Why it is disabled. It goes into the semantic hint and the tooltip.
  /// STATE-8 still requires the host to show it as visible text nearby, or
  /// to hide the button (Appendix A #19).
  final String? disabledReason;

  /// Set only by [KitIconButton.copy].
  final String Function()? copyText;

  @override
  State<KitIconButton> createState() => _KitIconButtonState();
}

class _KitIconButtonState extends State<KitIconButton> {
  Timer? _copiedTimer;
  bool _copied = false;
  bool _focused = false;

  bool get _isCopy => widget.copyText != null;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    if (_isCopy) {
      final value = widget.copyText!();
      unawaited(_copy(value));
      return;
    }
    widget.onPressed?.call();
  }

  Future<void> _copy(String value) async {
    await KitCopy.copy(context, value);
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(KitMotion.copiedHold, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final active = !widget.working && (_isCopy || widget.onPressed != null);
    final tooltipText = widget.tooltip ?? l10n.kitCopy;
    final still = KitMotion.reduced(context);

    final Color glyphColor;
    if (!active && !_isCopy) {
      glyphColor = roles.text3;
    } else if (widget.destructive) {
      glyphColor = roles.danger;
    } else if (widget.selected == true) {
      glyphColor = roles.accent;
    } else {
      glyphColor = roles.text1;
    }

    final Widget glyph;
    if (widget.working) {
      glyph = still
          ? Icon(
              key: const ValueKey('kit-icon-button-working'),
              AppIconography.statusDot,
              size: widget.size,
              color: roles.accent,
            )
          : SizedBox.square(
              key: const ValueKey('kit-icon-button-working'),
              dimension: widget.size,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: roles.accent,
              ),
            );
    } else if (_copied) {
      glyph = Icon(
        key: const ValueKey('kit-icon-button-copied'),
        AppIconography.check,
        size: widget.size,
        color: glyphColor,
      );
    } else {
      glyph = Icon(
        key: const ValueKey('kit-icon-button-icon'),
        widget.icon,
        size: widget.size,
        color: glyphColor,
      );
    }

    final swapped = AnimatedSwitcher(
      duration: still ? Duration.zero : KitMotion.quick,
      switchInCurve: KitMotion.enter,
      switchOutCurve: KitMotion.exit,
      child: glyph,
    );

    Widget control = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox.square(
        dimension: tokens.minTarget,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.selected == true ? roles.surface3 : null,
            shape: BoxShape.circle,
          ),
          child: InkWell(
            onTap: active ? _handleTap : null,
            customBorder: const CircleBorder(),
            hoverColor: roles.surface3,
            focusColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            onFocusChange: (value) => setState(() => _focused = value),
            child: Center(child: swapped),
          ),
        ),
      ),
    );

    if (_focused) {
      control = DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: roles.accent,
            width: KitTokens.focusRingWidth(context),
          ),
        ),
        child: control,
      );
    }

    final String? hint = widget.working
        ? l10n.kitWorking
        : (!active ? widget.disabledReason : widget.shortcut);

    final spans = <InlineSpan>[
      TextSpan(
        text: tooltipText,
        style: KitText.styleOf(
          context,
          KitTextRole.secondary,
          tone: KitTextTone.primary,
        ),
      ),
    ];
    final shortcut = widget.shortcut;
    if (shortcut != null && KitLayout.finePointer(context)) {
      spans
        ..add(const TextSpan(text: '  '))
        ..add(
          TextSpan(
            text: KitBidi.ltr(shortcut),
            style: KitText.styleOf(
              context,
              KitTextRole.mono,
              tone: KitTextTone.secondary,
            ),
          ),
        );
    }

    // Semantics is the outermost widget so the button's own element resolves
    // straight to its RenderSemanticsAnnotations (TEST-5/TEST-1 tooling:
    // `tester.getSemantics(find.byType(KitIconButton))` walks the render
    // tree from the element's own render object outward, and a bare
    // Tooltip's MouseRegion in between would hide this node behind it).
    return Semantics(
      button: true,
      label: tooltipText,
      hint: hint,
      enabled: active,
      toggled: widget.selected,
      onTap: active ? _handleTap : null,
      excludeSemantics: true,
      child: Tooltip(
        richMessage: TextSpan(children: spans),
        excludeFromSemantics: true,
        decoration: BoxDecoration(
          color: tokens.panelSurface,
          borderRadius: BorderRadius.circular(KitTokens.popoverRadius),
        ),
        child: control,
      ),
    );
  }
}
