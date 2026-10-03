// The Remaining page's personal quota budgets are retired (quota
// monitoring's threshold replaced them): the rules they left on the device
// go on the next load, and profile deletion still sweeps the key.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (_) async => null),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, null),
  );

  test('load drops every stored quota budget and nothing else', () async {
    SharedPreferences.setMockInitialValues({
      'oc.budgets.laptop': '{"version":1,"rules":{}}',
      'oc.budgets.phone': '{"version":1,"rules":{}}',
      'oc.consumptionBudgets.laptop': '{"version":1}',
      'oc.activeProfile': 'laptop',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = ProfileStore(prefs: prefs);
    await store.load();

    expect(
      prefs.getKeys().where(
        (key) => key.startsWith(ProfileStore.retiredQuotaBudgetsPrefix),
      ),
      isEmpty,
    );
    expect(prefs.getString('oc.consumptionBudgets.laptop'), isNotNull);
    expect(prefs.getString('oc.activeProfile'), 'laptop');

    // A second load finds nothing to do.
    await store.load();
    expect(prefs.getString('oc.consumptionBudgets.laptop'), isNotNull);
  });

  test('profile deletion still sweeps the key', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = ProfileStore(prefs: prefs);
    await store.load();
    await prefs.setString('oc.budgets.laptop', '{}');
    expect(
      store.profileScopedPreferenceKeys('laptop'),
      contains('oc.budgets.laptop'),
    );
  });
}
