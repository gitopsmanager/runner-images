#!/usr/bin/env bash
# Copyright (c) 2026 GitOps Manager, S.L.
# SPDX-License-Identifier: Apache-2.0
# Runs inside an image as it is built (the Dockerfiles' test stage), so a
# broken image never builds:
#
#   RUN bash /tmp/gom-common/smoke-test.sh
#
# Checks that it runs as the runner image's non-root user, that every tool in
# /usr/local/share/gom/tools.txt (written by install-tools.sh from each
# recipe) answers its recipe's CHECK with its EXPECT and is on the PATH
# system-wide, and that the base image's own tools are there. Nothing here is
# per-tool: a fork's recipes are checked the same way as ours.
set -euo pipefail

manifest=/usr/local/share/gom/tools.txt
fail=0

check() { # check <tool> <expected, or empty> <command line>
  local tool=$1 want=$2 cmdline=$3 out
  if ! out=$(bash -c "$cmdline" 2>&1); then
    echo "FAIL $tool: '$cmdline' exited non-zero: $out"; fail=1; return
  fi
  if [ -n "$want" ] && ! grep -qF -- "$want" <<<"$out"; then
    echo "FAIL $tool: wanted $want, got: $out"; fail=1; return
  fi
  echo "ok   $tool ${want:-(runs)}: $(head -n1 <<<"$out")"
}

user=$(id -un)
if [ "$user" != runner ] || [ "$(id -u)" = 0 ]; then
  echo "FAIL user: running as $user ($(id -u)), want runner"; fail=1
else
  echo "ok   user runner ($(id -u))"
fi

[ -s "$manifest" ] || { echo "FAIL: no $manifest"; exit 1; }

while IFS=$'\t' read -r tool version cmd checkline expect; do
  [ -n "$tool" ] || continue
  check "$tool" "$expect" "$checkline"
  # System-wide, not somewhere only the build user's PATH reaches. A recipe
  # with no command of its own (CMD=-, e.g. a library) is not looked up.
  [ "$cmd" = "-" ] && continue
  case "$(command -v "$cmd" || true)" in
    /usr/local/bin/*|/usr/bin/*) ;;
    *) echo "FAIL $tool: $cmd is at '$(command -v "$cmd" || echo nowhere)'"; fail=1 ;;
  esac
done < "$manifest"

# Every tool's licence text came with it (install-tools.sh stops without one).
licenses=/usr/local/share/gom/licenses
if [ -s "$licenses/README.md" ]; then
  echo "ok   licences: $(find "$licenses" -mindepth 2 -type f | wc -l) texts, index $licenses/README.md"
else
  echo "FAIL licences: no index at $licenses/README.md"; fail=1
fi

for tool in jq git curl bash; do
  check "$tool" "" "$tool --version"
done

exit "$fail"
