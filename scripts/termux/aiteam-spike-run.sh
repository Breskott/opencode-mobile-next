#!/bin/bash
export PATH=/usr/local/bin:$PATH TMPDIR=/tmp HOME=/root
cd /root/aiteam/city
grep -q 'patches.agent' city.toml || cat >> city.toml <<'T'

[[patches.agent]]
name = "gastown.mayor"
suspended = true
[[patches.agent]]
name = "gastown.deacon"
suspended = true
[[patches.agent]]
name = "gastown.boot"
suspended = true
T
gc doctor 2>&1 | grep -E "✗" | head -5
gc register --name phone-lights 2>&1 | tail -2
sleep 45
B=http://127.0.0.1:8372/v0/city/phone-lights
curl -s -m 5 $B/health; echo
curl -s -m 5 $B/status | head -c 400; echo
curl -s -m 5 $B/agents | jq -r '.items[] | "\(.name) \(.state) suspended=\(.suspended)"'
cd /root/projects/aiteam-spike
ID=$(gc bd create "Add subtract function to calc.py" -d "Add subtract(a, b) next to add and multiply in calc.py, with a docstring." -p 1 --json | jq -r .id)
echo "bead=$ID"
curl -s -m 10 -X POST -H 'X-GC-Request: 1' -H 'Content-Type: application/json' $B/sling -d "{\"bead\":\"$ID\",\"target\":\"spike/gastown.polecat\",\"rig\":\"spike\",\"merge\":\"local\"}"; echo
echo $ID > /root/aiteam/bead.id
free -m | head -2; uptime
