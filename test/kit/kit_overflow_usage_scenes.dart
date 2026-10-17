// G6 scenes for the usage and chat-composer parts added after the matrix
// was frozen: the task chip and its sheet, one limit window, and the project
// file list and its sheet. They exercise the public parts in English and
// Arabic.
import 'package:flutter/material.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_overflow_scenes.dart';

void _noop() {}

Future<List<String>> _top(String folder) async => [
  'lib/',
  'test/',
  'README.md',
  'a_very_long_file_name_that_keeps_going_and_going_until_it_wraps.dart',
];

List<KitTaskItem> _tasks(KitSceneCopy c) => [
  KitTaskItem(
    c.t('Find every raw colour in the screens', 'ابحث عن كل لون خام'),
    KitTaskItemState.done,
  ),
  KitTaskItem(
    c.t(
      'Run the tests and fix what they show about the settings page',
      'شغّل الاختبارات وأصلح ما تُظهره',
    ),
    KitTaskItemState.inProgress,
  ),
  KitTaskItem(c.t('Ship it', 'انشرها'), KitTaskItemState.todo),
  KitTaskItem(c.t('Old idea', 'فكرة قديمة'), KitTaskItemState.cancelled),
];

Widget _projectFiles(Future<List<String>> Function(String folder) initial) =>
    KitProjectFileList(
      search: (_) async => const [],
      initial: initial,
      onPick: (_) {},
    );

final kitOverflowUsageScenes = <KitOverflowScene>[
  // KitTaskChip: States none; the chip is one pill whose text follows the
  // counts.
  KitOverflowScene(
    const ['KitTaskChip'],
    'default',
    build: (_, c) => KitTaskChip(
      done: 12,
      total: 18,
      current: c.t('Run the tests', 'شغّل الاختبارات'),
      onPressed: _noop,
    ),
  ),
  KitOverflowScene(
    const ['showKitTaskSheet'],
    'default',
    host: KitOverflowHost.modal,
    open: (context, c) => showKitTaskSheet(
      context,
      items: _tasks(c),
      done: 1,
      total: 3,
      running: false,
    ),
  ),
  // KitWindowRow: States none; the tones and the inline form.
  KitOverflowScene(
    const ['KitWindowRow'],
    'default',
    build: (_, c) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KitWindowRow(
          title: c.t('5 hours', '٥ ساعات'),
          left: .18,
          valueLabel: c.t('18% left · 14:10', 'متبقي 18% · 14:10'),
          tone: KitWindowTone.low,
          note: c.t(
            'Resets at Wed 1:59 AM, in 14 hours',
            'يُعاد الضبط الأربعاء 1:59 ص بعد 14 ساعة',
          ),
        ),
        KitWindowRow(
          title: c.t('A very long window name', 'اسم نافذة طويل جدا'),
          left: 0,
          valueLabel: c.t('Used up · Sep 1', 'استُنفد · 1 سبتمبر'),
          tone: KitWindowTone.out,
        ),
      ],
    ),
  ),
  KitOverflowScene(
    const ['KitWindowRow'],
    'inline',
    build: (_, c) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      child: KitWindowRow(
        inline: true,
        title: c.t('Week', 'الأسبوع'),
        left: .12,
        valueLabel: c.t('12% · Thu 1:25 PM', '12% · الخميس 1:25 م'),
      ),
    ),
  ),
  // KitProjectFileList: States empty, error.
  KitOverflowScene(
    const ['KitProjectFileList'],
    'default',
    build: (_, _) => _projectFiles(_top),
  ),
  KitOverflowScene(
    const ['KitProjectFileList'],
    'empty',
    build: (_, _) => _projectFiles((_) async => const []),
  ),
  KitOverflowScene(
    const ['KitProjectFileList'],
    'error',
    build: (_, _) => _projectFiles((_) async => throw StateError('offline')),
  ),
  KitOverflowScene(
    const ['showKitProjectFileSheet'],
    'default',
    host: KitOverflowHost.modal,
    open: (context, c) => showKitProjectFileSheet(
      context,
      search: (_) async => const [],
      initial: _top,
    ),
  ),
];
