// G6 scenes for the form, disclosure and viewer parts exported on Sept 27.
// The matrix supplies compact/expanded windows, large text and both directions.
import 'package:flutter/material.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/widgets/request_routes.dart';

import 'kit_overflow_scenes.dart';

void _noop() {}
List<KitChoice<String>> _choices(KitSceneCopy c) => [
  KitChoice(
    value: 'balanced',
    title: c.t('Balanced', 'متوازن'),
    supporting: c.t('For everyday project work', 'للعمل اليومي على المشروع'),
  ),
  KitChoice(
    value: 'thorough',
    title: c.t('Thorough', 'شامل'),
    supporting: c.t(
      'Take more time to check the result',
      'استغرق وقتاً أطول للتحقق من النتيجة',
    ),
  ),
];

final kitFormsOverflowScenes = <KitOverflowScene>[
  KitOverflowScene(
    ['KitSegmented'],
    'stacked-long-labels',
    labelsOverflow: true,
    build: (_, c) => KitSegmented<String>(
      segments: [
        KitSegment(
          value: 'session',
          label: c.t('Only this conversation', 'هذه المحادثة فقط'),
        ),
        KitSegment(
          value: 'server',
          label: c.t(
            'Every conversation on this computer',
            'كل المحادثات على هذا الكمبيوتر',
          ),
        ),
      ],
      selected: 'session',
      onChanged: (_) {},
      semanticsLabel: c.t('Permission scope', 'نطاق الإذن'),
    ),
  ),
  for (final state in [
    'default',
    'loading',
    'empty',
    'multi',
    'choice-disabled',
  ])
    KitOverflowScene(
      ['KitChoiceList'],
      state,
      build: (_, c) {
        final choices = state == 'empty' ? <KitChoice<String>>[] : _choices(c);
        if (state == 'multi') {
          return KitChoiceList<String>.multi(
            choices: choices,
            selected: const {'balanced', 'thorough'},
            onChanged: (_) {},
          );
        }
        return KitChoiceList<String>.single(
          choices: state == 'choice-disabled'
              ? [
                  KitChoice(
                    value: 'thorough',
                    title: c.t('Thorough', 'شامل'),
                    enabled: false,
                    disabledReason: c.t(
                      'Download this model first',
                      'نزّل هذا النموذج أولاً',
                    ),
                  ),
                ]
              : choices,
          selected: state == 'empty' || state == 'choice-disabled'
              ? null
              : 'balanced',
          onSelected: (_) {},
          loading: state == 'loading',
          empty: state == 'empty'
              ? KitStateView(
                  icon: Icons.list_alt,
                  title: c.t('No models available', 'لا توجد نماذج متاحة'),
                )
              : null,
        );
      },
    ),
  for (final state in ['default', 'selected', 'current', 'disabled'])
    KitOverflowScene(
      ['KitChoiceRow'],
      state,
      build: (_, c) => KitChoiceRow(
        choice: KitChoice(
          value: 'balanced',
          title: c.t('Balanced', 'متوازن'),
          supporting: c.t(
            'For everyday project work',
            'للعمل اليومي على المشروع',
          ),
          enabled: state != 'disabled',
          disabledReason: state == 'disabled'
              ? c.t('Download this model first', 'نزّل هذا النموذج أولاً')
              : null,
        ),
        selected: state == 'selected',
        current: state == 'current',
        onTap: state == 'disabled' ? null : _noop,
      ),
    ),
  for (final state in ['default', 'single-option', 'disabled'])
    KitOverflowScene(
      ['KitPickerRow'],
      state,
      build: (_, c) => KitPickerRow(
        title: c.t('Model', 'النموذج'),
        choices: state == 'single-option'
            ? _choices(c).take(1).toList()
            : _choices(c),
        selected: 'balanced',
        onSelected: state == 'disabled' ? null : (_) {},
        disabledReason: state == 'disabled'
            ? c.t('Connect to choose a model', 'اتصل لاختيار نموذج')
            : null,
      ),
    ),
  KitOverflowScene(
    ['showKitChoiceSheet'],
    'default',
    host: KitOverflowHost.modal,
    open: (context, c) => showKitChoiceSheet<String>(
      context,
      title: c.t('Choose model', 'اختر النموذج'),
      choices: _choices(c),
      selected: 'balanced',
    ),
  ),
  for (final state in ['empty', 'set', 'error', 'disabled'])
    KitOverflowScene(
      ['KitDateTimeRow'],
      state,
      build: (_, c) => KitDateTimeRow.date(
        title: c.t('Due date', 'تاريخ الاستحقاق'),
        value: state == 'empty' ? null : DateTime(2026, 9, 28),
        onChanged: state == 'disabled' ? null : (_) {},
        error: state == 'error'
            ? c.t('Choose a future date', 'اختر تاريخاً في المستقبل')
            : null,
        disabledReason: state == 'disabled'
            ? c.t('Connect to change this date', 'اتصل لتغيير هذا التاريخ')
            : null,
      ),
    ),
  KitOverflowScene(
    ['showKitDatePicker'],
    'date',
    host: KitOverflowHost.modal,
    open: (context, c) => showKitDatePicker(
      context,
      title: c.t('Due date', 'تاريخ الاستحقاق'),
      initial: DateTime(2026, 9, 28),
    ),
  ),
  KitOverflowScene(
    ['showKitTimePicker'],
    'time',
    host: KitOverflowHost.modal,
    open: (context, c) => showKitTimePicker(
      context,
      title: c.t('Start time', 'وقت البدء'),
      initial: const TimeOfDay(hour: 14, minute: 30),
    ),
  ),
  KitOverflowScene(
    ['showKitDateTimePicker'],
    'date-and-time',
    host: KitOverflowHost.modal,
    open: (context, c) => showKitDateTimePicker(
      context,
      title: c.t('Start date and time', 'تاريخ ووقت البدء'),
      initial: DateTime(2026, 9, 28, 14, 30),
    ),
  ),
  for (final state in ['empty', 'collapsed', 'expanded'])
    KitOverflowScene(
      ['KitDetailsFold'],
      state,
      build: (_, c) => KitDetailsFold(
        initiallyExpanded: state == 'expanded',
        notes: state == 'empty'
            ? const []
            : [c.t('Check the connection address', 'تحقق من عنوان الاتصال')],
        values: state == 'empty'
            ? const []
            : [
                KitTechnicalValue(
                  c.t('Working folder', 'مجلد العمل'),
                  '/home/user/projects/mobile',
                ),
              ],
      ),
    ),
  KitOverflowScene(
    ['showKitTechnicalDetails'],
    'default',
    host: KitOverflowHost.modal,
    open: (context, c) => showKitTechnicalDetails(
      context,
      title: c.t('Connection details', 'تفاصيل الاتصال'),
      text: 'Connection refused: 127.0.0.1:4096',
      values: [
        KitTechnicalValue(
          c.t('Working folder', 'مجلد العمل'),
          '/home/user/projects/mobile',
        ),
      ],
    ),
  ),
  KitOverflowScene(
    ['showKitAlert'],
    'alert-with-details',
    host: KitOverflowHost.modal,
    open: (context, c) => showKitAlert(
      context,
      title: c.t('File unavailable', 'الملف غير متاح'),
      body: c.t('Try opening the file again.', 'حاول فتح الملف مرة أخرى.'),
      details: [
        KitTechnicalValue(
          c.t('Working folder', 'مجلد العمل'),
          '/home/user/projects/mobile',
        ),
      ],
    ),
  ),
  KitOverflowScene(
    ['showKitInputDialog'],
    'input-default',
    host: KitOverflowHost.modal,
    open: (context, c) => showKitInputDialog(
      context,
      title: c.t('Rename project', 'إعادة تسمية المشروع'),
      label: c.t('Project name', 'اسم المشروع'),
      confirmLabel: c.t('Rename', 'إعادة التسمية'),
      helper: c.t(
        'Use a name you will recognize later.',
        'استخدم اسماً يمكنك التعرف عليه لاحقاً.',
      ),
    ),
  ),
  KitOverflowScene(
    ['showKitRequestSheet'],
    'permission',
    host: KitOverflowHost.modal,
    open: (context, c) => showKitRequestSheet(
      context,
      routes: RequestRoutes(),
      fullText: 'flutter test --no-pub test/offline_queue_test.dart',
      card: KitRequestCard.ask(
        kind: KitRequestKind.permission,
        title: c.t('Run a shell command', 'تشغيل أمر'),
        who: 'Fox',
        reason: KitNeedsYouReason.decision,
        ifIgnored: c.t(
          'The agent waits; nothing is lost.',
          'ينتظر المساعد، ولن تفقد شيئاً.',
        ),
        announcement: c.t('Permission needed', 'الإذن مطلوب'),
        onDetails: _noop,
        answers: KitRequestDecide(onAllow: _noop, onReject: _noop),
      ),
    ),
  ),
  for (final state in ['explains', 'prerequisite', 'folded'])
    KitOverflowScene(
      ['KitCapabilityExplainer'],
      state,
      build: (_, c) => state == 'prerequisite'
          ? const _PrerequisiteScene()
          : state == 'folded'
          ? KitCapabilityExplainer.offer(
              capability: 'flag:fileBrowsing+terminal',
              host: KitHost.codex,
              folded: true,
              onNotNow: _noop,
            )
          : KitCapabilityExplainer.row(
              capability: 'flag:fileBrowsing+terminal',
              host: KitHost.codex,
              title: c.t('Files and Terminal', 'الملفات والطرفية'),
            ),
    ),
  KitOverflowScene(
    ['KitContextRegion'],
    'idle',
    build: (_, c) => KitContextRegion(
      menu: () => [
        KitMenuItem(
          label: c.t('Copy address', 'نسخ العنوان'),
          onSelected: _noop,
        ),
      ],
      child: KitRow(
        title: c.t('Computer address', 'عنوان الكمبيوتر'),
        trailing: const KitRowValue('100.64.0.3'),
      ),
    ),
  ),
  for (final state in ['loaded', 'empty', 'truncated', 'binary'])
    KitOverflowScene(
      ['KitViewer'],
      state,
      host: KitOverflowHost.fill,
      build: (_, c) => KitViewer(
        name: 'notes.txt',
        source: KitViewerSource(
          state == 'binary'
              ? const KitViewerContent.binary(
                  mimeType: 'application/octet-stream',
                  byteLength: 4096,
                )
              : KitViewerContent.text(
                  state == 'empty'
                      ? ''
                      : c.t(
                          'Project notes\nCheck the latest changes before continuing.',
                          'ملاحظات المشروع\nتحقق من أحدث التغييرات قبل المتابعة.',
                        ),
                  truncated: state == 'truncated',
                ),
        ),
        onOpenAll: state == 'truncated' ? _noop : null,
      ),
    ),
  KitOverflowScene(
    ['showKitViewer'],
    'loaded',
    host: KitOverflowHost.modal,
    open: (context, c) => showKitViewer(
      context,
      name: 'notes.txt',
      source: KitViewerSource(
        KitViewerContent.text(c.t('Project notes', 'ملاحظات المشروع')),
      ),
    ),
  ),
  for (final state in ['loaded', 'empty', 'error'])
    KitOverflowScene(
      ['KitDiffView'],
      state,
      host: KitOverflowHost.fill,
      build: (_, c) => KitDiffView(
        files: state == 'loaded'
            ? [
                KitDiffFile.fromTexts(
                  'notes.txt',
                  before: c.t('Before', 'قبل'),
                  after: c.t('After', 'بعد'),
                ),
              ]
            : [],
        error: state == 'error'
            ? c.t('Could not load changes', 'تعذر تحميل التغييرات')
            : null,
        onRetry: state == 'error' ? _noop : null,
      ),
    ),
  KitOverflowScene(
    ['showKitDiff'],
    'loaded',
    host: KitOverflowHost.modal,
    open: (context, c) => showKitDiff(
      context,
      title: c.t('Review changes', 'مراجعة التغييرات'),
      files: [
        KitDiffFile.fromTexts(
          'notes.txt',
          before: c.t('Before', 'قبل'),
          after: c.t('After', 'بعد'),
        ),
      ],
    ),
  ),
];

// A prerequisite must have a registered way to complete it, like app startup.
class _PrerequisiteScene extends StatefulWidget {
  const _PrerequisiteScene();
  @override
  State<_PrerequisiteScene> createState() => _PrerequisiteSceneState();
}

class _PrerequisiteSceneState extends State<_PrerequisiteScene> {
  @override
  void initState() {
    super.initState();
    KitCapabilities.registerFlow(KitEnableFlows.modelSignIn, (_, _) async {});
  }

  @override
  void dispose() {
    KitCapabilities.debugReset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const KitCapabilityExplainer.state(
    capability: 'model.auth',
    host: KitHost.codex,
    prerequisite: true,
  );
}
