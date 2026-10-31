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

Open source under the [Apache License 2.0](LICENSE). Copyright GitOps Manager, S.L.
