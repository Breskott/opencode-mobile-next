//! OC1 1.18.32 only. No provider configuration, subprocesses, or SSE completion.
//! Directory-local status cannot establish global chat admission; see the QA note.

use reqwest::{Client, Method, StatusCode, Url};
use serde_json::{json, Map, Value};
use std::{
    collections::BTreeSet,
    fmt,
    net::IpAddr,
    time::{Duration, Instant},
};

const VERSION: &str = "1.18.32";
const SOURCE: &str = "545f51d26cc39a907d2867492d498d9607ea5fa4";
const MAX_RESPONSE: usize = 8 * 1024 * 1024;
const MAX_STATUS_DIRECTORIES: usize = 64;
const MAX_SSE_FRAME: usize = 256 * 1024;
const MAX_BUSY_OBSERVATIONS: usize = 4096;
const STATUS_FRESHNESS: Duration = Duration::from_secs(10);
const STREAM_FRESHNESS: Duration = Duration::from_secs(30);

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
    stream_http: Client,
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
        // SSE has no overall lifetime timeout. Header and each read are bounded
        // separately; a heartbeat is emitted every ten seconds by pinned OC1.
        let stream_http = Client::builder()
            .no_proxy()
            .redirect(reqwest::redirect::Policy::none())
            .connect_timeout(Duration::from_secs(10))
            .build()
            .map_err(|_| ProtocolError("transport_unavailable"))?;
        Ok(Self {
            http,
            stream_http,
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
                "executionDriver": true, "knownPersonDirectoryStatus": true,
                "globalStatusObserver": true, "globalAdmissionAuthority": false,
                "chatAdmission": false, "execution": false, "oc2": false},
            "blockers": ["global_status_unavailable"]
        }))
    }

    /// Resolve an omitted role model from authenticated, directory-local OC1
    /// configuration and provider availability. Both responses can contain
    /// credentials: only the selected provider/model identity leaves this method.
    /// An explicit user choice is preserved without substituting another model.
    pub async fn resolve_model(
        &self,
        directory: &str,
        requested: &str,
    ) -> Result<String, ProtocolError> {
        if !requested.is_empty() {
            validate_model(requested)?;
            return Ok(requested.to_owned());
        }
        let configured = self
            .request(Method::GET, "/config", Some(directory), None)
            .await?
            .get("model")
            .and_then(Value::as_str)
            .map(str::to_owned);
        let providers = self
            .request(Method::GET, "/provider", Some(directory), None)
            .await?;
        resolve_runtime_model(configured.as_deref(), &providers)
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

    /// Complete, fresh snapshots only for the positively supplied known person
    /// directories. This cannot discover directories used by another client.
    /// Root must prove app-process absence before selecting this fallback.
    pub async fn person_directory_status(
        &self,
        directories: &[String],
        team_session_ids: &[String],
    ) -> Result<bool, ProtocolError> {
        let directories = known_directories(directories)?;
        validate_team_ids(team_session_ids)?;
        self.pinned_health().await?;
        let started = Instant::now();
        let mut idle = true;
        for directory in directories {
            let statuses = self
                .request(Method::GET, "/session/status", Some(directory), None)
                .await?;
            idle &= person_status_snapshot(&statuses, team_session_ids)?;
            if started.elapsed() > STATUS_FRESHNESS {
                return Err(ProtocolError("person_status_stale"));
            }
        }
        Ok(idle)
    }

    /// Volatile blocker observations only. Even connected with no observed busy
    /// sessions is not a complete global idle checkpoint or admission authority.
    pub async fn global_status_observer(&self) -> Result<GlobalStatusObserver, ProtocolError> {
        self.pinned_health().await?;
        let mut url = self.base.clone();
        url.set_path("/global/event");
        let response = tokio::time::timeout(
            Duration::from_secs(10),
            self.stream_http
                .get(url)
                .header(reqwest::header::ACCEPT, "text/event-stream")
                .basic_auth(&self.username, Some(&self.password))
                .send(),
        )
        .await
        .map_err(|_| ProtocolError("global_status_disconnected"))?
        .map_err(|_| ProtocolError("global_status_disconnected"))?;
        if !response.status().is_success() {
            return Err(ProtocolError(match response.status() {
                StatusCode::UNAUTHORIZED | StatusCode::FORBIDDEN => "authentication_failed",
                StatusCode::NOT_FOUND => "protocol_unavailable",
                _ => "global_status_disconnected",
            }));
        }
        if response
            .headers()
            .get(reqwest::header::CONTENT_TYPE)
            .and_then(|v| v.to_str().ok())
            .and_then(|v| v.split(';').next())
            .map(str::trim)
            != Some("text/event-stream")
        {
            return Err(ProtocolError("invalid_global_status_stream"));
        }
        Ok(GlobalStatusObserver {
            response: Some(response),
            decoder: SseStatusDecoder::default(),
            busy: BTreeSet::new(),
            last_event: Instant::now(),
            connected: true,
        })
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
    /// boundary proof. verify() distinguishes usable driver evidence from absent
    /// global admission authority; the coordinator owns app-authoritative gating.
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

/// Metadata only; never includes raw event bodies, retry messages, or errors.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GlobalStatusObservation {
    Status {
        directory: String,
        session_id: String,
        busy: bool,
    },
    Other,
}

/// A connection-local observation set. Do not persist or treat an empty set as
/// global idle. Reconnect starts a new incomplete history, never a checkpoint.
pub struct GlobalStatusObserver {
    response: Option<reqwest::Response>,
    decoder: SseStatusDecoder,
    busy: BTreeSet<(String, String)>,
    last_event: Instant,
    connected: bool,
}

impl GlobalStatusObserver {
    pub fn connected(&self) -> bool {
        self.connected && self.last_event.elapsed() <= STREAM_FRESHNESS
    }

    /// True blocks admission. False means only "no observed non-team busy";
    /// the independent app authority/known-directory snapshot is still required.
    pub fn observed_non_team_busy(
        &self,
        team_session_ids: &[String],
    ) -> Result<bool, ProtocolError> {
        validate_team_ids(team_session_ids)?;
        if !self.connected() {
            return Err(ProtocolError("global_status_disconnected"));
        }
        Ok(self
            .busy
            .iter()
            .any(|(_, id)| !team_session_ids.contains(id)))
    }

    fn disconnect(&mut self, code: &'static str) -> ProtocolError {
        self.connected = false;
        self.response = None;
        self.decoder = SseStatusDecoder::default();
        // Existing busy evidence remains in memory, but has no fresh authority.
        ProtocolError(code)
    }

    pub async fn next(&mut self) -> Result<GlobalStatusObservation, ProtocolError> {
        if !self.connected() {
            return Err(self.disconnect("global_status_disconnected"));
        }
        loop {
            let data = match self.decoder.next_event() {
                Ok(data) => data,
                Err(error) => return Err(self.disconnect(error.code())),
            };
            if let Some(data) = data {
                let event = match parse_global_status(&data) {
                    Ok(event) => event,
                    Err(error) => return Err(self.disconnect(error.code())),
                };
                if let GlobalStatusObservation::Status {
                    directory,
                    session_id,
                    busy,
                } = &event
                {
                    let key = (directory.clone(), session_id.clone());
                    if *busy {
                        if !self.busy.contains(&key) && self.busy.len() >= MAX_BUSY_OBSERVATIONS {
                            return Err(self.disconnect("global_status_capacity_unknown"));
                        }
                        self.busy.insert(key);
                    } else {
                        self.busy.remove(&key);
                    }
                }
                self.last_event = Instant::now();
                return Ok(event);
            }
            let Some(response) = self.response.as_mut() else {
                return Err(self.disconnect("global_status_disconnected"));
            };
            match tokio::time::timeout(STREAM_FRESHNESS, response.chunk()).await {
                Ok(Ok(Some(chunk))) => {
                    if let Err(error) = self.decoder.push(&chunk) {
                        return Err(self.disconnect(error.code()));
                    }
                }
                // EOF discards even a syntactically complete unterminated frame.
                // Closure never clears busy evidence or completes a task.
                _ => return Err(self.disconnect("global_status_disconnected")),
            }
        }
    }
}

#[derive(Default)]
struct SseStatusDecoder {
    buffer: Vec<u8>,
    data: String,
    frame_bytes: usize,
}

impl SseStatusDecoder {
    fn push(&mut self, bytes: &[u8]) -> Result<(), ProtocolError> {
        if self.buffer.len().saturating_add(bytes.len()) > MAX_SSE_FRAME {
            return Err(ProtocolError("global_status_frame_too_large"));
        }
        self.buffer.extend_from_slice(bytes);
        Ok(())
    }

    fn next_event(&mut self) -> Result<Option<String>, ProtocolError> {
        while let Some(end) = self.buffer.iter().position(|b| *b == b'\n') {
            let bytes: Vec<u8> = self.buffer.drain(..=end).collect();
            self.frame_bytes = self.frame_bytes.saturating_add(bytes.len());
            if self.frame_bytes > MAX_SSE_FRAME {
                return Err(ProtocolError("global_status_frame_too_large"));
            }
            let line = std::str::from_utf8(&bytes[..bytes.len() - 1])
                .map_err(|_| ProtocolError("invalid_global_status_stream"))?;
            let line = line.strip_suffix('\r').unwrap_or(line);
            if line.is_empty() {
                self.frame_bytes = 0;
                if !self.data.is_empty() {
                    return Ok(Some(std::mem::take(&mut self.data)));
                }
                continue;
            }
            if let Some(data) = line.strip_prefix("data:") {
                let data = data.strip_prefix(' ').unwrap_or(data);
                if !self.data.is_empty() {
                    self.data.push('\n');
                }
                self.data.push_str(data);
            }
            // event/id/retry/comments never establish status or checkpoints.
        }
        Ok(None)
    }
}

fn parse_global_status(data: &str) -> Result<GlobalStatusObservation, ProtocolError> {
    let data: Value =
        serde_json::from_str(data).map_err(|_| ProtocolError("invalid_global_status_stream"))?;
    let payload = data
        .get("payload")
        .and_then(Value::as_object)
        .ok_or(ProtocolError("invalid_global_status_stream"))?;
    let kind = payload
        .get("type")
        .and_then(Value::as_str)
        .ok_or(ProtocolError("invalid_global_status_stream"))?;
    if matches!(
        kind,
        "server.instance.disposed" | "server.disposed" | "global.disposed"
    ) {
        return Err(ProtocolError("global_status_disconnected"));
    }
    if !matches!(kind, "session.status" | "session.idle") {
        return Ok(GlobalStatusObservation::Other);
    }
    let directory = data
        .get("directory")
        .and_then(Value::as_str)
        .ok_or(ProtocolError("invalid_global_status_stream"))?;
    validate_directory(directory).map_err(|_| ProtocolError("invalid_global_status_stream"))?;
    let properties = payload
        .get("properties")
        .and_then(Value::as_object)
        .ok_or(ProtocolError("invalid_global_status_stream"))?;
    let id = properties
        .get("sessionID")
        .and_then(Value::as_str)
        .ok_or(ProtocolError("invalid_global_status_stream"))?;
    validate_session_id(id).map_err(|_| ProtocolError("invalid_global_status_stream"))?;
    let busy = if kind == "session.idle" {
        false
    } else {
        let state = properties
            .get("status")
            .ok_or(ProtocolError("invalid_global_status_stream"))?;
        validate_status_entry(state).map_err(|_| ProtocolError("invalid_global_status_stream"))?;
        state["type"] != "idle"
    };
    Ok(GlobalStatusObservation::Status {
        directory: directory.to_owned(),
        session_id: id.to_owned(),
        busy,
    })
}

fn validate_directory(directory: &str) -> Result<(), ProtocolError> {
    if !directory.starts_with('/') || directory.contains('\0') || directory.len() > 4096 {
        return Err(ProtocolError("person_directory_unknown"));
    }
    Ok(())
}

fn known_directories(directories: &[String]) -> Result<Vec<&str>, ProtocolError> {
    if directories.is_empty() || directories.len() > MAX_STATUS_DIRECTORIES {
        return Err(ProtocolError("person_directory_unknown"));
    }
    let mut known = BTreeSet::new();
    for directory in directories {
        validate_directory(directory)?;
        known.insert(directory.as_str());
    }
    Ok(known.into_iter().collect())
}

fn validate_team_ids(ids: &[String]) -> Result<(), ProtocolError> {
    for id in ids {
        validate_session_id(id)?;
    }
    Ok(())
}

fn validate_status_entry(entry: &Value) -> Result<(), ProtocolError> {
    let entry = entry.as_object().ok_or(ProtocolError("invalid_status"))?;
    match entry.get("type").and_then(Value::as_str) {
        Some("idle" | "busy") if entry.len() == 1 => Ok(()),
        Some("retry") => {
            if !entry.get("attempt").is_some_and(|v| v.as_u64().is_some())
                || !entry.get("next").is_some_and(|v| v.as_u64().is_some())
                || !entry.get("message").is_some_and(Value::is_string)
                || entry.keys().any(|k| {
                    !matches!(
                        k.as_str(),
                        "type" | "attempt" | "next" | "message" | "action"
                    )
                })
            {
                return Err(ProtocolError("invalid_status"));
            }
            if let Some(action) = entry.get("action") {
                let action = action.as_object().ok_or(ProtocolError("invalid_status"))?;
                if ["reason", "provider", "title", "message", "label"]
                    .iter()
                    .any(|k| !action.get(*k).is_some_and(Value::is_string))
                    || action.keys().any(|k| {
                        !matches!(
                            k.as_str(),
                            "reason" | "provider" | "title" | "message" | "label" | "link"
                        )
                    })
                    || action.get("link").is_some_and(|v| !v.is_string())
                {
                    return Err(ProtocolError("invalid_status"));
                }
            }
            Ok(())
        }
        _ => Err(ProtocolError("invalid_status")),
    }
}

fn person_status_snapshot(statuses: &Value, team_ids: &[String]) -> Result<bool, ProtocolError> {
    let statuses = statuses
        .as_object()
        .ok_or(ProtocolError("invalid_status"))?;
    let mut idle = true;
    for (id, entry) in statuses {
        validate_session_id(id).map_err(|_| ProtocolError("invalid_status"))?;
        validate_status_entry(entry)?;
        if !team_ids.contains(id) && entry["type"] != "idle" {
            idle = false;
        }
    }
    Ok(idle)
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

/// Local preflight only. Empty selection means the pinned OC1 server chooses
/// its configured default; explicit selections retain provider/model validation.
pub fn validate_model(model: &str) -> Result<(), ProtocolError> {
    model_selection(model).map(|_| ())
}

fn resolve_runtime_model(
    configured: Option<&str>,
    providers: &Value,
) -> Result<String, ProtocolError> {
    let all = providers["all"]
        .as_array()
        .ok_or(ProtocolError("invalid_response"))?;
    let defaults = providers["default"]
        .as_object()
        .ok_or(ProtocolError("invalid_response"))?;
    let connected: Vec<&str> = providers["connected"]
        .as_array()
        .ok_or(ProtocolError("invalid_response"))?
        .iter()
        .map(|id| id.as_str().ok_or(ProtocolError("invalid_response")))
        .collect::<Result<_, _>>()?;
    let usable = |candidate: &str| {
        let Ok(Some((provider_id, model_id))) = model_selection(candidate) else {
            return false;
        };
        if !connected.contains(&provider_id) {
            return false;
        }
        let mut matching = all.iter().filter(|p| p["id"] == provider_id);
        let Some(provider) = matching.next() else {
            return false;
        };
        // Ambiguous provider identities cannot establish a usable runtime model.
        matching.next().is_none()
            && provider["models"]
                .get(model_id)
                .and_then(Value::as_object)
                .is_some_and(|model| model.get("id").and_then(Value::as_str) == Some(model_id))
    };
    if let Some(model) = configured.filter(|model| usable(model)) {
        return Ok(model.to_owned());
    }
    // /provider defaults are model IDs keyed by provider, not full identities.
    // Follow the runtime's connected order without choosing a catalog-only model.
    for provider in &connected {
        if *provider == "zai-coding-plan" {
            // ZAI documents ordinary GLM-5.3 as supported by every Coding Plan:
            // https://docs.z.ai/devpack/overview#supported-models
            // OC1's catalog sort can instead nominate a subscription-restricted
            // highspeed model. Use the documented baseline only for omission;
            // this is selection policy, never proof of this key's entitlement.
            let baseline = "zai-coding-plan/glm-5.3";
            if usable(baseline) {
                return Ok(baseline.to_owned());
            }
            // No suffix stripping or automatic switch to a restricted variant.
            continue;
        }
        if let Some(model) = defaults.get(*provider).and_then(Value::as_str) {
            let candidate = format!("{provider}/{model}");
            if usable(&candidate) {
                return Ok(candidate);
            }
        }
    }
    Err(ProtocolError("modelNotConfigured"))
}

fn model_selection(model: &str) -> Result<Option<(&str, &str)>, ProtocolError> {
    if model.is_empty() {
        return Ok(None);
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
    Ok(Some((provider, model)))
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
    let selection = model_selection(model)?;
    // Role names are engine policy, not presumed server agent configuration.
    // The built-in build agent is callable; system is the exact custom field.
    let mut body = json!({"agent":"build",
        "system":format!("AI Team role: {role}.\n{instructions}"),
        "parts":[{"type":"text","text":text}]});
    if let Some((provider, model)) = selection {
        body["model"] = json!({"providerID":provider,"modelID":model});
    }
    Ok(body)
}

fn validate_openapi(doc: &Value) -> Result<(), ProtocolError> {
    let paths = doc
        .get("paths")
        .and_then(Value::as_object)
        .ok_or(ProtocolError("openapi_unconfirmed"))?;
    for (path, method, operation) in [
        ("/global/health", "get", "global.health"),
        ("/global/event", "get", "global.event"),
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
    let required = prompt
        .get("required")
        .and_then(Value::as_array)
        .ok_or(ProtocolError("openapi_unconfirmed"))?;
    if !required.iter().any(|field| field.as_str() == Some("parts"))
        || required
            .iter()
            .any(|field| !matches!(field.as_str(), Some("parts" | "agent" | "system")))
    {
        // Omission is supported only by the current callable schema. A server
        // that requires model (or another unsupplied field) is not this driver.
        return Err(ProtocolError("openapi_unconfirmed"));
    }
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
    fn empty_model_selection_omits_wire_field_and_keeps_authored_role() {
        assert!(validate_model("").is_ok());
        for (role, readonly) in [("planner", true), ("worker", false), ("checker", true)] {
            let body =
                prompt_body(role, "", "role instructions", "approved task", readonly).unwrap();
            assert!(body.get("model").is_none());
            assert_eq!(body["agent"], "build");
            assert_eq!(
                body["system"],
                format!("AI Team role: {role}.\nrole instructions")
            );
            assert_eq!(
                body["parts"],
                json!([{"type":"text","text":"approved task"}])
            );
        }
    }

    #[test]
    fn nonempty_model_preflight_and_explicit_wire_selection_agree() {
        for model in [
            "glm-5.3",
            " ",
            "/glm-5.3",
            "zai/",
            "z ai/glm-5.3",
            "zai/glm 5.3",
        ] {
            assert_eq!(validate_model(model).unwrap_err().code(), "invalid_model");
            assert_eq!(
                prompt_body("worker", model, "work", "task", false)
                    .unwrap_err()
                    .code(),
                "invalid_model"
            );
        }
        assert!(validate_model("zai/glm-5.3").is_ok());
        assert_eq!(
            prompt_body("worker", "zai/glm-5.3", "work", "task", false).unwrap()["model"],
            json!({"providerID":"zai","modelID":"glm-5.3"})
        );
    }

    fn pinned_document() -> Value {
        serde_json::from_str(include_str!(
            "../../../contracts/opencode-openapi-f12e14cf.json"
        ))
        .unwrap()
    }

    #[test]
    fn callable_prompt_contract_must_support_model_omission() {
        let mut doc = pinned_document();
        assert!(validate_openapi(&doc).is_ok());
        let prompt = doc.pointer_mut("/paths/~1session~1{sessionID}~1prompt_async/post/requestBody/content/application~1json/schema").unwrap();
        prompt["required"] = json!(["parts", "model"]);
        assert_eq!(
            validate_openapi(&doc).unwrap_err().code(),
            "openapi_unconfirmed"
        );
        for required in [
            Value::Null,
            json!(["parts", 42]),
            json!(["parts", "unknownField"]),
            json!([]),
        ] {
            doc.pointer_mut("/paths/~1session~1{sessionID}~1prompt_async/post/requestBody/content/application~1json/schema").unwrap()["required"] = required;
            assert!(validate_openapi(&doc).is_err());
        }
    }

    #[tokio::test]
    async fn invalid_explicit_model_does_not_send_any_http_request() {
        let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        listener.set_nonblocking(true).unwrap();
        let client = OpenCodeClient::new(
            &format!("http://{}", listener.local_addr().unwrap()),
            "opencode",
            "isolated-fixture",
        )
        .unwrap();
        let result = client
            .prompt(
                "/root/projects/fixture",
                "ses_test",
                "worker",
                "bad-model",
                "work",
                "task",
                false,
            )
            .await;
        assert_eq!(result.unwrap_err().code(), "invalid_model");
        assert_eq!(
            listener.accept().unwrap_err().kind(),
            std::io::ErrorKind::WouldBlock
        );
    }

    fn model_providers() -> Value {
        json!({
            "all":[
                {"id":"catalog-only","models":{"catalog-model":{"id":"catalog-model"}}},
                {"id":"zai-coding-plan","key":"fixture-provider-secret", "models":{
                    "glm-5.3":{"id":"glm-5.3"},"glm-5.3-highspeed":{"id":"glm-5.3-highspeed"}}}
            ],
            "default":{"catalog-only":"catalog-model","zai-coding-plan":"glm-5.3"},
            "connected":["zai-coding-plan"]
        })
    }

    async fn model_server(
        config: Value,
        providers: Value,
        status: axum::http::StatusCode,
    ) -> (
        OpenCodeClient,
        tokio::task::JoinHandle<()>,
        std::sync::Arc<std::sync::Mutex<Vec<(bool, String)>>>,
    ) {
        use axum::{
            http::{HeaderMap, Uri},
            routing::get,
            Json, Router,
        };
        let seen = std::sync::Arc::new(std::sync::Mutex::new(Vec::new()));
        let config_seen = seen.clone();
        let provider_seen = seen.clone();
        let record =
            |headers: HeaderMap, uri: Uri, seen: &std::sync::Mutex<Vec<(bool, String)>>| {
                // Synthetic Basic credentials only; failed assertions never dump headers.
                let authenticated = headers.get("authorization").and_then(|h| h.to_str().ok())
                    == Some("Basic b3BlbmNvZGU6aXNvbGF0ZWQtZml4dHVyZQ==");
                seen.lock().unwrap().push((authenticated, uri.to_string()));
            };
        let app = Router::new()
            .route(
                "/config",
                get(move |headers: HeaderMap, uri: Uri| {
                    record(headers, uri, &config_seen);
                    let config = config.clone();
                    async move { (status, Json(config)) }
                }),
            )
            .route(
                "/provider",
                get(move |headers: HeaderMap, uri: Uri| {
                    record(headers, uri, &provider_seen);
                    let providers = providers.clone();
                    async move { (status, Json(providers)) }
                }),
            );
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let client = OpenCodeClient::new(
            &format!("http://{}", listener.local_addr().unwrap()),
            "opencode",
            "isolated-fixture",
        )
        .unwrap();
        let server = tokio::spawn(async move {
            axum::serve(listener, app).await.unwrap();
        });
        (client, server, seen)
    }

    #[tokio::test]
    async fn omitted_model_resolves_authenticated_connected_provider_on_fresh_profile() {
        let (client, server, seen) = model_server(
            json!({"provider":{"fixture":{"options":{"apiKey":"fixture-config-secret"}}}}),
            model_providers(),
            axum::http::StatusCode::OK,
        )
        .await;
        assert_eq!(
            client
                .resolve_model("/root/projects/fresh", "")
                .await
                .unwrap(),
            "zai-coding-plan/glm-5.3"
        );
        assert_eq!(
            *seen.lock().unwrap(),
            vec![
                (true, "/config?directory=%2Froot%2Fprojects%2Ffresh".into()),
                (
                    true,
                    "/provider?directory=%2Froot%2Fprojects%2Ffresh".into()
                )
            ]
        );
        server.abort();
    }

    #[tokio::test]
    async fn configured_connected_model_precedes_provider_default() {
        let (client, server, _) = model_server(
            json!({"model":"zai-coding-plan/glm-5.3-highspeed"}),
            model_providers(),
            axum::http::StatusCode::OK,
        )
        .await;
        assert_eq!(
            client
                .resolve_model("/root/projects/fresh", "")
                .await
                .unwrap(),
            "zai-coding-plan/glm-5.3-highspeed"
        );
        server.abort();
    }

    #[tokio::test]
    async fn invalid_or_disconnected_configured_models_use_connected_default_only() {
        for configured in [
            "invalid",
            "catalog-only/catalog-model",
            "zai-coding-plan/missing",
        ] {
            let (client, server, _) = model_server(
                json!({"model":configured}),
                model_providers(),
                axum::http::StatusCode::OK,
            )
            .await;
            assert_eq!(
                client
                    .resolve_model("/root/projects/fresh", "")
                    .await
                    .unwrap(),
                "zai-coding-plan/glm-5.3"
            );
            server.abort();
        }
    }

    #[tokio::test]
    async fn missing_invalid_or_disconnected_defaults_return_typed_model_not_configured() {
        let mut cases = Vec::new();
        let mut providers = model_providers();
        providers["connected"] = json!([]);
        cases.push(providers);
        for defaults in [
            json!({}),
            json!({"zai-coding-plan":"missing"}),
            json!({"zai-coding-plan":"invalid model"}),
            json!({"zai-coding-plan":42}),
        ] {
            let mut providers = model_providers();
            providers["default"] = defaults;
            providers["all"][1]["models"]
                .as_object_mut()
                .unwrap()
                .remove("glm-5.3");
            cases.push(providers);
        }
        let mut providers = model_providers();
        providers["all"][1]["models"]["glm-5.3"]["id"] = json!("different-model");
        cases.push(providers);
        for providers in cases {
            let (client, server, _) =
                model_server(json!({}), providers, axum::http::StatusCode::OK).await;
            assert_eq!(
                client
                    .resolve_model("/root/projects/fresh", "")
                    .await
                    .unwrap_err()
                    .code(),
                "modelNotConfigured"
            );
            server.abort();
        }
    }

    #[tokio::test]
    async fn coding_plan_omission_uses_documented_standard_instead_of_highspeed_catalog_default() {
        let mut providers = model_providers();
        providers["default"]["zai-coding-plan"] = json!("glm-5.3-highspeed");
        let (client, server, _) =
            model_server(json!({}), providers.clone(), axum::http::StatusCode::OK).await;
        assert_eq!(
            client
                .resolve_model("/root/projects/fresh", "")
                .await
                .unwrap(),
            "zai-coding-plan/glm-5.3"
        );
        assert_eq!(
            client
                .resolve_model("/root/projects/fresh", "zai-coding-plan/glm-5.3-highspeed")
                .await
                .unwrap(),
            "zai-coding-plan/glm-5.3-highspeed"
        );
        server.abort();
        let (client, server, _) = model_server(
            json!({"model":"zai-coding-plan/glm-5.3-highspeed"}),
            providers.clone(),
            axum::http::StatusCode::OK,
        )
        .await;
        assert_eq!(
            client
                .resolve_model("/root/projects/fresh", "")
                .await
                .unwrap(),
            "zai-coding-plan/glm-5.3-highspeed"
        );
        server.abort();
        providers["all"][1]["models"]
            .as_object_mut()
            .unwrap()
            .remove("glm-5.3");
        let (client, server, _) =
            model_server(json!({}), providers, axum::http::StatusCode::OK).await;
        assert_eq!(
            client
                .resolve_model("/root/projects/fresh", "")
                .await
                .unwrap_err()
                .code(),
            "modelNotConfigured"
        );
        server.abort();
    }

    #[tokio::test]
    async fn explicit_model_is_preserved_without_runtime_http_and_invalid_choice_fails_locally() {
        let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        listener.set_nonblocking(true).unwrap();
        let client = OpenCodeClient::new(
            &format!("http://{}", listener.local_addr().unwrap()),
            "opencode",
            "isolated-fixture",
        )
        .unwrap();
        assert_eq!(
            client
                .resolve_model("/root/projects/fresh", "chosen/my-model")
                .await
                .unwrap(),
            "chosen/my-model"
        );
        assert_eq!(
            client
                .resolve_model("/root/projects/fresh", "invalid")
                .await
                .unwrap_err()
                .code(),
            "invalid_model"
        );
        assert_eq!(
            listener.accept().unwrap_err().kind(),
            std::io::ErrorKind::WouldBlock
        );
    }

    #[tokio::test]
    async fn model_resolution_preserves_safe_auth_and_server_failure_codes() {
        for (status, code) in [
            (
                axum::http::StatusCode::UNAUTHORIZED,
                "authentication_failed",
            ),
            (
                axum::http::StatusCode::SERVICE_UNAVAILABLE,
                "server_rejected",
            ),
        ] {
            let (client, server, seen) =
                model_server(json!({"error":"fixture-secret"}), model_providers(), status).await;
            assert_eq!(
                client
                    .resolve_model("/root/projects/fresh", "")
                    .await
                    .unwrap_err()
                    .code(),
                code
            );
            assert_eq!(seen.lock().unwrap().len(), 1);
            assert!(seen.lock().unwrap()[0].0);
            server.abort();
        }
    }

    #[tokio::test]
    async fn model_resolution_preserves_read_transport_failure() {
        let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        let client = OpenCodeClient::new(
            &format!("http://{}", listener.local_addr().unwrap()),
            "opencode",
            "isolated-fixture",
        )
        .unwrap();
        drop(listener);
        assert_eq!(
            client
                .resolve_model("/root/projects/fresh", "")
                .await
                .unwrap_err()
                .code(),
            "transport_unavailable"
        );
    }

    #[test]
    fn model_resolution_preserves_connected_order_and_never_uses_disconnected_catalog() {
        let mut providers = model_providers();
        providers["connected"] = json!(["catalog-only", "zai-coding-plan"]);
        assert_eq!(
            resolve_runtime_model(None, &providers).unwrap(),
            "catalog-only/catalog-model"
        );
        providers["connected"] = json!(["zai-coding-plan"]);
        assert_eq!(
            resolve_runtime_model(None, &providers).unwrap(),
            "zai-coding-plan/glm-5.3"
        );
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

    #[test]
    fn fallback_requires_complete_valid_known_scope() {
        assert!(known_directories(&[]).is_err());
        assert!(known_directories(&["unknown".into()]).is_err());
        assert!(known_directories(&["/ok".into(), "".into()]).is_err());
        assert_eq!(
            known_directories(&["/a".into(), "/a".into()]).unwrap(),
            vec!["/a"]
        );
        assert!(person_status_snapshot(&json!({}), &[]).unwrap());
        assert!(!person_status_snapshot(&json!({"ses_other":{"type":"busy"}}), &[]).unwrap());
        assert!(
            person_status_snapshot(&json!({"ses_team":{"type":"busy"}}), &["ses_team".into()])
                .unwrap()
        );
        assert!(!person_status_snapshot(
            &json!({"ses_retry":{"type":"retry","attempt":1,"next":123,"message":"retrying"}}),
            &[]
        )
        .unwrap());
        for malformed in [
            json!(null),
            json!([]),
            json!({"ses_other":{"type":"unknown"}}),
            json!({"ses_other":{"type":"retry"}}),
            json!({"invalid":{"type":"busy"}}),
            json!({"ses_other":{"type":"idle","unexpected":true}}),
        ] {
            assert!(person_status_snapshot(&malformed, &[]).is_err());
        }
    }

    #[test]
    fn global_fixture_parses_pinned_envelope_without_exposing_retry_text() {
        let event = parse_global_status(r#"{"directory":"/other-client","payload":{"type":"session.status","properties":{"sessionID":"ses_person","status":{"type":"retry","attempt":1,"next":123,"message":"credential-like private output"}}}}"#).unwrap();
        assert_eq!(
            event,
            GlobalStatusObservation::Status {
                directory: "/other-client".into(),
                session_id: "ses_person".into(),
                busy: true,
            }
        );
        assert_eq!(
            parse_global_status(r#"{"payload":{"type":"server.connected","properties":{}}}"#)
                .unwrap(),
            GlobalStatusObservation::Other
        );
        assert!(parse_global_status(r#"{"payload":{"type":"session.status","properties":{"sessionID":"ses_person","status":{"type":"busy"}}}}"#).is_err());
        assert!(parse_global_status(r#"{"directory":"/a","payload":{"type":"session.status","properties":{"sessionID":"ses_person","status":{"type":"unknown"}}}}"#).is_err());
    }

    #[test]
    fn split_sse_frames_multiline_crlf_and_eof_are_not_checkpoints() {
        let mut decoder = SseStatusDecoder::default();
        decoder
            .push(b": comment\r\ndata: {\"payload\":\r\ndata: {\"type\":\"server.heartbeat\"}}\r\n")
            .unwrap();
        assert!(decoder.next_event().unwrap().is_none());
        decoder.push(b"\r\n").unwrap();
        assert_eq!(
            parse_global_status(&decoder.next_event().unwrap().unwrap()).unwrap(),
            GlobalStatusObservation::Other
        );
        let mut decoder = SseStatusDecoder::default();
        decoder
            .push(b"data: {\"payload\":{\"type\":\"server.connected\"}}\n")
            .unwrap();
        assert!(decoder.next_event().unwrap().is_none());
        assert!(decoder.push(&vec![b'x'; MAX_SSE_FRAME + 1]).is_err());
    }
}
