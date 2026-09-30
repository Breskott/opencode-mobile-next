// The Work strip's row for the phone team's automatic safety check.
//
// After an app update the packaged engine binary is new, so the proof that
// this phone keeps the team's copy of the code separate runs again. This
// strip starts that check once per app run (only for a team that was on),
// shows its progress, and asks before anything the person is using stops.
// It draws nothing when there is nothing to say.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../builtin/builtin_linux.dart';
import '../../builtin/builtin_server.dart'
    show
        BuiltinServerStarter,
        builtinLinuxProvider,
        builtinServerStarterProvider;
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/phone_team_setup.dart';
import '../../state/profiles.dart' show OrchestrationProvider;
import '../kit/kit.dart';
import '../screens/team/team_phone_setup_screen.dart';

class PhoneTeamSetupStrip extends StatefulWidget {
  const PhoneTeamSetupStrip({super.key, required this.connection});

  final ConnectionController connection;

  @override
  State<PhoneTeamSetupStrip> createState() => _PhoneTeamSetupStripState();
}

class _PhoneTeamSetupStripState extends State<PhoneTeamSetupStrip> {
  PhoneTeamSetupController? _flow;

  bool get _engineProfile =>
      widget.connection.profile?.orchestration?.provider ==
      OrchestrationProvider.phoneEngine;

  @override
  void initState() {
    super.initState();
    widget.connection.addListener(_connectionChanged);
    _connectionChanged();
  }

  @override
  void dispose() {
    widget.connection.removeListener(_connectionChanged);
    _flow?.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _connectionChanged() {
    if (_flow != null || !_engineProfile || !mounted) return;
    // Providers are read once, here, when a phone team exists at all.
    BuiltinLinux? linux;
    BuiltinServerStarter? starter;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      linux = container.read(builtinLinuxProvider);
      starter = container.read(builtinServerStarterProvider);
    } catch (_) {
      // No provider scope (a bare test): the flow builds its own.
    }
    final flow = _flow = PhoneTeamSetup.of(
      widget.connection,
      copy: AppLocalizations.of(context),
      linux: linux,
      starter: starter,
    )..addListener(_changed);
    unawaited(flow.autoProof());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final flow = _flow;
    if (flow == null || !_engineProfile) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final waiting = flow.phase == PhoneTeamSetupPhase.confirming;
    final failed = flow.phase == PhoneTeamSetupPhase.failed && flow.automatic;
    if (!flow.isRunning && !failed) return const SizedBox.shrink();
    final done = PhoneTeamSetupStep.values
        .where((s) => flow.took(s) != null)
        .length;
    final Widget leading;
    final String title;
    final TextSpan supporting;
    if (waiting) {
      leading = KitNeedsYou.mark();
      title = l.phoneTeamStripWaiting;
      supporting = TextSpan(
        children: [
          KitNeedsYou.span(context),
          TextSpan(text: l.phoneTeamStripReview),
        ],
      );
    } else if (failed) {
      leading = const KitStatusMark(state: KitMarkState.failed);
      title = l.phoneTeamStripFailed;
      supporting = TextSpan(
        text: phoneTeamProblemCopy(
          l,
          flow.problem ?? PhoneTeamSetupProblem.engine,
        ).title,
      );
    } else {
      leading = const KitStatusMark(state: KitMarkState.working);
      title = l.phoneTeamStripChecking;
      supporting = TextSpan(
        text: l.phoneTeamStripStep(
          (done + 1).clamp(1, PhoneTeamSetupStep.values.length),
          PhoneTeamSetupStep.values.length,
        ),
      );
    }
    return KitRowGroup(
      key: const ValueKey('work-phone-team-setup'),
      leadingIcons: false,
      gapBefore: 0,
      children: [
        KitRow(
          key: const ValueKey('work-phone-team-setup-row'),
          leading: leading,
          title: title,
          supporting: supporting,
          trailing: const KitChevron(),
          onTap: () => unawaited(
            openPhoneTeamSetup(context, widget.connection, autoStart: false),
          ),
        ),
      ],
    );
  }
}
