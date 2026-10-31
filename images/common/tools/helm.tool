# Copyright (c) 2026 GitOps Manager, S.L.
# SPDX-License-Identifier: Apache-2.0
VERSION=$HELM_VERSION
TYPE=tar
URL="https://get.helm.sh/helm-v${VERSION}-linux-amd64.tar.gz"
SHA256=$HELM_SHA256
MEMBER=linux-amd64/helm
CHECK="helm version --short"
EXPECT="v$VERSION"
LICENSE_ID=Apache-2.0
LICENSE_MEMBER=linux-amd64/LICENSE
SOURCE=https://github.com/helm/helm
