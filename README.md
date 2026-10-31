<!-- Copyright (c) 2026 GitOps Manager, S.L. SPDX-License-Identifier: Apache-2.0 -->
# runner-images

Container images for self-hosted GitHub Actions runners on EKS, AKS and GKE,
with AWS, Azure and Google Cloud toolsets (OpenTofu, the cloud CLIs, kubectl,
Helm) pinned and checksum-verified, rebuilt on a schedule and published to
GHCR as `ghcr.io/gitopsmanager/<image>`. Part of
[GitOps Manager](https://gitopsmanager.io).

| Image | For |
|---|---|
| `runner-workflow-aws` | Long workflows (OpenTofu, Helm) on AWS |
| `runner-workflow-azure` | Long workflows on Azure |
| `runner-workflow-gcp` | Long workflows on Google Cloud |
| `runner-adhock-aws` | Short commands on an always-on runner, AWS |
| `runner-adhock-azure` | The same, Azure |
| `runner-adhock-gcp` | The same, Google Cloud |

What is in each, the pins and how they are checked, the build schedule and
tagging: [images/README.md](images/README.md). The build:
[`build-runner-images.yml`](.github/workflows/build-runner-images.yml), which
builds each image with [`build-image.yml`](.github/workflows/build-image.yml).

Tags are dated; there is no `latest`. Each build is a GitHub release named by
its date, with every image's digest in its notes and in an `images.json` for
scripts. The newest:
`gh release download --repo gitopsmanager/runner-images --pattern images.json`.

Developed here, in public, and rebuilt continuously -- unlike the rest of the
stack, these do not wait for a release.

## Your own images

The six images above are the ones the GitOps Manager service runs on: use
them, build on them, but don't change them, and don't reuse their names
(`runner-workflow-*`, `runner-adhock-*`) for images of your own. Everything
below adds to them without touching them.

### Build on ours, in your own repo (no fork)

The simplest way to add a tool or two. In your repo, with your own pipeline:

```dockerfile
FROM ghcr.io/gitopsmanager/runner-workflow-aws@sha256:<digest from images.json>
USER root
RUN apt-get update && apt-get install -y --no-install-recommends <package> \
 && rm -rf /var/lib/apt/lists/*
USER runner
```

You choose when to move to our newer digest.

### Fork this repo, and add your own

Your images then get everything ours do: the base moved to each new runner
release (two weeks old), every download checked, a smoke test in the build,
dated tags, a release with `images.json`, pruning.

1. **Fork** `gitopsmanager/runner-images` into your organisation. On the
   fork's Actions tab, enable workflows (GitHub disables them in a fork).
2. **Switch the build on:** repository variable `RUNNER_IMAGES_BUILD=true`.
   Images publish to `ghcr.io/<your org>/<image>`.
3. **Add your tools and images** -- only in the places this repo never
   writes, so "Sync fork" brings in our updates without conflicts:

   | To | Add |
   |---|---|
   | Add a tool to one of our images | its name to `images/<image>/tools.local` |
   | Define a tool we don't have | a recipe, `images/local/tools/<tool>.tool` ([format](images/common/tools/README.md)) |
   | Pin its version | `images/local/versions.env` (read after ours) |
   | Add an Ubuntu package | a recipe with `TYPE=apt`, `PACKAGES="name=version"` (a version in the pinned snapshot) |
   | Make a runner image of your own | a folder `images/runner-<yourorg>-<name>/` (below) |

4. **Run it:** Actions → build-runner-images → Run workflow. After that it
   runs on the same schedule as ours.

**A runner image of your own**, for example `runner-client-ci`:

```
images/runner-client-ci/
  Dockerfile      copy one of ours, change the folder name in its mounts and the description
  tools           e.g.  awscli kubectl helm yq python3 pyyaml dotnet
images/local/tools/dotnet.tool
```

```sh
# images/local/tools/dotnet.tool
VERSION=9.0.100
TYPE=tar
URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${VERSION}/dotnet-sdk-${VERSION}-linux-x64.tar.gz"
SHA256=<sha256 of that file>
INSTALL_DIR=/opt/dotnet
BIN=dotnet
CHECK="dotnet --version"
```

Every `images/runner-*` folder is built, so that becomes
`ghcr.io/<your org>/runner-client-ci`. Point an ARC runner set at it by
digest.

**Build on your own self-hosted runners, into your own registry** (ECR, ACR,
Artifact Registry): replace [`build-image.yml`](.github/workflows/build-image.yml)
-- the one file that builds and pushes an image -- with your own: your
`runs-on`, your build action (for example `gitopsmanager/multicloud-build-action`,
which signs in to ECR or ACR with the runner's own identity and builds through
its BuildKit), your registry. Keep its inputs, and give back what the release
needs: an artifact `digest-<image>` holding
`{"<image>": "<registry>/<image>@sha256:..."}`. The smoke test is inside each
Dockerfile, so your build runs it too, with no Docker daemon needed.

The base update commits to your fork's `main`, as it does to ours; both make
the same change, so syncing usually merges it cleanly.

## Security: use the newest release

**Published images are never patched.** Fixes arrive only in new builds: a
new image is built about every 15 days, on the newest GitHub runner base at
least two weeks old, with its tools at their pinned versions. An image you
pulled months ago keeps every vulnerability found since.

- **Move to the newest release regularly**, at least monthly. Read its digests
  from `images.json` rather than keeping an old one.
- **Old images are deleted:** each image keeps its 6 newest builds, about
  3 months. A digest older than that can no longer be pulled, so anything
  pinned to it (a runner set, a create runner) fails when it next needs the
  image.
- **What a new build picks up:** the runner base's updates (GitHub patches
  the base image's OS with each runner release), and any tool or package pin
  moved since (`images/common/versions.env`). Pins move by hand, so a
  vulnerability in a pinned tool is fixed when its pin is moved.

Report a vulnerability in these images privately, through this repo's
Security tab ("Report a vulnerability"), not in a public issue.

Open source under the [Apache License 2.0](LICENSE). Copyright GitOps Manager, S.L.
