// Real form states for the G6 overflow matrix. The owning kit API documents
// define the states; no platform camera or persisted drafts are needed here.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_overflow_scenes.dart';

void _noop() {}

List<KitChoice<String>> _choices(KitSceneCopy c) => [
  KitChoice(
    value: 'balanced',
    title: c.t('Balanced voice model', 'نموذج صوت متوازن'),
    supporting: c.t(
      'Clear speech for everyday replies',
      'كلام واضح للردود اليومية',
    ),
    recommended: true,
  ),
  KitChoice(
    value: 'quality',
    title: c.t('Higher quality voice model', 'نموذج صوت بجودة أعلى'),
    enabled: false,
    disabledReason: c.t(
      'Download the model to use this voice',
      'نزّل النموذج لاستخدام هذا الصوت',
    ),
  ),
];

final kitOverflowFormScenes = <KitOverflowScene>[
  KitOverflowScene(
    const ['showKitChoiceSheet'],
    'default',
    host: KitOverflowHost.modal,
    open: (context, c) {
      unawaited(
        showKitChoiceSheet<String>(
          context,
          title: c.t('Choose a voice model', 'اختيار نموذج صوت'),
          choices: _choices(c),
          selected: 'balanced',
        ),
      );
    },
  ),
  KitOverflowScene(
    const ['showKitDatePicker'],
    'date',
    host: KitOverflowHost.modal,
    open: (context, c) {
      unawaited(
        showKitDatePicker(
          context,
          title: c.t('Choose a reminder date', 'اختيار تاريخ التذكير'),
          initial: DateTime(2026, 9, 28),
          first: DateTime(2026, 9),
          last: DateTime(2027, 9),
        ),
      );
    },
  ),
  KitOverflowScene(
    const ['showKitTimePicker'],
    'time',
    host: KitOverflowHost.modal,
    open: (context, c) {
      unawaited(
        showKitTimePicker(
          context,
          title: c.t('When quiet hours begin', 'متى تبدأ ساعات الهدوء'),
          initial: const TimeOfDay(hour: 22, minute: 30),
          helper: c.t(
            'Notifications wait until quiet hours end',
            'تنتظر الإشعارات حتى تنتهي ساعات الهدوء',
          ),
        ),
      );
    },
  ),
  KitOverflowScene(
    const ['showKitDateTimePicker'],
    'date-and-time',
    host: KitOverflowHost.modal,
    open: (context, c) {
      unawaited(
        showKitDateTimePicker(
          context,
          title: c.t('When to remind me', 'متى يتم تذكيري'),
          initial: DateTime(2026, 9, 28, 18, 30),
          first: DateTime(2026, 9),
          last: DateTime(2027, 9),
        ),
      );
    },
  ),
  for (final state in ['default', 'collapsed', 'root-only', 'truncated'])
    KitOverflowScene(
      const ['KitBreadcrumb'],
      state,
      build: (_, c) => KitBreadcrumb(
        rootLabel: c.t('Project', 'المشروع'),
        segments: switch (state) {
          'root-only' => const [],
          'collapsed' => [
            'packages',
            'opencode',
            'lib',
            'ui',
            c.t('screens', 'الشاشات'),
          ],
          'truncated' => [
            'packages',
            c.t(
              'release-notes-for-the-next-preview-build',
              'ملاحظات الإصدار القادم للنسخة التجريبية',
            ),
          ],
          _ => ['lib', c.t('screens', 'الشاشات')],
        },
        onSelected: (_) {},
      ),
    ),
  KitOverflowScene(
    const ['KitChoiceList', 'KitChoiceRow'],
    'choice-disabled',
    build: (_, c) => KitChoiceList<String>.single(
      choices: _choices(c),
      selected: 'balanced',
      onSelected: (_) {},
    ),
  ),
  KitOverflowScene(
    const ['KitChoiceList'],
    'multi',
    build: (_, c) => KitChoiceList<String>.multi(
      choices: [
        KitChoice(
          value: 'files',
          title: c.t('Files in this project', 'ملفات هذا المشروع'),
        ),
        KitChoice(
          value: 'messages',
          title: c.t(
            'Earlier messages in this conversation',
            'الرسائل السابقة في هذه المحادثة',
          ),
        ),
      ],
      selected: const {'files', 'messages'},
      onChanged: (_) {},
    ),
  ),
  KitOverflowScene(
    const ['KitChoiceList'],
    'loading',
    build: (_, c) => KitChoiceList<String>.single(
      choices: const [],
      selected: null,
      loading: true,
      onSelected: (_) {},
    ),
  ),
  KitOverflowScene(
    const ['KitChoiceList'],
    'empty',
    build: (_, c) => KitChoiceList<String>.single(
      choices: const [],
      selected: null,
      onSelected: (_) {},
      empty: KitStateView(
        icon: AppIconography.info,
        title: c.t('No voices downloaded yet', 'لم تُنزّل أصوات بعد'),
        size: KitStateSize.inline,
        primary: KitAction(
          label: c.t('Download a voice', 'تنزيل صوت'),
          onPressed: _noop,
        ),
      ),
    ),
  ),
  for (final state in [
    KitReceiptState.sending,
    KitReceiptState.confirmed,
    KitReceiptState.answeredElsewhere,
  ])
    KitOverflowScene(
      const ['KitChoiceRow'],
      state.name,
      build: (_, c) => KitChoiceRow<String>(
        choice: _choices(c).first,
        selected: true,
        onTap: _noop,
        receipt: KitReceipt(
          state: state,
          label: c.t('Voice selected', 'تم اختيار الصوت'),
          where: c.t('the office laptop', 'حاسوب المكتب المحمول'),
        ),
      ),
    ),
  for (final disabled in [false, true])
    KitOverflowScene(
      const ['KitPickerRow'],
      disabled ? 'disabled' : 'default',
      build: (_, c) => KitPickerRow<String>(
        title: c.t('Voice for spoken replies', 'صوت الردود المنطوقة'),
        choices: _choices(c),
        selected: 'balanced',
        onSelected: disabled ? null : (_) {},
        disabledReason: disabled
            ? c.t(
                'Wait for the current reply to finish',
                'انتظر حتى ينتهي الرد الحالي',
              )
            : null,
      ),
    ),
  for (final state in ['row-empty', 'row-set', 'row-error', 'row-disabled'])
    KitOverflowScene(
      const ['KitDateTimeRow'],
      state,
      build: (_, c) => KitDateTimeRow.dateAndTime(
        title: c.t('Remind me about this conversation', 'ذكّرني بهذه المحادثة'),
        value: state == 'row-empty' ? null : DateTime(2026, 9, 28, 18, 30),
        onChanged: state == 'row-disabled' ? null : (_) {},
        clearable: true,
        supporting: c.t(
          'Use the time zone on this device',
          'استخدام المنطقة الزمنية لهذا الجهاز',
        ),
        error: state == 'row-error'
            ? c.t(
                'Choose a time after quiet hours',
                'اختر وقتاً بعد ساعات الهدوء',
              )
            : null,
        disabledReason: state == 'row-disabled'
            ? c.t(
                'Turn on reminders in settings first',
                'فعّل التذكيرات في الإعدادات أولاً',
              )
            : null,
      ),
    ),
  for (final open in [false, true])
    KitOverflowScene(
      const ['KitDetailsFold'],
      open ? 'open' : 'collapsed',
      build: (_, c) => KitDetailsFold(
        initiallyExpanded: open,
        label: c.t('Connection details', 'تفاصيل الاتصال'),
        notes: [
          c.t(
            'Check the address on your workstation',
            'تحقق من العنوان على محطة العمل',
          ),
        ],
        values: [
          KitTechnicalValue(
            c.t('Address', 'العنوان'),
            'http://192.168.1.20:4096',
          ),
          KitTechnicalValue(
            c.t('Project', 'المشروع'),
            '/home/developer/projects/opencode-mobile',
          ),
        ],
      ),
    ),
  for (final state in ['default', 'error', 'disabled', 'secret-saved'])
    KitOverflowScene(
      const ['KitField'],
      state,
      build: (_, c) => state == 'secret-saved'
          ? KitField.secret(
              label: c.t('Server password', 'كلمة مرور الخادم'),
              saved: true,
              onReplace: _noop,
            )
          : KitField(
              label: c.t('Name for this workstation', 'اسم محطة العمل هذه'),
              helper: c.t(
                'A name you can recognize in your server list',
                'اسم يمكنك التعرّف عليه في قائمة الخوادم',
              ),
              error: state == 'error'
                  ? c.t(
                      'Enter a name before continuing',
                      'أدخل اسماً قبل المتابعة',
                    )
                  : null,
              enabled: state != 'disabled',
              disabledReason: state == 'disabled'
                  ? c.t(
                      'Wait until the server finishes connecting',
                      'انتظر حتى يكتمل الاتصال بالخادم',
                    )
                  : null,
            ),
    ),
  for (final state in ['results', 'partial', 'filtered', 'no-match'])
    KitOverflowScene(
      state == 'no-match'
          ? const ['KitSearchField', 'KitSearchNoMatch']
          : const ['KitSearchField'],
      state,
      build: (_, c) => _SearchScene(copy: c, state: state),
    ),
  for (final state in ['scanning', 'rejected', 'loading'])
    KitOverflowScene(
      const ['KitScanner'],
      state,
      host: KitOverflowHost.fill,
      build: (_, c) => KitScanner(
        camera: _SceneCamera(loading: state == 'loading'),
        instruction: c.t(
          'Point the camera at the pairing code on your workstation',
          'وجّه الكاميرا نحو رمز الاقتران على محطة العمل',
        ),
        rejected: state == 'rejected'
            ? c.t(
                'That is not a pairing code. Try the code shown by your server.',
                'هذا ليس رمز اقتران. جرّب الرمز الذي يعرضه الخادم.',
              )
            : null,
        onCode: (_) => false,
        onFailed: (_) {},
      ),
    ),
];

