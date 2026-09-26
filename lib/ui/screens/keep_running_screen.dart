import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../builtin/app_exit_recovery.dart' show appLifecycleBridgeProvider;
import '../../builtin/thermal_guard.dart';
import '../../builtin/thermal_guard_teams.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/app_exit.dart';
import '../../platform/keep_alive_advice.dart';
import '../app_theme.dart';
import '../kit/kit.dart';

Future<void> openKeepRunningScreen(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const KeepRunningScreen()));

/// The step's words for [maker]'s phones.
({String title, String detail}) keepAliveStepText(
  AppLocalizations l10n,
  KeepAliveStep step,
  PhoneMaker maker, {
  bool batteryAllowed = false,
}) => switch (step.kind) {
  KeepAliveStepKind.battery => (
    title: l10n.keepRunningBatteryTitle,
    detail: batteryAllowed
        ? l10n.keepRunningBatteryDone
        : l10n.keepRunningBatteryDetail,
  ),
  KeepAliveStepKind.lockInRecents => (
    title: l10n.keepRunningLockTitle,
    detail: switch (maker) {
      PhoneMaker.nubia => l10n.keepRunningLockNubia,
      PhoneMaker.samsung => l10n.keepRunningLockSamsung,
      _ => l10n.keepRunningLockOther,
    },
  ),
  KeepAliveStepKind.autostart => (
    title: l10n.keepRunningAutostartTitle,
    detail: maker == PhoneMaker.huawei
        ? l10n.keepRunningAutostartHuawei
        : l10n.keepRunningAutostartDetail,
  ),
  KeepAliveStepKind.background => (
    title: l10n.keepRunningBackgroundTitle,
    detail: switch (maker) {
      PhoneMaker.xiaomi => l10n.keepRunningBackgroundXiaomi,
      PhoneMaker.oppo => l10n.keepRunningBackgroundOppo,
      PhoneMaker.vivo => l10n.keepRunningBackgroundVivo,
      PhoneMaker.samsung => l10n.keepRunningBackgroundSamsung,
      _ => l10n.keepRunningBackgroundOther,
    },
  ),
};

/// Settings › Keep running in the background: what to allow on this phone
/// so Android leaves the app (and the OpenCode and AI Team inside it)
/// running. Reached from the Settings row and from the notice after Android
/// closed the app; it never opens by itself.
class KeepRunningScreen extends ConsumerStatefulWidget {
  const KeepRunningScreen({super.key});

  @override
  ConsumerState<KeepRunningScreen> createState() => _KeepRunningScreenState();
}

class _KeepRunningScreenState extends ConsumerState<KeepRunningScreen>
    with WidgetsBindingObserver {
  KeepAliveInfo? _info;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from a settings screen: the battery switch may have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  Future<void> _load() async {
    final info = await ref.read(appLifecycleBridgeProvider).keepAliveInfo();
    if (mounted) setState(() => _info = info);
  }

  Future<void> _open(KeepAliveSetting setting) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = lookupAppLocalizations(
      Localizations.localeOf(context),
    ).keepRunningOpenFailed;
    final opened = await ref
        .read(appLifecycleBridgeProvider)
        .openKeepAliveSetting(setting);
    if (!opened) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final theme = Theme.of(context);
    final info = _info;
    final maker = info == null
        ? PhoneMaker.other
        : PhoneMaker.of(info.manufacturer, info.brand);
    final makerName = (info?.manufacturer.trim().isNotEmpty ?? false)
        ? info!.manufacturer.trim()
        : l10n.keepRunningThisPhone;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: AppTheme.mutedOf(theme),
      height: 1.4,
    );
    Widget rails(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.keepRunningTitle)),
      body: KitScreen(
        loading: info == null,
        loadingLabel: l10n.keepRunningTitle,
        body: info == null
            ? const SizedBox.shrink()
            : ListView(
                padding: EdgeInsets.only(
                  top: 16,
                  bottom: KitScreen.endPadding(context),
                ),
                children: [
                  rails(
                    Text(
                      l10n.keepRunningIntro(makerName),
                      key: const ValueKey('keep-running-intro'),
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ),
                  if (maker.closesOnSwipe) ...[
                    const SizedBox(height: 12),
                    rails(
                      KitNotice(
                        key: const ValueKey('keep-running-swipe'),
                        tone: AppStatusTone.attention,
                        message: l10n.keepRunningSwipeWarning,
                        liveRegion: false,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  for (final step in keepAliveSteps(maker))
                    _stepRow(context, l10n, step, maker, info),
                  _ThermalGuardRow(l10n: l10n),
                  const SizedBox(height: 16),
                  rails(Text(l10n.keepRunningFootnote, style: muted)),
                ],
              ),
      ),
    );
  }

  Widget _stepRow(
    BuildContext context,
    AppLocalizations l10n,
    KeepAliveStep step,
    PhoneMaker maker,
    KeepAliveInfo info,
  ) {
    final allowed =
        step.kind == KeepAliveStepKind.battery &&
        info.batteryOptimizationIgnored;
    final text = keepAliveStepText(l10n, step, maker, batteryAllowed: allowed);
    final icon = switch (step.kind) {
      KeepAliveStepKind.battery =>
        allowed
            ? AppIconography.batteryCharging
            : AppIconography.batteryWarning,
      KeepAliveStepKind.lockInRecents => AppIconography.locked,
      KeepAliveStepKind.autostart => AppIconography.launch,
      KeepAliveStepKind.background => AppIconography.sync,
    };
    final setting = step.setting;
    final opens = setting != null && !allowed;
    return KitRow(
      key: ValueKey('keep-running-${step.kind.name}'),
      leading: KitRow.icon(
        context,
        icon,
        color: allowed ? AppTheme.successOf(Theme.of(context)) : null,
      ),
      title: text.title,
      titleMaxLines: 2,
      supporting: TextSpan(text: text.detail),
      supportingMaxLines: 4,
      trailing: allowed
          ? const SizedBox.square(
              dimension: 48,
              child: Icon(AppIconography.check, size: 20),
            )
          : opens
          ? Tooltip(
              message: l10n.keepRunningOpen,
              child: const SizedBox.square(
                dimension: 48,
                child: Icon(AppIconography.externalLink, size: 20),
              ),
            )
          : null,
      onTap: opens ? () => unawaited(_open(setting)) : null,
    );
  }
}

/// "Pause the AI Team when the phone is hot" (on by default): Android keeps
/// a hot phone running but slow, so the guard pauses the team instead and
/// resumes it once the phone has cooled. Only where the guard runs.
class _ThermalGuardRow extends ConsumerWidget {
  const _ThermalGuardRow({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<ThermalGuard?>(
      valueListenable: ref.watch(thermalGuardSlotProvider),
      builder: (context, guard, _) {
        if (guard == null) return const SizedBox.shrink();
        return ListenableBuilder(
          listenable: guard,
          builder: (context, _) => KitSwitchRow(
            key: const ValueKey('keep-running-thermal'),
            switchKey: const ValueKey('keep-running-thermal-switch'),
            leading: KitRow.icon(context, AppIconography.pause),
            title: l10n.thermalGuardSetting,
            supporting: l10n.thermalGuardSettingDetail,
            value: guard.enabled,
            onChanged: (value) => unawaited(guard.setEnabled(value)),
          ),
        );
      },
    );
  }
}
