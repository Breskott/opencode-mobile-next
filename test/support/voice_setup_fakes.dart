import 'dart:async';
import 'dart:typed_data';

import 'package:opencode_mobile/builtin/setup/setup_contract.dart';
import 'package:opencode_mobile/voice/device.dart';
import 'package:opencode_mobile/voice/model_download.dart';
import 'package:opencode_mobile/voice/model_manager.dart';
import 'package:opencode_mobile/voice/model_manifest.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Voice typing in phone setup, without a network or files: a downloader
/// that keeps packs in memory and resumes a partial download like the real
/// one does (HTTP Range on its `.part` file), and a scriptable app-side
/// component for engine and screen tests.

class _NoStore implements VoiceFileStore {
  @override
  Future<void> createDirectory(String path) async {}
  @override
  Future<void> delete(String path) async {}
  @override
  Future<bool> exists(String path) async => false;
  @override
  Future<int> length(String path) async => 0;
  @override
  Stream<List<int>> read(String path) => const Stream.empty();
  @override
  Future<Uint8List> readBytes(String path) async => Uint8List(0);
  @override
  Future<VoiceByteSink> openWrite(String path, {required bool append}) =>
      throw UnimplementedError();
  @override
  Future<void> move(String from, String to) async {}
  @override
  Future<void> writeAtomic(String path, List<int> bytes) async {}
}

class _NoHttp implements VoiceHttpTransport {
  @override
  Future<VoiceHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const {},
    VoiceCancellationToken? cancellation,
  }) => throw UnimplementedError('no network in tests');

  @override
  void close() {}
}

class FakeVoiceDownloader extends VoiceModelDownloader {
  FakeVoiceDownloader() : super(store: _NoStore(), http: _NoHttp());

  final installed = <String>{};

  /// Bytes an interrupted download left behind, by pack id.
  final partial = <String, int>{};

  /// Where each download started, in bytes (a resume starts past zero).
  final starts = <int>[];
  final replaceFlags = <bool>[];
  final deleted = <String>[];

  /// Holds a download halfway until completed (or cancelled).
  Completer<void>? gate;

  /// Thrown once the download passes the gate.
  Object? failWith;

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
    required void Function(VoiceDownloadProgress progress) onProgress,
    required void Function() onVerifying,
    bool replaceExisting = false,
  }) async {
    replaceFlags.add(replaceExisting);
    final total = pack.downloadBytes;
    final from = partial[pack.id] ?? 0;
    starts.add(from);
    final half = total ~/ 2;
    if (from < half) {
      partial[pack.id] = half;
      onProgress(
        VoiceDownloadProgress(received: half, total: total, fileName: 'x'),
      );
    }
    final hold = gate;
    if (hold != null) {
      await Future.any([hold.future, cancellation.whenCancelled]);
    }
    cancellation.throwIfCancelled();
    final failure = failWith;
    if (failure != null) throw failure;
    onProgress(
      VoiceDownloadProgress(received: total, total: total, fileName: 'x'),
    );
    onVerifying();
    partial.remove(pack.id);
    installed.add(pack.id);
  }

  @override
  Future<void> deletePack(String root, VoiceModelPack pack) async {
    deleted.add(pack.id);
    installed.remove(pack.id);
    partial.remove(pack.id);
  }
}

class FakeVoiceDevice implements VoiceDevicePlatform {
  FakeVoiceDevice(this.info);

  VoiceDeviceInfo info;

  @override
  Future<VoiceDeviceInfo> getDeviceInfo() async => info;

  @override
  Future<VoiceMicrophonePermission> requestMicrophonePermission() async =>
      VoiceMicrophonePermission.granted;

  @override
  Future<void> openAppSettings() async {}
}

/// A phone with [totalMemoryMb] of RAM (null: it could not be read) and
/// plenty of space.
VoiceDeviceInfo voicePhone({
  int? totalMemoryMb = 8000,
  int? memoryClassMb = 256,
  int? availableStorageBytes = 20 * 1000 * 1000 * 1000,
  bool captureSupported = true,
}) => VoiceDeviceInfo(
  availableStorageBytes: availableStorageBytes,
  memoryClassMb: memoryClassMb,
  totalMemoryMb: totalMemoryMb,
  supportedAbis: const ['arm64-v8a'],
  hasMicrophone: captureSupported,
  captureSupported: captureSupported,
);

Future<VoiceModelManager> fakeVoiceManager(
  FakeVoiceDownloader downloader, {
  VoiceDeviceInfo? device,
  Map<String, Object> preferences = const {},
}) async {
  SharedPreferences.setMockInitialValues(preferences);
  final manager = VoiceModelManager(
    root: '/models',
    preferences: await SharedPreferences.getInstance(),
    downloader: downloader,
    devicePlatform: FakeVoiceDevice(device ?? voicePhone()),
  );
  await manager.initialize();
  return manager;
}

/// A scriptable [SetupAppComponent].
class FakeSetupApp implements SetupAppComponent {
  FakeSetupApp({
    this.offered = const SetupAppOffer(downloadBytes: 160 * 1000 * 1000),
    this.installed = false,
  });

  /// Null: this phone cannot have it.
  SetupAppOffer? offered;
  bool installed;
  var installs = 0;
  var cancels = 0;
  var removes = 0;
  var checks = 0;

  /// Holds [install] until completed; [cancel] ends it as cancelled.
  Completer<void>? gate;
  SetupAppFailureKind? failWith;
  SetupAppFailureKind? removeFailsWith;
  final List<SetupAppProgress> progressToReport = const [
    SetupAppProgress(
      stage: SetupAppStage.downloading,
      bytesDone: 80,
      bytesTotal: 160,
    ),
  ];
  Completer<void>? _cancelled;

  @override
  Future<SetupAppOffer?> offer() async {
    final offer = offered;
    if (offer == null) return null;
    return SetupAppOffer(
      downloadBytes: offer.downloadBytes,
      installed: installed,
    );
  }

  @override
  Future<({bool ok, String? version})> check() async {
    checks++;
    return (ok: installed, version: null);
  }

  @override
  Future<String?> install({
    required void Function(SetupAppProgress progress) onProgress,
  }) async {
    installs++;
    if (installed) return null;
    progressToReport.forEach(onProgress);
    final cancelled = _cancelled = Completer<void>();
    final hold = gate;
    if (hold != null) await Future.any([hold.future, cancelled.future]);
    if (cancelled.isCompleted) {
      throw const SetupAppFailure(SetupAppFailureKind.cancelled);
    }
    final failure = failWith;
    if (failure != null) throw SetupAppFailure(failure);
    installed = true;
    return null;
  }

  @override
  void cancel() {
    cancels++;
    final cancelled = _cancelled;
    if (cancelled != null && !cancelled.isCompleted) cancelled.complete();
  }

  @override
  Future<void> remove() async {
    removes++;
    final failure = removeFailsWith;
    if (failure != null) throw SetupAppFailure(failure);
    installed = false;
  }
}

/// The voice item as the registry declares it, around [app].
SetupComponent voiceSetupItem(
  SetupAppComponent app, {
  int? downloadBytes = 160 * 1000 * 1000,
}) => SetupComponent(
  id: 'voice',
  title: 'Voice typing',
  shortTitle: 'Voice typing',
  summary: 'Speak instead of typing, even offline',
  estimatedSeconds: 45,
  downloadBytes: downloadBytes,
  checkScript: '',
  installScript: '',
  app: app,
);
