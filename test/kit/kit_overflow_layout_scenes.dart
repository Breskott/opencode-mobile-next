// G6 fixtures for kit layout parts added by the September 27 revamp.
// These render the real parts; their overflows remain gate failures.
import 'package:flutter/material.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_overflow_scenes.dart';

void _noop() {}

Widget _transcript(KitSceneCopy copy) => ListView(
  children: [
    for (var i = 0; i < 20; i++)
      KitRow(
        title: copy.t(
          'Conversation update ${i + 1}',
          'تحديث المحادثة ${i + 1}',
        ),
        supporting: TextSpan(
          text: copy.t(
            'The release checks finished. Open the report to review the results.',
            'اكتملت فحوص الإصدار. افتح التقرير لمراجعة النتائج.',
          ),
        ),
        onTap: _noop,
      ),
  ],
);

final kitOverflowLayoutScenes = <KitOverflowScene>[
  KitOverflowScene(
    const ['KitContextRegion'],
    'default',
    build: (_, c) => KitContextRegion(
      menuLabel: c.t('Conversation actions', 'إجراءات المحادثة'),
      menu: () => [
        KitMenuItem(
          label: c.t('Copy message', 'نسخ الرسالة'),
          onSelected: _noop,
        ),
        KitMenuItem(
          label: c.t('Delete message', 'حذف الرسالة'),
          onSelected: _noop,
          destructive: true,
        ),
      ],
      child: KitRow(
        title: c.t('Review the release notes', 'مراجعة ملاحظات الإصدار'),
        supporting: TextSpan(
          text: c.t('Updated a minute ago', 'حُدّثت قبل دقيقة'),
        ),
        onTap: _noop,
      ),
    ),
  ),
  KitOverflowScene(
    const ['KitScrollArea'],
    'default',
    host: KitOverflowHost.fill,
    build: (_, c) => KitScrollArea(
      builder: (controller) => ListView(
        controller: controller,
        children: [
          for (var i = 0; i < 30; i++)
            KitText(
              c.t(
                'Release check ${i + 1}: completed',
                'فحص الإصدار ${i + 1}: اكتمل',
              ),
            ),
        ],
      ),
    ),
  ),
  KitOverflowScene(
    const ['KitScrollbar', 'KitOwnScrollbar'],
    'default',
    host: KitOverflowHost.fill,
    build: (_, c) => _ExplicitScrollScene(copy: c),
  ),
  for (final state in ['default', 'hidden', 'older'])
    KitOverflowScene(
      const ['KitJumpPill', 'KitJumpPillLayer'],
      state,
      host: KitOverflowHost.fill,
      build: (context, c) => KitJumpPillLayer(
        pill: state == 'older'
            ? KitJumpPill.older(
                label: c.t('Load earlier messages', 'تحميل الرسائل السابقة'),
                onPressed: _noop,
                visible: true,
              )
            : KitJumpPill(
                label: KitJumpPill.latestLabel(context, newCount: 3),
                onPressed: _noop,
                visible: state != 'hidden',
              ),
        child: _transcript(c),
      ),
    ),
  for (final state in ['empty', 'connection', 'contribution'])
    KitOverflowScene(
      const ['KitStatusScope', 'KitStatusLineSlot', 'KitStatusContribution'],
      state,
      host: KitOverflowHost.fill,
      build: (_, c) => _StatusScene(copy: c, state: state),
    ),
  for (final state in ['default', 'overflowing'])
    KitOverflowScene(
      const ['KitTabStrip'],
      state,
      build: (_, c) => KitTabStrip(
        selected: state == 'overflowing' ? 4 : 0,
        onSelected: (_) {},
        semanticsLabel: c.t('Task columns', 'أعمدة المهام'),
        tabs: [
          KitTab(label: c.t('Backlog', 'المهام المقبلة')),
          KitTab(label: c.t('Working', 'قيد العمل')),
          if (state == 'overflowing') ...[
            KitTab(label: c.t('Waiting for review', 'بانتظار المراجعة')),
            KitTab(label: c.t('Needs your answer', 'تحتاج إلى إجابتك')),
            KitTab(label: c.t('Completed', 'مكتملة')),
          ],
        ],
      ),
    ),
  for (final state in ['enabled', 'focused', 'disabled'])
    KitOverflowScene(
      const ['KitTappable'],
      state,
      build: (_, c) => KitTappable(
        onTap: state == 'disabled' ? null : _noop,
        autofocus: state == 'focused',
        disabledReason: state == 'disabled'
            ? c.t('Connect to the server first', 'اتصل بالخادم أولاً')
            : null,
        child: KitSurface.panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KitText(c.t('Open the release report', 'افتح تقرير الإصدار')),
              if (state == 'disabled')
                KitText(
                  c.t('Connect to the server first', 'اتصل بالخادم أولاً'),
                ),
            ],
          ),
        ),
      ),
    ),
  for (final state in [
    'default',
    'subtitle_working',
    'subtitle_neutral',
    'not_answering',
    'needs_you',
    'switcher',
    'brand',
    'close',
    'disabled_actions',
  ])
    KitOverflowScene(
      const ['KitTopBar'],
      state,
      host: KitOverflowHost.fill,
      build: (_, c) => KitScreen(
        topBar: KitTopBar(
          title: c.t('Review the release notes', 'مراجعة ملاحظات الإصدار'),
          subtitle: switch (state) {
            'subtitle_working' => c.t(
              'Working on the release checks',
              'جارٍ تنفيذ فحوص الإصدار',
            ),
            'subtitle_neutral' => c.t(
              'Ready for your next message',
              'جاهز لرسالتك التالية',
            ),
            'not_answering' => c.t(
              'Server is not answering',
              'الخادم لا يستجيب',
            ),
            'needs_you' => c.t(
              'A release decision is waiting',
              'قرار الإصدار بانتظارك',
            ),
            _ => null,
          },
          subtitleTone: state == 'subtitle_working'
              ? AppStatusTone.progress
              : AppStatusTone.neutral,
          needsYou: state == 'needs_you' ? 2 : 0,
          brand: state == 'brand',
          exit: state == 'brand'
              ? KitTopBarExit.none
              : state == 'close'
              ? KitTopBarExit.close
              : KitTopBarExit.back,
          onExit: _noop,
          onTitleTap: state == 'switcher' ? _noop : null,
          titleTapLabel: state == 'switcher'
              ? c.t('Switch conversation', 'تبديل المحادثة')
              : null,
          actions: [
            KitAction(
              label: c.t('Search conversation', 'البحث في المحادثة'),
              icon: AppIconography.search,
              onPressed: state == 'disabled_actions' ? null : _noop,
              disabledReason: state == 'disabled_actions'
                  ? c.t('Messages are still loading', 'الرسائل قيد التحميل')
                  : null,
            ),
          ],
          menu: [
            KitMenuItem(
              label: c.t('Conversation details', 'تفاصيل المحادثة'),
              onSelected: _noop,
            ),
          ],
        ),
        body: _transcript(c),
      ),
    ),
  for (final state in [
    'connected',
    'reconnecting',
    'not_answering',
    'needs_you',
    'sidebar',
  ])
    KitOverflowScene(
      const ['KitShellControls'],
      state,
      build: (_, c) => KitShellControls(
        server: c.t('Office workstation', 'محطة العمل في المكتب'),
        serverStatus: state == 'reconnecting'
            ? c.t('Reconnecting', 'إعادة الاتصال')
            : state == 'not_answering'
            ? c.t('Not answering', 'لا يستجيب')
            : c.t('Connected', 'متصل'),
        serverTone: state == 'reconnecting'
            ? AppStatusTone.progress
            : state == 'not_answering'
            ? AppStatusTone.failure
            : AppStatusTone.ok,
        onServer: _noop,
        project: 'oc_app',
        onProject: _noop,
        onSearch: _noop,
        needsYou: state == 'needs_you' ? 2 : 0,
        layout: state == 'sidebar'
            ? KitShellControlsLayout.sidebar
            : KitShellControlsLayout.bar,
      ),
    ),
  for (final state in ['default', 'with_action'])
    KitOverflowScene(
      const ['showKitAlert'],
      state,
      host: KitOverflowHost.modal,
      open: (context, c) => showKitAlert(
        context,
        title: c.t('The report is ready', 'التقرير جاهز'),
        body: c.t(
          'The release checks finished. Review the report before publishing.',
          'اكتملت فحوص الإصدار. راجع التقرير قبل النشر.',
        ),
        action: state == 'with_action'
            ? KitAction(
                label: c.t('Open report', 'فتح التقرير'),
                onPressed: _noop,
              )
            : null,
      ),
    ),
  KitOverflowScene(
    const ['showKitInputDialog'],
    'default',
    host: KitOverflowHost.modal,
    open: (context, c) async {
      await showKitInputDialog(
        context,
        title: c.t('Rename conversation', 'إعادة تسمية المحادثة'),
        label: c.t('Conversation name', 'اسم المحادثة'),
        confirmLabel: c.t('Rename', 'إعادة تسمية'),
        initial: c.t('Release checks', 'فحوص الإصدار'),
        helper: c.t(
          'Use a name that makes the conversation easy to find.',
          'استخدم اسماً يسهّل العثور على المحادثة.',
        ),
      );
    },
  ),
  KitOverflowScene(
    const ['showKitTechnicalDetails'],
    'default',
    host: KitOverflowHost.modal,
    open: (context, c) => showKitTechnicalDetails(
      context,
      title: c.t('Connection details', 'تفاصيل الاتصال'),
      text: 'GET /session/status\nHTTP 503 Service Unavailable',
      values: [
        KitTechnicalValue(
          c.t('Server', 'الخادم'),
          'https://office.example:4096',
        ),
      ],
      notes: [
        c.t(
          'Check that the server is running, then try again.',
          'تأكد من تشغيل الخادم ثم حاول مجدداً.',
        ),
      ],
    ),
  ),
];

