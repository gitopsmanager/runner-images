#!/usr/bin/env bash
# Copyright (c) 2026 GitOps Manager, S.L.
# SPDX-License-Identifier: Apache-2.0
# Runs inside a freshly built image, before it is pushed:
#
#   docker run --rm -v "$PWD/images/common:/gom:ro" <image> bash /gom/smoke-test.sh
#
# Checks that it runs as the runner image's non-root user, that every tool in
# /usr/local/share/gom/tools.txt is on the PATH system-wide and reports the
# pinned version, and that the base image's own tools are there.
set -euo pipefail

manifest=/usr/local/share/gom/tools.txt
fail=0

check() { # check <tool> <expected version> <command...>
  local tool=$1 want=$2 out
  shift 2
  if ! out=$("$@" 2>&1); then
    echo "FAIL $tool: '$*' exited non-zero: $out"; fail=1; return
  fi
  if [ -n "$want" ] && ! grep -qF -- "$want" <<<"$out"; then
    echo "FAIL $tool: wanted $want, got: $out"; fail=1; return
  fi
  echo "ok   $tool ${want:-(base image)}: $(head -n1 <<<"$out")"
}

user=$(id -un)
if [ "$user" != runner ] || [ "$(id -u)" = 0 ]; then
  echo "FAIL user: running as $user ($(id -u)), want runner"; fail=1
else
  echo "ok   user runner ($(id -u))"
fi

[ -s "$manifest" ] || { echo "FAIL: no $manifest"; exit 1; }

while read -r tool version; do
  case "$tool" in
    tofu)      check tofu "v$version" tofu version ;;
    awscli)    check awscli "aws-cli/$version" aws --version ;;
    azure-cli) check azure-cli "$version" az version --output tsv ;;
    kubelogin) check kubelogin "v$version" kubelogin --version ;;
    kubectl)   check kubectl "v$version" kubectl version --client ;;
    helm)      check helm "v$version" helm version --short ;;
    kustomize) check kustomize "v$version" kustomize version ;;
    yq)        check yq "v$version" yq --version ;;
    crane)     check crane "$version" crane version ;;
    python3)   check python3 "$version" python3 --version ;;
    pyyaml)    check pyyaml "$version" python3 -c 'import yaml; print(yaml.__version__)' ;;
    *)         echo "FAIL: no check for '$tool' in smoke-test.sh"; fail=1 ;;
  esac
  # System-wide, not somewhere only the build user's PATH reaches.
  case "$tool" in
    awscli) cmd=aws ;; azure-cli) cmd=az ;; pyyaml) continue ;; *) cmd=$tool ;;
  esac
  case "$(command -v "$cmd")" in
    /usr/local/bin/*|/usr/bin/*) ;;
    *) echo "FAIL $tool: $cmd is at '$(command -v "$cmd")'"; fail=1 ;;
  esac
done < "$manifest"

for tool in jq git curl bash; do
  check "$tool" "" "$tool" --version
done

exit "$fail"
