// F3: the B2 contract in the gateway (settings, export, control, structured
// reminders), device authentication before an owner signature, plain words
// for every refusal, and refusals matched by position in the outbox.
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:opencode_mobile/domain/factsbook/device_auth.dart';
import 'package:opencode_mobile/domain/factsbook/ed25519.dart';
import 'package:opencode_mobile/domain/factsbook/factsbook_types.dart';
import 'package:opencode_mobile/domain/factsbook/fake_factsbook_gateway.dart';
import 'package:opencode_mobile/domain/factsbook/http_factsbook_gateway.dart';
import 'package:opencode_mobile/domain/factsbook/jcs.dart';
import 'package:opencode_mobile/domain/factsbook/owner_signer.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/factsbook/device_authenticator.dart';
import 'package:opencode_mobile/state/factsbook/factsbook_controller.dart';
import 'package:opencode_mobile/state/factsbook/factsbook_outbox.dart';
import 'package:opencode_mobile/state/factsbook/factsbook_session.dart';
import 'package:opencode_mobile/ui/screens/factsbook/factsbook_text.dart';

import 'node_adapter.dart';

Object? _fixture(String name) =>
    jsonDecode(File('test/fixtures/factsbook/$name.json').readAsStringSync());

class _Auth implements DeviceAuthenticator {
  _Auth(this.at, {this.fail});
  final DateTime at;
  final FactsBookException? fail;
  final reasons = <String>[];

  @override
  Future<DateTime> authenticate({required String reason}) async {
    reasons.add(reason);
    if (fail != null) throw fail!;
    return at;
  }
}

class _FakePlatform extends LocalAuthPlatform {
  bool supported = true;
  bool result = true;
  LocalAuthException? throws;
  bool missing = false;
  String? reason;

  @override
  Future<bool> isDeviceSupported() async {
    if (missing) throw MissingPluginException();
    return supported;
  }

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    reason = localizedReason;
    if (throws != null) throw throws!;
    return result;
  }
}

