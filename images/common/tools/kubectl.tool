# Copyright (c) 2026 GitOps Manager, S.L.
# SPDX-License-Identifier: Apache-2.0
VERSION=$KUBECTL_VERSION
TYPE=bin
URL="https://dl.k8s.io/release/v${VERSION}/bin/linux/amd64/kubectl"
SHA256=$KUBECTL_SHA256
CHECK="kubectl version --client"
EXPECT="v$VERSION"
