// KitPhraseChips (the person's own short phrases above the message box): a
// tap chooses, a long-press offers Edit and Hide, empty draws nothing, and
// the still-motion registration G8 requires of every kit part.
import 'kit_motion_still.dart';

import 'package:flutter/material.dart';
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
  home: Scaffold(body: ListView(children: [child])),
);

void main() {
  kitMotionStillTests(
    'KitPhraseChips',
    builds: {
      'default': () => KitPhraseChips(
        phrases: const ['Continue', 'Run the tests'],
        onChoose: (_) {},
        onEdit: (_) {},
        onHide: (_) {},
      ),
    },
  );

  testWidgets('a tap chooses the phrase; the menu edits or hides it', (
    tester,
  ) async {
    final chosen = <String>[];
    final edited = <String>[];
    final hidden = <String>[];
    await tester.pumpWidget(
      _host(
        KitPhraseChips(
          phrases: const ['Continue', 'Run the tests'],
          onChoose: chosen.add,
          onEdit: edited.add,
          onHide: hidden.add,
        ),
      ),
    );
    await tester.tap(find.text('Run the tests'));
    await tester.pumpAndSettle();
    expect(chosen, ['Run the tests']);

    await tester.longPress(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(edited, ['Continue']);

    await tester.longPress(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide'));
    await tester.pumpAndSettle();
    expect(hidden, ['Continue']);
  });

  testWidgets('no phrases draws nothing', (tester) async {
    await tester.pumpWidget(
      _host(
        KitPhraseChips(
          phrases: const [],
          onChoose: (_) {},
          onEdit: (_) {},
          onHide: (_) {},
        ),
      ),
    );
    expect(find.byType(KitChip), findsNothing);
    expect(find.byType(SingleChildScrollView), findsNothing);
  });

  testWidgets('long phrases at 2.0 text scroll instead of overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        KitPhraseChips(
          phrases: [for (var i = 0; i < 6; i++) 'Run every test file $i'],
          onChoose: (_) {},
          onEdit: (_) {},
          onHide: (_) {},
        ),
        textScale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(KitPhraseChips), const Offset(-600, 0));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
