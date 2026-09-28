// Golden renders of slice-sessionlink-ui (P3.9 UI): Open on another phone
// with the per-link "Include this server's address" switch (off, on, and
// refused), and the incoming-link sheet's states (not available yet,
// rejected credential-bearing link, asking, unknown server, verify, sign-in
// needed, ready, not found). Phone 412x915 dark and light, plus the wide
// window (1280x800) for the switch and the asking state, with the app's real
// fonts at DPR 1. The backend is the verified test harness; production keeps
// both gates closed.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/sessionlink_ui_golden_test.dart
// and look at every changed image before committing it.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/domain/session_handoff.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/session_address_controller.dart';
import 'package:opencode_mobile/state/session_link_bindings.dart';
import 'package:opencode_mobile/ui/widgets/session_address_sheets.dart';
import 'package:opencode_mobile/ui/widgets/session_handoff_sheets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;

const _phone = Size(412, 915);
const _wide = Size(1280, 800);
const _origin = 'https://workstation.example-tailnet.ts.net';
const _instance = '9e30af6d-422d-4d89-baad-006ac07cb9d1';
const _verified = SessionAddressDeployment(
  privateIngress: true,
  privateTransportEnforced: true,
  requesterIdentityOnEveryRequest: true,
  taggedPeerPolicyVerified: true,
  noPublicAlternateIngress: true,
  scopedSessionAuthorization: true,
  sessionIdsAreBearerCredentials: false,
);

String _wire([String server = _origin]) =>
    'opencode-mobile://session/v2?server=${Uri.encodeQueryComponent(server)}'
    '&instance=$_instance&session=ses_0123456789abcdef';

class _Reader implements SessionAddressDescriptorReader {
  @override
  Future<SessionAddressDescriptor> discover(String origin) async =>
      SessionAddressDescriptor.parse({
        'schemaVersion': 1,
        'canonicalOrigin': origin,
        'instanceId': _instance,
        'linkVersions': [2],
        'capabilities': {'sessionLookupById': true},
      });
}

class _Lookup implements SessionAddressLookupGateway {
  bool missing = false;
  @override
  SessionAddressDeployment get deployment => _verified;
  @override
  String get origin => _origin;
  @override
  String get instanceId => _instance;
  @override
  Future<Session> lookupAuthorizedSession(String id) async {
    if (missing) {
      throw const SessionAddressFailure(
        SessionAddressFailureCode.sessionMissing,
      );
    }
    return Session(id: id);
  }
}

