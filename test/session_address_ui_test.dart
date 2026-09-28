// Session links that can carry the server's address (P3.9), the UI half:
// the per-link opt-in on Open on another phone and the incoming-link sheet.
// The backend is the verified test harness; production stays closed and is
// proved to hide the option and to say plainly that the link type is not
// available yet. Fakes only, no network.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/domain/session_handoff.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/session_address_controller.dart';
import 'package:opencode_mobile/state/session_link_bindings.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_qr.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:opencode_mobile/ui/widgets/session_address_sheets.dart';
import 'package:opencode_mobile/ui/widgets/session_handoff_sheets.dart';
import 'package:shared_preferences/shared_preferences.dart';

const origin = 'https://device.tailnet.ts.net';
const instance = '9e30af6d-422d-4d89-baad-006ac07cb9d1';
const verified = SessionAddressDeployment(
  privateIngress: true,
  privateTransportEnforced: true,
  requesterIdentityOnEveryRequest: true,
  taggedPeerPolicyVerified: true,
  noPublicAlternateIngress: true,
  scopedSessionAuthorization: true,
  sessionIdsAreBearerCredentials: false,
);
const on = ServerCapabilities(sessionAddressHandoff: true);

String wire([String session = 'ses_one', String server = origin]) =>
    'opencode-mobile://session/v2?server=${Uri.encodeQueryComponent(server)}'
    '&instance=$instance&session=$session';

class _Reader implements SessionAddressDescriptorReader {
  int calls = 0;
  SessionAddressFailureCode? fail;
  @override
  Future<SessionAddressDescriptor> discover(String origin) async {
    calls++;
    if (fail case final code?) throw SessionAddressFailure(code);
    return SessionAddressDescriptor.parse({
      'schemaVersion': 1,
      'canonicalOrigin': origin,
      'instanceId': instance,
      'linkVersions': [2],
      'capabilities': {'sessionLookupById': true},
    });
  }
}

