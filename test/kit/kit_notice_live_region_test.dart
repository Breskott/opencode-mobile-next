// KitNotice's one live region (A11Y-3, KitNotice.md test 9), counted on the
// semantics updates the framework sends to the engine, not on the tree the
// test reads back. A binding whose SemanticsUpdateBuilder records every
// `updateNode` call sees exactly what the platform is told: a live-region
// node that is not sent cannot be read again, and a label the platform
// receives changed is what Android's live region announces.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_notice.dart';

/// Every `updateNode` the framework sent: the node id and its label.
final List<(int, String)> _sent = [];

class _SpyBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() => _SpyBuilder();
}

/// Records each node update, then hands it on unchanged to the real builder.
class _SpyBuilder implements ui.SemanticsUpdateBuilder {
  final ui.SemanticsUpdateBuilder _real = ui.SemanticsUpdateBuilder();

  @override
  ui.SemanticsUpdate build() => _real.build();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final named = invocation.namedArguments;
    switch (invocation.memberName) {
      case #updateNode:
        _sent.add((named[#id]! as int, named[#label]! as String));
        return Function.apply(_real.updateNode, const [], named);
      case #updateCustomAction:
        return Function.apply(_real.updateCustomAction, const [], named);
    }
    return super.noSuchMethod(invocation);
  }
}

/// The ids of the live-region nodes in the current tree.
Set<int> _liveIds(WidgetTester tester) {
  final ids = <int>{};
  void visit(SemanticsNode node) {
    if (node.getSemanticsData().flagsCollection.isLiveRegion) ids.add(node.id);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  var root = tester.getSemantics(find.byType(Scaffold));
  while (root.parent != null) {
    root = root.parent!;
  }
  visit(root);
  return ids;
}

/// One step of the notice's life, as the platform saw it.
typedef _Step = ({
  /// `updateNode` calls for a live-region node in this step.
  int sends,

  /// Labels a live-region node was sent that differ from the label that
  /// node was last sent: what the platform announces.
  List<String> announced,
});

void main() {
  _SpyBinding();

  group('live region (A11Y-3, semantics updates)', () {
    late Map<int, String> lastSent;

    setUp(() => lastSent = {});

    Future<_Step> show(WidgetTester tester, Widget notice) async {
      _sent.clear();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: notice),
        ),
      );
      await tester.pumpAndSettle();
      final live = _liveIds(tester);
      expect(live, hasLength(1), reason: 'one live region per notice');
      var sends = 0;
      final announced = <String>[];
      for (final (id, label) in _sent) {
        if (!live.contains(id)) continue;
        sends += 1;
        if (lastSent[id] != label) announced.add(label);
        lastSent[id] = label;
      }
      return (sends: sends, announced: announced);
    }

    testWidgets('a rebuild with the same words sends the live region '
        'nothing; each new message is announced exactly once', (tester) async {
      final semantics = tester.ensureSemantics();
      var step = await show(
        tester,
        const KitNotice(message: 'Checking the server'),
      );
      expect(step.announced, hasLength(1));
      expect(step.announced.single, contains('Checking the server'));

      // The same notice rebuilt: the live region is not sent at all.
      for (var i = 0; i < 2; i += 1) {
        step = await show(
          tester,
          const KitNotice(message: 'Checking the server'),
        );
        expect(step.sends, 0, reason: 'rebuild $i re-sent the live region');
        expect(step.announced, isEmpty);
      }

      // A new verdict: one announcement, with the new words.
      step = await show(
        tester,
        const KitNotice(message: 'The server answered', tone: AppStatusTone.ok),
      );
      expect(step.announced, hasLength(1));
      expect(step.announced.single, contains('The server answered'));
      step = await show(
        tester,
        const KitNotice(message: 'The server answered', tone: AppStatusTone.ok),
      );
      expect(step.sends, 0);

      // The offer and the error: one live region each, announced once.
      step = await show(
        tester,
        KitNotice.offer(
          message: 'Pin it?',
          action: KitAction(label: 'Pin', onPressed: () {}),
          onDismiss: () {},
        ),
      );
      expect(step.announced, hasLength(1));
      expect(step.announced.single, contains('Pin it?'));
      step = await show(
        tester,
        const KitNotice.error(
          message: 'Couldn’t pin',
          error: FormatException('x'),
          details: 'trace',
        ),
      );
      expect(step.announced, hasLength(1));
      expect(step.announced.single, contains('Couldn’t pin'));
      semantics.dispose();
    });

    // Contract problem 8 in docs/qa/revamp-kit-KitNotice-v2-2026-09-26:
    // KitNotice.md says "announced once per change of tone or message", but
    // the tone has no words, and a live region announces its text. This
    // pins what the notice does today so a fix shows up here.
    testWidgets('a change of tone alone, with the same words, is not '
        'announced', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(tester, const KitNotice(message: 'The server answered'));
      final step = await show(
        tester,
        const KitNotice(message: 'The server answered', tone: AppStatusTone.ok),
      );
      expect(step.announced, isEmpty);
      semantics.dispose();
    });
  });
}
