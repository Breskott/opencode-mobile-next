import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/core.dart' as xterm;

import '../../l10n/app_localizations.dart';
import '../app_theme.dart';

/// The keys a phone keyboard lacks, for a terminal
/// (docs/design/local-terminal-2026-09-24.md §3). Written for this app;
/// Termux's extra-keys view is GPLv3 and is not used.
enum TerminalBarKey {
  esc('Esc'),
  slash('/'),
  dash('-'),
  pipe('|'),
  home('Home'),
  up('↑'),
  end('End'),
  pageUp('PgUp'),
  tab('Tab'),
  ctrl('Ctrl'),
  alt('Alt'),
  tilde('~'),
  left('←'),
  down('↓'),
  right('→'),
  pageDown('PgDn');

  const TerminalBarKey(this.face);

  /// What the key shows. Key caps are the same in every language.
  final String face;

  /// The two rows, as Termux users know them, plus `| ~`.
  static const rows = [
    [esc, slash, dash, pipe, home, up, end, pageUp],
    [tab, ctrl, alt, tilde, left, down, right, pageDown],
  ];

  bool get isModifier => this == ctrl || this == alt;

  /// The character a symbol key types, or null for a named key.
  String? get text => switch (this) {
    slash => '/',
    dash => '-',
    pipe => '|',
    tilde => '~',
    _ => null,
  };
}

/// [text] as typed with Ctrl and/or Alt held: Ctrl turns a letter or one of
/// `@[\]^_ ?` into its control byte (Ctrl-C is 0x03), Alt puts Esc before
/// it. Only the first character takes the modifiers; text that has no
/// control form (a digit under Ctrl) passes unchanged.
String terminalModifiedText(
  String text, {
  bool ctrl = false,
  bool alt = false,
}) {
  if (text.isEmpty || (!ctrl && !alt)) return text;
  final runes = text.runes.toList();
  var first = String.fromCharCode(runes.first);
  if (ctrl) {
    final control = _controlByte(runes.first);
    if (control != null) first = String.fromCharCode(control);
  }
  if (alt) first = '\x1b$first';
  return first + String.fromCharCodes(runes.skip(1));
}

int? _controlByte(int rune) {
  if (rune >= 0x61 && rune <= 0x7a) return rune - 0x60; // a-z
  if (rune >= 0x40 && rune <= 0x5f) return rune - 0x40; // @ A-Z [ \ ] ^ _
  if (rune == 0x20) return 0; // space: NUL, as in Termux and xterm
  if (rune == 0x3f) return 0x7f; // ?: DEL
  return null;
}

/// The sticky Ctrl and Alt of a [TerminalKeyBar]. A tap latches a modifier
/// for the next key, from the bar or the phone's keyboard; the key releases
/// it.
class TerminalKeyBarController extends ChangeNotifier {
  bool _ctrl = false;
  bool _alt = false;

  bool get ctrl => _ctrl;
  bool get alt => _alt;

  void toggle(TerminalBarKey key) {
    if (key == TerminalBarKey.ctrl) _ctrl = !_ctrl;
    if (key == TerminalBarKey.alt) _alt = !_alt;
    notifyListeners();
  }

  /// The latched modifiers, released.
  ({bool ctrl, bool alt}) take() {
    final held = (ctrl: _ctrl, alt: _alt);
    if (_ctrl || _alt) {
      _ctrl = false;
      _alt = false;
      notifyListeners();
    }
    return held;
  }

  /// Text from the phone's keyboard with the latched modifiers applied.
  String apply(String text) {
    if (!_ctrl && !_alt) return text;
    final held = take();
    return terminalModifiedText(text, ctrl: held.ctrl, alt: held.alt);
  }
}

