// Sample conversations for the chat use-cases: invented, about a fictional
// "shopfront" project. Nothing private.
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';

import '../fakes/fake_gateway.dart';

const chatSessionID = 'ses_checkout';

/// A small picture (a shop front under a sun) as a data URL.
const _pictureUrl =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAPAAAACWCAIAAABvmpKCAAAFi0lEQVR42u3SV26eVRSF4TWcAKG3AKFD6BA6OE5vTnPvPe699x63OIyEETAYrvgki+P/Mkq89zk6eaVnAmvp1Ymyv4Bs6ETZIyAbeu7cIyAbev7cAZANvVB+AGRDJ8sPgGzo5PmHQDb04vmHQDb00oV9IBt6+cI+kA29cnEfyEYR9B6QDb16aQ/Ihl67tAtkQ69f3gWyoTeu7ALZKILeAbKhN6/uANnQW1e3gWzo7WvbQDZ06to2kA2duv4gcf/+U/Y40h8CB3rn+oNkPWbKpVKeAwd698ZWgp4g5VJpjoIDvXdjKzVPWfOhBHfBgU7f3ErHsaRcKql1cFAEvZmIY6/5/6Y38ezQ+xWbKTCq+VAiG+FAH1RspMA06EQ2woE+vLURnWnNh1KYCQf66PZGXA41H4q+FA6KoNfjcgx6HdnTx3fWI3Kr+VDcsXCgT+6sReQcdNyxcKBP767F4lzzoYh74UCf3V2LJUrQEffCgT67txpLnKDj7YUDfX5vNZYoQUfcCwc6U7kSS5SgI+6FA31RuRJLlKAj7oUDfVm1EkuUoCPuhYMi6OVYIgW9jIzpq+rlWKIEHXEvHOjr6qVYogQdcS8c6JuapViiBB1xLxzo29qlWKIEHXEvHBRBL8YSKehFZEzf1S1G5Fxz3LFwoO/rFiJyDjruWDjQD/ULcbnVHH0pHOhs/UJcbkFHXwoHOtswH51HzQnMhAP92DCfAtOaE9kIB/qpcS4FpkEnshEO9HPjXCKMak5nIBzol6a5dBx7zUmtg4Mi6NnUHFPKs3gG6dfm2QQ9Zc1pjoID/dY8k6wnSDnlOXCg31tmEveYKac/BA70R+sMkI0i6GkgG/qzbRrIhsrapoBs6Fz7FJANlbdPAdlQecckkA2d75gEsqELnRNANnSxcwLIhi51TQDZKIIeh4+/y87gkN3Jutw9Dh90HNidrCvdY/BBx4Hdybp6fww+6DiwO1nXesbgg44Du5OLoEfhg45LgrY6Wdd7R+GDjgO7k3WjdwQ+6DiwO1k3+0bgg44Du5NV0TcCH3Qc2J2siv5h+KDjo6DNTtat/mH4oOPA7mTdHhiCDzoO7E7WnYEh+KDjwO5k3R0cgg86DuxOLoIehA86Lgna6mTdGxqEDzoO7E5W5dAAfNBxYHeyqoYH4IOOA7uTVT0yAB90HNidXATdDx90XBK01cmqGe2HDzoO7E5W7WgffNBxYHey6sb64IOOA7uTVT/WBx90HNidrPrxXvig46OgzU5Ww3gvfNBxYHeyGid64IOOA7uT1TTRAx90HNidrObJHvig48Du5CLo+/Bh18fpEycsWAZtdbJapu7DB0EHdierdaobPgg6sDtZbdPd8EHQgd3Jap/phg+CDuxOLoLugg+CLgna6mR1zHbBB0EHdierc7YTPgg6sDtZXXOd8EHQgd3J6p7rhA+CDuxOVvd8B3wQ9FHQZifr/nwHfBB0YHeyehba4YOgA7uT1bvQDh8EHdidrL7Fdvgg6MDu5CLoNvgg6JKgrU5W/1IbfBB0YHeyBpZa4YOgA7uTNbjcCh8EHdidrKGVVvgg6MDu5CLoFvgg6JKgrU7W8GoLfBB0YHeyRlab4YOgA7uTNbrWDB8EHdidrLG1Zvgg6MDuZI2tN8EHQR8FbXayxteb4IOgA7uTNbHRCB8EHdidrMmNRvgg6MDuZE1tNsIHQQd2JxdBN8AHQZcEbXWyprca4IOgA7uTNbNVDx8EHdidrNkH9fBB0IHdyZrbrocPgg7sTi6CroMPgi4J2upkze/UwQdBB3Yna2GnFj4IOrA7WYu7tfBB0IHdyVrarQWyoaW9GiAbWt6rAbKhlf1qIBta3a8GsqG1h9VANoqgq4BsaP2gCsiGNg4qgWxo81ElkI3/ANUDPjNnkMUIAAAAAElFTkSuQmCC';

