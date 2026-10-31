#!/usr/bin/env bash
# Copyright (c) 2026 GitOps Manager, S.L.
# SPDX-License-Identifier: Apache-2.0
# Installs tools system-wide from recipes, each download checked against its
# pinned SHA256 before it is used. Run as root at image build, from the
# Dockerfiles:
#
#   install-tools.sh --local /tmp/gom-local --list /tmp/gom-image/tools \
#                    --list-if-present /tmp/gom-image/tools.local
#
# A tool is a recipe, <name>.tool: common/tools/ holds ours; local/tools/
# (a fork's, never written by this repo) is read after it, so a fork can add
# tools and, if it must, replace one of ours. Pins: common/versions.env, then
# local/versions.env. The recipe format is in common/tools/README.md.
#
# Writes /usr/local/share/gom/tools.txt, one tab-separated line per tool --
# name, version, command, check, expected -- which smoke-test.sh runs and
# which tells anyone holding the image what's in it.
#
# And each tool's licence text, in /usr/local/share/gom/licenses/<tool>/,
# with an index (licenses/README.md): a file from the download
# (LICENSE_MEMBER), a pinned download (LICENSE_URL, LICENSE_SHA256), or a
# file the package installed (LICENSE_FILES). The images redistribute these
# tools, and their licences ask for the text to go with them.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
local_dir=""
tools=()

read_list() { # a list file: tool names, any whitespace, # comments
  sed -e 's/#.*//' "$1" | tr -s '[:space:]' '\n' | sed '/^$/d'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --local) local_dir=$2; shift 2 ;;
    --list) mapfile -t -O "${#tools[@]}" tools < <(read_list "$2"); shift 2 ;;
    --list-if-present) [ ! -f "$2" ] || mapfile -t -O "${#tools[@]}" tools < <(read_list "$2"); shift 2 ;;
    -*) echo "install-tools.sh: unknown option $1" >&2; exit 2 ;;
    *) tools+=("$1"); shift ;;
  esac
done
[ "${#tools[@]}" -gt 0 ] || { echo "usage: $0 [--local DIR] [--list FILE] [--list-if-present FILE] [tool...]" >&2; exit 2; }

# shellcheck source=versions.env
. "$here/versions.env"
if [ -n "$local_dir" ] && [ -f "$local_dir/versions.env" ]; then
  # shellcheck disable=SC1091
  . "$local_dir/versions.env"
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# GOM_PREFIX only exists so the script can be tried outside an image.
prefix=${GOM_PREFIX:-/usr/local}
bin=$prefix/bin
manifest=$prefix/share/gom/tools.txt
licenses=$prefix/share/gom/licenses
mkdir -p "$bin" "$(dirname "$manifest")" "$licenses"

# fetch <url> <sha256> <file>: download, then refuse anything whose hash
# isn't the pinned one.
fetch() {
  curl -fsSL --retry 5 --retry-all-errors -o "$3" "$1"
  echo "$2  $3" | sha256sum -c --strict -
}

# Ubuntu packages and .debs are collected and installed in one apt run at
# the end, from the pinned snapshot.
apt_pkgs=()
apt_add() { apt_pkgs+=("$@"); }

# lic_add <tool> <file>: a licence text into licenses/<tool>/, under its own
# name. Recipes of TYPE=script call it for files only they know about.
lic_add() {
  [ -s "$2" ] || { echo "install-tools.sh: $1: licence file $2 is missing or empty" >&2; exit 2; }
  mkdir -p "$licenses/$1"
  cp "$2" "$licenses/$1/$(basename "$2")"
}
# Installed files can only be copied once apt has run.
lic_later=()
lic_index=()

recipe_for() {
  local name=$1 found=""
  [ -f "$here/tools/$name.tool" ] && found="$here/tools/$name.tool"
  if [ -n "$local_dir" ] && [ -f "$local_dir/tools/$name.tool" ]; then
    [ -z "$found" ] || echo "install-tools.sh: $name: using local/tools/$name.tool instead of ours" >&2
    found="$local_dir/tools/$name.tool"
  fi
  [ -n "$found" ] || { echo "install-tools.sh: no recipe for '$name' (common/tools/ or local/tools/)" >&2; exit 2; }
  echo "$found"
}

