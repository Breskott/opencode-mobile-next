// The F7 review fixes: the Thing page's actions, Add something with a thing
// and an area to pick and a result line, the reminder guess that is a
// one-off unless the words say it repeats, and the reminder sheet that shows
// when it will fire above its detail rows.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/factsbook/factsbook_capabilities.dart';
import 'package:opencode_mobile/domain/factsbook/factsbook_types.dart';
import 'package:opencode_mobile/domain/factsbook/fake_factsbook_gateway.dart';
import 'package:opencode_mobile/domain/factsbook/reminder_guess.dart';
import 'package:opencode_mobile/state/factsbook/factsbook_session.dart';
import 'package:opencode_mobile/ui/screens/factsbook/capture_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/phone_node_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/status_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/memory_care_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/thing_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/triggers_screen.dart';

import 'factsbook_test_support.dart';

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await settle(tester);
}

/// The Repeats row of the reminder sheet, showing [word] as its value.
Finder _repeatRow(String word) => find.descendant(
  of: find.byKey(const ValueKey('factsbook-reminder-repeat')),
  matching: find.textContaining(word, findRichText: true),
);

Future<String> _thingId(FakeFactsBookGateway node, String title) async =>
    (await node.things()).firstWhere((t) => t.title == title).id;

class _PhoneHost extends NoNodeHost {
  const _PhoneHost();
  @override
  bool get supported => true;
}

