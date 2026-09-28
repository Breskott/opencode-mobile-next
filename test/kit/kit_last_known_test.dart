// KitLastKnown (docs/ux-system/kit-api/KitLastKnown.md, slice-speed-ui):
// what a list held last time, read-only while the live list loads. It says
// how old the rows are and that a fresh read is under way, and its rows do
// nothing when pressed: a remembered label proves nothing about now.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

const _rows = [
  KitLastKnownRow(
    key: ValueKey('row-a'),
    title: 'Fix the login redirect',
    detail: '5m ago',
  ),
  KitLastKnownRow(key: ValueKey('row-b'), title: 'Release notes for 1.0.45'),
];

KitLastKnown _part({bool refreshing = true}) => KitLastKnown(
  rows: _rows,
  updated: 'Updated 5m ago',
  refreshing: refreshing,
  labelKey: const ValueKey('label'),
);

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: ListView(children: [child])),
);

void main() {
  kitMotionStillTests(
    'KitLastKnown',
    builds: {
      'loading': () => _part(),
      'settled': () => _part(refreshing: false),
    },
    changes: {
      'refresh ends': KitMotionChange(
        build: _part,
        act: (tester, stage) => stage.rebuild(_part(refreshing: false)),
        hides: 'Updated 5m ago · Refreshing',
      ),
    },
  );

  testWidgets('says how old the rows are, and that it is refreshing', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_part()));
    expect(find.text('Updated 5m ago · Refreshing'), findsOneWidget);
    expect(find.text('Fix the login redirect'), findsOneWidget);
    expect(find.text('5m ago'), findsOneWidget);
    expect(find.text('Release notes for 1.0.45'), findsOneWidget);

    await tester.pumpWidget(_host(_part(refreshing: false)));
    expect(find.text('Updated 5m ago'), findsOneWidget);
    expect(find.textContaining('Refreshing'), findsNothing);
  });

  testWidgets('rows are read-only: no tap target, no button, no action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(_part()));
    expect(
      find.descendant(
        of: find.byType(KitLastKnown),
        matching: find.byType(KitTappable),
      ),
      findsNothing,
    );
    final row = tester.getSemantics(find.text('Fix the login redirect'));
    expect(row.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    expect(
      row.getSemanticsData().hasAction(SemanticsAction.longPress),
      isFalse,
    );
    // The group says once that these are a memory, not the live list.
    expect(
      find.bySemanticsLabel(RegExp('Fix the login redirect')),
      findsOneWidget,
    );
    expect(
      tester
          .widgetList<Semantics>(
            find.descendant(
              of: find.byType(KitLastKnown),
              matching: find.byType(Semantics),
            ),
          )
          .where(
            (s) =>
                s.properties.hint ==
                'Saved from last time. They open once the live list loads.',
          ),
      hasLength(1),
    );
    semantics.dispose();
  });

  testWidgets('long titles wrap to two lines and never overflow at 2.0 text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: ListView(
            children: const [
              KitLastKnown(
                rows: [
                  KitLastKnownRow(
                    title:
                        'A conversation title that is much longer than the '
                        'narrowest phone can show on one line',
                    detail: '3h ago',
                  ),
                ],
                updated: 'Updated 3h ago',
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
