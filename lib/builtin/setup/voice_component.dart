import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../voice/model_download.dart';
import '../../voice/model_manager.dart';
import '../../voice/model_manifest.dart';
import 'setup_contract.dart';

/// Voice typing's speech model as a phone setup component
/// ([SetupComponent.app]): offered on the setup's Customize sheet and in
/// "Add tools", off by default.
///
/// It is not part of Linux. The model lives in the app's own storage and is
/// fetched, verified and deleted by the voice settings' own code
/// ([VoiceModelManager] and its downloader), so setup and Settings › Voice
/// always agree on what is on the phone. The downloader resumes a partial
/// file, so an install stopped by a killed app or a cancel continues where
/// it left off. The model is device-wide: nothing here is per profile.
class VoiceSetupComponent implements SetupAppComponent {
  VoiceSetupComponent({Future<VoiceModelManager> Function()? manager})
    : _manager = manager ?? VoiceModelManager.shared;

  static VoiceSetupComponent? _instance;

  /// The one the registry uses (components.dart).
  static VoiceSetupComponent get instance =>
      _instance ??= VoiceSetupComponent();

  @visibleForTesting
  static set instance(VoiceSetupComponent? value) => _instance = value;

  final Future<VoiceModelManager> Function() _manager;

  /// The size the last [offer] found, for the registry, which is built
  /// synchronously; null until the device has been asked.
  int? get lastOfferBytes => _lastOfferBytes;
  int? _lastOfferBytes;

  VoiceModelManager? _installing;
  bool _cancelled = false;

  /// The pack Settings › Voice would use on this phone: one already on the
  /// phone (the chosen one first), else the chosen one (Balanced unless the
  /// person picked another), else the best one this phone can run. Gated on
  /// total RAM and the CPU, never on Android's per-app memory class; free
  /// space is not a reason to leave it out (setup's pre-flight says how much
  /// to free). Null when this phone can run none.
  static VoiceModelPack? packFor(VoiceModelManager manager) {
    if (!manager.deviceInfo.captureSupported) return null;
    bool runs(VoiceModelPack pack) {
      final support = manager.supportFor(pack);
      return support.supported || support.kind == VoicePackUnsupported.storage;
    }

    final selected = manager.selectedPack;
    if (manager.isInstalled(selected) && runs(selected)) return selected;
    for (final pack in voiceModelPacks) {
      if (manager.isInstalled(pack) && runs(pack)) return pack;
    }
    if (runs(selected)) return selected;
    final candidates = voiceModelPacks.where(runs).toList()
      ..sort((a, b) => b.minimumMemoryMb.compareTo(a.minimumMemoryMb));
    return candidates.firstOrNull;
  }

  Future<VoiceModelManager?> _managerOrNull() async {
    try {
      return await _manager();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<SetupAppOffer?> offer() async {
    final manager = await _managerOrNull();
    if (manager == null) return null;
    final pack = packFor(manager);
    if (pack == null) return null;
    final installed = manager.isInstalled(manager.selectedPack);
    final bytes = installed ? _installedBytes(manager) : pack.downloadBytes;
    _lastOfferBytes = pack.downloadBytes;
    return SetupAppOffer(downloadBytes: bytes, installed: installed);
  }

  static int _installedBytes(VoiceModelManager manager) => [
    for (final pack in voiceModelPacks)
      if (manager.isInstalled(pack)) pack.downloadBytes,
  ].fold(0, (total, bytes) => total + bytes);

  /// Installed means voice typing works: the pack in use is on the phone.
  @override
  Future<({bool ok, String? version})> check() async {
    final manager = await _managerOrNull();
    final ok = manager != null && manager.isInstalled(manager.selectedPack);
    return (ok: ok, version: null);
  }

  @override
  Future<String?> install({
    required void Function(SetupAppProgress progress) onProgress,
  }) async {
    final manager = await _managerOrNull();
    if (manager == null) {
      throw const SetupAppFailure(SetupAppFailureKind.failed);
    }
    final pack = packFor(manager);
    if (pack == null) {
      throw const SetupAppFailure(SetupAppFailureKind.unsupported);
    }
    // Settings › Voice is downloading right now: never take it over.
    if (manager.downloadInProgress) {
      throw const SetupAppFailure(SetupAppFailureKind.busy);
    }
    await manager.selectPack(pack);
    if (manager.isInstalled(pack)) return null;
    _cancelled = false;
    _installing = manager;
    void report() {
      final progress = manager.progress;
      onProgress(
        SetupAppProgress(
          stage: manager.state == VoiceModelState.verifying
              ? SetupAppStage.verifying
              : SetupAppStage.downloading,
          bytesDone: progress?.received,
          bytesTotal: progress?.total ?? pack.downloadBytes,
        ),
      );
    }

    manager.addListener(report);
    try {
      await manager.downloadSelected();
    } finally {
      manager.removeListener(report);
      _installing = null;
    }
    if (_cancelled) {
      throw const SetupAppFailure(SetupAppFailureKind.cancelled);
    }
    if (manager.isInstalled(pack) && manager.selectedPack.id == pack.id) {
      return null;
    }
    throw SetupAppFailure(failureOf(manager.error));
  }

  @override
  void cancel() {
    _cancelled = true;
    _installing?.cancelDownload();
  }

  /// Deletes every pack, a partial download included, so removing voice
  /// typing gives all its space back.
  @override
  Future<void> remove() async {
    final manager = await _managerOrNull();
    if (manager == null) {
      throw const SetupAppFailure(SetupAppFailureKind.failed);
    }
    if (manager.downloadInProgress ||
        manager.state == VoiceModelState.loading) {
      throw const SetupAppFailure(SetupAppFailureKind.busy);
    }
    try {
      for (final pack in voiceModelPacks) {
        await manager.deletePack(pack);
      }
    } catch (_) {
      throw const SetupAppFailure(SetupAppFailureKind.failed);
    }
    if (voiceModelPacks.any(manager.isInstalled)) {
      throw const SetupAppFailure(SetupAppFailureKind.failed);
    }
  }

  /// The manager's error as a kind; its text never leaves the voice code.
  @visibleForTesting
  static SetupAppFailureKind failureOf(Object? error) {
    if (error is VoiceModelPreflightException) {
      return error.support?.kind == VoicePackUnsupported.storage
          ? SetupAppFailureKind.noSpace
          : SetupAppFailureKind.unsupported;
    }
    if (error is VoiceDownloadException) {
      return switch (error.failure) {
        VoiceDownloadFailure.checksum ||
        VoiceDownloadFailure.verification => SetupAppFailureKind.checksum,
        VoiceDownloadFailure.timeout ||
        VoiceDownloadFailure.noResponse ||
        VoiceDownloadFailure.incomplete => SetupAppFailureKind.offline,
        _ => SetupAppFailureKind.failed,
      };
    }
    if (error is SocketException ||
        error is HttpException ||
        error is HandshakeException ||
        error is TimeoutException) {
      return SetupAppFailureKind.offline;
    }
    if (error is FileSystemException && error.osError?.errorCode == 28) {
      return SetupAppFailureKind.noSpace;
    }
    return SetupAppFailureKind.failed;
  }
}
