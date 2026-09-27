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
///
/// Built from kit parts only (screen-team-1): the top bar, the drawing,
/// two row panels (how it works, what it needs), the cost before the
/// set-up primary ([KitNotice.cost]: the time the first setup takes and
/// the memory each worker uses on a phone, KIT-37), and every action named
/// after what it sets up ("Set up AI Team on this phone").
library;

import 'dart:async';

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
}) => pushKitPage<void>(
  context,
  (_) =>
      TeamIntroScreen(controller: controller, probe: probe, runtime: runtime),
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

  /// Settings › Plugins, whose AI Team section opens phone setup's Add
  /// tools › AI Team when the team is not installed yet, then turns it on
  /// for the project.
  void _openPlugins() => unawaited(
    replaceWithKitPage<void, void>(
      context,
      (_) => PluginsSettingsScreen(
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
    final tokens = KitTokens.of(context);
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
          label: l10n.teamIntroSetUpPhone,
          onPressed: _openPlugins,
        );
      case TeamServerKind.termux:
        if (_termuxSupported == true) {
          primary = KitAction(
            key: const ValueKey('team-intro-set-up'),
            label: l10n.teamIntroSetUpPhone,
            working: _busy,
            onPressed: _busy ? null : _openTermuxSetup,
          );
        }
      case TeamServerKind.computer:
        if (_discovery?.result != null) {
          primary = KitAction(
            key: const ValueKey('team-intro-turn-on'),
            label: l10n.teamIntroTurnOn(name),
            working: _busy,
            onPressed: _busy ? null : _turnOn,
          );
        } else {
          primary = KitAction(
            key: const ValueKey('team-intro-set-up'),
            label: l10n.teamIntroSetUpOn(name),
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
    final inset = EdgeInsetsDirectional.symmetric(
      horizontal: tokens.gutter,
      vertical: tokens.space2,
    );

    return KitScreen(
      topBar: KitTopBar(title: l10n.teamUiHomeTitle),
      width: KitScreenWidth.reading,
      loading: _looking,
      loadingLabel: l10n.teamDiscoverLooking(name),
      body: ListView(
        key: const ValueKey('team-intro'),
        padding: EdgeInsetsDirectional.only(
          top: tokens.space2,
          bottom: actions.isEmpty
              ? KitScreen.endPadding(context)
              : tokens.space4,
        ),
        children: [
          const Center(
            child: KitIllustration(
              key: ValueKey('team-intro-drawing'),
              scene: TeamDiscoverRelayScene(),
            ),
          ),
          Padding(
            padding: inset,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KitText(l10n.teamDiscoverEntryTitle, role: KitTextRole.title),
                SizedBox(height: tokens.space2),
                KitText(
                  l10n.teamDiscoverIntroBody,
                  tone: KitTextTone.secondary,
                ),
              ],
            ),
          ),
          KitRowGroup(
            margin: _groupMargin(context),
            label: l10n.teamDiscoverHowHeading,
            children: [
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
                _fact(context, icon, title, body),
            ],
          ),
          if (kind != null) ..._needs(context, l10n, kind, name, inset),
        ],
      ),
      bottom: actions.isEmpty ? null : actions,
    );
  }

  /// What it needs on this kind of server, then its cost before the
  /// primary (KIT-37).
  List<Widget> _needs(
    BuildContext context,
    AppLocalizations l10n,
    TeamServerKind kind,
    String name,
    EdgeInsetsGeometry inset,
  ) {
    final label = kind == TeamServerKind.computer
        ? l10n.teamDiscoverNeedsServer(name)
        : l10n.teamDiscoverNeedsPhone;
    Widget group(List<Widget> rows) => KitRowGroup(
      margin: _groupMargin(context),
      key: const ValueKey('team-intro-needs'),
      label: label,
      children: rows,
    );
    // The phone's own cost: the time the first setup takes (measured
    // 8–10 min) and the memory each worker holds (about 550 MB).
    Widget phoneCost(String download) => Padding(
      padding: inset,
      child: KitNotice.cost(
        [download, l10n.teamIntroCostTime, l10n.teamIntroCostMemory],
        key: const ValueKey('team-intro-cost'),
        title: l10n.teamIntroCostTitle,
      ),
    );
    switch (kind) {
      case TeamServerKind.inApp:
        final download = l10n.teamDiscoverDownloadTitle(
          setupSizeText(l10n, AiTeamPins.deviceDownloadBytes),
        );
        return [
          group([
            _fact(
              context,
              AppIconography.download,
              download,
              l10n.teamDiscoverInAppDownloadBody,
            ),
            _fact(
              context,
              AppIconography.batteryWarning,
              l10n.teamDiscoverBatteryTitle,
              l10n.teamDiscoverInAppBatteryBody,
            ),
            _fact(
              context,
              AppIconography.projects,
              l10n.teamDiscoverProjectTitle,
              l10n.teamDiscoverProjectBody,
            ),
          ]),
          phoneCost(download),
        ];
      case TeamServerKind.termux:
        final supported = _termuxSupported;
        if (supported == null) {
          return [
            group(const [KitSkeletonRows(count: 2)]),
          ];
        }
        if (!supported) {
          // Explain instead of vanish (P7.4): why, and the computer route.
          return [
            Padding(
              padding: inset,
              child: KitNotice(
                key: const ValueKey('team-intro-unsupported'),
                icon: AppIconography.phone,
                title: l10n.teamDiscoverUnsupportedTitle,
                message: l10n.teamDiscoverUnsupportedBody,
                actions: [
                  KitAction(
                    key: const ValueKey('team-intro-on-computer'),
                    label: l10n.teamDiscoverOnComputer,
                    onPressed: () => unawaited(showTeamHostGuideSheet(context)),
                  ),
                ],
              ),
            ),
          ];
        }
        final download = l10n.teamDiscoverDownloadTitle(
          setupSizeText(l10n, (_termuxMb ?? 0) * 1000000),
        );
        return [
          group([
            _fact(
              context,
              AppIconography.download,
              download,
              l10n.teamDiscoverTermuxDownloadBody,
            ),
            _fact(
              context,
              AppIconography.batteryWarning,
              l10n.teamDiscoverBatteryTitle,
              l10n.teamDiscoverTermuxBatteryBody,
            ),
          ]),
          phoneCost(download),
        ];
      case TeamServerKind.computer:
        return [
          group([
            _fact(
              context,
              AppIconography.computer,
              l10n.teamDiscoverComputerTitle(name),
              l10n.teamDiscoverComputerBody,
            ),
            _fact(
              context,
              AppIconography.speed,
              l10n.teamDiscoverSpeedTitle,
              l10n.teamDiscoverSpeedBody,
            ),
          ]),
          if (_discovery?.result != null)
            Padding(
              padding: inset,
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

  /// A panel's place in the list: the gutter at the sides, a section step
  /// above its label.
  static EdgeInsetsDirectional _groupMargin(BuildContext context) {
    final tokens = KitTokens.of(context);
    return EdgeInsetsDirectional.fromSTEB(
      tokens.gutter,
      tokens.space3,
      tokens.gutter,
      tokens.space1,
    );
  }

  /// One line of the intro: an icon, a short title and what it means. Not
  /// a door (nothing to open), so no chevron.
  Widget _fact(
    BuildContext context,
    IconData icon,
    String title,
    String body,
  ) => MergeSemantics(
    child: KitRow(
      leading: KitRow.icon(context, icon),
      title: title,
      titleMaxLines: 2,
      supporting: TextSpan(text: body),
      supportingMaxLines: 3,
    ),
  );
}
