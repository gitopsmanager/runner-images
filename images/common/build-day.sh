#!/usr/bin/env bash
# Copyright (c) 2026 GitOps Manager, S.L.
# SPDX-License-Identifier: Apache-2.0
# Prints "true" if the given UTC date (default: today) is a scheduled build
# day, else "false". Used by build-runner-images.yml.
#
# Build days: the 15th, and the 30th, or the last day of February (28 or 29)
# since it has no 30th. Cron can't say that, so the schedule fires on the 15th,
# 28th, 29th and 30th and this picks. The 31st is never a build day: the 30th
# has just built.
#
#   build-day.sh [YYYY-MM-DD]
set -euo pipefail

d=${1:-$(date -u +%F)}
day=$(date -u -d "$d" +%d)
month=$(date -u -d "$d" +%m)
tomorrow=$(date -u -d "$d + 1 day" +%d)

if [ "$day" = 15 ] || [ "$day" = 30 ]; then
  echo true
elif [ "$month" = 02 ] && [ "$tomorrow" = 01 ]; then
  echo true
else
  echo false
fi
