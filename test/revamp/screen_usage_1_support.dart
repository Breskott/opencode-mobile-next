// Fixtures shared by screen-usage-1's behaviour tests and goldens: a saved
// server with usage statistics (so budgets are available) and a Codex
// account host. Synthetic only; nothing reaches a server.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/demo/demo_store.dart';
import 'package:opencode_mobile/domain/agent_account.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/usage_overview.dart';

import '../../tool/capture/fixtures.dart' show captureTheme;
import '../support/account_fakes.dart';

final usageNow = DateTime(2026, 9, 5, 12);

final _usageProfile = ServerProfile(
  id: 'usage-fixture',
  name: 'Studio',
  baseUrl: 'https://studio.example',
  username: 'opencode',
);

class _UsageStore extends ProfileStore {
  _UsageStore() : super(prefs: DemoPreferences());
  @override
  List<ServerProfile> get profiles => [_usageProfile];
  @override
  String? get activeId => _usageProfile.id;
}

Map<String, dynamic> _fixture() =>
    (jsonDecode(
          File('test/fixtures/api2/session_stats.json').readAsStringSync(),
        )
        as Map<String, dynamic>)['data'];

Map<String, dynamic> emptyUsage() => {
  'range': {'from': 0, 'to': 0},
  'sessions': 0,
  'subagents': 0,
  'prompts': 0,
  'steps': 0,
  'tokens': {
    'input': 0,
    'output': 0,
    'reasoning': 0,
    'cache': {'read': 0, 'write': 0},
  },
  'cost': 0,
  'tools': {
    'mode': 'summary',
    'totals': {'calls': 0, 'succeeded': 0, 'failed': 0, 'unfinished': 0},
  },
  'activeDays': 0,
  'streak': 0,
  'activity': [],
  'models': [],
};

UsageStatistics usageStats({bool empty = false}) => UsageStatistics.fromJson(
  (empty ? emptyUsage() : _fixture())
    ..['range'] = {
      'from': DateTime(2026, 8, 7).millisecondsSinceEpoch,
      'to': DateTime(2026, 9, 5, 12).millisecondsSinceEpoch + 1,
    },
);

class UsageRepo implements ServerOperationsGateway, UsageStatisticsGateway {
  bool supported = true;
  Object? failure;
  UsageStatistics result = usageStats();
  final queries = <UsageQuery>[];
  @override
  bool get usageStatisticsSupported => supported;
  @override
  Future<UsageStatistics> loadUsageStatistics(UsageQuery query) async {
    queries.add(query);
    if (failure != null) throw failure!;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected operation ${invocation.memberName}');
}

class UsageConnection extends ConnectionController {
  UsageConnection(this.repo) : super(_UsageStore()) {
    repository = repo;
  }
  final UsageRepo repo;
  @override
  Future<ServerOperationsGateway?> prepareActionRepository() async => repo;
}

/// A connection, its repository and an overview on a fixed clock.
({UsageConnection connection, UsageRepo repo, UsageOverview overview})
usageHarness() {
  final repo = UsageRepo();
  final connection = UsageConnection(repo);
  final overview = UsageOverview(
    connection,
    clock: () => usageNow,
    timezoneLoader: () async => 'Asia/Dubai',
  );
  addTearDown(overview.dispose);
  addTearDown(connection.dispose);
  return (connection: connection, repo: repo, overview: overview);
}

// --- Codex account ----------------------------------------------------------

class AccountStore extends ProfileStore {
  AccountStore() : super(prefs: DemoPreferences());
  final saved = ServerProfile(
    id: 'account-fixture',
    name: 'My Codex host',
    baseUrl: 'https://fixture.invalid',
    backend: ServerBackend.codex,
  );
  @override
  List<ServerProfile> get profiles => [saved];
  @override
  String? get activeId => saved.id;
}

class AccountGateway extends OpenCodeApi implements AgentAccountGateway {
  AccountGateway({this.accountEnabled = true, this.prepare})
    : super(baseUrl: 'https://fixture.invalid');
  final bool accountEnabled;
  final void Function(FakeAccountSession session)? prepare;
  final opened = <FakeAccountSession>[];
  @override
  ServerCapabilities get capabilities =>
      ServerCapabilities(agentAccount: accountEnabled);
  @override
  AgentAccountSession openAccountSession() {
    final session = FakeAccountSession();
    prepare?.call(session);
    opened.add(session);
    return session;
  }
}

class AccountConnection extends ConnectionController {
  AccountConnection() : super(AccountStore(), isIsolated: true);
  void changed() => notifyListeners();
}

/// A connected Codex host whose account session [prepare] fills.
AccountConnection accountConnection({
  bool accountEnabled = true,
  bool connected = true,
  void Function(FakeAccountSession session)? prepare,
}) {
  final connection = AccountConnection()
    ..api = AccountGateway(accountEnabled: accountEnabled, prepare: prepare)
    ..status = connected ? StreamStatus.connected : StreamStatus.disconnected;
  addTearDown(connection.dispose);
  return connection;
}

/// Signed in, with a 5-hour window at [primaryPercent] resetting 6 h after
/// [usageNow] and a 7-day window at 68 %.
void signedIn(FakeAccountSession session, {int primaryPercent = 32}) {
  session.account = fixtureSignedIn;
  session.buckets = [
    AccountRateBucket(
      'Codex',
      AccountRateWindow(
        primaryPercent,
        300,
        usageNow.add(const Duration(hours: 6)),
      ),
      const AccountRateWindow(68, 10080, null),
    ),
  ];
  session.tokens = const AccountTokenUsage(
    lifetimeTokens: 184250,
    peakDailyTokens: 12640,
  );
}

void mockSecureStorage() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (_) async => null,
      );
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        ),
  );
}

/// The app shell for one page: the real theme, English, no animations.
Widget usageApp(
  Widget home, {
  bool light = false,
  double scale = 1,
  GlobalKey? boundary,
  GlobalKey<NavigatorState>? navigator,
}) {
  final app = MaterialApp(
    navigatorKey: navigator,
    debugShowCheckedModeBanner: false,
    theme: captureTheme(light: light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: true, textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: home,
  );
  return boundary == null ? app : RepaintBoundary(key: boundary, child: app);
}
