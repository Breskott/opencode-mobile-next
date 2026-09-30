//! Native-only canonical Git authority. Worker metadata is always untrusted.
//! This module must live outside the workers' filesystem/process boundary.
use git2::{build::RepoBuilder, Oid, Repository, Signature};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::ffi::{CStr, CString, OsStr};
use std::fs::{self, File, OpenOptions};
use std::io::{Read, Write};
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd};
use std::os::unix::ffi::OsStrExt;
use std::os::unix::fs::{OpenOptionsExt, PermissionsExt};
use std::path::{Component, Path, PathBuf};

const MAIN: &str = "refs/heads/main";
const DEV: &str = "refs/heads/dev";
const MAX_SNAPSHOT_BYTES: u64 = 2 * 1024 * 1024 * 1024;
const MAX_SNAPSHOT_FILES: usize = 200_000;

#[derive(Debug)]
pub struct RepoError(&'static str);
impl RepoError {
    pub fn code(&self) -> &str {
        self.0
    }
}
impl std::fmt::Display for RepoError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.0)
    }
}
impl std::error::Error for RepoError {}
impl From<std::io::Error> for RepoError {
    fn from(_: std::io::Error) -> Self {
        Self("repository_io")
    }
}
impl From<git2::Error> for RepoError {
    fn from(_: git2::Error) -> Self {
        Self("repository_git")
    }
}
type Result<T> = std::result::Result<T, RepoError>;

pub struct RepositoryAuthority {
    private_root: PathBuf,
    worker_root: PathBuf,
}
struct Lock(File);
impl Drop for Lock {
    fn drop(&mut self) {
        unsafe {
            libc::flock(self.0.as_raw_fd(), libc::LOCK_UN);
        }
    }
}
struct Snapshot(PathBuf);
impl Drop for Snapshot {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct WorkerRecord {
    repo_id: String,
    task_id: String,
    dev_commit: String,
}
#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct PromotionReceipt {
    schema_version: u32,
    repo_id: String,
    request_id: String,
    expected_dev: String,
    expected_main: String,
    confirmed: bool,
    state: String,
    before: Value,
    after: Value,
}

impl RepositoryAuthority {
    pub fn new(private_root: PathBuf, worker_root: PathBuf) -> Result<Self> {
        // Reject overlap before creating either root (including ancestor symlinks).
        let private_root = absolute(&private_root)?;
        let worker_root = absolute(&worker_root)?;
        check_ancestors(&private_root)?;
        check_ancestors(&worker_root)?;
        if private_root.starts_with(&worker_root) || worker_root.starts_with(&private_root) {
            return Err(RepoError("overlapping_roots"));
        }
        secure_create_dir(&private_root)?;
        secure_create_dir(&worker_root)?;
        for name in ["repos", "workers", "receipts", "staging", "imports"] {
            secure_create_dir(&private_root.join(name))?;
        }
        Ok(Self {
            private_root,
            worker_root,
        })
    }

    pub fn import_repo(&self, repo_id: &str, source: &Path) -> Result<Value> {
        self.import_bound(repo_id, source, None)
    }

    /// Recover import completed before the command's SQLite commit. Bind the
    /// authored request, not just the source path or caller-selected repo id.
    pub fn import_repo_for_request(
        &self,
        repo_id: &str,
        source: &Path,
        request: &str,
    ) -> Result<Value> {
        if request.is_empty() || request.len() > 128 {
            return Err(RepoError("invalid_request"));
        }
        self.import_bound(repo_id, source, Some(request))
    }

