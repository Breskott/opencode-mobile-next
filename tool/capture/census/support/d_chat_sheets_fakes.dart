// Fakes and sample data for the `d-chat-sheets` census scenes: a chat API
// with one page of history, todos and an optional forms capability, a
// longer "shopfront" transcript, and on-device voice stand-ins (no
// microphone, no model download).
import 'dart:async';
import 'dart:typed_data';

import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/voice/audio.dart';
import 'package:opencode_mobile/voice/controller.dart';
import 'package:opencode_mobile/voice/model_download.dart';
import 'package:opencode_mobile/voice/model_manager.dart';
import 'package:opencode_mobile/voice/model_manifest.dart';
import 'package:opencode_mobile/voice/recognizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures.dart';

// ---------------------------------------------------------------------------
// Chat API
// ---------------------------------------------------------------------------

/// The capture API with one page of history, a todo list and, when [forms]
/// is set, the OpenCode 2 forms capability.
class DChatApi extends CaptureApi {
  DChatApi({this.transcript = const [], this.todoList = const [], this.forms})
    : super() {
    messagesHandler = (_) async => transcript;
  }

  List<MessageWithParts> transcript;
  List<Todo> todoList;
  final bool? forms;

  @override
  ServerCapabilities get capabilities => forms == true
      ? const ServerCapabilities(clientPromptMessageID: true, forms: true)
      : super.capabilities;

  @override
  Future<ServerPage<MessageWithParts>> messagePage(
    String id, {
    String? cursor,
    int limit = 100,
  }) async => ServerPage(items: cursor == null ? await messages(id) : const []);

  @override
  Future<List<Todo>> todos(String id) async => todoList;
}

// ---------------------------------------------------------------------------
// Transcripts
// ---------------------------------------------------------------------------

int get _now => DateTime.now().millisecondsSinceEpoch;

MessageWithParts dUser(String id, String text, {required int agoSeconds}) =>
    MessageWithParts(
      info: messageInfo(
        id,
        'user',
        created: _now - agoSeconds * 1000,
        completed: _now - agoSeconds * 1000,
      ),
      parts: [Part(id: 'p_$id', messageID: id, type: 'text', text: text)],
    );

MessageWithParts dAssistant(
  String id,
  List<Part> parts, {
  required int agoSeconds,
  bool finished = true,
}) => MessageWithParts(
  info: messageInfo(
    id,
    'assistant',
    created: _now - agoSeconds * 1000,
    completed: finished ? _now - (agoSeconds - 20) * 1000 : null,
  ),
  parts: [
    for (final part in parts)
      Part(
        id: part.id,
        messageID: id,
        type: part.type,
        text: part.text,
        callID: part.callID,
        toolName: part.toolName,
        toolState: part.toolState,
      ),
  ],
);

Part dText(String id, String text) => textPart(id, text);

/// A finished turn: the prompt and a short reply.
List<MessageWithParts> dFinishedTurn() => [
  dUser('msg_user', userPrompt, agoSeconds: 95),
  dAssistant('msg_assistant', [
    dText('part_intro', answerIntro),
  ], agoSeconds: 80),
];

/// Four turns of the shopfront session, for the timeline.
List<MessageWithParts> dLongTranscript() => [
  dUser(
    'msg_u1',
    'Why does the checkout test fail on CI but not locally?',
    agoSeconds: 3600,
  ),
  dAssistant('msg_a1', [
    dText(
      'a1',
      'CI runs the suite in parallel, so `CheckoutBloc` races the price '
          'refresh. Locally the refresh wins because the cache is warm.',
    ),
  ], agoSeconds: 3580),
  dUser('msg_u2', userPrompt, agoSeconds: 2400),
  dAssistant('msg_a2', [
    dText('a2', answerIntro),
    shellPart(),
  ], agoSeconds: 2380),
  dUser('msg_u3', 'Add a regression test for the coupon race', agoSeconds: 900),
  dAssistant('msg_a3', [
    dText(
      'a3',
      'Added `applies a coupon while prices refresh` to '
          '`test/checkout_test.dart`. It fails on the old code and passes now.',
    ),
    editPart(),
  ], agoSeconds: 880),
  dUser('msg_u4', 'Run the full test suite', agoSeconds: 120),
  dAssistant('msg_a4', [
    dText(
      'a4',
      'All 214 tests pass. The slowest file is `cart_repository_test.dart` '
          'at 9 s.',
    ),
  ], agoSeconds: 100),
];