class _Lookup implements SessionAddressLookupGateway {
  int calls = 0;
  SessionAddressFailureCode? fail;
  @override
  SessionAddressDeployment get deployment => verified;
  @override
  String get origin => 'https://device.tailnet.ts.net';
  @override
  String get instanceId => instance;
  @override
  Future<Session> lookupAuthorizedSession(String id) async {
    calls++;
    if (fail case final code?) throw SessionAddressFailure(code);
    return Session(id: id, directory: '/private/project');
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late ProfileStore store;
  late _Reader reader;
  late _Lookup lookup;
  final clipboard = <String>[];

  Future<void> useProfiles(List<Map<String, Object?>> profiles) async {
    SharedPreferences.setMockInitialValues({
      'oc.profiles': jsonEncode(profiles),
    });
    store = ProfileStore(prefs: await SharedPreferences.getInstance());
    await store.load();
  }

  SessionAddressController harness() {
    final controller = SessionAddressController.verifiedTestHarness(
      store: store,
      descriptors: reader,
      deploymentForOrigin: (_) => verified,
      lookupForProfile: (_) async => lookup,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  SessionAddressController production() {
    final controller = SessionAddressController(
      store: store,
      descriptors: reader,
      deploymentForOrigin: (_) => verified,
      lookupForProfile: (_) async => lookup,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  setUp(() async {
    clipboard.clear();
    KitRedact.clearKnownSecrets();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    reader = _Reader();
    lookup = _Lookup();
    await useProfiles([
      {'id': 'saved', 'name': 'Workstation', 'baseUrl': origin, 'username': ''},
    ]);
  });
  tearDown(() {
    KitRedact.clearKnownSecrets();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  Future<void> bind(String id) =>
      SessionLinkBindings.forProfile(store.prefs, id).save(
        SessionLinkBinding(
          origin: origin,
          instanceId: instance,
          verifiedAt: DateTime.utc(2026, 9, 28),
        ),
      );

  Future<void> host(
    WidgetTester tester,
    Future<void> Function(BuildContext context) open,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  final local = SessionLink.tryCreate(
    profileID: 'saved',
    sessionID: 'ses_one',
  )!;

  String qrData(WidgetTester tester, Key key) => tester
      .widget<KitQr>(
        find.ancestor(of: find.byKey(key), matching: find.byType(KitQr)),
      )
      .data;

  group('sender: Include this server’s address', () {
    test('the option exists only when both gates are open', () async {
      final profile = store.profiles.single;
      // The capability defaults off on every adapter.
      expect(
        SessionAddressOffer.forSession(
          capabilities: const ServerCapabilities(),
          addresses: harness(),
          profile: profile,
          sessionID: 'ses_one',
        ),
        isNull,
      );
      // The production coordinator refuses generation even with it on.
      expect(
        SessionAddressOffer.forSession(
          capabilities: on,
          addresses: production(),
          profile: profile,
          sessionID: 'ses_one',
        ),
        isNull,
      );
      final offer = SessionAddressOffer.forSession(
        capabilities: on,
        addresses: harness(),
        profile: profile,
        sessionID: 'ses_one',
      )!;
      // The effective port is spelled out even though the origin omits 443.
      expect(offer.hostPort, 'device.tailnet.ts.net:443');
    });

    testWidgets('hidden option: the local link sheet is unchanged', (
      tester,
    ) async {
      await host(
        tester,
        (context) => showContinueOnPhoneSheet(context, link: local),
      );
      expect(find.byKey(const Key('session-address-include')), findsNothing);
      expect(find.text('Include this server’s address'), findsNothing);
      expect(qrData(tester, const Key('session-link-qr')), local.toString());
      expect(
        find.byKey(const Key('continue-on-phone-server-note')),
        findsOneWidget,
      );
    });

    testWidgets(
      'off by default each time; the address goes in only after the opt-in',
      (tester) async {
        await bind('saved');
        final addresses = harness();
        final requested = <bool>[];
        final real = SessionAddressOffer.forSession(
          capabilities: on,
          addresses: addresses,
          profile: store.profiles.single,
          sessionID: 'ses_one',
        )!;
        final offer = SessionAddressOffer(
          hostPort: real.hostPort,
          build: ({required includeServerAddress}) {
            requested.add(includeServerAddress);
            return real.build(includeServerAddress: includeServerAddress);
          },
        );
        await host(
          tester,
          (context) =>
              showContinueOnPhoneSheet(context, link: local, address: offer),
        );

        // Off: the local link only, no build, no address anywhere.
        expect(find.text('Include this server’s address'), findsOneWidget);
        expect(find.text('device.tailnet.ts.net:443'), findsOneWidget);
        expect(
          find.byKey(const Key('session-address-disclosure')),
          findsOneWidget,
        );
        expect(requested, isEmpty);
        expect(qrData(tester, const Key('session-link-qr')), local.toString());
        expect(find.byKey(const Key('session-address-qr')), findsNothing);
        await tester.ensureVisible(
          find.byKey(const Key('continue-on-phone-copy')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('continue-on-phone-copy')));
        await tester.pumpAndSettle();
        expect(clipboard.single, local.toString());
        expect(clipboard.single, isNot(contains('ts.net')));

        // On: the portable link, built with the switch's own consent.
        await tester.ensureVisible(find.text('Include this server’s address'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Include this server’s address'));
        await tester.pumpAndSettle();
        expect(requested, [true]);
        final portable = qrData(tester, const Key('session-address-qr'));
        expect(SessionAddressLink.require(portable).origin, origin);
        expect(SessionAddressLink.require(portable).sessionId, 'ses_one');
        expect(find.byKey(const Key('session-link-qr')), findsNothing);
        // Copy builds again rather than reusing the shown string.
        await tester.ensureVisible(
          find.byKey(const Key('session-address-copy')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('session-address-copy')));
        await tester.pumpAndSettle();
        expect(requested, [true, true]);
        expect(clipboard.last, portable);

        // Off again: back to the local link, the address is gone.
        await tester.ensureVisible(find.text('Include this server’s address'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Include this server’s address'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('session-address-qr')), findsNothing);
        expect(qrData(tester, const Key('session-link-qr')), local.toString());

        // Reopened: off again.
        Navigator.of(tester.element(find.byType(KitQr))).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('session-address-qr')), findsNothing);
        expect(requested, [true, true]);

        // The low-level refusal without consent, for the record.
        expect(
          () => offer.build(includeServerAddress: false),
          throwsA(
            isA<SessionAddressFailure>().having(
              (f) => f.code,
              'code',
              SessionAddressFailureCode.consentRequired,
            ),
          ),
        );
      },
    );

    testWidgets('a secret in the link is refused, never stripped', (
      tester,
    ) async {
      await bind('saved');
      const secretSession = 'ses_hunter2secret';
      final offer = SessionAddressOffer.forSession(
        capabilities: on,
        addresses: harness(),
        profile: store.profiles.single,
        sessionID: secretSession,
      )!;
      // Registered after the sheet could have been built once.
      KitRedact.registerKnownSecret(secretSession);
      await host(
        tester,
        (context) => showContinueOnPhoneSheet(
          context,
          link: SessionLink.tryCreate(profileID: 'saved', sessionID: 'ses_x'),
          address: offer,
        ),
      );
      await tester.ensureVisible(find.text('Include this server’s address'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Include this server’s address'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'This link contains private sign-in information and cannot be used.',
        ),
        findsOneWidget,
      );
      // No code at all, neither a stripped portable one nor the local one.
      expect(find.byType(KitQr), findsNothing);
      expect(find.textContaining(secretSession), findsNothing);
      expect(clipboard, isEmpty);
    });

    testWidgets('an address with a password or no private name cannot go in', (
      tester,
    ) async {
      for (final baseUrl in [
        'https://me:hunter2@device.tailnet.ts.net',
        'http://100.64.1.2:4096',
      ]) {
        await useProfiles([
          {'id': 'p', 'name': 'P', 'baseUrl': baseUrl, 'username': ''},
        ]);
        final offer = SessionAddressOffer.forSession(
          capabilities: on,
          addresses: harness(),
          profile: store.profiles.single,
          sessionID: 'ses_one',
        )!;
        expect(offer.hostPort, isNull);
        await host(
          tester,
          (context) =>
              showContinueOnPhoneSheet(context, link: local, address: offer),
        );
        expect(
          find.text(
            'Only a private HTTPS address ending in .ts.net can go in a link.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('hunter2'), findsNothing);
        await tester.ensureVisible(find.text('Include this server’s address'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Include this server’s address'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('session-address-qr')), findsNothing);
        expect(qrData(tester, const Key('session-link-qr')), local.toString());
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });

  group('receiver: opening a link with an address', () {
    Future<SessionAddressOpened?> Function(BuildContext) sheet(
      SessionAddressController controller, {
      SessionAddressFailureCode? failure,
      List<String>? added,
      List<String>? signIns,
      void Function(SessionAddressOpened?)? done,
    }) => (context) async {
      final result = await showSessionAddressSheet(
        context,
        controller: controller,
        failure: failure,
        onAddServer: (origin) async {
          added?.add(origin);
          await store.upsert(
            ServerProfile(id: 'new', name: 'Added', baseUrl: origin),
          );
        },
        onSignIn: (id) async => signIns?.add(id),
      );
      done?.call(result);
      return result;
    };

    testWidgets('production says plainly the link type is not available', (
      tester,
    ) async {
      final addresses = production();
      addresses.receive(wire());
      await host(tester, sheet(addresses));
      expect(
        find.text(
          'Conversation links with a server address are not available yet.',
        ),
        findsOneWidget,
      );
      // Nothing to approve and nothing contacted.
      expect(find.byKey(const Key('session-address-check')), findsNothing);
      expect(
        find.byKey(const Key('session-address-check-again')),
        findsNothing,
      );
      expect(reader.calls, 0);
      // Details hold the category only.
      await tester.tap(find.byKey(const Key('session-address-details')));
      await tester.pumpAndSettle();
      expect(find.text('unavailable'), findsOneWidget);
      expect(find.textContaining('ts.net'), findsNothing);
      expect(find.textContaining('ses_one'), findsNothing);
    });

    testWidgets('a credential-bearing link is rejected, not stripped', (
      tester,
    ) async {
      final addresses = harness();
      addresses.receive(
        wire('ses_one', 'https://me:hunter2@device.tailnet.ts.net'),
      );
      expect(addresses.phase, SessionAddressPhase.failed);
      expect(addresses.failure, SessionAddressFailureCode.credentials);
      // Nothing was kept to open without the password.
      expect(addresses.pending, isNull);
      await host(tester, sheet(addresses));
      expect(
        find.text(
          'This link contains private sign-in information and cannot be used.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('hunter2'), findsNothing);
      expect(find.textContaining('device.tailnet'), findsNothing);
      expect(find.byKey(const Key('session-address-check')), findsNothing);
      expect(reader.calls, 0);
    });

    testWidgets('a link that failed to parse shows its category only', (
      tester,
    ) async {
      await host(
        tester,
        sheet(harness(), failure: SessionAddressFailureCode.tooLarge),
      );
      expect(
        find.text('This link is too long. Ask the sender for a new link.'),
        findsOneWidget,
      );
      expect(reader.calls, 0);
    });

    testWidgets('unknown server: ask, check, offer Add server, never connect', (
      tester,
    ) async {
      await useProfiles(const []);
      final addresses = harness();
      final added = <String>[];
      SessionAddressOpened? result;
      addresses.receive(wire());
      await host(
        tester,
        sheet(addresses, added: added, done: (r) => result = r),
      );

      // Asking: the actual host and port, no contact yet.
      expect(find.text('Add this server?'), findsOneWidget);
      expect(find.text('device.tailnet.ts.net:443'), findsOneWidget);
      expect(find.text('Not saved on this phone'), findsOneWidget);
      expect(reader.calls, 0);

      await tester.tap(find.byKey(const Key('session-address-check')));
      await tester.pumpAndSettle();
      expect(reader.calls, 1);
      expect(addresses.phase, SessionAddressPhase.addServer);
      expect(
        find.textContaining('This server is not saved on this phone.'),
        findsOneWidget,
      );
      expect(lookup.calls, 0);

      // Add server gets the validated address only; the added server still
      // has to be verified and opened by hand.
      await tester.tap(find.byKey(const Key('session-address-add')));
      await tester.pumpAndSettle();
      expect(added, [origin]);
      expect(addresses.phase, SessionAddressPhase.bindingRequired);
      expect(find.textContaining('Confirm that Added'), findsOneWidget);
      expect(lookup.calls, 0);

      await tester.tap(find.byKey(const Key('session-address-verify')));
      await tester.pumpAndSettle();
      expect(find.text('Added matches this link.'), findsOneWidget);
      expect(lookup.calls, 0);

      await tester.tap(find.byKey(const Key('session-address-open')));
      await tester.pumpAndSettle();
      expect(lookup.calls, 1);
      expect(result?.profileId, 'new');
      expect(result?.sessionId, 'ses_one');
      // Consumed once opened.
      expect(addresses.pending, isNull);
      expect(find.byKey(const Key('session-address-body')), findsNothing);
    });

    testWidgets('saved server: asks to open on it, then needs sign-in', (
      tester,
    ) async {
      await bind('saved');
      store.profiles.single.requiresPasswordReentry = true;
      final addresses = harness();
      final signIns = <String>[];
      addresses.receive(wire());
      await host(tester, sheet(addresses, signIns: signIns));
      expect(find.text('Open on this saved server?'), findsOneWidget);
      expect(find.text('Workstation'), findsOneWidget);

      await tester.tap(find.byKey(const Key('session-address-check')));
      await tester.pumpAndSettle();
      expect(addresses.phase, SessionAddressPhase.readyToOpen);
      expect(
        find.text(
          'Sign in to Workstation with your own account first, then open the conversation.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('session-address-open')), findsNothing);
      await tester.tap(find.byKey(const Key('session-address-sign-in-action')));
      await tester.pumpAndSettle();
      expect(signIns, ['saved']);
      expect(lookup.calls, 0);

      // Signed in: Open appears.
      store.profiles.single.requiresPasswordReentry = false;
      await tester.tap(find.byKey(const Key('session-address-sign-in-action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('session-address-open')), findsOneWidget);
    });

    testWidgets('not found: plain words, the saved server stays', (
      tester,
    ) async {
      await bind('saved');
      lookup.fail = SessionAddressFailureCode.sessionMissing;
      final addresses = harness();
      addresses.receive(wire());
      await host(tester, sheet(addresses));
      await tester.tap(find.byKey(const Key('session-address-check')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('session-address-open')));
      await tester.pumpAndSettle();
      expect(
        find.text('This conversation is not available on this server.'),
        findsOneWidget,
      );
      expect(store.profiles.single.id, 'saved');
      expect(
        find.byKey(const Key('session-address-check-again')),
        findsNothing,
      );
    });

    testWidgets('a timeout offers one explicit Check again', (tester) async {
      reader.fail = SessionAddressFailureCode.timedOut;
      final addresses = harness();
      addresses.receive(wire());
      await host(tester, sheet(addresses));
      await tester.tap(find.byKey(const Key('session-address-check')));
      await tester.pumpAndSettle();
      expect(
        find.text('The server did not answer in time. Try again.'),
        findsOneWidget,
      );
      expect(reader.calls, 1);
      reader.fail = null;
      await tester.tap(find.byKey(const Key('session-address-check-again')));
      await tester.pumpAndSettle();
      expect(reader.calls, 2);
      expect(addresses.phase, SessionAddressPhase.bindingRequired);
    });

    testWidgets('closing the sheet consumes the link without contact', (
      tester,
    ) async {
      final addresses = harness();
      addresses.receive(wire());
      await host(tester, sheet(addresses));
      expect(addresses.pending, isNotNull);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(addresses.pending, isNull);
      expect(addresses.phase, SessionAddressPhase.idle);
      expect(reader.calls, 0);
    });
  });
}
