// G6 fixtures for the AI Team kit parts (lib/ui/kit/team/). Each part is held
// in realistic copy in two states, English and Arabic.
import 'package:flutter/material.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_overflow_scenes.dart';

void _noop() {}

Widget _team(String part, KitSceneCopy c, KitTeamState state) {
  final title = c.t(
    'Settings screen and data model',
    'شاشة الإعدادات ونموذج البيانات',
  );
  final status = switch (state) {
    KitTeamState.failed => c.t(
      'The check could not finish. Retry the check.',
      'تعذر إكمال الفحص. أعد المحاولة.',
    ),
    _ => c.t('Waiting for your review · 2 min', 'بانتظار مراجعتك · دقيقتان'),
  };
  final items = [
    KitTeamItem(
      title: c.t(
        'Data model for the saved draft',
        'نموذج البيانات للمسودة المحفوظة',
      ),
      detail: c.t('Backend · Home PC', 'الخلفية · حاسوب المنزل'),
      meta: c.t(
        'App repo · 3 acceptance checks',
        'مستودع التطبيق · ٣ فحوص قبول',
      ),
    ),
    KitTeamItem(
      title: c.t('Settings screen', 'شاشة الإعدادات'),
      detail: c.t(
        'Frontend · after Data model',
        'الواجهة · بعد نموذج البيانات',
      ),
      state: KitTeamState.running,
    ),
  ];
  final primary = KitAction(
    label: c.t('Approve and start', 'وافق وابدأ'),
    onPressed: _noop,
  );
  switch (part) {
    case 'KitPlanCard':
      return KitPlanCard(
        title: title,
        status: status,
        state: state,
        items: items,
        primary: primary,
      );
    case 'KitPhaseCard':
      return KitPhaseCard(
        title: title,
        status: status,
        state: state,
        items: items,
        primary: primary,
      );
    case 'KitMergeQueue':
      return KitMergeQueue(
        title: title,
        status: status,
        state: state,
        items: items,
        primary: primary,
      );
    case 'KitPromoteCard':
      return KitPromoteCard(
        title: title,
        status: status,
        state: state,
        items: items,
        primary: primary,
      );
    case 'KitDigest':
      return KitDigest(
        title: title,
        status: status,
        state: state,
        items: items,
        primary: primary,
      );
    case 'KitTimelineDay':
      return KitTimelineDay(
        title: title,
        status: status,
        state: state,
        items: items,
        primary: primary,
      );
    case 'KitServerLane':
      return KitServerLane(
        title: title,
        status: status,
        state: state,
        items: items,
        primary: primary,
      );
    case 'KitProjectRow':
      return KitProjectRow(
        title: title,
        status: status,
        state: state,
        onPressed: _noop,
        completed: 2,
        total: 5,
      );
    case 'KitMilestoneRow':
      return KitMilestoneRow(
        title: title,
        status: status,
        state: state,
        onPressed: _noop,
        completed: 2,
        total: 5,
      );
    case 'KitFindingsCard':
      return KitFindingsCard(
        title: title,
        status: status,
        state: state,
        primary: primary,
        findings: [
          KitTeamFinding(
            id: 'critical',
            title: c.t('Preserve the saved draft', 'حافظ على المسودة المحفوظة'),
            severityLabel: c.t('Critical', 'حرج'),
            severity: KitFindingSeverity.critical,
            detail: c.t(
              'Criterion 1 · survives restart',
              'المعيار ١ · يبقى بعد إعادة التشغيل',
            ),
          ),
          KitTeamFinding(
            id: '1',
            title: c.t(
              'Keep the saved choice after restart',
              'أبقِ الاختيار المحفوظ بعد إعادة التشغيل',
            ),
            severityLabel: c.t('Major', 'مهم'),
            severity: KitFindingSeverity.major,
            selected: true,
            onChanged: (_) {},
          ),
        ],
      );
  }
  throw ArgumentError(part);
}

const _teamParts = [
  'KitPlanCard',
  'KitPhaseCard',
  'KitMergeQueue',
  'KitPromoteCard',
  'KitDigest',
  'KitTimelineDay',
  'KitServerLane',
  'KitProjectRow',
  'KitMilestoneRow',
  'KitFindingsCard',
];

final kitOverflowTeamScenes = <KitOverflowScene>[
  for (final part in _teamParts) ...[
    KitOverflowScene(
      [part],
      'needs-you',
      build: (_, c) => _team(part, c, KitTeamState.needsYou),
    ),
    KitOverflowScene(
      [part],
      'failed',
      build: (_, c) => _team(part, c, KitTeamState.failed),
    ),
  ],
];

Widget _spec(KitSceneCopy c, {required bool readOnly}) => KitSpecBlock(
  label: c.t('What the project must do', 'ما الذي يجب أن يفعله المشروع'),
  controller: TextEditingController(
    text: c.t(
      'Keep the saved draft across restarts and explain how to recover it.',
      'احتفظ بالمسودة المحفوظة بعد إعادة التشغيل واشرح كيفية استعادتها.',
    ),
  ),
  helper: c.t('Two or three sentences are enough.', 'تكفي جملتان أو ثلاث.'),
  readOnly: readOnly,
);

final kitOverflowTeamSpecScenes = <KitOverflowScene>[
  KitOverflowScene(
    ['KitSpecBlock'],
    'editable',
    build: (_, c) => _spec(c, readOnly: false),
  ),
  KitOverflowScene(
    ['KitSpecBlock'],
    'read-only',
    build: (_, c) => _spec(c, readOnly: true),
  ),
];
