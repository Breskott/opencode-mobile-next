"""Host protocol/argument checks; no adb device, model, Flutter or signing."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "phone_engine_acceptance.sh"
STEPS = (
    "engine_start_proof", "scratch_repo", "approved_plan", "checked_dev_merge",
    "unconfirmed_promotion_refused", "confirmed_promotion_receipt",
)
MOCK_ADB = r'''#!/usr/bin/env python3
import os, sys
from pathlib import Path
args = sys.argv[1:]
assert args[:2] == ["-s", "emulator-5554"], args
cmd = args[2:]
Path(os.environ["MOCK_CALLED"]).write_text("called")
stable = os.environ.get("MOCK_STABLE") == "1"
package = "io.github.eslamasabry.opencode_mobile" + ("" if stable else ".preview")
if cmd == ["get-state"]:
    print(os.environ.get("MOCK_STATE", "device"))
elif cmd == ["shell", "getprop", "ro.product.cpu.abi"]:
    print(os.environ.get("MOCK_ABI", "x86_64"))
elif cmd[:3] == ["shell", "pm", "path"]:
    if not os.environ.get("MOCK_MISSING_PACKAGE"):
        print("package:/data/app/isolated/base.apk")
elif cmd == ["shell", "pm", "list", "instrumentation"]:
    if not os.environ.get("MOCK_MISSING_RUNNER"):
        print("instrumentation:" + package + ".test/io.github.eslamasabry.opencode_mobile.PhoneEngineAcceptance (target=" + package + ")")
elif cmd[:3] == ["shell", "am", "instrument"]:
    assert cmd == ["shell", "am", "instrument", "-w", "-r",
        "-e", "server", "http://127.0.0.1:4097", "-e", "model", "example/test-model",
        "-e", "timeoutSeconds", "30", "-e", "isolatedQa", "false" if stable else "true",
        "-e", "stableAppQa", "true" if stable else "false",
        "-e", "allowModelSpend", "true",
        package + ".test/io.github.eslamasabry.opencode_mobile.PhoneEngineAcceptance"], cmd
    sys.stdout.write(Path(os.environ["MOCK_TRANSCRIPT"]).read_text())
    sys.exit(int(os.environ.get("MOCK_EXIT", "0")))
else:
    raise AssertionError(cmd)
'''


def transcript(steps=STEPS, result="PASS", code="-1"):
    lines = [f"INSTRUMENTATION_STATUS: phoneEngineStep=PASS {step}" for step in steps]
    lines += [f"INSTRUMENTATION_RESULT: phoneEngineResult={result}", f"INSTRUMENTATION_CODE: {code}"]
    return "\n".join(lines) + "\n"


class PhoneEngineAcceptanceTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.adb = self.root / "adb"
        self.adb.write_text(MOCK_ADB)
        self.adb.chmod(0o755)
        self.output = self.root / "transcript"
        self.called = self.root / "called"
        self.output.write_text(transcript())

    def run_script(self, extra=(), env_extra=None, consent=True):
        env = dict(os.environ, MOCK_CALLED=str(self.called), MOCK_TRANSCRIPT=str(self.output))
        env.update(env_extra or {})
        command = [str(SCRIPT), "--serial", "emulator-5554", "--server", "http://127.0.0.1:4097",
                   "--model", "example/test-model", "--timeout-seconds", "30", "--adb", str(self.adb)]
        if consent:
            command += ["--isolated-qa", "--allow-model-spend"]
        return subprocess.run(command + list(extra), env=env, capture_output=True, text=True, timeout=10)

    def test_success_requires_all_six_steps_and_success_finish(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(result.stdout.splitlines(), ["PASS preflight x86_64"] +
                         [f"PASS {step}" for step in STEPS] + ["PASS acceptance"])

    def test_arm64_is_supported(self):
        result = self.run_script(env_extra={"MOCK_ABI": "arm64-v8a"})
        self.assertEqual(result.returncode, 0)
        self.assertIn("PASS preflight arm64-v8a", result.stdout)

    def test_sensitive_output_and_optional_codes_are_discarded(self):
        data = transcript().replace("PASS engine_start_proof", "PASS engine_start_proof private-token")
        self.output.write_text("private-token provider exception /private/path\n" + data)
        result = self.run_script()
        self.assertEqual(result.returncode, 0)
        self.assertNotIn("private-token", result.stdout + result.stderr)
        self.assertNotIn("/private/path", result.stdout + result.stderr)

    def test_incomplete_steps_fail(self):
        self.output.write_text(transcript(STEPS[:-1]))
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL acceptance incomplete_steps", result.stdout)

    def test_duplicate_out_of_order_unknown_and_malformed_steps_fail(self):
        for steps in ((STEPS[0],) + STEPS, tuple(reversed(STEPS)), STEPS + ("unknown_step",)):
            with self.subTest(steps=steps):
                self.output.write_text(transcript(steps))
                result = self.run_script()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("invalid_step_protocol", result.stdout)
        self.output.write_text(transcript().replace("PASS engine_start_proof", "PASS engine_start_proof private key secret"))
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("private key secret", result.stdout + result.stderr)

    def test_failure_step_cannot_be_overridden_by_final_pass(self):
        self.output.write_text(transcript().replace("PASS checked_dev_merge", "FAIL checked_dev_merge"))
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL checked_dev_merge", result.stdout)

    def test_missing_duplicate_and_failed_result_code_fail(self):
        data = transcript()
        variants = [data.replace("INSTRUMENTATION_CODE: -1\n", ""),
                    data.replace("phoneEngineResult=PASS", "phoneEngineResult=FAIL"),
                    data.replace("INSTRUMENTATION_CODE: -1", "INSTRUMENTATION_CODE: 0"),
                    data + "INSTRUMENTATION_RESULT: phoneEngineResult=PASS\n",
                    data + "INSTRUMENTATION_CODE: -1\n"]
        for variant in variants:
            with self.subTest(variant=variant):
                self.output.write_text(variant)
                self.assertNotEqual(self.run_script().returncode, 0)

    def test_android_crash_error_and_adb_exit_fail_even_after_pass(self):
        for prefix in ("INSTRUMENTATION_FAILED:", "INSTRUMENTATION_RESULT: shortMsg=",
                       "INSTRUMENTATION_STATUS: Error=", "Error:"):
            with self.subTest(prefix=prefix):
                self.output.write_text(transcript() + prefix + "private-token\n")
                result = self.run_script()
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("private-token", result.stdout + result.stderr)
        self.output.write_text(transcript())
        self.assertNotEqual(self.run_script(env_extra={"MOCK_EXIT": "1"}).returncode, 0)

    def test_final_line_without_newline_is_accepted(self):
        self.output.write_text(transcript().rstrip())
        self.assertEqual(self.run_script().returncode, 0)

    def test_unsafe_or_nonisolated_arguments_fail_before_adb(self):
        cases = [("--server", "http://localhost:4097"), ("--server", "http://example.test"),
                 ("--package", "io.github.eslamasabry.opencode_mobile"),
                 ("--model", "example/test;touch injected"), ("--model", "example/$(id)"),
                 ("--serial", "emulator-5554;id"), ("--timeout-seconds", "0")]
        for extra in cases:
            with self.subTest(extra=extra):
                result = self.run_script(extra=extra)
                self.assertEqual(result.returncode, 64)
                self.assertFalse(self.called.exists())

    def test_consent_flags_required(self):
        result = self.run_script(consent=False)
        self.assertEqual(result.returncode, 64)
        self.assertFalse(self.called.exists())

    def test_stable_requires_exact_package_explicit_optin_and_stage_cleanup_evidence(self):
        stable_args = ("--package", "io.github.eslamasabry.opencode_mobile", "--stable-app-qa", "--allow-model-spend")
        evidence = ["INSTRUMENTATION_STATUS: phoneEngineStage=PASS " + stage for stage in
                    ("project_created", "planner_completed", "plan_approved", "worker_completed", "checker_completed", "dev_merged")]
        evidence.append("INSTRUMENTATION_STATUS: phoneEngineCleanup=PASS stable_server_restored")
        body = transcript().replace("INSTRUMENTATION_RESULT:", "\n".join(evidence) + "\nINSTRUMENTATION_RESULT:")
        self.output.write_text(body)
        result = self.run_script(extra=stable_args, env_extra={"MOCK_STABLE": "1"}, consent=False)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("PASS worker_completed", result.stdout)
        self.assertIn("PASS project_created", result.stdout)
        self.assertIn("PASS planner_completed", result.stdout)
        self.assertIn("PASS plan_approved", result.stdout)
        self.assertIn("PASS checker_completed", result.stdout)
        self.assertIn("PASS stable_server_restored", result.stdout)
        self.output.write_text(transcript())
        result = self.run_script(extra=stable_args, env_extra={"MOCK_STABLE": "1"}, consent=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("incomplete_stable_evidence", result.stdout)

    def test_ambiguous_target_and_failed_cleanup_fail(self):
        result = self.run_script(extra=("--stable-app-qa",))
        self.assertEqual(result.returncode, 64)
        self.assertFalse(self.called.exists())
        self.output.write_text(transcript().replace("INSTRUMENTATION_RESULT:",
            "INSTRUMENTATION_STATUS: phoneEngineCleanup=FAIL private-token\nINSTRUMENTATION_RESULT:"))
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("private-token", result.stdout + result.stderr)

    def test_device_app_runner_and_abi_preflight_failures(self):
        for env in ({"MOCK_STATE": "offline"}, {"MOCK_ABI": "armeabi-v7a"},
                    {"MOCK_MISSING_PACKAGE": "1"}, {"MOCK_MISSING_RUNNER": "1"}):
            with self.subTest(env=env):
                result = self.run_script(env_extra=env)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("PASS acceptance", result.stdout)


if __name__ == "__main__":
    unittest.main()
