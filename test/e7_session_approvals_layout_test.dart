import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/session_auto_approval.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/capture/fixtures.dart'
    show loadCaptureFonts, capturePng, writePng;
import 'support/complete_message_history.dart';

const _capture = bool.fromEnvironment('E7_APPROVALS_CAPTURE');
final _boundary = GlobalKey();

Future<void> _captureScreen(WidgetTester tester, String name) async {
  if (!_capture) return;
  await writePng(
    'docs/qa/session-auto-approval/$name.png',
    await capturePng(tester, _boundary, pixelRatio: 1),
  );
}

class _FakeApi extends OpenCodeApi with CompleteMessageHistory {
  _FakeApi() : super(baseUrl: 'http://localhost');
  final replies = <(String, String)>[];
  Completer<void>? hold;
  Object? fail;

  @override
  Future<void> respondPermission(
    String requestID,
    String reply, {
    String? legacySessionID,
    String? legacyPermissionID,
    String? message,
  }) async {
    await hold?.future;
    if (fail case final error?) throw error;
    replies.add((requestID, reply));
  }

  @override
  Future<List<PermissionRequest>> pendingPermissions() async => [];

  @override
  Future<List<PermissionRequest>> pendingPermissionsV2() =>
      Future.error(ApiException('V2 unavailable', statusCode: 404));
}

class _Controller extends ConnectionController {
  _Controller(super.store);
  @override
  ServerProfile get profile =>
      ServerProfile(id: 'server-a', name: 'A', baseUrl: 'http://localhost');
}

Future<(_Controller, _FakeApi)> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final api = _FakeApi();
  final controller = _Controller(ProfileStore(prefs: prefs))
    ..api = api
    ..status = StreamStatus.connected;
  addTearDown(controller.dispose);
  controller.sessionsById['parent'] = Session(id: 'parent', title: 'Parent');
  controller.sessionsById['child'] = Session(
    id: 'child',
    title: 'Child',
    parentID: 'parent',
  );
  return (controller, api);
}

Widget _app(
  ConnectionController controller,
  String sessionID,
  TextDirection direction,
) => ProviderScope(
  overrides: [connProvider.overrideWithValue(controller)],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(2.5)),
      child: RepaintBoundary(
        key: _boundary,
        child: Directionality(textDirection: direction, child: child!),
      ),
    ),
    home: ChatScreen(sessionID: sessionID),
  ),
);

EventEnvelope _ask(String id, String session) => EventEnvelope(
  type: 'permission.asked',
  properties: {
    'id': id,
    'sessionID': session,
    'permission': 'bash',
    'patterns': ['git status'],
    'metadata': <String, Object?>{},
    'always': <String>[],
  },
);