    fn import_bound(&self, repo_id: &str, source: &Path, request: Option<&str>) -> Result<Value> {
        valid_id(repo_id)?;
        let _lock = self.lock()?;
        let source = absolute(source)?;
        if source.starts_with(&self.private_root)
            || self.private_root.starts_with(&source)
            || source.starts_with(&self.worker_root)
            || self.worker_root.starts_with(&source)
        {
            return Err(RepoError("unsafe_source"));
        }
        let target = self.repo_path(repo_id);
        let binding_path = self
            .private_root
            .join("imports")
            .join(format!("{repo_id}.json"));
        let binding = json!({"repoId":repo_id,"source":source,"requestId":request});
        if target.exists() {
            if request.is_some() && read_json::<Value>(&binding_path)? == binding {
                return self.refs_unlocked(repo_id);
            }
            return Err(RepoError("repository_exists"));
        }
        if request.is_some() {
            if binding_path.exists() && read_json::<Value>(&binding_path)? != binding {
                return Err(RepoError("import_binding_mismatch"));
            }
            atomic_json(&binding_path, &binding)?;
        }
        let snapshot = self.snapshot(&source, true)?;
        let staged = self
            .private_root
            .join("staging")
            .join(uuid::Uuid::new_v4().to_string());
        let cleanup = Snapshot(staged.clone());
        let repo = RepoBuilder::new()
            .bare(true)
            .clone_local(git2::build::CloneLocal::None)
            .clone(path_string(&snapshot.0)?, &staged)?;
        let seed = repo
            .find_reference(MAIN)
            .and_then(|r| r.peel_to_commit())
            .or_else(|_| repo.head().and_then(|r| r.peel_to_commit()))?
            .id();
        // Import creates the engine-owned branch policy; worker/source branch names are not authority.
        let initial_dev = repo
            .find_reference(DEV)
            .and_then(|r| r.peel_to_commit())
            .map(|c| c.id())
            .unwrap_or(seed);
        if repo.find_reference(MAIN).is_err() {
            repo.reference(MAIN, seed, false, "initial main")?;
        }
        if repo.find_reference(DEV).is_err() {
            repo.reference(DEV, initial_dev, false, "initial dev")?;
        }
        direct_commit_ref(&repo, MAIN)?;
        direct_commit_ref(&repo, DEV)?;
        if !descends(&repo, initial_dev, seed)? {
            return Err(RepoError("divergent_import"));
        }
        remove_remotes(&repo)?;
        repo.set_head(DEV)?;
        install_hooks(&repo)?;
        sync_all(&staged)?;
        drop(repo);
        fs::rename(&staged, &target)?;
        sync_dir(target.parent().unwrap())?;
        drop(cleanup);
        let mut result = self.refs_unlocked(repo_id)?;
        result["before"] = json!({"devCommit":null,"mainCommit":null});
        result["after"] =
            json!({"devCommit":result["devCommit"],"mainCommit":result["mainCommit"]});
        Ok(result)
    }

    pub fn prepare_worker(&self, repo_id: &str, task_id: &str) -> Result<Value> {
        valid_id(repo_id)?;
        valid_id(task_id)?;
        let _lock = self.lock()?;
        let canonical = self.open_repo(repo_id)?;
        let dev = commit_ref(&canonical, DEV)?;
        let main = commit_ref(&canonical, MAIN)?;
        let path = self.worker_path(repo_id, task_id);
        if fs::symlink_metadata(&path).is_ok() {
            return Err(RepoError("worker_exists"));
        }
        // Build privately first, then export through directory descriptors. Agent-controlled
        // path replacement must never redirect a privileged libgit2 checkout into private state.
        let staged = self
            .private_root
            .join("staging")
            .join(uuid::Uuid::new_v4().to_string());
        let cleanup = Snapshot(staged.clone());
        let worker = Repository::init(&staged)?;
        // Anonymous transport copies objects: no linked .git, alternates, hardlinks, origin or main.
        let mut fetch_options = git2::FetchOptions::new();
        fetch_options.update_fetchhead(false);
        fetch_options.download_tags(git2::AutotagOption::None);
        worker
            .remote_anonymous(path_string(&self.repo_path(repo_id))?)?
            .fetch(
                &["refs/heads/dev:refs/heads/dev"],
                Some(&mut fetch_options),
                None,
            )?;
        // libgit2 may create FETCH_HEAD even with update_fetchhead(false).
        // Transport metadata must never expose the private canonical path.
        let fetch_head = worker.path().join("FETCH_HEAD");
        if fetch_head.exists() {
            fs::remove_file(fetch_head)?;
        }
        let branch = task_branch(task_id);
        worker.reference(
            &format!("refs/heads/{branch}"),
            dev,
            false,
            "seed worker from dev",
        )?;
        worker.set_head(&format!("refs/heads/{branch}"))?;
        worker.checkout_head(None)?;
        worker.find_reference(DEV)?.delete()?;
        install_hooks(&worker)?;
        drop(worker);
        let root_fd = open_directory(&self.worker_root)?;
        let repo_fd = mkdir_child(&root_fd, OsStr::new(repo_id), false)?;
        let task_fd = mkdir_child(&repo_fd, OsStr::new(task_id), true)?;
        export_directory(&staged, &task_fd)?;
        drop(cleanup);
        let record = WorkerRecord {
            repo_id: repo_id.into(),
            task_id: task_id.into(),
            dev_commit: dev.to_string(),
        };
        atomic_json(&self.worker_record(repo_id, task_id), &record)?;
        Ok(
            json!({"repoId":repo_id,"taskId":task_id,"workerPath":path,"branch":branch,
            "devCommit":dev.to_string(),"taskCommit":dev.to_string(),
            "before":{"devCommit":dev.to_string(),"mainCommit":main.to_string()},
            "after":{"devCommit":dev.to_string(),"mainCommit":main.to_string()}}),
        )
    }

