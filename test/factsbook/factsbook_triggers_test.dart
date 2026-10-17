// The node's trigger fixtures (spec 44) parse with the app's types, the HTTP
// gateway speaks the rules/offers paths with owner proofs and stable keys,
// the fake node behaves like the node where the app depends on it, and the
// rule editor's checks and the offer seed stay inside the contract.
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/factsbook/ed25519.dart';
import 'package:opencode_mobile/domain/factsbook/factsbook_capabilities.dart';
import 'package:opencode_mobile/domain/factsbook/factsbook_trigger_types.dart';
import 'package:opencode_mobile/domain/factsbook/factsbook_types.dart';
import 'package:opencode_mobile/domain/factsbook/fake_factsbook_gateway.dart';
import 'package:opencode_mobile/domain/factsbook/http_factsbook_gateway.dart';
import 'package:opencode_mobile/domain/factsbook/owner_signer.dart';
import 'package:opencode_mobile/state/factsbook/factsbook_triggers.dart';

import 'node_adapter.dart';

Map<String, Object?> _obj(String name) =>
    (jsonDecode(File('test/fixtures/factsbook/$name.json').readAsStringSync())
            as Map)
        .cast<String, Object?>();

void main() {
  group('the node\'s fixtures', () {
    test('a rule', () {
      final rule = Rule.fromJson(_obj('rule'));
      expect(rule.id, 'rul_00000000000000000000000005');
      expect(rule.revision, 1);
      expect(rule.deleted, isFalse);
      final d = rule.definition;
      expect(d.name, 'Library appointments');
      expect(d.enabled, isTrue);
      expect(d.source.kind, TriggerSourceKind.share);
      expect(d.source.instance, 'manual-share');
      expect(d.template.id, TriggerTemplateId.appointment);
      expect(d.template.locale, 'en');
      expect(d.containsAll, isEmpty);
      expect(d.hasOutcome(TriggerOutcomeKind.reminder), isTrue);
      expect(d.hasOutcome(TriggerOutcomeKind.conversation), isTrue);
      expect(d.hasOutcome(TriggerOutcomeKind.fact), isFalse);
      expect(d.limitPerDay, 20);
      expect(d.autoStart, isFalse);
    });

    test('a rule goes back to the node as the node wrote it', () {
      final raw = _obj('rule')['definition']! as Map<String, Object?>;
      expect(RuleDefinition.fromJson(raw).toJson(), raw);
    });

    test('a rule test, an event, a firing', () {
      final test = RuleTestResult.fromJson(_obj('rule-test'));
      expect(test.matched, isTrue);
      expect(test.reason, TriggerReason.matched);
      expect(test.summary, 'Library visit');
      expect(test.when, '2026-10-15T09:00');

      final event = TriggerEvent.fromJson(_obj('trigger-event'));
      expect(event.claims.sender, 'Sam');
      expect(event.trust, EventTrust.thirdPartyUntrusted);
      expect(event.sensitive, isFalse);
      expect(event.state, EventProcessingState.evaluated);
      expect(event.reason, TriggerReason.matched);
      expect(event.firings, ['trg_00000000000000000000000007']);

      final firing = TriggerFiring.fromJson(_obj('trigger-firing'));
      expect(firing.state, FiringState.proposed);
      expect(firing.ruleId, 'rul_00000000000000000000000005');
      expect(firing.outcomes, hasLength(2));
      expect(firing.collapseInto, isNull);
    });

    test('a reminder proposal, an offer, a start receipt', () {
      final proposal = ReminderProposal.fromJson(_obj('reminder-proposal'));
      expect(proposal.state, ProposalState.proposed);
      expect(proposal.preview.what, 'Library visit');
      expect(proposal.preview.date, '2026-10-15');

      final offer = ConversationOffer.fromJson(_obj('conversation-offer'));
      expect(offer.summary, 'Library visit');
      expect(offer.state, OfferState.offered);
      expect(offer.receipt, isNull);
      expect(offer.expiresAt.toUtc(), DateTime.utc(2026, 10, 12));
      expect(offer.isOpen(DateTime.utc(2026, 10, 11, 12)), isTrue);
      expect(offer.isOpen(DateTime.utc(2026, 10, 12, 1)), isFalse);

      final receipt = StartReceipt.fromJson(_obj('start-receipt'));
      expect(receipt.status, StartStatus.pending);
      expect(receipt.receiptKey, 'synthetic-start-one');
      expect(receipt.expiresAt, isNotNull);
      expect(
        StartReceipt.fromJson(_obj('started-receipt')).status,
        StartStatus.started,
      );
    });

    test('an unknown word reads as the cautious one', () {
      expect(TriggerReason.parse('something_new'), TriggerReason.uncertain);
      expect(EventTrust.parse('verified'), EventTrust.thirdPartyUntrusted);
      expect(OfferState.parse('x'), OfferState.cancelled);
      expect(StartStatus.parse('x'), StartStatus.unknown);
      expect(ProposalState.parse('x'), ProposalState.stale);
    });

    test('the capability matrix lists triggers and the templates', () {
      final node = FactsBookCapabilities.fromJson(_obj('capabilities'));
      expect(node.supports(FactsBookCapabilities.triggers), isTrue);
      expect(node.supports(FactsBookCapabilities.conversationOffers), isTrue);
      expect(
        node.supports(FactsBookCapabilities.automaticConversationStart),
        isFalse,
      );
      expect(
        node.isDisabled(FactsBookCapabilities.notificationCapture),
        isTrue,
      );
      expect(node.triggerTemplates, {
        'appointment',
        'delivery',
        'booking',
        'subscription',
      });
      expect(FactsBookCapabilities.b5.triggerTemplates, node.triggerTemplates);
    });
  });

  group('the rule editor\'s checks', () {
    RuleDefinition draft({
      String name = 'Mine',
      List<String> words = const [],
      List<TriggerOutcome> outcomes = const [
        TriggerOutcome(TriggerOutcomeKind.reminder),
      ],
      int perDay = 5,
      TriggerTemplateId template = TriggerTemplateId.appointment,
    }) => RuleDefinition(
      name: name,
      enabled: true,
      source: const TriggerSource(
        clientId: 'cli_00000000000000000000000001',
        kind: TriggerSourceKind.share,
        instance: 'manual-share',
      ),
      template: TriggerTemplate(id: template),
      area: 'general',
      containsAll: words,
      outcomes: outcomes,
      limitPerDay: perDay,
    );

    test('a good rule has no problem', () {
      expect(RuleRules.check(draft()), isEmpty);
    });

    test('name, words, outcomes, template and the daily limit', () {
      expect(RuleRules.check(draft(name: '  ')), [RuleProblem.nameEmpty]);
      expect(RuleRules.check(draft(name: 'x' * 81)), [RuleProblem.nameTooLong]);
      // Arabic letters are two bytes each: 41 of them are over 80 bytes.
      expect(RuleRules.check(draft(name: 'م' * 41)), [RuleProblem.nameTooLong]);
      expect(RuleRules.check(draft(name: 'م' * 40)), isEmpty);
      expect(RuleRules.check(draft(words: ['a', 'b', 'c', 'd', 'e'])), [
        RuleProblem.tooManyWords,
      ]);
      expect(RuleRules.check(draft(words: ['y' * 41])), [
        RuleProblem.wordTooLong,
      ]);
      expect(RuleRules.check(draft(outcomes: const [])), [
        RuleProblem.noOutcome,
      ]);
      expect(RuleRules.check(draft(template: TriggerTemplateId.billDue)), [
        RuleProblem.templateUnavailable,
      ]);
      expect(RuleRules.check(draft(perDay: 0)), [RuleProblem.limitOutOfRange]);
      expect(RuleRules.check(draft(perDay: 21)), [RuleProblem.limitOutOfRange]);
    });

    test('typed words are split, trimmed and not repeated', () {
      expect(RuleRules.splitWords(' Rent, rent ,\nدفع،  due '), [
        'Rent',
        'دفع',
        'due',
      ]);
      expect(RuleRules.splitWords(' , ,'), isEmpty);
    });
  });

  group('the HTTP gateway', () {
    late NodeAdapter node;
    late HttpFactsBookGateway gateway;
    final seed = bytesOfHex(
      '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
    );

    setUp(() {
      node = NodeAdapter();
      final dio = Dio(
        BaseOptions(
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      )..httpClientAdapter = node;
      gateway = HttpFactsBookGateway(
        baseUrl: Uri.parse('http://127.0.0.1:8787'),
        token: 'secret-token',
        owner: OwnerSigner(
          seed: seed,
          deviceId: 'dev_00000000000000000000000002',
          vault: 'vlt_00000000000000000000000001',
          clientId: 'cli_00000000000000000000000001',
        ),
        dio: dio,
        retryDelay: Duration.zero,
      );
    });

    test('lists hide deleted rules and read every page', () async {
      final rule = _obj('rule');
      node.reply('GET /v1/rules', {
        'items': [
          rule,
          {...rule, 'id': 'rul_00000000000000000000000099', 'deleted': true},
        ],
        'next_cursor': null,
      });
      expect(await gateway.rules(), hasLength(1));
      node.reply('GET /v1/trigger-firings', {
        'items': [_obj('trigger-firing')],
        'next_cursor': null,
      });
      expect(await gateway.firings(), hasLength(1));
      node.reply('GET /v1/offers', {
        'items': [_obj('conversation-offer')],
        'next_cursor': null,
      });
      expect(await gateway.offers(), hasLength(1));
    });

    test('creating a rule is a signed POST with base_rev 0', () async {
      node.reply('POST /v1/rules', _obj('rule'));
      final definition = Rule.fromJson(_obj('rule')).definition;
      final saved = await gateway.saveRule(definition);
      expect(saved.id, 'rul_00000000000000000000000005');
      final call = node.calls.single;
      final body = (call.body! as Map).cast<String, Object?>();
      expect(body['base_rev'], 0);
      expect((body['rule']! as Map)['auto_start'], isFalse);
      expect(
        (body['proof']! as Map)['signer'],
        'dev_00000000000000000000000002',
      );
      expect(call.headers['Idempotency-Key'], isNotEmpty);
    });

    test('pausing replaces at the revision seen, with enabled false', () async {
      final rule = Rule.fromJson(_obj('rule'));
      node.reply('PUT /v1/rules/${rule.id}', _obj('rule'));
      await gateway.saveRule(
        rule.definition.copyWith(enabled: false),
        replacing: rule,
      );
      final body = (node.calls.single.body! as Map).cast<String, Object?>();
      expect(body['base_rev'], 1);
      expect((body['rule']! as Map)['enabled'], isFalse);
      expect(body.containsKey('proof'), isTrue);
    });

    test('a rule write without an owner key is owner_required', () async {
      final plain = HttpFactsBookGateway(
        baseUrl: Uri.parse('http://127.0.0.1:8787'),
        token: 't',
        dio: Dio()..httpClientAdapter = node,
      );
      await expectLater(
        plain.saveRule(Rule.fromJson(_obj('rule')).definition),
        throwsA(
          isA<FactsBookException>().having(
            (e) => e.code,
            'code',
            'owner_required',
          ),
        ),
      );
      expect(node.calls, isEmpty);
    });

    test('delete is a signed DELETE; test sends only the sample', () async {
      final rule = Rule.fromJson(_obj('rule'));
      node.reply('DELETE /v1/rules/${rule.id}', {
        ..._obj('rule'),
        'deleted': true,
      });
      await gateway.deleteRule(rule);
      expect(
        ((node.calls.single.body! as Map)['proof'] as Map).containsKey('sig'),
        isTrue,
      );
      node.reply('POST /v1/rules/${rule.id}/test', _obj('rule-test'));
      final result = await gateway.testRule(
        rule,
        const TriggerSample(
          kind: TriggerSourceKind.share,
          text: 'Appointment: Library visit | 2026-10-15T09:00',
          area: 'general',
          locale: 'en',
          sourceInstance: 'manual-share',
        ),
      );
      expect(result.matched, isTrue);
      final call = node.calls.last;
      expect(call.headers.containsKey('Idempotency-Key'), isFalse);
      final sample = ((call.body! as Map)['sample']! as Map);
      expect(sample['text'], startsWith('Appointment:'));
      expect(sample['message_key'], isNotEmpty);
    });

    test(
      'accepting an offer binds revision, digest and the stable key',
      () async {
        final offer = ConversationOffer.fromJson(_obj('conversation-offer'));
        node.reply('POST /v1/offers/${offer.id}/accept', {
          ..._obj('start-receipt'),
          'status': 'started',
        });
        final key = FactsBookTriggers.receiptKeyFor(offer);
        final receipt = await gateway.acceptOffer(offer, receiptKey: key);
        expect(receipt.status, StartStatus.started);
        final body = (node.calls.single.body! as Map).cast<String, Object?>();
        expect(body['rev'], offer.revision);
        expect(body['digest'], offer.digest);
        expect(body['receipt_key'], key);
        expect(body['adapter'], 'client_report');
        expect(body.containsKey('adapter_result'), isFalse);
        // The same offer always gets the same key, and only letters.
        expect(FactsBookTriggers.receiptKeyFor(offer), key);
        expect(RegExp(r'^offer-[a-z]{24}$').hasMatch(key), isTrue);
      },
    );

    test('a reminder proposal decision is signed and digest-bound', () async {
      final proposal = ReminderProposal.fromJson(_obj('reminder-proposal'));
      node.reply('POST /v1/reminder-proposals/${proposal.id}/decision', {
        'status': 'ok',
        'id': proposal.id,
      });
      await gateway.decideReminderProposal(proposal, ProposalDecision.confirm);
      final body = (node.calls.single.body! as Map).cast<String, Object?>();
      expect(body['decision'], 'confirm');
      expect(body['digest'], proposal.digest);
      expect(body['rev'], proposal.revision);
      expect(body.containsKey('proof'), isTrue);
    });

    test('503 busy is asked again with the same key', () async {
      final busy = _obj('busy');
      node.reply(
        'POST /v1/offers/ofr_00000000000000000000000008/cancel',
        busy,
        status: 503,
      );
      node.reply(
        'POST /v1/offers/ofr_00000000000000000000000008/cancel',
        _obj('conversation-offer'),
      );
      final offer = ConversationOffer.fromJson(_obj('conversation-offer'));
      await gateway.cancelOffer(offer);
      expect(node.calls, hasLength(2));
      expect(
        node.calls[0].headers['Idempotency-Key'],
        node.calls[1].headers['Idempotency-Key'],
      );
    });
  });

  group('the B5 contract', () {
    late NodeAdapter node;
    late HttpFactsBookGateway gateway;
    final seed = bytesOfHex(
      '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
    );
    setUp(() {
      node = NodeAdapter();
      gateway = HttpFactsBookGateway(
        baseUrl: Uri.parse('http://127.0.0.1:8787'),
        token: 't',
        owner: OwnerSigner(
          seed: seed,
          deviceId: 'dev_00000000000000000000000002',
          vault: 'vlt_00000000000000000000000001',
          clientId: 'cli_00000000000000000000000001',
        ),
        dio: Dio(BaseOptions(responseType: ResponseType.plain))
          ..httpClientAdapter = node,
        retryDelay: Duration.zero,
      );
    });

    const sample = TriggerSample(
      kind: TriggerSourceKind.share,
      text: 'Appointment: Library visit | 2026-10-15T09:00',
      area: 'general',
      locale: 'en',
      sourceInstance: 'manual-share',
      messageKey: 'msg-abc',
    );

    test(
      'a rule is written with template version 2 and an optional sender claim',
      () {
        final rule = Rule.fromJson(_obj('rule'));
        expect(rule.definition.template.version, 2);
        expect(rule.definition.senderClaim, isNull);
        expect(rule.definition.toJson().containsKey('sender_claim'), isFalse);
        final withSender = rule.definition.copyWith(senderClaim: ' Sam ');
        expect(withSender.toJson()['sender_claim'], ' Sam ');
        expect(withSender.copyWith(name: 'x').senderClaim, ' Sam ');
        expect(withSender.copyWith(senderClaim: null).senderClaim, isNull);
        expect(RuleRules.check(rule.definition.copyWith(senderClaim: ' ')), [
          RuleProblem.senderClaimInvalid,
        ]);
        expect(
          RuleRules.check(rule.definition.copyWith(senderClaim: 'x' * 81)),
          [RuleProblem.senderClaimInvalid],
        );
        expect(const TriggerTemplate(id: TriggerTemplateId.booking).version, 2);
      },
    );

    test('a draft is tested without saving or signing', () async {
      node.reply('POST /v1/rules/test', _obj('rule-test'));
      final draft = Rule.fromJson(_obj('rule')).definition;
      final result = await gateway.testDraft(draft, sample);
      expect(result.matched, isTrue);
      final call = node.calls.single;
      final body = (call.body! as Map).cast<String, Object?>();
      expect(body.keys.toSet(), {'rule', 'sample'});
      expect(call.headers.containsKey('Idempotency-Key'), isFalse);
    });

    test('the node\'s own capabilities replace the shipped ones', () async {
      node.reply('GET /v1/capabilities', _obj('capabilities'));
      final caps = await gateway.capabilities();
      expect(caps.milestone, 'B5');
      expect(caps.supports(FactsBookCapabilities.conversationOffers), isTrue);
      expect(caps.supports(FactsBookCapabilities.proposalEdit), isTrue);
      expect(caps.supported, FactsBookCapabilities.b5.supported);
    });

    test(
      'a share is posted signed as ordinary text, bound to this request',
      () async {
        node.reply('POST /v1/events', {
          'status': 'accepted',
          'event': _obj('trigger-event'),
        });
        final event = await gateway.postEvent(
          sample,
          idempotencyKey: 'evt-abc',
          classifyNormal: true,
        );
        expect(event.evidenceRef, startsWith('itm_'));
        final body = (node.calls.single.body! as Map).cast<String, Object?>();
        expect(body['classify_normal'], isTrue);
        final proof = (body['proof']! as Map).cast<String, Object?>();
        expect(proof['signer'], 'dev_00000000000000000000000002');
        // The signature covers the request without its proof.
        final unsigned = {...body}..remove('proof');
        expect(unsigned['text'], sample.text);
      },
    );

    test(
      'an edited reminder proposal is signed with the new preview',
      () async {
        final proposal = ReminderProposal.fromJson(_obj('reminder-proposal'));
        node.reply('POST /v1/reminder-proposals/${proposal.id}/decision', {
          'status': 'ok',
          'id': proposal.id,
        });
        final edited = ReminderProposal.fromJson(
          _obj('edited-reminder-proposal'),
        );
        await gateway.editReminderProposal(proposal, edited.preview);
        final body = (node.calls.single.body! as Map).cast<String, Object?>();
        expect(body['decision'], 'edit');
        expect(body['rev'], proposal.revision);
        expect(body['digest'], proposal.digest);
        expect(body['preview_digest'], edited.preview.digest);
        expect(body.containsKey('proof'), isTrue);
      },
    );

    test(
      'the first message is reported as started only when it was sent',
      () async {
        final offer = ConversationOffer.fromJson(_obj('conversation-offer'));
        final pending = StartReceipt.fromJson(_obj('start-receipt'));
        node.reply(
          'POST /v1/offers/${offer.id}/receipt',
          _obj('started-receipt'),
        );
        await gateway.reportOffer(offer, pending, OfferReport.firstMessageSent);
        node.reply(
          'POST /v1/offers/${offer.id}/receipt',
          _obj('start-receipt'),
        );
        await gateway.reportOffer(offer, pending, OfferReport.cancelled);
        final started = (node.calls[0].body! as Map).cast<String, Object?>();
        expect(started['status'], 'started');
        expect(started['first_message_sent'], isTrue);
        expect(started['start_id'], pending.id);
        expect(started['receipt_key'], pending.receiptKey);
        final cancelled = (node.calls[1].body! as Map).cast<String, Object?>();
        expect(cancelled['status'], 'cancelled');
        expect(cancelled.containsKey('first_message_sent'), isFalse);
      },
    );
  });

  group('the fake node', () {
    late FakeFactsBookGateway fake;
    setUp(() => fake = FakeFactsBookGateway.withTriggers());

    test('a rule is replaced only at the revision seen', () async {
      final rules = await fake.rules();
      final first = rules.first;
      await fake.saveRule(
        first.definition.copyWith(name: 'Renamed'),
        replacing: first,
      );
      await expectLater(
        fake.saveRule(first.definition, replacing: first),
        throwsA(isA<FactsBookException>().having((e) => e.stale, 's', isTrue)),
      );
    });

    test('a rule the contract refuses is refused', () async {
      await expectLater(
        fake.saveRule(
          (await fake.rules()).first.definition.copyWith(outcomes: const []),
        ),
        throwsA(isA<FactsBookException>()),
      );
    });

    test('a test reads the one-line grammar and saves nothing', () async {
      final rule = (await fake.rules()).first;
      const sample = TriggerSample(
        kind: TriggerSourceKind.share,
        text: 'Appointment: Library visit | 2026-10-15T09:00',
        area: 'general',
        locale: 'en',
        sourceInstance: 'manual-share',
      );
      final hit = await fake.testRule(rule, sample);
      expect(hit.matched, isTrue);
      expect(hit.summary, 'Library visit');
      expect(hit.when, '2026-10-15T09:00');
      final before = (await fake.events()).length;
      // Arabic digits read as ASCII digits.
      final arabicRule = await fake.saveRule(
        rule.definition.copyWith(
          name: 'Arabic',
          template: const TriggerTemplate(
            id: TriggerTemplateId.appointment,
            locale: 'ar',
          ),
        ),
      );
      final arabic = await fake.testRule(
        arabicRule,
        const TriggerSample(
          kind: TriggerSourceKind.share,
          text: 'موعد: زيارة المكتبة | ٢٠٢٦-١٠-١٥T٠٩:٠٠',
          area: 'general',
          locale: 'ar',
          sourceInstance: 'manual-share',
        ),
      );
      expect(arabic.matched, isTrue);
      expect(arabic.when, '2026-10-15T09:00');
      expect((await fake.events()).length, before);
      // A different label, free text, and the wrong source all fall short.
      Future<RuleTestResult> run(String text, {TriggerSourceKind? kind}) =>
          fake.testRule(
            rule,
            TriggerSample(
              kind: kind ?? TriggerSourceKind.share,
              text: text,
              area: 'general',
              locale: 'en',
              sourceInstance: 'manual-share',
            ),
          );
      expect(
        (await run('Delivery: Box | 2026-10-15T09:00')).reason,
        TriggerReason.noMatch,
      );
      expect((await run('see you next week')).reason, TriggerReason.uncertain);
      expect(
        (await run(sample.text, kind: TriggerSourceKind.note)).reason,
        TriggerReason.noMatch,
      );
    });

    test('an offer is accepted once per receipt key', () async {
      final offer = (await fake.offers()).single;
      final a = await fake.acceptOffer(offer, receiptKey: 'one');
      final b = await fake.acceptOffer(offer, receiptKey: 'one');
      expect(b.id, a.id);
      expect((await fake.offers()).single.state, OfferState.pending);
      expect(a.status, StartStatus.pending);
      // A different key on a started offer is a stale answer.
      await expectLater(
        fake.acceptOffer(offer, receiptKey: 'two'),
        throwsA(isA<FactsBookException>().having((e) => e.stale, 's', isTrue)),
      );
    });

    test('editing a proposal keeps it proposed under a new revision', () async {
      final proposal = (await fake.reminderProposals()).single;
      await fake.editReminderProposal(proposal, proposal.preview);
      final after = (await fake.reminderProposals()).single;
      expect(after.state, ProposalState.proposed);
      expect(after.revision, proposal.revision + 1);
      expect(after.digest, isNot(proposal.digest));
      // The old decision is stale.
      await expectLater(
        fake.decideReminderProposal(proposal, ProposalDecision.confirm),
        throwsA(isA<FactsBookException>().having((e) => e.stale, 's', isTrue)),
      );
    });

    test('a sender claim must match, and a draft is tested unsaved', () async {
      final rule = (await fake.rules()).first;
      const sample = TriggerSample(
        kind: TriggerSourceKind.share,
        text: 'Appointment: Library visit | 2026-10-15T09:00',
        area: 'general',
        locale: 'en',
        sourceInstance: 'manual-share',
        claims: EventClaims(sender: 'Sam'),
      );
      final draft = rule.definition.copyWith(senderClaim: 'sam');
      expect((await fake.testDraft(draft, sample)).matched, isTrue);
      final other = rule.definition.copyWith(senderClaim: 'Alex');
      expect((await fake.testDraft(other, sample)).matched, isFalse);
      expect((await fake.rules()).length, 2);
      await expectLater(
        fake.testDraft(rule.definition.copyWith(name: ''), sample),
        throwsA(isA<FactsBookException>()),
      );
    });

    test(
      'a pending offer reports started only with the first message',
      () async {
        final offer = (await fake.offers()).single;
        final receipt = await fake.acceptOffer(offer, receiptKey: 'one');
        expect(receipt.status, StartStatus.pending);
        expect(receipt.expiresAt, isNotNull);
        final done = await fake.reportOffer(
          offer,
          receipt,
          OfferReport.firstMessageSent,
        );
        expect(done.status, StartStatus.started);
        expect((await fake.offers()).single.state, OfferState.started);
      },
    );

    test('an expired offer cannot be accepted', () async {
      final offer = (await fake.offers()).single;
      await withClock(
        Clock.fixed(offer.expiresAt.add(const Duration(minutes: 1))),
        () => expectLater(
          fake.acceptOffer(offer, receiptKey: 'late'),
          throwsA(isA<FactsBookException>()),
        ),
      );
    });

    test('a node without triggers says not found', () async {
      fake.triggersAvailable = false;
      await expectLater(
        fake.rules(),
        throwsA(
          isA<FactsBookException>().having((e) => e.code, 'code', 'not_found'),
        ),
      );
    });
  });

  group('the offer seed', () {
    test('is the lead-in and the summary, nothing else', () {
      final offer = ConversationOffer.fromJson({
        ..._obj('conversation-offer'),
        'summary': 'Rent changes from 1 January.',
      });
      final seed = offerChatSeed(offer, leadIn: 'FactsBook noticed this.');
      expect(seed, 'FactsBook noticed this.\n\nRent changes from 1 January.');
      // There is no raw-text field on an offer to leak.
      expect(
        _obj('conversation-offer').keys,
        isNot(containsAll(['text', 'body', 'raw'])),
      );
    });
  });
}
