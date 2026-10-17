// The clean work steps (owner 2026-10-14): one 32 dp line per step with no
// tool-name title, one rail x for the header and every node, a rail that ends
// on the last node, one chevron (the group's), and a full diff page whose
// header is the page's own ground, not a card. Reduced motion throughout.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/chat/kit_step_timeline.dart';
import 'package:opencode_mobile/ui/kit/chat/kit_tool_row.dart';
import 'package:opencode_mobile/ui/kit/kit_diff_view.dart';
import 'package:opencode_mobile/ui/kit/kit_motion.dart';
import 'package:opencode_mobile/ui/kit/kit_status_mark.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/kit/motion/kit_motion_parts.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: widget!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
  await tester.pump();
}

KitStepTimeline _timeline(List<Widget> steps) => KitStepTimeline(
  label: 'Ran 2 commands',
  icon: AppIconography.fileText,
  expanded: true,
  onPressed: () {},
  steps: steps,
);

const _ids = [ValueKey('step-a'), ValueKey('step-b'), ValueKey('step-c')];

KitToolRow _shell(int i, {KitToolStatus status = KitToolStatus.done}) =>
    KitToolRow(
      rowKey: _ids[i],
      kind: KitToolKind.shell,
      title: 'Shell',
      path: 'find /root/projects -iname "*review*"',
      pathCut: KitMonoCut.end,
      status: status,
    );

/// The first call the painter under [slot] made to drawRect: the rail.
Rect? _railRect(WidgetTester tester, Finder slot) {
  final render = tester.renderObject(slot);
  Rect? found;
  expect(
    render,
    paints..something((method, arguments) {
      if (method == #drawRect && found == null) {
        found = arguments.first as Rect;
      }
      return found != null;
    }),
  );
  return found;
}

Finder _slotOf(Key stepKey) => find
    .ancestor(of: find.byKey(stepKey), matching: find.byType(CustomPaint))
    .first;

