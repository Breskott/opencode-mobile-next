import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/voice/automatic_setup.dart';
import 'package:opencode_mobile/voice/automatic_setup_platform.dart';
import 'package:opencode_mobile/voice/controller.dart';
import 'package:opencode_mobile/voice/device.dart';
import 'package:opencode_mobile/voice/model_download.dart';
import 'package:opencode_mobile/voice/model_manager.dart';
import 'package:opencode_mobile/voice/model_manifest.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'voice_controller_test.dart' show FakeVoiceRecorder, FakeVoiceRecognizer;

class _UnusedHttp implements VoiceHttpTransport {
  @override
  void close() {}

  @override
  Future<VoiceHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const {},
    VoiceCancellationToken? cancellation,
  }) => throw StateError('Automatic setup tests must not use the network.');
}

class _Downloader extends VoiceModelDownloader {
  _Downloader()
    : super(store: const LocalVoiceFileStore(), http: _UnusedHttp());

  final installed = <String>{};
  int downloadCalls = 0;
  Completer<void>? gate;
  Object? failure;
  VoiceCancellationToken? cancellation;
  void Function(VoiceDownloadProgress)? reportProgress;
  void Function()? reportVerifying;

  @override
  Future<bool> verifyInstalled(
    String root,
    VoiceModelPack pack, {
    VoiceCancellationToken? cancellation,
  }) async => installed.contains(pack.id);

  @override
  Future<void> deletePack(String root, VoiceModelPack pack) async {
    installed.remove(pack.id);
  }

  @override
  Future<void> download(
    String root,
    VoiceModelPack pack, {
    required VoiceCancellationToken cancellation,
    required void Function(VoiceDownloadProgress) onProgress,
    required void Function() onVerifying,
    bool replaceExisting = false,
  }) async {
    downloadCalls++;
    this.cancellation = cancellation;
    reportProgress = onProgress;
    reportVerifying = onVerifying;
    await gate?.future;
    if (failure case final value?) throw value;
    // Deliberately allow a late completion after cancellation. The manager and
    // setup controller must prevent it from authorizing microphone capture.
    if (!cancellation.isCancelled) installed.add(pack.id);
  }
}

VoiceDeviceInfo _deviceInfo({
  int? memory = 4096,
  int memoryClass = 256,
  int storage = 4 * 1024 * 1024 * 1024,
  bool microphone = true,
  bool capture = true,
  List<String> abis = const ['arm64-v8a'],
}) => VoiceDeviceInfo(
  availableStorageBytes: storage,
  memoryClassMb: memoryClass,
  totalMemoryMb: memory,
  supportedAbis: abis,
  hasMicrophone: microphone,
  captureSupported: capture,
);

class _Device implements VoiceDevicePlatform {
  _Device(this.info);

  VoiceDeviceInfo info;
  int calls = 0;
  Completer<VoiceDeviceInfo>? gate;

  @override
  Future<VoiceDeviceInfo> getDeviceInfo() {
    calls++;
    return gate?.future ?? Future.value(info);
  }

  @override
  Future<VoiceMicrophonePermission> requestMicrophonePermission() async =>
      VoiceMicrophonePermission.granted;

  @override
  Future<void> openAppSettings() async {}
}

class _Platform implements VoiceSetupPlatform {
  VoiceSetupNetwork currentNetwork = VoiceSetupNetwork.unmetered;
  bool permission = true;
  Completer<bool>? permissionGate;
  bool postAccepted = true;
  bool postThrows = false;
  int networkCalls = 0;
  int permissionCalls = 0;
  int dismissCalls = 0;
  final notifications =
      <({VoiceSetupNotificationPhase phase, int received, int total})>[];

  @override
  Future<VoiceSetupNetwork> network() async {
    networkCalls++;
    return currentNetwork;
  }

  @override
  Future<bool> requestNotificationPermission() async {
    permissionCalls++;
    if (permissionGate case final gate?) return await gate.future;
    return permission;
  }

  @override
  Future<bool> showNotification({
    required VoiceSetupNotificationPhase phase,
    required int receivedBytes,
    required int totalBytes,
  }) async {
    if (postThrows) throw StateError('Synthetic notification failure');
    notifications.add((
      phase: phase,
      received: receivedBytes,
      total: totalBytes,
    ));
    return permission && postAccepted;
  }

