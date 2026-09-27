import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/session_address_link.dart';
import 'package:opencode_mobile/domain/session_handoff.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';

void main() {
  const origin = 'https://workstation.example-tailnet.ts.net';
  const instance = '9e30af6d-422d-4d89-baad-006ac07cb9d1';
  const session = 'ses_example';
  String wire({
    String server = origin,
    String id = session,
    String installation = instance,
  }) =>
      'opencode-mobile://session/v2?server=${Uri.encodeQueryComponent(server)}'
      '&instance=${Uri.encodeQueryComponent(installation)}&session=${Uri.encodeQueryComponent(id)}';
  SessionAddressLink build({String server = origin, String id = session}) =>
      SessionAddressLink.build(
        origin: server,
        instanceId: instance,
        sessionId: id,
        includeServerAddress: true,
      );
  Matcher failure(SessionAddressFailureCode code) => throwsA(
    isA<SessionAddressFailure>().having((e) => e.code, 'safe category', code),
  );
  setUp(KitRedact.clearKnownSecrets);
  tearDown(KitRedact.clearKnownSecrets);

  test('canonical round trip contains exactly three fields and no profile', () {
    final link = build(
      server: 'HTTPS://WORKSTATION.EXAMPLE-TAILNET.TS.NET:0443',
    );
    expect(link.origin, origin);
    expect(link.encode(), wire());
    expect(SessionAddressLink.require(link.encode()), link);
    expect(
      Uri.parse(link.encode()).queryParameters.keys,
      orderedEquals(['server', 'instance', 'session']),
    );
    expect(SessionLink.parse(link.encode()), isNull);
    expect(link.toString(), 'SessionAddressLink');
    expect(
      SessionAddressLink.require(
        wire().replaceFirst(
          'opencode-mobile://session',
          'OPENCODE-MOBILE://SESSION',
        ),
      ),
      link,
    );
    expect(build(server: '$origin:8443').origin, '$origin:8443');
  });

  test('address disclosure is required before building', () {
    expect(
      () => SessionAddressLink.build(
        origin: origin,
        instanceId: instance,
        sessionId: session,
        includeServerAddress: false,
      ),
      failure(SessionAddressFailureCode.consentRequired),
    );
  });

  test('strict envelope, keys, percent escapes and single decode', () {
    final valid = wire();
    final invalid = <Object?>[
      null,
      8,
      '',
      ' $valid',
      '$valid ',
      '$valid\n',
      valid.replaceFirst('/v2', '/V2'),
      valid.replaceFirst('/v2', '/v3'),
      valid.replaceFirst('/v2', '/x/../v2'),
      valid.replaceFirst('/v2', '/%762'),
      valid.replaceFirst('session/v2', 'session:5/v2'),
      valid.replaceFirst('session/v2', 'person@session/v2'),
      '$valid#fragment',
      '$valid#',
      '$valid&other=x',
      '$valid&server=x',
      '$valid&%73erver=x',
      valid.replaceFirst('server=', '%73erver='),
      valid.replaceFirst('server=', 'Server='),
      '$valid&',
      valid.replaceFirst('session=ses_example', 'session='),
      valid.replaceFirst('session=ses_example', 'session=a=b'),
      valid.replaceFirst('session=ses_example', 'session=%'),
      valid.replaceFirst('session=ses_example', 'session=%2'),
      valid.replaceFirst('session=ses_example', 'session=%gg'),
      valid.replaceFirst('session=ses_example', 'session=%FF'),
      valid.replaceFirst('session=ses_example', 'session=ses%252fother'),
      valid.replaceFirst('session=ses_example', 'session=ses+other'),
      wire(id: 'ses/other'),
      wire(id: 'ses\n'),
      wire(id: 'ses\u202Eother'),
      wire(id: 'ses&other'),
      wire(id: 'a' * 129),
      wire(id: '-option'),
      wire(installation: 'not-a-uuid'),
      wire(installation: '$instance\n'),
    ];
    for (var i = 0; i < invalid.length; i++) {
      expect(
        SessionAddressLink.parse(invalid[i]) == null,
        isTrue,
        reason: 'case $i',
      );
    }
  });

  test('native-equivalent encoded ASCII and size bounds', () {
    expect(
      () => SessionAddressLink.require('a' * 1025),
      failure(SessionAddressFailureCode.tooLarge),
    );
    expect(SessionAddressLink.parse('${wire()}\u00e9'), isNull);
    expect(SessionAddressLink.parse('${wire()}\u007f'), isNull);
    expect(SessionAddressLink.parse('${wire()}\u0000'), isNull);
  });

  test('only structurally valid full private HTTPS origins are accepted', () {
    final origins = [
      'http://workstation.example-tailnet.ts.net',
      'https://localhost',
      'https://127.0.0.1',
      'https://2130706433',
      'https://0x7f000001',
      'https://[::1]',
      'https://100.64.0.1',
      'https://workstation',
      'https://workstation.ts.net',
      'https://www.example.com',
      '$origin.',
      '$origin/',
      '$origin/path',
      '$origin?code=synthetic-code',
      '$origin#fragment',
      '$origin:0',
      '$origin:65536',
      '$origin:abc',
      'https://-device.tailnet.ts.net',
      'https://device-.tailnet.ts.net',
      'https://dev_ice.tailnet.ts.net',
      'https://device..ts.net',
      'https://*.tailnet.ts.net',
      'https://device.tailnet.ts.net.evil.test',
      'https://device%2etailnet.ts.net',
      'https://device.tailnet.ts.net\\@evil.test',
      'https://${'a' * 64}.tailnet.ts.net',
    ];
    for (var i = 0; i < origins.length; i++) {
      expect(
        SessionAddressLink.parse(wire(server: origins[i])) == null,
        isTrue,
        reason: 'origin case $i',
      );
    }
  });

  test(
    'credential-bearing input is rejected, never repaired or serialized',
    () {
      const secret = 'OpaqueSyntheticCredential';
      KitRedact.registerKnownSecret(secret);
      for (final raw in [
        wire(
          server: 'https://user:password@workstation.example-tailnet.ts.net',
        ),
        wire(server: '$origin?token=$secret'),
        wire(id: secret),
        wire(server: 'https://$secret.tailnet.ts.net'),
        wire(installation: secret),
        wire(id: 'sk-abcdefghijklmnopqrstuv'),
      ]) {
        expect(
          () => SessionAddressLink.require(raw),
          failure(SessionAddressFailureCode.credentials),
        );
      }
      expect(
        () => build(id: secret),
        failure(SessionAddressFailureCode.credentials),
      );
      final error = const SessionAddressFailure(
        SessionAddressFailureCode.credentials,
      );
      expect(error.toString(), 'SessionAddressFailure(credentials)');
    },
  );

  test('a secret registered after construction still cannot be serialized', () {
    final link = build();
    KitRedact.registerKnownSecret(session);
    expect(link.encode, failure(SessionAddressFailureCode.credentials));
  });
}
