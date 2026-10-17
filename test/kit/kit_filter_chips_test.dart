// KitFilterChips (filter chips on one line, scrolling sideways when they do
// not fit): its behaviour, and the still-motion registration G8
// requires of every kit part.
import 'kit_motion_still.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

Widget _host(Widget child, {double textScale = 1, bool scroll = true}) =>
    MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
      home: Scaffold(body: scroll ? ListView(children: [child]) : child),
    );

void main() {
  kitMotionStillTests(
    'KitFilterChips',
    builds: {
      'default': () => KitFilterChips(
        chips: [
          KitChip.summary(
            label: 'All projects',
            expanded: false,
            onPressed: () {},
          ),
          KitFilterChip(
            label: 'Needs you · 2',
            needsYou: true,
            selected: true,
            onPressed: () {},
          ),
          KitFilterChip(label: 'Running', selected: false, onPressed: () {}),
        ],
      ),
    },
  );

  testWidgets('stay on one line and scroll sideways when they do not fit; '
      'none is cut or wraps', (tester) async {
    await tester.pumpWidget(
      _host(
        KitFilterChips(
          chips: [
            for (var i = 0; i < 12; i++)
              KitFilterChip(
                label: 'Filter number $i',
                selected: false,
                onPressed: () {},
              ),
          ],
        ),
      ),
    );
    final first = tester.getRect(find.text('Filter number 0'));
    // Every chip is on the first chip's line, none dropped to a second one.
    for (var i = 0; i < 12; i++) {
      final box = tester.getRect(
        find.text('Filter number $i', skipOffstage: false),
      );
      expect(box.top, first.top, reason: 'chip $i');
    }
    // The last chip is off the screen's edge until the line is scrolled.
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(
      tester.getRect(find.text('Filter number 11', skipOffstage: false)).left,
      greaterThan(width),
    );
    await tester.drag(find.byType(KitFilterChips), const Offset(-4000, 0));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('Filter number 11')).right,
      lessThanOrEqualTo(width),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('at 2.0 text the chips still share one line', (tester) async {
    await tester.pumpWidget(
      _host(
        KitFilterChips(
          chips: [
            KitFilterChip(
              label: 'All projects',
              selected: false,
              onPressed: () {},
            ),
            KitFilterChip(
              label: 'Needs you · 2',
              selected: true,
              onPressed: () {},
            ),
            KitFilterChip(label: 'Running', selected: false, onPressed: () {}),
          ],
        ),
        textScale: 2,
      ),
    );
    final top = tester.getRect(find.text('All projects')).top;
    expect(tester.getRect(find.text('Running', skipOffstage: false)).top, top);
    expect(tester.takeException(), isNull);
  });
}