void main() {
  testWidgets('a step is one 32 dp line and has no tool-name title', (
    tester,
  ) async {
    await _pump(tester, _timeline([_shell(0), _shell(1)]));
    expect(find.text('Shell'), findsNothing);
    expect(
      find.text('find /root/projects -iname "*review*"'),
      findsNWidgets(2),
    );
    expect(tester.getSize(find.byKey(_ids[0])).height, 32);
    expect(tester.getSize(find.byKey(_ids[1])).height, 32);
  });

  testWidgets('other tools read as one sentence on the same line', (
    tester,
  ) async {
    await _pump(
      tester,
      _timeline([
        const KitToolRow(
          rowKey: ValueKey('read'),
          kind: KitToolKind.read,
          title: 'Read',
          path: 'lib/x.dart',
          status: KitToolStatus.done,
        ),
        const KitToolRow(
          rowKey: ValueKey('edit'),
          kind: KitToolKind.edit,
          title: 'Edit',
          path: 'c_test.dart',
          added: 3,
          removed: 1,
          status: KitToolStatus.done,
        ),
      ]),
    );
    expect(tester.getSize(find.byKey(const ValueKey('read'))).height, 32);
    expect(tester.getSize(find.byKey(const ValueKey('edit'))).height, 32);
    expect(
      tester.getCenter(find.text('Read')).dy,
      tester.getCenter(find.text('lib/x.dart')).dy,
    );
    expect(
      tester.getCenter(find.text('Edit')).dy,
      tester.getCenter(find.text('c_test.dart')).dy,
    );
    expect(find.textContaining('+3'), findsOneWidget);
  });

  testWidgets('the header glyph and every node share one centre x, and the '
      'header text starts where the step text starts', (tester) async {
    await _pump(
      tester,
      _timeline([
        _shell(0),
        _shell(1, status: KitToolStatus.running),
        const KitToolRow(
          rowKey: ValueKey('step-c'),
          kind: KitToolKind.edit,
          title: 'Edit',
          path: 'b.dart',
          status: KitToolStatus.done,
        ),
      ]),
    );
    final header = tester.getCenter(find.byIcon(AppIconography.fileText)).dx;
    final tile = tester.getCenter(find.byIcon(AppIconography.terminal)).dx;
    final edit = tester.getCenter(find.byIcon(AppIconography.editNote)).dx;
    final spinner = tester.getCenter(find.byType(KitStatusMark)).dx;
    expect(tile, closeTo(header, .01));
    expect(edit, closeTo(header, .01));
    expect(spinner, closeTo(header, .01));
    expect(
      tester.getTopLeft(find.text('Ran 2 commands')).dx,
      closeTo(tester.getTopLeft(find.text('Edit')).dx, .01),
    );
  });

  testWidgets('a running step shows a spinner in its node, no glyph tile', (
    tester,
  ) async {
    await _pump(tester, _timeline([_shell(0, status: KitToolStatus.running)]));
    expect(find.byType(KitStatusMark), findsOneWidget);
    expect(find.byIcon(AppIconography.terminal), findsNothing);
  });

  testWidgets('the rail ends at the last node, whatever is under it', (
    tester,
  ) async {
    await _pump(
      tester,
      _timeline([
        _shell(0),
        _shell(1),
        KitToolRow(
          rowKey: _ids[2],
          kind: KitToolKind.edit,
          title: 'Edit',
          path: 'b.dart',
          status: KitToolStatus.done,
          expanded: true,
          body: const [KitText('A long block of output under the last step')],
        ),
      ]),
    );
    // A step that is not the last runs the whole slot, so the strokes join.
    final first = _railRect(tester, _slotOf(_ids[0]))!;
    expect(first.bottom, closeTo(tester.getSize(_slotOf(_ids[0])).height, .01));
    // The last stops at its node's centre: half of the 32 dp line, though its
    // slot is much taller (the opened block).
    final last = _railRect(tester, _slotOf(_ids[2]))!;
    expect(last.bottom, closeTo(16, .01));
    expect(tester.getSize(_slotOf(_ids[2])).height, greaterThan(40));
  });

  testWidgets('only the group line has a chevron', (tester) async {
    await _pump(
      tester,
      _timeline([
        KitToolRow(
          rowKey: _ids[0],
          kind: KitToolKind.edit,
          title: 'Edit',
          path: 'a.dart',
          status: KitToolStatus.done,
          body: const [KitText('output')],
        ),
        KitToolRow(
          rowKey: _ids[1],
          kind: KitToolKind.edit,
          title: 'Edit',
          path: 'b.dart',
          status: KitToolStatus.done,
          expanded: true,
          body: const [KitText('output')],
        ),
      ]),
    );
    expect(find.byType(KitSpin), findsOneWidget);
  });

  testWidgets('tapping a step opens it', (tester) async {
    var open = false;
    await _pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => _timeline([
          KitToolRow(
            rowKey: _ids[0],
            kind: KitToolKind.edit,
            title: 'Edit',
            path: 'a.dart',
            status: KitToolStatus.done,
            expanded: open,
            onExpansionChanged: (value) => setState(() => open = value),
            body: const [KitText('the step opened')],
          ),
        ]),
      ),
    );
    expect(find.text('the step opened'), findsNothing);
    await tester.tap(find.byKey(_ids[0]));
    await tester.pump();
    await tester.pump(KitMotion.quick);
    expect(find.text('the step opened'), findsOneWidget);
  });

  testWidgets('the full diff page header is the page ground with a hairline, '
      'not a card', (tester) async {
    final file = KitDiffFile.fromTexts(
      'lib/a.dart',
      before: 'one\ntwo\nthree',
      after: 'one\n2\nthree',
    );
    await _pump(tester, KitDiffView(files: [file]));
    await tester.pumpAndSettle();
    final roles = AppTheme.rolesOf(
      Theme.of(tester.element(find.byType(KitDiffView))),
    );
    final header = tester.widget<Container>(
      find.byKey(const ValueKey('kit-diff-file-header-lib/a.dart')),
    );
    final decoration = header.decoration! as BoxDecoration;
    expect(decoration.color, roles.ground);
    expect(decoration.color, isNot(roles.surface1));
    expect(decoration.border, isNotNull);
  });
}
