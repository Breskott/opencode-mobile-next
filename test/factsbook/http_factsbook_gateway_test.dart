// HttpFactsBookGateway against the node's v1 contract: paths, the bearer
// token, idempotency keys, the error envelope in plain words, pagination,
// pairing, and the owner proof on the calls that need it.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/factsbook/ed25519.dart';
import 'package:opencode_mobile/domain/factsbook/factsbook_types.dart';
import 'package:opencode_mobile/domain/factsbook/http_factsbook_gateway.dart';
import 'package:opencode_mobile/domain/factsbook/jcs.dart';
import 'package:opencode_mobile/domain/factsbook/owner_signer.dart';

import 'node_adapter.dart';

import 'dart:io';

Object? _fixture(String name) =>
    jsonDecode(File('test/fixtures/factsbook/$name.json').readAsStringSync());

const _error501 = {
  'error': {
    'code': 'not_enabled',
    'message': 'This capability is not enabled.',
    'hint': 'Use an enabled capability.',
    'request_id': 'op_00000000000000000000000001',
  },
};

void main() {
  late NodeAdapter node;
  late Dio dio;
  late HttpFactsBookGateway gateway;
  final seed = bytesOfHex(
    '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
  );
  final owner = OwnerSigner(
    seed: seed,
    deviceId: 'dev_00000000000000000000000002',
    vault: 'vlt_00000000000000000000000001',
    clientId: 'cli_00000000000000000000000001',
  );

  HttpFactsBookGateway make({OwnerSigner? signer}) => HttpFactsBookGateway(
    baseUrl: Uri.parse('http://127.0.0.1:8787'),
    token: 'secret-token',
    owner: signer,
    dio: dio,
    retryDelay: Duration.zero,
  );

  setUp(() {
    node = NodeAdapter();
    dio = Dio(
      BaseOptions(
        responseType: ResponseType.plain,
        validateStatus: (_) => true,
      ),
    )..httpClientAdapter = node;
    gateway = make(signer: owner);
  });

  group('reads', () {
    test('send the bearer token in a header, never in the address', () async {
      node.reply('GET /v1/status', _fixture('status'));
      final status = await gateway.status();
      expect(status.module('storage').state, ModuleState.ok);
      final call = node.calls.single;
      expect(call.headers['Authorization'], 'Bearer secret-token');
      expect(call.uri.toString(), isNot(contains('secret-token')));
      expect(call.headers.containsKey('Idempotency-Key'), isFalse);
    });

    test('lists follow next_cursor to the end and pass the kind', () async {
      node.reply('GET /v1/things', {
        'items': (_fixture('things')! as Map)['items'],
        'next_cursor': 'page2',
      });
      node.reply('GET /v1/things', _fixture('things'));
      final things = await gateway.things(kind: ThingKind.person);
      expect(things, hasLength(2));
      expect(node.calls.first.uri.queryParameters['kind'], 'person');
      expect(
        node.calls.first.uri.queryParameters.containsKey('cursor'),
        isFalse,
      );
      expect(node.calls[1].uri.queryParameters['cursor'], 'page2');
    });

    test('a thing id is path-safe', () async {
      node.reply(
        'GET /v1/things/per_00000000000000000000000001',
        _fixture('thing'),
      );
      expect(
        (await gateway.thing('per_00000000000000000000000001')).title,
        'Sam',
      );
    });

    test(
      'search sends the words and says locked notes were not searched',
      () async {
        node.reply('GET /v1/search', _fixture('search'));
        node.reply('GET /v1/status', _fixture('status'));
        final result = await gateway.search('walks');
        expect(result.hits.single.snippet, 'Sam prefers morning walks.');
        expect(result.lockedNotesSkipped, isTrue);
        expect(node.calls.first.uri.queryParameters['q'], 'walks');
      },
    );
  });

  group('errors in plain words', () {
    test('501 not_enabled keeps its code and request id', () async {
      node.reply('GET /v1/areas', _error501, status: 501);
      await expectLater(
        gateway.areas(),
        throwsA(
          isA<FactsBookException>()
              .having((e) => e.code, 'code', 'not_enabled')
              .having((e) => e.notEnabled, 'notEnabled', isTrue)
              .having(
                (e) => e.requestId,
                'requestId',
                'op_00000000000000000000000001',
              )
              .having((e) => e.status, 'status', 501),
        ),
      );
    });

    test('a status with no body is named from the status', () async {
      for (final (status, code) in [
        (401, 'unauthorized'),
        (403, 'forbidden_scope'),
        (404, 'not_found'),
        (412, 'precondition_failed'),
        (423, 'locked_no_key'),
        (429, 'slow_down'),
        (503, 'starting'),
        (500, 'internal'),
      ]) {
        node.replies.clear();
        node.reply('GET /v1/status', '', status: status);
        await expectLater(
          gateway.status(),
          throwsA(
            isA<FactsBookException>().having((e) => e.code, 'code', code),
          ),
          reason: '$status',
        );
      }
    });

    test('no answer at all is node_unreachable', () async {
      node.failWith = true;
      await expectLater(
        gateway.status(),
        throwsA(
          isA<FactsBookException>().having(
            (e) => e.unreachable,
            'unreachable',
            isTrue,
          ),
        ),
      );
    });

    test(
      'an answer the app cannot read is a plain failure, not a crash',
      () async {
        node.reply('GET /v1/status', 'not json at all');
        await expectLater(
          gateway.status(),
          throwsA(
            isA<FactsBookException>().having(
              (e) => e.code,
              'code',
              'bad_response',
            ),
          ),
        );
        node.replies.clear();
        node.reply('GET /v1/status', {'modules': 'wrong'});
        await expectLater(
          gateway.status(),
          throwsA(
            isA<FactsBookException>().having(
              (e) => e.code,
              'code',
              'bad_response',
            ),
          ),
        );
      },
    );
  });

  group('mutations carry an Idempotency-Key', () {
    test('capture: the given key, the body of the contract', () async {
      node.reply('POST /v1/inbox', _fixture('capture'));
      final result = await gateway.capture(
        const CaptureRequest(
          kind: CaptureKind.note,
          text: 'Buy stamps',
          area: 'family',
        ),
        idempotencyKey: 'key-1',
      );
      expect(result.saved, isTrue);
      final call = node.calls.single;
      expect(call.headers['Idempotency-Key'], 'key-1');
      expect(call.body, {
        'kind': 'note',
        'text': 'Buy stamps',
        'area': 'family',
        'trust': 'user_authored',
      });
    });

    test(
      'a fact added to a thing and a fact changed: the contract bodies',
      () async {
        node.reply('POST /v1/things/per_00000000000000000000000001/facts', {
          'status': 'proposed',
          'id': 'rvw_00000000000000000000000001',
          'review_id': 'rvw_00000000000000000000000001',
        });
        node.reply('PATCH /v1/facts/f_00000000000000000000000001', {
          'status': 'proposed',
          'id': 'rvw_00000000000000000000000002',
        });
        final thing = Thing(
          id: 'per_00000000000000000000000001',
          title: 'Sam',
          kind: ThingKind.person,
          updatedAt: DateTime(2026),
          revision: 3,
        );
        final added = await gateway.addFact(thing, 'Sam likes tea');
        expect(added.status, 'proposed');
        final fact = Fact(
          id: 'f_00000000000000000000000001',
          thingId: thing.id,
          text: 'Sam likes books',
          provenance: FactProvenance.seen,
          observedAt: DateTime(2026),
          source: 'share',
          category: 'odd-category',
          revision: 2,
        );
        await gateway.editFact(fact, 'Sam likes poems');
        expect(node.calls[0].body, {
          'text': 'Sam likes tea',
          'category': 'note',
          'base_rev': 3,
        });
        expect(node.calls[0].headers['Idempotency-Key'], isNotEmpty);
        // A category the node does not know is sent as a note.
        expect(node.calls[1].body, {
          'text': 'Sam likes poems',
          'category': 'note',
          'base_rev': 2,
        });
        expect(node.calls[1].headers['Authorization'], 'Bearer secret-token');
      },
    );

    test('retry, discard and the outbox batch', () async {
      node.reply(
        'POST /v1/inbox/cqs_00000000000000000000000001/retry',
        _fixture('capture'),
      );
      node.reply('DELETE /v1/inbox/cqs_00000000000000000000000001', {
        'status': 'ok',
        'id': 'cqs_00000000000000000000000001',
      });
      node.reply('POST /v1/outbox', _fixture('outbox'));
      await gateway.retryCapture(
        'cqs_00000000000000000000000001',
        idempotencyKey: 'k-retry',
      );
      await gateway.discardCapture(
        'cqs_00000000000000000000000001',
        idempotencyKey: 'k-del',
      );
      final receipts = await gateway.sendOutbox([
        const OutboxEvent(
          key: 'synthetic-event-one',
          payload: {'kind': 'note', 'text': 'x'},
        ),
      ]);
      expect(receipts.single.status, OutboxReceiptStatus.accepted);
      expect(node.calls[0].headers['Idempotency-Key'], 'k-retry');
      expect(node.calls[1].headers['Idempotency-Key'], 'k-del');
      expect(node.calls[2].headers['Idempotency-Key'], isNotEmpty);
      expect(node.calls[2].body, {
        'events': [
          {
            'key': 'synthetic-event-one',
            'type': 'capture',
            'payload': {'kind': 'note', 'text': 'x'},
          },
        ],
      });
    });

    test('every other write has a fresh key', () async {
      node.reply('POST /v1/reminders/parse', _previewJson());
      node.reply('POST /v1/reminders', {
        'status': 'ok',
        'id': 'rem_00000000000000000000000002',
        'rev': 1,
      });
      final preview = await gateway.previewReminder(
        what: 'Dentist',
        timing: ReminderTiming(
          repeat: ReminderRepeat.never,
          at: DateTime(2026, 10, 21, 10),
        ),
        zone: 'vault',
        locale: 'en',
      );
      await gateway.createReminder(preview);
      await gateway.createReminder(preview);
      final keys = [
        for (final c in node.calls.where((c) => c.uri.path == '/v1/reminders'))
          c.headers['Idempotency-Key'],
      ];
      expect(keys.every((k) => k is String && k.isNotEmpty), isTrue);
      expect(keys.toSet(), hasLength(2));
    });
  });

  group('reminders', () {
    test(
      'the schedule goes as structured JSON with the title in its own field',
      () async {
        node.reply('POST /v1/reminders/parse', _previewJson());
        final preview = await gateway.previewReminder(
          what: ' Dentist ',
          timing: ReminderTiming(
            repeat: ReminderRepeat.never,
            at: DateTime(2026, 10, 21, 9, 5),
          ),
          zone: 'floating',
          locale: 'ar',
          area: 'health',
        );
        final body = (node.calls.single.body! as Map).cast<String, Object?>();
        expect(body['what'], 'Dentist');
        expect(body['locale'], 'ar');
        expect(body['zone'], 'floating');
        expect(body['area'], 'health');
        final schedule = (jsonDecode(body['text']! as String) as Map)
            .cast<String, Object?>();
        expect(schedule['v'], 1);
        expect(
          schedule['id'],
          matches(RegExp(r'^sch_[0-7][0-9A-HJKMNP-TV-Z]{25}$')),
        );
        expect(schedule['when'], {'once': '2026-10-21T09:05'});
        expect(schedule['zone'], 'floating');
        expect(schedule['window'], isNull);
        expect(schedule['catchup'], 'coalesce');
        // A preview needs no idempotency key.
        expect(
          node.calls.single.headers.containsKey('Idempotency-Key'),
          isFalse,
        );
        expect(preview.confirmable, isTrue);
        expect(preview.at, DateTime(2026, 10, 21, 10));
        expect(preview.settingsRevision, 1);
        expect(preview.effectiveZone, 'UTC');
        expect(preview.area, 'general');
      },
    );

    test('repeating schedules use the node\'s own forms', () async {
      final at = DateTime(2026, 10, 21, 8, 30);
      expect(ReminderTiming(repeat: ReminderRepeat.daily, at: at).toWhen(), {
        'every': 'day',
        'at': '08:30',
      });
      expect(
        ReminderTiming(
          repeat: ReminderRepeat.weekly,
          at: at,
          weekdays: const {5, 1},
        ).toWhen(),
        {
          'every': 'week',
          'on': ['mon', 'fri'],
          'at': '08:30',
        },
      );
      expect(
        ReminderTiming(
          repeat: ReminderRepeat.monthly,
          at: at,
          dayOfMonth: 15,
        ).toWhen(),
        {'every': 'month', 'day': 15, 'at': '08:30'},
      );
      expect(
        ReminderTiming(
          repeat: ReminderRepeat.monthly,
          at: at,
          lastDay: true,
        ).toWhen(),
        {'every': 'month', 'day': 'last', 'at': '08:30'},
      );
      expect(ReminderTiming(repeat: ReminderRepeat.yearly, at: at).toWhen(), {
        'every': 'year',
        'month': 10,
        'day': 21,
        'at': '08:30',
      });
    });

    test(
      'a schedule read back keeps its form; one the app does not build stays raw',
      () {
        for (final timing in [
          ReminderTiming(
            repeat: ReminderRepeat.never,
            at: DateTime(2026, 10, 21, 9),
          ),
          ReminderTiming(
            repeat: ReminderRepeat.daily,
            at: DateTime(2000, 1, 1, 7),
          ),
          ReminderTiming(
            repeat: ReminderRepeat.weekly,
            at: DateTime(2000, 1, 1, 7),
            weekdays: const {2, 4},
          ),
          ReminderTiming(
            repeat: ReminderRepeat.monthly,
            at: DateTime(2000, 1, 1, 7),
            dayOfMonth: 31,
          ),
          ReminderTiming(
            repeat: ReminderRepeat.yearly,
            at: DateTime(2000, 2, 29, 7),
          ),
        ]) {
          final back = ReminderTiming.fromWhen(ScheduleWhen(timing.toWhen()))!;
          expect(back.toWhen(), timing.toWhen());
        }
        expect(
          ReminderTiming.fromWhen(const ScheduleWhen({'every': '6h'})),
          isNull,
        );
        expect(
          ReminderTiming.fromWhen(
            const ScheduleWhen({'on': 'event', 'event': 'x'}),
          ),
          isNull,
        );
      },
    );

    test('an edit keeps the schedule id', () async {
      node.reply('POST /v1/reminders/parse', _previewJson());
      await gateway.previewReminder(
        what: 'Dentist',
        timing: ReminderTiming(
          repeat: ReminderRepeat.daily,
          at: DateTime(2026, 10, 21, 8),
        ),
        zone: 'vault',
        locale: 'en',
        scheduleId: 'sch_00000000000000000000000009',
      );
      final body = (node.calls.single.body! as Map).cast<String, Object?>();
      expect(
        (jsonDecode(body['text']! as String) as Map)['id'],
        'sch_00000000000000000000000009',
      );
    });

    test('an edit may confirm a floating zone', () async {
      node.reply('POST /v1/reminders/parse', _previewJson());
      node.reply('PATCH /v1/reminders/rem_00000000000000000000000001', {
        'status': 'ok',
        'id': 'rem_00000000000000000000000001',
        'rev': 2,
      });
      final reminder = Reminder.fromJson(
        ((_fixture('reminders')! as Map)['items']! as List).first
            as Map<String, Object?>,
      );
      final preview = await gateway.previewReminder(
        what: 'Dentist',
        timing: ReminderTiming(
          repeat: ReminderRepeat.never,
          at: DateTime(2026, 10, 21, 10),
        ),
        zone: 'floating',
        locale: 'en',
      );
      await gateway.updateReminder(reminder, preview, floatingConfirmed: true);
      final body = node.calls.last.body! as Map;
      expect(body['floating_confirmed'], isTrue);
      expect(body['preview'], preview.raw);
      expect(body['base_rev'], 1);
    });

    test(
      'create sends the preview exactly as received with its digest',
      () async {
        node.reply('POST /v1/reminders/parse', _previewJson());
        node.reply('POST /v1/reminders', {
          'status': 'ok',
          'id': 'rem_00000000000000000000000002',
          'rev': 1,
        });
        final preview = await gateway.previewReminder(
          what: 'Dentist',
          timing: ReminderTiming(
            repeat: ReminderRepeat.never,
            at: DateTime(2026, 10, 21, 10),
          ),
          zone: 'vault',
          locale: 'en',
        );
        await gateway.createReminder(
          preview,
          urgent: true,
          floatingConfirmed: true,
        );
        final body = node.calls.last.body! as Map;
        expect(body['preview'], preview.raw);
        expect(body['preview_digest'], preview.digest);
        expect(body['confirmed'], isTrue);
        expect(body['urgent'], isTrue);
        expect(body['floating_confirmed'], isTrue);
      },
    );

    test('pause is a patch with the revision it was based on', () async {
      node.reply('PATCH /v1/reminders/rem_00000000000000000000000001', {
        'status': 'ok',
        'id': 'rem_00000000000000000000000001',
        'rev': 2,
      });
      final reminder = Reminder.fromJson(
        ((_fixture('reminders')! as Map)['items']! as List).first
            as Map<String, Object?>,
      );
      await gateway.setReminderPaused(reminder, paused: true);
      expect(node.calls.single.body, {'base_rev': 1, 'paused': true});
    });
  });

  group('the owner proof', () {
    test(
      'a review decision is signed and bound to its digest and preconditions',
      () async {
        node.reply('POST /v1/review/rvw_00000000000000000000000001/decision', {
          'status': 'ok',
          'id': 'rvw_00000000000000000000000001',
        });
        final item = ReviewItem.fromJson(
          ((_fixture('review')! as Map)['items']! as List).first
              as Map<String, Object?>,
        );
        await gateway.decideReview(item, ReviewDecision.approve);
        final call = node.calls.single;
        final body = (call.body! as Map).cast<String, Object?>();
        expect(body['decision'], 'approve');
        expect(body['digest'], item.digest);
        expect(body['preconditions'], item.preconditions);
        final proof = (body['proof']! as Map).cast<String, Object?>();
        expect(proof['signer'], 'dev_00000000000000000000000002');
        // The signature covers the canonical envelope the node rebuilds.
        final unsigned = {...body}..remove('proof');
        final envelope = {
          'vault': 'vlt_00000000000000000000000001',
          'client': 'cli_00000000000000000000000001',
          'method': 'POST',
          'path': '/v1/review/rvw_00000000000000000000000001/decision',
          'body': unsigned,
          'nonce': proof['nonce'],
          'authenticated_at': proof['authenticated_at'],
        };
        expect(
          proof['sig'],
          hexOf(await Ed25519.sign(seed, Jcs.bytes(envelope))),
        );
      },
    );

    test('an edit sends the edited proposal', () async {
      node.reply('POST /v1/review/rvw_00000000000000000000000001/decision', {
        'status': 'ok',
        'id': 'rvw_00000000000000000000000001',
      });
      final item = ReviewItem.fromJson(
        ((_fixture('review')! as Map)['items']! as List).first
            as Map<String, Object?>,
      );
      await gateway.decideReview(
        item,
        ReviewDecision.edit,
        edited: {...item.proposal, 'text': 'Sam likes poems'},
      );
      final body = node.calls.single.body! as Map;
      expect(body['decision'], 'edit');
      expect((body['edited']! as Map)['text'], 'Sam likes poems');
      expect((body['edited']! as Map)['kind'], 'fact.add');
    });

    test('without an owner key the call never leaves the phone', () async {
      final plain = make();
      final item = ReviewItem.fromJson(
        ((_fixture('review')! as Map)['items']! as List).first
            as Map<String, Object?>,
      );
      await expectLater(
        plain.decideReview(item, ReviewDecision.skip),
        throwsA(
          isA<FactsBookException>().having(
            (e) => e.code,
            'code',
            'owner_required',
          ),
        ),
      );
      await expectLater(
        plain.setAreaShare(
          Area.fromJson(
            ((_fixture('areas')! as Map)['items']! as List).first
                as Map<String, Object?>,
          ),
          const AreaShare(),
        ),
        throwsA(
          isA<FactsBookException>().having(
            (e) => e.code,
            'code',
            'owner_required',
          ),
        ),
      );
      expect(node.calls.where((c) => c.method != 'GET'), isEmpty);
    });

    test('area sharing reads the policy revision and signs the area', () async {
      node.reply('GET /v1/policy', _fixture('policy'));
      node.reply('PATCH /v1/areas/family', {
        'status': 'ok',
        'id': 'dev_00000000000000000000000001',
        'rev': 2,
      });
      final area = Area.fromJson(
        ((_fixture('areas')! as Map)['items']! as List).first
            as Map<String, Object?>,
      );
      await gateway.setAreaShare(area, const AreaShare());
      expect(node.calls.map((c) => '${c.method} ${c.uri.path}'), [
        'GET /v1/policy',
        'PATCH /v1/areas/family',
      ]);
      final body = (node.calls.last.body! as Map).cast<String, Object?>();
      expect(body['base_rev'], 1);
      final sent = (body['area']! as Map).cast<String, Object?>();
      expect(sent['slug'], 'family');
      expect((sent['share']! as Map)['default'], 'none');
      expect(
        (body['proof']! as Map)['sig'],
        matches(RegExp(r'^[a-f0-9]{128}$')),
      );
    });

    test('a stale approval is named as stale', () async {
      node.reply('POST /v1/review/rvw_00000000000000000000000001/decision', {
        'error': {
          'code': 'stale_approval',
          'message': 'x',
          'hint': 'y',
          'request_id': 'op_00000000000000000000000002',
        },
      }, status: 412);
      final item = ReviewItem.fromJson(
        ((_fixture('review')! as Map)['items']! as List).first
            as Map<String, Object?>,
      );
      await expectLater(
        gateway.decideReview(item, ReviewDecision.approve),
        throwsA(
          isA<FactsBookException>().having((e) => e.stale, 'stale', isTrue),
        ),
      );
    });
  });

  group('pairing', () {
    final pairJson = {
      'token': 'tok_abc',
      'client_id': 'cli_00000000000000000000000001',
      'scopes': ['read', 'write'],
      'vault': 'vlt_00000000000000000000000001',
      'root_fingerprint': 'a' * 64,
      'node': 'dev_00000000000000000000000001',
    };

    test(
      'a code becomes a token, sent without an Authorization header',
      () async {
        node.reply('POST /v1/pair', pairJson);
        final result = await FactsBookPairing.pair(
          Uri.parse('http://127.0.0.1:8787'),
          code: ' ${'c' * 32} ',
          clientName: 'OpenCode Mobile',
          dio: dio,
        );
        expect(result.token, 'tok_abc');
        expect(result.scopes, ['read', 'write']);
        final call = node.calls.single;
        expect(call.headers.containsKey('Authorization'), isFalse);
        expect(call.body, {
          'code': 'c' * 32,
          'client_name': 'OpenCode Mobile',
          'scopes_requested': ['read', 'write'],
        });
      },
    );

    test('a refused code is a plain failure', () async {
      node.reply('POST /v1/pair', {
        'error': {
          'code': 'forbidden_scope',
          'message': 'm',
          'hint': 'h',
          'request_id': 'op_00000000000000000000000003',
        },
      }, status: 403);
      await expectLater(
        FactsBookPairing.pair(
          Uri.parse('http://127.0.0.1:8787'),
          code: 'x',
          clientName: 'OpenCode Mobile',
          dio: dio,
        ),
        throwsA(
          isA<FactsBookException>().having(
            (e) => e.code,
            'code',
            'forbidden_scope',
          ),
        ),
      );
    });

    test('info needs no credential', () async {
      node.reply('GET /v1/info', {
        'node_id': 'dev_00000000000000000000000001',
        'name': 'n',
      });
      final info = await FactsBookPairing.info(
        Uri.parse('http://127.0.0.1:8787'),
        dio: dio,
      );
      expect(info['name'], 'n');
      expect(node.calls.single.headers.containsKey('Authorization'), isFalse);
    });
  });
}

Map<String, Object?> _previewJson() {
  final value = <String, Object?>{
    'what': 'Dentist',
    'date': '2026-10-21',
    'time': '10:00',
    'zone': 'vault',
    'locale': 'en',
    'repeat': null,
    'ambiguities': <String>[],
    'schedule': {
      'v': 1,
      'id': 'sch_00000000000000000000000009',
      'when': {'once': '2026-10-21T10:00'},
      'zone': 'vault',
      'window': null,
      'catchup': 'coalesce',
    },
    'adjustments': <String>[],
    'settings_rev': 1,
    'effective_zone': 'UTC',
    'area': 'general',
    'sens': 'normal',
    'preview_digest': 'b' * 64,
  };
  return value;
}