    pub fn collect_worker(
        &self,
        repo_id: &str,
        task_id: &str,
        expected_dev: &str,
    ) -> Result<Value> {
        valid_id(repo_id)?;
        valid_id(task_id)?;
        let expected = parse_oid(expected_dev)?;
        let _lock = self.lock()?;
        let canonical = self.open_repo(repo_id)?;
        let main = commit_ref(&canonical, MAIN)?;
        if commit_ref(&canonical, DEV)? != expected {
            return Err(RepoError("stale_dev"));
        }
        let record: WorkerRecord = read_json(&self.worker_record(repo_id, task_id))?;
        if record.repo_id != repo_id || record.task_id != task_id {
            return Err(RepoError("worker_binding_mismatch"));
        }
        let base = parse_oid(&record.dev_commit)?;
        if !descends(&canonical, expected, base)? {
            return Err(RepoError("worker_binding_mismatch"));
        }
        let snapshot = self.snapshot(&self.worker_path(repo_id, task_id), false)?;
        let worker = Repository::open_bare(&snapshot.0)?;
        let task_ref = format!("refs/heads/{}", task_branch(task_id));
        // Never resolve symbolic refs supplied by an agent (including refs that alias main).
        let task = direct_commit_ref(&worker, &task_ref)?;
        if !descends(&worker, task, base)? {
            return Err(RepoError("task_not_descendant"));
        }
        let incoming = incoming_ref(task_id);
        if let Ok(previous) = direct_commit_ref(&canonical, &incoming) {
            if !descends(&worker, task, previous)? {
                return Err(RepoError("task_rewritten"));
            }
        }
        let mut fetch_options = git2::FetchOptions::new();
        fetch_options.update_fetchhead(false);
        fetch_options.download_tags(git2::AutotagOption::None);
        canonical
            .remote_anonymous(path_string(&snapshot.0)?)?
            .fetch(
                &[&format!("{task_ref}:{incoming}")],
                Some(&mut fetch_options),
                None,
            )?;
        if direct_commit_ref(&canonical, &incoming)? != task {
            return Err(RepoError("task_changed"));
        }
        // Recheck ancestry using canonical objects after the transport validates them.
        if !descends(&canonical, task, base)? {
            return Err(RepoError("task_not_descendant"));
        }
        Ok(
            json!({"repoId":repo_id,"taskId":task_id,"devCommit":expected.to_string(),"baseCommit":base.to_string(),"taskCommit":task.to_string(),
                "before":{"devCommit":expected.to_string(),"mainCommit":main.to_string()},
                "after":{"devCommit":expected.to_string(),"mainCommit":main.to_string()}}),
        )
    }

    pub fn merge_dev(
        &self,
        repo_id: &str,
        task_id: &str,
        expected_dev: &str,
        expected_task: &str,
    ) -> Result<Value> {
        valid_id(repo_id)?;
        valid_id(task_id)?;
        let expected_dev = parse_oid(expected_dev)?;
        let expected_task = parse_oid(expected_task)?;
        let _lock = self.lock()?;
        let repo = self.open_repo(repo_id)?;
        let mut tx = repo.transaction()?;
        tx.lock_ref(DEV)?;
        tx.lock_ref(MAIN)?;
        let main = commit_ref(&repo, MAIN)?;
        let dev = commit_ref(&repo, DEV)?;
        if dev != expected_dev {
            return Err(RepoError("stale_dev"));
        }
        if direct_commit_ref(&repo, &incoming_ref(task_id))? != expected_task {
            return Err(RepoError("stale_task"));
        }
        let next = if descends(&repo, expected_task, dev)? {
            expected_task
        } else if descends(&repo, dev, expected_task)? {
            dev
        } else {
            let ours = repo.find_commit(dev)?;
            let theirs = repo.find_commit(expected_task)?;
            let mut index = repo.merge_commits(&ours, &theirs, None)?;
            if index.has_conflicts() {
                return Err(RepoError("merge_conflict"));
            }
            let tree_id = index.write_tree_to(&repo)?;
            let tree = repo.find_tree(tree_id)?;
            let sig = engine_signature()?;
            repo.commit(
                None,
                &sig,
                &sig,
                "Integrate checked worker task",
                &tree,
                &[&ours, &theirs],
            )?
        };
        tx.set_target(
            DEV,
            next,
            Some(&engine_signature()?),
            "checked worker integration",
        )?;
        tx.commit()?;
        sync_all(repo.path())?;
        Ok(
            json!({"repoId":repo_id,"taskId":task_id,"taskCommit":expected_task.to_string(),
            "devCommit":next.to_string(),"mainCommit":main.to_string(),
            "before":{"devCommit":dev.to_string(),"mainCommit":main.to_string()},
            "after":{"devCommit":next.to_string(),"mainCommit":main.to_string()}}),
        )
    }

