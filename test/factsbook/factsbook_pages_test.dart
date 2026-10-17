// Memory care, Reminders, Areas and sharing, Status and Set up: the F2 pages
// against the fake node and against the real gateway over a stand-in node,
// plus the developer switch in About.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/factsbook/factsbook_capabilities.dart';
import 'package:opencode_mobile/domain/factsbook/factsbook_types.dart';
import 'package:opencode_mobile/domain/factsbook/fake_factsbook_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/factsbook/factsbook_flag.dart';
import 'package:opencode_mobile/state/factsbook/factsbook_session.dart';
import 'package:opencode_mobile/state/factsbook/factsbook_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/about_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/about_you_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/not_saved_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/settings_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/thing_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/areas_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/connect_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/memory_care_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/memory_section.dart';
import 'package:opencode_mobile/ui/screens/factsbook/reminders_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/status_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/team_control_fixtures.dart' show MemorySecureStorage;
import 'factsbook_test_support.dart';
import 'node_adapter.dart';

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await settle(tester);
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).first);
  await settle(tester);
}

Future<void> _openStatusDetails(WidgetTester tester) async {
  final fold = find.byKey(const ValueKey('factsbook-status-details'));
  await tester.scrollUntilVisible(fold, 200);
  await tester.tap(fold);
  await settle(tester);
}

Object? _fixture(String name) =>
    jsonDecode(File('test/fixtures/factsbook/$name.json').readAsStringSync());

