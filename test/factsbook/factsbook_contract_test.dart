// The node's own fixtures (copied from factsbook/api/fixtures, synthetic) parse
// with the app's types. A change to the contract breaks a test here first.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/factsbook/control_verifier.dart';
import 'package:opencode_mobile/domain/factsbook/ed25519.dart';
import 'package:opencode_mobile/domain/factsbook/factsbook_capabilities.dart';
import 'package:opencode_mobile/domain/factsbook/jcs.dart';
import 'package:opencode_mobile/domain/factsbook/factsbook_types.dart';

Object? _fixture(String name) =>
    jsonDecode(File('test/fixtures/factsbook/$name.json').readAsStringSync());

Map<String, Object?> _obj(String name) =>
    (_fixture(name)! as Map).cast<String, Object?>();

Map<String, Object?> _first(String name) =>
    ((_obj(name)['items']! as List).first as Map).cast<String, Object?>();

void main() {
  final manifest = _obj('manifest');

  test('every fixture the node ships has a parser here', () {
    // Add the parser and a test below before adding a name here.
    const covered = {
      'things': 'ThingList',
      'thing': 'Thing',
      'facts': 'FactList',
      'search': 'SearchHitList',
      'status': 'Status',
      'settings': 'Settings',
      'areas': 'AreaList',
      'couldnt-save': 'CouldntSaveList',
      'reminders': 'ReminderList',
      'review': 'ReviewList',
      'not-enabled': 'Error',
      'inbox': 'Inbox',
      'capture': 'CaptureResult',
      'policy': 'Policy',
      'outbox': 'OutboxResult',
      'control': 'ControlResponse',
      'inbox-ar': 'Inbox',
      'refused-outbox': 'OutboxResult',
      'clients': 'ClientList',
      'index-rebuilding': 'Error',
      'preview-en': 'Preview',
      'preview-ar': 'Preview',
      'duplicate-title': 'Error',
      'sensitive-unavailable': 'Error',
      'authored-note-en': 'Inbox',
      'authored-note-ar': 'Inbox',
      'rule': 'Rule',
      'trigger-event': 'TriggerEvent',
      'trigger-firing': 'TriggerFiring',
      'conversation-offer': 'ConversationOffer',
      'rule-test': 'RuleTestResult',
      'reminder-proposal': 'ReminderProposal',
      'start-receipt': 'StartReceipt',
      'busy': 'Error',
      'edited-reminder-proposal': 'ReminderProposal',
      'started-receipt': 'StartReceipt',
      'storm-summary': 'TriggerFiring',
      'capabilities': 'Capabilities',
    };
    expect(manifest['synthetic'], isTrue);
    expect(manifest['responses'], covered);
    final files = Directory('test/fixtures/factsbook')
        .listSync()
        .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''))
        .toSet();
    // The matrix and the signature vectors ship beside the responses.
    expect(files, {...covered.keys, 'manifest', 'capabilities', 'signatures'});
  });

  test('Thing and its facts', () {
    final thing = Thing.fromJson(_obj('thing'));
    expect(thing.id, 'per_00000000000000000000000001');
    expect(thing.title, 'Sam');
    expect(thing.kind, ThingKind.person);
    expect(thing.area, 'family');
    expect(thing.sensitive, isFalse);
    expect(thing.revision, 1);
    final fact = thing.facts.single;
    expect(fact.provenance, FactProvenance.told);
    // A told fact's source is the owner attestation's digest (B4).
    expect(fact.source, '0' * 64);
    expect(fact.observedAt.toUtc(), DateTime.utc(2026, 10, 11, 9));
    expect(fact.review, FactReview.approved);
    expect(fact.status, FactStatus.active);
    expect(fact.waitingForOk, isFalse);
    expect(fact.thingId, thing.id);
    expect(thing.newestFact, same(fact));
  });

  test('the list envelopes carry items and next_cursor', () {
    for (final name in [
      'things',
      'facts',
      'search',
      'couldnt-save',
      'reminders',
      'review',
      'areas',
    ]) {
      final json = _obj(name);
      expect(json.keys.toSet(), {'items', 'next_cursor'}, reason: name);
      expect(json['next_cursor'], isNull, reason: name);
    }
    expect(
      Thing.fromJson(_first('things')).facts.single.id,
      'f_00000000000000000000000001',
    );
    expect(Fact.fromJson(_first('facts')).category, 'preference');
  });

  test('SearchHit', () {
    final hit = SearchHit.fromJson(_first('search'));
    expect(hit.thingId, 'per_00000000000000000000000001');
    expect(hit.factId, 'f_00000000000000000000000001');
    expect(hit.snippet, 'Sam prefers morning walks.');
    expect(hit.provenance, FactProvenance.told);
    expect(hit.observedAt.toUtc(), DateTime.utc(2026, 10, 11, 9));
    expect(hit.area, 'family');
  });

  test('Status: canonical states, key, index, no claim of a backup', () {
    final status = NodeStatus.fromJson(_obj('status'));
    expect(status.module('storage').state, ModuleState.ok);
    expect(status.module('cloud').state, ModuleState.absent);
    expect(status.module('cloud').code, 'not_configured');
    expect(status.module('cloud').lastOk, isNull);
    expect(status.executor, 'dev_00000000000000000000000001');
    expect(status.key, 'absent');
    expect(status.indexNormal, ModuleState.ok);
    expect(status.indexSensitive, 'locked');
    expect(status.staleSeconds, isNull, reason: 'cloud freshness unknown');
    expect(status.generatedAt!.toUtc(), DateTime.utc(2026, 10, 11, 9));
    expect(status.stateRevision, 1);
    expect(status.module('replication').state, ModuleState.disabled);
    expect(status.module('replication').code, 'not_enabled');
    expect(status.safeInCloud, isFalse);
    expect(status.lastCareAt, isNull);
    expect(status.careOverdueReason, 'not_enabled');
  });

  test('Reminder and its schedule', () {
    final reminder = Reminder.fromJson(_first('reminders'));
    expect(reminder.what, 'Read with Sam');
    expect(reminder.schedule.id, 'sch_00000000000000000000000001');
    expect(reminder.schedule.when.once, DateTime(2026, 10, 15, 9));
    expect(reminder.schedule.zone, 'vault');
    expect(reminder.locale, 'en');
    expect(reminder.urgent, isFalse);
    expect(reminder.paused, isFalse);
    expect(reminder.revision, 1);
    expect(reminder.source, isNull);
    expect(reminder.area, 'general');
    expect(reminder.sensitive, isFalse);
    expect(reminder.done, isFalse);
  });

  test('Review item', () {
    final item = ReviewItem.fromJson(_first('review'));
    expect(item.id, 'rvw_00000000000000000000000001');
    expect(item.reviewClass, ReviewClass.factAdd);
    expect(item.state, ReviewState.proposed);
    expect(item.text, 'Sam likes books');
    expect(item.proposal['kind'], 'fact.add');
    expect(item.preconditions, {'per_00000000000000000000000001': 1});
    expect(item.digest, hasLength(64));
    expect(item.area, 'family');
    expect(item.risk, isEmpty);
    expect(item.expiresAt, isNull);
    expect(item.current, isNull);
  });

  test('Area: sharing, storage and review rules', () {
    final area = Area.fromJson(_first('areas'));
    expect(area.slug, 'family');
    expect(area.sensitiveStorage, isFalse);
    expect(area.reviewFirst, isFalse);
    expect(area.share.readByDefault, isTrue);
    expect(area.share.allow, isEmpty);
    expect(area.brief, isTrue);
    expect(area.export, isTrue);
    expect(area.notify, 'masked');
    // What the app sends back is what the node sent, with one change.
    final policyArea = ((_obj('policy')['areas']! as Map)['family']! as Map)
        .cast<String, Object?>();
    expect(area.toJson(), policyArea);
    expect(area.copyWith(share: const AreaShare()).toJson()['share'], {
      'default': 'none',
      'allow': <String>[],
      'deny': <String>[],
    });
  });

  test('CouldntSave: the node holds the item, not the text', () {
    final entry = CouldNotSaveEntry.fromJson(_first('couldnt-save'));
    expect(entry.id, 'cqs_00000000000000000000000001');
    expect(entry.itemId, 'itm_00000000000000000000000002');
    expect(entry.reason, CouldNotSaveReason.keyLocked);
    expect(entry.state, CouldNotSaveState.queued);
    expect(entry.retries, 0);
    expect(entry.promptDue, isFalse);
    expect(entry.text, isNull);
    expect(entry.onPhone, isFalse);
  });

  test('every reason code of the contract parses', () {
    for (final code in [
      'storage_full',
      'classification_failed',
      'parser_error',
      'node_unreachable',
      'outbox_full',
      'cloud_quota',
      'key_locked',
      'validation_rejected',
    ]) {
      expect(CouldNotSaveReason.parse(code).wire, code);
    }
  });

  test('CaptureResult', () {
    final result = CaptureResult.fromJson(_obj('capture'));
    expect(result.saved, isTrue);
    expect(result.itemId, 'itm_00000000000000000000000001');
    expect(result.couldntSaveId, isNull);
    final queued = CaptureResult.fromJson({
      'status': 'queued',
      'item_id': 'itm_00000000000000000000000003',
      'couldnt_save_id': 'cqs_00000000000000000000000002',
    });
    expect(queued.saved, isFalse);
    expect(queued.couldntSaveId, 'cqs_00000000000000000000000002');
  });

  test('a capture request is what POST /v1/inbox takes', () {
    const request = CaptureRequest(
      kind: CaptureKind.chatSelection,
      text: 'a selected message',
      area: 'work',
    );
    expect(request.toJson(), {
      'kind': 'chat_selection',
      'text': 'a selected message',
      'area': 'work',
      'trust': 'user_selected',
    });
    // The inbox fixture is what the node stores for a note.
    final stored = _obj('inbox');
    expect(stored['kind'], 'note');
    expect(stored['trust'], 'user_authored');
    expect(
      const CaptureRequest(kind: CaptureKind.note, text: 'x').trust,
      'user_authored',
    );
  });

  test('outbox receipts', () {
    final receipt = OutboxReceipt.fromJson(
      ((_obj('outbox')['receipts']! as List).single as Map)
          .cast<String, Object?>(),
    );
    expect(receipt.key, 'synthetic-event-one');
    expect(receipt.status, OutboxReceiptStatus.accepted);
    expect(receipt.error, isNull);
    expect(const OutboxEvent(key: 'k', payload: {'kind': 'note'}).toJson(), {
      'key': 'k',
      'type': 'capture',
      'payload': {'kind': 'note'},
    });
  });

  test('the error envelope: code, message, hint, request id', () {
    final json = ((_obj('not-enabled')['error']!) as Map)
        .cast<String, Object?>();
    final error = FactsBookException.fromJson(json, status: 501);
    expect(error.code, 'not_enabled');
    expect(error.notEnabled, isTrue);
    expect(error.requestId, 'op_00000000000000000000000001');
    expect(error.status, 501);
    expect(error.message, isNotEmpty);
    expect(error.hint, isNotEmpty);
    expect(
      const FactsBookException('stale_approval').stale &&
          const FactsBookException('precondition_failed').stale,
      isTrue,
    );
  });

  test(
    'settings and policy fixtures keep the shapes the owner calls rely on',
    () {
      final settings = _obj('settings');
      expect(settings['rev'], 1);
      expect(settings['lock_timeout_minutes'], 15);
      expect((settings['budget']! as Map)['monthly_money'], 0);
      final policy = _obj('policy');
      expect(policy['policy_version'], 1);
      expect(((policy['actions']! as Map)['default']), 'ask');
    },
  );

  group('cautious reading of words a newer node may send', () {
    test('provenance: unknown reads as guessed, external is kept apart', () {
      expect(FactProvenance.parse('external'), FactProvenance.external);
      expect(FactProvenance.parse('verified'), FactProvenance.guessed);
      expect(FactProvenance.parse(null), FactProvenance.guessed);
    });

    test('review state: unknown reads as waiting; module state as failed', () {
      expect(FactReview.parse('auto_safe'), FactReview.autoSafe);
      expect(FactReview.parse('mystery'), FactReview.proposed);
      expect(ReviewState.parse('mystery'), ReviewState.stale);
      expect(ModuleState.parse('green'), ModuleState.failed);
      expect(ThingKind.parse('spaceship'), ThingKind.other);
    });

    test('unknown keys are ignored', () {
      final json = _obj('thing')..['future_field'] = {'a': 1};
      expect(Thing.fromJson(json).title, 'Sam');
    });
  });

  test('the 30-day question: the node flags it, the phone counts it', () {
    final created = DateTime(2026, 9, 11, 12);
    final onPhone = CouldNotSaveEntry(
      id: 'out_1',
      text: 'x',
      reason: CouldNotSaveReason.nodeUnreachable,
      createdAt: created,
      onPhone: true,
    );
    expect(
      onPhone.needsThirtyDayPrompt(
        created.add(const Duration(days: 29, hours: 23)),
      ),
      isFalse,
    );
    expect(
      onPhone.needsThirtyDayPrompt(created.add(const Duration(days: 30))),
      isTrue,
    );
    final node = CouldNotSaveEntry.fromJson({
      ..._first('couldnt-save'),
      'prompt_due': true,
    });
    expect(node.needsThirtyDayPrompt(created), isTrue);
  });

  group('the B2 additions', () {
    test('the capability matrix the app ships is the node\'s', () {
      final node = FactsBookCapabilities.fromJson(_obj('capabilities'));
      expect(FactsBookCapabilities.b5.milestone, node.milestone);
      expect(FactsBookCapabilities.b5.supported, node.supported);
      expect(FactsBookCapabilities.b5.disabled, node.disabled);
      expect(node.supports(FactsBookCapabilities.reminders), isTrue);
      // Anything the node lists as disabled is "not available yet", never on.
      for (final off in [
        FactsBookCapabilities.cloudTransport,
        FactsBookCapabilities.safeInCloud,
        FactsBookCapabilities.sensitiveUnlock,
        FactsBookCapabilities.phoneAlarms,
      ]) {
        expect(node.supports(off), isFalse, reason: off);
        expect(node.isDisabled(off), isTrue, reason: off);
      }
    });

    test(
      'the English and Arabic inbox examples parse; Arabic stays Arabic',
      () {
        final ar = _obj('inbox-ar');
        expect(ar['text'], 'سام يقرأ الكتب');
        expect(ar['kind'], 'note');
        expect(_obj('inbox')['text'], 'Sam enjoys reading.');
      },
    );

    test(
      'the refusal fixtures: an outbox refusal and an index that is not ready',
      () {
        final refused = OutboxReceipt.fromJson(
          ((_obj('refused-outbox')['receipts']! as List).single as Map)
              .cast<String, Object?>(),
        );
        expect(refused.status, OutboxReceiptStatus.refused);
        expect(refused.error!.code, 'precondition_failed');
        expect(refused.error!.stale, isTrue);
        final rebuilding = FactsBookException.fromJson(
          ((_obj('index-rebuilding')['error']!) as Map).cast<String, Object?>(),
          status: 503,
        );
        expect(rebuilding.code, 'index_rebuilding');
        expect(rebuilding.requestId, 'op_00000000000000000000000003');
      },
    );

    test('clients and the control chain parse', () {
      final client = PairedClient.fromJson(_first('clients'));
      expect(client.scopes, ['read', 'write', 'owner', 'admin']);
      expect(client.ownerDevice, 'dev_00000000000000000000000001');
      final chain = ControlChain.fromJson(_obj('control'));
      expect(chain.records.map((r) => r.kind), [
        'vault.create',
        'executor.set',
      ]);
      expect(chain.cseq, 2);
      expect(chain.forked, isFalse);
    });

    test(
      'the settings fixture: lock timeout, brief cap, and a change keeps the rest',
      () {
        final settings = FactsBookSettings.fromJson(_obj('settings'));
        expect(settings.lockTimeoutMinutes, 15);
        expect(settings.brief.capPerDay, 5);
        expect(settings.brief.time, '08:00');
        expect(settings.brief.quietHours, '22:00-07:00');
        final next = settings.withBriefCap(3);
        expect((next['brief']! as Map)['cap_per_day'], 3);
        expect((next['brief']! as Map)['time'], '08:00');
        expect(next['budget'], _obj('settings')['budget']);
        expect(next['rev'], 1);
      },
    );
  });

  group('the fixed signature vector, byte for byte', () {
    final vector = _obj('signatures');
    final envelope = (vector['envelope']! as Map).cast<String, Object?>();

    test('our canonical JSON of the envelope is the vector\'s bytes', () {
      expect(Jcs.string(envelope), vector['canonical_utf8']);
      expect(
        Jcs.bytes(envelope),
        utf8.encode(vector['canonical_utf8']! as String),
      );
      expect(vector['canonicalization'], 'RFC8785');
      expect(vector['algorithm'], 'Ed25519');
    });

    test('the signature verifies against the vector\'s public key', () async {
      expect(
        await Ed25519.verify(
          bytesOfHex(vector['public_key']! as String),
          Jcs.bytes(envelope),
          bytesOfHex(vector['signature']! as String),
        ),
        isTrue,
      );
    });

    test(
      'every refusal the vector lists is a change that breaks the signature',
      () async {
        final key = bytesOfHex(vector['public_key']! as String);
        final sig = bytesOfHex(vector['signature']! as String);
        Future<bool> verifies(Map<String, Object?> changed) =>
            Ed25519.verify(key, Jcs.bytes(changed), sig);
        expect(
          await verifies({
            ...envelope,
            'body': {'x': 1},
          }),
          isFalse,
        );
        expect(await verifies({...envelope, 'method': 'PATCH'}), isFalse);
        expect(
          await verifies({
            ...envelope,
            'path': '/v1/clients/cli_00000000000000000000000003',
          }),
          isFalse,
        );
        expect(
          await verifies({
            ...envelope,
            'vault': 'vlt_00000000000000000000000002',
          }),
          isFalse,
        );
        expect(
          await verifies({...envelope, 'nonce': 'synthetic-nonce-0002'}),
          isFalse,
        );
        expect(
          await verifies({
            ...envelope,
            'authenticated_at': '2026-10-11T09:00:01Z',
          }),
          isFalse,
        );
        expect(vector['refusals'], contains('stale authentication'));
        expect(vector['refusals'], contains('forked authority'));
      },
    );

    test('the vector\'s root key hashes to its fingerprint', () {
      expect(
        sha256.convert(bytesOfHex(vector['public_key']! as String)).toString(),
        vector['root_fingerprint'],
      );
    });
  });

  group('the control chain against the pinned fingerprint', () {
    Future<ControlVerification> check(ControlChain chain, [String? pin]) =>
        ControlVerifier.verify(
          chain,
          pinnedFingerprint:
              pin ?? (_obj('control')['root_fingerprint']! as String),
        );

    test(
      'the node\'s chain is trusted: fingerprint, pin, signatures, links',
      () async {
        final result = await check(ControlChain.fromJson(_obj('control')));
        expect(result.fingerprintMatches, isTrue);
        expect(result.pinMatches, isTrue);
        expect(result.signaturesValid, isTrue);
        expect(result.chainLinked, isTrue);
        expect(result.forked, isFalse);
        expect(result.trusted, isTrue);
      },
    );

    test('the vectors embed the same chain', () async {
      final embedded = ((_obj('signatures')['control']!) as Map)
          .cast<String, Object?>();
      expect((await check(ControlChain.fromJson(embedded))).trusted, isTrue);
    });

    test(
      'a replacement fingerprint offered by the node is not accepted',
      () async {
        final result = await check(
          ControlChain.fromJson(_obj('control')),
          'a' * 64,
        );
        expect(result.pinMatches, isFalse);
        expect(result.trusted, isFalse);
      },
    );

    test(
      'a changed record, a changed order or a fork is not trusted',
      () async {
        Map<String, Object?> chain() =>
            jsonDecode(jsonEncode(_obj('control'))) as Map<String, Object?>;
        final tampered = chain();
        ((tampered['records']! as List).last as Map)['kind'] =
            'executor.retire';
        final changed = await check(ControlChain.fromJson(tampered));
        expect(changed.signaturesValid, isFalse);
        expect(changed.trusted, isFalse);

        final reordered = chain();
        (reordered['records']! as List).setAll(
          0,
          (reordered['records']! as List).reversed.toList(),
        );
        final order = await check(ControlChain.fromJson(reordered));
        expect(order.chainLinked, isFalse);

        final forked = chain()..['forked'] = true;
        final fork = await check(ControlChain.fromJson(forked));
        expect(fork.forked, isTrue);
        expect(fork.trusted, isFalse);

        final empty = chain()..['records'] = <Object?>[];
        expect((await check(ControlChain.fromJson(empty))).trusted, isFalse);
      },
    );
  });
}