    pub fn promote(
        &self,
        repo_id: &str,
        expected_dev: &str,
        expected_main: &str,
        confirmed: bool,
        request_id: &str,
    ) -> Result<Value> {
        valid_id(repo_id)?;
        valid_id(request_id)?;
        if !confirmed {
            return Err(RepoError("confirmation_required"));
        }
        let dev = parse_oid(expected_dev)?;
        let main = parse_oid(expected_main)?;
        let _lock = self.lock()?;
        let receipt_path = self
            .private_root
            .join("receipts")
            .join(format!("{request_id}.json"));
        let mut receipt = if receipt_path.exists() {
            let old: PromotionReceipt = read_json(&receipt_path)?;
            if old.schema_version != 1
                || old.repo_id != repo_id
                || old.request_id != request_id
                || old.expected_dev != dev.to_string()
                || old.expected_main != main.to_string()
                || old.confirmed != confirmed
            {
                return Err(RepoError("request_id_conflict"));
            }
            if old.state == "applied" {
                return Ok(promotion_result(&old));
            }
            if old.state == "superseded" {
                return Err(RepoError("promotion_superseded"));
            }
            if old.state != "prepared" {
                return Err(RepoError("invalid_receipt"));
            }
            old
        } else {
            PromotionReceipt {
                schema_version: 1,
                repo_id: repo_id.into(),
                request_id: request_id.into(),
                expected_dev: dev.to_string(),
                expected_main: main.to_string(),
                confirmed,
                state: "prepared".into(),
                before: json!({"devCommit":dev.to_string(),"mainCommit":main.to_string()}),
                after: json!({"devCommit":dev.to_string(),"mainCommit":dev.to_string()}),
            }
        };
        // Before a later promotion can move main beyond an interrupted receipt, resolve
        // every earlier durable intent for this repository. Otherwise refs alone would
        // no longer distinguish an applied request from an unapplied one after restart.
        self.reconcile_earlier_promotions(repo_id, request_id)?;
        let repo = self.open_repo(repo_id)?;
        let mut tx = repo.transaction()?;
        tx.lock_ref(MAIN)?;
        tx.lock_ref(DEV)?;
        let current_main = commit_ref(&repo, MAIN)?;
        let current_dev = commit_ref(&repo, DEV)?;
        if receipt_path.exists() && current_main == dev {
            // Main was committed after durable intent but before durable acknowledgement.
            receipt.state = "applied".into();
            atomic_json(&receipt_path, &receipt)?;
            return Ok(promotion_result(&receipt));
        }
        if current_dev != dev {
            return Err(RepoError("stale_dev"));
        }
        if current_main != main {
            return Err(RepoError("stale_main"));
        }
        if !descends(&repo, dev, main)? {
            return Err(RepoError("promotion_not_fast_forward"));
        }
        // Intent and both SHA values reach storage before main changes.
        sync_all(repo.path())?;
        atomic_json(&receipt_path, &receipt)?;
        tx.set_target(MAIN, dev, Some(&engine_signature()?), "confirmed promotion")?;
        tx.commit()?;
        sync_tree_refs(&repo)?;
        receipt.state = "applied".into();
        atomic_json(&receipt_path, &receipt)?;
        Ok(promotion_result(&receipt))
    }

