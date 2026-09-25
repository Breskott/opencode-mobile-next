/// The AI Team's intro, for a person who has not turned it on
/// (docs/qa/team-discover-2026-09-25): what the team does, in four plain
/// steps under a drawing of a task going from agent to agent, what it needs
/// on this kind of server, and one primary action that hands over to that
/// kind's own set-up. Nothing here sets anything up itself:
///
/// - **OpenCode inside the app**: Set it up opens Settings › Plugins, where
///   [BuiltinTeamSection] adds the team (the setup engine's download), turns
///   it on for the project and starts it.
/// - **OpenCode in Termux**: Set it up opens the Termux setup screen, whose
///   "Also run an AI team on this phone" block installs it
///   ([TeamPhoneOnboardingBlock]); the offer is reopened first, since the
///   person asked for it. On a phone that cannot run a team the screen says
///   so and offers the computer route instead.
/// - **A computer**: the app looks for Gas City on the server's host
///   ([TeamDiscovery]). Found: Turn on. Not found: Set it up shows the host
///   guide and looks again when it closes; Enter its address is the manual
///   form ([showTeamHostSheet]).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../builtin/setup/aiteam_scripts.dart' show AiTeamPins;
import '../../../l10n/app_localizations.dart';
import '../../../state/connection.dart';
import '../../../state/orchestration_store.dart';
import '../../../state/profiles.dart';
import '../../../termux/team_runtime.dart';
import '../../app_theme.dart';
import '../../kit/kit.dart';
import '../../kit/scenes/team_discover_scenes.dart';
import '../../widgets/team_discover.dart';
import '../../widgets/team_discovery_card.dart' show TeamDiscovery;
import '../../widgets/team_host_form.dart';
import '../../widgets/team_phone_onboarding.dart'
    show teamPhoneDownloadMb, teamPhoneRuntime;
import '../phone_setup/phone_setup_selection.dart' show setupSizeText;
import '../settings/plugins_screen.dart' show PluginsSettingsScreen;

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// Opens the intro for the connected server.
Future<void> openTeamIntro(
  BuildContext context,
  ConnectionController controller, {
  TeamHostProbe? probe,
  TermuxTeamRuntime? runtime,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) =>
        TeamIntroScreen(controller: controller, probe: probe, runtime: runtime),
  ),
);

class TeamIntroScreen extends StatefulWidget {
  const TeamIntroScreen({
    super.key,
    required this.controller,
    this.probe,
    this.runtime,
  });

  final ConnectionController controller;

  /// The Gas City probe (a computer); tests pass a fake.
  final TeamHostProbe? probe;

  /// The Termux team runtime; tests pass a fake.
  final TermuxTeamRuntime? runtime;

  @override
  State<TeamIntroScreen> createState() => _TeamIntroScreenState();
}

class _TeamIntroScreenState extends State<TeamIntroScreen> {
  ServerProfile? _profile;
  TeamServerKind? _kind;

  /// Termux: whether this phone can run a team (null while asked) and the
  /// download's size in MB.
  bool? _termuxSupported;
  int? _termuxMb;

