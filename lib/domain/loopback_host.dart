/// The loopback predicate, kept free of Flutter imports so the
/// orchestration adapters (and `dart run` tools such as
/// `tool/qa/gascity_read_proof.dart`) can use it outside a Flutter runtime.
/// `lib/state/profiles.dart` re-exports it for the rest of the app.
library;

/// The hosts this app will speak cleartext HTTP to: this device, by every
/// name it has.
///
/// Kept as one predicate on purpose. The app used to have three loopback
/// checks that disagreed — the URL normalizer split on `:` and so read the
/// host of `[::1]:4096` as `[`, the validator's allowlist had no IPv6 entry
/// at all, and the connection controller's did. `::1` reached different
/// verdicts depending on which one you hit. Anything added here must also be
/// added to `android/app/src/main/res/xml/network_security_config.xml`, or
/// Android blocks the request after this code has allowed it.
bool isLoopbackHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1';
}