int _ago(Duration d) =>
    DateTime.now().millisecondsSinceEpoch - d.inMilliseconds;

MessageInfo _info(
  String id,
  String role, {
  required Duration ago,
  Duration? took,
  String? errorText,
  MessageErrorKind? errorKind,
  String? parentID,
}) {
  final created = _ago(ago);
  return MessageInfo(
    id: id,
    sessionID: chatSessionID,
    role: role,
    providerID: role == 'assistant' ? 'anthropic' : null,
    modelID: role == 'assistant' ? 'claude-sonnet-4' : null,
    cost: role == 'assistant' ? 0.07 : 0,
    tokens: role == 'assistant'
        ? Tokens(input: 6420, output: 812, cacheRead: 3100)
        : Tokens(),
    time: MsgTime(
      created: created,
      completed: took == null ? null : created + took.inMilliseconds,
    ),
    errorText: errorText,
    errorKind: errorKind,
    parentID: parentID,
  );
}

Part textPart(String messageID, String id, String text) =>
    Part(id: id, messageID: messageID, type: 'text', text: text);

/// The person's message.
MessageWithParts userTurn(
  String id,
  String text, {
  Duration ago = const Duration(minutes: 2),
  List<Part> extra = const [],
}) => MessageWithParts(
  info: _info(id, 'user', ago: ago, took: Duration.zero),
  parts: [textPart(id, '${id}_text', text), ...extra],
);

/// The agent's reply. Without [took] the reply is still running.
MessageWithParts agentTurn(
  String id,
  List<Part> Function(String messageID) parts, {
  Duration ago = const Duration(minutes: 2),
  Duration? took = const Duration(seconds: 40),
  String? parentID,
  String? errorText,
  MessageErrorKind? errorKind,
}) => MessageWithParts(
  info: _info(
    id,
    'assistant',
    ago: ago,
    took: took,
    errorText: errorText,
    errorKind: errorKind,
    parentID: parentID,
  ),
  parts: parts(id),
);

Part reasoningPart(String messageID, String text) => Part(
  id: '${messageID}_think',
  messageID: messageID,
  type: 'reasoning',
  text: text,
);

Part picturePart(String messageID) => Part(
  id: '${messageID}_picture',
  messageID: messageID,
  type: 'file',
  mime: 'image/png',
  filename: 'checkout-screen.png',
  url: _pictureUrl,
);

Part readPart(String messageID, int n, String path) => Part(
  id: '${messageID}_read$n',
  messageID: messageID,
  type: 'tool',
  callID: '${messageID}_read$n',
  toolName: 'read',
  toolState: ToolState(
    status: 'completed',
    input: {'filePath': '$fakeProjectDirectory/$path'},
    output: '<file>\n...\n</file>',
    metadata: const {
      'display': {'lineStart': 1, 'lineEnd': 120},
    },
  ),
);

const _editPatch =
    '--- a/test/checkout_test.dart\n'
    '+++ b/test/checkout_test.dart\n'
    '@@ -12,7 +12,10 @@ void main() {\n'
    "   test('applies a coupon to the total', () async {\n"
    '-    final bloc = CheckoutBloc();\n'
    '+    final bloc = CheckoutBloc(clock: FakeClock());\n'
    "     bloc.add(ApplyCoupon('SAVE10'));\n"
    '-    await Future<void>.delayed(const Duration(seconds: 1));\n'
    '+    await bloc.stream.firstWhere((s) => s.total < 100);\n'
    '     expect(bloc.state.total, 90);\n';

