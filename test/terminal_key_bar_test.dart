import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/kit/terminal_key_bar.dart';
import 'package:xterm/core.dart' as xterm;

// The terminal key bar (docs/design/local-terminal-2026-09-24.md §3): our own
// keys, sticky Ctrl and Alt, and the bytes each key sends.

void main() {
  group('modified text', () {
    test('Ctrl turns letters into control bytes', () {
      expect(terminalModifiedText('c', ctrl: true), '\x03');
      expect(terminalModifiedText('C', ctrl: true), '\x03');
      expect(terminalModifiedText('d', ctrl: true), '\x04');
      expect(terminalModifiedText('r', ctrl: true), '\x12');
      expect(terminalModifiedText('z', ctrl: true), '\x1a');
    });

    test('Ctrl on the symbols that have a control form', () {
      expect(terminalModifiedText('[', ctrl: true), '\x1b');
      expect(terminalModifiedText(r'\', ctrl: true), '\x1c');
      expect(terminalModifiedText('_', ctrl: true), '\x1f');
      expect(terminalModifiedText(' ', ctrl: true), '\x00');
      expect(terminalModifiedText('?', ctrl: true), '\x7f');
    });

    test('text without a control form passes unchanged', () {
      expect(terminalModifiedText('5', ctrl: true), '5');
      expect(terminalModifiedText('é', ctrl: true), 'é');
      expect(terminalModifiedText('\r', ctrl: true), '\r');
    });

    test('Alt puts Esc first; only the first character is modified', () {
      expect(terminalModifiedText('b', alt: true), '\x1bb');
      expect(terminalModifiedText('cd', ctrl: true), '\x03d');
      expect(terminalModifiedText('x', ctrl: true, alt: true), '\x1b\x18');
      expect(terminalModifiedText('ls'), 'ls');
    });
  });

  group('sticky modifiers', () {
    test('Ctrl applies to the next text once, then releases', () {
      final keys = TerminalKeyBarController();
      keys.toggle(TerminalBarKey.ctrl);
      expect(keys.ctrl, isTrue);
      expect(keys.apply('c'), '\x03');
      expect(keys.ctrl, isFalse);
      expect(keys.apply('c'), 'c');
    });

    test('a second tap releases the latch', () {
      final keys = TerminalKeyBarController();
      keys.toggle(TerminalBarKey.ctrl);
      keys.toggle(TerminalBarKey.ctrl);
      expect(keys.apply('c'), 'c');
    });
  });

  group('keys sent to the terminal', () {
    late xterm.Terminal terminal;
    late List<String> sent;

    setUp(() {
      sent = [];
      terminal = xterm.Terminal(onOutput: sent.add);
    });

    test('arrows follow the cursor-key mode programs ask for', () {
      sendTerminalBarKey(terminal, TerminalBarKey.up);
      // vim and htop switch to application cursor keys.
      terminal.write('\x1b[?1h');
      sendTerminalBarKey(terminal, TerminalBarKey.up);
      expect(sent, ['\x1b[A', '\x1bOA']);
    });

    test('Esc, Tab, symbols and page keys', () {
      sendTerminalBarKey(terminal, TerminalBarKey.esc);
      sendTerminalBarKey(terminal, TerminalBarKey.tab);
      sendTerminalBarKey(terminal, TerminalBarKey.pipe);
      sendTerminalBarKey(terminal, TerminalBarKey.tilde);
      sendTerminalBarKey(terminal, TerminalBarKey.pageUp);
      expect(sent, ['\x1b', '\t', '|', '~', '\x1b[5~']);
    });

    test('Ctrl with an arrow sends the modified sequence', () {
      sendTerminalBarKey(terminal, TerminalBarKey.left, ctrl: true);
      expect(sent, ['\x1b[1;5D']);
    });
  });

  group('the bar', () {
    Future<List<(TerminalBarKey, bool, bool)>> mount(
      WidgetTester tester,
      TerminalKeyBarController keys,
    ) async {
      final pressed = <(TerminalBarKey, bool, bool)>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: TerminalKeyBar(
                controller: keys,
                onKey: (key, {required ctrl, required alt}) =>
                    pressed.add((key, ctrl, alt)),
              ),
            ),
          ),
        ),
      );
      return pressed;
    }

    testWidgets('has every key the spec lists', (tester) async {
      await mount(tester, TerminalKeyBarController());
      for (final key in TerminalBarKey.values) {
        expect(
          find.byKey(ValueKey('terminal-key-${key.name}')),
          findsOneWidget,
          reason: key.name,
        );
      }
    });

    testWidgets('tapping Ctrl latches it for the next key only', (
      tester,
    ) async {
      final keys = TerminalKeyBarController();
      final pressed = await mount(tester, keys);
      await tester.tap(find.byKey(const ValueKey('terminal-key-ctrl')));
      await tester.pump();
      expect(keys.ctrl, isTrue);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('terminal-key-ctrl'))),
        matchesSemantics(
          label: 'Control',
          isButton: true,
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('terminal-key-left')));
      await tester.tap(find.byKey(const ValueKey('terminal-key-left')));
      expect(pressed, [
        (TerminalBarKey.left, true, false),
        (TerminalBarKey.left, false, false),
      ]);
      expect(keys.ctrl, isFalse);
    });

    testWidgets('every key is at least 44 by 48 on a phone', (tester) async {
      tester.view
        ..physicalSize = const Size(412, 915)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await mount(tester, TerminalKeyBarController());
      for (final key in TerminalBarKey.values) {
        final size = tester.getSize(
          find.byKey(ValueKey('terminal-key-${key.name}')),
        );
        expect(size.height, greaterThanOrEqualTo(44), reason: key.name);
        expect(size.width, greaterThanOrEqualTo(48), reason: key.name);
      }
    });
  });
}
