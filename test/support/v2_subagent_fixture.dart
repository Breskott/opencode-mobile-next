import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api2/gateway_mappers.dart';
import 'package:opencode_mobile/api2/models.dart';

// Wire-shaped beta18600 fixtures: plugin subagent Input, context.progress and
// returned content/metadata. The output text is synthetic; shape is published.
ToolState v2SubagentState({
  String status = 'completed',
  String childStatus = 'running',
  bool background = true,
  bool executed = true,
}) => mapApi2ToolState(
  Api2ToolState.fromJson({
    'status': status,
    'input': {
      'agent': 'explore',
      'description': 'Inspect checkout validation',
      'prompt':
          'Find the checkout validation rules and report the relevant files.',
      if (background) 'background': true,
    },
    'metadata': {'sessionID': 'ses_child_v2', 'status': childStatus},
    if (status == 'completed')
      'content': [
        {
          'type': 'text',
          'text': childStatus == 'running'
              ? 'The subagent is working in the background (sessionID: ses_child_v2). You will be notified automatically when it finishes.\nDO NOT sleep, poll for progress, ask the subagent for status, or duplicate this subagent\'s work; avoid working with the same files or topics it is using.\nWork on non-overlapping tasks, or briefly tell the user what you launched and end your response.'
              : '<subagent sessionID="ses_child_v2" state="completed">\nValidation lives in checkout.dart.\n</subagent>',
        },
      ],
    if (status == 'error')
      'error': {'message': 'Subagent cancelled (sessionID: ses_child_v2)'},
  }),
  toolName: 'subagent',
  executed: executed,
);
