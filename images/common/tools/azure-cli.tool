# Copyright (c) 2026 GitOps Manager, S.L.
# SPDX-License-Identifier: Apache-2.0
# From the repo pool by exact version (see versions.env).
VERSION=$AZURE_CLI_VERSION
TYPE=deb
URL="https://packages.microsoft.com/repos/azure-cli/pool/main/a/azure-cli/azure-cli_${AZURE_CLI_DEB_VERSION}_amd64.deb"
SHA256=$AZURE_CLI_SHA256
CMD=az
CHECK="az version --output tsv"
