import 'package:flutter/widgets.dart';
import 'package:opencode_mobile/domain/usage_subscriptions.dart';
import 'package:opencode_mobile/ui/screens/usage/usage_subscription_screen.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:opencode_mobile/state/usage_subscriptions_controller.dart';

import '../fakes/usage_harness.dart';
import '../catalog.dart';
import '../fakes/fake_app.dart';

Widget _scene(String key, Future<UsageHarness> Function() create) =>
    FakeAppScene<UsageHarness>(
      create: () async {
        final h = await create();
        await h.usage.refresh();
        return h;
      },
      builder: (context, h) => UsageSubscriptionScreen(
        controller: h.connection,
        usage: h.usage,
        subscriptionKey: key,
        launcher: h.launcher,
        clock: () => usageNow,
      ),
    );

CatalogComponent usageSubscriptionPage() => catalogComponent(
  area: 'Usage',
  screen: 'UsageSubscriptionScreen',
  name: 'Plan page',
  useCases: [
    WidgetbookUseCase(
      name: 'GLM with 3 windows',
      builder: (_) => _scene(
        'glm|g',
        () => usageHarness(
          result: usageResult(
            readings: [
              usageReading(
                'glm',
                'inapp',
                account: 'g',
                plan: 'pro',
                windows: [
                  ...usageBoth(five: 22, week: 47),
                  UsageWindow(id: 'mcp', usedPercent: 10),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Codex, weekly only',
      builder: (_) => _scene(
        'codex|a',
        () => usageHarness(
          result: usageResult(
            readings: [
              usageReading(
                'codex',
                'inapp',
                account: 'a',
                plan: 'plus',
                windows: [
                  usageWindow(
                    'secondary',
                    41,
                    604800,
                    resetIn: const Duration(days: 2),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Cannot be read: sign-in ran out',
      builder: (_) => _scene(
        'codex|a',
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
      name: 'Cannot be read: reader broken',
      builder: (_) => _scene('codex|a', () async {
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
    WidgetbookUseCase(
      name: 'Several connections (where it is signed in)',
      builder: (_) => _scene(
        'codex|a',
        () => usageHarness(
          connections: const [usageInApp, usagePc],
          result: usageResult(
            readings: [
              usageReading('codex', 'inapp', account: 'a', plan: 'plus'),
              usageReading('codex', 'pc', account: 'a', plan: 'plus'),
            ],
          ),
        ),
      ),
    ),
  ],
);
