// Non-golden data-part scenes for the kit's bilingual overflow matrix.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_overflow_scenes.dart';

void _noop() {}

Widget _board(KitSceneCopy c, String state) => KitBoardLanes(
  loading: state == 'loading',
  columns: [
    KitBoardColumn(
      label: c.t('Working', 'قيد العمل'),
      count: state == 'loading'
          ? null
          : state == 'empty'
          ? 0
          : 1,
    ),
    KitBoardColumn(
      label: c.t('Review', 'مراجعة'),
      count: state == 'loading' ? null : 0,
    ),
  ],
  selected: 0,
  onSelected: (_) {},
  laneBuilder: (_, index) => KitBoardLane(
    cards: [
      if (state == 'loaded' && index == 0)
        KitTaskCard(
          key: const ValueKey('release-review-task'),
          title: c.t(
            'Review the release notes before publishing',
            'مراجعة ملاحظات الإصدار قبل النشر',
          ),
          mark: KitTaskState.working,
          onOpen: _noop,
        ),
    ],
    empty: KitStateView(
      size: KitStateSize.inline,
      icon: AppIconography.checklist,
      title: c.t('No work in this column', 'لا عمل في هذا العمود'),
    ),
  ),
);

Widget _checklist(KitSceneCopy c, String state) {
  final done = state == 'done';
  final failed = state == 'failed';
  final waiting =
      state == 'before-start' || state == 'person-step' || state == 'stopped';
  return KitChecklist(
    compact: state == 'compact',
    since: state == 'slow'
        ? DateTime.now().subtract(const Duration(seconds: 30))
        : null,
    onSlow: state == 'slow'
        ? [KitAction(label: c.t('Open the log', 'فتح السجل'), onPressed: _noop)]
        : const [],
    estimate: state == 'before-start'
        ? c.t(
            'About eight minutes the first time',
            'نحو ثماني دقائق في المرة الأولى',
          )
        : null,
    cost: state == 'before-start'
        ? [c.t('Downloads about 208 MB', 'تنزيل نحو 208 م.ب')]
        : const [],
    steps: [
      KitStep(
        title: c.t('Install the Linux environment', 'تثبيت بيئة لينكس'),
        state: waiting ? KitMarkState.waiting : KitMarkState.done,
      ),
      KitStep(
        title: c.t('Download and prepare OpenCode', 'تنزيل OpenCode وتجهيزه'),
        state: done
            ? KitMarkState.done
            : failed
            ? KitMarkState.failed
            : waiting
            ? KitMarkState.waiting
            : KitMarkState.working,
        paused: state == 'paused',
        supporting: c.t(
          'The installation files stay on this phone',
          'تبقى ملفات التثبيت على هذا الهاتف',
        ),
        value: !done && !failed && !waiting ? .62 : null,
        retry: failed
            ? KitAction(
                label: c.t('Try again', 'حاول مجدداً'),
                onPressed: _noop,
              )
            : null,
        personAction: state == 'person-step'
            ? KitAction(
                label: c.t('Open Termux', 'فتح Termux'),
                onPressed: _noop,
              )
            : null,
      ),
    ],
    stop: state == 'working'
        ? KitAction(label: c.t('Stop setup', 'إيقاف الإعداد'), onPressed: _noop)
        : null,
    resume: state == 'paused' || state == 'stopped'
        ? KitAction(
            label: c.t('Continue setup', 'متابعة الإعداد'),
            onPressed: _noop,
          )
        : null,
  );
}

KitDiffFile _changedFile() => KitDiffFile.fromPatch(
  'lib/features/conversations/release_notes.dart',
  '@@ -1,2 +1,2 @@\n-final title = "Draft";\n+final title = "Release notes ready for review";\n publish(title);',
);

