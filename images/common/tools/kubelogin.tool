# Copyright (c) 2026 GitOps Manager, S.L.
# SPDX-License-Identifier: Apache-2.0
VERSION=$KUBELOGIN_VERSION
TYPE=zip
URL="https://github.com/Azure/kubelogin/releases/download/v${VERSION}/kubelogin-linux-amd64.zip"
SHA256=$KUBELOGIN_SHA256
MEMBER=bin/linux_amd64/kubelogin
EXPECT="v$VERSION"
