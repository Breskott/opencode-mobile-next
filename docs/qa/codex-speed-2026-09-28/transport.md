# Native connection reuse

Finish line: native OpenCode 2 requests reuse their existing TCP connection after
a four-second reading/navigation pause, with transport disposal still owning the
connection lifetime. Non-goals: request/connect timeout changes, SSE policy,
authentication, decoder replacement, generated SDK changes, or UI changes.

`Api2Transport` previously inherited Dio 5.11.1's native three-second idle socket
timeout. Its native adapter now creates the same default `HttpClient` with a
15-second idle timeout. Socket reuse remains conditional on the server keeping
the connection alive. TLS trust, proxy defaults, credentials, request timeouts,
and `close(force: true)` disposal remain unchanged. Each transport owns its
client; no global pool crosses profiles. Other platform adapters are untouched.

The local HTTP test makes two pairs of requests separated by four seconds. It
counts distinct peer ports for stock Dio and the configured transport, checking
response behavior and idempotent close. This measures avoidable connections;
it does **not** estimate internet RTT, TLS cost, or device navigation latency.

| Host workload | Stock native Dio | Configured transport |
| --- | --- | --- |
| Two requests separated by four seconds | 2 connections | 1 connection |

## Large JSON decoding already implemented

The pinned Dio 5.11.1 `DioMixin` already installs `FusedTransformer` with a
50 KiB isolate threshold. On native platforms, JSON bodies at/above that size
use Dio's compute helper; smaller responses decode directly. Missing
`Content-Length` is supported by consolidating/counting bytes first. No extra
compute wrapper was added. The focused test checks intact large responses both
with and without that header. Decoded model construction above transport can
still consume main-isolate time; this does not establish a complete jank fix.

Focused verification (coordinator owns machine-heavy execution):

```sh
tool/qa/machine_lock.sh test -- "$FLUTTER" test --concurrency=1 \
  test/perf_transport_decode_test.dart test/api2_transport_test.dart
```

No UI hook-up is needed. The connection reuse policy is enabled when an existing
native `Api2Transport` is created.