void main() {
  _serialTests();
  _realNodeFindings();
  final seed = bytesOfHex(
    '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
  );
  late NodeAdapter node;
  late Dio dio;

  HttpFactsBookGateway make({DeviceAuthenticator? auth}) =>
      HttpFactsBookGateway(
        baseUrl: Uri.parse('http://127.0.0.1:8787'),
        token: 'secret-token',
        owner: OwnerSigner(
          seed: seed,
          deviceId: 'dev_00000000000000000000000002',
          vault: 'vlt_00000000000000000000000001',
          clientId: 'cli_00000000000000000000000001',
          authenticator: auth,
          reason: () => 'Approve this change in FactsBook',
        ),
        dio: dio,
        retryDelay: Duration.zero,
      );

  setUp(() {
    node = NodeAdapter();
    dio = Dio(BaseOptions(validateStatus: (_) => true))
      ..httpClientAdapter = node;
  });

  group('settings, export and the control chain', () {
    test('settings are read with the admin call and parse', () async {
      node.reply('GET /v1/config', _fixture('settings'));
      final settings = await make().settings();
      expect(settings.lockTimeoutMinutes, 15);
      expect(node.calls.single.headers['Authorization'], 'Bearer secret-token');
    });

    test(
      'a brief cap change is signed against the revision the person saw',
      () async {
        node.reply('PATCH /v1/config', {
          'status': 'ok',
          'id': 'dev_00000000000000000000000001',
          'rev': 2,
        });
        final settings = FactsBookSettings.fromJson(
          (_fixture('settings')! as Map).cast<String, Object?>(),
        );
        await make().setBriefCap(settings, 3);
        final call = node.calls.single;
        expect(call.method, 'PATCH');
        expect(call.headers['Idempotency-Key'], isNotEmpty);
        final body = (call.body! as Map).cast<String, Object?>();
        expect(body['base_rev'], 1);
        final sent = (body['settings']! as Map).cast<String, Object?>();
        expect((sent['brief']! as Map)['cap_per_day'], 3);
        expect(sent['budget'], (settings.raw['budget']));
        final proof = (body['proof']! as Map).cast<String, Object?>();
        final unsigned = {...body}..remove('proof');
        final envelope = {
          'vault': 'vlt_00000000000000000000000001',
          'client': 'cli_00000000000000000000000001',
          'method': 'PATCH',
          'path': '/v1/config',
          'body': unsigned,
          'nonce': proof['nonce'],
          'authenticated_at': proof['authenticated_at'],
        };
        expect(
          proof['sig'],
          hexOf(await Ed25519.sign(seed, Jcs.bytes(envelope))),
        );
        expect(proof['nonce'], matches(RegExp(r'^[A-Za-z0-9_.-]{16,128}$')));
      },
    );

    test(
      'an unsaved capture is exported as the encrypted object the node hands back',
      () async {
        node.reply('GET /v1/inbox/cqs_00000000000000000000000001/export', {
          'v': 1,
          'vault': 'vlt_00000000000000000000000001',
          'cqs': 'cqs_00000000000000000000000001',
          'item': 'itm_00000000000000000000000002',
          'format': 'factsbook-encrypted-capture',
          'sealed': {'nonce': 'AAAA', 'ciphertext': 'BBBB'},
        });
        final export = await make().exportCapture(
          'cqs_00000000000000000000000001',
        );
        expect(export.item, 'itm_00000000000000000000000002');
        expect(export.text, contains('factsbook-encrypted-capture'));
        expect(export.text, contains('ciphertext'));
      },
    );

    test('the control chain is asked for from the start', () async {
      node.reply('GET /v1/control', _fixture('control'));
      final chain = await make().control();
      expect(chain.records, hasLength(2));
      expect(node.calls.single.uri.queryParameters, {'since': '0'});
    });
  });

  group('device authentication before an owner signature', () {
    final at = DateTime.utc(2026, 10, 11, 8, 59, 30);
    final item = ReviewItem.fromJson(
      ((_fixture('review')! as Map)['items']! as List).first
          as Map<String, Object?>,
    );

    test(
      'authenticated_at is the time the person authenticated, and the prompt uses our words',
      () async {
        final auth = _Auth(at);
        node.reply('POST /v1/review/rvw_00000000000000000000000001/decision', {
          'status': 'ok',
          'id': 'rvw_00000000000000000000000001',
        });
        await withClock(
          Clock.fixed(DateTime.utc(2026, 10, 11, 9)),
          () => make(auth: auth).decideReview(item, ReviewDecision.approve),
        );
        final proof = ((node.calls.single.body! as Map)['proof']! as Map);
        expect(proof['authenticated_at'], '2026-10-11T08:59:30Z');
        expect(auth.reasons, ['Approve this change in FactsBook']);
      },
    );

    test(
      'a refused prompt means nothing is signed and nothing is sent',
      () async {
        for (final code in [
          'device_auth_unavailable',
          'device_auth_cancelled',
          'device_auth_locked',
          'device_auth_failed',
        ]) {
          node.calls.clear();
          node.reply('GET /v1/policy', _fixture('policy'));
          final auth = _Auth(at, fail: FactsBookException(code));
          await expectLater(
            make(auth: auth).decideReview(item, ReviewDecision.approve),
            throwsA(
              isA<FactsBookException>().having((e) => e.code, 'code', code),
            ),
          );
          await expectLater(
            make(auth: auth).setAreaShare(
              Area.fromJson(
                ((_fixture('areas')! as Map)['items']! as List).first
                    as Map<String, Object?>,
              ),
              const AreaShare(),
            ),
            throwsA(
              isA<FactsBookException>().having((e) => e.code, 'code', code),
            ),
          );
          // Only the policy read may have gone out; no signed write.
          expect(
            node.calls.where((c) => c.method != 'GET'),
            isEmpty,
            reason: code,
          );
        }
      },
    );

    group('the local_auth wrapper', () {
      late _FakePlatform platform;
      late LocalAuthDeviceAuthenticator authenticator;
      setUp(() {
        platform = _FakePlatform();
        LocalAuthPlatform.instance = platform;
        authenticator = LocalAuthDeviceAuthenticator(
          auth: LocalAuthentication(),
        );
      });

      test('success returns the time and passes the reason', () async {
        final when = await withClock(
          Clock.fixed(DateTime.utc(2026, 10, 11, 9)),
          () => authenticator.authenticate(reason: 'Approve it'),
        );
        expect(when, DateTime.utc(2026, 10, 11, 9));
        expect(platform.reason, 'Approve it');
      });

      test('no screen lock or biometric set up is "unavailable"', () async {
        platform.supported = false;
        await expectLater(
          authenticator.authenticate(reason: 'r'),
          throwsA(
            isA<FactsBookException>().having(
              (e) => e.code,
              'code',
              'device_auth_unavailable',
            ),
          ),
        );
        platform
          ..supported = true
          ..throws = const LocalAuthException(
            code: LocalAuthExceptionCode.noCredentialsSet,
          );
        await expectLater(
          authenticator.authenticate(reason: 'r'),
          throwsA(
            isA<FactsBookException>().having(
              (e) => e.code,
              'code',
              'device_auth_unavailable',
            ),
          ),
        );
        platform.throws = const LocalAuthException(
          code: LocalAuthExceptionCode.noBiometricsEnrolled,
        );
        await expectLater(
          authenticator.authenticate(reason: 'r'),
          throwsA(
            isA<FactsBookException>().having(
              (e) => e.code,
              'code',
              'device_auth_unavailable',
            ),
          ),
        );
      });

      test('a platform without the plugin is "unavailable" too', () async {
        platform.missing = true;
        await expectLater(
          authenticator.authenticate(reason: 'r'),
          throwsA(
            isA<FactsBookException>().having(
              (e) => e.code,
              'code',
              'device_auth_unavailable',
            ),
          ),
        );
      });

      test(
        'backing out, timing out and a system interruption are "cancelled"',
        () async {
          for (final code in [
            LocalAuthExceptionCode.userCanceled,
            LocalAuthExceptionCode.systemCanceled,
            LocalAuthExceptionCode.timeout,
            LocalAuthExceptionCode.userRequestedFallback,
          ]) {
            platform.throws = LocalAuthException(code: code);
            await expectLater(
              authenticator.authenticate(reason: 'r'),
              throwsA(
                isA<FactsBookException>().having(
                  (e) => e.code,
                  'code',
                  'device_auth_cancelled',
                ),
              ),
              reason: '$code',
            );
          }
          platform
            ..throws = null
            ..result = false;
          await expectLater(
            authenticator.authenticate(reason: 'r'),
            throwsA(
              isA<FactsBookException>().having(
                (e) => e.code,
                'code',
                'device_auth_cancelled',
              ),
            ),
          );
        },
      );

      test('too many tries is "locked"; anything else is "failed"', () async {
        for (final code in [
          LocalAuthExceptionCode.temporaryLockout,
          LocalAuthExceptionCode.biometricLockout,
        ]) {
          platform.throws = LocalAuthException(code: code);
          await expectLater(
            authenticator.authenticate(reason: 'r'),
            throwsA(
              isA<FactsBookException>().having(
                (e) => e.code,
                'code',
                'device_auth_locked',
              ),
            ),
          );
        }
        platform.throws = const LocalAuthException(
          code: LocalAuthExceptionCode.deviceError,
        );
        await expectLater(
          authenticator.authenticate(reason: 'r'),
          throwsA(
            isA<FactsBookException>().having(
              (e) => e.code,
              'code',
              'device_auth_failed',
            ),
          ),
        );
      });
    });
  });

  group('every refusal in plain words', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final ar = lookupAppLocalizations(const Locale('ar'));

    test('each code the node or the app can raise has its own sentence', () {
      const codes = [
        'bad_request',
        'unauthorized',
        'forbidden_scope',
        'not_found',
        'conflict',
        'precondition_failed',
        'stale_approval',
        'locked_no_key',
        'sensitive_locked',
        'slow_down',
        'outbox_full',
        'index_rebuilding',
        'starting',
        'not_enabled',
        'node_unreachable',
        'bad_response',
        'owner_required',
        'address_not_allowed',
        'device_auth_unavailable',
        'device_auth_cancelled',
        'device_auth_locked',
        'device_auth_failed',
      ];
      final generic = failureWords(en, const FactsBookException('internal'));
      final seen = <String>{};
      for (final code in codes) {
        final words = failureWords(en, FactsBookException(code));
        expect(words, isNot(generic), reason: code);
        if (code.contains('_')) {
          expect(words, isNot(contains(code)), reason: 'no raw code in $code');
        }
        expect(words, isNot(contains('_')), reason: code);
        final arabic = failureWords(ar, FactsBookException(code));
        expect(
          arabic,
          isNot(failureWords(ar, const FactsBookException('internal'))),
          reason: code,
        );
        seen.add(words);
      }
      // Codes that mean the same thing may share a sentence; the rest do not.
      expect(seen.length, greaterThanOrEqualTo(17));
    });

    test('a wait the node asked for is said in seconds', () {
      expect(
        failureWords(
          en,
          const FactsBookException('slow_down', retryAfterSeconds: 60),
        ),
        'Memory is busy. Try again in 60 seconds.',
      );
    });

    test('the code and request id are only under Details', () {
      expect(
        failureDetails(
          en,
          const FactsBookException(
            'index_rebuilding',
            requestId: 'op_00000000000000000000000003',
          ),
        ),
        'Code index_rebuilding\nRequest op_00000000000000000000000003',
      );
      expect(failureDetails(en, 'plain string'), isNull);
    });

    test('device authentication words say what to do', () {
      expect(
        failureWords(en, const FactsBookException('device_auth_unavailable')),
        contains('Set one up'),
      );
      expect(
        failureWords(en, const FactsBookException('device_auth_cancelled')),
        contains('Nothing was changed'),
      );
    });
  });

  group('the outbox and the node\'s refusals', () {
    test(
      'a refusal for an event whose key was unusable is matched by position',
      () async {
        final fake = _OneRefusalGateway();
        final outbox = FactsBookOutbox(MemoryOutboxStore());
        await outbox.add(
          const CaptureRequest(kind: CaptureKind.note, text: 'a. b'),
          'k1',
        );
        await outbox.add(
          const CaptureRequest(kind: CaptureKind.note, text: 'c. d'),
          'k2',
        );
        expect(await outbox.flush(fake), 1);
        expect(outbox.entries, hasLength(1));
        expect(outbox.entries.single.refused, isTrue);
        expect(outbox.entries.single.request.text, 'c. d');
      },
    );

    test(
      'a node whose own queue is full still gets the note kept on the phone',
      () async {
        final fake = _NodeFullGateway();
        final session = FactsBookSession.fixed(fake);
        final controller = FactsBookController(session);
        addTearDown(controller.dispose);
        final outcome = await controller.capture(
          const CaptureRequest(kind: CaptureKind.note, text: 'Keep me'),
        );
        expect(outcome, isA<CaptureKeptOnPhone>());
        expect(session.outbox.entries.single.request.text, 'Keep me');
      },
    );
  });
}

