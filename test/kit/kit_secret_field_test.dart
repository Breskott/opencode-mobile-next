import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

void main() {
  testWidgets('KitSecretField masks until shown, then masks again', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Bearer abc');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        KitSecretField(
          controller: controller,
          label: 'Value',
          showLabel: 'Show value',
          hideLabel: 'Hide value',
        ),
      ),
    );
    TextField field() => tester.widget<TextField>(find.byType(TextField));
    expect(field().obscureText, isTrue);
    expect(field().autocorrect, isFalse);
    expect(field().enableSuggestions, isFalse);

    await tester.tap(find.byTooltip('Show value'));
    await tester.pump();
    expect(field().obscureText, isFalse);

    await tester.tap(find.byTooltip('Hide value'));
    await tester.pump();
    expect(field().obscureText, isTrue);
  });

  testWidgets('KitSecretField cannot be revealed while disabled', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'secret');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        KitSecretField(
          controller: controller,
          label: 'Value',
          showLabel: 'Show value',
          hideLabel: 'Hide value',
          enabled: false,
        ),
      ),
    );
    await tester.tap(find.byTooltip('Show value'), warnIfMissed: false);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isTrue,
    );
  });

  testWidgets('KitIconButton is a labelled 48 dp target', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      _host(
        Center(
          child: KitIconButton(
            icon: Icons.close,
            label: 'Remove header',
            onPressed: () => pressed++,
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(KitIconButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel('Remove header'), findsWidgets);
    await tester.tap(find.byTooltip('Remove header'));
    expect(pressed, 1);
  });
}
