// Pure thresholds for P0.8's pre-flight (lib/builtin/setup/preflight.dart):
// CPU ABI, total RAM and free space, checked before phone setup downloads
// anything. See test/phone_setup_start_screen_test.dart's "P0.8 pre-flight"
// group and test/phone_setup_customize_sheet_test.dart for the UI these
// thresholds drive.

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/setup/preflight.dart';
import 'package:opencode_mobile/voice/device.dart';

const _download = 165000000; // 165 MB, the default registry's total.

VoiceDeviceInfo _device({
  List<String> abis = const ['arm64-v8a'],
  int? memoryMb = 4096,
  int? availableBytes = 2000000000,
}) => VoiceDeviceInfo(
  availableStorageBytes: availableBytes,
  memoryClassMb: 256,
  totalMemoryMb: memoryMb,
  supportedAbis: abis,
  hasMicrophone: false,
);

void main() {
  group('requiredSetupFreeBytes', () {
    test('is twice the download size once that clears the floor', () {
      expect(requiredSetupFreeBytes(_download), 330000000);
      expect(requiredSetupFreeBytes(500 * 1000 * 1000), 1000 * 1000 * 1000);
    });

    test('never drops below the floor for a tiny or zero download', () {
      expect(requiredSetupFreeBytes(0), 300 * 1000 * 1000);
      expect(requiredSetupFreeBytes(1000), 300 * 1000 * 1000);
    });
  });

  group('checkSetupPreflight', () {
    test('passes a supported, roomy, well-remembered phone', () {
      final result = checkSetupPreflight(_device(), downloadBytes: _download);
      expect(result.supported, isTrue);
      expect(result.issue, isNull);
    });

    test('blocks a 32-bit-only ABI, reporting the CPU it found', () {
      final result = checkSetupPreflight(
        _device(abis: ['armeabi-v7a']),
        downloadBytes: _download,
      );
      expect(result.issue, SetupPreflightIssue.unsupportedAbi);
      expect(result.reportedAbi, 'armeabi-v7a');
    });

    test('an x86_64 device passes: the rootfs ships for it too', () {
      final result = checkSetupPreflight(
        _device(abis: ['x86_64']),
        downloadBytes: _download,
      );
      expect(result.supported, isTrue);
    });

    test('an unknown (empty) ABI list never blocks', () {
      final result = checkSetupPreflight(
        _device(abis: const []),
        downloadBytes: _download,
      );
      expect(result.supported, isTrue);
    });

    test('blocks under the memory floor, naming both numbers', () {
      final result = checkSetupPreflight(
        _device(memoryMb: 1024),
        downloadBytes: _download,
      );
      expect(result.issue, SetupPreflightIssue.lowMemory);
      expect(result.totalMemoryMb, 1024);
    });

    test('exactly at the memory floor passes', () {
      final result = checkSetupPreflight(
        _device(memoryMb: minimumSetupMemoryMb),
        downloadBytes: _download,
      );
      expect(result.supported, isTrue);
    });

    test('an unknown (null) memory reading never blocks', () {
      final result = checkSetupPreflight(
        _device(memoryMb: null),
        downloadBytes: _download,
      );
      expect(result.supported, isTrue);
    });

    test('blocks low space, naming exactly how many bytes to free', () {
      final result = checkSetupPreflight(
        _device(availableBytes: 100000000),
        downloadBytes: _download,
      );
      expect(result.issue, SetupPreflightIssue.lowSpace);
      // Needs 330 MB (2x download), has 100 MB: 230 MB short.
      expect(result.bytesToFree, 230000000);
    });

    test('exactly the required space passes', () {
      final result = checkSetupPreflight(
        _device(availableBytes: requiredSetupFreeBytes(_download)),
        downloadBytes: _download,
      );
      expect(result.supported, isTrue);
    });

    test('an unknown (null) storage reading never blocks', () {
      final result = checkSetupPreflight(
        _device(availableBytes: null),
        downloadBytes: _download,
      );
      expect(result.supported, isTrue);
    });

    test('ABI is checked before memory or space: nothing else matters '
        'without a rootfs', () {
      final result = checkSetupPreflight(
        _device(abis: ['armeabi-v7a'], memoryMb: 512, availableBytes: 0),
        downloadBytes: _download,
      );
      expect(result.issue, SetupPreflightIssue.unsupportedAbi);
    });
  });
}
