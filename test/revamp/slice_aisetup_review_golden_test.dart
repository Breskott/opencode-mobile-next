// Golden renders of slice-aisetup-review: the AI setup page, review only
// (owner decision 2026-09-28), in every state it has. Phone 412x915 and one
// wide window (1280x800) for the two loaded forms, dark and light, with the
// app's real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/slice_aisetup_review_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/domain/setup_assistant.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/setup_session.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:opencode_mobile/ui/screens/settings/ai_setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;

class _Store extends ProfileStore {
  _Store({required super.prefs});

  final _profile = ServerProfile(
    id: 'laptop',
    name: 'Laptop',
    baseUrl: 'http://192.168.1.20:4096',
  );

  @override
  List<ServerProfile> get profiles => [_profile];

  @override
  String? get activeId => _profile.id;
}

class _Gateway implements SetupConfigGateway {
  _Gateway({
    this.config = const {},
    this.servers = const [],
    this.failure,
    this.hold = false,
  });
  final Map<String, Object?> config;
  final List<SetupMcpStatus> servers;
  final SetupFailure? failure;
  final bool hold;

  @override
  SetupSupport get support =>
      const SetupSupport(readConfig: true, mcpInventory: true);

  @override
  Future<Map<String, Object?>> readConfig() async {
    if (hold) await Completer<void>().future;
    if (failure != null) throw failure!;
    return config;
  }

  @override
  Future<void> patchConfig(Map<String, Object?> patch) =>
      throw UnimplementedError('review only');

  @override
  Future<List<SetupMcpStatus>> listMcpServers() async => servers;
}

const _oc1 = {
  'model': 'anthropic/claude-sonnet-4',
  'small_model': 'anthropic/claude-haiku-4',
  'default_agent': 'build',
  'provider': {
    'anthropic': {
      'options': {'apiKey': 'sk-ant-api03-GOLDENFIXTURE000000000000'},
    },
    'openai': <String, Object?>{},
  },
  'permission': {'bash': 'ask', 'edit': 'allow', 'webfetch': 'deny'},
  'mcp': {
    'github': {'type': 'remote', 'url': 'https://mcp.example.com/github'},
  },
};

const _servers = [
  SetupMcpStatus(name: 'docs', status: 'connected'),
  SetupMcpStatus(name: 'browser', status: 'connected'),
  SetupMcpStatus(name: 'archive', status: 'disabled'),
  SetupMcpStatus(name: 'search', status: 'failed'),
  SetupMcpStatus(name: 'github', status: 'needs_auth'),
];

const _oc2 = {
  'sources': [
    {
      'type': 'document',
      'path': '/home/me/.config/opencode/opencode.json',
      'info': {
        'model': 'anthropic/claude-sonnet-4',
        'mcp': <String, Object?>{},
      },
    },
    {
      'type': 'document',
      'path': '/home/me/projects/app/opencode.json',
      'info': {'permission': <String, Object?>{}, 'default_agent': 'plan'},
    },
  ],
};

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

String _name(String shot, Size size, bool light) => [
  shot,
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

Future<void> _shot(
  WidgetTester tester,
  String shot, {
  required bool light,
  required _Gateway? gateway,
  Size size = _phone,
  bool offlineAfterRead = false,
  bool openAllSettings = false,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  SharedPreferences.setMockInitialValues({
    'oc.profiles': jsonEncode([
      {'id': 'laptop', 'name': 'Laptop', 'baseUrl': 'http://192.168.1.20:4096'},
    ]),
  });
  final connection =
      ConnectionController(_Store(prefs: await SharedPreferences.getInstance()))
        ..api = OpenCodeApi(baseUrl: 'http://192.168.1.20:4096')
        ..status = StreamStatus.connected;
  final session = SetupSession(connection, gatewayFor: (_) => gateway);
  final boundary = GlobalKey();
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
          home: AiSetupScreen(
            controller: connection,
            serverName: 'Laptop',
            session: session,
          ),
        ),
      ),
    );
    if (offlineAfterRead) {
      await tester.pumpAndSettle();
      connection.status = StreamStatus.disconnected;
      connection.notifyListeners();
    }
    if (openAllSettings) {
      await tester.pumpAndSettle();
      await tester.tap(find.text('All settings'));
    }
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/${_name(shot, size, light)}.png'),
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
    connection.dispose();
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUp(() {
    debugPlatformCapabilities = const PlatformCapabilities.android();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          secure,
          (call) async => call.method == 'readAll' ? <String, String>{} : null,
        );
  });
  tearDown(() {
    debugPlatformCapabilities = null;
    KitRedact.clearKnownSecrets();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, null);
  });

  for (final light in [false, true]) {
    final tone = light ? 'light' : 'dark';
    group('ai setup ($tone)', () {
      for (final size in [_phone, _wide]) {
        testWidgets('opencode 1 ${size.width.toInt()}', (tester) async {
          await _shot(
            tester,
            'aisetup_oc1_ready',
            light: light,
            size: size,
            gateway: _Gateway(config: _oc1, servers: _servers),
          );
        });
        testWidgets('opencode 2 ${size.width.toInt()}', (tester) async {
          await _shot(
            tester,
            'aisetup_oc2_sources',
            light: light,
            size: size,
            gateway: _Gateway(config: _oc2, servers: _servers.sublist(0, 3)),
          );
        });
      }
      // The whole page on one tall phone, every setting unfolded: the
      // provider key is masked (review evidence for the redaction rule).
      testWidgets('opencode 1, all settings', (tester) async {
        await _shot(
          tester,
          'aisetup_oc1_all_settings',
          light: light,
          size: const Size(412, 2300),
          gateway: _Gateway(config: _oc1, servers: _servers),
          openAllSettings: true,
        );
      });
      testWidgets('loading', (tester) async {
        await _shot(
          tester,
          'aisetup_loading',
          light: light,
          gateway: _Gateway(hold: true),
          settle: false,
        );
      });
      testWidgets('empty', (tester) async {
        await _shot(tester, 'aisetup_empty', light: light, gateway: _Gateway());
      });
      testWidgets('offline with the last read', (tester) async {
        await _shot(
          tester,
          'aisetup_offline_stale',
          light: light,
          gateway: _Gateway(config: _oc1, servers: _servers),
          offlineAfterRead: true,
        );
      });
      testWidgets('unsupported', (tester) async {
        await _shot(tester, 'aisetup_unsupported', light: light, gateway: null);
      });
      testWidgets('needs sign-in', (tester) async {
        await _shot(
          tester,
          'aisetup_needs_sign_in',
          light: light,
          gateway: _Gateway(
            failure: const SetupFailure(
              SetupFailureCode.needsSignIn,
              'Sign in to this server to inspect setup.',
            ),
          ),
        );
      });
      testWidgets('error', (tester) async {
        await _shot(
          tester,
          'aisetup_error',
          light: light,
          gateway: _Gateway(
            failure: const SetupFailure(
              SetupFailureCode.transport,
              'The server could not load setup information.',
            ),
          ),
        );
      });
    });
  }
}