void main() {
  group('Thing page actions', () {
    factsTest('Add a fact and Remind me name their thing; no Remove', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample();
      await pumpFacts(
        tester,
        FactsBookThingScreen(thingId: await _thingId(node, 'Sam')),
        gateway: node,
      );
      expect(find.text('Add a fact to Sam'), findsOneWidget);
      expect(find.text('Remind me about Sam'), findsOneWidget);
      // The v1 node has no way to forget a fact, so none is offered.
      expect(find.textContaining('Remove'), findsNothing);
      expect(find.textContaining('Delete'), findsNothing);
    });

    factsTest('Add a fact sends one line and says it waits in Needs you', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample();
      final id = await _thingId(node, 'Sam');
      await pumpFacts(tester, FactsBookThingScreen(thingId: id), gateway: node);
      await _tapKey(tester, 'factsbook-thing-add-fact');
      await tester.enterText(
        find.byKey(const ValueKey('factsbook-thing-line-field')),
        'Sam likes   tea',
      );
      await settle(tester);
      await _tapKey(tester, 'factsbook-thing-line-save');
      await tester.pump(const Duration(milliseconds: 600));
      await settle(tester);
      expect(node.factWrites, ['$id: Sam likes tea']);
      expect(
        find.text('Sent for your OK. It waits in Needs you.'),
        findsOneWidget,
      );
      await _tapKey(tester, 'factsbook-thing-see-needs-you');
      expect(find.byType(FactsBookMemoryCareScreen), findsOneWidget);
      expect(find.text('Sam likes tea'), findsOneWidget);
    });

    factsTest('a tap on a fact explains it and offers to change it', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample();
      final id = await _thingId(node, 'Sam');
      await pumpFacts(tester, FactsBookThingScreen(thingId: id), gateway: node);
      final first = (await node.thing(id)).facts.first;
      await tester.tap(find.byKey(ValueKey('factsbook-fact-${first.id}')));
      await settle(tester);
      expect(
        find.byKey(const ValueKey('factsbook-fact-explain')),
        findsOneWidget,
      );
      await _tapKey(tester, 'factsbook-fact-edit');
      await tester.enterText(
        find.byKey(const ValueKey('factsbook-thing-line-field')),
        'Sam likes poems',
      );
      await settle(tester);
      await _tapKey(tester, 'factsbook-thing-line-save');
      await tester.pump(const Duration(milliseconds: 600));
      await settle(tester);
      expect(node.calls, contains('fact.edit'));
      expect(node.factWrites.single, '${first.id}: Sam likes poems');
      expect(
        find.text('Your change waits for your OK in Needs you.'),
        findsOneWidget,
      );
    });

    factsTest(
      'Remind me about Sam is a one-off tomorrow and saves a reminder',
      (tester) async {
        final node = FakeFactsBookGateway.sample();
        await pumpFacts(
          tester,
          FactsBookThingScreen(thingId: await _thingId(node, 'Sam')),
          gateway: node,
        );
        await _tapKey(tester, 'factsbook-thing-remind');
        expect(find.text('Check this reminder'), findsOneWidget);
        // A one-off, not a monthly: the repeat row says Never.
        expect(_repeatRow('Never'), findsOneWidget);
        await _tapKey(tester, 'factsbook-reminder-save');
        await tester.pump(const Duration(milliseconds: 600));
        await settle(tester);
        final made = (await node.reminders()).last;
        expect(made.what, 'Sam');
        expect(made.schedule.when.once, DateTime(2026, 10, 12, 9));
        expect(find.text('Reminder saved for Sam.'), findsOneWidget);
      },
    );

    factsTest('without the capabilities the actions are not offered', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample();
      final id = await _thingId(node, 'Sam');
      const none = FactsBookCapabilities(
        milestone: 'test',
        supported: {FactsBookCapabilities.search},
        disabled: {},
      );
      await pumpFacts(
        tester,
        FactsBookThingScreen(thingId: id),
        session: FactsBookSession.fixed(node)..capabilities = none,
      );
      expect(find.text('Add a fact to Sam'), findsNothing);
      expect(find.text('Remind me about Sam'), findsNothing);
    });
  });

  group('Add something', () {
    factsTest('pick a thing: the note becomes a fact of it, one result line', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample();
      final id = await _thingId(node, 'Sam');
      await pumpFacts(tester, const FactsBookCaptureScreen(), gateway: node);
      await tester.enterText(
        find.byKey(const ValueKey('factsbook-capture-field')),
        'Sam likes tea',
      );
      await _tapKey(tester, 'factsbook-capture-thing');
      await tester.tap(find.text('Sam').last);
      await settle(tester);
      // With a thing the area is the thing's own, so its picker is gone.
      expect(
        find.byKey(const ValueKey('factsbook-capture-area')),
        findsNothing,
      );
      await _tapKey(tester, 'factsbook-capture-save');
      expect(node.factWrites, ['$id: Sam likes tea']);
      expect(node.calls, isNot(contains('capture')));
      expect(
        find.text('Sent for your OK. It waits in Needs you.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('factsbook-capture-see-needs-you')),
        findsOneWidget,
      );
    });

    factsTest('pick an area: it goes with the capture', (tester) async {
      final node = FakeFactsBookGateway.sample();
      await pumpFacts(tester, const FactsBookCaptureScreen(), gateway: node);
      await tester.enterText(
        find.byKey(const ValueKey('factsbook-capture-field')),
        'Gym on Monday',
      );
      await _tapKey(tester, 'factsbook-capture-area');
      await tester.tap(find.text('Family').last);
      await settle(tester);
      await _tapKey(tester, 'factsbook-capture-save');
      expect(node.calls, contains('capture'));
      expect(node.lastCaptureArea, 'family');
      expect(
        find.text('Saved. Memory will check it for changes for you to review.'),
        findsOneWidget,
      );
    });

    factsTest('rules: how many are on, and the way to them', (tester) async {
      final node = FakeFactsBookGateway.withTriggers();
      await pumpFacts(tester, const FactsBookCaptureScreen(), gateway: node);
      expect(find.text('Let my rules read this'), findsOneWidget);
      expect(find.text('1 rule is on'), findsOneWidget);
      await _tapKey(tester, 'factsbook-capture-see-rules');
      expect(find.byType(FactsBookTriggersScreen), findsOneWidget);
    });

    factsTest('remind me is an option, not a second primary button', (
      tester,
    ) async {
      await pumpFacts(tester, const FactsBookCaptureScreen());
      expect(find.text('Also remind me about it'), findsOneWidget);
      expect(find.text('Remind me about it'), findsNothing);
      expect(find.text('Save'), findsOneWidget);
    });

    factsTest('a thing picker is a note-only choice', (tester) async {
      await pumpFacts(tester, const FactsBookCaptureScreen());
      expect(find.byKey(const ValueKey('factsbook-capture-thing')), findsOne);
      await tester.tap(find.byKey(const ValueKey('factsbook-capture-paste')));
      await settle(tester);
      expect(
        find.byKey(const ValueKey('factsbook-capture-thing')),
        findsNothing,
      );
      expect(find.text('Also remind me about it'), findsNothing);
    });
  });

  group('every action names its target', () {
    factsTest('rule and reminder pause buttons say which one', (tester) async {
      final node = FakeFactsBookGateway.withTriggers();
      await pumpFacts(tester, const FactsBookTriggersScreen(), gateway: node);
      expect(find.byTooltip('Pause “Library appointments”'), findsOneWidget);
      expect(find.byTooltip('Resume “Delivery notes”'), findsOneWidget);
    }, size: const Size(412, 3000));

    factsTest('Approve and Reject on a card name their claim', (tester) async {
      await pumpFacts(tester, const FactsBookMemoryCareScreen());
      expect(
        find.bySemanticsLabel('Approve “Sam likes books”'),
        findsOneWidget,
      );
    });
  });

  group('Status', () {
    factsTest('reaches the memory on this phone (Stop, Start) from its page', (
      tester,
    ) async {
      await pumpFacts(
        tester,
        const FactsBookStatusScreen(),
        nodeHost: const _PhoneHost(),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('factsbook-status-phone-node')),
        200,
      );
      await tester.tap(
        find.byKey(const ValueKey('factsbook-status-phone-node')),
      );
      await settle(tester);
      expect(find.byType(FactsBookPhoneNodeScreen), findsOneWidget);
    });
  });

  group('a reminder is a one-off unless the words say it repeats', () {
    final now = DateTime(2026, 10, 12, 8);
    test('plain words are a one-off', () {
      expect(
        ReminderGuess.from('Dentist next Wednesday at 10', now).repeat,
        ReminderRepeat.never,
      );
      expect(
        ReminderGuess.from('Pay the rent on the first', now).repeat,
        ReminderRepeat.never,
      );
    });

    test('words that say it repeats say how', () {
      for (final (text, repeat) in [
        ('Water the plants every day at 8', ReminderRepeat.daily),
        ('Vitamins daily', ReminderRepeat.daily),
        ('Call mum every Sunday', ReminderRepeat.weekly),
        ('Team review weekly', ReminderRepeat.weekly),
        ('Pay the rent every month', ReminderRepeat.monthly),
        ('Insurance renews yearly', ReminderRepeat.yearly),
      ]) {
        expect(ReminderGuess.from(text, now).repeat, repeat, reason: text);
      }
    });

    factsTest('Add something opens the check with Never for plain words', (
      tester,
    ) async {
      await pumpFacts(tester, const FactsBookCaptureScreen());
      await tester.enterText(
        find.byKey(const ValueKey('factsbook-capture-field')),
        'Dentist next Wednesday at 10',
      );
      await _tapKey(tester, 'factsbook-capture-remind');
      await _tapKey(tester, 'factsbook-capture-save');
      expect(_repeatRow('Never'), findsOneWidget);
    });

    factsTest('and with Every week when the text says so', (tester) async {
      await pumpFacts(tester, const FactsBookCaptureScreen());
      await tester.enterText(
        find.byKey(const ValueKey('factsbook-capture-field')),
        'Call mum every Sunday at 6pm',
      );
      await _tapKey(tester, 'factsbook-capture-remind');
      await _tapKey(tester, 'factsbook-capture-save');
      expect(_repeatRow('Every week'), findsOneWidget);
    });
  });

  group('the reminder sheet', () {
    factsTest('says when it will fire above its detail rows', (tester) async {
      await pumpFacts(tester, const FactsBookCaptureScreen());
      await tester.enterText(
        find.byKey(const ValueKey('factsbook-capture-field')),
        'Dentist next Wednesday at 10',
      );
      await _tapKey(tester, 'factsbook-capture-remind');
      await _tapKey(tester, 'factsbook-capture-save');
      final summary = tester.getTopLeft(
        find.byKey(const ValueKey('factsbook-reminder-summary')),
      );
      final repeat = tester.getTopLeft(
        find.byKey(const ValueKey('factsbook-reminder-repeat')),
      );
      expect(summary.dy, lessThan(repeat.dy));
    });
  });
}
