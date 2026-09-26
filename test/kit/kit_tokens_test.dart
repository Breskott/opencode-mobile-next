// The modal parts read their look from KitTokens (a ThemeExtension), so a
// new visual language lands by changing tokens, not parts.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

void main() {
  testWidgets('a theme\'s tokens reach the sheet and the confirmation', (
    tester,
  ) async {
    final base = AppTheme.dark();
    const surface = Color(0xFF3A1F5C);
    const scrim = Color(0x99102030);
    final theme = base.copyWith(
      extensions: [
        ...base.extensions.values,
        KitTokens.fallback(base).copyWith(
          sheetSurface: surface,
          scrim: scrim,
          sheetRadius: 4,
        ),
      ],
    );
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (inner) {
            context = inner;
            return const Scaffold();
          },
        ),
      ),
    );
    unawaited(
      showKitConfirm(
        context,
        title: 'Delete fox?',
        body: 'Removed from the server.',
        confirmLabel: 'Delete conversation',
      ),
    );
    await tester.pumpAndSettle();
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.backgroundColor, surface);
    expect(
      (sheet.shape! as RoundedRectangleBorder).borderRadius,
      const BorderRadius.vertical(top: Radius.circular(4)),
    );
    expect(
      tester
          .widgetList<ModalBarrier>(find.byType(ModalBarrier))
          .map((b) => b.color),
      contains(scrim),
    );
  });

  test('without an extension the tokens follow the theme', () {
    final theme = AppTheme.light();
    final tokens = KitTokens.fallback(theme);
    expect(tokens.sheetSurface, theme.bottomSheetTheme.modalBackgroundColor);
    expect(tokens.panelSurface, theme.dialogTheme.backgroundColor);
    expect(tokens.danger, theme.colorScheme.error);
    expect(tokens.minTarget, 48);
  });
}