  /// A computer: the search for Gas City on the server's host.
  TeamDiscovery? _discovery;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final profile = _profile = widget.controller.profile;
    if (profile == null) return;
    final kind = _kind = teamServerKindOf(profile);
    switch (kind) {
      case TeamServerKind.inApp:
        break;
      case TeamServerKind.termux:
        unawaited(_checkTermux());
      case TeamServerKind.computer:
        _look();
    }
  }

  @override
  void dispose() {
    _discovery
      ?..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _checkTermux() async {
    final runtime = widget.runtime ?? teamPhoneRuntime;
    final supported = await teamTermuxSupported(runtime);
    int? mb;
    if (supported) {
      try {
        mb = teamPhoneDownloadMb(await runtime.manifest());
      } catch (_) {
        mb = teamPhoneDownloadMb(null);
      }
    }
    if (!mounted) return;
    setState(() {
      _termuxSupported = supported;
      _termuxMb = mb;
    });
  }

  /// Looks for Gas City on the server's host, afresh.
  void _look() {
    _discovery
      ?..removeListener(_changed)
      ..dispose();
    final discovery = _discovery = TeamDiscovery(
      widget.controller,
      probe: widget.probe,
    )..addListener(_changed);
    // After this frame: the discovery notifies as soon as it starts.
    scheduleMicrotask(() {
      if (mounted && identical(discovery, _discovery)) {
        unawaited(discovery.ensureProbed());
      }
    });
  }

  bool get _looking {
    final discovery = _discovery;
    return discovery != null && (discovery.running || !discovery.probed);
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await work();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openPlugins() => Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(
      builder: (_) => PluginsSettingsScreen(
        controller: widget.controller,
        probe: widget.probe,
        teamRuntime: widget.runtime,
      ),
    ),
  );

  Future<void> _openTermuxSetup() => _run(() async {
    final profile = _profile;
    if (profile == null) return;
    // The person asked for it: the setup screen's offer shows again even
    // if it was skipped or dismissed before.
    final store = widget.controller.orchestrationStore;
    if (store.phoneOffer(profile.id) != PhoneOffer.open) {
      await store.setPhoneOffer(profile.id, PhoneOffer.open);
    }
    if (!mounted) return;
    unawaited(Navigator.of(context).pushReplacementNamed('/termux-setup'));
  });

  Future<void> _turnOn() => _run(() async {
    await _discovery?.turnOn();
    if (mounted && widget.controller.orchestration != null) {
      Navigator.of(context).pop();
    }
  });

  Future<void> _showGuide() async {
    await showTeamHostGuideSheet(context);
    // Installed it in the meantime? Look again.
    if (mounted) setState(_look);
  }

  Future<void> _enterAddress() async {
    final profile = _profile;
    if (profile == null) return;
    final config = await showTeamHostSheet(
      context,
      initialUrl: teamDiscoveryUrlFor(profile.baseUrl) ?? '',
      probe: widget.probe,
    );
    if (config == null || !mounted) return;
    await _run(() async {
      final controller = widget.controller;
      profile.orchestration = config;
      await controller.store.upsert(profile);
      controller.syncOrchestration();
    });
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final profile = _profile;
    final kind = _kind;
    final name = profile?.name ?? '';

    KitAction? primary;
    KitAction? secondary;
    switch (kind) {
      case null:
        break;
      case TeamServerKind.inApp:
        primary = KitAction(
          key: const ValueKey('team-intro-set-up'),
          label: l10n.teamDiscoverSetUp,
          onPressed: _openPlugins,
        );
      case TeamServerKind.termux:
        if (_termuxSupported == true) {
          primary = KitAction(
            key: const ValueKey('team-intro-set-up'),
            label: l10n.teamDiscoverSetUp,
            working: _busy,
            onPressed: _busy ? null : _openTermuxSetup,
          );
        }
      case TeamServerKind.computer:
        if (_discovery?.result != null) {
          primary = KitAction(
            key: const ValueKey('team-intro-turn-on'),
            label: l10n.teamUiDiscoveryTurnOn,
            working: _busy,
            onPressed: _busy ? null : _turnOn,
          );
        } else {
          primary = KitAction(
            key: const ValueKey('team-intro-set-up'),
            label: l10n.teamDiscoverSetUp,
            onPressed: _busy ? null : _showGuide,
          );
          secondary = KitAction(
            key: const ValueKey('team-intro-address'),
            label: l10n.teamDiscoverEnterAddress,
            onPressed: _busy ? null : _enterAddress,
          );
        }
    }
    final actions = KitActionBlock(primary: primary, secondary: secondary);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.teamUiHomeTitle)),
      body: KitScreen(
        loading: _looking,
        loadingLabel: l10n.teamDiscoverLooking(name),
        body: LayoutBuilder(
          builder: (context, constraints) => ListView(
            key: const ValueKey('team-intro'),
            padding: EdgeInsets.only(
              top: 8,
              bottom: actions.isEmpty ? KitScreen.endPadding(context) : 16,
            ),
            children: [
              Center(
                child: KitIllustration(
                  key: const ValueKey('team-intro-drawing'),
                  scene: const TeamDiscoverRelayScene(),
                  width: math.min(300, constraints.maxWidth - 32),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.teamDiscoverEntryTitle,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.teamDiscoverIntroBody,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.mutedOf(theme),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SectionLabel(l10n.teamDiscoverHowHeading),
              for (final (icon, title, body) in [
                (
                  AppIconography.checklist,
                  l10n.teamDiscoverStepPlanTitle,
                  l10n.teamDiscoverStepPlanBody,
                ),
                (
                  AppIconography.agent,
                  l10n.teamDiscoverStepWorkTitle,
                  l10n.teamDiscoverStepWorkBody,
                ),
                (
                  AppIconography.review,
                  l10n.teamDiscoverStepCheckTitle,
                  l10n.teamDiscoverStepCheckBody,
                ),
                (
                  AppIconography.branch,
                  l10n.teamDiscoverStepMergeTitle,
                  l10n.teamDiscoverStepMergeBody,
                ),
              ])
                _Fact(icon: icon, title: title, body: body),
              if (kind != null) ...[
                SectionLabel(
                  kind == TeamServerKind.computer
                      ? l10n.teamDiscoverNeedsServer(name)
                      : l10n.teamDiscoverNeedsPhone,
                  key: const ValueKey('team-intro-needs'),
                ),
                ..._needs(context, l10n, kind, name),
              ],
            ],
          ),
        ),
        bottom: actions.isEmpty ? null : actions,
      ),
    );
  }

  List<Widget> _needs(
    BuildContext context,
    AppLocalizations l10n,
    TeamServerKind kind,
    String name,
  ) {
    switch (kind) {
      case TeamServerKind.inApp:
        return [
          _Fact(
            icon: AppIconography.download,
            title: l10n.teamDiscoverDownloadTitle(
              setupSizeText(l10n, AiTeamPins.deviceDownloadBytes),
            ),
            body: l10n.teamDiscoverInAppDownloadBody,
          ),
          _Fact(
            icon: AppIconography.batteryWarning,
            title: l10n.teamDiscoverBatteryTitle,
            body: l10n.teamDiscoverInAppBatteryBody,
          ),
          _Fact(
            icon: AppIconography.projects,
            title: l10n.teamDiscoverProjectTitle,
            body: l10n.teamDiscoverProjectBody,
          ),
        ];
      case TeamServerKind.termux:
        final supported = _termuxSupported;
        if (supported == null) return const [KitSkeletonRows(count: 2)];
        if (!supported) {
          return [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: KitNotice(
                key: const ValueKey('team-intro-unsupported'),
                tone: AppStatusTone.attention,
                icon: AppIconography.phone,
                title: l10n.teamDiscoverUnsupportedTitle,
                message: l10n.teamDiscoverUnsupportedBody,
                actions: [
                  KitAction(
                    key: const ValueKey('team-intro-on-computer'),
                    label: l10n.teamDiscoverOnComputer,
                    onPressed: () => showTeamHostGuideSheet(context),
                  ),
                ],
              ),
            ),
          ];
        }
        return [
          _Fact(
            icon: AppIconography.download,
            title: l10n.teamDiscoverDownloadTitle(
              setupSizeText(l10n, (_termuxMb ?? 0) * 1000000),
            ),
            body: l10n.teamDiscoverTermuxDownloadBody,
          ),
          _Fact(
            icon: AppIconography.batteryWarning,
            title: l10n.teamDiscoverBatteryTitle,
            body: l10n.teamDiscoverTermuxBatteryBody,
          ),
        ];
      case TeamServerKind.computer:
        return [
          _Fact(
            icon: AppIconography.computer,
            title: l10n.teamDiscoverComputerTitle(name),
            body: l10n.teamDiscoverComputerBody,
          ),
          _Fact(
            icon: AppIconography.speed,
            title: l10n.teamDiscoverSpeedTitle,
            body: l10n.teamDiscoverSpeedBody,
          ),
          if (_discovery?.result != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: KitNotice(
                key: const ValueKey('team-intro-found'),
                tone: AppStatusTone.ok,
                icon: AppIconography.checkCircle,
                title: l10n.pluginsTeamRowFound(name),
                message: l10n.teamDiscoverFoundBody,
              ),
            ),
        ];
    }
  }
}

/// One line of the intro: an icon, a short title and what it means. Not a
/// door (nothing to open), so no chevron.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: KitRow(
      leading: KitRow.icon(context, icon),
      title: title,
      titleMaxLines: 2,
      supporting: TextSpan(text: body),
      supportingMaxLines: 3,
    ),
  );
}
