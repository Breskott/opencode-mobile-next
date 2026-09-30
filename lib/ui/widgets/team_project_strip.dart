import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../../state/team_project_controller.dart';
import '../kit/kit.dart';

/// The project demo uses the same snapshot as its workspace and decisions.
class TeamProjectStrip extends StatelessWidget {
  const TeamProjectStrip({
    super.key,
    required this.controller,
    required this.onOpen,
  });
  final TeamProjectController controller;
  final ValueChanged<String?> onOpen;

  static int _rank(TeamProject project) {
    if (project.requests.any((r) => !r.answered)) return 0;
    if (project.tasks.any((t) => t.status == 'running')) return 1;
    if (project.status == 'done') return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final copy = AppLocalizations.of(context);
      final projects = [...?controller.snapshot?.projects]
        ..sort((a, b) => _rank(a).compareTo(_rank(b)));
      final working = projects.fold<int>(
        0,
        (n, p) => n + p.tasks.where((t) => t.status == 'running').length,
      );
      final needsYou = projects.fold<int>(
        0,
        (n, p) => n + p.requests.where((r) => !r.answered).length,
      );
      return KitRowGroup(
        key: const ValueKey('work-team-projects'),
        leadingIcons: false,
        children: [
          KitRow(
            title: [
              copy.teamStripTitle,
              if (working > 0) copy.teamStripWorking(working),
              if (needsYou > 0) copy.teamStripNeedsYou(needsYou),
            ].join(' · '),
            supporting: TextSpan(text: copy.teamProjectDemo),
            onTap: () => onOpen(null),
          ),
          for (final project in projects.take(3))
            KitRow(
              key: ValueKey('work-team-project-${project.id}'),
              title: project.name,
              supporting: TextSpan(
                text: copy.teamProjectProgress(
                  project.tasks
                      .where((t) => t.status == 'done' || t.status == 'merged')
                      .length,
                  project.tasks.length,
                  project.tasks.where((t) => t.status == 'running').length,
                ),
              ),
              onTap: () => onOpen(project.id),
            ),
        ],
      );
    },
  );
}
