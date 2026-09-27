import 'dart:async';
import 'dart:ffi' show Abi;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/setup/components.dart';
import 'package:opencode_mobile/builtin/setup/setup_contract.dart';
import 'package:opencode_mobile/platform/network.dart';
import 'package:opencode_mobile/state/consent_owners.dart';
import 'package:opencode_mobile/state/download_size.dart';
import 'package:opencode_mobile/state/mobile_download_consent.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/voice/model_manifest.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const _mobile = NetworkReading(
  status: NetworkStatus.online,
  transport: NetworkTransport.mobile,
  metered: true,
  connected: true,
);
const _wifi = NetworkReading(
  status: NetworkStatus.online,
  transport: NetworkTransport.wifi,
  metered: true,
  connected: true,
);
const _large = DownloadSize.exact(50000001);

class _RefusingStore extends InMemorySharedPreferencesStore {
  _RefusingStore() : super.withData({});
  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });
  Future<MobileDownloadConsent> owner([String id = 'phone']) async =>
      ConsentOwners.mobileDownloads(await SharedPreferences.getInstance(), id);

  test('threshold is strict and only an explicit mobile route asks', () async {
    final gate = await owner();
    var calls = 0;
    for (final bytes in [0, 49999999, 50000000]) {
      final result = await gate.run(
        size: DownloadSize.exact(bytes),
        readNetwork: () async => _mobile,
        operation: () async => ++calls,
      );
      expect(result.decision.reason, MobileDownloadReason.belowThreshold);
    }
    final wifi = await gate.run(
      size: const DownloadSize.unknown(),
      readNetwork: () async => _wifi,
      operation: () async => ++calls,
    );
    expect(wifi.decision.reason, MobileDownloadReason.nonMobile);
    final mobile = await gate.run(
      size: _large,
      readNetwork: () async => _mobile,
      operation: () async => ++calls,
    );
    expect(mobile.decision.kind, MobileDownloadDecisionKind.needsConsent);
    expect(calls, 4);
  });

  test('unknown, VPN, offline and failed probes never run or claim', () async {
    final gate = await owner();
    for (final reading in [
      NetworkReading.unknown,
      const NetworkReading(
        status: NetworkStatus.online,
        transport: NetworkTransport.unknown,
        metered: true,
        connected: true,
      ),
      const NetworkReading(
        status: NetworkStatus.offline,
        transport: NetworkTransport.mobile,
        metered: true,
        connected: false,
      ),
    ]) {
      final result = await gate.run(
        size: _large,
        readNetwork: () async => reading,
        operation: () async => fail('Must not start a download'),
      );
      expect(result.decision.allowed, false);
    }
    final failed = await gate.request(
      size: _large,
      readNetwork: () async => throw StateError('sensitive native details'),
    );
    expect(failed.reason, MobileDownloadReason.networkUnknown);
    expect(gate.choice, MobileDownloadChoice.unseen);
  });

  test(
    'size provenance fails closed; sufficient lower bound can offer',
    () async {
      final gate = await owner();
      for (final size in [
        const DownloadSize.unknown(),
        const DownloadSize.estimate(999999999),
        const DownloadSize.lowerBound(50000000),
      ]) {
        final result = await gate.run(
          size: size,
          readNetwork: () async => _mobile,
          operation: () async => fail('Must not use incomplete size'),
        );
        expect(result.decision.reason, MobileDownloadReason.sizeUnknown);
      }
      expect(
        (await gate.request(
          size: const DownloadSize.lowerBound(50000001),
          readNetwork: () async => _mobile,
        )).kind,
        MobileDownloadDecisionKind.needsConsent,
      );
      await gate.answer(allow: true);
      expect(
        (await gate.run(
          size: const DownloadSize.lowerBound(50000001),
          readNetwork: () async => _mobile,
          operation: () async => 'downloaded',
        )).value,
        'downloaded',
      );
      expect(
        (await gate.request(
          size: const DownloadSize.unknown(),
          readNetwork: () async => _mobile,
        )).reason,
        MobileDownloadReason.sizeUnknown,
      );
    },
  );

  test(
    'concurrent claims persist once; denial and interruption survive reload',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final gate = await owner();
      final claims = await Future.wait(
        List.generate(
          4,
          (_) => gate.request(size: _large, readNetwork: () async => _mobile),
        ),
      );
      expect(
        claims.where((c) => c.kind == MobileDownloadDecisionKind.needsConsent),
        hasLength(1),
      );
      expect(
        prefs.getString('oc.mobileDownloadConsent.phone'),
        contains('offered'),
      );
      final interrupted = await MobileDownloadConsent.load(
        prefs,
        profileId: 'phone',
      );
      expect(
        (await interrupted.request(
          size: _large,
          readNetwork: () async => _mobile,
        )).reason,
        MobileDownloadReason.unfinished,
      );
      await gate.answer(allow: false);
      final restored = await MobileDownloadConsent.load(
        prefs,
        profileId: 'phone',
      );
      expect(
        (await restored.request(
          size: _large,
          readNetwork: () async => _mobile,
        )).reason,
        MobileDownloadReason.declined,
      );
      final other = await owner('other');
      expect(other.choice, MobileDownloadChoice.unseen);
      await restored.changeFromSettings(allow: true);
      expect(
        (await restored.run(
          size: _large,
          readNetwork: () async => _mobile,
          operation: () async => 42,
        )).value,
        42,
      );
    },
  );

  test(
    'accepted retry refreshes route; queued revocation precedes next start',
    () async {
      final gate = await owner();
      await gate.changeFromSettings(allow: true);
      final revoked = gate.changeFromSettings(allow: false);
      final blocked = gate.run(
        size: _large,
        readNetwork: () async => _mobile,
        operation: () async => fail('Consent was revoked before start'),
      );
      await revoked;
      expect((await blocked).decision.reason, MobileDownloadReason.declined);
      await gate.changeFromSettings(allow: true);
      expect(
        (await gate.run(
          size: _large,
          readNetwork: () async => NetworkReading.unknown,
          operation: () async => fail('Route must be refreshed'),
        )).decision.reason,
        MobileDownloadReason.networkUnknown,
      );
    },
  );

  test(
    'close and profile sweep reject stale owners without waiting on transfer',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final gate = await owner();
      await gate.changeFromSettings(allow: true);
      final started = Completer<void>();
      final transfer = Completer<String>();
      final running = gate.run(
        size: _large,
        readNetwork: () async => _mobile,
        operation: () {
          started.complete();
          return transfer.future;
        },
      );
      await started.future;
      await ConsentOwners.closeProfile(prefs, 'phone');
      final profiles = ProfileStore(prefs: prefs);
      expect(await profiles.removeScopedPreferences('phone'), isEmpty);
      expect(prefs.containsKey('oc.mobileDownloadConsent.phone'), false);
      await expectLater(gate.changeFromSettings(allow: true), throwsStateError);
      expect(
        (await gate.run(
          size: _large,
          readNetwork: () async => _mobile,
          operation: () async => fail('Closed owner must not run'),
        )).decision.reason,
        MobileDownloadReason.closed,
      );
      expect(prefs.containsKey('oc.mobileDownloadConsent.phone'), false);
      transfer.complete('finished');
      expect((await running).value, 'finished');
      expect((await owner()).choice, MobileDownloadChoice.unseen);
    },
  );

  test('closing during a probe cannot prompt or start later', () async {
    final gate = await owner();
    final probe = Completer<NetworkReading>();
    final entered = Completer<void>();
    final pending = gate.run(
      size: _large,
      readNetwork: () {
        entered.complete();
        return probe.future;
      },
      operation: () async => fail('Closed while awaiting probe'),
    );
    await entered.future;
    final closing = gate.close();
    probe.complete(_mobile);
    await closing;
    expect((await pending).decision.reason, MobileDownloadReason.closed);
  });

  test(
    'corrupt and refused persistence never authorize or return prompts',
    () async {
      SharedPreferences.setMockInitialValues({
        'oc.mobileDownloadConsent.phone': 'broken',
      });
      await expectLater(owner(), throwsStateError);
      SharedPreferencesStorePlatform.instance = _RefusingStore();
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final gate = await MobileDownloadConsent.load(prefs, profileId: 'fresh');
      final result = await gate.run(
        size: _large,
        readNetwork: () async => _mobile,
        operation: () async => fail('Failed durable claim must not run'),
      );
      expect(result.decision.reason, MobileDownloadReason.storageUnavailable);
      expect(gate.storageAvailable, false);
    },
  );

  test(
    'payload sources distinguish pinned bytes from setup display estimates',
    () {
      for (final pack in voiceModelPacks) {
        final size = DownloadSize.voicePack(pack);
        expect(size.kind, DownloadSizeKind.exact);
        expect(size.bytes, pack.downloadBytes);
      }
      final team = aiTeamSetupDownloadSize(abi: Abi.androidArm64);
      expect(team.kind, DownloadSizeKind.lowerBound);
      expect(team.bytes, 112378662);
      expect(aiTeamSetupDownloadSize(abi: Abi.androidX64).bytes, 122037705);
      expect(
        aiTeamSetupDownloadSize(abi: Abi.linuxX64).kind,
        DownloadSizeKind.unknown,
      );
      const component = SetupComponent(
        id: 'example',
        title: 'Example',
        shortTitle: 'Example',
        checkScript: '',
        installScript: '',
        downloadBytes: 60000000,
      );
      expect(
        component.withDownloadBytes(1).downloadSize.kind,
        DownloadSizeKind.unknown,
      );
      final refreshed = component.withAppOffer(
        const SetupAppOffer(
          downloadBytes: 60000000,
          downloadSize: DownloadSize.exact(60000000),
        ),
      );
      expect(refreshed.downloadSize.kind, DownloadSizeKind.exact);
      expect(refreshed.withDownloadBytes(1).downloadSize.bytes, 60000000);
      expect(
        DownloadSize.sum([team, const DownloadSize.estimate(3000000)]).bytes,
        team.bytes,
      );
      expect(
        DownloadSize.sum([
          const DownloadSize.exact(12),
          const DownloadSize.unknown(),
        ]).kind,
        DownloadSizeKind.lowerBound,
      );
    },
  );
}
