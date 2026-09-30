use oc_phone_engine::{config::Config, daemon};
use std::path::Path;
#[tokio::main]
async fn main() {
    // Protect the auth token and OpenCode credential material from same-UID
    // process inspection. Agent children must separately be kernel-confined.
    #[cfg(any(target_os = "linux", target_os = "android"))]
    {
        let parent = unsafe { libc::getppid() };
        if parent == 1
            || unsafe { libc::prctl(libc::PR_SET_PDEATHSIG, libc::SIGTERM, 0, 0, 0) } != 0
            || unsafe { libc::getppid() } != parent
        {
            eprintln!("engineParentUnavailable");
            std::process::exit(1);
        }
    }
    #[cfg(any(target_os = "linux", target_os = "android"))]
    if unsafe { libc::prctl(libc::PR_SET_DUMPABLE, 0, 0, 0, 0) } != 0 {
        eprintln!("engineInspectionProtectionUnavailable");
        std::process::exit(1);
    }
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 3 || args[1] != "--config" {
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
    if let Err(code) = daemon::serve(config).await {
        eprintln!("{code}");
        std::process::exit(1);
    }
}
