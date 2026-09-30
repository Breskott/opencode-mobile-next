#!/usr/bin/env bash
# Runs already-installed release instrumentation with an explicit QA target. No install,
# signing, app-data export, public QA endpoint, or emulator startup occurs here.
set -euo pipefail
exec python3 - "$@" <<'PY'
import argparse
import os
import re
import selectors
import shutil
import subprocess
import sys
import time

STEPS = (
    "engine_start_proof", "scratch_repo", "approved_plan", "checked_dev_merge",
    "unconfirmed_promotion_refused", "confirmed_promotion_receipt",
)
STAGES = ("planner_completed", "worker_completed", "checker_completed", "dev_merged")


def fail(step, code, exit_code=1):
    print(f"FAIL {step} {code}", flush=True)
    raise SystemExit(exit_code)


parser = argparse.ArgumentParser(
    description="Exercise the real phone engine through installed test-only instrumentation.",
    epilog="Install the matching app and release androidTest APK separately. "
           "This command restarts the selected app process and permits model usage. "
           "Stable testing requires explicit --stable-app-qa and the exact stable package.",
)
parser.add_argument("--serial", required=True)
parser.add_argument("--server", required=True, help="Phone URL: http://127.0.0.1:4097")
parser.add_argument("--model", required=True, help="Authenticated provider/model identifier")
parser.add_argument("--isolated-qa", action="store_true")
parser.add_argument("--stable-app-qa", action="store_true", help="Explicit existing stable-app QA; restarts its process, preserves data")
parser.add_argument("--allow-model-spend", action="store_true")
parser.add_argument("--package", default="io.github.eslamasabry.opencode_mobile.preview")
parser.add_argument("--timeout-seconds", type=int, default=900)
parser.add_argument("--adb", help="Path to adb; otherwise PATH or Android SDK")
args = parser.parse_args()

if args.isolated_qa == args.stable_app_qa or not args.allow_model_spend:
    fail("preflight", "explicit_qa_and_model_consent_required", 64)
if args.server != "http://127.0.0.1:4097":
    fail("preflight", "phone_loopback_server_required", 64)
if not re.fullmatch(r"[A-Za-z0-9_.:-]{1,128}", args.serial):
    fail("preflight", "invalid_serial", 64)
# adb shell rejoins argv on the device: allow only literal, shell-safe identifiers.
if len(args.model) > 256 or not re.fullmatch(r"[A-Za-z0-9_.:-]+/[A-Za-z0-9_./:-]+", args.model):
    fail("preflight", "invalid_model_identifier", 64)
expected_package = "io.github.eslamasabry.opencode_mobile" + ("" if args.stable_app_qa else ".preview")
if args.package != expected_package:
    fail("preflight", "explicit_target_package_required", 64)
if not 30 <= args.timeout_seconds <= 3600:
    fail("preflight", "invalid_timeout", 64)

sdk = os.environ.get("ANDROID_SDK_ROOT") or os.environ.get("ANDROID_HOME") or os.path.expanduser("~/Android/Sdk")
adb = args.adb or shutil.which("adb") or os.path.join(sdk, "platform-tools", "adb")
if not os.path.isfile(adb) or not os.access(adb, os.X_OK):
    fail("preflight", "adb_not_executable", 64)
base = [adb, "-s", args.serial]


def preflight(*command):
    try:
        result = subprocess.run(base + list(command), stdout=subprocess.PIPE,
                                stderr=subprocess.DEVNULL, timeout=15, check=False)
    except (OSError, subprocess.TimeoutExpired):
        fail("preflight", "adb_command_failed")
    if result.returncode != 0 or len(result.stdout) > 65536:
        fail("preflight", "adb_command_failed")
    return result.stdout.decode("utf-8", errors="replace").strip()


if preflight("get-state") != "device":
    fail("preflight", "device_not_ready")
abi = preflight("shell", "getprop", "ro.product.cpu.abi")
if abi not in ("arm64-v8a", "x86_64"):
    fail("preflight", "unsupported_device_abi")
test_package = args.package + ".test"
runner = "io.github.eslamasabry.opencode_mobile.PhoneEngineAcceptance"
component = test_package + "/" + runner
for package in (args.package, test_package):
    paths = preflight("shell", "pm", "path", package).splitlines()
    if not paths or any(not path.startswith("package:/") for path in paths):
        fail("preflight", "matching_app_and_test_apks_required")
instrumentations = preflight("shell", "pm", "list", "instrumentation").splitlines()
expected = f"instrumentation:{component} (target={args.package})"
if expected not in instrumentations:
    fail("preflight", "matching_instrumentation_required")
print(f"PASS preflight {abi}", flush=True)

