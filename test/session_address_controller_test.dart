import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/session_address_controller.dart';
import 'package:opencode_mobile/state/session_link_bindings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const origin = 'https://device.tailnet.ts.net';
const instance = '9e30af6d-422d-4d89-baad-006ac07cb9d1';
const otherInstance = '9e30af6d-422d-4d89-baad-006ac07cb9d2';
const verified = SessionAddressDeployment(
  privateIngress: true,
  privateTransportEnforced: true,
  requesterIdentityOnEveryRequest: true,
  taggedPeerPolicyVerified: true,
  noPublicAlternateIngress: true,
  scopedSessionAuthorization: true,
  sessionIdsAreBearerCredentials: false,
);

SessionAddressDescriptor descriptor([String id = instance]) =>
    SessionAddressDescriptor.parse({
      'schemaVersion': 1,
      'canonicalOrigin': origin,
      'instanceId': id,
      'linkVersions': [2],
      'capabilities': {'sessionLookupById': true},
    });
String link([String id = 'ses_one']) => SessionAddressLink.build(
  origin: origin,
  instanceId: instance,
  sessionId: id,
  includeServerAddress: true,
).encode();

class _Reader implements SessionAddressDescriptorReader {
  int calls = 0;
  Future<SessionAddressDescriptor> Function()? action;
  @override
  Future<SessionAddressDescriptor> discover(String origin) async {
    calls++;
    return action == null ? descriptor() : await action!();
  }
}

class _Lookup implements SessionAddressLookupGateway {
  int calls = 0;
  @override
  SessionAddressDeployment deployment = verified;
  @override
  String origin = 'https://device.tailnet.ts.net';
  @override
  String instanceId = instance;
  Future<Session> Function(String)? action;
  @override
  Future<Session> lookupAuthorizedSession(String id) async {
    calls++;
    return action == null
        ? Session(id: id, directory: '/private/project')
        : await action!(id);
  }
}

