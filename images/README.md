<!-- Copyright (c) 2026 GitOps Manager, S.L. SPDX-License-Identifier: Apache-2.0 -->
# Runner images

Container images for the runners that run GitOps Manager workflows. They're
built and pushed to GHCR by
[`build-runner-images.yml`](../.github/workflows/build-runner-images.yml),
one image at a time through
[`build-image.yml`](../.github/workflows/build-image.yml).

| Image | Runs on | Tools |
|---|---|---|
| `runner` | Every cloud: CodeBuild (long AWS workflows), Container Apps jobs (long Azure workflows), ARC on EKS, AKS and GKE (GUI commands) | OpenTofu, kubectl, Helm, kustomize, yq, crane, python3 + PyYAML; AWS CLI v2; Azure CLI, kubelogin; Google Cloud CLI, gke-gcloud-auth-plugin |

**One image serves every workflow on every cloud:** long ones (OpenTofu
creates, Helm installs) and short commands from the GUI (AddHock) on an
always-on runner.
- **Why not one per cloud.** There were three, and before that six (a lighter
  one for short commands, per cloud). GitHub's runner base is most of the
  image (about 520 MB compressed); each cloud's CLI is 70 to 110 MB to
  download. All three in one costs under 200 MB over the largest single-cloud
  image, pulled once per node, and saves a choice of image in every runner set.
- **The cost:** every runner carries two clouds' CLIs it doesn't use. What a
  runner can do is set by its identity, not by the tools installed.
- **A lean image** for one cloud is a fork's own `images/runner-<name>/` with
  its own `tools` file (repo README, "Your own images").

It also has jq, git, curl, unzip and bash from the base image. The exact list
is its `tools` file.

## The base

The image is built on the official GitHub Actions runner image,
`ghcr.io/actions/actions-runner`, pinned by tag **and** digest. That gives
Ubuntu 24.04, the non-root user `runner` (uid 1001) the image runs as, and
the runner agent.

- **CodeBuild** brings its own runner agent and ignores this one.
- **Container Apps jobs** and ARC use the one in the image.

A fork's own images (`runner-*`) use the same base, so there's one toolchain
to keep current. The workflow fails if their base `FROM` lines differ.

## Layout

| Path | What it is |
|---|---|
| `<image>/Dockerfile` | The base pin; the install; the smoke-test stage |
| `<image>/tools` | The tools in that image, by recipe name (ours: `runner/tools`) |
| `common/tools/<tool>.tool` | **How each tool is installed**: where from, what kind of file, how to check it. Format: [`common/tools/README.md`](common/tools/README.md) |
| `common/versions.env` | **Every tool version and SHA256**, with where each checksum came from |
| `common/install-tools.sh` | Runs the recipes: downloads, checks each SHA256, installs system-wide, writes `/usr/local/share/gom/tools.txt`, and puts each tool's licence text in `/usr/local/share/gom/licenses/` |
| `common/smoke-test.sh` | Run inside every build: the user is `runner`, and every tool answers its recipe's check |
| `common/build-day.sh`, `common/test-build-day.sh` | The schedule rule, and its test |
| `local/` | **A fork's own** recipes and pins. This repo never writes there (see the repo README, "Your own images") |

The build context is `images/`, so the Dockerfiles bind-mount `common/`,
`local/` and their own folder without copying them into a layer.

## The smoke test is part of the build

Each Dockerfile has three stages: `image` installs the tools; `test` runs
`smoke-test.sh` in it as the runner user; the final stage is `image` plus one
file copied from `test`, which makes the test a step of every build. So a
broken image never builds, with any builder -- GitHub's, or a remote BuildKit
on a self-hosted runner with no Docker daemon.

## How the pins work

- **Release binaries** (OpenTofu, kubectl, Helm, kustomize, yq, crane,
  kubelogin, the AWS CLI) are downloaded from the project's own release URL,
  at an exact version, and refused unless the SHA256 matches `versions.env`.
- **The Azure CLI and the Google Cloud CLI** `.deb`s are fetched from the
  vendor's apt repo pool, by exact version, with their checksums checked the
  same way. No vendor repo or key is left in the image.
