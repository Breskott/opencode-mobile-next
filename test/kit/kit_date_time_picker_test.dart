// Behaviour tests for KitDateTimePicker
// (docs/ux-system/kit-api/KitDateTimePicker.md, "Tests required"). Owner
// decision 2026-09-27: Arabic is dropped, so item 8 (RTL Arabic) is covered
// only by the mirrored-arrow check under a right-to-left Directionality.
import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_date_time_picker.dart';
import 'package:opencode_mobile/ui/kit/kit_field.dart';
import 'package:opencode_mobile/ui/kit/kit_row.dart';
import 'package:opencode_mobile/ui/kit/kit_segmented.dart';

final _today = DateTime(2026, 10, 1);
final _fixture = DateTime(2026, 10, 3);

class _Routes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route);
}

/// An empty screen; returns a context under the navigator.
Future<BuildContext> _host(
  WidgetTester tester, {
  Size size = const Size(412, 915),
  bool use24 = false,
  bool reduced = false,
  double textScale = 1,
  TextDirection? direction,
  _Routes? routes,
  Widget? child,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorObservers: [?routes],
      builder: (context, child) {
        Widget body = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: use24,
            disableAnimations: reduced,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        );
        if (direction != null) {
          body = Directionality(textDirection: direction, child: body);
        }
        return body;
      },
      home: Scaffold(
        body: Builder(
          builder: (inner) {
            context = inner;
            return child ?? const SizedBox.expand();
          },
        ),
      ),
    ),
  );
  return context;
}

/// Runs [body] with today fixed at 1 October 2026 (TEST-11).
Future<void> _fixed(Future<void> Function() body) =>
    withClock(Clock.fixed(_today), body);

/// Opens [open] and returns a completer that holds its result.
Future<Completer<T?>> _open<T>(
  WidgetTester tester,
  Future<T?> Function() open,
) async {
  final result = Completer<T?>();
  unawaited(open().then(result.complete));
  await tester.pumpAndSettle();
  return result;
}

