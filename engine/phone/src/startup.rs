//! Authentication over the child's private launch pipe, before TCP is trusted.
use hmac::{Hmac, Mac};
use sha2::Sha256;
use std::io::{Read, Write};

fn ready_line(port: u16, profile: &str, token: &str, nonce: &str) -> Result<String, &'static str> {
    if port == 0
        || !crate::config::valid_id(profile)
        || token.len() != 64
        || !token
            .bytes()
            .all(|b| b.is_ascii_hexdigit() && !b.is_ascii_uppercase())
        || uuid::Uuid::parse_str(nonce).is_err()
    {
        return Err("startupInvalid");
    }
    let message = format!("oc-phone-engine-ready-v1\n{profile}\n{port}\n{nonce}");
    let mut mac = Hmac::<Sha256>::new_from_slice(token.as_bytes()).map_err(|_| "startupInvalid")?;
    mac.update(message.as_bytes());
    let signature: String = mac
        .finalize()
        .into_bytes()
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect();
    let line = serde_json::json!({"schemaVersion":1,"profileId":profile,"port":port,"nonce":nonce,"mac":signature}).to_string();
    if line.len() > 1024 {
        return Err("startupInvalid");
    }
    Ok(line)
}

/// Call exactly once after binding port 0, and before starting HTTP processing.
pub fn publish_ready(port: u16, profile: &str, token: &str) -> Result<(), &'static str> {
    let line = ready_line(port, profile, token, &uuid::Uuid::new_v4().to_string())?;
    let stdout = std::io::stdout();
    let mut out = stdout.lock();
    writeln!(out, "{line}")
        .and_then(|_| out.flush())
        .map_err(|_| "startupPipeUnavailable")
}

fn wait_for_eof(mut reader: impl Read) -> std::io::Result<()> {
    let mut bytes = [0u8; 64];
    loop {
        match reader.read(&mut bytes) {
            Ok(0) => return Ok(()),
            Ok(_) => {}
            Err(error) if error.kind() == std::io::ErrorKind::Interrupted => {}
            Err(error) => return Err(error),
        }
    }
}

/// The native app retains the writable stdin endpoint until stop or app death.
/// Data is ignored; EOF or pipe failure sends the existing graceful SIGTERM.
pub fn watch_parent_pipe() {
    std::thread::spawn(|| {
        let _ = wait_for_eof(std::io::stdin().lock());
        unsafe {
            libc::kill(libc::getpid(), libc::SIGTERM);
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn readiness_is_bounded_authenticated_and_not_a_token_disclosure() {
        let token = "ab".repeat(32);
        let nonce = "57cfb6f9-6f2d-4d84-bbc4-26d23927a2c3";
        let line = ready_line(43123, "phone", &token, nonce).unwrap();
        let value: serde_json::Value = serde_json::from_str(&line).unwrap();
        let mut mac = Hmac::<Sha256>::new_from_slice(token.as_bytes()).unwrap();
        mac.update(b"oc-phone-engine-ready-v1\nphone\n43123\n57cfb6f9-6f2d-4d84-bbc4-26d23927a2c3");
        let expected: String = mac
            .finalize()
            .into_bytes()
            .iter()
            .map(|b| format!("{b:02x}"))
            .collect();
        assert_eq!(value["mac"], expected);
        assert!(!line.contains(&token));
        assert_ne!(ready_line(43124, "phone", &token, nonce).unwrap(), line);
        assert_ne!(ready_line(43123, "other", &token, nonce).unwrap(), line);
        assert!(ready_line(0, "phone", &token, nonce).is_err());
        assert!(ready_line(43123, "phone", &token, "invalid").is_err());
    }
    #[test]
    fn stdin_eof_child() {
        if std::env::var_os("OC_ENGINE_STDIN_EOF_CHILD").is_some() {
            watch_parent_pipe();
            loop {
                std::thread::sleep(std::time::Duration::from_secs(1));
            }
        }
    }
    #[cfg(unix)]
    #[test]
    fn engine_process_survives_launcher_thread_and_terminates_on_actual_stdin_eof() {
        use std::os::unix::process::ExitStatusExt;
        use std::process::{Command, Stdio};
        let executable = std::env::current_exe().unwrap();
        let mut child = std::thread::spawn(move || {
            Command::new(executable)
                .args(["--exact", "startup::tests::stdin_eof_child", "--nocapture"])
                .env("OC_ENGINE_STDIN_EOF_CHILD", "1")
                .stdin(Stdio::piped())
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .spawn()
                .unwrap()
        })
        .join()
        .unwrap();
        std::thread::sleep(std::time::Duration::from_millis(100));
        assert!(
            child.try_wait().unwrap().is_none(),
            "launch-thread exit killed engine"
        );
        drop(child.stdin.take());
        let deadline = std::time::Instant::now() + std::time::Duration::from_secs(3);
        loop {
            if let Some(status) = child.try_wait().unwrap() {
                assert_eq!(status.signal(), Some(libc::SIGTERM));
                break;
            }
            if std::time::Instant::now() >= deadline {
                child.kill().unwrap();
                let _ = child.wait();
                panic!("engine outlived stdin EOF");
            }
            std::thread::sleep(std::time::Duration::from_millis(10));
        }
    }
    #[cfg(unix)]
    #[test]
    fn launching_thread_exit_is_not_pipe_eof_but_parent_endpoint_close_is() {
        use std::fs::File;
        use std::os::fd::FromRawFd;
        use std::sync::mpsc;
        let mut descriptors = [-1; 2];
        assert_eq!(
            unsafe { libc::pipe2(descriptors.as_mut_ptr(), libc::O_CLOEXEC) },
            0
        );
        let child = unsafe { File::from_raw_fd(descriptors[0]) };
        let parent = unsafe { File::from_raw_fd(descriptors[1]) };
        let (done_tx, done_rx) = mpsc::channel();
        // A short-lived channel thread launches the reader then exits.
        std::thread::spawn(move || {
            std::thread::spawn(move || {
                wait_for_eof(child).unwrap();
                done_tx.send(()).unwrap();
            });
        })
        .join()
        .unwrap();
        assert!(done_rx
            .recv_timeout(std::time::Duration::from_millis(100))
            .is_err());
        drop(parent);
        done_rx
            .recv_timeout(std::time::Duration::from_secs(1))
            .unwrap();
    }
}
