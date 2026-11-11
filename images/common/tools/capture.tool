# Copyright (c) 2026 GitOps Manager, S.L.
# SPDX-License-Identifier: Apache-2.0
# The State of World capture tools (runner-capture only): a virtual
# environment at /opt/gom-capture (on the PATH first) holding Playwright, the
# Python Kubernetes client, Pillow, requests and timeout-decorator, for
# core-stack tools/state_of_world.py and stateofworld_agent.py.
#
# Every file is checked before it is installed, as in the other recipes:
#   - The wheels: capture-requirements.txt, every package (dependencies
#     included) at an exact version with its sha256, installed with
#     --require-hashes --no-deps --only-binary=:all:, so pip neither picks a
#     version nor builds anything. How to regenerate it is at its top.
#   - timeout-decorator has no wheel, only a source archive, and building it
#     would fetch build tools no hash covers. It is one pure-Python package,
#     so its folder is copied from the archive, checked by sha256.
#   - Chromium is not downloaded: the Dockerfile copies it from Microsoft's
#     Playwright image, pinned by digest, into /opt/ms-playwright
#     (PLAYWRIGHT_BROWSERS_PATH) before this runs. This checks that the
#     browsers there are the ones this Playwright version expects.
# Its system libraries come from capture-libs.tool, in the first run.
#
# The environment's own PyYAML (in the requirements) is the one python3 uses
# on this image: the Kubernetes client needs a newer one than Ubuntu's.
VERSION=$PLAYWRIGHT_VERSION
TYPE=script
CMD=playwright
CHECK="playwright --version"
EXPECT="Version $PLAYWRIGHT_VERSION"
LICENSE_ID="Apache-2.0 (Playwright); each package's own"
SOURCE=https://github.com/microsoft/playwright-python
install_tool() {
  python3 -m venv /opt/gom-capture
  /opt/gom-capture/bin/python -m pip install --no-cache-dir --disable-pip-version-check \
    --require-hashes --no-deps --only-binary=:all: -r "$here/tools/capture-requirements.txt"
  /opt/gom-capture/bin/python -m pip check

  fetch "https://files.pythonhosted.org/packages/source/t/timeout-decorator/timeout-decorator-${TIMEOUT_DECORATOR_VERSION}.tar.gz" \
    "$TIMEOUT_DECORATOR_SHA256" "$install_dir/timeout-decorator.tar.gz"
  tar -xzf "$install_dir/timeout-decorator.tar.gz" -C "$install_dir"
  site=$(/opt/gom-capture/bin/python -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')
  cp -r "$install_dir/timeout-decorator-${TIMEOUT_DECORATOR_VERSION}/timeout_decorator" "$site/"
  /opt/gom-capture/bin/python -m compileall -q "$site/timeout_decorator"
  fetch "https://raw.githubusercontent.com/pnpnpn/timeout-decorator/${TIMEOUT_DECORATOR_VERSION}/LICENSE.txt" \
    "$TIMEOUT_DECORATOR_LICENSE_SHA256" "$install_dir/timeout-decorator-LICENSE.txt"
  lic_add capture "$install_dir/timeout-decorator-LICENSE.txt"

  ln -sf /opt/gom-capture/bin/playwright "$bin/playwright"

  # The browsers copied from Microsoft's image must be the ones this
  # Playwright expects (a bump changes both: versions.env and the
  # Dockerfile's FROM line).
  locations=$(PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright /opt/gom-capture/bin/playwright install --dry-run chromium \
    | sed -n 's/^[[:space:]]*Install location:[[:space:]]*//p')
  [ -n "$locations" ] || { echo "capture.tool: playwright install --dry-run listed no browsers" >&2; exit 2; }
  for d in $locations; do
    [ -d "$d" ] || { echo "capture.tool: $d is missing: the Dockerfile's Playwright image is not Playwright $PLAYWRIGHT_VERSION" >&2; exit 2; }
  done
  chmod -R a+rX /opt/ms-playwright

  # Every installed package's licence, as the other recipes add theirs: named
  # <package>-<file>, since most are just LICENSE.
  mkdir -p "$install_dir/lic"
  for f in "$site"/*.dist-info/LICEN[CS]E* "$site"/*.dist-info/licenses/* "$site"/*.dist-info/licenses/*/*; do
    if [ -f "$f" ]; then
      dist=${f#"$site"/}
      dist=${dist%%.dist-info/*}
      cp "$f" "$install_dir/lic/$dist-$(basename "$f")"
      lic_add capture "$install_dir/lic/$dist-$(basename "$f")"
    fi
  done
}
