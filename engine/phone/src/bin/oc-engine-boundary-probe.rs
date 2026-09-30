//! Destructive probes use an isolated sentinel fixture, NEVER production state.
//! Exit 0 means all listed attacks were denied and the worker positive control
//! succeeded; it is only one component of the full Android/proot proof.
use std::ffi::CString;
use std::os::unix::ffi::OsStrExt;
use std::path::{Path, PathBuf};

// Android libc omits this AArch64 name. asm-generic/unistd.h defines
// __NR3264_truncate=45; bionic uses that 64-bit syscall on this target.
#[cfg(all(target_os = "android", target_arch = "aarch64"))]
const SYS_TRUNCATE: libc::c_long = 45;
#[cfg(not(all(target_os = "android", target_arch = "aarch64")))]
const SYS_TRUNCATE: libc::c_long = libc::SYS_truncate;

fn denied(control: &str, value: libc::c_long) -> bool {
    let errno = if value == -1 {
        std::io::Error::last_os_error().raw_os_error().unwrap_or(0)
    } else {
        0
    };
    // Landlock deliberately returns EXDEV when REFER/link rights would cross
    // the allowed hierarchy. Other attacks still require permission denial.
    let passed = value == -1
        && (matches!(errno, libc::EACCES | libc::EPERM)
            || (matches!(control, "link" | "rename") && errno == libc::EXDEV));
    if !passed {
        // Static control identifiers and numeric results only. Never print a
        // path, environment/argv value, sentinel contents or raw OS error.
        println!("boundary-control:{control}:result:{value}:errno:{errno}");
    }
    passed
}

fn path(value: &Path) -> CString {
    CString::new(value.as_os_str().as_bytes()).expect("fixture path")
}

