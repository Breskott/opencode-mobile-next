set -e
mkdir -p /root/bench/tree
cd /root/bench/tree
for a in $(seq 50); do mkdir -p d$a; for b in $(seq 100); do echo x > d$a/f$b; done; done
mkdir -p /root/bench/repo && cd /root/bench/repo
for a in $(seq 50); do mkdir -p d$a; for b in $(seq 100); do echo $a$b > d$a/f$b; done; done
git init -q . && git -c user.email=b@b -c user.name=b add -A && git -c user.email=b@b -c user.name=b commit -qm init
echo done-setup
