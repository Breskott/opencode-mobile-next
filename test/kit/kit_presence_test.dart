// KitPresence: a part that fades in and out with its slot, and is not built
// at all while hidden.
import 'package:flutter/material.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

Widget _part({required bool show}) => Row(
  children: [KitPresence(show: show, child: const Text('Collapse'))],
);

void main() {
  kitMotionStillTests(
    'KitPresence',
    builds: {
      'shown': () => _part(show: true),
      'hidden': () => _part(show: false),
    },
    changes: {
      'comes in': KitMotionChange(
        build: () => _part(show: false),
        act: (tester, stage) => stage.rebuild(_part(show: true)),
        shows: 'Collapse',
      ),
      'goes out': KitMotionChange(
        build: () => _part(show: true),
        act: (tester, stage) => stage.rebuild(_part(show: false)),
        hides: 'Collapse',
      ),
    },
  );
}
