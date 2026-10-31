# Copyright (c) 2026 GitOps Manager, S.L.
# SPDX-License-Identifier: Apache-2.0
# For the scripts that read values and topology files.
VERSION=$PYYAML_VERSION
TYPE=apt
PACKAGES="python3-yaml=$PYYAML_DEB_VERSION"
CMD=-
CHECK="python3 -c 'import yaml; print(yaml.__version__)'"
