import 'dart:async';
import 'dart:io' show Platform, Process;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../platform/app_exit.dart';

/// Whether this device may run the liquid glass shader, and a guard for
/// the devices where it takes the renderer down (emulator QA of build 2062,
/// F1: the Android emulator's software renderer died, QEMU SIGSEGV, with
/// liquid glass on screen).
///
/// Two checks, before the shader is loaded; either keeps the glass frosted
/// (the look phones had before liquid glass):
///
/// - **A software or emulated renderer** (the Android emulator: QEMU,
///   ranchu or goldfish hardware, the emulation or SwiftShader EGL): no
///   liquid glass there at all.
/// - **The last sessions crashed with liquid glass on screen.** While liquid
///   glass is shown in the foreground a flag is set, and it is cleared when
///   the app goes to the background. A launch that finds it still set asks
///   Android how the last process ended (`AppExitKind`) and counts a strike
///   only for a real crash (or an "isn't responding"): a force-stop (a swipe
///   from Recents on some phones), a low-memory kill or an update never
///   count. Two strikes in a row turn liquid glass off for [offFor], and
///   Appearance says so and offers to turn it back on ([turnBackOn]). A long
///   healthy session clears the strikes.
///
/// Real phones that run the shader well never see either: their look is
/// unchanged.
abstract final class KitGlassSafety {
  static const activeKey = 'oc.glassLiquidActive';
  static const strikesKey = 'oc.glassLiquidStrikes';
  static const offUntilKey = 'oc.glassLiquidOffUntil';

  /// How long liquid glass stays off after two strikes.
  static const offFor = Duration(days: 7);

  /// Liquid glass shown this long in one go (until the app goes to the
  /// background) clears the strikes.
  static const healthyAfter = Duration(seconds: 60);

  /// The device's system properties (Android's `getprop`); tests replace it.
  static Future<Map<String, String>> Function() readProperties = _getprop;

  /// The store; tests replace it.
  static Future<SharedPreferences> Function() store =
      SharedPreferences.getInstance;

  /// How the previous process ended, or null when Android did not say; tests
  /// replace it. (The launch report is read once per process natively, so
  /// the exit notice still gets it.)
  static Future<AppExitKind?> Function() readExit = _readExit;

  /// True while liquid glass is off because of crashes; Appearance says so.
  static final ValueNotifier<bool> turnedOffAfterCrashes = ValueNotifier(false);

  /// The clock; tests replace it.
  static DateTime Function() now = DateTime.now;

  /// Whether the device's properties name an emulated or software renderer.
  @visibleForTesting
  static bool softwareRenderer(Map<String, String> properties) {
    String prop(String key) => (properties[key] ?? '').trim().toLowerCase();
    if (prop('ro.kernel.qemu') == '1' || prop('ro.boot.qemu') == '1') {
      return true;
    }
    if (const {'ranchu', 'goldfish'}.contains(prop('ro.hardware'))) {
      return true;
    }
    for (final key in const ['ro.hardware.egl', 'ro.boot.hardware.egl']) {
      final egl = prop(key);
      if (egl == 'emulation' || egl.contains('swiftshader')) return true;
    }
    return false;
  }

  /// Whether liquid glass may be loaded on this device, now. Also counts a
  /// strike when the last session died with liquid glass on screen. Any
  /// failure to read the device or the store allows it (the check is a
  /// guard, never a reason to lose the look on a good phone).
  static Future<bool> allowed() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        if (softwareRenderer(await readProperties())) return false;
      } catch (_) {
        // Unknown: fall through to the strikes.
      }
    }
    try {
      final prefs = await store();
      final off = prefs.getInt(offUntilKey);
      if (off != null) {
        if (now().millisecondsSinceEpoch < off) {
          turnedOffAfterCrashes.value = true;
          return false;
        }
        await prefs.remove(offUntilKey);
      }
      if (prefs.getBool(activeKey) ?? false) {
        await prefs.setBool(activeKey, false);
        AppExitKind? kind;
        try {
          kind = await readExit();
        } catch (_) {}
        // Only a real crash is a strike; the person's own stop, Android's
        // memory kill and an update are not the glass's doing.
        final strikes =
            (prefs.getInt(strikesKey) ?? 0) +
            (kind == AppExitKind.crash ? 1 : 0);
        if (strikes >= 2) {
          turnedOffAfterCrashes.value = true;
          await prefs.setInt(strikesKey, 0);
          await prefs.setInt(
            offUntilKey,
            now().add(offFor).millisecondsSinceEpoch,
          );
          return false;
        }
        await prefs.setInt(strikesKey, strikes);
      }
    } catch (_) {
      // No store (a test without one): nothing to guard.
    }
    return true;
  }

  /// The person turned liquid glass back on: forget the strikes and the
  /// pause. Loading it is [KitGlassShader.turnLiquidBackOn]'s job.
  static Future<void> turnBackOn() async {
    turnedOffAfterCrashes.value = false;
    try {
      final prefs = await store();
      await prefs.remove(offUntilKey);
      await prefs.remove(strikesKey);
      await prefs.setBool(activeKey, false);
    } catch (_) {}
  }

  static AppLifecycleListener? _listener;
  static DateTime? _shownSince;

  /// Liquid glass is on screen from the next frame: set the flag, clear it
  /// in the background (then clearing the strikes too after a long healthy
  /// run), set it again in the foreground. Once per app run.
  static void watch() {
    if (_listener != null) return;
    _listener = AppLifecycleListener(
      onShow: () => _mark(true),
      onHide: () => _mark(false),
      onDetach: () => _mark(false),
    );
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _mark(true))
      ..ensureVisualUpdate();
  }

  static void _mark(bool active) {
    final since = _shownSince;
    _shownSince = active ? now() : null;
    unawaited(
      _write(
        active,
        healthy:
            !active && since != null && now().difference(since) >= healthyAfter,
      ),
    );
  }

  static Future<void> _write(bool active, {required bool healthy}) async {
    try {
      final prefs = await store();
      await prefs.setBool(activeKey, active);
      if (healthy) await prefs.remove(strikesKey);
    } catch (_) {}
  }

  /// Tests and captures only: forget the watch and restore the defaults.
  static void debugReset() {
    _listener?.dispose();
    _listener = null;
    _shownSince = null;
    readProperties = _getprop;
    store = SharedPreferences.getInstance;
    now = DateTime.now;
    readExit = _readExit;
    turnedOffAfterCrashes.value = false;
  }

  static Future<AppExitKind?> _readExit() async =>
      (await AppLifecycleBridge().launchReport()).exit?.kind;

  static Future<Map<String, String>> _getprop() async {
    final result = await Process.run(
      '/system/bin/getprop',
      const [],
    ).timeout(const Duration(seconds: 2));
    final properties = <String, String>{};
    final line = RegExp(r'^\[([^\]]+)\]: \[([^\]]*)\]$');
    for (final entry in '${result.stdout}'.split('\n')) {
      final match = line.firstMatch(entry.trim());
      if (match != null) properties[match.group(1)!] = match.group(2)!;
    }
    return properties;
  }
}
