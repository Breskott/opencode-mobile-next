// KitLogPanel behaviour (docs/ux-system/kit-api/KitLogPanel.md "Tests
// required"): follow, polling only on screen, failed reads, redaction, copy,
// states, levels, the buffer, virtualisation, wrap, the live region, LTR
// body, reduced motion, the fold and overflow.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_bidi.dart';
import 'package:opencode_mobile/ui/kit/kit_jump_pill.dart';
import 'package:opencode_mobile/ui/kit/kit_log_panel.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';

import 'kit_motion_still.dart';

const _panel = ValueKey('kit-log-panel');
const _copyAll = ValueKey('kit-log-copy-all');
const _wrap = ValueKey('kit-log-wrap');

Key _line(int i) => ValueKey('kit-log-line-$i');

String _plain(String s) => s
    .replaceAll(KitBidi.lri, '')
    .replaceAll(KitBidi.fsi, '')
    .replaceAll(KitBidi.pdi, '');

Future<void> _host(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(412, 915),
  double textScale = 1,
  TextDirection? direction,
  bool reduced = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduced,
        ),
        child: direction == null
            ? child!
            : Directionality(textDirection: direction, child: child!),
      ),
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}

KitLogBuffer _buffer(int count, {String prefix = 'line'}) {
  final buffer = KitLogBuffer();
  for (var i = 0; i < count; i++) {
    buffer.add(KitLogLine('$prefix $i'));
  }
  return buffer;
}

bool _onScreen(WidgetTester tester, Finder finder) {
  if (finder.evaluate().isEmpty) return false;
  final rect = tester.getRect(finder);
  final panel = tester.getRect(find.byKey(_panel));
  return rect.bottom <= panel.bottom + 0.5 && rect.top >= panel.top - 0.5;
}

