// KitTranscriptExcerpt (docs/ux-system/kit-api/KitTranscriptExcerpt.md,
// slice-chat-speed-fixes): a conversation's end as it read last time,
// read-only while the live history loads. It says how old the words are and
// that the live history is on its way, keeps the newest message at the
// bottom, and nothing in it can be pressed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

const _messages = [
  KitExcerptMessage(
    key: ValueKey('prompt'),
    text: 'Fix the flaky checkout test',
    fromPerson: true,
  ),
  KitExcerptMessage(
    key: ValueKey('reply'),
    text: 'The checkout test is fixed. See [the log](https://example.com).',
    fromPerson: false,
  ),
];

KitTranscriptExcerpt _part({bool refreshing = true}) => KitTranscriptExcerpt(
  messages: _messages,
  updated: 'Updated 5m ago',
  refreshing: refreshing,
  labelKey: const ValueKey('label'),
);

Widget _host(Widget child, {double textScale = 1}) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: app!,
  ),
  home: Scaffold(body: child),
);

void main() {
  kitMotionStillTests(
    'KitTranscriptExcerpt',
    builds: {
      'loading': () => SizedBox(height: 400, child: _part()),
      'settled': () => SizedBox(height: 400, child: _part(refreshing: false)),
    },
    changes: {
      'refresh ends': KitMotionChange(
        build: () => SizedBox(height: 400, child: _part()),
        act: (tester, stage) => stage.rebuild(
          SizedBox(height: 400, child: _part(refreshing: false)),
        ),
        hides: 'Updated 5m ago · Refreshing',
      ),
    },
  );

  testWidgets('shows the words, how old they are, and that it is refreshing', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_part()));
    expect(find.text('Updated 5m ago · Refreshing'), findsOneWidget);
    expect(find.text('Fix the flaky checkout test'), findsOneWidget);
    expect(find.textContaining('The checkout test is fixed.'), findsOneWidget);

    await tester.pumpWidget(_host(_part(refreshing: false)));
    expect(find.text('Updated 5m ago'), findsOneWidget);
    expect(find.textContaining('Refreshing'), findsNothing);
  });

  testWidgets('the newest message sits at the bottom, the prompt at the end '
      'edge and the reply at the start edge', (tester) async {
    await tester.pumpWidget(_host(_part()));
    final prompt = tester.getRect(find.byKey(const ValueKey('prompt')));
    final reply = tester.getRect(find.byKey(const ValueKey('reply')));
    final label = tester.getRect(find.byKey(const ValueKey('label')));
    expect(prompt.bottom, lessThanOrEqualTo(reply.top));
    expect(reply.bottom, lessThanOrEqualTo(label.top));
    final bubble = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('prompt')),
        matching: find.text('Fix the flaky checkout test'),
      ),
    );
    final screen = tester.getRect(find.byType(Scaffold));
    expect(bubble.center.dx, greaterThan(screen.center.dx));
  });

  testWidgets('nothing is pressable: no tap, no menu, no link', (tester) async {
    await tester.pumpWidget(_host(_part()));
    expect(
      find.descendant(
        of: find.byType(KitTranscriptExcerpt),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
    await tester.tap(
      find.textContaining('The checkout test is fixed.'),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    // Said once: these words are a memory, not the conversation.
    expect(
      tester
          .widgetList<Semantics>(
            find.descendant(
              of: find.byType(KitTranscriptExcerpt),
              matching: find.byType(Semantics),
            ),
          )
          .where(
            (s) =>
                s.properties.hint ==
                'Saved from last time. The conversation opens fully once it '
                    'loads.',
          ),
      hasLength(1),
    );
  });

  testWidgets('taller than its space: the newest words stay, older ones are '
      'cut off at the top, never an overflow, at 2.0 text on 320dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        KitTranscriptExcerpt(
          updated: 'Updated 3h ago',
          messages: [
            for (var i = 0; i < 12; i++)
              KitExcerptMessage(
                text: 'Message $i with enough words to wrap on a narrow phone',
                fromPerson: i.isEven,
              ),
          ],
        ),
        textScale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Message 11'), findsOneWidget);
    expect(find.text('Updated 3h ago · Refreshing'), findsOneWidget);
  });
}
