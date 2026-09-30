use crate::{
    attestation::{self, AttestationExpectation, BoundaryTier, VerifiedBoundary},
    chat::{ChatHeartbeat, ChatLedger},
    config::{Config, ServerCredentials},
    opencode::OpenCodeClient,
    repository::RepositoryAuthority,
    store::Store,
};
use axum::{
    extract::{DefaultBodyLimit, Query, Request, State},
    http::{header, StatusCode},
    middleware::{self, Next},
    response::{IntoResponse, Response},
    routing::{delete, get, post},
    Json, Router,
};
use serde::Deserialize;
use serde_json::{json, Value};
use std::{
    fs,
    sync::{Arc, Mutex},
    time::Duration,
};
use subtle::ConstantTimeEq;

pub struct Engine {
    pub config: Config,
    pub store: Mutex<Store>,
    pub repositories: Mutex<RepositoryAuthority>,
    pub server: OpenCodeClient,
    token: Vec<u8>,
    protocol: Mutex<Value>,
    pub(crate) chat: tokio::sync::RwLock<ChatLedger>,
    pub(crate) observer_connected: Mutex<bool>,
    pub(crate) parent_pid: i32,
    lane_admission: tokio::sync::Mutex<()>,
    boundary: Option<BoundaryAuthority>,
    deleting: std::sync::atomic::AtomicBool,
}
type Shared = Arc<Engine>;
#[derive(Debug)]
struct ApiError(StatusCode, &'static str);
impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        (self.0, Json(json!({"code":self.1}))).into_response()
    }
}
fn internal(code: &'static str) -> ApiError {
    ApiError(StatusCode::CONFLICT, code)
}

