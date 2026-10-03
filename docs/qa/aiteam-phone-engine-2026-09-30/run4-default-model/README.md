# Run 4: use the in-app server's default model

Finish line: an empty engine role model omits the `model` field on OC1 `prompt_async`, allowing the in-app server to choose its configured default; an explicit `provider/model` selection retains local validation and exact wire identity.

Non-goal: changing native startup, scheduler or dispatch receipts, adding a second model-selection source, inventing a default provider/model, changing UI, or issuing model requests in this worker.

## Callable evidence and behavior

The pinned local [OC1 contract](../../../../contracts/opencode-openapi-f12e14cf.json) defines `session.prompt_async` with only `parts` required. Its `model` object is optional; when supplied it requires `providerID` and `modelID`. The driver's live `verify()` now requires its actual `/doc` prompt schema to contain a typed `required` list with `parts`, exclude `model`, and require no other field the driver omits. The pinned server version and remaining schema/permissions checks still apply. A server requiring a model refuses capability admission rather than accepting guessed wire behavior.

`pub fn validate_model(&str) -> Result<(), ProtocolError>` is a pure local preflight for the daemon owner to call before clone/session creation and before recording dispatch. Exactly the empty string means server default. Nonempty selections must still have nonempty provider and model components and no whitespace. Prompt construction uses the same parser; default selection omits the key entirely (not `null` or an invented identifier). Explicit provider and model strings remain unchanged.

The existing prompt path validates the session/role/model before its first HTTP request. Completion still requires durable observed turn evidence; a default model does not change role permissions, chat admission, acceptance or retry behavior.

## Focused tests

Added four checks in `engine/phone/src/opencode.rs`:

- `empty_model_selection_omits_wire_field_and_keeps_authored_role`: planner/worker/checker requests preserve their role instructions, built-in build agent and task parts while omitting model.
- `nonempty_model_preflight_and_explicit_wire_selection_agree`: malformed explicit selections fail and `zai/glm-5.3` remains explicit.
- `callable_prompt_contract_must_support_model_omission`: the pinned real contract passes; requiring model, malformed/missing required evidence, an unknown required field or no required parts fails closed.
- `invalid_explicit_model_does_not_send_any_http_request`: a real local listener receives no request for malformed explicit selection.

Default omission and required-model refusal regressions fail on the prior implementation. Explicit-selection/no-HTTP checks preserve existing behavior.

Root owns daemon preflight integration and serialized cargo/native/Flutter/live checks. This worker ran Rust formatting and `git diff --check` only; no heavy tests, device actions, model calls, signing or push.
