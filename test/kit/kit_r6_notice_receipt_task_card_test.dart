// slice-R6: KitNotice.offer's wrapped layout (the close ends the first
// line, the action starts at the text inset), KitReceipt's own sending
// words, and KitTaskCard's single error glyph.
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_notice.dart';
import 'package:opencode_mobile/ui/kit/kit_receipt.dart';
import 'package:opencode_mobile/ui/kit/kit_task_card.dart';
import 'package:opencode_mobile/ui/kit/kit_task_mark.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(412, 915),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: inner!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Align(alignment: Alignment.topCenter, child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Every visible run of text, without KitBidi's isolates or icon glyphs.
String _visible(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((t) => t.text.toPlainText().replaceAll(RegExp('[\u2066-\u2069]'), ''))
    .where(
      (text) =>
          text.trim().isNotEmpty &&
          !RegExp('^[\ue000-\uf8ff]\$').hasMatch(text),
    )
    .join(' | ');

void main() {
  group('KitNotice.offer', () {
    const message =
        'This server also runs an AI team that can split work between '
        'agents. Turn it on?';

    Widget offer() => KitNotice.offer(
      message: message,
      action: KitAction(
        key: const ValueKey('offer-action'),
        label: 'Turn on',
        onPressed: () {},
      ),
      onDismiss: () {},
      dismissKey: const ValueKey('offer-close'),
      dismissLabel: 'Not now',
    );

    testWidgets('wrapped: the close ends the first line, the action sits '
        'under the sentence at its text inset', (tester) async {
      await _pump(tester, offer());
      final sentence = tester.getRect(find.text(message));
      final action = tester.getRect(find.byKey(const ValueKey('offer-action')));
      final close = tester.getRect(find.byKey(const ValueKey('offer-close')));
      final words = tester.getRect(find.text('Turn on'));

      expect(sentence.height, greaterThan(30), reason: 'the sentence wraps');
      // The close is at the end of the message's first line.
      expect(close.left, greaterThanOrEqualTo(sentence.right - 1));
      final firstLineCentre = sentence.top + 12;
      expect((close.center.dy - firstLineCentre).abs(), lessThan(6));
      // The action is under the sentence, not beside the close.
      expect(action.top, greaterThanOrEqualTo(sentence.bottom - 1));
      expect(close.bottom, lessThanOrEqualTo(action.top + 1));
      // The action's words start where the sentence's words start.
      expect((words.left - sentence.left).abs(), lessThanOrEqualTo(1));
    });

    testWidgets('one line: sentence, action and close share the line', (
      tester,
    ) async {
      await _pump(
        tester,
        KitNotice.offer(
          message: 'Pin it?',
          action: KitAction(
            key: const ValueKey('offer-action'),
            label: 'Pin',
            onPressed: () {},
          ),
          onDismiss: () {},
          dismissKey: const ValueKey('offer-close'),
        ),
      );
      final sentence = tester.getCenter(find.text('Pin it?'));
      final action = tester.getCenter(
        find.byKey(const ValueKey('offer-action')),
      );
      final close = tester.getCenter(find.byKey(const ValueKey('offer-close')));
      expect((action.dy - sentence.dy).abs(), lessThan(1));
      expect((close.dy - sentence.dy).abs(), lessThan(1));
    });
  });

  group('KitReceipt.sendingLabel', () {
    testWidgets('names the act while sending', (tester) async {
      await _pump(
        tester,
        const KitReceipt(
          state: KitReceiptState.sending,
          sendingLabel: 'Moving to Review…',
        ),
      );
      expect(_visible(tester), 'Moving to Review…');
      expect(find.text('Sending…'), findsNothing);
    });

    testWidgets('still turns into Not confirmed yet with Try again', (
      tester,
    ) async {
      var retries = 0;
      await _pump(
        tester,
        KitReceipt(
          state: KitReceiptState.sending,
          sendingLabel: 'Moving to Review…',
          since: clock.now().subtract(const Duration(seconds: 7)),
          onRetry: () => retries++,
        ),
      );
      expect(_visible(tester), 'Moving to Review…');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_visible(tester), contains('Not confirmed yet'));
      expect(_visible(tester), isNot(contains('Moving to Review')));
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('only the sending word changes: sent still says Sent', (
      tester,
    ) async {
      await _pump(
        tester,
        const KitReceipt(
          state: KitReceiptState.sent,
          sendingLabel: 'Moving to Review…',
        ),
      );
      expect(_visible(tester), 'Sent');
    });

    testWidgets('the row span uses it too', (tester) async {
      late InlineSpan span;
      await _pump(
        tester,
        Builder(
          builder: (context) {
            span = KitReceipt.span(
              context,
              KitReceiptState.sending,
              sendingLabel: 'Moving to Review…',
            );
            return const SizedBox();
          },
        ),
      );
      expect(
        span.toPlainText().replaceAll(RegExp('[\u2066-\u2069]'), ''),
        'Moving to Review… · ',
      );
    });
  });

  group('KitTaskCard', () {
    int glyphs(WidgetTester tester, IconData icon) => tester
        .widgetList<Icon>(find.byType(Icon))
        .where((i) => i.icon == icon)
        .length;

    testWidgets('a failed card shows the error glyph once', (tester) async {
      await _pump(
        tester,
        KitTaskCard(
          title: 'Fix the sync engine',
          mark: KitTaskState.failed,
          onOpen: () {},
          flag: const KitTaskFlag(
            kind: KitTaskFlagKind.failed,
            label: 'Stopped with an error',
          ),
        ),
      );
      expect(find.text('Stopped with an error'), findsOneWidget);
      expect(glyphs(tester, AppIconography.error), 1);
    });

    testWidgets('a stopped card shows the stop glyph once', (tester) async {
      await _pump(
        tester,
        KitTaskCard(
          title: 'Old idea',
          mark: KitTaskState.stopped,
          onOpen: () {},
          flag: const KitTaskFlag(
            kind: KitTaskFlagKind.stopped,
            label: 'Cancelled',
          ),
        ),
      );
      expect(find.text('Cancelled'), findsOneWidget);
      expect(glyphs(tester, AppIconography.stopCircle), 1);
    });

    testWidgets('a blocked flag keeps its own glyph', (tester) async {
      await _pump(
        tester,
        KitTaskCard(
          title: 'Ship the release',
          mark: KitTaskState.waiting,
          onOpen: () {},
          flag: const KitTaskFlag(
            kind: KitTaskFlagKind.blocked,
            label: 'Blocked by Sync engine',
          ),
        ),
      );
      expect(glyphs(tester, AppIconography.blocked), 1);
    });
  });
}
