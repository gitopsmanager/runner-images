#!/usr/bin/env bash
# Copyright (c) 2026 GitOps Manager, S.L.
# SPDX-License-Identifier: Apache-2.0
# Installs the named tools system-wide, at the versions in versions.env, each
# checked against its pinned SHA256 before it is unpacked. Run as root at
# image build, from the Dockerfiles:
#
#   install-tools.sh tofu awscli kubectl helm kustomize yq python3
#
# Tools: tofu awscli azure-cli kubelogin kubectl helm kustomize yq crane python3.
# jq, git, curl, unzip and bash are not here: the base runner image already
# has them, so they are pinned by its digest.
#
# Writes /usr/local/share/gom/tools.txt ("<tool> <version>" per line), which
# smoke-test.sh checks and which tells anyone holding the image what's in it.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=versions.env
. "$here/versions.env"

[ "$#" -gt 0 ] || { echo "usage: $0 <tool>..." >&2; exit 2; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# GOM_PREFIX only exists so the script can be tried outside an image.
prefix=${GOM_PREFIX:-/usr/local}
bin=$prefix/bin
manifest=$prefix/share/gom/tools.txt
mkdir -p "$bin" "$(dirname "$manifest")"

# fetch <url> <sha256> <file>: download, then refuse anything whose hash
# isn't the pinned one.
fetch() {
  curl -fsSL --retry 5 --retry-all-errors -o "$3" "$1"
  echo "$2  $3" | sha256sum -c --strict -
}

record() { echo "$1 $2" >> "$manifest"; }

# Ubuntu and .deb installs are collected and done in one apt run at the end.
apt_pkgs=()

for tool in "$@"; do
  case "$tool" in
    tofu)
      fetch "https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION}_linux_amd64.tar.gz" \
        "$OPENTOFU_SHA256" "$tmp/tofu.tgz"
      tar -xzf "$tmp/tofu.tgz" -C "$tmp" tofu
      install -m 0755 "$tmp/tofu" "$bin/tofu"
      record tofu "$OPENTOFU_VERSION"
      ;;
    kubectl)
      fetch "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
        "$KUBECTL_SHA256" "$tmp/kubectl"
      install -m 0755 "$tmp/kubectl" "$bin/kubectl"
      record kubectl "$KUBECTL_VERSION"
      ;;
    helm)
      fetch "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
        "$HELM_SHA256" "$tmp/helm.tgz"
      tar -xzf "$tmp/helm.tgz" -C "$tmp" linux-amd64/helm
      install -m 0755 "$tmp/linux-amd64/helm" "$bin/helm"
      record helm "$HELM_VERSION"
      ;;
    kustomize)
      fetch "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" \
        "$KUSTOMIZE_SHA256" "$tmp/kustomize.tgz"
      tar -xzf "$tmp/kustomize.tgz" -C "$tmp" kustomize
      install -m 0755 "$tmp/kustomize" "$bin/kustomize"
      record kustomize "$KUSTOMIZE_VERSION"
      ;;
    yq)
      fetch "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" \
        "$YQ_SHA256" "$tmp/yq"
      install -m 0755 "$tmp/yq" "$bin/yq"
      record yq "$YQ_VERSION"
      ;;
    crane)
      fetch "https://github.com/google/go-containerregistry/releases/download/v${CRANE_VERSION}/go-containerregistry_Linux_x86_64.tar.gz" \
        "$CRANE_SHA256" "$tmp/crane.tgz"
      tar -xzf "$tmp/crane.tgz" -C "$tmp" crane
      install -m 0755 "$tmp/crane" "$bin/crane"
      record crane "$CRANE_VERSION"
      ;;
    kubelogin)
      fetch "https://github.com/Azure/kubelogin/releases/download/v${KUBELOGIN_VERSION}/kubelogin-linux-amd64.zip" \
        "$KUBELOGIN_SHA256" "$tmp/kubelogin.zip"
      unzip -q "$tmp/kubelogin.zip" bin/linux_amd64/kubelogin -d "$tmp"
      install -m 0755 "$tmp/bin/linux_amd64/kubelogin" "$bin/kubelogin"
      record kubelogin "$KUBELOGIN_VERSION"
      ;;
    awscli)
      fetch "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip" \
        "$AWSCLI_SHA256" "$tmp/awscli.zip"
      unzip -q "$tmp/awscli.zip" -d "$tmp"
      "$tmp/aws/install" --install-dir "$prefix/aws-cli" --bin-dir "$bin"
      record awscli "$AWSCLI_VERSION"
      ;;
    azure-cli)
      # Straight from the repo's pool, by exact version and checksum, so no
      # signing key or repo entry is left in the image. apt resolves its
      # few library dependencies from the Ubuntu snapshot below.
      fetch "https://packages.microsoft.com/repos/azure-cli/pool/main/a/azure-cli/azure-cli_${AZURE_CLI_DEB_VERSION}_amd64.deb" \
        "$AZURE_CLI_SHA256" "$tmp/azure-cli.deb"
      apt_pkgs+=("$tmp/azure-cli.deb")
      record azure-cli "$AZURE_CLI_VERSION"
      ;;
    python3)
      # PyYAML for the scripts that read values and topology files.
      apt_pkgs+=("python3=$PYTHON3_DEB_VERSION" "python3-yaml=$PYYAML_DEB_VERSION")
      record python3 "${PYTHON3_DEB_VERSION%%-*}"
      record pyyaml "$PYYAML_VERSION"
      ;;
    *)
      echo "install-tools.sh: unknown tool '$tool'" >&2
      exit 2
      ;;
  esac
done

if [ "${#apt_pkgs[@]}" -gt 0 ]; then
  # A private source list pointing at the Ubuntu snapshot only. The image's
  # own sources (the live archive and the git PPA, which has no snapshots)
  # are left alone, so a workflow that apt-installs at run time still gets
  # current packages.
  mkdir -p "$tmp/apt/sources.d" "$tmp/apt/lists/partial"
  cat > "$tmp/apt/sources.d/snapshot.sources" <<EOF
Types: deb
URIs: https://snapshot.ubuntu.com/ubuntu/${UBUNTU_SNAPSHOT}
Suites: noble noble-updates noble-security
Components: main universe
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
  apt_opts=(
    -o "Dir::Etc::SourceList=/dev/null"
    -o "Dir::Etc::SourceParts=$tmp/apt/sources.d"
    -o "Dir::State::Lists=$tmp/apt/lists"
  )
  apt-get "${apt_opts[@]}" update
  DEBIAN_FRONTEND=noninteractive apt-get "${apt_opts[@]}" install -y --no-install-recommends "${apt_pkgs[@]}"
  apt-get clean
fi

sort -u -o "$manifest" "$manifest"
echo "Installed:"
cat "$manifest"
