# Copyright (c) 2026 GitOps Manager, S.L.
# SPDX-License-Identifier: Apache-2.0
# runner-workflow-azure: long Azure workflows (OpenTofu create, Helm installs), run on Container Apps jobs.
#
# Built by .github/workflows/build-runner-images.yml with images/ as the
# build context; images/README.md says what each image is for and how to
# bump it.
#
# Base: the official GitHub Actions runner image, by tag and digest. All four
# images share it so there is one toolchain to keep current. CodeBuild-hosted
# GitHub runners bring their own runner agent and ignore the one in here;
# Container Apps jobs use it. Either way it's Ubuntu 24.04 and the same
# non-root user (runner, uid 1001).
FROM ghcr.io/actions/actions-runner:2.338.0@sha256:4ffadc0002b2581327e06101fc8c06cd189232baf79fe561fac9caeb76f5e807

# The source label links the GHCR package to this repo, which is what lets the
# workflow's GITHUB_TOKEN push to it and prune old versions.
LABEL org.opencontainers.image.source="https://github.com/gitopsmanager/runner-images" \
      org.opencontainers.image.description="GitOps Manager workflow runner, Azure"

# Root only to install, system-wide. The scripts are bind-mounted rather than
# copied, so no layer keeps them. Versions and checksums: common/versions.env.
USER root
RUN --mount=type=bind,source=common,target=/tmp/gom-common \
    bash /tmp/gom-common/install-tools.sh tofu azure-cli kubelogin kubectl helm kustomize yq python3
USER runner
