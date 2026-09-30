#!/usr/bin/env bash
# Build source only. Does not sign, install, publish, or invoke CI.
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/../../.." && pwd)"
ndk_dir="${ANDROID_NDK_HOME:-/home/eslam/Android/Sdk/ndk/28.2.13676358}"
artifact_dir="${OC_ENGINE_BUILD_DIR:-/home/eslam/Storage/tmp/aiteam-phone-engine-build}"
case "$artifact_dir" in /tmp|/tmp/*) echo 'Build artifacts must use Storage, not /tmp' >&2; exit 64;; esac
mkdir -p "$artifact_dir/tmp" "$artifact_dir/target" "$artifact_dir/android/arm64-v8a"
export TMPDIR="$artifact_dir/tmp"
export CARGO_TARGET_DIR="$artifact_dir/target"
ndk_bin="$ndk_dir/toolchains/llvm/prebuilt/linux-x86_64/bin"
linker="$ndk_bin/aarch64-linux-android26-clang"
[[ -x "$linker" ]] || { echo 'Android NDK compiler unavailable' >&2; exit 1; }
rustup target list --installed | rg -q '^aarch64-linux-android$' || {
  echo 'Install the Rust Android standard library: rustup target add aarch64-linux-android' >&2; exit 1;
}
export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$linker"
export CC_aarch64_linux_android="$linker"
export AR_aarch64_linux_android="$ndk_bin/llvm-ar"
export CXX_aarch64_linux_android="$ndk_bin/aarch64-linux-android26-clang++"
cargo build --manifest-path "$repo_dir/engine/phone/Cargo.toml" --locked --release --target aarch64-linux-android \
  --bin oc-phone-engine --bin oc-engine-sandbox --bin oc-engine-boundary-probe
cp "$CARGO_TARGET_DIR/aarch64-linux-android/release/oc-phone-engine" "$artifact_dir/android/arm64-v8a/libaiteam_engine.so"
cp "$CARGO_TARGET_DIR/aarch64-linux-android/release/oc-engine-sandbox" "$artifact_dir/android/arm64-v8a/libaiteam_sandbox.so"
cp "$CARGO_TARGET_DIR/aarch64-linux-android/release/oc-engine-boundary-probe" "$artifact_dir/android/arm64-v8a/libaiteam_boundary_probe.so"
python3 - "$repo_dir" "$artifact_dir" "$ndk_dir" <<'PY'
import hashlib,json,pathlib,subprocess,sys
repo,artifacts,ndk=map(pathlib.Path,sys.argv[1:])
files={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (artifacts/'android/arm64-v8a').glob('*.so')}
revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip()
dirty=bool(subprocess.check_output(['git','status','--porcelain'],cwd=repo,text=True).strip())
inputs=[repo/'engine/phone/Cargo.toml',repo/'engine/phone/Cargo.lock',*sorted((repo/'engine/phone/src').rglob('*.rs'))]
source=hashlib.sha256()
for path in inputs:
    source.update(str(path.relative_to(repo)).encode()+b'\0'+path.read_bytes()+b'\0')
manifest={'rustcVersion':subprocess.check_output(['rustc','--version'],text=True).strip(),'ndkVersion':(ndk/'source.properties').read_text().split('Pkg.Revision = ')[1].splitlines()[0],'sourceSha256':source.hexdigest(),'schemaVersion':1,'target':'aarch64-linux-android','api':26,'sourceRevision':revision,'sourceDirty':dirty,'sha256':files}
(artifacts/'android/manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Android native artifacts: '+str(artifacts/'android'))
PY
python3 "$repo_dir/engine/phone/tool/native-notices.py" "$artifact_dir/android/Rust-Phone-Engine.txt"
if [[ "${1:-}" == '--stage-android' ]]; then
  mkdir -p "$repo_dir/android/app/src/main/jniLibs/arm64-v8a"
  cp "$artifact_dir/android/arm64-v8a/"*.so "$repo_dir/android/app/src/main/jniLibs/arm64-v8a/"
  mkdir -p "$repo_dir/android/app/src/main/assets"
  cp "$artifact_dir/android/manifest.json" "$repo_dir/android/app/src/main/assets/aiteam-engine-manifest.json"
  cp "$artifact_dir/android/Rust-Phone-Engine.txt" "$repo_dir/LICENSES/Rust-Phone-Engine.txt"
  echo 'Staged native libraries, manifest and notices locally; APK signing and delivery remain separate.'
fi
