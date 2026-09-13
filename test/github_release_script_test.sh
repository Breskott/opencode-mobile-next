#!/usr/bin/env bash
# Mocked publication contract: no GitHub access, signing keys or build processes.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
task_root="$(mktemp -d)"
trap 'rm -rf -- "$task_root"' EXIT
mkdir -p "$task_root/dist" "$task_root/scripts" "$task_root/mock-bin" "$task_root/docs/releases" "$task_root/artifact"
cp "$repo_root/scripts/"{release.sh,release_github.sh,verify_github_release.py} "$task_root/scripts/"
printf 'version: 1.0.43+49\n' > "$task_root/pubspec.yaml"
printf '# OpenCode Mobile 1.0.43+49\n\nFixture release notes.\n' > "$task_root/docs/releases/v1.0.43+49.md"
printf 'fixture signed APK bytes\n' > "$task_root/artifact/opencode-mobile-1.0.43+49.apk"
python3 - "$task_root" <<'PY'
import hashlib
from pathlib import Path
import sys
root = Path(sys.argv[1])
name = 'opencode-mobile-1.0.43+49.apk'
(root/'artifact/SHA256SUMS').write_text(hashlib.sha256((root/'artifact'/name).read_bytes()).hexdigest()+'  '+name+'\n')
(root/'artifact/RELEASE_NOTES.md').write_text((root/'docs/releases/v1.0.43+49.md').read_text()+'\n## Verify this build\n\n- Source commit: `'+('a'*40)+'`\n')
PY
cat > "$task_root/mock-bin/git" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  status) printf '%s' "${MOCK_DIRTY:-}" ;;
  symbolic-ref) echo "${MOCK_BRANCH:-master}" ;;
  rev-list) echo "${MOCK_COUNTS:-0 0}" ;;
  remote) echo "${MOCK_REMOTE:-https://github.com/Eslamasabry/opencode-mobile-next.git}" ;;
  fetch) [[ "${MOCK_FETCH_FAIL:-false}" == false ]] ;;
  rev-parse)
    case "$2" in
      --is-inside-work-tree) echo true ;;
      --abbrev-ref) echo mobile-next/master ;;
      --verify)
        [[ "${MOCK_TAG_MISSING:-false}" == false ]] || exit 1
        echo "${MOCK_TAG_HEAD:-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}"
        ;;
      HEAD) echo aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ;;
      *) exit 99 ;;
    esac ;;
  *) exit 99 ;;
esac
MOCK
cat > "$task_root/mock-bin/apksigner" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
echo "Signer #1 certificate SHA-256 digest: ${MOCK_CERT:-842284B27AA297FB74CF831779FD16498517E1BC2104451459FEC2EA7AC11D1C}"
MOCK
cat > "$task_root/mock-bin/aapt" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
echo "package: name='${MOCK_PACKAGE:-io.github.eslamasabry.opencode_mobile}' versionCode='${MOCK_CODE:-49}' versionName='1.0.43'"
MOCK
cat > "$task_root/mock-bin/gh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_ROOT/commands.log"
exec python3 "$MOCK_ROOT/gh-fixture.py" "$@"
MOCK
for tool in flutter shorebird; do
  printf '#!/usr/bin/env bash\necho "Unexpected build process" >&2\nexit 99\n' > "$task_root/mock-bin/$tool"
done
cat > "$task_root/gh-fixture.py" <<'PY'
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
args = sys.argv[1:]
root = Path(os.environ['MOCK_ROOT'])
head = os.getenv('MOCK_CI_HEAD', 'a'*40)
notes = (root/'artifact/RELEASE_NOTES.md').read_text()
def flag(name):
    return os.getenv(name) == 'true'
