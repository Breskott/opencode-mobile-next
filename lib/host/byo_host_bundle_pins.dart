import '../domain/byo_host.dart';

/// Reviewed bytes for the exact app version, never a remote checksum lookup.
/// This historical OC1 bundle remains unchanged. New OC2 source bundles use
/// version 2.0.0; new app versions stay unavailable until their reviewed bundles
/// are published and their exact hashes are added here (no fallback to OC1).
ByoHostBundle? byoHostBundleForAppVersion(String appVersion) {
  if (appVersion != '1.1.0+51') return null;
  return ByoHostBundle(
    version: '1.1.0',
    openCodeVersion: '1.18.32',
    artifacts: {
      'x64': ByoHostArtifact(
        url:
            'https://github.com/Eslamasabry/opencode-mobile-next/releases/download/v1.1.0+51/oc-byo-host-1.1.0-amd64.tar.gz',
        sha256:
            '014d92fefcbb520af55af5bf6e3290715c47030f0c1a9b4aa5c91ddc44ff9118',
      ),
      'arm64': ByoHostArtifact(
        url:
            'https://github.com/Eslamasabry/opencode-mobile-next/releases/download/v1.1.0+51/oc-byo-host-1.1.0-arm64.tar.gz',
        sha256:
            '691396beda4d71cb5c5cbd43951260e56d67fb5b3543a39a8be8dd46a757def0',
      ),
    },
  );
}
