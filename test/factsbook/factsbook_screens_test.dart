// The FactsBook screens against the fake node: the Memory section behind its
// developer flag, About you, Search, the Thing page, Add something with the
// reminder check, Needs you and Not saved yet. Provenance, source and date on
// everything recalled; Arabic renders right to left with amounts and card
// endings left to right.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/chat_feed.dart';
import 'package:opencode_mobile/domain/factsbook/factsbook_types.dart';
import 'package:opencode_mobile/domain/factsbook/fake_factsbook_gateway.dart';
import 'package:opencode_mobile/state/factsbook/factsbook_outbox.dart';
import 'package:opencode_mobile/state/factsbook/factsbook_session.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/chats/chats_home_screen.dart';
import 'package:opencode_mobile/ui/screens/chats/chats_host.dart'
    show chatsHostProvider;
import 'package:opencode_mobile/ui/screens/factsbook/about_you_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/capture_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/memory_care_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/memory_section.dart';
import 'package:opencode_mobile/ui/screens/factsbook/not_saved_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/search_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/status_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/thing_screen.dart';

import '../support/chats_fakes.dart';
import 'factsbook_test_support.dart';

Future<String> _id(FakeFactsBookGateway node, ThingKind kind) async =>
    (await node.things(kind: kind)).first.id;

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).first);
  await settle(tester);
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await settle(tester);
}

/// "Also remind me about it" is a switch in the note flow, and Save runs the
/// reminder check: no second primary button.
Future<void> _remindAndSave(WidgetTester tester) async {
  await _tapKey(tester, 'factsbook-capture-remind');
  await _tapKey(tester, 'factsbook-capture-save');
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await settle(tester);
}