def release():
    assets = [dict(id=1, name='opencode-mobile-1.0.43+49.apk'), dict(id=2, name='SHA256SUMS')]
    if flag('MOCK_UNEXPECTED_APK'):
        assets.append(dict(id=3, name='unverified.apk'))
    if flag('MOCK_DUPLICATE_ASSET'):
        assets.append(dict(id=4, name='opencode-mobile-1.0.43+49.apk'))
    return dict(id=1, tag_name='v1.0.43+49', assets=assets, draft=not ((root/'published').exists() or flag('MOCK_PUBLISHED')), prerelease=flag('MOCK_PRERELEASE'), body='wrong notes' if flag('MOCK_NOTES') else notes)
if args[0] == 'api':
    path = args[1]
    assert path.startswith('repos/Eslamasabry/opencode-mobile-next/')
    if '/jobs?' in path:
        names = ['Verify generated OpenCode SDK integrity', 'Test generated OpenCode SDK', 'Analyze generated OpenCode SDK', 'Analyze', 'Check the serial test runner', 'Test', 'Run Android release lint', 'Compile test-signed release APK', 'Verify release artifact exists']
        print(json.dumps(dict(jobs=[dict(conclusion='success', steps=[dict(name=name, conclusion='skipped' if name == 'Test' and flag('MOCK_APK_ONLY') else 'success') for name in names])])))
    elif '/actions/runs/' in path:
        workflow = 'android-quality' if path.endswith('/101') else 'android-release'
        print(json.dumps(dict(head_sha=head, path=f'.github/workflows/{workflow}.yml', status='completed', conclusion='failure' if flag('MOCK_CI_FAILED') else 'success', event='workflow_dispatch')))
    elif '/releases/' in path:
        print(json.dumps(release()))
    else:
        raise RuntimeError(path)
elif args[:2] in (['run', 'download'], ['release', 'download']):
    assert args[args.index('--repo')+1] == 'Eslamasabry/opencode-mobile-next'
    target = Path(args[args.index('--dir')+1])
    for item in (root/'artifact').iterdir():
        shutil.copyfile(item, target/item.name)
    if args[0] == 'run':
        assert args[args.index('--name')+1] == 'opencode-mobile-signed-'+('a'*40)
    elif flag('MOCK_DRAFT_DIFFERENT'):
        apk = target/'opencode-mobile-1.0.43+49.apk'
        apk.write_text('different bytes')
        (target/'SHA256SUMS').write_text(hashlib.sha256(apk.read_bytes()).hexdigest()+'  '+apk.name+'\n')
    elif flag('MOCK_BAD_CHECKSUM'):
        (target/'SHA256SUMS').write_text('0'*64+'  opencode-mobile-1.0.43+49.apk\n')
elif args[:2] == ['release', 'view']:
    if flag('MOCK_RELEASE_ABSENT'):
        raise SystemExit(1)
    print(json.dumps(dict(isDraft=not flag('MOCK_PUBLISHED'))))
elif args[:2] == ['release', 'edit']:
    if '--draft=false' in args:
        assert all(value in args for value in ['--prerelease=false', '--latest'])
        (root/'published').touch()
    else:
        assert all(value in args for value in ['--draft', '--prerelease=false'])
        (root/'draft-touched').touch()
elif args[:2] == ['release', 'create']:
    assert all(value in args for value in ['--verify-tag', '--draft', '--prerelease=false'])
    (root/'draft-touched').touch()
elif args[:2] == ['release', 'upload']:
    (root/'draft-touched').touch()
else:
    raise RuntimeError(args)
PY
chmod +x "$task_root/mock-bin/"*

