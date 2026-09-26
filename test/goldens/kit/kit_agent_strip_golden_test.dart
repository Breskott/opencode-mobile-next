// Gallery (gate G4) for KitAgentStrip, docs/ux-system/kit-api/KitAgentStrip.md.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_agent_strip_golden_test.dart
// and look at every changed image before committing it.
//
// Owner decision 2026-09-27 (dated later than KitAgentStrip.md, R15): Arabic
// is dropped — no Arabic/RTL galleries; galleries are phone 412x915 and one
// wide size 1280x800 only, light and dark. This replaces the spec's own
// "Galleries required" list (360x800/800x1280/915x412/1600x1000, text 2.0
// and Arabic RTL), a PROC-20 note recorded in the unit's QA record.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/chat/kit_agent_strip.dart';
import 'package:opencode_mobile/ui/kit/kit_task_mark.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import 'kit_gallery.dart';

const _sizes = [Size(412, 915), Size(1280, 800)];

void _noop() {}

/// A KitTopBar-height header standing in for the team conversation's own,
/// with the strip under it as the host arranges it.
Widget _scene(List<KitAgent> agents) => Builder(
  builder: (context) {
    final tokens = KitTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: tokens.navHeight,
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: tokens.gutter),
            child: const Align(
              alignment: AlignmentDirectional.centerStart,
              child: KitText('Fix the login redirect', role: KitTextRole.title),
            ),
          ),
        ),
        KitAgentStrip(agents: agents),
      ],
    );
  },
);

const _lead = KitAgent(
  id: 'lead',
  name: 'mayor',
  role: 'Lead',
  state: KitTaskState.working,
);

final _states = <String, List<KitAgent>>{
  'mixed': [
    _lead,
    const KitAgent(
      id: 'w1',
      name: 'furiosa',
      role: 'Worker',
      state: KitTaskState.waiting,
      onOpen: _noop,
    ),
    const KitAgent(
      id: 'r1',
      name: 'nux',
      role: 'Reviewer',
      state: KitTaskState.done,
      onOpen: _noop,
    ),
  ],
  'needs_you': [
    _lead,
    const KitAgent(
      id: 'w1',
      name: 'furiosa',
      role: 'Worker',
      state: KitTaskState.needsYou,
      onOpen: _noop,
    ),
    const KitAgent(
      id: 'w2',
      name: 'capable',
      role: 'Worker',
      state: KitTaskState.working,
      onOpen: _noop,
    ),
  ],
  'paused': [
    const KitAgent(
      id: 'lead',
      name: 'mayor',
      role: 'Lead',
      state: KitTaskState.working,
      paused: true,
    ),
    const KitAgent(
      id: 'w1',
      name: 'furiosa',
      role: 'Worker',
      state: KitTaskState.waiting,
      paused: true,
      onOpen: _noop,
    ),
  ],
  'done': [
    const KitAgent(
      id: 'lead',
      name: 'mayor',
      role: 'Lead',
      state: KitTaskState.done,
    ),
    const KitAgent(
      id: 'w1',
      name: 'furiosa',
      role: 'Worker',
      state: KitTaskState.done,
      onOpen: _noop,
    ),
    const KitAgent(
      id: 'r1',
      name: 'nux',
      role: 'Reviewer',
      state: KitTaskState.done,
      onOpen: _noop,
    ),
  ],
  'lead_only': [_lead],
  'overflow': [
    _lead,
    for (final (i, n) in const [
      'furiosa',
      'nux',
      'capable',
      'toast',
      'dag',
      'cheedo',
      'slit',
    ].indexed)
      KitAgent(
        id: n,
        name: n,
        role: i == 6 ? 'Reviewer' : 'Worker',
        state: KitTaskState.values[i % KitTaskState.values.length],
        onOpen: _noop,
      ),
  ],
};

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final MapEntry(key: state, value: agents) in _states.entries) {
    for (final size in _sizes) {
      for (final light in const [false, true]) {
        final name = kitGalleryName(
          'kit_agent_strip_$state',
          size,
          light: light,
        );
        testWidgets(name, (tester) async {
          await kitGalleryPart(
            tester,
            name: name,
            size: size,
            light: light,
            child: _scene(agents),
          );
        });
      }
    }
  }
}
