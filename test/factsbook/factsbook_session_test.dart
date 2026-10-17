// Pairing, the secure slots, the outbox and the profile deletion sweep.
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/factsbook/factsbook_types.dart';
import 'package:opencode_mobile/domain/factsbook/fake_factsbook_gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/factsbook/factsbook_controller.dart';
import 'package:opencode_mobile/state/factsbook/factsbook_outbox.dart';
import 'package:opencode_mobile/state/factsbook/factsbook_session.dart';
import 'package:opencode_mobile/state/factsbook/factsbook_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/team_control_fixtures.dart' show MemorySecureStorage;
import 'factsbook_test_support.dart';
import 'node_adapter.dart';

final _pairJson = {
  'token': 'tok_secret',
  'client_id': 'cli_00000000000000000000000001',
  'scopes': ['read', 'write', 'admin', 'owner'],
  'vault': 'vlt_00000000000000000000000001',
  'root_fingerprint': 'a' * 64,
  'node': 'dev_00000000000000000000000001',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late MemorySecureStorage secure;
  late FactsBookStore store;
  late NodeAdapter node;
  late Dio dio;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    secure = MemorySecureStorage();
    store = FactsBookStore(prefs: prefs, secure: secure);
    node = NodeAdapter();
    dio = Dio(BaseOptions(validateStatus: (_) => true))
      ..httpClientAdapter = node;
  });

  FactsBookSession session() =>
      FactsBookSession(store: store, profileId: 'srv-1', dio: dio);

  group('pairing', () {
    test(
      'a code becomes a token in secure storage and a record in preferences',
      () async {
        node.reply('POST /v1/pair', _pairJson);
        final s = session();
        await s.load();
        expect(s.paired, isFalse);
        await s.pair(
          address: '127.0.0.1:8787',
          code: 'c' * 32,
          ownerDeviceId: ' dev_00000000000000000000000002 ',
        );
        expect(s.paired, isTrue);
        expect(s.canApprove, isTrue);
        // The token is a credential: secure storage only, under the profile.
        expect(secure.values['oc.factsbook.srv-1'], 'tok_secret');
        for (final key in prefs.getKeys()) {
          expect(prefs.get(key).toString(), isNot(contains('tok_secret')));
        }
        final link = store.link('srv-1')!;
        expect(link.baseUrl, Uri.parse('http://127.0.0.1:8787'));
        expect(link.ownerDeviceId, 'dev_00000000000000000000000002');
        expect(prefs.containsKey('oc.factsbookNode.srv-1'), isTrue);
        // Owner powers were asked for because an owner device id was given.
        expect((node.calls.single.body! as Map)['scopes_requested'], [
          'read',
          'write',
          'admin',
          'owner',
        ]);
      },
    );

    test(
      'without an owner device id only read and write are asked for',
      () async {
        node.reply('POST /v1/pair', {
          ..._pairJson,
          'scopes': ['read', 'write'],
        });
        final s = session();
        await s.pair(address: '127.0.0.1', code: 'c' * 32);
        expect((node.calls.single.body! as Map)['scopes_requested'], [
          'read',
          'write',
        ]);
        expect(s.canApprove, isFalse);
      },
    );

    test('a public address is refused before anything is sent', () async {
      final s = session();
      await expectLater(
        s.pair(address: 'example.com', code: 'c' * 32),
        throwsA(
          isA<FactsBookException>().having(
            (e) => e.code,
            'code',
            'address_not_allowed',
          ),
        ),
      );
      expect(node.calls, isEmpty);
      expect(secure.values, isEmpty);
    });

    test('a refused code stores nothing', () async {
      node.reply('POST /v1/pair', {
        'error': {
          'code': 'forbidden_scope',
          'message': 'm',
          'hint': 'h',
          'request_id': 'op_00000000000000000000000001',
        },
      }, status: 403);
      final s = session();
      await expectLater(
        s.pair(address: '127.0.0.1', code: 'x'),
        throwsA(isA<FactsBookException>()),
      );
      expect(s.paired, isFalse);
      expect(secure.values, isEmpty);
      expect(store.link('srv-1'), isNull);
    });

    test('a new session finds the pairing again', () async {
      node.reply('POST /v1/pair', _pairJson);
      await session().pair(address: '127.0.0.1', code: 'c' * 32);
      final again = session();
      await again.load();
      expect(again.paired, isTrue);
      expect(again.link!.node, 'dev_00000000000000000000000001');
    });

    test('a record without its token reads as unpaired', () async {
      node.reply('POST /v1/pair', _pairJson);
      await session().pair(address: '127.0.0.1', code: 'c' * 32);
      secure.values.remove('oc.factsbook.srv-1');
      final again = session();
      await again.load();
      expect(again.paired, isFalse);
    });

    test(
      'disconnect forgets the token, the key and the record, and keeps the outbox',
      () async {
        node.reply('POST /v1/pair', _pairJson);
        final s = session();
        await s.pair(
          address: '127.0.0.1',
          code: 'c' * 32,
          ownerDeviceId: 'dev_00000000000000000000000002',
        );
        await s.outbox.add(
          const CaptureRequest(kind: CaptureKind.note, text: 'kept'),
          'k1',
        );
        await s.disconnect();
        expect(s.paired, isFalse);
        expect(secure.values.containsKey('oc.factsbook.srv-1'), isFalse);
        expect(secure.values.containsKey('oc.factsbookOwner.srv-1'), isFalse);
        expect(prefs.containsKey('oc.factsbookNode.srv-1'), isFalse);
        expect(secure.values.containsKey('oc.factsbookOutbox.srv-1'), isTrue);
      },
    );
  });

  group('the owner key', () {
    test(
      'is made once, kept in secure storage, and only its public half is shown',
      () async {
        final s = session();
        final first = await s.ownerPublicKeyHex();
        final second = await s.ownerPublicKeyHex();
        expect(first, matches(RegExp(r'^[a-f0-9]{64}$')));
        expect(second, first);
        final seedHex = secure.values['oc.factsbookOwner.srv-1']!;
        expect(seedHex, hasLength(64));
        expect(first, isNot(seedHex));
      },
    );
  });

  group('the outbox', () {
    test('keeps notes between runs, in order, in secure storage', () async {
      final outbox = FactsBookOutbox(MemoryOutboxStore());
      await outbox.add(
        const CaptureRequest(kind: CaptureKind.note, text: 'one'),
        'k1',
      );
      await outbox.add(
        const CaptureRequest(kind: CaptureKind.note, text: 'two'),
        'k2',
      );
      expect(outbox.entries.map((e) => e.request.text), ['one', 'two']);
      final shared = MemoryOutboxStore();
      final a = FactsBookOutbox(shared);
      await a.add(
        const CaptureRequest(kind: CaptureKind.share, text: 'persisted'),
        'k3',
      );
      final b = FactsBookOutbox(shared);
      await b.load();
      expect(b.entries.single.request.text, 'persisted');
      expect(b.entries.single.key, 'k3');
    });

    test(
      'is bounded to 100 notes: the newest is refused, the oldest stays',
      () async {
        final outbox = FactsBookOutbox(MemoryOutboxStore());
        for (var i = 0; i < FactsBookOutbox.maxEntries; i++) {
          await outbox.add(
            CaptureRequest(kind: CaptureKind.note, text: 'n$i'),
            'k$i',
          );
        }
        await expectLater(
          outbox.add(
            const CaptureRequest(kind: CaptureKind.note, text: 'newest'),
            'kx',
          ),
          throwsA(isA<OutboxFullException>()),
        );
        expect(outbox.entries, hasLength(100));
        expect(outbox.entries.first.request.text, 'n0');
        expect(outbox.entries.any((e) => e.request.text == 'newest'), isFalse);
      },
    );

    test('is bounded to 5 MB too', () async {
      final outbox = FactsBookOutbox(MemoryOutboxStore());
      final big = 'x' * (3 * 1024 * 1024);
      await outbox.add(CaptureRequest(kind: CaptureKind.note, text: big), 'a');
      await expectLater(
        outbox.add(CaptureRequest(kind: CaptureKind.note, text: big), 'b'),
        throwsA(isA<OutboxFullException>()),
      );
      expect(outbox.entries, hasLength(1));
    });

    test(
      'flush sends oldest first and drops only what the node took',
      () async {
        final fake = FakeFactsBookGateway();
        final outbox = FactsBookOutbox(MemoryOutboxStore());
        await outbox.add(
          const CaptureRequest(kind: CaptureKind.note, text: 'one. a'),
          'k1',
        );
        await outbox.add(
          const CaptureRequest(kind: CaptureKind.note, text: 'two. b'),
          'k2',
        );
        expect(await outbox.flush(fake), 2);
        expect(outbox.entries, isEmpty);
        expect(fake.calls, ['outbox', 'capture', 'capture']);
      },
    );

    test(
      'a flush that cannot reach the node leaves everything in place',
      () async {
        final fake = FakeFactsBookGateway(reachable: false);
        final outbox = FactsBookOutbox(MemoryOutboxStore());
        await outbox.add(
          const CaptureRequest(kind: CaptureKind.note, text: 'kept'),
          'k1',
        );
        await expectLater(
          outbox.flush(fake),
          throwsA(isA<FactsBookException>()),
        );
        expect(outbox.entries, hasLength(1));
      },
    );

    test(
      'a refused note is marked, kept, and never retried by itself',
      () async {
        final fake = FakeFactsBookGateway();
        final outbox = FactsBookOutbox(MemoryOutboxStore());
        await outbox.add(
          CaptureRequest(kind: CaptureKind.note, text: 'x' * 200001),
          'big',
        );
        expect(await outbox.flush(fake), 0);
        expect(outbox.entries.single.refused, isTrue);
        expect(
          outbox.entries.single.asEntry().reason,
          CouldNotSaveReason.validationRejected,
        );
        await outbox.flush(fake);
        expect(fake.calls.where((c) => c == 'outbox'), hasLength(1));
      },
    );
  });

  group('the controller keeps what it could not send', () {
    late FakeFactsBookGateway fake;
    late FactsBookSession fixed;
    late FactsBookController controller;
    setUp(() {
      fake = withClock(Clock.fixed(factsNow), FakeFactsBookGateway.sample);
      fixed = FactsBookSession.fixed(fake);
      controller = FactsBookController(fixed);
    });
    tearDown(() => controller.dispose());

    test(
      'a capture while unreachable is kept on the phone and counted once',
      () async {
        await withClock(Clock.fixed(factsNow), controller.refresh);
        final before = controller.needsYouCount;
        fake.reachable = false;
        final outcome = await withClock(
          Clock.fixed(factsNow),
          () => controller.capture(
            const CaptureRequest(kind: CaptureKind.note, text: 'Call the bank'),
          ),
        );
        expect(outcome, isA<CaptureKeptOnPhone>());
        expect(fixed.outbox.entries.single.request.text, 'Call the bank');
        expect(
          controller.pending.where((e) => e.onPhone).single.text,
          'Call the bank',
        );
        expect(controller.needsYouCount, before + 1);
      },
    );

    test(
      'it goes to the node by itself once the node is back, with the same key',
      () async {
        fake.reachable = false;
        await withClock(
          Clock.fixed(factsNow),
          () => controller.capture(
            const CaptureRequest(kind: CaptureKind.note, text: 'Call the bank'),
          ),
        );
        final key = fixed.outbox.entries.single.key;
        fake.reachable = true;
        await withClock(Clock.fixed(factsNow), controller.refresh);
        expect(fixed.outbox.entries, isEmpty);
        expect(controller.pending.where((e) => e.onPhone), isEmpty);
        // Sending the same key again is not a second copy.
        final again = await fake.capture(
          const CaptureRequest(kind: CaptureKind.note, text: 'Call the bank'),
          idempotencyKey: key,
        );
        expect(again.saved, isTrue);
        expect(
          (await fake.things()).where((t) => t.title == 'Call the bank'),
          hasLength(1),
        );
      },
    );

    test('a full outbox refuses the newest and keeps the oldest', () async {
      fake.reachable = false;
      for (var i = 0; i < FactsBookOutbox.maxEntries; i++) {
        await fixed.outbox.add(
          CaptureRequest(kind: CaptureKind.note, text: 'n$i'),
          'k$i',
        );
      }
      final outcome = await controller.capture(
        const CaptureRequest(kind: CaptureKind.note, text: 'newest'),
      );
      expect(outcome, isA<CaptureRefusedFull>());
      expect(fixed.outbox.entries.first.request.text, 'n0');
      expect(
        fixed.outbox.entries.any((e) => e.request.text == 'newest'),
        isFalse,
      );
    });

    test(
      'the node holding a note in its own queue is not a loss either',
      () async {
        final outcome = await withClock(
          Clock.fixed(factsNow),
          () => controller.capture(
            const CaptureRequest(
              kind: CaptureKind.note,
              text: 'Blood test',
              area: 'health',
            ),
          ),
        );
        expect(outcome, isA<CaptureQueuedAtNode>());
        expect(controller.pending.where((e) => !e.onPhone), hasLength(2));
      },
    );

    test(
      'discard removes a phone note locally and a node note at the node',
      () async {
        fake.reachable = false;
        await withClock(
          Clock.fixed(factsNow),
          () => controller.capture(
            const CaptureRequest(kind: CaptureKind.note, text: 'Call the bank'),
          ),
        );
        final phone = controller.pending.firstWhere((e) => e.onPhone);
        fake.reachable = true;
        fixed.outbox.entries.length; // still held
        await withClock(Clock.fixed(factsNow), () => controller.discard(phone));
        expect(fixed.outbox.entries, isEmpty);
        await withClock(Clock.fixed(factsNow), controller.refresh);
        final node = controller.pending.firstWhere((e) => !e.onPhone);
        await withClock(Clock.fixed(factsNow), () => controller.discard(node));
        expect(fake.calls, contains('discard'));
      },
    );
  });

  group('profile deletion sweeps FactsBook', () {
    final deletes = <String>[];

    setUp(() {
      deletes.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (call) async {
              if (call.method == 'delete') {
                deletes.add((call.arguments as Map)['key']?.toString() ?? '');
              }
              return null;
            },
          );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('oc/background'),
            (_) async => null,
          );
    });

    test('names the keys by the profile id so the sweep finds them', () {
      expect(FactsBookStore.linkKey('p1'), 'oc.factsbookNode.p1');
      expect(FactsBookStore.secureKeys('p1'), [
        'oc.factsbook.p1',
        'oc.factsbookOwner.p1',
        'oc.factsbookOutbox.p1',
      ]);
    });

    test(
      'deleting the server deletes its pairing, token, key and outbox, and only its own',
      () async {
        SharedPreferences.setMockInitialValues({
          'oc.profiles': jsonEncode([
            {
              'id': 'doomed',
              'name': 'Old',
              'baseUrl': 'https://old.example:4096',
              'username': '',
            },
            {
              'id': 'keeper',
              'name': 'Laptop',
              'baseUrl': 'https://keep.example:4096',
              'username': '',
            },
          ]),
          'oc.activeProfile': 'doomed',
          'oc.factsbookNode.doomed': '{"url":"http://127.0.0.1:8787"}',
          'oc.factsbookNode.keeper': '{"url":"http://127.0.0.1:8788"}',
          'oc.appearance': 'dark',
        });
        final p = await SharedPreferences.getInstance();
        final profiles = ProfileStore(prefs: p);
        await profiles.load();
        final controller = ConnectionController(profiles);
        addTearDown(controller.dispose);

        final result = await controller.deleteProfileAndLocalData('doomed');

        expect(
          result.removedPreferenceKeys,
          contains('oc.factsbookNode.doomed'),
        );
        expect(p.containsKey('oc.factsbookNode.doomed'), isFalse);
        expect(deletes, containsAll(FactsBookStore.secureKeys('doomed')));
        // Another server's pairing, and app-wide keys, are untouched.
        expect(p.containsKey('oc.factsbookNode.keeper'), isTrue);
        expect(p.getString('oc.appearance'), 'dark');
        expect(deletes, isNot(contains('oc.factsbook.keeper')));
        expect(deletes, isNot(contains('oc.factsbookOutbox.keeper')));
      },
    );
  });
}
