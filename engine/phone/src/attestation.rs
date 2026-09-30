//! Native-parent pinned, fresh proof receipts. Configuration booleans confer no authority.
use p256::ecdsa::{signature::Verifier, Signature, VerifyingKey};
use p256::pkcs8::DecodePublicKey;
use serde::Deserialize;
use sha2::{Digest, Sha256};
use std::io::Read;
use std::os::unix::fs::OpenOptionsExt;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct AttestationError(pub &'static str);

/// All pin fields originate in the trusted native parent's process handoff,
/// never in the mutable JSON config or signed payload being evaluated.
pub struct AttestationExpectation<'a> {
    pub receipt_file: &'a Path,
    pub public_key_file: &'a Path,
    pub profile_id: &'a str,
    pub generation: &'a str,
    pub trusted_public_key_sha256: &'a str,
    pub expected_parent_pid: i32,
    pub executable_path: &'a Path,
    pub expected_policy_sha256: &'a str,
}

#[derive(Debug)]
pub struct VerifiedBoundary {
    pub generation: String,
    pub policy_sha256: String,
    pub receipt_sha256: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct Receipt {
    schema_version: u32,
    profile_id: String,
    parent_pid: i32,
    generation: String,
    boot_id: String,
    kernel_release: String,
    policy_sha256: String,
    engine_sha256: String,
    sandbox_sha256: String,
    probe_sha256: String,
    issued_at_elapsed_ms: u64,
    protected_launches_required: bool,
    controls: Controls,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct Controls {
    native_attacks_denied: bool,
    proot_git_compatible: bool,
    fixture_unchanged: bool,
    complete: bool,
}

pub fn verify(expected: &AttestationExpectation<'_>) -> Result<VerifiedBoundary, AttestationError> {
    verify_impl(expected, true)
}

pub fn verify_current(
    expected: &AttestationExpectation<'_>,
    accepted: &VerifiedBoundary,
) -> Result<VerifiedBoundary, AttestationError> {
    if expected.generation != accepted.generation
        || expected.expected_policy_sha256 != accepted.policy_sha256
        || digest(&read_bounded(expected.receipt_file, 16384)?) != accepted.receipt_sha256
    {
        return Err(AttestationError("attestationChanged"));
    }
    verify_impl(expected, false)
}

fn verify_impl(
    expected: &AttestationExpectation<'_>,
    fresh_start: bool,
) -> Result<VerifiedBoundary, AttestationError> {
    if !hex(expected.trusted_public_key_sha256)
        || !hex(expected.expected_policy_sha256)
        || expected.expected_parent_pid <= 1
        || uuid::Uuid::parse_str(expected.generation).is_err()
    {
        return Err(AttestationError("attestationPinInvalid"));
    }
    let key_bytes = read_bounded(expected.public_key_file, 4096)?;
    if digest(&key_bytes) != expected.trusted_public_key_sha256 {
        return Err(AttestationError("attestationKeyMismatch"));
    }
    let key = VerifyingKey::from_public_key_der(&key_bytes)
        .map_err(|_| AttestationError("attestationKeyInvalid"))?;
    let payload = read_bounded(expected.receipt_file, 16384)?;
    let signature = read_bounded(&signature_path(expected.receipt_file), 256)?;
    let signature = Signature::from_der(&signature)
        .map_err(|_| AttestationError("attestationSignatureInvalid"))?;
    key.verify(&payload, &signature)
        .map_err(|_| AttestationError("attestationSignatureInvalid"))?;
    let receipt: Receipt =
        serde_json::from_slice(&payload).map_err(|_| AttestationError("attestationMalformed"))?;
    if receipt.schema_version != 1
        || receipt.profile_id != expected.profile_id
        || receipt.generation != expected.generation
        || receipt.parent_pid != expected.expected_parent_pid
        || unsafe { libc::getppid() } != expected.expected_parent_pid
        || receipt.policy_sha256 != expected.expected_policy_sha256
        || !receipt.protected_launches_required
    {
        return Err(AttestationError("attestationGenerationMismatch"));
    }
    if !(receipt.controls.native_attacks_denied
        && receipt.controls.proot_git_compatible
        && receipt.controls.fixture_unchanged
        && receipt.controls.complete)
    {
        return Err(AttestationError("attestationIncomplete"));
    }
    if receipt.boot_id != boot_id()? || receipt.kernel_release != kernel_release()? {
        return Err(AttestationError("attestationBootMismatch"));
    }
    let now = elapsed_ms()?;
    if receipt.issued_at_elapsed_ms == 0
        || receipt.issued_at_elapsed_ms > now
        || (fresh_start && now - receipt.issued_at_elapsed_ms > 120_000)
    {
        return Err(AttestationError("attestationStale"));
    }
    let directory = expected
        .executable_path
        .parent()
        .ok_or(AttestationError("attestationBinaryMismatch"))?;
    if receipt.engine_sha256 != hash_file(expected.executable_path)?
        || receipt.sandbox_sha256 != hash_file(&directory.join("libaiteam_sandbox.so"))?
        || receipt.probe_sha256 != hash_file(&directory.join("libaiteam_boundary_probe.so"))?
    {
        return Err(AttestationError("attestationBinaryMismatch"));
    }
    Ok(VerifiedBoundary {
        generation: receipt.generation,
        policy_sha256: receipt.policy_sha256,
        receipt_sha256: digest(&payload),
    })
}

pub fn signature_path(receipt: &Path) -> PathBuf {
    let mut name = receipt.as_os_str().to_os_string();
    name.push(".sig");
    PathBuf::from(name)
}

pub fn boot_id() -> Result<String, AttestationError> {
    let bytes = std::fs::read("/proc/sys/kernel/random/boot_id")
        .map_err(|_| AttestationError("attestationRuntimeUnavailable"))?;
    let id = std::str::from_utf8(&bytes)
        .map_err(|_| AttestationError("attestationRuntimeUnavailable"))?
        .trim();
    if uuid::Uuid::parse_str(id).is_err() {
        return Err(AttestationError("attestationRuntimeUnavailable"));
    }
    Ok(id.to_owned())
}

pub fn kernel_release() -> Result<String, AttestationError> {
    let mut info = std::mem::MaybeUninit::<libc::utsname>::uninit();
    if unsafe { libc::uname(info.as_mut_ptr()) } != 0 {
        return Err(AttestationError("attestationRuntimeUnavailable"));
    }
    let info = unsafe { info.assume_init() };
    unsafe { std::ffi::CStr::from_ptr(info.release.as_ptr()) }
        .to_str()
        .map(str::to_owned)
        .map_err(|_| AttestationError("attestationRuntimeUnavailable"))
}

pub fn elapsed_ms() -> Result<u64, AttestationError> {
    let mut time = libc::timespec {
        tv_sec: 0,
        tv_nsec: 0,
    };
    if unsafe { libc::clock_gettime(libc::CLOCK_BOOTTIME, &mut time) } != 0 || time.tv_sec < 0 {
        return Err(AttestationError("attestationRuntimeUnavailable"));
    }
    Ok((time.tv_sec as u64).saturating_mul(1000) + time.tv_nsec as u64 / 1_000_000)
}

pub fn hash_file(path: &Path) -> Result<String, AttestationError> {
    let mut file = std::fs::OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC)
        .open(path)
        .map_err(|_| AttestationError("attestationFileUnavailable"))?;
    if !file
        .metadata()
        .map_err(|_| AttestationError("attestationFileUnavailable"))?
        .is_file()
    {
        return Err(AttestationError("attestationFileUnavailable"));
    }
    let mut hash = Sha256::new();
    let mut buffer = [0_u8; 65536];
    loop {
        let n = file
            .read(&mut buffer)
            .map_err(|_| AttestationError("attestationFileUnavailable"))?;
        if n == 0 {
            break;
        }
        hash.update(&buffer[..n]);
    }
    Ok(format!("{:x}", hash.finalize()))
}

fn read_bounded(path: &Path, limit: usize) -> Result<Vec<u8>, AttestationError> {
    let file = std::fs::OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC | libc::O_NONBLOCK)
        .open(path)
        .map_err(|_| AttestationError("attestationFileUnavailable"))?;
    if !file
        .metadata()
        .map_err(|_| AttestationError("attestationFileUnavailable"))?
        .is_file()
    {
        return Err(AttestationError("attestationFileUnavailable"));
    }
    let mut bytes = Vec::new();
    file.take(limit as u64 + 1)
        .read_to_end(&mut bytes)
        .map_err(|_| AttestationError("attestationFileUnavailable"))?;
    if bytes.len() > limit {
        return Err(AttestationError("attestationMalformed"));
    }
    Ok(bytes)
}

fn digest(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}
fn hex(value: &str) -> bool {
    value.len() == 64
        && value
            .bytes()
            .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
}
