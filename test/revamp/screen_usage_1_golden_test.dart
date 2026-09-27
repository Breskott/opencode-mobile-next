// Golden renders of screen-usage-1's pages (wave 2b): Usage "Spent"
// (usage), its budget dialog and clear confirmation, and the Codex account
// (agent-account), rebuilt from kit parts. One render per state at the phone
// size (412x915) and the loaded state at one wide window (1280x800), dark and
// light (owner decision 2026-09-27: no Arabic), real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/screen_usage_1_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/agent_account.dart';
import 'package:opencode_mobile/state/agent_account.dart';
import 'package:opencode_mobile/ui/screens/agent_account_screen.dart';
import 'package:opencode_mobile/ui/screens/usage_screen.dart';

import '../../tool/capture/fixtures.dart' show loadCaptureFonts;
import '../support/account_fakes.dart';
import 'screen_usage_1_support.dart';

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

String _name(String state, Size size, bool light) => [
  state,
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

/// Pushes [page] over a blank route (so its bar has Back), runs [act],
/// settles and compares the whole window, all on a fixed clock.
Future<void> _shot(
  WidgetTester tester,
  String state,
  WidgetBuilder page, {
  required bool light,
  Size size = _phone,
  Future<void> Function(WidgetTester tester)? act,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  final boundary = GlobalKey();
  final navigator = GlobalKey<NavigatorState>();
  try {
    await withClock(Clock.fixed(usageNow), () async {
      await tester.pumpWidget(
        usageApp(
          const SizedBox.expand(),
          light: light,
          boundary: boundary,
          navigator: navigator,
        ),
      );
      unawaited(
        navigator.currentState!.push(MaterialPageRoute<void>(builder: page)),
      );
      await tester.pumpAndSettle();
      if (act != null) await act(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/${_name(state, size, light)}.png'),
      );
    });
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('usage-content')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _setBudget(WidgetTester tester, String amount) async {
  final row = find.byKey(const ValueKey('usage-budget-usd'));
  await _scrollTo(tester, row);
  await tester.tap(row);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('usage-budget-amount')),
    amount,
  );
  await tester.pump();
  await tester.tap(find.text('Save USD budget'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final theme = light ? 'light' : 'dark';

    group('usage', () {
      WidgetBuilder page({bool supported = true, bool empty = false}) {
        final h = usageHarness();
        h.repo.supported = supported;
        if (empty) h.repo.result = usageStats(empty: true);
        final screen = UsageScreen(
          controller: h.connection,
          overview: h.overview,
        );
        return (_) => screen;
      }

      testWidgets('loaded, $theme', (tester) async {
        await _shot(tester, 'usage_loaded', page(), light: light);
      });

      testWidgets('loaded at 1280x800, $theme', (tester) async {
        await _shot(tester, 'usage_loaded', page(), light: light, size: _wide);
      });

      testWidgets('budget reached, $theme', (tester) async {
        await _shot(
          tester,
          'usage_budget_reached',
          page(),
          light: light,
          act: (tester) async {
            await _setBudget(tester, '2.5');
            await _scrollTo(
              tester,
              find.byKey(const ValueKey('usage-budget-reached')),
            );
            // Bring the budget rows above the notice into view too.
            await tester.drag(
              find.byKey(const ValueKey('usage-content')),
              const Offset(0, 300),
            );
          },
        );
      });

      testWidgets('models, $theme', (tester) async {
        await _shot(
          tester,
          'usage_models',
          page(),
          light: light,
          act: (tester) =>
              _scrollTo(tester, find.byKey(const ValueKey('usage-search'))),
        );
      });

      testWidgets('empty range, $theme', (tester) async {
        await _shot(tester, 'usage_empty', page(empty: true), light: light);
      });

      testWidgets('unsupported, $theme', (tester) async {
        await _shot(
          tester,
          'usage_unsupported',
          page(supported: false),
          light: light,
        );
      });

      testWidgets('range picker, $theme', (tester) async {
        await _shot(
          tester,
          'usage_range_picker',
          page(),
          light: light,
          act: (tester) async {
            await tester.tap(find.text('Time range'));
            await tester.pumpAndSettle();
          },
        );
      });

      testWidgets('budget dialog, $theme', (tester) async {
        await _shot(
          tester,
          'usage_budget_dialog',
          page(),
          light: light,
          act: (tester) async {
            final row = find.byKey(const ValueKey('usage-budget-usd'));
            await _scrollTo(tester, row);
            await tester.tap(row);
            await tester.pumpAndSettle();
          },
        );
      });

      testWidgets('budget clear confirmation, $theme', (tester) async {
        await _shot(
          tester,
          'usage_budget_clear_dialog',
          page(),
          light: light,
          act: (tester) async {
            // Clear is offered only once a budget is set.
            await _setBudget(tester, '25');
            final row = find.byKey(const ValueKey('usage-budget-clear'));
            await _scrollTo(tester, row);
            await tester.tap(row);
            await tester.pumpAndSettle();
          },
        );
      });
    });

    group('agent account', () {
      setUp(mockSecureStorage);

      // The screen for the gate states; the panel it shows once bound for
      // the rest, with "Last checked" pinned (the controller stamps the
      // real time).
      WidgetBuilder page({
        bool accountEnabled = true,
        void Function(FakeAccountSession session)? prepare,
      }) {
        if (!accountEnabled) {
          final connection = accountConnection(accountEnabled: false);
          return (_) => AgentAccountScreen(connection: connection);
        }
        final session = FakeAccountSession();
        prepare?.call(session);
        final controller = AgentAccountController(session);
        addTearDown(controller.dispose);
        return (_) => _PinnedPanel(controller: controller);
      }

      testWidgets('signed out, $theme', (tester) async {
        await _shot(tester, 'agent_account_signed_out', page(), light: light);
      });

      testWidgets('sign-in code, $theme', (tester) async {
        await _shot(
          tester,
          'agent_account_code',
          page(),
          light: light,
          act: (tester) async {
            await tester.tap(
              find.byKey(const ValueKey('agent-account-sign-in')),
            );
            await tester.pumpAndSettle();
          },
        );
      });

      testWidgets('sign-in failed, $theme', (tester) async {
        late FakeAccountSession session;
        await _shot(
          tester,
          'agent_account_login_failed',
          page(prepare: (s) => session = s),
          light: light,
          act: (tester) async {
            await tester.tap(
              find.byKey(const ValueKey('agent-account-sign-in')),
            );
            await tester.pumpAndSettle();
            session.notifications.add(
              const AccountEvent(AccountEventKind.loginCompleted),
            );
            await tester.pumpAndSettle();
          },
        );
      });

      testWidgets('signed in, $theme', (tester) async {
        await _shot(
          tester,
          'agent_account_signed_in',
          page(prepare: signedIn),
          light: light,
        );
      });

      testWidgets('signed in at 1280x800, $theme', (tester) async {
        await _shot(
          tester,
          'agent_account_signed_in',
          page(prepare: signedIn),
          light: light,
          size: _wide,
        );
      });

      testWidgets('limit reached, $theme', (tester) async {
        await _shot(
          tester,
          'agent_account_limit_reached',
          page(prepare: (s) => signedIn(s, primaryPercent: 100)),
          light: light,
        );
      });

      testWidgets('not a Codex server, $theme', (tester) async {
        await _shot(
          tester,
          'agent_account_unsupported',
          page(accountEnabled: false),
          light: light,
        );
      });
    });
  }
}

/// Reads the account once, pins its "Last checked" time, then shows the
/// panel as AgentAccountScreen does.
class _PinnedPanel extends StatefulWidget {
  const _PinnedPanel({required this.controller});
  final AgentAccountController controller;
  @override
  State<_PinnedPanel> createState() => _PinnedPanelState();
}

class _PinnedPanelState extends State<_PinnedPanel> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_pin);
    unawaited(widget.controller.refresh());
  }

  void _pin() {
    if (widget.controller.updatedAt != null &&
        widget.controller.updatedAt != usageNow) {
      widget.controller.updatedAt = usageNow;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_pin);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AgentAccountPanel(
    controller: widget.controller,
    profileName: 'My Codex host',
  );
}
