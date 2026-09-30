use crate::{
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

pub async fn serve(config: Config) -> Result<(), &'static str> {
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
    let engine = Arc::new(Engine {
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
    let task_engine = engine.clone();
    let background = tokio::spawn(async move { reconcile(task_engine).await });
    let result = axum::serve(listener, router(engine.clone()))
        .with_graceful_shutdown(shutdown())
        .await;
    background.abort();
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
fn execution_enabled(engine: &Engine) -> bool {
    engine.config.boundary.verified
        && engine
            .protocol
            .lock()
            .ok()
            .and_then(|p| p["capabilities"]["execution"].as_bool())
            .unwrap_or(false)
}
fn command_actions(e: &Engine) -> Vec<&'static str> {
    let mut actions: Vec<_> = STORE_ACTIONS
        .iter()
        .copied()
        .filter(|action| {
            e.config.boundary.verified || !matches!(*action, "createProject" | "createQuickTask")
        })
        .collect();
    if execution_enabled(e) {
        actions.push("promote");
    }
    actions
}
async fn health(State(e): State<Shared>) -> Json<Value> {
    let protocol = e.protocol.lock().map(|v| v.clone()).unwrap_or(json!({}));
    Json(
        json!({"schemaVersion":1,"engineVersion":env!("CARGO_PKG_VERSION"),"profileId":e.config.profile_id,
        "capabilities":{"execution":execution_enabled(&e),"boundary":e.config.boundary.verified,
            "oc1Verified":protocol["pinnedVersion"] == true && protocol["openapiVerified"] == true,"oc2":false},
        "commandActions":command_actions(&e),"boundaryReason":e.config.boundary.reason,
        "restartRequired":e.config.boundary.restart_required,"protocol":protocol}),
    )
}
async fn workspace(State(e): State<Shared>) -> Result<Json<Value>, ApiError> {
    let s = e.store.lock().map_err(|_| internal("storeUnavailable"))?;
    Ok(Json(
        s.workspace().map_err(|_| internal("storeUnavailable"))?,
    ))
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
) -> Result<Json<Value>, ApiError> {
    if q.after < 0 || q.limit == 0 || q.limit > 500 {
        return Err(internal("queryInvalid"));
    }
    let s = e.store.lock().map_err(|_| internal("storeUnavailable"))?;
    Ok(Json(json!(s
        .events(q.after, q.limit)
        .map_err(|_| internal("storeUnavailable"))?)))
}
async fn command(
    State(e): State<Shared>,
    input: Result<Json<Value>, axum::extract::rejection::JsonRejection>,
) -> Result<Json<Value>, ApiError> {
    let Json(mut c) = input.map_err(|_| internal("commandInvalid"))?;
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
            .map_err(|_| internal("requestIdReuse"))?
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
            .map_err(|_| internal("promotionRefused"))?;
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
    if let Some(result) = e
        .store
        .lock()
        .map_err(|_| internal("storeUnavailable"))?
        .command_result(&c)
        .map_err(|_| internal("requestIdReuse"))?
    {
        return Ok(Json(result));
    }
    let mut imported = vec![];
    if matches!(action, "createProject" | "createQuickTask") {
        // Never put canonical Git authority beside an unconfined legacy
        // server. Disabled scheduling alone cannot protect raw refs on disk.
        if !e.config.boundary.verified {
            return Err(internal("boundaryUnavailable"));
        }
        let repos = c["repos"].as_array().ok_or(internal("reposRequired"))?;
        if repos.is_empty() || repos.len() > 32 {
            return Err(internal("reposRequired"));
        }
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
                .map_err(|_| internal("importFailed"))?;
            let mut edited = repo.clone();
            edited["devCommit"] = refs["devCommit"].clone();
            edited["mainCommit"] = refs["mainCommit"].clone();
            imported.push(edited);
        }
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
        .map_err(|_| internal("commandRefused"))?
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
    Ok(Json(result))
}
async fn delete_profile(State(e): State<Shared>) -> Result<Json<Value>, ApiError> {
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
        while let Some(result) = tasks.try_join_next() {
            if let Ok(id) = result {
                active.remove(&id);
            }
        }
        if tokio::time::Instant::now() >= next_verify {
            let protocol = e.server.verify().await.unwrap_or(
                json!({"capabilities":{"execution":false},"blockers":["protocolUnverified"]}),
            );
            if let Ok(mut value) = e.protocol.lock() {
                *value = protocol;
            }
            next_verify = tokio::time::Instant::now() + Duration::from_secs(30);
        }
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
                if job["reason"] != "Protected execution is not verified" {
                    if let Ok(s) = e.store.lock() {
                        let _ = s.update_job(
                            &id,
                            "queued",
                            &json!({"reason":"Protected execution is not verified"}),
                        );
                    }
                }
                continue;
            }
            let team_ids = team_sessions(&e);
            if !e.server.chat_admission(&team_ids).await.unwrap_or(false) {
                continue;
            }
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
fn team_sessions(e: &Engine) -> Vec<String> {
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
    let idle = e
        .server
        .chat_admission(&team_sessions(e))
        .await
        .map_err(|_| "chatStatusUnknown")?;
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
        .map_err(|_| "jobChanged")
}
async fn run_job(e: Shared, job: Value) -> Result<(), &'static str> {
    let result = task_pipeline(&e, &job).await;
    if let Err(reason) = result {
        let id = job["id"].as_str().ok_or("jobInvalid")?;
        if let Ok(s) = e.store.lock() {
            if let Ok(jobs) = s.jobs() {
                if let Some(current) = jobs.iter().find(|j| j["id"] == id) {
                    let stage = current["stage"].as_str().unwrap_or("unknown");
                    if !matches!(stage, "completed" | "stopped" | "paused") {
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
    let task = job["taskId"]
        .as_str()
        .filter(|s| !s.is_empty())
        .unwrap_or(id);
    let repo = job["repoId"].as_str().ok_or("repoInvalid")?;
    stage_admitted(e, job).await?;
    if job["stage"] == "resuming" {
        return resume_job(e, job).await;
    }
    patch(e, id, "queued", json!({"stage":"starting"}))?;
    let work = e
        .repositories
        .lock()
        .map_err(|_| "repositoryUnavailable")?
        .prepare_worker(repo, task)
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
    patch(
        e,
        id,
        "starting",
        json!({"stage":"running","directory":directory,"sessionIds":sessions,"expectedDevCommit":dev}),
    )?;
    stage_admitted(e, job).await?;
    let request = if planner {
        format!("Plan the approved specification. Return only JSON {{spec: TeamSpec, phases: TeamPhase[], tasks: TeamTask[]}}. Every task needs roleId, repoId, criteria and dependsOn. Do not modify files. Input: {}",job)
    } else {
        format!("Implement this task on branch {}. Keep edits in this isolated clone. Commit completed changes to that task branch, without editing main or dev. Acceptance criteria: {}. Task: {}",work["branch"],job["criteria"],job["title"])
    };
    e.server
        .prompt(
            &directory,
            &session,
            role,
            model,
            instructions,
            &request,
            planner || job["readOnly"] == true,
        )
        .await
        .map_err(|_| "promptUncertain")?;
    let output = await_completion(e, id, role, &directory, &session).await?;
    if planner {
        let plan = structured_output(&output)?;
        validate_plan(&plan, repo)?;
        patch(e, id, "running", json!({"stage":"completed","plan":plan}))?;
        return Ok(());
    }
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
    patch(
        e,
        id,
        "running",
        json!({"stage":"checking","sessionIds":{"worker":session,"checker":checker},"taskCommit":commit}),
    )?;
    let check = format!("Read-only verification. Inspect committed task changes against every criterion {}. Return only JSON {{findings:[{{id,severity,criterion,location,text,status}}],criterionResults:[{{criterion,status}}]}}. status must be met/unmet/notApplicable, findings severity critical/major/minor. Do not modify files.",job["criteria"]);
    stage_admitted(e, job).await?;
    e.server
        .prompt(
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
            true,
        )
        .await
        .map_err(|_| "checkUncertain")?;
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
fn current_dev(e: &Engine, repo: &str) -> Result<String, &'static str> {
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
    if role == "planner" {
        let plan = structured_output(&observed)?;
        validate_plan(&plan, job["repoId"].as_str().ok_or("repoInvalid")?)?;
        patch(e, id, "resuming", json!({"stage":"completed","plan":plan}))?;
        return Ok(());
    }
    // Worker completion needs a NEW explicit checker step. Preserve the
    // recorded checkpoint for user review rather than re-submit the worker.
    if role == "worker" {
        return Err("checkerResumeNeedsReview");
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
    for _ in 0..1800 {
        // One hour; expiration leaves a durable uncertain checkpoint.
        let observed = e
            .server
            .observe(directory, id)
            .await
            .map_err(|_| "sessionUnknown")?;
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
            Some("running") => tokio::time::sleep(Duration::from_secs(2)).await,
            Some("blocked") => return Err("needsAnswer"),
            Some("failed") => return Err("sessionFailed"),
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
pub fn structured_output(value: &Value) -> Result<Value, &'static str> {
    let text = value["text"].as_str().ok_or("structuredOutputInvalid")?;
    if text.len() > 1024 * 1024 {
        return Err("structuredOutputInvalid");
    }
    let text = text.trim();
    let text = text
        .strip_prefix("```json\n")
        .and_then(|s| s.strip_suffix("```"))
        .or_else(|| {
            text.strip_prefix("```\n")
                .and_then(|s| s.strip_suffix("```"))
        })
        .unwrap_or(text)
        .trim();
    serde_json::from_str(text).map_err(|_| "structuredOutputInvalid")
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
            config,
        })
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
                        json!({"requestId":"create","action":"createProject"}).to_string(),
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