  @override
  Future<void> dismissNotification() async {
    dismissCalls++;
  }
}

class _Recorder extends FakeVoiceRecorder {
  bool failStart = false;

  @override
  Future<Stream<Uint8List>> start() {
    if (failStart) {
      startCalls++;
      throw StateError('Synthetic microphone failure');
    }
    return super.start();
  }
}

class _Fixture {
  _Fixture(this.models, this.downloader, this.device, this.platform)
    : recorder = _Recorder() {
    composer = VoiceComposerController(
      models: models,
      recorder: recorder,
      recognizer: FakeVoiceRecognizer(),
    );
    setup = VoiceAutomaticSetupController(
      composer: composer,
      platform: platform,
    );
  }

  final VoiceModelManager models;
  final _Downloader downloader;
  final _Device device;
  final _Platform platform;
  final _Recorder recorder;
  late final VoiceComposerController composer;
  late final VoiceAutomaticSetupController setup;
  bool disposed = false;

  void disposeSetup() {
    if (disposed) return;
    disposed = true;
    setup.dispose();
  }

  void dispose() {
    disposeSetup();
    composer.dispose();
  }
}

Future<_Fixture> _fixture({
  VoiceDeviceInfo? info,
  String selected = 'base',
  Set<String> installed = const {},
}) async {
  SharedPreferences.setMockInitialValues({'voice.selected_pack': selected});
  final downloader = _Downloader()..installed.addAll(installed);
  final device = _Device(info ?? _deviceInfo());
  final models = VoiceModelManager(
    root: '/synthetic-voice-models',
    preferences: await SharedPreferences.getInstance(),
    downloader: downloader,
    devicePlatform: device,
  );
  final fixture = _Fixture(models, downloader, device, _Platform());
  addTearDown(fixture.dispose);
  return fixture;
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    debugPlatformCapabilities = const PlatformCapabilities.android();
    addTearDown(() => debugPlatformCapabilities = null);
  });

  test('creation and confirmation without a mic tap perform no work', () async {
    final f = await _fixture();
    await f.setup.confirmDownload(allowMetered: true);
    expect(f.setup.stage, VoiceSetupStage.idle);
    expect(f.device.calls, 0);
    expect(f.platform.networkCalls, 0);
    expect(f.downloader.downloadCalls, 0);
    expect(f.recorder.startCalls, 0);
  });

  for (final entry in <(int, String)>[
    (1024, 'tiny'),
    (1535, 'tiny'),
    (1536, 'base'),
    (3399, 'base'),
    (3400, 'small'),
    (16384, 'small'),
  ]) {
    test('total RAM ${entry.$1} selects ${entry.$2} before consent', () async {
      final f = await _fixture(info: _deviceInfo(memory: entry.$1));
      await f.setup.requestMicrophone();
      expect(f.setup.stage, VoiceSetupStage.consentRequired);
      expect(f.setup.pack?.id, entry.$2);
      expect(f.setup.downloadBytes, voiceModelPack(entry.$2).downloadBytes);
      expect(f.models.preferences.getString('voice.selected_pack'), entry.$2);
      expect(f.downloader.downloadCalls, 0);
      expect(f.recorder.startCalls, 0);
      expect(f.platform.permissionCalls, 0);
    });
  }

  test('a large Java heap class cannot qualify a low RAM device', () async {
    final f = await _fixture(
      info: _deviceInfo(memory: 1024, memoryClass: 16384),
    );
    await f.setup.requestMicrophone();
    expect(f.setup.pack?.id, 'tiny');
  });

  for (final memory in <int?>[null, 0, -1]) {
    test(
      'unknown or nonpositive total RAM $memory blocks automatic setup',
      () async {
        final f = await _fixture(info: _deviceInfo(memory: memory));
        await f.setup.requestMicrophone();
        expect(f.setup.stage, VoiceSetupStage.blocked);
        expect(f.setup.problem, VoiceSetupProblem.unknownMemory);
        expect(f.downloader.downloadCalls, 0);
        expect(f.recorder.startCalls, 0);
      },
    );
  }

  for (final info in [
    _deviceInfo(microphone: false),
    _deviceInfo(capture: false),
  ]) {
    test('unavailable capture never starts setup or downloads', () async {
      final f = await _fixture(info: info);
      await f.setup.requestMicrophone();
      expect(f.setup.stage, VoiceSetupStage.blocked);
      expect(f.setup.problem, VoiceSetupProblem.unavailable);
      expect(f.downloader.downloadCalls, 0);
    });
  }

  for (final info in [
    _deviceInfo(memory: 1023),
    _deviceInfo(storage: 0),
    _deviceInfo(abis: ['unsupported-abi']),
  ]) {
    test('unsupported hardware or storage exposes no eligible pack', () async {
      final f = await _fixture(info: info);
      await f.setup.requestMicrophone();
      expect(f.setup.stage, VoiceSetupStage.blocked);
      expect(f.setup.problem, VoiceSetupProblem.noSupportedPack);
      expect(f.downloader.downloadCalls, 0);
    });
  }

  test('storage can reduce the automatic choice to a supported pack', () async {
    final bytes = voiceModelPack('base').downloadBytes + 128 * 1024 * 1024;
    final f = await _fixture(info: _deviceInfo(storage: bytes));
    await f.setup.requestMicrophone();
    expect(f.setup.pack?.id, 'base');
    expect(f.setup.stage, VoiceSetupStage.consentRequired);
  });

  test(
    'an installed selected eligible pack starts even while offline',
    () async {
      final f = await _fixture(selected: 'tiny', installed: {'tiny'});
      f.platform.currentNetwork = VoiceSetupNetwork.offline;
      await f.setup.requestMicrophone();
      expect(f.setup.pack?.id, 'tiny');
      expect(f.setup.stage, VoiceSetupStage.listening);
      expect(f.recorder.startCalls, 1);
      expect(f.platform.networkCalls, 0);
      expect(f.platform.permissionCalls, 0);
      expect(f.downloader.downloadCalls, 0);
    },
  );

  test('installed selected pack above physical RAM does not start', () async {
    final f = await _fixture(
      selected: 'small',
      installed: {'small'},
      info: _deviceInfo(memory: 1536),
    );
    await f.setup.requestMicrophone();
    expect(f.setup.pack?.id, 'base');
    expect(f.setup.stage, VoiceSetupStage.consentRequired);
    expect(f.recorder.startCalls, 0);
  });

  test('offline first use blocks and can retry after reconnecting', () async {
    final f = await _fixture();
    f.platform.currentNetwork = VoiceSetupNetwork.offline;
    await f.setup.requestMicrophone();
    expect(f.setup.stage, VoiceSetupStage.blocked);
    expect(f.setup.problem, VoiceSetupProblem.offline);
    expect(f.downloader.downloadCalls, 0);
    f.platform.currentNetwork = VoiceSetupNetwork.unmetered;
    await f.setup.requestMicrophone();
    expect(f.setup.stage, VoiceSetupStage.consentRequired);
    expect(f.setup.problem, isNull);
  });

  for (final network in [
    VoiceSetupNetwork.metered,
    VoiceSetupNetwork.unknown,
  ]) {
    test(
      '$network requires explicit data consent before downloading',
      () async {
        final f = await _fixture();
        f.platform.currentNetwork = network;
        await f.setup.requestMicrophone();
        await f.setup.confirmDownload();
        expect(f.setup.stage, VoiceSetupStage.consentRequired);
        expect(f.setup.network, network);
        expect(f.downloader.downloadCalls, 0);
        await f.setup.confirmDownload(allowMetered: true);
        expect(f.downloader.downloadCalls, 1);
        expect(f.setup.stage, VoiceSetupStage.listening);
      },
    );
  }

  test(
    'Wi-Fi changing to mobile data before consent requires data approval',
    () async {
      final f = await _fixture();
      await f.setup.requestMicrophone();
      f.platform.currentNetwork = VoiceSetupNetwork.metered;
      await f.setup.confirmDownload();
      expect(f.setup.stage, VoiceSetupStage.consentRequired);
      expect(f.setup.network, VoiceSetupNetwork.metered);
      expect(f.downloader.downloadCalls, 0);
    },
  );

  test(
    'going offline before consent blocks even with mobile approval',
    () async {
      final f = await _fixture();
      await f.setup.requestMicrophone();
      f.platform.currentNetwork = VoiceSetupNetwork.offline;
      await f.setup.confirmDownload(allowMetered: true);
      expect(f.setup.stage, VoiceSetupStage.blocked);
      expect(f.setup.problem, VoiceSetupProblem.offline);
      expect(f.downloader.downloadCalls, 0);
    },
  );

  test(
    'progress and verification precede ready notification and listening',
    () async {
      final f = await _fixture();
      f.downloader.gate = Completer<void>();
      await f.setup.requestMicrophone();
      final finishing = f.setup.confirmDownload();
      await _flush();
      expect(f.setup.stage, VoiceSetupStage.downloading);
      final total = f.setup.downloadBytes;
      f.downloader.reportProgress!(
        VoiceDownloadProgress(
          received: total ~/ 2,
          total: total,
          fileName: 'fixture',
        ),
      );
      await _flush();
      expect(f.setup.receivedBytes, total ~/ 2);
      expect(f.recorder.startCalls, 0);
      expect(
        f.platform.notifications.any((n) => n.received == total ~/ 2),
        isTrue,
      );
      f.downloader.reportVerifying!();
      await _flush();
      expect(f.setup.stage, VoiceSetupStage.verifying);
      expect(f.recorder.startCalls, 0);
      expect(
        f.platform.notifications.any(
          (n) => n.phase == VoiceSetupNotificationPhase.verifying,
        ),
        isTrue,
      );
      f.downloader.gate!.complete();
      await finishing;
      await _flush();
      expect(f.models.isReady, isTrue);
      expect(f.setup.stage, VoiceSetupStage.listening);
      expect(f.recorder.startCalls, 1);
      expect(
        f.platform.notifications.any(
          (n) => n.phase == VoiceSetupNotificationPhase.complete,
        ),
        isTrue,
      );
    },
  );

  test(
    'notification permission denial still permits foreground setup',
    () async {
      final f = await _fixture();
      f.platform.permission = false;
      await f.setup.requestMicrophone();
      await f.setup.confirmDownload();
      expect(f.setup.notificationAvailable, isFalse);
      expect(f.setup.stage, VoiceSetupStage.listening);
      expect(f.recorder.startCalls, 1);
    },
  );

  for (final throws in [false, true]) {
    test(
      'notification ${throws ? 'exception' : 'rejection'} does not block listening',
      () async {
        final f = await _fixture();
        f.platform.postAccepted = false;
        f.platform.postThrows = throws;
        await f.setup.requestMicrophone();
        await f.setup.confirmDownload();
        expect(f.setup.notificationAvailable, isFalse);
        expect(f.setup.stage, VoiceSetupStage.listening);
        expect(f.recorder.startCalls, 1);
      },
    );
  }

  test(
    'network changing during the notification permission prompt needs data approval',
    () async {
      final f = await _fixture();
      f.platform.permissionGate = Completer<bool>();
      await f.setup.requestMicrophone();
      final confirm = f.setup.confirmDownload();
      await _flush();
      expect(f.platform.permissionCalls, 1);
      expect(f.downloader.downloadCalls, 0);
      f.platform.currentNetwork = VoiceSetupNetwork.metered;
      f.platform.permissionGate!.complete(true);
      await confirm;
      expect(f.setup.stage, VoiceSetupStage.consentRequired);
      expect(f.setup.network, VoiceSetupNetwork.metered);
      expect(f.downloader.downloadCalls, 0);
      await f.setup.confirmDownload(allowMetered: true);
      expect(f.setup.stage, VoiceSetupStage.listening);
    },
  );

  for (final dispose in [false, true]) {
    test(
      '${dispose ? 'disposal' : 'cancellation'} during notification permission revokes setup',
      () async {
        final f = await _fixture();
        f.platform.permissionGate = Completer<bool>();
        await f.setup.requestMicrophone();
        final confirm = f.setup.confirmDownload();
        await _flush();
        expect(f.platform.permissionCalls, 1);
        if (dispose) {
          f.disposeSetup();
        } else {
          await f.setup.cancel();
        }
        f.platform.permissionGate!.complete(true);
        await confirm;
        expect(f.downloader.downloadCalls, 0);
        expect(f.recorder.startCalls, 0);
        expect(f.platform.notifications, isEmpty);
      },
    );
  }

  test(
    'cancelling a pending microphone start prevents late listening',
    () async {
      final f = await _fixture(installed: {'base'});
      f.recorder.startGate = Completer<void>();
      final request = f.setup.requestMicrophone();
      await _flush();
      expect(f.setup.stage, VoiceSetupStage.starting);
      expect(f.recorder.startCalls, 1);
      await f.setup.cancel();
      f.recorder.startGate!.complete();
      await request;
      expect(f.setup.stage, VoiceSetupStage.cancelled);
      expect(f.composer.state, isNot(VoiceComposerState.listening));
      expect(f.recorder.audioClosed, isTrue);
    },
  );

  test(
    'verification failure prevents listening and retry asks for consent',
    () async {
      final f = await _fixture();
      f.downloader.failure = const VoiceDownloadException(
        'Synthetic checksum mismatch',
        failure: VoiceDownloadFailure.checksum,
      );
      await f.setup.requestMicrophone();
      await f.setup.confirmDownload();
      expect(f.setup.stage, VoiceSetupStage.failed);
      expect(f.setup.problem, VoiceSetupProblem.downloadFailed);
      expect(f.models.isReady, isFalse);
      expect(f.recorder.startCalls, 0);
      f.downloader.failure = null;
      await f.setup.requestMicrophone();
      expect(f.setup.stage, VoiceSetupStage.consentRequired);
      expect(f.downloader.downloadCalls, 1);
      await f.setup.confirmDownload();
      expect(f.setup.stage, VoiceSetupStage.listening);
      expect(f.downloader.downloadCalls, 2);
    },
  );

  test('microphone failure is recoverable without downloading again', () async {
    final f = await _fixture(installed: {'base'});
    f.recorder.failStart = true;
    await f.setup.requestMicrophone();
    expect(f.setup.stage, VoiceSetupStage.failed);
    expect(f.setup.problem, VoiceSetupProblem.listeningFailed);
    f.recorder.failStart = false;
    await f.setup.requestMicrophone();
    expect(f.setup.stage, VoiceSetupStage.listening);
    expect(f.downloader.downloadCalls, 0);
  });

  test(
    'automatic selection survives restart and deleting it requires consent again',
    () async {
      final f = await _fixture();
      await f.setup.requestMicrophone();
      await f.setup.confirmDownload();
      await f.setup.cancel();
      final restored = VoiceModelManager(
        root: f.models.root,
        preferences: f.models.preferences,
        downloader: f.downloader,
        devicePlatform: f.device,
      );
      addTearDown(restored.dispose);
      await restored.initialize();
      expect(restored.selectedPack.id, 'small');
      expect(restored.isReady, isTrue);
      await f.models.deletePack(voiceModelPack('small'));
      await f.setup.requestMicrophone();
      expect(f.setup.stage, VoiceSetupStage.consentRequired);
      expect(f.downloader.downloadCalls, 1);
      expect(f.recorder.startCalls, 1);
    },
  );

  test(
    'duplicate mic taps and download confirmations do not duplicate work',
    () async {
      final f = await _fixture();
      f.device.gate = Completer<VoiceDeviceInfo>();
      final request = f.setup.requestMicrophone();
      await f.setup.requestMicrophone();
      expect(f.device.calls, 1);
      f.device.gate!.complete(_deviceInfo());
      await request;
      f.downloader.gate = Completer<void>();
      final download = f.setup.confirmDownload();
      await f.setup.confirmDownload();
      await f.setup.requestMicrophone();
      await _flush();
      expect(f.downloader.downloadCalls, 1);
      f.downloader.gate!.complete();
      await download;
      await f.setup.requestMicrophone();
      expect(f.recorder.startCalls, 1);
    },
  );

  test('an existing manager download remains owned by its caller', () async {
    final f = await _fixture();
    await f.models.initialize();
    f.downloader.gate = Completer<void>();
    final externalDownload = f.models.downloadSelected();
    await _flush();
    final probes = f.device.calls;
    await f.setup.requestMicrophone();
    expect(f.setup.stage, VoiceSetupStage.blocked);
    expect(f.setup.problem, VoiceSetupProblem.busy);
    expect(f.device.calls, probes);
    expect(f.downloader.cancellation!.isCancelled, isFalse);
    f.downloader.gate!.complete();
    await externalDownload;
    expect(f.recorder.startCalls, 0);
  });

  test('external download preflight stays owned by its caller', () async {
    final f = await _fixture();
    await f.models.initialize();
    f.device.gate = Completer<VoiceDeviceInfo>();
    final externalDownload = f.models.downloadSelected();
    await _flush();
    final probes = f.device.calls;
    expect(f.models.downloadInProgress, isTrue);
    expect(f.downloader.downloadCalls, 0);
    await f.setup.requestMicrophone();
    expect(f.setup.stage, VoiceSetupStage.blocked);
    expect(f.setup.problem, VoiceSetupProblem.busy);
    expect(f.device.calls, probes);
    await f.setup.cancel();
    f.device.gate!.complete(_deviceInfo());
    await externalDownload;
    expect(f.downloader.downloadCalls, 1);
    expect(f.downloader.cancellation!.isCancelled, isFalse);
    expect(f.recorder.startCalls, 0);
  });

  test('cancelled consent cannot authorize a download', () async {
    final f = await _fixture();
    await f.setup.requestMicrophone();
    await f.setup.cancel();
    await f.setup.confirmDownload(allowMetered: true);
    expect(f.setup.stage, VoiceSetupStage.cancelled);
    expect(f.downloader.downloadCalls, 0);
  });

  test(
    'cancellation during device probing prevents a late consent state',
    () async {
      final f = await _fixture();
      f.device.gate = Completer<VoiceDeviceInfo>();
      final request = f.setup.requestMicrophone();
      await f.setup.cancel();
      f.device.gate!.complete(_deviceInfo());
      await request;
      expect(f.setup.stage, VoiceSetupStage.cancelled);
      expect(f.downloader.downloadCalls, 0);
      expect(f.recorder.startCalls, 0);
    },
  );

  for (final dispose in [false, true]) {
    test(
      '${dispose ? 'disposal' : 'cancellation'} rejects late download completion',
      () async {
        final f = await _fixture();
        f.downloader.gate = Completer<void>();
        await f.setup.requestMicrophone();
        final finishing = f.setup.confirmDownload();
        await _flush();
        expect(f.downloader.downloadCalls, 1);
        if (dispose) {
          f.disposeSetup();
        } else {
          await f.setup.cancel();
          expect(f.setup.stage, VoiceSetupStage.cancelled);
        }
        f.downloader.gate!.complete();
        await finishing;
        await _flush();
        expect(f.recorder.startCalls, 0);
        expect(
          f.platform.notifications.any(
            (n) => n.phase == VoiceSetupNotificationPhase.complete,
          ),
          isFalse,
        );
        expect(f.platform.dismissCalls, greaterThan(0));
      },
    );
  }

  test('a download that finishes in the background waits at ready, and '
      'the next mic tap starts listening', () async {
    final f = await _fixture();
    f.downloader.gate = Completer<void>();
    await f.setup.requestMicrophone();
    final finishing = f.setup.confirmDownload();
    await _flush();
    f.setup.setForeground(false);
    f.downloader.gate!.complete();
    await finishing;
    expect(f.setup.stage, VoiceSetupStage.ready);
    expect(f.models.isReady, isTrue);
    expect(f.recorder.startCalls, 0, reason: 'no microphone behind the back');

    f.setup.setForeground(true);
    await f.setup.requestMicrophone();
    expect(f.setup.stage, VoiceSetupStage.listening);
    expect(f.recorder.startCalls, 1);
    expect(f.downloader.downloadCalls, 1);
  });

  test('a handed-off recording survives the setup controller', () async {
    final f = await _fixture(selected: 'tiny', installed: {'tiny'});
    await f.setup.requestMicrophone();
    expect(f.composer.state, VoiceComposerState.listening);
    final cancels = f.recorder.cancelCalls;
    f.setup.handOff();
    await f.setup.cancel();
    f.disposeSetup();
    await _flush();
    expect(f.composer.state, VoiceComposerState.listening);
    expect(f.recorder.cancelCalls, cancels);
  });

  test(
    'without the hand-off, cancelling stops the recording it started',
    () async {
      final f = await _fixture(selected: 'tiny', installed: {'tiny'});
      await f.setup.requestMicrophone();
      await f.setup.cancel();
      expect(f.composer.state, isNot(VoiceComposerState.listening));
    },
  );
}
