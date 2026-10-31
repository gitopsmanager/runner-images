#!/usr/bin/env bash
# Copyright (c) 2026 GitOps Manager, S.L.
# SPDX-License-Identifier: Apache-2.0
# Checks build-day.sh against dates whose answer is known. Run by
# build-runner-images.yml before it decides, and runnable anywhere with GNU date.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
fail=0
while read -r date want why; do
  got=$(bash "$here/build-day.sh" "$date")
  if [ "$got" = "$want" ]; then echo "ok   $date $got  ($why)"; else echo "FAIL $date got $got want $want  ($why)"; fail=1; fi
done <<'DATES'
2026-10-15 true  the 15th
2027-02-15 true  the 15th of February
2026-10-30 true  the 30th, 31-day month
2026-11-30 true  the 30th, 30-day month
2026-10-28 false the 28th, not February
2026-10-29 false the 29th, 31-day month
2026-11-29 false the 29th, 30-day month
2026-10-31 false the 31st
2026-07-16 false an ordinary day
2027-02-28 true  last day of February, common year
2028-02-28 false the 28th of February, leap year
2028-02-29 true  last day of February, leap year
2100-02-28 true  last day of February, century non-leap year
2000-02-29 true  last day of February, 400-year leap year
DATES
exit "$fail"
