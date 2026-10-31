# Copyright (c) 2026 GitOps Manager, S.L.
# SPDX-License-Identifier: Apache-2.0
VERSION=$OPENTOFU_VERSION
TYPE=tar
URL="https://github.com/opentofu/opentofu/releases/download/v${VERSION}/tofu_${VERSION}_linux_amd64.tar.gz"
SHA256=$OPENTOFU_SHA256
CHECK="tofu version"
EXPECT="v$VERSION"
LICENSE_ID=MPL-2.0
LICENSE_MEMBER=LICENSE
SOURCE=https://github.com/opentofu/opentofu
