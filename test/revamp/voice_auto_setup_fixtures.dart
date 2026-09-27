// Fixtures for P10.4's first-mic voice setup sheet: the real setup
// controller, model manager and composer over a scripted downloader, device
// and platform (no network, no microphone).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/voice/automatic_setup_platform.dart';
import 'package:opencode_mobile/voice/controller.dart';
import 'package:opencode_mobile/voice/device.dart';
import 'package:opencode_mobile/voice/model_download.dart';
import 'package:opencode_mobile/voice/model_manager.dart';
import 'package:opencode_mobile/voice/model_manifest.dart';
import 'package:opencode_mobile/voice/voice_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../voice_controller_test.dart'
    show FakeVoiceRecognizer, FakeVoiceRecorder;
import 'screen_voice_1_fixtures.dart';

class _NoHttp implements VoiceHttpTransport {
  @override
  void close() {}

  @override
  Future<VoiceHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const {},
    VoiceCancellationToken? cancellation,
  }) => throw StateError('The setup sheet tests must not use the network.');
}

class AutoSetupDownloader extends VoiceModelDownloader {
  AutoSetupDownloader()
    : super(store: const LocalVoiceFileStore(), http: _NoHttp());

  final installed = <String>{};
  final downloads = <String>[];
  Completer<void>? gate;
  Object? failure;
  VoiceCancellationToken? cancellation;
  void Function(VoiceDownloadProgress)? progress;

  @override
  Future<bool> verifyInstalled(
    String root,
    VoiceModelPack pack, {
    VoiceCancellationToken? cancellation,
  }) async => installed.contains(pack.id);

  @override
  Future<void> download(
    String root,
    VoiceModelPack pack, {
    required VoiceCancellationToken cancellation,
    required void Function(VoiceDownloadProgress) onProgress,
    required void Function() onVerifying,
    bool replaceExisting = false,
  }) async {
    downloads.add(pack.id);
    this.cancellation = cancellation;
    progress = onProgress;
    await gate?.future;
    if (cancellation.isCancelled) throw const VoiceDownloadCancelled();
    if (failure case final value?) throw value;
    installed.add(pack.id);
  }
}

class AutoSetupDevice implements VoiceDevicePlatform {
  AutoSetupDevice(this.info);

  final VoiceDeviceInfo info;

  @override
  Future<VoiceDeviceInfo> getDeviceInfo() async => info;

  @override
  Future<VoiceMicrophonePermission> requestMicrophonePermission() async =>
      VoiceMicrophonePermission.granted;

  @override
  Future<void> openAppSettings() async {}
}

class AutoSetupPlatform implements VoiceSetupPlatform {
  VoiceSetupNetwork current = VoiceSetupNetwork.unmetered;
  final phases = <VoiceSetupNotificationPhase>[];

  @override
  Future<VoiceSetupNetwork> network() async => current;

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<bool> showNotification({
    required VoiceSetupNotificationPhase phase,
    required int receivedBytes,
    required int totalBytes,
  }) async {
    phases.add(phase);
    return true;
  }

  @override
  Future<void> dismissNotification() async {}
}

VoiceDeviceInfo autoSetupInfo({int? memory = 8192, int memoryClass = 128}) =>
    VoiceDeviceInfo(
      availableStorageBytes: 8 * 1024 * 1024 * 1024,
      memoryClassMb: memoryClass,
      totalMemoryMb: memory,
      supportedAbis: const ['arm64-v8a'],
      hasMicrophone: true,
      captureSupported: true,
    );

class AutoSetupRig {
  AutoSetupRig(this.models, this.downloader, this.platform, this.recorder)
    : composer = VoiceComposerController(
        models: models,
        recorder: recorder,
        recognizer: FakeVoiceRecognizer(),
      );

  final VoiceModelManager models;
  final AutoSetupDownloader downloader;
  final AutoSetupPlatform platform;
  final FakeVoiceRecorder recorder;
  final VoiceComposerController composer;
  bool? result;
}

void autoSetupPhone(WidgetTester tester, [Size size = voicePhone]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Taps [finder] after scrolling the sheet to it.
Future<void> autoSetupTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await pumpSheet(tester);
}

/// Opens the first-mic sheet over the real controller, manager and
/// composer, with [info] as the phone and Wi-Fi as the network.
Future<AutoSetupRig> openAutoSetup(
  WidgetTester tester, {
  VoiceDeviceInfo? info,
  Size size = voicePhone,
  bool light = true,
  Key? boundary,
  VoiceSetupNetwork network = VoiceSetupNetwork.unmetered,
}) async {
  autoSetupPhone(tester, size);
  SharedPreferences.setMockInitialValues({});
  final downloader = AutoSetupDownloader();
  final models = VoiceModelManager(
    root: '/synthetic-voice-models',
    preferences: await SharedPreferences.getInstance(),
    downloader: downloader,
    devicePlatform: AutoSetupDevice(info ?? autoSetupInfo()),
  );
  final rig = AutoSetupRig(
    models,
    downloader,
    AutoSetupPlatform()..current = network,
    FakeVoiceRecorder(),
  );
  addTearDown(() {
    rig.composer.dispose();
    models.dispose();
  });
  await tester.pumpWidget(
    voiceHost(
      light: light,
      boundary: boundary,
      home: voiceLauncher((context) async {
        rig.result = await showVoiceAutomaticSetupSheet(
          context,
          rig.composer,
          platform: rig.platform,
        );
        return rig.result;
      }),
    ),
  );
  await tester.tap(find.text('Open'));
  await pumpSheet(tester);
  await pumpSheet(tester);
  return rig;
}

/// Stops the fake recording so no capture timer outlives the test.
Future<void> stopAutoSetupRecording(
  WidgetTester tester,
  AutoSetupRig rig,
) async {
  unawaited(rig.composer.cancel());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

String plainMb(int bytes) => '${(bytes / 1000000).round()} MB';
