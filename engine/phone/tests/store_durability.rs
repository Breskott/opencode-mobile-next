use oc_phone_engine::store::Store;
use serde_json::{json, Value};
use std::{fs, path::PathBuf};
use tempfile::TempDir;

fn storage() -> TempDir {
    let root = std::env::var_os("OC_ENGINE_TEST_ROOT")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/home/eslam/Storage/tmp/oc-phone-engine-tests"));
    fs::create_dir_all(&root).unwrap();
    tempfile::Builder::new()
        .prefix("store-")
        .tempdir_in(root)
        .unwrap()
}
fn settings() -> Value {
    json!({"mode":"single","maxLanes":1,"reviewLevel":"milestones","maxFixRounds":2,"chargingOnly":false,"budget":{"chosen":true,"unlimited":true,"daily":null,"total":null,"taskTokens":null}})
}
fn create(request: &str) -> Value {
    json!({"requestId":request,"action":"createProject","name":"Durable authored project","settings":settings(),"spec":{"goal":"Implement the approved change","milestones":[{"id":"m1","title":"Works","criteria":["Behavior is verified"]}]},"repos":[{"id":"repo","serverId":"phone","path":"/workspace/source","devCommit":"abc","mainCommit":"abc"}]})
}
fn command(request: &str, action: &str, id: &str, revision: u64) -> Value {
    json!({"requestId":request,"action":action,"projectId":id,"expectedRevision":revision})
}
fn prepared(store: &Store) -> (String, String) {
    let created = store.execute(&create("create")).unwrap();
    let id = created["projectId"].as_str().unwrap().to_owned();
    assert_eq!(
        store
            .execute(&command("spec", "approveSpec", &id, 0))
            .unwrap()["accepted"],
        true
    );
    let planner = store.jobs().unwrap().remove(0)["id"]
        .as_str()
        .unwrap()
        .to_owned();
    store
        .update_job(&planner, "queued", &json!({"stage":"starting"}))
        .unwrap();
    store
        .update_job(
            &planner,
            "starting",
            &json!({"stage":"running","sessionIds":{"planner":"session-plan"}}),
        )
        .unwrap();
    store.update_job(&planner,"running",&json!({"stage":"completed","plan":{"phases":[{"id":"phase"}],"tasks":[{"id":"task","title":"Implementation","phaseId":"phase","roleId":"worker","repoId":"repo","serverId":"phone","criteria":["Behavior is verified"],"dependsOn":[],"status":"queued"}]}})).unwrap();
    (id, planner)
}