/// Markdown the reply renders: heading, list, a link, a file path chip, a
/// table, a code block and a choices block.
const dMarkdownReply =
    '## What changed\n\n'
    'The coupon race is fixed in `lib/checkout/checkout_bloc.dart`: '
    'the bloc now waits for **both** the coupon and the price refresh.\n\n'
    '- Settled state instead of a fixed delay\n'
    '- One source of truth for the total\n'
    '- See the [Bloc docs](https://bloclibrary.dev/testing/) for '
    '`pumpUntil`\n\n'
    '| File | Tests | Result |\n'
    '| --- | :---: | ---: |\n'
    '| `checkout_test.dart` | 12 | pass |\n'
    '| `cart_repository_test.dart` | 8 | pass |\n\n'
    '```dart\n'
    'final settled = await Future.wait([\n'
    '  _repository.applyCoupon(event.code),\n'
    '  _repository.refreshPrices(state.cart),\n'
    ']);\n'
    'emit(CheckoutSettled(cart: state.cart, total: settled.first));\n'
    '```\n\n'
    'Want me to open a pull request?\n\n'
    '```choices\n'
    'Open a pull request\n'
    'Keep it local for now\n'
    '```';

List<MessageWithParts> dMarkdownTranscript() => [
  dUser('msg_user', 'Summarise the fix', agoSeconds: 60),
  dAssistant('msg_assistant', [
    dText('part_md', dMarkdownReply),
  ], agoSeconds: 50),
];

/// A reply whose single tool call renders as its own card.
List<MessageWithParts> dToolTranscript(Part tool, {bool finished = true}) => [
  dUser('msg_user', userPrompt, agoSeconds: 95),
  dAssistant(
    'msg_assistant',
    [
      dText('part_intro', 'Checking the fix before I report back.'),
      tool,
      if (finished) dText('part_outro', 'All 12 checkout tests pass.'),
    ],
    agoSeconds: 80,
    finished: finished,
  ),
];

// ---------------------------------------------------------------------------
// Voice
// ---------------------------------------------------------------------------

class _NoStore implements VoiceFileStore {
  @override
  Future<void> createDirectory(String path) async {}
  @override
  Future<void> delete(String path) async {}
  @override
  Future<bool> exists(String path) async => false;
  @override
  Future<int> length(String path) async => 0;
  @override
  Future<void> move(String from, String to) async {}
  @override
  Future<VoiceByteSink> openWrite(String path, {required bool append}) =>
      throw UnimplementedError();
  @override
  Stream<List<int>> read(String path) => const Stream.empty();
  @override
  Future<Uint8List> readBytes(String path) async => Uint8List(0);
  @override
  Future<void> writeAtomic(String path, List<int> bytes) async {}
}

class _NoHttp implements VoiceHttpTransport {
  @override
  void close() {}
  @override
  Future<VoiceHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const {},
    VoiceCancellationToken? cancellation,
  }) => throw UnimplementedError();
}

/// A model manager frozen in one state: [installed] packs are on disk.
class DVoiceModels extends VoiceModelManager {
  DVoiceModels(
    SharedPreferences preferences, {
    VoiceModelState state = VoiceModelState.ready,
    this.installed = const {'base'},
    VoiceDownloadProgress? progress,
  }) : super(
         root: '/private/models',
         preferences: preferences,
         downloader: VoiceModelDownloader(store: _NoStore(), http: _NoHttp()),
       ) {
    this.state = state;
    this.progress = progress;
  }

  final Set<String> installed;

  @override
  bool isInstalled(VoiceModelPack pack) => installed.contains(pack.id);

  @override
  bool get isReady =>
      state == VoiceModelState.ready && isInstalled(selectedPack);
}

class DVoiceRecorder implements VoiceRecorder {
  final _events = StreamController<VoiceRecorderEvent>.broadcast();
  @override
  Stream<VoiceRecorderEvent> get events => _events.stream;
  @override
  Future<Stream<Uint8List>> start() async => const Stream.empty();
  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {}
  @override
  Future<void> dispose() async => _events.close();
}

class DVoiceRecognizer implements VoiceRecognizer {
  @override
  Future<VoiceRecognitionHandle> start(
    VoiceRecognitionRequest request, {
    required void Function() onLoaded,
  }) => Completer<VoiceRecognitionHandle>().future;
}

/// What "Start listening" leads to in a scene.
enum DVoiceOutcome { listening, draft, micDenied }

/// A voice controller that never touches a microphone: starting to listen
/// lands directly in [outcome].
class DVoiceController extends VoiceComposerController {
  DVoiceController({
    required super.models,
    this.outcome = DVoiceOutcome.listening,
  }) : super(recorder: DVoiceRecorder(), recognizer: DVoiceRecognizer());

  final DVoiceOutcome outcome;
  bool _gone = false;

  @override
  Future<void> startListening() async {
    switch (outcome) {
      case DVoiceOutcome.listening:
        state = VoiceComposerState.listening;
        elapsed = const Duration(seconds: 7);
        level = .55;
      case DVoiceOutcome.draft:
        state = VoiceComposerState.draft;
        draft =
            'Run the checkout tests again and tell me which ones are still '
            'slow';
      case DVoiceOutcome.micDenied:
        state = VoiceComposerState.error;
        error = const VoicePermissionDenied(permanent: true);
    }
    notifyListeners();
  }

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> cancel({String? reason, bool clearError = false}) async {
    if (_gone) return;
    state = VoiceComposerState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _gone = true;
    super.dispose();
  }
}
