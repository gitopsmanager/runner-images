# Copyright (c) 2026 GitOps Manager, S.L.
# SPDX-License-Identifier: Apache-2.0
# From the pinned Ubuntu snapshot.
VERSION=${PYTHON3_DEB_VERSION%%-*}
TYPE=apt
PACKAGES="python3=$PYTHON3_DEB_VERSION"
LICENSE_ID=PSF-2.0
LICENSE_FILES=/usr/share/doc/python3/copyright
SOURCE=https://www.python.org