- **Ubuntu packages** (python3, PyYAML, and the vendor packages' few
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

Each run first moves the base to the newest runner release at least two weeks
old (below), then builds. Tools are pinned, so a run with no bump installs
the same versions again; it still proves every pinned download is there and
matches its checksum.

GitHub disables scheduled workflows in a public repo after 60 days without a
commit. If the builds stop, re-enable it on the Actions tab.

## Tags, and pulling

Each build pushes `ghcr.io/<repo owner>/<image>` with two tags:

- `<YYYY.MM.DD>` (for example `2026.11.15`)
- `<YYYY.MM.DD>-<shortsha>` (the commit it was built from)

**There's no `latest`.** Clients pin by digest, and a moving tag would invite
an unpinned use that changes under a running estate. Every build is a GitHub
release named by its date, with each image's digest in its notes and in
`images.json`:

```bash
gh release download --repo gitopsmanager/runner-images --pattern images.json
docker pull ghcr.io/gitopsmanager/runner@sha256:<digest from images.json>
```

or put the same `image@sha256:...` reference in the CodeBuild project, the
Container Apps job or the ARC runner set.

The date tag moves if the same day is built twice. The digest never moves.

The workflow keeps the **6 newest versions** of each package (three months at
two builds a month) and deletes older ones. **Anything pinned to an older
digest stops pulling** once that version is deleted, so move clients forward
within three months. Manual runs count too, so each one shortens that window.

**Published images are never patched.** Security fixes reach you only by
moving to a newer build (see "Security" in the repo README): use the newest
release, at least monthly.

## Bumping a version

**A tool:**
1. Pick a release that is **at least two weeks old**.
2. Change its `*_VERSION` and `*_SHA256` in `common/versions.env`. Take the
   checksum from the project's own checksum file (the comment says which).
   - The AWS CLI publishes only a PGP signature. Download the zip, check the
     `.sig` against the AWS CLI Team key, then take its `sha256sum`.
   - For the Azure CLI, use the `SHA256` field for that version in
     `https://packages.microsoft.com/repos/azure-cli/dists/noble/main/binary-amd64/Packages`.
   - For the Google Cloud CLI and the GKE plugin, use the `Filename` and
     `SHA256` fields in
     `https://packages.cloud.google.com/apt/dists/cloud-sdk/main/binary-amd64/Packages`.
3. Run the workflow. The build's smoke test fails if the image doesn't report
   the new version.

**A new tool:** a recipe in `common/tools/`, its pins in `versions.env`, and
its name in `runner/tools`.

**Ubuntu packages:** move `UBUNTU_SNAPSHOT` forward, and update
`PYTHON3_DEB_VERSION` and `PYYAML_DEB_VERSION` to the versions in that
snapshot.

**The base image:** automatic. Every build run moves all the Dockerfiles to
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

and change the base `FROM` line in **every** Dockerfile.

## First run: things to check

- **The package starts out private.** The first push creates the GHCR
  package. Clients pull without credentials, so make it public in its package
  settings (Change visibility). Do the same again if the package is ever
  deleted: its settings go with it.
- **Pruning needs the repo to have admin on each package.** The source label
  in the Dockerfile links the package to this repo. If the prune step fails
  with a 403, add this repo under the package's "Manage Actions access" with
  the Admin role.
- **`main` must let github-actions push**: the base update commits and tags.

## Tested

29 Oct 2026, on Windows (Git Bash), without building any image:

- **Every checksum** in `versions.env` was checked against a download of the
  file at the URL the recipes use.
  - **The AWS CLI zip's PGP signature verified** against key
    `FB5DB77FD5C118B80511ADA8A6310ACC4672475C`, fetched from
    keyserver.ubuntu.com. gpg reported that copy of the key as expired.
- **The build-day rule:** `test-build-day.sh` passes.

31 Oct 2026:

- **The Google Cloud CLI and GKE plugin `.deb`s** were downloaded from
  Google's pool, and both matched the SHA256 in Google's Packages index.
- **The recipe installer**, run with a scratch `GOM_PREFIX`: tofu, kubectl,
  Helm, kustomize, yq, crane (`tar` and `bin` recipes) and kubelogin (`zip`)
  were downloaded, checked and installed, and `tools.txt` was written with
  each recipe's check. Lists with comments, an absent `--list-if-present`
  file, a `local/` recipe replacing one of ours (logged), and an unknown tool
  (stops, exit 2) all behaved.
- **The base update's `sed`**, on copies of the Dockerfiles: it changes the
  base line only and keeps `AS image`.
- **Both workflows** parse as YAML; the release's digest lookup and the
  14-day runner pick were run live against GitHub and GHCR.

31 Oct 2026, later:

- **The first build in GitHub Actions passed**, so every recipe type
  (`bin`, `tar`, `zip`, `deb`, `apt`, `script`), the snapshot apt sources and
  the smoke test inside the build are proven.
- **Licence texts** (installer run locally): the seven `bin`, `tar` and `zip`
  tools' texts were taken from their archives or fetched at their release
  tags and checked; the index was written; a recipe with no licence stopped
  the build (exit 2).

**Not tested:**
- The single `runner` image (31 Oct 2026, replacing `runner-aws`,
  `runner-azure` and `runner-gcp`): all three clouds' tools in one install,
  until the next build. Each recipe was built in one of the three before.
- The licence copies for the `deb`, `apt` and `script` tools (the packages'
  `copyright` files, the AWS CLI's), until the next build.
- Pruning, until there are more than six versions.
