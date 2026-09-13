export LD_PRELOAD=$PREFIX/lib/libtermux-exec-ld-preload.so TERMUX_EXEC__SYSTEM_LINKER_EXEC__MODE=disable
pkill -f 'gc supervisor' 2>/dev/null; pkill -x dolt 2>/dev/null; sleep 2
dolt config --global --add user.name "Phone Native" >/dev/null 2>&1; dolt config --global --add user.email "spike@phone-native.local" >/dev/null 2>&1
git config --global user.name "Phone Native"; git config --global user.email "spike@phone-native.local"; git config --global beads.role maintainer
mkdir -p ~/projects ~/aiteam-phone; cd ~/projects
if [ ! -d aiteam-spike/.git ]; then mkdir -p aiteam-spike && cd aiteam-spike && git init -q -b master && printf 'def add(a, b):\n    return a + b\n\n\ndef multiply(a, b):\n    return a * b\n' > calc.py && printf '{ "$schema": "https://opencode.ai/config.json", "model": "zai-coding-plan/glm-5.3-flash", "permission": { "bash": { "*": "allow" }, "edit": "allow" } }\n' > opencode.json && git add -A && git commit -qm init && git init -q --bare ~/projects/aiteam-spike.git && git remote add origin ~/projects/aiteam-spike.git && git push -q origin master; fi
cd ~/aiteam-phone
cat > city.toml <<'T'
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
rm -rf city; gc init --file ./city.toml --name phone-native --no-start city 2>&1 | tail -30
cd city
gc rig add ~/projects/aiteam-spike --name spike 2>&1 | tail -30
gc import install 2>&1 | tail -1
printf '\n[[patches.agent]]\nname = "gastown.mayor"\nsuspended = true\n[[patches.agent]]\nname = "gastown.deacon"\nsuspended = true\n[[patches.agent]]\nname = "gastown.boot"\nsuspended = true\n[[patches.agent]]\nname = "gastown.witness"\ndir = "spike"\nsuspended = true\n[[patches.agent]]\nname = "gastown.polecat"\ndir = "spike"\nmax_active_sessions = 1\n' >> city.toml
sed -i 's|#!/usr/bin/env bash|#!/bin/bash|' $HOME/.gc/cache/repos/*/gastown/assets/scripts/*.sh 2>/dev/null
gc doctor 2>&1 | grep -E "✗" | head -4
echo "--- start $(date +%T)"
nohup setsid gc supervisor run > ~/aiteam-phone/supervisor.log 2>&1 &
sleep 12
(gc register --name phone-native > ~/aiteam-phone/register.log 2>&1 &)
for i in $(seq 1 15); do sleep 15; h=$(curl -s -m 5 http://127.0.0.1:8372/v0/city/phone-native/health); echo "[$i] $(date +%T) $(echo "$h" | head -c 70)"; echo "$h" | grep -q '"status":"ok"' && break; done
grep -a -E "took" ~/aiteam-phone/supervisor.log | tail -6 | cut -c1-120
