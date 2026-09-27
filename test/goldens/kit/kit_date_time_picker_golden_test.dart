// Gallery (gate G4) for KitDateTimePicker
// (docs/ux-system/kit-api/KitDateTimePicker.md, "Galleries required"):
// every declared state at 412x915, and the date state at 1280x800 and at
// text 2.0, dark and light. Owner decision 2026-09-27: no Arabic/RTL shots,
// and only the phone and one wide size. Today is fixed at 1 October 2026
// and the chosen day at 3 October 2026 (TEST-11).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_date_time_picker_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_date_time_picker.dart';
import 'package:opencode_mobile/ui/kit/kit_row.dart';

import 'kit_gallery.dart';

const _phone = Size(412, 915);
const _wide = Size(1280, 800);
final _today = DateTime(2026, 10, 1);
final _fixture = DateTime(2026, 10, 3);

Future<void> _date(BuildContext context) => showKitDatePicker(
  context,
  title: 'Due date',
  helper: 'The task shows as late after this day.',
  initial: _fixture,
);

Future<void> _time(BuildContext context) => showKitTimePicker(
  context,
  title: 'Quiet from',
  initial: const TimeOfDay(hour: 22, minute: 0),
);

Future<void> _quietEnd(BuildContext context) => showKitTimePicker(
  context,
  title: 'Quiet until',
  helper: 'Quiet hours start at 07:00.',
  initial: const TimeOfDay(hour: 7, minute: 0),
  validate: (value) => value.hour == 7 && value.minute == 0
      ? 'Same as the start: quiet hours are off'
      : null,
);

Future<void> _typeDate(WidgetTester tester, String text) async {
  await tester.tap(find.text('Type a date'));
  await tester.pumpAndSettle();
  if (text.isNotEmpty) {
    // Set without a tap, so no touch selection handle is drawn: a person
    // typing on a keyboard sees none.
    tester
        .widget<EditableText>(find.byType(EditableText))
        .controller
        .value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    Future<void> shot(
      WidgetTester tester,
      String state,
      FutureOr<void> Function(BuildContext) open, {
      Size size = _phone,
      Future<void> Function(WidgetTester)? then,
      double textScale = 1,
      Locale locale = const Locale('en'),
    }) => withClock(
      Clock.fixed(_today),
      () => kitGalleryShot(
        tester,
        name: kitGalleryName(
          'kit_date_time_picker_$state',
          size,
          light: light,
          text2: textScale == 2,
        ),
        size: size,
        light: light,
        open: open,
        then: then,
        textScale: textScale,
        locale: locale,
      ),
    );

    Future<void> part(WidgetTester tester, String state, Widget child) =>
        withClock(
          Clock.fixed(_today),
          () => kitGalleryPart(
            tester,
            name: kitGalleryName(
              'kit_date_time_picker_$state',
              _phone,
              light: light,
            ),
            size: _phone,
            light: light,
            child: child,
          ),
        );

    testWidgets('kit_date_time_picker date · $mode', (tester) async {
      await shot(tester, 'date', _date);
    });

    testWidgets('kit_date_time_picker date 1280x800 · $mode', (tester) async {
      await shot(tester, 'date', _date, size: _wide);
    });

    testWidgets('kit_date_time_picker date text2 · $mode', (tester) async {
      await shot(tester, 'date', _date, textScale: 2);
    });

    testWidgets('kit_date_time_picker date_typed · $mode', (tester) async {
      await shot(tester, 'date_typed', _date, then: (t) => _typeDate(t, ''));
    });

    testWidgets('kit_date_time_picker date_invalid · $mode', (tester) async {
      await shot(
        tester,
        'date_invalid',
        _date,
        then: (t) => _typeDate(t, '2/31/2026'),
      );
    });

    // A 24-hour locale (en_GB) draws the time without AM/PM.
    testWidgets('kit_date_time_picker time · $mode', (tester) async {
      await shot(tester, 'time', _time, locale: const Locale('en', 'GB'));
    });

    testWidgets('kit_date_time_picker time_12h · $mode', (tester) async {
      await shot(tester, 'time_12h', _time);
    });

    testWidgets('kit_date_time_picker time_invalid · $mode', (tester) async {
      await shot(
        tester,
        'time_invalid',
        _quietEnd,
        locale: const Locale('en', 'GB'),
        then: (t) => t.tap(find.text('Set time')),
      );
    });

    testWidgets('kit_date_time_picker date_and_time · $mode', (tester) async {
      await shot(
        tester,
        'date_and_time',
        (context) => showKitDateTimePicker(
          context,
          title: 'Remind me',
          initial: DateTime(2026, 10, 3, 9, 30),
        ),
      );
    });

    testWidgets('kit_date_time_picker row_empty_set · $mode', (tester) async {
      await part(
        tester,
        'row_empty_set',
        KitRowGroup(
          label: 'Task',
          children: [
            KitDateTimeRow.date(
              title: 'Due date',
              value: _fixture,
              clearable: true,
              onChanged: (_) {},
            ),
            KitDateTimeRow.date(
              title: 'Start date',
              value: null,
              onChanged: (_) {},
            ),
            KitDateTimeRow.time(
              title: 'Quiet from',
              value: const TimeOfDay(hour: 22, minute: 0),
              onChanged: (_) {},
            ),
            KitDateTimeRow.dateAndTime(
              title: 'Remind me',
              value: DateTime(2026, 10, 3, 9, 30),
              onChanged: (_) {},
            ),
          ],
        ),
      );
    });

    testWidgets('kit_date_time_picker row_error · $mode', (tester) async {
      await part(
        tester,
        'row_error',
        KitRowGroup(
          label: 'Task',
          children: [
            KitDateTimeRow.date(
              title: 'Due date',
              value: null,
              supporting: 'The task shows as late after this day',
              error: 'A due date is required',
              onChanged: (_) {},
            ),
          ],
        ),
      );
    });

    testWidgets('kit_date_time_picker row_disabled · $mode', (tester) async {
      await part(
        tester,
        'row_disabled',
        const KitRowGroup(
          label: 'Notifications',
          children: [
            KitDateTimeRow.time(
              title: 'Quiet from',
              value: TimeOfDay(hour: 22, minute: 0),
              onChanged: null,
              disabledReason: 'Turn on quiet hours to set a time',
            ),
          ],
        ),
      );
    });
  }
}
