import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/feedback/bug_report.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/app_diagnostics_screen.dart';
import 'package:opencode_mobile/ui/widgets/product_states.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => debugPlatformCapabilities = null);

  test('labels every platform the seam can report', () {
    const cases = <TargetPlatform, String>{
      TargetPlatform.android: 'Android',
      TargetPlatform.linux: 'Linux desktop (alpha)',
      TargetPlatform.windows:
          'Windows desktop (experimental — contributor-tested)',
      TargetPlatform.macOS: 'macOS (untested)',
    };
    cases.forEach((platform, expected) {
      debugPlatformCapabilities = PlatformCapabilities(platform: platform);
      expect(bugReportPlatformLabel(), expected, reason: 'platform $platform');
    });
  });

  group('the failure surface carries the report affordance', () {
    testWidgets('ProductErrorState offers Report a problem next to Try '
        'again, and it opens Report a problem with the failure attached', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          ProductErrorState(
            title: "Couldn't load files",
            message: 'It broke.',
            onRetry: () async {},
          ),
        ),
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('product-error-report-bug')),
        findsOneWidget,
      );
      expect(find.text('Report a problem'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('product-error-report-bug')));
      await tester.pumpAndSettle();
      expect(find.byType(AppDiagnosticsScreen), findsOneWidget);
      expect(find.text("Attached: Couldn't load files"), findsOneWidget);
    });
  });
}
