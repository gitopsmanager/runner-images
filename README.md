<!-- Copyright (c) 2026 GitOps Manager, S.L. SPDX-License-Identifier: Apache-2.0 -->
# runner-images

Container images for self-hosted GitHub Actions runners on EKS, AKS and GKE,
with AWS, Azure and Google Cloud toolsets (OpenTofu, the cloud CLIs, kubectl,
Helm) pinned and checksum-verified, rebuilt on a schedule and published to
GHCR as `ghcr.io/gitopsmanager/<image>`. Part of
[GitOps Manager](https://gitopsmanager.io).

> **New images about every 15 days: on the 15th and the 30th of each month**
> (the last day of February, which has no 30th), at 04:00 UTC. Each build moves to the newest GitHub runner base
> that is at least two weeks old and is published as a dated release. Images
> are never patched once published, so move to the newest release at least
> monthly ([Security](#security-use-the-newest-release)).

**One image, `runner`, for every workflow on every cloud:** long ones that
can take many minutes, such as creating a cluster with OpenTofu or installing
with Helm, and short commands from the GUI on an always-on runner. It carries
the AWS, Azure and Google Cloud CLIs, so every runner set, on any cloud, pins
the same image and digest.

Most of it is GitHub's runner base (about 520 MB compressed: the runner agent
with its .NET and Node runtimes, Docker, Ubuntu and git). The shared tools add
about 175 MB and the three clouds' CLIs about 265 MB, as downloaded. One
image per cloud would save under 200 MB, and a lighter one for short commands
alone under 10%, so there is one.

What is in it, the pins and how they are checked, the build schedule and
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

**You don't need a subscription to use these.** The images and this repo are
open source (Apache 2.0): pull them, build on them or fork them for your own
self-hosted runners, free.

They are also the images the GitOps Manager SaaS offering runs on: its
workflows run on them, in your own accounts. See
[eksmanager.io](https://eksmanager.io) for the product, and subscribe through
[AWS Marketplace](https://aws.amazon.com/marketplace/pp/prodview-ne3pafhkcikaq).
To subscribe you need to be signed in to AWS Marketplace with the AWS account
you want to buy from; the subscription is billed to that account.

Use the image, build on it, but don't change it, and don't reuse its name
(`runner`) for an image of your own: the service expects what is in it. Everything below adds to them without
touching them.

### Fork this repo, and add your own

Your images then get everything ours do: the base moved to each new runner
release (two weeks old), every download checked, a smoke test in the build,
dated tags, a release with `images.json`, pruning.

**Why on the same cadence.** A runner image has to keep moving. GitHub stops
sending jobs to a self-hosted runner whose runner software is too far behind
the current release -- for runners that don't update themselves, as under
ARC, about 30 days after a new release -- and we delete our own images after
about three months. An image built once and left alone stops getting jobs.
A fork rebuilds on our schedule, on the same base, so yours keep up with ours.

1. **Fork** `gitopsmanager/runner-images` into your organisation. On the
   fork's Actions tab, enable workflows (GitHub disables them in a fork).
2. **Switch the build on:** repository variable `RUNNER_IMAGES_BUILD=true`.
   Images publish to `ghcr.io/<your org>/<image>`.
3. **Add your tools and images** -- only in the places this repo never
   writes, so "Sync fork" brings in our updates without conflicts:

   | To | Add |
   |---|---|
   | Add a tool to our image | its name to `images/runner/tools.local` |
   | Define a tool we don't have | a recipe, `images/local/tools/<tool>.tool` ([format](images/common/tools/README.md)) |
   | Pin its version | `images/local/versions.env` (read after ours) |
   | Add an Ubuntu package | a recipe with `TYPE=apt`, `PACKAGES="name=version"` (a version in the pinned snapshot) |
   | Make a runner image of your own | a folder `images/runner-<yourorg>-<name>/` (below) |
   | Build on your own runners, into your own registry | a copy of `examples/build/` at `images/local/build/`, and `BUILD_IMAGE=local` (below) |

4. **Run it:** Actions → build-runner-images → Run workflow. After that it
   runs on the same schedule as ours.

**A runner image of your own**, for example a lean AWS-only `runner-client-ci`
with .NET added. Three files, made from the repo root:

```bash
# 1. The image's folder, with a copy of our Dockerfile. The copy names its own
#    folder in its bind mount (source=runner,), so point that at the new folder.
mkdir images/runner-client-ci
cp images/runner/Dockerfile images/runner-client-ci/
sed -i 's/source=runner,/source=runner-client-ci,/' images/runner-client-ci/Dockerfile

# 2. Its tools file: the tools to install, by recipe name, separated by spaces
#    or new lines. Each name needs a recipe: ours in images/common/tools/
#    (awscli, kubectl, helm, yq, python3, pyyaml, ...) or yours in
#    images/local/tools/ (dotnet, below).
echo "awscli kubectl helm yq python3 pyyaml dotnet" > images/runner-client-ci/tools

# 3. The recipe for the one tool we don't have.
mkdir -p images/local/tools
cat > images/local/tools/dotnet.tool <<'EOF'
VERSION=9.0.100
TYPE=tar
URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${VERSION}/dotnet-sdk-${VERSION}-linux-x64.tar.gz"
SHA256=<sha256 of that file>
INSTALL_DIR=/opt/dotnet
BIN=dotnet
CHECK="dotnet --version"
LICENSE_ID=MIT
LICENSE_MEMBER="LICENSE.txt ThirdPartyNotices.txt"
SOURCE=https://github.com/dotnet/sdk
EOF
```

Then change the `description` label in the copied Dockerfile to say what your
image is for. The build checks the download against `SHA256`, installs .NET
into `/opt/dotnet` with `dotnet` on the PATH, copies its licence texts into
the image's `licenses/dotnet/`, and its smoke test runs `dotnet --version` and
looks for `9.0.100`. Every recipe needs its licence (`LICENSE_*`): the build
stops without one.

`images/runner` and every `images/runner-*` folder are built, so that becomes
`ghcr.io/<your org>/runner-client-ci`. Point an ARC runner set at it by
digest.

**Build on your own self-hosted runners, into your own registry** (ECR, ACR,
Artifact Registry): copy the example build action into your own area, and set
the repository variables below, starting with `BUILD_IMAGE=local`:

```bash
mkdir -p images/local/build
cp examples/build/action.yml images/local/build/action.yml
```

Without `BUILD_IMAGE`, our [`build-image.yml`](.github/workflows/build-image.yml)
builds on GitHub's runners into GHCR; with `BUILD_IMAGE=local`, it runs your
action at `images/local/build` instead, on the runner `RUNNER_LABELS` names.
This repo never writes in `images/local/` and never changes the example, so
your copy never conflicts on a sync -- don't edit `build-image.yml`, which we
do change.

As shipped, it builds with
[`multicloud-build-action`](https://github.com/gitopsmanager/multicloud-build-action):
on a self-hosted runner it builds through the runner's BuildKit, with no
Docker daemon needed, and signs in to ECR and ACR with the runner's own
identity (EKS Pod Identity, or the AKS managed identity). Set it up with
repository variables:

| Variable | |
|---|---|
| `BUILD_IMAGE` | `local`, to use this build instead of ours |
| `RUNNER_LABELS` | the runner to build on: a label or a JSON list, e.g. `["self-hosted","build"]` (default `ubuntu-24.04`, GitHub's) |
| `AWS_IMAGE_REGISTRY` | ECR, e.g. `111122223333.dkr.ecr.eu-west-1.amazonaws.com` |
| `AZURE_IMAGE_REGISTRY` | ACR, e.g. `clientacr.azurecr.io` (at least one of the two; both set pushes to both) |
| `IMAGE_REPOSITORY_PREFIX` | optional: repositories are `<prefix>/<image>` |
| `AWS_ECR_OIDC_ROLE_ARN` | optional: push to ECR through GitHub OIDC instead of the runner's identity |
| `AZURE_ACR_OIDC_CLIENT_ID`, `AZURE_TENANT_ID` | optional: the same for ACR |

ECR needs each repository to exist first; ACR makes them on the first push.
Nothing prunes old images there: keep the newest few with the registry's own
rule (an ECR lifecycle policy, ACR retention). Or change your copy however you
like; whatever it does, it must give back two outputs: `ref` (where it pushed,
`<registry>/<repository>`, no tag) and `digest` (`sha256:...`). The release
and `images.json` are built from them. The smoke test is inside each
Dockerfile, so your build runs it too.

The base update commits to your fork's `main`, as it does to ours; both make
the same change, so syncing usually merges it cleanly.

## Actions it uses

If your organisation allows only selected actions (Settings → Actions →
General → "Allow select actions"), a fork needs these. Pinned by major
version, so allow each by name (`owner/name@*`), or by owner (`actions/*`,
`docker/*`, `gitopsmanager/*`).

| Action | Version | Used by | For |
|---|---|---|---|
| `actions/checkout` | v7 | every build | the repo at the commit being built |
| `actions/upload-artifact` | v7 | every build | each image's digest, for the release |
| `actions/download-artifact` | v8 | every build | collecting the digests for the release |
| `docker/setup-buildx-action` | v4 | the default build | the image builder |
| `docker/login-action` | v4 | the default build | signing in to GHCR |
| `docker/build-push-action` | v7 | the default build | build, smoke test and push |
| `actions/delete-package-versions` | v5 | the default build | keeping the 6 newest images in GHCR |
| `gitopsmanager/multicloud-build-action` | v1 | `BUILD_IMAGE=local` (the example build) | build and push into ECR / ACR |
| `gitopsmanager/detect-cloud` | v1 | inside `multicloud-build-action` | which cloud the runner is in |
| `docker/bake-action` | v7 | inside `multicloud-build-action` | the build |
| `actions/github-script` | v9 | inside `multicloud-build-action` | its sign-in and build planning |

`actions/*` are GitHub's own and `docker/*` are Docker's (a verified creator),
so "Allow actions created by GitHub" and "Allow actions by Marketplace
verified creators" cover them; the `gitopsmanager/*` ones are needed only
for the example build and must be allowed by name. The `gh` and `jq` the
workflows run are on GitHub's runners already, not actions.

Licences of the software inside the images: [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

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
