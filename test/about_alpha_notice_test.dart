import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/screens/about_screen.dart'
    show AboutScreen, buildProvenanceBody;

/// The build-provenance notice and the bug-report affordances on About. Runs
/// in its own file because the document `ListView` builds lazily against a
/// process-wide asset cache: reusing a file that already loaded the privacy
/// documents leaves the 320dp fixture showing an empty first viewport.
void main() {
  testWidgets('About shows build provenance and both report paths', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('about-alpha-report-bug')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('about-report-bug')), findsOneWidget);
    expect(find.text('About this build'), findsOneWidget);
    expect(
      find.textContaining('built heavily with AI assistance'),
      findsOneWidget,
    );
    expect(find.textContaining('not been hardware-tested'), findsOneWidget);
  });

  test(
    'the notice retains provenance and desktop limits without a channel claim',
    () {
      // Android publication must not overstate readiness on other platforms.
      expect(buildProvenanceBody, contains('AI assistance'));
      expect(buildProvenanceBody, contains('Android is the primary supported'));
      expect(buildProvenanceBody, isNot(contains('public alpha')));
      expect(buildProvenanceBody, contains('not been hardware-tested'));
      expect(
        find.text('About this build'),
        findsNothing,
        reason: 'the title is a widget concern, asserted in the test above',
      );
    },
  );
}