#[test]
fn command_replay_survives_reopen_and_does_not_duplicate_events() {
    let root = storage();
    let store = Store::open(root.path(), "profile").unwrap();
    let first = store.execute(&create("create")).unwrap();
    assert_eq!(first["accepted"], true);
    let events = store.events(0, 100).unwrap();
    drop(store);
    let store = Store::open(root.path(), "profile").unwrap();
    let replay = store.execute(&create("create")).unwrap();
    assert_eq!(replay["replayed"], true);
    assert_eq!(replay["projectId"], first["projectId"]);
    assert_eq!(
        store.workspace().unwrap()["projects"]
            .as_array()
            .unwrap()
            .len(),
        1
    );
    assert_eq!(store.events(0, 100).unwrap(), events);
}
#[test]
fn request_reuse_is_payload_bound_and_rejections_are_durable() {
    let root = storage();
    let store = Store::open(root.path(), "p").unwrap();
    let c = create("create");
    store.execute(&c).unwrap();
    let mut changed = c.clone();
    changed["name"] = json!("Different");
    assert_eq!(store.execute(&changed).unwrap()["code"], "requestIdReuse");
    let bad = command(
        "stale",
        "pauseProject",
        store.workspace().unwrap()["projects"][0]["id"]
            .as_str()
            .unwrap(),
        99,
    );
    assert_eq!(store.execute(&bad).unwrap()["code"], "staleRevision");
    drop(store);
    let store = Store::open(root.path(), "p").unwrap();
    let result = store.execute(&bad).unwrap();
    assert_eq!(result["replayed"], true);
    assert_eq!(result["code"], "staleRevision");
}
#[test]
fn semantic_failure_rolls_back_all_proposed_plan_and_jobs() {
    let root = storage();
    let store = Store::open(root.path(), "p").unwrap();
    let (id, _) = prepared(&store);
    let before = store.workspace().unwrap();
    let jobs = store.jobs().unwrap();
    let revision = before["projects"][0]["revision"].as_u64().unwrap();
    let mut c = command("plan", "approvePlan", &id, revision);
    c["tasks"] = json!([{"id":"bad","title":"Bad","phaseId":"phase","roleId":"worker","repoId":"repo","serverId":"phone","criteria":["Check"],"dependsOn":["absent"]}]);
    assert_eq!(store.execute(&c).unwrap()["code"], "missingDependency");
    assert_eq!(store.workspace().unwrap(), before);
    assert_eq!(store.jobs().unwrap(), jobs);
}
#[test]
fn planner_proposal_requires_approval_before_task_queue_is_created() {
    let root = storage();
    let store = Store::open(root.path(), "p").unwrap();
    let (id, _) = prepared(&store);
    let w = store.workspace().unwrap();
    assert_eq!(w["projects"][0]["status"], "needsPlanApproval");
    assert_eq!(store.jobs().unwrap().len(), 1);
    let result = store
        .execute(&command(
            "plan",
            "approvePlan",
            &id,
            w["projects"][0]["revision"].as_u64().unwrap(),
        ))
        .unwrap();
    assert_eq!(result["accepted"], true);
    let jobs = store.jobs().unwrap();
    assert_eq!(jobs.len(), 2);
    assert_eq!(jobs[1]["stage"], "queued");
    assert_eq!(jobs[1]["usage"]["cost"], Value::Null);
    assert_eq!(
        store.workspace().unwrap()["projects"][0]["usageReported"],
        false
    );
}
#[test]
fn restart_interrupts_uncertain_submission_and_preserves_session_and_usage() {
    let root = storage();
    let store = Store::open(root.path(), "p").unwrap();
    let created = store.execute(&create("create")).unwrap();
    let id = created["projectId"].as_str().unwrap();
    store
        .execute(&command("spec", "approveSpec", id, 0))
        .unwrap();
    let job = store.jobs().unwrap()[0]["id"].as_str().unwrap().to_owned();
    store
        .update_job(
            &job,
            "queued",
            &json!({"stage":"starting","sessionIds":{"planner":"existing"},"usage":{"tokens":12}}),
        )
        .unwrap();
    drop(store);
    let store = Store::open(root.path(), "p").unwrap();
    store.recover().unwrap();
    let jobs = store.jobs().unwrap();
    assert_eq!(jobs[0]["stage"], "interrupted");
    assert_eq!(jobs[0]["sessionIds"]["planner"], "existing");
    assert_eq!(jobs[0]["usage"]["cost"], Value::Null);
    assert_eq!(jobs[0]["usage"]["tokens"], 12);
    let events = store.events(0, 100).unwrap();
    store.recover().unwrap();
    assert_eq!(store.events(0, 100).unwrap(), events);
}
#[test]
fn cas_rejects_late_updates_and_usage_regression_atomically() {
    let root = storage();
    let store = Store::open(root.path(), "p").unwrap();
    let created = store.execute(&create("create")).unwrap();
    store
        .execute(&command(
            "spec",
            "approveSpec",
            created["projectId"].as_str().unwrap(),
            0,
        ))
        .unwrap();
    let id = store.jobs().unwrap()[0]["id"].as_str().unwrap().to_owned();
    store
        .update_job(
            &id,
            "queued",
            &json!({"stage":"starting","usage":{"cost":0.25,"tokens":100}}),
        )
        .unwrap();
    let before = store.jobs().unwrap();
    assert_eq!(
        store
            .update_job(&id, "queued", &json!({"stage":"starting"}))
            .unwrap_err()
            .code(),
        "staleJobStage"
    );
    assert_eq!(
        store
            .update_job(
                &id,
                "starting",
                &json!({"stage":"running","usage":{"cost":0.10}})
            )
            .unwrap_err()
            .code(),
        "usageRegression"
    );
    assert_eq!(store.jobs().unwrap(), before);
    assert_eq!(
        store
            .update_job(&id, "starting", &json!({"sessionIds":{"planner":"one"}}))
            .unwrap()["sessionIds"]["planner"],
        "one"
    );
    assert_eq!(
        store
            .update_job(&id, "starting", &json!({"sessionIds":{"planner":"two"}}))
            .unwrap_err()
            .code(),
        "sessionAlreadyRecorded"
    );
}
#[test]
fn deletion_tombstone_blocks_old_handles_reopen_and_late_commands() {
    let root = storage();
    let first = Store::open(root.path(), "p").unwrap();
    let late = Store::open(root.path(), "p").unwrap();
    first.execute(&create("create")).unwrap();
    first.delete_profile().unwrap();
    assert_eq!(
        late.execute(&create("late")).unwrap_err().code(),
        "profileDeleted"
    );
    assert_eq!(late.workspace().unwrap_err().code(), "profileDeleted");
    assert_eq!(
        Store::open(root.path(), "p").err().unwrap().code(),
        "profileDeleted"
    );
    first.delete_profile().unwrap();
    assert!(Store::open(root.path(), "other")
        .unwrap()
        .workspace()
        .unwrap()["projects"]
        .as_array()
        .unwrap()
        .is_empty());
}
#[test]
fn event_stream_contains_metadata_and_never_authored_content() {
    let root = storage();
    let store = Store::open(root.path(), "p").unwrap();
    let mut c = create("create");
    c["spec"]["goal"] = json!("Private authored text with sk-redaction-probe");
    store.execute(&c).unwrap();
    let events = store.events(0, 100).unwrap();
    assert_eq!(events.len(), 1);
    assert!(!serde_json::to_string(&events)
        .unwrap()
        .contains("sk-redaction-probe"));
    assert!(store
        .events(events[0]["seq"].as_i64().unwrap(), 100)
        .unwrap()
        .is_empty());
    assert_eq!(store.events(-1, 1).unwrap_err().code(), "invalidCursor");
}
#[test]
fn profile_names_cannot_escape_namespace_and_symlink_is_rejected() {
    let root = storage();
    assert_eq!(
        Store::open(root.path(), "../other").err().unwrap().code(),
        "invalidProfile"
    );
    #[cfg(unix)]
    {
        std::os::unix::fs::symlink(root.path(), root.path().join("oc.teamEngine.link")).unwrap();
        assert_eq!(
            Store::open(root.path(), "link").err().unwrap().code(),
            "unsafeStoragePath"
        );
    }
}
#[test]
fn unsupported_simulation_and_merge_actions_never_modify_state() {
    let root = storage();
    let store = Store::open(root.path(), "p").unwrap();
    let before = store.workspace().unwrap();
    for action in [
        "advance",
        "simulateConflict",
        "promote",
        "processMergeQueue",
        "undoMerge",
    ] {
        let result = store
            .execute(&json!({"requestId":action,"action":action}))
            .unwrap();
        assert_eq!(result["accepted"], false);
        assert_eq!(result["code"], "unsupportedAction");
    }
    assert_eq!(store.workspace().unwrap(), before);
}

