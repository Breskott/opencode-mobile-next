//! OC1 1.18.32 only. No provider configuration, subprocesses, or SSE completion.
//! Directory-local status cannot establish global chat admission; see the QA note.

use reqwest::{Client, Method, StatusCode, Url};
use serde_json::{json, Map, Value};
use std::{fmt, net::IpAddr, time::Duration};

const VERSION: &str = "1.18.32";
const SOURCE: &str = "545f51d26cc39a907d2867492d498d9607ea5fa4";
const MAX_RESPONSE: usize = 8 * 1024 * 1024;

/// Contains a static, credential-safe code only. Never wraps a server body/error.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ProtocolError(&'static str);

impl ProtocolError {
    pub fn code(&self) -> &'static str {
        self.0
    }
}
impl fmt::Display for ProtocolError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.0)
    }
}
impl std::error::Error for ProtocolError {}

/// Deliberately not Debug: authentication stays in memory and HTTP headers only.
pub struct OpenCodeClient {
    http: Client,
    base: Url,
    username: String,
    password: String,
}

impl OpenCodeClient {
    pub fn new(base_url: &str, username: &str, password: &str) -> Result<Self, ProtocolError> {
        let base = Url::parse(base_url).map_err(|_| ProtocolError("invalid_server"))?;
        let loopback = base
            .host_str()
            .and_then(|s| s.trim_matches(['[', ']']).parse::<IpAddr>().ok())
            .is_some_and(|ip| ip.is_loopback());
        if base.scheme() != "http"
            || !loopback
            || !base.username().is_empty()
            || base.password().is_some()
            || base.query().is_some()
            || base.fragment().is_some()
            || base.path() != "/"
            || username != "opencode"
            || password.is_empty()
        {
            return Err(ProtocolError("invalid_server"));
        }
        let http = Client::builder()
            .no_proxy()
            .redirect(reqwest::redirect::Policy::none())
            .timeout(Duration::from_secs(10))
            .build()
            .map_err(|_| ProtocolError("transport_unavailable"))?;
        Ok(Self {
            http,
            base,
            username: username.to_owned(),
            password: password.to_owned(),
        })
    }

    async fn request(
        &self,
        method: Method,
        path: &str,
        directory: Option<&str>,
        body: Option<&Value>,
    ) -> Result<Value, ProtocolError> {
        let mut url = self.base.clone();
        url.set_path(path);
        if let Some(dir) = directory {
            if !dir.starts_with('/') || dir.contains('\0') || dir.len() > 4096 {
                return Err(ProtocolError("invalid_directory"));
            }
            url.query_pairs_mut().append_pair("directory", dir);
        }
        let mut request = self
            .http
            .request(method.clone(), url)
            .basic_auth(&self.username, Some(&self.password));
        if let Some(body) = body {
            request = request.json(body);
        }
        let mutation = method != Method::GET;
        let uncertain = if mutation {
            "transport_uncertain"
        } else {
            "transport_unavailable"
        };
        let mut response = request.send().await.map_err(|_| ProtocolError(uncertain))?;
        if !response.status().is_success() {
            return Err(ProtocolError(match response.status() {
                StatusCode::UNAUTHORIZED | StatusCode::FORBIDDEN => "authentication_failed",
                StatusCode::NOT_FOUND => "protocol_unavailable",
                status if mutation && status.is_server_error() => "transport_uncertain",
                _ => "server_rejected",
            }));
        }
        if response.status() == StatusCode::NO_CONTENT {
            return Ok(Value::Null);
        }
        let mut bytes = Vec::new();
        while let Some(chunk) = response
            .chunk()
            .await
            .map_err(|_| ProtocolError(uncertain))?
        {
            if bytes.len().saturating_add(chunk.len()) > MAX_RESPONSE {
                return Err(ProtocolError(if mutation {
                    "transport_uncertain"
                } else {
                    "response_too_large"
                }));
            }
            bytes.extend_from_slice(&chunk);
        }
        serde_json::from_slice(&bytes).map_err(|_| {
            ProtocolError(if mutation {
                "transport_uncertain"
            } else {
                "invalid_response"
            })
        })
    }

