// Shared harness for unit chat-3 (the composer): a chat on a fake server,
// pumped at a chosen window size and theme.
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
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart' show captureTheme;
import '../support/complete_message_history.dart';

class Chat3Api extends OpenCodeApi with CompleteMessageHistory {
  Chat3Api() : super(baseUrl: 'http://localhost');
  List<MessageWithParts> transcript = [];

  @override
  Future<List<Session>> sessions() async => const [];

  @override
  Future<Map<String, String>> sessionStatuses() async => const {};

  @override
  Future<List<MessageWithParts>> messages(String id) async => transcript;

  @override
  Future<Session> session(String id) async => Session(id: id);
}

MessageWithParts chat3Prompt(String id, String text) => MessageWithParts(
  info: MessageInfo(id: id, sessionID: 'session-1', role: 'user'),
  parts: [Part(type: 'text', text: text)],
);

/// flutter_secure_storage hangs inside testWidgets unless answered.
void chat3MockSecureStorage() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (_) async => null,
      );
}

Future<ConnectionController> chat3Controller({Chat3Api? api}) async {
  SharedPreferences.setMockInitialValues({
    'oc.profiles': jsonEncode([
      {
        'id': 'profile-1',
        'name': 'Laptop',
        'baseUrl': 'http://localhost',
        'username': '',
      },
    ]),
    'oc.activeProfile': 'profile-1',
  });
  final prefs = await SharedPreferences.getInstance();
  final store = ProfileStore(prefs: prefs);
  await store.load();
  return ConnectionController(store)
    ..api = api ?? Chat3Api()
    ..status = StreamStatus.connected;
}

/// Pumps the chat. With [theme] the app's real theme is used (goldens);
/// otherwise the default Material theme.
Future<void> pumpChat3(
  WidgetTester tester,
  ConnectionController conn, {
  Size size = const Size(412, 915),
  bool? light,
  GlobalKey? boundary,
}) async {
  // Goldens render as Android; the caller resets the override before the
  // test ends (the binding checks it before tear-down callbacks run).
  if (light != null) {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  }
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Widget app = ProviderScope(
    overrides: [connProvider.overrideWithValue(conn)],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: light == null ? null : captureTheme(light: light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: const ChatScreen(sessionID: 'session-1'),
    ),
  );
  if (boundary != null) app = RepaintBoundary(key: boundary, child: app);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}
