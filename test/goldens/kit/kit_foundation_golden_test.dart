// Gallery (gate G4) for the visual language v1 foundation
// (docs/design/visual-language-2026-09-26.md): the type roles (KitText),
// the button hierarchy (KitButton), grouped rows (KitRowGroup, KitRowValue),
// the needs-you card (KitNotice.card) and the request card (KitRequestCard),
// on a phone at 3x and a PC window, light and dark, at 2.0 text and in
// Arabic (right to left).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_foundation_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

class _Copy {
  const _Copy({
    required this.project,
    required this.meta,
    required this.caption,
    required this.cardTitle,
    required this.open,
    required this.allow,
    required this.working,
    required this.rows,
    required this.laptop,
    required this.settings,
    required this.run,
    required this.runDetail,
    required this.dontRun,
    required this.runOnce,
  });

  final String project;
  final String meta;
  final String caption;
  final String cardTitle;
  final String open;
  final String allow;
  final String working;
  final List<(IconData, String, String)> rows;
  final String laptop;
  final List<(IconData, String, String)> settings;
  final String run;
  final String runDetail;
  final String dontRun;
  final String runOnce;
}

const _en = _Copy(
  project: 'shopfront',
  meta: 'main · 2 working · 1 needs you',
  caption: 'Needs you · 40 s ago',
  cardTitle: 'Fix flaky checkout test wants to run a command',
  open: 'Open',
  allow: 'Allow once',
  working: 'Working now',
  rows: [
    (
      AppIconography.terminal,
      'Speed up the CI pipeline',
      'Editing workflow files · 4 min',
    ),
    (
      AppIconography.info,
      'Explain the payments module',
      'Answered · yesterday',
    ),
  ],
  laptop: 'Laptop',
  settings: [
    (AppIconography.star, 'Model', 'Claude Sonnet 4'),
    (AppIconography.shield, 'What agents may do', 'Ask first'),
    (AppIconography.mic, 'Voice', 'English'),
  ],
  run: 'Run this command?',
  runDetail: 'To check the fix · in shopfront',
  dontRun: 'Don’t run',
  runOnce: 'Run once',
);

const _ar = _Copy(
  project: 'shopfront',
  meta: 'main · اثنان يعملان · واحد يحتاجك',
  caption: 'يحتاجك · قبل 40 ثانية',
  cardTitle: 'إصلاح اختبار الدفع يريد تشغيل أمر',
  open: 'افتح',
  allow: 'اسمح مرة',
  working: 'يعمل الآن',
  rows: [
    (
      AppIconography.terminal,
      'تسريع خط التكامل',
      'تعديل ملفات سير العمل · 4 دقائق',
    ),
    (AppIconography.info, 'شرح وحدة الدفع', 'تمت الإجابة · أمس'),
  ],
  laptop: 'الحاسوب',
  settings: [
    (AppIconography.star, 'النموذج', 'Claude Sonnet 4'),
    (AppIconography.shield, 'ما يمكن للوكلاء فعله', 'اسأل أولاً'),
    (AppIconography.mic, 'الصوت', 'العربية'),
  ],
  run: 'تشغيل هذا الأمر؟',
  runDetail: 'للتحقق من الإصلاح · في shopfront',
  dontRun: 'لا تشغّل',
  runOnce: 'شغّل مرة',
);

Widget _work(_Copy copy) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KitText(copy.project, role: KitTextRole.largeTitle),
          const SizedBox(height: 4),
          KitText(copy.meta, role: KitTextRole.secondary),
        ],
      ),
    ),
    const SizedBox(height: 20),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: KitNotice.card(
        icon: AppIconography.terminal,
        caption: copy.caption,
        title: copy.cardTitle,
        message: 'flutter test test/checkout_test.dart',
        secondary: KitAction(label: copy.open, onPressed: () {}),
        primary: KitAction(label: copy.allow, onPressed: () {}),
      ),
    ),
    const SizedBox(height: 22),
    KitRowGroup(
      label: copy.working,
      children: [
        for (final (icon, title, supporting) in copy.rows)
          KitRow(
            leading: KitRowIcon(icon),
            title: title,
            supporting: TextSpan(text: supporting),
            trailing: const KitChevron(),
            onTap: () {},
          ),
      ],
    ),
    const SizedBox(height: 22),
    KitRowGroup(
      label: copy.laptop,
      children: [
        for (final (icon, title, value) in copy.settings)
          KitRow(
            leading: KitRowIcon(icon),
            title: title,
            trailing: KitRowValue(value),
            onTap: () {},
          ),
      ],
    ),
    const SizedBox(height: 22),
    KitRequestCard(
      icon: AppIconography.terminal,
      tone: AppStatusTone.attention,
      title: copy.run,
      announcement: copy.run,
      summary: r'$ flutter test test/checkout_test.dart',
      detail: copy.runDetail,
      secondary: KitAction(label: copy.dontRun, onPressed: () {}),
      primary: KitAction(label: copy.runOnce, onPressed: () {}),
    ),
  ],
);

Widget _type() => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 20),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final role in KitTextRole.values) ...[
        KitText(
          role == KitTextRole.mono
              ? r'$ flutter test test/checkout_test.dart'
              : '${role.name} · Fix flaky checkout test',
          role: role,
        ),
        const SizedBox(height: 10),
      ],
      const KitText(
        'Needs you · 40 s ago',
        role: KitTextRole.caption,
        tone: KitTextTone.attention,
      ),
      const SizedBox(height: 10),
      const KitText(
        'Stop removes the queued work',
        role: KitTextRole.secondary,
        tone: KitTextTone.danger,
      ),
      const SizedBox(height: 20),
      KitButton.primary(label: 'Allow once', onPressed: () {}),
      const SizedBox(height: 12),
      KitButton.secondary(label: 'Open', onPressed: () {}),
      const SizedBox(height: 12),
      KitButton.primary(
        label: 'Stop task',
        destructive: true,
        onPressed: () {},
      ),
      const SizedBox(height: 12),
      const KitButton.primary(label: 'Not available now', onPressed: null),
      const SizedBox(height: 4),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: KitButton.tertiary(label: 'See all', onPressed: () {}),
      ),
    ],
  ),
);

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in [const Size(412, 915), const Size(1280, 800)]) {
      final at = kitGallerySize(size);
      testWidgets('foundation work · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_foundation_work', size, light: light),
          size: size,
          light: light,
          child: _work(_en),
        );
      });
    }
    testWidgets('foundation type and buttons · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_foundation_type',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _type(),
      );
    });
    testWidgets('foundation work · 2.0 text · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_foundation_work',
          const Size(412, 915),
          light: light,
          text2: true,
        ),
        size: const Size(412, 915),
        light: light,
        textScale: 2,
        child: _work(_en),
      );
    });
    testWidgets('foundation work · Arabic · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_foundation_work',
          const Size(412, 915),
          light: light,
          ar: true,
        ),
        size: const Size(412, 915),
        light: light,
        locale: const Locale('ar'),
        textScale: 1.3,
        child: _work(_ar),
      );
    });
  }
}
