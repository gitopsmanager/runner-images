# Copyright (c) 2026 GitOps Manager, S.L.
# SPDX-License-Identifier: Apache-2.0
# From the repo pool by exact file (see versions.env).
VERSION=$GCLOUD_VERSION
TYPE=deb
URL="https://packages.cloud.google.com/apt/${GCLOUD_DEB}"
SHA256=$GCLOUD_SHA256
CHECK="gcloud version"
EXPECT="Google Cloud SDK $VERSION"
LICENSE_ID=Apache-2.0
LICENSE_FILES="/usr/share/google-cloud-sdk/LICENSE /usr/share/doc/google-cloud-cli/copyright"
SOURCE=https://cloud.google.com/sdk