#[test]
fn imported_actual_refs_preserve_the_authored_replay_binding() {
    let root = storage();
    let store = Store::open(root.path(), "p").unwrap();
    let c = create("create");
    assert!(store.command_result(&c).unwrap().is_none());
    let mut imported = c["repos"].clone();
    imported[0]["devCommit"] = json!("actual-dev");
    imported[0]["mainCommit"] = json!("actual-main");
    store.execute_with_repositories(&c, &imported).unwrap();
    assert_eq!(
        store.workspace().unwrap()["projects"][0]["repos"][0]["devCommit"],
        "actual-dev"
    );
    imported[0]["devCommit"] = json!("later-dev");
    assert_eq!(
        store.execute_with_repositories(&c, &imported).unwrap()["replayed"],
        true
    );
    assert_eq!(
        store.workspace().unwrap()["projects"][0]["repos"][0]["devCommit"],
        "actual-dev"
    );
    let mut changed = c.clone();
    changed["name"] = json!("Changed");
    assert_eq!(
        store.command_result(&changed).unwrap_err().code(),
        "requestIdReuse"
    );
}

#[test]
fn promotion_requires_bound_physical_evidence_and_replays_after_revision_changes() {
    let root = storage();
    let store = Store::open(root.path(), "p").unwrap();
    let id = store.execute(&create("create")).unwrap()["projectId"]
        .as_str()
        .unwrap()
        .to_owned();
    let mut c = command("promote", "promote", &id, 0);
    c["targetId"] = json!("repo");
    c["confirmed"] = json!(true);
    c["expectedDevCommit"] = json!("abc");
    c["expectedMainCommit"] = json!("abc");
    let receipt = json!({"repoId":"repo","receiptId":"promote","before":{"devCommit":"abc","mainCommit":"abc"},"after":{"devCommit":"abc","mainCommit":"abc"}});
    let mut bad = receipt.clone();
    bad["after"]["mainCommit"] = json!("different");
    let before = store.workspace().unwrap();
    assert_eq!(
        store.record_promotion(&c, &bad).unwrap_err().code(),
        "invalidRepositoryReceipt"
    );
    assert_eq!(store.workspace().unwrap(), before);
    let result = store.record_promotion(&c, &receipt).unwrap();
    assert_eq!(result["accepted"], true);
    assert_eq!(
        store.workspace().unwrap()["projects"][0]["receipts"]
            .as_array()
            .unwrap()
            .len(),
        1
    );
    assert_eq!(
        store.record_promotion(&c, &receipt).unwrap()["replayed"],
        true
    );
    c["expectedRevision"] = json!(1);
    assert_eq!(
        store.record_promotion(&c, &receipt).unwrap_err().code(),
        "requestIdReuse"
    );
}

