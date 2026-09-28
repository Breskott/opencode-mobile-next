// Golden renders of P6.7 (consent once, in flow): What runs by itself with
// its Your answers rows (one unanswered, the declined ones explaining
// themselves, one allowed), the phone server's first-start battery question,
// and the "Always allow" line on a third identical ask. Phone 412x915 and
// one wide window (1280x800), with the app's real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/p67_consent_golden_test.dart
// and look at every changed image before committing it.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/in_flow_consent.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/repeated_permission_consent.dart';
import 'package:opencode_mobile/ui/screens/automation_settings_screen.dart';
import 'package:opencode_mobile/ui/widgets/always_allow_invitation.dart';
import 'package:opencode_mobile/ui/widgets/phone_server_consents.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;
import '../support/complete_message_history.dart';

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

String _name(String shot, Size size, bool light) => [
  shot,
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

class _Api extends OpenCodeApi with CompleteMessageHistory {
  _Api() : super(baseUrl: 'http://localhost');

  @override
  Future<List<MessageWithParts>> messages(String id) async => [];

  @override
  Future<List<PermissionRequest>> pendingPermissions() async => const [];

  @override
  Future<List<PermissionRequest>> pendingPermissionsV2() =>
      Future.error(ApiException('V2 unavailable', statusCode: 404));
}

Future<ConnectionController> _controller({bool answers = true}) async {
  SharedPreferences.setMockInitialValues({
    'oc.profiles': jsonEncode([
      {
        'id': 'phone',
        'name': 'This phone',
        'baseUrl': 'http://192.168.1.20:4096',
        'username': '',
      },
    ]),
    'oc.activeProfile': 'phone',
    if (answers)
      'oc.inFlowConsent.phone': jsonEncode({
        'version': 1,
        'firstStart': true,
        'choices': {
          'batteryExemption': 'accepted',
          'makerAutoStart': 'denied',
          'needsYouNotifications': 'offered',
        },
      }),
  });
  final store = ProfileStore(prefs: await SharedPreferences.getInstance());
  await store.load();
  final controller = ConnectionController(store)
    ..api = _Api()
    ..status = StreamStatus.connected;
  if (answers) {
    final history = RepeatedPermissionConsent(store.prefs, profileId: 'phone');
    final scope = PermissionConsentScope(
      sessionID: 's',
      permission: 'bash',
      patterns: const ['npm test'],
    );
    for (final id in ['a', 'b', 'c']) {
      await history.observe(
        scope: scope,
        requestID: id,
        supportsPersistentGrants: true,
      );
    }
    await history.recordDecision(scope, accepted: false);
  }
  return controller;
}

Future<void> _shot(
  WidgetTester tester,
  String shot, {
  required bool light,
  required Widget Function(ConnectionController) home,
  bool answers = true,
  Size size = _phone,
  Future<void> Function(ConnectionController, BuildContext)? then,
  void Function(ConnectionController)? before,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  final controller = await _controller(answers: answers);
  addTearDown(controller.dispose);
  before?.call(controller);
  final boundary = GlobalKey();
  late BuildContext hostContext;
  try {
    await tester.pumpWidget(
      ProviderScope(
        child: RepaintBoundary(
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
              builder: (context) {
                hostContext = context;
                return home(controller);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (then != null) await then(controller, hostContext);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/${_name(shot, size, light)}.png'),
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('oc/lifecycle'),
      (call) async => call.method == 'keepAliveInfo'
          ? {'manufacturer': 'Xiaomi', 'batteryOptimizationIgnored': false}
          : null,
    );
  });

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    testWidgets('your answers · $mode', (tester) async {
      await _shot(
        tester,
        'p67_consent_answers',
        light: light,
        home: (c) => AutomationSettingsScreen(controller: c),
      );
    });
  }

  testWidgets('your answers wide · dark', (tester) async {
    await _shot(
      tester,
      'p67_consent_answers',
      light: false,
      size: _wide,
      home: (c) => AutomationSettingsScreen(controller: c),
    );
  });

  testWidgets('first start battery question · light', (tester) async {
    await _shot(
      tester,
      'p67_first_start_battery',
      light: true,
      answers: false,
      home: (c) => AutomationSettingsScreen(controller: c),
      then: (c, context) async {
        askConsent(context, InFlowConsentKind.batteryExemption).ignore();
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('first start battery question wide · dark', (tester) async {
    await _shot(
      tester,
      'p67_first_start_battery',
      light: false,
      answers: false,
      size: _wide,
      home: (c) => AutomationSettingsScreen(controller: c),
      then: (c, context) async {
        askConsent(context, InFlowConsentKind.batteryExemption).ignore();
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('always allow on the third ask · light', (tester) async {
    await _shot(
      tester,
      'p67_always_allow_invite',
      light: true,
      answers: false,
      home: (c) => Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final id in ['r1', 'r2', 'r3'])
                AlwaysAllowInvitation(
                  key: ValueKey(id),
                  controller: c,
                  sessionID: 'session-1',
                  requestID: id,
                ),
            ],
          ),
        ),
      ),
      before: (c) {
        for (final id in ['r1', 'r2', 'r3']) {
          c.handleEventForTesting(
            EventEnvelope(
              type: 'permission.asked',
              properties: {
                'id': id,
                'sessionID': 'session-1',
                'permission': 'bash',
                'patterns': ['flutter test test/cart_test.dart'],
                'metadata': <String, Object?>{},
                'always': ['flutter test *'],
              },
            ),
          );
        }
      },
      then: (c, context) async {
        await tester.pumpAndSettle();
      },
    );
  });
}