pub async fn serve(config: Config, pins: Option<LaunchPins>) -> Result<(), &'static str> {
    let token = fs::read_to_string(&config.auth_token_file).map_err(|_| "authUnavailable")?;
    let token = token.trim().as_bytes().to_vec();
    if token.len() != 64 || !token.iter().all(u8::is_ascii_hexdigit) {
        return Err("authInvalid");
    }
    let raw = fs::read(&config.oc1_credential_file).map_err(|_| "serverCredentialsUnavailable")?;
    let credentials: ServerCredentials =
        serde_json::from_slice(&raw).map_err(|_| "serverCredentialsInvalid")?;
    let server = OpenCodeClient::new(
        &config.oc1_base_url,
        &credentials.username,
        &credentials.password,
    )
    .map_err(|_| "serverConfigInvalid")?;
    let store = Store::open(&config.private_root.join("data"), &config.profile_id)
        .map_err(|_| "storeUnavailable")?;
    store.recover().map_err(|_| "recoveryFailed")?;
    let repositories = RepositoryAuthority::new(
        config.private_root.join("repos"),
        config.worker_root.clone(),
    )
    .map_err(|_| "repositoryUnavailable")?;
    let boundary = BoundaryAuthority::start(&config, pins);
    let chat = crate::admission::load_directories(&config);
    let engine = Arc::new(Engine {
        boundary,
        deleting: std::sync::atomic::AtomicBool::new(false),
        lane_admission: tokio::sync::Mutex::new(()),
        chat: tokio::sync::RwLock::new(chat),
        observer_connected: Mutex::new(false),
        parent_pid: unsafe { libc::getppid() },
        config,
        store: Mutex::new(store),
        repositories: Mutex::new(repositories),
        server,
        token,
        protocol: Mutex::new(
            json!({"capabilities":{"execution":false},"blockers":["protocolUnverified"]}),
        ),
    });
    let address = std::net::SocketAddr::from(([127, 0, 0, 1], engine.config.port));
    let listener = tokio::net::TcpListener::bind(address)
        .await
        .map_err(|_| "listenUnavailable")?;
    // The private child pipe introduces its already-bound listener before
    // native sends any bearer token over loopback.
    crate::startup::publish_ready(
        listener
            .local_addr()
            .map_err(|_| "listenUnavailable")?
            .port(),
        &engine.config.profile_id,
        std::str::from_utf8(&engine.token).map_err(|_| "authInvalid")?,
    )?;
    let task_engine = engine.clone();
    let background = tokio::spawn(async move { reconcile(task_engine).await });
    let observer = tokio::spawn(crate::admission::observe(engine.clone()));
    let result = axum::serve(listener, router(engine.clone()))
        .with_graceful_shutdown(shutdown())
        .await;
    background.abort();
    observer.abort();
    // On graceful shutdown, mark unfinished operations interrupted durably.
    // A hard process death is recovered by the same reconcile on next startup.
    if let Ok(store) = engine.store.lock() {
        let _ = store.recover();
    }
    result.map_err(|_| "serverStopped")
}
async fn shutdown() {
    #[cfg(unix)]
    {
        let mut term = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("signal handler");
        tokio::select! { _ = term.recv() => {}, _ = tokio::signal::ctrl_c() => {} }
    }
    #[cfg(not(unix))]
    {
        let _ = tokio::signal::ctrl_c().await;
    }
}
pub fn router(engine: Shared) -> Router {
    Router::new()
        .route("/v1/health", get(health))
        .route("/v1/workspace", get(workspace))
        .route("/v1/commands", post(command))
        .route("/v1/chatBusy", post(chat_busy))
        .route("/v1/events", get(events))
        .route("/v1/profile", delete(delete_profile))
        .route_layer(middleware::from_fn_with_state(engine.clone(), authorize))
        .layer(DefaultBodyLimit::max(1024 * 1024))
        .with_state(engine)
}
async fn authorize(State(engine): State<Shared>, request: Request, next: Next) -> Response {
    // Never put auth material in routes, debug output, errors or redirects.
    let supplied = request
        .headers()
        .get(header::AUTHORIZATION)
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
        .unwrap_or("")
        .as_bytes();
    if supplied.len() != engine.token.len() || !bool::from(supplied.ct_eq(&engine.token)) {
        return (
            StatusCode::UNAUTHORIZED,
            Json(json!({"code":"unauthorized"})),
        )
            .into_response();
    }
    let mut response = next.run(request).await;
    response
        .headers_mut()
        .insert(header::CACHE_CONTROL, "no-store".parse().unwrap());
    response
}
const STORE_ACTIONS: &[&str] = &[
    "createProject",
    "createQuickTask",
    "saveSpecDraft",
    "approveSpec",
    "approvePlan",
    "updateDefaults",
    "updateSettings",
    "pauseProject",
    "resumeProject",
    "stopProject",
    "pauseTask",
    "resumeTask",
    "stopTask",
    "acknowledgeDigest",
    "deleteProject",
    "saveRole",
    "deleteRole",
    "updateServer",
];
pub struct LaunchPins {
    pub trusted_public_key_sha256: String,
    pub generation: String,
    pub policy_sha256: String,
}
struct BoundaryAuthority {
    pins: LaunchPins,
    parent: i32,
    executable: std::path::PathBuf,
    receipt: VerifiedBoundary,
}
impl BoundaryAuthority {
    fn expectation<'a>(&'a self, config: &'a Config) -> Option<AttestationExpectation<'a>> {
        if config.boundary.generation.as_deref() != Some(&self.pins.generation) {
            return None;
        }
        let receipt_file = config.boundary.receipt_file.as_deref()?;
        let public_key_file = config.boundary.public_key_file.as_deref()?;
        for file in [receipt_file, public_key_file] {
            if !file.is_absolute() || !file.starts_with(&config.private_root) {
                return None;
            }
        }
        Some(AttestationExpectation {
            receipt_file,
            public_key_file,
            profile_id: &config.profile_id,
            generation: &self.pins.generation,
            trusted_public_key_sha256: &self.pins.trusted_public_key_sha256,
            expected_parent_pid: self.parent,
            executable_path: &self.executable,
            expected_policy_sha256: &self.pins.policy_sha256,
        })
    }
    fn start(config: &Config, pins: Option<LaunchPins>) -> Option<Self> {
        let pins = pins?;
        let executable = std::env::current_exe().ok()?;
        let mut authority = Self {
            pins,
            parent: unsafe { libc::getppid() },
            executable,
            receipt: VerifiedBoundary {
                tier: BoundaryTier::Landlock,
                generation: String::new(),
                policy_sha256: String::new(),
                receipt_sha256: String::new(),
            },
        };
        authority.receipt = attestation::verify(&authority.expectation(config)?).ok()?;
        Some(authority)
    }
}
fn boundary_verified(e: &Engine) -> bool {
    boundary_tier(e).is_some()
}
fn boundary_tier(e: &Engine) -> Option<BoundaryTier> {
    e.boundary
        .as_ref()
        .and_then(|b| {
            b.expectation(&e.config)
                .and_then(|expected| attestation::verify_current(&expected, &b.receipt).ok())
        })
        .map(|receipt| receipt.tier)
}
fn execution_enabled(engine: &Engine) -> bool {
    !engine.deleting.load(std::sync::atomic::Ordering::SeqCst)
        && boundary_verified(engine)
        && engine.protocol.lock().ok().is_some_and(|p| {
            p["capabilities"]["executionDriver"] == true
                && p["pinnedVersion"] == true
                && p["openapiVerified"] == true
        })
}
async fn chat_busy(
    State(e): State<Shared>,
    input: Result<Json<ChatHeartbeat>, axum::extract::rejection::JsonRejection>,
) -> Result<Json<Value>, ApiError> {
    let Json(heartbeat) = input.map_err(|_| internal("heartbeatInvalid"))?;
    Ok(Json(
        crate::admission::accept(&e, heartbeat)
            .await
            .map_err(internal)?,
    ))
}
fn command_actions(e: &Engine) -> Vec<&'static str> {
    let mut actions: Vec<_> = STORE_ACTIONS
        .iter()
        .copied()
        .filter(|action| {
            boundary_verified(e) || !matches!(*action, "createProject" | "createQuickTask")
        })
        .collect();
    if execution_enabled(e) {
        actions.push("promote");
    }
    actions
}
async fn health(State(e): State<Shared>) -> Json<Value> {
    let verified_tier = boundary_tier(&e);
    let tier = verified_tier.map_or("none", BoundaryTier::as_str);
    let protocol = e.protocol.lock().map(|v| v.clone()).unwrap_or(json!({}));
    let ledger = e.chat.read().await;
    let admission = crate::admission::label(ledger.admission(
        crate::admission::now_ms(),
        crate::admission::app_alive(&e),
        &team_sessions(&e),
    ));
    Json(
        json!({"schemaVersion":1,"engineVersion":env!("CARGO_PKG_VERSION"),"profileId":e.config.profile_id,"boundaryTier":tier,
        "capabilities":{"execution":execution_enabled(&e),"boundary":verified_tier.is_some(),"boundaryTier":tier,
            "oc1Verified":protocol["pinnedVersion"] == true && protocol["openapiVerified"] == true,"oc2":false},
        "commandActions":command_actions(&e),"boundaryReason":if verified_tier.is_some() {"boundary_attested"} else if e.boundary.is_some() {"attestation_rejected"} else {e.config.boundary.reason.as_str()},
        "readinessReason":readiness_reason(&e),"restartRequired":e.config.boundary.restart_required,
        "admission":admission,"chatAuthority":"phoneAppAndKnownDirectories","globalAdmissionAuthority":false,
        "boundaryGeneration":e.boundary.as_ref().map(|b|b.pins.generation.as_str()),"eventWindow":e.store.lock().ok().and_then(|store|store.event_window().ok()),"chargingTelemetry":false,"protocol":protocol}),
    )
}
fn protocol_driver_ready(protocol: &Value) -> bool {
    protocol["pinnedVersion"] == true
        && protocol["openapiVerified"] == true
        && protocol["capabilities"]["executionDriver"] == true
}
fn protocol_driver_reason(protocol: &Value) -> &str {
    if protocol_driver_ready(protocol) {
        ""
    } else {
        protocol["error"].as_str().unwrap_or("protocolUnverified")
    }
}
fn readiness_reason(e: &Engine) -> String {
    if boundary_tier(e).is_none() {
        return "boundaryUnavailable".into();
    }
    e.protocol
        .lock()
        .map(|p| protocol_driver_reason(&p).to_owned())
        .unwrap_or_else(|_| "protocolUnverified".into())
}
fn protocol_retry_delay(protocol: &Value) -> Duration {
    Duration::from_secs(if protocol_driver_ready(protocol) {
        30
    } else {
        2
    })
}
async fn workspace(State(e): State<Shared>) -> Result<Json<Value>, ApiError> {
    let mut workspace = e
        .store
        .lock()
        .map_err(|_| internal("storeUnavailable"))?
        .workspace()
        .map_err(|_| internal("storeUnavailable"))?;
    let protocol = e.protocol.lock().map(|p| p.clone()).unwrap_or(json!({}));
    let ledger = e.chat.read().await;
    let admission = ledger.admission(
        crate::admission::now_ms(),
        crate::admission::app_alive(&e),
        &team_sessions(&e),
    );
    if let Some(servers) = workspace["servers"].as_array_mut() {
        for server in servers.iter_mut().filter(|s| s["id"] == "phone") {
            server["online"] = json!(protocol_driver_ready(&protocol));
            server["chatWaiting"] = json!(admission != crate::chat::ChatAdmission::Idle);
            server["reason"] = json!(if !protocol_driver_ready(&protocol) {
                protocol_driver_reason(&protocol)
            } else {
                match admission {
                    crate::chat::ChatAdmission::Busy => "chatBusy",
                    crate::chat::ChatAdmission::Idle => "",
                    _ => "chatStatusUnknown",
                }
            });
        }
    }
    Ok(Json(workspace))
}
#[derive(Deserialize)]
struct EventQuery {
    #[serde(default)]
    after: i64,
    #[serde(default = "event_limit")]
    limit: usize,
}
fn event_limit() -> usize {
    100
}
async fn events(
    State(e): State<Shared>,
    Query(q): Query<EventQuery>,
) -> Result<Response, ApiError> {
    if q.after < 0 || q.limit == 0 || q.limit > 500 {
        return Err(internal("queryInvalid"));
    }
    let s = e.store.lock().map_err(|_| internal("storeUnavailable"))?;
    match s.events(q.after, q.limit) {
        Ok(mut items) => {
            for item in &mut items {
                item["type"] = item["kind"].clone();
            }
            Ok(Json(json!(items)).into_response())
        }
        Err(error) if error.code() == "cursorExpired" => Ok((
            StatusCode::CONFLICT,
            Json(json!({"code":"cursorExpired","resetRequired":true,
                "eventWindow":s.event_window().map_err(|_|internal("storeUnavailable"))?})),
        )
            .into_response()),
        Err(_) => Err(internal("storeUnavailable")),
    }
}
async fn command(
    State(e): State<Shared>,
    input: Result<Json<Value>, axum::extract::rejection::JsonRejection>,
) -> Result<Json<Value>, ApiError> {
    let Json(mut c) = input.map_err(|_| internal("commandInvalid"))?;
    // Serialize command-side imports and sweeps with starting reservations.
    let _command_fence = e.lane_admission.lock().await;
    let action_value = c["action"]
        .as_str()
        .ok_or(internal("commandInvalid"))?
        .to_owned();
    let action = action_value.as_str();
    if action == "promote" {
        if !execution_enabled(&e) {
            return Err(internal("executionUnavailable"));
        }
        if c["confirmed"] != true {
            return Err(internal("confirmationRequired"));
        }
        let store = e.store.lock().map_err(|_| internal("storeUnavailable"))?;
        let state = store
            .workspace()
            .map_err(|_| internal("storeUnavailable"))?;
        let project = state["projects"]
            .as_array()
            .and_then(|ps| ps.iter().find(|p| p["id"] == c["projectId"]))
            .ok_or(internal("projectMissing"))?;
        let replay = project["receipts"]
            .as_array()
            .is_some_and(|rs| rs.iter().any(|r| r["id"] == c["requestId"]));
        if !replay && c["expectedRevision"] != project["revision"] {
            return Err(internal("staleRevision"));
        }
        let repos = project["repos"].as_array().ok_or(internal("repoInvalid"))?;
        if repos.len() != 1 {
            return Err(internal("crossRepoPromotionUnavailable"));
        }
        let repo_id = repos[0]["id"].as_str().ok_or(internal("repoInvalid"))?;
        if c["targetId"].as_str().unwrap_or("").is_empty() {
            c["targetId"] = json!(repo_id);
        }
        if c["targetId"] != repo_id {
            return Err(internal("repoInvalid"));
        }
        if let Some(result) = store
            .command_result(&c)
            .map_err(|error| internal(error.code()))?
        {
            return Ok(Json(result));
        }
        let receipt = e
            .repositories
            .lock()
            .map_err(|_| internal("repositoryUnavailable"))?
            .promote(
                repo_id,
                c["expectedDevCommit"].as_str().unwrap_or(""),
                c["expectedMainCommit"].as_str().unwrap_or(""),
                true,
                c["requestId"].as_str().unwrap_or(""),
            )
            .map_err(|error| internal(error.code()))?;
        return Ok(Json(
            store
                .record_promotion(&c, &receipt)
                .map_err(|_| internal("receiptUncertain"))?,
        ));
    }
    if !STORE_ACTIONS.contains(&action) {
        // A promotion/merge can only enter via reviewed, typed authority calls.
        // No generic shell, ref update or unauthenticated write endpoint exists.
        return Ok(Json(
            json!({"accepted":false,"code":"unsupported","projectId":c["projectId"],"revision":0,"replayed":false}),
        ));
    }
    let previous_result = {
        let store = e.store.lock().map_err(|_| internal("storeUnavailable"))?;
        store
            .command_result(&c)
            .map_err(|error| internal(error.code()))?
    };
    if let Some(result) = previous_result {
        let mut result = result;
        if action == "deleteProject" && result["accepted"] == true {
            result["cleanupPending"] = json!(collect_unused_repositories(&e).is_err());
        }
        return Ok(Json(result));
    }
    {
        let store = e.store.lock().map_err(|_| internal("storeUnavailable"))?;
        if store.validate_command(&c).is_err() {
            // Persist the rejection before touching canonical storage.
            return Ok(Json(
                store.execute(&c).map_err(|error| internal(error.code()))?,
            ));
        }
    }
    let mut imported = vec![];
    if matches!(action, "createProject" | "createQuickTask") {
        // Never put canonical Git authority beside an unconfined legacy
        // server. Disabled scheduling alone cannot protect raw refs on disk.
        if !boundary_verified(&e) {
            return Err(internal("boundaryUnavailable"));
        }
        imported = match import_requested_repositories(&e, &c) {
            Ok(value) => value,
            Err(error) => {
                let _ = collect_unused_repositories(&e);
                return Err(error);
            }
        };
    }
    // Capture sessions before deleteProject removes its durable jobs.
    let interrupted_jobs = if matches!(
        action,
        "pauseProject" | "stopProject" | "pauseTask" | "stopTask" | "deleteProject"
    ) {
        e.store
            .lock()
            .map_err(|_| internal("storeUnavailable"))?
            .jobs()
            .map_err(|_| internal("storeUnavailable"))?
    } else {
        vec![]
    };
    let result = {
        let store = e.store.lock().map_err(|_| internal("storeUnavailable"))?;
        if imported.is_empty() {
            store.execute(&c)
        } else {
            store.execute_with_repositories(&c, &json!(imported))
        }
        .map_err(|error| internal(error.code()))?
    };
    if result["accepted"] == true
        && matches!(
            action,
            "pauseProject" | "stopProject" | "pauseTask" | "stopTask" | "deleteProject"
        )
    {
        for job in interrupted_jobs.iter().filter(|j| {
            j["projectId"] == c["projectId"]
                && (!matches!(action, "pauseTask" | "stopTask") || j["taskId"] == c["targetId"])
        }) {
            if let (Some(directory), Some(ids)) =
                (job["directory"].as_str(), job["sessionIds"].as_object())
            {
                for id in ids.values().filter_map(Value::as_str) {
                    let _ = e.server.abort(directory, id).await;
                }
            }
        }
    }
    let mut result = result;
    if action == "deleteProject" && result["accepted"] == true
        || matches!(action, "createProject" | "createQuickTask") && result["accepted"] != true
    {
        // A durable accepted delete stays accepted even if storage cleanup
        // needs a retry; never invite a duplicate command after committing it.
        result["cleanupPending"] = json!(collect_unused_repositories(&e).is_err());
    }
    Ok(Json(result))
}
fn collect_unused_repositories(e: &Engine) -> Result<Value, ApiError> {
    let store = e.store.lock().map_err(|_| internal("storeUnavailable"))?;
    let workspace = store
        .workspace()
        .map_err(|_| internal("storeUnavailable"))?;
    let retained: Vec<String> = workspace["projects"]
        .as_array()
        .ok_or(internal("storeUnavailable"))?
        .iter()
        .flat_map(|p| p["repos"].as_array().into_iter().flatten())
        .filter_map(|r| r["id"].as_str().map(str::to_owned))
        .collect();
    e.repositories
        .lock()
        .map_err(|_| internal("repositoryUnavailable"))?
        .collect_unreferenced_repositories(&retained)
        .map_err(|_| internal("repositoryCleanupPending"))
}
fn import_requested_repositories(e: &Engine, c: &Value) -> Result<Vec<Value>, ApiError> {
    let repos = c["repos"].as_array().ok_or(internal("reposRequired"))?;
    if repos.is_empty() || repos.len() > 32 {
        return Err(internal("reposRequired"));
    }
    let mut imported = Vec::new();
    for repo in repos {
        let id = repo["id"].as_str().ok_or(internal("repoInvalid"))?;
        let source = e
            .config
            .source_path(repo["path"].as_str().ok_or(internal("repoInvalid"))?)
            .map_err(internal)?;
        let refs = e
            .repositories
            .lock()
            .map_err(|_| internal("repositoryUnavailable"))?
            .import_repo_for_request(
                id,
                &source,
                c["requestId"]
                    .as_str()
                    .ok_or(internal("requestIdRequired"))?,
            )
            .map_err(|error| internal(error.code()))?;
        let mut edited = repo.clone();
        edited["devCommit"] = refs["devCommit"].clone();
        edited["mainCommit"] = refs["mainCommit"].clone();
        imported.push(edited);
    }
    Ok(imported)
}
async fn delete_profile(State(e): State<Shared>) -> Result<Json<Value>, ApiError> {
    e.deleting.store(true, std::sync::atomic::Ordering::SeqCst);
    let _dispatch_fence = e.chat.write().await;
    // Store deletion is a durable tombstone, serialized with every job write.
    // Native owner stops processes and sweeps canonical/worker files afterward.
    let jobs = e
        .store
        .lock()
        .map_err(|_| internal("storeUnavailable"))?
        .jobs()
        .or_else(|error| {
            if error.code() == "profileDeleted" {
                Ok(vec![])
            } else {
                Err(error)
            }
        })
        .map_err(|_| internal("storeUnavailable"))?;
    e.store
        .lock()
        .map_err(|_| internal("storeUnavailable"))?
        .delete_profile()
        .map_err(|_| internal("deleteFailed"))?;
    for job in jobs {
        if let (Some(directory), Some(ids)) =
            (job["directory"].as_str(), job["sessionIds"].as_object())
        {
            for id in ids.values().filter_map(Value::as_str) {
                let _ = e.server.abort(directory, id).await;
            }
        }
    }
    Ok(Json(json!({"deleted":true})))
}
async fn reconcile(e: Shared) {
    let mut ticks = tokio::time::interval(Duration::from_secs(2));
    let mut active = std::collections::HashSet::new();
    let mut tasks = tokio::task::JoinSet::new();
    let mut next_verify = tokio::time::Instant::now();
    loop {
        ticks.tick().await;
        if e.deleting.load(std::sync::atomic::Ordering::SeqCst) {
            let tombstoned = e
                .store
                .lock()
                .ok()
                .and_then(|store| store.workspace().err())
                .is_some_and(|error| error.code() == "profileDeleted");
            if tombstoned {
                tasks.abort_all();
                while tasks.join_next().await.is_some() {}
                return;
            }
            // DELETE is still waiting for the dispatch fence. Cancelling a
            // request before its ACK could let it start after an early abort.
            continue;
        }
        while let Some(result) = tasks.try_join_next() {
            if let Ok(id) = result {
                active.remove(&id);
            }
        }
        if tokio::time::Instant::now() >= next_verify {
            let protocol = e.server.verify().await.unwrap_or_else(|error| json!({"capabilities":{"executionDriver":false,"execution":false},"error":error.code(),"blockers":[error.code()]}));
            let retry_delay = protocol_retry_delay(&protocol);
            if let Ok(mut value) = e.protocol.lock() {
                *value = protocol;
            }
            next_verify = tokio::time::Instant::now() + retry_delay;
        }
        crate::admission::reconcile_busy(&e).await;
        let jobs = e
            .store
            .lock()
            .ok()
            .and_then(|s| s.jobs().ok())
            .unwrap_or_default();
        for job in jobs {
            let id = job["id"].as_str().unwrap_or("").to_owned();
            if id.is_empty()
                || active.contains(&id)
                || !matches!(job["stage"].as_str(), Some("queued" | "resuming"))
            {
                continue;
            }
            if !execution_enabled(&e) {
                let reason = readiness_reason(&e);
                if job["reason"] != reason {
                    if let Ok(s) = e.store.lock() {
                        let _ = s.update_job(
                            &id,
                            job["stage"].as_str().unwrap_or("queued"),
                            &json!({"reason":reason}),
                        );
                    }
                }
                continue;
            }
            let ledger = e.chat.read().await;
            if !crate::admission::idle(&e, &ledger).await.unwrap_or(false) {
                let reason = if ledger.admission(
                    crate::admission::now_ms(),
                    crate::admission::app_alive(&e),
                    &team_sessions(&e),
                ) == crate::chat::ChatAdmission::Busy
                {
                    "chatBusy"
                } else {
                    "chatStatusUnknown"
                };
                drop(ledger);
                if job["reason"] != reason && job["stage"] == "queued" {
                    if let Ok(store) = e.store.lock() {
                        let _ = store.update_job(&id, "queued", &json!({"reason":reason}));
                    }
                }
                continue;
            }
            drop(ledger);
            // The native proof and protocol admission prerequisites are checked
            // again at every stage. No SSE event is treated as completion.
            active.insert(id.clone());
            let owned = e.clone();
            tasks.spawn(async move {
                let _ = run_job(owned, job).await;
                id
            });
        }
    }
}
pub(crate) fn team_sessions(e: &Engine) -> Vec<String> {
    e.store
        .lock()
        .ok()
        .and_then(|s| s.jobs().ok())
        .unwrap_or_default()
        .iter()
        .flat_map(|j| {
            j["sessionIds"]
                .as_object()
                .into_iter()
                .flat_map(|o| o.values())
        })
        .filter_map(|v| v.as_str().map(str::to_owned))
        .collect()
}
async fn stage_admitted(e: &Engine, requested: &Value) -> Result<(), &'static str> {
    if !execution_enabled(e) {
        return Err("executionUnavailable");
    }
    loop {
        let ledger = e.chat.read().await;
        let result = stage_admitted_with_ledger(e, requested, &ledger).await;
        drop(ledger);
        if !matches!(result, Err("chatBusy" | "chatStatusUnknown")) {
            return result;
        }
        // Keep the durable checkpoint. Waiting for the person's reply must not
        // resubmit the worker or turn an already finished worker into an error.
        tokio::time::sleep(Duration::from_secs(2)).await;
    }
}
async fn stage_admitted_with_ledger(
    e: &Engine,
    requested: &Value,
    ledger: &ChatLedger,
) -> Result<(), &'static str> {
    if e.deleting.load(std::sync::atomic::Ordering::SeqCst) {
        return Err("profileDeleted");
    }
    if !execution_enabled(e) {
        return Err("executionUnavailable");
    }
    {
        let store = e.store.lock().map_err(|_| "storeUnavailable")?;
        let jobs = store.jobs().map_err(|_| "storeUnavailable")?;
        let current = jobs
            .iter()
            .find(|j| j["id"] == requested["id"])
            .ok_or("jobMissing")?;
        if matches!(
            current["stage"].as_str(),
            Some("paused" | "stopped" | "interrupted" | "failed")
        ) {
            return Err("jobNotActive");
        }
    }
    let idle = crate::admission::idle(e, ledger).await?;
    let store = e.store.lock().map_err(|_| "storeUnavailable")?;
    let state = store.workspace().map_err(|_| "storeUnavailable")?;
    let jobs = store.jobs().map_err(|_| "storeUnavailable")?;
    let current = jobs
        .iter()
        .find(|j| j["id"] == requested["id"])
        .ok_or("jobMissing")?;
    if matches!(
        current["stage"].as_str(),
        Some("paused" | "stopped" | "interrupted" | "failed")
    ) {
        return Err("jobNotActive");
    }
    let project = state["projects"]
        .as_array()
        .and_then(|ps| ps.iter().find(|p| p["id"] == current["projectId"]))
        .ok_or("projectMissing")?;
    let mut project = project.clone();
    let project_jobs: Vec<&Value> = jobs
        .iter()
        .filter(|j| j["projectId"] == current["projectId"])
        .collect();
    let never_dispatched = project_jobs.iter().all(|j| {
        j["sessionIds"]
            .as_object()
            .is_some_and(|ids| ids.is_empty())
    });
    let observed_cost = project_jobs.iter().try_fold(0.0, |sum, j| {
        if j["sessionIds"]
            .as_object()
            .is_some_and(|ids| ids.is_empty())
        {
            Some(sum)
        } else {
            j["usage"]["cost"].as_f64().map(|v| sum + v)
        }
    });
    if never_dispatched {
        project["spendDay"] = json!(utc_day());
    }
    let others: Vec<Value> = jobs
        .iter()
        .filter(|j| j["id"] != current["id"])
        .cloned()
        .collect();
    let mut candidate = current.clone();
    candidate["stage"] = json!("queued");
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_err(|_| "clockUnknown")?
        .as_millis() as u64;
    let context = crate::scheduler::AdmissionContext {
        now_ms: now,
        chat_idle: Some(idle),
        chat_observed_ms: Some(now),
        chat_max_age_ms: 5000,
        charging: None,
        server_online: true,
        lane_cap: 32,
        utc_day: utc_day(),
        observed_total_cost: observed_cost,
        observed_daily_cost: if never_dispatched {
            Some(0.0)
        } else if project["usageReported"] == true {
            project["spentToday"].as_f64()
        } else {
            None
        },
        observed_task_tokens: if current["sessionIds"]
            .as_object()
            .is_some_and(|ids| ids.is_empty())
        {
            Some(0)
        } else {
            current["usage"]["tokens"].as_u64()
        },
    };
    match crate::scheduler::evaluate(&project, &candidate, &others, &context) {
        crate::scheduler::Admission::Admit => Ok(()),
        crate::scheduler::Admission::Wait(code) | crate::scheduler::Admission::Pause(code) => {
            Err(code)
        }
    }
}
#[allow(clippy::too_many_arguments)]
async fn admitted_prompt(
    e: &Engine,
    job: &Value,
    directory: &str,
    session: &str,
    role: &str,
    model: &str,
    instructions: &str,
    prompt: &str,
    checkpoint_role: &str,
    read_only: bool,
) -> Result<(), &'static str> {
    crate::opencode::validate_model(model).map_err(|error| error.code())?;
    if instructions.is_empty() || prompt.is_empty() {
        return Err("invalid_role");
    }
    loop {
        let ledger = e.chat.read().await;
        // Hold through actual HTTP dispatch, never while waiting for the person.
        match stage_admitted_with_ledger(e, job, &ledger).await {
            Err("chatBusy" | "chatStatusUnknown") => {
                drop(ledger);
                tokio::time::sleep(Duration::from_secs(2)).await;
            }
            Err(code) => return Err(code),
            Ok(()) => {
                let id = job["id"].as_str().ok_or("jobInvalid")?;
                record_dispatch(e, id, checkpoint_role, "dispatching")?;
                let dispatch = tokio::time::timeout(
                    Duration::from_secs(5),
                    e.server.prompt(
                        directory,
                        session,
                        role,
                        model,
                        instructions,
                        prompt,
                        read_only,
                    ),
                )
                .await;
                drop(ledger);
                if active_stage(e, id).is_err() {
                    let _ = e.server.abort(directory, session).await;
                    return Err("jobNotActive");
                }
                match dispatch {
                    Ok(Ok(_)) => {
                        if record_dispatch(e, id, checkpoint_role, "dispatched").is_err() {
                            let _ = e.server.abort(directory, session).await;
                            return Err("jobNotActive");
                        }
                        return Ok(());
                    }
                    Ok(Err(error)) if error.code() != "transport_uncertain" => {
                        return Err(error.code())
                    }
                    _ => return Err("promptUncertain"),
                }
            }
        }
    }
}
fn active_stage(e: &Engine, id: &str) -> Result<String, &'static str> {
    if e.deleting.load(std::sync::atomic::Ordering::SeqCst) {
        return Err("profileDeleted");
    }
    let store = e.store.lock().map_err(|_| "storeUnavailable")?;
    let jobs = store.jobs().map_err(|_| "jobChanged")?;
    let stage = jobs
        .iter()
        .find(|j| j["id"] == id)
        .and_then(|j| j["stage"].as_str())
        .ok_or("jobChanged")?;
    if matches!(
        stage,
        "paused" | "stopped" | "interrupted" | "failed" | "completed"
    ) {
        return Err("jobNotActive");
    }
    Ok(stage.to_owned())
}
fn record_dispatch(e: &Engine, id: &str, role: &str, state: &str) -> Result<(), &'static str> {
    let stage = active_stage(e, id)?;
    patch(e, id, &stage, json!({"promptDispatch":{role:state}})).map(|_| ())
}
fn utc_day() -> String {
    #[cfg(unix)]
    {
        let seconds = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs() as libc::time_t;
        let mut time = std::mem::MaybeUninit::<libc::tm>::uninit();
        if unsafe { libc::gmtime_r(&seconds, time.as_mut_ptr()) }.is_null() {
            return String::new();
        }
        let time = unsafe { time.assume_init() };
        format!(
            "{:04}-{:02}-{:02}",
            time.tm_year + 1900,
            time.tm_mon + 1,
            time.tm_mday
        )
    }
    #[cfg(not(unix))]
    {
        String::new()
    }
}

