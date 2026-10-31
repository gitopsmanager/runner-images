<!-- Copyright (c) 2026 GitOps Manager, S.L. SPDX-License-Identifier: Apache-2.0 -->
# Runner images

Container images for the runners that run GitOps Manager workflows. They're
built and pushed to GHCR by
[`build-runner-images.yml`](../.github/workflows/build-runner-images.yml).

> **Status: first draft, 29 Oct 2026. None of these images has been built
> yet.** They couldn't be built where they were written. The pins and
> checksums were checked against the release files (see [Tested](#tested)).
> The first run of the workflow will be the first build.

| Image | Runs | Tools |
|---|---|---|
| `runner-workflow-aws` | Long workflows (OpenTofu create, Helm installs) on CodeBuild | OpenTofu, AWS CLI v2, kubectl, Helm, kustomize, yq, python3 + PyYAML |
| `runner-workflow-azure` | Long workflows on Container Apps jobs | OpenTofu, Azure CLI, kubelogin, kubectl, Helm, kustomize, yq, python3 + PyYAML |
| `runner-adhock-aws` | AddHock (short GUI commands) on an always-on runner | AWS CLI v2, kubectl, yq |
| `runner-adhock-azure` | AddHock on an always-on runner | Azure CLI, kubelogin, kubectl, yq |

All four also have jq, git, curl, unzip and bash from the base image.

The AddHock images are lean on purpose: an always-on runner is pulled to
every node it lands on, and AddHock never runs OpenTofu or Helm.

## The base

All four are built on the official GitHub Actions runner image,
`ghcr.io/actions/actions-runner`, pinned by tag **and** digest. That gives
Ubuntu 24.04, the non-root user `runner` (uid 1001) the images run as, and
the runner agent.

- **CodeBuild** brings its own runner agent and ignores this one.
- **Container Apps jobs** use the one in the image.

The same base is still used for all four so there's one toolchain to keep
current. The workflow fails if the four `FROM` lines differ.

## Layout

| Path | What it is |
|---|---|
| `<image>/Dockerfile` | The base pin, and which tools to install |
| `common/versions.env` | **Every tool version and SHA256**, with where each checksum came from |
| `common/install-tools.sh` | Downloads each tool from its official release URL, checks the SHA256, installs to `/usr/local/bin`, and writes `/usr/local/share/gom/tools.txt` |
| `common/smoke-test.sh` | Run in each new image before it's pushed: the user is `runner`, and every tool is on the PATH at the pinned version |
| `common/build-day.sh`, `common/test-build-day.sh` | The schedule rule, and its test |

The build context is `images/`, so the Dockerfiles can bind-mount `common/`
without copying it into a layer.

## How the pins work

- **Release binaries** (OpenTofu, kubectl, Helm, kustomize, yq, kubelogin,
  the AWS CLI) are downloaded from the project's own release URL, at an exact
  version, and refused unless the SHA256 matches `versions.env`.
- **The Azure CLI** `.deb` is fetched from Microsoft's apt repo pool, by its
  exact package version, with its checksum checked the same way. No
  Microsoft repo or key is left in the image.
- **Ubuntu packages** (python3, PyYAML, and the Azure CLI's few library
  dependencies) come from `snapshot.ubuntu.com` at the fixed time
  `UBUNTU_SNAPSHOT`. The live archive drops old versions, so pinning the
  version alone would break the next build.
  - The image's own apt sources are left as they were, so a workflow that
    runs `sudo apt-get install` gets current packages.
- **amd64 only:** CodeBuild and Container Apps run these on x86_64.

## When it builds

- **Scheduled:** on the 15th of each month, and on the 30th. February has
  no 30th, so it builds on its last day instead (28th or 29th).
  - Cron can't express that, so the schedule fires at 04:00 UTC on the 15th,
    28th, 29th and 30th, and the first job runs `common/build-day.sh` to skip
    the days that aren't build days.
- **Run now:** Actions → build-runner-images → Run workflow always builds.

Everything is pinned, so a scheduled build with no bump installs the same
versions again. It still proves every pinned download is there and matches
its checksum. Security fixes arrive only through a bump, including the base
pin.

GitHub disables scheduled workflows in a public repo after 60 days without a
commit. If the builds stop, re-enable it on the Actions tab.

## Tags, and pulling

Each build pushes `ghcr.io/gitopsmanager/<image>` with two tags:

- `<YYYY.MM.DD>` (for example `2026.10.30`)
- `<YYYY.MM.DD>-<shortsha>` (the commit it was built from)

**There's no `latest`.** Clients pin by digest, and a moving tag would invite
an unpinned use that changes under a running estate. The run summary has a
table with each image's digest. Use it like this:

```bash
docker pull ghcr.io/gitopsmanager/runner-workflow-aws@sha256:<digest from the run summary>
```

or put the same `image@sha256:...` reference in the CodeBuild project or the
Container Apps job.

The date tag moves if the same day is built twice. The digest never moves.

The workflow keeps the **6 newest versions** of each package (three months at
two builds a month) and deletes older ones. **Anything pinned to an older
digest stops pulling** once that version is deleted, so move clients forward
within three months. Manual runs count too, so each one shortens that window.

## Bumping a version

**A tool:**
1. Pick a release that is **at least two weeks old**.
2. Change its `*_VERSION` and `*_SHA256` in `common/versions.env`. Take the
   checksum from the project's own checksum file (the comment says which).
   - The AWS CLI publishes only a PGP signature. Download the zip, check the
     `.sig` against the AWS CLI Team key, then take its `sha256sum`.
   - For the Azure CLI, use the `SHA256` field for that version in
     `https://packages.microsoft.com/repos/azure-cli/dists/noble/main/binary-amd64/Packages`.
3. Run the workflow. The smoke test fails if the image doesn't report the new
   version.

**Ubuntu packages:** move `UBUNTU_SNAPSHOT` forward, and update
`PYTHON3_DEB_VERSION` and `PYYAML_DEB_VERSION` to the versions in that
snapshot.

**The base image:** automatic. Every build run moves all four Dockerfiles to
the newest runner release at least two weeks old, by tag and digest, commits
that when it changed, tags the commit `<YYYY.MM.DD>`, builds from the tag and
makes a GitHub release with the digests. To do it by hand instead, pick a
runner release at least two weeks old, then get the digest of its tag (the
index digest, which covers every architecture):

```bash
T=$(curl -s "https://ghcr.io/token?scope=repository:actions/actions-runner:pull" | jq -r .token)
curl -sI -H "Authorization: Bearer $T" \
  -H "Accept: application/vnd.oci.image.index.v1+json" \
  https://ghcr.io/v2/actions/actions-runner/manifests/<version> | grep -i docker-content-digest
```

Change the `FROM` line in **all four** Dockerfiles.

## First run: things to check

- **The packages start out private.** The first push creates the four GHCR
  packages. If clients should pull without credentials, make each one public
  in its package settings.
- **Pruning needs the repo to have admin on each package.** The source label
  in each Dockerfile links the package to this repo. If the prune step fails
  with a 403, add this repo under the package's "Manage Actions access" with
  the Admin role.

## Tested

29 Oct 2026, on Windows (Git Bash), without building any image:

- **Every checksum** in `versions.env` was checked against a download of the
  file at the URL `install-tools.sh` uses.
  - **The AWS CLI zip's PGP signature verified** against key
    `FB5DB77FD5C118B80511ADA8A6310ACC4672475C`, fetched from
    keyserver.ubuntu.com. gpg reported that copy of the key as expired.
- **`install-tools.sh`**, run with a scratch `GOM_PREFIX` for tofu, kubectl,
  Helm, kustomize, yq and kubelogin: every checksum passed, the right file
  was taken from each archive, and `tools.txt` was written.
  - A wrong checksum stops it.
  - An unknown tool name stops it.
- **The build-day rule:** `test-build-day.sh` passes. It checks the 15th, the
  30th, the 28th, 29th and 31st, the last day of February in 2027, 2028, 2100
  and 2000, and the 28th of February in a leap year.
- **The workflow:** parses as YAML, every `run:` block passes `bash -n`, and
  the decide and summary steps produce the right outputs when run locally.

**Not tested:**
- **Building any image.** That means the AWS CLI installer, the Azure CLI
  `.deb` and the snapshot apt sources are unproven.
- `smoke-test.sh`.
- Anything in GitHub Actions: the build, push, digest table and pruning.