final List<KitOverflowScene> kitOverflowDataScenes = [
  KitOverflowScene(
    const ['showKitDiff'],
    'loaded',
    host: KitOverflowHost.modal,
    open: (context, c) => showKitDiff(
      context,
      title: c.t('Changes in this reply', 'التغييرات في هذا الرد'),
      files: [_changedFile()],
    ),
  ),
  KitOverflowScene(
    const ['showKitViewer'],
    'loaded',
    host: KitOverflowHost.modal,
    open: (context, c) => showKitViewer(
      context,
      name: 'release-notes.md',
      path: '/projects/mobile/docs/release-notes.md',
      source: KitViewerSource(
        KitViewerContent.markdown(
          c.t(
            '# Release notes\nReview the conversation changes before publishing.',
            '# ملاحظات الإصدار\nراجع تغييرات المحادثة قبل النشر.',
          ),
        ),
      ),
    ),
  ),
  for (final state in ['loading', 'loaded', 'empty'])
    KitOverflowScene(
      const ['KitBoardLane', 'KitBoardLanes'],
      state,
      host: KitOverflowHost.fill,
      build: (_, c) => _board(c, state),
    ),
  for (final state in [
    'before-start',
    'working',
    'slow',
    'person-step',
    'failed',
    'paused',
    'stopped',
    'done',
    'compact',
  ])
    KitOverflowScene(
      const ['KitChecklist'],
      state,
      build: (_, c) => _checklist(c, state),
    ),
  for (final state in [
    'loading',
    'empty',
    'error',
    'loaded',
    'binary',
    'renamed',
    'too-big',
  ])
    KitOverflowScene(
      const ['KitDiffView'],
      state,
      host: KitOverflowHost.fill,
      build: (_, c) => KitDiffView(
        loading: state == 'loading',
        error: state == 'error'
            ? c.t(
                'The changes could not be loaded. Check the server connection.',
                'تعذر تحميل التغييرات. تحقق من الاتصال بالخادم.',
              )
            : null,
        onRetry: state == 'error' ? _noop : null,
        maxLines: state == 'too-big' ? 1 : null,
        onOpenAll: state == 'too-big' ? _noop : null,
        files: [
          if (state == 'loaded' || state == 'too-big') _changedFile(),
          if (state == 'binary')
            const KitDiffFile(
              path: 'assets/release-banner.png',
              segments: [],
              added: 0,
              removed: 0,
              binary: true,
            ),
          if (state == 'renamed')
            const KitDiffFile(
              path: 'docs/release-notes.md',
              oldPath: 'docs/draft-release-notes.md',
              status: KitDiffFileStatus.renamed,
              segments: [],
              added: 0,
              removed: 0,
            ),
        ],
      ),
    ),
  for (final state in ['empty', 'live', 'ended', 'failed'])
    KitOverflowScene(
      const ['KitLogPanel'],
      state,
      build: (_, c) => _OverflowLog(copy: c, status: state),
    ),
  for (final state in ['empty', 'loaded', 'truncated', 'binary'])
    KitOverflowScene(
      const ['KitViewer'],
      state,
      host: KitOverflowHost.fill,
      build: (_, c) => KitViewer(
        name: 'release-notes.md',
        path: '/projects/mobile/docs/release-notes.md',
        onClose: _noop,
        onOpenAll: state == 'truncated' ? _noop : null,
        source: KitViewerSource(
          state == 'binary'
              ? const KitViewerContent.binary(
                  mimeType: 'application/octet-stream',
                  byteLength: 42000,
                )
              : KitViewerContent.text(
                  state == 'empty'
                      ? ''
                      : c.t(
                          'Release notes\nReview the updated conversation controls before publishing.',
                          'ملاحظات الإصدار\nراجع عناصر التحكم الجديدة في المحادثة قبل النشر.',
                        ),
                  truncated: state == 'truncated',
                  totalLines: state == 'truncated' ? 120 : null,
                ),
        ),
      ),
    ),
  for (final state in ['loading', 'error'])
    KitOverflowScene(
      const ['KitViewer'],
      state,
      host: KitOverflowHost.fill,
      build: (_, c) => KitViewer(
        name: 'release-notes.md',
        path: '/projects/mobile/docs/release-notes.md',
        onClose: _noop,
        source: KitViewerSource.load(
          () => state == 'loading'
              ? Completer<KitViewerContent>().future
              : Future<KitViewerContent>.error(
                  StateError(
                    c.t(
                      'The file is no longer available on this server.',
                      'لم يعد الملف متاحاً على هذا الخادم.',
                    ),
                  ),
                ),
        ),
      ),
    ),
  for (final state in ['empty', 'laid-out', 'blocked-chain', 'needs-you'])
    KitOverflowScene(
      const ['KitWorkGraph'],
      state,
      host: KitOverflowHost.fill,
      build: (_, c) => KitWorkGraph(
        onOpen: (_) {},
        nodes: [
          if (state != 'empty') ...[
            KitWorkGraphNode(
              id: 'review',
              title: c.t(
                'Review the conversation changes',
                'مراجعة تغييرات المحادثة',
              ),
              mark: state == 'needs-you'
                  ? KitTaskState.needsYou
                  : state == 'blocked-chain'
                  ? KitTaskState.failed
                  : KitTaskState.working,
              stuck: state == 'blocked-chain' || state == 'needs-you',
            ),
            KitWorkGraphNode(
              id: 'publish',
              title: c.t(
                'Publish the approved release notes',
                'نشر ملاحظات الإصدار المعتمدة',
              ),
              mark: KitTaskState.waiting,
              dependsOn: const ['review'],
            ),
          ],
        ],
      ),
    ),
  for (final state in ['default', 'capped', 'wrapped', 'scrolling', 'empty'])
    KitOverflowScene(
      const ['KitCodeBlock'],
      state,
      build: (_, c) => KitCodeBlock(
        text: state == 'empty'
            ? ''
            : 'final title = "${c.t('Review the release notes before publishing the update', 'مراجعة ملاحظات الإصدار قبل نشر التحديث')}";\nprint(title);\nawait publish(title);',
        fileName: 'release_notes.dart',
        caption: c.t('Prepare the release notes', 'تجهيز ملاحظات الإصدار'),
        language: 'dart',
        maxLines: state == 'capped' ? 1 : 12,
        onOpenFull: state == 'capped' ? _noop : null,
        wrap: state == 'wrapped'
            ? true
            : state == 'scrolling'
            ? false
            : null,
      ),
    ),
  KitOverflowScene(
    const ['KitGroupNote'],
    'default',
    build: (_, c) => KitGroupNote(
      message: c.t(
        'Two settings are not available on this server.',
        'إعدادان غير متاحين على هذا الخادم.',
      ),
      action: KitAction(label: c.t('Why', 'لماذا'), onPressed: _noop),
    ),
  ),
  for (final (state, value) in <(String, double?)>[
    ('loading', null),
    ('loaded', .62),
    ('near-limit', .92),
    ('at-limit', 1),
    ('empty', 0),
  ])
    KitOverflowScene(
      const ['KitProgressRow'],
      state,
      build: (_, c) => KitProgressRow(
        title: c.t(
          'Provider usage for the current five-hour window',
          'استخدام المزوّد خلال فترة الساعات الخمس الحالية',
        ),
        value: value,
        valueLabel: value == null
            ? null
            : c.t(
                '${(value * 100).round()}% · resets in three hours',
                '${(value * 100).round()}٪ · يُعاد بعد ثلاث ساعات',
              ),
      ),
    ),
  KitOverflowScene(
    const ['KitProgressRow'],
    'stale',
    build: (_, c) => KitProgressRow(
      title: c.t('Provider usage', 'استخدام المزوّد'),
      value: .62,
      valueLabel: c.t(
        'Last reported usage: 62%',
        'آخر استخدام مُبلّغ عنه: ٦٢٪',
      ),
      asOf: DateTime.now().subtract(const Duration(minutes: 12)),
    ),
  ),
  KitOverflowScene(
    const ['KitProgressRow'],
    'segments',
    build: (_, c) => KitProgressRow.segments(
      title: c.t('Conversation context', 'سياق المحادثة'),
      segments: [
        KitProgressSegment(
          label: c.t('Conversation messages', 'رسائل المحادثة'),
          value: .42,
          valueLabel: '42k',
        ),
        KitProgressSegment(
          label: c.t('Tools and file references', 'الأدوات ومراجع الملفات'),
          value: .21,
          valueLabel: '21k',
        ),
      ],
    ),
  ),
  for (final state in KitReceiptState.values)
    KitOverflowScene(
      const ['KitReceipt'],
      state.name,
      build: (_, c) => KitReceipt(
        state: state,
        label: c.t('Moved to review', 'نُقل إلى المراجعة'),
        sendingLabel: c.t('Moving to review', 'جارٍ النقل إلى المراجعة'),
        reason: c.t(
          'This conversation is read-only on the server.',
          'هذه المحادثة للقراءة فقط على الخادم.',
        ),
        where: c.t('the workstation in the office', 'محطة العمل في المكتب'),
        onRetry: _noop,
        onUndo: _noop,
      ),
    ),
  KitOverflowScene(
    const ['KitReceipt'],
    'automatic',
    build: (_, c) => KitReceipt(
      state: KitReceiptState.confirmed,
      label: c.t('Restarted the phone server', 'أُعيد تشغيل خادم الهاتف'),
      automatic: true,
      at: DateTime.now(),
      onUndo: _noop,
    ),
  ),
];

