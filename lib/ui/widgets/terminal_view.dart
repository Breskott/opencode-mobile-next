import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import 'file_preview.dart';

/// A command and what it printed, drawn the way a terminal would: the
/// program picked out of its path, flags and quoted strings apart, the
/// output's own colours kept, and — where it has none — errors, warnings and
/// passes tinted so the result reads at a glance. Long output shows its end
/// first: that is where a build or a test run says how it went.
class TerminalView extends StatefulWidget {
  const TerminalView({
    super.key,
    this.command,
    required this.output,
    this.tailLines = 40,
    this.framed = true,
    this.wrap = true,
  });

  final String? command;
  final String output;
  final int tailLines;

  /// Draws its own tinted box. Off where the host already frames the
  /// output (setup's log panel), so there is one box, not a box in a box.
  final bool framed;

  /// Wraps long lines. Off keeps each line on one line and lets the output
  /// scroll sideways, as a terminal does (setup's apt lines).
  final bool wrap;

  /// Past this many lines the full output opens in the file viewer rather
  /// than inline: laying out tens of thousands of lines stalls a phone.
  static const inlineLineCap = 2000;

  @override
  State<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final palette = _Palette.of(theme);
    final base = theme.textTheme.bodySmall!.copyWith(
      fontFamily: AppTheme.monoFamily,
      height: 1.45,
      color: theme.colorScheme.onSurface,
    );
    final lines = widget.output.isEmpty
        ? const <String>[]
        : widget.output.split('\n');
    final hidden = _all
        ? 0
        : (lines.length - widget.tailLines).clamp(0, 1 << 30);
    final tooLong = lines.length > TerminalView.inlineLineCap;
    final shown = _all && tooLong
        ? lines.sublist(lines.length - TerminalView.inlineLineCap)
        : lines.sublist(hidden);
    final spans = <InlineSpan>[
      if (widget.command case final command? when command.trim().isNotEmpty)
        ..._commandSpans(command.trim(), palette),
      if (widget.command != null && shown.isNotEmpty)
        const TextSpan(text: '\n\n'),
      for (var i = 0; i < shown.length; i++) ...[
        if (i > 0) const TextSpan(text: '\n'),
        ..._outputLineSpans(shown[i], palette),
      ],
    ];
    final text = SelectableText.rich(TextSpan(style: base, children: spans));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: const Key('terminal-view'),
          padding: widget.framed ? const EdgeInsets.all(8) : EdgeInsets.zero,
          decoration: widget.framed
              ? BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? Colors.black.withValues(alpha: .4)
                      : Colors.black.withValues(alpha: .04),
                  borderRadius: BorderRadius.circular(6),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hidden > 0)
                TextButton(
                  key: const Key('terminal-show-earlier'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  onPressed: () => setState(() => _all = true),
                  child: Text(l10n.terminalShowEarlier(hidden)),
                ),
              if (widget.wrap)
                text
              else
                SingleChildScrollView(
                  key: const Key('terminal-view-sideways'),
                  scrollDirection: Axis.horizontal,
                  child: text,
                ),
              if (_all && tooLong)
                TextButton(
                  key: const Key('terminal-open-full'),
                  onPressed: () => showFilePreviewSheet(
                    context,
                    FilePreviewData(
                      name: 'terminal.txt',
                      text: stripAnsi(widget.output),
                    ),
                  ),
                  child: Text(l10n.terminalOpenFull(lines.length)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Palette {
  const _Palette({
    required this.muted,
    required this.program,
    required this.flag,
    required this.string,
    required this.error,
    required this.warning,
    required this.success,
    required this.ansi,
  });

  final Color muted, program, flag, string, error, warning, success;

  /// ANSI colours 0-7 (black … white) in this theme.
  final List<Color> ansi;

  static _Palette of(ThemeData theme) {
    final scheme = theme.colorScheme;
    final success = AppTheme.successOf(theme);
    final warning = AppTheme.statusColor(theme, AppStatusTone.attention);
    return _Palette(
      muted: AppTheme.mutedOf(theme),
      program: scheme.primary,
      // Code roles (visual language §3): flags and strings stand apart
      // from the path (text2) and the program (accent).
      flag: AppTheme.rolesOf(theme).codeType,
      string: AppTheme.rolesOf(theme).codeString,
      error: scheme.error,
      warning: warning,
      success: success,
      ansi: [
        AppTheme.mutedOf(theme),
        scheme.error,
        success,
        warning,
        scheme.primary,
        scheme.tertiary,
        scheme.secondary,
        scheme.onSurface,
      ],
    );
  }
}

final _ansiEscape = RegExp(r'\x1B(?:\[[0-?]*[ -/]*[@-~]|[@-Z\\-_])');
final _sgr = RegExp(r'\x1B\[([0-9;]*)m');

String stripAnsi(String text) => text.replaceAll(_ansiEscape, '');

final _commandToken = RegExp(
  r'''"(?:[^"\\]|\\.)*"|'[^']*'|&&|\|\||[|;<>]|\s+|[^\s|;<>"']+''',
);

/// The command as coloured spans: `$`, then the program with its folder
/// dimmed, flags, strings and operators each in their own shade.
List<InlineSpan> _commandSpans(String command, _Palette palette) {
  final spans = <InlineSpan>[
    TextSpan(
      text: r'$ ',
      style: TextStyle(color: palette.muted),
    ),
  ];
  var expectProgram = true;
  for (final match in _commandToken.allMatches(command)) {
    final token = match[0]!;
    if (token.trim().isEmpty) {
      spans.add(TextSpan(text: token));
    } else if (const {'&&', '||', '|', ';', '<', '>'}.contains(token)) {
      spans.add(
        TextSpan(
          text: token,
          style: TextStyle(color: palette.muted, fontWeight: FontWeight.w700),
        ),
      );
      expectProgram = true;
    } else if (token.startsWith('"') || token.startsWith("'")) {
      spans.add(
        TextSpan(
          text: token,
          style: TextStyle(color: palette.string),
        ),
      );
      expectProgram = false;
    } else if (expectProgram &&
        RegExp(r'^[A-Za-z_][A-Za-z0-9_]*=').hasMatch(token)) {
      // FOO=1 before the program: set-up, not the point.
      spans.add(
        TextSpan(
          text: token,
          style: TextStyle(color: palette.muted),
        ),
      );
    } else if (expectProgram) {
      final slash = token.lastIndexOf('/');
      if (slash > 0 && slash < token.length - 1) {
        spans.add(
          TextSpan(
            text: token.substring(0, slash + 1),
            style: TextStyle(color: palette.muted),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: slash > 0 && slash < token.length - 1
              ? token.substring(slash + 1)
              : token,
          style: TextStyle(color: palette.program, fontWeight: FontWeight.w700),
        ),
      );
      expectProgram = false;
    } else if (token.startsWith('-')) {
      spans.add(
        TextSpan(
          text: token,
          style: TextStyle(color: palette.flag),
        ),
      );
    } else {
      spans.add(TextSpan(text: token));
    }
  }
  return spans;
}

final _failure = RegExp(
  // "0 errors" and "no errors" are good news, not failures.
  r'(?<!(?:\b\d+|\bno) )\b(error|errors|failed|failure|fatal|exception|traceback|panic)\b|✗|✖|\bFAIL\b',
  caseSensitive: false,
);
final _warning = RegExp(r'\bwarn(ing|ings)?\b|⚠', caseSensitive: false);
final _pass = RegExp(
  r'\b(all tests passed|passed|succeeded|successfully|no issues found)\b|✓|✔',
  caseSensitive: false,
);
// Flutter and Dart test progress: "00:07 +6 ~1 -2: name".
final _testProgress = RegExp(r'^(\d+:\d+ )(\+\d+)( ~\d+)?( -\d+)?(:)');

/// One output line as spans: its ANSI colours when it has them; otherwise a
/// tint from what it says.
List<InlineSpan> _outputLineSpans(String line, _Palette palette) {
  if (line.contains('\x1B[')) return _ansiSpans(line, palette);
  final plain = stripAnsi(line);
  if (_testProgress.firstMatch(plain) case final progress?) {
    return [
      TextSpan(
        text: progress[1],
        style: TextStyle(color: palette.muted),
      ),
      TextSpan(
        text: progress[2],
        style: TextStyle(color: palette.success),
      ),
      if (progress[3] != null)
        TextSpan(
          text: progress[3],
          style: TextStyle(color: palette.warning),
        ),
      if (progress[4] != null)
        TextSpan(
          text: progress[4],
          style: TextStyle(color: palette.error),
        ),
      TextSpan(text: progress[5]),
      ..._tinted(plain.substring(progress.end), palette),
    ];
  }
  return _tinted(plain, palette);
}

List<InlineSpan> _tinted(String text, _Palette palette) {
  final color = _failure.hasMatch(text)
      ? palette.error
      : _warning.hasMatch(text)
      ? palette.warning
      : _pass.hasMatch(text)
      ? palette.success
      : null;
  return [
    TextSpan(
      text: text,
      style: color == null ? null : TextStyle(color: color),
    ),
  ];
}

List<InlineSpan> _ansiSpans(String line, _Palette palette) {
  final spans = <InlineSpan>[];
  Color? color;
  var bold = false;
  var faint = false;
  var at = 0;
  void emit(String text) {
    final clean = stripAnsi(text);
    if (clean.isEmpty) return;
    spans.add(
      TextSpan(
        text: clean,
        style: TextStyle(
          color: faint ? palette.muted : color,
          fontWeight: bold ? FontWeight.w700 : null,
        ),
      ),
    );
  }

  for (final match in _sgr.allMatches(line)) {
    emit(line.substring(at, match.start));
    at = match.end;
    final codes = match[1]!.isEmpty
        ? const [0]
        : match[1]!.split(';').map((c) => int.tryParse(c) ?? 0).toList();
    for (var i = 0; i < codes.length; i++) {
      final code = codes[i];
      if (code == 0) {
        color = null;
        bold = false;
        faint = false;
      } else if (code == 1) {
        bold = true;
      } else if (code == 2) {
        faint = true;
      } else if (code == 22) {
        bold = false;
        faint = false;
      } else if (code >= 30 && code <= 37) {
        color = palette.ansi[code - 30];
      } else if (code >= 90 && code <= 97) {
        color = palette.ansi[code - 90];
      } else if (code == 39) {
        color = null;
      } else if (code == 38 || code == 48) {
        // 256-colour and true-colour: skip their arguments.
        i += i + 1 < codes.length && codes[i + 1] == 5 ? 2 : 4;
      }
    }
  }
  emit(line.substring(at));
  return spans.isEmpty ? [const TextSpan(text: '')] : spans;
}
