// KitSteerBox: the small composer a home-screen widget opens.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

Widget _part(
  TextEditingController controller, {
  KitSteerBoxPhase phase = KitSteerBoxPhase.ready,
  String? blockedReason,
  String? message,
  ValueChanged<String>? onSend,
  VoidCallback? onDictate,
  VoidCallback? onClose,
}) => KitSteerBox(
  title: 'Add to this turn',
  controller: controller,
  hint: 'Write a message',
  sendLabel: 'Send',
  phase: phase,
  blockedReason: blockedReason,
  message: message,
  onSend: onSend ?? (_) {},
  onDictate: onDictate ?? () {},
  onClose: onClose ?? () {},
);

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  final c = TextEditingController();
  kitMotionStillTests(
    'KitSteerBox',
    builds: {
      'ready': () => _part(c),
      'sending': () => _part(c, phase: KitSteerBoxPhase.sending),
      'sent': () => _part(c, phase: KitSteerBoxPhase.sent),
      'blocked': () => _part(c, blockedReason: 'Waiting for details'),
    },
    changes: {
      'a note appears': KitMotionChange(
        build: () => _part(c),
        act: (tester, stage) =>
            stage.rebuild(_part(c, message: 'Your message is still here.')),
        shows: 'Your message is still here.',
      ),
    },
  );

  testWidgets('Send is off until there is text, then sends it trimmed', (
    tester,
  ) async {
    final controller = TextEditingController();
    final sent = <String>[];
    await tester.pumpWidget(_app(_part(controller, onSend: sent.add)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    expect(sent, isEmpty);
    await tester.enterText(find.byType(TextField), '  keep going  ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    expect(sent, ['keep going']);
  });

  testWidgets('blocked: field and Send are off and the reason is shown', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'draft');
    final sent = <String>[];
    await tester.pumpWidget(
      _app(
        _part(
          controller,
          blockedReason: 'Waiting for details',
          onSend: sent.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Waiting for details'), findsOneWidget);
    await tester.tap(find.text('Send'));
    expect(sent, isEmpty);
    expect(controller.text, 'draft');
  });

  testWidgets('sending shows progress and cannot be closed', (tester) async {
    final controller = TextEditingController(text: 'hi');
    var closed = 0;
    await tester.pumpWidget(
      _app(
        _part(
          controller,
          phase: KitSteerBoxPhase.sending,
          onClose: () => closed++,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Sending…'), findsWidgets);
    final close = tester.widget<KitIconButton>(
      find.byType(KitIconButton).first,
    );
    expect(close.onPressed, isNull);
    expect(closed, 0);
  });

  testWidgets('the microphone asks for dictation; sent shows a check', (
    tester,
  ) async {
    var dictated = 0;
    await tester.pumpWidget(
      _app(_part(TextEditingController(), onDictate: () => dictated++)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dictate a message'));
    expect(dictated, 1);
    await tester.pumpWidget(
      _app(_part(TextEditingController(), phase: KitSteerBoxPhase.sent)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sent'), findsWidgets);
  });
}