/// Answers the second event with a refusal whose key is empty.
class _OneRefusalGateway extends FakeFactsBookGateway {
  @override
  Future<List<OutboxReceipt>> sendOutbox(List<OutboxEvent> events) async => [
    OutboxReceipt(key: events.first.key, status: OutboxReceiptStatus.accepted),
    const OutboxReceipt(
      key: '',
      status: OutboxReceiptStatus.refused,
      error: FactsBookException('bad_request'),
    ),
  ];
}

class _NodeFullGateway extends FakeFactsBookGateway {
  @override
  Future<CaptureResult> capture(
    CaptureRequest request, {
    required String idempotencyKey,
  }) async => throw const FactsBookException('outbox_full', status: 409);
}

/// The node takes one request at a time and answers 429 to one that arrives
/// while it is busy: the gateway sends one at a time and asks again briefly.
void _serialTests() {
  group('the node takes one request at a time', () {
    test('a 429 is asked again, a few times, then shown', () async {
      final node = NodeAdapter();
      final dio = Dio(BaseOptions(validateStatus: (_) => true))
        ..httpClientAdapter = node;
      final gateway = HttpFactsBookGateway(
        baseUrl: Uri.parse('http://127.0.0.1:8787'),
        token: 't',
        dio: dio,
        retryDelay: Duration.zero,
      );
      node.reply('GET /v1/status', {
        'error': {
          'code': 'slow_down',
          'message': 'm',
          'hint': 'h',
          'request_id': 'op_00000000000000000000000001',
          'retry_after_s': 60,
        },
      }, status: 429);
      node.reply('GET /v1/status', _fixture('status'));
      expect((await gateway.status()).module('storage').state, ModuleState.ok);
      expect(node.calls, hasLength(2));
      node.calls.clear();
      node.replies.clear();
      node.reply('GET /v1/status', {
        'error': {
          'code': 'slow_down',
          'message': 'm',
          'hint': 'h',
          'request_id': 'op_00000000000000000000000001',
          'retry_after_s': 60,
        },
      }, status: 429);
      await expectLater(
        gateway.status(),
        throwsA(
          isA<FactsBookException>().having((e) => e.code, 'code', 'slow_down'),
        ),
      );
      expect(node.calls, hasLength(4));
    });

    test(
      'requests never overlap, even when several are asked at once',
      () async {
        final node = _OverlapAdapter();
        final dio = Dio(BaseOptions(validateStatus: (_) => true))
          ..httpClientAdapter = node;
        final gateway = HttpFactsBookGateway(
          baseUrl: Uri.parse('http://127.0.0.1:8787'),
          token: 't',
          dio: dio,
          retryDelay: Duration.zero,
        );
        await Future.wait([
          gateway.status(),
          gateway.reviewItems(),
          gateway.pendingCaptures(),
          gateway.things(),
        ]);
        expect(node.maxInFlight, 1);
        expect(node.served, 4);
      },
    );
  });
}

