// Golden renders of screen-review-1's pages (wave 2b), rebuilt from kit
// parts: Review changes (review-workspace) with its one KitDiffView, the
// selection bar, the comment sheet (review-comment-sheet), and the error,
// empty and slow states. Phone 412x915 and one wide window (1280x800),
// dark and light (owner decision 2026-09-27: no Arabic), with the app's
// real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/screen_review_1_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/product_repository.dart'
    show ProductException;
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/review_handoff.dart';
import 'package:opencode_mobile/ui/kit/kit_undo.dart';
import 'package:opencode_mobile/ui/screens/review_workspace.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

String _name(String shot, Size size, bool light) => [
  'review_workspace_$shot',
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

final _diffs = [
  FileDiff(
    file: 'lib/checkout/checkout_page.dart',
    status: 'modified',
    additions: 4,
    deletions: 2,
    patch:
        '@@ -12,9 +12,11 @@ class CheckoutPage extends StatelessWidget {\n'
        '   const CheckoutPage({super.key});\n'
        ' \n'
        '   @override\n'
        '   Widget build(BuildContext context) {\n'
        '-    final total = cart.total;\n'
        '-    return Text(total.toString());\n'
        '+    final total = cart.totalWithTax;\n'
        '+    final label = formatPrice(total, currency: cart.currency);\n'
        '+    return Text(label);\n'
        '   }\n'
        '+  // Keeps the button above the keyboard on small phones.\n'
        ' }\n'
        ' \n'
        ' String formatPrice(num value, {String currency = "USD"}) =>\n',
  ),
  FileDiff(
    file: 'lib/cart/cart_bloc.dart',
    status: 'modified',
    additions: 1,
    deletions: 1,
    patch:
        '@@ -40,3 +40,3 @@ class CartBloc {\n'
        '   void clear() => _items.clear();\n'
        '-  num get total => _items.fold(0, (a, b) => a + b.price);\n'
        '+  num get totalWithTax => _items.fold(0, (a, b) => a + b.gross);\n'
        '   int get count => _items.length;\n',
  ),
  FileDiff(
    file: 'test/checkout_test.dart',
    status: 'added',
    additions: 3,
    deletions: 0,
    patch:
        '@@ -0,0 +1,3 @@\n'
        "+import 'package:flutter_test/flutter_test.dart';\n"
        '+\n'
        "+void main() => test('adds tax', () {});\n",
  ),
];

Future<void> _shot(
  WidgetTester tester,
  String shot, {
  required bool light,
  Future<List<FileDiff>> Function()? load,
  Future<List<FileDiff>> Function()? loadWorkingTree,
  Size size = _phone,
  ReviewHandoffSession? handoff,
  Future<void> Function()? then,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  SharedPreferences.setMockInitialValues({});
  ReviewWorkspace.clearCache();
  final boundary = GlobalKey();
  try {
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: captureTheme(light: light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: ReviewWorkspace(
            loadDiffs: load ?? () async => _diffs,
            loadWorkingTreeDiffs: loadWorkingTree ?? () async => _diffs,
            handoff: handoff,
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    if (then != null) await then();
    if (settle) await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/${_name(shot, size, light)}.png'),
    );
  } finally {
    KitUndo.commitPending();
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    testWidgets('loaded · $mode', (tester) async {
      await _shot(tester, 'loaded', light: light);
    });
    testWidgets('loaded wide · $mode', (tester) async {
      await _shot(tester, 'loaded', light: light, size: _wide);
    });
    testWidgets('selecting · $mode', (tester) async {
      final store = ReviewHandoffStore();
      await _shot(
        tester,
        'selecting',
        light: light,
        handoff: ReviewHandoffSession(store: store, sessionID: 'chat'),
        then: () async {
          await tester.tap(
            find.byKey(const ValueKey('review-line-0-current-16')),
          );
        },
      );
    });
    testWidgets('comment sheet · $mode', (tester) async {
      final store = ReviewHandoffStore();
      await _shot(
        tester,
        'comment_sheet',
        light: light,
        handoff: ReviewHandoffSession(store: store, sessionID: 'chat'),
        then: () async {
          await tester.tap(
            find.byKey(const ValueKey('review-line-0-current-16')),
          );
          await tester.pump();
          await tester.tap(find.text('Comment'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('review-comment-field')),
            'Round the total before formatting it.',
          );
        },
      );
    });
    testWidgets('every file seen · $mode', (tester) async {
      final store = ReviewHandoffStore();
      final handoff = ReviewHandoffSession(store: store, sessionID: 'chat');
      await _shot(
        tester,
        'all_viewed',
        light: light,
        handoff: handoff,
        load: () async => [_diffs.last],
        then: () async {
          handoff.stage(
            ReviewReference(
              id: handoff.nextID('review-file'),
              kind: ReviewReferenceKind.changedFile,
              path: _diffs.last.file,
              scope: ReviewReferenceScope.session,
            ),
          );
        },
      );
    });
    testWidgets('error · $mode', (tester) async {
      await _shot(
        tester,
        'error',
        light: light,
        load: () async =>
            throw const ProductException('OpenCode is reconnecting.'),
      );
    });
    testWidgets('empty · $mode', (tester) async {
      // Nothing changed anywhere: with changes in another view the page
      // would open that one instead (P6.6a).
      await _shot(
        tester,
        'empty',
        light: light,
        load: () async => const [],
        loadWorkingTree: () async => const [],
      );
    });
    testWidgets('slow · $mode', (tester) async {
      final never = Completer<List<FileDiff>>();
      await _shot(
        tester,
        'slow',
        light: light,
        load: () => never.future,
        settle: false,
        then: () => tester.pump(const Duration(seconds: 9)),
      );
    });
  }
}
