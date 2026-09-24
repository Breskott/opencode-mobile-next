// TEAM-106 layout: Settings › Plugins (discovery card + row), the AI Team
// sheet, the manual-add form with a verdict, the host guide sheet and the
// server editor's AI Team section at 320dp × 2.5x, LTR and RTL, with no
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
import 'package:opencode_mobile/ui/screens/settings/plugins_screen.dart';
import 'package:opencode_mobile/ui/widgets/team_host_form.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/first_run_path.dart';

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

  /// At 2.5x most targets start below the fold: scroll them in, then tap.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    expect(finder.hitTestable(), findsOneWidget);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  for (final rtl in [false, true]) {
    for (final page in ['discovery', 'sheet', 'form', 'guide', 'editor']) {
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
        final on = page == 'sheet';
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
                      : PluginsSettingsScreen(
                          controller: controller,
                          probe: _foundProbe,
                        ),
                ),
              ),
            ),
          );
          await settle(tester);
          expect(tester.takeException(), isNull);
          switch (page) {
            case 'discovery':
              expect(
                find.byKey(const ValueKey('team-discovery-card')),
                findsOneWidget,
              );
              final row = find.byKey(const ValueKey('plugins-ai-team-row'));
              await tester.ensureVisible(row);
              await tester.pumpAndSettle();
              expect(row.hitTestable(), findsOneWidget);
            case 'sheet':
              expect(controller.orchestration?.phase, OrchestrationPhase.ready);
              await tapVisible(
                tester,
                find.byKey(const ValueKey('plugins-ai-team-row')),
              );
              expect(
                find.byKey(const ValueKey('team-plugin-sheet')),
                findsOneWidget,
              );
              await tapVisible(
                tester,
                find.byKey(const ValueKey('team-sheet-technical')),
              );
              final off = find.byKey(const ValueKey('team-sheet-turn-off'));
              await tester.ensureVisible(off);
              await tester.pumpAndSettle();
              expect(off.hitTestable(), findsOneWidget);
              // Ids and addresses stay LTR in RTL.
              for (final text in tester.widgetList<SelectableText>(
                find.byType(SelectableText),
              )) {
                expect(text.textDirection, TextDirection.ltr);
              }
            case 'form':
              await tapVisible(
                tester,
                find.byKey(const ValueKey('plugins-ai-team-row')),
              );
              await tapVisible(
                tester,
                find.byKey(const ValueKey('team-sheet-add-manually')),
              );
              final url = find.byKey(const ValueKey('team-host-url'));
              expect(
                tester.widget<TextField>(url).textDirection,
                TextDirection.ltr,
              );
              // TEAM-206: the kind chips wrap at large text and every one
              // is reachable; a tap on WSL selects it.
              for (final kind in teamHostKindChoices) {
                final chip = find.byKey(
                  ValueKey('team-host-kind-${kind.name}'),
                );
                await tester.ensureVisible(chip);
                await tester.pumpAndSettle();
                expect(chip.hitTestable(), findsOneWidget);
                expect(
                  find.text(teamHostKindLabel(l10n, kind)),
                  findsOneWidget,
                );
              }
              await tapVisible(
                tester,
                find.byKey(const ValueKey('team-host-kind-wsl')),
              );
              expect(
                tester
                    .widget<ChoiceChip>(
                      find.byKey(const ValueKey('team-host-kind-wsl')),
                    )
                    .selected,
                isTrue,
              );
              await tester.enterText(url, 'http://public.example:8372');
              await tapVisible(
                tester,
                find.byKey(const ValueKey('team-host-submit')),
              );
              final verdict = find.byKey(const ValueKey('team-host-verdict'));
              await tester.ensureVisible(verdict);
              await tester.pumpAndSettle();
              expect(find.text(l10n.teamUiTailnetRequired), findsOneWidget);
            case 'guide':
              unawaited(
                showTeamHostGuideSheet(
                  tester.element(
                    find.byKey(const ValueKey('plugins-ai-team-row')),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(
                find.byKey(const ValueKey('team-host-guide')),
                findsOneWidget,
              );
              expect(find.text(l10n.teamUiHostGuideStep4), findsOneWidget);
            case 'editor':
              await openFirstRunConnect(tester);
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
