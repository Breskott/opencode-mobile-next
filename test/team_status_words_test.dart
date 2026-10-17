import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/team_project.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/screens/team/projects/team_status_words.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  final now = DateTime.utc(2026, 10, 15, 12);

  TeamProject spec(Duration ago) => TeamProject(
    id: 'p',
    status: 'spec',
    updatedAt: now.subtract(ago).toIso8601String(),
  );

  test('a spec that takes minutes shows how long, then says still working', () {
    expect(
      teamPlanningWords(l, spec(const Duration(seconds: 20)), now),
      'Shaping the spec',
    );
    expect(
      teamPlanningWords(l, spec(const Duration(minutes: 1)), now),
      'Shaping the spec · 1 min',
    );
    expect(
      teamPlanningWords(l, spec(const Duration(minutes: 9)), now),
      'Still shaping the spec · 9 min',
    );
  });

  test('finished tasks never read as "0 working"', () {
    TeamProject withTasks(List<String> statuses) => TeamProject(
      id: 'p',
      status: 'running',
      tasks: [
        for (final (i, s) in statuses.indexed) TeamTask(id: 't$i', status: s),
      ],
    );
    expect(
      teamProgressWords(l, withTasks(['merged', 'done'])),
      'All 2 tasks complete',
    );
    expect(
      teamProgressWords(l, withTasks(['merged', 'queued'])),
      '1 of 2 tasks complete',
    );
    expect(
      teamProgressWords(l, withTasks(['merged', 'running'])),
      '1 of 2 tasks complete · 1 working',
    );
  });
}
