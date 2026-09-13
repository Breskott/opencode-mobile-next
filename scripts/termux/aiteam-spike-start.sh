#!/bin/bash
export PATH=/usr/local/bin:$PATH TMPDIR=/tmp HOME=/root
dolt config --global --add user.name "Phone Spike" >/dev/null 2>&1; dolt config --global --add user.email "spike@phone.local" >/dev/null 2>&1
git config --global user.name "Phone Spike"; git config --global user.email "spike@phone.local"; git config --global beads.role maintainer
cd /root/aiteam/city
gc rig list 2>&1 | grep -q spike || gc rig add /root/projects/aiteam-spike --name spike 2>&1 | tail -3
gc import install 2>&1 | tail -2
cat .gc/site.toml
# lean profile: suspend patrol agents
for a in gastown.mayor gastown.deacon gastown.boot; do gc agent suspend $a 2>&1 | tail -1; done
nohup setsid gc supervisor run > /root/aiteam/supervisor.log 2>&1 &
sleep 50
curl -s -m 5 http://127.0.0.1:8372/v0/city/phone-lights/health; echo
curl -s -m 5 http://127.0.0.1:8372/v0/cities | head -c 300; echo
tail -5 /root/aiteam/supervisor.log
free -m | head -2
