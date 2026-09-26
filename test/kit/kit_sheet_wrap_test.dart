// KitSheet's title/subtitle wrap at 200% text (A11Y-8, docs/ux-system/
// kit-api/KitSheet.md "Tests required" #2): a long title and a two-sentence
// subtitle lay out fully, never truncated, and nothing overflows.
//
// Its own file, not test/kit/kit_sheet_test.dart: measuring a realistic
// wrap needs the app's own face loaded (the default `flutter test` font
// renders every glyph as a fixed-width box roughly one em wide, wrapping
// far sooner, and taller, than the app ever does on a device), and
// FontLoader must run in setUpAll — loading it inside a testWidgets body
// hangs the test (real dart:io I/O inside the widget-test zone never
// completes).
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_harness.dart';

Future<void> _loadRealSansFont() async {
  final loader = FontLoader(AppTheme.sansFamily);
  loader.addFont(
    File(
      'assets/fonts/geist/Geist-Variable.ttf',
    ).readAsBytes().then(ByteData.sublistView),
  );
  await loader.load();
}

void main() {
  setUpAll(_loadRealSansFont);

  testWidgets('title and subtitle wrap fully at 2.0 text (A11Y-8)', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final context = await pumpKitHost(tester);
    const title =
        '123456789012345678901234567890123456789012345678901234'
        '56789012'; // 60 chars
    const subtitle =
        'This sentence is long enough to wrap on its own. So is this one.';
    unawaited(
      showKitSheet<void>(
        context,
        title: title,
        subtitle: subtitle,
        body: (_) => const Text('English'),
      ),
    );
    await tester.pumpAndSettle();
    RenderParagraph paragraphOf(String text) =>
        tester.renderObject<RenderParagraph>(
          find.descendant(of: find.text(text), matching: find.byType(RichText)),
        );
    expect(paragraphOf(title).didExceedMaxLines, isFalse);
    expect(paragraphOf(subtitle).didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });
}
