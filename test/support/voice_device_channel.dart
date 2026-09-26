import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers the `oc/voice` device probe at once, with an empty reading.
///
/// Phone setup's first screen reads the CPU, RAM and free space before its
/// button downloads anything (P0.8, `PhoneSetupStartScreen._probeDevice`,
/// through `AndroidVoiceDevicePlatform.getDeviceInfo`). A test that reaches
/// that screen through a real route has no `deviceProbe` to pass, and an
/// unanswered channel leaves the probe's five-second timeout pending past
/// the test's teardown. An empty reading is "unknown", which the pre-flight
/// never blocks on (`checkSetupPreflight`), so the screen reads as it did
/// before the probe existed.
///
/// Call it from `setUp` or a test body; the mock is removed when the test
/// ends.
void answerVoiceDeviceProbe() {
  const channel = MethodChannel('oc/voice');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'getDeviceInfo') return <String, Object?>{};
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
}
