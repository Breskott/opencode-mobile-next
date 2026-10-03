// KitReceipt (docs/ux-system/kit-api/KitReceipt.md, K2 §1.16): what
// happened to a write the phone sent, as a mark and a word, with the
// automatic-action line (KitAutoLine, AUTO-4). Time runs on the fake clock
// testWidgets already drives, through KitSince (C12, C25).
//
// Announcements are counted on the semantics updates the framework sends to
// the engine (the pattern of kit_notice_live_region_test.dart): a label a
// live-region node is sent that differs from the one it was last sent is
// what Android's live region announces.
import 'kit_motion_still.dart';

import 'dart:ui' as ui;

import 'package:clock/clock.dart';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_receipt.dart';
import 'package:opencode_mobile/ui/kit/kit_row.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';
import 'package:opencode_mobile/ui/widgets/team_receipt.dart';

/// Every `updateNode` the framework sent: the node id and its label.
final List<(int, String)> _sent = [];

class _SpyBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() => _SpyBuilder();
}

class _SpyBuilder implements ui.SemanticsUpdateBuilder {
  final ui.SemanticsUpdateBuilder _real = ui.SemanticsUpdateBuilder();

  @override
  ui.SemanticsUpdate build() => _real.build();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final named = invocation.namedArguments;
    switch (invocation.memberName) {
      case #updateNode:
        _sent.add((named[#id]! as int, named[#label]! as String));
        return Function.apply(_real.updateNode, const [], named);
      case #updateCustomAction:
        return Function.apply(_real.updateCustomAction, const [], named);
    }
    return super.noSuchMethod(invocation);
  }
}

Widget _app(Widget child, {bool reduced = false}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, inner) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
    child: inner!,
  ),
  home: Scaffold(body: Center(child: child)),
);

