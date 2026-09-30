import 'package:flutter_test/flutter_test.dart';
import 'team_kit_test_support.dart';

void main() {
  testWidgets('wraps at 360 dp with 2x text', (tester) async {
    await pumpTeam(tester, teamSample('kit_milestone_row'), scale: 2);
    expect(tester.takeException(), isNull);
    expect(find.text('Milestone 2'), findsOneWidget);
  });
  testWidgets('action is controlled by its caller', (tester) async {
    var calls = 0;
    await pumpTeam(
      tester,
      teamSample('kit_milestone_row', action: () => calls++),
    );
    await tester.tap(find.text('Milestone 2'));
    await tester.pump();
    expect(calls, 1);
  });
}