    async fn pinned_health(&self) -> Result<(), ProtocolError> {
        let health = self
            .request(Method::GET, "/global/health", None, None)
            .await?;
        if health.get("healthy") != Some(&Value::Bool(true))
            || health.get("version").and_then(Value::as_str) != Some(VERSION)
        {
            return Err(ProtocolError("unsupported_server_version"));
        }
        Ok(())
    }

    /// Health and current callable OpenAPI evidence, not an execution proof.
    pub async fn verify(&self) -> Result<Value, ProtocolError> {
        self.pinned_health().await?;
        let doc = self.request(Method::GET, "/doc", None, None).await?;
        validate_openapi(&doc)?;
        Ok(json!({
            "healthy": true, "version": VERSION, "sourceRevision": SOURCE,
            "pinnedVersion": true, "openapiVerified": true,
            "capabilities": {"sessionDriver": true, "readOnlyPermissions": true,
                "chatAdmission": false, "execution": false, "oc2": false},
            "blockers": ["global_status_unavailable"]
        }))
    }

    /// The pinned server stores status in InstanceState; global session inventory
    /// contains creation directories, not all execution instances. Never fake idle.
    pub async fn chat_admission(
        &self,
        _team_session_ids: &[String],
    ) -> Result<bool, ProtocolError> {
        self.pinned_health().await?;
        Err(ProtocolError("global_status_unavailable"))
    }

    pub async fn create_session(
        &self,
        directory: &str,
        title: &str,
    ) -> Result<String, ProtocolError> {
        self.pinned_health().await?;
        // A newly created lane starts with no tools until prompt chooses its role.
        let session = self
            .request(
                Method::POST,
                "/session",
                Some(directory),
                Some(&json!({"title": title, "permission": deny_all()})),
            )
            .await?;
        let id = session
            .get("id")
            .and_then(Value::as_str)
            .ok_or(ProtocolError("transport_uncertain"))?;
        validate_session_id(id).map_err(|_| ProtocolError("transport_uncertain"))?;
        if session.get("directory").and_then(Value::as_str) != Some(directory) {
            return Err(ProtocolError("transport_uncertain"));
        }
        Ok(id.to_owned())
    }

    /// Wire implementation. Coordinator must first obtain chat admission and
    /// boundary proof; current verify() explicitly reports execution unavailable.
    pub async fn prompt(
        &self,
        directory: &str,
        session_id: &str,
        role: &str,
        model: &str,
        instructions: &str,
        text: &str,
        readonly: bool,
    ) -> Result<Value, ProtocolError> {
        validate_session_id(session_id)?;
        let body = prompt_body(role, model, instructions, text, readonly)?;
        self.pinned_health().await?;
        let permission = role_permissions(readonly);
        let path = format!("/session/{session_id}");
        let updated = self
            .request(
                Method::PATCH,
                &path,
                Some(directory),
                Some(&json!({"permission": permission})),
            )
            .await?;
        // Handler merges rules append-only; ensure our complete policy is last.
        let actual = updated
            .get("permission")
            .and_then(Value::as_array)
            .ok_or(ProtocolError("permission_policy_unconfirmed"))?;
        let expected = permission
            .as_array()
            .ok_or(ProtocolError("invalid_permission_policy"))?;
        if !actual.ends_with(expected) {
            return Err(ProtocolError("permission_policy_unconfirmed"));
        }
        self.request(
            Method::POST,
            &format!("{path}/prompt_async"),
            Some(directory),
            Some(&body),
        )
        .await?;
        // 204 is acceptance only. No completion and no retry after uncertainty.
        Ok(json!({"state":"running", "sessionId":session_id, "accepted":true}))
    }

    /// Every poll/reconnect refetches durable messages, pending requests, and two
    /// status snapshots. No stream closure, cached delta, or old turn completes.
    pub async fn observe(&self, directory: &str, session_id: &str) -> Result<Value, ProtocolError> {
        validate_session_id(session_id)?;
        self.pinned_health().await?;
        let path = format!("/session/{session_id}");
        let session = self
            .request(Method::GET, &path, Some(directory), None)
            .await?;
        if session.get("id").and_then(Value::as_str) != Some(session_id)
            || session.get("directory").and_then(Value::as_str) != Some(directory)
        {
            return Err(ProtocolError("session_scope_mismatch"));
        }
        let before = self
            .request(Method::GET, "/session/status", Some(directory), None)
            .await?;
        let messages = self
            .request(
                Method::GET,
                &format!("{path}/message"),
                Some(directory),
                None,
            )
            .await?;
        let permissions = self
            .request(Method::GET, "/permission", Some(directory), None)
            .await?;
        let questions = self
            .request(Method::GET, "/question", Some(directory), None)
            .await?;
        let after = self
            .request(Method::GET, "/session/status", Some(directory), None)
            .await?;
        observation(
            session_id,
            &messages,
            &before,
            &after,
            &permissions,
            &questions,
        )
    }

