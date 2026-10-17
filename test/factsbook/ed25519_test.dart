// Ed25519 against the RFC 8032 test vectors, RFC 8785 canonical JSON, and the
// owner proof the node verifies.
import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/factsbook/ed25519.dart';
import 'package:opencode_mobile/domain/factsbook/jcs.dart';
import 'package:opencode_mobile/domain/factsbook/owner_signer.dart';

void main() {
  group('Ed25519 (RFC 8032 section 7.1)', () {
    test('test 1: empty message', () async {
      final seed = bytesOfHex(
        '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
      );
      expect(
        hexOf(await Ed25519.publicKey(seed)),
        'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a',
      );
      expect(
        hexOf(await Ed25519.sign(seed, const [])),
        'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b',
      );
    });

    test('test 2: one byte', () async {
      final seed = bytesOfHex(
        '4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb',
      );
      expect(
        hexOf(await Ed25519.publicKey(seed)),
        '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c',
      );
      expect(
        hexOf(await Ed25519.sign(seed, const [0x72])),
        '92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00',
      );
    });

    test('a seed of the wrong length is refused', () async {
      await expectLater(Ed25519.publicKey(Uint8List(31)), throwsArgumentError);
    });
  });

  group('JCS (RFC 8785)', () {
    test('sorts keys by code unit, drops whitespace, keeps integers', () {
      expect(
        Jcs.string({
          'b': 2,
          'a': [1, true, null, 'x'],
          'é': {'z': 1, 'A': 0},
        }),
        '{"a":[1,true,null,"x"],"b":2,"é":{"A":0,"z":1}}',
      );
    });

    test('escapes only what JSON requires', () {
      expect(Jcs.string('a"b\\c\n\u0001é'), r'"a\"b\\c\n\u0001é"');
    });

    test('refuses a non-integer number', () {
      expect(() => Jcs.string(1.5), throwsArgumentError);
    });

    test('the bytes are UTF-8', () {
      expect(Jcs.bytes('é'), utf8.encode('"é"'));
    });
  });

  group('OwnerSigner', () {
    final seed = bytesOfHex(
      '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
    );

    test(
      'the proof carries signer, nonce, time and a 128-hex signature',
      () async {
        final signer = OwnerSigner(
          seed: seed,
          deviceId: 'dev_00000000000000000000000002',
          vault: 'vlt_00000000000000000000000001',
          clientId: 'cli_00000000000000000000000001',
        );
        final proof = await withClock(
          Clock.fixed(DateTime.utc(2026, 10, 11, 12)),
          () {
            return signer.proof(
              method: 'post',
              path: '/v1/review/rvw_00000000000000000000000001/decision',
              body: {
                'decision': 'approve',
                'digest': 'a' * 64,
                'preconditions': {'per_00000000000000000000000001': 1},
                'proof': 'ignored',
              },
            );
          },
        );
        expect(proof['signer'], 'dev_00000000000000000000000002');
        expect(proof['authenticated_at'], '2026-10-11T12:00:00Z');
        expect((proof['nonce']! as String).length, 32);
        expect(proof['sig'], matches(RegExp(r'^[a-f0-9]{128}$')));
      },
    );

    test(
      'the signature covers the canonical envelope, and nothing else',
      () async {
        final signer = OwnerSigner(
          seed: seed,
          deviceId: 'dev_00000000000000000000000002',
          vault: 'vlt_00000000000000000000000001',
          clientId: 'cli_00000000000000000000000001',
        );
        final body = {
          'base_rev': 1,
          'settings': {'rev': 1},
        };
        final proof = await withClock(
          Clock.fixed(DateTime.utc(2026, 10, 11, 12)),
          () => signer.proof(method: 'PATCH', path: '/v1/config', body: body),
        );
        final envelope = {
          'vault': 'vlt_00000000000000000000000001',
          'client': 'cli_00000000000000000000000001',
          'method': 'PATCH',
          'path': '/v1/config',
          'body': body,
          'nonce': proof['nonce'],
          'authenticated_at': proof['authenticated_at'],
        };
        expect(
          proof['sig'],
          hexOf(await Ed25519.sign(seed, Jcs.bytes(envelope))),
        );
      },
    );

    test('a nonce is fresh every time', () async {
      final signer = OwnerSigner(
        seed: seed,
        deviceId: 'dev_00000000000000000000000002',
        vault: 'vlt_1',
        clientId: 'cli_1',
      );
      final a = await signer.proof(method: 'PUT', path: '/v1/policy', body: {});
      final b = await signer.proof(method: 'PUT', path: '/v1/policy', body: {});
      expect(a['nonce'], isNot(b['nonce']));
      expect(await signer.publicKeyHex(), hasLength(64));
    });
  });
}
