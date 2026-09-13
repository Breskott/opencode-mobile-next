/// The one-time discovery offer of 02-ux §1.2: when the connected server
/// has no AI Team config and its own host answers like a Gas City on port
/// 8373 (the host front, which gives controls) or 8372 (the bare
/// supervisor, read-only), a quiet card asks "… also runs an AI team. Turn
/// it on?". The front port is tried first and preferred. Never a
/// modal; "Not now" is remembered per server through
/// [OrchestrationStore.dismissDiscovery]. Absent from the tree in every
/// other state, so a screen can place it unconditionally (TEAM-107 puts it
/// on Workspace; Settings › Plugins shows it at the top).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/profiles.dart';
import '../app_theme.dart';
import 'team_host_form.dart';

/// What discovery found for a profile, shared with the Plugins row so it can
/// read "Found on … · Gas City 1.4" before the plugin is on.
class TeamDiscoveryResult {
  const TeamDiscoveryResult({required this.url, required this.found});

  final String url;
  final ProbeFound found;
}

/// Probes the profile's host once per (profile, config-null) and keeps the
/// answer for the widgets on this screen. One per screen; the card and the
/// row read it.
class TeamDiscovery extends ChangeNotifier {
  TeamDiscovery(this.controller, {TeamHostProbe? probe})
    : _probe = probe ?? teamHostProbe;

  final ConnectionController controller;
  final TeamHostProbe _probe;

  String? _probedProfileId;
  bool _running = false;
  bool _probed = false;
  TeamDiscoveryResult? _result;

  /// The found host, null before the probe answered or when nothing was
  /// found.
  TeamDiscoveryResult? get result => _result;

  /// True once the probe for the current profile answered (found or not).
  bool get probed => _probed;
  bool get running => _running;

  /// Runs the probe when the profile has no config and the offer is not
  /// dismissed; a profile switch re-probes, a config re-check is free.
  Future<void> ensureProbed() async {
    final profile = controller.profile;
    if (profile == null || profile.orchestration != null) {
      _reset();
      return;
    }
    if (_probedProfileId == profile.id) return;
    final store = controller.orchestrationStore;
    if (store.isDiscoveryDismissed(profile.id)) {
      _probedProfileId = profile.id;
      _probed = true;
      _result = null;
      notifyListeners();
      return;
    }
    final urls = teamDiscoveryUrlsFor(profile.baseUrl);
    _probedProfileId = profile.id;
    _result = null;
    if (urls.isEmpty) {
      _probed = true;
      notifyListeners();
      return;
    }
    _running = true;
    _probed = false;
    notifyListeners();
    TeamDiscoveryResult? result;
    for (final url in urls) {
      ProbeVerdict verdict;
      try {
        verdict = await _probe(url);
      } catch (error) {
        verdict = ProbeUnreachable(error: error);
      }
      if (_probedProfileId != profile.id) return;
      if (verdict is ProbeFound) {
        result = TeamDiscoveryResult(url: url, found: verdict);
        break;
      }
    }
    _running = false;
    _probed = true;
    _result = result;
    notifyListeners();
  }

  void _reset() {
    if (_probedProfileId == null && !_probed && _result == null) return;
    _probedProfileId = null;
    _probed = false;
    _running = false;
    _result = null;
    notifyListeners();
  }

  /// Remembers the dismissal and hides the offer.
  Future<void> dismiss() async {
    final profile = controller.profile;
    if (profile == null) return;
    await controller.orchestrationStore.dismissDiscovery(profile.id);
    _result = null;
    notifyListeners();
  }

  /// Saves the found host on the profile and starts the plugin.
  Future<void> turnOn() async {
    final profile = controller.profile;
    final result = _result;
    if (profile == null || result == null) return;
    profile.orchestration = teamConfigFromVerdict(
      result.found,
      url: result.found.front ? result.found.host.url : result.url,
      city: result.found.city ?? '',
    );
    await controller.store.upsert(profile);
    controller.syncOrchestration();
    _reset();
  }
}