#[test]
fn per_session_usage_is_cumulative_and_remains_unknown_without_cost_evidence() {
    let root = storage();
    let store = Store::open(root.path(), "p").unwrap();
    let id = store.execute(&create("create")).unwrap()["projectId"]
        .as_str()
        .unwrap()
        .to_owned();
    store
        .execute(&command("spec", "approveSpec", &id, 0))
        .unwrap();
    let job = store.jobs().unwrap()[0]["id"].as_str().unwrap().to_owned();
    let j=store.update_job(&job,"queued",&json!({"stage":"starting","sessionIds":{"planner":"session"},"sessionUsage":{"planner":{"cost":null,"tokens":5}},"usage":{"cost":null,"tokens":5}})).unwrap();
    assert_eq!(j["sessionUsage"]["planner"]["tokens"], 5);
    assert_eq!(j["sessionUsage"]["planner"]["cost"], Value::Null);
    assert_eq!(
        store.workspace().unwrap()["projects"][0]["usageReported"],
        false
    );
    assert_eq!(
        store
            .update_job(
                &job,
                "starting",
                &json!({"sessionUsage":{"planner":{"tokens":4}}})
            )
            .unwrap_err()
            .code(),
        "usageRegression"
    );
    store.recover().unwrap();
    assert_eq!(
        store
            .update_job(&job, "interrupted", &json!({"stage":"starting"}))
            .unwrap_err()
            .code(),
        "invalidJobTransition"
    );
    assert_eq!(
        store
            .update_job(&job, "interrupted", &json!({"stage":"resuming"}))
            .unwrap()["sessionIds"]["planner"],
        "session"
    );
}
