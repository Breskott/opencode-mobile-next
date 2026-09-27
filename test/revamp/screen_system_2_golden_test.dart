// screen-system-2 galleries: the update and feedback notices on the kit, at
// 412x915 and 1280x800, dark and light, with the app's real fonts.
//
// system_shorebird-update-notice_ready: the code-push update is ready; the app's one status
// line under the top bar of a Work-like page, clear of its pinned primary.
// system_desktop-release-notice_shown: a newer desktop release; the same line with
// "Open release page".
// (system_bug-report_link-copied is gone: slice-P8.2 sends every report
// through Report a problem and openExternalLink, whose own alert covers a
// browser that did not open.)
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/screen_system_2_golden_test.dart
// and look at every changed image before committing it.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_iconography.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_row.dart';
import 'package:opencode_mobile/ui/kit/kit_screen.dart';
import 'package:opencode_mobile/ui/kit/kit_top_bar.dart';
import 'package:opencode_mobile/update/desktop_release_check.dart';
import 'package:opencode_mobile/update/shorebird_update_notice.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

class _ReadyService implements AppUpdateService {
  const _ReadyService();

  @override
  bool get isAvailable => true;

  @override
  Future<AppUpdateState> checkForUpdate() async =>
      AppUpdateState.restartRequired;

  @override
  Future<void> downloadUpdate() async {}
}

class _Checker extends DesktopReleaseChecker {
  @override
  Future<DesktopReleaseInfo?> fetchLatest() async => const DesktopReleaseInfo(
    tag: 'v1.0.45+46',
    htmlUrl:
        'https://github.com/Eslamasabry/opencode-mobile-next/releases/tag/v1.0.45+46',
  );
}

/// A Work-like page on the kit's screen frame: its status slot draws the
/// app-wide line, and its pinned primary shows the line never covers it.
Widget _page() => KitScreen(
  topBar: const KitTopBar(title: 'Work'),
  body: ListView(
    children: [
      for (final (title, detail) in const [
        ('Fix the login redirect', 'Laptop · 4 min ago'),
        ('Tidy the settings page', 'Laptop · 1 h ago'),
        ('Release notes for 1.0.45', 'This phone · yesterday'),
      ])
        KitRow(
          leading: const Icon(AppIconography.chat),
          title: title,
          supporting: TextSpan(text: detail),
          onTap: () {},
        ),
    ],
  ),
  bottom: KitActionBlock(
    primary: KitAction(label: 'New conversation', onPressed: () {}),
  ),
);

Future<void> _golden(
  WidgetTester tester,
  String name, {
  required bool light,
  required Size size,
  Widget Function(Widget child)? above,
  Future<void> Function(BuildContext context)? act,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  final boundary = GlobalKey();
  final pageKey = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: captureTheme(light: light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          final page = child ?? const SizedBox.shrink();
          return above == null ? page : above(page);
        },
        home: KeyedSubtree(key: pageKey, child: _page()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (act != null) {
    await act(pageKey.currentContext!);
    await tester.pumpAndSettle();
  }
  expect(tester.takeException(), isNull);
  final suffix = size == _phone ? '' : '_1280x800';
  await expectLater(
    find.byKey(boundary),
    matchesGoldenFile('goldens/$name${suffix}_${light ? 'light' : 'dark'}.png'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in [_phone, _wide]) {
      final at = size == _phone ? 'phone' : 'wide';

      testWidgets('update ready · $mode · $at', (tester) async {
        await _golden(
          tester,
          'system_shorebird-update-notice_ready',
          light: light,
          size: size,
          above: (child) => ShorebirdUpdateNotice(
            service: const _ReadyService(),
            currentProfileId: () => 'golden-server',
            allowsAutomaticUpdate: (_) => true,
            child: child,
          ),
        );
      });

      testWidgets('desktop release · $mode · $at', (tester) async {
        await _golden(
          tester,
          'system_desktop-release-notice_shown',
          light: light,
          size: size,
          above: (child) => DesktopReleaseNotice(
            checker: _Checker(),
            enabledOverride: true,
            currentBuildNumberLoader: () async => 44,
            launcher: (_) async {},
            child: child,
          ),
        );
      });
    }
  }
}
