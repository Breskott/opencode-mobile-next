// slice-P3.4 goldens: the one AI Team page (docs/qa/slice-P3.4-2026-09-27)
// at 412x915 and 1280x800 with the app's real fonts and the recorded team
// fixture: the team on this phone, the same team paused and stopped by the
// heat guard (never the person's "Paused"), the page's menu with the
// switches the AI Team sheet used to hold, and the page while the team is
// off, saying why nothing was found.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/slice_p34_golden_test.dart
// and look at every changed image before committing it.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/thermal_guard.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/thermal.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;
import '../support/team_golden_fixture.dart';

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

enum _Shot {
  on('team_page_on_phone', _phone),
  onWide('team_page_on_phone', _wide),
  heat('team_page_heat_paused', _phone),
  heatWide('team_page_heat_paused', _wide),
  heatStopped('team_page_heat_stopped', _phone),
  menu('team_page_menu', _phone),
  off('team_page_off', _phone),
  offWide('team_page_off', _wide);

  const _Shot(this.state, this.size);
  final String state;
  final Size size;

  String get name {
    final sized = size == _phone
        ? ''
        : '_${size.width.toInt()}x${size.height.toInt()}';
    return 'slice_p34_$state${sized}_light';
  }
}

/// A heat guard that holds what the shot says; nothing reaches Android.
class _Guard extends ThermalGuard {
  _Guard(SharedPreferences prefs, this.held)
    : super(bridge: ThermalBridge(), port: _NoTeams(), prefs: prefs);

  final Map<String, ThermalTeamHold> held;

  @override
  Map<String, ThermalTeamHold> get holds => held;
}

class _NoTeams implements ThermalTeamPort {
  @override
  Future<List<ThermalTeam>> runningHere() async => const [];
  @override
  Future<ThermalTeamHold?> pause(ThermalTeam team, {required DateTime now}) =>
      throw UnimplementedError();
  @override
  Future<ThermalTeamHold> stop(ThermalTeamHold hold) =>
      throw UnimplementedError();
  @override
  Future<bool> resume(ThermalTeamHold hold) => throw UnimplementedError();
}

void _mockChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in [
    'plugins.it_nomads.com/flutter_secure_storage',
    'oc/background',
    'oc/shortcut',
  ]) {
    messenger.setMockMethodCallHandler(
      MethodChannel(channel),
      (call) async => call.method == 'readAll' ? <String, String>{} : null,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(MethodChannel(channel), null),
    );
  }
}

/// The page while the team is off, on a computer where nothing answered.
Future<Widget> _offPage() async {
  _mockChannels();
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = ProfileStore(prefs: prefs);
  final profile = ServerProfile(
    id: 'workstation',
    name: 'Workstation',
    baseUrl: 'http://100.100.1.2:4096',
  );
  await store.upsert(profile);
  await store.setActiveId(profile.id);
  final connection = ConnectionController(store);
  addTearDown(connection.dispose);
  connection.adoptConnectedProfileForTesting(profile);
  connection.syncOrchestration();
  return TeamPage(
    connection: connection,
    probe: (url, {city}) async => const ProbeUnreachable(error: 'no answer'),
  );
}

Future<Widget> _onPage(_Shot shot, OrchestrationController team) async {
  final prefs = await SharedPreferences.getInstance();
  final host = team.host!;
  final hold = ThermalTeamHold(
    team: ThermalTeam(
      id: team.profileId,
      url: host.url,
      city: host.city ?? '',
      builtin: true,
    ),
    since: teamSceneClock.subtract(const Duration(minutes: 4)),
    serviceStopped: shot == _Shot.heatStopped,
    status: ThermalStatus.severe,
  );
  final heat = switch (shot) {
    _Shot.heat || _Shot.heatWide || _Shot.heatStopped => {team.profileId: hold},
    _ => const <String, ThermalTeamHold>{},
  };
  final guard = _Guard(prefs, heat);
  addTearDown(guard.dispose);
  // The server this team belongs to, so the menu offers its switches.
  _mockChannels();
  final store = ProfileStore(prefs: prefs);
  final profile = ServerProfile(
    id: team.profileId,
    name: 'This phone',
    baseUrl: 'http://127.0.0.1:4097',
    orchestration: team.config,
  );
  await store.upsert(profile);
  await store.setActiveId(profile.id);
  final connection = ConnectionController(store);
  addTearDown(connection.dispose);
  connection.adoptConnectedProfileForTesting(profile);
  return TeamHomeScreen(
    controller: team,
    connection: connection,
    now: () => teamSceneClock,
    thermalGuard: ValueNotifier<ThermalGuard?>(guard),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final shot in _Shot.values) {
    testWidgets(shot.name, (tester) async {
      tester.view.physicalSize = shot.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      resetTeamMoments();
      final Widget home;
      if (shot == _Shot.off || shot == _Shot.offWide) {
        home = await _offPage();
      } else {
        final team = await teamSceneController(TeamScene.loaded, onPhone: true);
        addTearDown(team.dispose);
        home = await _onPage(shot, team);
      }
      final boundary = GlobalKey();
      debugDefaultTargetPlatformOverride = TargetPlatform.android; // ARCH-11
      try {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: captureTheme(light: true),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: RepaintBoundary(key: boundary, child: child),
            ),
            home: home,
          ),
        );
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        if (shot == _Shot.menu) {
          await tester.tap(find.byKey(const ValueKey('team-home-more')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
        }
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(boundary),
          matchesGoldenFile('goldens/${shot.name}.png'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
