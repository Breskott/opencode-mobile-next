// KitPlanBlock (one plan of a group of plans): its behaviour, and the
// still-motion registration G8 requires of every kit part.
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

KitPlanBlock _block({VoidCallback? onTap, String? summary = '12% left'}) =>
    KitPlanBlock(
      title: 'Codex',
      titleNote: 'Plus',
      summary: summary,
      summaryKey: const Key('summary'),
      onTap: onTap ?? () {},
      children: const [
        KitWindowRow(
          inline: true,
          title: '5 hours',
          left: .12,
          valueLabel: '12% · 1:25 PM',
        ),
        KitWindowRow(
          inline: true,
          title: 'Week',
          left: .14,
          valueLabel: '14% · Thu',
        ),
      ],
    );

void main() {
  kitMotionStillTests(
    'KitPlanBlock',
    builds: {'default': _block, 'no summary': () => _block(summary: null)},
  );

  testWidgets('the name with its tier, the summary and one line per window; '
      'a tap opens the plan', (tester) async {
    var opened = 0;
    await tester.pumpWidget(_host(_block(onTap: () => opened++)));
    expect(find.text('Codex Plus'), findsOneWidget);
    expect(find.text('12% left'), findsOneWidget);
    expect(find.text('12% · 1:25 PM'), findsOneWidget);
    expect(find.text('14% · Thu'), findsOneWidget);
    await tester.tap(find.text('Codex Plus'));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('one merged label names the plan and how low it is', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(_block()));
    expect(find.bySemanticsLabel('Codex, Plus, 12% left'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('at 2.0 text a long name leaves the summary under it, nothing '
      'cut', (tester) async {
    await tester.pumpWidget(
      _host(
        KitPlanBlock(
          title: 'Team plan for the whole engineering group',
          titleNote: 'Enterprise',
          summary: 'Back at Thursday 1:25 PM',
          summaryKey: const Key('summary'),
          onTap: () {},
        ),
        textScale: 2,
      ),
    );
    final name = tester.getRect(find.textContaining('Team plan'));
    final summary = tester.getRect(find.byKey(const Key('summary')));
    expect(summary.top, greaterThanOrEqualTo(name.bottom));
    expect(tester.takeException(), isNull);
  });
}
