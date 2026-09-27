import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _secureChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

Map<String, Object> _profile(int index, {String backend = 'openCode'}) => {
  'id': 'perf-$index',
  'name': 'Server $index',
  'baseUrl': 'https://server-$index.example',
  'backend': backend,
};

/// Advance a scripted storage delay, never time the host's test execution.
Future<int> _scriptedMillis(WidgetTester tester, Future<void> operation) async {
  var done = false;
  unawaited(operation.then((_) => done = true));
  final start = tester.binding.clock.now();
  await tester.pump();
  for (var tick = 0; tick < 20 && !done; tick++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(done, isTrue, reason: 'Storage completion must remain bounded.');
  await operation;
  return tester.binding.clock.now().difference(start).inMilliseconds;
}

void main() {
  testWidgets('eight secure reads use bounded overlap and preserve order', (
    tester,
  ) async {
    final metadata = [for (var i = 0; i < 8; i++) _profile(i)];
    SharedPreferences.setMockInitialValues({
      'oc.profiles': jsonEncode(metadata),
    });
    final prefs = await SharedPreferences.getInstance();
    var inFlight = 0;
    var peak = 0;
    var reads = 0;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_secureChannel, (call) async {
      expectSync(call.method, 'read');
      inFlight++;
      reads++;
      if (inFlight > peak) peak = inFlight;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      inFlight--;
      return 'fixture-sign-in-${call.arguments['key']}';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_secureChannel, null));

    // The previous loop's exact secure-read ordering, for the same keys/channel.
    Future<void> serialReference() async {
      const storage = FlutterSecureStorage();
      for (var i = 0; i < 8; i++) {
        await storage.read(key: 'pw.perf-$i');
      }
    }

    final before = await _scriptedMillis(tester, serialReference());
    expect(peak, 1);
    expect(reads, 8);
    peak = 0;
    reads = 0;
    final store = ProfileStore(prefs: prefs);
    List<ServerProfile>? loaded;
    final after = await _scriptedMillis(
      tester,
      store.load().then((value) => loaded = value),
    );
    expect(before, 160);
    expect(after, 40);
    expect(peak, 4);
    expect(inFlight, 0);
    expect(reads, 8);
    expect(loaded!.map((p) => p.id), metadata.map((p) => p['id']));
    for (final profile in loaded!) {
      // Compare booleans so an assertion failure cannot print a sign-in value.
      expect(profile.password == 'fixture-sign-in-pw.${profile.id}', isTrue);
      expect(KitRedact.text(profile.password) == KitRedact.mask, isTrue);
    }
    debugPrint(
      'PROFILE_LOAD_HOST_HARNESS profiles=8 scripted_read_ms=20 '
      'serial_ms=$before bounded_ms=$after max_in_flight=$peak',
    );
  });

  testWidgets('mixed secure failures stay isolated and require reentry', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'oc.profiles': jsonEncode([
        _profile(0),
        _profile(1, backend: 'codex'),
        _profile(2, backend: 'paseo'),
        _profile(3),
        _profile(4, backend: 'codex'),
        _profile(5, backend: 'paseo'),
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_secureChannel, (call) async {
      final key = call.arguments['key'] as String;
      await Future<void>.delayed(
        Duration(milliseconds: key.endsWith('0') ? 20 : 10),
      );
      if (key.endsWith('0') || key.endsWith('4') || key.endsWith('5')) {
        throw PlatformException(code: 'unavailable');
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_secureChannel, null));
    List<ServerProfile>? loaded;
    await _scriptedMillis(
      tester,
      ProfileStore(prefs: prefs).load().then((value) => loaded = value),
    );
    expect(loaded!.map((p) => p.id), [for (var i = 0; i < 6; i++) 'perf-$i']);
    expect(loaded!.map((p) => p.requiresPasswordReentry), [
      true,
      false,
      false,
      false,
      false,
      false,
    ]);
    expect(loaded!.map((p) => p.requiresCodexTokenReentry), [
      false,
      true,
      false,
      false,
      true,
      true,
    ]);
    expect(
      loaded!.every((p) => p.password.isEmpty && p.codexToken.isEmpty),
      isTrue,
    );
  });
}
