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

There are two kinds of image, one of each for every cloud:

- **Long-running** (`runner-workflow-*`): workflows that can take many
  minutes, such as creating a cluster with OpenTofu or installing with Helm.
  They carry the full toolset.
- **Short commands** (`runner-adhock-*`): quick AddHock commands from the GUI,
  on a runner that is always on. They are lean on purpose, with no OpenTofu or
  Helm, since an always-on runner is pulled to every node it lands on.

| Image | For |
|---|---|
| `runner-workflow-aws` | Long-running, AWS |
| `runner-workflow-azure` | Long-running, Azure |
| `runner-workflow-gcp` | Long-running, Google Cloud |
| `runner-adhock-aws` | Short commands, AWS |
| `runner-adhock-azure` | Short commands, Azure |
| `runner-adhock-gcp` | Short commands, Google Cloud |

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

**You don't need a subscription to use these.** The images and this repo are
open source (Apache 2.0): pull them, build on them or fork them for your own
self-hosted runners, free.

They are also the images the GitOps Manager SaaS offering runs on: its
workflows run on them, in your own accounts. See
[eksmanager.io](https://eksmanager.io) for the product, and subscribe through
[AWS Marketplace](https://aws.amazon.com/marketplace/pp/prodview-ne3pafhkcikaq).
To subscribe you need to be signed in to AWS Marketplace with the AWS account
you want to buy from; the subscription is billed to that account.

Use the images, build on them, but don't change them, and don't reuse their
names (`runner-workflow-*`, `runner-adhock-*`) for images of your own: the
service expects what is in them. Everything below adds to them without
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
   | Add a tool to one of our images | its name to `images/<image>/tools.local` |
   | Define a tool we don't have | a recipe, `images/local/tools/<tool>.tool` ([format](images/common/tools/README.md)) |
   | Pin its version | `images/local/versions.env` (read after ours) |
   | Add an Ubuntu package | a recipe with `TYPE=apt`, `PACKAGES="name=version"` (a version in the pinned snapshot) |
   | Make a runner image of your own | a folder `images/runner-<yourorg>-<name>/` (below) |

4. **Run it:** Actions → build-runner-images → Run workflow. After that it
   runs on the same schedule as ours.

**A runner image of your own**, for example `runner-client-ci` with .NET
added. Three files, made from the repo root:

```bash
# 1. The image's folder, with a copy of one of our Dockerfiles. The copy names
#    its own folder in its bind mount, so rename that (and its comment) to the
#    new folder.
mkdir images/runner-client-ci
cp images/runner-workflow-aws/Dockerfile images/runner-client-ci/
sed -i 's/runner-workflow-aws/runner-client-ci/' images/runner-client-ci/Dockerfile

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
EOF
```

Then change the `description` label in the copied Dockerfile to say what your
image is for. The build checks the download against `SHA256`, installs .NET
into `/opt/dotnet` with `dotnet` on the PATH, and its smoke test runs
`dotnet --version` and looks for `9.0.100`.

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
