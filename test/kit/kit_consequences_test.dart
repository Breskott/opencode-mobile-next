// KitConsequences (docs/design/visual-language-2026-09-26.md §5 "Sheets"):
// the one counted-facts panel a sheet body places wherever the facts
// belong. No states of its own (KIT-12): it only ever shows what it is
// given.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

List<KitConsequence> _items() => const [
  KitConsequence(
    '3 queued prompts will be deleted',
    mark: KitConsequenceMark.lost,
  ),
  KitConsequence(
    'The exported transcript is kept',
    mark: KitConsequenceMark.kept,
  ),
  KitConsequence('This runs in the background'),
];

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  // G8x (MOT-7): a StatelessWidget with no ticker — one build sample.
  kitMotionStillTests(
    'KitConsequences',
    builds: {'default': () => KitConsequences(items: _items())},
  );

  testWidgets(
    'lost is danger, kept is a text2 check, info is a text2 info glyph',
    (tester) async {
      final roles = ThemeRoles.resolve(AppTheme.light());
      await tester.pumpWidget(_host(KitConsequences(items: _items())));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kit-consequences')), findsOneWidget);
      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons, hasLength(3));
      expect(icons[0].icon, AppIconography.warning);
      expect(icons[0].color, roles.danger);
      expect(icons[1].icon, AppIconography.check);
      expect(icons[1].color, roles.text2);
      expect(icons[2].icon, AppIconography.info);
      expect(icons[2].color, roles.text2);
    },
  );

  testWidgets('the separator is one hairline, inset to the text start', (
    tester,
  ) async {
    await tester.pumpWidget(_host(KitConsequences(items: _items())));
    await tester.pumpAndSettle();
    final dividers = tester.widgetList<Divider>(find.byType(Divider));
    expect(dividers, hasLength(2));
    final hairline = KitTokens.hairlineWidth(
      tester.element(find.byType(KitConsequences)),
    );
    for (final divider in dividers) {
      expect(divider.thickness, moreOrLessEquals(hairline));
    }
  });

  testWidgets('the glyphs carry no semantics of their own (STATE-9)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(KitConsequences(items: _items())));
    await tester.pumpAndSettle();
    for (final icon in find.byType(Icon).evaluate()) {
      expect(
        find.ancestor(
          of: find.byWidget(icon.widget),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    }
    handle.dispose();
  });

  test('an icon override replaces the mark\'s own glyph', () {
    const consequence = KitConsequence(
      'the test run',
      mark: KitConsequenceMark.info,
      icon: AppIconography.terminal,
    );
    expect(consequence.icon, AppIconography.terminal);
  });
}