/// The card. Renders nothing until [discovery] found a host.
class TeamDiscoveryCard extends StatefulWidget {
  const TeamDiscoveryCard({
    super.key,
    required this.controller,
    this.discovery,
    this.probe,
  });

  final ConnectionController controller;

  /// A discovery shared with sibling widgets; the card owns one otherwise.
  final TeamDiscovery? discovery;
  final TeamHostProbe? probe;

  @override
  State<TeamDiscoveryCard> createState() => _TeamDiscoveryCardState();
}

class _TeamDiscoveryCardState extends State<TeamDiscoveryCard> {
  late TeamDiscovery _discovery;
  bool _owned = false;

  @override
  void initState() {
    super.initState();
    _adopt();
  }

  void _adopt() {
    final shared = widget.discovery;
    _owned = shared == null;
    _discovery =
        shared ?? TeamDiscovery(widget.controller, probe: widget.probe);
    _discovery.addListener(_changed);
    widget.controller.addListener(_connectionChanged);
    _kick();
  }

  /// Probes after the current frame: [TeamDiscovery] notifies as soon as
  /// it starts, which must not land inside a build.
  void _kick() => scheduleMicrotask(() {
    if (mounted) unawaited(_discovery.ensureProbed());
  });

  void _release() {
    _discovery.removeListener(_changed);
    widget.controller.removeListener(_connectionChanged);
    if (_owned) _discovery.dispose();
  }

  @override
  void didUpdateWidget(TeamDiscoveryCard old) {
    super.didUpdateWidget(old);
    if (old.discovery != widget.discovery ||
        old.controller != widget.controller) {
      _release();
      _adopt();
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _connectionChanged() => _kick();

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _discovery.result;
    final profile = widget.controller.profile;
    if (result == null || profile == null || profile.orchestration != null) {
      return const SizedBox.shrink();
    }
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('team-discovery-card'),
      margin: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  AppIconography.extensions,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.teamUiDiscoveryTitle(profile.name),
                    style: theme.textTheme.titleMedium?.copyWith(height: 1.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              teamFoundCopy(l10n, result.found),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.mutedOf(theme),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                TextButton(
                  key: const ValueKey('team-discovery-not-now'),
                  onPressed: () => unawaited(_discovery.dismiss()),
                  child: Text(l10n.teamUiDiscoveryNotNow),
                ),
                FilledButton(
                  key: const ValueKey('team-discovery-turn-on'),
                  onPressed: () => unawaited(_discovery.turnOn()),
                  child: Text(l10n.teamUiDiscoveryTurnOn),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The performance disclaimer of 03-onboarding §4 for the kind of machine
/// a team host runs on (TEAM-206): one sentence per [OrchestrationHostKind].
String teamHostDisclaimer(AppLocalizations l10n, OrchestrationHostKind kind) =>
    switch (kind) {
      OrchestrationHostKind.pc => l10n.teamUiDisclaimerComputer,
      OrchestrationHostKind.laptop => l10n.teamUiHostKindDisclaimerLaptop,
      OrchestrationHostKind.wsl => l10n.teamUiHostKindDisclaimerWsl,
      OrchestrationHostKind.phone => l10n.teamUiDisclaimerPhone,
    };

/// The kind a disclaimer is shown for: the chosen [config] kind when it
/// agrees with what the host reports, else the reported mode's default (a
/// host that says it is a phone is a phone whatever the form said).
OrchestrationHostKind teamHostKindFor(
  OrchestrationConfig? config,
  OrchestrationHostMode? reported,
) {
  final kind = config?.hostKind;
  final mode = reported ?? kind?.mode ?? OrchestrationHostMode.computer;
  return kind != null && kind.mode == mode
      ? kind
      : OrchestrationHostKind.forMode(mode);
}
