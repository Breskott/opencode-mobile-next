# Additive phone confinement tier contract

The authenticated schema-1 engine health response reports `boundaryTier` at the top level and inside `capabilities`. Native phone-engine status reports the same top-level field.

Accepted values are:

| Value | Meaning |
| --- | --- |
| `none` | No verified confinement tier is reported. |
| `landlock` | The signed device proof verified the Landlock kernel confinement tier. |
| `proot` | The signed device proof verified the proot confinement tier. This uses ptrace syscall translation; it is not kernel-enforced Landlock. |

A signed, verified proot tier enables the same `boundary` and `execution` flags as Landlock when the existing prerequisites pass. The Dart client uses those existing flags, OC1 readiness, and OC2 refusal to decide `canExecute`; it does not grant execution merely from a tier string.

For backwards compatibility, missing tier fields parse as `none` without changing an older schema-1 engine's existing execution flags. No stronger tier is inferred from those flags. During an additive transition, a tier at either health location is accepted. When both locations are supplied, they must agree. Unknown values, explicit nulls, incorrect types, and conflicting health locations fail as `payloadInvalid`; malformed native status fails with the plain `engine_status_invalid` error.

The recommended general UI label is **“Protected by this phone Linux sandbox”**. Technical details may name the verified tier. For `proot`, explain that protection uses the phone's proot ptrace syscall translation and passed the runtime boundary probe; do not label it Landlock or kernel confinement. Verification belongs to the signed device receipt and packaged binary, rather than a mutable preference or client label.

The native launcher and engine own proof, signature validation, and flag activation. This additive Dart contract changes no UI component or controller lifecycle.