// Own the query controller so each matrix cell disposes its editing state.
class _SearchScene extends StatefulWidget {
  const _SearchScene({required this.copy, required this.state});
  final KitSceneCopy copy;
  final String state;

  @override
  State<_SearchScene> createState() => _SearchSceneState();
}

class _SearchSceneState extends State<_SearchScene> {
  late final _controller = TextEditingController(
    text: widget.copy.t('Release notes', 'ملاحظات الإصدار'),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.copy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KitSearchField(
          label: c.t('Search conversations', 'البحث في المحادثات'),
          controller: _controller,
          onChanged: (_) {},
          resultCount: widget.state == 'no-match' ? 0 : 12,
          partial: widget.state == 'partial',
          activeFilter: widget.state == 'filtered'
              ? c.t('Current project', 'المشروع الحالي')
              : null,
          onClearFilter: _noop,
        ),
        if (widget.state == 'no-match')
          KitSearchNoMatch(
            query: _controller.text,
            what: c.t('conversations', 'المحادثات'),
            onClear: _noop,
            action: KitAction(
              label: c.t('Search all projects', 'البحث في كل المشاريع'),
              onPressed: _noop,
            ),
          ),
      ],
    );
  }
}

// Only the camera boundary is fake: the complete scanner renders its own
// viewfinder, instruction and rejection states. No native channel is opened.
class _SceneCamera implements KitScannerCamera {
  _SceneCamera({required this.loading});
  final bool loading;

  @override
  Stream<String> get codes => const Stream.empty();
  @override
  Future<void> start() => loading ? Completer<void>().future : Future.value();
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
  @override
  Widget preview(BuildContext context) =>
      ColoredBox(color: AppTheme.rolesOf(Theme.of(context)).surface3);
}
