import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/domain/provider_quota.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/in_app_quota_enroller.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_quota_test.dart' show providerQuotaFixture;

class _Gateway implements ProviderQuotaGateway {
  _Gateway(this.provider, this.signedIn);
  final QuotaProvider provider;
  final bool signedIn;
  int closes = 0;

  @override
  Future<ProviderQuotaSnapshot> readSnapshot() async {
    if (!signedIn) {
      throw const ProviderQuotaFailure(QuotaFailureKind.unavailable);
    }
    final value =
        jsonDecode(
              jsonEncode(
                providerQuotaFixture(
                  fetchedAtMs: DateTime.now().millisecondsSinceEpoch,
                  provider: provider,
                ),
              ),
            )
            as Map<String, dynamic>;
    return ProviderQuotaSnapshot.fromJson(value);
  }

  @override
  void close() => closes++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  testWidgets('every provider that answers is monitored for the widget', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    for (final name in [
      'plugins.it_nomads.com/flutter_secure_storage',
      'oc/background',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(MethodChannel(name), null),
      );
    }
    final store = ProfileStore(prefs: await SharedPreferences.getInstance());
    final profile = ServerProfile(
      id: 'builtin',
      name: 'In-app Ubuntu',
      baseUrl: BuiltinLinux.serverUrl,
      username: 'opencode',
      password: 'fixture-basic-password',
    );
    await store.upsert(profile);
    await store.setActiveId(profile.id);
    final connection = ConnectionController(store);
    final gateways = <_Gateway>[];
    final enroller = InAppQuotaEnroller(
      connection,
      gateway: (profile, provider) {
        // GLM is not signed in to OpenCode; the others answer.
        final g = _Gateway(provider, provider != QuotaProvider.glm);
        gateways.add(g);
        return g;
      },
    );
    final monitored = await enroller.enroll(profile);
    expect(monitored, contains(QuotaProvider.codex));
    expect(monitored, contains(QuotaProvider.minimax));
    expect(monitored, isNot(contains(QuotaProvider.glm)));
    expect(
      connection.quotaMonitor.rulesFor('builtin', QuotaProvider.codex),
      isNotNull,
    );
    expect(
      connection.quotaMonitor.rulesFor('builtin', QuotaProvider.glm),
      isNull,
    );
    expect(gateways.every((g) => g.closes == 1), isTrue);
    // Already monitored: no second read, still counted.
    gateways.clear();
    expect(await enroller.enroll(profile), contains(QuotaProvider.codex));
    expect(gateways.map((g) => g.provider), [QuotaProvider.glm]);
    // The monitor's timers belong to the connection; release them here.
    connection.quotaMonitor.dispose();
    connection.dispose();
  });
}
