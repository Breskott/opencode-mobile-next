// Chat input bugs: touch targets and the first Send tap.
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/chat/kit_composer.dart';
import 'package:opencode_mobile/ui/kit/kit_code_block.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Align(alignment: Alignment.bottomCenter, child: child),
  ),
);

Future<void> _composer(
  WidgetTester t,
  TextEditingController c,
  FocusNode f,
  void Function() onSend,
) => t.pumpWidget(
  _app(
    KitComposer(
      controller: c,
      focusNode: f,
      hint: 'Ask',
      onSend: onSend,
      onVoice: () {},
      sendKey: const Key('s'),
      voiceButtonKey: const Key('v'),
    ),
  ),
);

Size _target(WidgetTester t, Finder f) {
  // The hit area: the render box of the tappable that owns the key.
  return t.getSize(f);
}

void main() {
  testWidgets('composer Send and Mic hit areas are at least 48 dp', (t) async {
    final c = TextEditingController(text: 'hi');
    final f = FocusNode();
    addTearDown(c.dispose);
    addTearDown(f.dispose);
    await _composer(t, c, f, () {});
    expect(
      _target(t, find.byKey(const Key('s'))).shortestSide,
      greaterThanOrEqualTo(48),
    );
    c.clear();
    await t.pump();
    expect(
      _target(t, find.byKey(const Key('v'))).shortestSide,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('code block Copy and Wrap hit areas are at least 48 x 48', (
    t,
  ) async {
    await t.pumpWidget(
      _app(
        SizedBox(
          width: 300,
          child: KitCodeBlock(
            text: 'a very long line of code ' * 8,
            fileName: 'a.dart',
          ),
        ),
      ),
    );
    for (final k in ['kit-code-copy', 'kit-code-wrap']) {
      final size = _target(t, find.byKey(ValueKey(k)));
      expect(size.width, greaterThanOrEqualTo(48), reason: k);
      expect(size.height, greaterThanOrEqualTo(48), reason: k);
    }
  });

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('the first ${kind.name} press on Send keeps the field focused '
        'and sends once', (t) async {
      var sends = 0;
      final c = TextEditingController(text: 'hi');
      final f = FocusNode();
      addTearDown(c.dispose);
      addTearDown(f.dispose);
      await _composer(t, c, f, () => sends++);
      f.requestFocus();
      await t.pump();
      expect(f.hasFocus, isTrue);
      final g = await t.startGesture(
        t.getCenter(find.byKey(const Key('s'))),
        kind: kind,
      );
      await t.pump();
      // A press that drops focus hides the keyboard, the page slides down
      // under the finger and the release lands on nothing.
      expect(f.hasFocus, isTrue, reason: 'pressing Send dropped the focus');
      await g.up();
      await t.pump();
      expect(sends, 1);
    });
  }

  testWidgets('a touch tap on Send still sends when the keyboard collapses '
      'between press and release', (t) async {
    var sends = 0;
    final c = TextEditingController(text: 'hi');
    final f = FocusNode();
    addTearDown(c.dispose);
    addTearDown(f.dispose);
    Widget host(double keyboard) => MediaQuery(
      data: MediaQueryData(
        size: const Size(412, 915),
        viewInsets: EdgeInsets.only(bottom: keyboard),
      ),
      child: _app(
        KitComposer(
          controller: c,
          focusNode: f,
          hint: 'Ask',
          onSend: () => sends++,
          onVoice: () {},
          sendKey: const Key('s'),
          voiceButtonKey: const Key('v'),
        ),
      ),
    );
    await t.pumpWidget(host(300));
    f.requestFocus();
    await t.pump();
    final g = await t.startGesture(
      t.getCenter(find.byKey(const Key('s'))),
      kind: PointerDeviceKind.touch,
    );
    await t.pump();
    // The keyboard slides away and the composer moves under the finger.
    await t.pumpWidget(host(0));
    await t.pump(const Duration(milliseconds: 300));
    await g.up();
    await t.pump();
    expect(sends, 1);
  });
}
