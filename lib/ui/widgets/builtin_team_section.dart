/// AI Team for the OpenCode inside this app (no Termux): the one place the
/// in-app server's team is added, turned on for a project, started and
/// stopped. Shown in Settings › Plugins for the in-app profile, where the
/// Termux "On this phone" section appears for the Termux server.
///
/// - Not installed: "Run an AI team on this phone" with Add, which opens
///   Add tools with AI Team switched on (the reusable setup engine installs
///   it, with its own progress screen).
/// - Installed, not on for the open project: "Turn on AI Team for
///   {project}", which runs [BuiltinTeam.turnOn] with its stage shown here,
///   then gives the profile the team's plugin config, so the Team card and
///   the rest of the AI Team screens light up.
/// - On: running or stopped, with Start / Stop, and the plain explanation
///   of Android's limit on an app's child processes.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../builtin/builtin_server.dart' show looksLikeInAppServer;
import '../../builtin/setup/aiteam_scripts.dart';
import '../../builtin/setup/components.dart' show SetupComponentIds;
import '../../builtin/setup/phone_setup.dart';
import '../../builtin/setup/setup_contract.dart';
import '../../builtin/team/builtin_team.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/profiles.dart';
import '../app_theme.dart';
import '../kit/kit_illustration.dart';
import '../kit/scenes/team_scenes.dart';
import '../screens/phone_setup/phone_setup_routes.dart';
import '../screens/phone_setup/phone_setup_selection.dart' show setupSizeText;

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// The in-app team runtime the section uses; tests replace it.
BuiltinTeam? debugBuiltinTeam;

BuiltinTeam get _sharedTeam => debugBuiltinTeam ?? (_team ??= BuiltinTeam());
BuiltinTeam? _team;

/// Opens Add tools with AI Team switched on and, when the person goes
/// ahead, starts the install and shows its progress. Tests replace it.
@visibleForTesting
Future<void> Function(BuildContext context)? debugAddAiTeam;

Future<void> _addAiTeam(BuildContext context) async {
  final override = debugAddAiTeam;
  if (override != null) return override(context);
  final ids = await showPhoneSetupCustomize(
    context,
    addMode: true,
    selected: const {SetupComponentIds.aiTeam},
  );
  if (ids == null || ids.isEmpty || !context.mounted) return;
  await PhoneSetup.engine.run(ids, params: SetupJobParams.adding(ids));
  if (context.mounted) await openPhoneSetupProgress(context);
}

/// The words for a failed turn-on or start.
String builtinTeamFailureText(
  AppLocalizations l10n,
  BuiltinTeamException error,
) {
  if (error.exited) {
    return l10n.aiteamComponentFailed(l10n.aiteamComponentFailedExited);
  }
  if (error.timedOut) {
    return l10n.aiteamComponentFailed(l10n.aiteamComponentFailedTimeout);
  }
  final lines = error.detail.trim().split('\n');
  return l10n.aiteamComponentFailed(lines.isEmpty ? '' : lines.last.trim());
}

String builtinTeamStageText(
  AppLocalizations l10n,
  BuiltinTeamStage stage,
  String project,
) => switch (stage) {
  BuiltinTeamStage.preparing => l10n.aiteamComponentStageTeam,
  BuiltinTeamStage.addingProject => l10n.aiteamComponentStageProject(project),
  BuiltinTeamStage.starting => l10n.aiteamComponentStageStarting,
  BuiltinTeamStage.waiting => l10n.aiteamComponentStageWaiting,
};

/// What happened to the team's latest merge in [project]'s folder
/// ([BuiltinTeam.originHook]).
String builtinTeamBringInText(
  AppLocalizations l10n,
  BuiltinTeamBringIn bringIn,
  String project,
) {
  final commit = bringIn.commit ?? '';
  return switch (bringIn.outcome) {
    BuiltinTeamBringInOutcome.broughtIn ||
    BuiltinTeamBringInOutcome.upToDate => l10n.aiteamBringInDone(
      project,
      [commit, bringIn.detail].where((part) => part.isNotEmpty).join(' '),
    ),
    BuiltinTeamBringInOutcome.dirty => l10n.aiteamBringInDirty(
      commit,
      project,
      bringIn.detail,
    ),
    BuiltinTeamBringInOutcome.diverged => l10n.aiteamBringInDiverged(
      commit,
      project,
    ),
    BuiltinTeamBringInOutcome.skipped || BuiltinTeamBringInOutcome.failed =>
      l10n.aiteamBringInFailed(project, bringIn.detail),
  };
}

