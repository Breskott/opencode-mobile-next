// The file-change view (KitDiffView) for the conversation's Review changes:
// a file with one change (no arrows, no count, no More button; the folded
// lines are one line) and a file with two.
import 'package:flutter/material.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:widgetbook/widgetbook.dart';

import '../catalog.dart';

const _patch =
    '--- a/test/design_system_test.dart\n'
    '+++ b/test/design_system_test.dart\n'
    '@@ -53,6 +53,4 @@\n'
    "       RegExp(r'Color\\(0x'),\n"
    "       exempt: {'lib/ui/theme.dart', 'lib/ui/design/tokens.dart'},\n"
    '-      // Player overlay predates OverlayColors; migrate, then lower.\n'
    "-      legacyCaps: {'lib/ui/player/player_screen.dart': 36},\n"
    '     ),\n'
    '     isEmpty,\n';

const _twoChanges =
    '--- a/test/design_system_test.dart\n'
    '+++ b/test/design_system_test.dart\n'
    '@@ -53,6 +53,4 @@\n'
    "       RegExp(r'Color\\(0x'),\n"
    "       exempt: {'lib/ui/theme.dart', 'lib/ui/design/tokens.dart'},\n"
    '-      // Player overlay predates OverlayColors; migrate, then lower.\n'
    "-      legacyCaps: {'lib/ui/player/player_screen.dart': 36},\n"
    '     ),\n'
    '     isEmpty,\n'
    '@@ -90,3 +88,4 @@\n'
    '   test(\'the focus order is stable\', () {\n'
    '-    expect(order, isNotEmpty);\n'
    '+    expect(order, hasLength(3));\n'
    '+    expect(order.first, isNotNull);\n'
    '   });\n';

Widget _view(String patch) => Scaffold(
  body: SafeArea(
    child: KitDiffView(
      files: [KitDiffFile.fromPatch('test/design_system_test.dart', patch)],
      fileActions: (file) => [
        KitMenuItem(label: 'Comment on file', onSelected: () {}),
      ],
    ),
  ),
);

CatalogComponent kitDiffView() => catalogComponent(
  area: 'Chats',
  name: 'KitDiffView',
  useCases: [
    WidgetbookUseCase(name: 'One change', builder: (_) => _view(_patch)),
    WidgetbookUseCase(name: 'Two changes', builder: (_) => _view(_twoChanges)),
  ],
);