# release.sh prefers configured Android SDK tools; supply fixture tools there too.
mkdir -p "$task_root/sdk/build-tools/99.0.0"
cp "$task_root/mock-bin/"{apksigner,aapt} "$task_root/sdk/build-tools/99.0.0/"
case_number=0
run_case() {
  local expected="$1" mode="$2"
  shift 2
  case_number=$((case_number + 1))
  rm -f "$task_root/published"
  : > "$task_root/commands.log"
  local result=0
  local publish_args=()
  [[ "$mode" == publish ]] && publish_args=(--publish)
  env PATH="$task_root/mock-bin:$PATH" MOCK_ROOT="$task_root" \
    ANDROID_HOME="$task_root/sdk" OC_RELEASE_BUILD_RUN_ID=102 OC_RELEASE_QUALITY_RUN_ID=101 \
    "$@" bash "$task_root/scripts/release.sh" github "${publish_args[@]}" \
    > "$task_root/result.log" 2>&1 || result=$?
  if [[ "$expected" == pass && "$result" != 0 ]] || [[ "$expected" == fail && "$result" == 0 ]]; then
    cat "$task_root/result.log"
    echo "FAIL: case $case_number expected $expected, exit $result" >&2
    exit 1
  fi
  if [[ "$expected" == pass && "$mode" == publish ]]; then
    [[ -f "$task_root/published" ]] || { echo 'Publication did not occur'; exit 1; }
  else
    [[ ! -f "$task_root/published" ]] || { echo 'Unexpected publication'; exit 1; }
  fi
}
run_case pass dry
run_case pass publish
run_case fail publish MOCK_BRANCH=dev
run_case fail publish MOCK_DIRTY=' M pubspec.yaml'
run_case fail publish MOCK_COUNTS='1 0'
run_case fail publish MOCK_REMOTE=https://github.com/Eslamasabry/opencode-mobile.git
run_case fail publish MOCK_TAG_MISSING=true
run_case fail publish MOCK_TAG_HEAD=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
run_case fail publish MOCK_CI_HEAD=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
run_case fail publish MOCK_CI_FAILED=true
run_case fail publish MOCK_APK_ONLY=true
run_case fail publish MOCK_PUBLISHED=true
run_case fail publish MOCK_PRERELEASE=true
run_case fail publish MOCK_NOTES=true
run_case fail publish MOCK_DRAFT_DIFFERENT=true
run_case fail publish MOCK_BAD_CHECKSUM=true
run_case fail publish MOCK_UNEXPECTED_APK=true
run_case fail publish MOCK_DUPLICATE_ASSET=true
run_case fail publish MOCK_CERT=2D010C2103CB2F78ABAACA690EAD4D45F8003A6C0A02082CD2A2AE62FD18D0EC
run_case fail publish MOCK_PACKAGE=other.application
run_case fail publish MOCK_CODE=48
run_case fail publish OC_RELEASE_BUILD_RUN_ID=
# Execute the actual workflow draft-staging shell with the same no-network gh.
python3 - "$repo_root" "$task_root" <<'PYWORKFLOW'
from pathlib import Path
import sys
source = (Path(sys.argv[1])/'.github/workflows/android-release.yml').read_text()
body = source.split('      - name: Create draft stable GitHub release\n', 1)[1].split('        run: |\n', 1)[1]
(Path(sys.argv[2])/'stage-draft.sh').write_text('\n'.join(line[10:] if line.startswith('          ') else line for line in body.splitlines())+'\n')
PYWORKFLOW
run_draft_case() {
  local expected="$1"
  shift
  case_number=$((case_number + 1))
  rm -f "$task_root/draft-touched"
  local result=0
  env PATH="$task_root/mock-bin:$PATH" MOCK_ROOT="$task_root" \
    GITHUB_REF_NAME=v1.0.43+49 RUNNER_TEMP="$task_root" "$@" \
    bash "$task_root/stage-draft.sh" > "$task_root/result.log" 2>&1 || result=$?
  if [[ "$expected" == pass ]]; then
    [[ "$result" == 0 && -f "$task_root/draft-touched" ]] || {
      cat "$task_root/result.log"; echo 'Draft staging failed'; exit 1;
    }
  else
    [[ "$result" != 0 && ! -f "$task_root/draft-touched" ]] || {
      cat "$task_root/result.log"; echo 'Published release was modified'; exit 1;
    }
  fi
}
run_draft_case pass
run_draft_case pass MOCK_RELEASE_ABSENT=true
run_draft_case fail MOCK_PUBLISHED=true
echo "PASS: $case_number GitHub publication contract cases"
