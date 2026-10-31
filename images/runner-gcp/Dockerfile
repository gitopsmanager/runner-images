# Copyright (c) 2026 GitOps Manager, S.L.
# SPDX-License-Identifier: Apache-2.0
# runner-gcp: every Google Cloud workflow on one image: long ones (OpenTofu creates, Helm
# installs) and short GUI commands (AddHock), on CodeBuild, Container Apps jobs or ARC.
#
# Built by .github/workflows/build-runner-images.yml with images/ as the
# build context; images/README.md says what each image is for and how to
# bump it.
#
# Base: the official GitHub Actions runner image, by tag and digest. Every
# image shares it so there is one toolchain to keep current. CodeBuild-hosted
# GitHub runners bring their own runner agent and ignore the one in here;
# Container Apps jobs use it. Either way it's Ubuntu 24.04 and the same
# non-root user (runner, uid 1001).
FROM ghcr.io/actions/actions-runner:2.338.0@sha256:4ffadc0002b2581327e06101fc8c06cd189232baf79fe561fac9caeb76f5e807 AS image

# The source label links the GHCR package to this repo, which is what lets the
# workflow's GITHUB_TOKEN push to it and prune old versions.
LABEL org.opencontainers.image.source="https://github.com/gitopsmanager/runner-images" \
      org.opencontainers.image.description="GitOps Manager runner, Google Cloud"

# Root only to install, system-wide. The scripts, recipes and lists are
# bind-mounted rather than copied, so no layer keeps them. The tools are
# listed in tools (and a fork's tools.local); each is a recipe in
# common/tools/ or local/tools/, pinned in versions.env.
USER root
RUN --mount=type=bind,source=common,target=/tmp/gom-common \
    --mount=type=bind,source=local,target=/tmp/gom-local \
    --mount=type=bind,source=runner-gcp,target=/tmp/gom-image \
    bash /tmp/gom-common/install-tools.sh --local /tmp/gom-local \
      --list /tmp/gom-image/tools --list-if-present /tmp/gom-image/tools.local
# No prompts and no update checks: the SDK is pinned, and nothing here is
# interactive.
ENV CLOUDSDK_CORE_DISABLE_PROMPTS=1 \
    CLOUDSDK_COMPONENT_MANAGER_DISABLE_UPDATE_CHECK=true
USER runner

# The smoke test, inside the build: every tool answers its recipe's check,
# as the runner user. Any builder runs it, a remote BuildKit included, so a
# broken image never builds anywhere.
FROM image AS test
RUN --mount=type=bind,source=common,target=/tmp/gom-common \
    bash /tmp/gom-common/smoke-test.sh

# The image itself. Copying a file from the test stage (the same file the
# image already has) makes the test a step of every build, even one that
# builds only the default target.
FROM image
COPY --from=test /usr/local/share/gom/tools.txt /usr/local/share/gom/tools.txt