    pub async fn abort(&self, directory: &str, session_id: &str) -> Result<(), ProtocolError> {
        validate_session_id(session_id)?;
        self.pinned_health().await?;
        let result = self
            .request(
                Method::POST,
                &format!("/session/{session_id}/abort"),
                Some(directory),
                None,
            )
            .await?;
        if result != Value::Bool(true) {
            return Err(ProtocolError("transport_uncertain"));
        }
        Ok(())
    }
}

fn validate_session_id(id: &str) -> Result<(), ProtocolError> {
    if !id.starts_with("ses")
        || id.len() > 128
        || id.len() < 4
        || !id.bytes().all(|c| c.is_ascii_alphanumeric() || c == b'_')
    {
        return Err(ProtocolError("invalid_session"));
    }
    Ok(())
}

fn deny_all() -> Value {
    json!([{"permission":"*", "pattern":"*", "action":"deny"}])
}
fn role_permissions(readonly: bool) -> Value {
    if readonly {
        json!([
            {"permission":"*", "pattern":"*", "action":"deny"},
            {"permission":"read", "pattern":"*", "action":"allow"},
            {"permission":"glob", "pattern":"*", "action":"allow"},
            {"permission":"grep", "pattern":"*", "action":"allow"}
        ])
    } else {
        // All unsupported/custom tools and subagents remain denied. OS boundary
        // still required for worker bash/edit; permissions alone protect no main.
        json!([
            {"permission":"*", "pattern":"*", "action":"deny"},
            {"permission":"read", "pattern":"*", "action":"allow"},
            {"permission":"glob", "pattern":"*", "action":"allow"},
            {"permission":"grep", "pattern":"*", "action":"allow"},
            {"permission":"edit", "pattern":"*", "action":"allow"},
            {"permission":"bash", "pattern":"*", "action":"allow"}
        ])
    }
}

fn prompt_body(
    role: &str,
    model: &str,
    instructions: &str,
    text: &str,
    readonly: bool,
) -> Result<Value, ProtocolError> {
    if !matches!(role, "planner" | "worker" | "checker")
        || (matches!(role, "planner" | "checker") && !readonly)
        || instructions.is_empty()
        || text.is_empty()
    {
        return Err(ProtocolError("invalid_role"));
    }
    let (provider, model) = model
        .split_once('/')
        .ok_or(ProtocolError("invalid_model"))?;
    if provider.is_empty()
        || model.is_empty()
        || provider.chars().any(char::is_whitespace)
        || model.chars().any(char::is_whitespace)
    {
        return Err(ProtocolError("invalid_model"));
    }
    // Role names are engine policy, not presumed server agent configuration.
    // The built-in build agent is callable; system is the exact custom field.
    Ok(
        json!({"agent":"build", "model":{"providerID":provider,"modelID":model},
        "system":format!("AI Team role: {role}.\n{instructions}"),
        "parts":[{"type":"text","text":text}]}),
    )
}

