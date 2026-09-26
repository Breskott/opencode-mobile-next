// Gallery (gate G4) for KitSegmented (docs/ux-system/kit-api/KitSegmented.md
// §"Galleries required"): the default, with-counts, segment-disabled and
// disabled scenes at 412x915, the default state at the other §8.4 sizes, and
// the default state in Arabic (right to left), each in dark and light.
//
// Not here yet, because they need kit-KitChoiceList's `KitChoiceRow`
// (KIT-24), which has not merged: the "stacked" scene, and the default state
// at text 2.0, which the spec says shows the stacked form. A text-2.0
// baseline of the one-row form would contradict the spec, so none is
// committed. See docs/qa/revamp-kit-KitSegmented-2026-09-26/README.md.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_segmented_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_segmented.dart';

import 'kit_gallery.dart';

class _Copy {
  const _Copy({
    required this.timeRange,
    required this.today,
    required this.week,
    required this.month,
    required this.filter,
    required this.all,
    required this.needsYou,
    required this.done,
    required this.mode,
    required this.chat,
    required this.voice,
    required this.camera,
    required this.cameraReason,
    required this.scope,
    required this.mine,
    required this.team,
    required this.workspace,
    required this.scopeReason,
  });

  final String timeRange;
  final String today;
  final String week;
  final String month;
  final String filter;
  final String all;
  final String needsYou;
  final String done;
  final String mode;
  final String chat;
  final String voice;
  final String camera;
  final String cameraReason;
  final String scope;
  final String mine;
  final String team;
  final String workspace;
  final String scopeReason;
}

const _en = _Copy(
  timeRange: 'Time range',
  today: 'Today',
  week: 'Week',
  month: 'Month',
  filter: 'Filter',
  all: 'All',
  needsYou: 'Needs you',
  done: 'Done',
  mode: 'Mode',
  chat: 'Chat',
  voice: 'Voice',
  camera: 'Camera',
  cameraReason: 'Chosen at install · reinstall to change',
  scope: 'Scope',
  mine: 'Mine',
  team: 'Team',
  workspace: 'Workspace',
  scopeReason: 'Set by your workspace admin',
);

const _ar = _Copy(
  timeRange: 'النطاق الزمني',
  today: 'اليوم',
  week: 'الأسبوع',
  month: 'الشهر',
  filter: 'التصفية',
  all: 'الكل',
  needsYou: 'يحتاجك',
  done: 'تم',
  mode: 'الوضع',
  chat: 'الدردشة',
  voice: 'الصوت',
  camera: 'الكاميرا',
  cameraReason: 'اختير عند التثبيت · أعد التثبيت للتغيير',
  scope: 'النطاق',
  mine: 'لي',
  team: 'الفريق',
  workspace: 'مساحة العمل',
  scopeReason: 'حدده مسؤول مساحة العمل',
);

Widget _default(_Copy copy) => KitSegmented<String>(
  segments: [
    KitSegment(value: 'today', label: copy.today),
    KitSegment(value: 'week', label: copy.week),
    KitSegment(value: 'month', label: copy.month),
  ],
  selected: 'week',
  onChanged: (_) {},
  semanticsLabel: copy.timeRange,
);

Widget _counts(_Copy copy) => KitSegmented<String>(
  segments: [
    KitSegment(value: 'all', label: copy.all),
    KitSegment(value: 'needsYou', label: copy.needsYou, count: 2),
    KitSegment(value: 'done', label: copy.done),
  ],
  selected: 'needsYou',
  onChanged: (_) {},
  semanticsLabel: copy.filter,
);

Widget _segmentDisabled(_Copy copy) => KitSegmented<String>(
  segments: [
    KitSegment(value: 'chat', label: copy.chat),
    KitSegment(value: 'voice', label: copy.voice),
    KitSegment(
      value: 'camera',
      label: copy.camera,
      enabled: false,
      disabledReason: copy.cameraReason,
    ),
  ],
  selected: 'chat',
  onChanged: (_) {},
  semanticsLabel: copy.mode,
);

Widget _disabled(_Copy copy) => KitSegmented<String>(
  segments: [
    KitSegment(value: 'mine', label: copy.mine),
    KitSegment(value: 'team', label: copy.team),
    KitSegment(value: 'workspace', label: copy.workspace),
  ],
  selected: 'mine',
  onChanged: null,
  semanticsLabel: copy.scope,
  disabledReason: copy.scopeReason,
);

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    // Every scene the spec names (bar "stacked"), dark and light, at 412x915.
    testWidgets('default · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_segmented_default',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _default(_en),
      );
    });
    testWidgets('with counts · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_segmented_with_counts',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _counts(_en),
      );
    });
    testWidgets('segment disabled · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_segmented_segment_disabled',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _segmentDisabled(_en),
      );
    });
    testWidgets('disabled · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_segmented_disabled',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _disabled(_en),
      );
    });

    // The default state at the other §8.4 sizes.
    for (final size in [
      ...kitGallerySizes.where((s) => s != const Size(412, 915)),
      const Size(915, 412),
    ]) {
      final at = kitGallerySize(size);
      testWidgets('default · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_segmented_default', size, light: light),
          size: size,
          light: light,
          child: _default(_en),
        );
      });
    }

    // The default state in Arabic, at 412x915 and 1280x800. Its text-2.0
    // twins wait for the stacked form (see the file header).
    for (final size in kitGalleryScaledSizes) {
      final at = kitGallerySize(size);
      testWidgets('default · Arabic · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_segmented_default',
            size,
            light: light,
            ar: true,
          ),
          size: size,
          light: light,
          locale: const Locale('ar'),
          textScale: 1.3,
          child: _default(_ar),
        );
      });
    }
  }
}