void main() {
  group('Memory care', () {
    factsTest('every change shows its claim, who suggested it, Approve and '
        'Reject; Edit and Skip are a tap on the card', (tester) async {
      final node = FakeFactsBookGateway.sample();
      final first = (await node.reviewItems()).first;
      await pumpFacts(tester, const FactsBookMemoryCareScreen(), gateway: node);
      expect(find.text('Needs you'), findsWidgets);
      expect(find.text('Memory care'), findsNothing);
      expect(find.text('3 waiting for your OK'), findsOneWidget);
      // The title is the claim; the kind of change is a small label.
      expect(find.text('Sam likes books'), findsOneWidget);
      expect(find.text('Sam pays the bill by card ••42'), findsOneWidget);
      expect(find.text('Add a fact'), findsNWidgets(3));
      // Who suggested it is on the card.
      expect(
        find.byKey(ValueKey('factsbook-care-source-${first.id}')),
        findsOneWidget,
      );
      // The money one carries its area and risk, in words.
      expect(find.text('Money area'), findsOneWidget);
      expect(find.text('Money'), findsOneWidget);
      expect(find.text('Approve'), findsNWidgets(3));
      expect(find.text('Reject'), findsNWidgets(3));
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Skip'), findsNothing);
      // Each answer names its claim for screen readers.
      expect(
        find.bySemanticsLabel('Approve “Sam likes books”'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Reject “Sam likes books”'), findsOneWidget);
      // The card's tap offers the other two, naming the claim.
      await _tapKey(tester, 'factsbook-care-${first.id}');
      expect(find.text('Change “Sam likes books”'), findsOneWidget);
      expect(find.text('Skip “Sam likes books”'), findsOneWidget);
    });

    factsTest('the card says who suggested it: you, a rule or an agent', (
      tester,
    ) async {
      ReviewItem item(String n, String text, List<Evidence> evidence) =>
          ReviewItem(
            id: 'rvw_0000000000000000000000000$n',
            reviewClass: ReviewClass.factAdd,
            state: ReviewState.proposed,
            digest: 'a' * 64,
            preconditions: const {'per_00000000000000000000000001': 1},
            proposal: {'kind': 'fact.add', 'text': text},
            evidence: evidence,
          );
      final node = FakeFactsBookGateway(
        review: [
          item('1', 'Sam likes tea', [
            Evidence(source: 'note', observedAt: DateTime(2026, 10, 3, 9)),
          ]),
          item('2', 'Sam owns a bike', const []),
        ],
      );
      await pumpFacts(tester, const FactsBookMemoryCareScreen(), gateway: node);
      expect(find.text('You told it · Oct 3'), findsOneWidget);
      expect(find.text('An agent suggested it'), findsOneWidget);
    });

    factsTest('offers and notes not saved are sections of the same page', (
      tester,
    ) async {
      await pumpFacts(tester, const FactsBookMemoryCareScreen());
      expect(find.text('Not saved yet'), findsWidgets);
      expect(
        find.byKey(const ValueKey('factsbook-needs-notSaved')),
        findsOneWidget,
      );
      await _tapKey(tester, 'factsbook-needs-notSaved');
      expect(find.byType(FactsBookNotSavedScreen), findsOneWidget);
    }, size: const Size(412, 1600));

    factsTest('Approve applies it and it leaves the list', (tester) async {
      final node = FakeFactsBookGateway.sample();
      final first = (await node.reviewItems()).first;
      await pumpFacts(tester, const FactsBookMemoryCareScreen(), gateway: node);
      await _tapKey(tester, 'factsbook-care-approve-${first.id}');
      expect(find.text('Approved.'), findsOneWidget);
      expect(find.text('Sam likes books'), findsNothing);
      expect(find.text('2 waiting for your OK'), findsOneWidget);
      expect(node.calls, contains('decide:approve'));
    });

    factsTest('Reject says it will not come back; Skip leaves it here', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample();
      final items = await node.reviewItems();
      await pumpFacts(tester, const FactsBookMemoryCareScreen(), gateway: node);
      await _tapKey(tester, 'factsbook-care-reject-${items[0].id}');
      expect(
        find.text('Rejected. It will not be proposed again.'),
        findsOneWidget,
      );
      await _tapKey(tester, 'factsbook-care-${items[1].id}');
      await _tapKey(tester, 'factsbook-care-more-skip');
      expect(find.text('Skipped. It stays here.'), findsOneWidget);
      expect(find.text('Sam pays the bill by card ••42'), findsOneWidget);
    });

    factsTest('Edit sends the person\'s words as the edited proposal', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample();
      final first = (await node.reviewItems()).first;
      await pumpFacts(tester, const FactsBookMemoryCareScreen(), gateway: node);
      await _tapKey(tester, 'factsbook-care-${first.id}');
      await _tapKey(tester, 'factsbook-care-more-edit');
      expect(find.text('Edit before approving'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('factsbook-care-edit-field')),
        'Sam likes poems',
      );
      await settle(tester);
      await _tapKey(tester, 'factsbook-care-edit-save');
      await tester.pump(const Duration(milliseconds: 600));
      await settle(tester);
      expect(node.calls, contains('decide:edit'));
      expect(find.text('Approved.'), findsOneWidget);
    });

    factsTest('a proposal that changed fails visibly and nothing is applied', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample();
      final first = (await node.reviewItems()).first;
      await pumpFacts(tester, const FactsBookMemoryCareScreen(), gateway: node);
      node.makeStale(first.id);
      await _tapKey(tester, 'factsbook-care-approve-${first.id}');
      expect(
        find.text(
          'That changed after it was proposed, so nothing was applied. It is off this list now.',
        ),
        findsOneWidget,
      );
      // Refetched: the stale one is no longer offered for approval.
      expect(find.text('Sam likes books'), findsNothing);
      expect(find.text('2 waiting for your OK'), findsOneWidget);
    });

    factsTest('without an approval key the decisions are off and say why', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample();
      await pumpFacts(
        tester,
        const FactsBookMemoryCareScreen(),
        gateway: node,
        canApprove: false,
      );
      expect(
        find.text(
          'This phone cannot approve changes yet. Set up approval to continue.',
        ),
        findsOneWidget,
      );
      final first = (await node.reviewItems()).first;
      await tester.tap(
        find.byKey(ValueKey('factsbook-care-approve-${first.id}')),
      );
      await settle(tester);
      expect(node.calls, isNot(contains('decide:approve')));
      await _tapText(tester, 'Set up approval');
      expect(find.byType(FactsBookConnectScreen), findsOneWidget);
    });

    factsTest('nothing to review says so', (tester) async {
      final node = FakeFactsBookGateway(review: const [], pending: const []);
      await pumpFacts(tester, const FactsBookMemoryCareScreen(), gateway: node);
      expect(find.text('Nothing needs you right now.'), findsOneWidget);
    });

    factsTest('not reachable: plain words with Try again', (tester) async {
      final node = FakeFactsBookGateway()..reachable = false;
      await pumpFacts(tester, const FactsBookMemoryCareScreen(), gateway: node);
      expect(find.text('Memory did not answer'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('Reminders', () {
    factsTest('lists active reminders with when, zone and a pause button', (
      tester,
    ) async {
      await pumpFacts(tester, const FactsBookRemindersScreen());
      expect(find.text('Reminders'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Dentist'), findsOneWidget);
      expect(rich('Oct 21, '), findsOneWidget);
      expect(rich('Home time zone'), findsOneWidget);
      expect(find.byTooltip('Pause “Dentist”'), findsOneWidget);
    });

    factsTest('Pause moves it to Paused, Resume brings it back', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample();
      await pumpFacts(tester, const FactsBookRemindersScreen(), gateway: node);
      await tester.tap(find.byTooltip('Pause “Dentist”'));
      await settle(tester);
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Active'), findsNothing);
      expect((await node.reminders()).single.paused, isTrue);
      await tester.tap(find.byTooltip('Resume “Dentist”'));
      await settle(tester);
      expect(find.text('Active'), findsOneWidget);
      expect(
        node.calls,
        containsAllInOrder(['reminder.pause', 'reminder.resume']),
      );
    });

    factsTest('Edit goes through the same check: date, time, zone and language '
        'shown, node reads the same values', (tester) async {
      final node = FakeFactsBookGateway.sample();
      final id = (await node.reminders()).single.id;
      await pumpFacts(tester, const FactsBookRemindersScreen(), gateway: node);
      await _tapKey(tester, 'factsbook-reminder-$id');
      expect(find.text('Check this reminder'), findsOneWidget);
      for (final row in ['Date', 'Time', 'Time zone', 'Language of dates']) {
        expect(find.text(row), findsOneWidget);
      }
      // Change the zone, then save.
      await _tapKey(tester, 'factsbook-reminder-zone');
      await _tapText(tester, 'This phone\'s time');
      await _tapKey(tester, 'factsbook-reminder-save');
      await tester.pump(const Duration(milliseconds: 600));
      await settle(tester);
      final edited = (await node.reminders()).single;
      expect(edited.schedule.zone, 'floating');
      expect(edited.revision, 2);
      expect(node.calls, contains('reminder.update'));
    });

    factsTest(
      'a repeating reminder is described and edited through the same check',
      (tester) async {
        final node = FakeFactsBookGateway(
          remindersList: [
            Reminder(
              id: 'rem_00000000000000000000000005',
              what: 'Take the vitamins',
              schedule: ReminderSchedule(
                id: 'sch_00000000000000000000000005',
                when: const ScheduleWhen({
                  'every': 'week',
                  'on': ['mon', 'thu'],
                  'at': '08:00',
                }),
                zone: 'floating',
                raw: const {},
              ),
              locale: 'en',
              revision: 1,
            ),
          ],
        );
        await pumpFacts(
          tester,
          const FactsBookRemindersScreen(),
          gateway: node,
        );
        expect(rich('Every week on Mon, Thu at'), findsOneWidget);
        expect(rich('This phone\'s time'), findsOneWidget);
        await tester.tap(find.text('Take the vitamins'));
        await settle(tester);
        expect(find.text('Check this reminder'), findsOneWidget);
        expect(find.text('Repeats'), findsOneWidget);
        await _tapKey(tester, 'factsbook-reminder-save');
        await tester.pump(const Duration(milliseconds: 600));
        await settle(tester);
        final saved = (await node.reminders()).single;
        expect(saved.schedule.when.raw['every'], 'week');
        expect(saved.schedule.id, 'sch_00000000000000000000000005');
        expect(saved.revision, 2);
      },
    );

    factsTest('a schedule the app does not build can be paused, not edited', (
      tester,
    ) async {
      final node = FakeFactsBookGateway(
        remindersList: [
          Reminder(
            id: 'rem_00000000000000000000000006',
            what: 'Check the filter',
            schedule: ReminderSchedule(
              id: 'sch_00000000000000000000000006',
              when: const ScheduleWhen({'every': '6h'}),
              zone: 'vault',
              raw: const {},
            ),
            locale: 'en',
            revision: 1,
          ),
        ],
      );
      await pumpFacts(tester, const FactsBookRemindersScreen(), gateway: node);
      expect(rich('Custom schedule'), findsOneWidget);
      await tester.tap(find.text('Check the filter'));
      await settle(tester);
      expect(find.text('Check this reminder'), findsNothing);
      expect(find.byTooltip('Pause “Check the filter”'), findsOneWidget);
    });

    factsTest(
      'Add a reminder asks for the title, then saves it with the node\'s reading',
      (tester) async {
        final node = FakeFactsBookGateway(remindersList: const []);
        await pumpFacts(
          tester,
          const FactsBookRemindersScreen(),
          gateway: node,
        );
        await _tapKey(tester, 'factsbook-reminders-add');
        expect(find.text('Check this reminder'), findsOneWidget);
        // Nothing to save until it has a title.
        await tester.tap(find.byKey(const ValueKey('factsbook-reminder-save')));
        await settle(tester);
        expect(node.calls, isNot(contains('reminder.create')));
        await tester.enterText(
          find.byKey(const ValueKey('factsbook-reminder-title')),
          'Water the plants',
        );
        await settle(tester);
        await _tapKey(tester, 'factsbook-reminder-repeat');
        await _tapText(tester, 'Every day');
        await _tapKey(tester, 'factsbook-reminder-save');
        await tester.pump(const Duration(milliseconds: 600));
        await settle(tester);
        final made = (await node.reminders()).single;
        expect(made.what, 'Water the plants');
        expect(made.schedule.when.raw['every'], 'day');
        expect(find.text('Water the plants'), findsOneWidget);
        expect(rich('Every day at'), findsOneWidget);
      },
    );

    factsTest('a weekly reminder picks its days', (tester) async {
      final node = FakeFactsBookGateway(remindersList: const []);
      await pumpFacts(tester, const FactsBookRemindersScreen(), gateway: node);
      await _tapKey(tester, 'factsbook-reminders-add');
      await tester.enterText(
        find.byKey(const ValueKey('factsbook-reminder-title')),
        'Rubbish out',
      );
      await settle(tester);
      await _tapKey(tester, 'factsbook-reminder-repeat');
      await _tapText(tester, 'Every week');
      expect(
        find.byKey(const ValueKey('factsbook-reminder-weekday-1')),
        findsOneWidget,
      );
      // The sheet starts on tomorrow's weekday; add the day after it, so
      // the test does not depend on which day it runs.
      final tomorrow = DateTime.now().add(const Duration(days: 1)).weekday;
      final added = tomorrow % 7 + 1;
      await _tapKey(tester, 'factsbook-reminder-weekday-$added');
      await _tapKey(tester, 'factsbook-reminder-save');
      await tester.pump(const Duration(milliseconds: 600));
      await settle(tester);
      final days =
          (await node.reminders()).single.schedule.when.raw['on'] as List;
      const names = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
      expect(days, hasLength(2));
      expect(days, containsAll([names[tomorrow - 1], names[added - 1]]));
    });

    factsTest('the row says this phone does not sound it; no banner on top', (
      tester,
    ) async {
      await pumpFacts(tester, const FactsBookRemindersScreen());
      expect(rich('does not sound them yet'), findsNothing);
      expect(rich('Not sounded on this phone'), findsOneWidget);
    });

    factsTest('no reminders yet says how to add one', (tester) async {
      final node = FakeFactsBookGateway(remindersList: const []);
      await pumpFacts(tester, const FactsBookRemindersScreen(), gateway: node);
      expect(find.text('No reminders yet'), findsOneWidget);
    });

    factsTest('a change made elsewhere is said in plain words', (tester) async {
      final node = FakeFactsBookGateway.sample();
      final reminder = (await node.reminders()).single;
      await pumpFacts(tester, const FactsBookRemindersScreen(), gateway: node);
      // Someone else paused it first: the phone's copy is one revision behind.
      await node.setReminderPaused(reminder, paused: true);
      await tester.tap(find.byTooltip('Pause “Dentist”'));
      await settle(tester);
      expect(
        find.text(
          'That changed since you looked. Look again, then try once more.',
        ),
        findsOneWidget,
      );
      expect(find.text('Paused'), findsOneWidget);
    });
  });

  group('Areas and sharing', () {
    factsTest(
      'the four built-in areas, with sharing, storage and review rules',
      (tester) async {
        await pumpFacts(tester, const FactsBookAreasScreen());
        for (final area in ['Family', 'Money', 'Health', 'Work']) {
          expect(find.text(area), findsOneWidget);
        }
        expect(
          find.text('Other apps and agents can read it'),
          findsNWidgets(4),
        );
        expect(find.text('Locked folder'), findsNWidgets(2));
        expect(
          find.text('New facts wait for your OK first.'),
          findsNWidgets(2),
        );
        // The node cannot make a new area, so none is offered.
        expect(
          find.textContaining(
            'These areas are built in',
            findRichText: true,
            skipOffstage: false,
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Add an area'), findsNothing);
        expect(find.textContaining('New area'), findsNothing);
      },
    );

    factsTest('turning sharing off sends the change, signed by the node call', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample();
      await pumpFacts(tester, const FactsBookAreasScreen(), gateway: node);
      await _tapKey(tester, 'factsbook-area-share-family');
      expect(node.calls, contains('area:family'));
      expect(
        (await node.areas())
            .firstWhere((a) => a.slug == 'family')
            .share
            .readByDefault,
        isFalse,
      );
    });

    factsTest('sharing a locked-folder area asks first', (tester) async {
      final node = FakeFactsBookGateway.sample();
      await pumpFacts(tester, const FactsBookAreasScreen(), gateway: node);
      await _tapKey(tester, 'factsbook-area-share-money');
      expect(find.text('Let others read Money?'), findsOneWidget);
      // Cancel by tapping outside: nothing changes.
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(node.calls, isNot(contains('area:money')));
      await _tapKey(tester, 'factsbook-area-share-money');
      await _tapKey(tester, 'factsbook-area-confirm-money');
      await tester.pump(const Duration(milliseconds: 600));
      await settle(tester);
      expect(node.calls, contains('area:money'));
      expect(
        (await node.areas())
            .firstWhere((a) => a.slug == 'money')
            .share
            .readByDefault,
        isTrue,
      );
    });

    factsTest('without an approval key the switches are off and say why', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample();
      await pumpFacts(
        tester,
        const FactsBookAreasScreen(),
        gateway: node,
        canApprove: false,
      );
      expect(find.text('Set up approval'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('factsbook-area-share-family')),
      );
      await settle(tester);
      expect(node.calls, isNot(contains('area:family')));
    });

    factsTest('a node that does not offer it yet says so, not an error code', (
      tester,
    ) async {
      final node = _NotEnabledAreas();
      await pumpFacts(tester, const FactsBookAreasScreen(), gateway: node);
      expect(find.text('That is turned off in this memory.'), findsOneWidget);
      expect(find.textContaining('not_enabled'), findsNothing);
    });
  });

  group('Status', () {
    factsTest(
      'one row per module with its canonical word, never a single green',
      (tester) async {
        await pumpFacts(tester, const FactsBookStatusScreen());
        expect(find.text('Status'), findsOneWidget);
        // One summary line first; the module rows are under Details.
        expect(find.text('Everything is working'), findsOneWidget);
        expect(rich('Ready · updated 3h ago'), findsNothing);
        await _openStatusDetails(tester);
        expect(rich('Ready · updated 3h ago'), findsOneWidget);
        expect(find.text('Storage'), findsOneWidget);
        // The three cloud rows are one Backup row.
        expect(find.text('Cloud backup'), findsNothing);
        expect(find.text('Cloud copy'), findsNothing);
        expect(find.text('Backup'), findsOneWidget);
        expect(find.text('Replication'), findsOneWidget);
        expect(
          rich('Off · not turned on yet · updated 3h ago'),
          findsNWidgets(2),
        );
        // The report's own time, and freshness it cannot know.
        expect(find.text('Checked'), findsOneWidget);
        expect(rich('Just now'), findsWidgets);
        expect(find.text('No backup yet'), findsOneWidget);
        expect(find.text('Locked'), findsOneWidget);
        // Replication off is said, never hidden behind a green word.
        await tester.scrollUntilVisible(
          find.textContaining('Replication is off', findRichText: true),
          200,
        );
        expect(find.text('Not available yet'), findsNothing);
        expect(find.text('Cloud sync and backup'), findsOneWidget);
        expect(find.text('Opening the locked folder'), findsOneWidget);
        expect(find.text('Reminder alarms on this phone'), findsOneWidget);
      },
    );

    factsTest('all six canonical states have their own word', (tester) async {
      final node = _StatesNode();
      await pumpFacts(tester, const FactsBookStatusScreen(), gateway: node);
      await _openStatusDetails(tester);
      for (final word in [
        'Ready',
        'Waiting',
        'Stale',
        'Failed',
        'Off',
        'Not set up',
      ]) {
        expect(rich('$word · updated'), findsOneWidget, reason: word);
      }
    });

    factsTest('Disconnect names the target and the effect first', (
      tester,
    ) async {
      await pumpFacts(tester, const FactsBookStatusScreen());
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('factsbook-status-disconnect')),
        200,
      );
      // The action names what it disconnects.
      expect(find.text('Disconnect this memory'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('factsbook-status-disconnect')),
      );
      await settle(tester);
      expect(find.text('Disconnect this memory?'), findsOneWidget);
      expect(
        find.textContaining(
          'notes waiting on this phone stay until you discard them',
        ),
        findsOneWidget,
      );
    });

    factsTest('Disconnect names the memory on this phone, or the address', (
      tester,
    ) async {
      FactsBookLink at(String url) => FactsBookLink(
        baseUrl: Uri.parse(url),
        clientId: 'cli_00000000000000000000000001',
        vault: 'vlt_00000000000000000000000001',
        rootFingerprint: 'a' * 64,
        node: 'dev_00000000000000000000000001',
        scopes: const ['read'],
      );
      for (final (url, name) in [
        ('http://127.0.0.1:8787', 'this phone\'s memory'),
        ('http://100.64.0.7:8787', '100.64.0.7:8787'),
      ]) {
        await pumpFacts(
          tester,
          const FactsBookStatusScreen(),
          session: FactsBookSession.fixed(
            FakeFactsBookGateway.sample(),
            link: at(url),
          ),
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('factsbook-status-disconnect')),
          200,
        );
        expect(find.text('Disconnect $name'), findsOneWidget, reason: url);
      }
    });

    factsTest(
      'approval shows Not set up with a way in when the phone has no key',
      (tester) async {
        await pumpFacts(
          tester,
          const FactsBookStatusScreen(),
          canApprove: false,
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('factsbook-status-approve')),
          200,
        );
        await tester.tap(
          find.byKey(const ValueKey('factsbook-status-approve')),
        );
        await settle(tester);
        expect(find.byType(FactsBookConnectScreen), findsOneWidget);
      },
    );

    factsTest('not reachable: plain words', (tester) async {
      final node = FakeFactsBookGateway()..reachable = false;
      await pumpFacts(tester, const FactsBookStatusScreen(), gateway: node);
      expect(find.text('Memory did not answer'), findsOneWidget);
    });
  });

  group('Settings', () {
    factsTest('shows what the node lets a client see, and the cap can change', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample();
      await pumpFacts(tester, const FactsBookSettingsScreen(), gateway: node);
      expect(find.text('Memory settings'), findsOneWidget);
      expect(rich('15 minutes'), findsOneWidget);
      expect(find.text('Locked folder stays open for'), findsOneWidget);
      expect(find.text('Items a day'), findsOneWidget);
      expect(rich('08:00'), findsOneWidget);
      expect(rich('22:00-07:00'), findsOneWidget);
      expect(rich('Nothing may be spent'), findsOneWidget);
      await _tapKey(tester, 'factsbook-settings-cap');
      await _tapText(tester, '3 items');
      await tester.pump(const Duration(milliseconds: 600));
      await settle(tester);
      expect(node.calls, contains('settings:cap:3'));
      expect((await node.settings()).brief.capPerDay, 3);
      expect((await node.settings()).revision, 2);
    });

    factsTest('without an approval key the cap is off and says why', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample();
      await pumpFacts(
        tester,
        const FactsBookSettingsScreen(),
        gateway: node,
        canApprove: false,
      );
      expect(
        find.byKey(const ValueKey('factsbook-settings-needs-owner')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('factsbook-settings-cap')));
      await settle(tester);
      expect(node.calls.where((c) => c.startsWith('settings:')), isEmpty);
    });

    factsTest('area sharing is one row away', (tester) async {
      await pumpFacts(tester, const FactsBookSettingsScreen());
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('factsbook-settings-areas')),
        200,
      );
      await tester.tap(find.byKey(const ValueKey('factsbook-settings-areas')));
      await settle(tester);
      expect(find.byType(FactsBookAreasScreen), findsOneWidget);
    });

    factsTest('a node that will not show settings says so in plain words', (
      tester,
    ) async {
      final node = _ForbiddenSettings();
      await pumpFacts(tester, const FactsBookSettingsScreen(), gateway: node);
      expect(
        find.text('This phone is not allowed to do that.'),
        findsOneWidget,
      );
      expect(find.textContaining('forbidden_scope'), findsNothing);
    });

    factsTest('About you reaches it from its footer, not a menu', (
      tester,
    ) async {
      await pumpFacts(tester, const FactsBookAboutYouScreen());
      expect(find.byTooltip('More about you'), findsNothing);
      await tester.drag(find.byType(ListView).first, const Offset(0, -900));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('factsbook-about-settings')));
      await settle(tester);
      expect(find.text('Memory settings'), findsOneWidget);
    });
  });

  group('what the capability matrix hides', () {
    const noReminders = FactsBookCapabilities(
      milestone: 'test',
      supported: {FactsBookCapabilities.search},
      disabled: {},
    );

    factsTest(
      'a node that does not support reminders or rules has no row for them',
      (tester) async {
        final node = FakeFactsBookGateway.sample();
        final session = FactsBookSession.fixed(node)
          ..capabilities = noReminders;
        await pumpFacts(
          tester,
          const FactsBookAboutYouScreen(),
          session: session,
        );
        expect(
          find.byKey(const ValueKey('factsbook-about-reminders')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('factsbook-about-triggers')),
          findsNothing,
        );
        // Needs you and Areas are always there.
        expect(
          find.byKey(const ValueKey('factsbook-about-needs-you')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('factsbook-about-areas')),
          findsOneWidget,
        );
      },
    );

    factsTest('no add-a-reminder row without the capability', (tester) async {
      final session = FactsBookSession.fixed(FakeFactsBookGateway.sample())
        ..capabilities = noReminders;
      await pumpFacts(
        tester,
        const FactsBookRemindersScreen(),
        session: session,
      );
      expect(
        find.byKey(const ValueKey('factsbook-reminders-add')),
        findsNothing,
      );
    });

    factsTest('no export without the capability', (tester) async {
      final node = FakeFactsBookGateway.sample();
      final id = (await node.pendingCaptures()).first.id;
      await pumpFacts(
        tester,
        const FactsBookNotSavedScreen(),
        session: FactsBookSession.fixed(node)..capabilities = noReminders,
      );
      expect(find.byKey(ValueKey('factsbook-export-$id')), findsNothing);
    });

    factsTest('a node note has Export with the capability', (tester) async {
      final node = FakeFactsBookGateway.sample();
      final id = (await node.pendingCaptures()).first.id;
      await pumpFacts(tester, const FactsBookNotSavedScreen(), gateway: node);
      expect(find.byKey(ValueKey('factsbook-export-$id')), findsOneWidget);
    });

    factsTest(
      'Status lists what is off as not available yet, never as working',
      (tester) async {
        await pumpFacts(tester, const FactsBookStatusScreen());
        await tester.scrollUntilVisible(
          find.byKey(
            const ValueKey('factsbook-status-not-yet-cloud_transport'),
          ),
          200,
        );
        for (final key in [
          'cloud_transport',
          'sensitive_unlock',
          'phone_alarm_delivery',
        ]) {
          expect(
            find.byKey(ValueKey('factsbook-status-not-yet-$key')),
            findsOneWidget,
            reason: key,
          );
        }
      },
    );
  });

  group('unsaved-capture export', () {
    factsTest(
      'a note the node holds is exported as an encrypted object that is copyable',
      (tester) async {
        final node = FakeFactsBookGateway.sample();
        final id = (await node.pendingCaptures()).first.id;
        await pumpFacts(tester, const FactsBookNotSavedScreen(), gateway: node);
        await _tapKey(tester, 'factsbook-export-$id');
        expect(find.text('Export this note'), findsOneWidget);
        expect(rich('does not unlock the locked folder'), findsOneWidget);
        expect(find.text('Copy export'), findsOneWidget);
        expect(node.calls, contains('export'));
      },
    );
  });

  group('an edited approval keeps where it was first read', () {
    factsTest('the fact shows its original source and date beneath it', (
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
                text: 'Likes poems.',
                provenance: FactProvenance.told,
                observedAt: factsNow,
                source: '',
                support: [
                  Evidence(
                    source: 'itm_00000000000000000000000001',
                    observedAt: DateTime(2026, 10, 3, 9),
                  ),
                ],
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
      expect(find.text('You told it · Oct 11'), findsOneWidget);
      expect(
        find.text('Originally read from something you saved · Oct 3'),
        findsOneWidget,
      );
    });

    factsTest(
      'Memory care shows the evidence of a proposal the person is about to edit',
      (tester) async {
        final node = FakeFactsBookGateway(
          review: [
            ReviewItem(
              id: 'rvw_00000000000000000000000009',
              reviewClass: ReviewClass.factAdd,
              state: ReviewState.proposed,
              digest: 'a' * 64,
              preconditions: const {'per_00000000000000000000000001': 1},
              proposal: const {'kind': 'fact.add', 'text': 'Sam likes books'},
              evidence: [
                Evidence(
                  source: 'itm_00000000000000000000000001',
                  observedAt: DateTime(2026, 10, 3, 9),
                ),
              ],
            ),
          ],
        );
        await pumpFacts(
          tester,
          const FactsBookMemoryCareScreen(),
          gateway: node,
        );
        expect(find.text('From something you saved · Oct 3'), findsOneWidget);
      },
    );
  });

  group('the signed history on Status', () {
    FactsBookLink link(String fingerprint) => FactsBookLink(
      baseUrl: Uri.parse('http://127.0.0.1:8787'),
      clientId: 'cli_00000000000000000000000001',
      vault: 'vlt_00000000000000000000000001',
      rootFingerprint: fingerprint,
      node: 'dev_00000000000000000000000001',
      scopes: const ['read', 'write'],
    );
    final chain = ControlChain.fromJson(
      (_fixture('control')! as Map).cast<String, Object?>(),
    );

    factsTest('verified against the key pinned at pairing', (tester) async {
      final node = FakeFactsBookGateway.sample()..controlChain = chain;
      await pumpFacts(
        tester,
        const FactsBookStatusScreen(),
        session: FactsBookSession.fixed(
          node,
          link: link(chain.rootFingerprint),
        ),
      );
      await _openStatusDetails(tester);
      expect(
        rich('Verified against the key pinned when you paired'),
        findsOneWidget,
      );
      expect(find.text('Everything is working'), findsOneWidget);
    });

    factsTest('a different pin means it is not trusted, in plain words', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample()..controlChain = chain;
      await pumpFacts(
        tester,
        const FactsBookStatusScreen(),
        session: FactsBookSession.fixed(node, link: link('b' * 64)),
      );
      // The summary line says it before Details do.
      expect(find.text('1 thing needs a look'), findsOneWidget);
      await _openStatusDetails(tester);
      expect(
        rich('Could not be verified. Do not approve anything until it is.'),
        findsOneWidget,
      );
    });

    factsTest('a node that will not show it is "not checked", never verified', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.sample();
      await pumpFacts(
        tester,
        const FactsBookStatusScreen(),
        session: FactsBookSession.fixed(
          node,
          link: link(chain.rootFingerprint),
        ),
      );
      await _openStatusDetails(tester);
      expect(rich('Not checked'), findsOneWidget);
    });

    factsTest('a fork is said, and approvals are paused', (tester) async {
      final forked = ControlChain.fromJson({
        ...(_fixture('control')! as Map).cast<String, Object?>(),
        'forked': true,
      });
      final node = FakeFactsBookGateway.sample()..controlChain = forked;
      await pumpFacts(
        tester,
        const FactsBookStatusScreen(),
        session: FactsBookSession.fixed(
          node,
          link: link(chain.rootFingerprint),
        ),
      );
      await _openStatusDetails(tester);
      expect(rich('Two competing histories were found'), findsOneWidget);
    });
  });

  group('Set up, against a stand-in for the real node', () {
    late SharedPreferences prefs;
    late MemorySecureStorage secure;
    late NodeAdapter node;
    late FactsBookSession session;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      secure = MemorySecureStorage();
      node = NodeAdapter();
      final dio = Dio(BaseOptions(validateStatus: (_) => true))
        ..httpClientAdapter = node;
      session = FactsBookSession(
        store: FactsBookStore(prefs: prefs, secure: secure),
        profileId: 'srv-1',
        dio: dio,
      );
      await session.load();
    });

    void nodeAnswers() {
      node
        ..reply('GET /v1/status', _fixture('status'))
        ..reply('GET /v1/review', _fixture('review'))
        ..reply('GET /v1/inbox/pending', _fixture('couldnt-save'))
        ..reply('GET /v1/things', _fixture('things'));
    }

    factsTest('before pairing the section is one row, Set up FactsBook', (
      tester,
    ) async {
      await pumpFacts(tester, const FactsBookMemorySection(), session: session);
      expect(find.text('Set up Memory'), findsOneWidget);
      expect(find.text('Open About you'), findsNothing);
      expect(find.text('Add something'), findsNothing);
    });

    factsTest('a public address is refused in plain words', (tester) async {
      await pumpFacts(tester, const FactsBookMemorySection(), session: session);
      await _tapText(tester, 'Set up Memory');
      expect(find.byType(FactsBookConnectScreen), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('factsbook-connect-address')),
        'example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('factsbook-connect-code')),
        'c' * 32,
      );
      await settle(tester);
      await _tapKey(tester, 'factsbook-connect-button');
      expect(find.text('Could not connect'), findsOneWidget);
      expect(find.textContaining('not on a private network'), findsOneWidget);
      expect(node.calls, isEmpty);
    });

    factsTest('Connect waits for both fields, a wrong code says so, and stores '
        'nothing', (tester) async {
      await pumpFacts(tester, const FactsBookMemorySection(), session: session);
      await _tapText(tester, 'Set up Memory');
      await tester.enterText(
        find.byKey(const ValueKey('factsbook-connect-address')),
        '127.0.0.1:8787',
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('factsbook-connect-button')));
      await settle(tester);
      expect(node.calls, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('factsbook-connect-code')),
        'wrong',
      );
      await settle(tester);
      node.reply('POST /v1/pair', {
        'error': {
          'code': 'forbidden_scope',
          'message': 'm',
          'hint': 'h',
          'request_id': 'op_00000000000000000000000009',
        },
      }, status: 403);
      await _tapKey(tester, 'factsbook-connect-button');
      expect(
        find.text('That code did not work. Ask the node for a new one.'),
        findsOneWidget,
      );
      // No token: only this phone's own key was made.
      expect(secure.values.containsKey('oc.factsbook.srv-1'), isFalse);
      expect(session.paired, isFalse);
    });

    factsTest('a good code pairs, stores the token only in secure storage and '
        'the section shows the real node\'s data', (tester) async {
      nodeAnswers();
      node.reply('POST /v1/pair', {
        'token': 'tok_secret',
        'client_id': 'cli_00000000000000000000000001',
        'scopes': ['read', 'write'],
        'vault': 'vlt_00000000000000000000000001',
        'root_fingerprint': 'a' * 64,
        'node': 'dev_00000000000000000000000001',
      });
      await pumpFacts(tester, const FactsBookMemorySection(), session: session);
      await _tapText(tester, 'Set up Memory');
      await tester.enterText(
        find.byKey(const ValueKey('factsbook-connect-address')),
        '127.0.0.1:8787',
      );
      await tester.enterText(
        find.byKey(const ValueKey('factsbook-connect-code')),
        'c' * 32,
      );
      await settle(tester);
      await _tapKey(tester, 'factsbook-connect-button');
      await tester.pump(const Duration(milliseconds: 600));
      await settle(tester);
      expect(session.paired, isTrue);
      expect(secure.values['oc.factsbook.srv-1'], 'tok_secret');
      // The page behind now reads the node through the real gateway.
      expect(find.text('Open About you'), findsOneWidget);
      expect(find.text('1 change to review'), findsOneWidget);
      expect(find.text('1 note not saved yet'), findsOneWidget);
      expect(find.text('Sam'), findsOneWidget);
      final reads = node.calls
          .where((c) => c.method == 'GET')
          .map((c) => c.uri.path);
      expect(
        reads,
        containsAll([
          '/v1/status',
          '/v1/review',
          '/v1/inbox/pending',
          '/v1/things',
        ]),
      );
      // Every call after pairing carries the token in a header only.
      for (final call in node.calls.where((c) => c.uri.path != '/v1/pair')) {
        expect(call.headers['Authorization'], 'Bearer tok_secret');
        expect(call.uri.toString(), isNot(contains('tok_secret')));
      }
    });

    factsTest(
      'the page shows this phone\'s public key for the console, never the '
      'private one',
      (tester) async {
        await pumpFacts(
          tester,
          const FactsBookConnectScreen(),
          session: session,
        );
        expect(find.text('This phone\'s public key'), findsWidgets);
        final seed = secure.values['oc.factsbookOwner.srv-1'];
        expect(seed, isNotNull);
        expect(find.textContaining(seed!), findsNothing);
      },
    );
  });

  group('the developer switch in About', () {
    setUp(() {
      PackageInfo.setMockInitialValues(
        appName: 'OpenCode Mobile',
        packageName: 'io.example.app',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
    });

    testWidgets('is off by default and turns FactsBook on and off', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(412, 1400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = ConnectionController(ProfileStore(prefs: prefs));
      addTearDown(controller.dispose);
      late WidgetRef ref;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [connProvider.overrideWithValue(controller)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, r, _) {
                ref = r;
                return AboutScreen(controller: controller);
              },
            ),
          ),
        ),
      );
      await settle(tester);
      expect(find.text('Developer'), findsOneWidget);
      final switchFinder = find.byKey(const ValueKey('about-factsbook-switch'));
      await tester.ensureVisible(switchFinder);
      expect(tester.widget<Switch>(switchFinder).value, isFalse);
      expect(prefs.getBool(FactsBookFlag.preferenceKey), isNull);
      expect(ref.read(factsBookEnabledProvider), isFalse);
      await tester.tap(switchFinder);
      await settle(tester);
      expect(prefs.getBool('oc.dev.factsbook'), isTrue);
      expect(ref.read(factsBookEnabledProvider), isTrue);
      await tester.tap(switchFinder);
      await settle(tester);
      expect(prefs.getBool('oc.dev.factsbook'), isFalse);
      expect(ref.read(factsBookEnabledProvider), isFalse);
    });

    testWidgets('a build without a connection shows no switch', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AboutScreen(),
        ),
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('about-developer')), findsNothing);
    });
  });
}

/// A node whose areas call is one it does not offer yet.
class _NotEnabledAreas extends FakeFactsBookGateway {
  @override
  Future<List<Area>> areas() async =>
      throw const FactsBookException('not_enabled', status: 501);
}

/// A node that reports every canonical state.
class _StatesNode extends FakeFactsBookGateway {
  @override
  Future<NodeStatus> status() async {
    final since = DateTime(2026, 10, 11, 9);
    return NodeStatus(
      modules: {
        for (final s in ModuleState.values)
          s.name: ModuleStatus(state: s, since: since),
      },
    );
  }
}

/// A node whose settings call is one this client may not make.
class _ForbiddenSettings extends FakeFactsBookGateway {
  @override
  Future<FactsBookSettings> settings() async =>
      throw const FactsBookException('forbidden_scope', status: 403);
}