Future<void> _openApprovals(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('session-actions-button')));
  await tester.pumpAndSettle();
  final actions = find.text('Conversation actions');
  await tester.ensureVisible(actions);
  await tester.pumpAndSettle();
  await tester.tap(actions);
  await tester.pumpAndSettle();
  final approvals = find.text('Approvals');
  await tester.ensureVisible(approvals);
  await tester.pumpAndSettle();
  await tester.tap(approvals);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('session-approvals-sheet')), findsOneWidget);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (_capture) setUpAll(loadCaptureFonts);

  for (final direction in TextDirection.values) {
    testWidgets(
      '320dp 2.5x $direction approvals sheet, indicator and auto-approval record',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final (controller, api) = await _boot();
        await tester.pumpWidget(_app(controller, 'parent', direction));
        await tester.pumpAndSettle();

        // Default: asking, and no indicator anywhere.
        expect(find.byKey(const Key('auto-approval-indicator')), findsNothing);

        await _openApprovals(tester);
        await _captureScreen(tester, 'sheet-ask-${direction.name}');
        // Inheritance cannot be switched on while asking.
        final inherit = find.byKey(const Key('approvals-inherit-switch'));
        expect(tester.widget<SwitchListTile>(inherit).onChanged, isNull);
        expect(
          find.text('Available once automatic approval is on.'),
          findsOneWidget,
        );

        await _tapVisible(
          tester,
          find.text('Approve automatically while connected'),
        );
        expect(controller.autoApprovalFor('parent').automatic, isTrue);
        expect(tester.widget<SwitchListTile>(inherit).onChanged, isNotNull);
        await _tapVisible(tester, find.text('Subagents inherit this'));
        expect(
          controller.autoApprovalFor('parent').setting.inheritToChildren,
          isTrue,
        );
        expect(controller.autoApprovalFor('child').inheritedFrom, 'parent');
        // The consequences are spelled out in the sheet itself.
        expect(find.textContaining('deny rules still apply'), findsOneWidget);
        expect(
          find.textContaining('Nothing is saved as always allowed'),
          findsOneWidget,
        );
        await _captureScreen(tester, 'sheet-auto-${direction.name}');
        await _tapVisible(tester, find.byKey(const Key('approvals-done')));
        expect(find.byKey(const Key('session-approvals-sheet')), findsNothing);

        // The indicator is on while the setting is on.
        final indicator = find.byKey(const Key('auto-approval-indicator'));
        expect(indicator, findsOneWidget);
        expect(find.text('Approving automatically'), findsOneWidget);

        // A request is answered without a card, and the record names it.
        controller.handleEventForTesting(_ask('req-1', 'parent'));
        await tester.pumpAndSettle();
        expect(api.replies, [('req-1', 'once')]);
        expect(find.byKey(const Key('permission-card-review')), findsNothing);
        expect(
          find.textContaining('Auto-approved · Run a shell command'),
          findsOneWidget,
        );
        await _captureScreen(tester, 'indicator-${direction.name}');

        // Tapping the indicator reopens the sheet, which lists the record;
        // Ask switches approval off again.
        await _tapVisible(tester, indicator);
        expect(
          find.byKey(const Key('session-approvals-sheet')),
          findsOneWidget,
        );
        expect(
          find.text('1 request approved automatically on this server'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Auto-approved · Run a shell command'),
          findsNWidgets(2),
        );
        await _captureScreen(tester, 'sheet-record-${direction.name}');
        await _tapVisible(tester, find.text('Ask each time'));
        await _tapVisible(tester, find.byKey(const Key('approvals-done')));
        expect(find.byKey(const Key('auto-approval-indicator')), findsNothing);
        controller.handleEventForTesting(_ask('req-2', 'parent'));
        await tester.pumpAndSettle();
        expect(api.replies, hasLength(1));
        expect(find.byKey(const Key('permission-card-review')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '320dp 2.5x $direction child session shows inheritance and can override',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final (controller, api) = await _boot();
        await controller.setSessionAutoApproval(
          'parent',
          const SessionAutoApproval(
            mode: AutoApprovalMode.autoOnce,
            inheritToChildren: true,
          ),
        );
        await tester.pumpWidget(_app(controller, 'child', direction));
        await tester.pumpAndSettle();

        expect(find.textContaining('Approving automatically'), findsOneWidget);
        expect(
          find.textContaining('Inherited from parent conversation'),
          findsOneWidget,
        );
        await _captureScreen(tester, 'child-indicator-${direction.name}');

        await _tapVisible(
          tester,
          find.byKey(const Key('auto-approval-indicator')),
        );
        expect(
          find.byKey(const Key('approvals-inherited-note')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Inherited from parent conversation'),
          findsWidgets,
        );
        expect(find.byKey(const Key('approvals-follow-parent')), findsNothing);
        await _captureScreen(tester, 'child-sheet-${direction.name}');

        // Override keeps the inherited choice but makes it this session's own.
        await _tapVisible(tester, find.byKey(const Key('approvals-override')));
        expect(controller.autoApprovalFor('child').explicit, isTrue);
        expect(controller.autoApprovalFor('child').automatic, isTrue);
        expect(find.byKey(const Key('approvals-inherited-note')), findsNothing);
        expect(
          find.byKey(const Key('approvals-follow-parent')),
          findsOneWidget,
        );

        // Choosing Ask on the override stops inherited approval here only.
        await _tapVisible(tester, find.text('Ask each time'));
        expect(controller.autoApprovalFor('child').automatic, isFalse);
        expect(controller.autoApprovalFor('parent').automatic, isTrue);

        // Following the parent again restores the inherited state.
        await _tapVisible(
          tester,
          find.byKey(const Key('approvals-follow-parent')),
        );
        expect(controller.autoApprovalFor('child').inheritedFrom, 'parent');
        expect(
          find.byKey(const Key('approvals-inherited-note')),
          findsOneWidget,
        );
        await _tapVisible(tester, find.byKey(const Key('approvals-done')));

        controller.handleEventForTesting(_ask('req-child', 'child'));
        await tester.pumpAndSettle();
        expect(api.replies, [('req-child', 'once')]);
        expect(find.byKey(const Key('permission-card-review')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('disconnecting pauses the indicator without hiding it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (controller, api) = await _boot();
    await controller.setSessionAutoApproval(
      'parent',
      const SessionAutoApproval(mode: AutoApprovalMode.autoOnce),
    );
    await tester.pumpWidget(_app(controller, 'parent', TextDirection.ltr));
    await tester.pumpAndSettle();
    expect(find.text('Approving automatically'), findsOneWidget);

    controller.status = StreamStatus.reconnecting;
    controller.notifyListeners();
    // The connection banner animates while reconnecting; pump a fixed frame.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('auto-approval-indicator')), findsOneWidget);
    expect(find.textContaining('Auto-approval paused'), findsOneWidget);
    expect(find.textContaining('Not connected'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // A request arriving now waits for a person: covered by the controller
    // test. (A permission card next to the reconnecting banner at 320dp/2.5x
    // is a pre-existing layout limit unrelated to this slice.)
    expect(api.replies, isEmpty);
  });

  testWidgets('a failed automatic reply shows the request with the reason', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (controller, api) = await _boot();
    await controller.setSessionAutoApproval(
      'parent',
      const SessionAutoApproval(mode: AutoApprovalMode.autoOnce),
    );
    api.fail = ApiException('server refused the reply');
    await tester.pumpWidget(_app(controller, 'parent', TextDirection.ltr));
    await tester.pumpAndSettle();

    controller.handleEventForTesting(_ask('req-1', 'parent'));
    await tester.pumpAndSettle();

    expect(api.replies, isEmpty);
    expect(find.byKey(const Key('permission-card-review')), findsOneWidget);
    expect(
      find.text('Automatic approval failed. Review this request.'),
      findsOneWidget,
    );
    // The card takes the slot while a person is needed; the strip is back
    // as soon as the request is answered by hand.
    expect(find.byKey(const Key('auto-approval-indicator')), findsNothing);
    expect(tester.takeException(), isNull);

    api.fail = null;
    await controller.answerPermission('req-1', 'reject');
    await tester.pumpAndSettle();
    expect(api.replies, [('req-1', 'reject')]);
    expect(find.byKey(const Key('permission-card-review')), findsNothing);
    expect(find.byKey(const Key('auto-approval-indicator')), findsOneWidget);
    expect(find.text('Approving automatically'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('approve everything is confirmed, saved, and can be declined', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (controller, _) = await _boot();
    await tester.pumpWidget(_app(controller, 'parent', TextDirection.ltr));
    await tester.pumpAndSettle();
    await _openApprovals(tester);

    // At 2.5x text the tile is taller than the sheet's viewport, so its
    // centre can be off screen; its title line is not.
    Future<void> tapEverything() async {
      final tile = find.byKey(const Key('approvals-everything-switch'));
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getTopLeft(tile) + const Offset(30, 24));
      await tester.pumpAndSettle();
    }

    // Declining the confirmation changes nothing.
    await tapEverything();
    expect(
      find.byKey(const Key('approvals-everything-confirm')),
      findsOneWidget,
    );
    await _tapVisible(tester, find.text('Cancel'));
    expect(controller.approvesEverything, isFalse);

    // Confirming turns it on for conversations that never had a setting.
    await tapEverything();
    await _tapVisible(
      tester,
      find.byKey(const Key('approvals-everything-confirm-action')),
    );
    expect(controller.approvesEverything, isTrue);
    expect(controller.autoApprovalFor('parent').automatic, isTrue);
    expect(controller.autoApprovalFor('never-seen').automatic, isTrue);
    expect(
      find.byKey(const Key('approvals-everything-active')),
      findsOneWidget,
    );

    // Turning it off needs no confirmation.
    await tapEverything();
    expect(controller.approvesEverything, isFalse);
    expect(controller.autoApprovalFor('never-seen').automatic, isFalse);
  });
}
