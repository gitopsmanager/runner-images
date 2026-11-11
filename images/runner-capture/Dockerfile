# Copyright (c) 2026 GitOps Manager, S.L.
# SPDX-License-Identifier: Apache-2.0
# runner-capture: the runner image plus Playwright (Chromium) and the Python
# Kubernetes client, for the images runners (gom-<cloud>-images): State of
# World captures, which screenshot ingresses and read a cluster the agent's
# way (core-stack tools/state_of_world.py). Everything else is the runner
# image's, from the same recipes.
#
# Chromium comes from Microsoft's Playwright image, pinned by its index
# digest, not from Playwright's own download (which nothing checks): the
# playwright stage below. The Python packages are pinned by sha256
# (common/tools/capture-requirements.txt).
#
# runner: every workflow, on AWS, Azure and Google Cloud, on one image: long
# ones (cluster creates, Helm installs) and short GUI commands (AddHock), on
# CodeBuild, Container Apps jobs or ARC. All three clouds' CLIs are in it, so
# one image, one digest, serves every runner.
#
# Built by .github/workflows/build-runner-images.yml with images/ as the
# build context; images/README.md says what each image is for and how to
# bump it.
#
# Base: the official GitHub Actions runner image, by tag and digest. A fork's
# own images share it, so there is one toolchain to keep current. CodeBuild-hosted
# GitHub runners bring their own runner agent and ignore the one in here;
# Container Apps jobs use it. Either way it's Ubuntu 24.04 and the same
# non-root user (runner, uid 1001).
#
# Microsoft's Playwright image for PLAYWRIGHT_VERSION (common/versions.env),
# by tag and index digest; bump both together. Only its browsers are used:
# Chromium, its headless shell and ffmpeg (Firefox and WebKit are dropped
# here). capture.tool fails the build if they aren't the ones that
# Playwright version expects.
FROM mcr.microsoft.com/playwright/python:v1.64.1-noble@sha256:330d401ae23c905896a0c26c66c36fc971b621519e7b11b435a8328d7bf6e031 AS playwright
RUN rm -rf /ms-playwright/firefox-* /ms-playwright/webkit-*

FROM ghcr.io/actions/actions-runner:2.338.0@sha256:4ffadc0002b2581327e06101fc8c06cd189232baf79fe561fac9caeb76f5e807 AS image

# The source label links the GHCR package to this repo, which is what lets the
# workflow's GITHUB_TOKEN push to it and prune old versions.
LABEL org.opencontainers.image.source="https://github.com/gitopsmanager/runner-images" \
      org.opencontainers.image.description="GitOps Manager runner with Playwright and the Python Kubernetes client (State of World captures)"

# Root only to install, system-wide. The scripts, recipes and lists are
# bind-mounted rather than copied, so no layer keeps them. The tools are
# listed in tools (and a fork's tools.local); each is a recipe in
# common/tools/ or local/tools/, pinned in versions.env.
USER root
RUN --mount=type=bind,source=common,target=/tmp/gom-common \
    --mount=type=bind,source=local,target=/tmp/gom-local \
    --mount=type=bind,source=runner-capture,target=/tmp/gom-image \
    bash /tmp/gom-common/install-tools.sh --local /tmp/gom-local \
      --list /tmp/gom-image/tools --list-if-present /tmp/gom-image/tools.local
# The browsers, then the capture tools: a second run, because capture.tool
# needs python3-venv, which the first run installs at its end.
COPY --from=playwright /ms-playwright /opt/ms-playwright
RUN --mount=type=bind,source=common,target=/tmp/gom-common \
    --mount=type=bind,source=local,target=/tmp/gom-local \
    --mount=type=bind,source=runner-capture,target=/tmp/gom-image \
    bash /tmp/gom-common/install-tools.sh --local /tmp/gom-local \
      --list /tmp/gom-image/tools.capture
# No prompts and no update checks: the Google Cloud SDK is pinned, and nothing
# here is interactive.
ENV CLOUDSDK_CORE_DISABLE_PROMPTS=1 \
    CLOUDSDK_COMPONENT_MANAGER_DISABLE_UPDATE_CHECK=true \
    PATH=/opt/gom-capture/bin:$PATH \
    PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright
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
