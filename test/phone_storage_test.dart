import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/platform/phone_storage.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/voice/device.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  VoiceDeviceInfo device(int? bytes) => VoiceDeviceInfo(
    availableStorageBytes: bytes,
    memoryClassMb: null,
    supportedAbis: const [],
    hasMicrophone: false,
  );

  test(
    'free-space warning includes zero and boundary; unknown stays unknown',
    () async {
      int? bytes;
      var scans = 0;
      final service = PhoneStorageService(
        capabilities: const PlatformCapabilities.android(),
        nearlyFullAtBytes: 100,
        readDeviceInfo: () async => device(bytes),
        readBuiltinStorage: () async {
          scans++;
          throw StateError('not requested');
        },
      );
      for (final (value, expected) in <(int?, PhoneStoragePressure)>[
        (null, PhoneStoragePressure.unknown),
        (-1, PhoneStoragePressure.unknown),
        (0, PhoneStoragePressure.nearlyFull),
        (100, PhoneStoragePressure.nearlyFull),
        (101, PhoneStoragePressure.aboveThreshold),
      ]) {
        bytes = value;
        final result = await service.read();
        final unknown = value == null || value < 0;
        expect(result.availableBytes, unknown ? null : value);
        expect(result.pressure, expected);
        expect(
          result.builtinAvailability,
          BuiltinStorageAvailability.notRequested,
        );
      }
      expect(scans, 0);
      expect(
        () => PhoneStorageService(nearlyFullAtBytes: -1),
        throwsArgumentError,
      );
    },
  );

  test(
    'independent failures preserve the other source and never stale data',
    () async {
      var failDevice = false;
      var failHost = false;
      var invalidHost = false;
      final service = PhoneStorageService(
        capabilities: const PlatformCapabilities.android(),
        readDeviceInfo: () async {
          if (failDevice) throw StateError('probe failed');
          return device(20);
        },
        readBuiltinStorage: () async {
          if (failHost) throw StateError('scan failed');
          return BuiltinProjectStorage(
            runtimeBytes: invalidHost ? -1 : 0,
            projectsBytes: 30,
            measuredAtMilliseconds: 10,
          );
        },
      );
      expect(
        (await service.read(
          includeBuiltinHost: true,
        )).builtinHost?.projectsBytes,
        30,
      );
      failHost = true;
      final missingHost = await service.read(includeBuiltinHost: true);
      expect(missingHost.availableBytes, 20);
      expect(missingHost.builtinHost, isNull);
      expect(
        missingHost.builtinAvailability,
        BuiltinStorageAvailability.unavailable,
      );
      failHost = false;
      failDevice = true;
      final missingDevice = await service.read(includeBuiltinHost: true);
      expect(missingDevice.pressure, PhoneStoragePressure.unknown);
      expect(missingDevice.builtinHost?.runtimeBytes, 0);
      expect(
        missingDevice.builtinAvailability,
        BuiltinStorageAvailability.available,
      );
      invalidHost = true;
      final invalid = await service.read(includeBuiltinHost: true);
      expect(invalid.builtinHost, isNull);
      expect(
        invalid.builtinAvailability,
        BuiltinStorageAvailability.unavailable,
      );
    },
  );

  test('unsupported platform performs no probes', () async {
    var calls = 0;
    final service = PhoneStorageService(
      capabilities: const PlatformCapabilities.linuxDesktop(),
      readDeviceInfo: () async {
        calls++;
        return device(5);
      },
      readBuiltinStorage: () async {
        calls++;
        throw StateError('unavailable');
      },
    );
    expect(service.isSupported, isFalse);
    final result = await service.read(includeBuiltinHost: true);
    expect(calls, 0);
    expect(result.availableBytes, isNull);
    expect(result.builtinAvailability, BuiltinStorageAvailability.unavailable);
  });

  test('default adapters use existing read-only native methods', () async {
    const voice = MethodChannel('oc/voice');
    const builtin = MethodChannel(BuiltinLinux.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final methods = <String>[];
    final previousCapabilities = debugPlatformCapabilities;
    debugPlatformCapabilities = const PlatformCapabilities.android();
    addTearDown(() {
      debugPlatformCapabilities = previousCapabilities;
      messenger.setMockMethodCallHandler(voice, null);
      messenger.setMockMethodCallHandler(builtin, null);
    });
    messenger.setMockMethodCallHandler(voice, (call) async {
      methods.add(call.method);
      return {'availableStorageBytes': 42};
    });
    messenger.setMockMethodCallHandler(builtin, (call) async {
      methods.add(call.method);
      return {
        'runtimeBytes': 80,
        'projectsBytes': 20,
        'measuredAtMilliseconds': 123,
      };
    });
    final result = await PhoneStorageService().read(includeBuiltinHost: true);
    expect(result.availableBytes, 42);
    expect(result.builtinHost?.runtimeBytes, 80);
    expect(result.builtinHost?.projectsBytes, 20);
    expect(methods, ['getDeviceInfo', 'projectStorage']);
  });
}