/// Sends [key] to [terminal] as a real keyboard would, so programs in
/// application-cursor mode (vim, less, htop) get the sequences they expect.
void sendTerminalBarKey(
  xterm.Terminal terminal,
  TerminalBarKey key, {
  bool ctrl = false,
  bool alt = false,
}) {
  final text = key.text;
  if (text != null) {
    terminal.textInput(terminalModifiedText(text, ctrl: ctrl, alt: alt));
    return;
  }
  final named = switch (key) {
    TerminalBarKey.esc => xterm.TerminalKey.escape,
    TerminalBarKey.tab => xterm.TerminalKey.tab,
    TerminalBarKey.home => xterm.TerminalKey.home,
    TerminalBarKey.end => xterm.TerminalKey.end,
    TerminalBarKey.pageUp => xterm.TerminalKey.pageUp,
    TerminalBarKey.pageDown => xterm.TerminalKey.pageDown,
    TerminalBarKey.up => xterm.TerminalKey.arrowUp,
    TerminalBarKey.down => xterm.TerminalKey.arrowDown,
    TerminalBarKey.left => xterm.TerminalKey.arrowLeft,
    TerminalBarKey.right => xterm.TerminalKey.arrowRight,
    _ => null,
  };
  if (named == null) return;
  // xterm 4.0.0 reads application cursor keys from the keypad mode, so a
  // program that sets only DECCKM would get the wrong arrows from it.
  final arrow = switch (key) {
    TerminalBarKey.up => 'A',
    TerminalBarKey.down => 'B',
    TerminalBarKey.right => 'C',
    TerminalBarKey.left => 'D',
    _ => null,
  };
  if (arrow != null && !ctrl && !alt) {
    terminal.textInput('\x1b${terminal.cursorKeysMode ? 'O' : '['}$arrow');
    return;
  }
  terminal.keyInput(named, ctrl: ctrl, alt: alt);
}

/// Two rows of terminal keys above the phone's keyboard, with sticky Ctrl
/// and Alt. [onKey] gets every non-modifier key with the modifiers that
/// were latched for it.
class TerminalKeyBar extends StatelessWidget {
  const TerminalKeyBar({
    super.key,
    required this.controller,
    required this.onKey,
    this.enabled = true,
    this.compact = false,
  });

  final TerminalKeyBarController controller;
  final void Function(
    TerminalBarKey key, {
    required bool ctrl,
    required bool alt,
  })
  onKey;
  final bool enabled;

  /// One row that scrolls sideways instead of two, for a short screen
  /// (landscape with the keyboard up).
  final bool compact;

  static const keyHeight = 44.0;

  /// A key's width in the one-row form.
  static const compactKeyWidth = 56.0;

  String _label(AppLocalizations l10n, TerminalBarKey key) => switch (key) {
    TerminalBarKey.esc => l10n.e7SetupEscapeKey,
    TerminalBarKey.tab => l10n.e7SetupTabKey,
    TerminalBarKey.up => l10n.e7SetupUpKey,
    TerminalBarKey.down => l10n.e7SetupDownKey,
    TerminalBarKey.left => l10n.e7SetupLeftKey,
    TerminalBarKey.right => l10n.e7SetupRightKey,
    TerminalBarKey.ctrl => l10n.localTerminalKeyCtrl,
    TerminalBarKey.alt => l10n.localTerminalKeyAlt,
    TerminalBarKey.home => l10n.localTerminalKeyHome,
    TerminalBarKey.end => l10n.localTerminalKeyEnd,
    TerminalBarKey.pageUp => l10n.localTerminalKeyPageUp,
    TerminalBarKey.pageDown => l10n.localTerminalKeyPageDown,
    _ => key.face,
  };

  static const _compactOrder = [
    TerminalBarKey.esc,
    TerminalBarKey.ctrl,
    TerminalBarKey.alt,
    TerminalBarKey.tab,
    TerminalBarKey.left,
    TerminalBarKey.up,
    TerminalBarKey.down,
    TerminalBarKey.right,
    TerminalBarKey.slash,
    TerminalBarKey.dash,
    TerminalBarKey.pipe,
    TerminalBarKey.tilde,
    TerminalBarKey.home,
    TerminalBarKey.end,
    TerminalBarKey.pageUp,
    TerminalBarKey.pageDown,
  ];

  void _tap(TerminalBarKey key) {
    HapticFeedback.selectionClick();
    if (key.isModifier) {
      controller.toggle(key);
      return;
    }
    final held = controller.take();
    onKey(key, ctrl: held.ctrl, alt: held.alt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final theme = Theme.of(context);
    Widget keyOf(TerminalBarKey key) => _Key(
      key: ValueKey('terminal-key-${key.name}'),
      face: key.face,
      label: _label(l10n, key),
      latched: switch (key) {
        TerminalBarKey.ctrl => controller.ctrl,
        TerminalBarKey.alt => controller.alt,
        _ => null,
      },
      onTap: enabled ? () => _tap(key) : null,
      theme: theme,
    );
    return Semantics(
      container: true,
      label: l10n.localTerminalKeysLabel,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Directionality(
          // Keys sit where a keyboard has them in every language.
          textDirection: TextDirection.ltr,
          child: compact
              ? SizedBox(
                  height: keyHeight,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // Modifiers and arrows first: what a short screen
                      // needs most.
                      for (final key in _compactOrder)
                        SizedBox(width: compactKeyWidth, child: keyOf(key)),
                    ],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final row in TerminalBarKey.rows)
                      SizedBox(
                        height: keyHeight,
                        child: Row(
                          children: [
                            for (final key in row) Expanded(child: keyOf(key)),
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

class _Key extends StatelessWidget {
  const _Key({
    super.key,
    required this.face,
    required this.label,
    required this.latched,
    required this.onTap,
    required this.theme,
  });

  final String face;
  final String label;

  /// Null for a key that does not latch.
  final bool? latched;
  final VoidCallback? onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final on = latched == true;
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      toggled: latched,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: on ? scheme.primary : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppTheme.radiusControl / 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusControl / 2),
            onTap: onTap,
            child: Center(
              child: Text(
                face,
                maxLines: 1,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontFamily: AppTheme.monoFamily,
                  color: onTap == null
                      ? AppTheme.mutedOf(theme)
                      : on
                      ? scheme.onPrimary
                      : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
