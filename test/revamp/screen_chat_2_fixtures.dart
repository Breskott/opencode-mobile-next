// Fakes shared by screen-chat-2's behaviour tests and goldens: a controller
// with a saved profile (so scope guards pass), an in-memory note, a
// relations repository, an active-context repository and a web search
// gateway.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A controller whose note lives in memory and whose action repository is
/// whatever [repository] holds.
class ChatTwoController extends ConnectionController {
  ChatTwoController(super.store);

  String? note;
  int noteRevision = 0;
  Object? saveFailure;
  final noteWrites = <String?>[];
  final aborted = <String>[];
  ServerGateway? transport;

  @override
  Future<ServerOperationsGateway?> prepareActionRepository() async =>
      repository;

  @override
  Future<ServerGateway?> prepareActionTransport() async => transport;

  @override
  bool isSessionNoteReviewCurrent(SessionNoteReview review) =>
      review.revision == noteRevision;

  @override
  Future<SessionNoteReview> loadSessionNote(String id) async =>
      SessionNoteReview(
        scope: this,
        sessionID: id,
        value: note,
        revision: noteRevision,
      );

  @override
  Future<void> saveSessionNote(SessionNoteReview review, String? value) async {
    if (saveFailure case final failure?) throw failure;
    noteWrites.add(value);
    note = value;
    noteRevision++;
  }
}

Future<ChatTwoController> chatTwoController() async {
  SharedPreferences.setMockInitialValues({
    'oc.profiles': jsonEncode([
      {'id': 'profile', 'name': 'Laptop', 'baseUrl': 'http://localhost'},
    ]),
    'oc.activeProfile': 'profile',
  });
  final preferences = await SharedPreferences.getInstance();
  final store = ProfileStore(prefs: preferences);
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(secure, (_) async => null);
  addTearDown(() => messenger.setMockMethodCallHandler(secure, null));
  await store.load();
  final controller = ChatTwoController(store)
    ..directory = '/srv/shopfront'
    ..workspace = 'laptop'
    ..status = StreamStatus.connected;
  return controller;
}

final relationsParent = Session(
  id: 'parent',
  title: 'Speed up the checkout page',
  directory: '/srv/shopfront',
  workspaceID: 'laptop',
  time: SessionTime(
    created: DateTime.now()
        .subtract(const Duration(hours: 2))
        .millisecondsSinceEpoch,
  ),
);

Session relationsChild(String id, String title, Duration age) => Session(
  id: id,
  title: title,
  parentID: 'parent',
  directory: '/srv/shopfront',
  workspaceID: 'laptop',
  time: SessionTime(
    created: DateTime.now().subtract(age).millisecondsSinceEpoch,
  ),
);

final relationsChildren = [
  relationsChild(
    'child-audit',
    'Audit the image sizes',
    const Duration(minutes: 40),
  ),
  relationsChild(
    'child-tests',
    'Write checkout tests',
    const Duration(minutes: 5),
  ),
  relationsChild(
    'child-cache',
    'Cache the product list',
    const Duration(minutes: 20),
  ),
];

class RelationsRepository implements ProductRepository {
  RelationsRepository({List<Session>? children})
    : children = children ?? relationsChildren;

  final List<Session> children;

  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<Session> getSessionDetails(String id) async {
    if (id == relationsParent.id) return relationsParent;
    return children.firstWhere((session) => session.id == id);
  }

  @override
  Future<List<Session>> listSessionChildren(String id) async => children;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records the abort a stop sends.
class AbortTransport implements ServerGateway {
  AbortTransport(this.controller);
  final ChatTwoController controller;

  @override
  Future<void> abort(String sessionID) async =>
      controller.aborted.add(sessionID);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const contextRows = [
  ActiveContextMessage(
    id: 'msg_01',
    type: 'compaction',
    content: [
      ContextContent(
        ContextContentKind.text,
        'The conversation so far: speed up the checkout page, keep the cart '
        'total exact, and verify the Android build.',
      ),
    ],
  ),
  ActiveContextMessage(
    id: 'msg_02',
    type: 'user',
    content: [
      ContextContent(
        ContextContentKind.text,
        'Profile the checkout page and fix the slowest part.',
      ),
    ],
  ),
  ActiveContextMessage(
    id: 'msg_03',
    type: 'assistant',
    content: [
      ContextContent(
        ContextContentKind.toolOutput,
        'lib/checkout/checkout_page.dart: 412 lines, 3 rebuilds per frame',
        name: 'read',
      ),
      ContextContent(
        ContextContentKind.text,
        'The cart total rebuilds the whole page on every keystroke.',
      ),
    ],
  ),
];

class ContextRepository extends ProductRepository
    implements ActiveContextGateway {
  ContextRepository({this.rows = contextRows});
  List<ActiveContextMessage> rows;

  @override
  bool get activeContextSupported => true;

  @override
  Future<List<ActiveContextMessage>> loadActiveContext(
    String sessionID,
  ) async => rows;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A server with one search provider and a scripted search.
class SearchGateway implements ServerGateway, WebSearchGateway {
  SearchGateway({this.searchProviders = const [defaultProvider], this.results});

  static const defaultProvider = WebSearchProvider(id: 'exa', name: 'Exa');

  final List<WebSearchProvider> searchProviders;
  List<WebSearchResult>? results;
  WebSearchFailureKind? failure;
  int searches = 0;

  @override
  ServerCapabilities get capabilities =>
      const ServerCapabilities(webSearch: true);

  @override
  void close() {}

  @override
  Future<List<WebSearchProvider>> webSearchProviders() async => searchProviders;

  @override
  Future<WebSearchResponse> searchWeb(
    String query, {
    required String providerID,
  }) async {
    searches++;
    if (failure case final kind?) throw WebSearchFailure(kind);
    return WebSearchResponse(providerID: providerID, results: results ?? []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const searchResults = [
  WebSearchResult(
    url: 'https://docs.flutter.dev/testing/overview',
    title: 'Testing Flutter apps',
    content: 'Unit, widget and integration tests, and when to use each.',
  ),
  WebSearchResult(
    url: 'https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html',
    title: 'matchesGoldenFile function',
    content: 'Asserts that a Finder matches the golden image file.',
  ),
];
