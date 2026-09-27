// Golden renders of P10.4's first-mic voice setup sheet: the offer on
// Wi-Fi (phone and a wide window), the offer on mobile data, the download
// with progress, and a failed download. Dark and light, the app's real
// fonts at DPR 1, driven through the real setup controller.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/voice_auto_setup_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/voice/automatic_setup_platform.dart';
import 'package:opencode_mobile/voice/model_download.dart';
import 'package:opencode_mobile/voice/model_manifest.dart';

import '../../tool/capture/fixtures.dart' show loadCaptureFonts;
import 'screen_voice_1_fixtures.dart';
import 'voice_auto_setup_fixtures.dart';

String _name(String shot, Size size, bool light) => [
  'voice_auto_setup_$shot',
  if (size != voicePhone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

Future<void> _shot(
  WidgetTester tester,
  String shot, {
  required bool light,
  Size size = voicePhone,
  VoiceSetupNetwork network = VoiceSetupNetwork.unmetered,
  Future<void> Function(AutoSetupRig rig)? then,
}) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  final boundary = GlobalKey();
  try {
    final rig = await openAutoSetup(
      tester,
      info: autoSetupInfo(memory: 3000),
      size: size,
      light: light,
      boundary: boundary,
      network: network,
    );
    if (then != null) await then(rig);
    await pumpSheet(tester);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/${_name(shot, size, light)}.png'),
    );
    rig.downloader.gate?.complete();
    await pumpSheet(tester);
    await stopAutoSetupRecording(tester, rig);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  setUp(() {
    debugPlatformCapabilities = const PlatformCapabilities.android();
    addTearDown(() => debugPlatformCapabilities = null);
  });

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final size in const [voicePhone, voiceWide]) {
      testWidgets('offer ${size.width} · $mode', (tester) async {
        await _shot(tester, 'offer', light: light, size: size);
      });
    }

    testWidgets('offer on mobile data · $mode', (tester) async {
      await _shot(
        tester,
        'mobile_data',
        light: light,
        network: VoiceSetupNetwork.metered,
      );
    });

    testWidgets('downloading · $mode', (tester) async {
      await _shot(
        tester,
        'downloading',
        light: light,
        then: (rig) async {
          rig.downloader.gate = Completer<void>();
          await autoSetupTap(
            tester,
            find.byKey(const Key('voice-auto-setup-download')),
          );
          final pack = voiceModelPack('base');
          rig.downloader.progress!(
            VoiceDownloadProgress(
              received: pack.downloadBytes * 2 ~/ 5,
              total: pack.downloadBytes,
              fileName: pack.encoder.name,
            ),
          );
        },
      );
    });

    testWidgets('failed · $mode', (tester) async {
      await _shot(
        tester,
        'failed',
        light: light,
        then: (rig) async {
          rig.downloader.failure = const VoiceDownloadException(
            'GET https://huggingface.co/x/base-encoder.int8.onnx timed out',
            failure: VoiceDownloadFailure.timeout,
          );
          await autoSetupTap(
            tester,
            find.byKey(const Key('voice-auto-setup-download')),
          );
        },
      );
    });
  }
}
