# Copyright (c) 2026 GitOps Manager, S.L.
# SPDX-License-Identifier: Apache-2.0
# What kubectl runs to sign in to GKE. It reports its own Kubernetes-style
# version, not the SDK release it is pinned through, so only check it runs.
VERSION=$GCLOUD_VERSION
TYPE=deb
URL="https://packages.cloud.google.com/apt/${GKE_AUTH_PLUGIN_DEB}"
SHA256=$GKE_AUTH_PLUGIN_SHA256
EXPECT=""
