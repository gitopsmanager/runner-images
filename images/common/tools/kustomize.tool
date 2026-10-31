# Copyright (c) 2026 GitOps Manager, S.L.
# SPDX-License-Identifier: Apache-2.0
VERSION=$KUSTOMIZE_VERSION
TYPE=tar
URL="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${VERSION}/kustomize_v${VERSION}_linux_amd64.tar.gz"
SHA256=$KUSTOMIZE_SHA256
CHECK="kustomize version"
EXPECT="v$VERSION"
