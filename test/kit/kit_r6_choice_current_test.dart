// slice-R6: KitChoiceList keeps "current" (the applied value) apart from
// "selected" (the radio), and a KitChoiceRow carries its own row menu so a
// choice's actions live on the choice they act on.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_choice_list.dart';
import 'package:opencode_mobile/ui/kit/kit_menu.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
  await tester.pump();
}

List<KitChoice<String>> _packs({List<KitMenuItem> fastMenu = const []}) => [
  KitChoice(
    value: 'fast',
    title: 'Fast',
    supporting: 'On this phone',
    menu: fastMenu,
    menuLabel: 'Fast actions',
  ),
  const KitChoice(
    value: 'balanced',
    title: 'Balanced',
    supporting: '153 MB download',
  ),
];

/// A host that owns the selection; [current] is what is applied.
class _Host extends StatefulWidget {
  const _Host({required this.current, this.actsOnTap = false});

  final String? current;
  final bool actsOnTap;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late String? _selected = widget.current;

  @override
  Widget build(BuildContext context) => KitChoiceList<String>.single(
    choices: _packs(),
    selected: _selected,
    current: widget.current,
    actsOnTap: widget.actsOnTap,
    onSelected: (value) => setState(() => _selected = value),
  );
}

/// The whole supporting line of the row titled [title].
String _supporting(WidgetTester tester, String title) {
  final row = find.ancestor(
    of: find.text(title),
    matching: find.byType(KitChoiceRow<String>),
  );
  return tester
      .widgetList<RichText>(
        find.descendant(of: row, matching: find.byType(RichText)),
      )
      .map((text) => text.text.toPlainText())
      .where((text) => text != title)
      .join(' | ');
}

void main() {
  testWidgets('no pending change: nothing says Current', (tester) async {
    await _pump(tester, const _Host(current: 'fast'));
    expect(find.textContaining('Current'), findsNothing);
    // The radio alone marks the applied, selected value.
    expect(
      find.byKey(const ValueKey('kit-choice-mark-radio-selected')),
      findsOneWidget,
    );
  });

  testWidgets('a pending change: Current moves to the applied value only', (
    tester,
  ) async {
    await _pump(tester, const _Host(current: 'fast'));
    await tester.tap(find.text('Balanced'));
    await tester.pump();

    expect(find.textContaining('Current'), findsOneWidget);
    expect(_supporting(tester, 'Fast'), startsWith('Current'));
    // "Balanced · Current · 153 MB download" is impossible: the selected,
    // not-yet-downloaded choice never says Current.
    expect(_supporting(tester, 'Balanced'), isNot(contains('Current')));
    expect(_supporting(tester, 'Balanced'), '153 MB download');

    // Going back to the applied value ends the pending change.
    await tester.tap(find.text('Fast'));
    await tester.pump();
    expect(find.textContaining('Current'), findsNothing);
  });

  testWidgets('a picker that acts on tap never repeats its radio', (
    tester,
  ) async {
    await _pump(tester, const _Host(current: 'fast', actsOnTap: true));
    expect(find.textContaining('Current'), findsNothing);
  });

  testWidgets('sends: a question never says Current', (tester) async {
    await _pump(
      tester,
      KitChoiceList<String>.single(
        choices: _packs(),
        selected: 'balanced',
        current: 'fast',
        sends: true,
        onSelected: (_) {},
      ),
    );
    expect(find.textContaining('Current'), findsNothing);
  });

  testWidgets('KitChoiceRow: current on the selected row stays silent', (
    tester,
  ) async {
    await _pump(
      tester,
      Column(
        children: [
          KitChoiceRow<String>(
            choice: const KitChoice(value: 'a', title: 'Selected'),
            selected: true,
            current: true,
            onTap: () {},
          ),
          KitChoiceRow<String>(
            choice: const KitChoice(value: 'b', title: 'Applied'),
            selected: false,
            current: true,
            onTap: () {},
          ),
        ],
      ),
    );
    expect(find.textContaining('Current'), findsOneWidget);
    expect(_supporting(tester, 'Applied'), 'Current');
  });

  testWidgets('a choice carries its own row menu; the tap still selects', (
    tester,
  ) async {
    final chosen = <String>[];
    var redownloads = 0;
    await _pump(
      tester,
      KitChoiceList<String>.single(
        choices: _packs(
          fastMenu: [
            KitMenuItem(
              label: 'Download Fast again',
              onSelected: () => redownloads++,
            ),
            KitMenuItem(
              label: 'Delete Fast',
              destructive: true,
              onSelected: () {},
            ),
          ],
        ),
        selected: 'fast',
        actsOnTap: false,
        onSelected: chosen.add,
      ),
    );

    // One "More" button, on the choice it acts on, and none elsewhere.
    final more = find.byKey(const ValueKey('kit-row-menu-button'));
    expect(more, findsOneWidget);
    final fastRow = tester.getRect(
      find.ancestor(
        of: find.text('Fast'),
        matching: find.byType(KitChoiceRow<String>),
      ),
    );
    expect(fastRow.contains(tester.getCenter(more)), isTrue);

    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.text('Download Fast again'), findsOneWidget);
    expect(find.text('Delete Fast'), findsOneWidget);
    await tester.tap(find.text('Download Fast again'));
    await tester.pumpAndSettle();
    expect(redownloads, 1);
    expect(chosen, isEmpty, reason: 'the menu never selects');

    await tester.tap(find.text('Balanced'));
    await tester.pump();
    expect(chosen, ['balanced']);
  });

  testWidgets('the row menu opens on long-press too', (tester) async {
    await _pump(
      tester,
      KitChoiceList<String>.single(
        choices: _packs(
          fastMenu: [KitMenuItem(label: 'Delete Fast', onSelected: () {})],
        ),
        selected: 'balanced',
        actsOnTap: false,
        onSelected: (_) {},
      ),
    );
    await tester.longPress(find.text('Fast'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Fast'), findsOneWidget);
  });
}
