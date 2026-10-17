import 'package:flutter/widgets.dart';
import 'package:opencode_mobile/domain/usage_subscriptions.dart';
import 'package:opencode_mobile/ui/screens/usage_hub_screen.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:opencode_mobile/state/usage_subscriptions_controller.dart';

import '../fakes/usage_harness.dart';
import '../catalog.dart';
import '../fakes/fake_app.dart';

Widget _hub(BuildContext context, UsageHarness h) => UsageHubScreen(
  controller: h.connection,
  usage: h.usage,
  launcher: h.launcher,
  clock: () => usageNow,
  prepare: false,
);

Widget _scene(Future<UsageHarness> Function() create) =>
    FakeAppScene<UsageHarness>(create: create, builder: _hub);

const _pcSignedInCodex = UsageSignIn(
  providerId: 'codex',
  connectionId: 'pc',
  displayName: 'Codex',
);

CatalogComponent usagePlansPage() => catalogComponent(
  area: 'Usage',
  screen: 'UsageHubScreen',
  name: 'Plans page',
  useCases: [
    WidgetbookUseCase(
      name: 'Loading',
      builder: (_) => _scene(() => usageHarness(hold: true)),
    ),
    WidgetbookUseCase(
      name: 'Empty (nothing signed in)',
      builder: (_) => _scene(usageHarness),
    ),
    WidgetbookUseCase(
      name: 'One plan, 5 hours and week',
      builder: (_) => _scene(
        () => usageHarness(
          result: usageResult(
            readings: [
              usageReading('codex', 'inapp', account: 'a', plan: 'plus'),
            ],
          ),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Several: Codex near limit, GLM ok, MiniMax out',
      builder: (_) => _scene(
        () => usageHarness(
          result: usageResult(
            readings: [
              usageReading(
                'codex',
                'inapp',
                account: 'a',
                plan: 'plus',
                windows: usageBoth(five: 88, week: 86),
              ),
              usageReading('glm', 'inapp', account: 'b', plan: 'pro'),
              usageReading(
                'minimax',
                'inapp',
                account: 'c',
                windows: usageBoth(five: 100, week: 64),
              ),
            ],
          ),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Setup: Sign in and Add key',
      builder: (_) => _scene(
        () => usageHarness(
          result: usageResult(
            readings: [
              usageReading(
                'codex',
                'inapp',
                status: UsageReadingStatus.notSignedIn,
              ),
              usageReading(
                'glm',
                'inapp',
                status: UsageReadingStatus.notSignedIn,
              ),
            ],
          ),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Setup: Read usage (signed in on a PC)',
      builder: (_) => _scene(
        () => usageHarness(
          connections: const [usageInApp, usagePc],
          result: usageResult(
            signIns: const [_pcSignedInCodex],
            authoritative: {'pc'},
          ),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Setup: sign-in ran out (Sign in again)',
      builder: (_) => _scene(
        () => usageHarness(
          connections: const [usageInApp, usagePc],
          result: usageResult(
            readings: [
              usageReading(
                'codex',
                'pc',
                account: 'a',
                status: UsageReadingStatus.authRequired,
              ),
            ],
          ),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Offline: old numbers kept',
      builder: (_) => _scene(() async {
        final h = await usageHarness(
          connections: const [usageInApp, usagePc],
          result: usageResult(
            readings: [
              usageReading(
                'codex',
                'pc',
                account: 'a',
                age: const Duration(hours: 3),
                windows: usageBoth(five: 60, week: 30),
              ),
            ],
          ),
        );
        await h.usage.refresh();
        h.source.result = usageResult(unreached: {'pc'});
        await h.usage.refresh(force: true);
        return h;
      }),
    ),
    WidgetbookUseCase(
      name: 'Reader broken (Try again)',
      builder: (_) => _scene(() async {
        final h = await usageHarness(
          result: usageResult(
            readings: [usageReading('codex', 'inapp', account: 'a')],
          ),
        );
        await h.usage.refresh();
        h.source.result = const UsageSourceResult(
          failures: [UsageFailure('inapp', 'codex', UsageProblem.broken)],
        );
        await h.usage.refresh(force: true);
        return h;
      }),
    ),
  ],
);
