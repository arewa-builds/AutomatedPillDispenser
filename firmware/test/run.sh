#!/usr/bin/env bash
# Build and run the host harness for pill_dispenser.ino. Needs only g++.
#
#   ./firmware/test/run.sh
#
# This checks the sketch's behaviour without a board. It is not a substitute for
# compiling against the real core — for that, run verify_arduino_toolchain.sh.
set -euo pipefail

cd "$(dirname "$0")"
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT

echo "==> Building host harness"
g++ -std=c++14 -Wall -Wextra -Istubs -o "$OUT/harness" host_harness.cpp

echo "==> Running"
"$OUT/harness"
