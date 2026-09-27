// KitLogPanel R3 (docs/ux-system/revamp/leftover-units.json, slice-R3): the
// header Wrap toggle keeps the standard inset from the panel's edge and
// shows a pressed state, and one extra header action (a host's "Copy
// failure report") sits next to Copy all inside the panel.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_icon_button.dart';
import 'package:opencode_mobile/ui/kit/kit_log_panel.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

const _panel = ValueKey('kit-log-panel');
const _copyAll = ValueKey('kit-log-copy-all');
const _wrap = ValueKey('kit-log-wrap');

late List<MethodCall> _platform;

Future<void> _host(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(412, 915),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
  await tester.pump();
}

KitLogBuffer _lines() => KitLogBuffer()
  ..add(const KitLogLine('[oc] Installing opencode'))
  ..add(const KitLogLine('listen EADDRINUSE', level: KitLogLevel.error));

void main() {
  setUp(() {
    _platform = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      _platform.add(call);
      return null;
    });
    messenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (message) async => null,
    );
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      null,
    );
  });

  testWidgets('Wrap keeps the standard inset and shows a pressed state', (
    tester,
  ) async {
    await _host(tester, KitLogPanel(lines: _lines(), wrap: true));
    final tokens = KitTokens.of(tester.element(find.byKey(_panel)));
    final panel = tester.getRect(find.byKey(_panel));
    final wrap = tester.getRect(find.byKey(_wrap));
    final copy = tester.getRect(find.byKey(_copyAll));

    // Never touches the card's top or end edge.
    expect(wrap.top, greaterThanOrEqualTo(panel.top + tokens.space1 - .5));
    expect(copy.right, lessThanOrEqualTo(panel.right - tokens.space2 + .5));
    expect(wrap.height, tokens.minTarget);
    // Sized to the header: the controls share its centre line.
    expect(wrap.center.dy, copy.center.dy);

    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byKey(_wrap)),
      isSemantics(hasToggledState: true, isToggled: true, label: 'Wrap lines'),
    );
    handle.dispose();
    expect(tester.widget<KitIconButton>(find.byKey(_wrap)).selected, isTrue);
  });

  KitLogPanel reportPanel() => KitLogPanel(
    lines: _lines(),
    ended: const KitLogEnd(exitCode: 1, failed: true),
    headerAction: KitAction.copy(
      key: const ValueKey('report'),
      label: 'Copy failure report',
      text: () => 'the report',
    ),
  );

  testWidgets('wide: the extra header action sits beside Copy all', (
    tester,
  ) async {
    await _host(tester, reportPanel(), size: const Size(1280, 800));
    final panel = tester.getRect(find.byKey(_panel));
    final copy = tester.getRect(find.byKey(_copyAll));
    final action = tester.getRect(find.text('Copy failure report'));
    expect(panel.contains(action.center), isTrue, reason: 'inside the panel');
    expect(action.left, greaterThanOrEqualTo(copy.right));
    expect((action.center.dy - copy.center.dy).abs(), lessThanOrEqualTo(1));
  });

  testWidgets('phone: the action takes its own header line, words whole', (
    tester,
  ) async {
    await _host(tester, reportPanel());
    final panel = tester.getRect(find.byKey(_panel));
    final copy = tester.getRect(find.byKey(_copyAll));
    final button = tester.getRect(find.byKey(const ValueKey('report')));
    final words = find.text('Copy failure report');
    expect(panel.contains(button.center), isTrue, reason: 'inside the panel');
    // Under Copy all, end-aligned with it, still above the first log line.
    expect(button.top, greaterThanOrEqualTo(copy.bottom - .5));
    expect((button.right - copy.right).abs(), lessThanOrEqualTo(1));
    expect(
      button.bottom,
      lessThan(tester.getRect(find.text('[oc] Installing opencode')).top),
    );
    // Never cut short: one line, no ellipsis.
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: words, matching: find.byType(RichText)).first,
    );
    expect(paragraph.didExceedMaxLines, isFalse);

    await tester.tap(find.byKey(const ValueKey('report')));
    await tester.pump();
    final call = _platform.lastWhere((c) => c.method == 'Clipboard.setData');
    expect((call.arguments as Map)['text'], 'the report');
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no extra action: the header shows only Wrap and Copy all', (
    tester,
  ) async {
    await _host(tester, KitLogPanel(lines: _lines()));
    expect(
      find.descendant(of: find.byKey(_panel), matching: find.byType(KitButton)),
      findsNothing,
    );
  });
}
