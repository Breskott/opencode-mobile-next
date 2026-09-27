import 'package:flutter/material.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

class _ScrollSample extends StatefulWidget {
  const _ScrollSample({this.own = false, this.horizontal = false});
  final bool own;
  final bool horizontal;

  @override
  State<_ScrollSample> createState() => _ScrollSampleState();
}

class _ScrollSampleState extends State<_ScrollSample> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final axis = widget.horizontal ? Axis.horizontal : Axis.vertical;
    final child = ListView(
      controller: _controller,
      scrollDirection: axis,
      children: [
        for (var i = 0; i < 30; i++)
          SizedBox(width: 160, height: 60, child: Text('Log line $i')),
      ],
    );
    return SizedBox(
      height: 300,
      child: widget.own
          ? KitOwnScrollbar(child: child)
          : KitScrollbar(controller: _controller, axis: axis, child: child),
    );
  }
}

void main() {
  kitMotionStillTests(
    'KitScrollbar',
    builds: {
      'vertical log': () => const _ScrollSample(),
      'horizontal log': () => const _ScrollSample(horizontal: true),
    },
  );
  kitMotionStillTests(
    'KitOwnScrollbar',
    builds: {'owned log': () => const _ScrollSample(own: true)},
  );
  Widget area(String first) => SizedBox(
    height: 300,
    child: KitScrollArea(
      builder: (controller) => ListView(
        controller: controller,
        children: [
          Text(first),
          for (var i = 0; i < 30; i++) Text('Log line $i'),
        ],
      ),
    ),
  );
  kitMotionStillTests(
    'KitScrollArea',
    builds: {'long log': () => area('Starting')},
    changes: {
      'log updates': KitMotionChange(
        build: () => area('Starting'),
        act: (tester, stage) => stage.rebuild(area('Connected')),
        shows: 'Connected',
      ),
    },
  );
}