    fn reconcile_earlier_promotions(&self, repo_id: &str, request_id: &str) -> Result<()> {
        for entry in fs::read_dir(self.private_root.join("receipts"))? {
            let path = entry?.path();
            if path.extension() != Some(OsStr::new("json")) {
                continue;
            }
            let mut receipt: PromotionReceipt = read_json(&path)?;
            if receipt.repo_id != repo_id
                || receipt.request_id == request_id
                || receipt.state != "prepared"
            {
                continue;
            }
            if receipt.schema_version != 1 || !receipt.confirmed {
                return Err(RepoError("invalid_receipt"));
            }
            let dev = parse_oid(&receipt.expected_dev)?;
            let main = parse_oid(&receipt.expected_main)?;
            let repo = self.open_repo(repo_id)?;
            let mut tx = repo.transaction()?;
            tx.lock_ref(MAIN)?;
            tx.lock_ref(DEV)?;
            let current_main = commit_ref(&repo, MAIN)?;
            let current_dev = commit_ref(&repo, DEV)?;
            if current_main == dev {
                receipt.state = "applied".into();
            } else if current_main == main && current_dev != dev {
                // Exact dev was not applied and has since changed. Never substitute a new SHA.
                receipt.state = "superseded".into();
            } else if current_main == main && current_dev == dev {
                if !descends(&repo, dev, main)? {
                    return Err(RepoError("promotion_not_fast_forward"));
                }
                sync_all(repo.path())?;
                tx.set_target(
                    MAIN,
                    dev,
                    Some(&engine_signature()?),
                    "confirmed promotion recovery",
                )?;
                tx.commit()?;
                sync_tree_refs(&repo)?;
                receipt.state = "applied".into();
            } else {
                return Err(RepoError("promotion_recovery_required"));
            }
            atomic_json(&path, &receipt)?;
        }
        Ok(())
    }

    pub fn refs(&self, repo_id: &str) -> Result<Value> {
        valid_id(repo_id)?;
        let _lock = self.lock()?;
        self.refs_unlocked(repo_id)
    }
    fn refs_unlocked(&self, repo_id: &str) -> Result<Value> {
        let repo = self.open_repo(repo_id)?;
        Ok(
            json!({"repoId":repo_id,"mainCommit":commit_ref(&repo,MAIN)?.to_string(),"devCommit":commit_ref(&repo,DEV)?.to_string()}),
        )
    }
    fn repo_path(&self, repo: &str) -> PathBuf {
        self.private_root.join("repos").join(format!("{repo}.git"))
    }
    fn worker_path(&self, repo: &str, task: &str) -> PathBuf {
        self.worker_root.join(repo).join(task)
    }
    fn worker_record(&self, repo: &str, task: &str) -> PathBuf {
        self.private_root
            .join("workers")
            .join(format!("{repo}.{task}.json"))
    }
    fn open_repo(&self, id: &str) -> Result<Repository> {
        let path = self.repo_path(id);
        check_ancestors(&path)?;
        Repository::open_bare(path).map_err(|_| RepoError("repository_unavailable"))
    }
    fn lock(&self) -> Result<Lock> {
        let file = OpenOptions::new()
            .create(true)
            .truncate(false)
            .read(true)
            .write(true)
            .mode(0o600)
            .custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC)
            .open(self.private_root.join("authority.lock"))?;
        if unsafe { libc::flock(file.as_raw_fd(), libc::LOCK_EX) } != 0 {
            return Err(RepoError("repository_busy"));
        }
        Ok(Lock(file))
    }
    fn snapshot(&self, source: &Path, importing: bool) -> Result<Snapshot> {
        let source_fd = open_directory(source)?;
        let git_fd = match open_child(source_fd.as_raw_fd(), OsStr::new(".git")) {
            Ok(fd) => {
                if !is_directory(&fd)? {
                    return Err(RepoError("linked_repository"));
                }
                fd
            }
            Err(_) => {
                // Bare repositories have HEAD + objects at their root.
                let head = open_child(source_fd.as_raw_fd(), OsStr::new("HEAD"))?;
                if is_directory(&head)? {
                    return Err(RepoError("invalid_repository"));
                }
                source_fd
            }
        };
        let path = self
            .private_root
            .join("staging")
            .join(uuid::Uuid::new_v4().to_string());
        secure_create_dir(&path)?;
        let snapshot = Snapshot(path);
        let mut budget = (0u64, 0usize);
        copy_directory(&git_fd, &snapshot.0, &mut budget, 0)?;
        // Never allow libgit2 config includes/alternates to read daemon-private files.
        for forbidden in [
            "objects/info/alternates",
            "objects/info/http-alternates",
            "commondir",
            "gitdir",
            "shallow",
            "info/grafts",
            "refs/replace",
        ] {
            if snapshot.0.join(forbidden).exists() {
                return Err(RepoError("unsafe_repository_metadata"));
            }
        }
        let config = fs::read_to_string(snapshot.0.join("config"))?;
        let lower = config.to_ascii_lowercase();
        if lower.contains("[include")
            || lower.contains("[extensions")
            || lower.contains("[url ")
            || (!importing && lower.contains("[remote"))
        {
            return Err(RepoError("unsafe_repository_config"));
        }
        // Import may carry a normal network origin; it is never fetched or retained.
        // Local/file/scp origins are refused rather than interpreting untrusted paths.
        for line in config.lines() {
            if let Some((key, value)) = line.trim().split_once('=') {
                if key.trim().eq_ignore_ascii_case("url") {
                    let value = value.trim().trim_matches('"');
                    if !["https://", "http://", "ssh://", "git://"]
                        .iter()
                        .any(|prefix| value.starts_with(prefix))
                    {
                        return Err(RepoError("unsafe_repository_config"));
                    }
                }
            }
        }
        fs::write(
            snapshot.0.join("config"),
            "[core]\n\trepositoryformatversion = 0\n\tbare = true\n",
        )?;
        // Native authority never executes any hook from untrusted input.
        if snapshot.0.join("hooks").exists() {
            fs::remove_dir_all(snapshot.0.join("hooks"))?;
        }
        Ok(snapshot)
    }
}

