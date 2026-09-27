// Scenes for the G6 kit overflow matrix (docs/ux-system/revamp/STANDARDS.md
// §18, A11Y-2, LAY-4, KIT-24), read by test/text_scale_overflow_test.dart.
//
// The matrix finds the kit's parts itself, from the exports of
// lib/ui/kit/kit.dart, and fails when a part has no scene here or a scene
// names a part the kit no longer exports. A kit unit that adds a part adds
// one block at the end of [kitOverflowScenes] (append-only, like the other
// PROC-13 registries) and never edits the matrix. When the G4 manifest
// exposes the gallery scenes, the matrix reads those instead.
//
// A scene holds a part in realistic copy for each declared state, in
// English for left to right and Arabic for right to left.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

/// Where the matrix puts a scene.
enum KitOverflowHost {
  /// In a padded scrolling list, as rows and panels sit on a screen.
  list,

  /// As the whole body of the screen, for parts that fill it.
  fill,

  /// Opened from an empty screen through [KitOverflowScene.open].
  modal,
}

/// The words a scene shows, in the direction under test.
class KitSceneCopy {
  const KitSceneCopy({required this.rtl});

  final bool rtl;

  /// English in left to right, Arabic in right to left.
  String t(String en, String ar) => rtl ? ar : en;
}

/// One state of one part, as the overflow matrix pumps it.
class KitOverflowScene {
  const KitOverflowScene(
    this.parts,
    this.state, {
    this.build,
    this.open,
    this.host = KitOverflowHost.list,
    this.labelsOverflow = false,
  }) : assert((build == null) != (open == null));

  /// The manifest names this scene shows (a widget class or `showKit…`).
  final List<String> parts;

  /// The declared state (KIT-12) or `default`.
  final String state;
  final Widget Function(BuildContext context, KitSceneCopy copy)? build;
  final FutureOr<void> Function(BuildContext context, KitSceneCopy copy)? open;
  final KitOverflowHost host;

  /// For KitSegmented (KIT-24): the labels are too long for one line at
  /// text 2.0 on a phone, so the part must stack its KitChoiceRows.
  final bool labelsOverflow;

  String get id => '${parts.first}/$state';
}

void _noop() {}

List<KitAction> _tertiary(KitSceneCopy c) => [
  KitAction(label: c.t('Copy the address', 'نسخ العنوان'), onPressed: _noop),
  KitAction(label: c.t('Open settings', 'فتح الإعدادات'), onPressed: _noop),
];

Widget _row(KitSceneCopy c, {Widget? trailing, bool enabled = true}) => KitRow(
  leading: const KitRowIcon(AppIconography.terminal),
  title: c.t('Workstation on the office network', 'محطة العمل على شبكة المكتب'),
  supporting: TextSpan(
    text: c.t('Connected · last reply a minute ago', 'متصل · آخر رد قبل دقيقة'),
  ),
  trailing: trailing ?? const KitChevron(),
  enabled: enabled,
  onTap: _noop,
);

Future<void> _sheet(
  BuildContext context,
  KitSceneCopy c, {
  KitSheetHeight height = KitSheetHeight.content,
  bool loading = false,
  bool disabled = false,
}) => showKitSheet<void>(
  context,
  title: c.t('Language', 'اللغة'),
  subtitle: c.t('Words across the whole app', 'الكلمات في كل التطبيق'),
  height: height,
  loading: loading ? ValueNotifier(true) : null,
  body: (_) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (en, ar) in const [
        ('English', 'الإنجليزية'),
        ('Arabic', 'العربية'),
        ('German', 'الألمانية'),
      ])
        KitRow(
          leading: const KitRowIcon(AppIconography.info),
          title: c.t(en, ar),
          supporting: TextSpan(
            text: c.t('Used for menus and messages', 'للقوائم والرسائل'),
          ),
          onTap: _noop,
        ),
    ],
  ),
  primary: KitAction(
    label: c.t('Use English', 'استخدام العربية'),
    onPressed: disabled ? null : _noop,
  ),
  secondary: KitAction(
    label: c.t('Keep current', 'إبقاء الحالية'),
    onPressed: _noop,
  ),
  tertiary: [
    KitAction(label: c.t('More languages', 'لغات أخرى'), onPressed: _noop),
  ],
);

Future<void> _confirm(
  BuildContext context,
  KitSceneCopy c, {
  KitConfirmKind kind = KitConfirmKind.neutral,
  bool full = false,
}) => showKitConfirm(
  context,
  title: c.t('Delete the conversation?', 'حذف المحادثة؟'),
  body: c.t(
    'It is removed from the server for everyone who can open it.',
    'تُزال من الخادم لكل من يستطيع فتحها.',
  ),
  confirmLabel: c.t('Delete conversation', 'حذف المحادثة'),
  kind: kind,
  consequences: full
      ? [
          c.t('Its 42 messages are gone', 'تُحذف رسائلها الـ42'),
          c.t('Shared links stop working', 'تتوقف الروابط المشاركة'),
        ]
      : const [],
  typedName: full ? 'release-notes-draft' : null,
  details: full
      ? const [
          KitTechnicalValue('Address', 'http://192.168.1.20:4096/session'),
          KitTechnicalValue('Branch', 'feature/very-long-branch-name-here'),
        ]
      : const [],
);

