import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api extends OpenCodeApi {
  _Api(this.statuses) : super(baseUrl: 'http://localhost');
  final Map<String, String> statuses;

  @override
  Future<Map<String, String>> sessionStatuses() async => statuses;
}

class _Repository implements ServerOperationsGateway {
  _Repository(this.results);
  final List<GlobalSessionResult> results;

  @override
  Future<ServerPage<GlobalSessionResult>> listGlobalSessions({
    String? search,
    bool includeArchived = false,
    String? cursor,
    int limit = 50,
  }) async => ServerPage(items: results);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GlobalSessionResult _result(
  String id,
  String directory, {
  int updated = 0,
  String? parent,
}) => GlobalSessionResult(
  session: Session(
    id: id,
    title: id,
    directory: directory,
    parentID: parent,
    time: SessionTime(created: 0, updated: updated),
  ),
  projectDirectory: directory,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('conversations elsewhere: other projects only, running first, then '
      'most recent; subagents left out', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = ConnectionController(ProfileStore(prefs: prefs))
      ..api = _Api({'busy-old': 'busy', 'here-busy': 'busy'})
      ..repository = _Repository([
        _result('here-busy', '/work/app', updated: 99),
        _result('idle-new', '/work/site', updated: 50),
        _result('busy-old', '/work/FinanceHub3', updated: 1),
        _result('idle-old', '/work/site', updated: 10),
        _result('child', '/work/site', updated: 80, parent: 'idle-new'),
      ])
      ..status = StreamStatus.connected
      ..directory = '/work/app';
    addTearDown(controller.dispose);

    final found = await controller.conversationsElsewhere();
    expect(found.map((c) => c.session.id), [
      'busy-old',
      'idle-new',
      'idle-old',
    ]);
    expect(found.first.running, isTrue);
    expect(found.first.project, 'FinanceHub3');
    expect(found[1].running, isFalse);
  });
}
