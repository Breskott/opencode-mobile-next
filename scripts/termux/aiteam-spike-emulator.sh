#!/bin/bash
# Runs inside the emulator's proot Ubuntu rootfs. Mirrors the phone spike with the lean profile.
export PATH=/usr/local/bin:/usr/bin:/bin:$PATH TMPDIR=/tmp HOME=/root
dolt config --global --add user.name "Emu Spike" >/dev/null 2>&1; dolt config --global --add user.email "spike@emu.local" >/dev/null 2>&1
git config --global user.name "Emu Spike"; git config --global user.email "spike@emu.local"; git config --global beads.role maintainer
mkdir -p /root/projects/aiteam-spike /root/aiteam
cd /root/projects/aiteam-spike
if [ ! -d .git ]; then
  git init -q -b master
  printf 'def add(a, b):\n    return a + b\n\n\ndef multiply(a, b):\n    return a * b\n' > calc.py
  printf '{ "$schema": "https://opencode.ai/config.json", "model": "zai-coding-plan/glm-5.3-flash", "permission": { "bash": { "*": "allow" }, "edit": "allow" } }\n' > opencode.json
  git add -A; git commit -qm init
  git init -q --bare /root/projects/aiteam-spike.git
  git remote add origin /root/projects/aiteam-spike.git; git push -q origin master
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
rm -rf city; gc init --file ./city.toml --name emu-lights --no-start city 2>&1 | tail -3
cd city
gc rig list 2>&1 | grep -q spike || gc rig add /root/projects/aiteam-spike --name spike 2>&1 | tail -3
grep -q 'gastown.witness' city.toml || printf '\n[[patches.agent]]\nname = "gastown.mayor"\nsuspended = true\n[[patches.agent]]\nname = "gastown.deacon"\nsuspended = true\n[[patches.agent]]\nname = "gastown.boot"\nsuspended = true\n[[patches.agent]]\nname = "gastown.witness"\ndir = "spike"\nsuspended = true\n[[patches.agent]]\nname = "gastown.polecat"\ndir = "spike"\nmax_active_sessions = 1\n' >> city.toml
gc import install 2>&1 | tail -1
gc doctor 2>&1 | grep -E "✗" | head -5
echo "--- start $(date +%T)"; ps -e | wc -l
nohup setsid gc supervisor run > /root/aiteam/supervisor.log 2>&1 &
sleep 15
gc register --name emu-lights > /root/aiteam/register.log 2>&1 &
for i in $(seq 1 24); do sleep 20; h=$(curl -s -m 5 http://127.0.0.1:8372/v0/city/emu-lights/health); echo "[$i] $(date +%T) procs=$(ps -e | wc -l) mem=$(free -m | awk '/Mem/{print $7}') $(echo "$h" | head -c 60)"; echo "$h" | grep -q '"status":"ok"' && break; done
grep -a -E "took|SIGSEGV|returned -38|slow_storage" /root/aiteam/supervisor.log | tail -8 | cut -c1-160
