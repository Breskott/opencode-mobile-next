// The trigger screens against the fake node (spec 44): Triggers grouped by
// source with counts and pause, the rule editor in plain words with a test
// on a sample, "Why this fired", trigger outcomes in Memory care, the
// conversation offer that seeds a new chat with its summary only, and the
// capability gates. Arabic renders right to left.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/factsbook/factsbook_capabilities.dart';
import 'package:opencode_mobile/domain/factsbook/factsbook_trigger_types.dart';
import 'package:opencode_mobile/domain/factsbook/fake_factsbook_gateway.dart';
import 'package:opencode_mobile/state/factsbook/factsbook_session.dart';
import 'package:opencode_mobile/ui/screens/chats/chats_host.dart'
    show chatsHostProvider;
import 'package:opencode_mobile/ui/screens/factsbook/event_detail_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/memory_care_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/rule_editor_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/settings_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/about_you_screen.dart';
import 'package:opencode_mobile/ui/screens/factsbook/triggers_screen.dart';

import '../support/chats_fakes.dart';
import 'factsbook_test_support.dart';

/// Scrolls the page until [finder] is built: the lists are lazy, so what is
/// far from the viewport does not exist until it is near.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  final page = find.byType(Scrollable).first;
  for (final direction in [-300.0, 300.0]) {
    for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
      await tester.drag(page, Offset(0, direction));
      await tester.pump();
    }
  }
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await _reveal(tester, finder);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await settle(tester);
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  final finder = find.byKey(ValueKey(key));
  await _reveal(tester, finder);
  await tester.enterText(finder, text);
  await settle(tester);
}

String _fieldText(WidgetTester tester, String key) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(EditableText),
      ),
    )
    .controller
    .text;

/// A tall window, so the whole lazy list is built and nothing needs scrolling.
void tTest(String name, Future<void> Function(WidgetTester tester) body) =>
    factsTest(name, body, size: const Size(412, 3000));

