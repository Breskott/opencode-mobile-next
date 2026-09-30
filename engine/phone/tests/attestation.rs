use oc_phone_engine::attestation::{self, AttestationExpectation};
use p256::ecdsa::{signature::Signer, Signature, SigningKey};
use p256::pkcs8::EncodePublicKey;
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::path::{Path, PathBuf};

struct Fixture {
    _directory: tempfile::TempDir,
    receipt: PathBuf,
    public_key: PathBuf,
    engine: PathBuf,
    generation: String,
    key_hash: String,
    key: SigningKey,
    payload: Value,
}
impl Fixture {
    fn new() -> Self {
        let artifacts = std::env::var_os("OC_PHONE_PROOF_ROOT")
            .or_else(|| std::env::var_os("CARGO_TARGET_DIR"))
            .map(PathBuf::from)
            .unwrap_or_else(|| std::env::current_dir().unwrap().join("target"))
            .join("attestation-fixtures");
        std::fs::create_dir_all(&artifacts).unwrap();
        let directory = tempfile::tempdir_in(artifacts).unwrap();
        let root = directory.path();
        let engine = root.join("libaiteam_engine.so");
        let sandbox = root.join("libaiteam_sandbox.so");
        let probe = root.join("libaiteam_boundary_probe.so");
        for (file, value) in [
            (&engine, "engine"),
            (&sandbox, "sandbox"),
            (&probe, "probe"),
        ] {
            std::fs::write(file, value).unwrap();
        }
        // Synthetic test-only signer; production private keys are nonexportable.
        let key = SigningKey::from_bytes((&[7_u8; 32]).into()).unwrap();
        let public = key.verifying_key().to_public_key_der().unwrap();
        let public_key = root.join("public.der");
        std::fs::write(&public_key, public.as_bytes()).unwrap();
        let generation = uuid::Uuid::new_v4().to_string();
        let receipt = root.join("receipt.json");
        let payload = json!({
            "schemaVersion":1, "profileId":"phone-profile", "parentPid":unsafe {libc::getppid()},
            "generation":generation, "bootId":attestation::boot_id().unwrap(),
            "kernelRelease":attestation::kernel_release().unwrap(), "policySha256":"a".repeat(64),
            "engineSha256":attestation::hash_file(&engine).unwrap(),
            "sandboxSha256":attestation::hash_file(&sandbox).unwrap(),
            "probeSha256":attestation::hash_file(&probe).unwrap(),
            "issuedAtElapsedMs":attestation::elapsed_ms().unwrap(), "protectedLaunchesRequired":true,
            "controls":{"nativeAttacksDenied":true,"prootGitCompatible":true,"fixtureUnchanged":true,"complete":true}
        });
        let fixture = Self {
            _directory: directory,
            receipt,
            public_key,
            engine,
            generation,
            key_hash: format!("{:x}", Sha256::digest(public.as_bytes())),
            key,
            payload,
        };
        fixture.sign();
        fixture
    }
    fn sign_bytes(&self, bytes: &[u8]) {
        let signature: Signature = self.key.sign(bytes);
        std::fs::write(&self.receipt, bytes).unwrap();
        std::fs::write(
            attestation::signature_path(&self.receipt),
            signature.to_der().as_bytes(),
        )
        .unwrap();
    }
    fn sign(&self) {
        self.sign_bytes(&serde_json::to_vec(&self.payload).unwrap());
    }
    fn expected(&self) -> AttestationExpectation<'_> {
        AttestationExpectation {
            receipt_file: &self.receipt,
            public_key_file: &self.public_key,
            profile_id: "phone-profile",
            generation: &self.generation,
            trusted_public_key_sha256: &self.key_hash,
            expected_parent_pid: unsafe { libc::getppid() },
            executable_path: &self.engine,
            expected_policy_sha256:
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        }
    }
    fn error(&self) -> &'static str {
        attestation::verify(&self.expected()).unwrap_err().0
    }
}

