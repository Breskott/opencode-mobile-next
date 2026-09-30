//! Scoped app authority, not an in-process priority promise.
use crate::{
    chat::{ChatAdmission, ChatHeartbeat, ChatLedger},
    daemon::Engine,
    opencode::GlobalStatusObservation,
};
use serde_json::{json, Value};
use std::{
    fs,
    io::{Read, Write},
    os::unix::fs::OpenOptionsExt,
    time::Duration,
};

pub fn now_ms() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0)
}

pub fn app_alive(e: &Engine) -> Option<bool> {
    let pid = e.parent_pid;
    if pid <= 1 {
        return None;
    }
    if unsafe { libc::kill(pid, 0) } == 0 {
        return Some(true);
    }
    match std::io::Error::last_os_error().raw_os_error() {
        Some(libc::ESRCH) => Some(false),
        _ => None,
    }
}

pub fn load_directories(config: &crate::config::Config) -> ChatLedger {
    let mut ledger = ChatLedger::default();
    let path = config.private_root.join("person-directories.json");
    let file = fs::OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NOFOLLOW)
        .open(path);
    let Ok(file) = file else {
        return ledger;
    };
    let mut bytes = Vec::new();
    if file.take(1_048_577).read_to_end(&mut bytes).is_err() || bytes.len() > 1_048_576 {
        ledger.observation_unknown();
        return ledger;
    }
    match serde_json::from_slice::<Vec<String>>(&bytes) {
        Ok(dirs) if dirs.len() <= 256 => {
            for dir in dirs {
                if ledger.learn_directory(&dir).is_err() {
                    ledger.observation_unknown();
                    break;
                }
            }
        }
        _ => ledger.observation_unknown(),
    }
    // Never reload a heartbeat as fresh authority after restart.
    ledger
}

fn persist_directories(e: &Engine, ledger: &ChatLedger) -> Result<(), &'static str> {
    let bytes = serde_json::to_vec(&ledger.directories()).map_err(|_| "heartbeatInvalid")?;
    let path = e
        .config
        .private_root
        .join(format!(".person-directories-{}", uuid::Uuid::new_v4()));
    let result = (|| {
        let mut file = fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(0o600)
            .custom_flags(libc::O_NOFOLLOW)
            .open(&path)
            .map_err(|_| "heartbeatStorageUnavailable")?;
        file.write_all(&bytes)
            .map_err(|_| "heartbeatStorageUnavailable")?;
        file.sync_all().map_err(|_| "heartbeatStorageUnavailable")?;
        fs::rename(&path, e.config.private_root.join("person-directories.json"))
            .map_err(|_| "heartbeatStorageUnavailable")?;
        fs::File::open(&e.config.private_root)
            .and_then(|f| f.sync_all())
            .map_err(|_| "heartbeatStorageUnavailable")
    })();
    let _ = fs::remove_file(path);
    result
}

pub async fn accept(e: &Engine, heartbeat: ChatHeartbeat) -> Result<Value, &'static str> {
    // WRITE acknowledgment serializes with the READ-held engine prompt admission.
    // The app waits for this acknowledgment before dispatching its human turn.
    let mut ledger = e.chat.write().await;
    let store = e.store.lock().map_err(|_| "storeUnavailable")?;
    store.workspace().map_err(|_| "profileDeleted")?;
    let mut proposed = ledger.clone();
    proposed.accept(heartbeat, now_ms())?;
    persist_directories(e, &proposed)?;
    *ledger = proposed;
    drop(store);
    Ok(
        json!({"accepted":true,"admission":label(ledger.admission(now_ms(),app_alive(e),&crate::daemon::team_sessions(e)))}),
    )
}

pub fn label(value: ChatAdmission) -> &'static str {
    match value {
        ChatAdmission::Idle => "idle",
        ChatAdmission::Busy => "busy",
        ChatAdmission::Unknown => "unknown",
        ChatAdmission::PollKnownDirectories => "observing",
    }
}

pub async fn idle(e: &Engine, ledger: &ChatLedger) -> Result<bool, &'static str> {
    match ledger.admission(now_ms(), app_alive(e), &crate::daemon::team_sessions(e)) {
        ChatAdmission::Idle => Ok(true),
        ChatAdmission::Busy => Ok(false),
        ChatAdmission::Unknown => Err("chatStatusUnknown"),
        ChatAdmission::PollKnownDirectories => {
            if !*e
                .observer_connected
                .lock()
                .map_err(|_| "chatStatusUnknown")?
            {
                return Err("chatStatusUnknown");
            }
            e.server
                .person_directory_status(&ledger.directories(), &crate::daemon::team_sessions(e))
                .await
                .map_err(|_| "chatStatusUnknown")
        }
    }
}

pub async fn observe(e: std::sync::Arc<Engine>) {
    loop {
        if let Ok(mut connected) = e.observer_connected.lock() {
            *connected = false;
        }
        match e.server.global_status_observer().await {
            Ok(mut observer) => {
                if let Ok(mut connected) = e.observer_connected.lock() {
                    *connected = true;
                }
                loop {
                    match observer.next().await {
                        Ok(GlobalStatusObservation::Status {
                            directory,
                            session_id,
                            busy,
                        }) => {
                            if crate::daemon::team_sessions(&e).contains(&session_id) {
                                continue;
                            }
                            let mut ledger = e.chat.write().await;
                            if ledger.observe(&directory, &session_id, busy).is_err()
                                || persist_directories(&e, &ledger).is_err()
                            {
                                ledger.observation_unknown();
                            }
                        }
                        Ok(GlobalStatusObservation::Other) => {}
                        Err(_) => break,
                    }
                }
            }
            Err(_) => {}
        }
        if let Ok(mut connected) = e.observer_connected.lock() {
            *connected = false;
        }
        // Reconnection never clears cached busy evidence.
        tokio::time::sleep(Duration::from_secs(2)).await;
    }
}

pub async fn reconcile_busy(e: &Engine) {
    let (dirs, revision, busy) = {
        let ledger = e.chat.read().await;
        (
            ledger.directories(),
            ledger.observation_revision(),
            ledger.has_observed_busy(),
        )
    };
    if !busy {
        return;
    }
    if e.server
        .person_directory_status(&dirs, &crate::daemon::team_sessions(e))
        .await
        == Ok(true)
    {
        // A newer SSE busy event arriving during the poll cannot be overwritten.
        e.chat.write().await.reconcile_observed_idle(revision);
    }
}
