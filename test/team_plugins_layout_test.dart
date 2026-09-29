// TEAM-106 layout: the AI Team page (on and off), the manual-add form with a
// verdict, the host guide sheet and the server editor's AI Team section at 320dp × 2.5x, LTR and RTL, with no
// overflow. Set TEAM_PLUGINS_CAPTURE=true to write PNGs under
// docs/qa/ai-team/.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/servers_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_page.dart';
import 'package:opencode_mobile/ui/widgets/team_host_form.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/first_run_path.dart';
import 'support/server_editor.dart';

import '../tool/capture/fixtures.dart'
    show loadCaptureFonts, captureTheme, capturePng, writePng;

const _profileId = 'workstation';

Directory _findFixtureRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 5; i++) {
    final candidate = Directory('${dir.path}/tool/qa/gascity_fixture');
    if (candidate.existsSync()) return candidate;
    dir = dir.parent;
  }
  throw StateError('tool/qa/gascity_fixture not found');
}

class _MemorySecureStorage extends FlutterSecureStorage {
  _MemorySecureStorage();
  final values = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => Map.of(values);
}

class _EmptyStore extends ProfileStore {
  _EmptyStore({required super.prefs, required super.secure});
  @override
  List<ServerProfile> get profiles => const [];
}

Future<ProbeVerdict> _foundProbe(String url, {String? city}) async =>
    ProbeFound(
      host: OrchestrationHostIdentity(
        provider: 'gascity',
        url: url,
        hostMode: OrchestrationHostMode.computer,
        version: '1.4.1',
        city: 'bright-lights',
      ),
      version: '1.4.1',
      city: 'bright-lights',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  late String fixturePath;

  setUp(() {
    fixturePath = _findFixtureRoot().path;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in ['oc/background', 'oc/shortcut', 'oc/tailscale']) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (call) async => channel == 'oc/tailscale'
            ? (call.method == 'check' ? 'installed' : true)
            : null,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(MethodChannel(channel), null),
      );
    }
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// A lazily built list only builds what is near the viewport: scroll
  /// until [finder] exists, then bring it fully into view.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder);
  }

  /// At 2.5x most targets start below the fold: scroll them in, then tap.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await reveal(tester, finder);
    await tester.pumpAndSettle();
    expect(finder.hitTestable(), findsOneWidget);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  for (final rtl in [false, true]) {
    for (final page in ['team', 'form', 'guide', 'editor']) {
      testWidgets('plugins $page at 320dp 2.5x ${rtl ? 'RTL' : 'LTR'}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final secure = _MemorySecureStorage();
        final on = page == 'team';
        final profile = ServerProfile(
          id: _profileId,
          name: 'Development PC',
          baseUrl: 'http://100.100.1.2:4096',
          orchestration: on
              ? OrchestrationConfig(
                  provider: OrchestrationProvider.fixture,
                  url: fixturePath,
                  city: 'bright-lights',
                  enabledAt: DateTime.utc(2026, 9, 10),
                )
              : null,
        );
        final ProfileStore store;
        if (page == 'editor') {
          store = _EmptyStore(prefs: prefs, secure: secure);
        } else {
          store = ProfileStore(prefs: prefs, secure: secure);
          await store.upsert(profile);
          await store.setActiveId(profile.id);
        }
        final controller = ConnectionController(store);
        if (page != 'editor') {
          controller.adoptConnectedProfileForTesting(profile);
          controller.syncOrchestration();
        }
        final boundary = GlobalKey();
        final hasArabic = AppLocalizations.supportedLocales.any(
          (locale) => locale.languageCode == 'ar',
        );
        final locale = Locale(rtl && hasArabic ? 'ar' : 'en');
        final l10n = lookupAppLocalizations(locale);
        try {
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: ProviderScope(
                overrides: [
                  bootstrapProvider.overrideWithValue(AppBootstrap(store)),
                  connProvider.overrideWithValue(controller),
                ],
                child: MaterialApp(
                  theme: captureTheme(light: true),
                  debugShowCheckedModeBanner: false,
                  locale: locale,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(2.5)),
                    child: Directionality(
                      textDirection: rtl
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      child: child!,
                    ),
                  ),
                  home: page == 'editor'
                      ? const ServersScreen()
                      : TeamPage(connection: controller, probe: _foundProbe),
                ),
              ),
            ),
          );
          await settle(tester);
          expect(tester.takeException(), isNull);
          switch (page) {
            case 'team':
              // The one AI Team page; its switches are in the top bar's
              // menu, reachable at large text.
              expect(controller.orchestration?.phase, OrchestrationPhase.ready);
              expect(find.byKey(const ValueKey('team-home')), findsOneWidget);
              await tapVisible(
                tester,
                find.byKey(const ValueKey('team-home-settings')),
              );
              final off = find.byKey(const ValueKey('team-home-turn-off'));
              await tester.ensureVisible(off);
              await tester.pumpAndSettle();
              expect(off.hitTestable(), findsOneWidget);
            case 'form':
              // The team page, off (its drawing moves, so frames are
              // pumped rather than settled): Enter its address.
              final address = find.byKey(const ValueKey('team-intro-address'));
              expect(address.hitTestable(), findsOneWidget);
              await tester.tap(address);
              await settle(tester);
              final url = find.byKey(const ValueKey('team-host-url'));
              // The address is a KitField of the url kind: left to right.
              expect(
                tester
                    .widget<TextField>(
                      find.descendant(
                        of: url,
                        matching: find.byType(TextField),
                      ),
                    )
                    .textDirection,
                TextDirection.ltr,
              );
              // shared-team-1 (map team-host-sheet, fix): no "kind of
              // computer" question any more; the team name field is
              // reachable at large text.
              expect(
                find.byKey(
                  ValueKey('team-host-kind-${teamHostKindChoices.first.name}'),
                ),
                findsNothing,
              );
              final team = find.byKey(const ValueKey('team-host-city'));
              await tester.ensureVisible(team);
              await settle(tester);
              expect(team.hitTestable(), findsOneWidget);
              await tester.enterText(url, 'http://public.example:8372');
              // R12: Test and turn on is pinned by the sheet, so it is in
              // reach at 2.5x while the fields scroll.
              final submit = find.descendant(
                of: find.byKey(const ValueKey('kit-sheet-actions')),
                matching: find.byKey(const ValueKey('team-host-submit')),
              );
              expect(submit.hitTestable(), findsOneWidget);
              await tester.tap(submit);
              await settle(tester);
              final verdict = find.byKey(const ValueKey('team-host-verdict'));
              await tester.ensureVisible(verdict);
              await settle(tester);
              expect(find.text(l10n.teamUiTailnetRequired), findsOneWidget);
            case 'guide':
              unawaited(
                showTeamHostGuideSheet(tester.element(find.byType(TeamPage))),
              );
              await tester.pumpAndSettle();
              expect(
                find.byKey(const ValueKey('team-host-guide')),
                findsOneWidget,
              );
              expect(find.text(l10n.teamUiHostGuideStep4), findsOneWidget);
            case 'editor':
              await openFirstRunConnect(tester);
              await openServerMoreOptions(tester);
              final section = find.byKey(
                const ValueKey('server-editor-team-section'),
              );
              await tester.ensureVisible(section);
              await tester.pumpAndSettle();
              expect(section.hitTestable(), findsOneWidget);
              await tapVisible(
                tester,
                find.byKey(const ValueKey('server-editor-team-add')),
              );
              expect(
                find.byKey(const ValueKey('team-host-form')),
                findsOneWidget,
              );
          }
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('TEAM_PLUGINS_CAPTURE')) {
            await writePng(
              'docs/qa/ai-team/${locale.languageCode}-${rtl ? 'rtl' : 'ltr'}-plugins-$page-large.png',
              await capturePng(tester, boundary),
            );
          }
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }
}
