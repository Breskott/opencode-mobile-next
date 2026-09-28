// KitTime (F15, emulator QA 2026-09-28): one way to write a time, so the
// Inbox's "as of" and the banner's "at" never disagree — the clock follows
// the device's 12/24-hour setting and the locale, and a moment grows a day
// or a date only when it is not today.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

Future<String> _render(
  WidgetTester tester,
  String Function(BuildContext) words, {
  bool use24h = false,
}) async {
  late String result;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24h),
        child: child!,
      ),
      home: Builder(
        builder: (context) {
          result = words(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return result;
}

void main() {
  final now = DateTime(2026, 9, 28, 23, 40);

  testWidgets('the clock follows the device 12/24-hour setting', (
    tester,
  ) async {
    final at = DateTime(2026, 9, 28, 23, 19);
    expect(await _render(tester, (c) => KitTime.clock(c, at)), '11:19 PM');
    expect(
      await _render(tester, (c) => KitTime.clock(c, at), use24h: true),
      '23:19',
    );
  });

  testWidgets('a moment is the clock today, the day this year, the date '
      'before', (tester) async {
    Future<String> moment(DateTime at) =>
        _render(tester, (c) => KitTime.moment(c, at, now: now));
    expect(await moment(DateTime(2026, 9, 28, 9, 5)), '9:05 AM');
    expect(await moment(DateTime(2026, 9, 25, 20, 19)), 'Sep 25, 8:19 PM');
    expect(await moment(DateTime(2025, 12, 31, 8, 0)), 'Dec 31, 2025, 8:00 AM');
  });

  test('without a tree, the English defaults stand in', () {
    const material = DefaultMaterialLocalizations();
    final at = DateTime(2026, 9, 28, 14, 2);
    expect(KitTime.clockWith(material, at, use24h: false), '2:02 PM');
    expect(KitTime.clockWith(material, at, use24h: true), '14:02');
    expect(
      KitTime.momentWith(
        material,
        at,
        use24h: false,
        now: DateTime(2026, 9, 29),
      ),
      'Sep 28, 2:02 PM',
    );
  });
}