class _OverflowLog extends StatefulWidget {
  const _OverflowLog({required this.copy, required this.status});
  final KitSceneCopy copy;
  final String status;

  @override
  State<_OverflowLog> createState() => _OverflowLogState();
}

class _OverflowLogState extends State<_OverflowLog> {
  final _lines = ValueNotifier<List<KitLogLine>>(const []);

  void _updateLines() {
    _lines.value = [
      if (widget.status != 'empty') ...[
        const KitLogLine(
          'Preparing /data/local/opencode/projects/release-notes',
        ),
        KitLogLine(
          widget.copy.t(
            'Waiting for the server to answer',
            'بانتظار استجابة الخادم',
          ),
        ),
      ],
    ];
  }

  @override
  void initState() {
    super.initState();
    _updateLines();
  }

  @override
  void didUpdateWidget(_OverflowLog oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateLines();
  }

  @override
  void dispose() {
    _lines.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KitLogPanel(
    title: widget.copy.t('Phone server output', 'مخرجات خادم الهاتف'),
    lines: _lines,
    live: widget.status == 'live',
    ended: widget.status == 'ended' || widget.status == 'failed'
        ? KitLogEnd(
            exitCode: widget.status == 'failed' ? 1 : 0,
            failed: widget.status == 'failed',
            reason: widget.status == 'failed'
                ? widget.copy.t(
                    'The setup process stopped before completion.',
                    'توقفت عملية الإعداد قبل اكتمالها.',
                  )
                : null,
          )
        : null,
  );
}
