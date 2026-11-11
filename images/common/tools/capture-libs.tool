# Copyright (c) 2026 GitOps Manager, S.L.
# SPDX-License-Identifier: Apache-2.0
# The system side of the State of World capture tools (runner-capture only):
# python3-venv, for capture.tool's virtual environment, and the Ubuntu 24.04
# libraries and fonts Playwright's Chromium needs -- exactly what
# `playwright install-deps chromium` would install for Playwright
# $PLAYWRIGHT_VERSION (packages/playwright-core/src/server/registry/
# nativeDeps.ts at that tag: 'ubuntu24.04-x64', its tools and chromium lists).
# From the pinned Ubuntu snapshot like every other package here, not from the
# live archive install-deps would use.
#
# Its own recipe, in the image's first install-tools.sh run: install-tools.sh
# installs packages at the end of a run, and capture.tool (the second run)
# needs python3-venv already there. On a Playwright bump, compare the lists
# with nativeDeps.ts at the new tag.
VERSION=$PLAYWRIGHT_VERSION
TYPE=script
CMD=-
CHECK="/sbin/ldconfig -p | grep -F libgbm.so.1"
EXPECT="libgbm.so.1"
# Each package's terms are in /usr/share/doc/<package>/copyright, as for the
# base image's own packages; NSS is the one this list is built around.
LICENSE_ID="MPL-2.0 and others (Ubuntu packages, see /usr/share/doc)"
LICENSE_FILES=/usr/share/doc/libnss3/copyright
SOURCE=https://github.com/microsoft/playwright/blob/v${PLAYWRIGHT_VERSION}/packages/playwright-core/src/server/registry/nativeDeps.ts
install_tool() {
  apt_add python3-venv
  # nativeDeps.ts 'ubuntu24.04-x64'.tools
  apt_add xvfb fonts-noto-color-emoji fonts-unifont libfontconfig1 libfreetype6 \
    xfonts-cyrillic xfonts-scalable fonts-liberation fonts-ipafont-gothic \
    fonts-wqy-zenhei fonts-tlwg-loma-otf fonts-freefont-ttf
  # nativeDeps.ts 'ubuntu24.04-x64'.chromium
  apt_add libasound2t64 libatk-bridge2.0-0t64 libatk1.0-0t64 libatspi2.0-0t64 \
    libcairo2 libcups2t64 libdbus-1-3 libdrm2 libgbm1 libglib2.0-0t64 libnspr4 \
    libnss3 libpango-1.0-0 libx11-6 libxcb1 libxcomposite1 libxdamage1 \
    libxext6 libxfixes3 libxkbcommon0 libxrandr2
}
