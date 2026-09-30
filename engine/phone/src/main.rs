use oc_phone_engine::{config::Config, daemon};
use std::path::Path;
#[tokio::main]
async fn main() {
    // Protect the auth token and OpenCode credential material from same-UID
    // process inspection. Agent children must separately be kernel-confined.
    #[cfg(any(target_os = "linux", target_os = "android"))]
    if unsafe { libc::prctl(libc::PR_SET_DUMPABLE, 0, 0, 0, 0) } != 0 {
        eprintln!("engineInspectionProtectionUnavailable");
        std::process::exit(1);
    }
    let args: Vec<String> = std::env::args().collect();
    if args.len() == 3 && args[1] == "--erase-tree" {
        // Native supplies an app-owned canonical child path after stopping
        // tracked processes. Agent invocations retain their kernel confinement.
        if oc_phone_engine::repository::erase_tree_no_links(Path::new(&args[2])).is_err() {
            eprintln!("privateCleanupFailed");
            std::process::exit(1);
        }
        return;
    }

    if !matches!(args.len(), 3 | 9) || args[1] != "--config" {
        eprintln!("usage: oc-phone-engine --config <private-config-path>");
        std::process::exit(64);
    }
    let config = match Config::read(Path::new(&args[2])) {
        Ok(c) => c,
        Err(code) => {
            eprintln!("{code}");
            std::process::exit(1);
        }
    };
    let pins = if args.len() == 9
        && args[3] == "--trusted-public-key-sha256"
        && args[5] == "--native-generation"
        && args[7] == "--policy-sha256"
    {
        Some(daemon::LaunchPins {
            trusted_public_key_sha256: args[4].clone(),
            generation: args[6].clone(),
            policy_sha256: args[8].clone(),
        })
    } else if args.len() == 3 {
        None
    } else {
        eprintln!("nativePinsInvalid");
        std::process::exit(64);
    };
    // A Java channel thread may exit immediately after launch. The app-owned
    // stdin pipe, unlike PR_SET_PDEATHSIG, follows the whole app lifetime.
    oc_phone_engine::startup::watch_parent_pipe();
    if let Err(code) = daemon::serve(config, pins).await {
        eprintln!("{code}");
        std::process::exit(1);
    }
}