/// Every visible run of text, without the bidi isolates KitBidi adds.
String _visible(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((t) => t.text.toPlainText().replaceAll(_isolates, ''))
    // Icons draw as a one-glyph RichText in the private use area.
    .where((text) => text.trim().isNotEmpty && !_iconGlyph.hasMatch(text))
    .join(' | ');

/// KitBidi's isolate marks (LRI, RLI, FSI, PDI).
final _isolates = RegExp('[\\u2066-\\u2069]');

final _iconGlyph = RegExp('^[\\ue000-\\uf8ff]\$');

/// The ids of the live-region nodes in the current tree.
Set<int> _liveIds(WidgetTester tester) {
  final ids = <int>{};
  void visit(SemanticsNode node) {
    if (node.getSemanticsData().flagsCollection.isLiveRegion) ids.add(node.id);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  var root = tester.getSemantics(find.byType(Scaffold));
  while (root.parent != null) {
    root = root.parent!;
  }
  visit(root);
  return ids;
}

/// The labels of the live-region nodes in the current tree.
List<String> _liveLabels(WidgetTester tester) {
  final labels = <String>[];
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (data.flagsCollection.isLiveRegion) labels.add(data.label);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  var root = tester.getSemantics(find.byType(Scaffold));
  while (root.parent != null) {
    root = root.parent!;
  }
  visit(root);
  return labels;
}

/// Tracks what the platform announces across pumps.
class _Announcer {
  _Announcer() {
    _sent.clear();
  }

  final Map<int, String> _last = {};

  /// Labels sent since the last call that changed a live-region node.
  List<String> take(WidgetTester tester) {
    final live = _liveIds(tester);
    final announced = <String>[];
    for (final (id, label) in _sent) {
      if (!live.contains(id)) continue;
      if (_last[id] != label) announced.add(label);
      _last[id] = label;
    }
    _sent.clear();
    return announced;
  }
}

void main() {
  _SpyBinding();

  kitMotionStillTests(
    'KitReceipt',
    builds: {
      for (final state in KitReceiptState.values)
        state.name: () => KitReceipt(
          state: state,
          reason: 'Access changed',
          where: 'another device',
        ),
    },
    changes: {
      'server confirms': KitMotionChange(
        build: () => const KitReceipt(state: KitReceiptState.sending),
        act: (tester, stage) =>
            stage.rebuild(const KitReceipt(state: KitReceiptState.confirmed)),
        shows: 'Done',
      ),
    },
  );

  group('every state', () {
    const cases = <(KitReceiptState, String, IconData?)>[
      (KitReceiptState.sent, 'Sent', AppIconography.check),
      (KitReceiptState.confirmed, 'Done', AppIconography.check),
      (
        KitReceiptState.notConfirmed,
        'Not confirmed yet',
        AppIconography.warning,
      ),
      (KitReceiptState.refused, 'Not accepted', AppIconography.error),
      (
        KitReceiptState.answeredElsewhere,
        'Answered on the laptop',
        AppIconography.check,
      ),
    ];
    for (final (state, word, icon) in cases) {
      testWidgets('${state.name} renders "$word" and its mark', (tester) async {
        await tester.pumpWidget(
          _app(KitReceipt(state: state, where: 'the laptop')),
        );
        await tester.pumpAndSettle();
        expect(_visible(tester), word);
        expect(find.byIcon(icon!), findsOneWidget);
        if (state == KitReceiptState.sent) {
          expect(find.textContaining('Done'), findsNothing);
        }
      });
    }

    testWidgets('marks carry the spec colours', (tester) async {
      final roles = AppTheme.rolesOf(AppTheme.dark());
      Future<Color?> colour(KitReceiptState state) async {
        await tester.pumpWidget(_app(KitReceipt(state: state)));
        await tester.pumpAndSettle();
        return tester.widget<Icon>(find.byType(Icon)).color;
      }

      expect(await colour(KitReceiptState.sent), roles.text2);
      expect(await colour(KitReceiptState.confirmed), roles.success);
      expect(await colour(KitReceiptState.notConfirmed), roles.text1);
      expect(await colour(KitReceiptState.refused), roles.text1);
    });

    testWidgets('sending shows a working ring', (tester) async {
      await tester.pumpWidget(
        _app(const KitReceipt(state: KitReceiptState.sending)),
      );
      await tester.pump();
      expect(_visible(tester), 'Sending…');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('a sent receipt with a label never says the act', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const KitReceipt(state: KitReceiptState.sent, label: 'Allowed once'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_visible(tester), 'Sent');
    });

    testWidgets('confirmed with a label says the act', (tester) async {
      await tester.pumpWidget(
        _app(
          const KitReceipt(
            state: KitReceiptState.confirmed,
            label: 'Allowed once',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_visible(tester), 'Allowed once');
    });
  });

  group('escalation (STATE-5, STATE-10)', () {
    testWidgets('sent turns into Not confirmed yet at 8 s, announced once', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final announcer = _Announcer();
      var retries = 0;
      final since = clock.now().subtract(const Duration(seconds: 7));
      await tester.pumpWidget(
        _app(
          KitReceipt(
            state: KitReceiptState.sent,
            since: since,
            onRetry: () => retries++,
          ),
        ),
      );
      await tester.pump();
      expect(_visible(tester), 'Sent');
      expect(find.text('Try again'), findsNothing);
      announcer.take(tester);

      await tester.pump(const Duration(milliseconds: 900));
      expect(_visible(tester), 'Sent', reason: 'still sent at 7.9 s');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(_visible(tester), contains('Not confirmed yet'));
      expect(find.text('Try again'), findsOneWidget);
      expect(announcer.take(tester), ['Not confirmed yet']);

      await tester.tap(find.text('Try again'));
      expect(retries, 1);
      semantics.dispose();
    });

    testWidgets('sending with since escalates too', (tester) async {
      await tester.pumpWidget(
        _app(
          KitReceipt(
            state: KitReceiptState.sending,
            since: clock.now().subtract(const Duration(seconds: 9)),
            onRetry: () {},
          ),
          reduced: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(_visible(tester), contains('Not confirmed yet'));
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('confirmed never escalates', (tester) async {
      await tester.pumpWidget(
        _app(
          KitReceipt(
            state: KitReceiptState.confirmed,
            since: clock.now().subtract(const Duration(seconds: 20)),
            onRetry: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 30));
      expect(_visible(tester), 'Done');
      expect(find.text('Try again'), findsNothing);
    });
  });

  testWidgets('announcements: three transitions, three announcements; a '
      'rebuild with the same state none (A11Y-3)', (tester) async {
    final semantics = tester.ensureSemantics();
    final announcer = _Announcer();
    Future<List<String>> show(KitReceiptState state) async {
      await tester.pumpWidget(_app(KitReceipt(state: state), reduced: true));
      await tester.pumpAndSettle();
      return announcer.take(tester);
    }

    expect(await show(KitReceiptState.sending), ['Sending…']);
    expect(await show(KitReceiptState.sent), ['Sent']);
    expect(await show(KitReceiptState.confirmed), ['Done']);
    expect(await show(KitReceiptState.confirmed), isEmpty);
    expect(await show(KitReceiptState.confirmed), isEmpty);
    expect(_liveIds(tester), hasLength(1), reason: 'one live region');
    semantics.dispose();
  });

  testWidgets('Undo shows until at + 8 s and calls onUndo once', (
    tester,
  ) async {
    var undos = 0;
    await tester.pumpWidget(
      _app(
        KitReceipt(
          state: KitReceiptState.confirmed,
          at: clock.now(),
          onUndo: () => undos++,
          undoKey: const ValueKey('undo'),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('undo')));
    expect(undos, 1);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsNothing);
    expect(undos, 1);
  });

  testWidgets('Undo is never offered on a receipt that is not confirmed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        KitReceipt(state: KitReceiptState.sent, at: clock.now(), onUndo: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('refused names the reason; answered elsewhere the device', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const KitReceipt(
          state: KitReceiptState.refused,
          reason: 'the run already finished',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_visible(tester), 'Not accepted: the run already finished');

    await tester.pumpWidget(
      _app(
        const KitReceipt(
          state: KitReceiptState.answeredElsewhere,
          where: 'the laptop',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_visible(tester), 'Answered on the laptop');
  });

  testWidgets('answered elsewhere with no device says "another device"', (
    tester,
  ) async {
    late BuildContext context;
    for (final where in const [null, '  ']) {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (inner) {
              context = inner;
              return KitReceipt(
                state: KitReceiptState.answeredElsewhere,
                where: where,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_visible(tester), 'Answered on another device');
      expect(find.textContaining('…'), findsNothing);
      expect(
        KitReceipt.span(
          context,
          KitReceiptState.answeredElsewhere,
          where: where,
        ).toPlainText(),
        'Answered on another device · ',
      );
    }
  });

  testWidgets('semantics: word, reason and time; the mark is excluded', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final at = clock.now();
    await tester.pumpWidget(
      _app(
        KitReceipt(
          state: KitReceiptState.refused,
          reason: 'the run already finished',
          at: at,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(KitReceipt));
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(at));
    final label = _liveLabels(tester).single.replaceAll(_isolates, '');
    expect(label, 'Not accepted, the run already finished, at $time');
    semantics.dispose();
  });

  testWidgets('automatic: "{label} at {time}" with Undo (KitAutoLine)', (
    tester,
  ) async {
    final at = clock.now();
    var undos = 0;
    await tester.pumpWidget(
      _app(
        KitReceipt(
          state: KitReceiptState.confirmed,
          automatic: true,
          label: "Restarted the phone's server",
          at: at,
          onUndo: () => undos++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(KitReceipt));
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(at));
    expect(_visible(tester), "Restarted the phone's server at $time · | Undo");
    await tester.tap(find.text('Undo'));
    expect(undos, 1);
  });

  testWidgets('automatic names the act in every state, beside the state\'s '
      'own mark', (tester) async {
    final roles = AppTheme.rolesOf(AppTheme.dark());
    final at = clock.now();
    late String time;
    Future<void> show(KitReceiptState state, {String? reason}) async {
      await tester.pumpWidget(
        _app(
          KitReceipt(
            state: state,
            automatic: true,
            label: "Restarted the phone's server",
            reason: reason,
            at: at,
            onUndo: () {},
            onRetry: () {},
          ),
        ),
      );
      await tester.pump();
      final context = tester.element(find.byType(KitReceipt));
      time = MaterialLocalizations.of(
        context,
      ).formatTimeOfDay(TimeOfDay.fromDateTime(at));
    }

    // Sent: the act, the sent check in text2 (never the success check), no
    // Undo (STATE-10: sent is not done).
    await show(KitReceiptState.sent);
    expect(_visible(tester), "Restarted the phone's server at $time");
    expect(tester.widget<Icon>(find.byType(Icon)).color, roles.text2);
    expect(find.text('Sent'), findsNothing);
    expect(find.text('Undo'), findsNothing);

    // Not confirmed: the act, the warning mark, and the state's Try again.
    await show(KitReceiptState.notConfirmed);
    expect(
      _visible(tester),
      "Restarted the phone's server at $time · | Try again",
    );
    expect(find.byIcon(AppIconography.warning), findsOneWidget);
    expect(find.text('Not confirmed yet'), findsNothing);

    // Refused: the act and the server's reason, the error mark.
    await show(KitReceiptState.refused, reason: 'the server is busy');
    expect(
      _visible(tester),
      "Restarted the phone's server: the server is busy at $time",
    );
    expect(find.byIcon(AppIconography.error), findsOneWidget);
  });

  testWidgets('span: the same words, no actions', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (inner) {
            context = inner;
            return KitRow(
              title: 'Approve the migration',
              supporting: KitReceipt.span(
                inner,
                KitReceiptState.refused,
                reason: 'the run already finished',
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    String plain(InlineSpan span) =>
        span.toPlainText().replaceAll(_isolates, '');
    expect(plain(KitReceipt.span(context, KitReceiptState.sent)), 'Sent · ');
    expect(
      plain(KitReceipt.span(context, KitReceiptState.notConfirmed)),
      'Not confirmed yet · ',
    );
    expect(
      plain(
        KitReceipt.span(
          context,
          KitReceiptState.answeredElsewhere,
          where: 'the laptop',
        ),
      ),
      'Answered on the laptop · ',
    );
    expect(
      plain(
        KitReceipt.span(
          context,
          KitReceiptState.confirmed,
          label: 'Allowed once',
        ),
      ),
      'Allowed once · ',
    );
    expect(
      _visible(tester),
      contains('Not accepted: the run already finished'),
    );
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('onTap makes the words one button', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(KitReceipt(state: KitReceiptState.sent, onTap: () => taps++)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(KitReceipt));
    expect(taps, 1);
  });

  testWidgets('onTap: keyboard focus draws the kit ring and Enter taps', (
    tester,
  ) async {
    final roles = AppTheme.rolesOf(AppTheme.dark());
    var taps = 0;
    await tester.pumpWidget(
      _app(KitReceipt(state: KitReceiptState.sent, onTap: () => taps++)),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(KitReceipt));
    final width = KitTokens.focusRingWidth(context);
    bool ringed() => tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(KitReceipt),
            matching: find.byType(DecoratedBox),
          ),
        )
        .any((box) {
          final decoration = box.decoration;
          if (decoration is! BoxDecoration) return false;
          final border = decoration.border;
          return border is Border &&
              border.top.color == roles.accent &&
              border.top.width == width;
        });

    expect(ringed(), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(ringed(), isTrue, reason: 'keyboard focus shows the ring');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('actions are 48 dp targets', (tester) async {
    await tester.pumpWidget(
      _app(
        KitReceipt(
          state: KitReceiptState.notConfirmed,
          onRetry: () {},
          retryKey: const ValueKey('retry'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('retry'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('200 % text wraps, never truncates, and stays in bounds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 800),
          textScaler: TextScaler.linear(2),
        ),
        child: _app(
          KitReceipt(
            state: KitReceiptState.refused,
            reason: 'the run already finished before the answer arrived',
            onRetry: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      _visible(tester),
      'Not accepted: the run already finished before the answer arrived',
    );
  });

  testWidgets('reduced motion: sending is a still dot and settles', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const KitReceipt(state: KitReceiptState.sending), reduced: true),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(AppIconography.statusDot), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  // slice-close-team: a gate row's receipt is a word and its mark in the
  // row's supporting line (never a trailing chip), so the row keeps its
  // chevron and the row itself opens the gate, where Try again lives.
  group('teamGateRowLine', () {
    MutationRecord record(MutationStatus status) => MutationRecord(
      key: 'r-1',
      request: MutationRequest.message('mayor', 'Add dark mode'),
      createdAt: DateTime.utc(2026, 9, 27),
      status: status,
    );

    Future<String> line(WidgetTester tester, MutationRecord? r) async {
      late InlineSpan span;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              span = teamGateRowLine(context, const [
                'Question',
                'Add dark mode',
                '2m ago',
              ], record: r);
              return Text.rich(span);
            },
          ),
        ),
      );
      await tester.pump();
      // The mark is a WidgetSpan: one object-replacement character.
      return span.toPlainText().replaceAll('\uFFFC', '<mark>');
    }

    testWidgets('no record or a confirmed one: the plain line', (tester) async {
      expect(await line(tester, null), 'Question · Add dark mode · 2m ago');
      expect(
        await line(tester, record(MutationStatus.confirmed)),
        'Question · Add dark mode · 2m ago',
      );
    });

    testWidgets('the receipt word follows the first part, with its mark', (
      tester,
    ) async {
      for (final (status, word) in const [
        (MutationStatus.sent, 'Sending…'),
        (MutationStatus.unconfirmed, 'Not confirmed yet'),
        (MutationStatus.rejected, 'Not accepted'),
      ]) {
        expect(
          await line(tester, record(status)),
          'Question · <mark>$word · Add dark mode · 2m ago',
        );
      }
      // A mark inside text never spins.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    // The line wraps inside a row at large text on a 360 dp phone.
    for (final scale in const [1.3, 2.0]) {
      testWidgets('fits a KitRow at 360 dp, text x$scale', (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: const Size(360, 800),
              textScaler: TextScaler.linear(scale),
            ),
            child: _app(
              Builder(
                builder: (context) => KitRow(
                  leading: KitRow.icon(context, AppIconography.warning),
                  title:
                      'Approve the database migration for the release '
                      'branch before the nightly run',
                  titleMaxLines: 2,
                  supporting: teamGateRowLine(context, const [
                    'Approval',
                    '2m ago',
                  ], record: record(MutationStatus.unconfirmed)),
                  supportingMaxLines: 2,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