command = base + ["shell", "am", "instrument", "-w", "-r",
                  "-e", "server", args.server, "-e", "model", args.model,
                  "-e", "timeoutSeconds", str(args.timeout_seconds),
                  "-e", "isolatedQa", "true" if args.isolated_qa else "false",
                  "-e", "stableAppQa", "true" if args.stable_app_qa else "false",
                  "-e", "allowModelSpend", "true", component]
process = None
try:
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    deadline = time.monotonic() + args.timeout_seconds + 30
    pending = b""
    total = 0
    seen = []
    seen_stages = []
    cleanup_passed = False
    final_result = None
    final_code = None
    malformed = False
    protocol_failure = False

    def line_received(raw):
        global final_result, final_code, malformed, protocol_failure, cleanup_passed
        line = raw.decode("utf-8", errors="replace").strip()
        if line.startswith("INSTRUMENTATION_STATUS: phoneEngineStep="):
            value = line.partition("phoneEngineStep=")[2]
            match = re.fullmatch(r"(PASS|FAIL) ([a-z_]+)(?: ([A-Za-z0-9_.:-]{1,128}))?", value)
            if not match:
                malformed = True
                return
            outcome, step, code = match.groups()
            if final_result is not None or final_code is not None or step not in STEPS or step in seen or len(seen) >= len(STEPS) or step != STEPS[len(seen)]:
                malformed = True
                return
            seen.append(step)
            # Even a syntactically safe code could contain a token. Only the
            # fixed step and outcome vocabulary is relayed to the host terminal.
            print(f"{outcome} {step}", flush=True)
            if outcome == "FAIL":
                protocol_failure = True
        elif line.startswith("INSTRUMENTATION_STATUS: phoneEngineStage="):
            value = line.partition("phoneEngineStage=")[2]
            if final_result is not None or len(seen_stages) >= len(STAGES) or value != "PASS " + STAGES[len(seen_stages)]:
                malformed = True
                return
            stage = STAGES[len(seen_stages)]
            seen_stages.append(stage)
            print("PASS " + stage, flush=True)
        elif line.startswith("INSTRUMENTATION_STATUS: phoneEngineCleanup="):
            value = line.partition("phoneEngineCleanup=")[2]
            if cleanup_passed or final_result is not None or value != "PASS stable_server_restored":
                protocol_failure = True
            else:
                cleanup_passed = True
                print("PASS stable_server_restored", flush=True)
        elif line.startswith("INSTRUMENTATION_RESULT: phoneEngineResult="):
            value = line.partition("phoneEngineResult=")[2]
            if final_result is not None or value not in ("PASS", "FAIL"):
                malformed = True
            final_result = value
        elif line.startswith("INSTRUMENTATION_CODE:"):
            value = line.partition(":")[2].strip()
            if final_result is None or final_code is not None or not re.fullmatch(r"-?[0-9]{1,4}", value):
                malformed = True
            final_code = value
        elif line.startswith(("INSTRUMENTATION_FAILED:", "INSTRUMENTATION_ABORTED:",
                              "INSTRUMENTATION_RESULT: shortMsg=", "INSTRUMENTATION_RESULT: longMsg=",
                              "INSTRUMENTATION_STATUS: Error=", "Error:", "Failure ")):
            protocol_failure = True
        # Deliberately discard all other adb/runner output, including exceptions,
        # private paths, provider text and instrumentation's default stream field.

    while selector.get_map():
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            fail("acceptance", "timeout")
        for key, _ in selector.select(min(remaining, 1)):
            chunk = os.read(key.fd, 4096)
            if not chunk:
                selector.unregister(key.fileobj)
                if pending:
                    line_received(pending)
                    pending = b""
                continue
            total += len(chunk)
            if total > 4 * 1024 * 1024:
                fail("acceptance", "output_limit")
            pending += chunk
            while b"\n" in pending:
                line, pending = pending.split(b"\n", 1)
                if len(line) > 4096:
                    fail("acceptance", "invalid_runner_output")
                line_received(line)
            if len(pending) > 4096:
                fail("acceptance", "invalid_runner_output")
    return_code = process.wait(timeout=max(1, deadline - time.monotonic()))
    if malformed:
        fail("acceptance", "invalid_step_protocol")
    if protocol_failure or return_code != 0 or final_result != "PASS" or final_code != "-1":
        fail("acceptance", "instrumentation_failed")
    if tuple(seen) != STEPS:
        fail("acceptance", "incomplete_steps")
    if args.stable_app_qa and (tuple(seen_stages) != STAGES or not cleanup_passed):
        fail("acceptance", "incomplete_stable_evidence")
    print("PASS acceptance", flush=True)
except KeyboardInterrupt:
    fail("acceptance", "interrupted", 130)
except (OSError, subprocess.TimeoutExpired):
    fail("acceptance", "adb_command_failed")
finally:
    if process is not None and process.poll() is None:
        # Stop only this host adb client. The native test owns bounded cleanup;
        # never kill device processes by pattern or stop the person's server.
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)
PY
