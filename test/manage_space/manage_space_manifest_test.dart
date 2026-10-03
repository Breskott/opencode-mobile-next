// Android's "Clear storage" must open the guard page first: the manifest
// names ManageSpaceActivity as the application's manageSpaceActivity, the
// activity exists, and its Dart entrypoint is kept for release builds.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const kotlin =
      'android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile';
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  test('the application declares the manage-space activity', () {
    final application = RegExp(
      r'<application\b[^>]*>',
    ).firstMatch(manifest)!.group(0)!;
    expect(
      application,
      contains('android:manageSpaceActivity=".ManageSpaceActivity"'),
    );
    expect(
      manifest,
      contains('android:name=".ManageSpaceActivity"'),
      reason: 'the named activity must be declared',
    );
  });

  test('the activity runs the manage-space entrypoint, not the app', () {
    final activity = File('$kotlin/ManageSpaceActivity.kt').readAsStringSync();
    expect(activity, contains('class ManageSpaceActivity : FlutterActivity()'));
    expect(activity, contains('"manageSpaceMain"'));
    expect(activity, contains('ProjectExportBridge('));
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains("@pragma('vm:entry-point')\nvoid manageSpaceMain()"));
  });

  test('both halves of oc/project_export agree on the channel', () {
    final bridge = File('$kotlin/ProjectExportBridge.kt').readAsStringSync();
    expect(bridge, contains('"oc/project_export"'));
    expect(bridge, contains('clearApplicationUserData()'));
    final dart = File('lib/builtin/project_export.dart').readAsStringSync();
    expect(dart, contains("MethodChannel('oc/project_export')"));
    for (final method in [
      'pickDestination',
      'export',
      'cancel',
      'cacheBytes',
      'clearCache',
      'clearAllData',
    ]) {
      expect(bridge, contains('"$method"'), reason: method);
      expect(dart, contains("'$method'"), reason: method);
    }
  });
}