Finder _day(int n) =>
    find.descendant(of: find.byType(Semantics), matching: find.text('$n'));

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  group('showKitDatePicker', () {
    testWidgets('its route is named by the title and a day is returned', (
      tester,
    ) async {
      await _fixed(() async {
        final context = await _host(tester);
        final semantics = tester.ensureSemantics();
        final result = await _open(
          tester,
          () =>
              showKitDatePicker(context, title: 'Due date', initial: _fixture),
        );
        expect(
          tester.getSemantics(find.text('Due date')),
          isSemantics(namesRoute: true, isHeader: true),
        );
        await tester.tap(_day(10).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Set date'));
        await tester.pumpAndSettle();
        expect(await result.future, DateTime(2026, 10, 10));
        semantics.dispose();
      });
    });

    testWidgets('Esc, back, close and a swipe return null', (tester) async {
      await _fixed(() async {
        final context = await _host(tester);
        Future<DateTime?> open() =>
            showKitDatePicker(context, title: 'Due date', initial: _fixture);

        var result = await _open(tester, open);
        await _key(tester, LogicalKeyboardKey.escape);
        expect(result.isCompleted, isTrue);
        expect(await result.future, isNull);

        result = await _open(tester, open);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(await result.future, isNull);

        result = await _open(tester, open);
        await tester.tap(find.byKey(const ValueKey('kit-sheet-close')));
        await tester.pumpAndSettle();
        expect(await result.future, isNull);

        result = await _open(tester, open);
        await tester.fling(find.text('Due date'), const Offset(0, 800), 3000);
        await tester.pumpAndSettle();
        expect(await result.future, isNull);
      });
    });

    testWidgets('days outside the range or refused are inert and unavailable', (
      tester,
    ) async {
      await _fixed(() async {
        final context = await _host(tester);
        final semantics = tester.ensureSemantics();
        final result = await _open(
          tester,
          () => showKitDatePicker(
            context,
            title: 'Due date',
            initial: DateTime(2026, 10, 14),
            first: DateTime(2026, 10, 5),
            last: DateTime(2026, 10, 25),
            selectable: (day) => day.day != 15,
          ),
        );
        for (final n in [2, 15, 28]) {
          final node = tester.getSemantics(_day(n).first);
          expect(
            node,
            isSemantics(
              isButton: true,
              hasEnabledState: true,
              isEnabled: false,
            ),
          );
          await tester.tap(_day(n).first, warnIfMissed: false);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Set date'));
        await tester.pumpAndSettle();
        expect(await result.future, DateTime(2026, 10, 14));
        semantics.dispose();
      });
    });

    testWidgets('each day announces its full date and today', (tester) async {
      await _fixed(() async {
        final context = await _host(tester);
        final semantics = tester.ensureSemantics();
        await _open(
          tester,
          () =>
              showKitDatePicker(context, title: 'Due date', initial: _fixture),
        );
        expect(
          tester.getSemantics(_day(3).first),
          isSemantics(label: 'Saturday, October 3, 2026', isSelected: true),
        );
        expect(
          tester.getSemantics(_day(1).first),
          isSemantics(label: 'Thursday, October 1, 2026, Today'),
        );
        semantics.dispose();
      });
    });

    testWidgets('"Type a date" swaps in place and checks the entry', (
      tester,
    ) async {
      await _fixed(() async {
        final routes = _Routes();
        final context = await _host(tester, routes: routes);
        final result = await _open(
          tester,
          () => showKitDatePicker(
            context,
            title: 'Due date',
            initial: _fixture,
            last: DateTime(2026, 12, 31),
          ),
        );
        final pushes = routes.pushed.length;
        await tester.tap(find.text('Type a date'));
        await tester.pumpAndSettle();
        expect(routes.pushed.length, pushes);
        expect(find.byType(KitField), findsOneWidget);
        expect(find.text('Show calendar'), findsOneWidget);

        await tester.enterText(find.byType(EditableText), '2/31/2026');
        await tester.tap(find.text('Set date'));
        await tester.pumpAndSettle();
        expect(find.text('Not a date'), findsOneWidget);
        expect(result.isCompleted, isFalse);

        await tester.enterText(find.byType(EditableText), '1/1/2030');
        await tester.tap(find.text('Set date'));
        await tester.pumpAndSettle();
        expect(
          find.text('Pick a date between Jan 1, 1900 and Dec 31, 2026'),
          findsOneWidget,
        );
        expect(result.isCompleted, isFalse);

        await tester.enterText(find.byType(EditableText), '10/20/2026');
        await tester.tap(find.text('Set date'));
        await tester.pumpAndSettle();
        expect(await result.future, DateTime(2026, 10, 20));
      });
    });

    testWidgets('no stock picker or dialog route is pushed', (tester) async {
      await _fixed(() async {
        final routes = _Routes();
        final context = await _host(tester, routes: routes);
        await _open(
          tester,
          () =>
              showKitDatePicker(context, title: 'Due date', initial: _fixture),
        );
        expect(find.byType(DatePickerDialog), findsNothing);
        expect(find.byType(CalendarDatePicker), findsNothing);
        expect(routes.pushed.last, isA<ModalBottomSheetRoute<dynamic>>());
        expect(routes.pushed.whereType<DialogRoute<dynamic>>(), isEmpty);
      });
    });
  });

  group('showKitTimePicker', () {
    testWidgets('24-hour: two number fields and Set returns the time', (
      tester,
    ) async {
      final context = await _host(tester, use24: true);
      final result = await _open(
        tester,
        () => showKitTimePicker(
          context,
          title: 'Quiet from',
          initial: const TimeOfDay(hour: 22, minute: 0),
        ),
      );
      expect(find.byType(KitField), findsNWidgets(2));
      expect(find.text('Hour'), findsOneWidget);
      expect(find.text('Minute'), findsOneWidget);
      expect(find.byType(KitSegmented<DayPeriod>), findsNothing);
      await tester.enterText(find.byType(EditableText).at(0), '07');
      await tester.enterText(find.byType(EditableText).at(1), '45');
      await tester.tap(find.text('Set time'));
      await tester.pumpAndSettle();
      expect(await result.future, const TimeOfDay(hour: 7, minute: 45));
      expect(find.byType(TimePickerDialog), findsNothing);
    });

    testWidgets('12-hour: AM/PM control, and 12 AM is 00:00', (tester) async {
      final context = await _host(tester);
      final result = await _open(
        tester,
        () => showKitTimePicker(
          context,
          title: 'Quiet from',
          initial: const TimeOfDay(hour: 21, minute: 30),
        ),
      );
      expect(find.byType(KitSegmented<DayPeriod>), findsOneWidget);
      await tester.enterText(find.byType(EditableText).at(0), '12');
      await tester.enterText(find.byType(EditableText).at(1), '00');
      await tester.tap(find.text('AM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set time'));
      await tester.pumpAndSettle();
      expect(await result.future, const TimeOfDay(hour: 0, minute: 0));
    });

    testWidgets('Arrow Up/Down step the field, Page Down moves 10 minutes', (
      tester,
    ) async {
      final context = await _host(tester, use24: true);
      final result = await _open(
        tester,
        () => showKitTimePicker(
          context,
          title: 'Quiet from',
          initial: const TimeOfDay(hour: 23, minute: 55),
        ),
      );
      String field(int i) => tester
          .widget<EditableText>(find.byType(EditableText).at(i))
          .controller
          .text;
      // Focus starts on the hour field.
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(field(0), '00');
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(field(0), '22');
      await _key(tester, LogicalKeyboardKey.pageDown);
      expect(field(1), '45');
      await tester.tap(find.text('Set time'));
      await tester.pumpAndSettle();
      expect(await result.future, const TimeOfDay(hour: 22, minute: 45));
    });

    testWidgets('hour 25 is refused with "Not a time"', (tester) async {
      final context = await _host(tester, use24: true);
      final result = await _open(
        tester,
        () => showKitTimePicker(
          context,
          title: 'Quiet from',
          initial: const TimeOfDay(hour: 22, minute: 0),
        ),
      );
      await tester.enterText(find.byType(EditableText).at(0), '25');
      await tester.tap(find.text('Set time'));
      await tester.pumpAndSettle();
      expect(find.text('Not a time'), findsOneWidget);
      expect(result.isCompleted, isFalse);
    });

    testWidgets('a validate reason blocks closing and is announced once', (
      tester,
    ) async {
      final context = await _host(tester, use24: true);
      final result = await _open(
        tester,
        () => showKitTimePicker(
          context,
          title: 'Quiet from',
          initial: const TimeOfDay(hour: 7, minute: 0),
          helper: 'Quiet hours end at 07:00',
          validate: (value) => value.hour == 7 && value.minute == 0
              ? 'Same as the end: quiet hours are off'
              : null,
        ),
      );
      tester.takeAnnouncements();
      await tester.tap(find.text('Set time'));
      await tester.pumpAndSettle();
      expect(find.text('Same as the end: quiet hours are off'), findsOneWidget);
      expect(result.isCompleted, isFalse);
      final announced = tester.takeAnnouncements();
      expect(announced, hasLength(1));
      expect(announced.single.message, 'Same as the end: quiet hours are off');
    });
  });

  testWidgets('showKitDateTimePicker returns the combined local DateTime', (
    tester,
  ) async {
    await _fixed(() async {
      final context = await _host(tester, use24: true);
      final result = await _open(
        tester,
        () => showKitDateTimePicker(
          context,
          title: 'Remind me',
          initial: DateTime(2026, 10, 3, 9, 15),
        ),
      );
      await tester.tap(_day(12).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).at(0), '18');
      await tester.enterText(find.byType(EditableText).at(1), '05');
      await tester.tap(find.text('Set'));
      await tester.pumpAndSettle();
      final value = await result.future;
      expect(value, DateTime(2026, 10, 12, 18, 5));
      expect(value!.isUtc, isFalse);
    });
  });

  group('KitDateTimeRow', () {
    testWidgets('shows the formatted value or "Not set"', (tester) async {
      await _host(
        tester,
        child: KitRowGroup(
          children: [
            KitDateTimeRow.date(
              title: 'Due date',
              value: _fixture,
              onChanged: (_) {},
            ),
            KitDateTimeRow.time(
              title: 'Quiet from',
              value: const TimeOfDay(hour: 22, minute: 0),
              onChanged: (_) {},
            ),
            KitDateTimeRow.date(
              title: 'Start date',
              value: null,
              onChanged: (_) {},
            ),
          ],
        ),
      );
      expect(find.text('Oct 3, 2026'), findsOneWidget);
      expect(find.text('10:00 PM'), findsOneWidget);
      expect(find.text('Not set'), findsOneWidget);
    });

    testWidgets('a tap opens the picker and the result reaches onChanged', (
      tester,
    ) async {
      await _fixed(() async {
        DateTime? changed;
        await _host(
          tester,
          child: KitRowGroup(
            children: [
              KitDateTimeRow.date(
                title: 'Due date',
                pickerTitle: 'Due on',
                value: _fixture,
                onChanged: (value) => changed = value,
              ),
            ],
          ),
        );
        await tester.tap(find.text('Due date'));
        await tester.pumpAndSettle();
        expect(find.text('Due on'), findsOneWidget);
        await tester.tap(_day(9).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Set date'));
        await tester.pumpAndSettle();
        expect(changed, DateTime(2026, 10, 9));
      });
    });

    testWidgets('clearable shows a labelled Clear that sends null', (
      tester,
    ) async {
      var changed = false;
      DateTime? value = _fixture;
      await _host(
        tester,
        child: KitRowGroup(
          children: [
            KitDateTimeRow.date(
              title: 'Due date',
              value: value,
              clearable: true,
              onChanged: (next) {
                changed = true;
                value = next;
              },
            ),
          ],
        ),
      );
      expect(find.byTooltip('Clear Due date'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear Due date'));
      await tester.pumpAndSettle();
      expect(changed, isTrue);
      expect(value, isNull);
    });

    testWidgets('disabled needs a reason and shows it', (tester) async {
      ValueChanged<DateTime?>? none;
      expect(
        () => KitDateTimeRow.date(
          title: 'Due date',
          value: null,
          onChanged: none,
        ),
        throwsAssertionError,
      );
      await _host(
        tester,
        child: const KitRowGroup(
          children: [
            KitDateTimeRow.date(
              title: 'Due date',
              value: null,
              onChanged: null,
              disabledReason: 'Set by the server',
            ),
          ],
        ),
      );
      expect(find.text('Set by the server'), findsOneWidget);
      await tester.tap(find.text('Due date'));
      await tester.pumpAndSettle();
      expect(find.text('Set date'), findsNothing);
    });

    testWidgets('an error shows under the row', (tester) async {
      await _host(
        tester,
        child: KitRowGroup(
          children: [
            KitDateTimeRow.date(
              title: 'Due date',
              value: null,
              onChanged: (_) {},
              error: 'A due date is required',
            ),
          ],
        ),
      );
      expect(find.text('A due date is required'), findsOneWidget);
    });
  });

  group('keyboard', () {
    testWidgets('focus starts on the selected day; arrows and Enter pick', (
      tester,
    ) async {
      await _fixed(() async {
        final context = await _host(tester);
        final result = await _open(
          tester,
          () =>
              showKitDatePicker(context, title: 'Due date', initial: _fixture),
        );
        await _key(tester, LogicalKeyboardKey.arrowRight);
        await _key(tester, LogicalKeyboardKey.arrowDown);
        await _key(tester, LogicalKeyboardKey.enter);
        await tester.tap(find.text('Set date'));
        await tester.pumpAndSettle();
        expect(await result.future, DateTime(2026, 10, 11));
      });
    });

    testWidgets('Home and End go to the week start and end', (tester) async {
      await _fixed(() async {
        final context = await _host(tester);
        final result = await _open(
          tester,
          () => showKitDatePicker(
            context,
            title: 'Due date',
            initial: DateTime(2026, 10, 14),
          ),
        );
        await _key(tester, LogicalKeyboardKey.home);
        await _key(tester, LogicalKeyboardKey.space);
        await tester.tap(find.text('Set date'));
        await tester.pumpAndSettle();
        // en weeks start on Sunday.
        expect(await result.future, DateTime(2026, 10, 11));
      });
    });

    testWidgets('Page Down turns to the next month, announced once', (
      tester,
    ) async {
      await _fixed(() async {
        final context = await _host(tester);
        await _open(
          tester,
          () =>
              showKitDatePicker(context, title: 'Due date', initial: _fixture),
        );
        expect(find.text('October 2026'), findsOneWidget);
        tester.takeAnnouncements();
        await _key(tester, LogicalKeyboardKey.pageDown);
        expect(find.text('November 2026'), findsOneWidget);
        expect(find.text('October 2026'), findsNothing);
        final announced = tester.takeAnnouncements();
        expect(announced.map((a) => a.message), ['November 2026']);
      });
    });

    testWidgets('arrows follow visual direction in RTL', (tester) async {
      await _fixed(() async {
        final context = await _host(tester, direction: TextDirection.rtl);
        final result = await _open(
          tester,
          () =>
              showKitDatePicker(context, title: 'Due date', initial: _fixture),
        );
        await _key(tester, LogicalKeyboardKey.arrowLeft);
        await _key(tester, LogicalKeyboardKey.enter);
        await tester.tap(find.text('Set date'));
        await tester.pumpAndSettle();
        expect(await result.future, DateTime(2026, 10, 4));
      });
    });

    testWidgets('Tab reaches every action; Esc returns null', (tester) async {
      await _fixed(() async {
        final context = await _host(tester);
        final result = await _open(
          tester,
          () =>
              showKitDatePicker(context, title: 'Due date', initial: _fixture),
        );
        final reached = <String>{};
        for (var i = 0; i < 12; i++) {
          await _key(tester, LogicalKeyboardKey.tab);
          final node = FocusManager.instance.primaryFocus;
          final focus = node?.context;
          if (node == null || focus == null) continue;
          if (node.debugLabel == 'kit-date-grid') reached.add('grid');
          for (final label in ['Type a date', 'Set date']) {
            final inside = find.descendant(
              of: find.byElementPredicate((e) => e == focus),
              matching: find.text(label),
            );
            if (inside.evaluate().isNotEmpty) reached.add(label);
          }
        }
        expect(reached, containsAll(['grid', 'Type a date', 'Set date']));
        await _key(tester, LogicalKeyboardKey.escape);
        expect(await result.future, isNull);
      });
    });
  });

  testWidgets('under reduced motion the month change and swap take one pump', (
    tester,
  ) async {
    await _fixed(() async {
      final context = await _host(tester, reduced: true);
      unawaited(
        showKitDatePicker(context, title: 'Due date', initial: _fixture),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next month'));
      await tester.pump();
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('October 2026'), findsNothing);
      await tester.tap(find.text('Type a date'));
      await tester.pump();
      expect(find.byType(KitField), findsOneWidget);
      expect(find.text('November 2026'), findsNothing);
    });
  });

  group('overflow (G6)', () {
    for (final size in const [
      Size(320, 640),
      Size(412, 915),
      Size(915, 412),
      Size(1280, 800),
      Size(1600, 1000),
    ]) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        testWidgets('date and time at $size, text $scale', (tester) async {
          await _fixed(() async {
            final context = await _host(tester, size: size, textScale: scale);
            unawaited(
              showKitDateTimePicker(
                context,
                title: 'Remind me',
                initial: _fixture,
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          });
        });
      }
    }

    testWidgets('day cells are 48 dp targets on a 412 dp phone', (
      tester,
    ) async {
      await _fixed(() async {
        final context = await _host(tester);
        unawaited(
          showKitDatePicker(context, title: 'Due date', initial: _fixture),
        );
        await tester.pumpAndSettle();
        final size = tester.getSize(
          find
              .ancestor(
                of: _day(15).first,
                matching: find.byType(GestureDetector),
              )
              .first,
        );
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      });
    });
  });
}