void main() {
  group('the Memory section in the Inbox (Chats home)', () {
    FakeChatsHost host() => FakeChatsHost(
      FakeChatFeedSource(
        items: [
          chat(
            'a',
            'Fix the login bug',
            status: ChatStatus.needsYou,
            at: factsNow.subtract(const Duration(minutes: 2)),
          ),
        ],
        projects: [project('alpha', chats: 1, needs: 1)],
      ),
    );

    factsTest('the flag off shows no Memory section at all', (tester) async {
      await pumpFacts(
        tester,
        const ChatsHomeScreen(),
        flag: false,
        overrides: [chatsHostProvider.overrideWithValue(host())],
      );
      expect(find.byType(FactsBookMemorySection), findsNothing);
      expect(find.text('Memory'), findsNothing);
      expect(find.text('Open About you'), findsNothing);
      expect(find.text(KitBidi.auto('Fix the login bug')), findsOneWidget);
    });

    factsTest('the flag on shows Memory under Needs you, counted once', (
      tester,
    ) async {
      await pumpFacts(
        tester,
        const ChatsHomeScreen(),
        overrides: [chatsHostProvider.overrideWithValue(host())],
      );
      expect(find.byType(FactsBookMemorySection), findsOneWidget);
      expect(find.text('Memory'), findsOneWidget);
      expect(find.text('4 waiting'), findsOneWidget);
    });

    factsTest(
      'needs-you rows, recent things with source and date, both ways in',
      (tester) async {
        await pumpFacts(tester, const FactsBookMemorySection());
        expect(find.text('3 changes to review'), findsOneWidget);
        expect(find.text('1 note not saved yet'), findsOneWidget);
        expect(rich('Needs your OK'), findsOneWidget);
        expect(find.text('Recently added to memory'), findsOneWidget);
        expect(find.text('Dentist'), findsOneWidget);
        expect(richExact('You told it · Oct 11'), findsOneWidget);
        expect(find.text('Sam'), findsOneWidget);
        expect(
          rich('It guessed · Oct 9 · from a chat you saved'),
          findsWidgets,
        );
        expect(find.text('Open About you'), findsOneWidget);
        expect(find.text('Add something'), findsOneWidget);
      },
    );

    factsTest('at most three recent things', (tester) async {
      final node = FakeFactsBookGateway.sample();
      for (var i = 0; i < 4; i++) {
        await node.capture(
          CaptureRequest(kind: CaptureKind.note, text: 'Note $i. More.'),
          idempotencyKey: 'k$i',
        );
      }
      await pumpFacts(tester, const FactsBookMemorySection(), gateway: node);
      final rows = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('factsbook-recent-'),
      );
      expect(rows, findsNWidgets(3));
    });

    factsTest('the rows open their pages', (tester) async {
      await pumpFacts(tester, const FactsBookMemorySection());
      await _tapText(tester, 'Open About you');
      expect(find.byType(FactsBookAboutYouScreen), findsOneWidget);
      await tester.pageBack();
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 600));
      await _tapText(tester, 'Add something');
      expect(find.byType(FactsBookCaptureScreen), findsOneWidget);
      await tester.pageBack();
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 600));
      await _tapText(tester, '1 note not saved yet');
      expect(find.byType(FactsBookNotSavedScreen), findsOneWidget);
      await tester.pageBack();
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 600));
      await _tapText(tester, '3 changes to review');
      expect(find.byType(FactsBookMemoryCareScreen), findsOneWidget);
    });

    factsTest('quiet when nothing needs the person', (tester) async {
      final node = FakeFactsBookGateway(review: const [], pending: const []);
      await pumpFacts(tester, const FactsBookMemorySection(), gateway: node);
      expect(find.text('All clear'), findsOneWidget);
      // Said once, in the header.
      expect(find.text('Nothing in memory needs you.'), findsNothing);
    });

    factsTest('not reachable: a plain notice with Try again, never raw text', (
      tester,
    ) async {
      final node = FakeFactsBookGateway()..reachable = false;
      await pumpFacts(tester, const FactsBookMemorySection(), gateway: node);
      expect(find.text('Memory did not answer'), findsOneWidget);
      expect(find.textContaining('could not be reached'), findsOneWidget);
      expect(find.textContaining('FactsBookException'), findsNothing);
      expect(find.textContaining('node_unreachable'), findsNothing);
    });
  });

  group('About you', () {
    factsTest('opens on Needs you when something waits, with the status line', (
      tester,
    ) async {
      await pumpFacts(tester, const FactsBookAboutYouScreen());
      expect(find.text('About you'), findsOneWidget);
      // "Last saved 2 min ago" is gone: it said nothing to act on.
      expect(find.textContaining('Last saved'), findsNothing);
      // No tab strip, and no Map or Watching until they exist.
      expect(find.text('Map'), findsNothing);
      expect(find.text('Watching'), findsNothing);
      expect(find.text('Not available yet'), findsNothing);
      expect(find.text('3 waiting'), findsNothing);
      expect(rich('4 waiting'), findsOneWidget);
    });

    factsTest('List shows each thing with its source and date, and filters', (
      tester,
    ) async {
      await pumpFacts(tester, const FactsBookAboutYouScreen());
      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('[Bank A] Visa ••42'), findsOneWidget);
      expect(find.text('Passport'), findsOneWidget);
      expect(rich('Card · Used for groceries.'), findsOneWidget);
      expect(rich('You told it · Sep 12'), findsOneWidget);
      expect(rich('waiting for your OK'), findsWidgets);
      expect(
        find.text(
          "Notes with passwords or account numbers aren't saved yet. They wait in Not saved yet.",
        ),
        findsOneWidget,
      );
      await _tapKey(tester, 'factsbook-filter-people');
      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('Passport'), findsNothing);
      await _tapKey(tester, 'factsbook-filter-all');
      expect(find.text('Passport'), findsOneWidget);
    });

    factsTest('the places are visible rows, not a menu', (tester) async {
      await pumpFacts(tester, const FactsBookAboutYouScreen());
      expect(find.byTooltip('More about you'), findsNothing);
      for (final (key, label) in [
        ('needs-you', 'Needs you'),
        ('reminders', 'Reminders'),
        ('triggers', 'When something new arrives'),
        ('areas', 'Areas and sharing'),
      ]) {
        final row = find.byKey(ValueKey('factsbook-about-$key'));
        expect(row, findsOneWidget, reason: key);
        expect(
          find.descendant(of: row, matching: find.text(label)),
          findsOneWidget,
          reason: key,
        );
      }
      await _tapKey(tester, 'factsbook-about-needs-you');
      expect(find.byType(FactsBookMemoryCareScreen), findsOneWidget);
    });

    factsTest('Status and Settings are a small footer group', (tester) async {
      await pumpFacts(tester, const FactsBookAboutYouScreen());
      await tester.drag(find.byType(ListView).first, const Offset(0, -900));
      await settle(tester);
      expect(
        find.byKey(const ValueKey('factsbook-about-footer')),
        findsOneWidget,
      );
      await _tapKey(tester, 'factsbook-about-status');
      expect(find.byType(FactsBookStatusScreen), findsOneWidget);
    });

    factsTest('an empty memory says what to do', (tester) async {
      final node = FakeFactsBookGateway(
        things: const [],
        review: const [],
        pending: const [],
      );
      await pumpFacts(tester, const FactsBookAboutYouScreen(), gateway: node);
      expect(find.text('Nothing here yet'), findsOneWidget);
    });

    factsTest('searching opens the results', (tester) async {
      await pumpFacts(tester, const FactsBookAboutYouScreen());
      await _type(tester, 'factsbook-search-field', 'dentist');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.byType(FactsBookSearchScreen), findsOneWidget);
      expect(find.text('2 matches for “dentist”'), findsOneWidget);
    });
  });

  group('Search results', () {
    factsTest('every hit shows its source and date; words, not meaning', (
      tester,
    ) async {
      await pumpFacts(tester, const FactsBookSearchScreen(query: 'dentist'));
      expect(find.text('2 matches for “dentist”'), findsOneWidget);
      expect(
        find.text(
          'Matches words in your notes. It does not search by meaning.',
        ),
        findsOneWidget,
      );
      final rows = find.byType(KitFactRow);
      expect(rows, findsNWidgets(2));
      for (final row in tester.widgetList<KitFactRow>(rows)) {
        expect(row.open, isNotNull);
      }
      expect(find.text('You told it · Oct 11'), findsOneWidget);
      expect(find.text('From a chat you saved · Oct 3'), findsOneWidget);
      expect(
        find.text('Locked notes are not searched until you unlock.'),
        findsOneWidget,
      );
    });

    factsTest('a hit opens its thing', (tester) async {
      await pumpFacts(tester, const FactsBookSearchScreen(query: 'dentist'));
      await tester.tap(find.byType(KitFactRow).first);
      await settle(tester);
      expect(find.byType(FactsBookThingScreen), findsOneWidget);
    });

    factsTest('no match says so plainly', (tester) async {
      await pumpFacts(tester, const FactsBookSearchScreen(query: 'zebra'));
      expect(find.text('No matches for “zebra”'), findsOneWidget);
      expect(find.text('Nothing matches'), findsOneWidget);
    });
  });

  group('Thing page', () {
    factsTest(
      'every fact has provenance, source and date; a source can be wrong',
      (tester) async {
        final node = FakeFactsBookGateway.sample();
        await pumpFacts(
          tester,
          FactsBookThingScreen(thingId: await _id(node, ThingKind.card)),
          gateway: node,
        );
        expect(find.text('[Bank A] Visa ••42'), findsOneWidget);
        expect(find.text('Card · Money area'), findsOneWidget);
        expect(find.text('Annual fee is [AMOUNT] CUR.'), findsOneWidget);
        expect(find.text('You told it · Sep 12'), findsOneWidget);
        expect(find.text('From text you shared · Oct 3'), findsOneWidget);
        expect(
          find.text(
            'It guessed · Oct 9 · from a chat you saved · waiting for your OK',
          ),
          findsOneWidget,
        );
        final rows = tester.widgetList<KitFactRow>(find.byType(KitFactRow));
        expect(rows, hasLength(3));
        expect(rows.map((r) => r.provenance), [
          KitProvenance.seen,
          KitProvenance.told,
          KitProvenance.guessed,
        ]);
        // The legend paragraph is gone: a tap on a fact explains it.
        expect(find.textContaining('Solid border'), findsNothing);
        expect(
          find.text('Tap a fact to see where it came from or to change it.'),
          findsOneWidget,
        );
        await tester.tap(find.byType(KitFactRow).first);
        await settle(tester);
        expect(
          tester
              .widget<KitText>(
                find.byKey(const ValueKey('factsbook-fact-explain')),
              )
              .text,
          'Memory read this from text you shared on Oct 3. A source can be '
          'wrong, so check it before you rely on it.',
        );
        expect(
          find.text('Facts marked "waiting for your OK" are in Needs you.'),
          findsOneWidget,
        );
      },
    );

    factsTest('an unverified edit reads like a guess, never as told', (
      tester,
    ) async {
      final node = FakeFactsBookGateway(
        things: [
          Thing(
            id: 'per_00000000000000000000000077',
            title: 'Alex',
            kind: ThingKind.person,
            updatedAt: factsNow,
            facts: [
              Fact(
                id: 'f_00000000000000000000000077',
                thingId: 'per_00000000000000000000000077',
                text: 'Lives nearby.',
                provenance: FactProvenance.external,
                observedAt: factsNow,
                source: 'itm_00000000000000000000000001',
              ),
            ],
          ),
        ],
      );
      await pumpFacts(
        tester,
        const FactsBookThingScreen(thingId: 'per_00000000000000000000000077'),
        gateway: node,
      );
      final row = tester.widget<KitFactRow>(find.byType(KitFactRow));
      expect(row.provenance, KitProvenance.guessed);
      // An id source is worded, never shown.
      expect(find.textContaining('itm_'), findsNothing);
      expect(find.textContaining('something you saved'), findsOneWidget);
    });

    factsTest('a thing that is gone says so in plain words', (tester) async {
      await pumpFacts(tester, const FactsBookThingScreen(thingId: 'per_gone'));
      expect(find.text('Memory did not answer'), findsOneWidget);
      expect(find.text('That is not in memory any more.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('FactsBookException'), findsNothing);
    });
  });

  group('Add something', () {
    factsTest('Save is off until something is written, then saves a note', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample();
      await pumpFacts(tester, const FactsBookCaptureScreen(), gateway: node);
      expect(find.text('What should it remember?'), findsOneWidget);
      await _type(tester, 'factsbook-capture-field', 'Buy stamps. Today.');
      await _tapKey(tester, 'factsbook-capture-save');
      expect(
        find.text('Saved. Memory will check it for changes for you to review.'),
        findsOneWidget,
      );
      expect(node.calls, contains('capture'));
      expect((await node.things()).first.title, 'Buy stamps');
    });

    factsTest(
      'when the node cannot be reached the note is kept on the phone and '
      'the text is not lost',
      (tester) async {
        final node = FakeFactsBookGateway.sample()..reachable = false;
        final store = MemoryOutboxStore();
        await pumpFacts(
          tester,
          const FactsBookCaptureScreen(),
          gateway: node,
          outbox: store,
        );
        await _type(tester, 'factsbook-capture-field', 'Call the bank');
        await _tapKey(tester, 'factsbook-capture-save');
        expect(
          find.text('It could not be saved yet. It is kept on this phone.'),
          findsOneWidget,
        );
        expect(find.text('Call the bank'), findsOneWidget);
        expect(store.value, contains('Call the bank'));
        await _tapText(tester, 'See Not saved yet');
        expect(find.byType(FactsBookNotSavedScreen), findsOneWidget);
        // Away from the node the page still shows what this phone holds.
        expect(find.text('Call the bank'), findsOneWidget);
        expect(find.text('Copy text'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('factsbook-notsaved-unreachable')),
          findsOneWidget,
        );
      },
    );

    factsTest('a full queue refuses the newest and keeps the text on screen', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample()..reachable = false;
      final store = MemoryOutboxStore();
      final session = FactsBookSession.fixed(node, outboxStore: store);
      for (var i = 0; i < FactsBookOutbox.maxEntries; i++) {
        await session.outbox.add(
          CaptureRequest(kind: CaptureKind.note, text: 'n$i'),
          'k$i',
        );
      }
      await pumpFacts(tester, const FactsBookCaptureScreen(), session: session);
      await _type(tester, 'factsbook-capture-field', 'The newest one');
      await _tapKey(tester, 'factsbook-capture-save');
      expect(find.textContaining('queue is full'), findsOneWidget);
      expect(find.text('The newest one'), findsOneWidget);
      expect(session.outbox.entries, hasLength(100));
      expect(session.outbox.entries.first.request.text, 'n0');
    });

    factsTest('the locked folder keeps a health note at the node and says so', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample();
      final session = FactsBookSession.fixed(node);
      await pumpFacts(tester, const FactsBookCaptureScreen(), session: session);
      // The note goes to the health area through the capture request; the node
      // holds it, and the page points to Not saved yet.
      final outcome = await node.capture(
        const CaptureRequest(
          kind: CaptureKind.note,
          text: 'Blood test',
          area: 'health',
        ),
        idempotencyKey: 'k',
      );
      expect(outcome.saved, isFalse);
      expect((await node.pendingCaptures()).length, 2);
    });

    factsTest('Remind me about it shows date, time, zone and language before '
        'anything is saved (D27)', (tester) async {
      final node = FakeFactsBookGateway.sample();
      await pumpFacts(tester, const FactsBookCaptureScreen(), gateway: node);
      await _type(
        tester,
        'factsbook-capture-field',
        'Dentist next Wednesday at 10. Bring the insurance card.',
      );
      await _remindAndSave(tester);
      expect(find.text('Check this reminder'), findsOneWidget);
      expect(
        find.text(
          'You wrote: “Dentist next Wednesday at 10. Bring the insurance card.”',
        ),
        findsOneWidget,
      );
      for (final row in ['Date', 'Time', 'Time zone', 'Language of dates']) {
        expect(find.text(row), findsOneWidget);
      }
      expect(find.text('Repeats'), findsOneWidget);
      expect(find.textContaining('Home time zone'), findsWidgets);
      expect(find.textContaining('English'), findsOneWidget);
      expect(
        find.textContaining('Wednesday, October 21, 2026'),
        findsOneWidget,
      );
      expect(
        find.text('Change anything that is wrong before saving.'),
        findsOneWidget,
      );
      expect(node.calls, isNot(contains('capture')));
      expect(node.calls, isNot(contains('reminder.create')));
    });

    factsTest('Change what I wrote saves nothing and keeps the text', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample();
      await pumpFacts(tester, const FactsBookCaptureScreen(), gateway: node);
      await _type(
        tester,
        'factsbook-capture-field',
        'Dentist next Wednesday at 10',
      );
      await _remindAndSave(tester);
      await _tapKey(tester, 'factsbook-reminder-change');
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Check this reminder'), findsNothing);
      expect(node.calls, isNot(contains('capture')));
      expect(find.text('Dentist next Wednesday at 10'), findsOneWidget);
    });

    factsTest('Save reminder: the node reads the same values, the note and the '
        'reminder are saved', (tester) async {
      final node = FakeFactsBookGateway.sample();
      await pumpFacts(tester, const FactsBookCaptureScreen(), gateway: node);
      await _type(
        tester,
        'factsbook-capture-field',
        'Dentist next Wednesday at 10',
      );
      await _remindAndSave(tester);
      await _tapKey(tester, 'factsbook-reminder-save');
      await tester.pump(const Duration(milliseconds: 600));
      await settle(tester);
      expect(find.textContaining('Saved with a reminder for'), findsOneWidget);
      final reminders = await node.reminders();
      expect(reminders, hasLength(2));
      expect(reminders.last.schedule.when.once, DateTime(2026, 10, 21, 10));
      expect(reminders.last.what, 'Dentist next Wednesday at 10');
      expect(node.calls, containsAllInOrder(['capture', 'reminder.create']));
    });

    factsTest(
      'the node\'s standing notes about clock changes do not hold the save back',
      (tester) async {
        final node = FakeFactsBookGateway.sample()
          ..previewAdjustments = [
            'DST gaps use the first valid instant; folds use the first occurrence.',
            'Occurs at 2026-10-21T10:00:00+00:00.',
          ];
        await pumpFacts(tester, const FactsBookCaptureScreen(), gateway: node);
        await _type(
          tester,
          'factsbook-capture-field',
          'Dentist next Wednesday at 10',
        );
        await _remindAndSave(tester);
        // The sheet says in its own words how a clock change is read.
        expect(
          find.textContaining('If a time does not exist that day'),
          findsOneWidget,
        );
        await _tapKey(tester, 'factsbook-reminder-save');
        await tester.pump(const Duration(milliseconds: 600));
        await settle(tester);
        expect(node.calls, contains('reminder.create'));
        expect(find.textContaining('DST gaps'), findsNothing);
      },
    );

    factsTest('an unclear date or time is flagged in the sheet', (
      tester,
    ) async {
      await pumpFacts(tester, const FactsBookCaptureScreen());
      await _type(tester, 'factsbook-capture-field', 'Call Sam');
      await _remindAndSave(tester);
      expect(find.text('I could not tell the date. Check it.'), findsOneWidget);
      expect(find.text('I could not tell the time. Check it.'), findsOneWidget);
    });

    factsTest('a note that was kept on the phone gets no reminder, and says so', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample();
      await pumpFacts(tester, const FactsBookCaptureScreen(), gateway: node);
      await _type(
        tester,
        'factsbook-capture-field',
        'Dentist next Wednesday at 10',
      );
      await _remindAndSave(tester);
      node.reachable = false;
      await _tapKey(tester, 'factsbook-reminder-save');
      // Nothing could be confirmed with the node away: the sheet stays and says
      // why in plain words.
      expect(
        find.byKey(const ValueKey('factsbook-reminder-failure')),
        findsOneWidget,
      );
      expect(find.textContaining('could not be reached'), findsOneWidget);
      expect(find.textContaining('node_unreachable'), findsNothing);
    });
  });

  group('Needs you', () {
    factsTest('changes to approve, counted once, with notes not saved', (
      tester,
    ) async {
      await pumpFacts(tester, const FactsBookMemoryCareScreen());
      expect(find.text('4 waiting'), findsOneWidget);
      expect(find.text('3 waiting for your OK'), findsOneWidget);
      expect(find.text('1 note not saved yet'), findsOneWidget);
    });

    factsTest('empty says nothing needs you', (tester) async {
      final node = FakeFactsBookGateway(review: const [], pending: const []);
      await pumpFacts(tester, const FactsBookMemoryCareScreen(), gateway: node);
      expect(find.text('Nothing needs you right now.'), findsOneWidget);
    });
  });

  group('Not saved yet', () {
    factsTest('lists what the node holds and what the phone holds, and why', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample()..failOutbox = true;
      final session = FactsBookSession.fixed(node);
      await session.outbox.add(
        const CaptureRequest(kind: CaptureKind.note, text: 'Trip checklist'),
        'k1',
      );
      await pumpFacts(
        tester,
        const FactsBookNotSavedScreen(),
        session: session,
      );
      expect(rich('2 items kept on this phone'), findsOneWidget);
      expect(
        find.text(
          'Kept until you discard them: on this phone, or by Memory. None is in your cloud yet.',
        ),
        findsOneWidget,
      );
      expect(find.text('A note Memory is holding'), findsOneWidget);
      expect(rich('Held by Memory'), findsOneWidget);
      expect(find.text('Trip checklist'), findsOneWidget);
      expect(rich('On this phone'), findsOneWidget);
      // Only the phone's note has text to copy.
      expect(find.text('Copy text'), findsOneWidget);
      expect(find.text('Try now'), findsNWidgets(2));
      expect(find.text('Discard note'), findsNWidgets(2));
      expect(find.text('Try again'), findsNothing);
      expect(
        find.textContaining(
          'At 30 days Memory asks: Retry, Export or Discard.',
        ),
        findsOneWidget,
      );
    });

    factsTest('Try now sends a phone note when the node answers', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample()..failOutbox = true;
      final session = FactsBookSession.fixed(node);
      final entry = await session.outbox.add(
        const CaptureRequest(kind: CaptureKind.note, text: 'Trip checklist'),
        'k1',
      );
      await pumpFacts(
        tester,
        const FactsBookNotSavedScreen(),
        session: session,
      );
      node.failOutbox = false;
      await _tapKey(tester, 'factsbook-retry-${entry.id}');
      expect(find.text('Saved.'), findsOneWidget);
      expect(session.outbox.entries, isEmpty);
    });

    factsTest('Try now with the node away keeps it and says so', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample()..failOutbox = true;
      final session = FactsBookSession.fixed(node);
      final entry = await session.outbox.add(
        const CaptureRequest(kind: CaptureKind.note, text: 'Trip checklist'),
        'k1',
      );
      await pumpFacts(
        tester,
        const FactsBookNotSavedScreen(),
        session: session,
      );
      await _tapKey(tester, 'factsbook-retry-${entry.id}');
      expect(find.text('Still not saved. It stays here.'), findsOneWidget);
      expect(session.outbox.entries, hasLength(1));
    });

    factsTest('a locked-folder note stays at the node when tried', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample();
      final id = (await node.pendingCaptures()).first.id;
      await pumpFacts(tester, const FactsBookNotSavedScreen(), gateway: node);
      await _tapKey(tester, 'factsbook-retry-$id');
      expect(find.text('Still not saved. It stays here.'), findsOneWidget);
      expect(
        // The node cannot open the locked folder yet (B5 matrix): no
        // "unlock it" promise with no way to unlock.
        rich("Memory can't save those yet. It stays here on this phone."),
        findsOneWidget,
      );
    });

    factsTest(
      'Discard asks first; cancelling keeps it, confirming removes it',
      (tester) async {
        final node = FakeFactsBookGateway.sample();
        final id = (await node.pendingCaptures()).first.id;
        await pumpFacts(tester, const FactsBookNotSavedScreen(), gateway: node);
        await _tapKey(tester, 'factsbook-discard-$id');
        expect(find.text('Discard this note?'), findsOneWidget);
        await tester.tapAt(const Offset(10, 10));
        await settle(tester);
        await tester.pump(const Duration(milliseconds: 600));
        expect(await node.pendingCaptures(), hasLength(1));
        await _tapKey(tester, 'factsbook-discard-$id');
        await _tapKey(tester, 'factsbook-discard-confirm-$id');
        await tester.pump(const Duration(milliseconds: 600));
        await settle(tester);
        expect(await node.pendingCaptures(), isEmpty);
      },
    );

    factsTest('at 30 days it asks Retry, Export or Discard, and keeps the '
        'item until the person decides', (tester) async {
      final node = FakeFactsBookGateway(
        pending: [
          CouldNotSaveEntry(
            id: 'cqs_OLD',
            reason: CouldNotSaveReason.nodeUnreachable,
            createdAt: factsNow.subtract(const Duration(days: 31)),
            promptDue: true,
          ),
          CouldNotSaveEntry(
            id: 'cqs_NEW',
            reason: CouldNotSaveReason.cloudQuota,
            createdAt: factsNow.subtract(const Duration(days: 3)),
          ),
        ],
      );
      node.failOutbox = true;
      node.failOutbox = true;
      final session = FactsBookSession.fixed(node);
      await session.outbox.add(
        const CaptureRequest(kind: CaptureKind.note, text: 'Old on the phone'),
        'k1',
      );
      await pumpFacts(
        tester,
        const FactsBookNotSavedScreen(),
        session: session,
      );
      expect(
        find.byKey(const ValueKey('factsbook-notsaved-30-cqs_OLD')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('factsbook-notsaved-30-cqs_NEW')),
        findsNothing,
      );
      expect(
        find.text(
          'This has been kept for 30 days. Retry it, export the text, or discard it.',
        ),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      // Asking is not deciding: all are still kept.
      expect(await node.pendingCaptures(), hasLength(2));
      expect(session.outbox.entries, hasLength(1));
    });

    factsTest('empty says everything is saved', (tester) async {
      final node = FakeFactsBookGateway(pending: const []);
      await pumpFacts(tester, const FactsBookNotSavedScreen(), gateway: node);
      expect(find.text('Everything is saved'), findsOneWidget);
    });
  });

  group('Arabic, right to left', () {
    const ar = Locale('ar');

    factsTest('a fact keeps its amount and card ending left to right', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample();
      await pumpFacts(
        tester,
        FactsBookThingScreen(thingId: await _id(node, ThingKind.card)),
        gateway: node,
        locale: ar,
      );
      expect(
        Directionality.of(tester.element(find.byType(KitFactRow).first)),
        TextDirection.rtl,
      );
      expect(
        find.text('\u2066Annual fee is [AMOUNT] CUR\u2069.'),
        findsOneWidget,
      );
      expect(find.textContaining('قلت ذلك'), findsOneWidget);
      expect(find.textContaining('خمّنه النظام · '), findsOneWidget);
      expect(find.text('\u2068[Bank A] Visa ••42\u2069'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    factsTest('Memory, Not saved yet, Memory care and Status speak Arabic', (
      tester,
    ) async {
      await pumpFacts(tester, const FactsBookMemorySection(), locale: ar);
      expect(find.text('الذاكرة'), findsOneWidget);
      expect(find.text('افتح «عنّي»'), findsOneWidget);
      expect(find.text('أضف شيئًا'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await pumpFacts(tester, const FactsBookNotSavedScreen(), locale: ar);
      expect(find.text('لم يُحفظ بعد'), findsWidgets);
      expect(tester.takeException(), isNull);
      await pumpFacts(tester, const FactsBookMemoryCareScreen(), locale: ar);
      expect(find.textContaining('بانتظارك'), findsWidgets);
      expect(find.text('موافقة'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('large text and a narrow phone', () {
    factsTest('the Thing page does not overflow at 2x text', (tester) async {
      final node = FakeFactsBookGateway.sample();
      await pumpFacts(
        tester,
        FactsBookThingScreen(thingId: await _id(node, ThingKind.card)),
        gateway: node,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    }, size: const Size(360, 780));

    factsTest('Not saved yet does not overflow at 2x text', (tester) async {
      await pumpFacts(tester, const FactsBookNotSavedScreen(), textScale: 2);
      expect(tester.takeException(), isNull);
    }, size: const Size(360, 780));

    factsTest('Memory care does not overflow at 2x text', (tester) async {
      await pumpFacts(tester, const FactsBookMemoryCareScreen(), textScale: 2);
      expect(tester.takeException(), isNull);
    }, size: const Size(360, 780));
  });
}
