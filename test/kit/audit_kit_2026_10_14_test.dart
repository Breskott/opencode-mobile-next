// Kit fixes from the 2026-10-14 UI audit (docs/qa/audit-kit-2026-10-14):
// neutral failure copy, icons that grow with text, a hover border on search,
// one rail for group notes, the long-press chip's hover tooltip.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

Widget _host(Widget child, {double textScale = 1}) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: app!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(child: Center(child: child)),
  ),
);

void main() {
  final roles = ThemeRoles.resolve(AppTheme.dark());

  testWidgets('P2-12: a failed copy is neutral text with the error glyph', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'denied');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(_host(const KitCodeBlock(text: 'ls -la')));
    await tester.tap(find.byKey(const ValueKey('kit-code-copy')));
    await tester.pump();
    await tester.pump();
    final failed = find.byKey(const ValueKey('kit-code-copy-failed'));
    expect(failed, findsOneWidget);
    final icon = tester.widget<Icon>(
      find.descendant(of: failed, matching: find.byType(Icon)),
    );
    expect(icon.icon, AppIconography.error);
    final texts = tester.widgetList<RichText>(
      find.descendant(of: failed, matching: find.byType(RichText)),
    );
    for (final t in texts) {
      expect(t.text.style?.color, isNot(roles.danger));
    }
    expect(icon.color, isNot(roles.danger));
  });

  testWidgets('P2-12: a top bar subtitle on a failure is not red', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 400,
          height: 200,
          child: KitScreen(
            topBar: KitTopBar(
              title: 'Server',
              subtitle: 'Offline',
              subtitleTone: AppStatusTone.failure,
            ),
            body: SizedBox.shrink(),
          ),
        ),
      ),
    );
    final rich = tester
        .widgetList<RichText>(find.byType(RichText))
        .where((r) => r.text.toPlainText().contains('Offline'));
    expect(rich, isNotEmpty);
    for (final r in rich) {
      r.text.visitChildren((span) {
        if (span is TextSpan && span.text == 'Offline') {
          expect(span.style?.color, isNot(roles.danger));
        }
        return true;
      });
    }
  });

  testWidgets('P1-9: a chip glyph grows with the text size', (tester) async {
    double glyph(double scale) {
      return tester
          .widget<Icon>(
            find.descendant(
              of: find.byType(KitChip),
              matching: find.byType(Icon),
            ),
          )
          .size!;
    }

    Widget chip() =>
        KitChip.action(label: 'Open', icon: Icons.add, onPressed: () {});
    await tester.pumpWidget(_host(chip()));
    final base = glyph(1);
    await tester.pumpWidget(_host(chip(), textScale: 1.5));
    expect(glyph(1.5), greaterThan(base));
  });

  testWidgets('P2-9: a group note starts on the section label rail', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KitSectionLabel('Servers'),
              KitGroupNote(message: 'Two settings are unavailable'),
            ],
          ),
        ),
      ),
    );
    final label = tester.getTopLeft(find.text('Servers')).dx;
    final note = tester
        .getTopLeft(find.text('Two settings are unavailable'))
        .dx;
    expect(note, label);
  });

  testWidgets('P2-15: a search field border steps up on pointer hover', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 360,
          child: KitSearchField(
            label: 'Search',
            controller: TextEditingController(),
            onChanged: (_) {},
          ),
        ),
      ),
    );
    Color border() {
      final box = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(KitSearchField),
              matching: find.byType(DecoratedBox),
            ),
          )
          .firstWhere(
            (b) =>
                b.decoration is BoxDecoration &&
                (b.decoration as BoxDecoration).border != null,
          );
      return ((box.decoration as BoxDecoration).border! as Border).top.color;
    }

    expect(border(), roles.hairline);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(KitSearchField)));
    await tester.pump();
    expect(border(), roles.text3);
  });

  testWidgets('P3-9: a long-press chip still shows its full label on hover', (
    tester,
  ) async {
    const label = 'A very long label that does not fit in the chip at all';
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 120,
          child: KitChip.action(
            label: label,
            onPressed: () {},
            onLongPress: () {},
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(KitChip)));
    await tester.pump(const Duration(seconds: 2));
    expect(
      find.byWidgetPredicate((w) => w is Tooltip && w.message == label),
      findsOneWidget,
    );
    // The tooltip's own copy is on screen beside the chip's cut-off one.
    expect(find.text(label), findsNWidgets(2));
  });
}