fn check(root: &Path, worker: &Path, parent: i32) -> bool {
    let target = root.join("sentinel");
    let mut ok = true;
    for (candidate_id, candidate) in [
        target.clone(),
        root.join("../protected/sentinel"),
        PathBuf::from(format!("/proc/self/root{}", target.display())),
        PathBuf::from(format!("/proc/{parent}/root{}", target.display())),
        worker.join("protected-alias/sentinel"),
    ]
    .into_iter()
    .enumerate()
    {
        let name = path(&candidate);
        for (flags_id, flags) in [
            libc::O_RDONLY,
            libc::O_WRONLY,
            libc::O_WRONLY | libc::O_TRUNC,
        ]
        .into_iter()
        .enumerate()
        {
            let fd =
                unsafe { libc::syscall(libc::SYS_openat, libc::AT_FDCWD, name.as_ptr(), flags, 0) };
            if !denied(&format!("open-{candidate_id}-{flags_id}"), fd) {
                ok = false;
                if fd >= 0 {
                    unsafe { libc::close(fd as i32) };
                }
            }
        }
    }
    let canonical = path(&target);
    let escaped = path(&worker.join("stolen"));
    let attacks: &[&dyn Fn() -> libc::c_long] = &[
        &|| unsafe { libc::syscall(SYS_TRUNCATE, canonical.as_ptr(), 0) },
        &|| unsafe {
            libc::syscall(
                libc::SYS_renameat,
                libc::AT_FDCWD,
                canonical.as_ptr(),
                libc::AT_FDCWD,
                escaped.as_ptr(),
            )
        },
        &|| unsafe {
            libc::syscall(
                libc::SYS_linkat,
                libc::AT_FDCWD,
                canonical.as_ptr(),
                libc::AT_FDCWD,
                escaped.as_ptr(),
                0,
            )
        },
        &|| unsafe {
            libc::syscall(
                libc::SYS_fchmodat,
                libc::AT_FDCWD,
                canonical.as_ptr(),
                0o777,
            )
        },
        &|| unsafe {
            libc::syscall(
                libc::SYS_fchownat,
                libc::AT_FDCWD,
                canonical.as_ptr(),
                libc::geteuid(),
                libc::getegid(),
                0,
            )
        },
        &|| unsafe {
            libc::syscall(
                libc::SYS_utimensat,
                libc::AT_FDCWD,
                canonical.as_ptr(),
                std::ptr::null::<libc::timespec>(),
                0,
            )
        },
        &|| unsafe {
            libc::syscall(
                libc::SYS_setxattr,
                canonical.as_ptr(),
                c"user.boundary".as_ptr(),
                c"bad".as_ptr(),
                3,
                0,
            )
        },
        &|| unsafe { libc::syscall(libc::SYS_kill, parent, 0) },
        &|| unsafe { libc::syscall(libc::SYS_socket, libc::AF_UNIX, libc::SOCK_STREAM, 0) },
        &|| unsafe { libc::syscall(libc::SYS_io_uring_setup, 1, std::ptr::null::<u8>()) },
    ];
    for (id, attack) in [
        "truncate",
        "rename",
        "link",
        "chmod",
        "chown",
        "utime",
        "xattr",
        "signal",
        "unix-socket",
        "io-uring",
    ]
    .into_iter()
    .zip(attacks)
    {
        if !denied(id, attack()) {
            ok = false;
        }
    }
    // Parent is an isolated proof process outside the Landlock domain.
    let ptrace = unsafe { libc::ptrace(0x4206 as _, parent, 0, 0) };
    if !denied("ptrace", ptrace as libc::c_long) {
        ok = false;
        if ptrace == 0 {
            unsafe { libc::ptrace(libc::PTRACE_DETACH, parent, 0, 0) };
        }
    }
    let mut byte = 0_u8;
    let local = libc::iovec {
        iov_base: (&mut byte as *mut u8).cast(),
        iov_len: 1,
    };
    let remote = libc::iovec {
        iov_base: std::ptr::null_mut(),
        iov_len: 1,
    };
    if !denied("process-vm-read", unsafe {
        libc::syscall(libc::SYS_process_vm_readv, parent, &local, 1, &remote, 1, 0)
    }) {
        ok = false;
    }
    for (id, entry) in ["environ", "mem", "fd/0"].into_iter().enumerate() {
        let name = path(&PathBuf::from(format!("/proc/{parent}/{entry}")));
        let fd = unsafe {
            libc::syscall(
                libc::SYS_openat,
                libc::AT_FDCWD,
                name.as_ptr(),
                libc::O_RDONLY,
                0,
            )
        };
        if !denied(&format!("parent-proc-{id}"), fd) {
            ok = false;
            if fd >= 0 {
                unsafe { libc::close(fd as i32) };
            }
        }
    }
    // A namespace handle identifies a public kernel object; it is not a
    // credential or a data file. Acquiring it must NEVER grant authority to
    // enter the parent's namespace. The seccomp policy denies every setns.
    let namespace = path(&PathBuf::from(format!("/proc/{parent}/ns/mnt")));
    let fd = unsafe {
        libc::syscall(
            libc::SYS_openat,
            libc::AT_FDCWD,
            namespace.as_ptr(),
            libc::O_RDONLY | libc::O_CLOEXEC,
            0,
        )
    };
    if fd >= 0 {
        if !denied("namespace-setns", unsafe {
            libc::syscall(libc::SYS_setns, fd as i32, 0)
        }) {
            ok = false;
        }
        unsafe { libc::close(fd as i32) };
    } else if !denied("namespace-open", fd) {
        ok = false;
    }
    if !denied("namespace-unshare", unsafe {
        libc::syscall(libc::SYS_unshare, libc::CLONE_NEWNS)
    }) {
        ok = false;
    }
    // Ordinary worker writes must still work. A blanket deny policy is not proof.
    if let Err(error) = std::fs::write(worker.join("positive-control"), b"worker") {
        println!(
            "boundary-control:worker-write:errno:{}",
            error.raw_os_error().unwrap_or(0)
        );
        ok = false;
    }
    // Real worker ref/file renames remain permitted; protected-source REFER
    // denial must not be confused with blanket mutation failure.
    let rename = std::fs::rename(
        worker.join("positive-control"),
        worker.join("renamed-control"),
    )
    .and_then(|_| {
        std::fs::rename(
            worker.join("renamed-control"),
            worker.join("positive-control"),
        )
    });
    if let Err(error) = rename {
        println!(
            "boundary-control:worker-rename:errno:{}",
            error.raw_os_error().unwrap_or(0)
        );
        ok = false;
    }
    ok
}

fn main() {
    let args: Vec<_> = std::env::args_os().skip(1).collect();
    if args.len() < 3 || args.len() > 4 {
        std::process::exit(64);
    }
    let root = PathBuf::from(&args[0]);
    let worker = PathBuf::from(&args[1]);
    let parent: i32 = args[2].to_str().and_then(|s| s.parse().ok()).unwrap_or(0);
    if parent <= 1 || !root.is_absolute() || !worker.is_absolute() {
        std::process::exit(64);
    }
    let mut ok = check(&root, &worker, parent);
    // exec and descendants must inherit exactly the same restrictions.
    if args.len() == 3 {
        let status = std::env::current_exe().ok().and_then(|exe| {
            std::process::Command::new(exe)
                .args(&args)
                .arg("leaf")
                .status()
                .ok()
        });
        let descendant = status.is_some_and(|s| s.success());
        if !descendant {
            println!("boundary-control:descendant:failed");
        }
        ok &= descendant;
    }
    println!(
        "{}",
        if ok {
            "native-boundary-probes-passed"
        } else {
            "native-boundary-probes-failed"
        }
    );
    if !ok {
        std::process::exit(1);
    }
}
