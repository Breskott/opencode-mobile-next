// Gallery of unit chat-5 (chat requests on the one card): a permission
// waiting on the one request card with Allow once in place, its details in
// the one request sheet, an OpenCode 1 question on the same card, and the
// approvals sheet, at 412x915 and 1280x800, dark and light, with the app's
// real fonts.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/chat_5_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';

import '../../tool/capture/fixtures.dart' show loadCaptureFonts;
import 'chat_3_support.dart';

class _Api extends Chat3Api {
  @override
  Future<List<PermissionRequest>> pendingPermissions() async => const [];

  @override
  Future<List<PermissionRequest>> pendingPermissionsV2() =>
      Future.error(ApiException('V2 unavailable', statusCode: 404));
}

final _permission = EventEnvelope(
  type: 'permission.asked',
  properties: {
    'id': 'request-1',
    'sessionID': 'session-1',
    'permission': 'bash',
    'patterns': ['flutter test test/checkout_test.dart'],
    'metadata': <String, Object?>{},
    'always': ['flutter test *'],
  },
);

final _question = EventEnvelope(
  type: 'question.asked',
  properties: {
    'id': 'question-1',
    'sessionID': 'session-1',
    'questions': [
      {
        'header': 'Pick a target',
        'question': 'Where should this deploy?',
        'multiple': false,
        'custom': true,
        'options': [
          {'label': 'Staging', 'description': 'Test environment'},
          {'label': 'Production', 'description': 'Live environment'},
        ],
      },
    ],
  },
);

typedef _Scene =
    Future<void> Function(WidgetTester tester, ConnectionController conn);

final _scenes = <String, _Scene>{
  'chat_5_permission_card': (tester, conn) async {
    conn.handleEventForTesting(_permission);
    await tester.pumpAndSettle();
  },
  'chat_5_permission_sheet': (tester, conn) async {
    conn.handleEventForTesting(_permission);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('permission-card-review')));
    await tester.pumpAndSettle();
  },
  'chat_5_question_card': (tester, conn) async {
    conn.handleEventForTesting(_question);
    await tester.pumpAndSettle();
  },
  'chat_5_approvals_sheet': (tester, conn) async {
    showSessionApprovalsSheet(
      tester.element(find.byType(ChatScreen)),
      controller: conn,
      sessionID: 'session-1',
    );
    await tester.pumpAndSettle();
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  setUp(chat3MockSecureStorage);

  for (final size in const [Size(412, 915), Size(1280, 800)]) {
    for (final light in [false, true]) {
      final sized = size.width == 412
          ? ''
          : '_${size.width.toInt()}x${size.height.toInt()}';
      final theme = light ? 'light' : 'dark';
      for (final MapEntry(key: name, value: scene) in _scenes.entries) {
        final file = '$name${sized}_$theme';
        testWidgets(file, (tester) async {
          final conn = await chat3Controller(api: _Api());
          addTearDown(conn.dispose);
          final boundary = GlobalKey();
          debugDefaultTargetPlatformOverride =
              TargetPlatform.android; // ARCH-11
          try {
            await pumpChat3(
              tester,
              conn,
              size: size,
              light: light,
              boundary: boundary,
            );
            await scene(tester, conn);
            expect(tester.takeException(), isNull);
            await expectLater(
              find.byKey(boundary),
              matchesGoldenFile('goldens/$file.png'),
            );
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            debugDefaultTargetPlatformOverride = null;
          }
        });
      }
    }
  }
}
