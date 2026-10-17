import 'package:flutter/material.dart';
import 'package:opencode_mobile/domain/usage_subscriptions.dart';
import 'package:opencode_mobile/state/computer_usage_source.dart';
import 'package:opencode_mobile/ui/kit/kit_window_row.dart';
import 'package:opencode_mobile/ui/screens/usage/usage_add_picker_screen.dart';
import 'package:opencode_mobile/ui/screens/usage/usage_add_screen.dart';
import 'package:opencode_mobile/ui/screens/usage/usage_alerts_screen.dart';
import 'package:opencode_mobile/ui/screens/usage/usage_read_from_screen.dart';
import 'package:opencode_mobile/ui/screens/usage_widget_screen.dart';
import 'package:widgetbook/widgetbook.dart';

import '../catalog.dart';
import '../fakes/computer_usage_fakes.dart';
import '../fakes/fake_app.dart';
import 'package:opencode_mobile/state/usage_subscriptions_controller.dart';

import '../fakes/usage_harness.dart';

Future<UsageHarness> _withPlans({bool plans = true, bool? alertsOn}) async {
  final h = await usageHarness(
    result: usageResult(
      readings: [
        if (plans) ...[
          usageReading('codex', 'inapp', account: 'a'),
          usageReading('glm', 'inapp', account: 'b'),
        ],
      ],
    ),
  );
  await h.usage.refresh();
  if (alertsOn != null) await h.usage.setAlertsOn(alertsOn);
  return h;
}

Widget _alerts({required bool plans, bool alertsOn = true}) =>
    FakeAppScene<UsageHarness>(
      platform: FakePlatform.android,
      create: () => _withPlans(plans: plans, alertsOn: alertsOn),
      builder: (context, h) => UsageAlertsScreen(
        controller: h.connection,
        usage: h.usage,
        clock: () => usageNow,
      ),
    );

CatalogComponent usageAlertsPage() => catalogComponent(
  area: 'Usage',
  screen: 'UsageAlertsScreen',
  name: 'Alerts page',
  useCases: [
    WidgetbookUseCase(name: 'On', builder: (_) => _alerts(plans: true)),
    WidgetbookUseCase(
      name: 'Off',
      builder: (_) => _alerts(plans: true, alertsOn: false),
    ),
    WidgetbookUseCase(
      name: 'On, no plans yet',
      builder: (_) => _alerts(plans: false),
    ),
  ],
);

Widget _widgetSettings({required bool plans}) => FakeAppScene<UsageHarness>(
  create: () => _withPlans(plans: plans),
  builder: (context, h) =>
      UsageWidgetScreen(controller: h.connection, usage: h.usage),
);

CatalogComponent usageWidgetSettings() => catalogComponent(
  area: 'Usage',
  screen: 'UsageWidgetScreen',
  name: 'Widget settings',
  useCases: [
    WidgetbookUseCase(
      name: 'With plans',
      builder: (_) => _widgetSettings(plans: true),
    ),
    WidgetbookUseCase(
      name: 'No plans yet',
      builder: (_) => _widgetSettings(plans: false),
    ),
  ],
);

Widget _add(String provider) => FakeAppScene<UsageHarness>(
  create: () => usageHarness(connections: const [usageInApp, usagePc]),
  builder: (context, h) => UsageAddScreen(
    controller: h.connection,
    usage: h.usage,
    launcher: h.launcher,
    providerId: provider,
  ),
);

CatalogComponent usageAddPicker() => catalogComponent(
  area: 'Usage',
  screen: 'UsageAddPickerScreen',
  name: 'Add picker',
  useCases: [
    WidgetbookUseCase(
      name: 'Which provider',
      builder: (_) =>
          UsageAddPickerScreen(providerIds: usagePlanProviders, onPick: (_) {}),
    ),
  ],
);