/// The project's folder name, as the person named it.
String builtinTeamProjectName(String path) {
  final trimmed = path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  return trimmed.substring(trimmed.lastIndexOf('/') + 1);
}

class BuiltinTeamSection extends StatefulWidget {
  const BuiltinTeamSection({
    super.key,
    required this.connection,
    required this.profile,
  });

  final ConnectionController connection;

  /// The in-app server's profile.
  final ServerProfile profile;

  /// Whether [profile] gets this section: the in-app server on Android.
  static bool appliesTo(ServerProfile? profile) =>
      looksLikeInAppServer(profile);

  @override
  State<BuiltinTeamSection> createState() => _BuiltinTeamSectionState();
}

class _BuiltinTeamSectionState extends State<BuiltinTeamSection> {
  BuiltinTeam get _team => _sharedTeam;

  BuiltinTeamState? _state;
  bool _loading = true;
  bool _busy = false;
  BuiltinTeamStage? _stage;
  String? _error;
  String? _detail;
  bool _showDetail = false;

  String? get _project {
    final directory = widget.connection.directory;
    if (directory == null || directory.trim().isEmpty) return null;
    return directory;
  }

  bool get _configured =>
      BuiltinTeam.isBuiltinConfig(widget.profile.orchestration);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    BuiltinTeamState state;
    try {
      state = await _team.status();
    } catch (_) {
      state = const BuiltinTeamState();
    }
    if (!mounted) return;
    setState(() {
      _state = state;
      _loading = false;
    });
  }

  String get _notice => _copy(context).aiteamComponentNotice;

  Future<void> _add() async {
    await _addAiTeam(context);
    if (mounted) await _load();
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _detail = null;
      _showDetail = false;
    });
    try {
      await work();
    } on BuiltinTeamException catch (error) {
      if (mounted) {
        setState(() {
          _error = builtinTeamFailureText(_copy(context), error);
          _detail = error.detail;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = _copy(context).aiteamComponentFailed('$error'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _stage = null;
        });
        await _load();
      }
    }
  }

  Future<void> _turnOn(String project) => _run(() async {
    await _team.turnOn(
      project,
      notice: _notice,
      onStage: (stage) {
        if (mounted) setState(() => _stage = stage);
      },
    );
    await _enable();
  });

  Future<void> _start() => _run(() async {
    await _team.start(
      notice: _notice,
      onStage: (stage) {
        if (mounted) setState(() => _stage = stage);
      },
    );
    if (!_configured) await _enable();
  });

  Future<void> _stop() => _run(_team.stop);

  /// Tries again what the origin's hook does after every merge; the section
  /// then shows the new outcome (still left alone when it is not safe).
  Future<void> _bringIn(String project) => _run(() => _team.bringIn(project));

  /// Gives the in-app profile the team's plugin config and lets the
  /// connection build its controller: the Team card, Inbox gates and the
  /// AI Team screens then read this team.
  Future<void> _enable() async {
    final connection = widget.connection;
    final profile = widget.profile;
    profile.orchestration = BuiltinTeam.config();
    await connection.store.upsert(profile);
    connection.syncOrchestration();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: AppTheme.mutedOf(theme),
      height: 1.4,
    );
    final state = _state;
    final children = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AppIconography.phone,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.aiteamComponentSectionTitle,
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
    ];
    if (_loading || state == null) {
      children.add(const LinearProgressIndicator());
    } else if (!state.installed) {
      children
        ..add(
          Text(
            l10n.aiteamComponentOfferBody(
              setupSizeText(l10n, AiTeamPins.deviceDownloadBytes),
            ),
            key: const ValueKey('builtin-team-offer'),
            style: muted,
          ),
        )
        ..add(const SizedBox(height: 8))
        ..add(
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.tonal(
              key: const ValueKey('builtin-team-add'),
              onPressed: _add,
              child: Text(l10n.aiteamComponentAdd),
            ),
          ),
        );
    } else {
      children.addAll(_installed(context, l10n, state, muted));
    }
    if (_busy && _stage != null) {
      children
        ..add(const SizedBox(height: 10))
        ..add(
          Row(
            children: [
              // The team waking up while it starts on this phone.
              const KitIllustration(
                key: ValueKey('builtin-team-waking'),
                scene: TeamWakingScene(),
                width: 72,
                ambient: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  builtinTeamStageText(
                    l10n,
                    _stage!,
                    builtinTeamProjectName(_project ?? ''),
                  ),
                  key: const ValueKey('builtin-team-stage'),
                  style: muted,
                ),
              ),
            ],
          ),
        )
        ..add(const SizedBox(height: 6))
        ..add(const LinearProgressIndicator());
    }
    final error = _error;
    if (error != null) {
      children
        ..add(const SizedBox(height: 10))
        ..add(
          Text(
            error,
            key: const ValueKey('builtin-team-error'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        );
      final detail = _detail;
      if (detail != null && detail.trim().isNotEmpty) {
        children.add(
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => setState(() => _showDetail = !_showDetail),
              child: Text(l10n.aiteamComponentShowDetails),
            ),
          ),
        );
        if (_showDetail) {
          children.add(
            SelectableText(
              detail,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          );
        }
      }
    }
    return Card(
      key: const ValueKey('builtin-team-section'),
      margin: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  List<Widget> _installed(
    BuildContext context,
    AppLocalizations l10n,
    BuiltinTeamState state,
    TextStyle? muted,
  ) {
    final project = _project;
    final projectOn = project != null && state.hasProject(project);
    final on = _configured && state.rigs.isNotEmpty;
    final widgets = <Widget>[];
    if (on) {
      widgets
        ..add(
          Text(
            state.running
                ? l10n.aiteamComponentRunning
                : l10n.aiteamComponentStopped,
            key: const ValueKey('builtin-team-status'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        )
        ..add(
          Text(
            l10n.aiteamComponentProjects(state.rigs.join(', ')),
            style: muted,
          ),
        );
    } else {
      widgets.add(
        Text(
          project == null
              ? l10n.aiteamComponentNoProject
              : l10n.aiteamComponentTurnOnBody,
          key: const ValueKey('builtin-team-turn-on-body'),
          style: muted,
        ),
      );
    }
    final bringIn = on && projectOn ? state.bringInFor(project) : null;
    if (bringIn != null) {
      final name = builtinTeamProjectName(project!);
      widgets
        ..add(const SizedBox(height: 8))
        ..add(
          Text(
            builtinTeamBringInText(l10n, bringIn, name),
            key: const ValueKey('builtin-team-bring-in'),
            style: bringIn.leftBehind
                ? Theme.of(context).textTheme.bodyMedium
                : muted,
          ),
        );
    }
    final actions = <Widget>[
      if (bringIn != null &&
          (bringIn.outcome == BuiltinTeamBringInOutcome.dirty ||
              bringIn.outcome == BuiltinTeamBringInOutcome.failed))
        TextButton(
          key: const ValueKey('builtin-team-bring-in-action'),
          onPressed: _busy ? null : () => _bringIn(project!),
          child: Text(
            l10n.aiteamBringInAction(builtinTeamProjectName(project!)),
          ),
        ),
      if (on && state.running)
        TextButton(
          key: const ValueKey('builtin-team-stop'),
          onPressed: _busy ? null : _stop,
          child: Text(l10n.aiteamComponentStop),
        ),
      if (on && !state.running)
        FilledButton.tonal(
          key: const ValueKey('builtin-team-start'),
          onPressed: _busy ? null : _start,
          child: Text(l10n.aiteamComponentStart),
        ),
      if (project != null && !(on && projectOn))
        FilledButton.tonal(
          key: const ValueKey('builtin-team-turn-on'),
          onPressed: _busy ? null : () => _turnOn(project),
          child: Text(
            l10n.aiteamComponentTurnOn(builtinTeamProjectName(project)),
          ),
        ),
    ];
    if (actions.isNotEmpty) {
      widgets
        ..add(const SizedBox(height: 8))
        ..add(
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.end,
            children: actions,
          ),
        );
    }
    if (on || _configured) {
      widgets
        ..add(const SizedBox(height: 10))
        ..add(
          Text(
            l10n.aiteamComponentChildProcesses,
            key: const ValueKey('builtin-team-child-processes'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.mutedOf(Theme.of(context)),
              height: 1.4,
            ),
          ),
        );
    }
    return widgets;
  }
}