class _OverlapAdapter extends NodeAdapter {
  var inFlight = 0;
  var maxInFlight = 0;
  var served = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    inFlight--;
    served++;
    final path = options.uri.path;
    final body = switch (path) {
      '/v1/status' => _fixture('status'),
      _ => {'items': <Object?>[], 'next_cursor': null},
    };
    return ResponseBody.fromString(jsonEncode(body), 200);
  }
}

/// What the real node taught us on an emulator (F4).
void _realNodeFindings() {
  group('what the real node needs', () {
    late NodeAdapter node;
    late HttpFactsBookGateway gateway;
    setUp(() {
      node = NodeAdapter();
      gateway = HttpFactsBookGateway(
        baseUrl: Uri.parse('http://127.0.0.1:8787'),
        token: 't',
        dio: Dio(BaseOptions(validateStatus: (_) => true))
          ..httpClientAdapter = node,
        retryDelay: Duration.zero,
      );
    });

    test('a write with nothing to send still says it is JSON', () async {
      node.reply(
        'POST /v1/inbox/cqs_00000000000000000000000001/retry',
        _fixture('capture'),
      );
      await gateway.retryCapture(
        'cqs_00000000000000000000000001',
        idempotencyKey: 'k',
      );
      final call = node.calls.single;
      expect(call.headers['Content-Type'], 'application/json');
      expect(call.body, <String, Object?>{});
    });

    test('a read and a delete send no body', () async {
      node.reply('GET /v1/status', _fixture('status'));
      node.reply('DELETE /v1/inbox/cqs_00000000000000000000000001', {
        'status': 'ok',
        'id': 'cqs_00000000000000000000000001',
      });
      await gateway.status();
      await gateway.discardCapture(
        'cqs_00000000000000000000000001',
        idempotencyKey: 'k',
      );
      for (final call in node.calls) {
        expect(call.body, isNull);
        expect(call.headers.containsKey('Content-Type'), isFalse);
      }
    });

    test('only proposals still waiting are the person\'s to decide', () async {
      final items = ((_fixture('review')! as Map)['items']! as List)
          .cast<Map<String, Object?>>();
      node.reply('GET /v1/review', {
        'items': [
          items.first,
          for (final state in ['approved', 'rejected', 'stale'])
            {
              ...items.first,
              'rvw': 'rvw_0000000000000000000000000$state'.substring(0, 30),
              'state': state,
            },
        ],
        'next_cursor': null,
      });
      final waiting = await gateway.reviewItems();
      expect(waiting, hasLength(1));
      expect(waiting.single.state, ReviewState.proposed);
    });

    test(
      'keys are letters only, so the node\'s classifier never reads a card number in one',
      () async {
        final fake = FakeFactsBookGateway.sample();
        final controller = FactsBookController(FactsBookSession.fixed(fake));
        addTearDown(controller.dispose);
        for (var i = 0; i < 20; i++) {
          await controller.capture(
            CaptureRequest(kind: CaptureKind.note, text: 'Sam walks $i'),
          );
        }
        expect(fake.keys, hasLength(20));
        for (final key in fake.keys) {
          expect(key, matches(RegExp(r'^cap-[a-z]{24}$')));
        }
        expect(fake.keys.toSet(), hasLength(20));
      },
    );

    test('a source that is a hash is worded, never shown', () {
      final en = lookupAppLocalizations(const Locale('en'));
      expect(
        sourceWords(
          en,
          '7f199d40fbe6ab9f9d4cd032d6a0f1bfd7267ace611267b2b06aa79213a3f1e4',
        ),
        'something you saved',
      );
      expect(sourceWords(en, 'a shared message'), 'a shared message');
    });
  });
}
