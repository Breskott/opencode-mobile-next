import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/desktop/shortcuts.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

void main() {
  testWidgets('the launcher opened from a Search button is ready to type', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: KitIconButton(
              icon: AppIconography.search,
              tooltip: 'Search',
              onPressed: () => showCommandPalette(context, [
                DesktopCommand(
                  label: 'Open diagnostics',
                  icon: AppIconography.info,
                  onInvoke: () {},
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(AppIconography.search));
    await tester.pumpAndSettle();

    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('command-palette-query')),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.focusNode.hasFocus, isTrue);
  });
}