fn validate_openapi(doc: &Value) -> Result<(), ProtocolError> {
    let paths = doc
        .get("paths")
        .and_then(Value::as_object)
        .ok_or(ProtocolError("openapi_unconfirmed"))?;
    for (path, method, operation) in [
        ("/global/health", "get", "global.health"),
        ("/session", "post", "session.create"),
        ("/session/{sessionID}", "get", "session.get"),
        ("/session/{sessionID}", "patch", "session.update"),
        ("/session/status", "get", "session.status"),
        ("/session/{sessionID}/message", "get", "session.messages"),
        (
            "/session/{sessionID}/prompt_async",
            "post",
            "session.prompt_async",
        ),
        ("/session/{sessionID}/abort", "post", "session.abort"),
        ("/permission", "get", "permission.list"),
        ("/question", "get", "question.list"),
    ] {
        if paths
            .get(path)
            .and_then(|v| v.get(method))
            .and_then(|v| v.get("operationId"))
            .and_then(Value::as_str)
            != Some(operation)
        {
            return Err(ProtocolError("openapi_unconfirmed"));
        }
    }
    let body = |path: &str, method: &str| -> Option<&Value> {
        paths
            .get(path)?
            .get(method)?
            .pointer("/requestBody/content/application~1json/schema")
    };
    let prompt = body("/session/{sessionID}/prompt_async", "post")
        .ok_or(ProtocolError("openapi_unconfirmed"))?;
    for (name, kind) in [
        ("agent", "string"),
        ("system", "string"),
        ("parts", "array"),
        ("model", "object"),
    ] {
        if prompt
            .get("properties")
            .and_then(|v| v.get(name))
            .and_then(|v| v.get("type"))
            .and_then(Value::as_str)
            != Some(kind)
        {
            return Err(ProtocolError("openapi_unconfirmed"));
        }
    }
    for field in ["providerID", "modelID"] {
        if prompt
            .pointer("/properties/model/properties")
            .and_then(|v| v.get(field))
            .and_then(|v| v.get("type"))
            .and_then(Value::as_str)
            != Some("string")
        {
            return Err(ProtocolError("openapi_unconfirmed"));
        }
    }
    for (path, method) in [("/session", "post"), ("/session/{sessionID}", "patch")] {
        if body(path, method)
            .and_then(|v| v.pointer("/properties/permission/$ref"))
            .and_then(Value::as_str)
            != Some("#/components/schemas/PermissionRuleset")
        {
            return Err(ProtocolError("openapi_unconfirmed"));
        }
    }
    if doc
        .pointer("/components/schemas/PermissionRuleset/items/$ref")
        .and_then(Value::as_str)
        != Some("#/components/schemas/PermissionRule")
    {
        return Err(ProtocolError("openapi_unconfirmed"));
    }
    for name in ["permission", "pattern", "action"] {
        if doc
            .pointer("/components/schemas/PermissionRule/properties")
            .and_then(|v| v.get(name))
            .is_none()
        {
            return Err(ProtocolError("openapi_unconfirmed"));
        }
    }
    Ok(())
}

fn status(statuses: &Value, id: &str) -> Result<&'static str, ProtocolError> {
    let statuses = statuses
        .as_object()
        .ok_or(ProtocolError("invalid_status"))?;
    for entry in statuses.values() {
        if !matches!(
            entry.get("type").and_then(Value::as_str),
            Some("busy" | "retry" | "idle")
        ) {
            return Err(ProtocolError("invalid_status"));
        }
    }
    // Exact pinned source deletes idle entries. Valid fresh map absence is idle,
    // only after observe separately verifies the session's existence and scope.
    match statuses
        .get(id)
        .and_then(|s| s.get("type"))
        .and_then(Value::as_str)
    {
        None | Some("idle") => Ok("idle"),
        Some("busy" | "retry") => Ok("running"),
        _ => Err(ProtocolError("invalid_status")),
    }
}

fn pending(items: &Value, id: &str) -> Result<bool, ProtocolError> {
    let items = items
        .as_array()
        .ok_or(ProtocolError("invalid_pending_requests"))?;
    let mut found = false;
    for item in items {
        let session = item
            .get("sessionID")
            .and_then(Value::as_str)
            .ok_or(ProtocolError("invalid_pending_requests"))?;
        found |= session == id;
    }
    Ok(found)
}

