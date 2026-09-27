import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/session_address_handoff.dart';
import 'package:opencode_mobile/domain/session_address_link.dart';
import 'package:opencode_mobile/platform/session_address_transport.dart';

const origin = 'https://device.tailnet.ts.net';
const instance = '9e30af6d-422d-4d89-baad-006ac07cb9d1';
Map<String, Object> payload() => {
  'schemaVersion': 1,
  'instanceId': instance,
  'canonicalOrigin': origin,
  'linkVersions': [2],
  'capabilities': {'sessionLookupById': true},
};
Matcher fails(SessionAddressFailureCode code) =>
    throwsA(isA<SessionAddressFailure>().having((e) => e.code, 'code', code));

class _Task {
  bool cancelled = false;
  late final ConnectionTask<Socket> connection = ConnectionTask.fromSocket(
    Completer<Socket>().future,
    () {
      cancelled = true;
    },
  );
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.statusCode, this.body);
  @override
  final int statusCode;
  final List<int> body;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(body).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.response);
  final _Response response;
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;
  @override
  Future<HttpClientResponse> close() async => response;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client implements HttpClient {
  _Client(this.request);
  final _Request request;
  Future<ConnectionTask<Socket>> Function(Uri, String?, int?)? factory;
  Object? error;
  Uri? requested;
  bool closed = false;
  bool touchedAuthentication = false;
  bool bypassedCertificates = false;
  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(Uri, String?, int?)? value,
  ) {
    factory = value;
  }

  @override
  set connectionTimeout(Duration? value) {}
  @override
  set findProxy(String Function(Uri)? value) {
    expect(value!(Uri.parse(origin)), 'DIRECT');
  }

  @override
  set badCertificateCallback(
    bool Function(X509Certificate, String, int)? value,
  ) {
    bypassedCertificates = true;
  }

  @override
  set authenticate(Future<bool> Function(Uri, String, String?)? value) {
    touchedAuthentication = true;
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requested = url;
    if (error != null) throw error!;
    await factory!(url, null, null);
    return request;
  }

  @override
  void close({bool force = false}) {
    closed = force;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Client client;
  late _Task task;
  late List<InternetAddress> addresses;
  var connects = 0;
  PrivateSessionDescriptorReader reader() => PrivateSessionDescriptorReader(
    resolve: (_) async => addresses,
    connect: (address, port) async {
      expect(
        PrivateSessionDescriptorReader.isPrivateTailnetAddress(address),
        isTrue,
      );
      expect(port, 443);
      connects++;
      return task.connection;
    },
    clientFactory: () => client,
    timeout: const Duration(milliseconds: 100),
  );
  setUp(() {
    client = _Client(
      _Request(_Response(200, utf8.encode(jsonEncode(payload())))),
    );
    task = _Task();
    addresses = [InternetAddress('100.80.1.2')];
    connects = 0;
  });
  test(
    'anonymous exact discovery pins checked IP, validates descriptor and closes',
    () async {
      final result = await reader().discover(origin);
      expect(result.origin, origin);
      expect(result.instanceId, instance);
      expect(
        client.requested?.path,
        '/.well-known/opencode-mobile-session-handoff',
      );
      expect(client.requested?.hasQuery, isFalse);
      expect(client.request.followRedirects, isFalse);
      expect(client.request.maxRedirects, 0);
      expect(client.request.persistentConnection, isFalse);
      expect(
        client.touchedAuthentication || client.bypassedCertificates,
        isFalse,
      );
      expect(client.closed && task.cancelled, isTrue);
      expect(connects, 1);
    },
  );
  for (final address in [
    '8.8.8.8',
    '127.0.0.1',
    '169.254.1.2',
    '192.168.1.2',
    '10.0.0.1',
    '100.63.255.255',
    '100.128.0.0',
    '::1',
    'fe80::1',
    'fd00::1',
    '::ffff:100.80.1.2',
  ]) {
    test(
      'rejects non-tailnet destination $address before connection',
      () async {
        addresses = [InternetAddress(address)];
        await expectLater(
          reader().discover(origin),
          fails(SessionAddressFailureCode.privateRouteRequired),
        );
        expect(connects, 0);
      },
    );
  }
  test(
    'tailnet IPv6 accepted, mixed/public DNS and changed DNS refused',
    () async {
      addresses = [InternetAddress('fd7a:115c:a1e0::1234')];
      await reader().discover(origin);
      addresses = [InternetAddress('100.80.1.2'), InternetAddress('1.1.1.1')];
      await expectLater(
        reader().discover(origin),
        fails(SessionAddressFailureCode.privateRouteRequired),
      );
      addresses = [InternetAddress('1.1.1.1')];
      await expectLater(
        reader().discover(origin),
        fails(SessionAddressFailureCode.privateRouteRequired),
      );
      expect(connects, 1);
    },
  );
  for (final status in [301, 302, 307, 308, 401, 403, 404]) {
    test('status $status is a bounded typed refusal, never followed', () async {
      client = _Client(_Request(_Response(status, [])));
      await expectLater(
        reader().discover(origin),
        fails(
          status < 400
              ? SessionAddressFailureCode.redirectsRejected
              : status == 401 || status == 403
              ? SessionAddressFailureCode.accessDenied
              : SessionAddressFailureCode.invalidDescriptor,
        ),
      );
      expect(connects, 1);
      expect(client.closed, isTrue);
    });
  }
  test(
    'certificate failure is typed without raw host or exception details',
    () async {
      client.error = const HandshakeException(
        'private fixture must not surface',
      );
      await expectLater(
        reader().discover(origin),
        fails(SessionAddressFailureCode.tlsRejected),
      );
      expect(client.bypassedCertificates, isFalse);
    },
  );
  test('response size bound and malformed descriptor fail closed', () async {
    client = _Client(_Request(_Response(200, List.filled(8193, 32))));
    await expectLater(
      reader().discover(origin),
      fails(SessionAddressFailureCode.invalidDescriptor),
    );
    for (final value in [
      null,
      {},
      {...payload(), 'credentials': 'forbidden'},
      {
        ...payload(),
        'capabilities': {'sessionLookupById': false},
      },
      {...payload(), 'canonicalOrigin': '$origin/'},
      {...payload(), 'instanceId': 'wrong'},
    ]) {
      expect(
        () => SessionAddressDescriptor.parse(value),
        fails(SessionAddressFailureCode.invalidDescriptor),
      );
    }
  });
  test('late DNS after timeout cannot start a socket', () async {
    final dns = Completer<List<InternetAddress>>();
    final transport = PrivateSessionDescriptorReader(
      resolve: (_) => dns.future,
      connect: (_, _) async {
        connects++;
        return task.connection;
      },
      clientFactory: () => client,
      timeout: const Duration(milliseconds: 1),
    );
    await expectLater(
      transport.discover(origin),
      fails(SessionAddressFailureCode.timedOut),
    );
    dns.complete([InternetAddress('100.80.1.2')]);
    await Future<void>.delayed(Duration.zero);
    expect(connects, 0);
    expect(client.closed, isTrue);
  });
  test(
    'all deployment proofs required; response fields cannot establish them',
    () {
      expect(const SessionAddressDeployment().verified, isFalse);
      expect(
        const SessionAddressDeployment(
          privateIngress: true,
          privateTransportEnforced: true,
          requesterIdentityOnEveryRequest: true,
          taggedPeerPolicyVerified: true,
          noPublicAlternateIngress: true,
          scopedSessionAuthorization: true,
        ).verified,
        isFalse,
      );
    },
  );
  test('each host verification item independently blocks admission', () {
    for (var omitted = 0; omitted < 7; omitted++) {
      final proof = SessionAddressDeployment(
        privateIngress: omitted != 0,
        privateTransportEnforced: omitted != 1,
        requesterIdentityOnEveryRequest: omitted != 2,
        taggedPeerPolicyVerified: omitted != 3,
        noPublicAlternateIngress: omitted != 4,
        scopedSessionAuthorization: omitted != 5,
        sessionIdsAreBearerCredentials: omitted == 6,
      );
      expect(
        proof.verified,
        isFalse,
        reason: 'missing verification item $omitted',
      );
    }
  });
}
