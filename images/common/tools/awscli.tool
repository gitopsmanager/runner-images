# Copyright (c) 2026 GitOps Manager, S.L.
# SPDX-License-Identifier: Apache-2.0
# AWS ships an installer, not a single binary: TYPE=script.
VERSION=$AWSCLI_VERSION
TYPE=script
CMD=aws
EXPECT="aws-cli/$VERSION"
install_tool() {
  fetch "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${VERSION}.zip" "$AWSCLI_SHA256" "$install_dir/awscli.zip"
  unzip -q "$install_dir/awscli.zip" -d "$install_dir"
  "$install_dir/aws/install" --install-dir "$prefix/aws-cli" --bin-dir "$bin"
}
