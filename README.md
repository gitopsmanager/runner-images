<!-- Copyright (c) 2026 GitOps Manager, S.L. SPDX-License-Identifier: Apache-2.0 -->
# runner-images

Container images for self-hosted GitHub Actions runners on EKS and AKS, with
AWS and Azure toolsets (OpenTofu, AWS and Azure CLI, kubectl, Helm) pinned and
checksum-verified, rebuilt on a schedule and published to GHCR as
`ghcr.io/gitopsmanager/<image>`. Part of [GitOps Manager](https://gitopsmanager.io).

| Image | For |
|---|---|
| `runner-workflow-aws` | Long workflows (OpenTofu, Helm) on AWS |
| `runner-workflow-azure` | Long workflows on Azure |
| `runner-adhock-aws` | Short commands on an always-on runner, AWS |
| `runner-adhock-azure` | The same, Azure |

What is in each, the pins and how they are checked, the build schedule and
tagging: [images/README.md](images/README.md). The build:
[`.github/workflows/build-runner-images.yml`](.github/workflows/build-runner-images.yml).

To customise one, build on it: `FROM ghcr.io/gitopsmanager/<image>:<date>`.
Tags are dated; there is no `latest`. Each build is a GitHub release named by
its date, with every image's digest in its notes and in an `images.json` for
scripts. The newest:
`gh release download --repo gitopsmanager/runner-images --pattern images.json`.

Developed here, in public, and rebuilt continuously -- unlike the rest of the
stack, these do not wait for a release.

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