void main() {
  group('Triggers', () {
    tTest('rules are grouped by source with counts and the week', (
      tester,
    ) async {
      await pumpFacts(
        tester,
        const FactsBookTriggersScreen(),
        gateway: FakeFactsBookGateway.withTriggers(),
      );
      expect(find.text('When something new arrives'), findsOneWidget);
      expect(find.text('Triggers'), findsNothing);
      expect(find.text('Text you share · 1 rule'), findsOneWidget);
      expect(find.text('Conversations you save · 1 rule'), findsOneWidget);
      expect(find.text('Library appointments'), findsOneWidget);
      expect(rich('This week: 1 proposed, 1 ignored, 1 offer'), findsOneWidget);
      expect(rich('Looks for an appointment'), findsOneWidget);
      // The other rule is paused and says so.
      expect(find.text('Paused'), findsOneWidget);
      expect(
        find.textContaining('A rule only suggests. Nothing is saved or sent'),
        findsOneWidget,
      );
    });

    tTest('pause signs a replacement and the row says Paused', (tester) async {
      final node = FakeFactsBookGateway.withTriggers();
      await pumpFacts(tester, const FactsBookTriggersScreen(), gateway: node);
      final library = (await node.rules()).first;
      await _tapKey(tester, 'factsbook-rule-pause-${library.id}');
      expect(node.triggerCalls, contains('rule.replace'));
      expect(find.text('Rule paused.'), findsOneWidget);
      expect(find.text('Paused'), findsNWidgets(2));
      // And resume it.
      await _tapKey(tester, 'factsbook-rule-pause-${library.id}');
      expect(find.text('Rule is on again.'), findsOneWidget);
      expect(find.text('Paused'), findsOneWidget);
    });

    tTest('a phone without an approval key cannot pause', (tester) async {
      final node = FakeFactsBookGateway.withTriggers();
      await pumpFacts(
        tester,
        const FactsBookTriggersScreen(),
        gateway: node,
        canApprove: false,
      );
      expect(
        find.byKey(const ValueKey('factsbook-triggers-needs-owner')),
        findsOneWidget,
      );
      final library = (await node.rules()).first;
      await tester.tap(
        find.byKey(ValueKey('factsbook-rule-pause-${library.id}')),
      );
      await settle(tester);
      expect(node.triggerCalls, isNot(contains('rule.replace')));
    });

    tTest('no rules is said plainly with a way to make one', (tester) async {
      await pumpFacts(tester, const FactsBookTriggersScreen());
      expect(find.text('No rules yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('factsbook-triggers-new')), findsOne);
    });

    tTest('a node without triggers says rules are not turned on', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.withTriggers()
        ..triggersAvailable = false;
      await pumpFacts(tester, const FactsBookTriggersScreen(), gateway: node);
      expect(find.text('Rules are off here'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('factsbook-triggers-new')),
        findsNothing,
      );
    });

    tTest('a matrix without the capability asks the node nothing', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.withTriggers();
      const none = FactsBookCapabilities(
        milestone: 'test',
        supported: {FactsBookCapabilities.search},
        disabled: {},
      );
      await pumpFacts(
        tester,
        const FactsBookTriggersScreen(),
        session: FactsBookSession.fixed(node)..capabilities = none,
      );
      expect(find.text('Rules are off here'), findsOneWidget);
      expect(node.triggerCalls, isEmpty);
    });

    tTest('About you and settings link to Triggers only with the capability', (
      tester,
    ) async {
      await pumpFacts(tester, const FactsBookSettingsScreen());
      expect(find.text('When something new arrives'), findsOneWidget);
      const none = FactsBookCapabilities(
        milestone: 'test',
        supported: {FactsBookCapabilities.search},
        disabled: {},
      );
      await pumpFacts(
        tester,
        const FactsBookSettingsScreen(),
        session: FactsBookSession.fixed(FakeFactsBookGateway.sample())
          ..capabilities = none,
      );
      expect(find.text('When something new arrives'), findsNothing);
      await pumpFacts(tester, const FactsBookAboutYouScreen());
      expect(
        find.byKey(const ValueKey('factsbook-about-triggers')),
        findsOneWidget,
      );
    });

    tTest('there is no Notification access row until the feature exists', (
      tester,
    ) async {
      await pumpFacts(
        tester,
        const FactsBookTriggersScreen(),
        gateway: FakeFactsBookGateway.withTriggers(),
      );
      expect(find.textContaining('Notification'), findsNothing);
      expect(find.textContaining('planned'), findsNothing);
      expect(find.textContaining('version 1.1'), findsNothing);
    });

    tTest('Arabic reads right to left', (tester) async {
      await pumpFacts(
        tester,
        const FactsBookTriggersScreen(),
        gateway: FakeFactsBookGateway.withTriggers(),
        locale: const Locale('ar'),
      );
      expect(find.text('عند وصول شيء جديد'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('عند وصول شيء جديد'))),
        TextDirection.rtl,
      );
      expect(find.text('Triggers'), findsNothing);
    });
  });

  group('the rule editor', () {
    tTest('a new rule is tested as a draft before it is saved, then saved', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.withTriggers();
      await pumpFacts(tester, const FactsBookRuleEditorScreen(), gateway: node);
      await _type(tester, 'factsbook-rule-name', 'Clinic visits');
      await _tapKey(tester, 'factsbook-rule-example');
      expect(
        _fieldText(tester, 'factsbook-rule-sample'),
        startsWith('Appointment: Library visit | '),
      );
      await _tapKey(tester, 'factsbook-rule-test');
      // Tested as it stands: nothing saved, nothing signed.
      expect(node.triggerCalls, contains('rule.testDraft'));
      expect(node.triggerCalls, isNot(contains('rule.create')));
      expect(find.textContaining('It matches. Found: Library visit'), findsOne);
      expect(
        find.textContaining('Would propose: propose a reminder'),
        findsOne,
      );
      expect((await node.rules()).length, 2);
      expect((await node.events()).length, 3);

      await _tapKey(tester, 'factsbook-rule-save');
      expect(node.triggerCalls, contains('rule.create'));
      expect(find.text('Rule saved.'), findsOneWidget);
      final saved = (await node.rules()).last;
      expect(saved.definition.name, 'Clinic visits');
      expect(saved.definition.autoStart, isFalse);
      expect(saved.definition.template.version, 2);
      expect(saved.definition.source.kind, TriggerSourceKind.share);
      expect(saved.definition.hasOutcome(TriggerOutcomeKind.reminder), isTrue);
    });

    tTest('a sender claim narrows the rule and is saved with it', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.withTriggers();
      await pumpFacts(tester, const FactsBookRuleEditorScreen(), gateway: node);
      await _type(tester, 'factsbook-rule-name', 'From Sam');
      await _type(tester, 'factsbook-rule-sender', ' Sam ');
      expect(find.text('Sender claim (optional)'), findsOneWidget);
      await _tapKey(tester, 'factsbook-rule-save');
      final saved = (await node.rules()).last;
      expect(saved.definition.senderClaim, 'Sam');
    });

    tTest('a sample that does not match says why', (tester) async {
      final node = FakeFactsBookGateway.withTriggers();
      final rule = (await node.rules()).first;
      await pumpFacts(
        tester,
        FactsBookRuleEditorScreen(rule: rule),
        gateway: node,
      );
      await _type(tester, 'factsbook-rule-sample', 'see you next week');
      await _tapKey(tester, 'factsbook-rule-test');
      expect(find.textContaining('It does not match.'), findsOneWidget);
      expect(find.textContaining('could not read this safely'), findsOne);
    });

    tTest('what the contract refuses is not sent', (tester) async {
      final node = FakeFactsBookGateway.withTriggers();
      await pumpFacts(tester, const FactsBookRuleEditorScreen(), gateway: node);
      await _tapKey(tester, 'factsbook-rule-save');
      expect(
        find.text('Give the rule a name of up to 80 letters.'),
        findsWidgets,
      );
      await _type(tester, 'factsbook-rule-name', 'Five words');
      await _type(tester, 'factsbook-rule-words', 'a, b, c, d, e');
      await _tapKey(tester, 'factsbook-rule-save');
      expect(
        find.text('Use up to 4 words, each up to 40 letters.'),
        findsWidgets,
      );
      expect(node.triggerCalls, isEmpty);
    });

    tTest('turning off both outcomes is refused', (tester) async {
      final node = FakeFactsBookGateway.withTriggers();
      await pumpFacts(tester, const FactsBookRuleEditorScreen(), gateway: node);
      await _type(tester, 'factsbook-rule-name', 'Nothing');
      await _tapKey(tester, 'factsbook-rule-reminder');
      await _tapKey(tester, 'factsbook-rule-conversation');
      await _tapKey(tester, 'factsbook-rule-save');
      expect(
        find.text('Choose at least one thing for the rule to suggest.'),
        findsWidgets,
      );
      expect(node.triggerCalls, isEmpty);
    });

    tTest('automatic start is shown as unavailable and off', (tester) async {
      final node = FakeFactsBookGateway.withTriggers();
      await pumpFacts(
        tester,
        FactsBookRuleEditorScreen(rule: (await node.rules()).first),
        gateway: node,
      );
      await tester.ensureVisible(
        find.text('Start these conversations by itself'),
      );
      expect(find.text('Start these conversations by itself'), findsOneWidget);
      expect(
        find.textContaining('Conversations are only offered'),
        findsOneWidget,
      );
      final toggle = tester.widget<Switch>(
        find.byKey(const ValueKey('factsbook-rule-autostart')),
      );
      expect(toggle.value, isFalse);
      expect(toggle.onChanged, isNull);
    });

    tTest('editing replaces at the revision seen; a changed rule reloads', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.withTriggers();
      final rule = (await node.rules()).first;
      await pumpFacts(
        tester,
        FactsBookRuleEditorScreen(rule: rule),
        gateway: node,
      );
      // Someone else changes the rule on the node first.
      await node.saveRule(
        rule.definition.copyWith(name: 'Changed elsewhere'),
        replacing: rule,
      );
      await _type(tester, 'factsbook-rule-name', 'My rename');
      await _tapKey(tester, 'factsbook-rule-save');
      expect(
        find.textContaining('This rule changed in memory'),
        findsOneWidget,
      );
      expect((await node.rules()).first.definition.name, 'Changed elsewhere');
      expect(_fieldText(tester, 'factsbook-rule-name'), 'Changed elsewhere');
    });

    tTest('delete asks first and removes the rule from the list', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.withTriggers();
      final rule = (await node.rules()).first;
      await pumpFacts(
        tester,
        FactsBookRuleEditorScreen(rule: rule),
        gateway: node,
      );
      await _tapKey(tester, 'factsbook-rule-delete');
      expect(find.text('Delete this rule?'), findsOneWidget);
      expect(node.triggerCalls, isNot(contains('rule.delete')));
      await tester.tap(find.text('Delete rule').last);
      await settle(tester);
      expect(node.triggerCalls, contains('rule.delete'));
      expect((await node.rules()).length, 1);
    });

    tTest('a phone without an approval key cannot save', (tester) async {
      final node = FakeFactsBookGateway.withTriggers();
      await pumpFacts(
        tester,
        const FactsBookRuleEditorScreen(),
        gateway: node,
        canApprove: false,
      );
      expect(
        find.byKey(const ValueKey('factsbook-rule-needs-owner')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('factsbook-rule-save')));
      await settle(tester);
      expect(node.triggerCalls, isEmpty);
    });
  });

  group('What happened here', () {
    tTest('outcome first, then the rule and where it came from, claims only', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.withTriggers();
      final event = (await node.events()).first;
      await pumpFacts(
        tester,
        FactsBookEventScreen(eventId: event.id),
        gateway: node,
      );
      expect(find.text('What happened here'), findsOneWidget);
      expect(find.text('Why this fired'), findsNothing);
      // The first row is the outcome, above where it came from.
      final outcome = tester.getTopLeft(
        find.byKey(const ValueKey('factsbook-event-outcome')),
      );
      final from = tester.getTopLeft(
        find.byKey(const ValueKey('factsbook-event-source')),
      );
      expect(outcome.dy, lessThan(from.dy));
      expect(find.textContaining('It suggested'), findsOneWidget);
      expect(find.text('Sender (a claim)'), findsOneWidget);
      expect(rich('Sam'), findsOneWidget);
      expect(find.text('Library appointments'), findsOneWidget);
      expect(find.textContaining('Unverified sender.'), findsOneWidget);
      expect(find.textContaining('Library visit'), findsWidgets);
      expect(rich('Waiting for your OK'), findsWidgets);
      expect(find.textContaining('never shown here'), findsOneWidget);
    });

    tTest('an event that was set aside says why once, not twice', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.withTriggers();
      final abstained = (await node.events())[1];
      await pumpFacts(
        tester,
        FactsBookEventScreen(eventId: abstained.id),
        gateway: node,
      );
      expect(find.byKey(const ValueKey('factsbook-event-outcome')), findsOne);
      expect(find.text('No rule fired for this message.'), findsNothing);
      expect(find.text('Nothing was kept from this message.'), findsNothing);
      // The reason is said once: in the outcome, not again further down.
      expect(find.textContaining('could not read this safely'), findsOneWidget);
    });

    tTest('an unknown event is not found, in words', (tester) async {
      await pumpFacts(
        tester,
        const FactsBookEventScreen(eventId: 'evt_00000000000000000000000099'),
        gateway: FakeFactsBookGateway.withTriggers(),
      );
      expect(
        find.byKey(const ValueKey('factsbook-event-error')),
        findsOneWidget,
      );
    });

    tTest('Triggers opens an event from its recent messages', (tester) async {
      final node = FakeFactsBookGateway.withTriggers();
      await pumpFacts(tester, const FactsBookTriggersScreen(), gateway: node);
      final event = (await node.events()).first;
      await tester.ensureVisible(
        find.byKey(ValueKey('factsbook-event-${event.id}')),
      );
      await tester.tap(find.byKey(ValueKey('factsbook-event-${event.id}')));
      await settle(tester);
      expect(find.text('Sender (a claim)'), findsOneWidget);
    });
  });

  group('trigger outcomes in Memory care', () {
    tTest('a reminder proposal can be confirmed, rejected or skipped', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.withTriggers();
      final proposal = (await node.reminderProposals()).single;
      await pumpFacts(tester, const FactsBookMemoryCareScreen(), gateway: node);
      expect(
        find.byKey(ValueKey('factsbook-care-${proposal.id}')),
        findsOneWidget,
      );
      expect(find.text('From a trigger'), findsOneWidget);
      expect(find.text('A rule suggested it'), findsWidgets);
      // The proposal is one card, not one here and one more as a review card.
      expect(find.text('4 waiting for your OK'), findsOneWidget);
      // A proposal can be changed (a tap on the card); it stays proposed
      // under a new revision.
      await _tapKey(tester, 'factsbook-care-${proposal.id}');
      expect(
        find.byKey(const ValueKey('factsbook-care-more-edit')),
        findsOneWidget,
      );
      Navigator.of(
        tester.element(find.byKey(const ValueKey('factsbook-care-more-edit'))),
      ).pop();
      await settle(tester);
      await _tapKey(tester, 'factsbook-care-approve-${proposal.id}');
      expect(node.triggerCalls, contains('proposal:confirm'));
      expect(find.text('Approved.'), findsOne);
      expect(
        find.byKey(ValueKey('factsbook-care-${proposal.id}')),
        findsNothing,
      );
    });

    tTest('reject and skip are sent as they are', (tester) async {
      final node = FakeFactsBookGateway.withTriggers();
      final proposal = (await node.reminderProposals()).single;
      await pumpFacts(tester, const FactsBookMemoryCareScreen(), gateway: node);
      await _tapKey(tester, 'factsbook-care-${proposal.id}');
      await _tapKey(tester, 'factsbook-care-more-skip');
      expect(node.triggerCalls, contains('proposal:skip'));
      await _tapKey(tester, 'factsbook-care-reject-${proposal.id}');
      expect(node.triggerCalls, contains('proposal:reject'));
    });

    tTest('a proposal that changed is stale and refreshed', (tester) async {
      final node = FakeFactsBookGateway.withTriggers();
      final proposal = (await node.reminderProposals()).single;
      await pumpFacts(tester, const FactsBookMemoryCareScreen(), gateway: node);
      await node.decideReminderProposal(proposal, ProposalDecision.skip);
      node.proposalsList[0] = ReminderProposal(
        id: proposal.id,
        revision: proposal.revision + 1,
        eventId: proposal.eventId,
        firingId: proposal.firingId,
        area: proposal.area,
        preview: proposal.preview,
        digest: proposal.digest,
        state: ProposalState.proposed,
      );
      await _tapKey(tester, 'factsbook-care-approve-${proposal.id}');
      expect(find.textContaining('changed'), findsWidgets);
    });

    tTest('What happened here opens the event', (tester) async {
      final node = FakeFactsBookGateway.withTriggers();
      final proposal = (await node.reminderProposals()).single;
      await pumpFacts(tester, const FactsBookMemoryCareScreen(), gateway: node);
      await _tapKey(tester, 'factsbook-care-${proposal.id}');
      await _tapKey(tester, 'factsbook-care-more-why');
      expect(find.text('Sender (a claim)'), findsOneWidget);
    });

    tTest('without an approval key the answers are off', (tester) async {
      final node = FakeFactsBookGateway.withTriggers();
      final proposal = (await node.reminderProposals()).single;
      await pumpFacts(
        tester,
        const FactsBookMemoryCareScreen(),
        gateway: node,
        canApprove: false,
      );
      await tester.tap(
        find.byKey(ValueKey('factsbook-care-approve-${proposal.id}')),
      );
      await settle(tester);
      expect(node.triggerCalls, isNot(contains('proposal:confirm')));
    });
  });

  group('the conversation offer', () {
    FakeChatsHost host() => FakeChatsHost(
      FakeChatFeedSource(
        projects: [project('alpha', kind: 'dart')],
        lastUsed: '/root/projects/alpha',
      ),
    );

    tTest('is a card in Needs you with the summary and two answers', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.withTriggers();
      await pumpFacts(tester, const FactsBookMemoryCareScreen(), gateway: node);
      expect(find.text('Discuss with your agent?'), findsOneWidget);
      expect(find.text('1 offer from a trigger'), findsOneWidget);
      expect(find.text('Library visit'), findsOneWidget);
      expect(find.text('Talk about this'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      expect(find.textContaining('not the whole message'), findsOneWidget);
    });

    tTest('Talk about this opens a new chat seeded with the summary', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.withTriggers();
      final offer = (await node.offers()).single;
      await pumpFacts(
        tester,
        const FactsBookMemoryCareScreen(),
        gateway: node,
        overrides: [chatsHostProvider.overrideWithValue(host())],
      );
      await _tapKey(tester, 'factsbook-offer-talk-${offer.id}');
      expect(node.triggerCalls, contains('offer.accept'));
      final seed = _fieldText(tester, 'chats-new-field');
      expect(
        seed,
        'Memory noticed something you may want to talk about. This is a '
        'short summary, not the original message:\n\nLibrary visit',
      );
      // Accepting is not a start: the node waits for the first message.
      expect((await node.offers()).single.state, OfferState.pending);
      expect(
        node.triggerCalls,
        isNot(contains('offer.report:firstMessageSent')),
      );
    });

    tTest('sending the first message reports the chat as started', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.withTriggers();
      final offer = (await node.offers()).single;
      await pumpFacts(
        tester,
        const FactsBookMemoryCareScreen(),
        gateway: node,
        overrides: [chatsHostProvider.overrideWithValue(host())],
      );
      await _tapKey(tester, 'factsbook-offer-talk-${offer.id}');
      await _tapKey(tester, 'chats-new-send');
      expect(node.triggerCalls, contains('offer.report:firstMessageSent'));
      expect((await node.offers()).single.state, OfferState.started);
    });

    tTest('leaving without sending reports the offer as cancelled', (
      tester,
    ) async {
      final node = FakeFactsBookGateway.withTriggers();
      final offer = (await node.offers()).single;
      await pumpFacts(
        tester,
        const FactsBookMemoryCareScreen(),
        gateway: node,
        overrides: [chatsHostProvider.overrideWithValue(host())],
      );
      await _tapKey(tester, 'factsbook-offer-talk-${offer.id}');
      expect(find.byKey(const ValueKey('chats-new-field')), findsOneWidget);
      Navigator.of(
        tester.element(find.byKey(const ValueKey('chats-new-field'))),
      ).pop();
      await settle(tester);
      expect(node.triggerCalls, contains('offer.report:cancelled'));
      expect(
        node.triggerCalls,
        isNot(contains('offer.report:firstMessageSent')),
      );
      expect(node.triggerCalls.where((c) => c == 'offer.accept'), hasLength(1));
      expect((await node.offers()).single.state, OfferState.cancelled);
    });

    tTest('Not now dismisses the offer', (tester) async {
      final node = FakeFactsBookGateway.withTriggers();
      final offer = (await node.offers()).single;
      await pumpFacts(tester, const FactsBookMemoryCareScreen(), gateway: node);
      await _tapKey(tester, 'factsbook-offer-later-${offer.id}');
      expect(node.triggerCalls, contains('offer.cancel'));
      expect(find.text('Discuss with your agent?'), findsNothing);
    });

    tTest('an expired offer is not offered', (tester) async {
      final node = FakeFactsBookGateway.withTriggers();
      final offer = (await node.offers()).single;
      node.offersList[0] = ConversationOffer(
        id: offer.id,
        revision: offer.revision,
        eventId: offer.eventId,
        firingId: offer.firingId,
        area: offer.area,
        summary: offer.summary,
        digest: offer.digest,
        state: OfferState.offered,
        expiresAt: factsNow.subtract(const Duration(minutes: 1)),
      );
      await pumpFacts(tester, const FactsBookMemoryCareScreen(), gateway: node);
      expect(find.text('Discuss with your agent?'), findsNothing);
    });

    tTest('without the offers capability there is no card', (tester) async {
      final node = FakeFactsBookGateway.withTriggers();
      const noOffers = FactsBookCapabilities(
        milestone: 'test',
        supported: {FactsBookCapabilities.triggers},
        disabled: {},
      );
      await pumpFacts(
        tester,
        const FactsBookMemoryCareScreen(),
        session: FactsBookSession.fixed(node)..capabilities = noOffers,
      );
      expect(find.text('Discuss with your agent?'), findsNothing);
    });
  });
}
