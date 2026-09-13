#!/bin/bash
set -e
export PATH=/usr/local/bin:$PATH TMPDIR=/tmp HOME=/root
mkdir -p /root/projects/aiteam-spike /root/aiteam
cd /root/projects/aiteam-spike
if [ ! -d .git ]; then
  git init -q -b master
  git config user.email spike@phone.local; git config user.name "Phone Spike"
  printf 'def add(a, b):\n    return a + b\n\n\ndef multiply(a, b):\n    return a * b\n' > calc.py
  printf '{ "$schema": "https://opencode.ai/config.json", "model": "zai-coding-plan/glm-5.3-flash", "permission": { "bash": { "*": "allow" }, "edit": "allow" } }\n' > opencode.json
  git add -A; git commit -qm init
  git init -q --bare /root/projects/aiteam-spike.git
  git remote add origin /root/projects/aiteam-spike.git
  git push -q origin master
fi
cat > /root/aiteam/city.toml <<'T'
[workspace]
provider = "opencode"
install_agent_hooks = ["opencode"]

[providers]
[providers.opencode]
base = "builtin:opencode"
ready_delay_ms = 0
[defaults]
[defaults.rig]
[defaults.rig.imports]
[defaults.rig.imports.gastown]
source = "https://github.com/gastownhall/gascity-packs/tree/main/gastown"
version = "sha:33d3a430a67d1782ad364556cb566bdb01d0afe3"

[daemon]
patrol_interval = "30s"
max_restarts = 5
restart_window = "1h"
shutdown_timeout = "5s"
T
cd /root/aiteam
if [ ! -f city/city.toml ]; then
  gc init --file ./city.toml --name phone-lights --no-start city 2>&1 | tail -5
fi
cd city
gc rig add /root/projects/aiteam-spike --name spike 2>&1 | tail -4
gc doctor 2>&1 | grep -vE "^\s+✓" | head -12