fn promotion_result(r: &PromotionReceipt) -> Value {
    json!({"repoId":r.repo_id,"receiptId":r.request_id,"devCommit":r.expected_dev,
        "mainCommit":r.expected_dev,"before":r.before,"after":r.after,"state":"applied"})
}
fn valid_id(id: &str) -> Result<()> {
    if id.is_empty()
        || id.len() > 128
        || !id
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-')
    {
        return Err(RepoError("invalid_id"));
    }
    Ok(())
}
fn parse_oid(value: &str) -> Result<Oid> {
    if value.len() != 40 || !value.bytes().all(|b| b.is_ascii_hexdigit()) {
        return Err(RepoError("invalid_commit"));
    }
    Oid::from_str(value).map_err(|_| RepoError("invalid_commit"))
}
fn task_branch(task: &str) -> String {
    format!("task/{task}")
}
fn incoming_ref(task: &str) -> String {
    format!("refs/aiteam/collected/{task}")
}
fn engine_signature() -> Result<Signature<'static>> {
    Ok(Signature::now("Phone project engine", "engine@localhost")?)
}
fn direct_commit_ref(repo: &Repository, name: &str) -> Result<Oid> {
    let reference = repo.find_reference(name)?;
    let oid = reference
        .target()
        .ok_or(RepoError("symbolic_ref_refused"))?;
    repo.find_commit(oid)?;
    Ok(oid)
}
fn commit_ref(repo: &Repository, name: &str) -> Result<Oid> {
    direct_commit_ref(repo, name)
}
fn descends(repo: &Repository, next: Oid, before: Oid) -> Result<bool> {
    Ok(next == before || repo.graph_descendant_of(next, before)?)
}
fn remove_remotes(repo: &Repository) -> Result<()> {
    let names: Vec<String> = repo
        .remotes()?
        .iter()
        .flatten()
        .map(str::to_owned)
        .collect();
    for name in names {
        repo.remote_delete(&name)?;
    }
    Ok(())
}
fn path_string(path: &Path) -> Result<&str> {
    path.to_str().ok_or(RepoError("invalid_path"))
}
fn absolute(path: &Path) -> Result<PathBuf> {
    if !path.is_absolute()
        || path
            .components()
            .any(|c| matches!(c, Component::ParentDir | Component::CurDir))
    {
        return Err(RepoError("invalid_path"));
    }
    Ok(path.into())
}
fn check_ancestors(path: &Path) -> Result<()> {
    let mut current = PathBuf::from("/");
    for part in path.components().skip(1) {
        current.push(part);
        match fs::symlink_metadata(&current) {
            Ok(m) if m.file_type().is_symlink() => return Err(RepoError("symlink_refused")),
            Ok(_) => (),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => (),
            Err(e) => return Err(e.into()),
        }
    }
    Ok(())
}
fn secure_create_dir(path: &Path) -> Result<()> {
    absolute(path)?;
    let mut current = open_directory(Path::new("/"))?;
    for part in path.components().skip(1) {
        current = mkdir_child(&current, part.as_os_str(), false)?;
    }
    if unsafe { libc::fchmod(current.as_raw_fd(), 0o700) } != 0 {
        return Err(RepoError("repository_io"));
    }
    Ok(())
}
fn mkdir_child(parent: &OwnedFd, name: &OsStr, exclusive: bool) -> Result<OwnedFd> {
    let name_c = CString::new(name.as_bytes()).map_err(|_| RepoError("invalid_path"))?;
    if unsafe { libc::mkdirat(parent.as_raw_fd(), name_c.as_ptr(), 0o700) } != 0 {
        let error = std::io::Error::last_os_error();
        if exclusive || error.kind() != std::io::ErrorKind::AlreadyExists {
            return Err(RepoError("worker_exists"));
        }
    }
    let fd = open_child(parent.as_raw_fd(), name)?;
    if !is_directory(&fd)? {
        return Err(RepoError("unsafe_repository_path"));
    }
    Ok(fd)
}
fn export_directory(source: &Path, destination: &OwnedFd) -> Result<()> {
    for entry in fs::read_dir(source)? {
        let entry = entry?;
        let name = entry.file_name();
        let metadata = fs::symlink_metadata(entry.path())?;
        if metadata.is_dir() {
            let child = mkdir_child(destination, &name, true)?;
            export_directory(&entry.path(), &child)?;
        } else {
            let name_c = CString::new(name.as_bytes()).map_err(|_| RepoError("invalid_path"))?;
            if metadata.file_type().is_symlink() {
                let target = fs::read_link(entry.path())?;
                let target_c = CString::new(target.as_os_str().as_bytes())
                    .map_err(|_| RepoError("invalid_path"))?;
                if unsafe {
                    libc::symlinkat(target_c.as_ptr(), destination.as_raw_fd(), name_c.as_ptr())
                } != 0
                {
                    return Err(RepoError("repository_io"));
                }
            } else if metadata.is_file() {
                let fd = unsafe {
                    libc::openat(
                        destination.as_raw_fd(),
                        name_c.as_ptr(),
                        libc::O_WRONLY
                            | libc::O_CREAT
                            | libc::O_EXCL
                            | libc::O_NOFOLLOW
                            | libc::O_CLOEXEC,
                        metadata.permissions().mode() & 0o777,
                    )
                };
                if fd < 0 {
                    return Err(RepoError("unsafe_repository_path"));
                }
                let mut output = unsafe { File::from_raw_fd(fd) };
                std::io::copy(&mut File::open(entry.path())?, &mut output)?;
            } else {
                return Err(RepoError("unsafe_repository_metadata"));
            }
        }
    }
    Ok(())
}
fn open_child(parent: i32, name: &OsStr) -> Result<OwnedFd> {
    let name = CString::new(name.as_bytes()).map_err(|_| RepoError("invalid_path"))?;
    let fd = unsafe {
        libc::openat(
            parent,
            name.as_ptr(),
            libc::O_RDONLY | libc::O_NOFOLLOW | libc::O_CLOEXEC | libc::O_NONBLOCK,
        )
    };
    if fd < 0 {
        return Err(RepoError("unsafe_repository_path"));
    }
    Ok(unsafe { OwnedFd::from_raw_fd(fd) })
}
fn open_directory(path: &Path) -> Result<OwnedFd> {
    absolute(path)?;
    let root = CString::new("/").unwrap();
    let fd = unsafe {
        libc::open(
            root.as_ptr(),
            libc::O_RDONLY | libc::O_DIRECTORY | libc::O_CLOEXEC,
        )
    };
    if fd < 0 {
        return Err(RepoError("repository_io"));
    }
    let mut current = unsafe { OwnedFd::from_raw_fd(fd) };
    for part in path.components().skip(1) {
        current = open_child(current.as_raw_fd(), part.as_os_str())?;
        if !is_directory(&current)? {
            return Err(RepoError("unsafe_repository_path"));
        }
    }
    Ok(current)
}
fn stat(fd: &OwnedFd) -> Result<libc::stat> {
    let mut value = std::mem::MaybeUninit::uninit();
    if unsafe { libc::fstat(fd.as_raw_fd(), value.as_mut_ptr()) } != 0 {
        return Err(RepoError("repository_io"));
    }
    Ok(unsafe { value.assume_init() })
}
fn is_directory(fd: &OwnedFd) -> Result<bool> {
    Ok(stat(fd)?.st_mode & libc::S_IFMT == libc::S_IFDIR)
}
fn copy_directory(
    source: &OwnedFd,
    destination: &Path,
    budget: &mut (u64, usize),
    depth: usize,
) -> Result<()> {
    if depth > 128 {
        return Err(RepoError("repository_too_large"));
    }
    let duplicate = unsafe { libc::dup(source.as_raw_fd()) };
    if duplicate < 0 {
        return Err(RepoError("repository_io"));
    }
    let dir = unsafe { libc::fdopendir(duplicate) };
    if dir.is_null() {
        unsafe {
            libc::close(duplicate);
        }
        return Err(RepoError("repository_io"));
    }
    struct Dir(*mut libc::DIR);
    impl Drop for Dir {
        fn drop(&mut self) {
            unsafe {
                libc::closedir(self.0);
            }
        }
    }
    let dir = Dir(dir);
    loop {
        let entry = unsafe { libc::readdir(dir.0) };
        if entry.is_null() {
            break;
        }
        let name = unsafe { CStr::from_ptr((*entry).d_name.as_ptr()) }.to_bytes();
        if name == b"." || name == b".." {
            continue;
        }
        budget.1 += 1;
        if budget.1 > MAX_SNAPSHOT_FILES {
            return Err(RepoError("repository_too_large"));
        }
        let name = OsStr::from_bytes(name);
        let child = open_child(source.as_raw_fd(), name)?;
        let metadata = stat(&child)?;
        let output = destination.join(name);
        match metadata.st_mode & libc::S_IFMT {
            libc::S_IFDIR => {
                fs::create_dir(&output)?;
                copy_directory(&child, &output, budget, depth + 1)?;
            }
            libc::S_IFREG => {
                if metadata.st_nlink != 1 {
                    return Err(RepoError("shared_repository_objects"));
                }
                if metadata.st_size < 0 {
                    return Err(RepoError("unsafe_repository_metadata"));
                }
                budget.0 = budget
                    .0
                    .checked_add(metadata.st_size as u64)
                    .ok_or(RepoError("repository_too_large"))?;
                if budget.0 > MAX_SNAPSHOT_BYTES {
                    return Err(RepoError("repository_too_large"));
                }
                let mut input = File::from(child).take((metadata.st_size as u64) + 1);
                let mut out = OpenOptions::new()
                    .create_new(true)
                    .write(true)
                    .mode(0o600)
                    .open(output)?;
                let bytes = std::io::copy(&mut input, &mut out)?;
                if bytes != metadata.st_size as u64 {
                    return Err(RepoError("repository_changed"));
                }
            }
            _ => return Err(RepoError("unsafe_repository_metadata")),
        }
    }
    Ok(())
}
fn atomic_json(path: &Path, value: &impl Serialize) -> Result<()> {
    let bytes = serde_json::to_vec(value).map_err(|_| RepoError("receipt_encoding"))?;
    let temporary = path.with_extension(format!("{}.pending", uuid::Uuid::new_v4()));
    let mut file = OpenOptions::new()
        .create_new(true)
        .write(true)
        .mode(0o600)
        .custom_flags(libc::O_NOFOLLOW)
        .open(&temporary)?;
    file.write_all(&bytes)?;
    file.sync_all()?;
    fs::rename(&temporary, path)?;
    sync_dir(path.parent().unwrap())?;
    Ok(())
}
fn read_json<T: for<'a> Deserialize<'a>>(path: &Path) -> Result<T> {
    let file = OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NOFOLLOW)
        .open(path)?;
    serde_json::from_reader(file.take(1024 * 1024)).map_err(|_| RepoError("invalid_receipt"))
}
fn sync_dir(path: &Path) -> Result<()> {
    File::open(path)?.sync_all()?;
    Ok(())
}
fn sync_all(path: &Path) -> Result<()> {
    for entry in fs::read_dir(path)? {
        let entry = entry?;
        let metadata = fs::symlink_metadata(entry.path())?;
        if metadata.is_dir() {
            sync_all(&entry.path())?;
        } else if metadata.is_file() {
            File::open(entry.path())?.sync_all()?;
        } else {
            return Err(RepoError("unsafe_repository_metadata"));
        }
    }
    sync_dir(path)
}
fn sync_tree_refs(repo: &Repository) -> Result<()> {
    for name in ["refs/heads/main", "logs/refs/heads/main"] {
        let path = repo.path().join(name);
        if path.exists() {
            File::open(&path)?.sync_all()?;
            sync_dir(path.parent().unwrap())?;
        }
    }
    sync_dir(repo.path())
}
fn install_hooks(repo: &Repository) -> Result<()> {
    let hooks = repo.path().join("hooks");
    fs::create_dir_all(&hooks)?;
    // No token exception: daemon uses libgit2 and its own authenticated authority.
    for (name,script) in [
        ("reference-transaction", "#!/bin/sh\n[ \"$1\" = prepared ] || exit 0\nwhile read old new ref; do\n [ \"$ref\" != refs/heads/main ] || exit 1\ndone\n"),
        ("pre-receive", "#!/bin/sh\nwhile read old new ref; do\n [ \"$ref\" != refs/heads/main ] || exit 1\ndone\n")
    ] {
        fs::write(hooks.join(name),script)?;
        fs::set_permissions(hooks.join(name),fs::Permissions::from_mode(0o700))?;
    }
    Ok(())
}
