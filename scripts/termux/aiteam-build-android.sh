#!/bin/bash
# Build gc, bd and dolt for Android (Termux, native, no proot) on the PC.
# Why: Android 15's seccomp policy kills processes that call faccessat2 (and
# some futex variants); Go's linux builds use them, Go's GOOS=android builds
# do not. gc and bd are pure Go; dolt needs cgo (zstd, ICU) and therefore
# the NDK plus Termux's libicu headers/libs (pkg install libicu on the phone).
set -euo pipefail
NDK=${NDK:-$HOME/Android/Sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/bin}
OUT=${OUT:-$PWD/out-android-arm64}; mkdir -p "$OUT"
export GOTOOLCHAIN=auto GOFLAGS=-mod=mod
(cd "${GASCITY_SRC:?path to gastownhall/gascity checkout}" && CGO_ENABLED=0 GOOS=android GOARCH=arm64 go build -trimpath -ldflags="-s -w" -o "$OUT/gc" ./cmd/gc)
(cd "${BEADS_SRC:?path to gastownhall/beads checkout}" && CGO_ENABLED=0 GOOS=android GOARCH=arm64 go build -trimpath -ldflags="-s -w" -o "$OUT/bd" ./cmd/bd)
ICU=${TERMUX_ICU:?dir with Termux libicu unpacked (data/data/com.termux/files/usr)}
(cd "${DOLT_SRC:?path to dolthub/dolt checkout}/go" && CGO_ENABLED=1 GOOS=android GOARCH=arm64 \
  CC="$NDK/aarch64-linux-android30-clang" CXX="$NDK/aarch64-linux-android30-clang++" \
  CGO_CFLAGS="-I$ICU/include" CGO_CXXFLAGS="-I$ICU/include" \
  CGO_LDFLAGS="-L$ICU/lib -Wl,-rpath,/data/data/com.termux/files/usr/lib -static-libstdc++" \
  go build -trimpath -ldflags="-s -w" -o "$OUT/dolt" ./cmd/dolt)
ls -la "$OUT"
