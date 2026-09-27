// slice-R15: a phone server row (LocalServerRow) shows its own agent mark,
// its own ⋮ menu and a failure in words in the LOOK-5 failure tone (text1,
// never the danger colour).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/widgets/local_server_row.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: ListView(
      children: [
        KitRowGroup(children: [child]),
      ],
    ),
  ),
);

LocalServerRow _row({
  IconData mark = AppIconography.phone,
  String? failure,
  bool connected = false,
  VoidCallback? onDetails,
}) => LocalServerRow(
  keyPrefix: 'row',
  mark: mark,
  title: 'Claude Code on this phone',
  status: 'Running',
  connectedLabel: 'Connected',
  stopped: false,
  locked: false,
  inProgress: false,
  connected: connected,
  failure: failure,
  menuTooltip: 'More for Claude Code',
  menuItems: [
    LocalServerRowMenuItem(
      keySuffix: 'details',
      label: 'Details',
      onSelected: onDetails ?? () {},
    ),
  ],
  startLabel: 'Start',
  restartLabel: 'Restart',
  stopLabel: 'Stop Claude Code',
  onRestart: () {},
  onStop: () {},
);

void main() {
  testWidgets('each agent leads with its own mark; OpenCode keeps the phone', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_row(mark: AppIconography.agent)));
    expect(find.byIcon(AppIconography.agent), findsOneWidget);
    expect(find.byIcon(AppIconography.phone), findsNothing);

    await tester.pumpWidget(_app(_row()));
    expect(find.byIcon(AppIconography.phone), findsOneWidget);
    expect(find.byIcon(AppIconography.agent), findsNothing);

    // In use: the same mark, filled.
    await tester.pumpWidget(
      _app(_row(mark: AppIconography.agent, connected: true)),
    );
    expect(find.byKey(const ValueKey('kit-row-current-mark')), findsOneWidget);
    expect(find.byIcon(AppIconography.agent), findsOneWidget);
  });

  testWidgets('the row has its own ⋮ menu with its acts', (tester) async {
    var details = 0;
    await tester.pumpWidget(_app(_row(onDetails: () => details++)));
    final menu = find.byKey(const ValueKey('row-menu'));
    expect(menu, findsOneWidget);
    expect(find.byType(KitRowMenu), findsOneWidget);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Stop Claude Code'), findsOneWidget);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(details, 1);
  });

  testWidgets('a failure is said in words in text1, never the danger colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_row(failure: 'Claude Code didn’t start. Try again.')),
    );
    final failure = find.byKey(const ValueKey('row-failure'));
    expect(failure, findsOneWidget);
    final text = tester.widget<Text>(
      find.descendant(of: failure, matching: find.byType(Text)),
    );
    final roles = KitTokens.of(tester.element(failure)).roles;
    final color =
        text.style?.color ??
        DefaultTextStyle.of(tester.element(failure)).style.color;
    expect(color, roles.text1);
    expect(color, isNot(roles.danger));
  });
}
