// The top bar paints no ground of its own: the page's live background shows
// through it, so a strong look does not end in a flat band at the top.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_top_bar.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

void main() {
  testWidgets('KitTopBar leaves the page ground showing at rest', (
    tester,
  ) async {
    const backdrop = Color(0xFF7A3FD0);
    late Color ground;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            ground = KitTokens.of(context).roles.ground;
            return const ColoredBox(
              color: backdrop,
              child: Align(
                alignment: Alignment.topCenter,
                child: KitTopBar(title: 'Appearance'),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(KitTopBar),
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color.a == 1.0,
        ),
      ),
      findsNothing,
      reason: 'no opaque ground band (${ground.toARGB32()}) at rest',
    );
    expect(find.text('Appearance'), findsOneWidget);
  });
}
