import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/host/byo_host_bundle_pins.dart';

void main() {
  test('compiled artifacts match the exact app-version review ledger', () {
    final ledger =
        jsonDecode(
              File('scripts/byo-host/release-pins.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final historical =
        (ledger['legacyBundles'] as List).single as Map<String, dynamic>;
    expect(ledger['openCodeVersion'], '2.0.29');
    expect(
      ledger['appVersions'],
      isEmpty,
    ); // Publication requires owner review.
    final reviews = historical['appVersions'] as Map<String, dynamic>;
    for (final entry in reviews.entries) {
      final bundle = byoHostBundleForAppVersion(entry.key)!;
      expect(bundle.version, historical['bundleVersion']);
      expect(bundle.openCodeVersion, historical['openCodeVersion']);
      for (final arch in ['amd64', 'arm64']) {
        final artifact = bundle.artifacts[arch == 'amd64' ? 'x64' : arch]!;
        expect(artifact.sha256, entry.value[arch]);
        expect(
          artifact.url,
          'https://github.com/Eslamasabry/opencode-mobile-next/releases/download/v${entry.key}/oc-byo-host-${bundle.version}-$arch.tar.gz',
        );
      }
    }
    for (final version in ['1.1.0+52', '1.1.0', '', 'latest']) {
      expect(byoHostBundleForAppVersion(version), isNull);
    }
  });
}
