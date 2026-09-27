// Fixtures shared by screen-usage-2's behaviour tests and goldens: a saved
// server that can read the quota collector (HTTPS and a password), a
// collector gateway that answers with a synthetic Codex snapshot, and a
// usage repository. Synthetic only; nothing reaches a server.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/domain/provider_quota.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/provider_quota_overview.dart';
import 'package:opencode_mobile/state/usage_overview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../provider_quota_test.dart' show providerQuotaFixture;

const quotaProfileId = 'usage-2-profile';
const quotaOrigin = 'https://collector.example:8443';

/// A synthetic Codex snapshot fetched at [at]: a 5-hour primary window at
/// [usedPercent] used (resetting five minutes later) and a secondary window
/// the collector did not report.
ProviderQuotaSnapshot quotaSnapshot(DateTime at, {double usedPercent = 25.5}) {
  final value =
      jsonDecode(
            jsonEncode(
              providerQuotaFixture(fetchedAtMs: at.millisecondsSinceEpoch),
            ),
          )
          as Map<String, dynamic>;
  ((value['windows'] as List).first as Map<String, dynamic>)['usedPercent'] =
      usedPercent;
  return ProviderQuotaSnapshot.fromJson(value);
}

class QuotaGateway implements ProviderQuotaGateway {
  QuotaGateway(this.answer);
  final ProviderQuotaSnapshot Function() answer;
  int reads = 0;

  @override
  Future<ProviderQuotaSnapshot> readSnapshot() async {
    reads++;
    return answer();
  }

  @override
  void close() {}
}

class _Api extends OpenCodeApi {
  _Api() : super(baseUrl: quotaOrigin);
  @override
  Future<Health> health() async => Health(healthy: true, version: 'fixture');
}

class _Repository extends ProductRepository implements UsageStatisticsGateway {
  @override
  bool get usageStatisticsSupported => true;
  @override
  Future<WorkspaceProject?> loadCurrentProject() async => null;
  @override
  Future<UsageStatistics> loadUsageStatistics(UsageQuery query) async =>
      UsageStatistics.fromJson(
        (jsonDecode(
              File('test/fixtures/api2/session_stats.json').readAsStringSync(),
            )
            as Map<String, dynamic>)['data'],
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class QuotaConnection extends ConnectionController {
  QuotaConnection(super.store);
  @override
  Future<ServerOperationsGateway?> prepareActionRepository() async =>
      repository;
  @override
  Future<ServerGateway?> prepareActionTransport() async => api;
}

/// Secure storage kept in memory for the test (AGENTS.md: a test touching
/// ProfileStore.upsert must mock the channel or it hangs).
void mockQuotaSecureStorage() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final values = <String, String>{};
  messenger.setMockMethodCallHandler(channel, (call) async {
    final arguments = call.arguments as Map;
    final key = arguments['key'] as String?;
    switch (call.method) {
      case 'read':
        return values[key];
      case 'write':
        values[key!] = arguments['value'] as String;
      case 'delete':
        values.remove(key);
    }
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
}

typedef QuotaHarness = ({
  QuotaConnection connection,
  ProviderQuotaOverview quota,
  UsageOverview usage,
  List<QuotaGateway> gateways,
});

/// A saved HTTPS server with a password (so the collector may be read), a
/// quota overview whose reads answer [snapshot] and a usage overview.
Future<QuotaHarness> quotaHarness({
  required DateTime Function() clock,
  required ProviderQuotaSnapshot Function() snapshot,
  bool statistics = true,
}) async {
  mockQuotaSecureStorage();
  SharedPreferences.setMockInitialValues({});
  final store = ProfileStore(prefs: await SharedPreferences.getInstance());
  await store.upsert(
    ServerProfile(
      id: quotaProfileId,
      name: 'Studio',
      baseUrl: quotaOrigin,
      username: 'fixture-user',
      password: 'fixture-only-usage-2-password',
    ),
  );
  await store.setActiveId(quotaProfileId);
  final connection = QuotaConnection(store)
    ..api = _Api()
    ..repository = statistics ? _Repository() : null
    ..status = StreamStatus.connected;
  final gateways = <QuotaGateway>[];
  final quota = ProviderQuotaOverview(
    connection,
    clock: clock,
    gatewayFactory: (_) {
      final gateway = QuotaGateway(snapshot);
      gateways.add(gateway);
      return gateway;
    },
  );
  final usage = UsageOverview(
    connection,
    clock: clock,
    timezoneLoader: () async => 'Asia/Dubai',
  );
  return (
    connection: connection,
    quota: quota,
    usage: usage,
    gateways: gateways,
  );
}

/// Releases what [quotaHarness] made, after the widgets are gone.
void disposeQuotaHarness(QuotaHarness h) {
  h.quota.dispose();
  h.usage.dispose();
  h.connection.quotaMonitor.dispose();
  h.connection.dispose();
}

/// Holds [child] and releases the harness when the tree is torn down,
/// before the binding checks for pending timers (addTearDown runs after
/// that check; the overview and the monitor keep expiry timers).
class QuotaHarnessOwner extends StatefulWidget {
  const QuotaHarnessOwner({
    super.key,
    required this.harness,
    required this.child,
  });

  final QuotaHarness harness;
  final Widget child;

  @override
  State<QuotaHarnessOwner> createState() => _QuotaHarnessOwnerState();
}

class _QuotaHarnessOwnerState extends State<QuotaHarnessOwner> {
  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    disposeQuotaHarness(widget.harness);
    super.dispose();
  }
}