fn patch(e: &Engine, id: &str, stage: &str, value: Value) -> Result<Value, &'static str> {
    e.store
        .lock()
        .map_err(|_| "storeUnavailable")?
        .update_job(id, stage, &value)
        .map_err(|error| error.code())
}
async fn run_job(e: Shared, job: Value) -> Result<(), &'static str> {
    let result = task_pipeline(&e, &job).await;
    if let Err(reason) = result {
        let id = job["id"].as_str().ok_or("jobInvalid")?;
        if let Ok(s) = e.store.lock() {
            if let Ok(jobs) = s.jobs() {
                if let Some(current) = jobs.iter().find(|j| j["id"] == id) {
                    let stage = current["stage"].as_str().unwrap_or("unknown");
                    if stage == "queued"
                        && matches!(
                            reason,
                            "laneCap"
                                | "dependencyPending"
                                | "projectNotRunning"
                                | "chatBusy"
                                | "chatStatusUnknown"
                        )
                    {
                        let _ = s.update_job(id, stage, &json!({"reason":reason}));
                    } else if !matches!(stage, "completed" | "stopped" | "paused") {
                        let _ = s.update_job(
                            id,
                            stage,
                            &json!({"stage":"interrupted","reason":reason}),
                        );
                    }
                }
            }
        }
    }
    result
}
async fn task_pipeline(e: &Engine, job: &Value) -> Result<(), &'static str> {
    let id = job["id"].as_str().ok_or("jobInvalid")?;
    crate::opencode::validate_model(job["model"].as_str().ok_or("invalid_model")?)
        .map_err(|error| error.code())?;
    if job["instructions"].as_str().is_none_or(str::is_empty) {
        return Err("invalid_role");
    }
    if job["kind"] != "planner" {
        crate::opencode::validate_model(
            job["checkerRole"]["model"]
                .as_str()
                .ok_or("checkerRoleMissing")?,
        )
        .map_err(|error| error.code())?;
    }
    let task = job["taskId"]
        .as_str()
        .filter(|s| !s.is_empty())
        .unwrap_or(id);
    let repo = job["repoId"].as_str().ok_or("repoInvalid")?;
    stage_admitted(e, job).await?;
    if job["stage"] == "resuming" {
        return resume_job(e, job).await;
    }
    {
        // The durable starting reservation and cap check are one serialized
        // admission. Concurrent queued futures cannot both take the last lane.
        let _reservation = e.lane_admission.lock().await;
        stage_admitted(e, job).await?;
        patch(e, id, "queued", json!({"stage":"starting"}))?;
    }
    if !undispatched_clone_allowed(job) {
        return Err("recoveryNeedsReview");
    }
    let work = e
        .repositories
        .lock()
        .map_err(|_| "repositoryUnavailable")?
        .prepare_fresh_worker(repo, task)
        .map_err(|_| "workerCloneFailed")?;
    let directory = format!("{}/{}/{}", e.config.guest_worker_root, repo, task);
    let dev = work["devCommit"].as_str().ok_or("repoInvalid")?;
    let planner = job["kind"] == "planner";
    let role = if planner {
        "planner"
    } else {
        job["roleId"].as_str().unwrap_or("worker")
    };
    let instructions = job["instructions"].as_str().unwrap_or("");
    let model = job["model"].as_str().unwrap_or("");
    let session = e
        .server
        .create_session(&directory, role)
        .await
        .map_err(|_| "sessionCreateUncertain")?;
    let sessions = if planner {
        json!({"planner":session})
    } else {
        json!({"worker":session})
    };
    if patch(
        e,
        id,
        "starting",
        json!({"stage":"running","directory":directory,"sessionIds":sessions,"expectedDevCommit":dev}),
    ).is_err() {
        let _ = e.server.abort(&directory, &session).await;
        return Err("jobChanged");
    }
    stage_admitted(e, job).await?;
    let request = if planner {
        planner_request(job)
    } else {
        format!("Implement this task on branch {}. Keep edits in this isolated clone. Commit completed changes to that task branch, without editing main or dev. Acceptance criteria: {}. Task: {}",work["branch"],job["criteria"],job["title"])
    };
    admitted_prompt(
        e,
        job,
        &directory,
        &session,
        role,
        model,
        instructions,
        &request,
        if planner { "planner" } else { "worker" },
        planner || job["readOnly"] == true,
    )
    .await?;
    let output = await_completion(
        e,
        id,
        if planner { "planner" } else { "worker" },
        &directory,
        &session,
    )
    .await?;
    if planner {
        let plan = structured_output(&output)?;
        validate_plan(&plan, repo)?;
        patch(e, id, "running", json!({"stage":"completed","plan":plan}))?;
        return Ok(());
    }
    check_and_merge(e, job, &session).await
}
async fn check_and_merge(e: &Engine, job: &Value, session: &str) -> Result<(), &'static str> {
    let id = job["id"].as_str().ok_or("jobInvalid")?;
    let task = job["taskId"]
        .as_str()
        .filter(|s| !s.is_empty())
        .unwrap_or(id);
    let repo = job["repoId"].as_str().ok_or("repoInvalid")?;
    let directory = format!("{}/{}/{}", e.config.guest_worker_root, repo, task);
    let expected_dev = current_dev(e, repo)?;
    let collected = e
        .repositories
        .lock()
        .map_err(|_| "repositoryUnavailable")?
        .collect_worker(repo, task, &expected_dev)
        .map_err(|_| "collectFailed")?;
    let commit = collected["taskCommit"].as_str().ok_or("repoInvalid")?;
    stage_admitted(e, job).await?;
    let checker = e
        .server
        .create_session(&directory, "checker")
        .await
        .map_err(|_| "sessionCreateUncertain")?;
    if patch(
        e,
        id,
        "running",
        json!({"stage":"checking","sessionIds":{"worker":session,"checker":checker},"taskCommit":commit}),
    ).is_err() {
        let _ = e.server.abort(&directory, &checker).await;
        return Err("jobChanged");
    }
    let check = format!("Read-only verification. Inspect committed task changes against every criterion {}. Return only JSON {{findings:[{{id,severity,criterion,location,text,status}}],criterionResults:[{{criterion,status}}]}}. status must be met/unmet/notApplicable, findings severity critical/major/minor. Do not modify files.",job["criteria"]);
    stage_admitted(e, job).await?;
    admitted_prompt(
        e,
        job,
        &directory,
        &checker,
        "checker",
        job["checkerRole"]["model"]
            .as_str()
            .ok_or("checkerRoleMissing")?,
        job["checkerRole"]["instructions"]
            .as_str()
            .ok_or("checkerRoleMissing")?,
        &check,
        "checker",
        true,
    )
    .await?;
    let checked = await_completion(e, id, "checker", &directory, &checker).await?;
    let verification = structured_output(&checked)?;
    let passed = validate_check(&verification, &job["criteria"])?;
    patch(
        e,
        id,
        "checking",
        json!({"stage":if passed {"mergeReady"} else {"needsFix"},"findings":verification["findings"],"criterionResults":verification["criterionResults"]}),
    )?;
    if !passed {
        return Ok(());
    }
    // The checker must not have changed the worker head; integration consumes
    // the exact commit captured before checking and refuses stale dev.
    let expected_dev = current_dev(e, repo)?;
    let current = e
        .repositories
        .lock()
        .map_err(|_| "repositoryUnavailable")?
        .collect_worker(repo, task, &expected_dev)
        .map_err(|_| "collectFailed")?;
    if current["taskCommit"] != commit {
        return Err("checkedCommitChanged");
    }
    stage_admitted(e, job).await?;
    patch(e, id, "mergeReady", json!({"stage":"merging"}))?;
    let expected_dev = current_dev(e, repo)?;
    let receipt = e
        .repositories
        .lock()
        .map_err(|_| "repositoryUnavailable")?
        .merge_dev(repo, task, &expected_dev, commit)
        .map_err(|_| "mergeRefused")?;
    patch(
        e,
        id,
        "merging",
        json!({"stage":"completed","mergedCommit":receipt["devCommit"],"repoReceipt":receipt}),
    )?;
    Ok(())
}
fn undispatched_clone_allowed(job: &Value) -> bool {
    job["stage"] == "queued"
        && job["sessionIds"]
            .as_object()
            .is_some_and(|ids| ids.is_empty())
        && (job["promptDispatch"].is_null()
            || job["promptDispatch"]
                .as_object()
                .is_some_and(|ids| ids.is_empty()))
        && job["reason"] != "sessionCreateUncertain"
}
fn current_dev(e: &Engine, repo: &str) -> Result<String, &'static str> {
    if !boundary_verified(e) {
        return Err("boundaryUnavailable");
    }
    let refs = e
        .repositories
        .lock()
        .map_err(|_| "repositoryUnavailable")?
        .refs(repo)
        .map_err(|_| "repoInvalid")?;
    refs["devCommit"]
        .as_str()
        .map(str::to_owned)
        .ok_or("repoInvalid")
}
async fn resume_job(e: &Engine, job: &Value) -> Result<(), &'static str> {
    // Only refetch an already recorded session. A lost prompt acknowledgment
    // cannot lead to a replacement prompt, session or duplicate provider cost.
    let id = job["id"].as_str().ok_or("jobInvalid")?;
    let directory = job["directory"].as_str().ok_or("recoveryNeedsReview")?;
    let role = if job["sessionIds"]["checker"].is_string() {
        "checker"
    } else if job["kind"] == "planner" {
        "planner"
    } else {
        "worker"
    };
    let session = job["sessionIds"][role]
        .as_str()
        .ok_or("recoveryNeedsReview")?;
    let observed = await_completion(e, id, role, directory, session).await?;
    if !boundary_verified(e) {
        return Err("boundaryUnavailable");
    }
    if role == "planner" {
        let plan = structured_output(&observed)?;
        validate_plan(&plan, job["repoId"].as_str().ok_or("repoInvalid")?)?;
        patch(e, id, "resuming", json!({"stage":"completed","plan":plan}))?;
        return Ok(());
    }
    // Explicit resume observes the original worker, then creates a fresh
    // checker. It never resends the original worker prompt.
    if role == "worker" {
        patch(e, id, "resuming", json!({"stage":"running"}))?;
        return check_and_merge(e, job, session).await;
    }
    let checked = structured_output(&observed)?;
    if !validate_check(&checked, &job["criteria"])? {
        patch(e, id, "resuming", json!({"stage":"checking"}))?;
        patch(
            e,
            id,
            "checking",
            json!({"stage":"needsFix","findings":checked["findings"],"criterionResults":checked["criterionResults"]}),
        )?;
        return Ok(());
    }
    let repo = job["repoId"].as_str().ok_or("repoInvalid")?;
    let task = job["taskId"].as_str().ok_or("jobInvalid")?;
    let commit = job["taskCommit"].as_str().ok_or("recoveryNeedsReview")?;
    let dev = current_dev(e, repo)?;
    let current = e
        .repositories
        .lock()
        .map_err(|_| "repositoryUnavailable")?
        .collect_worker(repo, task, &dev)
        .map_err(|_| "collectFailed")?;
    if current["taskCommit"] != commit {
        return Err("checkedCommitChanged");
    }
    patch(
        e,
        id,
        "resuming",
        json!({"stage":"mergeReady","findings":checked["findings"],"criterionResults":checked["criterionResults"]}),
    )?;
    stage_admitted(e, job).await?;
    patch(e, id, "mergeReady", json!({"stage":"merging"}))?;
    let receipt = e
        .repositories
        .lock()
        .map_err(|_| "repositoryUnavailable")?
        .merge_dev(repo, task, &dev, commit)
        .map_err(|_| "mergeRefused")?;
    patch(
        e,
        id,
        "merging",
        json!({"stage":"completed","mergedCommit":receipt["devCommit"],"repoReceipt":receipt}),
    )?;
    Ok(())
}
async fn await_completion(
    e: &Engine,
    job_id: &str,
    role: &str,
    directory: &str,
    id: &str,
) -> Result<Value, &'static str> {
    let accepted_at = tokio::time::Instant::now();
    let mut seen_running = false;
    let mut errors = 0;
    for _ in 0..1800 {
        // One hour; expiration leaves a durable uncertain checkpoint.
        active_stage(e, job_id)?;
        let observed = match e.server.observe(directory, id).await {
            Ok(value) => {
                errors = 0;
                value
            }
            Err(_) if errors < 3 => {
                errors += 1;
                tokio::time::sleep(Duration::from_secs(2)).await;
                continue;
            }
            Err(_) => return Err("sessionUnknown"),
        };
        let usage = normalized_usage(&observed["usage"]);
        {
            let store = e.store.lock().map_err(|_| "storeUnavailable")?;
            let jobs = store.jobs().map_err(|_| "jobChanged")?;
            let current = jobs
                .iter()
                .find(|job| job["id"] == job_id)
                .ok_or("jobChanged")?;
            let stage = current["stage"].as_str().ok_or("jobChanged")?;
            if matches!(stage, "paused" | "stopped" | "interrupted") {
                return Err("jobChanged");
            }
            if current["sessionUsage"][role] != usage {
                store
                    .update_job(job_id, stage, &json!({"sessionUsage":{role:usage}}))
                    .map_err(|_| "usageUncertain")?;
            }
        }
        match observed["state"].as_str() {
            Some("completed") => return Ok(observed),
            Some("running") => {
                seen_running = true;
                tokio::time::sleep(Duration::from_secs(2)).await
            }
            Some("blocked") => return Err("needsAnswer"),
            Some("failed") => return Err("sessionFailed"),
            Some("unknown") if !seen_running && accepted_at.elapsed() < Duration::from_secs(30) => {
                // A 204 may precede both status and turn persistence. Missing
                // evidence stays pending briefly, never completed or resent.
                tokio::time::sleep(Duration::from_secs(2)).await;
            }
            _ => return Err("sessionUnknown"),
        }
    }
    Err("sessionUncertain")
}
fn normalized_usage(usage: &Value) -> Value {
    // Preserve the protocol's explicit cumulative total; no token arithmetic.
    json!({"cost":usage["cost"].as_f64().filter(|n| n.is_finite() && *n >= 0.0),
           "tokens":usage["tokens"]["total"].as_u64()})
}
// Model-authored JSON must not silently overwrite an earlier finding/status.
fn strict_json(text: &str) -> Result<Value, &'static str> {
    struct StrictValue(Value);
    impl<'de> serde::Deserialize<'de> for StrictValue {
        fn deserialize<D: serde::Deserializer<'de>>(d: D) -> Result<Self, D::Error> {
            struct Visitor;
            impl<'de> serde::de::Visitor<'de> for Visitor {
                type Value = StrictValue;
                fn expecting(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
                    f.write_str("JSON without duplicate object keys")
                }
                fn visit_bool<E: serde::de::Error>(self, v: bool) -> Result<Self::Value, E> {
                    Ok(StrictValue(json!(v)))
                }
                fn visit_i64<E: serde::de::Error>(self, v: i64) -> Result<Self::Value, E> {
                    Ok(StrictValue(json!(v)))
                }
                fn visit_u64<E: serde::de::Error>(self, v: u64) -> Result<Self::Value, E> {
                    Ok(StrictValue(json!(v)))
                }
                fn visit_f64<E: serde::de::Error>(self, v: f64) -> Result<Self::Value, E> {
                    serde_json::Number::from_f64(v)
                        .map(|n| StrictValue(Value::Number(n)))
                        .ok_or_else(|| E::custom("invalid number"))
                }
                fn visit_str<E: serde::de::Error>(self, v: &str) -> Result<Self::Value, E> {
                    Ok(StrictValue(json!(v)))
                }
                fn visit_unit<E: serde::de::Error>(self) -> Result<Self::Value, E> {
                    Ok(StrictValue(Value::Null))
                }
                fn visit_seq<A: serde::de::SeqAccess<'de>>(
                    self,
                    mut a: A,
                ) -> Result<Self::Value, A::Error> {
                    let mut values = Vec::new();
                    while let Some(value) = a.next_element::<StrictValue>()? {
                        values.push(value.0);
                    }
                    Ok(StrictValue(Value::Array(values)))
                }
                fn visit_map<A: serde::de::MapAccess<'de>>(
                    self,
                    mut a: A,
                ) -> Result<Self::Value, A::Error> {
                    let mut map = serde_json::Map::new();
                    while let Some(key) = a.next_key::<String>()? {
                        if map.contains_key(&key) {
                            return Err(serde::de::Error::custom("duplicate object key"));
                        }
                        map.insert(key, a.next_value::<StrictValue>()?.0);
                    }
                    Ok(StrictValue(Value::Object(map)))
                }
            }
            d.deserialize_any(Visitor)
        }
    }
    let mut parser = serde_json::Deserializer::from_str(text);
    let value = <StrictValue as serde::Deserialize>::deserialize(&mut parser)
        .map_err(|_| "structuredOutputInvalid")?;
    parser.end().map_err(|_| "structuredOutputInvalid")?;
    Ok(value.0)
}
pub fn structured_output(value: &Value) -> Result<Value, &'static str> {
    let text = value["text"].as_str().ok_or("structuredOutputInvalid")?;
    if text.len() > 1024 * 1024 {
        return Err("structuredOutputInvalid");
    }
    let text = text.trim();
    if let Ok(value) = strict_json(text) {
        return Ok(value);
    }
    // A model may append explanatory prose to its explicitly fenced verdict.
    // Accept exactly one JSON fence, never scan prose for an object or choose
    // between multiple candidate verdicts. Schema/criteria validation follows.
    let (before, fenced) = text.split_once("```").ok_or("structuredOutputInvalid")?;
    let fenced = fenced
        .strip_prefix("json\n")
        .or_else(|| fenced.strip_prefix('\n'))
        .ok_or("structuredOutputInvalid")?;
    let (body, after) = fenced.split_once("```").ok_or("structuredOutputInvalid")?;
    if after.contains("```")
        || [before, after]
            .iter()
            .any(|prose| prose.contains(['{', '}', '[', ']']))
    {
        return Err("structuredOutputInvalid");
    }
    strict_json(body.trim())
}
pub fn planner_request(job: &Value) -> String {
    let schema = json!({"type":"object","required":["spec","phases","tasks"],"properties":{
        "spec":{"type":"object"},
        "phases":{"type":"array","minItems":1,"items":{"type":"object","required":["id","title","milestoneId"]}},
        "tasks":{"type":"array","minItems":1,"items":{"type":"object","required":["id","title","phaseId","roleId","repoId","serverId","criteria","dependsOn"],"properties":{
            "roleId":{"enum":job["planningRoles"].as_array().map(|roles| roles.iter().map(|r| r["id"].clone()).collect::<Vec<_>>()).unwrap_or_default()},
            "title":{"type":"string","minLength":1},"serverId":{"const":"phone"},"repoId":{"const":job["repoId"]},
            "criteria":{"type":"array","minItems":1,"items":{"type":"string","minLength":1}},"dependsOn":{"type":"array","items":{"type":"string"}}
        }}}
    }});
    format!("Plan the approved specification. Return only a JSON object conforming to this schema: {schema}. Copy spec from the approved input. Every task must have a nonempty title, reference an existing phase and configured worker role, and use the input repoId and phone server. Supply authored proposals only; omit runtime status, findings and usage. Do not modify files. Input: {job}")
}
pub fn validate_plan(value: &Value, repo: &str) -> Result<(), &'static str> {
    let tasks = value["tasks"].as_array().ok_or("planInvalid")?;
    if !value["spec"].is_object()
        || !value["phases"].is_array()
        || tasks.is_empty()
        || tasks.len() > 1000
    {
        return Err("planInvalid");
    }
    let mut ids = std::collections::HashSet::new();
    for t in tasks {
        if t["title"].as_str().is_none_or(|s| s.trim().is_empty()) {
            return Err("planTaskTitleRequired");
        }
        let id = t["id"].as_str().ok_or("planInvalid")?;
        if !crate::config::valid_id(id)
            || !ids.insert(id)
            || t["repoId"] != repo
            || !t["roleId"].is_string()
            || t["criteria"]
                .as_array()
                .is_none_or(|a| a.is_empty() || a.iter().any(|v| !v.is_string()))
        {
            return Err("planInvalid");
        }
    }
    for t in tasks {
        for dep in t["dependsOn"].as_array().ok_or("planInvalid")? {
            let dep = dep.as_str().ok_or("planInvalid")?;
            if !ids.contains(dep) || t["id"] == dep {
                return Err("planInvalid");
            }
        }
    }
    // Cyclic dependency plans are rejected; no infinite waiting queue.
    let mut done = std::collections::HashSet::new();
    for _ in 0..tasks.len() {
        for t in tasks {
            if t["dependsOn"]
                .as_array()
                .unwrap()
                .iter()
                .all(|d| done.contains(d.as_str().unwrap()))
            {
                done.insert(t["id"].as_str().unwrap());
            }
        }
    }
    if done.len() != tasks.len() {
        return Err("planInvalid");
    }
    Ok(())
}
pub fn validate_check(value: &Value, criteria: &Value) -> Result<bool, &'static str> {
    let expected = criteria.as_array().ok_or("checkInvalid")?;
    let results = value["criterionResults"].as_array().ok_or("checkInvalid")?;
    let findings = value["findings"].as_array().ok_or("checkInvalid")?;
    if expected.is_empty() || results.len() != expected.len() {
        return Err("checkInvalid");
    }
    let mut met = true;
    let mut seen = std::collections::HashSet::new();
    for result in results {
        let criterion = result["criterion"].as_str().ok_or("checkInvalid")?;
        if !seen.insert(criterion) || !expected.iter().any(|c| c == criterion) {
            return Err("checkInvalid");
        }
        match result["status"].as_str() {
            Some("met") => {}
            Some("unmet" | "notApplicable") => met = false,
            _ => return Err("checkInvalid"),
        }
    }
    for f in findings {
        if !matches!(f["severity"].as_str(), Some("critical" | "major" | "minor"))
            || !f["text"].is_string()
            || !f["criterion"].is_string()
        {
            return Err("checkInvalid");
        }
        // A checker cannot grant its own waiver or declare a finding fixed.
        // Any finding blocks this first slice; the owner resolves it separately.
        met = false;
    }
    Ok(met)
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::body::Body;
    use tower::ServiceExt;

    fn running_planner(e: &Engine) -> (String, String) {
        let store = e.store.lock().unwrap();
        let created = store.execute(&json!({"requestId":"create-poll","action":"createProject","name":"Poll proof",
            "settings":{"mode":"single","maxLanes":1,"reviewLevel":"milestones","maxFixRounds":2,"chargingOnly":false,"budget":{"chosen":true,"unlimited":true}},
            "spec":{"goal":"Poll safely","milestones":[{"id":"m","title":"Safe","criteria":["Observe exact turn"]}]},
            "repos":[{"id":"repo","serverId":"phone","path":"/root/projects/poll","devCommit":"seed","mainCommit":"seed"}]})).unwrap();
        assert_eq!(created["accepted"], true);
        let project = created["projectId"].as_str().unwrap().to_owned();
        let revision = store.workspace().unwrap()["projects"][0]["revision"]
            .as_u64()
            .unwrap();
        assert_eq!(store.execute(&json!({"requestId":"approve-poll","action":"approveSpec","projectId":project,"expectedRevision":revision})).unwrap()["accepted"],true);
        let job = store.jobs().unwrap()[0]["id"].as_str().unwrap().to_owned();
        store
            .update_job(&job, "queued", &json!({"stage":"starting"}))
            .unwrap();
        store.update_job(&job,"starting",&json!({"stage":"running","directory":"/root/projects/poll","sessionIds":{"planner":"ses_test"},"promptDispatch":{"planner":"dispatched"}})).unwrap();
        (project, job)
    }

    async fn poll_server(
        complete: bool,
        fail_first: bool,
    ) -> (
        String,
        Arc<std::sync::atomic::AtomicUsize>,
        Arc<std::sync::atomic::AtomicUsize>,
        tokio::task::JoinHandle<()>,
    ) {
        use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
        let polls = Arc::new(AtomicUsize::new(0));
        let posts = Arc::new(AtomicUsize::new(0));
        let failure = Arc::new(AtomicBool::new(fail_first));
        let counts = polls.clone();
        let writes = posts.clone();
        let app = Router::new().fallback(move |request: Request| {
            let counts = counts.clone(); let writes = writes.clone(); let failure = failure.clone();
            async move {
                if request.method() != axum::http::Method::GET { writes.fetch_add(1, Ordering::SeqCst); }
                if failure.swap(false, Ordering::SeqCst) { return (StatusCode::SERVICE_UNAVAILABLE, Json(json!({}))).into_response(); }
                let body = match request.uri().path() {
                    "/global/health" => json!({"healthy":true,"version":"1.18.32"}),
                    "/session/ses_test" => json!({"id":"ses_test","directory":"/root/projects/poll"}),
                    "/session/status" => json!({}),
                    "/session/ses_test/message" => {
                        let index = counts.fetch_add(1, Ordering::SeqCst);
                        if complete && index > 0 { json!([
                            {"info":{"id":"msg_u","sessionID":"ses_test","role":"user"},"parts":[]},
                            {"info":{"id":"msg_a","sessionID":"ses_test","role":"assistant","parentID":"msg_u","finish":"stop","time":{"completed":1},"cost":0.2},"parts":[{"type":"text","text":"completed proof"}]}
                        ]) } else { json!([]) }
                    },
                    "/permission" | "/question" => json!([]),
                    _ => json!({}),
                };
                Json(body).into_response()
            }
        });
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let address = format!("http://{}", listener.local_addr().unwrap());
        let server = tokio::spawn(async move {
            axum::serve(listener, app).await.unwrap();
        });
        (address, polls, posts, server)
    }

    #[tokio::test]
    async fn accepted_async_turn_can_appear_after_first_idle_poll_without_resubmission() {
        let root = tempfile::tempdir().unwrap();
        let mut e = fixture(root.path());
        let (url, polls, posts, server) = poll_server(true, false).await;
        Arc::get_mut(&mut e).unwrap().server =
            OpenCodeClient::new(&url, "opencode", "fixture-only").unwrap();
        let (_, job) = running_planner(&e);
        let result = await_completion(&e, &job, "planner", "/root/projects/poll", "ses_test").await;
        server.abort();
        assert_eq!(result.unwrap()["state"], "completed");
        assert!(polls.load(std::sync::atomic::Ordering::SeqCst) >= 2);
        assert_eq!(posts.load(std::sync::atomic::Ordering::SeqCst), 0);
        assert_eq!(
            e.store.lock().unwrap().jobs().unwrap()[0]["sessionIds"]["planner"],
            "ses_test"
        );
    }

    #[tokio::test]
    async fn transient_observe_failure_refetches_same_session_without_new_prompt() {
        let root = tempfile::tempdir().unwrap();
        let mut e = fixture(root.path());
        let (url, _, posts, server) = poll_server(true, true).await;
        Arc::get_mut(&mut e).unwrap().server =
            OpenCodeClient::new(&url, "opencode", "fixture-only").unwrap();
        let (_, job) = running_planner(&e);
        let result = await_completion(&e, &job, "planner", "/root/projects/poll", "ses_test").await;
        server.abort();
        assert_eq!(result.unwrap()["state"], "completed");
        assert_eq!(posts.load(std::sync::atomic::Ordering::SeqCst), 0);
    }

    #[tokio::test]
    async fn stop_remains_effective_while_unknown_turn_is_in_grace_window() {
        let root = tempfile::tempdir().unwrap();
        let mut e = fixture(root.path());
        let (url, _, posts, server) = poll_server(false, false).await;
        Arc::get_mut(&mut e).unwrap().server =
            OpenCodeClient::new(&url, "opencode", "fixture-only").unwrap();
        let (project, job) = running_planner(&e);
        let observation = await_completion(&e, &job, "planner", "/root/projects/poll", "ses_test");
        let stop = async {
            tokio::time::sleep(Duration::from_millis(100)).await;
            let store = e.store.lock().unwrap();
            let revision = store.workspace().unwrap()["projects"][0]["revision"].clone();
            store.execute(&json!({"requestId":"stop-poll","action":"stopProject","projectId":project,"expectedRevision":revision,"confirmed":true})).unwrap()
        };
        let (result, stopped) = tokio::join!(observation, stop);
        server.abort();
        assert_eq!(stopped["accepted"], true);
        assert_eq!(result.unwrap_err(), "jobNotActive");
        assert_eq!(posts.load(std::sync::atomic::Ordering::SeqCst), 0);
    }

    #[test]
    fn fresh_clone_reset_never_reuses_a_dispatched_or_uncertain_checkpoint() {
        let pristine = json!({"stage":"queued","sessionIds":{},"promptDispatch":{}});
        assert!(undispatched_clone_allowed(&pristine));
        for patch in [
            json!({"sessionIds":{"worker":"ses_known"}}),
            json!({"promptDispatch":{"worker":"dispatching"}}),
            json!({"stage":"resuming"}),
            json!({"reason":"sessionCreateUncertain"}),
        ] {
            let mut candidate = pristine.clone();
            for (key, value) in patch.as_object().unwrap() {
                candidate[key] = value.clone();
            }
            assert!(!undispatched_clone_allowed(&candidate));
        }
    }
    #[tokio::test]
    async fn rejected_create_is_durable_before_import_and_delete_sweeps_only_unreferenced_repo() {
        let root = tempfile::tempdir().unwrap();
        let e = fixture(root.path());
        let settings = json!({"mode":"single","maxLanes":1,"reviewLevel":"milestones","maxFixRounds":2,"chargingOnly":false,"budget":{"chosen":false,"unlimited":true}});
        let mut create = json!({"requestId":"bad-create","action":"createProject","name":"GC regression","settings":settings,
            "spec":{"goal":"Verify deletion","milestones":[{"title":"GC","criteria":["Deleted repo removed"]}]},
            "repos":[{"id":"repo","serverId":"phone","path":"/root/projects/source"}]});
        let rejected = command(State(e.clone()), Ok(Json(create.clone())))
            .await
            .unwrap()
            .0;
        assert_eq!(rejected["accepted"], false);
        assert_eq!(rejected["code"], "chooseBudget");
        assert_eq!(
            e.store
                .lock()
                .unwrap()
                .command_result(&create)
                .unwrap()
                .unwrap()["replayed"],
            true
        );
        assert_eq!(
            fs::read_dir(e.config.private_root.join("repos/repos"))
                .unwrap()
                .count(),
            0
        );
        let source = git2::Repository::init(root.path().join("source")).unwrap();
        source.set_head("refs/heads/main").unwrap();
        let tree_id = source.index().unwrap().write_tree().unwrap();
        let tree = source.find_tree(tree_id).unwrap();
        let signature = git2::Signature::now("Fixture", "fixture@localhost").unwrap();
        source
            .commit(Some("HEAD"), &signature, &signature, "Seed", &tree, &[])
            .unwrap();
        e.repositories
            .lock()
            .unwrap()
            .import_repo("repo", source.workdir().unwrap())
            .unwrap();
        create["requestId"] = json!("valid-create");
        create["settings"]["budget"]["chosen"] = json!(true);
        let created = e.store.lock().unwrap().execute(&create).unwrap();
        let id = created["projectId"].clone();
        let delete = json!({"requestId":"delete-gc","action":"deleteProject","projectId":id,"expectedRevision":0,"confirmed":true});
        let result = command(State(e.clone()), Ok(Json(delete.clone())))
            .await
            .unwrap()
            .0;
        assert_eq!(result["accepted"], true);
        assert_eq!(result["cleanupPending"], false);
        assert!(e.repositories.lock().unwrap().refs("repo").is_err());
        let replay = command(State(e.clone()), Ok(Json(delete))).await.unwrap().0;
        assert_eq!(replay["accepted"], true);
        assert_eq!(replay["replayed"], true);
    }
    fn fixture(path: &std::path::Path) -> Shared {
        let private = path.join("private");
        let worker = path.join("worker");
        fs::create_dir_all(&private).unwrap();
        fs::create_dir_all(&worker).unwrap();
        let config = Config {
            schema_version: 1,
            profile_id: "profile".into(),
            private_root: private.clone(),
            worker_root: worker.clone(),
            guest_worker_root: "/root/aiteam/work/profile".into(),
            port: 4098,
            auth_token_file: private.join("auth.token"),
            oc1_credential_file: private.join("credentials"),
            oc1_base_url: "http://127.0.0.1:4097".into(),
            source_roots: vec![],
            boundary: crate::config::Boundary {
                verified: false,
                reason: "boundary_unverified".into(),
                restart_required: false,
                receipt_file: None,
                public_key_file: None,
                generation: None,
            },
        };
        Arc::new(Engine {
            store: Mutex::new(Store::open(&private, "profile").unwrap()),
            repositories: Mutex::new(
                RepositoryAuthority::new(private.join("repos"), worker).unwrap(),
            ),
            server: OpenCodeClient::new(
                "http://127.0.0.1:4097",
                "opencode",
                "fixture-server-secret",
            )
            .unwrap(),
            token: vec![b'a'; 64],
            protocol: Mutex::new(json!({})),
            boundary: None,
            deleting: std::sync::atomic::AtomicBool::new(false),
            lane_admission: tokio::sync::Mutex::new(()),
            chat: tokio::sync::RwLock::new(ChatLedger::default()),
            observer_connected: Mutex::new(false),
            parent_pid: unsafe { libc::getppid() },
            config,
        })
    }
    #[tokio::test]
    async fn repository_import_refusal_returns_static_typed_code_and_allows_corrected_retry() {
        let temp = tempfile::tempdir().unwrap();
        let projects = temp.path().join("projects");
        let source = projects.join("scratch");
        let repo = git2::Repository::init(&source).unwrap();
        repo.set_head("refs/heads/main").unwrap();
        drop(repo);
        let mut shared = fixture(temp.path());
        Arc::get_mut(&mut shared).unwrap().config.source_roots = vec![crate::config::SourceRoot {
            host_root: projects,
            guest_root: "/root/projects".into(),
        }];
        let command = json!({"requestId":"create-scratch","repos":[{"id":"editor_repo","serverId":"phone","path":"/root/projects/scratch"}]});
        let error = import_requested_repositories(&shared, &command).unwrap_err();
        let response = error.into_response();
        assert_eq!(response.status(), StatusCode::CONFLICT);
        let bytes = axum::body::to_bytes(response.into_body(), 65536)
            .await
            .unwrap();
        assert_eq!(
            serde_json::from_slice::<Value>(&bytes).unwrap(),
            json!({"code":"repository_empty"})
        );
        collect_unused_repositories(&shared).unwrap();
        let repo = git2::Repository::open(&source).unwrap();
        let tree_id = repo.index().unwrap().write_tree().unwrap();
        let tree = repo.find_tree(tree_id).unwrap();
        let signature = git2::Signature::now("QA", "qa@localhost.invalid").unwrap();
        let seed = repo
            .commit(Some("HEAD"), &signature, &signature, "Seed", &tree, &[])
            .unwrap();
        let imported = import_requested_repositories(&shared, &command).unwrap();
        assert_eq!(imported[0]["mainCommit"], seed.to_string());
        assert_eq!(imported[0]["devCommit"], seed.to_string());
    }
    fn attested_fixture(path: &std::path::Path, tier: &str) -> Shared {
        use p256::{
            ecdsa::{signature::Signer, Signature, SigningKey},
            pkcs8::EncodePublicKey,
        };
        use sha2::{Digest, Sha256};
        let mut shared = fixture(path);
        let e = Arc::get_mut(&mut shared).unwrap();
        let binaries = path.join("native");
        fs::create_dir(&binaries).unwrap();
        let executable = binaries.join("libaiteam_engine.so");
        for name in [
            "libaiteam_engine.so",
            "libaiteam_sandbox.so",
            "libaiteam_boundary_probe.so",
        ] {
            fs::write(binaries.join(name), name).unwrap();
        }
        let key = SigningKey::from_bytes((&[9u8; 32]).into()).unwrap();
        let public = key.verifying_key().to_public_key_der().unwrap();
        let key_file = e.config.private_root.join("public.der");
        fs::write(&key_file, public.as_bytes()).unwrap();
        let receipt_file = e.config.private_root.join("receipt.json");
        let generation = uuid::Uuid::new_v4().to_string();
        let payload = serde_json::to_vec(&json!({"schemaVersion":2,"tier":tier,"profileId":"profile","parentPid":e.parent_pid,
            "generation":generation,"bootId":attestation::boot_id().unwrap(),"kernelRelease":attestation::kernel_release().unwrap(),
            "policySha256":"a".repeat(64),"engineSha256":attestation::hash_file(&executable).unwrap(),
            "sandboxSha256":attestation::hash_file(&binaries.join("libaiteam_sandbox.so")).unwrap(),
            "probeSha256":attestation::hash_file(&binaries.join("libaiteam_boundary_probe.so")).unwrap(),
            "issuedAtElapsedMs":attestation::elapsed_ms().unwrap(),"protectedLaunchesRequired":true,
            "controls":{"nativeAttacksDenied":tier == "landlock","prootGitCompatible":true,"fixtureUnchanged":true,"complete":true,
                "canonicalPathsDenied":true,"daemonProcDenied":true,"fdHygiene":true,"parentInspectionDenied":true}})).unwrap();
        let signature: Signature = key.sign(&payload);
        fs::write(&receipt_file, &payload).unwrap();
        fs::write(
            attestation::signature_path(&receipt_file),
            signature.to_der().as_bytes(),
        )
        .unwrap();
        e.config.boundary.receipt_file = Some(receipt_file.clone());
        e.config.boundary.public_key_file = Some(key_file);
        e.config.boundary.generation = Some(generation.clone());
        let mut authority = BoundaryAuthority {
            pins: LaunchPins {
                trusted_public_key_sha256: format!("{:x}", Sha256::digest(public.as_bytes())),
                generation,
                policy_sha256: "a".repeat(64),
            },
            parent: e.parent_pid,
            executable,
            receipt: VerifiedBoundary {
                tier: BoundaryTier::Landlock,
                generation: String::new(),
                policy_sha256: String::new(),
                receipt_sha256: String::new(),
            },
        };
        authority.receipt =
            attestation::verify(&authority.expectation(&e.config).unwrap()).unwrap();
        e.boundary = Some(authority);
        *e.protocol.lock().unwrap() = json!({"pinnedVersion":true,"openapiVerified":true,"capabilities":{"executionDriver":true,"execution":false,"globalAdmissionAuthority":false}});
        shared
    }
    #[test]
    fn exact_native_receipt_composes_driver_capability_and_replacement_closes_it() {
        let temp = tempfile::tempdir().unwrap();
        let e = attested_fixture(temp.path(), "landlock");
        assert!(!e.config.boundary.verified);
        assert!(execution_enabled(&e));
        assert!(command_actions(&e).contains(&"createProject"));
        assert!(command_actions(&e).contains(&"promote"));
        e.deleting.store(true, std::sync::atomic::Ordering::SeqCst);
        assert!(!execution_enabled(&e));
        assert!(!command_actions(&e).contains(&"promote"));
        e.deleting.store(false, std::sync::atomic::Ordering::SeqCst);
        // No permanently cached verified boolean may survive a receipt change.
        fs::write(
            e.config.boundary.receipt_file.as_ref().unwrap(),
            b"replacement",
        )
        .unwrap();
        assert!(!execution_enabled(&e));
        assert!(!command_actions(&e).contains(&"createProject"));
        assert!(!command_actions(&e).contains(&"promote"));
    }
    #[test]
    fn failed_protocol_probes_retry_before_the_setup_readiness_window() {
        let failed =
            json!({"error":"transport_unavailable","capabilities":{"executionDriver":false}});
        assert_eq!(protocol_retry_delay(&failed), Duration::from_secs(2));
        assert_eq!(protocol_driver_reason(&failed), "transport_unavailable");
        let healthy = json!({"pinnedVersion":true,"openapiVerified":true,"capabilities":{"executionDriver":true}});
        assert_eq!(protocol_retry_delay(&healthy), Duration::from_secs(30));
        assert_eq!(protocol_driver_reason(&healthy), "");
    }
    #[tokio::test]
    async fn workspace_reports_live_server_state_and_preserves_command_revision() {
        let temp = tempfile::tempdir().unwrap();
        let e = attested_fixture(temp.path(), "proot");
        let before = e.store.lock().unwrap().workspace().unwrap();
        let observed = workspace(State(e.clone())).await.unwrap().0;
        assert_eq!(observed["servers"][0]["online"], true);
        assert_eq!(e.store.lock().unwrap().workspace().unwrap(), before);
        *e.protocol.lock().unwrap() =
            json!({"error":"authentication_failed","capabilities":{"executionDriver":false}});
        let observed = workspace(State(e.clone())).await.unwrap().0;
        assert_eq!(observed["servers"][0]["online"], false);
        assert_eq!(observed["servers"][0]["reason"], "authentication_failed");
        assert_eq!(
            health(State(e)).await.0["readinessReason"],
            "authentication_failed"
        );
    }
    #[tokio::test]
    async fn invalid_model_is_local_before_any_worker_or_dispatch_checkpoint() {
        let temp = tempfile::tempdir().unwrap();
        let e = fixture(temp.path());
        let job = json!({"id":"job-invalid-model","kind":"planner","model":"not-a-model-identity","instructions":"Plan only","repoId":"repo"});
        assert_eq!(task_pipeline(&e, &job).await, Err("invalid_model"));
        assert!(fs::read_dir(&e.config.worker_root)
            .unwrap()
            .next()
            .is_none());
        assert!(e.store.lock().unwrap().jobs().unwrap().is_empty());
    }
    #[tokio::test]
    async fn health_reports_only_live_signed_boundary_tier_at_both_locations() {
        for tier in ["landlock", "proot"] {
            let temp = tempfile::tempdir().unwrap();
            let e = attested_fixture(temp.path(), tier);
            let value = health(State(e.clone())).await.0;
            assert_eq!(value["boundaryTier"], tier);
            assert_eq!(value["capabilities"]["boundaryTier"], tier);
            assert_eq!(value["capabilities"]["boundary"], true);
            assert_eq!(value["capabilities"]["execution"], true);
            fs::write(
                e.config.boundary.receipt_file.as_ref().unwrap(),
                b"tampered",
            )
            .unwrap();
            let value = health(State(e)).await.0;
            assert_eq!(value["boundaryTier"], "none");
            assert_eq!(value["capabilities"]["boundaryTier"], "none");
            assert_eq!(value["capabilities"]["boundary"], false);
            assert_eq!(value["capabilities"]["execution"], false);
        }
    }
    #[tokio::test]
    async fn heartbeat_ack_waits_for_admission_and_stale_idle_cannot_overwrite_busy() {
        let temp = tempfile::tempdir().unwrap();
        let e = fixture(temp.path());
        let admitted = e.chat.read().await;
        let owned = e.clone();
        let now = crate::admission::now_ms();
        let pending = tokio::spawn(async move {
            crate::admission::accept(
                &owned,
                ChatHeartbeat {
                    until: now + 30_000,
                    session_ids: vec!["person".into()],
                    directories: vec!["/root/person".into()],
                    known: true,
                    app_instance: "app".into(),
                    sequence: 2,
                },
            )
            .await
        });
        tokio::task::yield_now().await;
        assert!(
            !pending.is_finished(),
            "human acknowledgment must await the admitted team dispatch"
        );
        drop(admitted);
        assert_eq!(pending.await.unwrap().unwrap()["admission"], "busy");
        assert_eq!(
            crate::admission::accept(
                &e,
                ChatHeartbeat {
                    until: now + 30_000,
                    session_ids: vec![],
                    directories: vec!["/root/person".into()],
                    known: true,
                    app_instance: "app".into(),
                    sequence: 1,
                }
            )
            .await
            .unwrap_err(),
            "heartbeatStale"
        );
        let ledger = e.chat.read().await;
        assert!(!crate::admission::idle(&e, &ledger).await.unwrap());
        drop(ledger);
        let reloaded = crate::admission::load_directories(&e.config);
        assert_eq!(reloaded.directories(), vec!["/root/person".to_string()]);
        assert_eq!(
            reloaded.admission(now, Some(true), &[]),
            crate::chat::ChatAdmission::Unknown
        );
        e.store.lock().unwrap().delete_profile().unwrap();
        assert_eq!(
            crate::admission::accept(
                &e,
                ChatHeartbeat {
                    until: now + 30_000,
                    session_ids: vec![],
                    directories: vec![],
                    known: true,
                    app_instance: "app".into(),
                    sequence: 3,
                }
            )
            .await
            .unwrap_err(),
            "profileDeleted"
        );
    }
    #[tokio::test]
    async fn all_routes_require_bearer_and_workspace_deletion_is_durable() {
        let temp = tempfile::tempdir().unwrap();
        let e = fixture(temp.path());
        let app = router(e.clone());
        for (method, route) in [
            ("GET", "/v1/health"),
            ("GET", "/v1/workspace"),
            ("GET", "/v1/events"),
            ("POST", "/v1/commands"),
            ("POST", "/v1/chatBusy"),
            ("DELETE", "/v1/profile"),
        ] {
            let response = app
                .clone()
                .oneshot(
                    axum::http::Request::builder()
                        .method(method)
                        .uri(route)
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
        }
        let health = app
            .clone()
            .oneshot(
                axum::http::Request::builder()
                    .uri("/v1/health")
                    .header("Authorization", format!("Bearer {}", "a".repeat(64)))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(health.status(), StatusCode::OK);
        let bytes = axum::body::to_bytes(health.into_body(), 65536)
            .await
            .unwrap();
        let value: Value = serde_json::from_slice(&bytes).unwrap();
        assert_eq!(value["capabilities"]["execution"], false);
        assert_eq!(value["boundaryTier"], "none");
        assert_eq!(value["capabilities"]["boundaryTier"], "none");
        assert_eq!(value["profileId"], "profile");
        assert!(!value["commandActions"]
            .as_array()
            .unwrap()
            .contains(&json!("createProject")));
        let create = app
            .clone()
            .oneshot(
                axum::http::Request::builder()
                    .method("POST")
                    .uri("/v1/commands")
                    .header("Authorization", format!("Bearer {}", "a".repeat(64)))
                    .header("Content-Type", "application/json")
                    .body(Body::from(
                        json!({"requestId":"create","action":"createProject","name":"Valid protected create",
                            "settings":{"mode":"single","maxLanes":1,"reviewLevel":"milestones","maxFixRounds":2,"chargingOnly":false,"budget":{"chosen":true,"unlimited":true}},
                            "spec":{"goal":"Prove boundary","milestones":[{"title":"Protected","criteria":["No import before proof"]}]},
                            "repos":[{"id":"repo","serverId":"phone","path":"/root/projects/source"}]}).to_string(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(create.status(), StatusCode::CONFLICT);
        assert!(e.store.lock().unwrap().workspace().unwrap()["projects"]
            .as_array()
            .unwrap()
            .is_empty());
        assert!(!String::from_utf8_lossy(&bytes).contains("fixture-server-secret"));
        let response = app
            .clone()
            .oneshot(
                axum::http::Request::builder()
                    .method("DELETE")
                    .uri("/v1/profile")
                    .header("Authorization", format!("Bearer {}", "a".repeat(64)))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::OK);
        assert!(e.store.lock().unwrap().workspace().is_err());
    }
    #[test]
    fn checker_cannot_waive_findings_or_invent_token_totals() {
        let check = json!({"criterionResults":[{"criterion":"safe","status":"met"}],"findings":[{"criterion":"safe","text":"Unresolved","severity":"major","status":"ignored"}]});
        assert!(!validate_check(&check, &json!(["safe"])).unwrap());
        assert_eq!(
            normalized_usage(&json!({"tokens":{"input":10,"output":20}}))["tokens"],
            Value::Null
        );
        assert_eq!(
            normalized_usage(&json!({"cost":0.0,"tokens":{"total":0}})),
            json!({"cost":0.0,"tokens":0})
        );
    }
    #[test]
    fn arbitrary_output_and_dependency_cycles_are_refused() {
        assert!(structured_output(&json!({"text":"Done!"})).is_err());
        let plan = json!({"spec":{},"phases":[],"tasks":[{"id":"a","repoId":"r","roleId":"worker","criteria":["A"],"dependsOn":["b"]},{"id":"b","repoId":"r","roleId":"worker","criteria":["B"],"dependsOn":["a"]}]});
        assert!(validate_plan(&plan, "r").is_err());
    }
}
