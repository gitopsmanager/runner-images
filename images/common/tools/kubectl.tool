# Copyright (c) 2026 GitOps Manager, S.L.
# SPDX-License-Identifier: Apache-2.0
VERSION=$KUBECTL_VERSION
TYPE=bin
URL="https://dl.k8s.io/release/v${VERSION}/bin/linux/amd64/kubectl"
SHA256=$KUBECTL_SHA256
CHECK="kubectl version --client"
EXPECT="v$VERSION"
LICENSE_ID=Apache-2.0
LICENSE_URL="https://raw.githubusercontent.com/kubernetes/kubernetes/v${VERSION}/LICENSE"
LICENSE_SHA256=$KUBECTL_LICENSE_SHA256
SOURCE=https://github.com/kubernetes/kubernetes