Part editPart(String messageID) => Part(
  id: '${messageID}_edit',
  messageID: messageID,
  type: 'tool',
  callID: '${messageID}_edit',
  toolName: 'edit',
  toolState: ToolState(
    status: 'completed',
    input: const {'filePath': '$fakeProjectDirectory/test/checkout_test.dart'},
    output: 'Edited test/checkout_test.dart',
    metadata: const {
      'filediff': {'patch': _editPatch, 'additions': 3, 'deletions': 2},
    },
  ),
);

const checkoutCommand = 'flutter test test/checkout_test.dart';

Part shellPart(String messageID, {String status = 'completed'}) => Part(
  id: '${messageID}_bash',
  messageID: messageID,
  type: 'tool',
  callID: '${messageID}_bash',
  toolName: 'bash',
  toolState: ToolState(
    status: status,
    input: const {
      'command': checkoutCommand,
      'description': 'Run the checkout tests',
    },
    output: status == 'completed'
        ? '00:03 +0: applies a coupon to the total\n'
              '00:04 +1: keeps the total when the coupon is invalid\n'
              '00:06 +12: All tests passed!'
        : null,
    metadata: status == 'completed' ? const {'exit': 0} : null,
  ),
);

/// A long answer with a code block, as the agent writes them.
const longCodeAnswer = r'''
The test was racing the bloc: it waited one second and hoped the total had
changed. Waiting for the state itself removes the race.

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shopfront/checkout/checkout_bloc.dart';
import 'package:shopfront/checkout/checkout_event.dart';
import 'package:shopfront/checkout/checkout_state.dart';

void main() {
  group('CheckoutBloc coupons', () {
    late CheckoutBloc bloc;

    setUp(() {
      bloc = CheckoutBloc(clock: FakeClock(), cart: FakeCart(total: 100));
    });

    tearDown(() => bloc.close());

    test('applies a coupon to the total', () async {
      bloc.add(const ApplyCoupon('SAVE10'));
      final state = await bloc.stream.firstWhere((s) => s.total < 100);
      expect(state.total, 90);
      expect(state.coupon, 'SAVE10');
    });

    test('keeps the total when the coupon is invalid', () async {
      bloc.add(const ApplyCoupon('NOPE'));
      final state = await bloc.stream.firstWhere((s) => s.couponError != null);
      expect(state.total, 100);
      expect(state.couponError, 'That code is not valid.');
    });

    test('clears the cart after payment', () async {
      bloc.add(const PayNow());
      await bloc.stream.firstWhere((s) => s.status == CheckoutStatus.paid);
      expect(bloc.cart.items, isEmpty);
    });
  });
}
```

Run it with `flutter test test/checkout_test.dart`; it no longer depends on
timing, so it should stay green on a slow machine too.
''';

const shortAnswer =
    'A bloc is a small object that turns events into states. In this app '
    'the checkout bloc takes "apply coupon" and "pay now" events and emits '
    'the new total. Screens only listen to the states.';

/// Fills a server with one conversation, [chatSessionID].
FakeServer serverWith(
  List<MessageWithParts> messages, {
  String title = 'Fix flaky checkout test',
  bool busy = false,
  List<PermissionRequest> permissions = const [],
  List<PendingQuestion> questions = const [],
  ServerCapabilities? capabilities,
}) => FakeServer(
  sessions: {chatSessionID: fakeSession(chatSessionID, title, cost: 0.42)},
  messages: {chatSessionID: messages},
  busy: {if (busy) chatSessionID},
  permissions: permissions,
  questions: questions,
  capabilities: capabilities ?? ServerCapabilities.allV1,
);

/// The agent's task list: [done] of six finished, the next one in progress.
Part todoPart(String messageID, {int done = 5}) {
  const tasks = [
    'Find raw colours in the player',
    'Move them into OverlayColors',
    'Fix the two raw text fields',
    'Update the TV focus tests',
    'Remove the legacy cap from the design test',
    'Run the tests',
  ];
  return Part(
    id: '${messageID}_todo',
    messageID: messageID,
    type: 'tool',
    callID: '${messageID}_todo',
    toolName: 'todowrite',
    toolState: ToolState(
      status: 'completed',
      input: {
        'todos': [
          for (var i = 0; i < tasks.length; i++)
            {
              'content': tasks[i],
              'status': i < done
                  ? 'completed'
                  : i == done
                  ? 'in_progress'
                  : 'pending',
            },
        ],
      },
      output: '',
    ),
  );
}
