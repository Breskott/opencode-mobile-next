// slice-R8 (docs/ux-system/revamp/leftover-units.json): KitField and
// KitSearchField fall back to English without localization delegates;
// KitProgressRow.segments stacks its legend at 2.0 text and its 4th /
// "Other" fills stand apart from the unfilled track; KitAvatar's error
// badge clears the initials.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/kit/r08_kit_fields_progress_avatar_test.dart
// and look at every changed image before committing it.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_field.dart';
import 'package:opencode_mobile/ui/kit/kit_image.dart';
import 'package:opencode_mobile/ui/kit/kit_progress_row.dart';
import 'package:opencode_mobile/ui/kit/kit_search_field.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import '../goldens/kit/kit_gallery.dart';

const _segments = [
  KitProgressSegment(
    label: 'Conversation',
    value: 0.41,
    valueLabel: '41k tokens',
  ),
  KitProgressSegment(
    label: 'System prompt',
    value: 0.12,
    valueLabel: '12k tokens',
  ),
  KitProgressSegment(label: 'Tools', value: 0.09, valueLabel: '9k tokens'),
  KitProgressSegment(label: 'History', value: 0.09, valueLabel: '9k tokens'),
  KitProgressSegment(label: 'Cache', value: 0.05, valueLabel: '5k tokens'),
];

const _segmentsRow = KitProgressRow.segments(
  title: 'Context used',
  segments: _segments,
  valueLabel: '76 % of 200k tokens',
);

/// A bare harness: MaterialApp with no app localization delegates.
Widget _bare(Widget child, {double textScale = 1}) => MaterialApp(
  theme: AppTheme.dark(),
  builder: (context, inner) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: true,
      textScaler: TextScaler.linear(textScale),
    ),
    child: inner!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: child,
    ),
  ),
);

class _FailingProvider extends ImageProvider<_FailingProvider> {
  const _FailingProvider();

  @override
  Future<_FailingProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _FailingProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    Future<ImageInfo>.error(StateError('r08: forced failure')),
  );

  @override
  bool operator ==(Object other) => other is _FailingProvider;

  @override
  int get hashCode => runtimeType.hashCode;
}

void main() {
  group('English fallback without localization delegates', () {
    testWidgets('KitField shows its counter words', (tester) async {
      final controller = TextEditingController(text: '123456789');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _bare(KitField(label: 'Name', controller: controller, maxLength: 10)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('9 of 10'), findsOneWidget);
    });

    testWidgets('KitField.secret shows Saved and Replace', (tester) async {
      await tester.pumpWidget(
        _bare(KitField.secret(label: 'API key', saved: true, onReplace: () {})),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Replace'), findsOneWidget);
    });

    testWidgets('KitSearchField shows its result count and clear', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'lap');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _bare(
          KitSearchField(
            label: 'Search servers',
            controller: controller,
            onChanged: (_) {},
            resultCount: 3,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(find.text('3 results'), findsOneWidget);
      expect(find.byTooltip('Clear search'), findsOneWidget);
    });
  });

  group('KitProgressRow.segments', () {
    testWidgets('2.0 text: one legend entry per line, no overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_bare(_segmentsRow, textScale: 2));
      await tester.pump();
      expect(tester.takeException(), isNull);
      // Every entry sits on its own line: the labels' tops strictly
      // descend, and all start at the same x.
      final labels = ['Conversation', 'System prompt', 'Tools', 'History'];
      final tops = [for (final l in labels) tester.getTopLeft(find.text(l))];
      for (var i = 1; i < tops.length; i++) {
        expect(tops[i].dy, greaterThan(tops[i - 1].dy));
        expect(tops[i].dx, tops[0].dx);
      }
      expect(find.text('Other'), findsOneWidget);
    });

    testWidgets('1.0 text at width keeps two legend columns', (tester) async {
      tester.view.physicalSize = const Size(1280, 800) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_bare(_segmentsRow));
      await tester.pump();
      final first = tester.getTopLeft(find.text('Conversation'));
      final second = tester.getTopLeft(find.text('System prompt'));
      expect(second.dy, first.dy);
    });

    testWidgets('the 4th and Other fills differ from the unfilled track', (
      tester,
    ) async {
      await tester.pumpWidget(_bare(_segmentsRow));
      await tester.pump();
      final theme = Theme.of(tester.element(find.byType(KitProgressRow)));
      final roles = AppTheme.rolesOf(theme);
      final fills = KitTokens.of(
        tester.element(find.byType(KitProgressRow)),
      ).segmentFills;
      // The unfilled track is a colour no fill uses, and the 4th and
      // "Other" fills (`surface3`) are drawn over it, then the outline.
      expect(fills.contains(roles.surface1), isFalse);
      final bar = find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            w.painter.runtimeType.toString() == '_BarPainter',
      );
      expect(
        bar,
        paints
          ..rect(color: roles.surface1)
          ..rect(color: fills[0])
          ..rect(color: fills[1])
          ..rect(color: fills[2])
          ..rect(color: roles.surface3)
          ..rect(color: roles.surface3)
          ..rrect(color: roles.hairline, style: PaintingStyle.stroke),
      );
    });
  });

  testWidgets('KitAvatar error badge does not cover the initials', (
    tester,
  ) async {
    for (final size in KitAvatarSize.values) {
      await tester.pumpWidget(
        _bare(
          Center(
            child: KitAvatar(
              key: ValueKey(size),
              name: 'A teammate',
              size: size,
              image: KitImageSource.provider(const _FailingProvider()),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      final badge = find.byIcon(KitTokens.glyphFor(AppStatusTone.failure));
      expect(badge, findsOneWidget, reason: '$size');
      final initials = tester.getRect(find.text('AT'));
      final glyph = tester.getRect(badge);
      final overlap = initials.intersect(glyph);
      expect(
        overlap.width <= 0 || overlap.height <= 0,
        isTrue,
        reason: '$size: initials $initials, badge $glyph',
      );
    }
  });

  group('gallery', () {
    setUpAll(loadKitGalleryFonts);
    for (final light in [false, true]) {
      for (final size in const [Size(412, 915), Size(1280, 800)]) {
        final name = kitGalleryName(
          'kit_progress_row_segments',
          size,
          light: light,
          text2: true,
        );
        testWidgets(name, (tester) async {
          await kitGalleryPart(
            tester,
            name: '../goldens/kit/$name',
            size: size,
            light: light,
            textScale: 2,
            child: _segmentsRow,
          );
        });
      }
    }
  });
}