void main() {
  kitMotionStillTests(
    'KitLogPanel',
    builds: {
      'live': () {
        final buffer = _buffer(3);
        addTearDown(buffer.dispose);
        return KitLogPanel(lines: buffer, live: true);
      },
      'ended': () {
        final buffer = _buffer(3);
        addTearDown(buffer.dispose);
        return KitLogPanel(lines: buffer, ended: const KitLogEnd(exitCode: 0));
      },
    },
    changes: {
      'line arrives': KitMotionChange(
        build: () {
          final buffer = _buffer(2);
          addTearDown(buffer.dispose);
          return KitLogPanel(lines: buffer);
        },
        act: (tester, stage) async {
          final buffer =
              tester.widget<KitLogPanel>(find.byType(KitLogPanel)).lines
                  as KitLogBuffer;
          buffer.add(const KitLogLine('Review completed'));
        },
        shows: 'Review completed',
      ),
    },
  );

  late List<MethodCall> platform;
  late List<Map<Object?, Object?>> announcements;

  setUp(() {
    KitRedact.clearKnownSecrets();
    platform = [];
    announcements = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platform.add(call);
      return null;
    });
    messenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (message) async {
        final map = message as Map<Object?, Object?>;
        if (map['type'] == 'announce') announcements.add(map);
        return null;
      },
    );
  });

  tearDown(() {
    KitRedact.clearKnownSecrets();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      null,
    );
  });

  testWidgets('1 follows the newest line until scrolled up; the pill resumes', (
    tester,
  ) async {
    final buffer = _buffer(200);
    await _host(
      tester,
      KitLogPanel(lines: buffer, live: true, size: KitLogSize.fill),
    );
    await tester.pump();
    expect(_onScreen(tester, find.byKey(_line(199))), isTrue);

    buffer.add(const KitLogLine('line 200'));
    await tester.pump();
    await tester.pump();
    expect(_onScreen(tester, find.byKey(_line(200))), isTrue);

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pump();
    final offset = tester
        .state<ScrollableState>(find.byType(Scrollable).last)
        .position
        .pixels;
    for (var i = 0; i < 12; i++) {
      buffer.add(KitLogLine('more $i'));
    }
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).last)
          .position
          .pixels,
      offset,
    );
    expect(find.text('12 new lines'), findsOneWidget);

    await tester.tap(find.text('12 new lines'));
    await tester.pumpAndSettle();
    expect(_onScreen(tester, find.byKey(_line(212))), isTrue);
    buffer.add(const KitLogLine('after'));
    await tester.pump();
    await tester.pump();
    expect(_onScreen(tester, find.byKey(_line(213))), isTrue);
  });

  testWidgets('2 polls only while visible, never overlapping, until ended', (
    tester,
  ) async {
    var calls = 0;
    var ticker = true;
    late StateSetter setOuter;
    KitLogEnd? ended;
    Future<void> refresh() async => calls++;
    final buffer = _buffer(3);
    await _host(
      tester,
      StatefulBuilder(
        builder: (context, set) {
          setOuter = set;
          return TickerMode(
            enabled: ticker,
            child: KitLogPanel(
              lines: buffer,
              live: true,
              ended: ended,
              onRefresh: refresh,
            ),
          );
        },
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(calls, 2);

    setOuter(() => ticker = false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(calls, 2);
    setOuter(() => ticker = true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(calls, 3);

    // Another route covers the panel.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const SizedBox.expand()),
      ),
    );
    await tester.pumpAndSettle();
    final covered = calls;
    await tester.pump(const Duration(seconds: 6));
    expect(calls, covered);
    navigator.pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(calls, greaterThan(covered));

    // The app is paused.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final paused = calls;
    await tester.pump(const Duration(seconds: 6));
    expect(calls, paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));
    expect(calls, paused + 1);

    setOuter(() => ended = const KitLogEnd(exitCode: 0));
    await tester.pump();
    final done = calls;
    await tester.pump(const Duration(seconds: 6));
    expect(calls, done);
  });

  testWidgets('2b calls never overlap', (tester) async {
    var calls = 0;
    final pending = Completer<void>();
    await _host(
      tester,
      KitLogPanel(
        lines: _buffer(1),
        live: true,
        onRefresh: () {
          calls++;
          return pending.future;
        },
      ),
    );
    await tester.pump(const Duration(seconds: 10));
    expect(calls, 1);
    pending.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(calls, 2);
  });

  testWidgets(
    '3 a failed read keeps the lines, pauses, and Try again retries',
    (tester) async {
      var calls = 0;
      await _host(
        tester,
        KitLogPanel(
          lines: _buffer(3),
          live: true,
          onRefresh: () async {
            calls++;
            throw StateError('boom');
          },
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text("Couldn't read the output"), findsOneWidget);
      expect(find.byKey(_line(2)), findsOneWidget);
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 8));
      expect(calls, 1);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(calls, 2);
    },
  );

  testWidgets('4 lines are redacted on screen and in Copy all', (tester) async {
    final buffer = KitLogBuffer()
      ..add(const KitLogLine('key sk-ant-api03-AbCdEfGhIjKlMnOp'))
      ..add(const KitLogLine('Authorization: Bearer FAKEtokenFAKEtoken123'));
    await _host(tester, KitLogPanel(lines: buffer));
    expect(find.textContaining('AbCdEfGhIjKlMnOp'), findsNothing);
    expect(find.textContaining('FAKEtokenFAKEtoken123'), findsNothing);

    await tester.tap(find.byKey(_copyAll));
    await tester.pump();
    final call = platform.lastWhere((c) => c.method == 'Clipboard.setData');
    final text = (call.arguments as Map)['text'] as String;
    expect(text, isNot(contains('AbCdEfGhIjKlMnOp')));
    expect(text, isNot(contains('FAKEtokenFAKEtoken123')));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('5 Copy all copies the lines, announces once, no SnackBar', (
    tester,
  ) async {
    await _host(tester, KitLogPanel(lines: _buffer(3)));
    await tester.tap(find.byKey(_copyAll));
    await tester.pump();
    final call = platform.lastWhere((c) => c.method == 'Clipboard.setData');
    expect((call.arguments as Map)['text'], 'line 0\nline 1\nline 2');
    expect(announcements, hasLength(1));
    expect(announcements.single['data'], containsPair('message', 'Copied'));
    expect(find.byType(SnackBar), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('6 states: empty, live, quiet, failed', (tester) async {
    await _host(tester, KitLogPanel(lines: KitLogBuffer()));
    expect(find.text('No output yet'), findsOneWidget);

    final buffer = _buffer(2);
    await _host(tester, KitLogPanel(lines: buffer, live: true));
    expect(find.text('Live'), findsOneWidget);
    expect(find.byKey(const ValueKey('kit-log-live-dot')), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
    expect(find.text('Last line 8 s ago'), findsOneWidget);
    expect(find.byKey(const ValueKey('kit-log-live-dot')), findsNothing);

    await _host(
      tester,
      KitLogPanel(
        lines: buffer,
        live: true,
        ended: const KitLogEnd(exitCode: 1, failed: true),
      ),
    );
    final words = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => _plain(t.data ?? ''));
    expect(words, contains('Failed · exit 1'));
    expect(find.text('Live'), findsNothing);
    expect(find.byKey(const ValueKey('kit-log-live-dot')), findsNothing);
  });

  testWidgets('7 levels: glyph and text1 for errors, text2 for normal', (
    tester,
  ) async {
    final buffer = KitLogBuffer()
      ..add(const KitLogLine('ordinary [oc] line'))
      ..add(const KitLogLine('careful', level: KitLogLevel.warning))
      ..add(const KitLogLine('boom', level: KitLogLevel.error));
    await _host(tester, KitLogPanel(lines: buffer));
    final roles = ThemeRoles.resolve(AppTheme.dark());
    Color colour(String s) => tester.widget<Text>(find.text(s)).style!.color!;
    expect(colour('ordinary [oc] line'), roles.text2);
    expect(colour('careful'), roles.text1);
    expect(colour('boom'), roles.text1);
    for (final s in ['ordinary [oc] line', 'careful', 'boom']) {
      expect(
        colour(s),
        isNot(anyOf(roles.accent, roles.attention, roles.danger)),
      );
    }
    expect(
      find.descendant(
        of: find.byKey(_line(2)),
        matching: find.byIcon(AppIconography.error),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(_line(1)),
        matching: find.byIcon(AppIconography.warning),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Error: boom'), findsOneWidget);
    expect(find.bySemanticsLabel('Warning: careful'), findsOneWidget);
  });

  test(
    '8 KitLogBuffer splits chunks, keeps a partial line, drops and counts',
    () {
      final buffer = KitLogBuffer(capacity: 3);
      buffer.appendText('a\nb');
      expect(buffer.value.map((l) => l.text), ['a', 'b']);
      buffer.appendText('c\n');
      expect(buffer.value.map((l) => l.text), ['a', 'bc']);
      buffer.appendText('d\ne\nf\n');
      expect(buffer.value.map((l) => l.text), ['d', 'e', 'f']);
      expect(buffer.dropped, 2);
      buffer.replaceText('x\ny');
      expect(buffer.value.map((l) => l.text), ['x', 'y']);
      expect(buffer.dropped, 0);
      buffer.clear();
      expect(buffer.value, isEmpty);
    },
  );

  testWidgets('8b the panel shows the dropped row', (tester) async {
    final buffer = KitLogBuffer(capacity: 5);
    for (var i = 0; i < 1245; i++) {
      buffer.add(KitLogLine('l $i'));
    }
    await _host(tester, KitLogPanel(lines: buffer, follow: false));
    expect(find.byKey(const ValueKey('kit-log-dropped')), findsOneWidget);
    expect(find.text('1240 earlier lines not shown'), findsOneWidget);
  });

  testWidgets('9 2,000 lines build only the visible rows at one extent', (
    tester,
  ) async {
    final lines = _buffer(2000);
    await _host(
      tester,
      KitLogPanel(lines: lines, wrap: false, size: KitLogSize.fill),
    );
    final built = find.byWidgetPredicate((w) {
      final key = w.key;
      return key is ValueKey<String> && key.value.startsWith('kit-log-line-');
    });
    expect(built.evaluate().length, lessThan(100));
    final at1 = tester.getSize(built.first).height;
    expect(at1, 20);

    await _host(
      tester,
      KitLogPanel(lines: lines, wrap: false, size: KitLogSize.fill),
      textScale: 2,
    );
    final at2 = tester.getSize(built.first).height;
    expect(at2, greaterThan(at1));
    final heights = built
        .evaluate()
        .map((e) => tester.getSize(find.byWidget(e.widget)).height)
        .toSet();
    expect(heights, {at2});
  });

  testWidgets('10 wraps on compact, scrolls sideways wide, toggle flips', (
    tester,
  ) async {
    final long = 'x' * 300;
    final buffer = KitLogBuffer()..add(KitLogLine(long));
    await _host(tester, KitLogPanel(lines: buffer), size: const Size(360, 800));
    expect(tester.getSize(find.byKey(_line(0))).height, greaterThan(40));

    await _host(
      tester,
      KitLogPanel(lines: buffer),
      size: const Size(1280, 800),
    );
    expect(tester.getSize(find.byKey(_line(0))).height, 20);
    expect(
      tester.getSemantics(find.byKey(_wrap)),
      isSemantics(hasToggledState: true, isToggled: false),
    );
    await tester.tap(find.byKey(_wrap));
    await tester.pump();
    expect(tester.getSize(find.byKey(_line(0))).height, greaterThan(20));
    expect(
      tester.getSemantics(find.byKey(_wrap)),
      isSemantics(hasToggledState: true, isToggled: true),
    );
  });

  testWidgets('11 the header is the only live region; lines never announce', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final buffer = _buffer(2);
    await _host(tester, KitLogPanel(lines: buffer, live: true));
    final live = find.byWidgetPredicate(
      (w) => w is Semantics && (w.properties.liveRegion ?? false),
    );
    expect(live, findsOneWidget);
    final label = tester.widget<Semantics>(live).properties.label;
    expect(label, 'Live');
    buffer.add(const KitLogLine('new'));
    await tester.pump();
    expect(live, findsOneWidget);
    expect(tester.widget<Semantics>(live).properties.label, label);
    expect(announcements, isEmpty);
    handle.dispose();
  });

  testWidgets('12 the body is LTR and left-aligned under RTL', (tester) async {
    await _host(
      tester,
      KitLogPanel(lines: _buffer(1)),
      direction: TextDirection.rtl,
    );
    final panel = tester.getRect(find.byKey(_panel));
    final text = tester.getRect(find.text('line 0'));
    expect(text.left - panel.left, lessThan(panel.width / 4));
    expect(
      tester.widget<Text>(find.text('line 0')).textDirection,
      TextDirection.ltr,
    );
  });

  testWidgets('13 reduced motion: the pill jump settles after one pump', (
    tester,
  ) async {
    final buffer = _buffer(200);
    await _host(
      tester,
      KitLogPanel(lines: buffer, wrap: false, size: KitLogSize.fill),
      reduced: true,
    );
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pump();
    buffer.add(const KitLogLine('newest'));
    await tester.pump();
    await tester.tap(find.text('1 new line'));
    await tester.pump();
    expect(_onScreen(tester, find.byKey(_line(200))), isTrue);
    // Settled: the list rests at the newest end (no scroll animation left
    // to run) and the pill is already hidden.
    final position = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    expect(position.pixels, position.maxScrollExtent);
    expect(position.isScrollingNotifier.value, isFalse);
    expect(
      tester.widget<KitJumpPill>(find.byType(KitJumpPill)).visible,
      isFalse,
    );
  });

  testWidgets('14 fold: collapsed under Show output, opens the panel', (
    tester,
  ) async {
    await _host(
      tester,
      SingleChildScrollView(child: KitLogPanel.fold(lines: _buffer(3))),
    );
    expect(find.text('Show output'), findsOneWidget);
    expect(find.byKey(_panel), findsNothing);
    await tester.tap(find.text('Show output'));
    await tester.pumpAndSettle();
    expect(find.byKey(_panel), findsOneWidget);
  });

  testWidgets('15 a 500-character line never overflows', (tester) async {
    final buffer = KitLogBuffer()
      ..add(KitLogLine('${'y' * 500} end', level: KitLogLevel.error));
    for (final size in const [Size(320, 700), Size(412, 915)]) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        for (final dir in TextDirection.values) {
          for (final fill in [false, true]) {
            await _host(
              tester,
              KitLogPanel(
                lines: buffer,
                live: true,
                ended: const KitLogEnd(
                  exitCode: 1,
                  failed: true,
                  reason: 'The setup script stopped.',
                ),
                size: fill ? KitLogSize.fill : KitLogSize.folded,
              ),
              size: size,
              textScale: scale,
              direction: dir,
            );
            expect(
              tester.takeException(),
              isNull,
              reason: '$size $scale $dir $fill',
            );
          }
        }
      }
    }
  });
}