CatalogComponent usageAddFlow() => catalogComponent(
  area: 'Usage',
  screen: 'UsageAddScreen',
  name: 'Add: where to sign in',
  useCases: [
    WidgetbookUseCase(
      name: 'Codex, two connections',
      builder: (_) => _add('codex'),
    ),
    WidgetbookUseCase(
      name: 'Nowhere to sign in (Claude)',
      builder: (_) => _add('claude'),
    ),
  ],
);

UsageSourceResult _signedInOnPc() => usageResult(
  signIns: [const UsageSignIn(providerId: 'codex', connectionId: 'pc')],
  authoritative: {'pc'},
);

Widget _readFrom(
  List<FakeStep> steps, {
  String? autoTap,
  bool alreadyOn = false,
}) => FakeAppScene<UsageHarness>(
  autoTap: autoTap,
  create: () async {
    final h = await usageHarness(
      connections: const [usageInApp, usagePc],
      result: _signedInOnPc(),
      prefs: {if (alreadyOn) 'oc.usageComputerReader.pc': true},
    );
    await h.usage.refresh();
    return h;
  },
  builder: (context, h) => UsageReadFromScreen(
    controller: h.connection,
    usage: h.usage,
    connectionId: 'pc',
    providerId: 'codex',
    computer: ComputerUsageSource(
      prefs: h.usage.prefs,
      profiles: () => h.connection.store.profiles,
      isReadable: (_) => true,
      isInApp: (_) => false,
      createPort: (_) => FakeComputerPort(steps),
      loadSource: () async => 'SCRIPT',
      timeout: const Duration(seconds: 2),
    ),
  ),
);

CatalogComponent usageReadFromPc() => catalogComponent(
  area: 'Usage',
  screen: 'UsageReadFromScreen',
  name: 'Read usage from PC',
  useCases: [
    WidgetbookUseCase(
      name: 'Off (explains the check)',
      builder: (_) => _readFrom(const []),
    ),
    WidgetbookUseCase(
      name: 'On, with results',
      builder: (_) => _readFrom([
        FakeStep(output: ['${computerLine(computerCodexOk)}\r\n']),
      ], autoTap: 'usage-read-from-set-up'),
    ),
    WidgetbookUseCase(
      name: 'On, no plan found',
      builder: (_) => _readFrom([
        FakeStep(output: ['${computerLine(computerAnswer())}\r\n']),
      ], autoTap: 'usage-read-from-set-up'),
    ),
    WidgetbookUseCase(
      name: 'Failed: PC needs Node.js 20 or later',
      builder: (_) => _readFrom([
        FakeStep(
          output: ['${computerLine(computerAnswer(error: 'nodeTooOld'))}\r\n'],
        ),
      ], autoTap: 'usage-read-from-set-up'),
    ),
    WidgetbookUseCase(
      name: 'Failed: PC not reachable',
      builder: (_) => _readFrom(const [
        FakeStep(startError: ComputerUsageProblem.unreachable),
      ], autoTap: 'usage-read-from-set-up'),
    ),
  ],
);

CatalogComponent kitWindowRow() => catalogComponent(
  area: 'Usage',
  folder: 'Kit parts',
  name: 'KitWindowRow',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final left = context.knobs.double.slider(
          label: 'left',
          initialValue: 0.82,
          min: 0,
          max: 1,
          divisions: 100,
          precision: 2,
        );
        final tone = context.knobs.object.dropdown<KitWindowTone>(
          label: 'tone',
          options: KitWindowTone.values,
          labelBuilder: (t) => t.name,
        );
        final title = context.knobs.string(
          label: 'title',
          initialValue: '5 hours',
        );
        final valueLabel = context.knobs.string(
          label: 'valueLabel',
          initialValue: '82% left · 14:10',
        );
        final note = context.knobs.stringOrNull(
          label: 'note',
          initialValue: 'Resets at Wed 1:59 AM, in 14 h',
        );
        return Padding(
          padding: const EdgeInsets.all(16),
          child: KitWindowRow(
            title: title,
            left: left,
            valueLabel: valueLabel,
            tone: tone,
            note: note,
          ),
        );
      },
    ),
  ],
);
