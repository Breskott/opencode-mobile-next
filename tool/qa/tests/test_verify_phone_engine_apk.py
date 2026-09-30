"""Packaged-byte regression checks; no Gradle, Android, models or signing."""
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import warnings
import zipfile


SCRIPT = Path(__file__).resolve().parents[1] / "verify_phone_engine_apk.py"
SPEC = importlib.util.spec_from_file_location("verify_phone_engine_apk", SCRIPT)
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


class PhoneEngineApkTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.payloads = {
            f"lib/{abi}/{library}": f"unstripped fixture {abi}/{library}".encode()
            for abi in ("arm64-v8a", "x86_64") for library in CHECK.ENGINE_LIBRARIES
        }
        self.manifest = {
            "schemaVersion": 2,
            "abis": {abi: {"sha256": {
                library: hashlib.sha256(self.payloads[f"lib/{abi}/{library}"]).hexdigest()
                for library in CHECK.ENGINE_LIBRARIES
            }} for abi in ("arm64-v8a", "x86_64")},
        }
        self.manifest_data = json.dumps(self.manifest).encode()
        self.manifest_path = self.root / "manifest.json"
        self.manifest_path.write_bytes(self.manifest_data)
        self.apk = self.root / "app-release.apk"

    def write_apk(self, payloads=None, manifest_data=None, duplicate=None, path=None):
        path = path or self.apk
        with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            archive.writestr(CHECK.MANIFEST_ENTRY, manifest_data or self.manifest_data)
            for name, payload in (self.payloads if payloads is None else payloads).items():
                archive.writestr(name, payload)
            if duplicate:
                with warnings.catch_warnings():
                    warnings.simplefilter("ignore", UserWarning)
                    archive.writestr(duplicate, b"other bytes")
        return path

    def test_unstripped_universal_apk_passes_with_all_actual_hashes(self):
        self.write_apk()
        results = CHECK.verify_apk(self.apk, self.manifest_data)
        self.assertEqual(len(results), 6)
        for abi, library, actual in results:
            self.assertEqual(actual, self.manifest["abis"][abi]["sha256"][library])

    def test_stripped_packaged_bytes_fail_even_when_staged_manifest_is_valid(self):
        payloads = dict(self.payloads)
        payloads["lib/x86_64/libaiteam_engine.so"] = b"AGP stripped fixture"
        self.write_apk(payloads)
        with self.assertRaisesRegex(CHECK.VerificationError, "hash_mismatch"):
            CHECK.verify_apk(self.apk, self.manifest_data)

    def test_missing_library_fails(self):
        payloads = dict(self.payloads)
        del payloads["lib/x86_64/libaiteam_sandbox.so"]
        self.write_apk(payloads)
        with self.assertRaisesRegex(CHECK.VerificationError, "missing_library"):
            CHECK.verify_apk(self.apk, self.manifest_data)

    def test_missing_whole_declared_abi_fails_universal_check(self):
        self.write_apk({name: data for name, data in self.payloads.items() if "/x86_64/" in name})
        with self.assertRaisesRegex(CHECK.VerificationError, "missing_library"):
            CHECK.verify_apk(self.apk, self.manifest_data)

    def test_duplicate_zip_library_or_manifest_fails(self):
        for name in (CHECK.MANIFEST_ENTRY, "lib/x86_64/libaiteam_engine.so"):
            with self.subTest(name=name):
                self.write_apk(duplicate=name)
                with self.assertRaisesRegex(CHECK.VerificationError, "duplicate_zip_entry"):
                    CHECK.verify_apk(self.apk, self.manifest_data)

    def test_embedded_manifest_cannot_be_changed_to_match_rewritten_binary(self):
        manifest = json.loads(self.manifest_data)
        manifest["sourceRevision"] = "changed-after-staging"
        self.write_apk(manifest_data=json.dumps(manifest).encode())
        with self.assertRaisesRegex(CHECK.VerificationError, "packaged_manifest_mismatch"):
            CHECK.verify_apk(self.apk, self.manifest_data)

    def test_missing_embedded_manifest_fails(self):
        with zipfile.ZipFile(self.apk, "w") as archive:
            archive.writestr("classes.dex", b"fixture")
        with self.assertRaisesRegex(CHECK.VerificationError, "missing_manifest"):
            CHECK.verify_apk(self.apk, self.manifest_data)

    def test_unknown_engine_library_or_abi_fails(self):
        for name in ("lib/x86_64/libaiteam_unlisted.so", "lib/unknown/libaiteam_engine.so"):
            with self.subTest(name=name):
                self.write_apk(dict(self.payloads, **{name: b"fixture"}))
                with self.assertRaisesRegex(CHECK.VerificationError, "unexpected_library"):
                    CHECK.verify_apk(self.apk, self.manifest_data)

    def test_explicit_abi_filter_checks_complete_selected_abi(self):
        self.write_apk({name: data for name, data in self.payloads.items() if "/x86_64/" in name})
        self.assertEqual(len(CHECK.verify_apk(self.apk, self.manifest_data, ["x86_64"])), 3)
        with self.assertRaisesRegex(CHECK.VerificationError, "no_supported_abi"):
            CHECK.verify_apk(self.apk, self.manifest_data, ["armeabi-v7a"])

    def test_invalid_or_incomplete_manifest_is_rejected(self):
        for data in (b'{"schemaVersion":2,"schemaVersion":2,"abis":{}}',
                     b'{"schemaVersion":2,"abis":{}}',
                     b'{"schemaVersion":2,"abis":{"x86_64":{"sha256":{}}}}'):
            with self.subTest(data=data), self.assertRaises(CHECK.VerificationError):
                CHECK.manifest_hashes(data)

    def test_agp_split_metadata_limits_abi_and_ignores_stale_apks(self):
        elements = []
        for abi in self.manifest["abis"]:
            name = f"app-{abi}-release.apk"
            self.write_apk({name: data for name, data in self.payloads.items() if f"/{abi}/" in name},
                           path=self.root / name)
            elements.append({"outputFile": name, "filters": [{"filterType": "ABI", "identifier": abi}]})
        (self.root / "stale.apk").write_bytes(b"not an APK")
        (self.root / "output-metadata.json").write_text(json.dumps({"elements": elements}))
        outputs = CHECK.packaged_outputs(self.root)
        self.assertEqual(len(outputs), 2)
        for apk, abis in outputs:
            self.assertEqual(len(CHECK.verify_apk(apk, self.manifest_data, abis)), 3)

    def test_agp_metadata_cannot_escape_output_directory_or_duplicate_output(self):
        self.write_apk()
        for filenames in (("../external.apk",), (str(self.apk),), (self.apk.name, self.apk.name)):
            with self.subTest(filenames=filenames):
                (self.root / "output-metadata.json").write_text(json.dumps({"elements": [
                    {"outputFile": name, "filters": []} for name in filenames
                ]}))
                with self.assertRaisesRegex(CHECK.VerificationError, "invalid_apk_output"):
                    CHECK.packaged_outputs(self.root)

    def test_cli_failure_is_nonzero_and_success_reports_packaged_hashes(self):
        self.write_apk()
        args = [sys.executable, str(SCRIPT), "--manifest", str(self.manifest_path), "--apk", str(self.apk)]
        result = subprocess.run(args, capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PASS phone_engine_packaging", result.stdout)
        self.write_apk(dict(self.payloads, **{"lib/x86_64/libaiteam_engine.so": b"stripped"}))
        result = subprocess.run(args, capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 1)
        self.assertIn("FAIL phone_engine_packaging hash_mismatch", result.stderr)


if __name__ == "__main__":
    unittest.main()
