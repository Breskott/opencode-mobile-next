// Behaviour of screen-chat-1's rebuilt pages that the older test files do
// not cover: the move and cloud-move sheets and their confirmation, the
// organization switch, and the offline demo's frame (map fixes).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/ui/kit/kit_page_route.dart';
import 'package:opencode_mobile/ui/screens/demo_screen.dart';
import 'package:opencode_mobile/ui/screens/session_destination_sheet.dart';

import 'screen_chat_1_support.dart';

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Finder _line(String text) => find.textContaining(text, findRichText: true);

/// Taps [finder] after scrolling it into view (a question can be taller
/// than the part of the sheet on screen).
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  // A phone window: the sheets are bottom sheets here.
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(412, 915);
    view.devicePixelRatio = 1;
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  testWidgets('move names each place and its kind, and marks the current', (
    tester,
  ) async {
    final conn = await chatOneConnection();
    await tester.pumpWidget(
      chatOneApp(
        opener(
          (context) => showSessionDestinationSheet(
            context,
            controller: conn,
            sessionID: 'ses_a',
            mode: SessionDestinationMode.move,
          ),
        ),
      ),
    );
    await _open(tester);
    expect(find.byKey(const Key('move-session-sheet')), findsOneWidget);
    expect(find.text('Move conversation'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    expect(_line('Main copy'), findsOneWidget);
    expect(_line('Separate copy'), findsOneWidget);
    // Name and kind only: no raw path under a unique name.
    expect(_line('/work/checkout-retry'), findsNothing);
  });

  testWidgets(
    'the move question says where changes go and where they stay, and moving '
    'without them leaves them',
    (tester) async {
      final conn = await chatOneConnection();
      await tester.pumpWidget(
        chatOneApp(
          opener(
            (context) => showSessionDestinationSheet(
              context,
              controller: conn,
              sessionID: 'ses_a',
              mode: SessionDestinationMode.move,
            ),
          ),
        ),
      );
      await _open(tester);
      await tester.tap(
        find.byKey(const Key('move-destination-/work/checkout-retry')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('2 changed files are present.'), findsOne);
      expect(
        find.text('With changes, they go with it to checkout-retry.'),
        findsOneWidget,
      );
      expect(find.text('Without changes, they stay in acme.'), findsOneWidget);
      await _tap(
        tester,
        find.byKey(const Key('session-destination-without-changes')),
      );
      expect(conn.moves, [('/work/checkout-retry', false)]);
      expect(find.byKey(const Key('move-session-sheet')), findsNothing);
    },
  );

  testWidgets('a move the server refuses keeps the question open', (
    tester,
  ) async {
    final conn = await chatOneConnection()
      ..refuse = const ProductException('The server refused the move.');
    await tester.pumpWidget(
      chatOneApp(
        opener(
          (context) => showSessionDestinationSheet(
            context,
            controller: conn,
            sessionID: 'ses_a',
            mode: SessionDestinationMode.move,
          ),
        ),
      ),
    );
    await _open(tester);
    await tester.tap(
      find.byKey(const Key('move-destination-/work/checkout-retry')),
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('session-destination-confirm')));
    expect(conn.moves, isEmpty);
    // Still asking, with the reason: it never closes on an error.
    expect(find.byKey(const Key('session-destination-confirm')), findsOne);
  });

  testWidgets('a cloud machine that is not connected says why it cannot be '
      'picked', (tester) async {
    final conn = await chatOneConnection();
    await tester.pumpWidget(
      chatOneApp(
        opener(
          (context) => showSessionDestinationSheet(
            context,
            controller: conn,
            sessionID: 'ses_a',
            mode: SessionDestinationMode.warp,
          ),
        ),
      ),
    );
    await _open(tester);
    expect(find.text('Move to the cloud'), findsOneWidget);
    expect(_line('Cloud machine · Connected'), findsOneWidget);
    expect(
      find.textContaining('It can be picked once it connects.'),
      findsOneWidget,
    );
    await _tap(tester, find.byKey(const Key('warp-destination-ws-offline')));
    expect(find.byKey(const Key('session-destination-confirm')), findsNothing);
    await _tap(tester, find.byKey(const Key('warp-destination-ws-review')));
    await _tap(tester, find.byKey(const Key('session-destination-confirm')));
    expect(conn.warps, [('ws-review', true)]);
  });

  testWidgets('with nowhere else to go the sheet says so', (tester) async {
    final repo = ChatOneRepository()
      ..directories = const [ProjectDirectoryInfo(directory: '/work/acme')];
    final conn = await chatOneConnection(repo);
    await tester.pumpWidget(
      chatOneApp(
        opener(
          (context) => showSessionDestinationSheet(
            context,
            controller: conn,
            sessionID: 'ses_a',
            mode: SessionDestinationMode.move,
          ),
        ),
      ),
    );
    await _open(tester);
    expect(find.text('Nowhere to move it'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
  });

  testWidgets('organizations are grouped once per account and the switch says '
      'what changes', (tester) async {
    final conn = await chatOneConnection();
    await tester.pumpWidget(
      chatOneApp(
        opener(
          (context) => showConsoleOrganizationSheet(context, controller: conn),
        ),
      ),
    );
    await _open(tester);
    expect(find.text('sam@example.com · console.example.com'), findsOneWidget);
    expect(
      find.text('sam@agency.example · console.example.com'),
      findsOneWidget,
    );
    // Raw ids are not shown as supporting lines.
    expect(_line('org-side'), findsNothing);
    await _tap(tester, find.byKey(const Key('console-org-acct-1-org-side')));
    final body = find.textContaining('becomes the organization for models');
    expect(body, findsOneWidget);
    final words = tester.widget<Text>(body).data ?? '';
    expect(words, isNot(contains('..')));
    expect(words, contains('nothing running is stopped'));
    await _tap(tester, find.byKey(const Key('console-org-confirm')));
    expect(conn.switched, ['org-side']);
    expect(find.byKey(const Key('console-organization-sheet')), findsNothing);
  });

  testWidgets('a switch that fails keeps the question open', (tester) async {
    final conn = await chatOneConnection()
      ..refuse = const ProductException('Console refused.');
    await tester.pumpWidget(
      chatOneApp(
        opener(
          (context) => showConsoleOrganizationSheet(context, controller: conn),
        ),
      ),
    );
    await _open(tester);
    await _tap(tester, find.byKey(const Key('console-org-acct-2-org-client')));
    await _tap(tester, find.byKey(const Key('console-org-confirm')));
    expect(conn.switched, isEmpty);
    expect(find.byKey(const Key('console-org-confirm')), findsOneWidget);
  });

  testWidgets('with one organization there is nothing to switch, said once', (
    tester,
  ) async {
    final repo = ChatOneRepository();
    repo.organizations = [repo.organizations.first];
    final conn = await chatOneConnection(repo);
    await tester.pumpWidget(
      chatOneApp(
        opener(
          (context) => showConsoleOrganizationSheet(context, controller: conn),
        ),
      ),
    );
    await _open(tester);
    expect(
      find.byKey(const Key('console-organization-only-one')),
      findsOneWidget,
    );
  });

  testWidgets('the demo is titled, says it is simulated, and keeps "Set up '
      'your own server" reachable', (tester) async {
    await tester.pumpWidget(
      chatOneApp(
        opener(
          (context) => pushKitPage<void>(context, (_) => const DemoScreen()),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Try it offline'), findsOneWidget);
    expect(find.text('Simulated · nothing is saved'), findsOneWidget);
    expect(find.byTooltip('Reset demo'), findsOneWidget);
    expect(find.text('Set up your own server'), findsNothing);
    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Set up your own server'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
