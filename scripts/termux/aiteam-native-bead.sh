export LD_PRELOAD=$PREFIX/lib/libtermux-exec-ld-preload.so TERMUX_EXEC__SYSTEM_LINKER_EXEC__MODE=disable
B=http://127.0.0.1:8372/v0/city/phone-native
cd ~/projects/aiteam-spike
ID=$(gc bd create "Add subtract function to calc.py" -d "Add subtract(a, b) next to add and multiply in calc.py, with a docstring." -p 1 --json 2>/dev/null | jq -r .id)
echo "bead=$ID"; echo $ID > ~/aiteam-phone/bead.id
curl -s -m 10 -X POST -H "X-GC-Request: 1" -H "Content-Type: application/json" $B/sling -d "{\"bead\":\"$ID\",\"target\":\"spike/gastown.polecat\",\"rig\":\"spike\",\"merge\":\"local\"}" | head -c 60; echo
for i in $(seq 1 16); do sleep 30; st=$(curl -s -m 8 $B/bead/$ID | jq -r '"\(.status) \(.assignee) \(.metadata.branch)"' 2>/dev/null); ag=$(curl -s -m 8 $B/agents | jq -r '[.items[] | select(.state != "stopped" and .state != "suspended") | .name] | join(",")' 2>/dev/null); echo "[$i] $(date +%T) procs=$(ps -e | wc -l) $st | active: $ag | br: $(git branch -a --list '*polecat*' | tr '\n' ' ')"; done
grep -a -E "session lifecycle|SIGSEGV|returned -38|provider_error|initialize timeout|slow_storage|acp:" ~/aiteam-phone/supervisor.log | tail -8 | cut -c1-200
ls ~/.aiteam-env.* 2>/dev/null | head -2
