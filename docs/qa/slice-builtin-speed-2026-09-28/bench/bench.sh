#!/system/bin/sh
# Runs as the app uid. Usage: bench.sh <nativeDir> <reps> <workloads...>
N="$1"; shift
REPS="$1"; shift
APP=/data/data/io.github.eslamasabry.opencode_mobile
F=$APP/files
R=$F/linux/ubuntu
T=$APP/cache/bench-proot-tmp
mkdir -p "$T"
export PROOT_LOADER="$N/libproot-loader.so"
export PROOT_TMP_DIR="$T"
export LD_LIBRARY_PATH="$N"
P="$N/libproot.so"
ENVI="/usr/bin/env -i HOME=/root LANG=C.UTF-8 PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin TERM=xterm-256color TMPDIR=/tmp"
FAKE="--bind=$F/linux/proc/stat:/proc/stat --bind=$F/linux/proc/loadavg:/proc/loadavg --bind=$F/linux/proc/uptime:/proc/uptime --bind=$F/linux/proc/version:/proc/version --bind=$F/linux/proc/vmstat:/proc/vmstat"
BASE_BINDS="--rootfs=$R --bind=/dev --bind=/proc --bind=/sys --bind=$R/tmp:/dev/shm --bind=$F/projects:/root/projects"
SYS=""
for p in /apex /odm /product /system /system_ext /vendor; do [ -d "$p" ] && SYS="$SYS --bind=$p"; done
KREL='--kernel-release=\Linux\localhost\6.17.0-PRoot-Distro\#1 SMP PREEMPT_DYNAMIC Fri, 10 Oct 2025 00:00:00 +0000\x86_64\localdomain\-1\'

run_variant() { # variant, cmd
  v="$1"; c="$2"
  unset PROOT_NO_SECCOMP PROOT_L2S_DIR
  case "$v" in
    ours)    set -- --root-id --kill-on-exit --link2symlink -L --sysvipc $BASE_BINDS $FAKE ;;
    noseccomp) export PROOT_NO_SECCOMP=1; set -- --root-id --kill-on-exit --link2symlink -L --sysvipc $BASE_BINDS $FAKE ;;
    nol2s)   set -- --root-id --kill-on-exit -L --sysvipc $BASE_BINDS $FAKE ;;
    nofake)  set -- --root-id --kill-on-exit --link2symlink -L --sysvipc $BASE_BINDS ;;
    pdistro) mkdir -p "$R/.l2s"; export PROOT_L2S_DIR="$R/.l2s"
             set -- --root-id --kill-on-exit --link2symlink --sysvipc "$KREL" -L $BASE_BINDS --bind=/dev/urandom:/dev/random $FAKE $SYS ;;
  esac
  "$P" "$@" --cwd=/root $ENVI /bin/sh -c "$c" >/dev/null 2>&1
}

now_ms() { t=$EPOCHREALTIME; s=${t%.*}; u=${t#*.}; u=${u}000000; u=${u%${u#??????}}; echo $(( s*1000 + 1${u}/1000 - 1000 )); }

for w in "$@"; do
  case "$w" in
    true) c="true" ;;
    node0) c="node -e 0" ;;
    ocver) c="opencode --version" ;;
    walk) c="node /root/bench/walk.js /root/bench/tree" ;;
    git) c="cd /root/bench/repo && git status --porcelain >/dev/null" ;;
    exec200) c='for i in $(seq 200); do /bin/true; done' ;;
    io20k) c="node /root/bench/io.js" ;;
  esac
  i=0
  while [ $i -lt $REPS ]; do
    for v in ours noseccomp nol2s nofake pdistro; do
      s=$(now_ms); run_variant $v "$c"; rc=$?; e=$(now_ms)
      echo "$w $v $((e-s)) rc=$rc"
    done
    i=$((i+1))
  done
done