fn observation(
    id: &str,
    messages: &Value,
    before: &Value,
    after: &Value,
    permissions: &Value,
    questions: &Value,
) -> Result<Value, ProtocolError> {
    let before = status(before, id)?;
    let after = status(after, id)?;
    let blocked = pending(permissions, id)? | pending(questions, id)?;
    let messages = messages
        .as_array()
        .ok_or(ProtocolError("invalid_messages"))?;
    for message in messages {
        let info = message
            .get("info")
            .ok_or(ProtocolError("invalid_messages"))?;
        if info.get("sessionID").and_then(Value::as_str) != Some(id)
            || !matches!(
                info.get("role").and_then(Value::as_str),
                Some("user" | "assistant")
            )
            || !message.get("parts").is_some_and(Value::is_array)
        {
            return Err(ProtocolError("invalid_messages"));
        }
    }
    let user = messages.iter().rfind(|m| m["info"]["role"] == "user");
    let assistant = messages.iter().rfind(|m| m["info"]["role"] == "assistant");
    let mut text = String::new();
    if let Some(message) = assistant {
        for part in message["parts"]
            .as_array()
            .ok_or(ProtocolError("invalid_messages"))?
        {
            if part.get("type").and_then(Value::as_str) == Some("text")
                && part.get("ignored") != Some(&Value::Bool(true))
                && part.get("synthetic") != Some(&Value::Bool(true))
            {
                let value = part
                    .get("text")
                    .and_then(Value::as_str)
                    .ok_or(ProtocolError("invalid_messages"))?;
                if !text.is_empty() {
                    text.push('\n');
                }
                text.push_str(value);
            }
        }
    }
    let latest_turn = user.zip(assistant).is_some_and(|(u, a)| {
        u["info"]["id"].as_str().is_some()
            && a["info"]["parentID"].as_str() == u["info"]["id"].as_str()
    });
    let mut state = if before == "running" || after == "running" {
        "running"
    } else {
        "unknown"
    };
    if blocked {
        state = "blocked";
    } else if latest_turn {
        let message = assistant.ok_or(ProtocolError("invalid_messages"))?;
        let info = &message["info"];
        let finish = info.get("finish").and_then(Value::as_str);
        let tools = message["parts"]
            .as_array()
            .ok_or(ProtocolError("invalid_messages"))?
            .iter()
            .any(|p| p.get("type").and_then(Value::as_str) == Some("tool"));
        if info.get("error").is_some_and(|e| !e.is_null())
            || matches!(finish, Some("length" | "content-filter" | "error"))
        {
            state = "failed";
        } else if before == "idle"
            && after == "idle"
            && finish == Some("stop")
            && info
                .pointer("/time/completed")
                .and_then(Value::as_u64)
                .is_some_and(|n| n > 0)
            && !tools
            && !text.is_empty()
        {
            state = "completed";
        }
    }
    Ok(json!({"state":state,"text":text,"usage":usage(messages)}))
}