#[test]
fn exact_signed_complete_native_handoff_is_valid_and_rechecked() {
    let fixture = Fixture::new();
    let accepted = attestation::verify(&fixture.expected()).unwrap();
    assert_eq!(accepted.generation, fixture.generation);
    assert!(attestation::verify_current(&fixture.expected(), &accepted).is_ok());
    let mut bytes = std::fs::read(&fixture.receipt).unwrap();
    bytes.push(b' '); // Same JSON value, different exact signed payload bytes.
    std::fs::write(&fixture.receipt, bytes).unwrap();
    assert_eq!(
        attestation::verify_current(&fixture.expected(), &accepted)
            .unwrap_err()
            .0,
        "attestationChanged"
    );
}

#[test]
fn malformed_and_tampered_signature_are_rejected_without_native_details() {
    let fixture = Fixture::new();
    fixture.sign_bytes(b"not-json");
    assert_eq!(fixture.error(), "attestationMalformed");
    fixture.sign();
    std::fs::write(attestation::signature_path(&fixture.receipt), b"bad-der").unwrap();
    assert_eq!(fixture.error(), "attestationSignatureInvalid");
    fixture.sign();
    let mut bytes = std::fs::read(&fixture.receipt).unwrap();
    bytes.push(b' ');
    std::fs::write(&fixture.receipt, bytes).unwrap();
    assert_eq!(fixture.error(), "attestationSignatureInvalid");
}

#[test]
fn stale_future_boot_and_generation_replay_fail_closed() {
    let mut fixture = Fixture::new();
    fixture.payload["issuedAtElapsedMs"] = json!(attestation::elapsed_ms().unwrap() + 10000);
    fixture.sign();
    assert_eq!(fixture.error(), "attestationStale");
    fixture.payload["issuedAtElapsedMs"] = json!(1);
    fixture.sign();
    assert_eq!(fixture.error(), "attestationStale");
    fixture.payload["issuedAtElapsedMs"] = json!(attestation::elapsed_ms().unwrap());
    fixture.payload["generation"] = json!(uuid::Uuid::new_v4().to_string());
    fixture.sign();
    assert_eq!(fixture.error(), "attestationGenerationMismatch");
    fixture.payload["generation"] = json!(fixture.generation);
    fixture.payload["bootId"] = json!(uuid::Uuid::new_v4().to_string());
    fixture.sign();
    assert_eq!(fixture.error(), "attestationBootMismatch");
}

#[test]
fn signer_pin_binary_mismatch_and_missing_controls_reject_authority() {
    let mut fixture = Fixture::new();
    let original_key = fixture.key_hash.clone();
    fixture.key_hash = "b".repeat(64);
    assert_eq!(fixture.error(), "attestationKeyMismatch");
    fixture.key_hash = original_key;
    fixture.payload["controls"]["nativeAttacksDenied"] = json!(false);
    fixture.sign();
    assert_eq!(fixture.error(), "attestationIncomplete");
    fixture.payload["controls"]["nativeAttacksDenied"] = json!(true);
    fixture.sign();
    std::fs::write(
        fixture
            .engine
            .parent()
            .unwrap()
            .join("libaiteam_sandbox.so"),
        "replaced",
    )
    .unwrap();
    assert_eq!(fixture.error(), "attestationBinaryMismatch");
}

#[test]
fn profile_parent_policy_and_symlink_replacements_are_not_authority() {
    let mut fixture = Fixture::new();
    for (field, value) in [
        ("profileId", json!("other")),
        ("parentPid", json!(1)),
        ("policySha256", json!("b".repeat(64))),
        ("protectedLaunchesRequired", json!(false)),
    ] {
        let original = fixture.payload[field].clone();
        fixture.payload[field] = value;
        fixture.sign();
        assert_eq!(fixture.error(), "attestationGenerationMismatch");
        fixture.payload[field] = original;
    }
    fixture.sign();
    let alias = fixture.receipt.with_extension("alias");
    std::os::unix::fs::symlink(&fixture.receipt, &alias).unwrap();
    let expected = AttestationExpectation {
        receipt_file: Path::new(&alias),
        ..fixture.expected()
    };
    assert_eq!(
        attestation::verify(&expected).unwrap_err().0,
        "attestationFileUnavailable"
    );
}