String _name(String shot, Size size, bool light) => [
  shot,
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  Future<ProfileStore> store({bool saved = true, bool bound = true}) async {
    SharedPreferences.setMockInitialValues({
      'oc.profiles': jsonEncode([
        if (saved)
          {
            'id': 'saved',
            'name': 'Workstation',
            'baseUrl': _origin,
            'username': '',
          },
      ]),
    });
    final store = ProfileStore(prefs: await SharedPreferences.getInstance());
    await store.load();
    if (saved && bound) {
      await SessionLinkBindings.forProfile(store.prefs, 'saved').save(
        SessionLinkBinding(
          origin: _origin,
          instanceId: _instance,
          verifiedAt: DateTime.utc(2026, 9, 28),
        ),
      );
    }
    return store;
  }

  SessionAddressController harness(ProfileStore store, [_Lookup? lookup]) {
    final controller = SessionAddressController.verifiedTestHarness(
      store: store,
      descriptors: _Reader(),
      deploymentForOrigin: (_) => _verified,
      lookupForProfile: (_) async => lookup ?? _Lookup(),
    );
    addTearDown(controller.dispose);
    return controller;
  }

  Future<void> shot(
    WidgetTester tester,
    String name, {
    required bool light,
    required Future<void> Function(BuildContext context) open,
    Size size = _phone,
    Future<void> Function()? then,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    debugDefaultTargetPlatformOverride = TargetPlatform.android; // ARCH-11
    try {
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: captureTheme(light: light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => open(context),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      if (then != null) {
        await then();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/${_name(name, size, light)}.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox.shrink());
    }
  }

  final local = SessionLink.tryCreate(
    profileID: '1757500000000000',
    sessionID: 'ses_0123456789abcdef',
  );

  Future<SessionAddressOffer> offer({bool bound = true}) async {
    final s = await store(bound: bound);
    return SessionAddressOffer.forSession(
      capabilities: const ServerCapabilities(sessionAddressHandoff: true),
      addresses: harness(s),
      profile: s.profiles.single,
      sessionID: 'ses_0123456789abcdef',
    )!;
  }

  Future<void> Function(BuildContext) receive(
    SessionAddressController controller, {
    SessionAddressFailureCode? failure,
  }) =>
      (context) => showSessionAddressSheet(
        context,
        controller: controller,
        failure: failure,
        onAddServer: (_) async {},
        onSignIn: (_) async {},
      );

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final size in [_phone, _wide]) {
      testWidgets('phone sheet address off ${size.width.toInt()} · $mode', (
        tester,
      ) async {
        final address = await offer();
        await shot(
          tester,
          'sessionlink_send_address_off',
          light: light,
          size: size,
          open: (context) =>
              showContinueOnPhoneSheet(context, link: local, address: address),
        );
      });

      testWidgets('phone sheet address on ${size.width.toInt()} · $mode', (
        tester,
      ) async {
        final address = await offer();
        await shot(
          tester,
          'sessionlink_send_address_on',
          light: light,
          size: size,
          open: (context) =>
              showContinueOnPhoneSheet(context, link: local, address: address),
          then: () async {
            await tester.tap(find.text('Include this server’s address'));
            await tester.pumpAndSettle();
          },
        );
      });

      testWidgets('receive asking ${size.width.toInt()} · $mode', (
        tester,
      ) async {
        final controller = harness(await store(saved: false));
        controller.receive(_wire());
        await shot(
          tester,
          'sessionlink_receive_asking',
          light: light,
          size: size,
          open: receive(controller),
        );
      });
    }

    testWidgets('phone sheet address refused · $mode', (tester) async {
      final address = await offer(bound: false);
      await shot(
        tester,
        'sessionlink_send_address_unverified',
        light: light,
        open: (context) =>
            showContinueOnPhoneSheet(context, link: local, address: address),
        then: () async {
          await tester.tap(find.text('Include this server’s address'));
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('receive not available yet · $mode', (tester) async {
      final s = await store();
      final production = SessionAddressController(
        store: s,
        descriptors: _Reader(),
        deploymentForOrigin: (_) => _verified,
        lookupForProfile: (_) async => null,
      );
      addTearDown(production.dispose);
      production.receive(_wire());
      await shot(
        tester,
        'sessionlink_receive_unavailable',
        light: light,
        open: receive(production),
      );
    });

    testWidgets('receive credential-bearing link · $mode', (tester) async {
      final controller = harness(await store());
      controller.receive(
        _wire('https://me:hunter2@workstation.example-tailnet.ts.net'),
      );
      await shot(
        tester,
        'sessionlink_receive_credentials',
        light: light,
        open: receive(controller),
      );
    });

    testWidgets('receive unknown server · $mode', (tester) async {
      final controller = harness(await store(saved: false));
      controller.receive(_wire());
      await shot(
        tester,
        'sessionlink_receive_unknown_server',
        light: light,
        open: receive(controller),
        then: () => tap(tester, 'session-address-check'),
      );
    });

    testWidgets('receive verify saved server · $mode', (tester) async {
      final controller = harness(await store(bound: false));
      controller.receive(_wire());
      await shot(
        tester,
        'sessionlink_receive_verify',
        light: light,
        open: receive(controller),
        then: () => tap(tester, 'session-address-check'),
      );
    });

    testWidgets('receive matched and ready · $mode', (tester) async {
      final controller = harness(await store());
      controller.receive(_wire());
      await shot(
        tester,
        'sessionlink_receive_ready',
        light: light,
        open: receive(controller),
        then: () => tap(tester, 'session-address-check'),
      );
    });

    testWidgets('receive needs sign-in · $mode', (tester) async {
      final s = await store();
      s.profiles.single.requiresPasswordReentry = true;
      final controller = harness(s);
      controller.receive(_wire());
      await shot(
        tester,
        'sessionlink_receive_sign_in',
        light: light,
        open: receive(controller),
        then: () => tap(tester, 'session-address-check'),
      );
    });

    testWidgets('receive not found · $mode', (tester) async {
      final controller = harness(await store(), _Lookup()..missing = true);
      controller.receive(_wire());
      await shot(
        tester,
        'sessionlink_receive_not_found',
        light: light,
        open: receive(controller),
        then: () async {
          await tap(tester, 'session-address-check');
          await tap(tester, 'session-address-open');
          await tap(tester, 'session-address-details');
        },
      );
    });
  }
}