class _BindingDisk extends InMemorySharedPreferencesStore {
  _BindingDisk(super.data) : super.withData();
  bool refuseBinding = false;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (refuseBinding && key.startsWith('flutter.oc.sessionLinkBinding.')) {
      return false;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late ProfileStore store;
  late _BindingDisk disk;
  late _Reader reader;
  late _Lookup lookup;
  late SessionAddressController controller;
  var credentialReads = 0;
  var gatewayBuilds = 0;
  setUp(() async {
    credentialReads = 0;
    gatewayBuilds = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        if (call.method == 'read') credentialReads++;
        return null;
      },
    );
    SharedPreferences.setMockInitialValues({
      'oc.profiles': jsonEncode([
        {'id': 'profile', 'name': 'Saved', 'baseUrl': origin, 'username': ''},
      ]),
    });
    disk = _BindingDisk(await SharedPreferencesStorePlatform.instance.getAll());
    SharedPreferencesStorePlatform.instance = disk;
    SharedPreferences.resetStatic();
    store = ProfileStore(prefs: await SharedPreferences.getInstance());
    await store.load();
    credentialReads = 0;
    reader = _Reader();
    lookup = _Lookup();
    controller = SessionAddressController.verifiedTestHarness(
      store: store,
      descriptors: reader,
      deploymentForOrigin: (_) => verified,
      lookupForProfile: (_) async {
        gatewayBuilds++;
        return lookup;
      },
    );
  });
  tearDown(() {
    controller.dispose();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });
  Future<void> ready() async {
    controller.receive(link());
    await controller.approveContact();
    expect(controller.phase, SessionAddressPhase.bindingRequired);
    await controller.approveBinding();
    expect(controller.phase, SessionAddressPhase.readyToOpen);
  }

  test('production capability and coordinator remain unavailable', () async {
    expect(const ServerCapabilities().sessionAddressHandoff, isFalse);
    expect(ServerCapabilities.allV1.sessionAddressHandoff, isFalse);
    final production = SessionAddressController(
      store: store,
      descriptors: reader,
      deploymentForOrigin: (_) => verified,
      lookupForProfile: (_) async {
        gatewayBuilds++;
        return lookup;
      },
    );
    addTearDown(production.dispose);
    production.receive(link());
    await production.approveContact();
    expect(production.failure, SessionAddressFailureCode.unavailable);
    expect(
      () => production.buildForProfile(
        'profile',
        'ses_one',
        includeServerAddress: true,
      ),
      throwsA(isA<SessionAddressFailure>()),
    );
    expect(reader.calls + gatewayBuilds + credentialReads, 0);
  });
  test('receive duplicate and cancel are silent even for saved host', () {
    var changes = 0;
    controller.addListener(() => changes++);
    controller.receive(link());
    final before = changes;
    controller.receive(link());
    expect(changes, before);
    controller.cancel();
    expect(controller.pending, isNull);
    expect(reader.calls + gatewayBuilds + credentialReads, 0);
  });
  test('binding requires approval before any authenticated lookup', () async {
    controller.receive(link());
    await controller.approveContact();
    await controller.open();
    expect(controller.phase, SessionAddressPhase.bindingRequired);
    expect(gatewayBuilds + credentialReads, 0);
    await controller.approveBinding();
    await controller.open();
    expect(controller.openedSession?.id, 'ses_one');
    expect(gatewayBuilds, 1);
    expect(lookup.calls, 1);
    expect(reader.calls, 2);
    expect(store.profiles, hasLength(1));
  });
  test(
    'unknown host retains locator through own Add server and sign-in',
    () async {
      await store.prefs.setString('oc.profiles', '[]');
      await store.load();
      controller.receive(link());
      await controller.approveContact();
      expect(controller.phase, SessionAddressPhase.addServer);
      expect(gatewayBuilds, 0);
      await store.upsert(
        ServerProfile(id: 'new', name: 'Own server', baseUrl: origin),
      );
      controller.selectProfile('new');
      await controller.approveBinding();
      await controller.open();
      expect(controller.phase, SessionAddressPhase.opened);
      expect(controller.profileId, 'new');
    },
  );
  test(
    'multiple origin matches require choice and mismatch never reuses secrets',
    () async {
      await store.upsert(
        ServerProfile(id: 'second', name: 'Saved', baseUrl: origin),
      );
      await SessionLinkBindings.forProfile(store.prefs, 'second').save(
        SessionLinkBinding(
          origin: origin,
          instanceId: otherInstance,
          verifiedAt: DateTime.now(),
        ),
      );
      controller.receive(link());
      await controller.approveContact();
      expect(controller.phase, SessionAddressPhase.chooseProfile);
      controller.selectProfile('second');
      expect(controller.failure, SessionAddressFailureCode.instanceMismatch);
      expect(gatewayBuilds + credentialReads, 0);
    },
  );
  test(
    'replacement instance rejected at discovery and again before credential lookup',
    () async {
      reader.action = () async => descriptor(otherInstance);
      controller.receive(link());
      await controller.approveContact();
      expect(controller.failure, SessionAddressFailureCode.instanceMismatch);
      controller.cancel();
      reader.action = null;
      await ready();
      reader.action = () async => descriptor(otherInstance);
      await controller.open();
      expect(controller.failure, SessionAddressFailureCode.instanceMismatch);
      expect(gatewayBuilds, 0);
    },
  );
  test('bearer ID and unverified gateways are never queried', () async {
    await ready();
    lookup.deployment = const SessionAddressDeployment();
    await controller.open();
    expect(controller.failure, SessionAddressFailureCode.unsafeLookup);
    expect(lookup.calls, 0);
  });
  for (final code in [
    SessionAddressFailureCode.sessionMissing,
    SessionAddressFailureCode.accessDenied,
    SessionAddressFailureCode.signInRequired,
  ]) {
    test('$code leaves profile saved and performs only one read', () async {
      await ready();
      lookup.action = (_) async => throw SessionAddressFailure(code);
      await controller.open();
      expect(controller.failure, code);
      expect(lookup.calls, 1);
      expect(store.profiles.single.id, 'profile');
    });
  }
  test('newer intent wins over late descriptor and lookup results', () async {
    final delayed = Completer<SessionAddressDescriptor>();
    reader.action = () => delayed.future;
    controller.receive(link());
    final checking = controller.approveContact();
    controller.receive(link('ses_new'));
    delayed.complete(descriptor());
    await checking;
    expect(controller.pending?.sessionId, 'ses_new');
    expect(controller.phase, SessionAddressPhase.awaitingConsent);
    reader.action = null;
    controller.cancel();
    await ready();
    final answer = Completer<Session>();
    lookup.action = (_) => answer.future;
    final opening = controller.open();
    while (lookup.calls == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    controller.receive(link('ses_newer'));
    answer.complete(Session(id: 'ses_one'));
    await opening;
    expect(controller.pending?.sessionId, 'ses_newer');
    expect(controller.openedSession, isNull);
  });
  test(
    'real deletion invalidates pending and sweeps binding; no late open',
    () async {
      await ready();
      final connection = ConnectionController(store);
      addTearDown(connection.dispose);
      final result = await connection.deleteProfileAndLocalData('profile');
      expect(result.removedProfile, isTrue);
      expect(controller.pending, isNull);
      expect(store.prefs.containsKey('oc.sessionLinkBinding.profile'), isFalse);
      await controller.open();
      expect(gatewayBuilds, 0);
    },
  );
  test(
    'deletion before contact consent invalidates known-host pending route',
    () async {
      controller.receive(link());
      final connection = ConnectionController(store);
      addTearDown(connection.dispose);
      await connection.deleteProfileAndLocalData('profile');
      expect(controller.pending, isNull);
      expect(reader.calls, 0);
    },
  );
  test(
    'sender requires disclosure and current binding, emits only three fields',
    () async {
      await ready();
      expect(
        () => controller.buildForProfile(
          'profile',
          'ses_one',
          includeServerAddress: false,
        ),
        throwsA(
          isA<SessionAddressFailure>().having(
            (e) => e.code,
            'code',
            SessionAddressFailureCode.consentRequired,
          ),
        ),
      );
      final encoded = controller.buildForProfile(
        'profile',
        'ses_one',
        includeServerAddress: true,
      );
      expect(Uri.parse(encoded).queryParameters.keys.toSet(), {
        'server',
        'instance',
        'session',
      });
      expect(encoded.contains('profile'), isFalse);
      store.profiles.single.baseUrl = 'https://replacement.tailnet.ts.net';
      expect(
        () => controller.buildForProfile(
          'profile',
          'ses_one',
          includeServerAddress: true,
        ),
        throwsA(isA<SessionAddressFailure>()),
      );
    },
  );
  test(
    'unverified deployment makes zero discovery or credential calls',
    () async {
      final denied = SessionAddressController.verifiedTestHarness(
        store: store,
        descriptors: reader,
        deploymentForOrigin: (_) => const SessionAddressDeployment(),
        lookupForProfile: (_) async {
          gatewayBuilds++;
          return lookup;
        },
      );
      addTearDown(denied.dispose);
      denied.receive(link());
      await denied.approveContact();
      expect(denied.failure, SessionAddressFailureCode.unsafeLookup);
      expect(reader.calls + gatewayBuilds + credentialReads, 0);
    },
  );
  test(
    'explicit retry is bounded and cancellation defeats a late lookup',
    () async {
      reader.action = () async =>
          throw const SessionAddressFailure(SessionAddressFailureCode.timedOut);
      controller.receive(link());
      await controller.approveContact();
      expect(controller.failure, SessionAddressFailureCode.timedOut);
      expect(reader.calls, 1);
      reader.action = null;
      await controller.checkAgain();
      await controller.approveBinding();
      final result = Completer<Session>();
      lookup.action = (_) => result.future;
      final opening = controller.open();
      while (lookup.calls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      controller.cancel();
      result.complete(Session(id: 'ses_one'));
      await opening;
      expect(controller.phase, SessionAddressPhase.idle);
      expect(controller.pending, isNull);
      await controller.checkAgain();
      expect(reader.calls, 3);
    },
  );
  test(
    'real deletion during lookup consumes locator and ignores late result',
    () async {
      await ready();
      final result = Completer<Session>();
      lookup.action = (_) => result.future;
      final opening = controller.open();
      while (lookup.calls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final connection = ConnectionController(store);
      addTearDown(connection.dispose);
      await connection.deleteProfileAndLocalData('profile');
      result.complete(Session(id: 'ses_one'));
      await opening;
      expect(controller.phase, SessionAddressPhase.idle);
      expect(controller.openedSession, isNull);
    },
  );
  test(
    'wrong resolved session is refused without searching or creating',
    () async {
      await ready();
      lookup.action = (_) async => Session(id: 'ses_wrong');
      await controller.open();
      expect(controller.failure, SessionAddressFailureCode.sessionMissing);
      expect(lookup.calls, 1);
    },
  );
  test(
    'failed binding write reports storage without silently dismissing',
    () async {
      controller.receive(link());
      await controller.approveContact();
      disk.refuseBinding = true;
      await controller.approveBinding();
      expect(controller.phase, SessionAddressPhase.failed);
      expect(controller.failure, SessionAddressFailureCode.storage);
      expect(controller.pending, isNotNull);
      expect(gatewayBuilds, 0);
    },
  );
}