/// Every scene in the matrix, one block per part, appended at the end.
final kitOverflowScenes = <KitOverflowScene>[
  // product_states.dart (re-exported by kit.dart)
  KitOverflowScene(
    const ['LoadingList'],
    'loading',
    host: KitOverflowHost.fill,
    build: (_, _) => const LoadingList(),
  ),
  KitOverflowScene(
    const ['ProductEmptyState'],
    'empty',
    host: KitOverflowHost.fill,
    build: (_, c) => ProductEmptyState(
      icon: AppIconography.search,
      title: c.t('No conversations yet', 'لا محادثات بعد'),
      message: c.t(
        'Start one from the composer below, or open a project first.',
        'ابدأ واحدة من خانة الكتابة، أو افتح مشروعاً أولاً.',
      ),
      actionLabel: c.t('Open a project', 'فتح مشروع'),
      onAction: _noop,
    ),
  ),
  KitOverflowScene(
    const ['ProductErrorState'],
    'error',
    host: KitOverflowHost.fill,
    build: (_, c) => ProductErrorState(
      message: c.t(
        'The server did not answer. Check that it is running.',
        'لم يرد الخادم. تأكد أنه يعمل.',
      ),
      onRetry: () async {},
    ),
  ),
  KitOverflowScene(
    const ['ProductInlineEmpty'],
    'empty',
    build: (_, c) => ProductInlineEmpty(
      icon: AppIconography.info,
      title: c.t('Nothing is waiting for you', 'لا شيء بانتظارك'),
      message: c.t(
        'Requests from your agents appear here.',
        'تظهر طلبات الوكلاء هنا.',
      ),
      actionLabel: c.t('Open activity', 'فتح النشاط'),
      onAction: _noop,
    ),
  ),
  KitOverflowScene(
    const ['SectionLabel'],
    'default',
    build: (_, c) => SectionLabel(
      c.t('Servers on this network', 'الخوادم على هذه الشبكة'),
      trailing: const KitChevron(),
    ),
  ),
  // kit_action_stack.dart
  KitOverflowScene(
    const ['KitActionStack'],
    'default',
    build: (_, c) => KitActionStack(
      primary: KitAction(
        label: c.t('Connect to this server', 'الاتصال بهذا الخادم'),
        onPressed: _noop,
      ),
      secondary: KitAction(
        label: c.t('Scan the code instead', 'مسح الرمز بدلاً من ذلك'),
        onPressed: _noop,
      ),
      tertiary: _tertiary(c),
    ),
  ),
  // kit_ask_line.dart
  KitOverflowScene(
    const ['KitAskLine'],
    'default',
    build: (_, c) => KitAskLine(
      icon: AppIconography.info,
      question: c.t(
        'Keep the phone awake while agents work?',
        'إبقاء الهاتف مستيقظاً أثناء عمل الوكلاء؟',
      ),
      accept: KitAction(label: c.t('Keep awake', 'إبقاؤه'), onPressed: _noop),
      decline: KitAction(label: c.t('Not now', 'ليس الآن'), onPressed: _noop),
    ),
  ),
  // kit_buttons.dart
  KitOverflowScene(
    const ['KitButton'],
    'default',
    build: (_, c) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KitButton.primary(
          label: c.t('Send to the agent', 'إرسال إلى الوكيل'),
          icon: AppIconography.send,
          onPressed: _noop,
        ),
        KitButton.secondary(
          label: c.t('Save as a draft', 'حفظ كمسودة'),
          onPressed: _noop,
        ),
        KitButton.tertiary(
          label: c.t('Discard the message', 'تجاهل الرسالة'),
          destructive: true,
          onPressed: _noop,
        ),
        Row(
          children: [
            KitButton.secondary(
              label: c.t('Retry', 'إعادة'),
              expand: false,
              onPressed: _noop,
            ),
          ],
        ),
      ],
    ),
  ),
  KitOverflowScene(
    const ['KitButton'],
    'working',
    build: (_, c) => KitButton.primary(
      label: c.t('Sending to the agent', 'جارٍ الإرسال إلى الوكيل'),
      working: true,
      onPressed: _noop,
    ),
  ),
  KitOverflowScene(
    const ['KitButton'],
    'disabled',
    build: (_, c) => KitButton.primary(
      label: c.t('Send to the agent', 'إرسال إلى الوكيل'),
      onPressed: null,
    ),
  ),
  KitOverflowScene(
    const ['KitActionBlock'],
    'default',
    build: (_, c) => KitActionBlock(
      primary: KitAction(
        label: c.t('Start the server', 'تشغيل الخادم'),
        onPressed: _noop,
      ),
      secondary: KitAction(
        label: c.t('Choose another folder', 'اختيار مجلد آخر'),
        onPressed: _noop,
      ),
      tertiary: [
        ..._tertiary(c),
        KitAction(label: c.t('Report', 'إبلاغ'), onPressed: _noop),
      ],
    ),
  ),
  KitOverflowScene(
    const ['KitActionBlock'],
    'disabled',
    build: (_, c) => KitActionBlock(
      primary: KitAction(
        label: c.t('Start the server', 'تشغيل الخادم'),
        onPressed: null,
      ),
      secondary: KitAction(
        label: c.t('Choose another folder', 'اختيار مجلد آخر'),
        onPressed: null,
      ),
    ),
  ),
  KitOverflowScene(
    const ['KitInset'],
    'default',
    build: (_, c) => KitInset(
      child: Text(
        c.t(
          'Agents keep working while the phone is locked.',
          'يواصل الوكلاء العمل والهاتف مقفل.',
        ),
      ),
    ),
  ),
  // kit_icon_button.dart
  KitOverflowScene(
    const ['KitIconButton'],
    'default',
    build: (_, c) => Row(
      children: [
        KitIconButton(
          icon: AppIconography.copy,
          label: c.t('Copy', 'نسخ'),
          onPressed: _noop,
        ),
        KitIconButton(
          icon: AppIconography.close,
          label: c.t('Close', 'إغلاق'),
          onPressed: null,
        ),
      ],
    ),
  ),
  // kit_illustration.dart
  KitOverflowScene(
    const ['KitIllustration'],
    'default',
    build: (_, c) => Center(
      child: KitIllustration(
        scene: const KitPortalScene(),
        semanticLabel: c.t('A doorway', 'باب'),
      ),
    ),
  ),
  // kit_panel.dart
  KitOverflowScene(
    const ['KitPanel'],
    'default',
    build: (_, c) => KitPanel(
      tone: AppStatusTone.attention,
      icon: AppIconography.info,
      title: c.t('Battery saver is on', 'موفر البطارية مفعّل'),
      onTap: _noop,
      child: Text(
        c.t(
          'Android may pause agents after a few minutes in the background.',
          'قد يوقف أندرويد الوكلاء بعد دقائق في الخلفية.',
        ),
      ),
    ),
  ),
  // kit_notice.dart
  KitOverflowScene(
    const ['KitNotice'],
    'default',
    build: (_, c) => KitNotice(
      tone: AppStatusTone.failure,
      icon: AppIconography.info,
      title: c.t('The key was not accepted', 'لم يُقبل المفتاح'),
      message: c.t(
        'The provider said the key has expired. Paste a new one.',
        'قال المزوّد إن المفتاح منتهٍ. الصق مفتاحاً جديداً.',
      ),
      notes: [
        c.t('Keys start with sk-', 'تبدأ المفاتيح بـ sk-'),
        c.t('Nothing was saved', 'لم يُحفظ شيء'),
      ],
      actions: _tertiary(c),
      onDismiss: _noop,
    ),
  ),
  // kit_progress.dart
  KitOverflowScene(
    const ['KitLoadingBar'],
    'loading',
    build: (_, c) =>
        KitLoadingBar(loading: true, label: c.t('Loading', 'جارٍ التحميل')),
  ),
  KitOverflowScene(
    const ['KitSkeletonRows'],
    'loading',
    build: (_, _) => const KitSkeletonRows(),
  ),
  KitOverflowScene(
    const ['KitProgressView'],
    'working',
    build: (_, c) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KitProgressView(
          progress: KitProgress.known(
            0.62,
            caption: c.t(
              '29 of 30 MB · about 1 min left',
              '29 من 30 م.ب · نحو دقيقة متبقية',
            ),
          ),
        ),
        KitProgressView(
          progress: KitProgress.waiting(
            caption: c.t('Waiting for the server', 'بانتظار الخادم'),
          ),
        ),
      ],
    ),
  ),
  // kit_request_card.dart
  KitOverflowScene(
    const ['KitRequestCard'],
    'default',
    build: (_, c) => KitRequestCard(
      icon: AppIconography.terminal,
      title: c.t('Run a command?', 'تشغيل أمر؟'),
      announcement: c.t('The agent asks to run', 'يطلب الوكيل التشغيل'),
      tone: AppStatusTone.attention,
      summary: c.t(
        'Push the release branch to the shared remote',
        'دفع فرع الإصدار إلى المستودع المشترك',
      ),
      detail: 'git push origin main --force-with-lease --no-verify',
      primary: KitAction(
        label: c.t('Allow once', 'السماح مرة'),
        onPressed: _noop,
      ),
      secondary: KitAction(label: c.t('Deny', 'رفض'), onPressed: _noop),
      tertiary: [
        KitAction(
          label: c.t('Always allow in this project', 'السماح دائماً هنا'),
          onPressed: _noop,
        ),
      ],
    ),
  ),
  KitOverflowScene(
    const ['KitRequestCard'],
    'disabled',
    build: (_, c) => KitRequestCard(
      icon: AppIconography.terminal,
      title: c.t('Run a command?', 'تشغيل أمر؟'),
      announcement: c.t('The agent asks to run', 'يطلب الوكيل التشغيل'),
      summary: c.t('Answered on another device', 'أُجيب على جهاز آخر'),
      primary: KitAction(
        label: c.t('Allow once', 'السماح مرة'),
        onPressed: null,
      ),
      secondary: KitAction(label: c.t('Deny', 'رفض'), onPressed: null),
    ),
  ),
  // kit_row.dart
  KitOverflowScene(
    const ['KitRow'],
    'default',
    build: (_, c) => Column(
      children: [
        _row(c),
        KitRow(
          title: c.t(
            'A conversation title that runs long enough to wrap twice',
            'عنوان محادثة طويل بما يكفي ليلتف على سطرين',
          ),
          titleMaxLines: 2,
          supportingMaxLines: 2,
          supporting: TextSpan(
            text: c.t(
              'Updated 3 minutes ago in the release project',
              'حُدّثت قبل 3 دقائق في مشروع الإصدار',
            ),
          ),
          trailing: KitButton.tertiary(
            label: c.t('Open', 'فتح'),
            onPressed: _noop,
          ),
          onTap: _noop,
        ),
      ],
    ),
  ),
  KitOverflowScene(
    const ['KitRow'],
    'disabled',
    build: (_, c) => _row(c, enabled: false),
  ),
  // kit_row_parts.dart
  KitOverflowScene(
    const ['KitRowIcon', 'KitChevron'],
    'default',
    build: (_, c) => Column(
      children: [
        _row(c),
        KitRow(
          leading: const KitRowIcon(AppIconography.check, current: true),
          title: c.t('English', 'العربية'),
          trailing: const KitChevron(),
          onTap: _noop,
        ),
      ],
    ),
  ),
  KitOverflowScene(
    const ['KitRowMenu'],
    'default',
    build: (_, c) => _row(
      c,
      trailing: KitRowMenu(
        tooltip: c.t('More', 'المزيد'),
        items: [
          KitMenuItem(label: c.t('Rename', 'إعادة التسمية'), onSelected: _noop),
          KitMenuItem(
            label: c.t('Delete', 'حذف'),
            destructive: true,
            onSelected: _noop,
          ),
        ],
      ),
    ),
  ),
  KitOverflowScene(
    const ['KitRowMenu'],
    'disabled',
    build: (_, c) => _row(
      c,
      trailing: KitRowMenu(
        enabled: false,
        items: [
          KitMenuItem(label: c.t('Rename', 'إعادة التسمية'), onSelected: _noop),
        ],
      ),
    ),
  ),
  KitOverflowScene(
    const ['KitSwitchRow'],
    'default',
    build: (_, c) => KitSwitchRow(
      leading: const KitRowIcon(AppIconography.settings),
      title: c.t(
        'Keep agents working in the background',
        'إبقاء الوكلاء يعملون في الخلفية',
      ),
      supporting: c.t(
        'Android allows about six hours a day',
        'يسمح أندرويد بنحو ست ساعات يومياً',
      ),
      value: true,
      onChanged: (_) {},
    ),
  ),
  KitOverflowScene(
    const ['KitSwitchRow'],
    'disabled',
    build: (_, c) => KitSwitchRow(
      title: c.t('Vibrate when a reply arrives', 'الاهتزاز عند وصول رد'),
      value: false,
      onChanged: null,
    ),
  ),
  KitOverflowScene(
    const ['KitExpandRow'],
    'default',
    build: (_, c) => KitExpandRow(
      leading: const KitRowIcon(AppIconography.branch),
      title: c.t('Other ways to connect', 'طرق أخرى للاتصال'),
      supporting: TextSpan(
        text: c.t(
          'Scan a code or type an address',
          'امسح رمزاً أو اكتب عنواناً',
        ),
      ),
      children: [_row(c)],
    ),
  ),
  KitOverflowScene(
    const ['KitExpandRow'],
    'expanded',
    build: (_, c) => KitExpandRow(
      title: c.t('Other ways to connect', 'طرق أخرى للاتصال'),
      initiallyExpanded: true,
      children: [_row(c), _row(c)],
    ),
  ),
  // kit_screen.dart
  KitOverflowScene(
    const ['KitScreen'],
    'default',
    host: KitOverflowHost.fill,
    build: (_, c) => KitScreen(
      header: [SectionLabel(c.t('Servers', 'الخوادم'))],
      body: ListView(children: [_row(c), _row(c), _row(c)]),
      bottom: KitActionBlock(
        primary: KitAction(
          label: c.t('Add a server', 'إضافة خادم'),
          onPressed: _noop,
        ),
        tertiary: _tertiary(c),
      ),
    ),
  ),
  KitOverflowScene(
    const ['KitScreen'],
    'loading',
    host: KitOverflowHost.fill,
    build: (_, c) => KitScreen(
      loading: true,
      loadingLabel: c.t('Loading servers', 'جارٍ تحميل الخوادم'),
      body: const KitSkeletonRows(),
    ),
  ),
  // kit_secret_field.dart
  KitOverflowScene(
    const ['KitSecretField'],
    'default',
    build: (_, c) => KitSecretField(
      controller: TextEditingController(text: 'sk-test-not-a-real-key'),
      label: c.t('Provider key', 'مفتاح المزوّد'),
      showLabel: c.t('Show the key', 'إظهار المفتاح'),
      hideLabel: c.t('Hide the key', 'إخفاء المفتاح'),
      hint: c.t(
        'Paste the key from your account page',
        'الصق المفتاح من صفحة حسابك',
      ),
    ),
  ),
  KitOverflowScene(
    const ['KitSecretField'],
    'disabled',
    build: (_, c) => KitSecretField(
      controller: TextEditingController(),
      label: c.t('Provider key', 'مفتاح المزوّد'),
      showLabel: c.t('Show the key', 'إظهار المفتاح'),
      hideLabel: c.t('Hide the key', 'إخفاء المفتاح'),
      enabled: false,
    ),
  ),
  // kit_sheet.dart (KitSheet, showKitSheet)
  KitOverflowScene(
    const ['KitSheet', 'showKitSheet'],
    'default',
    host: KitOverflowHost.modal,
    open: (context, c) => _sheet(context, c),
  ),
  KitOverflowScene(
    const ['KitSheet', 'showKitSheet'],
    'full',
    host: KitOverflowHost.modal,
    open: (context, c) => _sheet(context, c, height: KitSheetHeight.full),
  ),
  KitOverflowScene(
    const ['KitSheet', 'showKitSheet'],
    'loading',
    host: KitOverflowHost.modal,
    open: (context, c) => _sheet(context, c, loading: true),
  ),
  KitOverflowScene(
    const ['KitSheet', 'showKitSheet'],
    'disabled',
    host: KitOverflowHost.modal,
    open: (context, c) => _sheet(context, c, disabled: true),
  ),
  KitOverflowScene(
    const ['KitSheet'],
    'inline',
    host: KitOverflowHost.fill,
    build: (_, c) => Align(
      alignment: AlignmentDirectional.bottomCenter,
      child: KitSheet(
        title: c.t('Language', 'اللغة'),
        subtitle: c.t('Words across the whole app', 'الكلمات في كل التطبيق'),
        primary: KitAction(
          label: c.t('Use English', 'استخدام العربية'),
          onPressed: _noop,
        ),
        secondary: KitAction(
          label: c.t('Keep current', 'إبقاء الحالية'),
          onPressed: _noop,
        ),
        onClose: _noop,
        child: _row(c),
      ),
    ),
  ),
  // kit_confirm_sheet.dart (KitConfirmSheet, showKitConfirm)
  KitOverflowScene(
    const ['KitConfirmSheet', 'showKitConfirm'],
    'neutral',
    host: KitOverflowHost.modal,
    open: (context, c) => _confirm(context, c),
  ),
  KitOverflowScene(
    const ['KitConfirmSheet', 'showKitConfirm'],
    'destructive',
    host: KitOverflowHost.modal,
    open: (context, c) =>
        _confirm(context, c, kind: KitConfirmKind.destructive, full: true),
  ),
  KitOverflowScene(
    const ['KitConfirmSheet', 'showKitConfirm'],
    'stop',
    host: KitOverflowHost.modal,
    open: (context, c) => _confirm(context, c, kind: KitConfirmKind.stop),
  ),
  for (final (state, working, failed) in const [
    ('working', true, false),
    ('error', false, true),
  ])
    KitOverflowScene(
      const ['KitConfirmSheet'],
      state,
      build: (_, c) => KitConfirmSheet(
        title: c.t('Stop the agent?', 'إيقاف الوكيل؟'),
        body: c.t(
          'The reply so far stays in the conversation.',
          'يبقى الرد حتى الآن في المحادثة.',
        ),
        confirmLabel: c.t('Stop working', 'إيقاف العمل'),
        kind: KitConfirmKind.stop,
        working: working,
        failed: failed,
        onConfirm: _noop,
        onCancel: _noop,
      ),
    ),
  // kit_skeleton_transcript.dart
  KitOverflowScene(
    const ['KitSkeletonTranscript'],
    'loading',
    build: (_, _) => const KitSkeletonTranscript(),
  ),
  // kit_state_view.dart
  KitOverflowScene(
    const ['KitStateView'],
    'error',
    host: KitOverflowHost.fill,
    build: (_, c) => KitStateView(
      icon: AppIconography.info,
      tone: AppStatusTone.failure,
      title: c.t('Could not reach the server', 'تعذّر الوصول إلى الخادم'),
      body: c.t(
        'Check that the computer is awake and on the same network.',
        'تأكد أن الحاسوب مستيقظ وعلى الشبكة نفسها.',
      ),
      primary: KitAction(
        label: c.t('Try again', 'إعادة المحاولة'),
        onPressed: _noop,
      ),
      secondary: KitAction(
        label: c.t('Edit the server', 'تعديل الخادم'),
        onPressed: _noop,
      ),
      tertiary: _tertiary(c),
      details:
          'SocketException: Connection refused (OS Error: 111), '
          'address = 192.168.1.20, port = 4096',
      detailNotes: [c.t('Is the server running?', 'هل الخادم يعمل؟')],
    ),
  ),
  KitOverflowScene(
    const ['KitStateView'],
    'working',
    host: KitOverflowHost.fill,
    build: (_, c) => KitStateView(
      icon: AppIconography.terminal,
      tone: AppStatusTone.progress,
      title: c.t('Setting up the phone', 'جارٍ تجهيز الهاتف'),
      body: c.t(
        'This takes a few minutes the first time.',
        'يستغرق ذلك دقائق في المرة الأولى.',
      ),
      progress: KitProgress.known(
        0.4,
        caption: c.t(
          '12 of 30 MB · about 2 min left',
          '12 من 30 م.ب · نحو دقيقتين',
        ),
      ),
      secondary: KitAction(
        label: c.t('Stop setup', 'إيقاف التجهيز'),
        onPressed: _noop,
      ),
    ),
  ),
  KitOverflowScene(
    const ['KitStateView'],
    'empty',
    build: (_, c) => KitStateView(
      icon: AppIconography.search,
      size: KitStateSize.inline,
      title: c.t('No matching files', 'لا ملفات مطابقة'),
      body: c.t('Try a shorter name.', 'جرّب اسماً أقصر.'),
      primary: KitAction(
        label: c.t('Clear the search', 'مسح البحث'),
        onPressed: _noop,
      ),
    ),
  ),
  KitOverflowScene(
    const ['KitStateView'],
    'illustrated',
    host: KitOverflowHost.fill,
    build: (_, c) => KitStateView(
      icon: AppIconography.info,
      illustration: const KitPortalScene(),
      title: c.t('Connect your first server', 'اتصل بأول خادم'),
      body: c.t(
        'Your agents run there; this phone steers them.',
        'يعمل وكلاؤك هناك، وهذا الهاتف يوجّههم.',
      ),
      primary: KitAction(
        label: c.t('Add a server', 'إضافة خادم'),
        onPressed: _noop,
      ),
    ),
  ),
  // kit_status_line.dart
  KitOverflowScene(
    const ['KitStatusLine'],
    'default',
    build: (_, c) => KitStatusLine(
      icon: AppIconography.info,
      tone: AppStatusTone.attention,
      message: c.t(
        'Reconnecting to the workstation on the office network',
        'جارٍ إعادة الاتصال بمحطة العمل على شبكة المكتب',
      ),
      supporting: c.t('Last reply 2 minutes ago', 'آخر رد قبل دقيقتين'),
      action: KitAction(
        label: c.t('Try now', 'المحاولة الآن'),
        onPressed: _noop,
      ),
      more: _tertiary(c),
      onDismiss: _noop,
      dismissTooltip: c.t('Dismiss', 'إغلاق'),
    ),
  ),
  KitOverflowScene(
    const ['KitStatusLine'],
    'together',
    build: (_, c) => KitStatusLine(
      icon: AppIconography.check,
      tone: AppStatusTone.ok,
      message: c.t('Saved to the server', 'حُفظ على الخادم'),
      action: KitAction(label: c.t('Undo', 'تراجع'), onPressed: _noop),
      controlsTogether: true,
    ),
  ),
  // kit_status_mark.dart
  KitOverflowScene(
    const ['KitStatusMark'],
    'default',
    build: (_, _) => Wrap(
      children: [
        for (final state in KitMarkState.values) KitStatusMark(state: state),
      ],
    ),
  ),
  // kit_task_mark.dart
  KitOverflowScene(
    const ['KitTaskMark'],
    'default',
    build: (_, _) => Wrap(
      children: [
        for (final state in KitTaskState.values) KitTaskMark(state: state),
      ],
    ),
  ),
  // motion/
  KitOverflowScene(
    const ['KitAnimatedRows'],
    'default',
    build: (_, c) => KitAnimatedRows(
      children: [
        KeyedSubtree(key: const ValueKey('first'), child: _row(c)),
        KeyedSubtree(key: const ValueKey('second'), child: _row(c)),
      ],
    ),
  ),
  KitOverflowScene(
    const ['KitRefresh'],
    'default',
    host: KitOverflowHost.fill,
    build: (_, c) => KitRefresh(
      onRefresh: () async {},
      child: ListView(children: [_row(c), _row(c)]),
    ),
  ),
  KitOverflowScene(
    const ['KitReveal', 'KitEntrance'],
    'default',
    build: (_, c) => Column(
      children: [
        KitReveal(child: _row(c)),
        KitEntrance(child: _row(c)),
      ],
    ),
  ),
  KitOverflowScene(
    const ['KitTabSwitcher'],
    'default',
    host: KitOverflowHost.fill,
    build: (_, c) => KitTabSwitcher(
      index: 0,
      children: [
        ListView(children: [_row(c)]),
        ListView(children: [_row(c), _row(c)]),
      ],
    ),
  ),
  // glass/
  KitOverflowScene(
    const ['KitGlass'],
    'default',
    build: (_, c) => KitGlass(child: _row(c)),
  ),
  // kit_effects.dart (lib/state/effects.dart)
  KitOverflowScene(
    const ['KitEffectsScope'],
    'default',
    build: (_, c) => KitEffectsScope(
      effects: const KitEffects(glass: false, motion: KitMotionLevel.off),
      child: _row(c),
    ),
  ),
  // kit_arrival.dart (slice-P9.4): a row arrived at, its wash on.
  KitOverflowScene(
    const ['KitArrival', 'KitArrivalScope'],
    'default',
    build: (_, c) => KitArrivalScope(
      rowId: 'arrived',
      child: KitArrival(id: 'arrived', child: _row(c)),
    ),
  ),
  // kit_text.dart (visual language merge, before the wave-0b gates)
  KitOverflowScene(
    const ['KitText'],
    'default',
    build: (_, c) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final role in KitTextRole.values)
          KitText(
            role == KitTextRole.mono
                ? r'$ flutter test test/checkout_test.dart'
                : c.t(
                    'Fix the flaky checkout test before the release',
                    'إصلاح اختبار الدفع غير المستقر قبل الإصدار',
                  ),
            role: role,
          ),
      ],
    ),
  ),
  // kit_row.dart: rows grouped on one panel, and a row's current value
  KitOverflowScene(
    const ['KitRowGroup', 'KitRowValue'],
    'default',
    build: (_, c) => KitRowGroup(
      label: c.t('Laptop on the office network', 'الحاسوب على شبكة المكتب'),
      children: [
        _row(c),
        KitRow(
          leading: const KitRowIcon(AppIconography.star),
          title: c.t('Model', 'النموذج'),
          trailing: const KitRowValue('Claude Sonnet 4'),
          onTap: _noop,
        ),
        KitRow(
          leading: const KitRowIcon(AppIconography.shield),
          title: c.t('What agents may do', 'ما يمكن للوكلاء فعله'),
          trailing: KitRowValue(c.t('Ask first', 'اسأل أولاً'), chevron: false),
          onTap: _noop,
        ),
      ],
    ),
  ),
  // ── Kit tier 1 (integration 2026-09-27). Arabic is dropped (owner
  // decision), so these scenes use the English copy in both directions.
  KitOverflowScene(
    const ['KitSurface'],
    'default',
    build: (_, c) => KitSurface(child: _row(c)),
  ),
  KitOverflowScene(
    const ['KitDivider'],
    'default',
    build: (_, c) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_row(c), const KitDivider(), _row(c)],
    ),
  ),
  KitOverflowScene(
    const ['KitIcon', 'KitBrandMark'],
    'default',
    build: (_, _) => const Row(
      children: [
        KitIcon(AppIconography.terminal),
        SizedBox(width: 12),
        KitBrandMark(),
      ],
    ),
  ),
  KitOverflowScene(
    const ['KitChip', 'KitChipWrap'],
    'default',
    build: (_, _) => KitChipWrap(
      children: [
        const KitChip(label: 'feature/checkout-retry'),
        KitChip.action(label: 'Needs you', onPressed: _noop, selected: true),
        KitChip.removable(label: 'lib/checkout/retry.dart', onRemove: _noop),
        KitChip.count(label: 'Tasks', count: 3),
        KitChip.summary(label: 'Read 3 files · edited 1', onPressed: _noop),
      ],
    ),
  ),
  KitOverflowScene(
    const ['KitSegmented'],
    'default',
    build: (_, _) => KitSegmented<String>(
      segments: const [
        KitSegment(value: 'today', label: 'Today'),
        KitSegment(value: 'week', label: 'This week'),
        KitSegment(value: 'month', label: 'This month'),
      ],
      selected: 'week',
      onChanged: (_) {},
      semanticsLabel: 'Time range',
    ),
  ),
  KitOverflowScene(
    const ['KitMenuPanel'],
    'default',
    build: (_, _) => KitMenuPanel(
      items: [
        KitMenuItem(label: 'Rename conversation', onSelected: _noop),
        KitMenuItem(label: 'Archive conversation', onSelected: _noop),
        KitMenuItem(
          label: 'Delete conversation',
          onSelected: _noop,
          destructive: true,
        ),
      ],
      onSelected: (_) {},
    ),
  ),
  KitOverflowScene(
    const ['showKitMenu'],
    'default',
    host: KitOverflowHost.modal,
    open: (context, _) => showKitMenu(
      context,
      items: [
        KitMenuItem(label: 'Rename conversation', onSelected: _noop),
        KitMenuItem(label: 'Archive conversation', onSelected: _noop),
      ],
    ),
  ),
  KitOverflowScene(
    const ['KitTerm'],
    'default',
    build: (_, _) => const KitTerm(
      'MCP',
      explanation:
          'A way to give the assistant extra tools, such as your issue '
          'tracker or a database.',
    ),
  ),
  KitOverflowScene(
    const ['showKitTerm'],
    'default',
    host: KitOverflowHost.modal,
    open: (context, _) => showKitTerm(
      context,
      term: 'MCP',
      explanation:
          'A way to give the assistant extra tools, such as your issue '
          'tracker or a database.',
    ),
  ),
  KitOverflowScene(
    const ['showKitUndo'],
    'default',
    host: KitOverflowHost.modal,
    open: (context, _) {
      showKitUndo(
        context,
        message: 'Archived "Fix the flaky checkout test"',
        onUndo: _noop,
      );
      // Settle it at once so no undo window is left running after the scene.
      Future<void>.delayed(
        const Duration(milliseconds: 700),
        KitUndo.commitPending,
      );
    },
  ),
  KitOverflowScene(
    const ['KitBottomInset'],
    'default',
    build: (_, c) =>
        KitBottomInset(insets: const KitClearance(bottom: 80), child: _row(c)),
  ),
  KitOverflowScene(
    const ['KitSince'],
    'default',
    build: (_, _) => KitSince(
      since: DateTime(2026),
      builder: (context, status) =>
          KitText('Waiting for the server to answer · ${status.phase.name}'),
    ),
  ),
  KitOverflowScene(
    const ['KitAvatar', 'KitImage', 'KitZoom'],
    'default',
    build: (_, _) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const KitAvatar(name: 'Open AI'),
        const SizedBox(height: 16),
        SizedBox(
          width: 120,
          height: 90,
          child: KitImage(
            source: KitImageSource.provider(
              MemoryImage(Uint8List.fromList(_onePixelPng)),
            ),
            semanticsLabel: 'A photo',
          ),
        ),
        const SizedBox(height: 16),
        const SizedBox(
          width: 280,
          height: 200,
          child: KitZoom(
            label: 'Screenshot.png',
            child: SizedBox(
              width: 160,
              height: 120,
              child: ColoredBox(color: Color(0xFF3D6BFF)),
            ),
          ),
        ),
      ],
    ),
  ),
  KitOverflowScene(
    const ['KitQr'],
    'default',
    build: (_, _) => const KitQr(
      data: 'https://example.com/join/3f9c2a',
      semanticsLabel: 'Code to open this session on another device',
    ),
  ),
  KitOverflowScene(
    const ['KitLevelMeter'],
    'default',
    build: (_, _) => const KitLevelMeter(level: 0.6),
  ),
  KitOverflowScene(
    const ['KitSwatch', 'KitSwatchGrid', 'KitThemePreview'],
    'default',
    build: (context, _) {
      final roles = KitTokens.of(context).roles;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KitSwatchGrid(
            label: 'Theme',
            children: [
              KitSwatch(
                roles: roles,
                label: 'Graphite',
                selected: true,
                onPressed: _noop,
              ),
              KitSwatch(
                roles: null,
                label: 'Material You',
                selected: false,
                onPressed: null,
                disabledReason: 'Needs Android 12 or later',
              ),
            ],
          ),
          const SizedBox(height: 16),
          KitThemePreview(roles: roles, label: 'Preview of Graphite'),
        ],
      );
    },
  ),
  KitOverflowScene(
    const ['KitTerminalView'],
    'default',
    build: (_, _) => const KitTerminalView.output(
      command: 'flutter test test/checkout_test.dart',
      output:
          '00:02 +12: All tests passed!\n'
          'Ran 12 tests in lib/checkout and lib/payments in 2.4 seconds',
    ),
  ),
  KitOverflowScene(
    const ['KitSelectable', 'KitLtr'],
    'default',
    build: (_, _) => const KitSelectable(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KitText('Fix the flaky checkout test before the release'),
          KitLtr(child: KitText('OPENCODE_SERVER=http://127.0.0.1:4096')),
        ],
      ),
    ),
  ),
  KitOverflowScene(
    const ['KitConsequences'],
    'default',
    build: (_, _) => KitConsequences(
      items: const [
        KitConsequence('The conversation and its 42 messages are removed'),
        KitConsequence('Files the agent changed stay as they are'),
      ],
    ),
  ),
  KitOverflowScene(
    const ['KitSwap', 'KitSpin', 'KitDim'],
    'default',
    build: (_, c) => Row(
      children: [
        const KitSpin(turns: 0.25, child: KitIcon(AppIconography.retry)),
        const SizedBox(width: 12),
        // A drawing, not a glyph: a glyph is a paragraph (LOOK-14).
        const KitDim(
          child: SizedBox.square(
            dimension: 24,
            child: ColoredBox(color: Color(0xFF3D6BFF)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: KitSwap(child: _row(c))),
      ],
    ),
  ),
  KitOverflowScene(
    const ['KitAnimatedBox', 'KitAnimatedValue'],
    'default',
    build: (_, c) => KitAnimatedBox(
      level: KitSurfaceLevel.surface2,
      child: KitAnimatedValue(
        value: 0.4,
        builder: (context, value) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _row(c),
            KitText('Uploaded ${(value * 100).round()} % of the build'),
          ],
        ),
      ),
    ),
  ),
];

/// A valid 1x1 opaque PNG (the fixture kit_image_test.dart uses).
const _onePixelPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00, 0x00,
  0x90, 0x77, 0x53, 0xDE,
  0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54,
  0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00, 0x03, 0x01, 0x01, 0x00,
  0x18, 0xDD, 0x8D, 0xB0,
  0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
];