class _ExplicitScrollScene extends StatefulWidget {
  const _ExplicitScrollScene({required this.copy});
  final KitSceneCopy copy;
  @override
  State<_ExplicitScrollScene> createState() => _ExplicitScrollSceneState();
}

class _ExplicitScrollSceneState extends State<_ExplicitScrollScene> {
  final controller = ScrollController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KitScrollbar(
    controller: controller,
    child: ListView(
      controller: controller,
      children: [
        for (var i = 0; i < 30; i++)
          KitRow(
            title: widget.copy.t(
              'Release report ${i + 1}',
              'تقرير الإصدار ${i + 1}',
            ),
            onTap: _noop,
          ),
      ],
    ),
  );
}

class _StatusScene extends StatefulWidget {
  const _StatusScene({required this.copy, required this.state});
  final KitSceneCopy copy;
  final String state;
  @override
  State<_StatusScene> createState() => _StatusSceneState();
}

class _StatusSceneState extends State<_StatusScene> {
  late final conditions = ValueNotifier<List<KitStatus>>(
    widget.state == 'connection'
        ? [
            KitStatus(
              kind: KitStatusKind.connection,
              icon: AppIconography.retry,
              message: widget.copy.t(
                'Reconnecting to the office workstation',
                'إعادة الاتصال بمحطة العمل في المكتب',
              ),
              tone: AppStatusTone.progress,
              action: KitAction(
                label: widget.copy.t('Try again', 'حاول مجدداً'),
                onPressed: _noop,
              ),
            ),
          ]
        : [],
  );
  @override
  void dispose() {
    conditions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KitStatusScope(
    conditions: conditions,
    child: KitStatusLineSlot(
      child: KitStatusContribution(
        status: widget.state == 'contribution'
            ? KitStatus(
                kind: KitStatusKind.work,
                icon: AppIconography.terminal,
                message: widget.copy.t(
                  'Running the release checks',
                  'جارٍ تنفيذ فحوص الإصدار',
                ),
              )
            : null,
        child: _transcript(widget.copy),
      ),
    ),
  );
}