declare -A seen=()
for tool in "${tools[@]}"; do
  [ -z "${seen[$tool]:-}" ] || continue
  seen[$tool]=1
  recipe=$(recipe_for "$tool")

  # Each recipe starts from nothing.
  unset VERSION TYPE URL SHA256 BIN MEMBER INSTALL_DIR STRIP PACKAGES CMD CHECK EXPECT \
        LICENSE_ID LICENSE_URL LICENSE_SHA256 LICENSE_MEMBER LICENSE_FILES SOURCE
  unset -f install_tool 2>/dev/null || true
  # shellcheck disable=SC1090
  . "$recipe"
  : "${VERSION:?$recipe: VERSION is required}" "${TYPE:?$recipe: TYPE is required}"
  BIN=${BIN:-$tool}
  CMD=${CMD:-$BIN}
  CHECK=${CHECK:-$CMD --version}
  EXPECT=${EXPECT-$VERSION}

  case "$TYPE" in
    bin)
      fetch "$URL" "$SHA256" "$tmp/$tool"
      install -m 0755 "$tmp/$tool" "$bin/$BIN"
      ;;
    tar|zip)
      fetch "$URL" "$SHA256" "$tmp/$tool.archive"
      mkdir -p "$tmp/$tool.x"
      if [ "$TYPE" = tar ]; then
        tar -xf "$tmp/$tool.archive" -C "$tmp/$tool.x" ${STRIP:+--strip-components="$STRIP"}
      else
        unzip -q "$tmp/$tool.archive" -d "$tmp/$tool.x"
      fi
      for m in ${LICENSE_MEMBER:-}; do lic_add "$tool" "$tmp/$tool.x/$m"; done
      if [ -n "${INSTALL_DIR:-}" ]; then
        # The whole archive into its own folder, its command linked onto the PATH.
        rm -rf "$INSTALL_DIR" && mkdir -p "$(dirname "$INSTALL_DIR")"
        mv "$tmp/$tool.x" "$INSTALL_DIR"
        ln -sf "$INSTALL_DIR/${MEMBER:-$BIN}" "$bin/$BIN"
      else
        install -m 0755 "$tmp/$tool.x/${MEMBER:-$BIN}" "$bin/$BIN"
      fi
      ;;
    deb)
      # A vendor's .deb by exact file and checksum: no signing key or repo
      # entry is left in the image. apt resolves its dependencies from the
      # Ubuntu snapshot.
      fetch "$URL" "$SHA256" "$tmp/$tool.deb"
      apt_add "$tmp/$tool.deb"
      ;;
    apt)
      # Ubuntu packages, name=version, from the pinned snapshot.
      : "${PACKAGES:?$recipe: PACKAGES is required for TYPE=apt}"
      # shellcheck disable=SC2086
      apt_add $PACKAGES
      ;;
    script)
      declare -F install_tool >/dev/null || { echo "$recipe: TYPE=script needs an install_tool function" >&2; exit 2; }
      install_dir=$tmp/$tool.x
      mkdir -p "$install_dir"
      install_tool
      ;;
    *)
      echo "$recipe: unknown TYPE '$TYPE' (bin tar zip deb apt script)" >&2
      exit 2
      ;;
  esac
  # The licence text: a pinned download, and/or installed files (after apt).
  if [ -n "${LICENSE_URL:-}" ]; then
    : "${LICENSE_SHA256:?$recipe: LICENSE_URL needs LICENSE_SHA256}"
    fetch "$LICENSE_URL" "$LICENSE_SHA256" "$tmp/$tool.license"
    mkdir -p "$licenses/$tool"
    cp "$tmp/$tool.license" "$licenses/$tool/$(basename "$LICENSE_URL")"
  fi
  for f in ${LICENSE_FILES:-}; do lic_later+=("$tool $f"); done
  lic_index+=("$(printf '| %s | %s | %s | %s |' "$tool" "$VERSION" "${LICENSE_ID:-see licenses/$tool}" "${SOURCE:-}")")

  printf '%s\t%s\t%s\t%s\t%s\n' "$tool" "$VERSION" "$CMD" "$CHECK" "$EXPECT" >> "$manifest"
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

for entry in "${lic_later[@]}"; do lic_add "${entry%% *}" "${entry#* }"; done

# Every tool must have its licence text with it.
for tool in "${!seen[@]}"; do
  [ -n "$(ls -A "$licenses/$tool" 2>/dev/null)" ] || {
    echo "install-tools.sh: $tool: no licence text (set LICENSE_MEMBER, LICENSE_URL or LICENSE_FILES in its recipe)" >&2
    exit 2
  }
done

# The index, kept with the texts. Added to, so an image that runs the
# installer twice keeps both lists.
index=$licenses/README.md
if [ ! -f "$index" ]; then
  cat > "$index" <<'EOF'
# Third-party software in this image

The base, GitHub's runner image (ghcr.io/actions/actions-runner: MIT,
https://github.com/actions/runner), and its Ubuntu packages: each package's
terms are in /usr/share/doc/<package>/copyright. The tools added on top, each
with its licence text in licenses/<tool>/:

| Tool | Version | Licence | Source |
|---|---|---|---|
EOF
fi
printf '%s\n' "${lic_index[@]}" >> "$index"

sort -u -o "$manifest" "$manifest"
echo "Installed:"
cut -f1,2 "$manifest"
