//! Deferred by owner. Run on Storage with the coordinator's machine lock.
use std::os::unix::fs::{symlink, PermissionsExt};
use std::process::Command;

fn fixture() -> tempfile::TempDir {
    let root = std::env::var_os("OC_PHONE_PROOF_ROOT")
        .map(std::path::PathBuf::from)
        .expect("set OC_PHONE_PROOF_ROOT to an isolated Storage artifact directory");
    assert!(root.is_absolute());
    std::fs::create_dir_all(&root).unwrap();
    tempfile::tempdir_in(root).unwrap()
}

#[test]
fn unsupported_or_unproven_kernel_never_executes_a_tool() {
    let temp = fixture();
    let marker = temp.path().join("marker");
    // No policy is a hard refusal on every kernel, not an unsandboxed fallback.
    let result = Command::new(env!("CARGO_BIN_EXE_oc-engine-sandbox"))
        .arg("--")
        .arg("/bin/sh")
        .arg("-c")
        .arg(format!("touch {}", marker.display()))
        .status()
        .unwrap();
    assert!(!result.success());
    assert!(!marker.exists());
}

#[test]
#[ignore = "OS boundary proof requires Landlock ABI6; owner deferred execution"]
fn raw_syscalls_proc_aliases_metadata_and_descendants_cannot_reach_private_state() {
    let temp = fixture();
    let protected = temp.path().join("protected");
    let worker = temp.path().join("worker");
    std::fs::create_dir_all(&protected).unwrap();
    std::fs::create_dir_all(&worker).unwrap();
    std::fs::write(protected.join("sentinel"), b"canonical-main-and-auth").unwrap();
    std::fs::set_permissions(
        protected.join("sentinel"),
        std::fs::Permissions::from_mode(0o600),
    )
    .unwrap();
    symlink(&protected, worker.join("protected-alias")).unwrap();
    let probe = std::path::Path::new(env!("CARGO_BIN_EXE_oc-engine-boundary-probe"));
    // Build binaries live in a separate directory; allowing the temporary
    // fixture ancestor would defeat the protected-state test.
    assert!(!protected.starts_with(probe.parent().unwrap()));
    let result = Command::new(env!("CARGO_BIN_EXE_oc-engine-sandbox"))
        .arg("--read-only")
        .arg(probe.parent().unwrap())
        .arg("--read-only")
        .arg("/usr")
        .arg("--read-only")
        .arg("/lib")
        .arg("--read-only")
        .arg("/lib64")
        .arg("--read-only")
        .arg("/proc")
        .arg("--read-write")
        .arg(&worker)
        .arg("--")
        .arg(probe)
        .arg(&protected)
        .arg(&worker)
        .arg(std::process::id().to_string())
        .status()
        .unwrap();
    assert!(result.success(), "native attack proof did not pass");
    assert_eq!(
        std::fs::read(protected.join("sentinel")).unwrap(),
        b"canonical-main-and-auth"
    );
    assert_eq!(
        std::fs::metadata(protected.join("sentinel"))
            .unwrap()
            .permissions()
            .mode()
            & 0o777,
        0o600
    );
    assert_eq!(
        std::fs::read(worker.join("positive-control")).unwrap(),
        b"worker"
    );
}