fn usage(messages: &[Value]) -> Value {
    let assistants: Vec<&Value> = messages
        .iter()
        .filter(|m| m["info"]["role"] == "assistant")
        .map(|m| &m["info"])
        .collect();
    let mut usage = Map::new();
    if assistants.is_empty() {
        return Value::Object(usage);
    }
    let sum = |path: &str| -> Option<Value> {
        let mut total = 0.0;
        for info in &assistants {
            let n = info.pointer(path)?.as_f64()?;
            if !n.is_finite() || n < 0.0 {
                return None;
            }
            total += n;
        }
        serde_json::Number::from_f64(total).map(Value::Number)
    };
    if let Some(cost) = sum("/cost") {
        usage.insert("cost".into(), cost);
    }
    let mut tokens = Map::new();
    for field in ["total", "input", "output", "reasoning"] {
        if let Some(value) = sum(&format!("/tokens/{field}")) {
            tokens.insert(field.into(), value);
        }
    }
    let mut cache = Map::new();
    for field in ["read", "write"] {
        if let Some(value) = sum(&format!("/tokens/cache/{field}")) {
            cache.insert(field.into(), value);
        }
    }
    if !cache.is_empty() {
        tokens.insert("cache".into(), Value::Object(cache));
    }
    if !tokens.is_empty() {
        usage.insert("tokens".into(), Value::Object(tokens));
    }
    Value::Object(usage)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn messages(finish: &str) -> Value {
        json!([
            {"info":{"id":"msg_u","sessionID":"ses_test","role":"user"},"parts":[]},
            {"info":{"id":"msg_a","sessionID":"ses_test","role":"assistant",
                "parentID":"msg_u","finish":finish,"time":{"completed":1},
                "cost":0.2,"tokens":{"input":10,"output":20}},
                "parts":[{"type":"text","text":"done"}]}
        ])
    }
    fn observed(messages: &Value) -> Value {
        observation(
            "ses_test",
            messages,
            &json!({}),
            &json!({}),
            &json!([]),
            &json!([]),
        )
        .unwrap()
    }
    #[test]
    fn only_latest_final_idle_turn_completes() {
        assert_eq!(observed(&messages("stop"))["state"], "completed");
        for finish in ["unknown", "tool-calls", "other", "end-turn"] {
            assert_eq!(observed(&messages(finish))["state"], "unknown");
        }
        let mut m = messages("stop");
        m.as_array_mut()
            .unwrap()
            .push(json!({"info":{"id":"msg_new","sessionID":"ses_test","role":"user"},"parts":[]}));
        assert_eq!(observed(&m)["state"], "unknown");
    }
    #[test]
    fn requests_errors_tools_and_busy_prevent_completion() {
        let m = messages("stop");
        let pending = json!([{"sessionID":"ses_test"}]);
        assert_eq!(
            observation("ses_test", &m, &json!({}), &json!({}), &pending, &json!([])).unwrap()
                ["state"],
            "blocked"
        );
        let busy = json!({"ses_test":{"type":"busy"}});
        assert_eq!(
            observation("ses_test", &m, &busy, &json!({}), &json!([]), &json!([])).unwrap()
                ["state"],
            "running"
        );
        let mut m = m;
        m[1]["info"]["error"] = json!({"data":"sensitive"});
        assert_eq!(observed(&m)["state"], "failed");
        m[1]["info"].as_object_mut().unwrap().remove("error");
        m[1]["parts"]
            .as_array_mut()
            .unwrap()
            .push(json!({"type":"tool"}));
        assert_eq!(observed(&m)["state"], "unknown");
    }
    #[test]
    fn usage_omits_unknown_and_preserves_known_zero() {
        let mut m = messages("stop");
        assert_eq!(observed(&m)["usage"]["cost"], 0.2);
        assert!(observed(&m)["usage"]["tokens"].get("total").is_none());
        m[1]["info"]["cost"] = json!(0);
        assert_eq!(observed(&m)["usage"]["cost"], 0.0);
        m[1]["info"].as_object_mut().unwrap().remove("cost");
        assert!(observed(&m)["usage"].get("cost").is_none());
    }
    #[test]
    fn role_fields_and_readonly_policy_are_exact() {
        let body = prompt_body("planner", "openai/gpt-6", "plan", "task", true).unwrap();
        assert_eq!(
            body["model"],
            json!({"providerID":"openai","modelID":"gpt-6"})
        );
        assert_eq!(body["agent"], "build");
        assert!(body.get("tools").is_none());
        assert_eq!(role_permissions(true)[0]["permission"], "*");
        assert_eq!(role_permissions(true)[0]["action"], "deny");
        assert_eq!(role_permissions(true).as_array().unwrap().len(), 4);
        assert!(prompt_body("checker", "openai/gpt-6", "check", "task", false).is_err());
        assert!(prompt_body("worker", "gpt-6", "work", "task", false).is_err());
    }
    #[test]
    fn endpoint_and_error_never_expose_credentials() {
        for url in [
            "http://example.com:4096",
            "http://localhost:4096",
            "http://127.0.0.1:4096/api",
            "http://user:secret@127.0.0.1:4096",
        ] {
            assert!(OpenCodeClient::new(url, "opencode", "secret").is_err());
        }
        assert!(OpenCodeClient::new("http://127.0.0.1:4096", "opencode", "secret").is_ok());
        assert!(OpenCodeClient::new("http://[::1]:4096", "opencode", "secret").is_ok());
        assert_eq!(
            ProtocolError("transport_uncertain").to_string(),
            "transport_uncertain"
        );
    }
    #[test]
    fn malformed_status_and_pending_requests_fail_closed() {
        assert!(observation(
            "ses_test",
            &messages("stop"),
            &Value::Null,
            &json!({}),
            &json!([]),
            &json!([])
        )
        .is_err());
        assert!(observation(
            "ses_test",
            &messages("stop"),
            &json!({}),
            &json!({}),
            &json!([{}]),
            &json!([])
        )
        .is_err());
        assert!(validate_session_id("ses/../global/config").is_err());
        assert!(validate_openapi(&json!({"paths":{}})).is_err());
    }
}
