<!-- Copyright (c) 2026 GitOps Manager, S.L. SPDX-License-Identifier: Apache-2.0 -->
# Tool recipes

One file per tool, `<name>.tool`: shell variable assignments, read by
`install-tools.sh` after `versions.env` (and a fork's `local/versions.env`),
so a value may use the pins there. An image lists the recipes it wants, by
name, in its `tools` file. The same format works in `local/tools/` for a
fork's own tools.

```sh
VERSION=9.0.100                      # required: what the image reports
TYPE=tar                             # required: bin | tar | zip | deb | apt | script
URL="https://example.com/thing-${VERSION}-linux-x64.tar.gz"
SHA256=<the download's sha256>       # required for bin, tar, zip, deb
BIN=thing                            # the command it installs (default: the recipe's name)
MEMBER=bin/thing                     # tar/zip: the binary's path inside the archive (default: BIN)
INSTALL_DIR=/opt/thing               # tar/zip: unpack the whole archive here, link MEMBER onto the PATH
STRIP=1                              # tar: strip this many leading folders
CMD=thing                            # what the smoke test looks up on the PATH (default: BIN; - for none)
CHECK="thing --version"              # what the smoke test runs (default: "$CMD --version")
EXPECT="v$VERSION"                   # what CHECK must print (default: VERSION; empty: only that it runs)

# The licence -- required: every tool's licence text goes into the image with it.
LICENSE_ID=MIT                       # its SPDX identifier, for the image's licence index
SOURCE=https://github.com/example/thing   # the project, for the index
LICENSE_MEMBER=LICENSE               # tar/zip: the licence file(s) inside the archive, or
LICENSE_URL="https://raw.githubusercontent.com/example/thing/v${VERSION}/LICENSE"  # a pinned download
LICENSE_SHA256=<its sha256>          #   (with LICENSE_URL), or
LICENSE_FILES=/usr/share/doc/thing/copyright   # deb/apt: the file(s) the package installs
```

The texts land in `/usr/local/share/gom/licenses/<tool>/`, with an index of
every tool, its version, licence and source in `licenses/README.md`. A recipe
with no licence text stops the build. A `script` recipe can add more with
`lic_add <tool> <file>` (the AWS CLI adds the list of what it bundles).

| TYPE | For | Needs |
|---|---|---|
| `bin` | A single downloaded binary | `URL`, `SHA256` |
| `tar`, `zip` | An archive holding the binary, or a whole folder (`INSTALL_DIR`) | `URL`, `SHA256` |
| `deb` | A vendor's `.deb`, by exact file; its dependencies come from the Ubuntu snapshot | `URL`, `SHA256` |
| `apt` | Ubuntu packages, pinned to versions in the snapshot | `PACKAGES="name=version ..."` |
| `script` | Anything else: an `install_tool` function, which can use `fetch <url> <sha256> <file>`, `$install_dir` (scratch), `$bin`, `$prefix`, `apt_add <package...>` and `lic_add <tool> <file>` | the function |

Every download is checked against its `SHA256` before it is used, and the
build's smoke test runs each recipe's `CHECK`. A recipe never writes outside
the image's system paths and never leaves a repo key or source behind.

Examples: [`kubectl.tool`](kubectl.tool) (`bin`), [`helm.tool`](helm.tool)
(`tar`), [`kubelogin.tool`](kubelogin.tool) (`zip`),
[`gcloud.tool`](gcloud.tool) (`deb`), [`python3.tool`](python3.tool) (`apt`),
[`awscli.tool`](awscli.tool) (`script`).
