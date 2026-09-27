import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

void main() {
  setUp(
    () => debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop(),
  );
  tearDown(() => debugPlatformCapabilities = null);
  Widget region() => KitContextRegion(
    menu: () => [KitMenuItem(label: 'Copy address', onSelected: () {})],
    child: const SizedBox(
      width: 200,
      height: 60,
      child: Text('Computer address'),
    ),
  );
  kitMotionStillTests(
    'KitContextRegion',
    builds: {'idle': region},
    changes: {
      'menu opens': KitMotionChange(
        build: region,
        act: (tester, stage) async {
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(KitContextRegion)),
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          );
          await gesture.up();
        },
        shows: 'Copy address',
      ),
    },
  );
}
