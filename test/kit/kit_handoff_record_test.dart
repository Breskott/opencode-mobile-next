// KitHandoffRecord: the record is reviewed before it is sent; the preview is
// folded until asked and shows at most the preview limit.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

Widget _record({
  bool expanded = false,
  String markdown = '# Record\n\nHello',
}) => KitHandoffRecord(
  sizeBytes: 2048,
  omittedMessages: 3,
  redacted: true,
  markdown: markdown,
  path: '.opencode/handoff/record.md',
  initiallyExpanded: expanded,
);

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('the preview is folded until asked', (tester) async {
    await tester.pumpWidget(_app(_record()));
    expect(find.textContaining('Hello'), findsNothing);
  });

  testWidgets('opened at first, it shows the record', (tester) async {
    await tester.pumpWidget(_app(_record(expanded: true)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hello', findRichText: true), findsWidgets);
  });

  kitMotionStillTests(
    'KitHandoffRecord',
    builds: {'folded': () => _record(), 'open': () => _record(expanded: true)},
    changes: {
      'asks for the preview': KitMotionChange(
        build: () => _record(),
        act: (tester, stage) =>
            tester.tap(find.byKey(const ValueKey('handoff-record-toggle'))),
        shows: 'Hide preview',
      ),
    },
  );
}
