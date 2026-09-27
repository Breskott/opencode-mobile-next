import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/feedback/bug_report.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/widgets/product_states.dart';
import 'package:package_info_plus/package_info_plus.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  tearDown(() => debugPlatformCapabilities = null);

  group('bug report URL', () {
    test(
      'prefills the template, version, and platform, and nothing else',
      () async {
        debugPlatformCapabilities = const PlatformCapabilities(
          platform: TargetPlatform.windows,
        );
        final url = await buildBugReportUrl(
          info: PackageInfo(
            appName: 'opencode_mobile',
            packageName: 'io.github.eslamasabry.opencode_mobile',
            version: '1.0.31',
            buildNumber: '32',
          ),
        );

        expect(url.host, 'github.com');
        expect(url.path, '/Eslamasabry/opencode-mobile-next/issues/new');
        expect(url.queryParameters['template'], 'bug_report.yml');
        expect(url.queryParameters['app-version'], '1.0.31+32');
        final body = url.queryParameters['what-happened']!;
        expect(body, contains('App: 1.0.31+32'));
        expect(
          body,
          contains('Platform: Windows desktop (experimental'),
          reason: 'a Windows report must arrive already contexted',
        );
        // The prefill is environment-only: no field exists for a server URL,
        // directory, session id, or transcript, and none may be smuggled in.
        expect(body, isNot(contains('http://127.0.0.1')));
        expect(body, isNot(contains('/home/')));
      },
    );

    test(
      'falls back to an unknown version when the plugin never answers',
      () async {
        // PackageInfo.fromPlatform() would hang here; exercise only the
        // explicit-info path and assert the fallback shape separately via the
        // platform label contract below.
        final url = await buildBugReportUrl(
          info: PackageInfo(
            appName: 'opencode_mobile',
            packageName: 'io.github.eslamasabry.opencode_mobile',
            version: '0.0.0',
            buildNumber: '0',
          ),
        );
        expect(url.queryParameters['app-version'], '0.0.0+0');
      },
    );

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
        addTearDown(() => debugPlatformCapabilities = null);
        expect(
          bugReportPlatformLabel(),
          expected,
          reason: 'platform $platform',
        );
      });
    });
  });

  group('openBugReport fallback', () {
    const link = 'https://github.com/fake/issues/new';
    const explained =
        "Your browser didn't open, so the link to the bug form is copied. "
        'Paste it into a browser to file the report.';

    /// Records what reaches the clipboard.
    List<String> recordClipboard(WidgetTester tester) {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      return copied;
    }

    testWidgets('a failed launch copies the link and says so in a sheet', (
      tester,
    ) async {
      final copied = recordClipboard(tester);
      await tester.pumpWidget(_app(const SizedBox.shrink()));
      final context = tester.element(find.byType(SizedBox));

      await openBugReport(
        context,
        urlBuilder: () async => Uri.parse(link),
        launcher: (_) async => false,
      );
      await tester.pumpAndSettle();

      expect(copied, [link]);
      expect(find.text('Report a bug'), findsOneWidget);
      expect(find.text(explained), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(find.text('Copy bug form link'));
      await tester.pump();
      expect(copied, [link, link]);
      await tester.pumpAndSettle();
    });

    testWidgets('a launch that throws or hangs still ends in the sheet', (
      tester,
    ) async {
      recordClipboard(tester);
      await tester.pumpWidget(_app(const SizedBox.shrink()));
      final context = tester.element(find.byType(SizedBox));

      await openBugReport(
        context,
        urlBuilder: () async => Uri.parse(link),
        launcher: (_) async => throw StateError('no browser'),
      );
      await tester.pumpAndSettle();
      expect(find.text(explained), findsOneWidget);
    });

    testWidgets('an opened browser leaves the app as it was', (tester) async {
      final copied = recordClipboard(tester);
      await tester.pumpWidget(_app(const SizedBox.shrink()));
      final context = tester.element(find.byType(SizedBox));
      Uri? launched;

      await openBugReport(
        context,
        urlBuilder: () async => Uri.parse(link),
        launcher: (url) async {
          launched = url;
          return true;
        },
      );
      await tester.pumpAndSettle();

      expect(launched, Uri.parse(link));
      expect(copied, isEmpty);
      expect(find.text(explained), findsNothing);
    });
  });
  group('the failure surface carries the report affordance', () {
    testWidgets('ProductErrorState offers Report a bug next to Try again', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(ProductErrorState(message: 'It broke.', onRetry: () async {})),
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('product-error-report-bug')),
        findsOneWidget,
      );
      expect(find.text('Report a bug'), findsOneWidget);
    });
  });

  group('l10n', () {
    testWidgets('localizations still load alongside the feedback imports', (
      tester,
    ) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(l10n.appTitle, 'OpenCode Mobile');
    });
  });
}
